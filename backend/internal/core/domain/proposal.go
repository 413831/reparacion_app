package domain

import (
	"errors"
	"time"

	"github.com/google/uuid"
)

type ProposalStatus string

const (
	ProposalStatusPending   ProposalStatus = "pending"
	ProposalStatusAccepted  ProposalStatus = "accepted"
	ProposalStatusRejected  ProposalStatus = "rejected"
	ProposalStatusWithdrawn ProposalStatus = "withdrawn"
)

type Proposal struct {
	ID                     uuid.UUID      `json:"id"`
	JobID                  uuid.UUID      `json:"job_id"`
	TechnicianID           uuid.UUID      `json:"technician_id"`
	EstimatedBudget        float64        `json:"estimated_budget"`
	EstimatedDurationHours int            `json:"estimated_duration_hours"`
	CoverNote              string         `json:"cover_note"`
	Status                 ProposalStatus `json:"status"`
	CreatedAt              time.Time      `json:"created_at"`
	UpdatedAt              time.Time      `json:"updated_at"`

	// Enriched fields for client review
	TechnicianName   string  `json:"technician_name,omitempty"`
	TechnicianRating float64 `json:"technician_rating,omitempty"`
	TechnicianAvatar string  `json:"technician_avatar,omitempty"`
}

var (
	ErrProposalAlreadyExists = errors.New("technician has already applied for this job")
	ErrProposalNotFound      = errors.New("proposal not found")
	ErrInvalidBudget         = errors.New("budget must be greater than zero")
)
