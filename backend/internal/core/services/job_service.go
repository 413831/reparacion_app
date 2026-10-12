package services

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/reparatutti/backend/internal/core/domain"
	"github.com/reparatutti/backend/internal/core/ports"
)

type JobService struct {
	jobRepo      ports.JobRepository
	proposalRepo ports.ProposalRepository
	userRepo     ports.UserRepository
}

func NewJobService(
	jobRepo ports.JobRepository,
	proposalRepo ports.ProposalRepository,
	userRepo ports.UserRepository,
) *JobService {
	return &JobService{
		jobRepo:      jobRepo,
		proposalRepo: proposalRepo,
		userRepo:     userRepo,
	}
}

// CreateJob creates a service request by a client
func (s *JobService) CreateJob(ctx context.Context, clientID uuid.UUID, category domain.TradeCategory, title, description, locality string, scheduleDate time.Time, photos []string) (*domain.Job, error) {
	client, err := s.userRepo.GetByID(ctx, clientID)
	if err != nil {
		return nil, fmt.Errorf("client not found: %w", err)
	}
	if client.Role != domain.RoleClient {
		return nil, errors.New("only clients can publish service jobs")
	}

	job := &domain.Job{
		ID:                    uuid.New(),
		ClientID:              clientID,
		Category:              category,
		Title:                 title,
		Description:           description,
		PhotosURLs:            photos,
		EstimatedScheduleDate: scheduleDate,
		GeneralLocality:       locality,
		Status:                domain.JobStatusPublished,
		CreatedAt:             time.Now(),
		UpdatedAt:             time.Now(),
	}

	if err := s.jobRepo.Create(ctx, job); err != nil {
		return nil, fmt.Errorf("failed to create job: %w", err)
	}

	return job, nil
}

// ApplyForJob validates KYC status before permitting a proposal:
// "Técnicos con estado unverified o pending no pueden postularse a trabajos."
func (s *JobService) ApplyForJob(ctx context.Context, technicianID, jobID uuid.UUID, budget float64, durationHours int, coverNote string) (*domain.Proposal, error) {
	tech, err := s.userRepo.GetByID(ctx, technicianID)
	if err != nil {
		return nil, fmt.Errorf("technician not found: %w", err)
	}

	if !tech.CanApplyForJobs() {
		return nil, domain.ErrUserNotVerified
	}

	job, err := s.jobRepo.GetByID(ctx, jobID)
	if err != nil {
		return nil, fmt.Errorf("job not found: %w", err)
	}

	if job.Status != domain.JobStatusPublished && job.Status != domain.JobStatusInBidding {
		return nil, errors.New("job is no longer accepting proposals")
	}

	if budget <= 0 {
		return nil, domain.ErrInvalidBudget
	}

	existing, _ := s.proposalRepo.GetByJobAndTechnician(ctx, jobID, technicianID)
	if existing != nil {
		return nil, domain.ErrProposalAlreadyExists
	}

	proposal := &domain.Proposal{
		ID:                     uuid.New(),
		JobID:                  jobID,
		TechnicianID:           technicianID,
		EstimatedBudget:        budget,
		EstimatedDurationHours: durationHours,
		CoverNote:              coverNote,
		Status:                 domain.ProposalStatusPending,
		CreatedAt:              time.Now(),
		UpdatedAt:              time.Now(),
	}

	if err := s.proposalRepo.Create(ctx, proposal); err != nil {
		return nil, fmt.Errorf("failed to submit proposal: %w", err)
	}

	// Update job status to in_bidding if it was just published
	if job.Status == domain.JobStatusPublished {
		_ = s.jobRepo.UpdateStatus(ctx, jobID, domain.JobStatusInBidding)
	}

	return proposal, nil
}

// AcceptProposal assigns the technician and unlocks the 1:1 chat
func (s *JobService) AcceptProposal(ctx context.Context, clientID, proposalID uuid.UUID) (*domain.Job, error) {
	proposal, err := s.proposalRepo.GetByID(ctx, proposalID)
	if err != nil {
		return nil, domain.ErrProposalNotFound
	}

	job, err := s.jobRepo.GetByID(ctx, proposal.JobID)
	if err != nil {
		return nil, fmt.Errorf("job not found: %w", err)
	}

	if job.ClientID != clientID {
		return nil, errors.New("only the job owner can accept proposals")
	}

	// Mark proposal accepted
	if err := s.proposalRepo.UpdateStatus(ctx, proposal.ID, domain.ProposalStatusAccepted); err != nil {
		return nil, err
	}

	// Assign technician to job and advance status
	if err := s.jobRepo.AssignTechnician(ctx, job.ID, proposal.TechnicianID); err != nil {
		return nil, err
	}

	job.AssignedTechnicianID = &proposal.TechnicianID
	job.Status = domain.JobStatusAssigned

	// Mark all other proposals as rejected
	allProposals, _ := s.proposalRepo.ListByJobID(ctx, job.ID)
	for _, p := range allProposals {
		if p.ID != proposal.ID && p.Status == domain.ProposalStatusPending {
			_ = s.proposalRepo.UpdateStatus(ctx, p.ID, domain.ProposalStatusRejected)
		}
	}

	return job, nil
}

// CompleteJob closes the service and enables rating
func (s *JobService) CompleteJob(ctx context.Context, clientID, jobID uuid.UUID) error {
	job, err := s.jobRepo.GetByID(ctx, jobID)
	if err != nil {
		return err
	}
	if job.ClientID != clientID {
		return errors.New("only the client can mark the job as completed")
	}
	if job.Status != domain.JobStatusAssigned && job.Status != domain.JobStatusInProgress {
		return domain.ErrJobCannotBeCompleted
	}

	return s.jobRepo.UpdateStatus(ctx, jobID, domain.JobStatusCompleted)
}
