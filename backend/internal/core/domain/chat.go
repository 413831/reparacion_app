package domain

import (
	"errors"
	"time"

	"github.com/google/uuid"
)

type MessageType string

const (
	MessageTypeText     MessageType = "text"
	MessageTypeLocation MessageType = "location"
	MessageTypeSystem   MessageType = "system"
	MessageTypeImage    MessageType = "image"
)

type LocationMetadata struct {
	Latitude  float64 `json:"latitude"`
	Longitude float64 `json:"longitude"`
	Address   string  `json:"address"`
	Apartment string  `json:"apartment,omitempty"`
	Notes     string  `json:"notes,omitempty"`
}

type Message struct {
	ID        uuid.UUID              `json:"id"`
	JobID     uuid.UUID              `json:"job_id"`
	SenderID  uuid.UUID              `json:"sender_id"`
	Type      MessageType            `json:"type"`
	Content   string                 `json:"content"`
	Metadata  map[string]interface{} `json:"metadata,omitempty"`
	IsRead    bool                   `json:"is_read"`
	CreatedAt time.Time              `json:"created_at"`
}

var (
	ErrEmptyMessageContent = errors.New("message content or location cannot be empty")
	ErrInvalidLocation     = errors.New("location coordinates are invalid")
)
