package domain_test

import (
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/reparatutti/backend/internal/core/domain"
)

func TestDoubleConfirmationStateMachine(t *testing.T) {
	clientID := uuid.New()
	techID := uuid.New()
	intruderID := uuid.New()

	job := &domain.Job{
		ID:                   uuid.New(),
		ClientID:             clientID,
		AssignedTechnicianID: &techID,
		Category:             domain.TradeElectricidad,
		Title:                "Cambio de térmica",
		Status:               domain.StatusPendienteDeAceptacion,
		ScheduledAt:          time.Now().Add(48 * time.Hour),
		CreatedAt:            time.Now(),
	}

	// 1. Intruder attempt must fail
	_, err := job.ConfirmStatus(intruderID, domain.StatusAgendado)
	if err != domain.ErrJobUnauthorizedAccess {
		t.Fatalf("expected ErrJobUnauthorizedAccess for intruder, got: %v", err)
	}

	// 2. Client confirms 'agendado'
	trans1, err1 := job.ConfirmStatus(clientID, domain.StatusAgendado)
	if err1 != nil {
		t.Fatalf("unexpected error on client confirmation: %v", err1)
	}
	if trans1 {
		t.Errorf("job should NOT have transitioned with only client confirmation")
	}
	if job.Status != domain.StatusPendienteDeAceptacion {
		t.Errorf("global status must remain pendiente_de_aceptacion, got %v", job.Status)
	}
	if job.ClientConfirmedStatus == nil || *job.ClientConfirmedStatus != domain.StatusAgendado {
		t.Errorf("client confirmation flag not set correctly")
	}
	if job.TechConfirmedStatus != nil {
		t.Errorf("tech confirmation flag should still be nil")
	}

	// 3. Technician confirms 'agendado' -> Official transition triggers!
	trans2, err2 := job.ConfirmStatus(techID, domain.StatusAgendado)
	if err2 != nil {
		t.Fatalf("unexpected error on tech confirmation: %v", err2)
	}
	if !trans2 {
		t.Errorf("job MUST officially transition when both parties confirm the same status")
	}
	if job.Status != domain.StatusAgendado {
		t.Errorf("expected global status 'agendado', got %v", job.Status)
	}

	// 4. Test completion flow: Both confirm 'finalizado'
	trans3, _ := job.ConfirmStatus(techID, domain.StatusFinalizado)
	if trans3 {
		t.Errorf("job should not be finalized when only tech confirms")
	}
	trans4, _ := job.ConfirmStatus(clientID, domain.StatusFinalizado)
	if !trans4 {
		t.Errorf("job MUST transition to finalizado when client confirms too")
	}
	if job.Status != domain.StatusFinalizado {
		t.Errorf("expected global status 'finalizado', got %v", job.Status)
	}
	if job.CompletedAt == nil {
		t.Errorf("completed_at timestamp should be recorded")
	}
}
