-- Valley Hybrid DB Bootstrap - Fase 1 comercial focada.
-- Fecha o escopo operacional pedido para Financeiro, Stock, Marketplace, Checkout,
-- Signin/Login, perfis PF/PJ, Home, chat comprador-lojista, reviews, carrinho,
-- favoritos, SAC Valley e integracoes de dropshipping/checkout.

BEGIN;

SET search_path = public;

CREATE TYPE auth_identity_type_enum AS ENUM (
    'EMAIL_PASSWORD',
    'PHONE_OTP',
    'GOOGLE_OAUTH',
    'APPLE_OAUTH',
    'MAGIC_LINK'
);

CREATE TYPE auth_identity_status_enum AS ENUM (
    'PENDING_VERIFICATION',
    'ACTIVE',
    'LOCKED',
    'REVOKED'
);

CREATE TYPE auth_session_status_enum AS ENUM (
    'ACTIVE',
    'REFRESHED',
    'REVOKED',
    'EXPIRED'
);

CREATE TYPE auth_login_event_status_enum AS ENUM (
    'SUCCEEDED',
    'FAILED',
    'LOCKED',
    'REVOKED',
    'LOGOUT',
    'REFRESHED'
);

CREATE TYPE user_profile_status_enum AS ENUM (
    'DRAFT',
    'ACTIVE',
    'PAUSED',
    'ARCHIVED'
);

CREATE TYPE merchant_profile_status_enum AS ENUM (
    'ONBOARDING',
    'ACTIVE',
    'PAUSED',
    'SUSPENDED',
    'ARCHIVED'
);

CREATE TYPE home_surface_enum AS ENUM ('USER', 'MERCHANT');

CREATE TYPE checkout_provider_code_enum AS ENUM (
    'MERCADO_PAGO',
    'STRIPE',
    'PAGSEGURO',
    'ASAAS',
    'PICPAY',
    'MANUAL'
);

CREATE TYPE checkout_integration_status_enum AS ENUM (
    'DRAFT',
    'ACTIVE',
    'DEGRADED',
    'DISABLED',
    'REVOKED'
);

CREATE TYPE checkout_payment_method_enum AS ENUM (
    'PIX',
    'CARD',
    'BOLETO',
    'WALLET_BRL',
    'TOKEN_NEX',
    'LED_CARD_NFC'
);

CREATE TYPE checkout_intent_status_enum AS ENUM (
    'CREATED',
    'PENDING_CUSTOMER',
    'AUTHORIZED',
    'CAPTURED',
    'SETTLED',
    'FAILED',
    'CANCELLED',
    'EXPIRED',
    'REFUNDED'
);

CREATE TYPE commerce_chat_context_enum AS ENUM (
    'LISTING',
    'ORDER',
    'CHECKOUT',
    'SUPPORT'
);

CREATE TYPE shopping_cart_status_enum AS ENUM (
    'ACTIVE',
    'ABANDONED',
    'CONVERTED',
    'EXPIRED',
    'MERGED'
);

CREATE TYPE favorite_target_type_enum AS ENUM (
    'ITEM',
    'LISTING',
    'STOREFRONT',
    'MERCHANT'
);

CREATE TYPE marketplace_review_status_enum AS ENUM (
    'PENDING_MODERATION',
    'PUBLISHED',
    'HIDDEN',
    'ARCHIVED'
);

CREATE TYPE support_ticket_status_enum AS ENUM (
    'OPEN',
    'IN_PROGRESS',
    'WAITING_USER',
    'WAITING_MERCHANT',
    'RESOLVED',
    'CANCELLED'
);

CREATE TYPE support_ticket_priority_enum AS ENUM (
    'LOW',
    'NORMAL',
    'HIGH',
    'URGENT'
);

CREATE TYPE support_message_sender_type_enum AS ENUM (
    'USER',
    'MERCHANT',
    'AGENT',
    'BOT',
    'SYSTEM'
);

CREATE TABLE auth_identities (
    identity_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    identity_type auth_identity_type_enum NOT NULL,
    identity_status auth_identity_status_enum NOT NULL DEFAULT 'PENDING_VERIFICATION',
    login_identifier TEXT NOT NULL,
    login_identifier_normalized TEXT NOT NULL,
    email TEXT,
    phone_e164 TEXT,
    password_hash TEXT,
    password_algo TEXT,
    provider_subject TEXT,
    is_primary BOOLEAN NOT NULL DEFAULT FALSE,
    is_login_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    failed_login_count INTEGER NOT NULL DEFAULT 0,
    locked_until TIMESTAMPTZ,
    verified_at TIMESTAMPTZ,
    last_authenticated_at TIMESTAMPTZ,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_auth_identities_user
        FOREIGN KEY (user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT chk_auth_identities_identifier CHECK (btrim(login_identifier) <> ''),
    CONSTRAINT chk_auth_identities_identifier_normalized CHECK (btrim(login_identifier_normalized) <> ''),
    CONSTRAINT chk_auth_identities_email_format CHECK (
        email IS NULL OR email ~* '^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$'
    ),
    CONSTRAINT chk_auth_identities_phone_format CHECK (
        phone_e164 IS NULL OR phone_e164 ~ '^\+[1-9][0-9]{7,14}$'
    ),
    CONSTRAINT chk_auth_identities_password_requirement CHECK (
        identity_type <> 'EMAIL_PASSWORD'
        OR (password_hash IS NOT NULL AND length(password_hash) >= 32)
    ),
    CONSTRAINT chk_auth_identities_phone_requirement CHECK (
        identity_type <> 'PHONE_OTP'
        OR phone_e164 IS NOT NULL
    ),
    CONSTRAINT chk_auth_identities_provider_requirement CHECK (
        identity_type NOT IN ('GOOGLE_OAUTH', 'APPLE_OAUTH')
        OR (provider_subject IS NOT NULL AND btrim(provider_subject) <> '')
    ),
    CONSTRAINT chk_auth_identities_failed_login_count CHECK (failed_login_count >= 0),
    CONSTRAINT chk_auth_identities_metadata CHECK (jsonb_typeof(metadata_json) = 'object')
);

CREATE TABLE auth_sessions (
    session_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    identity_id UUID NOT NULL,
    session_status auth_session_status_enum NOT NULL DEFAULT 'ACTIVE',
    session_token_hash TEXT NOT NULL UNIQUE,
    refresh_token_hash TEXT UNIQUE,
    device_fingerprint TEXT,
    user_agent TEXT,
    ip_address TEXT,
    last_seen_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ NOT NULL,
    revoked_at TIMESTAMPTZ,
    revoke_reason TEXT,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_auth_sessions_user
        FOREIGN KEY (user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_auth_sessions_identity
        FOREIGN KEY (identity_id) REFERENCES auth_identities (identity_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT chk_auth_sessions_session_hash CHECK (length(session_token_hash) >= 32),
    CONSTRAINT chk_auth_sessions_refresh_hash CHECK (
        refresh_token_hash IS NULL OR length(refresh_token_hash) >= 32
    ),
    CONSTRAINT chk_auth_sessions_revoke_reason CHECK (
        revoke_reason IS NULL OR btrim(revoke_reason) <> ''
    ),
    CONSTRAINT chk_auth_sessions_timeline CHECK (
        expires_at > created_at
        AND (last_seen_at IS NULL OR last_seen_at >= created_at - INTERVAL '5 minutes')
        AND (revoked_at IS NULL OR revoked_at >= created_at)
    ),
    CONSTRAINT chk_auth_sessions_metadata CHECK (jsonb_typeof(metadata_json) = 'object')
);

CREATE TABLE auth_login_events (
    login_event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID,
    identity_id UUID,
    session_id UUID,
    login_identifier_normalized TEXT NOT NULL,
    event_status auth_login_event_status_enum NOT NULL,
    failure_reason TEXT,
    ip_address TEXT,
    user_agent TEXT,
    correlation_id TEXT,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_auth_login_events_user
        FOREIGN KEY (user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_auth_login_events_identity
        FOREIGN KEY (identity_id) REFERENCES auth_identities (identity_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_auth_login_events_session
        FOREIGN KEY (session_id) REFERENCES auth_sessions (session_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT chk_auth_login_events_identifier CHECK (btrim(login_identifier_normalized) <> ''),
    CONSTRAINT chk_auth_login_events_failure_reason CHECK (
        failure_reason IS NULL OR btrim(failure_reason) <> ''
    ),
    CONSTRAINT chk_auth_login_events_metadata CHECK (jsonb_typeof(metadata_json) = 'object')
);

CREATE TABLE user_profiles (
    user_profile_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL UNIQUE,
    profile_status user_profile_status_enum NOT NULL DEFAULT 'DRAFT',
    username TEXT,
    display_handle TEXT,
    bio_summary TEXT,
    profile_visibility TEXT NOT NULL DEFAULT 'PUBLIC',
    avatar_url TEXT,
    cover_url TEXT,
    default_shipping_address_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    preferences_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    marketing_opt_in BOOLEAN NOT NULL DEFAULT FALSE,
    support_opt_in BOOLEAN NOT NULL DEFAULT TRUE,
    onboarding_completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_user_profiles_user
        FOREIGN KEY (user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT chk_user_profiles_username CHECK (
        username IS NULL OR username ~ '^[a-z0-9._-]{3,40}$'
    ),
    CONSTRAINT chk_user_profiles_handle CHECK (
        display_handle IS NULL OR btrim(display_handle) <> ''
    ),
    CONSTRAINT chk_user_profiles_bio CHECK (
        bio_summary IS NULL OR btrim(bio_summary) <> ''
    ),
    CONSTRAINT chk_user_profiles_visibility CHECK (
        profile_visibility IN ('PUBLIC', 'PRIVATE', 'CONTACTS_ONLY')
    ),
    CONSTRAINT chk_user_profiles_shipping_json CHECK (
        jsonb_typeof(default_shipping_address_json) = 'object'
    ),
    CONSTRAINT chk_user_profiles_preferences_json CHECK (
        jsonb_typeof(preferences_json) = 'object'
    )
);

CREATE TABLE merchant_profiles (
    merchant_profile_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_user_id UUID NOT NULL UNIQUE,
    pj_profile_id UUID UNIQUE,
    wallet_id UUID NOT NULL,
    primary_storefront_id UUID,
    profile_status merchant_profile_status_enum NOT NULL DEFAULT 'ONBOARDING',
    merchant_code TEXT NOT NULL UNIQUE,
    slug TEXT NOT NULL UNIQUE,
    display_name TEXT NOT NULL,
    legal_name_override TEXT,
    support_email TEXT,
    support_phone_e164 TEXT,
    support_whatsapp_e164 TEXT,
    average_rating NUMERIC(4,2) NOT NULL DEFAULT 0,
    review_count INTEGER NOT NULL DEFAULT 0,
    response_sla_hours INTEGER NOT NULL DEFAULT 24,
    return_policy_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    shipping_policy_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    checkout_policy_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    support_policy_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    onboarding_completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_merchant_profiles_user
        FOREIGN KEY (merchant_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_merchant_profiles_pj
        FOREIGN KEY (pj_profile_id) REFERENCES pj_profiles (pj_profile_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_merchant_profiles_wallet
        FOREIGN KEY (wallet_id) REFERENCES wallets (wallet_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_merchant_profiles_storefront
        FOREIGN KEY (primary_storefront_id) REFERENCES merchant_storefronts (storefront_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT chk_merchant_profiles_code CHECK (merchant_code ~ '^[A-Z0-9_-]{3,64}$'),
    CONSTRAINT chk_merchant_profiles_slug CHECK (slug ~ '^[a-z0-9-]{3,80}$'),
    CONSTRAINT chk_merchant_profiles_display_name CHECK (btrim(display_name) <> ''),
    CONSTRAINT chk_merchant_profiles_support_email CHECK (
        support_email IS NULL OR support_email ~* '^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$'
    ),
    CONSTRAINT chk_merchant_profiles_support_phone CHECK (
        support_phone_e164 IS NULL OR support_phone_e164 ~ '^\+[1-9][0-9]{7,14}$'
    ),
    CONSTRAINT chk_merchant_profiles_support_whatsapp CHECK (
        support_whatsapp_e164 IS NULL OR support_whatsapp_e164 ~ '^\+[1-9][0-9]{7,14}$'
    ),
    CONSTRAINT chk_merchant_profiles_rating CHECK (
        average_rating >= 0 AND average_rating <= 5
    ),
    CONSTRAINT chk_merchant_profiles_review_count CHECK (review_count >= 0),
    CONSTRAINT chk_merchant_profiles_response_sla CHECK (response_sla_hours >= 0),
    CONSTRAINT chk_merchant_profiles_json_shapes CHECK (
        jsonb_typeof(return_policy_json) = 'object'
        AND jsonb_typeof(shipping_policy_json) = 'object'
        AND jsonb_typeof(checkout_policy_json) = 'object'
        AND jsonb_typeof(support_policy_json) = 'object'
        AND jsonb_typeof(metadata_json) = 'object'
    )
);

CREATE TABLE home_surface_preferences (
    home_surface_preference_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    home_surface home_surface_enum NOT NULL DEFAULT 'USER',
    default_wallet_id UUID,
    default_storefront_id UUID,
    hero_layout TEXT NOT NULL DEFAULT 'BALANCE_FIRST',
    visible_module_codes TEXT[] NOT NULL DEFAULT ARRAY[
        'HOME',
        'FINANCAS',
        'MARKETPLACE',
        'CHECKOUT',
        'CHAT',
        'FAVORITES',
        'ORDERS'
    ]::TEXT[],
    pinned_module_codes TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
    favorite_category_paths TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
    quick_actions_json JSONB NOT NULL DEFAULT '[]'::JSONB,
    widget_preferences_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    dock_state_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    last_context_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_home_surface_preferences_user
        FOREIGN KEY (user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_home_surface_preferences_wallet
        FOREIGN KEY (default_wallet_id) REFERENCES wallets (wallet_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_home_surface_preferences_storefront
        FOREIGN KEY (default_storefront_id) REFERENCES merchant_storefronts (storefront_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT ux_home_surface_preferences_surface UNIQUE (user_id, home_surface),
    CONSTRAINT chk_home_surface_preferences_hero_layout CHECK (btrim(hero_layout) <> ''),
    CONSTRAINT chk_home_surface_preferences_visible_modules CHECK (
        cardinality(visible_module_codes) > 0
    ),
    CONSTRAINT chk_home_surface_preferences_json_shapes CHECK (
        jsonb_typeof(quick_actions_json) = 'array'
        AND jsonb_typeof(widget_preferences_json) = 'object'
        AND jsonb_typeof(dock_state_json) = 'object'
        AND jsonb_typeof(last_context_json) = 'object'
    )
);

CREATE TABLE checkout_provider_configs (
    checkout_provider_config_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_user_id UUID NOT NULL,
    wallet_id UUID NOT NULL,
    provider_code checkout_provider_code_enum NOT NULL,
    integration_status checkout_integration_status_enum NOT NULL DEFAULT 'DRAFT',
    environment TEXT NOT NULL DEFAULT 'sandbox',
    provider_merchant_id TEXT,
    public_key_ref TEXT,
    access_token_ref TEXT,
    refresh_token_ref TEXT,
    webhook_secret_ref TEXT,
    webhook_url TEXT,
    statement_descriptor TEXT,
    settlement_delay_days INTEGER NOT NULL DEFAULT 0,
    supports_pix BOOLEAN NOT NULL DEFAULT TRUE,
    supports_card BOOLEAN NOT NULL DEFAULT TRUE,
    supports_boleto BOOLEAN NOT NULL DEFAULT FALSE,
    supports_wallet_balance BOOLEAN NOT NULL DEFAULT TRUE,
    supports_split BOOLEAN NOT NULL DEFAULT TRUE,
    accepts_nex_token BOOLEAN NOT NULL DEFAULT FALSE,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_checkout_provider_configs_merchant
        FOREIGN KEY (merchant_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_checkout_provider_configs_wallet
        FOREIGN KEY (wallet_id) REFERENCES wallets (wallet_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT ux_checkout_provider_configs_merchant_provider_env
        UNIQUE (merchant_user_id, provider_code, environment),
    CONSTRAINT chk_checkout_provider_configs_environment CHECK (
        environment IN ('sandbox', 'staging', 'production')
    ),
    CONSTRAINT chk_checkout_provider_configs_provider_merchant CHECK (
        provider_merchant_id IS NULL OR btrim(provider_merchant_id) <> ''
    ),
    CONSTRAINT chk_checkout_provider_configs_public_key_ref CHECK (
        public_key_ref IS NULL OR public_key_ref LIKE 'vault/%' OR public_key_ref LIKE 'secret/%' OR public_key_ref LIKE 'env/%'
    ),
    CONSTRAINT chk_checkout_provider_configs_access_token_ref CHECK (
        access_token_ref IS NULL OR access_token_ref LIKE 'vault/%' OR access_token_ref LIKE 'secret/%' OR access_token_ref LIKE 'env/%'
    ),
    CONSTRAINT chk_checkout_provider_configs_refresh_token_ref CHECK (
        refresh_token_ref IS NULL OR refresh_token_ref LIKE 'vault/%' OR refresh_token_ref LIKE 'secret/%' OR refresh_token_ref LIKE 'env/%'
    ),
    CONSTRAINT chk_checkout_provider_configs_webhook_secret_ref CHECK (
        webhook_secret_ref IS NULL OR webhook_secret_ref LIKE 'vault/%' OR webhook_secret_ref LIKE 'secret/%' OR webhook_secret_ref LIKE 'env/%'
    ),
    CONSTRAINT chk_checkout_provider_configs_webhook_url CHECK (
        webhook_url IS NULL OR webhook_url ~ '^https?://'
    ),
    CONSTRAINT chk_checkout_provider_configs_statement_descriptor CHECK (
        statement_descriptor IS NULL OR btrim(statement_descriptor) <> ''
    ),
    CONSTRAINT chk_checkout_provider_configs_settlement_delay CHECK (settlement_delay_days >= 0),
    CONSTRAINT chk_checkout_provider_configs_metadata CHECK (jsonb_typeof(metadata_json) = 'object')
);

CREATE TABLE checkout_payment_intents (
    checkout_intent_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID,
    buyer_user_id UUID NOT NULL,
    merchant_user_id UUID NOT NULL,
    merchant_wallet_id UUID NOT NULL,
    checkout_provider_config_id UUID,
    source_transaction_id UUID,
    idempotency_key TEXT NOT NULL UNIQUE,
    intent_status checkout_intent_status_enum NOT NULL DEFAULT 'CREATED',
    payment_method checkout_payment_method_enum NOT NULL,
    amount_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    amount_nex DECIMAL(18,8) NOT NULL DEFAULT 0,
    service_fee_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    platform_fee_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    merchant_net_amount_brl DECIMAL(18,4) GENERATED ALWAYS AS (
        GREATEST(amount_brl - service_fee_brl - platform_fee_brl, 0)
    ) STORED,
    external_intent_id TEXT,
    checkout_url TEXT,
    qr_code_payload TEXT,
    split_rule_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    failure_reason TEXT,
    expires_at TIMESTAMPTZ,
    authorized_at TIMESTAMPTZ,
    captured_at TIMESTAMPTZ,
    settled_at TIMESTAMPTZ,
    failed_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_checkout_payment_intents_order
        FOREIGN KEY (order_id) REFERENCES orders (order_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_checkout_payment_intents_buyer
        FOREIGN KEY (buyer_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_checkout_payment_intents_merchant
        FOREIGN KEY (merchant_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_checkout_payment_intents_wallet
        FOREIGN KEY (merchant_wallet_id) REFERENCES wallets (wallet_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_checkout_payment_intents_provider
        FOREIGN KEY (checkout_provider_config_id) REFERENCES checkout_provider_configs (checkout_provider_config_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_checkout_payment_intents_transaction
        FOREIGN KEY (source_transaction_id) REFERENCES transactions (transaction_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT chk_checkout_payment_intents_idempotency_key CHECK (btrim(idempotency_key) <> ''),
    CONSTRAINT chk_checkout_payment_intents_amounts CHECK (
        amount_brl >= 0
        AND amount_nex >= 0
        AND service_fee_brl >= 0
        AND platform_fee_brl >= 0
        AND (amount_brl > 0 OR amount_nex > 0)
    ),
    CONSTRAINT chk_checkout_payment_intents_method_amount_coherence CHECK (
        (payment_method = 'TOKEN_NEX' AND amount_nex > 0)
        OR (payment_method <> 'TOKEN_NEX' AND amount_brl > 0)
    ),
    CONSTRAINT chk_checkout_payment_intents_checkout_url CHECK (
        checkout_url IS NULL OR checkout_url ~ '^https?://'
    ),
    CONSTRAINT chk_checkout_payment_intents_external_intent CHECK (
        external_intent_id IS NULL OR btrim(external_intent_id) <> ''
    ),
    CONSTRAINT chk_checkout_payment_intents_failure_reason CHECK (
        failure_reason IS NULL OR btrim(failure_reason) <> ''
    ),
    CONSTRAINT chk_checkout_payment_intents_split_rule_json CHECK (
        jsonb_typeof(split_rule_json) = 'object'
    ),
    CONSTRAINT chk_checkout_payment_intents_metadata_json CHECK (
        jsonb_typeof(metadata_json) = 'object'
    ),
    CONSTRAINT chk_checkout_payment_intents_timeline CHECK (
        (expires_at IS NULL OR expires_at >= created_at)
        AND (authorized_at IS NULL OR authorized_at >= created_at)
        AND (captured_at IS NULL OR authorized_at IS NULL OR captured_at >= authorized_at)
        AND (settled_at IS NULL OR captured_at IS NULL OR settled_at >= captured_at)
        AND (failed_at IS NULL OR failed_at >= created_at)
        AND (cancelled_at IS NULL OR cancelled_at >= created_at)
    )
);

CREATE TABLE checkout_webhook_events (
    checkout_webhook_event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    checkout_provider_config_id UUID,
    merchant_user_id UUID NOT NULL,
    order_id UUID,
    checkout_intent_id UUID,
    transaction_id UUID,
    provider_event_id TEXT NOT NULL,
    event_type TEXT NOT NULL,
    event_status TEXT NOT NULL DEFAULT 'RECEIVED',
    signature_valid BOOLEAN NOT NULL DEFAULT FALSE,
    payload_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    processed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_checkout_webhook_events_provider
        FOREIGN KEY (checkout_provider_config_id) REFERENCES checkout_provider_configs (checkout_provider_config_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_checkout_webhook_events_merchant
        FOREIGN KEY (merchant_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_checkout_webhook_events_order
        FOREIGN KEY (order_id) REFERENCES orders (order_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_checkout_webhook_events_intent
        FOREIGN KEY (checkout_intent_id) REFERENCES checkout_payment_intents (checkout_intent_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_checkout_webhook_events_transaction
        FOREIGN KEY (transaction_id) REFERENCES transactions (transaction_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT ux_checkout_webhook_events_provider_event UNIQUE (checkout_provider_config_id, provider_event_id),
    CONSTRAINT chk_checkout_webhook_events_provider_event CHECK (btrim(provider_event_id) <> ''),
    CONSTRAINT chk_checkout_webhook_events_type CHECK (btrim(event_type) <> ''),
    CONSTRAINT chk_checkout_webhook_events_status CHECK (btrim(event_status) <> ''),
    CONSTRAINT chk_checkout_webhook_events_payload CHECK (jsonb_typeof(payload_json) = 'object'),
    CONSTRAINT chk_checkout_webhook_events_processed_at CHECK (
        processed_at IS NULL OR processed_at >= created_at
    )
);

CREATE TABLE commerce_chat_threads (
    commerce_chat_thread_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL UNIQUE,
    buyer_user_id UUID NOT NULL,
    merchant_user_id UUID NOT NULL,
    storefront_id UUID,
    listing_id UUID,
    order_id UUID,
    checkout_intent_id UUID,
    thread_context commerce_chat_context_enum NOT NULL DEFAULT 'LISTING',
    last_message_at TIMESTAMPTZ,
    is_blocked_by_buyer BOOLEAN NOT NULL DEFAULT FALSE,
    is_blocked_by_merchant BOOLEAN NOT NULL DEFAULT FALSE,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_commerce_chat_threads_conversation
        FOREIGN KEY (conversation_id) REFERENCES chat_conversations (conversation_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_commerce_chat_threads_buyer
        FOREIGN KEY (buyer_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_commerce_chat_threads_merchant
        FOREIGN KEY (merchant_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_commerce_chat_threads_storefront
        FOREIGN KEY (storefront_id) REFERENCES merchant_storefronts (storefront_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_commerce_chat_threads_listing
        FOREIGN KEY (listing_id) REFERENCES marketplace_listings (listing_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_commerce_chat_threads_order
        FOREIGN KEY (order_id) REFERENCES orders (order_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_commerce_chat_threads_intent
        FOREIGN KEY (checkout_intent_id) REFERENCES checkout_payment_intents (checkout_intent_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT chk_commerce_chat_threads_distinct_users CHECK (buyer_user_id <> merchant_user_id),
    CONSTRAINT chk_commerce_chat_threads_metadata CHECK (jsonb_typeof(metadata_json) = 'object')
);

CREATE TABLE shopping_carts (
    cart_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    merchant_user_id UUID NOT NULL,
    storefront_id UUID,
    checkout_provider_config_id UUID,
    cart_status shopping_cart_status_enum NOT NULL DEFAULT 'ACTIVE',
    currency_code CHAR(3) NOT NULL DEFAULT 'BRL',
    line_count INTEGER NOT NULL DEFAULT 0,
    total_quantity DECIMAL(18,4) NOT NULL DEFAULT 0,
    subtotal_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    discount_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    freight_estimate_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    total_estimate_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    expires_at TIMESTAMPTZ,
    converted_order_id UUID,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_shopping_carts_user
        FOREIGN KEY (user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_shopping_carts_merchant
        FOREIGN KEY (merchant_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_shopping_carts_storefront
        FOREIGN KEY (storefront_id) REFERENCES merchant_storefronts (storefront_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_shopping_carts_provider
        FOREIGN KEY (checkout_provider_config_id) REFERENCES checkout_provider_configs (checkout_provider_config_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_shopping_carts_converted_order
        FOREIGN KEY (converted_order_id) REFERENCES orders (order_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT chk_shopping_carts_currency_code CHECK (currency_code = 'BRL'),
    CONSTRAINT chk_shopping_carts_counts CHECK (
        line_count >= 0
        AND total_quantity >= 0
    ),
    CONSTRAINT chk_shopping_carts_amounts CHECK (
        subtotal_brl >= 0
        AND discount_brl >= 0
        AND freight_estimate_brl >= 0
        AND total_estimate_brl >= 0
        AND total_estimate_brl = subtotal_brl - discount_brl + freight_estimate_brl
    ),
    CONSTRAINT chk_shopping_carts_expiration CHECK (
        expires_at IS NULL OR expires_at >= created_at
    ),
    CONSTRAINT chk_shopping_carts_metadata CHECK (jsonb_typeof(metadata_json) = 'object')
);

CREATE TABLE shopping_cart_items (
    cart_item_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cart_id UUID NOT NULL,
    user_id UUID NOT NULL,
    merchant_user_id UUID NOT NULL,
    item_id UUID NOT NULL,
    listing_id UUID NOT NULL,
    product_source_id UUID,
    quantity DECIMAL(18,4) NOT NULL,
    unit_price_brl DECIMAL(18,4) NOT NULL,
    unit_discount_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    line_total_brl DECIMAL(18,4) GENERATED ALWAYS AS (
        quantity * GREATEST(unit_price_brl - unit_discount_brl, 0)
    ) STORED,
    selected_attributes_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    reservation_expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_shopping_cart_items_cart
        FOREIGN KEY (cart_id) REFERENCES shopping_carts (cart_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT fk_shopping_cart_items_user
        FOREIGN KEY (user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_shopping_cart_items_merchant
        FOREIGN KEY (merchant_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_shopping_cart_items_item
        FOREIGN KEY (item_id) REFERENCES inventory_items (item_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_shopping_cart_items_listing
        FOREIGN KEY (listing_id) REFERENCES marketplace_listings (listing_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_shopping_cart_items_product_source
        FOREIGN KEY (product_source_id) REFERENCES dropshipping_product_sources (product_source_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT ux_shopping_cart_items_cart_listing UNIQUE (cart_id, listing_id),
    CONSTRAINT chk_shopping_cart_items_quantity CHECK (quantity > 0),
    CONSTRAINT chk_shopping_cart_items_prices CHECK (
        unit_price_brl >= 0
        AND unit_discount_brl >= 0
        AND unit_discount_brl <= unit_price_brl
    ),
    CONSTRAINT chk_shopping_cart_items_attributes CHECK (
        jsonb_typeof(selected_attributes_json) = 'object'
    ),
    CONSTRAINT chk_shopping_cart_items_reservation CHECK (
        reservation_expires_at IS NULL OR reservation_expires_at >= created_at
    )
);

CREATE TABLE user_favorites (
    favorite_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    target_type favorite_target_type_enum NOT NULL,
    item_id UUID,
    listing_id UUID,
    storefront_id UUID,
    merchant_user_id UUID,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_user_favorites_user
        FOREIGN KEY (user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_user_favorites_item
        FOREIGN KEY (item_id) REFERENCES inventory_items (item_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT fk_user_favorites_listing
        FOREIGN KEY (listing_id) REFERENCES marketplace_listings (listing_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT fk_user_favorites_storefront
        FOREIGN KEY (storefront_id) REFERENCES merchant_storefronts (storefront_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT fk_user_favorites_merchant
        FOREIGN KEY (merchant_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT chk_user_favorites_notes CHECK (notes IS NULL OR btrim(notes) <> '')
);

CREATE TABLE marketplace_item_reviews (
    review_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    item_id UUID NOT NULL,
    listing_id UUID,
    order_id UUID,
    review_author_user_id UUID NOT NULL,
    merchant_user_id UUID NOT NULL,
    storefront_id UUID,
    review_status marketplace_review_status_enum NOT NULL DEFAULT 'PENDING_MODERATION',
    rating SMALLINT NOT NULL,
    review_title TEXT,
    review_body TEXT,
    merchant_reply_text TEXT,
    merchant_replied_at TIMESTAMPTZ,
    verified_purchase BOOLEAN NOT NULL DEFAULT FALSE,
    is_anonymous BOOLEAN NOT NULL DEFAULT FALSE,
    helpful_count INTEGER NOT NULL DEFAULT 0,
    media_refs_json JSONB NOT NULL DEFAULT '[]'::JSONB,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_marketplace_item_reviews_item
        FOREIGN KEY (item_id) REFERENCES inventory_items (item_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_marketplace_item_reviews_listing
        FOREIGN KEY (listing_id) REFERENCES marketplace_listings (listing_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_marketplace_item_reviews_order
        FOREIGN KEY (order_id) REFERENCES orders (order_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_marketplace_item_reviews_author
        FOREIGN KEY (review_author_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_marketplace_item_reviews_merchant
        FOREIGN KEY (merchant_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_marketplace_item_reviews_storefront
        FOREIGN KEY (storefront_id) REFERENCES merchant_storefronts (storefront_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT chk_marketplace_item_reviews_rating CHECK (rating BETWEEN 1 AND 5),
    CONSTRAINT chk_marketplace_item_reviews_title CHECK (
        review_title IS NULL OR btrim(review_title) <> ''
    ),
    CONSTRAINT chk_marketplace_item_reviews_body CHECK (
        review_body IS NULL OR btrim(review_body) <> ''
    ),
    CONSTRAINT chk_marketplace_item_reviews_reply CHECK (
        merchant_reply_text IS NULL OR btrim(merchant_reply_text) <> ''
    ),
    CONSTRAINT chk_marketplace_item_reviews_reply_timeline CHECK (
        merchant_replied_at IS NULL OR merchant_replied_at >= created_at
    ),
    CONSTRAINT chk_marketplace_item_reviews_helpful_count CHECK (helpful_count >= 0),
    CONSTRAINT chk_marketplace_item_reviews_media_json CHECK (jsonb_typeof(media_refs_json) = 'array'),
    CONSTRAINT chk_marketplace_item_reviews_metadata_json CHECK (jsonb_typeof(metadata_json) = 'object')
);

CREATE TABLE support_tickets (
    support_ticket_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    requester_user_id UUID NOT NULL,
    merchant_user_id UUID,
    storefront_id UUID,
    order_id UUID,
    transaction_id UUID,
    checkout_intent_id UUID,
    related_conversation_id UUID,
    ticket_number TEXT UNIQUE,
    ticket_status support_ticket_status_enum NOT NULL DEFAULT 'OPEN',
    priority support_ticket_priority_enum NOT NULL DEFAULT 'NORMAL',
    issue_category TEXT NOT NULL,
    subject TEXT NOT NULL,
    description TEXT NOT NULL,
    assigned_admin_id UUID,
    first_response_due_at TIMESTAMPTZ,
    resolved_at TIMESTAMPTZ,
    satisfaction_rating SMALLINT,
    resolution_summary TEXT,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_support_tickets_requester
        FOREIGN KEY (requester_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_support_tickets_merchant
        FOREIGN KEY (merchant_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_support_tickets_storefront
        FOREIGN KEY (storefront_id) REFERENCES merchant_storefronts (storefront_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_support_tickets_order
        FOREIGN KEY (order_id) REFERENCES orders (order_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_support_tickets_transaction
        FOREIGN KEY (transaction_id) REFERENCES transactions (transaction_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_support_tickets_intent
        FOREIGN KEY (checkout_intent_id) REFERENCES checkout_payment_intents (checkout_intent_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_support_tickets_conversation
        FOREIGN KEY (related_conversation_id) REFERENCES chat_conversations (conversation_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_support_tickets_admin
        FOREIGN KEY (assigned_admin_id) REFERENCES admin_users (admin_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT chk_support_tickets_ticket_number CHECK (
        ticket_number IS NULL OR btrim(ticket_number) <> ''
    ),
    CONSTRAINT chk_support_tickets_issue_category CHECK (btrim(issue_category) <> ''),
    CONSTRAINT chk_support_tickets_subject CHECK (btrim(subject) <> ''),
    CONSTRAINT chk_support_tickets_description CHECK (btrim(description) <> ''),
    CONSTRAINT chk_support_tickets_satisfaction_rating CHECK (
        satisfaction_rating IS NULL OR satisfaction_rating BETWEEN 1 AND 5
    ),
    CONSTRAINT chk_support_tickets_resolution_summary CHECK (
        resolution_summary IS NULL OR btrim(resolution_summary) <> ''
    ),
    CONSTRAINT chk_support_tickets_timeline CHECK (
        (first_response_due_at IS NULL OR first_response_due_at >= created_at)
        AND (resolved_at IS NULL OR resolved_at >= created_at)
    ),
    CONSTRAINT chk_support_tickets_metadata_json CHECK (jsonb_typeof(metadata_json) = 'object')
);

CREATE TABLE support_ticket_messages (
    support_ticket_message_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    support_ticket_id UUID NOT NULL,
    sender_user_id UUID,
    sender_admin_id UUID,
    sender_type support_message_sender_type_enum NOT NULL,
    message_body TEXT NOT NULL,
    attachment_refs_json JSONB NOT NULL DEFAULT '[]'::JSONB,
    internal_note BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_support_ticket_messages_ticket
        FOREIGN KEY (support_ticket_id) REFERENCES support_tickets (support_ticket_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT fk_support_ticket_messages_user
        FOREIGN KEY (sender_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_support_ticket_messages_admin
        FOREIGN KEY (sender_admin_id) REFERENCES admin_users (admin_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT chk_support_ticket_messages_body CHECK (btrim(message_body) <> ''),
    CONSTRAINT chk_support_ticket_messages_attachments CHECK (
        jsonb_typeof(attachment_refs_json) = 'array'
    )
);

CREATE UNIQUE INDEX ux_auth_identities_type_identifier
    ON auth_identities (identity_type, login_identifier_normalized);

CREATE UNIQUE INDEX ux_auth_identities_primary_per_user
    ON auth_identities (user_id)
    WHERE is_primary;

CREATE INDEX ix_auth_identities_user_status
    ON auth_identities (user_id, identity_status, identity_type);

CREATE INDEX ix_auth_sessions_user_status
    ON auth_sessions (user_id, session_status, expires_at);

CREATE INDEX ix_auth_sessions_identity_status
    ON auth_sessions (identity_id, session_status, expires_at);

CREATE INDEX ix_auth_login_events_identifier_time
    ON auth_login_events (login_identifier_normalized, occurred_at DESC);

CREATE UNIQUE INDEX ux_user_profiles_username_lower
    ON user_profiles (lower(username))
    WHERE username IS NOT NULL;

CREATE INDEX ix_merchant_profiles_status
    ON merchant_profiles (profile_status, created_at);

CREATE INDEX ix_home_surface_preferences_user_surface
    ON home_surface_preferences (user_id, home_surface);

CREATE INDEX ix_checkout_provider_configs_merchant_status
    ON checkout_provider_configs (merchant_user_id, integration_status, provider_code);

CREATE INDEX ix_checkout_payment_intents_buyer_status
    ON checkout_payment_intents (buyer_user_id, intent_status, created_at DESC);

CREATE INDEX ix_checkout_payment_intents_merchant_status
    ON checkout_payment_intents (merchant_user_id, intent_status, created_at DESC);

CREATE INDEX ix_checkout_payment_intents_order
    ON checkout_payment_intents (order_id)
    WHERE order_id IS NOT NULL;

CREATE INDEX ix_checkout_webhook_events_merchant_created_at
    ON checkout_webhook_events (merchant_user_id, created_at DESC);

CREATE INDEX ix_commerce_chat_threads_buyer
    ON commerce_chat_threads (buyer_user_id, last_message_at DESC NULLS LAST);

CREATE INDEX ix_commerce_chat_threads_merchant
    ON commerce_chat_threads (merchant_user_id, last_message_at DESC NULLS LAST);

CREATE UNIQUE INDEX ux_shopping_carts_active_scope
    ON shopping_carts (
        user_id,
        merchant_user_id,
        COALESCE(storefront_id, '00000000-0000-0000-0000-000000000000'::UUID)
    )
    WHERE cart_status = 'ACTIVE';

CREATE INDEX ix_shopping_carts_user_status
    ON shopping_carts (user_id, cart_status, updated_at DESC);

CREATE INDEX ix_shopping_cart_items_listing
    ON shopping_cart_items (listing_id, created_at);

CREATE UNIQUE INDEX ux_user_favorites_item
    ON user_favorites (user_id, item_id)
    WHERE item_id IS NOT NULL;

CREATE UNIQUE INDEX ux_user_favorites_listing
    ON user_favorites (user_id, listing_id)
    WHERE listing_id IS NOT NULL;

CREATE UNIQUE INDEX ux_user_favorites_storefront
    ON user_favorites (user_id, storefront_id)
    WHERE storefront_id IS NOT NULL;

CREATE UNIQUE INDEX ux_user_favorites_merchant
    ON user_favorites (user_id, merchant_user_id)
    WHERE merchant_user_id IS NOT NULL;

CREATE UNIQUE INDEX ux_marketplace_item_reviews_author_scope
    ON marketplace_item_reviews (
        review_author_user_id,
        item_id,
        COALESCE(order_id, '00000000-0000-0000-0000-000000000000'::UUID)
    );

CREATE INDEX ix_marketplace_item_reviews_listing_status
    ON marketplace_item_reviews (listing_id, review_status, created_at DESC)
    WHERE listing_id IS NOT NULL;

CREATE INDEX ix_marketplace_item_reviews_merchant_status
    ON marketplace_item_reviews (merchant_user_id, review_status, created_at DESC);

CREATE INDEX ix_support_tickets_requester_status
    ON support_tickets (requester_user_id, ticket_status, created_at DESC);

CREATE INDEX ix_support_tickets_merchant_status
    ON support_tickets (merchant_user_id, ticket_status, created_at DESC)
    WHERE merchant_user_id IS NOT NULL;

CREATE INDEX ix_support_ticket_messages_ticket_time
    ON support_ticket_messages (support_ticket_id, created_at);

CREATE OR REPLACE FUNCTION normalize_auth_identity()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.login_identifier := btrim(NEW.login_identifier);
    NEW.login_identifier_normalized := lower(btrim(NEW.login_identifier_normalized));

    IF NEW.email IS NOT NULL THEN
        NEW.email := lower(btrim(NEW.email));
    END IF;

    IF NEW.password_algo IS NOT NULL THEN
        NEW.password_algo := btrim(NEW.password_algo);
    END IF;

    IF NEW.provider_subject IS NOT NULL THEN
        NEW.provider_subject := btrim(NEW.provider_subject);
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION assert_merchant_profile_coherence()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    wallet_owner_id UUID;
    wallet_type_value wallet_type_enum;
    profile_user_id UUID;
    storefront_owner_id UUID;
BEGIN
    SELECT user_id, wallet_type
      INTO wallet_owner_id, wallet_type_value
      FROM wallets
     WHERE wallet_id = NEW.wallet_id;

    IF wallet_owner_id IS NULL THEN
        RAISE EXCEPTION 'Wallet % does not exist for merchant profile %', NEW.wallet_id, NEW.merchant_profile_id;
    END IF;

    IF wallet_owner_id <> NEW.merchant_user_id THEN
        RAISE EXCEPTION 'Merchant wallet owner % differs from merchant user %', wallet_owner_id, NEW.merchant_user_id;
    END IF;

    IF wallet_type_value NOT IN ('CUSTODIAL', 'SETTLEMENT') THEN
        RAISE EXCEPTION 'Merchant profile wallet must be CUSTODIAL or SETTLEMENT. Found %', wallet_type_value;
    END IF;

    IF NEW.pj_profile_id IS NOT NULL THEN
        SELECT user_id
          INTO profile_user_id
          FROM pj_profiles
         WHERE pj_profile_id = NEW.pj_profile_id;

        IF profile_user_id IS NULL OR profile_user_id <> NEW.merchant_user_id THEN
            RAISE EXCEPTION 'PJ profile % does not belong to merchant user %', NEW.pj_profile_id, NEW.merchant_user_id;
        END IF;
    END IF;

    IF NEW.primary_storefront_id IS NOT NULL THEN
        SELECT merchant_user_id
          INTO storefront_owner_id
          FROM merchant_storefronts
         WHERE storefront_id = NEW.primary_storefront_id;

        IF storefront_owner_id IS NULL OR storefront_owner_id <> NEW.merchant_user_id THEN
            RAISE EXCEPTION 'Storefront % does not belong to merchant user %', NEW.primary_storefront_id, NEW.merchant_user_id;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION assert_home_surface_coherence()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    wallet_owner_id UUID;
    storefront_owner_id UUID;
BEGIN
    IF NEW.default_wallet_id IS NOT NULL THEN
        SELECT user_id
          INTO wallet_owner_id
          FROM wallets
         WHERE wallet_id = NEW.default_wallet_id;

        IF wallet_owner_id IS NULL OR wallet_owner_id <> NEW.user_id THEN
            RAISE EXCEPTION 'Home preference wallet % does not belong to user %', NEW.default_wallet_id, NEW.user_id;
        END IF;
    END IF;

    IF NEW.default_storefront_id IS NOT NULL THEN
        SELECT merchant_user_id
          INTO storefront_owner_id
          FROM merchant_storefronts
         WHERE storefront_id = NEW.default_storefront_id;

        IF storefront_owner_id IS NULL THEN
            RAISE EXCEPTION 'Home preference storefront % does not exist', NEW.default_storefront_id;
        END IF;

        IF NEW.home_surface = 'MERCHANT' AND storefront_owner_id <> NEW.user_id THEN
            RAISE EXCEPTION 'Merchant home surface requires storefront owned by user %', NEW.user_id;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION assert_checkout_provider_coherence()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    wallet_owner_id UUID;
BEGIN
    SELECT user_id
      INTO wallet_owner_id
      FROM wallets
     WHERE wallet_id = NEW.wallet_id;

    IF wallet_owner_id IS NULL THEN
        RAISE EXCEPTION 'Checkout wallet % does not exist', NEW.wallet_id;
    END IF;

    IF wallet_owner_id <> NEW.merchant_user_id THEN
        RAISE EXCEPTION 'Checkout wallet owner % differs from merchant user %', wallet_owner_id, NEW.merchant_user_id;
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION assert_checkout_intent_coherence()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    wallet_owner_id UUID;
    provider_owner_id UUID;
    order_user_id UUID;
    order_merchant_id UUID;
    order_restaurant_id UUID;
BEGIN
    SELECT user_id
      INTO wallet_owner_id
      FROM wallets
     WHERE wallet_id = NEW.merchant_wallet_id;

    IF wallet_owner_id IS NULL OR wallet_owner_id <> NEW.merchant_user_id THEN
        RAISE EXCEPTION 'Checkout merchant wallet % is not owned by merchant user %', NEW.merchant_wallet_id, NEW.merchant_user_id;
    END IF;

    IF NEW.checkout_provider_config_id IS NOT NULL THEN
        SELECT merchant_user_id
          INTO provider_owner_id
          FROM checkout_provider_configs
         WHERE checkout_provider_config_id = NEW.checkout_provider_config_id;

        IF provider_owner_id IS NULL OR provider_owner_id <> NEW.merchant_user_id THEN
            RAISE EXCEPTION 'Checkout provider config % does not belong to merchant user %', NEW.checkout_provider_config_id, NEW.merchant_user_id;
        END IF;
    END IF;

    IF NEW.order_id IS NOT NULL THEN
        SELECT user_id, merchant_user_id, restaurant_user_id
          INTO order_user_id, order_merchant_id, order_restaurant_id
          FROM orders
         WHERE order_id = NEW.order_id;

        IF order_user_id IS NULL THEN
            RAISE EXCEPTION 'Order % does not exist for checkout intent %', NEW.order_id, NEW.checkout_intent_id;
        END IF;

        IF order_user_id <> NEW.buyer_user_id THEN
            RAISE EXCEPTION 'Checkout buyer % differs from order buyer %', NEW.buyer_user_id, order_user_id;
        END IF;

        IF (order_merchant_id IS NOT NULL OR order_restaurant_id IS NOT NULL)
           AND NEW.merchant_user_id <> COALESCE(order_merchant_id, NEW.merchant_user_id)
           AND NEW.merchant_user_id <> COALESCE(order_restaurant_id, NEW.merchant_user_id) THEN
            RAISE EXCEPTION 'Checkout merchant % differs from order merchant/restaurant for order %', NEW.merchant_user_id, NEW.order_id;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION assert_commerce_chat_thread_coherence()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    participant_a UUID;
    participant_b UUID;
    storefront_owner_id UUID;
    listing_merchant_id UUID;
    order_buyer_id UUID;
    order_merchant_id UUID;
    intent_buyer_id UUID;
    intent_merchant_id UUID;
BEGIN
    SELECT participant1_id, participant2_id
      INTO participant_a, participant_b
      FROM chat_conversations
     WHERE conversation_id = NEW.conversation_id;

    IF participant_a IS NULL THEN
        RAISE EXCEPTION 'Conversation % does not exist for commerce thread %', NEW.conversation_id, NEW.commerce_chat_thread_id;
    END IF;

    IF ARRAY[participant_a, participant_b] <> ARRAY[NEW.buyer_user_id, NEW.merchant_user_id]
       AND ARRAY[participant_a, participant_b] <> ARRAY[NEW.merchant_user_id, NEW.buyer_user_id] THEN
        RAISE EXCEPTION 'Conversation participants do not match buyer % and merchant %', NEW.buyer_user_id, NEW.merchant_user_id;
    END IF;

    IF NEW.storefront_id IS NOT NULL THEN
        SELECT merchant_user_id
          INTO storefront_owner_id
          FROM merchant_storefronts
         WHERE storefront_id = NEW.storefront_id;

        IF storefront_owner_id IS NULL OR storefront_owner_id <> NEW.merchant_user_id THEN
            RAISE EXCEPTION 'Storefront % does not belong to merchant %', NEW.storefront_id, NEW.merchant_user_id;
        END IF;
    END IF;

    IF NEW.listing_id IS NOT NULL THEN
        SELECT merchant_user_id
          INTO listing_merchant_id
          FROM marketplace_listings
         WHERE listing_id = NEW.listing_id;

        IF listing_merchant_id IS NULL OR listing_merchant_id <> NEW.merchant_user_id THEN
            RAISE EXCEPTION 'Listing % does not belong to merchant %', NEW.listing_id, NEW.merchant_user_id;
        END IF;
    END IF;

    IF NEW.order_id IS NOT NULL THEN
        SELECT user_id, COALESCE(merchant_user_id, restaurant_user_id)
          INTO order_buyer_id, order_merchant_id
          FROM orders
         WHERE order_id = NEW.order_id;

        IF order_buyer_id IS NULL OR order_buyer_id <> NEW.buyer_user_id THEN
            RAISE EXCEPTION 'Order % does not belong to buyer %', NEW.order_id, NEW.buyer_user_id;
        END IF;

        IF order_merchant_id IS NOT NULL AND order_merchant_id <> NEW.merchant_user_id THEN
            RAISE EXCEPTION 'Order % does not belong to merchant %', NEW.order_id, NEW.merchant_user_id;
        END IF;
    END IF;

    IF NEW.checkout_intent_id IS NOT NULL THEN
        SELECT buyer_user_id, merchant_user_id
          INTO intent_buyer_id, intent_merchant_id
          FROM checkout_payment_intents
         WHERE checkout_intent_id = NEW.checkout_intent_id;

        IF intent_buyer_id IS NULL OR intent_buyer_id <> NEW.buyer_user_id OR intent_merchant_id <> NEW.merchant_user_id THEN
            RAISE EXCEPTION 'Checkout intent % does not match buyer % and merchant %', NEW.checkout_intent_id, NEW.buyer_user_id, NEW.merchant_user_id;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION assert_shopping_cart_coherence()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    storefront_owner_id UUID;
    provider_owner_id UUID;
    order_user_id UUID;
    order_merchant_id UUID;
BEGIN
    IF NEW.storefront_id IS NOT NULL THEN
        SELECT merchant_user_id
          INTO storefront_owner_id
          FROM merchant_storefronts
         WHERE storefront_id = NEW.storefront_id;

        IF storefront_owner_id IS NULL OR storefront_owner_id <> NEW.merchant_user_id THEN
            RAISE EXCEPTION 'Cart storefront % does not belong to merchant %', NEW.storefront_id, NEW.merchant_user_id;
        END IF;
    END IF;

    IF NEW.checkout_provider_config_id IS NOT NULL THEN
        SELECT merchant_user_id
          INTO provider_owner_id
          FROM checkout_provider_configs
         WHERE checkout_provider_config_id = NEW.checkout_provider_config_id;

        IF provider_owner_id IS NULL OR provider_owner_id <> NEW.merchant_user_id THEN
            RAISE EXCEPTION 'Cart checkout provider % does not belong to merchant %', NEW.checkout_provider_config_id, NEW.merchant_user_id;
        END IF;
    END IF;

    IF NEW.converted_order_id IS NOT NULL THEN
        SELECT user_id, COALESCE(merchant_user_id, restaurant_user_id)
          INTO order_user_id, order_merchant_id
          FROM orders
         WHERE order_id = NEW.converted_order_id;

        IF order_user_id IS NULL OR order_user_id <> NEW.user_id THEN
            RAISE EXCEPTION 'Converted order % does not belong to cart user %', NEW.converted_order_id, NEW.user_id;
        END IF;

        IF order_merchant_id IS NOT NULL AND order_merchant_id <> NEW.merchant_user_id THEN
            RAISE EXCEPTION 'Converted order % does not belong to cart merchant %', NEW.converted_order_id, NEW.merchant_user_id;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION assert_shopping_cart_item_coherence()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    cart_user_id UUID;
    cart_merchant_id UUID;
    item_owner_id UUID;
    listing_merchant_id UUID;
    listing_item_id UUID;
    source_owner_id UUID;
    source_item_id UUID;
BEGIN
    SELECT user_id, merchant_user_id
      INTO cart_user_id, cart_merchant_id
      FROM shopping_carts
     WHERE cart_id = NEW.cart_id;

    IF cart_user_id IS NULL THEN
        RAISE EXCEPTION 'Cart % does not exist for cart item %', NEW.cart_id, NEW.cart_item_id;
    END IF;

    IF cart_user_id <> NEW.user_id OR cart_merchant_id <> NEW.merchant_user_id THEN
        RAISE EXCEPTION 'Cart item ownership differs from parent cart %', NEW.cart_id;
    END IF;

    SELECT merchant_user_id
      INTO item_owner_id
      FROM inventory_items
     WHERE item_id = NEW.item_id;

    IF item_owner_id IS NULL OR item_owner_id <> NEW.merchant_user_id THEN
        RAISE EXCEPTION 'Item % does not belong to merchant %', NEW.item_id, NEW.merchant_user_id;
    END IF;

    SELECT merchant_user_id, item_id
      INTO listing_merchant_id, listing_item_id
      FROM marketplace_listings
     WHERE listing_id = NEW.listing_id;

    IF listing_merchant_id IS NULL OR listing_merchant_id <> NEW.merchant_user_id OR listing_item_id <> NEW.item_id THEN
        RAISE EXCEPTION 'Listing % is not coherent with item % and merchant %', NEW.listing_id, NEW.item_id, NEW.merchant_user_id;
    END IF;

    IF NEW.product_source_id IS NOT NULL THEN
        SELECT owner_user_id, item_id
          INTO source_owner_id, source_item_id
          FROM dropshipping_product_sources
         WHERE product_source_id = NEW.product_source_id;

        IF source_owner_id IS NULL OR source_owner_id <> NEW.merchant_user_id OR source_item_id <> NEW.item_id THEN
            RAISE EXCEPTION 'Dropshipping source % is not coherent with item % and merchant %', NEW.product_source_id, NEW.item_id, NEW.merchant_user_id;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION refresh_shopping_cart_totals()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    target_cart_id UUID;
BEGIN
    target_cart_id := COALESCE(NEW.cart_id, OLD.cart_id);

    UPDATE shopping_carts
       SET line_count = COALESCE(agg.line_count, 0),
           total_quantity = COALESCE(agg.total_quantity, 0),
           subtotal_brl = COALESCE(agg.subtotal_brl, 0),
           discount_brl = COALESCE(agg.discount_brl, 0),
           total_estimate_brl = COALESCE(agg.subtotal_brl, 0) - COALESCE(agg.discount_brl, 0) + freight_estimate_brl,
           updated_at = NOW()
      FROM (
            SELECT
                cart_id,
                COUNT(*)::INTEGER AS line_count,
                COALESCE(SUM(quantity), 0) AS total_quantity,
                COALESCE(SUM(quantity * unit_price_brl), 0) AS subtotal_brl,
                COALESCE(SUM(quantity * unit_discount_brl), 0) AS discount_brl
            FROM shopping_cart_items
            WHERE cart_id = target_cart_id
            GROUP BY cart_id
      ) AS agg
     WHERE shopping_carts.cart_id = target_cart_id;

    UPDATE shopping_carts
       SET line_count = 0,
           total_quantity = 0,
           subtotal_brl = 0,
           discount_brl = 0,
           total_estimate_brl = freight_estimate_brl,
           updated_at = NOW()
     WHERE cart_id = target_cart_id
       AND NOT EXISTS (
            SELECT 1
              FROM shopping_cart_items
             WHERE cart_id = target_cart_id
       );

    RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION assert_user_favorite_target()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.target_type = 'ITEM' AND (NEW.item_id IS NULL OR NEW.listing_id IS NOT NULL OR NEW.storefront_id IS NOT NULL OR NEW.merchant_user_id IS NOT NULL) THEN
        RAISE EXCEPTION 'Favorite target ITEM requires only item_id';
    END IF;

    IF NEW.target_type = 'LISTING' AND (NEW.listing_id IS NULL OR NEW.item_id IS NOT NULL OR NEW.storefront_id IS NOT NULL OR NEW.merchant_user_id IS NOT NULL) THEN
        RAISE EXCEPTION 'Favorite target LISTING requires only listing_id';
    END IF;

    IF NEW.target_type = 'STOREFRONT' AND (NEW.storefront_id IS NULL OR NEW.item_id IS NOT NULL OR NEW.listing_id IS NOT NULL OR NEW.merchant_user_id IS NOT NULL) THEN
        RAISE EXCEPTION 'Favorite target STOREFRONT requires only storefront_id';
    END IF;

    IF NEW.target_type = 'MERCHANT' AND (NEW.merchant_user_id IS NULL OR NEW.item_id IS NOT NULL OR NEW.listing_id IS NOT NULL OR NEW.storefront_id IS NOT NULL) THEN
        RAISE EXCEPTION 'Favorite target MERCHANT requires only merchant_user_id';
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION assert_marketplace_review_coherence()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    item_owner_id UUID;
    listing_owner_id UUID;
    listing_item_id UUID;
    storefront_owner_id UUID;
    order_buyer_id UUID;
    order_merchant_id UUID;
BEGIN
    SELECT merchant_user_id
      INTO item_owner_id
      FROM inventory_items
     WHERE item_id = NEW.item_id;

    IF item_owner_id IS NULL OR item_owner_id <> NEW.merchant_user_id THEN
        RAISE EXCEPTION 'Review item % does not belong to merchant %', NEW.item_id, NEW.merchant_user_id;
    END IF;

    IF NEW.listing_id IS NOT NULL THEN
        SELECT merchant_user_id, item_id
          INTO listing_owner_id, listing_item_id
          FROM marketplace_listings
         WHERE listing_id = NEW.listing_id;

        IF listing_owner_id IS NULL OR listing_owner_id <> NEW.merchant_user_id OR listing_item_id <> NEW.item_id THEN
            RAISE EXCEPTION 'Review listing % is not coherent with item % and merchant %', NEW.listing_id, NEW.item_id, NEW.merchant_user_id;
        END IF;
    END IF;

    IF NEW.storefront_id IS NOT NULL THEN
        SELECT merchant_user_id
          INTO storefront_owner_id
          FROM merchant_storefronts
         WHERE storefront_id = NEW.storefront_id;

        IF storefront_owner_id IS NULL OR storefront_owner_id <> NEW.merchant_user_id THEN
            RAISE EXCEPTION 'Review storefront % does not belong to merchant %', NEW.storefront_id, NEW.merchant_user_id;
        END IF;
    END IF;

    IF NEW.order_id IS NOT NULL THEN
        SELECT user_id, COALESCE(merchant_user_id, restaurant_user_id)
          INTO order_buyer_id, order_merchant_id
          FROM orders
         WHERE order_id = NEW.order_id;

        IF order_buyer_id IS NULL OR order_buyer_id <> NEW.review_author_user_id THEN
            RAISE EXCEPTION 'Review order % does not belong to author %', NEW.order_id, NEW.review_author_user_id;
        END IF;

        IF order_merchant_id IS NOT NULL AND order_merchant_id <> NEW.merchant_user_id THEN
            RAISE EXCEPTION 'Review order % does not belong to merchant %', NEW.order_id, NEW.merchant_user_id;
        END IF;

        NEW.verified_purchase := TRUE;
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION refresh_merchant_review_metrics()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    target_merchant_id UUID;
BEGIN
    target_merchant_id := COALESCE(NEW.merchant_user_id, OLD.merchant_user_id);

    UPDATE merchant_profiles
       SET average_rating = COALESCE(stats.average_rating, 0),
           review_count = COALESCE(stats.review_count, 0),
           updated_at = NOW()
      FROM (
            SELECT
                merchant_user_id,
                ROUND(AVG(rating)::NUMERIC, 2) AS average_rating,
                COUNT(*)::INTEGER AS review_count
            FROM marketplace_item_reviews
            WHERE merchant_user_id = target_merchant_id
              AND review_status = 'PUBLISHED'
            GROUP BY merchant_user_id
      ) AS stats
     WHERE merchant_profiles.merchant_user_id = target_merchant_id;

    UPDATE merchant_profiles
       SET average_rating = 0,
           review_count = 0,
           updated_at = NOW()
     WHERE merchant_user_id = target_merchant_id
       AND NOT EXISTS (
            SELECT 1
              FROM marketplace_item_reviews
             WHERE merchant_user_id = target_merchant_id
               AND review_status = 'PUBLISHED'
       );

    RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION assert_support_ticket_coherence()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    storefront_owner_id UUID;
    order_user_id UUID;
    order_merchant_id UUID;
    transaction_user_id UUID;
    intent_buyer_id UUID;
    intent_merchant_id UUID;
BEGIN
    IF NEW.storefront_id IS NOT NULL THEN
        SELECT merchant_user_id
          INTO storefront_owner_id
          FROM merchant_storefronts
         WHERE storefront_id = NEW.storefront_id;

        IF storefront_owner_id IS NULL OR (NEW.merchant_user_id IS NOT NULL AND storefront_owner_id <> NEW.merchant_user_id) THEN
            RAISE EXCEPTION 'Support storefront % is not coherent with merchant %', NEW.storefront_id, NEW.merchant_user_id;
        END IF;
    END IF;

    IF NEW.order_id IS NOT NULL THEN
        SELECT user_id, COALESCE(merchant_user_id, restaurant_user_id)
          INTO order_user_id, order_merchant_id
          FROM orders
         WHERE order_id = NEW.order_id;

        IF order_user_id IS NULL OR order_user_id <> NEW.requester_user_id THEN
            RAISE EXCEPTION 'Support order % does not belong to requester %', NEW.order_id, NEW.requester_user_id;
        END IF;

        IF NEW.merchant_user_id IS NOT NULL AND order_merchant_id IS NOT NULL AND order_merchant_id <> NEW.merchant_user_id THEN
            RAISE EXCEPTION 'Support order % does not belong to merchant %', NEW.order_id, NEW.merchant_user_id;
        END IF;
    END IF;

    IF NEW.transaction_id IS NOT NULL THEN
        SELECT user_id
          INTO transaction_user_id
          FROM transactions
         WHERE transaction_id = NEW.transaction_id;

        IF transaction_user_id IS NULL OR transaction_user_id <> NEW.requester_user_id THEN
            RAISE EXCEPTION 'Support transaction % does not belong to requester %', NEW.transaction_id, NEW.requester_user_id;
        END IF;
    END IF;

    IF NEW.checkout_intent_id IS NOT NULL THEN
        SELECT buyer_user_id, merchant_user_id
          INTO intent_buyer_id, intent_merchant_id
          FROM checkout_payment_intents
         WHERE checkout_intent_id = NEW.checkout_intent_id;

        IF intent_buyer_id IS NULL OR intent_buyer_id <> NEW.requester_user_id THEN
            RAISE EXCEPTION 'Support checkout intent % does not belong to requester %', NEW.checkout_intent_id, NEW.requester_user_id;
        END IF;

        IF NEW.merchant_user_id IS NOT NULL AND intent_merchant_id <> NEW.merchant_user_id THEN
            RAISE EXCEPTION 'Support checkout intent % does not belong to merchant %', NEW.checkout_intent_id, NEW.merchant_user_id;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION assert_support_ticket_message_coherence()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    ticket_requester_id UUID;
    ticket_merchant_id UUID;
BEGIN
    SELECT requester_user_id, merchant_user_id
      INTO ticket_requester_id, ticket_merchant_id
      FROM support_tickets
     WHERE support_ticket_id = NEW.support_ticket_id;

    IF ticket_requester_id IS NULL THEN
        RAISE EXCEPTION 'Support ticket % does not exist for message %', NEW.support_ticket_id, NEW.support_ticket_message_id;
    END IF;

    IF NEW.sender_type = 'USER' AND (NEW.sender_user_id IS NULL OR NEW.sender_user_id <> ticket_requester_id OR NEW.sender_admin_id IS NOT NULL) THEN
        RAISE EXCEPTION 'Support message type USER must use requester sender_user_id only';
    END IF;

    IF NEW.sender_type = 'MERCHANT' AND (NEW.sender_user_id IS NULL OR ticket_merchant_id IS NULL OR NEW.sender_user_id <> ticket_merchant_id OR NEW.sender_admin_id IS NOT NULL) THEN
        RAISE EXCEPTION 'Support message type MERCHANT must use merchant sender_user_id only';
    END IF;

    IF NEW.sender_type = 'AGENT' AND (NEW.sender_admin_id IS NULL OR NEW.sender_user_id IS NOT NULL) THEN
        RAISE EXCEPTION 'Support message type AGENT must use sender_admin_id only';
    END IF;

    IF NEW.sender_type IN ('BOT', 'SYSTEM') AND NEW.sender_admin_id IS NULL AND NEW.sender_user_id IS NULL THEN
        RETURN NEW;
    END IF;

    IF NEW.sender_type IN ('BOT', 'SYSTEM') AND (NEW.sender_admin_id IS NOT NULL OR NEW.sender_user_id IS NOT NULL) THEN
        RAISE EXCEPTION 'Support message type % must not bind user/admin sender', NEW.sender_type;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_auth_identities_set_updated_at
BEFORE UPDATE ON auth_identities
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_auth_identities_normalize
BEFORE INSERT OR UPDATE ON auth_identities
FOR EACH ROW
EXECUTE FUNCTION normalize_auth_identity();

CREATE TRIGGER trg_auth_sessions_set_updated_at
BEFORE UPDATE ON auth_sessions
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_user_profiles_set_updated_at
BEFORE UPDATE ON user_profiles
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_merchant_profiles_set_updated_at
BEFORE UPDATE ON merchant_profiles
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_merchant_profiles_assert_coherence
BEFORE INSERT OR UPDATE ON merchant_profiles
FOR EACH ROW
EXECUTE FUNCTION assert_merchant_profile_coherence();

CREATE TRIGGER trg_home_surface_preferences_set_updated_at
BEFORE UPDATE ON home_surface_preferences
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_home_surface_preferences_assert_coherence
BEFORE INSERT OR UPDATE ON home_surface_preferences
FOR EACH ROW
EXECUTE FUNCTION assert_home_surface_coherence();

CREATE TRIGGER trg_checkout_provider_configs_set_updated_at
BEFORE UPDATE ON checkout_provider_configs
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_checkout_provider_configs_assert_coherence
BEFORE INSERT OR UPDATE ON checkout_provider_configs
FOR EACH ROW
EXECUTE FUNCTION assert_checkout_provider_coherence();

CREATE TRIGGER trg_checkout_payment_intents_set_updated_at
BEFORE UPDATE ON checkout_payment_intents
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_checkout_payment_intents_assert_coherence
BEFORE INSERT OR UPDATE ON checkout_payment_intents
FOR EACH ROW
EXECUTE FUNCTION assert_checkout_intent_coherence();

CREATE TRIGGER trg_checkout_webhook_events_prevent_update
BEFORE UPDATE ON checkout_webhook_events
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

CREATE TRIGGER trg_checkout_webhook_events_prevent_delete
BEFORE DELETE ON checkout_webhook_events
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

CREATE TRIGGER trg_commerce_chat_threads_set_updated_at
BEFORE UPDATE ON commerce_chat_threads
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_commerce_chat_threads_assert_coherence
BEFORE INSERT OR UPDATE ON commerce_chat_threads
FOR EACH ROW
EXECUTE FUNCTION assert_commerce_chat_thread_coherence();

CREATE TRIGGER trg_shopping_carts_set_updated_at
BEFORE UPDATE ON shopping_carts
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_shopping_carts_assert_coherence
BEFORE INSERT OR UPDATE ON shopping_carts
FOR EACH ROW
EXECUTE FUNCTION assert_shopping_cart_coherence();

CREATE TRIGGER trg_shopping_cart_items_set_updated_at
BEFORE UPDATE ON shopping_cart_items
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_shopping_cart_items_assert_coherence
BEFORE INSERT OR UPDATE ON shopping_cart_items
FOR EACH ROW
EXECUTE FUNCTION assert_shopping_cart_item_coherence();

CREATE TRIGGER trg_shopping_cart_items_refresh_after_insert
AFTER INSERT ON shopping_cart_items
FOR EACH ROW
EXECUTE FUNCTION refresh_shopping_cart_totals();

CREATE TRIGGER trg_shopping_cart_items_refresh_after_update
AFTER UPDATE ON shopping_cart_items
FOR EACH ROW
EXECUTE FUNCTION refresh_shopping_cart_totals();

CREATE TRIGGER trg_shopping_cart_items_refresh_after_delete
AFTER DELETE ON shopping_cart_items
FOR EACH ROW
EXECUTE FUNCTION refresh_shopping_cart_totals();

CREATE TRIGGER trg_user_favorites_assert_target
BEFORE INSERT OR UPDATE ON user_favorites
FOR EACH ROW
EXECUTE FUNCTION assert_user_favorite_target();

CREATE TRIGGER trg_marketplace_item_reviews_set_updated_at
BEFORE UPDATE ON marketplace_item_reviews
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_marketplace_item_reviews_assert_coherence
BEFORE INSERT OR UPDATE ON marketplace_item_reviews
FOR EACH ROW
EXECUTE FUNCTION assert_marketplace_review_coherence();

CREATE TRIGGER trg_marketplace_item_reviews_refresh_metrics_after_insert
AFTER INSERT ON marketplace_item_reviews
FOR EACH ROW
EXECUTE FUNCTION refresh_merchant_review_metrics();

CREATE TRIGGER trg_marketplace_item_reviews_refresh_metrics_after_update
AFTER UPDATE ON marketplace_item_reviews
FOR EACH ROW
EXECUTE FUNCTION refresh_merchant_review_metrics();

CREATE TRIGGER trg_marketplace_item_reviews_refresh_metrics_after_delete
AFTER DELETE ON marketplace_item_reviews
FOR EACH ROW
EXECUTE FUNCTION refresh_merchant_review_metrics();

CREATE TRIGGER trg_support_tickets_set_updated_at
BEFORE UPDATE ON support_tickets
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_support_tickets_assert_coherence
BEFORE INSERT OR UPDATE ON support_tickets
FOR EACH ROW
EXECUTE FUNCTION assert_support_ticket_coherence();

CREATE TRIGGER trg_support_ticket_messages_assert_coherence
BEFORE INSERT OR UPDATE ON support_ticket_messages
FOR EACH ROW
EXECUTE FUNCTION assert_support_ticket_message_coherence();

CREATE TRIGGER trg_support_ticket_messages_prevent_update
BEFORE UPDATE ON support_ticket_messages
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

CREATE TRIGGER trg_support_ticket_messages_prevent_delete
BEFORE DELETE ON support_ticket_messages
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

CREATE TRIGGER trg_auth_login_events_prevent_update
BEFORE UPDATE ON auth_login_events
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

CREATE TRIGGER trg_auth_login_events_prevent_delete
BEFORE DELETE ON auth_login_events
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

COMMENT ON TABLE auth_identities IS
    'Identidades de login do usuario para email, telefone, OAuth e magic link.';
COMMENT ON TABLE auth_sessions IS
    'Sessoes ativas e revogadas do usuario para signin/login seguro.';
COMMENT ON TABLE user_profiles IS
    'Perfil operacional do usuario final com preferencias, shipping e visibilidade.';
COMMENT ON TABLE merchant_profiles IS
    'Perfil operacional do lojista com wallet, storefront, politicas e nota agregada.';
COMMENT ON TABLE home_surface_preferences IS
    'Configuracao da home do usuario ou lojista para modulos, dock e contexto rapido.';
COMMENT ON TABLE checkout_provider_configs IS
    'Configuracoes seguras das integracoes de checkout por lojista sem segredo bruto.';
COMMENT ON TABLE checkout_payment_intents IS
    'Intencoes de pagamento por pedido/carrinho antes da liquidacao no ledger financeiro.';
COMMENT ON TABLE checkout_webhook_events IS
    'Trilha append-only dos webhooks de checkout recebidos da PSP.';
COMMENT ON TABLE commerce_chat_threads IS
    'Amarra conversa buyer-merchant a listing, order, checkout ou suporte.';
COMMENT ON TABLE shopping_carts IS
    'Carrinho persistido por usuario e lojista com totais recalculados por trigger.';
COMMENT ON TABLE shopping_cart_items IS
    'Itens do carrinho com listing, produto e opcionalmente source de dropshipping.';
COMMENT ON TABLE user_favorites IS
    'Favoritos do usuario para item, listing, storefront ou merchant.';
COMMENT ON TABLE marketplace_item_reviews IS
    'Avaliacoes de itens do marketplace com reply do lojista e purchase verification.';
COMMENT ON TABLE support_tickets IS
    'SAC Valley com vinculo a pedido, transacao, checkout e conversa.';
COMMENT ON TABLE support_ticket_messages IS
    'Mensagens append-only do SAC entre usuario, lojista e agente.';

COMMIT;
