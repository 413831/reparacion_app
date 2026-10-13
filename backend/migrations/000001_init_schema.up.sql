-- ==============================================================================
-- REPARATUTTI MVP - PostgreSQL Production Schema
-- Designed for High Concurrency, Double Confirmation State Machine & Reminders
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
    CREATE TYPE user_account_status AS ENUM ('active', 'suspended', 'deleted');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE kyc_status AS ENUM ('unverified', 'pending', 'verified', 'rejected');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE trade_category AS ENUM (
        'plomeria',
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

-- 4 Valid States of the Job Lifecycle
DO $$ BEGIN
    CREATE TYPE job_status AS ENUM (
        'pendiente_de_aceptacion',
        'agendado',
        'finalizado',
        'cancelado'
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
    password_hash VARCHAR(255),
    full_name VARCHAR(120) NOT NULL,
    phone_number VARCHAR(30),
    role user_role NOT NULL DEFAULT 'client',
    account_status user_account_status NOT NULL DEFAULT 'active',
    auth_provider VARCHAR(50) NOT NULL DEFAULT 'local',
    auth_provider_id VARCHAR(255),
    avatar_url TEXT,
    
    -- Legal & KYC State
    terms_accepted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    terms_version VARCHAR(50) NOT NULL DEFAULT '[CONFIG_TERMINOS_Y_CONDICIONES_LEGALES]',
    kyc_status kyc_status NOT NULL DEFAULT 'unverified',
    
    -- Technician specific metrics (cached & denormalized for speed)
    trade trade_category,
    rating_average NUMERIC(3, 2) NOT NULL DEFAULT 0.00 CHECK (rating_average >= 0.00 AND rating_average <= 5.00),
    reviews_count INT NOT NULL DEFAULT 0 CHECK (reviews_count >= 0),
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_users_role_status ON users(role, kyc_status) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_users_trade ON users(trade) WHERE role = 'technician' AND deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_users_email_lower ON users(LOWER(email));

-- ------------------------------------------------------------------------------
-- 2. NOTIFICATION PREFERENCES TABLE (Multichannel: Push, Email, SMS, Reminders)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS notification_preferences (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    push_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    email_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    sms_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    reminders_24h_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    reminders_2h_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ------------------------------------------------------------------------------
-- 3. KYC VERIFICATIONS TABLE
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS kyc_verifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    provider VARCHAR(50) NOT NULL, -- 'renaper', 'didit', 'aws_rekognition', 'mock'
    status kyc_status NOT NULL DEFAULT 'pending',
    
    dni_front_url TEXT,
    dni_back_url TEXT,
    selfie_url TEXT NOT NULL,
    
    confidence_score NUMERIC(5, 2),
    liveness_confirmed BOOLEAN NOT NULL DEFAULT FALSE,
    external_reference_id VARCHAR(255),
    rejection_reason TEXT,
    metadata JSONB DEFAULT '{}'::jsonb,
    
    verified_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_kyc_user_id ON kyc_verifications(user_id);

-- ------------------------------------------------------------------------------
-- 4. JOBS TABLE (With Double Confirmation & Schedule Indexes)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    assigned_technician_id UUID REFERENCES users(id) ON DELETE SET NULL,
    
    category trade_category NOT NULL,
    title VARCHAR(200) NOT NULL,
    description TEXT NOT NULL,
    photos_urls TEXT[] NOT NULL DEFAULT '{}',
    
    -- Smart Triage & Pricing
    estimated_price NUMERIC(12, 2) CHECK (estimated_price IS NULL OR estimated_price >= 0),

    -- Schedule Timestamp
    scheduled_at TIMESTAMPTZ NOT NULL,
    
    -- Service Location (Obfuscated at first, shared in 1:1 chat)
    general_locality VARCHAR(120) NOT NULL,
    full_address TEXT,
    location_latitude DOUBLE PRECISION,
    location_longitude DOUBLE PRECISION,
    
    -- Global Status (Official transition occurs when both flags match)
    status job_status NOT NULL DEFAULT 'pendiente_de_aceptacion',
    
    -- Double Confirmation Flags
    client_confirmed_status job_status,
    tech_confirmed_status job_status,
    client_confirmed_at TIMESTAMPTZ,
    tech_confirmed_at TIMESTAMPTZ,
    
    -- Reminder Tracking Flags (Prevent duplicate dispatches)
    reminder_24h_sent_at TIMESTAMPTZ,
    reminder_2h_sent_at TIMESTAMPTZ,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,
    deleted_at TIMESTAMPTZ
);

-- Compound Index for the Scheduled Reminders Cron / Ticker
CREATE INDEX IF NOT EXISTS idx_jobs_status_scheduled ON jobs(status, scheduled_at) WHERE deleted_at IS NULL;
-- Indexes for Feed & Technician discovery
CREATE INDEX IF NOT EXISTS idx_jobs_category_status ON jobs(category, status) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_jobs_client_status ON jobs(client_id, status) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_jobs_assigned_tech_status ON jobs(assigned_technician_id, status) WHERE assigned_technician_id IS NOT NULL;

-- ------------------------------------------------------------------------------
-- 5. JOB STATUS TRANSITIONS (Audit Log for Double Confirmations)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS job_status_transitions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id UUID NOT NULL REFERENCES jobs(id) ON DELETE CASCADE,
    initiated_by_user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    from_status job_status NOT NULL,
    target_status job_status NOT NULL,
    
    client_confirmed BOOLEAN NOT NULL DEFAULT FALSE,
    tech_confirmed BOOLEAN NOT NULL DEFAULT FALSE,
    is_completed BOOLEAN NOT NULL DEFAULT FALSE,
    
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_transitions_job ON job_status_transitions(job_id, created_at DESC);

-- ------------------------------------------------------------------------------
-- 6. PROPOSALS TABLE (Postulaciones)
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
    
    CONSTRAINT uq_job_technician_proposal UNIQUE (job_id, technician_id)
);

CREATE INDEX IF NOT EXISTS idx_proposals_job_id ON proposals(job_id, status);
CREATE INDEX IF NOT EXISTS idx_proposals_tech_id ON proposals(technician_id, created_at DESC);

-- ------------------------------------------------------------------------------
-- 7. MESSAGES TABLE (Chat 1:1 aislado por job_id)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id UUID NOT NULL REFERENCES jobs(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    type message_type NOT NULL DEFAULT 'text',
    content TEXT NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb,
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_messages_job_created ON messages(job_id, created_at ASC);
CREATE INDEX IF NOT EXISTS idx_messages_unread ON messages(job_id, is_read) WHERE is_read = FALSE;

-- ------------------------------------------------------------------------------
-- 8. REVIEWS TABLE (Calificaciones)
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

CREATE TRIGGER set_timestamp_jobs
BEFORE UPDATE ON jobs
FOR EACH ROW EXECUTE FUNCTION trigger_set_timestamp();

CREATE TRIGGER set_timestamp_proposals
BEFORE UPDATE ON proposals
FOR EACH ROW EXECUTE FUNCTION trigger_set_timestamp();

-- ------------------------------------------------------------------------------
-- 9. JOB CATALOG PRICES (Smart Triage & Benchmark Estimations)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS job_catalog_prices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    category trade_category NOT NULL,
    service_name VARCHAR(150) NOT NULL,
    keyword_patterns TEXT[] NOT NULL DEFAULT '{}',
    average_price NUMERIC(12, 2) NOT NULL CHECK (average_price > 0),
    min_price NUMERIC(12, 2) NOT NULL CHECK (min_price > 0),
    max_price NUMERIC(12, 2) NOT NULL CHECK (max_price >= min_price),
    currency VARCHAR(10) NOT NULL DEFAULT 'ARS',
    estimated_duration_hours INT NOT NULL DEFAULT 2 CHECK (estimated_duration_hours > 0),
    description TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_catalog_category_active ON job_catalog_prices(category, is_active);
CREATE INDEX IF NOT EXISTS idx_catalog_keywords ON job_catalog_prices USING GIN(keyword_patterns);

CREATE TRIGGER set_timestamp_catalog_prices
BEFORE UPDATE ON job_catalog_prices
FOR EACH ROW EXECUTE FUNCTION trigger_set_timestamp();

-- Seed Initial Benchmark Catalog Data
INSERT INTO job_catalog_prices (category, service_name, keyword_patterns, average_price, min_price, max_price, estimated_duration_hours, description)
VALUES
('plomeria', 'Destapar cañería / Desagote', ARRAY['destapar', 'cañeria', 'desague', 'cloaca', 'tapada', 'inodoro'], 40000.00, 30000.00, 55000.00, 2, 'Servicio estándar de desobstrucción mecánica o química de cañerías'),
('plomeria', 'Reparación de canilla / Grifería', ARRAY['gotea', 'canilla', 'grifo', 'griferia', 'monocomando', 'cuerito', 'fuga de agua'], 28000.00, 20000.00, 38000.00, 1, 'Cambio de vástago, cuerito o cartucho monocomando con prueba de estanqueidad'),
('electricidad', 'Cambio de disyuntor / Térmica', ARRAY['disyuntor', 'termica', 'corte de luz', 'tablero', 'salta la termica', 'llave termomagnetica'], 32000.00, 24000.00, 46000.00, 2, 'Reemplazo y dimensionamiento de protecciones en tablero seccional'),
('electricidad', 'Instalación de luminaria / Ventilador', ARRAY['lampara', 'luz', 'ventilador', 'aplique', 'led', 'cableado'], 26000.00, 18000.00, 38000.00, 2, 'Colocación segura de artefacto lumínico con verificación de puesta a tierra'),
('gas', 'Instalación / Reparación de estufa', ARRAY['estufa', 'calefactor', 'tiro balanceado', 'olor a gas', 'calefaccion', 'piloto'], 45000.00, 35000.00, 60000.00, 3, 'Revisión y habilitación por gasista matriculado con detección de fugas'),
('gas', 'Reparación de calefón / Termotanque', ARRAY['calefon', 'termotanque', 'agua caliente', 'no enciende', 'termostato'], 42000.00, 32000.00, 58000.00, 2, 'Limpieza de quemador, cambio de termocupla o diafragma'),
('pintura', 'Pintura de ambiente estándar (hasta 15m²)', ARRAY['pintar', 'pintura', 'pared', 'techo', 'enduido', 'humedad'], 75000.00, 60000.00, 98000.00, 8, 'Preparación de muros, lijado, sellador y dos manos de látex lavable'),
('flete', 'Flete urbano corto (hasta 15km)', ARRAY['flete', 'mudanza', 'traslado', 'camioneta', 'cajas', 'muebles'], 38000.00, 28000.00, 50000.00, 2, 'Traslado puerta a puerta con ayudante para carga y descarga ligera'),
('reparacion_edilicia', 'Reparación de persiana / Cortina', ARRAY['persiana', 'cinta', 'enrollar', 'traba', 'cortina de rollo'], 29000.00, 22000.00, 40000.00, 2, 'Cambio de cinta, enrollador o sustitución de varillas rotas')
ON CONFLICT DO NOTHING;

