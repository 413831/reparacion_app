package domain_test

import (
	"testing"

	"github.com/google/uuid"
	"github.com/reparatutti/backend/internal/core/domain"
)

func TestUserPasswordHashingAndValidation(t *testing.T) {
	u := &domain.User{
		ID:    uuid.New(),
		Email: "seguridad@reparatutti.com",
	}

	// 1. Rejection of empty password
	errEmpty := u.SetPassword("")
	if errEmpty != domain.ErrPasswordEmpty {
		t.Errorf("expected ErrPasswordEmpty, got: %v", errEmpty)
	}

	// 2. Rejection of password shorter than 8 characters
	errShort := u.SetPassword("short")
	if errShort != domain.ErrPasswordTooShort {
		t.Errorf("expected ErrPasswordTooShort, got: %v", errShort)
	}

	// 3. Valid password hashing
	plainPassword := "SuperSecurePass2026!"
	err := u.SetPassword(plainPassword)
	if err != nil {
		t.Fatalf("unexpected error setting password: %v", err)
	}

	if u.PasswordHash == "" || u.PasswordHash == plainPassword {
		t.Errorf("password must be securely hashed and not stored in plaintext")
	}

	// 4. Correct password verification
	if !u.CheckPassword(plainPassword) {
		t.Errorf("CheckPassword failed to authenticate valid password")
	}

	// 5. Wrong password verification
	if u.CheckPassword("WrongPassword123!") {
		t.Errorf("CheckPassword must reject invalid password")
	}
}
