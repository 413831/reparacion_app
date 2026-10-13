package http

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/reparatutti/backend/internal/core/domain"
	"github.com/reparatutti/backend/internal/core/ports"
)

type UserHandler struct {
	userRepo ports.UserRepository
}

func NewUserHandler(userRepo ports.UserRepository) *UserHandler {
	return &UserHandler{userRepo: userRepo}
}

func (h *UserHandler) SuspendAccount(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)

	if err := h.userRepo.SuspendAccount(c.Request.Context(), userID); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "error al suspender la cuenta"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "Cuenta suspendida exitosamente. Puede reactivarla contactando a soporte.",
	})
}

func (h *UserHandler) DeleteAccount(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)

	if err := h.userRepo.DeleteAccount(c.Request.Context(), userID); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "error al eliminar la cuenta"})
		return
	}

	// Explicit session invalidation header and compliance metadata
	c.Header("Clear-Site-Data", `"cache", "cookies", "storage"`)
	c.JSON(http.StatusOK, gin.H{
		"status":  "deleted",
		"message": "Cuenta eliminada y anonimizada definitivamente conforme a las directrices de privacidad y App Store Guideline 5.1.1(v).",
	})
}

func (h *UserHandler) GetNotificationPreferences(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)

	prefs, err := h.userRepo.GetNotificationConfig(c.Request.Context(), userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "error al obtener preferencias"})
		return
	}

	c.JSON(http.StatusOK, prefs)
}

func (h *UserHandler) UpdateNotificationPreferences(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)

	var req domain.NotificationConfig
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	req.UserID = userID
	if err := h.userRepo.UpdateNotificationConfig(c.Request.Context(), &req); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "error al actualizar preferencias"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message":     "Preferencias de notificación actualizadas",
		"preferences": req,
	})
}
