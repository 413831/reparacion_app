package http

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/reparatutti/backend/internal/adapters/repository/postgres"
	"github.com/reparatutti/backend/internal/adapters/repository/seed"
	"github.com/reparatutti/backend/internal/config"
	"github.com/reparatutti/backend/internal/core/domain"
)

func init() {
	gin.SetMode(gin.TestMode)
}

func TestVersionHandler_GetAppVersionConfig(t *testing.T) {
	cfg := &config.Config{
		MinIOSBuild:       10,
		MinIOSVersion:     "1.0.0",
		MinAndroidBuild:   12,
		MinAndroidVersion: "1.0.0",
		IOSStoreURL:       "https://apps.apple.com/app/reparatutti/id1234567890",
		AndroidStoreURL:   "https://play.google.com/store/apps/details?id=com.reparatutti.app",
	}

	handler := NewVersionHandler(cfg)
	router := gin.New()
	router.GET("/api/v1/config/app-version", handler.GetAppVersionConfig)

	req, _ := http.NewRequest(http.MethodGet, "/api/v1/config/app-version", nil)
	w := httptest.NewRecorder()
	router.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", w.Code)
	}

	var resp VersionResponse
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}

	if resp.MinIOSBuild != 10 || resp.MinAndroidBuild != 12 {
		t.Errorf("mismatched build requirements: %+v", resp)
	}
	if resp.IOSStoreURL != cfg.IOSStoreURL || resp.AndroidStoreURL != cfg.AndroidStoreURL {
		t.Errorf("mismatched store urls: %+v", resp)
	}
	if resp.ForceUpdateMessage == "" {
		t.Errorf("expected force_update_message to be populated")
	}
}

func TestUserHandler_DeleteAccount_Anonymization(t *testing.T) {
	ctx := context.Background()
	userRepo := postgres.NewInMemoryUserRepo()

	userID := uuid.New()
	user := &domain.User{
		ID:            userID,
		Email:         "real.user@gmail.com",
		FullName:      "Juan Perez",
		PhoneNumber:   "+5491122334455",
		Role:          domain.RoleClient,
		AccountStatus: domain.AccountStatusActive,
		IsActive:      true,
	}
	_ = userRepo.Create(ctx, user)

	handler := NewUserHandler(userRepo)
	router := gin.New()
	router.DELETE("/api/v1/users/me", func(c *gin.Context) {
		c.Set("user_id", userID)
		handler.DeleteAccount(c)
	})

	req, _ := http.NewRequest(http.MethodDelete, "/api/v1/users/me", nil)
	w := httptest.NewRecorder()
	router.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d: %s", w.Code, w.Body.String())
	}

	// Verify User has been anonymized in the repository
	updatedUser, err := userRepo.GetByID(ctx, userID)
	if err != nil {
		t.Fatalf("failed to retrieve deleted user: %v", err)
	}

	if updatedUser.AccountStatus != domain.AccountStatusDeleted {
		t.Errorf("expected AccountStatusDeleted, got %s", updatedUser.AccountStatus)
	}
	if updatedUser.IsActive {
		t.Errorf("expected user IsActive to be false")
	}
	if updatedUser.DeletedAt == nil {
		t.Errorf("expected DeletedAt timestamp to be set")
	}
	if updatedUser.FullName != "Usuario Eliminado" {
		t.Errorf("expected anonymized FullName, got %s", updatedUser.FullName)
	}
	if updatedUser.Email == "real.user@gmail.com" {
		t.Errorf("expected anonymized email, got original email")
	}
}

func TestReviewerSeeds_Verification(t *testing.T) {
	ctx := context.Background()
	userRepo := postgres.NewInMemoryUserRepo()
	jobRepo := postgres.NewInMemoryJobRepo()

	err := seed.SeedReviewerAccounts(ctx, userRepo, jobRepo)
	if err != nil {
		t.Fatalf("unexpected seed error: %v", err)
	}

	// Verify Technician Reviewer exists and has KYCVerified
	tech, err := userRepo.GetByEmail(ctx, seed.TechReviewerEmail)
	if err != nil {
		t.Fatalf("tech reviewer not found: %v", err)
	}
	if tech.Role != domain.RoleTechnician {
		t.Errorf("expected RoleTechnician, got %s", tech.Role)
	}
	if tech.KYCStatus != domain.KYCVerified {
		t.Errorf("expected KYCVerified for reviewer, got %s", tech.KYCStatus)
	}
	if !tech.CanApplyForJobs() {
		t.Errorf("expected technician reviewer to be eligible to apply for jobs without friction")
	}

	// Verify Client Reviewer exists
	client, err := userRepo.GetByEmail(ctx, seed.ClientReviewerEmail)
	if err != nil {
		t.Fatalf("client reviewer not found: %v", err)
	}
	if client.Role != domain.RoleClient {
		t.Errorf("expected RoleClient, got %s", client.Role)
	}
}
