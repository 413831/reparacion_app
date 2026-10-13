package services

import (
	"context"
	"strings"

	"github.com/reparatutti/backend/internal/core/domain"
	"github.com/reparatutti/backend/internal/core/ports"
)

type CatalogService struct {
	catalogRepo ports.CatalogPriceRepository
}

func NewCatalogService(catalogRepo ports.CatalogPriceRepository) *CatalogService {
	return &CatalogService{
		catalogRepo: catalogRepo,
	}
}

func (s *CatalogService) GetActiveCatalog(ctx context.Context) ([]*domain.CatalogPrice, error) {
	return s.catalogRepo.ListActive(ctx)
}

func (s *CatalogService) GetByCategory(ctx context.Context, category domain.TradeCategory) ([]*domain.CatalogPrice, error) {
	return s.catalogRepo.GetByCategory(ctx, category)
}

func (s *CatalogService) InferSmartTriage(ctx context.Context, rawQuery string) (*domain.TriageResult, error) {
	cleanQuery := strings.TrimSpace(rawQuery)
	if cleanQuery == "" {
		// Return general default if empty
		return &domain.TriageResult{
			SuggestedCategory:   domain.TradePlomeria,
			CategoryDisplayName: "Plomería",
			ServiceName:         "Revisión y diagnóstico general",
			EstimatedAverage:    25000.0,
			MinPrice:            18000.0,
			MaxPrice:            35000.0,
			Currency:            "ARS",
			ConfidenceScore:     0.50,
		}, nil
	}

	catalog, err := s.catalogRepo.ListActive(ctx)
	if err != nil {
		return nil, err
	}

	var bestMatch *domain.CatalogPrice
	highestScore := 0

	for _, item := range catalog {
		score := item.MatchScore(cleanQuery)
		if score > highestScore {
			highestScore = score
			bestMatch = item
		}
	}

	if bestMatch != nil && highestScore > 0 {
		confidence := 0.70 + float64(highestScore)*0.02
		if confidence > 0.99 {
			confidence = 0.99
		}
		return &domain.TriageResult{
			SuggestedCategory:   bestMatch.Category,
			CategoryDisplayName: formatCategoryDisplay(bestMatch.Category),
			ServiceName:         bestMatch.ServiceName,
			EstimatedAverage:    bestMatch.AveragePrice,
			MinPrice:            bestMatch.MinPrice,
			MaxPrice:            bestMatch.MaxPrice,
			Currency:            bestMatch.Currency,
			ConfidenceScore:     confidence,
			MatchedCatalogID:    &bestMatch.ID,
		}, nil
	}

	// Fallback heuristic based on generic trade keywords
	lower := strings.ToLower(cleanQuery)
	switch {
	case strings.Contains(lower, "agua") || strings.Contains(lower, "bomba") || strings.Contains(lower, "caño") || strings.Contains(lower, "fuga"):
		return &domain.TriageResult{
			SuggestedCategory:   domain.TradePlomeria,
			CategoryDisplayName: "Plomería",
			ServiceName:         "Servicio general de plomería",
			EstimatedAverage:    30000.0,
			MinPrice:            22000.0,
			MaxPrice:            42000.0,
			Currency:            "ARS",
			ConfidenceScore:     0.65,
		}, nil
	case strings.Contains(lower, "luz") || strings.Contains(lower, "corriente") || strings.Contains(lower, "cable") || strings.Contains(lower, "enchufe"):
		return &domain.TriageResult{
			SuggestedCategory:   domain.TradeElectricidad,
			CategoryDisplayName: "Electricidad",
			ServiceName:         "Reparación eléctrica general",
			EstimatedAverage:    28000.0,
			MinPrice:            20000.0,
			MaxPrice:            38000.0,
			Currency:            "ARS",
			ConfidenceScore:     0.65,
		}, nil
	case strings.Contains(lower, "gas") || strings.Contains(lower, "calefón") || strings.Contains(lower, "cocina"):
		return &domain.TriageResult{
			SuggestedCategory:   domain.TradeGas,
			CategoryDisplayName: "Gas",
			ServiceName:         "Revisión por gasista matriculado",
			EstimatedAverage:    40000.0,
			MinPrice:            30000.0,
			MaxPrice:            55000.0,
			Currency:            "ARS",
			ConfidenceScore:     0.65,
		}, nil
	default:
		return &domain.TriageResult{
			SuggestedCategory:   domain.TradeReparacionEdilicia,
			CategoryDisplayName: "Reparación Edilicia",
			ServiceName:         "Mantenimiento y reparación",
			EstimatedAverage:    30000.0,
			MinPrice:            20000.0,
			MaxPrice:            45000.0,
			Currency:            "ARS",
			ConfidenceScore:     0.55,
		}, nil
	}
}

func formatCategoryDisplay(c domain.TradeCategory) string {
	switch c {
	case domain.TradePlomeria:
		return "Plomería"
	case domain.TradeElectricidad:
		return "Electricidad"
	case domain.TradePintura:
		return "Pintura"
	case domain.TradeGas:
		return "Gas"
	case domain.TradeConstruccion:
		return "Construcción"
	case domain.TradeFlete:
		return "Flete"
	case domain.TradeReparacionEdilicia:
		return "Reparación Edilicia"
	default:
		return string(c)
	}
}
