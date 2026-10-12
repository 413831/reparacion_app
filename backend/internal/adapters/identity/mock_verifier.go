package identity

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/reparatutti/backend/internal/core/domain"
	"github.com/reparatutti/backend/internal/core/ports"
)

// MockIdentityVerifier simulates an identity verification provider (e.g., Renaper / Didit / AWS Rekognition)
type MockIdentityVerifier struct {
	providerName string
}

func NewMockIdentityVerifier() *MockIdentityVerifier {
	return &MockIdentityVerifier{
		providerName: "mock_renaper_biometrics",
	}
}

func (m *MockIdentityVerifier) VerifyTechnician(ctx context.Context, sub *domain.VerificationSubmission) (*ports.VerificationResult, error) {
	// Simulate lightweight network latency to remote identity provider
	select {
	case <-time.After(200 * time.Millisecond):
	case <-ctx.Done():
		return nil, ctx.Err()
	}

	// Deterministic rejection simulation for QA/testing
	if sub.DocumentNumber == "00000000" {
		return &ports.VerificationResult{
			Provider:          m.providerName,
			IsVerified:        false,
			ConfidenceScore:   42.0,
			LivenessConfirmed: false,
			ExternalRefID:     fmt.Sprintf("REJ-%s", uuid.New().String()[:8]),
			RejectionReason:   "DNI no coincide con el padrón electoral o biometría facial insuficiente",
			RawMetadata: map[string]interface{}{
				"facial_match": 42.0,
				"dni_status":   "unmatched",
			},
		}, nil
	}

	return &ports.VerificationResult{
		Provider:          m.providerName,
		IsVerified:        true,
		ConfidenceScore:   98.7,
		LivenessConfirmed: true,
		ExternalRefID:     fmt.Sprintf("RENAPER-%s", uuid.New().String()[:8]),
		RawMetadata: map[string]interface{}{
			"facial_match_percentage": 98.7,
			"liveness_test":           "passed",
			"renaper_validation":      "valid_argentine_id",
			"document_type":           "DNI Tarjeta",
		},
	}, nil
}

func (m *MockIdentityVerifier) VerifyClient(ctx context.Context, sub *domain.VerificationSubmission) (*ports.VerificationResult, error) {
	select {
	case <-time.After(150 * time.Millisecond):
	case <-ctx.Done():
		return nil, ctx.Err()
	}

	return &ports.VerificationResult{
		Provider:          m.providerName,
		IsVerified:        true,
		ConfidenceScore:   99.1,
		LivenessConfirmed: true,
		ExternalRefID:     fmt.Sprintf("CLIENT-BIO-%s", uuid.New().String()[:8]),
		RawMetadata: map[string]interface{}{
			"facial_biometrics_score": 99.1,
			"liveness_check":          "passed",
		},
	}, nil
}
