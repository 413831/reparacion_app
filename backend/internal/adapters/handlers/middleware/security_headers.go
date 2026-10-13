package middleware

import (
	"github.com/gin-gonic/gin"
)

// SecurityHeadersMiddleware injects industry-standard HTTP security headers
// to protect against XSS, clickjacking, MIME sniffing, and MITM attacks.
func SecurityHeadersMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		// Prevent Clickjacking
		c.Header("X-Frame-Options", "DENY")

		// Prevent MIME-sniffing
		c.Header("X-Content-Type-Options", "nosniff")

		// XSS Filter Protection (Legacy browsers support)
		c.Header("X-XSS-Protection", "1; mode=block")

		// HTTP Strict Transport Security (HSTS) - Enforce HTTPS for 1 year with subdomains
		c.Header("Strict-Transport-Security", "max-age=31536000; includeSubDomains; preload")

		// Restrict Referrer information
		c.Header("Referrer-Policy", "strict-origin-when-cross-origin")

		// Content Security Policy (CSP)
		c.Header("Content-Security-Policy", "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; object-src 'none'; frame-ancestors 'none'; base-uri 'self';")

		// Permissions Policy (formerly Feature-Policy)
		c.Header("Permissions-Policy", "geolocation=(self), microphone=(), camera=()")

		c.Next()
	}
}
