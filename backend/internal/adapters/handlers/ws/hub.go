package ws

import (
	"context"
	"encoding/json"
	"log"
	"sync"
	"time"

	"github.com/google/uuid"
	"github.com/gorilla/websocket"
	"github.com/reparatutti/backend/internal/core/domain"
	"github.com/reparatutti/backend/internal/core/ports"
)

type WSMessageIn struct {
	Type     domain.MessageType     `json:"type"` // "text", "location"
	Content  string                 `json:"content"`
	Metadata map[string]interface{} `json:"metadata,omitempty"`
}

type WSMessageOut struct {
	ID        uuid.UUID              `json:"id"`
	JobID     uuid.UUID              `json:"job_id"`
	SenderID  uuid.UUID              `json:"sender_id"`
	Type      domain.MessageType     `json:"type"`
	Content   string                 `json:"content"`
	Metadata  map[string]interface{} `json:"metadata,omitempty"`
	CreatedAt time.Time              `json:"created_at"`
}

type Client struct {
	Hub    *Hub
	Conn   *websocket.Conn
	UserID uuid.UUID
	JobID  uuid.UUID
	Send   chan []byte
}

type Hub struct {
	mu         sync.RWMutex
	rooms      map[uuid.UUID]map[*Client]bool
	register   chan *Client
	unregister chan *Client
	broadcast  chan *domain.Message

	chatRepo ports.ChatRepository
	jobRepo  ports.JobRepository
}

func NewHub(chatRepo ports.ChatRepository, jobRepo ports.JobRepository) *Hub {
	return &Hub{
		rooms:      make(map[uuid.UUID]map[*Client]bool),
		register:   make(chan *Client),
		unregister: make(chan *Client),
		broadcast:  make(chan *domain.Message, 256),
		chatRepo:   chatRepo,
		jobRepo:    jobRepo,
	}
}

func (h *Hub) Run() {
	for {
		select {
		case client := <-h.register:
			h.mu.Lock()
			if _, exists := h.rooms[client.JobID]; !exists {
				h.rooms[client.JobID] = make(map[*Client]bool)
			}
			h.rooms[client.JobID][client] = true
			h.mu.Unlock()
			log.Printf("[WebSocket] User %s connected to Job Room %s", client.UserID, client.JobID)

		case client := <-h.unregister:
			h.mu.Lock()
			if clients, ok := h.rooms[client.JobID]; ok {
				if _, exists := clients[client]; exists {
					delete(clients, client)
					close(client.Send)
					if len(clients) == 0 {
						delete(h.rooms, client.JobID)
					}
				}
			}
			h.mu.Unlock()
			log.Printf("[WebSocket] User %s disconnected from Job Room %s", client.UserID, client.JobID)

		case msg := <-h.broadcast:
			h.mu.RLock()
			clients, exists := h.rooms[msg.JobID]
			if exists {
				out := WSMessageOut{
					ID:        msg.ID,
					JobID:     msg.JobID,
					SenderID:  msg.SenderID,
					Type:      msg.Type,
					Content:   msg.Content,
					Metadata:  msg.Metadata,
					CreatedAt: msg.CreatedAt,
				}
				data, err := json.Marshal(out)
				if err == nil {
					for client := range clients {
						select {
						case client.Send <- data:
						default:
							close(client.Send)
							delete(clients, client)
						}
					}
				}
			}
			h.mu.RUnlock()
		}
	}
}

func (c *Client) ReadPump() {
	defer func() {
		c.Hub.unregister <- c
		c.Conn.Close()
	}()

	c.Conn.SetReadLimit(64 * 1024) // 64KB max payload
	_ = c.Conn.SetReadDeadline(time.Now().Add(60 * time.Second))
	c.Conn.SetPongHandler(func(string) error {
		_ = c.Conn.SetReadDeadline(time.Now().Add(60 * time.Second))
		return nil
	})

	for {
		_, messageData, err := c.Conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				log.Printf("[WebSocket error] %v", err)
			}
			break
		}

		var in WSMessageIn
		if err := json.Unmarshal(messageData, &in); err != nil {
			log.Printf("[WebSocket unmarshal error]: %v", err)
			continue
		}

		msg := &domain.Message{
			ID:        uuid.New(),
			JobID:     c.JobID,
			SenderID:  c.UserID,
			Type:      in.Type,
			Content:   in.Content,
			Metadata:  in.Metadata,
			CreatedAt: time.Now(),
		}

		// Handle explicit location sharing
		if in.Type == domain.MessageTypeLocation {
			c.handleLocationPayload(msg, in.Metadata)
		}

		// Persist message asynchronously
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		if err := c.Hub.chatRepo.SaveMessage(ctx, msg); err != nil {
			log.Printf("[WebSocket DB Save Error]: %v", err)
		}
		cancel()

		// Broadcast to job room
		c.Hub.broadcast <- msg
	}
}

func (c *Client) handleLocationPayload(msg *domain.Message, metadata map[string]interface{}) {
	if metadata == nil {
		return
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	job, err := c.Hub.jobRepo.GetByID(ctx, c.JobID)
	if err != nil {
		return
	}

	if !job.CanShareLocation(c.UserID) {
		log.Printf("[WebSocket Location] Sender %s is not permitted to share location on job %s", c.UserID, c.JobID)
		return
	}

	var address string
	var lat, lng float64
	if addr, ok := metadata["address"].(string); ok {
		address = addr
	}
	if lt, ok := metadata["latitude"].(float64); ok {
		lat = lt
	}
	if lg, ok := metadata["longitude"].(float64); ok {
		lng = lg
	}

	if address != "" {
		_ = c.Hub.jobRepo.UpdateLocation(ctx, c.JobID, address, lat, lng)
	}
}

func (c *Client) WritePump() {
	ticker := time.NewTicker(30 * time.Second)
	defer func() {
		ticker.Stop()
		c.Conn.Close()
	}()

	for {
		select {
		case message, ok := <-c.Send:
			_ = c.Conn.SetWriteDeadline(time.Now().Add(10 * time.Second))
			if !ok {
				_ = c.Conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}
			w, err := c.Conn.NextWriter(websocket.TextMessage)
			if err != nil {
				return
			}
			_, _ = w.Write(message)
			if err := w.Close(); err != nil {
				return
			}

		case <-ticker.C:
			_ = c.Conn.SetWriteDeadline(time.Now().Add(10 * time.Second))
			if err := c.Conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}
