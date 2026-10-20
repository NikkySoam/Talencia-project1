-- Phase 3: Sourcing and Consultant Requests (Milestones 11‑14)
-- Idempotent creation of sourcing‑related tables

-- Sourcing request (initiated by a recruiter/organisation for a job)
CREATE TABLE IF NOT EXISTS sourcing_request (
    id BIGSERIAL PRIMARY KEY,
    job_position_id BIGINT NOT NULL REFERENCES job_position(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    requester_user_id BIGINT NOT NULL REFERENCES "user"(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    requested_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open','fulfilled','cancelled')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by BIGINT,
    CONSTRAINT uq_sourcing_request_job_user UNIQUE (job_position_id, requester_user_id)
);

-- Consultant decision (accept/reject a sourcing request)
CREATE TABLE IF NOT EXISTS consultant_decision (
    id BIGSERIAL PRIMARY KEY,
    sourcing_request_id BIGINT NOT NULL REFERENCES sourcing_request(id) ON UPDATE CASCADE ON DELETE CASCADE,
    consultant_user_id BIGINT NOT NULL REFERENCES "user"(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    decision TEXT NOT NULL CHECK (decision IN ('accepted','rejected')),
    decided_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by BIGINT,
    CONSTRAINT uq_consultant_decision UNIQUE (sourcing_request_id, consultant_user_id)
);

-- Outreach batch (group of outreach events to consultants)
CREATE TABLE IF NOT EXISTS outreach_batch (
    id BIGSERIAL PRIMARY KEY,
    sourcing_request_id BIGINT NOT NULL REFERENCES sourcing_request(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    batch_number INTEGER NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by BIGINT,
    CONSTRAINT uq_outreach_batch UNIQUE (sourcing_request_id, batch_number)
);

-- Outreach recipient (individual consultant contacted in a batch)
CREATE TABLE IF NOT EXISTS outreach_recipient (
    id BIGSERIAL PRIMARY KEY,
    outreach_batch_id BIGINT NOT NULL REFERENCES outreach_batch(id) ON UPDATE CASCADE ON DELETE CASCADE,
    consultant_user_id BIGINT NOT NULL REFERENCES "user"(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    contacted_at TIMESTAMPTZ,
    response TEXT CHECK (response IN ('no_response','interested','not_interested')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by BIGINT,
    CONSTRAINT uq_outreach_recipient UNIQUE (outreach_batch_id, consultant_user_id)
);

-- Candidate sourcing shortlist (candidates selected for a job by a consultant)
CREATE TABLE IF NOT EXISTS candidate_sourcing_shortlist (
    id BIGSERIAL PRIMARY KEY,
    sourcing_request_id BIGINT NOT NULL REFERENCES sourcing_request(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    candidate_profile_id BIGINT NOT NULL REFERENCES candidate_profile(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    shortlisted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by BIGINT,
    CONSTRAINT uq_candidate_shortlist UNIQUE (sourcing_request_id, candidate_profile_id)
);

-- Indexes for fast lookup
CREATE INDEX IF NOT EXISTS idx_sourcing_request_job ON sourcing_request(job_position_id);
CREATE INDEX IF NOT EXISTS idx_consultant_decision_request ON consultant_decision(sourcing_request_id);
CREATE INDEX IF NOT EXISTS idx_outreach_batch_request ON outreach_batch(sourcing_request_id);
CREATE INDEX IF NOT EXISTS idx_outreach_recipient_batch ON outreach_recipient(outreach_batch_id);
CREATE INDEX IF NOT EXISTS idx_candidate_shortlist_request ON candidate_sourcing_shortlist(sourcing_request_id);
