-- Phase 1: Profile entities
-- Idempotent creation of profile related tables

-- Candidate profile (core identity separate from authentication)
CREATE TABLE IF NOT EXISTS candidate_profile (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL, -- reference to authentication service (outside this DB)
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE,
    phone TEXT,
    birth_date DATE,
    gender TEXT,
    locale TEXT,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by BIGINT,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by BIGINT
);

-- Education history
CREATE TABLE IF NOT EXISTS education (
    id BIGSERIAL PRIMARY KEY,
    candidate_profile_id BIGINT NOT NULL REFERENCES candidate_profile(id) ON UPDATE CASCADE ON DELETE CASCADE,
    institution TEXT NOT NULL,
    degree TEXT,
    field_of_study TEXT,
    start_date DATE,
    end_date DATE,
    grade TEXT,
    description TEXT,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by BIGINT,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by BIGINT,
    CONSTRAINT ck_education_dates CHECK (start_date IS NULL OR end_date IS NULL OR end_date >= start_date)
);

-- Work experience
CREATE TABLE IF NOT EXISTS experience (
    id BIGSERIAL PRIMARY KEY,
    candidate_profile_id BIGINT NOT NULL REFERENCES candidate_profile(id) ON UPDATE CASCADE ON DELETE CASCADE,
    employer TEXT NOT NULL,
    role TEXT NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE,
    description TEXT,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by BIGINT,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by BIGINT,
    CONSTRAINT ck_experience_dates CHECK (end_date IS NULL OR end_date >= start_date)
);

-- Candidate‑skill association (many‑to‑many)
CREATE TABLE IF NOT EXISTS candidate_skill (
    id BIGSERIAL PRIMARY KEY,
    candidate_profile_id BIGINT NOT NULL REFERENCES candidate_profile(id) ON UPDATE CASCADE ON DELETE CASCADE,
    skill_id BIGINT NOT NULL REFERENCES skill(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    proficiency INTEGER, -- 1‑5 scale
    years_experience INTEGER,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by BIGINT,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by BIGINT,
    CONSTRAINT uq_candidate_skill UNIQUE (candidate_profile_id, skill_id),
    CONSTRAINT ck_candidate_skill_proficiency CHECK (proficiency BETWEEN 1 AND 5)
);

-- Candidate‑language association
CREATE TABLE IF NOT EXISTS candidate_language (
    id BIGSERIAL PRIMARY KEY,
    candidate_profile_id BIGINT NOT NULL REFERENCES candidate_profile(id) ON UPDATE CASCADE ON DELETE CASCADE,
    language_id BIGINT NOT NULL REFERENCES language(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    proficiency INTEGER, -- 1‑5 scale
    active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by BIGINT,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by BIGINT,
    CONSTRAINT uq_candidate_language UNIQUE (candidate_profile_id, language_id),
    CONSTRAINT ck_candidate_language_proficiency CHECK (proficiency BETWEEN 1 AND 5)
);

-- Project portfolio
CREATE TABLE IF NOT EXISTS project (
    id BIGSERIAL PRIMARY KEY,
    candidate_profile_id BIGINT NOT NULL REFERENCES candidate_profile(id) ON UPDATE CASCADE ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    url TEXT,
    start_date DATE,
    end_date DATE,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by BIGINT,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by BIGINT,
    CONSTRAINT ck_project_dates CHECK (end_date IS NULL OR end_date >= start_date)
);

-- Resume versioning (metadata only; file stored externally)
CREATE TABLE IF NOT EXISTS resume (
    id BIGSERIAL PRIMARY KEY,
    candidate_profile_id BIGINT NOT NULL REFERENCES candidate_profile(id) ON UPDATE CASCADE ON DELETE CASCADE,
    version INTEGER NOT NULL,
    file_path TEXT NOT NULL, -- reference to storage location (e.g., S3, blob)
    is_primary BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by BIGINT,
    CONSTRAINT uq_resume_candidate_version UNIQUE (candidate_profile_id, version)
);

-- Assessment definition (catalog of assessments)
CREATE TABLE IF NOT EXISTS assessment (
    id BIGSERIAL PRIMARY KEY,
    code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    description TEXT,
    max_score NUMERIC(5,2) NOT NULL CHECK (max_score > 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by BIGINT
);

-- Assessment scores per candidate
CREATE TABLE IF NOT EXISTS assessment_score (
    id BIGSERIAL PRIMARY KEY,
    candidate_profile_id BIGINT NOT NULL REFERENCES candidate_profile(id) ON UPDATE CASCADE ON DELETE CASCADE,
    assessment_id BIGINT NOT NULL REFERENCES assessment(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    score NUMERIC(5,2) NOT NULL,
    taken_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by BIGINT,
    CONSTRAINT uq_assessment_score UNIQUE (candidate_profile_id, assessment_id),
    CONSTRAINT ck_assessment_score_range CHECK (score >= 0 AND score <= (SELECT max_score FROM assessment WHERE id = assessment_id))
);

-- Course enrolment history
CREATE TABLE IF NOT EXISTS course_enrollment (
    id BIGSERIAL PRIMARY KEY,
    candidate_profile_id BIGINT NOT NULL REFERENCES candidate_profile(id) ON UPDATE CASCADE ON DELETE CASCADE,
    course_name TEXT NOT NULL,
    provider TEXT,
    enrolment_date DATE NOT NULL,
    completion_date DATE,
    status TEXT NOT NULL CHECK (status IN ('enrolled','completed','dropped')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by BIGINT,
    CONSTRAINT ck_course_dates CHECK (completion_date IS NULL OR completion_date >= enrolment_date)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_candidate_profile_email ON candidate_profile(email);
CREATE INDEX IF NOT EXISTS idx_education_candidate ON education(candidate_profile_id);
CREATE INDEX IF NOT EXISTS idx_experience_candidate ON experience(candidate_profile_id);
CREATE INDEX IF NOT EXISTS idx_candidate_skill_candidate ON candidate_skill(candidate_profile_id);
CREATE INDEX IF NOT EXISTS idx_candidate_language_candidate ON candidate_language(candidate_profile_id);
CREATE INDEX IF NOT EXISTS idx_project_candidate ON project(candidate_profile_id);
CREATE INDEX IF NOT EXISTS idx_resume_candidate ON resume(candidate_profile_id);
CREATE INDEX IF NOT EXISTS idx_assessment_score_candidate ON assessment_score(candidate_profile_id);
CREATE INDEX IF NOT EXISTS idx_course_enrollment_candidate ON course_enrollment(candidate_profile_id);
