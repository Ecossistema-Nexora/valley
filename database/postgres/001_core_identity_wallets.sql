-- Valley Hybrid DB Bootstrap - Step 1
-- Core identity, PJ/Rider profiles, wallets and LED cards.
-- Source of truth: AGENTS instructions for this Valley worktree.

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

SET search_path = public;

CREATE TYPE user_kind_enum AS ENUM ('PF', 'PJ', 'RIDER', 'ADMIN', 'SYSTEM');
CREATE TYPE account_status_enum AS ENUM ('PENDING', 'ACTIVE', 'SUSPENDED', 'BLOCKED', 'ARCHIVED');
CREATE TYPE kyc_status_enum AS ENUM ('NOT_STARTED', 'PENDING', 'UNDER_REVIEW', 'APPROVED', 'REJECTED', 'EXPIRED');
CREATE TYPE wallet_asset_enum AS ENUM ('BRL', 'NEX');
CREATE TYPE wallet_type_enum AS ENUM ('CUSTODIAL', 'ESCROW', 'REWARDS', 'SETTLEMENT', 'EQUITY');
CREATE TYPE wallet_status_enum AS ENUM ('PENDING', 'ACTIVE', 'FROZEN', 'CLOSED');
CREATE TYPE led_card_status_enum AS ENUM ('UNASSIGNED', 'ASSIGNED', 'ACTIVE', 'BLOCKED', 'REVOKED', 'LOST');
CREATE TYPE rider_status_enum AS ENUM ('ONBOARDING', 'ACTIVE', 'INACTIVE', 'SUSPENDED', 'BLOCKED');

CREATE TABLE users (
    user_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_kind user_kind_enum NOT NULL DEFAULT 'PF',
    account_status account_status_enum NOT NULL DEFAULT 'PENDING',
    kyc_status kyc_status_enum NOT NULL DEFAULT 'NOT_STARTED',
    full_name TEXT NOT NULL,
    display_name TEXT,
    email TEXT,
    phone_e164 TEXT,
    birth_date DATE,
    birth_city TEXT,
    birth_state CHAR(2),
    document_country CHAR(2) NOT NULL DEFAULT 'BR',
    document_type TEXT NOT NULL,
    document_number TEXT NOT NULL,
    nationality CHAR(2),
    tax_residence_country CHAR(2),
    risk_level SMALLINT NOT NULL DEFAULT 0,
    primary_role TEXT NOT NULL DEFAULT 'USER',
    nexus_external_ref TEXT,
    led_card_default_id UUID,
    terms_accepted_at TIMESTAMPTZ,
    privacy_accepted_at TIMESTAMPTZ,
    last_login_at TIMESTAMPTZ,
    module_tier TEXT NOT NULL DEFAULT 'CORE',
    ops_region_code TEXT,
    compliance_notes TEXT,
    internal_tags TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_users_full_name_not_blank CHECK (btrim(full_name) <> ''),
    CONSTRAINT chk_users_birth_city_not_blank CHECK (
        birth_city IS NULL OR btrim(birth_city) <> ''
    ),
    CONSTRAINT chk_users_birth_state_format CHECK (
        birth_state IS NULL OR birth_state ~ '^[A-Z]{2}$'
    ),
    CONSTRAINT chk_users_document_country_format CHECK (document_country ~ '^[A-Z]{2}$'),
    CONSTRAINT chk_users_document_type_not_blank CHECK (btrim(document_type) <> ''),
    CONSTRAINT chk_users_document_number_not_blank CHECK (btrim(document_number) <> ''),
    CONSTRAINT chk_users_nationality_format CHECK (nationality IS NULL OR nationality ~ '^[A-Z]{2}$'),
    CONSTRAINT chk_users_tax_residence_country_format CHECK (
        tax_residence_country IS NULL OR tax_residence_country ~ '^[A-Z]{2}$'
    ),
    CONSTRAINT chk_users_risk_level_range CHECK (risk_level BETWEEN 0 AND 5),
    CONSTRAINT chk_users_email_format CHECK (
        email IS NULL OR email ~* '^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$'
    ),
    CONSTRAINT chk_users_phone_e164_format CHECK (
        phone_e164 IS NULL OR phone_e164 ~ '^\+[1-9][0-9]{7,14}$'
    ),
    CONSTRAINT chk_users_terms_privacy_order CHECK (
        privacy_accepted_at IS NULL
        OR terms_accepted_at IS NULL
        OR privacy_accepted_at >= terms_accepted_at - INTERVAL '5 minutes'
    )
);

CREATE UNIQUE INDEX ux_users_document
    ON users (document_country, document_type, document_number);

CREATE UNIQUE INDEX ux_users_email_lower
    ON users (lower(email))
    WHERE email IS NOT NULL;

CREATE UNIQUE INDEX ux_users_phone_e164
    ON users (phone_e164)
    WHERE phone_e164 IS NOT NULL;

CREATE UNIQUE INDEX ux_users_nexus_external_ref
    ON users (nexus_external_ref)
    WHERE nexus_external_ref IS NOT NULL;

CREATE INDEX ix_users_status_kind
    ON users (account_status, user_kind);

CREATE INDEX ix_users_kyc_status
    ON users (kyc_status);

CREATE INDEX ix_users_created_at
    ON users (created_at);

CREATE TABLE pj_profiles (
    pj_profile_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL UNIQUE,
    legal_name TEXT NOT NULL,
    trade_name TEXT,
    cnpj TEXT NOT NULL UNIQUE,
    state_registration TEXT,
    municipal_registration TEXT,
    tax_regime TEXT,
    cnae_primary TEXT,
    cnae_secondary TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
    legal_representative_name TEXT NOT NULL,
    legal_representative_document TEXT NOT NULL,
    billing_email TEXT,
    billing_phone TEXT,
    incorporation_date DATE,
    kyb_status kyc_status_enum NOT NULL DEFAULT 'NOT_STARTED',
    kyb_verified_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_pj_profiles_user
        FOREIGN KEY (user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT chk_pj_profiles_legal_name_not_blank CHECK (btrim(legal_name) <> ''),
    CONSTRAINT chk_pj_profiles_cnpj_format CHECK (cnpj ~ '^[0-9]{14}$'),
    CONSTRAINT chk_pj_profiles_legal_representative_not_blank CHECK (
        btrim(legal_representative_name) <> ''
        AND btrim(legal_representative_document) <> ''
    ),
    CONSTRAINT chk_pj_profiles_billing_email_format CHECK (
        billing_email IS NULL OR billing_email ~* '^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$'
    ),
    CONSTRAINT chk_pj_profiles_billing_phone_format CHECK (
        billing_phone IS NULL OR billing_phone ~ '^\+[1-9][0-9]{7,14}$'
    ),
    CONSTRAINT chk_pj_profiles_kyb_verified_consistency CHECK (
        kyb_verified_at IS NULL OR kyb_status = 'APPROVED'
    )
);

CREATE INDEX ix_pj_profiles_user_id
    ON pj_profiles (user_id);

CREATE INDEX ix_pj_profiles_kyb_status
    ON pj_profiles (kyb_status);

CREATE TABLE rider_profiles (
    rider_profile_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL UNIQUE,
    rider_status rider_status_enum NOT NULL DEFAULT 'ONBOARDING',
    mode_preference TEXT,
    vehicle_type TEXT,
    vehicle_plate TEXT,
    vehicle_model TEXT,
    driver_license_number TEXT,
    driver_license_category TEXT,
    driver_license_expires_at DATE,
    service_zone_code TEXT,
    availability_status TEXT NOT NULL DEFAULT 'OFFLINE',
    background_check_status kyc_status_enum NOT NULL DEFAULT 'NOT_STARTED',
    insurance_policy_ref TEXT,
    performance_score NUMERIC(5,2) NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_rider_profiles_user
        FOREIGN KEY (user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT chk_rider_profiles_availability_status CHECK (
        availability_status IN ('OFFLINE', 'ONLINE', 'BUSY', 'PAUSED')
    ),
    CONSTRAINT chk_rider_profiles_performance_score CHECK (
        performance_score >= 0 AND performance_score <= 100
    ),
    CONSTRAINT chk_rider_profiles_vehicle_plate_format CHECK (
        vehicle_plate IS NULL OR vehicle_plate ~ '^[A-Z0-9-]{5,12}$'
    )
);

CREATE INDEX ix_rider_profiles_user_id
    ON rider_profiles (user_id);

CREATE INDEX ix_rider_profiles_status_availability
    ON rider_profiles (rider_status, availability_status);

CREATE INDEX ix_rider_profiles_service_zone
    ON rider_profiles (service_zone_code);

CREATE TABLE wallets (
    wallet_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    wallet_type wallet_type_enum NOT NULL DEFAULT 'CUSTODIAL',
    asset_code wallet_asset_enum NOT NULL,
    wallet_status wallet_status_enum NOT NULL DEFAULT 'PENDING',
    balance_available_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    balance_blocked_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    balance_pending_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    balance_available_nex DECIMAL(18,8) NOT NULL DEFAULT 0,
    balance_blocked_nex DECIMAL(18,8) NOT NULL DEFAULT 0,
    balance_pending_nex DECIMAL(18,8) NOT NULL DEFAULT 0,
    daily_limit_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    monthly_limit_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    ledger_version BIGINT NOT NULL DEFAULT 0,
    last_reconciled_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_wallets_user
        FOREIGN KEY (user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT ux_wallets_user_type_asset UNIQUE (user_id, wallet_type, asset_code),
    CONSTRAINT chk_wallets_brl_balances_non_negative CHECK (
        balance_available_brl >= 0
        AND balance_blocked_brl >= 0
        AND balance_pending_brl >= 0
        AND daily_limit_brl >= 0
        AND monthly_limit_brl >= 0
    ),
    CONSTRAINT chk_wallets_nex_balances_non_negative CHECK (
        balance_available_nex >= 0
        AND balance_blocked_nex >= 0
        AND balance_pending_nex >= 0
    ),
    CONSTRAINT chk_wallets_ledger_version_non_negative CHECK (ledger_version >= 0),
    CONSTRAINT chk_wallets_asset_balance_coherence CHECK (
        (
            asset_code = 'BRL'
            AND balance_available_nex = 0
            AND balance_blocked_nex = 0
            AND balance_pending_nex = 0
        )
        OR
        (
            asset_code = 'NEX'
            AND balance_available_brl = 0
            AND balance_blocked_brl = 0
            AND balance_pending_brl = 0
            AND daily_limit_brl = 0
            AND monthly_limit_brl = 0
        )
    )
);

CREATE INDEX ix_wallets_user_id
    ON wallets (user_id);

CREATE INDEX ix_wallets_status_asset
    ON wallets (wallet_status, asset_code);

CREATE INDEX ix_wallets_last_reconciled_at
    ON wallets (last_reconciled_at);

CREATE TABLE led_cards (
    led_card_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    wallet_id UUID,
    card_uid TEXT NOT NULL UNIQUE,
    nfc_serial TEXT NOT NULL UNIQUE,
    token_reference TEXT,
    card_status led_card_status_enum NOT NULL DEFAULT 'UNASSIGNED',
    issued_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    assigned_at TIMESTAMPTZ,
    activated_at TIMESTAMPTZ,
    blocked_at TIMESTAMPTZ,
    revoked_at TIMESTAMPTZ,
    revocation_reason TEXT,
    last_handshake_at TIMESTAMPTZ,
    custody_notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_led_cards_user
        FOREIGN KEY (user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_led_cards_wallet
        FOREIGN KEY (wallet_id) REFERENCES wallets (wallet_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT chk_led_cards_card_uid_not_blank CHECK (btrim(card_uid) <> ''),
    CONSTRAINT chk_led_cards_nfc_serial_not_blank CHECK (btrim(nfc_serial) <> ''),
    CONSTRAINT chk_led_cards_revocation_consistency CHECK (
        (card_status NOT IN ('REVOKED', 'LOST') AND revoked_at IS NULL)
        OR
        (card_status IN ('REVOKED', 'LOST') AND revoked_at IS NOT NULL)
    ),
    CONSTRAINT chk_led_cards_activation_order CHECK (
        activated_at IS NULL
        OR assigned_at IS NULL
        OR activated_at >= assigned_at
    )
);

CREATE UNIQUE INDEX ux_led_cards_token_reference
    ON led_cards (token_reference)
    WHERE token_reference IS NOT NULL;

CREATE INDEX ix_led_cards_user_id
    ON led_cards (user_id);

CREATE INDEX ix_led_cards_wallet_id
    ON led_cards (wallet_id);

CREATE INDEX ix_led_cards_status
    ON led_cards (card_status);

ALTER TABLE users
    ADD CONSTRAINT fk_users_default_led_card
    FOREIGN KEY (led_card_default_id) REFERENCES led_cards (led_card_id)
    ON UPDATE CASCADE
    ON DELETE SET NULL;

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION assert_profile_user_kind()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    actual_kind user_kind_enum;
BEGIN
    SELECT user_kind
      INTO actual_kind
      FROM users
     WHERE user_id = NEW.user_id;

    IF actual_kind IS NULL THEN
        RAISE EXCEPTION 'User % does not exist for %', NEW.user_id, TG_TABLE_NAME;
    END IF;

    IF TG_TABLE_NAME = 'pj_profiles' AND actual_kind <> 'PJ' THEN
        RAISE EXCEPTION 'pj_profiles requires user_kind PJ. Found % for user %', actual_kind, NEW.user_id;
    END IF;

    IF TG_TABLE_NAME = 'rider_profiles' AND actual_kind <> 'RIDER' THEN
        RAISE EXCEPTION 'rider_profiles requires user_kind RIDER. Found % for user %', actual_kind, NEW.user_id;
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION assert_led_card_wallet_owner()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    wallet_owner_id UUID;
BEGIN
    IF NEW.wallet_id IS NULL THEN
        RETURN NEW;
    END IF;

    SELECT user_id
      INTO wallet_owner_id
      FROM wallets
     WHERE wallet_id = NEW.wallet_id;

    IF wallet_owner_id IS NULL THEN
        RAISE EXCEPTION 'Wallet % does not exist for LED card %', NEW.wallet_id, NEW.led_card_id;
    END IF;

    IF wallet_owner_id <> NEW.user_id THEN
        RAISE EXCEPTION 'LED card wallet owner % differs from LED card user %', wallet_owner_id, NEW.user_id;
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION assert_default_led_card_owner()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    card_owner_id UUID;
BEGIN
    IF NEW.led_card_default_id IS NULL THEN
        RETURN NEW;
    END IF;

    SELECT user_id
      INTO card_owner_id
      FROM led_cards
     WHERE led_card_id = NEW.led_card_default_id;

    IF card_owner_id IS NULL THEN
        RAISE EXCEPTION 'Default LED card % does not exist', NEW.led_card_default_id;
    END IF;

    IF card_owner_id <> NEW.user_id THEN
        RAISE EXCEPTION 'Default LED card owner % differs from user %', card_owner_id, NEW.user_id;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_users_set_updated_at
BEFORE UPDATE ON users
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_pj_profiles_set_updated_at
BEFORE UPDATE ON pj_profiles
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_rider_profiles_set_updated_at
BEFORE UPDATE ON rider_profiles
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_wallets_set_updated_at
BEFORE UPDATE ON wallets
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_led_cards_set_updated_at
BEFORE UPDATE ON led_cards
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_pj_profiles_assert_user_kind
BEFORE INSERT OR UPDATE OF user_id ON pj_profiles
FOR EACH ROW
EXECUTE FUNCTION assert_profile_user_kind();

CREATE TRIGGER trg_rider_profiles_assert_user_kind
BEFORE INSERT OR UPDATE OF user_id ON rider_profiles
FOR EACH ROW
EXECUTE FUNCTION assert_profile_user_kind();

CREATE TRIGGER trg_led_cards_assert_wallet_owner
BEFORE INSERT OR UPDATE OF user_id, wallet_id ON led_cards
FOR EACH ROW
EXECUTE FUNCTION assert_led_card_wallet_owner();

CREATE TRIGGER trg_users_assert_default_led_card_owner
BEFORE INSERT OR UPDATE OF led_card_default_id ON users
FOR EACH ROW
EXECUTE FUNCTION assert_default_led_card_owner();

COMMIT;
