-- Phase 1: Jobs and Applications entities
-- Idempotent creation of job‑related tables

-- Job requirement (template describing a role)
CREATE TABLE IF NOT EXISTS job_requirement (
    id BIGSERIAL PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT,
    department TEXT,
    employment_type TEXT CHECK (employment_type IN ('full_time','part_time','contract','temporary','internship')),
    seniority_level TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by BIGINT,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by BIGINT
);

-- Job position (a concrete vacancy derived from a requirement)
CREATE TABLE IF NOT EXISTS job_position (
    id BIGSERIAL PRIMARY KEY,
    job_requirement_id BIGINT NOT NULL REFERENCES job_requirement(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    location_city_id BIGINT REFERENCES city(id) ON UPDATE CASCADE ON DELETE SET NULL,
    vacancy_count INTEGER NOT NULL CHECK (vacancy_count > 0),
    posted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    closed_at TIMESTAMPTZ,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by BIGINT,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by BIGINT,
    CONSTRAINT ck_job_position_dates CHECK (closed_at IS NULL OR closed_at >= posted_at)
);

-- Questionnaire linked to a job position (optional – can also be linked to requirement)
CREATE TABLE IF NOT EXISTS questionnaire (
    id BIGSERIAL PRIMARY KEY,
    job_position_id BIGINT NOT NULL REFERENCES job_position(id) ON UPDATE CASCADE ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by BIGINT,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by BIGINT
);

-- Question within a questionnaire
CREATE TABLE IF NOT EXISTS question (
    id BIGSERIAL PRIMARY KEY,
    questionnaire_id BIGINT NOT NULL REFERENCES questionnaire(id) ON UPDATE CASCADE ON DELETE CASCADE,
    question_text TEXT NOT NULL,
    answer_type TEXT NOT NULL CHECK (answer_type IN ('text','multiple_choice','rating','boolean')),
    is_required BOOLEAN NOT NULL DEFAULT TRUE,
    position INTEGER NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by BIGINT,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by BIGINT,
    CONSTRAINT uq_question_questionnaire_position UNIQUE (questionnaire_id, position)
);

-- Candidate application to a job position
CREATE TABLE IF NOT EXISTS application (
    id BIGSERIAL PRIMARY KEY,
    candidate_profile_id BIGINT NOT NULL REFERENCES candidate_profile(id) ON UPDATE CASCADE ON DELETE CASCADE,
    job_position_id BIGINT NOT NULL REFERENCES job_position(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    applied_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    current_status TEXT NOT NULL DEFAULT 'draft' CHECK (current_status IN ('draft','submitted','screening','interview','offer','rejected','hired','withdrawn')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by BIGINT,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by BIGINT,
    CONSTRAINT uq_application_candidate_position UNIQUE (candidate_profile_id, job_position_id)
);

-- Application answer (link to question)
CREATE TABLE IF NOT EXISTS application_answer (
    id BIGSERIAL PRIMARY KEY,
    application_id BIGINT NOT NULL REFERENCES application(id) ON UPDATE CASCADE ON DELETE CASCADE,
    question_id BIGINT NOT NULL REFERENCES question(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    answer_text TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by BIGINT,
    CONSTRAINT uq_application_answer UNIQUE (application_id, question_id)
);

-- Application status history (immutable log)
CREATE TABLE IF NOT EXISTS application_status_history (
    id BIGSERIAL PRIMARY KEY,
    application_id BIGINT NOT NULL REFERENCES application(id) ON UPDATE CASCADE ON DELETE CASCADE,
    status TEXT NOT NULL CHECK (status IN ('draft','submitted','screening','interview','offer','rejected','hired','withdrawn')),
    changed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    changed_by BIGINT,
    CONSTRAINT uq_status_history UNIQUE (application_id, status, changed_at)
);

-- Shortlist (pending decision) – pending approval design
CREATE TABLE IF NOT EXISTS shortlist (
    id BIGSERIAL PRIMARY KEY,
    application_id BIGINT NOT NULL REFERENCES application(id) ON UPDATE CASCADE ON DELETE CASCADE,
    shortlisted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    notes TEXT,
    created_by BIGINT
);

-- Referral (candidate referral) – pending approval design
CREATE TABLE IF NOT EXISTS referral (
    id BIGSERIAL PRIMARY KEY,
    referring_candidate_id BIGINT NOT NULL REFERENCES candidate_profile(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    referred_candidate_id BIGINT NOT NULL REFERENCES candidate_profile(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    job_position_id BIGINT NOT NULL REFERENCES job_position(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    referral_date TIMESTAMPTZ NOT NULL DEFAULT now(),
    status TEXT NOT NULL CHECK (status IN ('pending','accepted','rejected')),
    created_by BIGINT
);

-- Offer details
CREATE TABLE IF NOT EXISTS offer (
    id BIGSERIAL PRIMARY KEY,
    application_id BIGINT NOT NULL UNIQUE REFERENCES application(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    offer_date TIMESTAMPTZ NOT NULL DEFAULT now(),
    salary NUMERIC(12,2) NOT NULL CHECK (salary >= 0),
    currency_code CHAR(3) NOT NULL,
    terms TEXT,
    accepted BOOLEAN,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by BIGINT
);

-- Rejection record
CREATE TABLE IF NOT EXISTS rejection (
    id BIGSERIAL PRIMARY KEY,
    application_id BIGINT NOT NULL UNIQUE REFERENCES application(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    rejection_date TIMESTAMPTZ NOT NULL DEFAULT now(),
    reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by BIGINT
);

-- Joining record (post‑hire onboarding)
CREATE TABLE IF NOT EXISTS joining_record (
    id BIGSERIAL PRIMARY KEY,
    application_id BIGINT NOT NULL UNIQUE REFERENCES application(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    start_date DATE NOT NULL,
    employee_id TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by BIGINT
);

-- Indexes for fast lookup
CREATE INDEX IF NOT EXISTS idx_job_position_requirement ON job_position(job_requirement_id);
CREATE INDEX IF NOT EXISTS idx_application_candidate ON application(candidate_profile_id);
CREATE INDEX IF NOT EXISTS idx_application_position ON application(job_position_id);
CREATE INDEX IF NOT EXISTS idx_application_status_history ON application_status_history(application_id);
CREATE INDEX IF NOT EXISTS idx_offer_application ON offer(application_id);
CREATE INDEX IF NOT EXISTS idx_rejection_application ON rejection(application_id);
CREATE INDEX IF NOT EXISTS idx_joining_application ON joining_record(application_id);
