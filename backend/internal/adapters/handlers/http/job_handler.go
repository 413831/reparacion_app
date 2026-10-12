package http

import (
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/reparatutti/backend/internal/core/domain"
	"github.com/reparatutti/backend/internal/core/ports"
	"github.com/reparatutti/backend/internal/core/services"
)

type JobHandler struct {
	jobService   *services.JobService
	jobRepo      ports.JobRepository
	proposalRepo ports.ProposalRepository
}

func NewJobHandler(jobService *services.JobService, jobRepo ports.JobRepository, proposalRepo ports.ProposalRepository) *JobHandler {
	return &JobHandler{
		jobService:   jobService,
		jobRepo:      jobRepo,
		proposalRepo: proposalRepo,
	}
}

type CreateJobRequest struct {
	Category     domain.TradeCategory `json:"category" binding:"required"`
	Title        string               `json:"title" binding:"required"`
	Description  string               `json:"description" binding:"required"`
	Locality     string               `json:"locality" binding:"required"`
	ScheduledAt  time.Time            `json:"scheduled_at" binding:"required"`
	Photos       []string             `json:"photos"`
}

type ApplyJobRequest struct {
	EstimatedBudget float64 `json:"estimated_budget" binding:"required,gt=0"`
	DurationHours   int     `json:"duration_hours" binding:"required,gt=0"`
	CoverNote       string  `json:"cover_note"`
}

type ConfirmStatusRequest struct {
	TargetStatus domain.JobStatus `json:"target_status" binding:"required"`
}

func (h *JobHandler) CreateJob(c *gin.Context) {
	clientID := c.MustGet("user_id").(uuid.UUID)

	var req CreateJobRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	job, err := h.jobService.CreateJob(c.Request.Context(), clientID, req.Category, req.Title, req.Description, req.Locality, req.ScheduledAt, req.Photos)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusCreated, job)
}

func (h *JobHandler) ListAvailableJobs(c *gin.Context) {
	categoryStr := c.Query("category")
	var categoryPtr *domain.TradeCategory
	if categoryStr != "" {
		cat := domain.TradeCategory(categoryStr)
		categoryPtr = &cat
	}

	jobs, err := h.jobRepo.ListAvailable(c.Request.Context(), categoryPtr, 50, 0)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "error fetching jobs"})
		return
	}

	c.JSON(http.StatusOK, jobs)
}

func (h *JobHandler) GetJob(c *gin.Context) {
	jobID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid job id"})
		return
	}

	job, err := h.jobRepo.GetByID(c.Request.Context(), jobID)
	if err != nil || job == nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "job not found"})
		return
	}

	c.JSON(http.StatusOK, job)
}

func (h *JobHandler) ApplyForJob(c *gin.Context) {
	technicianID := c.MustGet("user_id").(uuid.UUID)
	jobID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid job id"})
		return
	}

	var req ApplyJobRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	proposal, err := h.jobService.ApplyForJob(c.Request.Context(), technicianID, jobID, req.EstimatedBudget, req.DurationHours, req.CoverNote)
	if err != nil {
		if err == domain.ErrUserNotVerified {
			c.JSON(http.StatusForbidden, gin.H{
				"error": "Técnicos con estado 'unverified' o 'pending' no pueden postularse a trabajos. Complete su validación KYC primero.",
			})
			return
		}
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusCreated, proposal)
}

func (h *JobHandler) ListProposals(c *gin.Context) {
	jobID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid job id"})
		return
	}

	proposals, err := h.proposalRepo.ListByJobID(c.Request.Context(), jobID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to list proposals"})
		return
	}

	c.JSON(http.StatusOK, proposals)
}

func (h *JobHandler) AcceptProposal(c *gin.Context) {
	clientID := c.MustGet("user_id").(uuid.UUID)
	proposalID, err := uuid.Parse(c.Param("proposal_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid proposal id"})
		return
	}

	job, err := h.jobService.AcceptProposal(c.Request.Context(), clientID, proposalID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "Presupuesto aceptado. Esperando confirmación de fecha para transicionar a 'agendado'.",
		"job":     job,
	})
}

// ConfirmStatus handles the Double Confirmation endpoint
func (h *JobHandler) ConfirmStatus(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)
	jobID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "id de trabajo inválido"})
		return
	}

	var req ConfirmStatusRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	job, transitioned, err := h.jobService.ConfirmJobStatusTransition(c.Request.Context(), jobID, userID, req.TargetStatus)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	message := "Confirmación registrada. Pendiente la confirmación de la otra parte."
	if transitioned {
		message = "¡Doble confirmación completada! El estado oficial del trabajo se actualizó a: " + string(job.Status)
	}

	c.JSON(http.StatusOK, gin.H{
		"message":      message,
		"transitioned": transitioned,
		"job":          job,
	})
}
