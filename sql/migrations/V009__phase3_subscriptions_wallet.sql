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
