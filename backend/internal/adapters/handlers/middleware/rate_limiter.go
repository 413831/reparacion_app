package middleware

import (
	"fmt"
	"net/http"
	"strconv"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
	"golang.org/x/time/rate"
)

type clientLimiter struct {
	limiter  *rate.Limiter
	lastSeen time.Time
}

// TokenBucketRateLimiter implements an 80 RPM rate limiter capped per IP and User
type TokenBucketRateLimiter struct {
	mu      sync.Mutex
	clients map[string]*clientLimiter
	rate    rate.Limit
	burst   int
	rpm     int
}

func NewTokenBucketRateLimiter(rpm int, burst int) *TokenBucketRateLimiter {
	limiter := &TokenBucketRateLimiter{
		clients: make(map[string]*clientLimiter),
		rate:    rate.Every(time.Minute / time.Duration(rpm)),
		burst:   burst,
		rpm:     rpm,
	}

	// Periodic cleanup of stale records every 5 minutes
	go limiter.cleanupStaleEntries()

	return limiter
}

func (l *TokenBucketRateLimiter) getLimiter(key string) *rate.Limiter {
	l.mu.Lock()
	defer l.mu.Unlock()

	item, exists := l.clients[key]
	if !exists {
		limiter := rate.NewLimiter(l.rate, l.burst)
		l.clients[key] = &clientLimiter{limiter: limiter, lastSeen: time.Now()}
		return limiter
	}

	item.lastSeen = time.Now()
	return item.limiter
}

func (l *TokenBucketRateLimiter) cleanupStaleEntries() {
	ticker := time.NewTicker(5 * time.Minute)
	for range ticker.C {
		l.mu.Lock()
		for key, item := range l.clients {
			if time.Since(item.lastSeen) > 10*time.Minute {
				delete(l.clients, key)
			}
		}
		l.mu.Unlock()
	}
}

func (l *TokenBucketRateLimiter) Middleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		// Identify client either by authenticated user ID or by client IP address
		key := "ip:" + c.ClientIP()
		if userID, exists := c.Get("user_id"); exists {
			key = fmt.Sprintf("user:%v", userID)
		}

		limiter := l.getLimiter(key)

		// Set rate limit headers
		c.Header("X-RateLimit-Limit", strconv.Itoa(l.rpm))

		if !limiter.Allow() {
			c.Header("Retry-After", "60")
			c.Header("X-RateLimit-Remaining", "0")

			c.AbortWithStatusJSON(http.StatusTooManyRequests, gin.H{
				"error":       "Too many requests. Rate limit is 80 requests per minute.",
				"status":      http.StatusTooManyRequests,
				"retry_after": 60,
			})
			return
		}

		c.Next()
	}
}
