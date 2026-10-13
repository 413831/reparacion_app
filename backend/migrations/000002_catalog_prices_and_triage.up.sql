-- ==============================================================================
-- REPARATUTTI MIGRATION 000002: Catalog Prices, Smart Triage & Estimated Price
-- ==============================================================================

-- 1. Ensure 'plomeria' exists in trade_category
DO $$ BEGIN
    ALTER TYPE trade_category ADD VALUE IF NOT EXISTS 'plomeria' BEFORE 'electricidad';
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- 2. Add estimated_price to jobs
ALTER TABLE jobs ADD COLUMN IF NOT EXISTS estimated_price NUMERIC(12, 2) CHECK (estimated_price IS NULL OR estimated_price >= 0);

-- 3. Create job_catalog_prices table
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

-- 4. Seed Initial Benchmark Catalog Data
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
