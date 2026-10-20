-- Phase 3: Licences, Seats, Devices and Sessions (Milestones 11‑14)
-- Idempotent creation of licence‑related tables and login‑audit tables

-- Licence catalogue (what can be purchased/granted)
CREATE TABLE IF NOT EXISTS licence (
    id BIGSERIAL PRIMARY KEY,
    code TEXT NOT NULL UNIQUE,            -- e.g., 'STD', 'PREM'
    name TEXT NOT NULL,
    description TEXT,
    max_seats INTEGER NOT NULL CHECK (max_seats > 0),
    max_devices INTEGER NOT NULL CHECK (max_devices > 0),
    active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by BIGINT,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by BIGINT
);

-- Seat allocation – links a licence to a user (or a profile) and records the active flag
CREATE TABLE IF NOT EXISTS seat_allocation (
    id BIGSERIAL PRIMARY KEY,
    licence_id BIGINT NOT NULL REFERENCES licence(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    user_id BIGINT NOT NULL REFERENCES "user"(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    allocated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    revoked_at TIMESTAMPTZ,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by BIGINT,
    CONSTRAINT uq_seat_allocation UNIQUE (licence_id, user_id, allocated_at),
    CONSTRAINT ck_seat_allocation_revoked CHECK (revoked_at IS NULL OR revoked_at >= allocated_at)
    -- Over‑allocation (exceeding licence.max_seats) enforced by trigger (pending decision)
);

-- Device registry (protect device identifiers)
CREATE TABLE IF NOT EXISTS device (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES "user"(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    device_fingerprint TEXT NOT NULL,   -- hashed identifier, never raw serial number
    device_type TEXT,
    last_seen_at TIMESTAMPTZ,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by BIGINT,
    CONSTRAINT uq_device_user_fingerprint UNIQUE (user_id, device_fingerprint)
);

-- Login attempt audit (always recorded, never stores secrets)
CREATE TABLE IF NOT EXISTS login_attempt (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT REFERENCES "user"(id) ON UPDATE CASCADE ON DELETE SET NULL,
    device_id BIGINT REFERENCES device(id) ON UPDATE CASCADE ON DELETE SET NULL,
    attempted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    success BOOLEAN NOT NULL,
    failure_reason TEXT,               -- e.g., 'bad_password', 'locked_account'
    ip_address INET,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by BIGINT,
    CONSTRAINT ck_login_success_reason CHECK (success OR failure_reason IS NOT NULL)
    -- No secret fields; audit only.
);

-- Session revocation (soft‑delete of a session, separate from the main session table)
CREATE TABLE IF NOT EXISTS session_revocation (
    id BIGSERIAL PRIMARY KEY,
    session_id BIGINT NOT NULL REFERENCES session(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    revoked_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    revoked_by BIGINT,
    reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by BIGINT,
    CONSTRAINT uq_session_revocation UNIQUE (session_id)
);

-- Indexes for fast look‑up
CREATE INDEX IF NOT EXISTS idx_licence_code ON licence(code);
CREATE INDEX IF NOT EXISTS idx_seat_allocation_user ON seat_allocation(user_id);
CREATE INDEX IF NOT EXISTS idx_device_user ON device(user_id);
CREATE INDEX IF NOT EXISTS idx_login_attempt_user ON login_attempt(user_id);
CREATE INDEX IF NOT EXISTS idx_login_attempt_device ON login_attempt(device_id);
