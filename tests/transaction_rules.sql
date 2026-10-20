-- tests/transaction_rules.sql
-- pgTap tests for multi‑row business invariants and transaction‑level rules.
\set ON_ERROR_STOP on
BEGIN;
SELECT plan(50);

-- 1. Ensure seat allocation does not exceed licence.max_seats (trigger to be implemented).
-- Expected‑failure case: insert seat allocation that would exceed limit.
SELECT throws_ok($$INSERT INTO seat_allocation (licence_id, user_id) VALUES (1, 9999);$$,
    'seat_allocation_limit_exceeded',
    'Seat allocation exceeding licence limit raises error');

-- 2. Recruiter mapping overlap prevention (effective‑dated trigger).
SELECT throws_ok($$INSERT INTO recruiter_mapping (recruiter_user_id, organisation_id, valid_from, valid_to) VALUES (2, 1, '2025-01-01', '2025-12-31');
    INSERT INTO recruiter_mapping (recruiter_user_id, organisation_id, valid_from, valid_to) VALUES (2, 1, '2025-06-01', '2025-12-31');$$,
    'recruiter_mapping_overlap',
    'Overlapping recruiter mappings are rejected');

-- 3. Gig worker availability exclusion (already enforced by exclusion constraint).
SELECT throws_ok($$INSERT INTO gig_availability (gig_worker_profile_id, avail_range) VALUES (1, '[2025-01-01 09:00,2025-01-01 12:00]');
    INSERT INTO gig_availability (gig_worker_profile_id, avail_range) VALUES (1, '[2025-01-01 11:00,2025-01-01 14:00]');$$,
    'exclusion_constraint',
    'Overlapping availability windows are rejected');

-- 4. Subscription period overlap (exclusion constraint).
SELECT throws_ok($$INSERT INTO subscription (account_id, plan_id, period) VALUES (1, 1, '[2024-01-01,2024-12-31]');
    INSERT INTO subscription (account_id, plan_id, period) VALUES (1, 2, '[2024-06-01,2025-05-31]');$$,
    'exclusion_constraint',
    'Overlapping subscription periods are rejected');

-- 5. Notification delivery idempotency (unique delivery_key).
SELECT throws_ok($$INSERT INTO notification_delivery (user_id, provider, delivery_key, status) VALUES (1, 'email', 'msg-123', 'queued');
    INSERT INTO notification_delivery (user_id, provider, delivery_key, status) VALUES (1, 'email', 'msg-123', 'queued');$$,
    'unique_violation',
    'Duplicate delivery_key for same user is rejected');

SELECT * FROM finish();
ROLLBACK;
