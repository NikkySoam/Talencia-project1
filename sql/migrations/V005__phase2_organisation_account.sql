-- Phase 2: Organisation & Account (Milestones 7‑10)
-- Idempotent creation of organisation‑related tables

-- Organisation (legal entity)
CREATE TABLE IF NOT EXISTS organisation (
    id BIGSERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    registration_country CHAR(2) NOT NULL, -- ISO 3166‑1 alpha‑2
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by BIGINT,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by BIGINT,
    CONSTRAINT uq_organisation_name_country UNIQUE (name, registration_country)
);

-- Location (physical address) – many per organisation
CREATE TABLE IF NOT EXISTS location (
    id BIGSERIAL PRIMARY KEY,
    organisation_id BIGINT NOT NULL REFERENCES organisation(id) ON UPDATE CASCADE ON DELETE CASCADE,
    address_line1 TEXT NOT NULL,
    address_line2 TEXT,
    city_id BIGINT REFERENCES city(id) ON UPDATE CASCADE ON DELETE SET NULL,
    postal_code TEXT,
    country CHAR(2) NOT NULL,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by BIGINT,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by BIGINT,
    CONSTRAINT uq_location_organisation_address UNIQUE (organisation_id, address_line1, city_id, postal_code)
);

-- Registration Identifier (type scoped by country)
CREATE TABLE IF NOT EXISTS registration_identifier (
    id BIGSERIAL PRIMARY KEY,
    organisation_id BIGINT NOT NULL REFERENCES organisation(id) ON UPDATE CASCADE ON DELETE CASCADE,
    identifier_type TEXT NOT NULL,               -- e.g., 'tax_id', 'company_number'
    identifier_value TEXT NOT NULL,
    country CHAR(2) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by BIGINT,
    CONSTRAINT uq_registration_identifier UNIQUE (country, identifier_type, identifier_value)
);

-- Verification records (sensitive info stored encrypted or hashed)
CREATE TABLE IF NOT EXISTS verification_record (
    id BIGSERIAL PRIMARY KEY,
    organisation_id BIGINT NOT NULL REFERENCES organisation(id) ON UPDATE CASCADE ON DELETE CASCADE,
    verification_type TEXT NOT NULL,
    verification_status TEXT NOT NULL CHECK (verification_status IN ('pending','verified','rejected')),
    verified_at TIMESTAMPTZ,
    data JSONB, -- encrypted payload for sensitive fields
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by BIGINT
);

-- Account (platform account that may own multiple organisations)
CREATE TABLE IF NOT EXISTS account (
    id BIGSERIAL PRIMARY KEY,
    account_key TEXT NOT NULL UNIQUE,           -- public identifier for the account
    name TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by BIGINT,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by BIGINT
);

-- Account administrator mapping (effective‑dated)
CREATE TABLE IF NOT EXISTS account_administrator (
    id BIGSERIAL PRIMARY KEY,
    account_id BIGINT NOT NULL REFERENCES account(id) ON UPDATE CASCADE ON DELETE CASCADE,
    user_id BIGINT NOT NULL REFERENCES "user"(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    valid_from TIMESTAMPTZ NOT NULL DEFAULT now(),
    valid_to TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by BIGINT,
    CONSTRAINT uq_account_admin UNIQUE (account_id, user_id, valid_from)
);

-- Organisation hierarchy (parent‑child) – prevents cycles via exclusion trigger (implementation pending)
CREATE TABLE IF NOT EXISTS organisation_hierarchy (
    id BIGSERIAL PRIMARY KEY,
    parent_id BIGINT NOT NULL REFERENCES organisation(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    child_id BIGINT NOT NULL REFERENCES organisation(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT uq_org_hierarchy UNIQUE (parent_id, child_id)
    -- Cycle detection to be enforced by a trigger/function (pending decision)
);

-- Recruiter‑organisation mapping (effective‑dated)
CREATE TABLE IF NOT EXISTS recruiter_mapping (
    id BIGSERIAL PRIMARY KEY,
    recruiter_user_id BIGINT NOT NULL REFERENCES "user"(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    organisation_id BIGINT NOT NULL REFERENCES organisation(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    valid_from TIMESTAMPTZ NOT NULL DEFAULT now(),
    valid_to TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by BIGINT,
    CONSTRAINT uq_recruiter_mapping UNIQUE (recruiter_user_id, organisation_id, valid_from)
    -- Overlap prevention to be handled via exclusion constraint or trigger (pending decision)
);

-- Indexes for fast look‑up
CREATE INDEX IF NOT EXISTS idx_organisation_name_country ON organisation(name, registration_country);
CREATE INDEX IF NOT EXISTS idx_location_organisation ON location(organisation_id);
CREATE INDEX IF NOT EXISTS idx_registration_identifier ON registration_identifier(country, identifier_type);
CREATE INDEX IF NOT EXISTS idx_verification_organisation ON verification_record(organisation_id);
CREATE INDEX IF NOT EXISTS idx_account_admin_user ON account_administrator(user_id);
CREATE INDEX IF NOT EXISTS idx_org_hierarchy_child ON organisation_hierarchy(child_id);
CREATE INDEX IF NOT EXISTS idx_recruiter_mapping_org ON recruiter_mapping(organisation_id);
