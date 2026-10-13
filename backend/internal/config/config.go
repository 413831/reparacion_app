package config

import (
	"fmt"
	"log"
	"os"
	"strconv"

	"github.com/joho/godotenv"
)

type Config struct {
	Port                   string
	AppEnv                 string
	JWTSecret              string
	RateLimitRPM           int
	RateLimitBurst         int
	DatabaseURL            string
	DBHost                 string
	DBPort                 string
	DBUser                 string
	DBPassword             string
	DBName                 string
	DBSSLMode              string
	MercadoPagoAccessToken string
	MinIOSBuild            int
	MinAndroidBuild        int
	MinIOSVersion          string
	MinAndroidVersion      string
	IOSStoreURL            string
	AndroidStoreURL        string
}

// Load loads configuration from environment variables and optionally from a .env file
func Load() (*Config, error) {
	// Attempt loading .env if present (non-fatal if missing, e.g. in cloud/container environments)
	if err := godotenv.Load(); err != nil {
		if os.IsNotExist(err) {
			log.Println("[Config] No .env file found; falling back to system environment variables")
		} else {
			log.Printf("[Config] Notice loading .env: %v", err)
		}
	}

	cfg := &Config{
		Port:                   getEnv("PORT", "8080"),
		AppEnv:                 getEnv("APP_ENV", "development"),
		JWTSecret:              getEnv("JWT_SECRET", ""),
		RateLimitRPM:           getEnvAsInt("RATE_LIMIT_RPM", 80),
		RateLimitBurst:         getEnvAsInt("RATE_LIMIT_BURST", 20),
		DBHost:                 getEnv("DB_HOST", "localhost"),
		DBPort:                 getEnv("DB_PORT", "5432"),
		DBUser:                 getEnv("DB_USER", "postgres"),
		DBPassword:             getEnv("DB_PASSWORD", ""),
		DBName:                 getEnv("DB_NAME", "reparatutti_db"),
		DBSSLMode:              getEnv("DB_SSLMODE", "disable"),
		MercadoPagoAccessToken: getEnv("MERCADOPAGO_ACCESS_TOKEN", "mock_mp_access_token_dev"),
		MinIOSBuild:            getEnvAsInt("MIN_IOS_BUILD", 1),
		MinAndroidBuild:        getEnvAsInt("MIN_ANDROID_BUILD", 1),
		MinIOSVersion:          getEnv("MIN_IOS_VERSION", "1.0.0"),
		MinAndroidVersion:      getEnv("MIN_ANDROID_VERSION", "1.0.0"),
		IOSStoreURL:            getEnv("IOS_STORE_URL", "https://apps.apple.com/app/reparatutti/id1234567890"),
		AndroidStoreURL:        getEnv("ANDROID_STORE_URL", "https://play.google.com/store/apps/details?id=com.reparatutti.app"),
	}

	// DevSecOps Guard: Fail or warn if JWT Secret is empty or default in production
	if cfg.JWTSecret == "" {
		if cfg.AppEnv == "production" {
			return nil, fmt.Errorf("CRITICAL SECURITY VIOLATION: JWT_SECRET environment variable is missing in production")
		}
		log.Println("[Config] WARNING: JWT_SECRET not set; using development fallback secret. NEVER use in production!")
		cfg.JWTSecret = "dev-reparatutti-jwt-secret-do-not-use-in-production-2026"
	}

	// Build Database URL if not provided directly
	cfg.DatabaseURL = getEnv("DATABASE_URL", "")
	if cfg.DatabaseURL == "" {
		cfg.DatabaseURL = fmt.Sprintf(
			"postgres://%s:%s@%s:%s/%s?sslmode=%s",
			cfg.DBUser, cfg.DBPassword, cfg.DBHost, cfg.DBPort, cfg.DBName, cfg.DBSSLMode,
		)
	}

	return cfg, nil
}

func getEnv(key, defaultVal string) string {
	if val, exists := os.LookupEnv(key); exists && val != "" {
		return val
	}
	return defaultVal
}

func getEnvAsInt(key string, defaultVal int) int {
	valStr := getEnv(key, "")
	if val, err := strconv.Atoi(valStr); err == nil {
		return val
	}
	return defaultVal
}
