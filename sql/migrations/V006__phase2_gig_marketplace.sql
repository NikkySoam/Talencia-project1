-- Phase 2: Gig Marketplace (Milestones 7‑10)
-- Idempotent creation of gig‑related tables with constraints, exclusion for worker windows, and audit fields

-- Gig worker profile (extended from candidate_profile but separate for marketplace)
CREATE TABLE IF NOT EXISTS gig_worker_profile (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES "user"(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    display_name TEXT NOT NULL,
    bio TEXT,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by BIGINT,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by BIGINT
);

-- Service catalog (what a worker can offer)
CREATE TABLE IF NOT EXISTS gig_service (
    id BIGSERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by BIGINT,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by BIGINT,
    CONSTRAINT uq_gig_service_name UNIQUE (name)
);

-- Worker‑service association (many‑to‑many)
CREATE TABLE IF NOT EXISTS worker_service (
    id BIGSERIAL PRIMARY KEY,
    gig_worker_profile_id BIGINT NOT NULL REFERENCES gig_worker_profile(id) ON UPDATE CASCADE ON DELETE CASCADE,
    gig_service_id BIGINT NOT NULL REFERENCES gig_service(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    price NUMERIC(12,2) NOT NULL CHECK (price >= 0),
    currency_code CHAR(3) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by BIGINT,
    CONSTRAINT uq_worker_service UNIQUE (gig_worker_profile_id, gig_service_id)
);

-- Availability windows for a worker (range type + exclusion constraint)
CREATE EXTENSION IF NOT EXISTS btree_gist;  -- required for range exclusion
CREATE TABLE IF NOT EXISTS gig_availability (
    id BIGSERIAL PRIMARY KEY,
    gig_worker_profile_id BIGINT NOT NULL REFERENCES gig_worker_profile(id) ON UPDATE CASCADE ON DELETE CASCADE,
    avail_range TSRANGE NOT NULL,   -- [start, end) timestamps in UTC
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by BIGINT,
    CONSTRAINT uq_gig_worker_availability UNIQUE (gig_worker_profile_id, avail_range),
    CONSTRAINT exc_gig_worker_no_overlap EXCLUDE USING GIST (gig_worker_profile_id WITH =, avail_range WITH &&)
);

-- Gig request (posted by a requester – could be a user or an organisation)
CREATE TABLE IF NOT EXISTS gig_request (
    id BIGSERIAL PRIMARY KEY,
    requester_user_id BIGINT REFERENCES "user"(id) ON UPDATE CASCADE ON DELETE SET NULL,
    requester_account_id BIGINT REFERENCES account(id) ON UPDATE CASCADE ON DELETE SET NULL,
    gig_service_id BIGINT NOT NULL REFERENCES gig_service(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    title TEXT NOT NULL,
    description TEXT,
    request_range TSRANGE NOT NULL,   -- required time window for the work
    budget NUMERIC(12,2) CHECK (budget >= 0),
    currency_code CHAR(3),
    posted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open','closed','cancelled')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by BIGINT,
    CONSTRAINT ck_gig_request_dates CHECK (upper(request_range) > lower(request_range))
);

-- Application to a gig request (worker applies)
CREATE TABLE IF NOT EXISTS gig_application (
    id BIGSERIAL PRIMARY KEY,
    gig_worker_profile_id BIGINT NOT NULL REFERENCES gig_worker_profile(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    gig_request_id BIGINT NOT NULL REFERENCES gig_request(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    applied_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    current_status TEXT NOT NULL DEFAULT 'draft' CHECK (current_status IN ('draft','submitted','accepted','rejected','withdrawn')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by BIGINT,
    CONSTRAINT uq_gig_application_worker_request UNIQUE (gig_worker_profile_id, gig_request_id)
);

-- Assignment – one per accepted application (enforced by UNIQUE on application_id where status = 'accepted')
CREATE TABLE IF NOT EXISTS gig_assignment (
    id BIGSERIAL PRIMARY KEY,
    gig_application_id BIGINT NOT NULL REFERENCES gig_application(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    assigned_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    start_at TIMESTAMPTZ NOT NULL,
    end_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by BIGINT,
    CONSTRAINT ck_assignment_window CHECK (end_at > start_at),
    CONSTRAINT uq_assignment_one_per_application UNIQUE (gig_application_id)
);

-- External handoff reference (idempotent external integration identifier)
CREATE TABLE IF NOT EXISTS gig_handoff (
    id BIGSERIAL PRIMARY KEY,
    gig_assignment_id BIGINT NOT NULL REFERENCES gig_assignment(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    external_system TEXT NOT NULL,
    external_id TEXT NOT NULL,
    handoff_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by BIGINT,
    CONSTRAINT uq_gig_handoff_external UNIQUE (external_system, external_id)
);

-- Earnings snapshot (read‑only copy of external earnings data)
CREATE TABLE IF NOT EXISTS gig_earning_snapshot (
    id BIGSERIAL PRIMARY KEY,
    gig_assignment_id BIGINT NOT NULL REFERENCES gig_assignment(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    amount NUMERIC(12,2) NOT NULL CHECK (amount >= 0),
    currency_code CHAR(3) NOT NULL,
    snapshot_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    source_json JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by BIGINT
);

-- Rating (worker rating by requester)
CREATE TABLE IF NOT EXISTS gig_rating (
    id BIGSERIAL PRIMARY KEY,
    gig_assignment_id BIGINT NOT NULL REFERENCES gig_assignment(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    rater_user_id BIGINT NOT NULL REFERENCES "user"(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    score INTEGER NOT NULL CHECK (score >= 1 AND score <= 5),
    comment TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by BIGINT,
    CONSTRAINT uq_gig_rating_assignment UNIQUE (gig_assignment_id, rater_user_id),
    CONSTRAINT ck_gig_rating_self CHECK (rater_user_id <> (SELECT gig_worker_profile.user_id FROM gig_worker_profile WHERE gig_worker_profile.id = (SELECT gig_application.gig_worker_profile_id FROM gig_application WHERE gig_application.id = gig_rating.gig_assignment_id)))
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_gig_worker_user ON gig_worker_profile(user_id);
CREATE INDEX IF NOT EXISTS idx_worker_service_worker ON worker_service(gig_worker_profile_id);
CREATE INDEX IF NOT EXISTS idx_gig_availability_worker ON gig_availability(gig_worker_profile_id);
CREATE INDEX IF NOT EXISTS idx_gig_request_service ON gig_request(gig_service_id);
CREATE INDEX IF NOT EXISTS idx_gig_application_worker ON gig_application(gig_worker_profile_id);
CREATE INDEX IF NOT EXISTS idx_gig_assignment_application ON gig_assignment(gig_application_id);
CREATE INDEX IF NOT EXISTS idx_gig_handoff_assignment ON gig_handoff(gig_assignment_id);
CREATE INDEX IF NOT EXISTS idx_gig_rating_assignment ON gig_rating(gig_assignment_id);
