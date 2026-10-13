package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	httpHandlers "github.com/reparatutti/backend/internal/adapters/handlers/http"
	"github.com/reparatutti/backend/internal/adapters/handlers/middleware"
	"github.com/reparatutti/backend/internal/adapters/handlers/ws"
	"github.com/reparatutti/backend/internal/adapters/identity"
	"github.com/reparatutti/backend/internal/adapters/notification"
	"github.com/reparatutti/backend/internal/adapters/payment"
	"github.com/reparatutti/backend/internal/adapters/repository/postgres"
	"github.com/reparatutti/backend/internal/adapters/repository/seed"
	"github.com/reparatutti/backend/internal/config"
	"github.com/reparatutti/backend/internal/core/domain"
	"github.com/reparatutti/backend/internal/core/services"
)

func main() {
	log.Println("==================================================")
	log.Println(" Reparatutti Cloud-Native Backend (Go 1.22+)")
	log.Println(" Clean / Hexagonal Architecture Active")
	log.Println(" DevSecOps & Security Hardening Enabled")
	log.Println("==================================================")

	// 0. Load Environment Configuration (.env & System Env)
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("[FATAL] Configuration load failure: %v", err)
	}
	log.Printf("[Config] Environment: %s | Port: %s | RateLimit: %d RPM", cfg.AppEnv, cfg.Port, cfg.RateLimitRPM)

	// 1. Core Repositories
	userRepo := postgres.NewInMemoryUserRepo()
	kycRepo := postgres.NewInMemoryKYCRepo()
	jobRepo := postgres.NewInMemoryJobRepo()
	proposalRepo := postgres.NewInMemoryProposalRepo()
	chatRepo := postgres.NewInMemoryChatRepo()
	reviewRepo := postgres.NewInMemoryReviewRepo()
	catalogRepo := postgres.NewInMemoryCatalogPriceRepo()

	// 2. Adapters & Ports
	identityVerifier := identity.NewMockIdentityVerifier()
	multichannelNotifier := notification.NewMockMultichannelNotifier(userRepo)
	paymentGateway := payment.NewMockMercadoPagoGateway()

	// 3. Domain Services
	kycService := services.NewKYCService(userRepo, kycRepo, identityVerifier)
	jobService := services.NewJobService(jobRepo, proposalRepo, userRepo, multichannelNotifier, paymentGateway)
	reviewService := services.NewReviewService(reviewRepo, jobRepo, userRepo)
	catalogService := services.NewCatalogService(catalogRepo)

	// 4. Background Scheduled Reminder Service (Ticker)
	reminderScheduler := services.NewReminderSchedulerService(jobRepo, userRepo, multichannelNotifier)
	reminderScheduler.Start(30 * time.Second)

	// 5. WebSocket Hub
	wsHub := ws.NewHub(chatRepo, jobRepo)
	go wsHub.Run()

	// 6. Security Middlewares
	authMw := middleware.NewAuthMiddleware(cfg.JWTSecret)
	rateLimiter := middleware.NewTokenBucketRateLimiter(cfg.RateLimitRPM, cfg.RateLimitBurst)

	// 7. HTTP & WS Handlers
	authHandler := httpHandlers.NewAuthHandler(userRepo, authMw)
	kycHandler := httpHandlers.NewKYCHandler(kycService)
	jobHandler := httpHandlers.NewJobHandler(jobService, jobRepo, proposalRepo)
	reviewHandler := httpHandlers.NewReviewHandler(reviewService)
	userHandler := httpHandlers.NewUserHandler(userRepo)
	catalogHandler := httpHandlers.NewCatalogHandler(catalogService)
	versionHandler := httpHandlers.NewVersionHandler(cfg)
	chatWSHandler := ws.NewChatWSHandler(wsHub, jobRepo)

	// Seed Sample Data for Testing / Demo & App Store Reviewers
	seedDatabase(userRepo, jobRepo)
	if err := seed.SeedReviewerAccounts(context.Background(), userRepo, jobRepo); err != nil {
		log.Printf("[WARNING] Reviewer accounts seed error: %v", err)
	}

	// 8. Gin Engine & Global Security Middlewares
	router := gin.Default()
	router.Use(gin.Recovery())

	// Security Controls:
	// A. Security Headers (OWASP: HSTS, CSP, X-Frame-Options, X-Content-Type-Options, XSS)
	router.Use(middleware.SecurityHeadersMiddleware())
	// B. Token Bucket Rate Limiter (80 RPM capped per IP / User)
	router.Use(rateLimiter.Middleware())

	// Health Check
	router.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"status":    "healthy",
			"timestamp": time.Now().Format(time.RFC3339),
			"version":   "1.2.1-devsecops",
			"env":       cfg.AppEnv,
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

		// Public & Smart Triage Catalog Endpoints
		catalogGroup := api.Group("/catalog")
		{
			catalogGroup.GET("/prices", catalogHandler.GetPrices)
			catalogGroup.GET("/triage", catalogHandler.SmartTriage)
		}

		// Public App Version Policy (Remote Config & Forced Update)
		configGroup := api.Group("/config")
		{
			configGroup.GET("/app-version", versionHandler.GetAppVersionConfig)
		}

		// Authenticated Routes
		protected := api.Group("")
		protected.Use(authMw.Authenticate())
		{
			// User Account Management & Preferences (App Store Guideline 5.1.1 & GDPR)
			userGroup := protected.Group("/users/me")
			{
				userGroup.DELETE("", userHandler.DeleteAccount)
				userGroup.POST("/delete", userHandler.DeleteAccount)
				userGroup.POST("/suspend", userHandler.SuspendAccount)
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
				// 1-Tap Instant Accept with suggested price
				jobsGroup.POST("/:id/instant-accept",
					middleware.RequireRole(domain.RoleTechnician),
					middleware.RequireVerifiedTechnician(),
					jobHandler.InstantAccept,
				)
				jobsGroup.GET("/:id/proposals", jobHandler.ListProposals)

				// Client accepts proposal
				jobsGroup.POST("/:id/accept/:proposal_id", middleware.RequireRole(domain.RoleClient), jobHandler.AcceptProposal)

				// Double Confirmation State Machine Endpoint (Both Client and Tech confirm) + Payment & Warranty
				jobsGroup.POST("/:id/confirm-status", jobHandler.ConfirmStatus)

				// Reviews
				jobsGroup.POST("/:id/review", middleware.RequireRole(domain.RoleClient), reviewHandler.SubmitReview)
			}

			// 1:1 Real-Time Chat WebSocket
			protected.GET("/ws/chat/:job_id", chatWSHandler.HandleChatWS)
		}
	}

	log.Printf("Server listening on port :%s", cfg.Port)
	if err := router.Run(":" + cfg.Port); err != nil {
		log.Fatalf("Server stopped: %v", err)
	}
}

func seedDatabase(userRepo *postgres.InMemoryUserRepo, jobRepo *postgres.InMemoryJobRepo) {
	ctx := context.Background()

	// 1. Client user
	clientID := uuid.MustParse("11111111-1111-1111-1111-111111111111")
	client := &domain.User{
		ID:              clientID,
		Email:           "cliente@reparatutti.com",
		FullName:        "Lucía Fernández",
		PhoneNumber:     "+5491144556677",
		Role:            domain.RoleClient,
		AccountStatus:   domain.AccountStatusActive,
		TermsAcceptedAt: time.Now(),
		TermsVersion:    domain.DefaultTermsPlaceholder,
		KYCStatus:       domain.KYCVerified,
		IsActive:        true,
	}
	_ = client.SetPassword("Password123!")
	_ = userRepo.Create(ctx, client)

	// 2. Verified Technician
	trade := domain.TradeElectricidad
	techID := uuid.MustParse("22222222-2222-2222-2222-222222222222")
	tech := &domain.User{
		ID:              techID,
		Email:           "tecnico.verificado@reparatutti.com",
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
	_ = tech.SetPassword("Password123!")
	_ = userRepo.Create(ctx, tech)

	// 3. Unverified Technician (cannot bid)
	tradeGas := domain.TradeGas
	unverifiedTechID := uuid.MustParse("33333333-3333-3333-3333-333333333333")
	unverifiedTech := &domain.User{
		ID:              unverifiedTechID,
		Email:           "tecnico.pendiente@reparatutti.com",
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
	_ = unverifiedTech.SetPassword("Password123!")
	_ = userRepo.Create(ctx, unverifiedTech)

	// 4. Sample Job 1 (Agendado with double confirmation)
	jobID := uuid.MustParse("44444444-4444-4444-4444-444444444444")
	now := time.Now()
	agendadoStatus := domain.StatusAgendado
	elecPrice := 32000.0
	sampleJob := &domain.Job{
		ID:                    jobID,
		ClientID:              clientID,
		AssignedTechnicianID:  &techID,
		Category:              domain.TradeElectricidad,
		Title:                 "Instalación de disyuntor y recableado de cocina",
		Description:           "Corte térmico frecuente al conectar horno eléctrico. Se necesita cambio de disyuntor diferencial y revisión térmica.",
		GeneralLocality:       "Palermo Soho, CABA",
		PhotosURLs:            []string{"https://images.unsplash.com/photo-1621905251189-08b45d6a269e"},
		ScheduledAt:           now.Add(24 * time.Hour),
		EstimatedPrice:        &elecPrice,
		Status:                domain.StatusAgendado,
		ClientConfirmedStatus: &agendadoStatus,
		TechConfirmedStatus:   &agendadoStatus,
		ClientConfirmedAt:     &now,
		TechConfirmedAt:       &now,
		CreatedAt:             now,
		UpdatedAt:             now,
	}
	_ = jobRepo.Create(ctx, sampleJob)

	// 5. Sample Job 2 (Pendiente de Aceptación con Precio Sugerido para Instant Conversion)
	jobID2 := uuid.MustParse("55555555-5555-5555-5555-555555555555")
	plumbPrice := 28000.0
	sampleJob2 := &domain.Job{
		ID:              jobID2,
		ClientID:        clientID,
		Category:        domain.TradePlomeria,
		Title:           "Gotea la canilla de la cocina",
		Description:     "Pérdida continua de agua en grifería monocomando bajo mesada. Se requiere cambio de vástago o cartucho.",
		GeneralLocality: "Belgrano, CABA",
		PhotosURLs:      []string{"https://images.unsplash.com/photo-1584622650111-993a426fbf0a"},
		ScheduledAt:     now.Add(48 * time.Hour),
		EstimatedPrice:  &plumbPrice,
		Status:          domain.StatusPendienteDeAceptacion,
		CreatedAt:       now.Add(-2 * time.Hour),
		UpdatedAt:       now.Add(-2 * time.Hour),
	}
	_ = jobRepo.Create(ctx, sampleJob2)

	fmt.Println(">> [Seed] Demo database populated:")
	fmt.Printf("   - Cliente: %s (%s)\n", client.Email, clientID)
	fmt.Printf("   - Técnico Verificado: %s (%s)\n", tech.Email, techID)
	fmt.Printf("   - Técnico Pendiente KYC: %s (%s)\n", unverifiedTech.Email, unverifiedTechID)
	fmt.Printf("   - Trabajo 1 (Agendado): %s (%s)\n", sampleJob.Title, jobID)
	fmt.Printf("   - Trabajo 2 (Triage / Precio Sugerido): %s (%s) - $%.2f\n", sampleJob2.Title, jobID2, *sampleJob2.EstimatedPrice)
}
