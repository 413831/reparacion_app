package http

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/reparatutti/backend/internal/core/services"
)

type ReviewHandler struct {
	reviewService *services.ReviewService
}

func NewReviewHandler(reviewService *services.ReviewService) *ReviewHandler {
	return &ReviewHandler{reviewService: reviewService}
}

type CreateReviewRequest struct {
	Score   int    `json:"score" binding:"required,min=1,max=5"`
	Comment string `json:"comment"`
}

func (h *ReviewHandler) SubmitReview(c *gin.Context) {
	clientID := c.MustGet("user_id").(uuid.UUID)
	jobID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid job id"})
		return
	}

	var req CreateReviewRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	review, err := h.reviewService.SubmitReview(c.Request.Context(), clientID, jobID, req.Score, req.Comment)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusCreated, gin.H{
		"message": "Calificación registrada con éxito. Se actualizó el rating promedio del técnico.",
		"review":  review,
	})
}
