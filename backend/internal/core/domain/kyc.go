package domain

import (
	"errors"
	"time"

	"github.com/google/uuid"
)

type KYCStatus string

const (
	KYCUnverified KYCStatus = "unverified"
	KYCPending    KYCStatus = "pending"
	KYCVerified   KYCStatus = "verified"
	KYCRejected   KYCStatus = "rejected"
)

type DocumentType string

const (
	DocDNIFront       DocumentType = "dni_front"
	DocDNIBack        DocumentType = "dni_back"
	DocSelfieLiveness DocumentType = "selfie_liveness"
)

type KYCVerification struct {
	ID                  uuid.UUID              `json:"id"`
	UserID              uuid.UUID              `json:"user_id"`
	Provider            string                 `json:"provider"` // renaper, didit, aws_rekognition, mock
	Status              KYCStatus              `json:"status"`
	DNIFrontURL         string                 `json:"dni_front_url,omitempty"`
	DNIBackURL          string                 `json:"dni_back_url,omitempty"`
	SelfieURL           string                 `json:"selfie_url"`
	ConfidenceScore     float64                `json:"confidence_score"`
	LivenessConfirmed   bool                   `json:"liveness_confirmed"`
	ExternalReferenceID string                 `json:"external_reference_id,omitempty"`
	RejectionReason     string                 `json:"rejection_reason,omitempty"`
	Metadata            map[string]interface{} `json:"metadata,omitempty"`
	VerifiedAt          *time.Time             `json:"verified_at,omitempty"`
	CreatedAt           time.Time              `json:"created_at"`
	UpdatedAt           time.Time              `json:"updated_at"`
}

type VerificationSubmission struct {
	UserID       uuid.UUID
	UserRole     UserRole
	DNIFrontB64  string
	DNIBackB64   string
	SelfieB64    string
	DocumentNumber string
}

var (
	ErrKYCIncompleteTechnicianDocs = errors.New("technician verification requires DNI front, DNI back, and facial selfie")
	ErrKYCIncompleteClientDocs     = errors.New("client verification requires a selfie with facial biometrics")
	ErrKYCAlreadyVerified          = errors.New("user is already KYC verified")
	ErrKYCPendingReview            = errors.New("user KYC verification is currently pending evaluation")
)

func (s *VerificationSubmission) Validate() error {
	if s.SelfieB64 == "" {
		return ErrKYCIncompleteClientDocs
	}
	if s.UserRole == RoleTechnician {
		if s.DNIFrontB64 == "" || s.DNIBackB64 == "" {
			return ErrKYCIncompleteTechnicianDocs
		}
	}
	return nil
}
