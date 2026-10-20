-- Phase 2: Administration (Milestones 7‑10)
-- Idempotent creation of identity, credential, role, permission, session, consent, audit and block tables

-- Shared identity (users)
CREATE TABLE IF NOT EXISTS "user" (
    id BIGSERIAL PRIMARY KEY,
    email TEXT NOT NULL,
    normalized_email TEXT NOT NULL,
    first_name TEXT,
    last_name TEXT,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by BIGINT,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by BIGINT,
    -- Unique email only if policy mandates one account per email (approved)
    CONSTRAINT uq_user_normalized_email UNIQUE (normalized_email)
);

-- Credentials (password hashes, external provider identifiers)
CREATE TABLE IF NOT EXISTS credential (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES "user"(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    provider TEXT NOT NULL,                     -- e.g., 'local', 'google', 'azure'
    provider_subject TEXT NOT NULL,            -- unique identifier from provider
    secret_hash TEXT,                           -- password hash for local provider only
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by BIGINT,
    CONSTRAINT uq_credential_provider_subject UNIQUE (provider, provider_subject)
);

-- Role definition
CREATE TABLE IF NOT EXISTS role (
    id BIGSERIAL PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by BIGINT,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by BIGINT
);

-- Permission definition
CREATE TABLE IF NOT EXISTS permission (
    id BIGSERIAL PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by BIGINT,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by BIGINT
);

-- User‑role assignment (effective‑dated)
CREATE TABLE IF NOT EXISTS user_role (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES "user"(id) ON UPDATE CASCADE ON DELETE CASCADE,
    role_id BIGINT NOT NULL REFERENCES role(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    valid_from TIMESTAMPTZ NOT NULL DEFAULT now(),
    valid_to TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by BIGINT,
    CONSTRAINT uq_user_role_unique UNIQUE (user_id, role_id, valid_from)
    -- Note: overlapping periods are prevented by application logic / stored procedure (pending decision)
);

-- Role‑permission assignment (static, no effective dating required)
CREATE TABLE IF NOT EXISTS role_permission (
    id BIGSERIAL PRIMARY KEY,
    role_id BIGINT NOT NULL REFERENCES role(id) ON UPDATE CASCADE ON DELETE CASCADE,
    permission_id BIGINT NOT NULL REFERENCES permission(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by BIGINT,
    CONSTRAINT uq_role_permission UNIQUE (role_id, permission_id)
);

-- Sessions (token reference, expiration, revocation)
CREATE TABLE IF NOT EXISTS session (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES "user"(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    device_id TEXT,
    token_hash TEXT NOT NULL,
    issued_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at TIMESTAMPTZ NOT NULL,
    revoked_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by BIGINT,
    CONSTRAINT uq_session_token_hash UNIQUE (token_hash)
);

-- Consent records (policy version, grant/withdrawal timestamps)
CREATE TABLE IF NOT EXISTS consent_record (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES "user"(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    policy_version TEXT NOT NULL,
    granted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    withdrawn_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by BIGINT,
    CONSTRAINT uq_consent_user_policy UNIQUE (user_id, policy_version, granted_at)
);

-- Audit events (append‑only, immutable)
CREATE TABLE IF NOT EXISTS audit_event (
    id BIGSERIAL PRIMARY KEY,
    event_type TEXT NOT NULL,
    entity_type TEXT NOT NULL,
    entity_id BIGINT,
    performed_by BIGINT,
    performed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    details JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    -- No UPDATE/DELETE privileges for ordinary roles (enforced by DB role management)
);

-- Block entries (e.g., blocked users, IPs, devices)
CREATE TABLE IF NOT EXISTS block_entry (
    id BIGSERIAL PRIMARY KEY,
    blocked_entity_type TEXT NOT NULL,   -- e.g., 'user', 'ip', 'device'
    blocked_entity_id BIGINT NOT NULL,
    reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by BIGINT,
    CONSTRAINT uq_block_entity UNIQUE (blocked_entity_type, blocked_entity_id)
);

-- Indexes for fast look‑up
CREATE INDEX IF NOT EXISTS idx_user_normalized_email ON "user"(normalized_email);
CREATE INDEX IF NOT EXISTS idx_credential_user ON credential(user_id);
CREATE INDEX IF NOT EXISTS idx_user_role_user ON user_role(user_id);
CREATE INDEX IF NOT EXISTS idx_user_role_role ON user_role(role_id);
CREATE INDEX IF NOT EXISTS idx_role_permission_role ON role_permission(role_id);
CREATE INDEX IF NOT EXISTS idx_role_permission_permission ON role_permission(permission_id);
CREATE INDEX IF NOT EXISTS idx_session_user ON session(user_id);
CREATE INDEX IF NOT EXISTS idx_consents_user ON consent_record(user_id);
