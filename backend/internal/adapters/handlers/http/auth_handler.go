package http

import (
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/reparatutti/backend/internal/adapters/handlers/middleware"
	"github.com/reparatutti/backend/internal/core/domain"
	"github.com/reparatutti/backend/internal/core/ports"
	"golang.org/x/crypto/bcrypt"
)

type AuthHandler struct {
	userRepo ports.UserRepository
	jwtAuth  *middleware.AuthMiddleware
}

func NewAuthHandler(userRepo ports.UserRepository, jwtAuth *middleware.AuthMiddleware) *AuthHandler {
	return &AuthHandler{
		userRepo: userRepo,
		jwtAuth:  jwtAuth,
	}
}

type RegisterRequest struct {
	Email         string                `json:"email" binding:"required,email"`
	Password      string                `json:"password" binding:"required,min=8"`
	FullName      string                `json:"full_name" binding:"required"`
	PhoneNumber   string                `json:"phone_number" binding:"required"`
	Role          domain.UserRole       `json:"role" binding:"required"`
	Trade         *domain.TradeCategory `json:"trade"`
	TermsAccepted bool                  `json:"terms_accepted" binding:"required"`
	TermsVersion  string                `json:"terms_version" binding:"required"`
}

type LoginRequest struct {
	Email    string `json:"email" binding:"required,email"`
	Password string `json:"password" binding:"required"`
}

type OAuthRequest struct {
	Provider      string          `json:"provider" binding:"required"` // "google", "apple"
	ProviderToken string          `json:"provider_token" binding:"required"`
	Email         string          `json:"email" binding:"required,email"`
	FullName      string          `json:"full_name" binding:"required"`
	Role          domain.UserRole `json:"role" binding:"required"`
	TermsAccepted bool            `json:"terms_accepted" binding:"required"`
	TermsVersion  string          `json:"terms_version" binding:"required"`
}

func (h *AuthHandler) Register(c *gin.Context) {
	var req RegisterRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Argentine Law 25.326 mandatory consent validation
	if !req.TermsAccepted {
		c.JSON(http.StatusUnprocessableEntity, gin.H{
			"error": "Debe aceptar expresamente los Términos y Condiciones conforme a la Ley 25.326 y Ley 24.240",
		})
		return
	}

	existing, _ := h.userRepo.GetByEmail(c.Request.Context(), req.Email)
	if existing != nil {
		c.JSON(http.StatusConflict, gin.H{"error": "El correo electrónico ya está registrado"})
		return
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "error hashing password"})
		return
	}

	user := &domain.User{
		ID:              uuid.New(),
		Email:           req.Email,
		PasswordHash:    string(hash),
		FullName:        req.FullName,
		PhoneNumber:     req.PhoneNumber,
		Role:            req.Role,
		AuthProvider:    "local",
		TermsAcceptedAt: time.Now(),
		TermsVersion:    req.TermsVersion,
		KYCStatus:       domain.KYCUnverified,
		Trade:           req.Trade,
		RatingAverage:   0.00,
		ReviewsCount:    0,
		IsActive:        true,
		CreatedAt:       time.Now(),
		UpdatedAt:       time.Now(),
	}

	if err := h.userRepo.Create(c.Request.Context(), user); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "error creating user: " + err.Error()})
		return
	}

	// Audit legal consent
	_ = h.userRepo.LogLegalConsent(c.Request.Context(), user.ID, "terms_accepted", c.ClientIP(), c.Request.UserAgent(), req.TermsVersion)

	token, _ := h.jwtAuth.GenerateToken(user)
	c.JSON(http.StatusCreated, gin.H{
		"token": token,
		"user":  user,
	})
}

func (h *AuthHandler) Login(c *gin.Context) {
	var req LoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	user, err := h.userRepo.GetByEmail(c.Request.Context(), req.Email)
	if err != nil || user == nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Credenciales inválidas"})
		return
	}

	if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(req.Password)); err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Credenciales inválidas"})
		return
	}

	token, _ := h.jwtAuth.GenerateToken(user)
	c.JSON(http.StatusOK, gin.H{
		"token": token,
		"user":  user,
	})
}

// OAuthLogin handles Google Sign-In and Apple Sign-In (mandatory on iOS)
func (h *AuthHandler) OAuthLogin(c *gin.Context) {
	var req OAuthRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	if !req.TermsAccepted {
		c.JSON(http.StatusUnprocessableEntity, gin.H{
			"error": "Debe aceptar expresamente los Términos y Condiciones conforme a la Ley 25.326 y Ley 24.240",
		})
		return
	}

	user, err := h.userRepo.GetByEmail(c.Request.Context(), req.Email)
	if err != nil || user == nil {
		// Create new OAuth user
		user = &domain.User{
			ID:              uuid.New(),
			Email:           req.Email,
			FullName:        req.FullName,
			Role:            req.Role,
			AuthProvider:    req.Provider,
			TermsAcceptedAt: time.Now(),
			TermsVersion:    req.TermsVersion,
			KYCStatus:       domain.KYCUnverified,
			RatingAverage:   0.00,
			ReviewsCount:    0,
			IsActive:        true,
			CreatedAt:       time.Now(),
			UpdatedAt:       time.Now(),
		}
		if err := h.userRepo.Create(c.Request.Context(), user); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "error creating user"})
			return
		}
		_ = h.userRepo.LogLegalConsent(c.Request.Context(), user.ID, "terms_accepted", c.ClientIP(), c.Request.UserAgent(), req.TermsVersion)
	}

	token, _ := h.jwtAuth.GenerateToken(user)
	c.JSON(http.StatusOK, gin.H{
		"token": token,
		"user":  user,
	})
}
