package postgres

import (
	"context"
	"errors"
	"sync"
	"time"

	"github.com/google/uuid"
	"github.com/reparatutti/backend/internal/core/domain"
	"github.com/reparatutti/backend/internal/core/ports"
)

type InMemoryCatalogPriceRepo struct {
	mu     sync.RWMutex
	prices map[uuid.UUID]*domain.CatalogPrice
}

func NewInMemoryCatalogPriceRepo() *InMemoryCatalogPriceRepo {
	repo := &InMemoryCatalogPriceRepo{
		prices: make(map[uuid.UUID]*domain.CatalogPrice),
	}
	repo.seedInitialCatalog()
	return repo
}

func (r *InMemoryCatalogPriceRepo) seedInitialCatalog() {
	now := time.Now()
	seeds := []*domain.CatalogPrice{
		{
			ID:                     uuid.New(),
			Category:               domain.TradePlomeria,
			ServiceName:            "Destapar cañería / Desagote",
			KeywordPatterns:        []string{"destapar", "cañeria", "caño", "desague", "cloaca", "tapada", "inodoro"},
			AveragePrice:           40000.0,
			MinPrice:               30000.0,
			MaxPrice:               55000.0,
			Currency:               "ARS",
			EstimatedDurationHours: 2,
			Description:            "Servicio estándar de desobstrucción mecánica o química de cañerías",
			IsActive:               true,
			CreatedAt:              now,
			UpdatedAt:              now,
		},
		{
			ID:                     uuid.New(),
			Category:               domain.TradePlomeria,
			ServiceName:            "Reparación de canilla / Grifería",
			KeywordPatterns:        []string{"gotea", "canilla", "grifo", "griferia", "monocomando", "cuerito", "fuga de agua"},
			AveragePrice:           28000.0,
			MinPrice:               20000.0,
			MaxPrice:               38000.0,
			Currency:               "ARS",
			EstimatedDurationHours: 1,
			Description:            "Cambio de vástago, cuerito o cartucho monocomando con prueba de estanqueidad",
			IsActive:               true,
			CreatedAt:              now,
			UpdatedAt:              now,
		},
		{
			ID:                     uuid.New(),
			Category:               domain.TradeElectricidad,
			ServiceName:            "Cambio de disyuntor / Térmica",
			KeywordPatterns:        []string{"disyuntor", "termica", "corte de luz", "tablero", "salta la termica", "llave termomagnetica"},
			AveragePrice:           32000.0,
			MinPrice:               24000.0,
			MaxPrice:               46000.0,
			Currency:               "ARS",
			EstimatedDurationHours: 2,
			Description:            "Reemplazo y dimensionamiento de protecciones en tablero seccional",
			IsActive:               true,
			CreatedAt:              now,
			UpdatedAt:              now,
		},
		{
			ID:                     uuid.New(),
			Category:               domain.TradeElectricidad,
			ServiceName:            "Instalación de luminaria / Ventilador",
			KeywordPatterns:        []string{"lampara", "luz", "ventilador", "aplique", "led", "cableado"},
			AveragePrice:           26000.0,
			MinPrice:               18000.0,
			MaxPrice:               38000.0,
			Currency:               "ARS",
			EstimatedDurationHours: 2,
			Description:            "Colocación segura de artefacto lumínico con verificación de puesta a tierra",
			IsActive:               true,
			CreatedAt:              now,
			UpdatedAt:              now,
		},
		{
			ID:                     uuid.New(),
			Category:               domain.TradeGas,
			ServiceName:            "Instalación / Reparación de estufa",
			KeywordPatterns:        []string{"estufa", "calefactor", "tiro balanceado", "olor a gas", "calefaccion", "piloto"},
			AveragePrice:           45000.0,
			MinPrice:               35000.0,
			MaxPrice:               60000.0,
			Currency:               "ARS",
			EstimatedDurationHours: 3,
			Description:            "Revisión y habilitación por gasista matriculado con detección de fugas",
			IsActive:               true,
			CreatedAt:              now,
			UpdatedAt:              now,
		},
		{
			ID:                     uuid.New(),
			Category:               domain.TradeGas,
			ServiceName:            "Reparación de calefón / Termotanque",
			KeywordPatterns:        []string{"calefon", "termotanque", "agua caliente", "no enciende", "termostato"},
			AveragePrice:           42000.0,
			MinPrice:               32000.0,
			MaxPrice:               58000.0,
			Currency:               "ARS",
			EstimatedDurationHours: 2,
			Description:            "Limpieza de quemador, cambio de termocupla o diafragma",
			IsActive:               true,
			CreatedAt:              now,
			UpdatedAt:              now,
		},
		{
			ID:                     uuid.New(),
			Category:               domain.TradePintura,
			ServiceName:            "Pintura de ambiente estándar (hasta 15m²)",
			KeywordPatterns:        []string{"pintar", "pintura", "pared", "techo", "enduido", "humedad"},
			AveragePrice:           75000.0,
			MinPrice:               60000.0,
			MaxPrice:               98000.0,
			Currency:               "ARS",
			EstimatedDurationHours: 8,
			Description:            "Preparación de muros, lijado, sellador y dos manos de látex lavable",
			IsActive:               true,
			CreatedAt:              now,
			UpdatedAt:              now,
		},
		{
			ID:                     uuid.New(),
			Category:               domain.TradeFlete,
			ServiceName:            "Flete urbano corto (hasta 15km)",
			KeywordPatterns:        []string{"flete", "mudanza", "traslado", "camioneta", "cajas", "muebles"},
			AveragePrice:           38000.0,
			MinPrice:               28000.0,
			MaxPrice:               50000.0,
			Currency:               "ARS",
			EstimatedDurationHours: 2,
			Description:            "Traslado puerta a puerta con ayudante para carga y descarga ligera",
			IsActive:               true,
			CreatedAt:              now,
			UpdatedAt:              now,
		},
		{
			ID:                     uuid.New(),
			Category:               domain.TradeReparacionEdilicia,
			ServiceName:            "Reparación de persiana / Cortina",
			KeywordPatterns:        []string{"persiana", "cinta", "enrollar", "traba", "cortina de rollo"},
			AveragePrice:           29000.0,
			MinPrice:               22000.0,
			MaxPrice:               40000.0,
			Currency:               "ARS",
			EstimatedDurationHours: 2,
			Description:            "Cambio de cinta, enrollador o sustitución de varillas rotas",
			IsActive:               true,
			CreatedAt:              now,
			UpdatedAt:              now,
		},
	}

	for _, s := range seeds {
		r.prices[s.ID] = s
	}
}

func (r *InMemoryCatalogPriceRepo) Create(ctx context.Context, price *domain.CatalogPrice) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	cp := *price
	r.prices[price.ID] = &cp
	return nil
}

func (r *InMemoryCatalogPriceRepo) ListActive(ctx context.Context) ([]*domain.CatalogPrice, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	res := make([]*domain.CatalogPrice, 0, len(r.prices))
	for _, p := range r.prices {
		if p.IsActive {
			cp := *p
			res = append(res, &cp)
		}
	}
	return res, nil
}

func (r *InMemoryCatalogPriceRepo) GetByCategory(ctx context.Context, category domain.TradeCategory) ([]*domain.CatalogPrice, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	res := make([]*domain.CatalogPrice, 0)
	for _, p := range r.prices {
		if p.IsActive && p.Category == category {
			cp := *p
			res = append(res, &cp)
		}
	}
	return res, nil
}

func (r *InMemoryCatalogPriceRepo) GetByID(ctx context.Context, id uuid.UUID) (*domain.CatalogPrice, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	p, exists := r.prices[id]
	if !exists {
		return nil, errors.New("catalog price not found")
	}
	cp := *p
	return &cp, nil
}

var _ ports.CatalogPriceRepository = (*InMemoryCatalogPriceRepo)(nil)
