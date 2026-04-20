-- Valley Hybrid DB Bootstrap - TECH e LEGAL foundation v47.
-- Este arquivo implanta contratos operacionais de API, integracoes, webhooks, contratos legais, assinaturas e disputas.
-- Seguranca mandataria: nenhum segredo bruto e armazenado; chaves, webhook secrets e fallback PIN ficam apenas como hash/prefixo.
-- Execute depois de 001, 002, 004, 005, 007 e 008, porque integra users, module_delivery_registry, document_records, orders e transactions.

BEGIN;

SET search_path = public;

-- tech_api_client_status_enum controla o lifecycle do client de API.
CREATE TYPE tech_api_client_status_enum AS ENUM ('DRAFT', 'ACTIVE', 'SUSPENDED', 'REVOKED', 'ARCHIVED');

-- tech_credential_status_enum controla credenciais tecnicas sem guardar segredo bruto.
CREATE TYPE tech_credential_status_enum AS ENUM ('ACTIVE', 'ROTATED', 'REVOKED', 'EXPIRED');

-- tech_connector_status_enum controla conectores externos ou internos.
CREATE TYPE tech_connector_status_enum AS ENUM ('DRAFT', 'ACTIVE', 'DEGRADED', 'SUSPENDED', 'ARCHIVED');

-- tech_auth_strategy_enum descreve tipo de autenticacao sem expor credenciais.
CREATE TYPE tech_auth_strategy_enum AS ENUM ('NONE', 'API_KEY_HASHED', 'OAUTH2', 'JWT', 'MTLS', 'WEBHOOK_SIGNATURE');

-- webhook_subscription_status_enum controla assinatura de webhook.
CREATE TYPE webhook_subscription_status_enum AS ENUM ('DRAFT', 'ACTIVE', 'PAUSED', 'FAILED', 'REVOKED');

-- webhook_delivery_status_enum controla resultado append-only de cada tentativa.
CREATE TYPE webhook_delivery_status_enum AS ENUM ('PENDING', 'SUCCESS', 'FAILED', 'RETRYING', 'DISCARDED');

-- legal_contract_status_enum controla lifecycle juridico do contrato.
CREATE TYPE legal_contract_status_enum AS ENUM ('DRAFT', 'PENDING_SIGNATURE', 'ACTIVE', 'EXPIRED', 'TERMINATED', 'DISPUTED', 'ARCHIVED');

-- legal_party_role_enum descreve papel da parte no contrato.
CREATE TYPE legal_party_role_enum AS ENUM ('OWNER', 'COUNTERPARTY', 'SIGNER', 'WITNESS', 'APPROVER', 'MEDIATOR');

-- legal_signature_status_enum controla status de assinatura.
CREATE TYPE legal_signature_status_enum AS ENUM ('PENDING', 'SIGNED', 'REJECTED', 'EXPIRED', 'REVOKED');

-- legal_signature_method_enum descreve metodo sem expor segredo bruto.
CREATE TYPE legal_signature_method_enum AS ENUM ('CLICKWRAP', 'OTP', 'BIOMETRIC', 'CERTIFICATE', 'FALLBACK_PIN_HASHED');

-- legal_dispute_status_enum controla lifecycle de disputa e mediacao.
CREATE TYPE legal_dispute_status_enum AS ENUM ('OPEN', 'UNDER_REVIEW', 'MEDIATION', 'RESOLVED', 'REJECTED', 'CANCELLED');

-- legal_audit_event_type_enum classifica trilha juridica append-only.
CREATE TYPE legal_audit_event_type_enum AS ENUM ('CONTRACT_CREATED', 'PARTY_ADDED', 'SIGNATURE_REQUESTED', 'SIGNED', 'REJECTED', 'DISPUTE_OPENED', 'DISPUTE_UPDATED', 'RESOLUTION_RECORDED', 'PIN_VALIDATED', 'PIN_LOCKED');

-- fallback_pin_status_enum controla estado de fallback PIN sem armazenar PIN bruto.
CREATE TYPE fallback_pin_status_enum AS ENUM ('PENDING', 'ACTIVE', 'LOCKED', 'REVOKED');

-- tech_api_clients registra apps e clients da plataforma developer.
CREATE TABLE tech_api_clients (
    api_client_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_user_id UUID NOT NULL,
    module_code TEXT NOT NULL DEFAULT 'TECH',
    client_name TEXT NOT NULL,
    client_status tech_api_client_status_enum NOT NULL DEFAULT 'DRAFT',
    allowed_modules TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
    redirect_uris TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
    rate_limit_per_minute INTEGER NOT NULL DEFAULT 60,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_tech_api_clients_owner
        FOREIGN KEY (owner_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_tech_api_clients_module
        FOREIGN KEY (module_code) REFERENCES module_delivery_registry (module_code)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT chk_tech_api_clients_name CHECK (btrim(client_name) <> ''),
    CONSTRAINT chk_tech_api_clients_rate_limit CHECK (rate_limit_per_minute > 0 AND rate_limit_per_minute <= 60000),
    CONSTRAINT chk_tech_api_clients_module_code CHECK (module_code = 'TECH')
);

-- tech_api_credentials registra credenciais por hash; nunca guarde API key bruta.
CREATE TABLE tech_api_credentials (
    api_credential_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    api_client_id UUID NOT NULL,
    owner_user_id UUID NOT NULL,
    credential_status tech_credential_status_enum NOT NULL DEFAULT 'ACTIVE',
    key_prefix TEXT NOT NULL UNIQUE,
    key_hash_sha256 TEXT NOT NULL UNIQUE,
    scopes TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
    expires_at TIMESTAMPTZ,
    last_used_at TIMESTAMPTZ,
    rotated_from_credential_id UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_tech_api_credentials_client
        FOREIGN KEY (api_client_id) REFERENCES tech_api_clients (api_client_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT fk_tech_api_credentials_owner
        FOREIGN KEY (owner_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_tech_api_credentials_rotated_from
        FOREIGN KEY (rotated_from_credential_id) REFERENCES tech_api_credentials (api_credential_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT chk_tech_api_credentials_prefix CHECK (key_prefix ~ '^[A-Za-z0-9_-]{4,32}$'),
    CONSTRAINT chk_tech_api_credentials_hash CHECK (key_hash_sha256 ~ '^[a-fA-F0-9]{64}$'),
    CONSTRAINT chk_tech_api_credentials_expiration CHECK (expires_at IS NULL OR expires_at > created_at)
);

-- tech_integration_connectors registra conectores com configuracao segura em JSONB.
CREATE TABLE tech_integration_connectors (
    connector_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_user_id UUID NOT NULL,
    module_code TEXT NOT NULL DEFAULT 'TECH',
    connector_name TEXT NOT NULL,
    connector_type TEXT NOT NULL,
    connector_status tech_connector_status_enum NOT NULL DEFAULT 'DRAFT',
    auth_strategy tech_auth_strategy_enum NOT NULL DEFAULT 'NONE',
    endpoint_url TEXT,
    config_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    health_status_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    last_healthcheck_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_tech_integration_connectors_owner
        FOREIGN KEY (owner_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_tech_integration_connectors_module
        FOREIGN KEY (module_code) REFERENCES module_delivery_registry (module_code)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT chk_tech_integration_connectors_name CHECK (btrim(connector_name) <> ''),
    CONSTRAINT chk_tech_integration_connectors_type CHECK (connector_type ~ '^[A-Z0-9_]{2,80}$'),
    CONSTRAINT chk_tech_integration_connectors_endpoint CHECK (endpoint_url IS NULL OR endpoint_url ~ '^https?://'),
    CONSTRAINT chk_tech_integration_connectors_module_code CHECK (module_code = 'TECH')
);

-- tech_webhook_subscriptions registra destinos de webhook com secret apenas como hash.
CREATE TABLE tech_webhook_subscriptions (
    webhook_subscription_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_user_id UUID NOT NULL,
    api_client_id UUID,
    connector_id UUID,
    module_code TEXT NOT NULL DEFAULT 'TECH',
    subscription_status webhook_subscription_status_enum NOT NULL DEFAULT 'DRAFT',
    target_url TEXT NOT NULL,
    event_types TEXT[] NOT NULL,
    signing_secret_hash_sha256 TEXT NOT NULL,
    retry_policy_json JSONB NOT NULL DEFAULT '{"max_attempts":5,"backoff":"exponential"}'::JSONB,
    last_delivery_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_tech_webhook_subscriptions_owner
        FOREIGN KEY (owner_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_tech_webhook_subscriptions_client
        FOREIGN KEY (api_client_id) REFERENCES tech_api_clients (api_client_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_tech_webhook_subscriptions_connector
        FOREIGN KEY (connector_id) REFERENCES tech_integration_connectors (connector_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_tech_webhook_subscriptions_module
        FOREIGN KEY (module_code) REFERENCES module_delivery_registry (module_code)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT chk_tech_webhook_subscriptions_target CHECK (target_url ~ '^https://'),
    CONSTRAINT chk_tech_webhook_subscriptions_events CHECK (cardinality(event_types) > 0),
    CONSTRAINT chk_tech_webhook_subscriptions_secret CHECK (signing_secret_hash_sha256 ~ '^[a-fA-F0-9]{64}$'),
    CONSTRAINT chk_tech_webhook_subscriptions_module_code CHECK (module_code = 'TECH')
);

-- tech_webhook_delivery_attempts e append-only para auditoria de entrega de webhook.
CREATE TABLE tech_webhook_delivery_attempts (
    webhook_delivery_attempt_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    webhook_subscription_id UUID NOT NULL,
    owner_user_id UUID NOT NULL,
    event_type TEXT NOT NULL,
    payload_hash_sha256 TEXT NOT NULL,
    delivery_status webhook_delivery_status_enum NOT NULL DEFAULT 'PENDING',
    response_status_code INTEGER,
    duration_ms INTEGER,
    error_message TEXT,
    attempted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_tech_webhook_delivery_attempts_subscription
        FOREIGN KEY (webhook_subscription_id) REFERENCES tech_webhook_subscriptions (webhook_subscription_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_tech_webhook_delivery_attempts_owner
        FOREIGN KEY (owner_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT chk_tech_webhook_delivery_attempts_event CHECK (btrim(event_type) <> ''),
    CONSTRAINT chk_tech_webhook_delivery_attempts_payload_hash CHECK (payload_hash_sha256 ~ '^[a-fA-F0-9]{64}$'),
    CONSTRAINT chk_tech_webhook_delivery_attempts_status_code CHECK (response_status_code IS NULL OR response_status_code BETWEEN 100 AND 599),
    CONSTRAINT chk_tech_webhook_delivery_attempts_duration CHECK (duration_ms IS NULL OR duration_ms >= 0)
);

-- tech_api_usage_daily guarda agregados mutaveis de uso diario por client.
CREATE TABLE tech_api_usage_daily (
    api_usage_daily_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    api_client_id UUID NOT NULL,
    owner_user_id UUID NOT NULL,
    usage_date DATE NOT NULL,
    request_count BIGINT NOT NULL DEFAULT 0,
    error_count BIGINT NOT NULL DEFAULT 0,
    bytes_in BIGINT NOT NULL DEFAULT 0,
    bytes_out BIGINT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_tech_api_usage_daily_client
        FOREIGN KEY (api_client_id) REFERENCES tech_api_clients (api_client_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT fk_tech_api_usage_daily_owner
        FOREIGN KEY (owner_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT ux_tech_api_usage_daily_client_date UNIQUE (api_client_id, usage_date),
    CONSTRAINT chk_tech_api_usage_daily_counts CHECK (
        request_count >= 0
        AND error_count >= 0
        AND error_count <= request_count
        AND bytes_in >= 0
        AND bytes_out >= 0
    )
);

-- legal_contracts registra contratos juridicos ligados a usuarios e documentos.
CREATE TABLE legal_contracts (
    legal_contract_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_user_id UUID NOT NULL,
    counterparty_user_id UUID,
    module_code TEXT NOT NULL DEFAULT 'LEGAL',
    document_id UUID,
    contract_status legal_contract_status_enum NOT NULL DEFAULT 'DRAFT',
    contract_type TEXT NOT NULL,
    title TEXT NOT NULL,
    jurisdiction_country CHAR(2) NOT NULL DEFAULT 'BR',
    terms_hash_sha256 TEXT NOT NULL,
    contract_uri TEXT,
    effective_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_legal_contracts_owner
        FOREIGN KEY (owner_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_legal_contracts_counterparty
        FOREIGN KEY (counterparty_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_legal_contracts_module
        FOREIGN KEY (module_code) REFERENCES module_delivery_registry (module_code)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_legal_contracts_document
        FOREIGN KEY (document_id) REFERENCES document_records (document_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT chk_legal_contracts_module_code CHECK (module_code = 'LEGAL'),
    CONSTRAINT chk_legal_contracts_type CHECK (contract_type ~ '^[A-Z0-9_]{2,80}$'),
    CONSTRAINT chk_legal_contracts_title CHECK (btrim(title) <> ''),
    CONSTRAINT chk_legal_contracts_country CHECK (jurisdiction_country ~ '^[A-Z]{2}$'),
    CONSTRAINT chk_legal_contracts_terms_hash CHECK (terms_hash_sha256 ~ '^[a-fA-F0-9]{64}$'),
    CONSTRAINT chk_legal_contracts_uri CHECK (contract_uri IS NULL OR btrim(contract_uri) <> ''),
    CONSTRAINT chk_legal_contracts_timeline CHECK (expires_at IS NULL OR effective_at IS NULL OR expires_at > effective_at)
);

-- legal_contract_parties registra partes e papeis do contrato.
CREATE TABLE legal_contract_parties (
    legal_contract_party_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    legal_contract_id UUID NOT NULL,
    user_id UUID NOT NULL,
    party_role legal_party_role_enum NOT NULL,
    signing_order INTEGER NOT NULL DEFAULT 1,
    accepted_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_legal_contract_parties_contract
        FOREIGN KEY (legal_contract_id) REFERENCES legal_contracts (legal_contract_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT fk_legal_contract_parties_user
        FOREIGN KEY (user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT ux_legal_contract_parties_contract_user_role UNIQUE (legal_contract_id, user_id, party_role),
    CONSTRAINT chk_legal_contract_parties_order CHECK (signing_order > 0)
);

-- legal_signatures e append-only para preservar prova de assinatura.
CREATE TABLE legal_signatures (
    legal_signature_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    legal_contract_id UUID NOT NULL,
    signer_user_id UUID NOT NULL,
    document_id UUID,
    signature_status legal_signature_status_enum NOT NULL DEFAULT 'PENDING',
    signature_method legal_signature_method_enum NOT NULL,
    signature_hash_sha256 TEXT,
    ip_hash_sha256 TEXT,
    device_fingerprint_hash_sha256 TEXT,
    signed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_legal_signatures_contract
        FOREIGN KEY (legal_contract_id) REFERENCES legal_contracts (legal_contract_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_legal_signatures_signer
        FOREIGN KEY (signer_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_legal_signatures_document
        FOREIGN KEY (document_id) REFERENCES document_records (document_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT chk_legal_signatures_hash CHECK (signature_hash_sha256 IS NULL OR signature_hash_sha256 ~ '^[a-fA-F0-9]{64}$'),
    CONSTRAINT chk_legal_signatures_ip_hash CHECK (ip_hash_sha256 IS NULL OR ip_hash_sha256 ~ '^[a-fA-F0-9]{64}$'),
    CONSTRAINT chk_legal_signatures_device_hash CHECK (device_fingerprint_hash_sha256 IS NULL OR device_fingerprint_hash_sha256 ~ '^[a-fA-F0-9]{64}$'),
    CONSTRAINT chk_legal_signatures_signed_state CHECK (
        signature_status <> 'SIGNED'
        OR (signature_hash_sha256 IS NOT NULL AND signed_at IS NOT NULL)
    )
);

-- legal_disputes registra disputas, mediacao e resolucao.
CREATE TABLE legal_disputes (
    legal_dispute_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_user_id UUID NOT NULL,
    opened_by_user_id UUID NOT NULL,
    assigned_admin_id UUID,
    module_code TEXT NOT NULL DEFAULT 'LEGAL',
    legal_contract_id UUID,
    order_id UUID,
    transaction_id UUID,
    dispute_status legal_dispute_status_enum NOT NULL DEFAULT 'OPEN',
    dispute_reason TEXT NOT NULL,
    resolution_summary TEXT,
    opened_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    resolved_at TIMESTAMPTZ,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_legal_disputes_owner
        FOREIGN KEY (owner_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_legal_disputes_opened_by
        FOREIGN KEY (opened_by_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_legal_disputes_admin
        FOREIGN KEY (assigned_admin_id) REFERENCES admin_users (admin_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_legal_disputes_module
        FOREIGN KEY (module_code) REFERENCES module_delivery_registry (module_code)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_legal_disputes_contract
        FOREIGN KEY (legal_contract_id) REFERENCES legal_contracts (legal_contract_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_legal_disputes_order
        FOREIGN KEY (order_id) REFERENCES orders (order_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_legal_disputes_transaction
        FOREIGN KEY (transaction_id) REFERENCES transactions (transaction_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT chk_legal_disputes_module_code CHECK (module_code = 'LEGAL'),
    CONSTRAINT chk_legal_disputes_reason CHECK (btrim(dispute_reason) <> ''),
    CONSTRAINT chk_legal_disputes_reference CHECK (
        legal_contract_id IS NOT NULL OR order_id IS NOT NULL OR transaction_id IS NOT NULL
    ),
    CONSTRAINT chk_legal_disputes_resolution CHECK (resolved_at IS NULL OR resolved_at >= opened_at)
);

-- legal_audit_events e append-only para trilha juridica de contratos e disputas.
CREATE TABLE legal_audit_events (
    legal_audit_event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    legal_contract_id UUID,
    legal_dispute_id UUID,
    user_id UUID,
    admin_id UUID,
    event_type legal_audit_event_type_enum NOT NULL,
    event_name TEXT NOT NULL,
    event_payload_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    event_hash_sha256 TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_legal_audit_events_contract
        FOREIGN KEY (legal_contract_id) REFERENCES legal_contracts (legal_contract_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_legal_audit_events_dispute
        FOREIGN KEY (legal_dispute_id) REFERENCES legal_disputes (legal_dispute_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_legal_audit_events_user
        FOREIGN KEY (user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_legal_audit_events_admin
        FOREIGN KEY (admin_id) REFERENCES admin_users (admin_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT chk_legal_audit_events_name CHECK (btrim(event_name) <> ''),
    CONSTRAINT chk_legal_audit_events_hash CHECK (event_hash_sha256 IS NULL OR event_hash_sha256 ~ '^[a-fA-F0-9]{64}$'),
    CONSTRAINT chk_legal_audit_events_reference CHECK (
        legal_contract_id IS NOT NULL OR legal_dispute_id IS NOT NULL OR user_id IS NOT NULL OR admin_id IS NOT NULL
    )
);

-- legal_fallback_pin_credentials guarda somente hash do PIN de fallback.
CREATE TABLE legal_fallback_pin_credentials (
    fallback_pin_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL UNIQUE,
    pin_status fallback_pin_status_enum NOT NULL DEFAULT 'PENDING',
    pin_hash_sha256 TEXT NOT NULL,
    failed_attempts INTEGER NOT NULL DEFAULT 0,
    locked_until TIMESTAMPTZ,
    last_verified_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_legal_fallback_pin_credentials_user
        FOREIGN KEY (user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT chk_legal_fallback_pin_credentials_hash CHECK (pin_hash_sha256 ~ '^[a-fA-F0-9]{64}$'),
    CONSTRAINT chk_legal_fallback_pin_credentials_attempts CHECK (failed_attempts >= 0),
    CONSTRAINT chk_legal_fallback_pin_credentials_lock CHECK (
        (pin_status = 'LOCKED' AND locked_until IS NOT NULL)
        OR (pin_status <> 'LOCKED' AND locked_until IS NULL)
    )
);

-- assert_tech_owner_coherence valida se client, connector e agregado pertencem ao mesmo owner_user_id.
CREATE OR REPLACE FUNCTION assert_tech_owner_coherence()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_TABLE_NAME IN ('tech_api_credentials', 'tech_api_usage_daily')
        AND NOT EXISTS (
            SELECT 1
            FROM tech_api_clients
            WHERE tech_api_clients.api_client_id = NEW.api_client_id
              AND tech_api_clients.owner_user_id = NEW.owner_user_id
        ) THEN
        RAISE EXCEPTION 'api_client_id % nao pertence ao owner_user_id % em %', NEW.api_client_id, NEW.owner_user_id, TG_TABLE_NAME;
    END IF;

    IF TG_TABLE_NAME = 'tech_webhook_subscriptions'
        AND NEW.api_client_id IS NOT NULL
        AND NOT EXISTS (
            SELECT 1
            FROM tech_api_clients
            WHERE tech_api_clients.api_client_id = NEW.api_client_id
              AND tech_api_clients.owner_user_id = NEW.owner_user_id
        ) THEN
        RAISE EXCEPTION 'api_client_id % nao pertence ao owner_user_id % em tech_webhook_subscriptions', NEW.api_client_id, NEW.owner_user_id;
    END IF;

    IF TG_TABLE_NAME = 'tech_webhook_subscriptions'
        AND NEW.connector_id IS NOT NULL
        AND NOT EXISTS (
            SELECT 1
            FROM tech_integration_connectors
            WHERE tech_integration_connectors.connector_id = NEW.connector_id
              AND tech_integration_connectors.owner_user_id = NEW.owner_user_id
        ) THEN
        RAISE EXCEPTION 'connector_id % nao pertence ao owner_user_id % em tech_webhook_subscriptions', NEW.connector_id, NEW.owner_user_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- assert_legal_signature_party valida se o assinante faz parte do contrato.
CREATE OR REPLACE FUNCTION assert_legal_signature_party()
RETURNS TRIGGER AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM legal_contract_parties
        WHERE legal_contract_parties.legal_contract_id = NEW.legal_contract_id
          AND legal_contract_parties.user_id = NEW.signer_user_id
    ) THEN
        RAISE EXCEPTION 'signer_user_id % nao e parte do contrato %', NEW.signer_user_id, NEW.legal_contract_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Indices TECH para clients, credenciais, conectores e webhooks.
CREATE INDEX ix_tech_api_clients_owner_status
    ON tech_api_clients (owner_user_id, client_status, created_at);

CREATE INDEX ix_tech_api_credentials_client_status
    ON tech_api_credentials (api_client_id, credential_status, created_at);

CREATE INDEX ix_tech_integration_connectors_owner_status
    ON tech_integration_connectors (owner_user_id, connector_status, updated_at);

CREATE INDEX ix_tech_webhook_subscriptions_owner_status
    ON tech_webhook_subscriptions (owner_user_id, subscription_status, updated_at);

CREATE INDEX ix_tech_webhook_delivery_attempts_subscription_time
    ON tech_webhook_delivery_attempts (webhook_subscription_id, attempted_at);

CREATE INDEX ix_tech_api_usage_daily_owner_date
    ON tech_api_usage_daily (owner_user_id, usage_date);

-- Indices LEGAL para contratos, partes, assinaturas e disputas.
CREATE INDEX ix_legal_contracts_owner_status
    ON legal_contracts (owner_user_id, contract_status, created_at);

CREATE INDEX ix_legal_contract_parties_user_role
    ON legal_contract_parties (user_id, party_role, created_at);

CREATE INDEX ix_legal_signatures_contract_status
    ON legal_signatures (legal_contract_id, signature_status, created_at);

CREATE INDEX ix_legal_disputes_owner_status
    ON legal_disputes (owner_user_id, dispute_status, created_at);

CREATE INDEX ix_legal_audit_events_contract_time
    ON legal_audit_events (legal_contract_id, created_at)
    WHERE legal_contract_id IS NOT NULL;

CREATE INDEX ix_legal_audit_events_dispute_time
    ON legal_audit_events (legal_dispute_id, created_at)
    WHERE legal_dispute_id IS NOT NULL;

-- Triggers updated_at para tabelas mutaveis TECH.
CREATE TRIGGER trg_tech_api_clients_set_updated_at
BEFORE UPDATE ON tech_api_clients
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_tech_api_credentials_set_updated_at
BEFORE UPDATE ON tech_api_credentials
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_tech_integration_connectors_set_updated_at
BEFORE UPDATE ON tech_integration_connectors
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_tech_webhook_subscriptions_set_updated_at
BEFORE UPDATE ON tech_webhook_subscriptions
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_tech_api_usage_daily_set_updated_at
BEFORE UPDATE ON tech_api_usage_daily
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

-- Triggers updated_at para tabelas mutaveis LEGAL.
CREATE TRIGGER trg_legal_contracts_set_updated_at
BEFORE UPDATE ON legal_contracts
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_legal_contract_parties_set_updated_at
BEFORE UPDATE ON legal_contract_parties
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_legal_disputes_set_updated_at
BEFORE UPDATE ON legal_disputes
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_legal_fallback_pin_credentials_set_updated_at
BEFORE UPDATE ON legal_fallback_pin_credentials
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

-- Triggers de coerencia TECH para impedir credenciais e webhooks com dono cruzado.
CREATE TRIGGER trg_tech_api_credentials_owner_coherence
BEFORE INSERT OR UPDATE ON tech_api_credentials
FOR EACH ROW
EXECUTE FUNCTION assert_tech_owner_coherence();

CREATE TRIGGER trg_tech_webhook_subscriptions_owner_coherence
BEFORE INSERT OR UPDATE ON tech_webhook_subscriptions
FOR EACH ROW
EXECUTE FUNCTION assert_tech_owner_coherence();

CREATE TRIGGER trg_tech_api_usage_daily_owner_coherence
BEFORE INSERT OR UPDATE ON tech_api_usage_daily
FOR EACH ROW
EXECUTE FUNCTION assert_tech_owner_coherence();

-- Trigger de coerencia LEGAL para assinatura somente por parte do contrato.
CREATE TRIGGER trg_legal_signatures_party_coherence
BEFORE INSERT ON legal_signatures
FOR EACH ROW
EXECUTE FUNCTION assert_legal_signature_party();

-- Triggers append-only para tentativas de webhook e trilhas juridicas.
CREATE TRIGGER trg_tech_webhook_delivery_attempts_prevent_update
BEFORE UPDATE ON tech_webhook_delivery_attempts
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

CREATE TRIGGER trg_tech_webhook_delivery_attempts_prevent_delete
BEFORE DELETE ON tech_webhook_delivery_attempts
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

CREATE TRIGGER trg_legal_signatures_prevent_update
BEFORE UPDATE ON legal_signatures
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

CREATE TRIGGER trg_legal_signatures_prevent_delete
BEFORE DELETE ON legal_signatures
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

CREATE TRIGGER trg_legal_audit_events_prevent_update
BEFORE UPDATE ON legal_audit_events
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

CREATE TRIGGER trg_legal_audit_events_prevent_delete
BEFORE DELETE ON legal_audit_events
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

COMMENT ON TYPE tech_api_client_status_enum IS 'Status de client de API do Valley Tech.';
COMMENT ON TYPE tech_credential_status_enum IS 'Status de credencial tecnica armazenada somente por hash.';
COMMENT ON TYPE tech_connector_status_enum IS 'Status de conector de integracao.';
COMMENT ON TYPE tech_auth_strategy_enum IS 'Estrategia de autenticacao sem expor segredo bruto.';
COMMENT ON TYPE webhook_subscription_status_enum IS 'Status de assinatura de webhook.';
COMMENT ON TYPE webhook_delivery_status_enum IS 'Status de tentativa append-only de webhook.';
COMMENT ON TYPE legal_contract_status_enum IS 'Status juridico de contrato.';
COMMENT ON TYPE legal_party_role_enum IS 'Papel de parte em contrato.';
COMMENT ON TYPE legal_signature_status_enum IS 'Status de assinatura juridica.';
COMMENT ON TYPE legal_signature_method_enum IS 'Metodo de assinatura, incluindo fallback PIN por hash.';
COMMENT ON TYPE legal_dispute_status_enum IS 'Status de disputa juridica.';
COMMENT ON TYPE legal_audit_event_type_enum IS 'Tipo de evento juridico append-only.';
COMMENT ON TYPE fallback_pin_status_enum IS 'Status de PIN de fallback armazenado apenas como hash.';

COMMENT ON TABLE tech_api_clients IS 'Clients de API do Valley Tech ligados a users.user_id.';
COMMENT ON TABLE tech_api_credentials IS 'Credenciais de API com hash SHA-256; sem segredo bruto.';
COMMENT ON TABLE tech_integration_connectors IS 'Conectores de integracao internos ou externos.';
COMMENT ON TABLE tech_webhook_subscriptions IS 'Assinaturas de webhook com secret apenas como hash.';
COMMENT ON TABLE tech_webhook_delivery_attempts IS 'Tentativas append-only de entrega de webhook.';
COMMENT ON TABLE tech_api_usage_daily IS 'Agregado diario mutavel de consumo de API.';
COMMENT ON TABLE legal_contracts IS 'Contratos juridicos do Valley Legal integrados a documentos.';
COMMENT ON TABLE legal_contract_parties IS 'Partes e papeis de contratos juridicos.';
COMMENT ON TABLE legal_signatures IS 'Assinaturas append-only com prova hash e metodo.';
COMMENT ON TABLE legal_disputes IS 'Disputas e mediacoes juridicas.';
COMMENT ON TABLE legal_audit_events IS 'Trilha append-only de eventos juridicos.';
COMMENT ON TABLE legal_fallback_pin_credentials IS 'Fallback PIN por usuario com hash SHA-256, sem PIN bruto.';

COMMENT ON FUNCTION assert_tech_owner_coherence() IS 'Trigger function que impede credencial, webhook ou uso diario com owner_user_id divergente.';
COMMENT ON FUNCTION assert_legal_signature_party() IS 'Trigger function que impede assinatura por usuario que nao esta nas partes do contrato.';

COMMENT ON COLUMN tech_api_clients.api_client_id IS 'PK UUID do client de API.';
COMMENT ON COLUMN tech_api_clients.owner_user_id IS 'FK para users.user_id do dono do client.';
COMMENT ON COLUMN tech_api_clients.module_code IS 'FK para module_delivery_registry, fixa em TECH.';
COMMENT ON COLUMN tech_api_clients.client_name IS 'Nome humano do client.';
COMMENT ON COLUMN tech_api_clients.client_status IS 'Lifecycle do client.';
COMMENT ON COLUMN tech_api_clients.allowed_modules IS 'Modulos autorizados para este client.';
COMMENT ON COLUMN tech_api_clients.redirect_uris IS 'Redirect URIs de OAuth ou fluxos similares.';
COMMENT ON COLUMN tech_api_clients.rate_limit_per_minute IS 'Limite por minuto para protecao de plataforma.';
COMMENT ON COLUMN tech_api_clients.metadata_json IS 'Metadados do client.';
COMMENT ON COLUMN tech_api_clients.created_at IS 'Criacao do registro.';
COMMENT ON COLUMN tech_api_clients.updated_at IS 'Ultima atualizacao do registro.';

COMMENT ON COLUMN tech_api_credentials.api_credential_id IS 'PK UUID da credencial.';
COMMENT ON COLUMN tech_api_credentials.api_client_id IS 'FK para tech_api_clients.';
COMMENT ON COLUMN tech_api_credentials.owner_user_id IS 'FK para users.user_id do dono.';
COMMENT ON COLUMN tech_api_credentials.credential_status IS 'Status da credencial.';
COMMENT ON COLUMN tech_api_credentials.key_prefix IS 'Prefixo publico para identificar chave sem revelar segredo.';
COMMENT ON COLUMN tech_api_credentials.key_hash_sha256 IS 'Hash SHA-256 da chave real.';
COMMENT ON COLUMN tech_api_credentials.scopes IS 'Permissoes tecnicas da credencial.';
COMMENT ON COLUMN tech_api_credentials.expires_at IS 'Expiracao opcional.';
COMMENT ON COLUMN tech_api_credentials.last_used_at IS 'Ultimo uso observado.';
COMMENT ON COLUMN tech_api_credentials.rotated_from_credential_id IS 'Credencial anterior quando houve rotacao.';
COMMENT ON COLUMN tech_api_credentials.created_at IS 'Criacao do registro.';
COMMENT ON COLUMN tech_api_credentials.updated_at IS 'Ultima atualizacao do registro.';

COMMENT ON COLUMN tech_integration_connectors.connector_id IS 'PK UUID do conector.';
COMMENT ON COLUMN tech_integration_connectors.owner_user_id IS 'FK para users.user_id do dono.';
COMMENT ON COLUMN tech_integration_connectors.module_code IS 'FK para module_delivery_registry, fixa em TECH.';
COMMENT ON COLUMN tech_integration_connectors.connector_name IS 'Nome humano do conector.';
COMMENT ON COLUMN tech_integration_connectors.connector_type IS 'Tipo tecnico do conector.';
COMMENT ON COLUMN tech_integration_connectors.connector_status IS 'Status do conector.';
COMMENT ON COLUMN tech_integration_connectors.auth_strategy IS 'Estrategia de autenticacao.';
COMMENT ON COLUMN tech_integration_connectors.endpoint_url IS 'Endpoint de integracao quando existir.';
COMMENT ON COLUMN tech_integration_connectors.config_json IS 'Configuracao sem segredo bruto.';
COMMENT ON COLUMN tech_integration_connectors.health_status_json IS 'Resultado de healthcheck.';
COMMENT ON COLUMN tech_integration_connectors.last_healthcheck_at IS 'Ultimo healthcheck.';
COMMENT ON COLUMN tech_integration_connectors.created_at IS 'Criacao do registro.';
COMMENT ON COLUMN tech_integration_connectors.updated_at IS 'Ultima atualizacao do registro.';

COMMENT ON COLUMN tech_webhook_subscriptions.webhook_subscription_id IS 'PK UUID da assinatura de webhook.';
COMMENT ON COLUMN tech_webhook_subscriptions.owner_user_id IS 'FK para users.user_id do dono.';
COMMENT ON COLUMN tech_webhook_subscriptions.api_client_id IS 'FK opcional para client de API.';
COMMENT ON COLUMN tech_webhook_subscriptions.connector_id IS 'FK opcional para conector.';
COMMENT ON COLUMN tech_webhook_subscriptions.module_code IS 'FK para module_delivery_registry, fixa em TECH.';
COMMENT ON COLUMN tech_webhook_subscriptions.subscription_status IS 'Status da assinatura.';
COMMENT ON COLUMN tech_webhook_subscriptions.target_url IS 'URL HTTPS de destino.';
COMMENT ON COLUMN tech_webhook_subscriptions.event_types IS 'Tipos de evento entregues.';
COMMENT ON COLUMN tech_webhook_subscriptions.signing_secret_hash_sha256 IS 'Hash SHA-256 do segredo de assinatura.';
COMMENT ON COLUMN tech_webhook_subscriptions.retry_policy_json IS 'Politica de retentativa.';
COMMENT ON COLUMN tech_webhook_subscriptions.last_delivery_at IS 'Ultima entrega observada.';
COMMENT ON COLUMN tech_webhook_subscriptions.created_at IS 'Criacao do registro.';
COMMENT ON COLUMN tech_webhook_subscriptions.updated_at IS 'Ultima atualizacao do registro.';

COMMENT ON COLUMN tech_webhook_delivery_attempts.webhook_delivery_attempt_id IS 'PK UUID da tentativa.';
COMMENT ON COLUMN tech_webhook_delivery_attempts.webhook_subscription_id IS 'FK para assinatura.';
COMMENT ON COLUMN tech_webhook_delivery_attempts.owner_user_id IS 'FK para users.user_id do dono.';
COMMENT ON COLUMN tech_webhook_delivery_attempts.event_type IS 'Tipo de evento entregue.';
COMMENT ON COLUMN tech_webhook_delivery_attempts.payload_hash_sha256 IS 'Hash SHA-256 do payload entregue.';
COMMENT ON COLUMN tech_webhook_delivery_attempts.delivery_status IS 'Resultado da tentativa.';
COMMENT ON COLUMN tech_webhook_delivery_attempts.response_status_code IS 'HTTP status code retornado.';
COMMENT ON COLUMN tech_webhook_delivery_attempts.duration_ms IS 'Duracao da tentativa em ms.';
COMMENT ON COLUMN tech_webhook_delivery_attempts.error_message IS 'Erro resumido quando houver.';
COMMENT ON COLUMN tech_webhook_delivery_attempts.attempted_at IS 'Momento da tentativa.';
COMMENT ON COLUMN tech_webhook_delivery_attempts.created_at IS 'Criacao append-only do registro.';

COMMENT ON COLUMN tech_api_usage_daily.api_usage_daily_id IS 'PK UUID do agregado diario.';
COMMENT ON COLUMN tech_api_usage_daily.api_client_id IS 'FK para client.';
COMMENT ON COLUMN tech_api_usage_daily.owner_user_id IS 'FK para users.user_id do dono.';
COMMENT ON COLUMN tech_api_usage_daily.usage_date IS 'Dia de uso.';
COMMENT ON COLUMN tech_api_usage_daily.request_count IS 'Total de requests.';
COMMENT ON COLUMN tech_api_usage_daily.error_count IS 'Total de erros.';
COMMENT ON COLUMN tech_api_usage_daily.bytes_in IS 'Bytes de entrada.';
COMMENT ON COLUMN tech_api_usage_daily.bytes_out IS 'Bytes de saida.';
COMMENT ON COLUMN tech_api_usage_daily.created_at IS 'Criacao do agregado.';
COMMENT ON COLUMN tech_api_usage_daily.updated_at IS 'Ultima atualizacao do agregado.';

COMMENT ON COLUMN legal_contracts.legal_contract_id IS 'PK UUID do contrato juridico.';
COMMENT ON COLUMN legal_contracts.owner_user_id IS 'FK para users.user_id do dono.';
COMMENT ON COLUMN legal_contracts.counterparty_user_id IS 'FK opcional para contraparte.';
COMMENT ON COLUMN legal_contracts.module_code IS 'FK para module_delivery_registry, fixa em LEGAL.';
COMMENT ON COLUMN legal_contracts.document_id IS 'FK opcional para document_records.';
COMMENT ON COLUMN legal_contracts.contract_status IS 'Status juridico do contrato.';
COMMENT ON COLUMN legal_contracts.contract_type IS 'Tipo tecnico do contrato.';
COMMENT ON COLUMN legal_contracts.title IS 'Titulo humano do contrato.';
COMMENT ON COLUMN legal_contracts.jurisdiction_country IS 'Pais de jurisdicao em ISO-2.';
COMMENT ON COLUMN legal_contracts.terms_hash_sha256 IS 'Hash SHA-256 dos termos vigentes.';
COMMENT ON COLUMN legal_contracts.contract_uri IS 'URI segura do contrato.';
COMMENT ON COLUMN legal_contracts.effective_at IS 'Inicio de vigencia.';
COMMENT ON COLUMN legal_contracts.expires_at IS 'Fim de vigencia opcional.';
COMMENT ON COLUMN legal_contracts.metadata_json IS 'Metadados juridicos.';
COMMENT ON COLUMN legal_contracts.created_at IS 'Criacao do registro.';
COMMENT ON COLUMN legal_contracts.updated_at IS 'Ultima atualizacao do registro.';

COMMENT ON COLUMN legal_contract_parties.legal_contract_party_id IS 'PK UUID da parte.';
COMMENT ON COLUMN legal_contract_parties.legal_contract_id IS 'FK para contrato.';
COMMENT ON COLUMN legal_contract_parties.user_id IS 'FK para users.user_id da parte.';
COMMENT ON COLUMN legal_contract_parties.party_role IS 'Papel juridico da parte.';
COMMENT ON COLUMN legal_contract_parties.signing_order IS 'Ordem de assinatura.';
COMMENT ON COLUMN legal_contract_parties.accepted_at IS 'Aceite da parte quando existir.';
COMMENT ON COLUMN legal_contract_parties.created_at IS 'Criacao do registro.';
COMMENT ON COLUMN legal_contract_parties.updated_at IS 'Ultima atualizacao do registro.';

COMMENT ON COLUMN legal_signatures.legal_signature_id IS 'PK UUID da assinatura.';
COMMENT ON COLUMN legal_signatures.legal_contract_id IS 'FK para contrato.';
COMMENT ON COLUMN legal_signatures.signer_user_id IS 'FK para users.user_id do assinante.';
COMMENT ON COLUMN legal_signatures.document_id IS 'FK opcional para document_records.';
COMMENT ON COLUMN legal_signatures.signature_status IS 'Status da assinatura.';
COMMENT ON COLUMN legal_signatures.signature_method IS 'Metodo de assinatura.';
COMMENT ON COLUMN legal_signatures.signature_hash_sha256 IS 'Hash SHA-256 da prova de assinatura.';
COMMENT ON COLUMN legal_signatures.ip_hash_sha256 IS 'Hash SHA-256 do IP, sem guardar IP bruto.';
COMMENT ON COLUMN legal_signatures.device_fingerprint_hash_sha256 IS 'Hash SHA-256 do device fingerprint.';
COMMENT ON COLUMN legal_signatures.signed_at IS 'Momento da assinatura.';
COMMENT ON COLUMN legal_signatures.created_at IS 'Criacao append-only do registro.';

COMMENT ON COLUMN legal_disputes.legal_dispute_id IS 'PK UUID da disputa.';
COMMENT ON COLUMN legal_disputes.owner_user_id IS 'FK para users.user_id do dono.';
COMMENT ON COLUMN legal_disputes.opened_by_user_id IS 'FK para users.user_id de quem abriu.';
COMMENT ON COLUMN legal_disputes.assigned_admin_id IS 'FK opcional para admin responsavel.';
COMMENT ON COLUMN legal_disputes.module_code IS 'FK para module_delivery_registry, fixa em LEGAL.';
COMMENT ON COLUMN legal_disputes.legal_contract_id IS 'FK opcional para contrato.';
COMMENT ON COLUMN legal_disputes.order_id IS 'FK opcional para pedido.';
COMMENT ON COLUMN legal_disputes.transaction_id IS 'FK opcional para transacao.';
COMMENT ON COLUMN legal_disputes.dispute_status IS 'Status da disputa.';
COMMENT ON COLUMN legal_disputes.dispute_reason IS 'Motivo da disputa.';
COMMENT ON COLUMN legal_disputes.resolution_summary IS 'Resumo da resolucao.';
COMMENT ON COLUMN legal_disputes.opened_at IS 'Abertura da disputa.';
COMMENT ON COLUMN legal_disputes.resolved_at IS 'Resolucao da disputa.';
COMMENT ON COLUMN legal_disputes.metadata_json IS 'Metadados da disputa.';
COMMENT ON COLUMN legal_disputes.created_at IS 'Criacao do registro.';
COMMENT ON COLUMN legal_disputes.updated_at IS 'Ultima atualizacao do registro.';

COMMENT ON COLUMN legal_audit_events.legal_audit_event_id IS 'PK UUID do evento juridico.';
COMMENT ON COLUMN legal_audit_events.legal_contract_id IS 'FK opcional para contrato.';
COMMENT ON COLUMN legal_audit_events.legal_dispute_id IS 'FK opcional para disputa.';
COMMENT ON COLUMN legal_audit_events.user_id IS 'FK opcional para usuario.';
COMMENT ON COLUMN legal_audit_events.admin_id IS 'FK opcional para admin.';
COMMENT ON COLUMN legal_audit_events.event_type IS 'Tipo do evento juridico.';
COMMENT ON COLUMN legal_audit_events.event_name IS 'Nome tecnico do evento.';
COMMENT ON COLUMN legal_audit_events.event_payload_json IS 'Payload controlado do evento.';
COMMENT ON COLUMN legal_audit_events.event_hash_sha256 IS 'Hash SHA-256 opcional da prova.';
COMMENT ON COLUMN legal_audit_events.created_at IS 'Criacao append-only do evento.';

COMMENT ON COLUMN legal_fallback_pin_credentials.fallback_pin_id IS 'PK UUID do fallback PIN.';
COMMENT ON COLUMN legal_fallback_pin_credentials.user_id IS 'FK unica para users.user_id.';
COMMENT ON COLUMN legal_fallback_pin_credentials.pin_status IS 'Status do fallback PIN.';
COMMENT ON COLUMN legal_fallback_pin_credentials.pin_hash_sha256 IS 'Hash SHA-256 do PIN, sem PIN bruto.';
COMMENT ON COLUMN legal_fallback_pin_credentials.failed_attempts IS 'Tentativas falhas acumuladas.';
COMMENT ON COLUMN legal_fallback_pin_credentials.locked_until IS 'Bloqueio temporario quando status LOCKED.';
COMMENT ON COLUMN legal_fallback_pin_credentials.last_verified_at IS 'Ultima verificacao bem-sucedida.';
COMMENT ON COLUMN legal_fallback_pin_credentials.created_at IS 'Criacao do registro.';
COMMENT ON COLUMN legal_fallback_pin_credentials.updated_at IS 'Ultima atualizacao do registro.';

COMMIT;
