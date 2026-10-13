package domain

import (
	"time"

	"github.com/google/uuid"
)

type PaymentEscrowStatus string

const (
	EscrowStatusNone     PaymentEscrowStatus = "none"
	EscrowStatusHeld     PaymentEscrowStatus = "held_in_escrow"
	EscrowStatusReleased PaymentEscrowStatus = "released_to_technician"
	EscrowStatusRefunded PaymentEscrowStatus = "refunded_to_client"
)

type WarrantyStatus string

const (
	WarrantyStatusPending   WarrantyStatus = "pending_completion"
	WarrantyStatusActive30D WarrantyStatus = "active_30_days"
	WarrantyStatusClaimed   WarrantyStatus = "claimed"
	WarrantyStatusExpired   WarrantyStatus = "expired"
)

type PaymentGuaranteeReceipt struct {
	ReceiptID           uuid.UUID           `json:"receipt_id"`
	JobID               uuid.UUID           `json:"job_id"`
	ClientID            uuid.UUID           `json:"client_id"`
	TechnicianID        uuid.UUID           `json:"technician_id"`
	Amount              float64             `json:"amount"`
	Currency            string              `json:"currency"`
	PaymentMethod       string              `json:"payment_method"` // 'mercadopago_wallet', 'credit_card', 'debit_card'
	EscrowStatus        PaymentEscrowStatus `json:"escrow_status"`
	WarrantyStatus      WarrantyStatus      `json:"warranty_status"`
	WarrantyCertificate string              `json:"warranty_certificate"`
	WarrantyExpiresAt   *time.Time          `json:"warranty_expires_at,omitempty"`
	ReleasedAt          time.Time           `json:"released_at"`
}
