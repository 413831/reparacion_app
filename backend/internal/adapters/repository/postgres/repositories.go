package postgres

import (
	"context"
	"errors"
	"sort"
	"sync"
	"time"

	"github.com/google/uuid"
	"github.com/reparatutti/backend/internal/core/domain"
	"github.com/reparatutti/backend/internal/core/ports"
)

// ============================================================================
// IN-MEMORY KYC REPOSITORY
// ============================================================================

type InMemoryKYCRepo struct {
	mu      sync.RWMutex
	records map[uuid.UUID]*domain.KYCVerification
	byUser  map[uuid.UUID][]uuid.UUID
}

func NewInMemoryKYCRepo() *InMemoryKYCRepo {
	return &InMemoryKYCRepo{
		records: make(map[uuid.UUID]*domain.KYCVerification),
		byUser:  make(map[uuid.UUID][]uuid.UUID),
	}
}

func (r *InMemoryKYCRepo) Create(ctx context.Context, kyc *domain.KYCVerification) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	copy := *kyc
	r.records[kyc.ID] = &copy
	r.byUser[kyc.UserID] = append(r.byUser[kyc.UserID], kyc.ID)
	return nil
}

func (r *InMemoryKYCRepo) GetLatestByUserID(ctx context.Context, userID uuid.UUID) (*domain.KYCVerification, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	ids, exists := r.byUser[userID]
	if !exists || len(ids) == 0 {
		return nil, errors.New("no kyc record found")
	}

	latestID := ids[len(ids)-1]
	copy := *r.records[latestID]
	return &copy, nil
}

func (r *InMemoryKYCRepo) UpdateStatus(ctx context.Context, id uuid.UUID, status domain.KYCStatus, score float64, liveness bool, reason string) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	rec, exists := r.records[id]
	if !exists {
		return errors.New("kyc record not found")
	}

	rec.Status = status
	rec.ConfidenceScore = score
	rec.LivenessConfirmed = liveness
	rec.RejectionReason = reason
	now := time.Now()
	rec.UpdatedAt = now
	if status == domain.KYCVerified {
		rec.VerifiedAt = &now
	}
	return nil
}

var _ ports.KYCRepository = (*InMemoryKYCRepo)(nil)

// ============================================================================
// IN-MEMORY JOB REPOSITORY (With Double Confirmation & Reminder Search)
// ============================================================================

type InMemoryJobRepo struct {
	mu          sync.RWMutex
	jobs        map[uuid.UUID]*domain.Job
	transitions []*domain.JobStatusTransition
}

func NewInMemoryJobRepo() *InMemoryJobRepo {
	return &InMemoryJobRepo{
		jobs:        make(map[uuid.UUID]*domain.Job),
		transitions: make([]*domain.JobStatusTransition, 0),
	}
}

func (r *InMemoryJobRepo) Create(ctx context.Context, job *domain.Job) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	copy := *job
	r.jobs[job.ID] = &copy
	return nil
}

func (r *InMemoryJobRepo) GetByID(ctx context.Context, id uuid.UUID) (*domain.Job, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	job, exists := r.jobs[id]
	if !exists {
		return nil, errors.New("trabajo no encontrado")
	}
	copy := *job
	return &copy, nil
}

func (r *InMemoryJobRepo) ListAvailable(ctx context.Context, category *domain.TradeCategory, limit, offset int) ([]*domain.Job, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	var result []*domain.Job
	for _, j := range r.jobs {
		if j.Status == domain.StatusPendienteDeAceptacion {
			if category == nil || j.Category == *category {
				copy := *j
				result = append(result, &copy)
			}
		}
	}

	sort.Slice(result, func(i, j int) bool {
		return result[i].CreatedAt.After(result[j].CreatedAt)
	})

	return result, nil
}

func (r *InMemoryJobRepo) ListByClientID(ctx context.Context, clientID uuid.UUID) ([]*domain.Job, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	var result []*domain.Job
	for _, j := range r.jobs {
		if j.ClientID == clientID {
			copy := *j
			result = append(result, &copy)
		}
	}

	sort.Slice(result, func(i, j int) bool {
		return result[i].ScheduledAt.Before(result[j].ScheduledAt)
	})

	return result, nil
}

func (r *InMemoryJobRepo) ListByTechnicianID(ctx context.Context, techID uuid.UUID) ([]*domain.Job, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	var result []*domain.Job
	for _, j := range r.jobs {
		if j.AssignedTechnicianID != nil && *j.AssignedTechnicianID == techID {
			copy := *j
			result = append(result, &copy)
		}
	}

	sort.Slice(result, func(i, j int) bool {
		return result[i].ScheduledAt.Before(result[j].ScheduledAt)
	})

	return result, nil
}

func (r *InMemoryJobRepo) AssignTechnician(ctx context.Context, jobID, technicianID uuid.UUID) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	job, exists := r.jobs[jobID]
	if !exists {
		return errors.New("trabajo no encontrado")
	}
	job.AssignedTechnicianID = &technicianID
	job.UpdatedAt = time.Now()
	return nil
}

func (r *InMemoryJobRepo) UpdateStatus(ctx context.Context, jobID uuid.UUID, status domain.JobStatus) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	job, exists := r.jobs[jobID]
	if !exists {
		return errors.New("trabajo no encontrado")
	}
	job.Status = status
	now := time.Now()
	job.UpdatedAt = now
	switch status {
	case domain.StatusFinalizado:
		job.CompletedAt = &now
	case domain.StatusCancelado:
		job.CancelledAt = &now
	}
	return nil
}

func (r *InMemoryJobRepo) UpdateConfirmationStatus(ctx context.Context, job *domain.Job) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	existing, exists := r.jobs[job.ID]
	if !exists {
		return errors.New("trabajo no encontrado")
	}
	*existing = *job
	return nil
}

func (r *InMemoryJobRepo) UpdateLocation(ctx context.Context, jobID uuid.UUID, address string, lat, lng float64) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	job, exists := r.jobs[jobID]
	if !exists {
		return errors.New("trabajo no encontrado")
	}
	job.FullAddress = &address
	job.LocationLatitude = &lat
	job.LocationLongitude = &lng
	job.UpdatedAt = time.Now()
	return nil
}

func (r *InMemoryJobRepo) RecordTransition(ctx context.Context, transition *domain.JobStatusTransition) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	copy := *transition
	r.transitions = append(r.transitions, &copy)
	return nil
}

func (r *InMemoryJobRepo) GetUpcomingJobsForReminder(ctx context.Context, windowStart, windowEnd time.Time, reminderType string) ([]*domain.Job, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	var results []*domain.Job
	for _, j := range r.jobs {
		if j.Status == domain.StatusAgendado {
			if (j.ScheduledAt.After(windowStart) || j.ScheduledAt.Equal(windowStart)) &&
				(j.ScheduledAt.Before(windowEnd) || j.ScheduledAt.Equal(windowEnd)) {
				if reminderType == "24h" && j.Reminder24hSentAt == nil {
					copy := *j
					results = append(results, &copy)
				} else if reminderType == "2h" && j.Reminder2hSentAt == nil {
					copy := *j
					results = append(results, &copy)
				}
			}
		}
	}
	return results, nil
}

func (r *InMemoryJobRepo) MarkReminderSent(ctx context.Context, jobID uuid.UUID, reminderType string) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	job, exists := r.jobs[jobID]
	if !exists {
		return errors.New("trabajo no encontrado")
	}
	now := time.Now()
	switch reminderType {
	case "24h":
		job.Reminder24hSentAt = &now
	case "2h":
		job.Reminder2hSentAt = &now
	}
	return nil
}

var _ ports.JobRepository = (*InMemoryJobRepo)(nil)

// ============================================================================
// IN-MEMORY PROPOSAL REPOSITORY
// ============================================================================

type InMemoryProposalRepo struct {
	mu        sync.RWMutex
	proposals map[uuid.UUID]*domain.Proposal
}

func NewInMemoryProposalRepo() *InMemoryProposalRepo {
	return &InMemoryProposalRepo{
		proposals: make(map[uuid.UUID]*domain.Proposal),
	}
}

func (r *InMemoryProposalRepo) Create(ctx context.Context, proposal *domain.Proposal) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	copy := *proposal
	r.proposals[proposal.ID] = &copy
	return nil
}

func (r *InMemoryProposalRepo) GetByID(ctx context.Context, id uuid.UUID) (*domain.Proposal, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	p, exists := r.proposals[id]
	if !exists {
		return nil, domain.ErrProposalNotFound
	}
	copy := *p
	return &copy, nil
}

func (r *InMemoryProposalRepo) GetByJobAndTechnician(ctx context.Context, jobID, technicianID uuid.UUID) (*domain.Proposal, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	for _, p := range r.proposals {
		if p.JobID == jobID && p.TechnicianID == technicianID {
			copy := *p
			return &copy, nil
		}
	}
	return nil, errors.New("not found")
}

func (r *InMemoryProposalRepo) ListByJobID(ctx context.Context, jobID uuid.UUID) ([]*domain.Proposal, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	var list []*domain.Proposal
	for _, p := range r.proposals {
		if p.JobID == jobID {
			copy := *p
			list = append(list, &copy)
		}
	}
	return list, nil
}

func (r *InMemoryProposalRepo) ListByTechnicianID(ctx context.Context, technicianID uuid.UUID) ([]*domain.Proposal, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	var list []*domain.Proposal
	for _, p := range r.proposals {
		if p.TechnicianID == technicianID {
			copy := *p
			list = append(list, &copy)
		}
	}
	return list, nil
}

func (r *InMemoryProposalRepo) UpdateStatus(ctx context.Context, id uuid.UUID, status domain.ProposalStatus) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	p, exists := r.proposals[id]
	if !exists {
		return domain.ErrProposalNotFound
	}
	p.Status = status
	p.UpdatedAt = time.Now()
	return nil
}

var _ ports.ProposalRepository = (*InMemoryProposalRepo)(nil)

// ============================================================================
// IN-MEMORY CHAT REPOSITORY
// ============================================================================

type InMemoryChatRepo struct {
	mu       sync.RWMutex
	messages map[uuid.UUID][]*domain.Message
}

func NewInMemoryChatRepo() *InMemoryChatRepo {
	return &InMemoryChatRepo{
		messages: make(map[uuid.UUID][]*domain.Message),
	}
}

func (r *InMemoryChatRepo) SaveMessage(ctx context.Context, msg *domain.Message) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	copy := *msg
	r.messages[msg.JobID] = append(r.messages[msg.JobID], &copy)
	return nil
}

func (r *InMemoryChatRepo) GetMessagesByJobID(ctx context.Context, jobID uuid.UUID, limit, offset int) ([]*domain.Message, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	list := r.messages[jobID]
	var res []*domain.Message
	for _, m := range list {
		copy := *m
		res = append(res, &copy)
	}
	return res, nil
}

func (r *InMemoryChatRepo) MarkMessagesAsRead(ctx context.Context, jobID, readerID uuid.UUID) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	for _, m := range r.messages[jobID] {
		if m.SenderID != readerID {
			m.IsRead = true
		}
	}
	return nil
}

var _ ports.ChatRepository = (*InMemoryChatRepo)(nil)

// ============================================================================
// IN-MEMORY REVIEW REPOSITORY
// ============================================================================

type InMemoryReviewRepo struct {
	mu      sync.RWMutex
	reviews map[uuid.UUID]*domain.Review
	byJob   map[uuid.UUID]uuid.UUID
}

func NewInMemoryReviewRepo() *InMemoryReviewRepo {
	return &InMemoryReviewRepo{
		reviews: make(map[uuid.UUID]*domain.Review),
		byJob:   make(map[uuid.UUID]uuid.UUID),
	}
}

func (r *InMemoryReviewRepo) Create(ctx context.Context, review *domain.Review) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	if _, exists := r.byJob[review.JobID]; exists {
		return domain.ErrReviewAlreadySubmitted
	}

	copy := *review
	r.reviews[review.ID] = &copy
	r.byJob[review.JobID] = review.ID
	return nil
}

func (r *InMemoryReviewRepo) GetByJobID(ctx context.Context, jobID uuid.UUID) (*domain.Review, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	revID, exists := r.byJob[jobID]
	if !exists {
		return nil, errors.New("review no encontrada")
	}
	copy := *r.reviews[revID]
	return &copy, nil
}

func (r *InMemoryReviewRepo) ListByTechnicianID(ctx context.Context, techID uuid.UUID, limit, offset int) ([]*domain.Review, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	var list []*domain.Review
	for _, rev := range r.reviews {
		if rev.TechnicianID == techID {
			copy := *rev
			list = append(list, &copy)
		}
	}
	return list, nil
}

var _ ports.ReviewRepository = (*InMemoryReviewRepo)(nil)
