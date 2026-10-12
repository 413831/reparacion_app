package domain

import (
	"errors"
	"time"

	"github.com/google/uuid"
)

type Review struct {
	ID           uuid.UUID `json:"id"`
	JobID        uuid.UUID `json:"job_id"`
	ClientID     uuid.UUID `json:"client_id"`
	TechnicianID uuid.UUID `json:"technician_id"`
	Score        int       `json:"score"` // 1 to 5
	Comment      string    `json:"comment"`
	CreatedAt    time.Time `json:"created_at"`
}

var (
	ErrReviewAlreadySubmitted = errors.New("a review for this job has already been registered")
	ErrOnlyClientCanReview    = errors.New("only the client who created the job can submit a review")
	ErrJobNotFinished         = errors.New("reviews can only be submitted for completed jobs")
)
