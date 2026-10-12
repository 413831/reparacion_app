package ports

import (
	"context"

	"github.com/reparatutti/backend/internal/core/domain"
)

// ReminderNotifier defines the port for multichannel reminder alerts (Push, Email, SMS, In-App)
type ReminderNotifier interface {
	SendScheduleReminder(ctx context.Context, job *domain.Job, recipient *domain.User, reminderType string) error
	SendStatusChangeAlert(ctx context.Context, job *domain.Job, recipient *domain.User, newStatus domain.JobStatus) error
}
