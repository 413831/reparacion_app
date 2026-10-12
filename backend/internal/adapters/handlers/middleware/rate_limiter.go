package middleware

import (
	"net/http"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
	"golang.org/x/time/rate"
)

type ipLimiter struct {
	limiter  *rate.Limiter
	lastSeen time.Time
}

// TokenBucketRateLimiter implements an 80 RPM (Requests Per Minute) rate limiter
type TokenBucketRateLimiter struct {
	mu      sync.Mutex
	clients map[string]*ipLimiter
	rate    rate.Limit
	burst   int
}

func NewTokenBucketRateLimiter(rpm int, burst int) *TokenBucketRateLimiter {
	limiter := &TokenBucketRateLimiter{
		clients: make(map[string]*ipLimiter),
		rate:    rate.Every(time.Minute / time.Duration(rpm)),
		burst:   burst,
	}

	// Periodic cleanup of stale IP records every 5 minutes
	go limiter.cleanupStaleEntries()

	return limiter
}

func (l *TokenBucketRateLimiter) getLimiter(ip string) *rate.Limiter {
	l.mu.Lock()
	defer l.mu.Unlock()

	item, exists := l.clients[ip]
	if !exists {
		limiter := rate.NewLimiter(l.rate, l.burst)
		l.clients[ip] = &ipLimiter{limiter: limiter, lastSeen: time.Now()}
		return limiter
	}

	item.lastSeen = time.Now()
	return item.limiter
}

func (l *TokenBucketRateLimiter) cleanupStaleEntries() {
	ticker := time.NewTicker(5 * time.Minute)
	for range ticker.C {
		l.mu.Lock()
		for ip, item := range l.clients {
			if time.Since(item.lastSeen) > 10*time.Minute {
				delete(l.clients, ip)
			}
		}
		l.mu.Unlock()
	}
}

func (l *TokenBucketRateLimiter) Middleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		clientIP := c.ClientIP()
		limiter := l.getLimiter(clientIP)

		if !limiter.Allow() {
			c.AbortWithStatusJSON(http.StatusTooManyRequests, gin.H{
				"error":       "Too many requests. Rate limit is 80 requests per minute.",
				"retry_after": "Wait a few seconds before trying again.",
			})
			return
		}

		c.Next()
	}
}
