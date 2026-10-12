package domain

import (
	"errors"
	"time"

	"github.com/google/uuid"
)

// 4 Estados Válidos del Ciclo de Vida del Trabajo
type JobStatus string

const (
	StatusPendienteDeAceptacion JobStatus = "pendiente_de_aceptacion"
	StatusAgendado              JobStatus = "agendado"
	StatusFinalizado            JobStatus = "finalizado"
	StatusCancelado             JobStatus = "cancelado"
)

type Job struct {
	ID                    uuid.UUID     `json:"id"`
	ClientID              uuid.UUID     `json:"client_id"`
	AssignedTechnicianID  *uuid.UUID    `json:"assigned_technician_id,omitempty"`
	Category              TradeCategory `json:"category"`
	Title                 string        `json:"title"`
	Description           string        `json:"description"`
	PhotosURLs            []string      `json:"photos_urls"`
	
	// Fecha y hora agendada para el servicio
	ScheduledAt           time.Time     `json:"scheduled_at"`
	
	GeneralLocality       string        `json:"general_locality"`
	FullAddress           *string       `json:"full_address,omitempty"`
	LocationLatitude      *float64      `json:"location_latitude,omitempty"`
	LocationLongitude     *float64      `json:"location_longitude,omitempty"`
	
	// Estado global oficial de la orden
	Status                JobStatus     `json:"status"`
	
	// Flags independientes de Doble Confirmación
	ClientConfirmedStatus *JobStatus    `json:"client_confirmed_status,omitempty"`
	TechConfirmedStatus   *JobStatus    `json:"tech_confirmed_status,omitempty"`
	ClientConfirmedAt     *time.Time    `json:"client_confirmed_at,omitempty"`
	TechConfirmedAt       *time.Time    `json:"tech_confirmed_at,omitempty"`
	
	// Control de recordatorios preventivos de agenda
	Reminder24hSentAt     *time.Time    `json:"reminder_24h_sent_at,omitempty"`
	Reminder2hSentAt      *time.Time    `json:"reminder_2h_sent_at,omitempty"`
	
	CreatedAt             time.Time     `json:"created_at"`
	UpdatedAt             time.Time     `json:"updated_at"`
	CompletedAt           *time.Time    `json:"completed_at,omitempty"`
	CancelledAt           *time.Time    `json:"cancelled_at,omitempty"`
}

type JobStatusTransition struct {
	ID                 uuid.UUID `json:"id"`
	JobID              uuid.UUID `json:"job_id"`
	InitiatedByUserID  uuid.UUID `json:"initiated_by_user_id"`
	FromStatus         JobStatus `json:"from_status"`
	TargetStatus       JobStatus `json:"target_status"`
	ClientConfirmed    bool      `json:"client_confirmed"`
	TechConfirmed      bool      `json:"tech_confirmed"`
	IsCompleted        bool      `json:"is_completed"`
	Notes              string    `json:"notes,omitempty"`
	CreatedAt          time.Time `json:"created_at"`
	CompletedAt        *time.Time `json:"completed_at,omitempty"`
}

type NotificationConfig struct {
	UserID              uuid.UUID `json:"user_id"`
	PushEnabled         bool      `json:"push_enabled"`
	EmailEnabled        bool      `json:"email_enabled"`
	SMSEnabled          bool      `json:"sms_enabled"`
	Reminders24hEnabled bool      `json:"reminders_24h_enabled"`
	Reminders2hEnabled  bool      `json:"reminders_2h_enabled"`
	UpdatedAt           time.Time `json:"updated_at"`
}

var (
	ErrJobUnauthorizedAccess       = errors.New("el usuario no es un participante autorizado en este trabajo")
	ErrJobCannotBeCompleted         = errors.New("el trabajo no puede ser finalizado en su estado actual")
	ErrInvalidStatusTransition      = errors.New("transición de estado inválida")
	ErrTechnicianNotAssignedYet     = errors.New("se requiere un técnico asignado antes de confirmar el agendamiento")
)

func (j *Job) CanAccessChat(userID uuid.UUID) bool {
	if j.ClientID == userID {
		return true
	}
	if j.AssignedTechnicianID != nil && *j.AssignedTechnicianID == userID {
		return true
	}
	return false
}

func (j *Job) CanShareLocation(senderID uuid.UUID) bool {
	if j.ClientID != senderID {
		return false
	}
	return j.Status == StatusAgendado
}

// ConfirmStatus implements the Double Confirmation business rule:
// "El cambio de estado requiere la confirmación de ambas partes (cliente y técnico).
// Cuando ambos coinciden, el estado global de la orden transiciona oficialmente."
func (j *Job) ConfirmStatus(callerID uuid.UUID, targetStatus JobStatus) (transitioned bool, err error) {
	isClient := j.ClientID == callerID
	isTech := j.AssignedTechnicianID != nil && *j.AssignedTechnicianID == callerID

	if !isClient && !isTech {
		return false, ErrJobUnauthorizedAccess
	}

	if targetStatus == StatusAgendado && j.AssignedTechnicianID == nil {
		return false, ErrTechnicianNotAssignedYet
	}

	now := time.Now()
	targetCopy := targetStatus

	if isClient {
		j.ClientConfirmedStatus = &targetCopy
		j.ClientConfirmedAt = &now
	}
	if isTech {
		j.TechConfirmedStatus = &targetCopy
		j.TechConfirmedAt = &now
	}

	// Check if both parties have confirmed the SAME target status
	if j.ClientConfirmedStatus != nil && j.TechConfirmedStatus != nil &&
		*j.ClientConfirmedStatus == *j.TechConfirmedStatus {
		j.Status = *j.ClientConfirmedStatus
		j.UpdatedAt = now

		switch j.Status {
		case StatusFinalizado:
			j.CompletedAt = &now
		case StatusCancelado:
			j.CancelledAt = &now
		}

		return true, nil
	}

	return false, nil
}
