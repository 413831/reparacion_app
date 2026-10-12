package http

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/reparatutti/backend/internal/core/domain"
	"github.com/reparatutti/backend/internal/core/services"
)

type KYCHandler struct {
	kycService *services.KYCService
}

func NewKYCHandler(kycService *services.KYCService) *KYCHandler {
	return &KYCHandler{kycService: kycService}
}

type SubmitKYCRequest struct {
	DNIFrontBase64 string `json:"dni_front_base64"`
	DNIBackBase64  string `json:"dni_back_base64"`
	SelfieBase64   string `json:"selfie_base64" binding:"required"`
	DocumentNumber string `json:"document_number"`
}

func (h *KYCHandler) SubmitVerification(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)
	userRole := c.MustGet("role").(domain.UserRole)

	var req SubmitKYCRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	submission := &domain.VerificationSubmission{
		UserID:         userID,
		UserRole:       userRole,
		DNIFrontB64:    req.DNIFrontBase64,
		DNIBackB64:     req.DNIBackBase64,
		SelfieB64:      req.SelfieBase64,
		DocumentNumber: req.DocumentNumber,
	}

	record, err := h.kycService.SubmitVerification(c.Request.Context(), submission)
	if err != nil {
		c.JSON(http.StatusUnprocessableEntity, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusAccepted, gin.H{
		"message": "Solicitud de verificación KYC enviada exitosamente. Se encuentra en procesamiento.",
		"status":  record.Status,
		"kyc_id":  record.ID,
	})
}

func (h *KYCHandler) GetStatus(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)
	record, err := h.kycService.GetStatus(c.Request.Context(), userID)
	if err != nil || record == nil {
		c.JSON(http.StatusOK, gin.H{
			"status": domain.KYCUnverified,
		})
		return
	}

	c.JSON(http.StatusOK, record)
}
