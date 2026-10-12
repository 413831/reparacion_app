package domain

import (
	"errors"
	"math"
	"time"

	"github.com/google/uuid"
)

type UserRole string

const (
	RoleClient     UserRole = "client"
	RoleTechnician UserRole = "technician"
	RoleAdmin      UserRole = "admin"
)

type UserAccountStatus string

const (
	AccountStatusActive    UserAccountStatus = "active"
	AccountStatusSuspended UserAccountStatus = "suspended"
	AccountStatusDeleted   UserAccountStatus = "deleted"
)

const DefaultTermsPlaceholder = "[CONFIG_TERMINOS_Y_CONDICIONES_LEGALES]"

type TradeCategory string

const (
	TradeElectricidad        TradeCategory = "electricidad"
	TradePintura             TradeCategory = "pintura"
	TradeGas                 TradeCategory = "gas"
	TradeConstruccion        TradeCategory = "construccion"
	TradeFlete               TradeCategory = "flete"
	TradeReparacionEdilicia  TradeCategory = "reparacion_edilicia"
)

type User struct {
	ID               uuid.UUID         `json:"id"`
	Email            string            `json:"email"`
	PasswordHash     string            `json:"-"`
	FullName         string            `json:"full_name"`
	PhoneNumber      string            `json:"phone_number"`
	Role             UserRole          `json:"role"`
	AccountStatus    UserAccountStatus `json:"account_status"`
	AuthProvider     string            `json:"auth_provider"` // local, google, apple
	AuthProviderID   string            `json:"auth_provider_id,omitempty"`
	AvatarURL        string            `json:"avatar_url,omitempty"`
	TermsAcceptedAt  time.Time         `json:"terms_accepted_at"`
	TermsVersion     string            `json:"terms_version"`
	KYCStatus        KYCStatus         `json:"kyc_status"`
	Trade            *TradeCategory    `json:"trade,omitempty"`
	RatingAverage    float64           `json:"rating_average"`
	ReviewsCount     int               `json:"reviews_count"`
	IsActive         bool              `json:"is_active"`
	CreatedAt        time.Time         `json:"created_at"`
	UpdatedAt        time.Time         `json:"updated_at"`
	DeletedAt        *time.Time        `json:"deleted_at,omitempty"`
}

var (
	ErrUserNotVerified      = errors.New("technician must have KYC status verified to perform this action")
	ErrInvalidRole          = errors.New("invalid user role")
	ErrTermsNotAccepted     = errors.New("terms and conditions under Argentine law must be explicitly accepted")
	ErrInvalidRatingScore   = errors.New("rating score must be between 1 and 5")
)

// CanApplyForJobs validates business rule:
// "Técnicos con estado unverified o pending no pueden postularse a trabajos."
func (u *User) CanApplyForJobs() bool {
	if u.Role != RoleTechnician {
		return false
	}
	isAccountOk := u.AccountStatus == "" || u.AccountStatus == AccountStatusActive
	return u.KYCStatus == KYCVerified && u.IsActive && isAccountOk
}

// CalculateNewRating computes cumulative moving average:
// rating_nuevo = ((rating_actual * N) + score) / (N + 1)
func (u *User) CalculateNewRating(score int) (float64, error) {
	if score < 1 || score > 5 {
		return u.RatingAverage, ErrInvalidRatingScore
	}

	newTotalCount := u.ReviewsCount + 1
	accumulated := (u.RatingAverage * float64(u.ReviewsCount)) + float64(score)
	rawAverage := accumulated / float64(newTotalCount)

	// Round to 2 decimal places for financial/rating consistency
	rounded := math.Round(rawAverage*100) / 100
	return rounded, nil
}
