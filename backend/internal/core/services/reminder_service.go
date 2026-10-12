package services

import (
	"context"
	"log"
	"sync"
	"time"

	"github.com/reparatutti/backend/internal/core/domain"
	"github.com/reparatutti/backend/internal/core/ports"
)

type ReminderSchedulerService struct {
	jobRepo  ports.JobRepository
	userRepo ports.UserRepository
	notifier ports.ReminderNotifier
	stopChan chan struct{}
	wg       sync.WaitGroup
}

func NewReminderSchedulerService(
	jobRepo ports.JobRepository,
	userRepo ports.UserRepository,
	notifier ports.ReminderNotifier,
) *ReminderSchedulerService {
	return &ReminderSchedulerService{
		jobRepo:  jobRepo,
		userRepo: userRepo,
		notifier: notifier,
		stopChan: make(chan struct{}),
	}
}

// Start launches the background scheduler ticker that runs every minute
func (s *ReminderSchedulerService) Start(interval time.Duration) {
	s.wg.Add(1)
	go func() {
		defer s.wg.Done()
		ticker := time.NewTicker(interval)
		defer ticker.Stop()

		log.Printf("[Scheduler] Servicio de recordatorios iniciado (intervalo: %v)", interval)

		for {
			select {
			case <-ticker.C:
				s.CheckAndDispatchReminders(context.Background())
			case <-s.stopChan:
				log.Println("[Scheduler] Servicio de recordatorios detenido")
				return
			}
		}
	}()
}

// Stop cleanly stops the background ticker
func (s *ReminderSchedulerService) Stop() {
	close(s.stopChan)
	s.wg.Wait()
}

// CheckAndDispatchReminders queries jobs in status 'agendado' and sends 24h & 2h alerts
func (s *ReminderSchedulerService) CheckAndDispatchReminders(ctx context.Context) {
	now := time.Now()

	// 1. Check 24 hours reminder (window: between 23h30m and 24h30m ahead)
	window24hStart := now.Add(23*time.Hour + 30*time.Minute)
	window24hEnd := now.Add(24*time.Hour + 30*time.Minute)
	jobs24h, err := s.jobRepo.GetUpcomingJobsForReminder(ctx, window24hStart, window24hEnd, "24h")
	if err == nil {
		for _, job := range jobs24h {
			s.dispatchJobReminder(ctx, job, "24h")
		}
	}

	// 2. Check 2 hours reminder (window: between 1h45m and 2h15m ahead)
	window2hStart := now.Add(1*time.Hour + 45*time.Minute)
	window2hEnd := now.Add(2*time.Hour + 15*time.Minute)
	jobs2h, err := s.jobRepo.GetUpcomingJobsForReminder(ctx, window2hStart, window2hEnd, "2h")
	if err == nil {
		for _, job := range jobs2h {
			s.dispatchJobReminder(ctx, job, "2h")
		}
	}
}

func (s *ReminderSchedulerService) dispatchJobReminder(ctx context.Context, job *domain.Job, reminderType string) {
	if s.notifier == nil {
		return
	}

	// Notify Client
	client, err := s.userRepo.GetByID(ctx, job.ClientID)
	if err == nil && client != nil {
		_ = s.notifier.SendScheduleReminder(ctx, job, client, reminderType)
	}

	// Notify Technician
	if job.AssignedTechnicianID != nil {
		tech, err := s.userRepo.GetByID(ctx, *job.AssignedTechnicianID)
		if err == nil && tech != nil {
			_ = s.notifier.SendScheduleReminder(ctx, job, tech, reminderType)
		}
	}

	// Mark as sent in repository to avoid duplicates
	_ = s.jobRepo.MarkReminderSent(ctx, job.ID, reminderType)
	log.Printf("[Scheduler] Recordatorio de %s enviado con éxito para trabajo ID: %s (%s)", reminderType, job.ID, job.Title)
}
