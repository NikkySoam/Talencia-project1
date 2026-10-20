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
