package domain_test

import (
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/reparatutti/backend/internal/core/domain"
)

func TestSmartTriageKeywordMatching(t *testing.T) {
	plumbingPrice := &domain.CatalogPrice{
		ID:              uuid.New(),
		Category:        domain.TradePlomeria,
		ServiceName:     "Reparación de canilla / Grifería",
		KeywordPatterns: []string{"gotea", "canilla", "grifo", "griferia", "cuerito"},
		AveragePrice:    28000.0,
		MinPrice:        20000.0,
		MaxPrice:        38000.0,
		Currency:        "ARS",
		IsActive:        true,
		CreatedAt:       time.Now(),
	}

	tests := []struct {
		query       string
		expectMatch bool
	}{
		{"Gotea la canilla de la cocina", true},
		{"Hola, tengo una canilla rota", true},
		{"Cambio de cuerito en baño", true},
		{"Pintar pared del living", false},
	}

	for _, tt := range tests {
		t.Run(tt.query, func(t *testing.T) {
			score := plumbingPrice.MatchScore(tt.query)
			if tt.expectMatch && score == 0 {
				t.Errorf("expected positive match score for query '%s', got 0", tt.query)
			}
			if !tt.expectMatch && score > 0 {
				t.Errorf("expected 0 match score for unrelated query '%s', got %d", tt.query, score)
			}
		})
	}
}
