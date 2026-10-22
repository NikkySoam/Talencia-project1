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


-- Phase 3: Subscriptions, Wallet, Payments and Downloads (Milestones 11‑14)
-- Idempotent creation of subscription and financial tables

-- Subscription plan catalogue (defines limits, price, etc.)
CREATE TABLE IF NOT EXISTS subscription_plan (
    id BIGSERIAL PRIMARY KEY,
    code TEXT NOT NULL UNIQUE,               -- e.g., 'BASIC_MONTHLY'
    name TEXT NOT NULL,
    description TEXT,
    price NUMERIC(12,2) NOT NULL CHECK (price >= 0),
    currency_code CHAR(3) NOT NULL,
    max_licences INTEGER NOT NULL CHECK (max_licences > 0),
    max_seats INTEGER NOT NULL CHECK (max_seats > 0),
    max_devices INTEGER NOT NULL CHECK (max_devices > 0),
    billing_cycle TEXT NOT NULL CHECK (billing_cycle IN ('monthly','yearly')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by BIGINT,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by BIGINT
);

-- Subscription instance (assigned to an account)
CREATE TABLE IF NOT EXISTS subscription (
    id BIGSERIAL PRIMARY KEY,
    account_id BIGINT NOT NULL REFERENCES account(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    plan_id BIGINT NOT NULL REFERENCES subscription_plan(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    period TSRANGE NOT NULL,                -- [start, end) in UTC
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active','cancelled','expired')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by BIGINT,
    CONSTRAINT uq_subscription_account_plan UNIQUE (account_id, plan_id, period),
    CONSTRAINT ck_subscription_period CHECK (upper(period) > lower(period)),
    CONSTRAINT exc_subscription_no_overlap EXCLUDE USING GIST (account_id WITH =, period WITH &&)
);

-- Payment order (request to external payment gateway)
CREATE TABLE IF NOT EXISTS payment_order (
    id BIGSERIAL PRIMARY KEY,
    subscription_id BIGINT NOT NULL REFERENCES subscription(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    amount NUMERIC(12,2) NOT NULL CHECK (amount >= 0),
    currency_code CHAR(3) NOT NULL,
    external_reference TEXT NOT NULL,          -- e.g., gateway transaction id
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','succeeded','failed')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by BIGINT,
    CONSTRAINT uq_payment_order_external UNIQUE (external_reference)
);

-- Invoice (generated after successful payment)
CREATE TABLE IF NOT EXISTS invoice (
    id BIGSERIAL PRIMARY KEY,
    payment_order_id BIGINT NOT NULL REFERENCES payment_order(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    invoice_number TEXT NOT NULL UNIQUE,
    issued_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    total_amount NUMERIC(12,2) NOT NULL CHECK (total_amount >= 0),
    currency_code CHAR(3) NOT NULL,
    pdf_url TEXT,                              -- reference to stored document (S3, etc.)
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by BIGINT
);

-- Refund (partial or full)
CREATE TABLE IF NOT EXISTS refund (
    id BIGSERIAL PRIMARY KEY,
    payment_order_id BIGINT NOT NULL REFERENCES payment_order(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    amount NUMERIC(12,2) NOT NULL CHECK (amount >= 0),
    currency_code CHAR(3) NOT NULL,
    refunded_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by BIGINT,
    CONSTRAINT ck_refund_amount CHECK (amount <= (SELECT amount FROM payment_order WHERE id = payment_order_id))
);

-- Wallet (per account, holds balance in base currency)
CREATE TABLE IF NOT EXISTS wallet (
    id BIGSERIAL PRIMARY KEY,
    account_id BIGINT NOT NULL UNIQUE REFERENCES account(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    currency_code CHAR(3) NOT NULL,
    balance NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (balance >= 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by BIGINT
);

-- Ledger entry (append‑only, immutable)
CREATE TABLE IF NOT EXISTS wallet_ledger_entry (
    id BIGSERIAL PRIMARY KEY,
    wallet_id BIGINT NOT NULL REFERENCES wallet(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    entry_type TEXT NOT NULL CHECK (entry_type IN ('credit','debit','reversal')),
    amount NUMERIC(12,2) NOT NULL CHECK (amount >= 0),
    currency_code CHAR(3) NOT NULL,
    related_payment_order_id BIGINT REFERENCES payment_order(id) ON UPDATE CASCADE ON DELETE SET NULL,
    related_refund_id BIGINT REFERENCES refund(id) ON UPDATE CASCADE ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by BIGINT,
    CONSTRAINT uq_ledger_entry UNIQUE (wallet_id, entry_type, created_at, amount)
    -- No UPDATE/DELETE; immutable by design.
);

-- Credit consumption (e.g., profile download cost)
CREATE TABLE IF NOT EXISTS credit_consumption (
    id BIGSERIAL PRIMARY KEY,
    wallet_id BIGINT NOT NULL REFERENCES wallet(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    amount NUMERIC(12,2) NOT NULL CHECK (amount > 0),
    currency_code CHAR(3) NOT NULL,
    consumed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    description TEXT,
    related_download_id BIGINT REFERENCES profile_download_history(id) ON UPDATE CASCADE ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by BIGINT,
    CONSTRAINT uq_credit_consumption UNIQUE (wallet_id, consumed_at, amount)
);

-- Profile download history (records of a candidate profile download by a user/account)
CREATE TABLE IF NOT EXISTS profile_download_history (
    id BIGSERIAL PRIMARY KEY,
    downloader_user_id BIGINT NOT NULL REFERENCES "user"(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    candidate_profile_id BIGINT NOT NULL REFERENCES candidate_profile(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    download_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    file_path TEXT NOT NULL,                     -- location of the exported file (s3, blob, etc.)
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by BIGINT,
    CONSTRAINT uq_profile_download UNIQUE (downloader_user_id, candidate_profile_id, download_at)
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_subscription_account ON subscription(account_id);
CREATE INDEX IF NOT EXISTS idx_payment_order_subscription ON payment_order(subscription_id);
CREATE INDEX IF NOT EXISTS idx_invoice_payment ON invoice(payment_order_id);
CREATE INDEX IF NOT EXISTS idx_refund_payment ON refund(payment_order_id);
CREATE INDEX IF NOT EXISTS idx_wallet_account ON wallet(account_id);
CREATE INDEX IF NOT EXISTS idx_ledger_wallet ON wallet_ledger_entry(wallet_id);
CREATE INDEX IF NOT EXISTS idx_credit_consumption_wallet ON credit_consumption(wallet_id);
CREATE INDEX IF NOT EXISTS idx_profile_download_user ON profile_download_history(downloader_user_id);


-- Phase 4: Notifications, Preferences, Community (Milestones 15‑18)
-- Idempotent creation of notification & preference tables, delivery logs, community posts, reactions, support tickets, FAQs, referral events.

-- Notification preferences (generic key/value with active flag)
CREATE TABLE IF NOT EXISTS notification_preference (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES "user"(id) ON UPDATE CASCADE ON DELETE CASCADE,
    pref_type TEXT NOT NULL,               -- e.g., 'email', 'sms', 'push'
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by BIGINT,
    CONSTRAINT uq_notification_pref_user_type UNIQUE (user_id, pref_type)  -- one record per type per user
);

-- Job‑alert preferences (link to specific job categories or services)
CREATE TABLE IF NOT EXISTS job_alert_preference (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES "user"(id) ON UPDATE CASCADE ON DELETE CASCADE,
    service_id BIGINT NOT NULL REFERENCES gig_service(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by BIGINT,
    CONSTRAINT uq_job_alert_user_service UNIQUE (user_id, service_id)
);

-- Language preferences (preferred UI languages)
CREATE TABLE IF NOT EXISTS language_preference (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES "user"(id) ON UPDATE CASCADE ON DELETE CASCADE,
    language_id BIGINT NOT NULL REFERENCES language(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by BIGINT,
    CONSTRAINT uq_language_pref_user UNIQUE (user_id)
);

-- Privacy settings (e.g., profile visibility)
CREATE TABLE IF NOT EXISTS privacy_setting (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES "user"(id) ON UPDATE CASCADE ON DELETE CASCADE,
    setting_key TEXT NOT NULL,
    setting_value TEXT NOT NULL,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by BIGINT,
    CONSTRAINT uq_privacy_user_key UNIQUE (user_id, setting_key)
);

-- Notification delivery record (idempotent via delivery_key)
CREATE TABLE IF NOT EXISTS notification_delivery (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES "user"(id) ON UPDATE CASCADE ON DELETE CASCADE,
    provider TEXT NOT NULL,                 -- e.g., 'email', 'sms', 'push'
    delivery_key TEXT NOT NULL,            -- external idempotency key from provider
    status TEXT NOT NULL CHECK (status IN ('queued','sent','failed','rejected')),
    attempted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    completed_at TIMESTAMPTZ,
    outcome_details TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by BIGINT,
    CONSTRAINT uq_notification_delivery_user_key UNIQUE (user_id, delivery_key)
);

-- Indexes for high‑volume access patterns on deliveries
CREATE INDEX IF NOT EXISTS idx_notification_delivery_user ON notification_delivery(user_id);
CREATE INDEX IF NOT EXISTS idx_notification_delivery_status ON notification_delivery(status);
CREATE INDEX IF NOT EXISTS idx_notification_delivery_attempted ON notification_delivery(attempted_at);

-- Community post (author is a user)
CREATE TABLE IF NOT EXISTS community_post (
    id BIGSERIAL PRIMARY KEY,
    author_user_id BIGINT NOT NULL REFERENCES "user"(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    posted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by BIGINT,
    CONSTRAINT ck_community_post_body CHECK (body <> '')
);

-- Reaction to a community post (one per user per post)
CREATE TABLE IF NOT EXISTS post_reaction (
    id BIGSERIAL PRIMARY KEY,
    post_id BIGINT NOT NULL REFERENCES community_post(id) ON UPDATE CASCADE ON DELETE CASCADE,
    user_id BIGINT NOT NULL REFERENCES "user"(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    reaction_type TEXT NOT NULL CHECK (reaction_type IN ('like','dislike','laugh','insight')),
    reacted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by BIGINT,
    CONSTRAINT uq_post_reaction UNIQUE (post_id, user_id)
);

-- Support ticket (opened by a user)
CREATE TABLE IF NOT EXISTS support_ticket (
    id BIGSERIAL PRIMARY KEY,
    opener_user_id BIGINT NOT NULL REFERENCES "user"(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    subject TEXT NOT NULL,
    description TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','resolved','closed')),
    priority TEXT NOT NULL DEFAULT 'medium' CHECK (priority IN ('low','medium','high','critical')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by BIGINT,
    CONSTRAINT ck_support_ticket_desc CHECK (description <> '')
);

-- Support ticket status history (immutable log)
CREATE TABLE IF NOT EXISTS support_ticket_status_history (
    id BIGSERIAL PRIMARY KEY,
    ticket_id BIGINT NOT NULL REFERENCES support_ticket(id) ON UPDATE CASCADE ON DELETE CASCADE,
    old_status TEXT NOT NULL,
    new_status TEXT NOT NULL,
    changed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    changed_by BIGINT,
    CONSTRAINT uq_ticket_status_history UNIQUE (ticket_id, changed_at)
);

-- FAQ (canonical question) and translations
CREATE TABLE IF NOT EXISTS faq (
    id BIGSERIAL PRIMARY KEY,
    category TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by BIGINT
);

CREATE TABLE IF NOT EXISTS faq_translation (
    id BIGSERIAL PRIMARY KEY,
    faq_id BIGINT NOT NULL REFERENCES faq(id) ON UPDATE CASCADE ON DELETE CASCADE,
    language_id BIGINT NOT NULL REFERENCES language(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    question TEXT NOT NULL,
    answer TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by BIGINT,
    CONSTRAINT uq_faq_translation UNIQUE (faq_id, language_id)
);

-- Referral event (reuse existing referral model – here we capture a usage event)
CREATE TABLE IF NOT EXISTS referral_event (
    id BIGSERIAL PRIMARY KEY,
    referral_id BIGINT NOT NULL REFERENCES referral(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    event_type TEXT NOT NULL CHECK (event_type IN ('viewed','clicked','converted')),
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by BIGINT
);

-- Indexes for community and support
CREATE INDEX IF NOT EXISTS idx_community_post_author ON community_post(author_user_id);
CREATE INDEX IF NOT EXISTS idx_post_reaction_user ON post_reaction(user_id);
CREATE INDEX IF NOT EXISTS idx_support_ticket_status ON support_ticket(status);
CREATE INDEX IF NOT EXISTS idx_support_ticket_opener ON support_ticket(opener_user_id);
CREATE INDEX IF NOT EXISTS idx_faq_category ON faq(category);

