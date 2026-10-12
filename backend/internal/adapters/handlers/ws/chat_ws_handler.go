package ws

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/gorilla/websocket"
	"github.com/reparatutti/backend/internal/core/ports"
)

var upgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
	CheckOrigin: func(r *http.Request) bool {
		// MVP: Allow requests from Flutter mobile / web clients
		return true
	},
}

type ChatWSHandler struct {
	hub     *Hub
	jobRepo ports.JobRepository
}

func NewChatWSHandler(hub *Hub, jobRepo ports.JobRepository) *ChatWSHandler {
	return &ChatWSHandler{
		hub:     hub,
		jobRepo: jobRepo,
	}
}

func (h *ChatWSHandler) HandleChatWS(c *gin.Context) {
	jobIDStr := c.Param("job_id")
	jobID, err := uuid.Parse(jobIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid job id"})
		return
	}

	// Retrieve authenticated user from context (set by auth middleware)
	userIDVal, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}
	userID := userIDVal.(uuid.UUID)

	// Validate user participation in this 1:1 job chat
	job, err := h.jobRepo.GetByID(c.Request.Context(), jobID)
	if err != nil || job == nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "job not found"})
		return
	}

	if !job.CanAccessChat(userID) {
		c.JSON(http.StatusForbidden, gin.H{"error": "user is not a participant in this job"})
		return
	}

	conn, err := upgrader.Upgrade(c.Writer, c.Request, nil)
	if err != nil {
		return
	}

	client := &Client{
		Hub:    h.hub,
		Conn:   conn,
		UserID: userID,
		JobID:  jobID,
		Send:   make(chan []byte, 256),
	}

	h.hub.register <- client

	go client.WritePump()
	go client.ReadPump()
}
