-- ==============================================================================
-- REPARATUTTI MVP - PostgreSQL Production Schema
-- Designed for High Concurrency, Data Integrity & Strict Role Auditing
-- ==============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ------------------------------------------------------------------------------
-- ENUM TYPES
-- ------------------------------------------------------------------------------
DO $$ BEGIN
    CREATE TYPE user_role AS ENUM ('client', 'technician', 'admin');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE kyc_status AS ENUM ('unverified', 'pending', 'verified', 'rejected');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE kyc_document_type AS ENUM ('dni_front', 'dni_back', 'selfie_liveness');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE trade_category AS ENUM (
        'electricidad',
        'pintura',
        'gas',
        'construccion',
        'flete',
        'reparacion_edilicia'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE job_status AS ENUM (
        'published',
        'in_bidding',
        'assigned',
        'in_progress',
        'completed',
        'cancelled'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE proposal_status AS ENUM (
        'pending',
        'accepted',
        'rejected',
        'withdrawn'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE message_type AS ENUM (
        'text',
        'location',
        'system',
        'image'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- ------------------------------------------------------------------------------
-- 1. USERS TABLE
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255), -- Nullable for pure OAuth users
    full_name VARCHAR(120) NOT NULL,
    phone_number VARCHAR(30),
    role user_role NOT NULL DEFAULT 'client',
    auth_provider VARCHAR(50) NOT NULL DEFAULT 'local', -- local, google, apple
    auth_provider_id VARCHAR(255),
    avatar_url TEXT,
    
    -- Legal & KYC State
    terms_accepted_at TIMESTAMPTZ NOT NULL,
    terms_version VARCHAR(20) NOT NULL DEFAULT '1.0-AR',
    kyc_status kyc_status NOT NULL DEFAULT 'unverified',
    
    -- Technician specific metrics (cached & denormalized for speed)
    trade trade_category,
    rating_average NUMERIC(3, 2) NOT NULL DEFAULT 0.00 CHECK (rating_average >= 0.00 AND rating_average <= 5.00),
    reviews_count INT NOT NULL DEFAULT 0 CHECK (reviews_count >= 0),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

-- Indexes for users
CREATE INDEX IF NOT EXISTS idx_users_role_status ON users(role, kyc_status) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_users_trade ON users(trade) WHERE role = 'technician' AND deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_users_email_lower ON users(LOWER(email));
CREATE UNIQUE INDEX IF NOT EXISTS idx_users_provider ON users(auth_provider, auth_provider_id) WHERE auth_provider_id IS NOT NULL;

-- ------------------------------------------------------------------------------
-- 2. KYC VERIFICATIONS TABLE
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS kyc_verifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    provider VARCHAR(50) NOT NULL, -- e.g., 'renaper', 'didit', 'aws_rekognition', 'mock'
    status kyc_status NOT NULL DEFAULT 'pending',
    
    dni_front_url TEXT,
    dni_back_url TEXT,
    selfie_url TEXT NOT NULL,
    
    -- Biometric score (0.00 to 100.00)
    confidence_score NUMERIC(5, 2),
    liveness_confirmed BOOLEAN NOT NULL DEFAULT FALSE,
    external_reference_id VARCHAR(255),
    rejection_reason TEXT,
    metadata JSONB DEFAULT '{}'::jsonb,
    
    verified_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Fast lookup for the latest KYC record of a user
CREATE INDEX IF NOT EXISTS idx_kyc_user_id ON kyc_verifications(user_id);
CREATE INDEX IF NOT EXISTS idx_kyc_status_created ON kyc_verifications(status, created_at DESC);

-- ------------------------------------------------------------------------------
-- 3. JOBS TABLE (Solicitudes de Servicio)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    assigned_technician_id UUID REFERENCES users(id) ON DELETE SET NULL,
    
    category trade_category NOT NULL,
    title VARCHAR(200) NOT NULL,
    description TEXT NOT NULL,
    photos_urls TEXT[] NOT NULL DEFAULT '{}',
    
    estimated_schedule_date TIMESTAMPTZ NOT NULL,
    
    -- Service Location (Obfuscated at first, shared explicitly when accepted)
    general_locality VARCHAR(120) NOT NULL, -- e.g. "Palermo, CABA"
    full_address TEXT,                     -- e.g. "Av. Santa Fe 3200, 4B" (Shared in chat)
    location_latitude DOUBLE PRECISION,
    location_longitude DOUBLE PRECISION,
    
    status job_status NOT NULL DEFAULT 'published',
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    deleted_at TIMESTAMPTZ
);

-- Query optimizations for job feeds and client dashboards
CREATE INDEX IF NOT EXISTS idx_jobs_category_status ON jobs(category, status) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_jobs_client_id ON jobs(client_id, created_at DESC) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_jobs_assigned_tech ON jobs(assigned_technician_id, status) WHERE assigned_technician_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_jobs_schedule_date ON jobs(estimated_schedule_date) WHERE status = 'assigned';

-- ------------------------------------------------------------------------------
-- 4. PROPOSALS TABLE (Postulaciones de Técnicos)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS proposals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id UUID NOT NULL REFERENCES jobs(id) ON DELETE CASCADE,
    technician_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    estimated_budget NUMERIC(12, 2) NOT NULL CHECK (estimated_budget >= 0),
    estimated_duration_hours INT NOT NULL DEFAULT 1 CHECK (estimated_duration_hours > 0),
    cover_note TEXT,
    
    status proposal_status NOT NULL DEFAULT 'pending',
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Ensure 1 proposal per technician per job
    CONSTRAINT uq_job_technician_proposal UNIQUE (job_id, technician_id)
);

CREATE INDEX IF NOT EXISTS idx_proposals_job_id ON proposals(job_id, status);
CREATE INDEX IF NOT EXISTS idx_proposals_tech_id ON proposals(technician_id, created_at DESC);

-- ------------------------------------------------------------------------------
-- 5. MESSAGES TABLE (Chat 1:1 aislado por job_id)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id UUID NOT NULL REFERENCES jobs(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    type message_type NOT NULL DEFAULT 'text',
    content TEXT NOT NULL,
    
    -- Structured payload for location sharing: {"latitude": -34.588, "longitude": -58.411, "address": "..."}
    metadata JSONB DEFAULT '{}'::jsonb,
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Fast pagination index for chat messages
CREATE INDEX IF NOT EXISTS idx_messages_job_created ON messages(job_id, created_at ASC);
CREATE INDEX IF NOT EXISTS idx_messages_unread ON messages(job_id, is_read) WHERE is_read = FALSE;

-- ------------------------------------------------------------------------------
-- 6. REVIEWS TABLE (Calificaciones y Feedback)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id UUID NOT NULL UNIQUE REFERENCES jobs(id) ON DELETE CASCADE,
    client_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    technician_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    
    score SMALLINT NOT NULL CHECK (score >= 1 AND score <= 5),
    comment TEXT,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_reviews_technician ON reviews(technician_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_reviews_client ON reviews(client_id);

-- ------------------------------------------------------------------------------
-- 7. AUDIT LOG (Legal Argentine Law 25.326 ARCO compliance)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS legal_consents_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    action VARCHAR(50) NOT NULL, -- 'terms_accepted', 'data_access_requested', 'data_deletion_requested'
    ip_address VARCHAR(45) NOT NULL,
    user_agent TEXT,
    terms_version VARCHAR(20) NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_legal_consents_user ON legal_consents_log(user_id, created_at DESC);

-- ------------------------------------------------------------------------------
-- AUTOMATIC TIMESTAMPS TRIGGER FUNCTION
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION trigger_set_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_timestamp_users
BEFORE UPDATE ON users
FOR EACH ROW EXECUTE FUNCTION trigger_set_timestamp();

CREATE TRIGGER set_timestamp_kyc
BEFORE UPDATE ON kyc_verifications
FOR EACH ROW EXECUTE FUNCTION trigger_set_timestamp();

CREATE TRIGGER set_timestamp_jobs
BEFORE UPDATE ON jobs
FOR EACH ROW EXECUTE FUNCTION trigger_set_timestamp();

CREATE TRIGGER set_timestamp_proposals
BEFORE UPDATE ON proposals
FOR EACH ROW EXECUTE FUNCTION trigger_set_timestamp();
