package services_test

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/reparatutti/backend/internal/adapters/payment"
	"github.com/reparatutti/backend/internal/adapters/repository/postgres"
	"github.com/reparatutti/backend/internal/core/domain"
	"github.com/reparatutti/backend/internal/core/services"
)

func TestDoubleConfirmationWithPaymentAndWarranty(t *testing.T) {
	ctx := context.Background()

	userRepo := postgres.NewInMemoryUserRepo()
	jobRepo := postgres.NewInMemoryJobRepo()
	proposalRepo := postgres.NewInMemoryProposalRepo()
	paymentGateway := payment.NewMockMercadoPagoGateway()

	jobService := services.NewJobService(jobRepo, proposalRepo, userRepo, nil, paymentGateway)

	clientID := uuid.New()
	client := &domain.User{
		ID:        clientID,
		Email:     "lucia.cliente@test.com",
		Role:      domain.RoleClient,
		FullName:  "Lucía Cliente",
		IsActive:  true,
		KYCStatus: domain.KYCVerified,
	}
	_ = userRepo.Create(ctx, client)

	techID := uuid.New()
	trade := domain.TradePlomeria
	tech := &domain.User{
		ID:        techID,
		Email:     "carlos.tech@test.com",
		Role:      domain.RoleTechnician,
		FullName:  "Carlos Técnico",
		Trade:     &trade,
		IsActive:  true,
		KYCStatus: domain.KYCVerified,
	}
	_ = userRepo.Create(ctx, tech)

	estPrice := 28000.0
	job, err := jobService.CreateJob(ctx, clientID, domain.TradePlomeria, "Gotea la canilla", "Pérdida en grifo", "Palermo", time.Now().Add(24*time.Hour), []string{}, &estPrice)
	if err != nil {
		t.Fatalf("failed to create job: %v", err)
	}

	// Tech instant accept
	_, updatedJob, err := jobService.InstantAcceptJob(ctx, techID, job.ID)
	if err != nil {
		t.Fatalf("failed instant accept: %v", err)
	}
	if updatedJob.AssignedTechnicianID == nil || *updatedJob.AssignedTechnicianID != techID {
		t.Fatalf("technician not assigned correctly")
	}

	// Client confirms 'agendado' -> official transition to StatusAgendado
	jobAgendado, confAgendado, err := jobService.ConfirmJobStatusTransition(ctx, job.ID, clientID, domain.StatusAgendado)
	if err != nil {
		t.Fatalf("unexpected error confirming agendado: %v", err)
	}
	if !confAgendado.Transitioned || jobAgendado.Status != domain.StatusAgendado {
		t.Fatalf("job should have transitioned to 'agendado', got: %v", jobAgendado.Status)
	}

	// 1st step to finalize: Tech confirms finalizado
	_, confTechFin, err := jobService.ConfirmJobStatusTransition(ctx, job.ID, techID, domain.StatusFinalizado)
	if err != nil {
		t.Fatalf("unexpected error on tech confirm finalizado: %v", err)
	}
	if confTechFin.Transitioned {
		t.Errorf("job must not transition with only technician confirmation")
	}
	if confTechFin.PaymentTriggered {
		t.Errorf("payment should not be triggered before client confirmation")
	}

	// 2nd step to finalize: Client confirms finalizado (Double confirmation complete)
	jobFin, confClientFin, err := jobService.ConfirmJobStatusTransition(ctx, job.ID, clientID, domain.StatusFinalizado)
	if err != nil {
		t.Fatalf("unexpected error on client confirm finalizado: %v", err)
	}
	if !confClientFin.Transitioned {
		t.Errorf("job MUST officially transition when both parties confirm")
	}
	if jobFin.Status != domain.StatusFinalizado {
		t.Errorf("expected global status 'finalizado', got: %v", jobFin.Status)
	}

	// Payment Escrow released & 30-day warranty activated!
	if !confClientFin.PaymentTriggered {
		t.Errorf("payment escrow capture and release must be triggered")
	}
	if !confClientFin.WarrantyActive {
		t.Errorf("30-day warranty must be active")
	}
	if confClientFin.WarrantyCertificate == "" {
		t.Errorf("warranty certificate must not be empty")
	}
	if jobFin.PaymentReceipt == nil {
		t.Errorf("job must store payment receipt")
	}
}

func TestCatalogServiceSmartTriageInference(t *testing.T) {
	ctx := context.Background()
	catalogRepo := postgres.NewInMemoryCatalogPriceRepo()
	catalogService := services.NewCatalogService(catalogRepo)

	// Test 1: "Gotea la canilla"
	res1, err1 := catalogService.InferSmartTriage(ctx, "Gotea la canilla de la cocina")
	if err1 != nil {
		t.Fatalf("unexpected triage error: %v", err1)
	}
	if res1.SuggestedCategory != domain.TradePlomeria {
		t.Errorf("expected plomeria for 'Gotea la canilla', got %v", res1.SuggestedCategory)
	}
	if res1.EstimatedAverage != 28000.0 {
		t.Errorf("expected 28000 ARS for canilla, got %.2f", res1.EstimatedAverage)
	}

	// Test 2: "Destapar cañería"
	res2, err2 := catalogService.InferSmartTriage(ctx, "Necesito destapar la cañeria del patio")
	if err2 != nil {
		t.Fatalf("unexpected triage error: %v", err2)
	}
	if res2.SuggestedCategory != domain.TradePlomeria {
		t.Errorf("expected plomeria, got %v", res2.SuggestedCategory)
	}
	if res2.EstimatedAverage != 40000.0 {
		t.Errorf("expected 40000 ARS, got %.2f", res2.EstimatedAverage)
	}

	// Test 3: "Salta la térmica"
	res3, err3 := catalogService.InferSmartTriage(ctx, "Se corta la luz cuando prendo el horno, salta la termica")
	if err3 != nil {
		t.Fatalf("unexpected triage error: %v", err3)
	}
	if res3.SuggestedCategory != domain.TradeElectricidad {
		t.Errorf("expected electricidad, got %v", res3.SuggestedCategory)
	}
	if res3.EstimatedAverage != 32000.0 {
		t.Errorf("expected 32000 ARS, got %.2f", res3.EstimatedAverage)
	}
}
