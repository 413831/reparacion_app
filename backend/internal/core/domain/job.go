package domain

import (
	"errors"
	"time"

	"github.com/google/uuid"
)

type JobStatus string

const (
	JobStatusPublished  JobStatus = "published"
	JobStatusInBidding  JobStatus = "in_bidding"
	JobStatusAssigned   JobStatus = "assigned"
	JobStatusInProgress JobStatus = "in_progress"
	JobStatusCompleted  JobStatus = "completed"
	JobStatusCancelled  JobStatus = "cancelled"
)

type Job struct {
	ID                   uuid.UUID     `json:"id"`
	ClientID             uuid.UUID     `json:"client_id"`
	AssignedTechnicianID *uuid.UUID    `json:"assigned_technician_id,omitempty"`
	Category             TradeCategory `json:"category"`
	Title                string        `json:"title"`
	Description          string        `json:"description"`
	PhotosURLs           []string      `json:"photos_urls"`
	EstimatedScheduleDate time.Time    `json:"estimated_schedule_date"`
	GeneralLocality      string        `json:"general_locality"`
	FullAddress          *string       `json:"full_address,omitempty"`
	LocationLatitude     *float64      `json:"location_latitude,omitempty"`
	LocationLongitude    *float64      `json:"location_longitude,omitempty"`
	Status               JobStatus     `json:"status"`
	CreatedAt            time.Time     `json:"created_at"`
	UpdatedAt            time.Time     `json:"updated_at"`
	CompletedAt          *time.Time    `json:"completed_at,omitempty"`
}

var (
	ErrJobNotAssigned          = errors.New("chat and exact address sharing are only permitted once a technician is assigned")
	ErrJobUnauthorizedAccess  = errors.New("user is not a participant in this job")
	ErrJobCannotBeCompleted    = errors.New("job cannot be completed in its current state")
)

func (j *Job) CanAccessChat(userID uuid.UUID) bool {
	if j.ClientID == userID {
		return true
	}
	if j.AssignedTechnicianID != nil && *j.AssignedTechnicianID == userID {
		return true
	}
	return false
}

func (j *Job) CanShareLocation(senderID uuid.UUID) bool {
	// Only the client can share the exact address, and only when assigned or in progress
	if j.ClientID != senderID {
		return false
	}
	return j.Status == JobStatusAssigned || j.Status == JobStatusInProgress
}
