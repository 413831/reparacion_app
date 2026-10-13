package ports

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/reparatutti/backend/internal/core/domain"
)

type UserRepository interface {
	Create(ctx context.Context, user *domain.User) error
	GetByID(ctx context.Context, id uuid.UUID) (*domain.User, error)
	GetByEmail(ctx context.Context, email string) (*domain.User, error)
	UpdateKYCStatus(ctx context.Context, id uuid.UUID, status domain.KYCStatus) error
	UpdateRating(ctx context.Context, id uuid.UUID, newRating float64, newCount int) error
	LogLegalConsent(ctx context.Context, userID uuid.UUID, action, ip, userAgent, version string) error
	SuspendAccount(ctx context.Context, id uuid.UUID) error
	DeleteAccount(ctx context.Context, id uuid.UUID) error
	GetNotificationConfig(ctx context.Context, userID uuid.UUID) (*domain.NotificationConfig, error)
	UpdateNotificationConfig(ctx context.Context, config *domain.NotificationConfig) error
}

type KYCRepository interface {
	Create(ctx context.Context, kyc *domain.KYCVerification) error
	GetLatestByUserID(ctx context.Context, userID uuid.UUID) (*domain.KYCVerification, error)
	UpdateStatus(ctx context.Context, id uuid.UUID, status domain.KYCStatus, score float64, liveness bool, reason string) error
}

type JobRepository interface {
	Create(ctx context.Context, job *domain.Job) error
	GetByID(ctx context.Context, id uuid.UUID) (*domain.Job, error)
	ListAvailable(ctx context.Context, category *domain.TradeCategory, limit, offset int) ([]*domain.Job, error)
	ListByClientID(ctx context.Context, clientID uuid.UUID) ([]*domain.Job, error)
	ListByTechnicianID(ctx context.Context, techID uuid.UUID) ([]*domain.Job, error)
	AssignTechnician(ctx context.Context, jobID, technicianID uuid.UUID) error
	UpdateStatus(ctx context.Context, jobID uuid.UUID, status domain.JobStatus) error
	UpdateConfirmationStatus(ctx context.Context, job *domain.Job) error
	UpdateLocation(ctx context.Context, jobID uuid.UUID, address string, lat, lng float64) error
	RecordTransition(ctx context.Context, transition *domain.JobStatusTransition) error
	GetUpcomingJobsForReminder(ctx context.Context, windowStart, windowEnd time.Time, reminderType string) ([]*domain.Job, error)
	MarkReminderSent(ctx context.Context, jobID uuid.UUID, reminderType string) error
}

type ProposalRepository interface {
	Create(ctx context.Context, proposal *domain.Proposal) error
	GetByID(ctx context.Context, id uuid.UUID) (*domain.Proposal, error)
	GetByJobAndTechnician(ctx context.Context, jobID, technicianID uuid.UUID) (*domain.Proposal, error)
	ListByJobID(ctx context.Context, jobID uuid.UUID) ([]*domain.Proposal, error)
	ListByTechnicianID(ctx context.Context, technicianID uuid.UUID) ([]*domain.Proposal, error)
	UpdateStatus(ctx context.Context, id uuid.UUID, status domain.ProposalStatus) error
}

type ChatRepository interface {
	SaveMessage(ctx context.Context, msg *domain.Message) error
	GetMessagesByJobID(ctx context.Context, jobID uuid.UUID, limit, offset int) ([]*domain.Message, error)
	MarkMessagesAsRead(ctx context.Context, jobID, readerID uuid.UUID) error
}

type ReviewRepository interface {
	Create(ctx context.Context, review *domain.Review) error
	GetByJobID(ctx context.Context, jobID uuid.UUID) (*domain.Review, error)
	ListByTechnicianID(ctx context.Context, techID uuid.UUID, limit, offset int) ([]*domain.Review, error)
}

type CatalogPriceRepository interface {
	Create(ctx context.Context, price *domain.CatalogPrice) error
	ListActive(ctx context.Context) ([]*domain.CatalogPrice, error)
	GetByCategory(ctx context.Context, category domain.TradeCategory) ([]*domain.CatalogPrice, error)
	GetByID(ctx context.Context, id uuid.UUID) (*domain.CatalogPrice, error)
}

