package middleware

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/reparatutti/backend/internal/core/domain"
)

// RequireRole ensures that the authenticated user has the specified role
func RequireRole(allowedRoles ...domain.UserRole) gin.HandlerFunc {
	return func(c *gin.Context) {
		roleVal, exists := c.Get("role")
		if !exists {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
			return
		}

		userRole := roleVal.(domain.UserRole)
		for _, allowed := range allowedRoles {
			if userRole == allowed {
				c.Next()
				return
			}
		}

		c.AbortWithStatusJSON(http.StatusForbidden, gin.H{
			"error": "access denied: insufficient permissions for role " + string(userRole),
		})
	}
}

// RequireVerifiedTechnician enforces that technicians must be KYC verified
func RequireVerifiedTechnician() gin.HandlerFunc {
	return func(c *gin.Context) {
		roleVal, existsRole := c.Get("role")
		kycVal, existsKYC := c.Get("kyc_status")

		if !existsRole || !existsKYC {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
			return
		}

		role := roleVal.(domain.UserRole)
		kycStatus := kycVal.(domain.KYCStatus)

		if role == domain.RoleTechnician && kycStatus != domain.KYCVerified {
			c.AbortWithStatusJSON(http.StatusForbidden, gin.H{
				"error":      "technicians must complete identity verification (KYC verified) to perform this action",
				"kyc_status": kycStatus,
			})
			return
		}

		c.Next()
	}
}
