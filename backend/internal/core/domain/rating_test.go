package domain_test

import (
	"math"
	"testing"

	"github.com/google/uuid"
	"github.com/reparatutti/backend/internal/core/domain"
)

func TestRatingFormula(t *testing.T) {
	tests := []struct {
		name         string
		initialAvg   float64
		initialCount int
		score        int
		expected     float64
	}{
		{
			name:         "First review with 5 stars",
			initialAvg:   0.0,
			initialCount: 0,
			score:        5,
			expected:     5.0,
		},
		{
			name:         "Current 4.0 with 1 review, new score 5",
			initialAvg:   4.0,
			initialCount: 1,
			score:        5,
			expected:     4.5, // ((4.0 * 1) + 5) / 2 = 9 / 2 = 4.5
		},
		{
			name:         "Current 4.80 with 10 reviews, new score 3",
			initialAvg:   4.80,
			initialCount: 10,
			score:        3,
			expected:     4.64, // ((4.80 * 10) + 3) / 11 = 51 / 11 = 4.6363... -> 4.64
		},
		{
			name:         "Current 5.0 with 4 reviews, new score 1",
			initialAvg:   5.0,
			initialCount: 4,
			score:        1,
			expected:     4.20, // ((5.0 * 4) + 1) / 5 = 21 / 5 = 4.2
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			u := &domain.User{
				ID:            uuid.New(),
				RatingAverage: tt.initialAvg,
				ReviewsCount:  tt.initialCount,
			}

			newRating, err := u.CalculateNewRating(tt.score)
			if err != nil {
				t.Fatalf("unexpected error: %v", err)
			}

			if math.Abs(newRating-tt.expected) > 0.01 {
				t.Errorf("expected rating %.2f, got %.2f", tt.expected, newRating)
			}
		})
	}
}

func TestRatingFormula_InvalidScore(t *testing.T) {
	u := &domain.User{
		RatingAverage: 4.5,
		ReviewsCount:  2,
	}

	_, errLow := u.CalculateNewRating(0)
	if errLow != domain.ErrInvalidRatingScore {
		t.Errorf("expected ErrInvalidRatingScore for 0, got %v", errLow)
	}

	_, errHigh := u.CalculateNewRating(6)
	if errHigh != domain.ErrInvalidRatingScore {
		t.Errorf("expected ErrInvalidRatingScore for 6, got %v", errHigh)
	}
}

func TestTechnicianKYCGuard(t *testing.T) {
	techUnverified := &domain.User{
		Role:      domain.RoleTechnician,
		KYCStatus: domain.KYCUnverified,
		IsActive:  true,
	}
	if techUnverified.CanApplyForJobs() {
		t.Errorf("unverified technician should NOT be allowed to apply for jobs")
	}

	techPending := &domain.User{
		Role:      domain.RoleTechnician,
		KYCStatus: domain.KYCPending,
		IsActive:  true,
	}
	if techPending.CanApplyForJobs() {
		t.Errorf("pending technician should NOT be allowed to apply for jobs")
	}

	techVerified := &domain.User{
		Role:      domain.RoleTechnician,
		KYCStatus: domain.KYCVerified,
		IsActive:  true,
	}
	if !techVerified.CanApplyForJobs() {
		t.Errorf("verified technician MUST be allowed to apply for jobs")
	}

	client := &domain.User{
		Role:      domain.RoleClient,
		KYCStatus: domain.KYCVerified,
		IsActive:  true,
	}
	if client.CanApplyForJobs() {
		t.Errorf("clients must NOT apply for jobs even if verified")
	}
}
