package services

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/reparatutti/backend/internal/core/domain"
	"github.com/reparatutti/backend/internal/core/ports"
)

type ReviewService struct {
	reviewRepo ports.ReviewRepository
	jobRepo    ports.JobRepository
	userRepo   ports.UserRepository
}

func NewReviewService(
	reviewRepo ports.ReviewRepository,
	jobRepo ports.JobRepository,
	userRepo ports.UserRepository,
) *ReviewService {
	return &ReviewService{
		reviewRepo: reviewRepo,
		jobRepo:    jobRepo,
		userRepo:   userRepo,
	}
}

// SubmitReview registers the score and updates the technician's cumulative rating
func (s *ReviewService) SubmitReview(ctx context.Context, clientID, jobID uuid.UUID, score int, comment string) (*domain.Review, error) {
	if score < 1 || score > 5 {
		return nil, domain.ErrInvalidRatingScore
	}

	job, err := s.jobRepo.GetByID(ctx, jobID)
	if err != nil {
		return nil, fmt.Errorf("job not found: %w", err)
	}

	if job.ClientID != clientID {
		return nil, domain.ErrOnlyClientCanReview
	}

	if job.Status != domain.JobStatusCompleted {
		return nil, domain.ErrJobNotFinished
	}

	if job.AssignedTechnicianID == nil {
		return nil, fmt.Errorf("no technician was assigned to this job")
	}

	existingReview, _ := s.reviewRepo.GetByJobID(ctx, jobID)
	if existingReview != nil {
		return nil, domain.ErrReviewAlreadySubmitted
	}

	technicianID := *job.AssignedTechnicianID
	technician, err := s.userRepo.GetByID(ctx, technicianID)
	if err != nil {
		return nil, fmt.Errorf("technician not found: %w", err)
	}

	// Calculate new cumulative rating using domain formula:
	// rating_nuevo = ((rating_actual * N) + score) / (N + 1)
	newRating, err := technician.CalculateNewRating(score)
	if err != nil {
		return nil, err
	}

	review := &domain.Review{
		ID:           uuid.New(),
		JobID:        jobID,
		ClientID:     clientID,
		TechnicianID: technicianID,
		Score:        score,
		Comment:      comment,
		CreatedAt:    time.Now(),
	}

	if err := s.reviewRepo.Create(ctx, review); err != nil {
		return nil, fmt.Errorf("failed to save review: %w", err)
	}

	// Persist updated technician rating average and increment reviews count
	newReviewsCount := technician.ReviewsCount + 1
	if err := s.userRepo.UpdateRating(ctx, technicianID, newRating, newReviewsCount); err != nil {
		return nil, fmt.Errorf("failed to update technician rating: %w", err)
	}

	return review, nil
}
