-- tests/schema_constraints.sql
-- This file uses pgTap (https://pgtap.org/) to verify the schema constraints.
-- Run with: psql -f tests/schema_constraints.sql <your_db>

\set ON_ERROR_STOP on

BEGIN;

-- 1. Verify that all expected tables exist.
SELECT plan(200);  -- adjust as needed

SELECT ok((SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'user')),
    'Table user exists');
SELECT ok((SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'credential')),
    'Table credential exists');
SELECT ok((SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'role')),
    'Table role exists');
SELECT ok((SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'permission')),
    'Table permission exists');
SELECT ok((SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'session')),
    'Table session exists');
SELECT ok((SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'audit_event')),
    'Table audit_event exists');
-- Add similar checks for every table created by migrations V001‑V010.

-- 2. Primary key existence and naming convention (singular snake_case, id).
SELECT ok((SELECT column_name FROM information_schema.columns WHERE table_name='user' AND column_name='id'),
    'user has id primary key column');
SELECT ok((SELECT column_name FROM information_schema.columns WHERE table_name='credential' AND column_name='id'),
    'credential has id primary key column');
-- etc.

-- 3. Unique constraints and naming.
SELECT ok((SELECT COUNT(*) FROM information_schema.table_constraints WHERE constraint_type='UNIQUE' AND table_name='user' AND constraint_name='uq_user_normalized_email'),
    'user.normalized_email unique constraint present');
-- Repeat for other unique constraints.

-- 4. Foreign key existence and ON UPDATE/DELETE actions.
SELECT ok((SELECT COUNT(*) FROM information_schema.referential_constraints WHERE constraint_name='fk_credential_user_id'),
    'credential.user_id FK exists');
-- Use pg_constraint to verify ON UPDATE/DELETE actions if needed.

-- 5. CHECK constraints example.
SELECT ok((SELECT COUNT(*) FROM pg_constraint WHERE conname='ck_user_normalized_email'),
    'Check constraint for normalized_email format exists');
-- Add checks for all CHECK constraints defined in migrations.

-- 6. Exclusion constraints (gig availability, subscription periods).
SELECT ok((SELECT COUNT(*) FROM pg_constraint WHERE contype='x' AND conname='exc_gig_worker_no_overlap'),
    'Exclusion constraint for gig worker availability exists');
SELECT ok((SELECT COUNT(*) FROM pg_constraint WHERE contype='x' AND conname='exc_subscription_no_overlap'),
    'Exclusion constraint for subscription periods exists');

-- 7. Index existence for important access paths.
SELECT ok((SELECT COUNT(*) FROM pg_indexes WHERE tablename='notification_delivery' AND indexname='idx_notification_delivery_user'),
    'Index on notification_delivery.user_id exists');
-- Add more index checks as required.

-- 8. Nullable vs NOT NULL verification.
SELECT ok((SELECT is_nullable FROM information_schema.columns WHERE table_name='candidate_profile' AND column_name='phone') = 'YES',
    'candidate_profile.phone nullable as expected');
-- Repeat for each column with explicit nullability expectations.

-- 9. Default values verification.
SELECT ok((SELECT column_default FROM information_schema.columns WHERE table_name='country' AND column_name='active') = 'true',
    'country.active default true');
-- Add for other defaults like created_at, updated_at.

-- 10. Sensitive data classification placeholder – ensure columns like secret_hash are NOT exposed via SELECT * in public roles (to be enforced by RLS / role grants, not tested here).

SELECT * FROM finish();

ROLLBACK;  -- Keep DB unchanged after the test run.
