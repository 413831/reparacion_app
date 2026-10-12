package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"golang.org/x/crypto/bcrypt"

	httpHandlers "github.com/reparatutti/backend/internal/adapters/handlers/http"
	"github.com/reparatutti/backend/internal/adapters/handlers/middleware"
	"github.com/reparatutti/backend/internal/adapters/handlers/ws"
	"github.com/reparatutti/backend/internal/adapters/identity"
	"github.com/reparatutti/backend/internal/adapters/notification"
	"github.com/reparatutti/backend/internal/adapters/repository/postgres"
	"github.com/reparatutti/backend/internal/core/domain"
	"github.com/reparatutti/backend/internal/core/services"
)

func main() {
	log.Println("==================================================")
	log.Println(" Reparatutti Cloud-Native Backend (Go 1.22+)")
	log.Println(" Clean / Hexagonal Architecture Active")
	log.Println("==================================================")

	// 1. Core Repositories
	userRepo := postgres.NewInMemoryUserRepo()
	kycRepo := postgres.NewInMemoryKYCRepo()
	jobRepo := postgres.NewInMemoryJobRepo()
	proposalRepo := postgres.NewInMemoryProposalRepo()
	chatRepo := postgres.NewInMemoryChatRepo()
	reviewRepo := postgres.NewInMemoryReviewRepo()

	// 2. Adapters & Ports
	identityVerifier := identity.NewMockIdentityVerifier()
	multichannelNotifier := notification.NewMockMultichannelNotifier(userRepo)

	// 3. Domain Services
	kycService := services.NewKYCService(userRepo, kycRepo, identityVerifier)
	jobService := services.NewJobService(jobRepo, proposalRepo, userRepo, multichannelNotifier)
	reviewService := services.NewReviewService(reviewRepo, jobRepo, userRepo)
	
	// 4. Background Scheduled Reminder Service (Ticker)
	reminderScheduler := services.NewReminderSchedulerService(jobRepo, userRepo, multichannelNotifier)
	reminderScheduler.Start(30 * time.Second)

	// 5. WebSocket Hub
	wsHub := ws.NewHub(chatRepo, jobRepo)
	go wsHub.Run()

	// 6. Middlewares
	jwtSecret := os.Getenv("JWT_SECRET")
	if jwtSecret == "" {
		jwtSecret = "super-secure-reparatutti-jwt-secret-key-2026"
	}
	authMw := middleware.NewAuthMiddleware(jwtSecret)
	rateLimiter := middleware.NewTokenBucketRateLimiter(80, 20) // 80 RPM with burst of 20

	// 7. HTTP & WS Handlers
	authHandler := httpHandlers.NewAuthHandler(userRepo, authMw)
	kycHandler := httpHandlers.NewKYCHandler(kycService)
	jobHandler := httpHandlers.NewJobHandler(jobService, jobRepo, proposalRepo)
	reviewHandler := httpHandlers.NewReviewHandler(reviewService)
	userHandler := httpHandlers.NewUserHandler(userRepo)
	chatWSHandler := ws.NewChatWSHandler(wsHub, jobRepo)

	// Seed Sample Data for Testing / Demo
	seedDatabase(userRepo, jobRepo)

	// 8. Gin Engine & Routing
	router := gin.Default()
	router.Use(gin.Recovery())

	// Apply Rate Limiting
	router.Use(rateLimiter.Middleware())

	// Health Check
	router.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"status":    "healthy",
			"timestamp": time.Now().Format(time.RFC3339),
			"version":   "1.1.0-mvp",
		})
	})

	api := router.Group("/api/v1")
	{
		// Public Auth Endpoints
		authGroup := api.Group("/auth")
		{
			authGroup.POST("/register", authHandler.Register)
			authGroup.POST("/login", authHandler.Login)
			authGroup.POST("/oauth", authHandler.OAuthLogin)
		}

		// Authenticated Routes
		protected := api.Group("")
		protected.Use(authMw.Authenticate())
		{
			// User Account Management & Preferences (App Store Guideline 5.1.1)
			userGroup := protected.Group("/users/me")
			{
				userGroup.POST("/suspend", userHandler.SuspendAccount)
				userGroup.POST("/delete", userHandler.DeleteAccount)
				userGroup.GET("/notifications", userHandler.GetNotificationPreferences)
				userGroup.PUT("/notifications", userHandler.UpdateNotificationPreferences)
			}

			// KYC Verification
			protected.POST("/kyc/submit", kycHandler.SubmitVerification)
			protected.GET("/kyc/status", kycHandler.GetStatus)

			// Jobs Management
			jobsGroup := protected.Group("/jobs")
			{
				jobsGroup.POST("", middleware.RequireRole(domain.RoleClient), jobHandler.CreateJob)
				jobsGroup.GET("", jobHandler.ListAvailableJobs)
				jobsGroup.GET("/:id", jobHandler.GetJob)

				// Technician proposal submission - Strict Guard: KYC Verified only!
				jobsGroup.POST("/:id/proposals",
					middleware.RequireRole(domain.RoleTechnician),
					middleware.RequireVerifiedTechnician(),
					jobHandler.ApplyForJob,
				)
				jobsGroup.GET("/:id/proposals", jobHandler.ListProposals)

				// Client accepts proposal
				jobsGroup.POST("/:id/accept/:proposal_id", middleware.RequireRole(domain.RoleClient), jobHandler.AcceptProposal)

				// Double Confirmation State Machine Endpoint (Both Client and Tech confirm)
				jobsGroup.POST("/:id/confirm-status", jobHandler.ConfirmStatus)

				// Reviews
				jobsGroup.POST("/:id/review", middleware.RequireRole(domain.RoleClient), reviewHandler.SubmitReview)
			}

			// 1:1 Real-Time Chat WebSocket
			protected.GET("/ws/chat/:job_id", chatWSHandler.HandleChatWS)
		}
	}

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	log.Printf("Server listening on port :%s", port)
	if err := router.Run(":" + port); err != nil {
		log.Fatalf("Server stopped: %v", err)
	}
}

// seedDatabase pre-populates demo accounts
func seedDatabase(userRepo *postgres.InMemoryUserRepo, jobRepo *postgres.InMemoryJobRepo) {
	ctx := context.Background()
	hash, _ := bcrypt.GenerateFromPassword([]byte("Password123!"), bcrypt.DefaultCost)

	// 1. Client user
	clientID := uuid.MustParse("11111111-1111-1111-1111-111111111111")
	client := &domain.User{
		ID:              clientID,
		Email:           "cliente@reparatutti.com",
		PasswordHash:    string(hash),
		FullName:        "Lucía Fernández",
		PhoneNumber:     "+5491144556677",
		Role:            domain.RoleClient,
		AccountStatus:   domain.AccountStatusActive,
		TermsAcceptedAt: time.Now(),
		TermsVersion:    domain.DefaultTermsPlaceholder,
		KYCStatus:       domain.KYCVerified,
		IsActive:        true,
	}
	_ = userRepo.Create(ctx, client)

	// 2. Verified Technician
	trade := domain.TradeElectricidad
	techID := uuid.MustParse("22222222-2222-2222-2222-222222222222")
	tech := &domain.User{
		ID:              techID,
		Email:           "tecnico.verificado@reparatutti.com",
		PasswordHash:    string(hash),
		FullName:        "Carlos Benítez",
		PhoneNumber:     "+5491199887766",
		Role:            domain.RoleTechnician,
		AccountStatus:   domain.AccountStatusActive,
		TermsAcceptedAt: time.Now(),
		TermsVersion:    domain.DefaultTermsPlaceholder,
		KYCStatus:       domain.KYCVerified,
		Trade:           &trade,
		RatingAverage:   4.85,
		ReviewsCount:    14,
		IsActive:        true,
	}
	_ = userRepo.Create(ctx, tech)

	// 3. Unverified Technician (cannot bid)
	tradeGas := domain.TradeGas
	unverifiedTechID := uuid.MustParse("33333333-3333-3333-3333-333333333333")
	unverifiedTech := &domain.User{
		ID:              unverifiedTechID,
		Email:           "tecnico.pendiente@reparatutti.com",
		PasswordHash:    string(hash),
		FullName:        "Esteban Rossi",
		PhoneNumber:     "+5491133221100",
		Role:            domain.RoleTechnician,
		AccountStatus:   domain.AccountStatusActive,
		TermsAcceptedAt: time.Now(),
		TermsVersion:    domain.DefaultTermsPlaceholder,
		KYCStatus:       domain.KYCPending,
		Trade:           &tradeGas,
		RatingAverage:   0.00,
		ReviewsCount:    0,
		IsActive:        true,
	}
	_ = userRepo.Create(ctx, unverifiedTech)

	// 4. Sample Job (Agendado with double confirmation)
	jobID := uuid.MustParse("44444444-4444-4444-4444-444444444444")
	now := time.Now()
	agendadoStatus := domain.StatusAgendado
	sampleJob := &domain.Job{
		ID:                    jobID,
		ClientID:              clientID,
		AssignedTechnicianID:  &techID,
		Category:              domain.TradeElectricidad,
		Title:                 "Instalación de disyuntor y recableado de cocina",
		Description:           "Corte térmico frecuente al conectar horno eléctrico. Se necesita cambio de disyuntor diferencial y revisión térmica.",
		GeneralLocality:       "Palermo Soho, CABA",
		PhotosURLs:            []string{"https://images.unsplash.com/photo-1621905251189-08b45d6a269e"},
		ScheduledAt:           now.Add(24 * time.Hour), // 24 hours ahead
		Status:                domain.StatusAgendado,
		ClientConfirmedStatus: &agendadoStatus,
		TechConfirmedStatus:   &agendadoStatus,
		ClientConfirmedAt:     &now,
		TechConfirmedAt:       &now,
		CreatedAt:             now,
		UpdatedAt:             now,
	}
	_ = jobRepo.Create(ctx, sampleJob)

	fmt.Println(">> [Seed] Demo database populated:")
	fmt.Printf("   - Cliente: %s (%s)\n", client.Email, clientID)
	fmt.Printf("   - Técnico Verificado: %s (%s)\n", tech.Email, techID)
	fmt.Printf("   - Técnico Pendiente KYC: %s (%s)\n", unverifiedTech.Email, unverifiedTechID)
	fmt.Printf("   - Trabajo Agendado (Doble Confirmación): %s (%s)\n", sampleJob.Title, jobID)
}
