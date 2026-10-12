package services

import (
	"context"
	"fmt"
	"log"
	"time"

	"github.com/google/uuid"
	"github.com/reparatutti/backend/internal/core/domain"
	"github.com/reparatutti/backend/internal/core/ports"
)

type KYCService struct {
	userRepo ports.UserRepository
	kycRepo  ports.KYCRepository
	verifier ports.IdentityVerifier
}

func NewKYCService(
	userRepo ports.UserRepository,
	kycRepo ports.KYCRepository,
	verifier ports.IdentityVerifier,
) *KYCService {
	return &KYCService{
		userRepo: userRepo,
		kycRepo:  kycRepo,
		verifier: verifier,
	}
}

// SubmitVerification initiates an asynchronous identity verification workflow
func (s *KYCService) SubmitVerification(ctx context.Context, sub *domain.VerificationSubmission) (*domain.KYCVerification, error) {
	if err := sub.Validate(); err != nil {
		return nil, err
	}

	user, err := s.userRepo.GetByID(ctx, sub.UserID)
	if err != nil {
		return nil, fmt.Errorf("user not found: %w", err)
	}

	if user.KYCStatus == domain.KYCVerified {
		return nil, domain.ErrKYCAlreadyVerified
	}

	kycRecord := &domain.KYCVerification{
		ID:          uuid.New(),
		UserID:      user.ID,
		Provider:    "renaper_mock",
		Status:      domain.KYCPending,
		DNIFrontURL: sub.DNIFrontB64,
		DNIBackURL:  sub.DNIBackB64,
		SelfieURL:   sub.SelfieB64,
		CreatedAt:   time.Now(),
		UpdatedAt:   time.Now(),
	}

	if err := s.kycRepo.Create(ctx, kycRecord); err != nil {
		return nil, fmt.Errorf("failed to persist kyc record: %w", err)
	}

	// Update user status to pending
	if err := s.userRepo.UpdateKYCStatus(ctx, user.ID, domain.KYCPending); err != nil {
		return nil, fmt.Errorf("failed to update user status to pending: %w", err)
	}

	// Launch async verification process simulating third-party KYC worker / webhook callback
	go s.processVerificationAsync(kycRecord.ID, sub)

	return kycRecord, nil
}

func (s *KYCService) processVerificationAsync(kycID uuid.UUID, sub *domain.VerificationSubmission) {
	// Use detached background context for async background worker
	bgCtx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
	defer cancel()

	var result *ports.VerificationResult
	var err error

	if sub.UserRole == domain.RoleTechnician {
		result, err = s.verifier.VerifyTechnician(bgCtx, sub)
	} else {
		result, err = s.verifier.VerifyClient(bgCtx, sub)
	}

	if err != nil {
		log.Printf("[KYC Worker] verification error for user %s: %v", sub.UserID, err)
		_ = s.kycRepo.UpdateStatus(bgCtx, kycID, domain.KYCRejected, 0, false, "Internal verification provider timeout")
		_ = s.userRepo.UpdateKYCStatus(bgCtx, sub.UserID, domain.KYCRejected)
		return
	}

	targetStatus := domain.KYCVerified
	if !result.IsVerified {
		targetStatus = domain.KYCRejected
	}

	// Persist KYC verification outcome
	if err := s.kycRepo.UpdateStatus(bgCtx, kycID, targetStatus, result.ConfidenceScore, result.LivenessConfirmed, result.RejectionReason); err != nil {
		log.Printf("[KYC Worker] failed to update kyc status in db: %v", err)
	}

	// Update user master status
	if err := s.userRepo.UpdateKYCStatus(bgCtx, sub.UserID, targetStatus); err != nil {
		log.Printf("[KYC Worker] failed to update user kyc status: %v", err)
	}

	log.Printf("[KYC Worker] Successfully processed verification for user %s. Status: %s (Score: %.2f)",
		sub.UserID, targetStatus, result.ConfidenceScore)
}

func (s *KYCService) GetStatus(ctx context.Context, userID uuid.UUID) (*domain.KYCVerification, error) {
	return s.kycRepo.GetLatestByUserID(ctx, userID)
}
