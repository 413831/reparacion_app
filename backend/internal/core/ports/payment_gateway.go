package ports

import (
	"context"

	"github.com/google/uuid"
	"github.com/reparatutti/backend/internal/core/domain"
)

type PaymentGateway interface {
	CaptureEscrow(ctx context.Context, jobID, clientID, technicianID uuid.UUID, amount float64, paymentMethod string) (*domain.PaymentGuaranteeReceipt, error)
	ReleaseEscrowAndWarranty(ctx context.Context, jobID uuid.UUID) (*domain.PaymentGuaranteeReceipt, error)
}
