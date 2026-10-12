package notification

import (
	"context"
	"fmt"
	"log"

	"github.com/reparatutti/backend/internal/core/domain"
	"github.com/reparatutti/backend/internal/core/ports"
)

type MockMultichannelNotifier struct {
	userRepo ports.UserRepository
}

func NewMockMultichannelNotifier(userRepo ports.UserRepository) *MockMultichannelNotifier {
	return &MockMultichannelNotifier{userRepo: userRepo}
}

func (m *MockMultichannelNotifier) SendScheduleReminder(ctx context.Context, job *domain.Job, recipient *domain.User, reminderType string) error {
	prefs, _ := m.userRepo.GetNotificationConfig(ctx, recipient.ID)
	if prefs == nil {
		prefs = &domain.NotificationConfig{
			PushEnabled:         true,
			EmailEnabled:        true,
			SMSEnabled:          false,
			Reminders24hEnabled: true,
			Reminders2hEnabled:  true,
		}
	}

	title := fmt.Sprintf("⏰ Recordatorio de Servicio (%s antes)", reminderType)
	body := fmt.Sprintf("Tu cita de '%s' está programada para %s.", job.Title, job.ScheduledAt.Format("02/01/2006 15:04"))

	if prefs.PushEnabled {
		log.Printf("[Push Notification] Para: %s (%s) | Título: %s | Mensaje: %s", recipient.FullName, recipient.Email, title, body)
	}
	if prefs.EmailEnabled {
		log.Printf("[Email Notification] Para: %s | Asunto: %s | Contenido: %s", recipient.Email, title, body)
	}
	if prefs.SMSEnabled && recipient.PhoneNumber != "" {
		log.Printf("[SMS Notification] Para: %s | Mensaje: %s", recipient.PhoneNumber, body)
	}

	return nil
}

func (m *MockMultichannelNotifier) SendStatusChangeAlert(ctx context.Context, job *domain.Job, recipient *domain.User, newStatus domain.JobStatus) error {
	log.Printf("[In-App & Push Alert] Usuario: %s | El trabajo '%s' cambió oficialmente a estado: '%s'",
		recipient.FullName, job.Title, newStatus)
	return nil
}
