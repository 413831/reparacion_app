package services

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/reparatutti/backend/internal/core/domain"
	"github.com/reparatutti/backend/internal/core/ports"
)

type JobService struct {
	jobRepo        ports.JobRepository
	proposalRepo   ports.ProposalRepository
	userRepo       ports.UserRepository
	notifier       ports.ReminderNotifier
	paymentGateway ports.PaymentGateway
}

func NewJobService(
	jobRepo ports.JobRepository,
	proposalRepo ports.ProposalRepository,
	userRepo ports.UserRepository,
	notifier ports.ReminderNotifier,
	paymentGateway ports.PaymentGateway,
) *JobService {
	return &JobService{
		jobRepo:        jobRepo,
		proposalRepo:   proposalRepo,
		userRepo:       userRepo,
		notifier:       notifier,
		paymentGateway: paymentGateway,
	}
}

// CreateJob creates a service request by a client, including optional estimated benchmark price
func (s *JobService) CreateJob(ctx context.Context, clientID uuid.UUID, category domain.TradeCategory, title, description, locality string, scheduledAt time.Time, photos []string, estimatedPrice *float64) (*domain.Job, error) {
	client, err := s.userRepo.GetByID(ctx, clientID)
	if err != nil {
		return nil, fmt.Errorf("cliente no encontrado: %w", err)
	}
	if client.Role != domain.RoleClient {
		return nil, errors.New("solo los clientes pueden publicar solicitudes de servicio")
	}

	job := &domain.Job{
		ID:              uuid.New(),
		ClientID:        clientID,
		Category:        category,
		Title:           title,
		Description:     description,
		PhotosURLs:      photos,
		ScheduledAt:     scheduledAt,
		GeneralLocality: locality,
		EstimatedPrice:  estimatedPrice,
		Status:          domain.StatusPendienteDeAceptacion,
		CreatedAt:       time.Now(),
		UpdatedAt:       time.Now(),
	}

	if err := s.jobRepo.Create(ctx, job); err != nil {
		return nil, fmt.Errorf("error al guardar el trabajo: %w", err)
	}

	return job, nil
}

// ApplyForJob validates KYC status before permitting a proposal (Presupuesto a medida)
func (s *JobService) ApplyForJob(ctx context.Context, technicianID, jobID uuid.UUID, budget float64, durationHours int, coverNote string) (*domain.Proposal, error) {
	tech, err := s.userRepo.GetByID(ctx, technicianID)
	if err != nil {
		return nil, fmt.Errorf("técnico no encontrado: %w", err)
	}

	if !tech.CanApplyForJobs() {
		return nil, domain.ErrUserNotVerified
	}

	job, err := s.jobRepo.GetByID(ctx, jobID)
	if err != nil {
		return nil, fmt.Errorf("trabajo no encontrado: %w", err)
	}

	if job.Status != domain.StatusPendienteDeAceptacion {
		return nil, errors.New("el trabajo ya no está disponible para postulaciones")
	}

	if budget <= 0 {
		return nil, domain.ErrInvalidBudget
	}

	existing, _ := s.proposalRepo.GetByJobAndTechnician(ctx, jobID, technicianID)
	if existing != nil {
		return nil, domain.ErrProposalAlreadyExists
	}

	proposal := &domain.Proposal{
		ID:                     uuid.New(),
		JobID:                  jobID,
		TechnicianID:           technicianID,
		EstimatedBudget:        budget,
		EstimatedDurationHours: durationHours,
		CoverNote:              coverNote,
		Status:                 domain.ProposalStatusPending,
		CreatedAt:              time.Now(),
		UpdatedAt:              time.Now(),
	}

	if err := s.proposalRepo.Create(ctx, proposal); err != nil {
		return nil, fmt.Errorf("error al registrar la propuesta: %w", err)
	}

	return proposal, nil
}

// InstantAcceptJob implements 1-tap conversion: technician accepts the Client's suggested price directly
func (s *JobService) InstantAcceptJob(ctx context.Context, technicianID, jobID uuid.UUID) (*domain.Proposal, *domain.Job, error) {
	tech, err := s.userRepo.GetByID(ctx, technicianID)
	if err != nil {
		return nil, nil, fmt.Errorf("técnico no encontrado: %w", err)
	}

	if !tech.CanApplyForJobs() {
		return nil, nil, domain.ErrUserNotVerified
	}

	job, err := s.jobRepo.GetByID(ctx, jobID)
	if err != nil {
		return nil, nil, fmt.Errorf("trabajo no encontrado: %w", err)
	}

	if job.Status != domain.StatusPendienteDeAceptacion {
		return nil, nil, errors.New("el trabajo ya no está disponible para aceptación inmediata")
	}

	budget := 28000.0 // Default benchmark fallback
	if job.EstimatedPrice != nil && *job.EstimatedPrice > 0 {
		budget = *job.EstimatedPrice
	}

	proposal := &domain.Proposal{
		ID:                     uuid.New(),
		JobID:                  jobID,
		TechnicianID:           technicianID,
		EstimatedBudget:        budget,
		EstimatedDurationHours: 2,
		CoverNote:              "Aceptación instantánea al Precio Sugerido por el cliente.",
		Status:                 domain.ProposalStatusAccepted,
		CreatedAt:              time.Now(),
		UpdatedAt:              time.Now(),
	}

	if err := s.proposalRepo.Create(ctx, proposal); err != nil {
		return nil, nil, fmt.Errorf("error al registrar propuesta instantánea: %w", err)
	}

	// Assign technician to job
	if err := s.jobRepo.AssignTechnician(ctx, job.ID, technicianID); err != nil {
		return nil, nil, err
	}
	job.AssignedTechnicianID = &technicianID

	// Reject other proposals
	allProposals, _ := s.proposalRepo.ListByJobID(ctx, job.ID)
	for _, p := range allProposals {
		if p.ID != proposal.ID && p.Status == domain.ProposalStatusPending {
			_ = s.proposalRepo.UpdateStatus(ctx, p.ID, domain.ProposalStatusRejected)
		}
	}

	// Capture escrow if payment gateway available
	if s.paymentGateway != nil {
		_, _ = s.paymentGateway.CaptureEscrow(ctx, job.ID, job.ClientID, technicianID, budget, "mercadopago_escrow")
	}

	// Automatically register technician confirmation for agendado
	now := time.Now()
	targetStatus := domain.StatusAgendado
	job.TechConfirmedStatus = &targetStatus
	job.TechConfirmedAt = &now
	_ = s.jobRepo.UpdateConfirmationStatus(ctx, job)

	updatedJob, _ := s.jobRepo.GetByID(ctx, job.ID)
	return proposal, updatedJob, nil
}

// AcceptProposal assigns the technician and registers client's confirmation for scheduling
func (s *JobService) AcceptProposal(ctx context.Context, clientID, proposalID uuid.UUID) (*domain.Job, error) {
	proposal, err := s.proposalRepo.GetByID(ctx, proposalID)
	if err != nil {
		return nil, domain.ErrProposalNotFound
	}

	job, err := s.jobRepo.GetByID(ctx, proposal.JobID)
	if err != nil {
		return nil, fmt.Errorf("trabajo no encontrado: %w", err)
	}

	if job.ClientID != clientID {
		return nil, errors.New("solo el cliente dueño del trabajo puede aceptar propuestas")
	}

	// Mark proposal accepted
	if err := s.proposalRepo.UpdateStatus(ctx, proposal.ID, domain.ProposalStatusAccepted); err != nil {
		return nil, err
	}

	// Assign technician to job
	if err := s.jobRepo.AssignTechnician(ctx, job.ID, proposal.TechnicianID); err != nil {
		return nil, err
	}
	job.AssignedTechnicianID = &proposal.TechnicianID

	// Reject all other proposals
	allProposals, _ := s.proposalRepo.ListByJobID(ctx, job.ID)
	for _, p := range allProposals {
		if p.ID != proposal.ID && p.Status == domain.ProposalStatusPending {
			_ = s.proposalRepo.UpdateStatus(ctx, p.ID, domain.ProposalStatusRejected)
		}
	}

	// Capture escrow hold
	if s.paymentGateway != nil {
		_, _ = s.paymentGateway.CaptureEscrow(ctx, job.ID, clientID, proposal.TechnicianID, proposal.EstimatedBudget, "mercadopago_escrow")
	}

	// Automatically register client confirmation for 'agendado'
	_, _, _ = s.ConfirmJobStatusTransition(ctx, job.ID, clientID, domain.StatusAgendado)

	// Fetch fresh state
	return s.jobRepo.GetByID(ctx, job.ID)
}

// ConfirmJobStatusTransition executes the Double Confirmation business rule:
// El cambio de estado requiere la confirmación de ambas partes (cliente y técnico).
// Cuando ambos coinciden, el estado global de la orden transiciona oficialmente.
// Al finalizar, se procesa la pasarela de pagos mock (MercadoPago) y se libera la Garantía de 30 días.
func (s *JobService) ConfirmJobStatusTransition(ctx context.Context, jobID, callerID uuid.UUID, targetStatus domain.JobStatus) (*domain.Job, *domain.JobStatusConfirmation, error) {
	job, err := s.jobRepo.GetByID(ctx, jobID)
	if err != nil {
		return nil, nil, fmt.Errorf("trabajo no encontrado: %w", err)
	}

	fromStatus := job.Status
	transitioned, err := job.ConfirmStatus(callerID, targetStatus)
	if err != nil {
		return nil, nil, err
	}

	confirmation := &domain.JobStatusConfirmation{
		JobID:            job.ID,
		CallerID:         callerID,
		TargetStatus:     targetStatus,
		ClientConfirmed:  job.ClientConfirmedStatus != nil && *job.ClientConfirmedStatus == targetStatus,
		TechConfirmed:    job.TechConfirmedStatus != nil && *job.TechConfirmedStatus == targetStatus,
		Transitioned:     transitioned,
		PaymentTriggered: false,
		WarrantyActive:   false,
	}

	// Handle Payment release & Warranty activation on finalization
	if transitioned && targetStatus == domain.StatusFinalizado {
		if s.paymentGateway != nil {
			receipt, pErr := s.paymentGateway.ReleaseEscrowAndWarranty(ctx, job.ID)
			if pErr == nil && receipt != nil {
				job.PaymentReceipt = receipt
				confirmation.PaymentTriggered = true
				confirmation.PaymentReceipt = receipt
				confirmation.WarrantyActive = true
				confirmation.WarrantyCertificate = receipt.WarrantyCertificate
			}
		}
	}

	// Persist the confirmation flags and any resulting global status change
	if err := s.jobRepo.UpdateConfirmationStatus(ctx, job); err != nil {
		return nil, nil, fmt.Errorf("error al actualizar el estado de confirmación: %w", err)
	}

	// Record audit transition
	transition := &domain.JobStatusTransition{
		ID:                uuid.New(),
		JobID:             job.ID,
		InitiatedByUserID: callerID,
		FromStatus:        fromStatus,
		TargetStatus:      targetStatus,
		ClientConfirmed:   confirmation.ClientConfirmed,
		TechConfirmed:     confirmation.TechConfirmed,
		IsCompleted:       transitioned,
		PaymentTriggered:  confirmation.PaymentTriggered,
		WarrantyReleased:  confirmation.WarrantyActive,
		CreatedAt:         time.Now(),
	}
	_ = s.jobRepo.RecordTransition(ctx, transition)

	// If official transition completed, send notification alerts
	if transitioned && s.notifier != nil {
		client, _ := s.userRepo.GetByID(ctx, job.ClientID)
		if client != nil {
			_ = s.notifier.SendStatusChangeAlert(ctx, job, client, job.Status)
		}
		if job.AssignedTechnicianID != nil {
			tech, _ := s.userRepo.GetByID(ctx, *job.AssignedTechnicianID)
			if tech != nil {
				_ = s.notifier.SendStatusChangeAlert(ctx, job, tech, job.Status)
			}
		}
	}

	if transitioned {
		confirmation.Message = fmt.Sprintf("¡Doble confirmación exitosa! Estado global actualizado a %s.", targetStatus)
		if confirmation.WarrantyActive {
			confirmation.Message += " Pago liberado y Garantía Reparatutti de 30 días activada."
		}
	} else {
		confirmation.Message = "Confirmación registrada. Esperando la confirmación de la contraparte para completar la transición."
	}

	return job, confirmation, nil
}
