package domain

import (
	"strings"
	"time"

	"github.com/google/uuid"
)

type CatalogPrice struct {
	ID                     uuid.UUID     `json:"id"`
	Category               TradeCategory `json:"category"`
	ServiceName            string        `json:"service_name"`
	KeywordPatterns        []string      `json:"keyword_patterns"`
	AveragePrice           float64       `json:"average_price"`
	MinPrice               float64       `json:"min_price"`
	MaxPrice               float64       `json:"max_price"`
	Currency               string        `json:"currency"`
	EstimatedDurationHours int           `json:"estimated_duration_hours"`
	Description            string        `json:"description,omitempty"`
	IsActive               bool          `json:"is_active"`
	CreatedAt              time.Time     `json:"created_at"`
	UpdatedAt              time.Time     `json:"updated_at"`
}

type TriageResult struct {
	SuggestedCategory   TradeCategory `json:"suggested_category"`
	CategoryDisplayName string        `json:"category_display_name"`
	ServiceName         string        `json:"service_name"`
	EstimatedAverage    float64       `json:"estimated_average"`
	MinPrice            float64       `json:"min_price"`
	MaxPrice            float64       `json:"max_price"`
	Currency            string        `json:"currency"`
	ConfidenceScore     float64       `json:"confidence_score"`
	MatchedCatalogID    *uuid.UUID    `json:"matched_catalog_id,omitempty"`
}

// MatchScore checks if the query contains any of the keyword patterns and returns a score
func (cp *CatalogPrice) MatchScore(normalizedQuery string) int {
	score := 0
	lowerQuery := strings.ToLower(normalizedQuery)

	for _, kw := range cp.KeywordPatterns {
		lowerKw := strings.ToLower(strings.TrimSpace(kw))
		if lowerKw == "" {
			continue
		}
		if strings.Contains(lowerQuery, lowerKw) {
			score += 10
		}
	}

	// Also check against service name words
	serviceWords := strings.Fields(strings.ToLower(cp.ServiceName))
	for _, word := range serviceWords {
		if len(word) > 3 && strings.Contains(lowerQuery, word) {
			score += 5
		}
	}

	return score
}
