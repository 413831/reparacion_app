package seed

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/reparatutti/backend/internal/core/domain"
	"github.com/reparatutti/backend/internal/core/ports"
)

const (
	TechReviewerEmail   = "tech-reviewer@reparatutti.com"
	ClientReviewerEmail = "client-reviewer@reparatutti.com"
	DefaultReviewerPass = "Reviewer2026!"
)

// SeedReviewerAccounts injects dedicated test accounts for Apple App Store and Google Play Store review teams.
// The technician is pre-verified with KYC Approved status to eliminate any onboarding friction during app review.
func SeedReviewerAccounts(ctx context.Context, userRepo ports.UserRepository, jobRepo ports.JobRepository) error {
	now := time.Now()

	// 1. Verified Technician Reviewer Account
	techID := uuid.MustParse("77777777-7777-7777-7777-777777777777")
	trade := domain.TradePlomeria
	tech := &domain.User{
		ID:              techID,
		Email:           TechReviewerEmail,
		FullName:        "Técnico Evaluador App Store",
		PhoneNumber:     "+5491100000001",
		Role:            domain.RoleTechnician,
		AccountStatus:   domain.AccountStatusActive,
		AuthProvider:    "local",
		TermsAcceptedAt: now,
		TermsVersion:    domain.DefaultTermsPlaceholder,
		KYCStatus:       domain.KYCVerified, // Frictionless KYC Verification for Reviewers
		Trade:           &trade,
		RatingAverage:   5.00,
		ReviewsCount:    12,
		IsActive:        true,
		CreatedAt:       now,
		UpdatedAt:       now,
	}
	if err := tech.SetPassword(DefaultReviewerPass); err != nil {
		return fmt.Errorf("failed to hash password for tech reviewer: %w", err)
	}

	// Only insert if not already present
	if existing, _ := userRepo.GetByEmail(ctx, TechReviewerEmail); existing == nil {
		if err := userRepo.Create(ctx, tech); err != nil {
			return fmt.Errorf("failed to create tech reviewer: %w", err)
		}
	}

	// 2. Client Reviewer Account
	clientID := uuid.MustParse("88888888-8888-8888-8888-888888888888")
	client := &domain.User{
		ID:              clientID,
		Email:           ClientReviewerEmail,
		FullName:        "Cliente Evaluador App Store",
		PhoneNumber:     "+5491100000002",
		Role:            domain.RoleClient,
		AccountStatus:   domain.AccountStatusActive,
		AuthProvider:    "local",
		TermsAcceptedAt: now,
		TermsVersion:    domain.DefaultTermsPlaceholder,
		KYCStatus:       domain.KYCVerified,
		RatingAverage:   5.00,
		ReviewsCount:    4,
		IsActive:        true,
		CreatedAt:       now,
		UpdatedAt:       now,
	}
	if err := client.SetPassword(DefaultReviewerPass); err != nil {
		return fmt.Errorf("failed to hash password for client reviewer: %w", err)
	}

	if existing, _ := userRepo.GetByEmail(ctx, ClientReviewerEmail); existing == nil {
		if err := userRepo.Create(ctx, client); err != nil {
			return fmt.Errorf("failed to create client reviewer: %w", err)
		}
	}

	// 3. Reviewer Job 1: Ready for instant application/acceptance
	job1ID := uuid.MustParse("99999999-9999-9999-9999-999999999991")
	price1 := 28000.0
	job1 := &domain.Job{
		ID:              job1ID,
		ClientID:        clientID,
		Category:        domain.TradePlomeria,
		Title:           "[Demo Reviewer] Pérdida en canilla monocomando de baño",
		Description:     "Pérdida continua de agua bajo la mesada. Trabajo de muestra con precio sugerido para probar la conversión instantánea o envío de presupuesto.",
		GeneralLocality: "Recoleta, CABA",
		PhotosURLs:      []string{"https://images.unsplash.com/photo-1584622650111-993a426fbf0a"},
		ScheduledAt:     now.Add(24 * time.Hour),
		EstimatedPrice:  &price1,
		Status:          domain.StatusPendienteDeAceptacion,
		CreatedAt:       now.Add(-1 * time.Hour),
		UpdatedAt:       now.Add(-1 * time.Hour),
	}
	if existing, _ := jobRepo.GetByID(ctx, job1ID); existing == nil {
		_ = jobRepo.Create(ctx, job1)
	}

	// 4. Reviewer Job 2: Ready for Double-Confirmation State Machine & Escrow/Warranty testing
	job2ID := uuid.MustParse("99999999-9999-9999-9999-999999999992")
	price2 := 35000.0
	agendadoStatus := domain.StatusAgendado
	job2 := &domain.Job{
		ID:                    job2ID,
		ClientID:              clientID,
		AssignedTechnicianID:  &techID,
		Category:              domain.TradePlomeria,
		Title:                 "[Demo Reviewer] Instalación y prueba de grifería completa",
		Description:           "Trabajo en curso para que el evaluador pruebe el cambio de estados, la doble confirmación de cierre y la liberación de garantía.",
		GeneralLocality:       "Palermo, CABA",
		PhotosURLs:            []string{"https://images.unsplash.com/photo-1621905251189-08b45d6a269e"},
		ScheduledAt:           now.Add(4 * time.Hour),
		EstimatedPrice:        &price2,
		Status:                domain.StatusAgendado,
		ClientConfirmedStatus: &agendadoStatus,
		TechConfirmedStatus:   &agendadoStatus,
		ClientConfirmedAt:     &now,
		TechConfirmedAt:       &now,
		CreatedAt:             now.Add(-3 * time.Hour),
		UpdatedAt:             now,
	}
	if existing, _ := jobRepo.GetByID(ctx, job2ID); existing == nil {
		_ = jobRepo.Create(ctx, job2)
	}

	fmt.Println(">> [Store Reviewer Seeds] Successfully injected test credentials:")
	fmt.Printf("   • Technician Reviewer: %s / %s (KYC: VERIFIED)\n", TechReviewerEmail, DefaultReviewerPass)
	fmt.Printf("   • Client Reviewer:     %s / %s\n", ClientReviewerEmail, DefaultReviewerPass)
	fmt.Printf("   • Interactive Jobs:    Job 1 (%s), Job 2 (%s)\n", job1ID, job2ID)

	return nil
}
