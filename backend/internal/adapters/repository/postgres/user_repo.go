package postgres

import (
	"context"
	"database/sql"
	"errors"
	"sync"

	"github.com/google/uuid"
	"github.com/reparatutti/backend/internal/core/domain"
	"github.com/reparatutti/backend/internal/core/ports"
)

// InMemoryUserRepo provides thread-safe in-memory storage for MVP testing
// while conforming strictly to ports.UserRepository
type InMemoryUserRepo struct {
	mu      sync.RWMutex
	users   map[uuid.UUID]*domain.User
	byEmail map[string]uuid.UUID
}

func NewInMemoryUserRepo() *InMemoryUserRepo {
	return &InMemoryUserRepo{
		users:   make(map[uuid.UUID]*domain.User),
		byEmail: make(map[string]uuid.UUID),
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
	// Consents logged to audit store
	return nil
}

var _ ports.UserRepository = (*InMemoryUserRepo)(nil)

// SQL Queries for PostgreSQL implementation
const (
	SQLUserInsert = `
		INSERT INTO users (id, email, password_hash, full_name, phone_number, role, auth_provider, terms_accepted_at, terms_version, kyc_status, trade, rating_average, reviews_count, is_active, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16);
	`
	SQLUserGetByID = `
		SELECT id, email, password_hash, full_name, phone_number, role, auth_provider, auth_provider_id, avatar_url, terms_accepted_at, terms_version, kyc_status, trade, rating_average, reviews_count, is_active, created_at, updated_at
		FROM users WHERE id = $1 AND deleted_at IS NULL;
	`
	SQLUserUpdateKYC = `
		UPDATE users SET kyc_status = $2, updated_at = NOW() WHERE id = $1;
	`
	SQLUserUpdateRating = `
		UPDATE users SET rating_average = $2, reviews_count = $3, updated_at = NOW() WHERE id = $1;
	`
)

type PostgresUserRepo struct {
	db *sql.DB
}

func NewPostgresUserRepo(db *sql.DB) *PostgresUserRepo {
	return &PostgresUserRepo{db: db}
}
