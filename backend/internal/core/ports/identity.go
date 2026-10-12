package ports

import (
	"context"

	"github.com/reparatutti/backend/internal/core/domain"
)

type VerificationResult struct {
	Provider          string
	IsVerified        bool
	ConfidenceScore   float64
	LivenessConfirmed bool
	ExternalRefID     string
	RejectionReason   string
	RawMetadata       map[string]interface{}
}

// IdentityVerifier is the decoupled port for KYC verification providers
// (e.g., Renaper, Didit, AWS Rekognition, or MVP Mock).
type IdentityVerifier interface {
	VerifyTechnician(ctx context.Context, sub *domain.VerificationSubmission) (*VerificationResult, error)
	VerifyClient(ctx context.Context, sub *domain.VerificationSubmission) (*VerificationResult, error)
}
