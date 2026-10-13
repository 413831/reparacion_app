package http

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/reparatutti/backend/internal/core/domain"
	"github.com/reparatutti/backend/internal/core/services"
)

type CatalogHandler struct {
	catalogService *services.CatalogService
}

func NewCatalogHandler(catalogService *services.CatalogService) *CatalogHandler {
	return &CatalogHandler{
		catalogService: catalogService,
	}
}

// GetPrices returns all benchmark catalog prices
func (h *CatalogHandler) GetPrices(c *gin.Context) {
	categoryStr := c.Query("category")
	if categoryStr != "" {
		prices, err := h.catalogService.GetByCategory(c.Request.Context(), domain.TradeCategory(categoryStr))
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusOK, gin.H{"catalog": prices})
		return
	}

	prices, err := h.catalogService.GetActiveCatalog(c.Request.Context())
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"catalog": prices})
}

// SmartTriage analyzes user input (e.g. 'Gotea la canilla') and infers category and benchmark price
func (h *CatalogHandler) SmartTriage(c *gin.Context) {
	query := c.Query("q")
	if query == "" {
		query = c.Query("query")
	}

	result, err := h.catalogService.InferSmartTriage(c.Request.Context(), query)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"query":  query,
		"triage": result,
	})
}
