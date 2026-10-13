package middleware

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"
)

func init() {
	gin.SetMode(gin.TestMode)
}

func TestSecurityHeadersMiddleware(t *testing.T) {
	router := gin.New()
	router.Use(SecurityHeadersMiddleware())
	router.GET("/test", func(c *gin.Context) {
		c.String(http.StatusOK, "ok")
	})

	req, _ := http.NewRequest(http.MethodGet, "/test", nil)
	w := httptest.NewRecorder()
	router.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected status %d, got %d", http.StatusOK, w.Code)
	}

	headers := map[string]string{
		"X-Frame-Options":           "DENY",
		"X-Content-Type-Options":    "nosniff",
		"X-XSS-Protection":          "1; mode=block",
		"Strict-Transport-Security": "max-age=31536000; includeSubDomains; preload",
		"Referrer-Policy":           "strict-origin-when-cross-origin",
	}

	for header, expected := range headers {
		actual := w.Header().Get(header)
		if actual != expected {
			t.Errorf("header %s: expected %q, got %q", header, expected, actual)
		}
	}

	csp := w.Header().Get("Content-Security-Policy")
	if csp == "" {
		t.Errorf("expected Content-Security-Policy header to be set")
	}
}

func TestTokenBucketRateLimiter_Enforcement(t *testing.T) {
	// Limiter with burst capacity of 3 requests for fast testing
	limiter := NewTokenBucketRateLimiter(60, 3)

	router := gin.New()
	router.Use(limiter.Middleware())
	router.GET("/ping", func(c *gin.Context) {
		c.String(http.StatusOK, "pong")
	})

	// Make 3 allowed requests
	for i := 1; i <= 3; i++ {
		req, _ := http.NewRequest(http.MethodGet, "/ping", nil)
		w := httptest.NewRecorder()
		router.ServeHTTP(w, req)

		if w.Code != http.StatusOK {
			t.Fatalf("request #%d should be allowed, got status %d", i, w.Code)
		}
		if w.Header().Get("X-RateLimit-Limit") != "60" {
			t.Errorf("expected X-RateLimit-Limit 60, got %s", w.Header().Get("X-RateLimit-Limit"))
		}
	}

	// 4th request must be rejected with HTTP 429 Too Many Requests
	req, _ := http.NewRequest(http.MethodGet, "/ping", nil)
	w := httptest.NewRecorder()
	router.ServeHTTP(w, req)

	if w.Code != http.StatusTooManyRequests {
		t.Fatalf("request #4 should be rejected with 429, got %d", w.Code)
	}

	retryAfter := w.Header().Get("Retry-After")
	if retryAfter != "60" {
		t.Errorf("expected Retry-After 60, got %s", retryAfter)
	}
}

func TestTokenBucketRateLimiter_AuthenticatedUserKey(t *testing.T) {
	limiter := NewTokenBucketRateLimiter(60, 2)

	router := gin.New()
	// Set mock user_id in gin context
	router.Use(func(c *gin.Context) {
		c.Set("user_id", "user-uuid-999")
		c.Next()
	})
	router.Use(limiter.Middleware())
	router.GET("/profile", func(c *gin.Context) {
		c.String(http.StatusOK, "profile")
	})

	for i := 1; i <= 2; i++ {
		req, _ := http.NewRequest(http.MethodGet, "/profile", nil)
		w := httptest.NewRecorder()
		router.ServeHTTP(w, req)
		if w.Code != http.StatusOK {
			t.Fatalf("authenticated request #%d should pass, got %d", i, w.Code)
		}
	}

	// 3rd request from same authenticated user exceeds burst
	req, _ := http.NewRequest(http.MethodGet, "/profile", nil)
	w := httptest.NewRecorder()
	router.ServeHTTP(w, req)
	if w.Code != http.StatusTooManyRequests {
		t.Fatalf("authenticated request #3 should be rate limited, got %d", w.Code)
	}
}
