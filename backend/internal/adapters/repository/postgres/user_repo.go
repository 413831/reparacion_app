package postgres

import (
	"context"
	"database/sql"
	"errors"
	"sync"
	"time"

	"github.com/google/uuid"
	"github.com/reparatutti/backend/internal/core/domain"
	"github.com/reparatutti/backend/internal/core/ports"
)

type InMemoryUserRepo struct {
	mu           sync.RWMutex
	users        map[uuid.UUID]*domain.User
	byEmail      map[string]uuid.UUID
	notifConfigs map[uuid.UUID]*domain.NotificationConfig
}

func NewInMemoryUserRepo() *InMemoryUserRepo {
	return &InMemoryUserRepo{
		users:        make(map[uuid.UUID]*domain.User),
		byEmail:      make(map[string]uuid.UUID),
		notifConfigs: make(map[uuid.UUID]*domain.NotificationConfig),
	}
}

func (r *InMemoryUserRepo) Create(ctx context.Context, user *domain.User) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	if _, exists := r.byEmail[user.Email]; exists {
		return errors.New("user with this email already exists")
	}

	copy := *user
	r.users[user.ID] = &copy
	r.byEmail[user.Email] = user.ID
	r.notifConfigs[user.ID] = &domain.NotificationConfig{
		UserID:              user.ID,
		PushEnabled:         true,
		EmailEnabled:        true,
		SMSEnabled:          false,
		Reminders24hEnabled: true,
		Reminders2hEnabled:  true,
		UpdatedAt:           time.Now(),
	}
	return nil
}

func (r *InMemoryUserRepo) GetByID(ctx context.Context, id uuid.UUID) (*domain.User, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	user, exists := r.users[id]
	if !exists {
		return nil, errors.New("user not found")
	}
	copy := *user
	return &copy, nil
}

func (r *InMemoryUserRepo) GetByEmail(ctx context.Context, email string) (*domain.User, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	id, exists := r.byEmail[email]
	if !exists {
		return nil, errors.New("user not found")
	}
	copy := *r.users[id]
	return &copy, nil
}

func (r *InMemoryUserRepo) UpdateKYCStatus(ctx context.Context, id uuid.UUID, status domain.KYCStatus) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	user, exists := r.users[id]
	if !exists {
		return errors.New("user not found")
	}
	user.KYCStatus = status
	return nil
}

func (r *InMemoryUserRepo) UpdateRating(ctx context.Context, id uuid.UUID, newRating float64, newCount int) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	user, exists := r.users[id]
	if !exists {
		return errors.New("user not found")
	}
	user.RatingAverage = newRating
	user.ReviewsCount = newCount
	return nil
}

func (r *InMemoryUserRepo) LogLegalConsent(ctx context.Context, userID uuid.UUID, action, ip, userAgent, version string) error {
	return nil
}

func (r *InMemoryUserRepo) SuspendAccount(ctx context.Context, id uuid.UUID) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	user, exists := r.users[id]
	if !exists {
		return errors.New("user not found")
	}
	user.AccountStatus = domain.AccountStatusSuspended
	user.IsActive = false
	user.UpdatedAt = time.Now()
	return nil
}

func (r *InMemoryUserRepo) DeleteAccount(ctx context.Context, id uuid.UUID) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	user, exists := r.users[id]
	if !exists {
		return errors.New("user not found")
	}
	now := time.Now()
	user.AccountStatus = domain.AccountStatusDeleted
	user.IsActive = false
	user.DeletedAt = &now
	user.UpdatedAt = now
	return nil
}

func (r *InMemoryUserRepo) GetNotificationConfig(ctx context.Context, userID uuid.UUID) (*domain.NotificationConfig, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	cfg, exists := r.notifConfigs[userID]
	if !exists {
		return &domain.NotificationConfig{
			UserID:              userID,
			PushEnabled:         true,
			EmailEnabled:        true,
			SMSEnabled:          false,
			Reminders24hEnabled: true,
			Reminders2hEnabled:  true,
			UpdatedAt:           time.Now(),
		}, nil
	}
	copy := *cfg
	return &copy, nil
}

func (r *InMemoryUserRepo) UpdateNotificationConfig(ctx context.Context, config *domain.NotificationConfig) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	copy := *config
	copy.UpdatedAt = time.Now()
	r.notifConfigs[config.UserID] = &copy
	return nil
}

var _ ports.UserRepository = (*InMemoryUserRepo)(nil)

type PostgresUserRepo struct {
	db *sql.DB
}

func NewPostgresUserRepo(db *sql.DB) *PostgresUserRepo {
	return &PostgresUserRepo{db: db}
}
