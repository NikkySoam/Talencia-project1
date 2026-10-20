-- Phase 1: Master Data
-- Idempotent creation of lookup/reference tables

-- Country lookup
CREATE TABLE IF NOT EXISTS country (
    id BIGSERIAL PRIMARY KEY,
    code CHAR(2) NOT NULL UNIQUE,               -- ISO 3166‑1 alpha‑2
    name TEXT NOT NULL,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by BIGINT,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by BIGINT,
    CONSTRAINT ck_country_code CHECK (code ~ '^[A-Z]{2}$')
);

-- State / Province lookup (hierarchy to country)
CREATE TABLE IF NOT EXISTS state (
    id BIGSERIAL PRIMARY KEY,
    country_id BIGINT NOT NULL REFERENCES country(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    code VARCHAR(3) NOT NULL,
    name TEXT NOT NULL,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by BIGINT,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by BIGINT,
    CONSTRAINT uq_state_country_code UNIQUE (country_id, code),
    CONSTRAINT ck_state_code CHECK (code ~ '^[A-Z0-9]{1,3}$')
);

-- City lookup (hierarchy to state)
CREATE TABLE IF NOT EXISTS city (
    id BIGSERIAL PRIMARY KEY,
    state_id BIGINT NOT NULL REFERENCES state(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    name TEXT NOT NULL,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by BIGINT,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by BIGINT,
    CONSTRAINT uq_city_state_name UNIQUE (state_id, name)
);

-- Skill lookup
CREATE TABLE IF NOT EXISTS skill (
    id BIGSERIAL PRIMARY KEY,
    code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by BIGINT,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by BIGINT
);

-- Qualification lookup
CREATE TABLE IF NOT EXISTS qualification (
    id BIGSERIAL PRIMARY KEY,
    code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by BIGINT,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by BIGINT
);

-- Language lookup
CREATE TABLE IF NOT EXISTS language (
    id BIGSERIAL PRIMARY KEY,
    code CHAR(2) NOT NULL UNIQUE,               -- ISO 639‑1
    name TEXT NOT NULL,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by BIGINT,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by BIGINT,
    CONSTRAINT ck_language_code CHECK (code ~ '^[a-z]{2}$')
);

-- Additional master data tables (job classifications, employment types, etc.) can be added following the same pattern.

-- Indexes for fast look‑up (named per convention)
CREATE INDEX IF NOT EXISTS idx_country_code ON country(code);
CREATE INDEX IF NOT EXISTS idx_state_country_code ON state(country_id, code);
CREATE INDEX IF NOT EXISTS idx_city_state_name ON city(state_id, name);
CREATE INDEX IF NOT EXISTS idx_skill_code ON skill(code);
CREATE INDEX IF NOT EXISTS idx_qualification_code ON qualification(code);
CREATE INDEX IF NOT EXISTS idx_language_code ON language(code);
