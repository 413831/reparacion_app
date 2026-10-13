package payment

import (
	"context"
	"fmt"
	"sync"
	"time"

	"github.com/google/uuid"
	"github.com/reparatutti/backend/internal/core/domain"
	"github.com/reparatutti/backend/internal/core/ports"
)

type MockMercadoPagoGateway struct {
	mu       sync.RWMutex
	receipts map[uuid.UUID]*domain.PaymentGuaranteeReceipt
}

func NewMockMercadoPagoGateway() *MockMercadoPagoGateway {
	return &MockMercadoPagoGateway{
		receipts: make(map[uuid.UUID]*domain.PaymentGuaranteeReceipt),
	}
}

func (m *MockMercadoPagoGateway) CaptureEscrow(ctx context.Context, jobID, clientID, technicianID uuid.UUID, amount float64, paymentMethod string) (*domain.PaymentGuaranteeReceipt, error) {
	m.mu.Lock()
	defer m.mu.Unlock()

	receipt := &domain.PaymentGuaranteeReceipt{
		ReceiptID:           uuid.New(),
		JobID:               jobID,
		ClientID:            clientID,
		TechnicianID:        technicianID,
		Amount:              amount,
		Currency:            "ARS",
		PaymentMethod:       paymentMethod,
		EscrowStatus:        domain.EscrowStatusHeld,
		WarrantyStatus:      domain.WarrantyStatusPending,
		WarrantyCertificate: fmt.Sprintf("MP-ESCROW-%s", uuid.New().String()[:8]),
		ReleasedAt:          time.Now(),
	}

	m.receipts[jobID] = receipt
	return receipt, nil
}

func (m *MockMercadoPagoGateway) ReleaseEscrowAndWarranty(ctx context.Context, jobID uuid.UUID) (*domain.PaymentGuaranteeReceipt, error) {
	m.mu.Lock()
	defer m.mu.Unlock()

	receipt, exists := m.receipts[jobID]
	now := time.Now()
	expiresAt := now.Add(30 * 24 * time.Hour) // 30-Day Reparatutti Guarantee

	if !exists {
		// Auto-generate if not previously captured in escrow
		receipt = &domain.PaymentGuaranteeReceipt{
			ReceiptID:     uuid.New(),
			JobID:         jobID,
			Amount:        28000.0,
			Currency:      "ARS",
			PaymentMethod: "mercadopago_escrow_auto",
		}
		m.receipts[jobID] = receipt
	}

	receipt.EscrowStatus = domain.EscrowStatusReleased
	receipt.WarrantyStatus = domain.WarrantyStatusActive30D
	receipt.WarrantyCertificate = fmt.Sprintf("GARANTIA-REPARATUTTI-30D-%s", receipt.ReceiptID.String()[:8])
	receipt.WarrantyExpiresAt = &expiresAt
	receipt.ReleasedAt = now

	return receipt, nil
}

var _ ports.PaymentGateway = (*MockMercadoPagoGateway)(nil)
