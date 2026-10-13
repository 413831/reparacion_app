package config

import (
	"os"
	"testing"
)

func TestConfigLoad_DefaultValues(t *testing.T) {
	// Clear specific env vars
	os.Unsetenv("PORT")
	os.Unsetenv("APP_ENV")
	os.Unsetenv("JWT_SECRET")
	os.Unsetenv("RATE_LIMIT_RPM")

	cfg, err := Load()
	if err != nil {
		t.Fatalf("unexpected error loading config: %v", err)
	}

	if cfg.Port != "8080" {
		t.Errorf("expected default Port 8080, got %s", cfg.Port)
	}

	if cfg.RateLimitRPM != 80 {
		t.Errorf("expected default RateLimitRPM 80, got %d", cfg.RateLimitRPM)
	}

	if cfg.AppEnv != "development" {
		t.Errorf("expected default AppEnv development, got %s", cfg.AppEnv)
	}
}

func TestConfigLoad_EnvironmentOverride(t *testing.T) {
	t.Setenv("PORT", "9090")
	t.Setenv("RATE_LIMIT_RPM", "120")
	t.Setenv("JWT_SECRET", "super-secret-jwt-key")
	t.Setenv("APP_ENV", "staging")

	cfg, err := Load()
	if err != nil {
		t.Fatalf("unexpected error loading config: %v", err)
	}

	if cfg.Port != "9090" {
		t.Errorf("expected Port 9090, got %s", cfg.Port)
	}
	if cfg.RateLimitRPM != 120 {
		t.Errorf("expected RateLimitRPM 120, got %d", cfg.RateLimitRPM)
	}
	if cfg.JWTSecret != "super-secret-jwt-key" {
		t.Errorf("expected custom JWTSecret, got %s", cfg.JWTSecret)
	}
}

func TestConfigLoad_ProductionMissingJWTSecret(t *testing.T) {
	t.Setenv("APP_ENV", "production")
	t.Setenv("JWT_SECRET", "")

	_, err := Load()
	if err == nil {
		t.Fatal("expected error in production mode when JWT_SECRET is missing, got nil")
	}
}
