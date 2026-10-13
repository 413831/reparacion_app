package http

import (
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/reparatutti/backend/internal/config"
)

type VersionResponse struct {
	MinIOSBuild        int    `json:"min_ios_build"`
	MinIOSVersion      string `json:"min_ios_version"`
	MinAndroidBuild    int    `json:"min_android_build"`
	MinAndroidVersion  string `json:"min_android_version"`
	IOSStoreURL        string `json:"ios_store_url"`
	AndroidStoreURL    string `json:"android_store_url"`
	ForceUpdateMessage string `json:"force_update_message"`
	ServerTime         string `json:"server_time"`
}

type VersionHandler struct {
	cfg *config.Config
}

func NewVersionHandler(cfg *config.Config) *VersionHandler {
	return &VersionHandler{cfg: cfg}
}

// GetAppVersionConfig returns operational version policies for Google Play and Apple App Store
func (h *VersionHandler) GetAppVersionConfig(c *gin.Context) {
	c.JSON(http.StatusOK, VersionResponse{
		MinIOSBuild:        h.cfg.MinIOSBuild,
		MinIOSVersion:      h.cfg.MinIOSVersion,
		MinAndroidBuild:    h.cfg.MinAndroidBuild,
		MinAndroidVersion:  h.cfg.MinAndroidVersion,
		IOSStoreURL:        h.cfg.IOSStoreURL,
		AndroidStoreURL:    h.cfg.AndroidStoreURL,
		ForceUpdateMessage: "Para garantizar la seguridad de tus transacciones y la compatibilidad con el sistema de Doble Confirmación, es necesario actualizar Reparatutti a la última versión disponible.",
		ServerTime:         time.Now().UTC().Format(time.RFC3339),
	})
}
