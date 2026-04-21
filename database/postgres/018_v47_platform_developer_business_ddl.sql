BEGIN;

-- Aprofunda o dominio Platform Developer com DDL de negocio real para DOCS e TECH.
-- Esta migration sai do nivel apenas de registry/views e cria contratos operacionais
-- para template documental, trilha de checksum, versionamento de recibos, limites por client,
-- rotacao segura de credenciais e replay controlado de webhook.

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_type WHERE typname = 'docs_template_scope_enum'
    ) THEN
        CREATE TYPE docs_template_scope_enum AS ENUM (
            'GENERIC',
            'ORDER',
            'TRANSACTION',
            'LEGAL_CONTRACT',
            'TICKET'
        );
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_type WHERE typname = 'docs_template_status_enum'
    ) THEN
        CREATE TYPE docs_template_status_enum AS ENUM (
            'DRAFT',
            'ACTIVE',
            'DEPRECATED',
            'ARCHIVED'
        );
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_type WHERE typname = 'docs_template_version_status_enum'
    ) THEN
        CREATE TYPE docs_template_version_status_enum AS ENUM (
            'DRAFT',
            'PUBLISHED',
            'SUPERSEDED',
            'REVOKED'
        );
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_type WHERE typname = 'docs_checksum_event_type_enum'
    ) THEN
        CREATE TYPE docs_checksum_event_type_enum AS ENUM (
            'REGISTERED',
            'VERIFIED',
            'SUPERSEDED'
        );
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_type WHERE typname = 'docs_receipt_version_status_enum'
    ) THEN
        CREATE TYPE docs_receipt_version_status_enum AS ENUM (
            'GENERATED',
            'PUBLISHED',
            'SUPERSEDED',
            'CANCELLED'
        );
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_type WHERE typname = 'tech_limit_scope_enum'
    ) THEN
        CREATE TYPE tech_limit_scope_enum AS ENUM (
            'GLOBAL',
            'MODULE',
            'ENDPOINT',
            'EVENT_TOPIC'
        );
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_type WHERE typname = 'tech_limit_window_enum'
    ) THEN
        CREATE TYPE tech_limit_window_enum AS ENUM (
            'MINUTE',
            'HOUR',
            'DAY',
            'MONTH'
        );
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_type WHERE typname = 'tech_limit_status_enum'
    ) THEN
        CREATE TYPE tech_limit_status_enum AS ENUM (
            'DRAFT',
            'ACTIVE',
            'PAUSED',
            'ARCHIVED'
        );
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_type WHERE typname = 'tech_rotation_reason_enum'
    ) THEN
        CREATE TYPE tech_rotation_reason_enum AS ENUM (
            'SCHEDULED',
            'COMPROMISED',
            'MANUAL',
            'EXPIRING'
        );
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_type WHERE typname = 'tech_webhook_replay_status_enum'
    ) THEN
        CREATE TYPE tech_webhook_replay_status_enum AS ENUM (
            'REQUESTED',
            'APPROVED',
            'REJECTED',
            'REPLAYED',
            'FAILED',
            'CANCELLED'
        );
    END IF;
END
$$;

CREATE TABLE IF NOT EXISTS docs_template_contracts (
    template_contract_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_user_id UUID NOT NULL,
    module_code TEXT NOT NULL DEFAULT 'DOCS',
    template_name TEXT NOT NULL,
    template_scope docs_template_scope_enum NOT NULL DEFAULT 'GENERIC',
    template_status docs_template_status_enum NOT NULL DEFAULT 'DRAFT',
    source_legal_contract_id UUID,
    render_engine TEXT NOT NULL DEFAULT 'HTML_TO_PDF',
    checksum_policy_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    variable_schema_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    published_version_number INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_docs_template_contracts_owner
        FOREIGN KEY (owner_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_docs_template_contracts_module
        FOREIGN KEY (module_code) REFERENCES module_delivery_registry (module_code)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_docs_template_contracts_legal_contract
        FOREIGN KEY (source_legal_contract_id) REFERENCES legal_contracts (legal_contract_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT ux_docs_template_contracts_name_scope UNIQUE (owner_user_id, template_name, template_scope),
    CONSTRAINT chk_docs_template_contracts_module_code CHECK (module_code = 'DOCS'),
    CONSTRAINT chk_docs_template_contracts_name CHECK (btrim(template_name) <> ''),
    CONSTRAINT chk_docs_template_contracts_engine CHECK (btrim(render_engine) <> ''),
    CONSTRAINT chk_docs_template_contracts_checksum_json CHECK (jsonb_typeof(checksum_policy_json) = 'object'),
    CONSTRAINT chk_docs_template_contracts_variable_json CHECK (jsonb_typeof(variable_schema_json) = 'object'),
    CONSTRAINT chk_docs_template_contracts_published_version CHECK (published_version_number >= 0)
);

CREATE TABLE IF NOT EXISTS docs_template_versions (
    template_version_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    template_contract_id UUID NOT NULL,
    owner_user_id UUID NOT NULL,
    template_document_id UUID NOT NULL,
    version_number INTEGER NOT NULL,
    version_status docs_template_version_status_enum NOT NULL DEFAULT 'DRAFT',
    checksum_sha256 TEXT NOT NULL,
    render_schema_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    published_by_user_id UUID,
    published_at TIMESTAMPTZ,
    supersedes_template_version_id UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_docs_template_versions_contract
        FOREIGN KEY (template_contract_id) REFERENCES docs_template_contracts (template_contract_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT fk_docs_template_versions_owner
        FOREIGN KEY (owner_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_docs_template_versions_document
        FOREIGN KEY (template_document_id) REFERENCES document_records (document_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_docs_template_versions_published_by
        FOREIGN KEY (published_by_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_docs_template_versions_supersedes
        FOREIGN KEY (supersedes_template_version_id) REFERENCES docs_template_versions (template_version_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT ux_docs_template_versions_contract_version UNIQUE (template_contract_id, version_number),
    CONSTRAINT chk_docs_template_versions_number CHECK (version_number > 0),
    CONSTRAINT chk_docs_template_versions_checksum CHECK (checksum_sha256 ~ '^[a-fA-F0-9]{64}$'),
    CONSTRAINT chk_docs_template_versions_render_json CHECK (jsonb_typeof(render_schema_json) = 'object'),
    CONSTRAINT chk_docs_template_versions_publish_timeline CHECK (
        published_at IS NULL OR published_at >= created_at
    )
);

CREATE TABLE IF NOT EXISTS docs_document_checksum_events (
    checksum_event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id UUID NOT NULL,
    owner_user_id UUID NOT NULL,
    module_code TEXT NOT NULL DEFAULT 'DOCS',
    checksum_event_type docs_checksum_event_type_enum NOT NULL,
    checksum_sha256 TEXT NOT NULL,
    previous_checksum_event_id UUID,
    receipt_id UUID,
    template_version_id UUID,
    reference_event_topic TEXT,
    notes TEXT,
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_docs_document_checksum_events_document
        FOREIGN KEY (document_id) REFERENCES document_records (document_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_docs_document_checksum_events_owner
        FOREIGN KEY (owner_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_docs_document_checksum_events_module
        FOREIGN KEY (module_code) REFERENCES module_delivery_registry (module_code)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_docs_document_checksum_events_previous
        FOREIGN KEY (previous_checksum_event_id) REFERENCES docs_document_checksum_events (checksum_event_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_docs_document_checksum_events_receipt
        FOREIGN KEY (receipt_id) REFERENCES docs_receipts (receipt_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_docs_document_checksum_events_template_version
        FOREIGN KEY (template_version_id) REFERENCES docs_template_versions (template_version_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT chk_docs_document_checksum_events_module_code CHECK (module_code = 'DOCS'),
    CONSTRAINT chk_docs_document_checksum_events_checksum CHECK (checksum_sha256 ~ '^[a-fA-F0-9]{64}$'),
    CONSTRAINT chk_docs_document_checksum_events_topic CHECK (
        reference_event_topic IS NULL OR reference_event_topic ~ '^[a-z0-9._]+$'
    ),
    CONSTRAINT chk_docs_document_checksum_events_notes CHECK (
        notes IS NULL OR btrim(notes) <> ''
    )
);

CREATE TABLE IF NOT EXISTS docs_receipt_versions (
    receipt_version_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    receipt_id UUID NOT NULL,
    owner_user_id UUID NOT NULL,
    version_number INTEGER NOT NULL,
    version_status docs_receipt_version_status_enum NOT NULL DEFAULT 'GENERATED',
    document_id UUID NOT NULL,
    checksum_event_id UUID,
    template_version_id UUID,
    file_url TEXT NOT NULL,
    render_context_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    supersedes_receipt_version_id UUID,
    published_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_docs_receipt_versions_receipt
        FOREIGN KEY (receipt_id) REFERENCES docs_receipts (receipt_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT fk_docs_receipt_versions_owner
        FOREIGN KEY (owner_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_docs_receipt_versions_document
        FOREIGN KEY (document_id) REFERENCES document_records (document_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_docs_receipt_versions_checksum_event
        FOREIGN KEY (checksum_event_id) REFERENCES docs_document_checksum_events (checksum_event_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_docs_receipt_versions_template_version
        FOREIGN KEY (template_version_id) REFERENCES docs_template_versions (template_version_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_docs_receipt_versions_supersedes
        FOREIGN KEY (supersedes_receipt_version_id) REFERENCES docs_receipt_versions (receipt_version_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT ux_docs_receipt_versions_receipt_version UNIQUE (receipt_id, version_number),
    CONSTRAINT chk_docs_receipt_versions_number CHECK (version_number > 0),
    CONSTRAINT chk_docs_receipt_versions_file_url CHECK (btrim(file_url) <> ''),
    CONSTRAINT chk_docs_receipt_versions_context_json CHECK (jsonb_typeof(render_context_json) = 'object'),
    CONSTRAINT chk_docs_receipt_versions_publish_timeline CHECK (
        published_at IS NULL OR published_at >= created_at
    )
);

CREATE TABLE IF NOT EXISTS tech_client_module_limits (
    api_client_limit_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    api_client_id UUID NOT NULL,
    owner_user_id UUID NOT NULL,
    module_code TEXT,
    limit_scope tech_limit_scope_enum NOT NULL DEFAULT 'GLOBAL',
    limit_window tech_limit_window_enum NOT NULL DEFAULT 'MINUTE',
    endpoint_pattern TEXT,
    event_topic TEXT,
    limit_status tech_limit_status_enum NOT NULL DEFAULT 'ACTIVE',
    hard_limit_count INTEGER NOT NULL,
    burst_limit_count INTEGER NOT NULL DEFAULT 0,
    cooldown_seconds INTEGER NOT NULL DEFAULT 0,
    effective_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    effective_until TIMESTAMPTZ,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_tech_client_module_limits_client
        FOREIGN KEY (api_client_id) REFERENCES tech_api_clients (api_client_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT fk_tech_client_module_limits_owner
        FOREIGN KEY (owner_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_tech_client_module_limits_module
        FOREIGN KEY (module_code) REFERENCES module_delivery_registry (module_code)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT chk_tech_client_module_limits_hard_limit CHECK (hard_limit_count > 0),
    CONSTRAINT chk_tech_client_module_limits_burst CHECK (burst_limit_count >= 0),
    CONSTRAINT chk_tech_client_module_limits_cooldown CHECK (cooldown_seconds >= 0),
    CONSTRAINT chk_tech_client_module_limits_effective_window CHECK (
        effective_until IS NULL OR effective_until > effective_from
    ),
    CONSTRAINT chk_tech_client_module_limits_metadata_json CHECK (jsonb_typeof(metadata_json) = 'object'),
    CONSTRAINT chk_tech_client_module_limits_scope_requirements CHECK (
        (limit_scope <> 'MODULE' OR module_code IS NOT NULL)
        AND (limit_scope <> 'ENDPOINT' OR endpoint_pattern IS NOT NULL)
        AND (limit_scope <> 'EVENT_TOPIC' OR event_topic IS NOT NULL)
    ),
    CONSTRAINT chk_tech_client_module_limits_endpoint CHECK (
        endpoint_pattern IS NULL OR btrim(endpoint_pattern) <> ''
    ),
    CONSTRAINT chk_tech_client_module_limits_event_topic CHECK (
        event_topic IS NULL OR event_topic ~ '^[a-z0-9._]+$'
    )
);

CREATE TABLE IF NOT EXISTS tech_credential_rotation_events (
    credential_rotation_event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    api_client_id UUID NOT NULL,
    owner_user_id UUID NOT NULL,
    previous_credential_id UUID NOT NULL,
    new_credential_id UUID NOT NULL,
    rotation_reason tech_rotation_reason_enum NOT NULL DEFAULT 'SCHEDULED',
    approved_by_user_id UUID,
    rotation_notes TEXT,
    rotation_window_started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    rotation_window_closed_at TIMESTAMPTZ,
    compromised_detected_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_tech_credential_rotation_events_client
        FOREIGN KEY (api_client_id) REFERENCES tech_api_clients (api_client_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT fk_tech_credential_rotation_events_owner
        FOREIGN KEY (owner_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_tech_credential_rotation_events_previous
        FOREIGN KEY (previous_credential_id) REFERENCES tech_api_credentials (api_credential_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_tech_credential_rotation_events_new
        FOREIGN KEY (new_credential_id) REFERENCES tech_api_credentials (api_credential_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_tech_credential_rotation_events_approved_by
        FOREIGN KEY (approved_by_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT chk_tech_credential_rotation_events_distinct_credentials CHECK (
        previous_credential_id <> new_credential_id
    ),
    CONSTRAINT chk_tech_credential_rotation_events_notes CHECK (
        rotation_notes IS NULL OR btrim(rotation_notes) <> ''
    ),
    CONSTRAINT chk_tech_credential_rotation_events_timeline CHECK (
        (rotation_window_closed_at IS NULL OR rotation_window_closed_at >= rotation_window_started_at)
        AND (compromised_detected_at IS NULL OR compromised_detected_at <= COALESCE(rotation_window_closed_at, compromised_detected_at))
    )
);

CREATE TABLE IF NOT EXISTS tech_webhook_replay_requests (
    webhook_replay_request_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    webhook_subscription_id UUID NOT NULL,
    original_delivery_attempt_id UUID NOT NULL,
    owner_user_id UUID NOT NULL,
    requested_by_user_id UUID NOT NULL,
    approved_by_user_id UUID,
    replay_delivery_attempt_id UUID,
    replay_status tech_webhook_replay_status_enum NOT NULL DEFAULT 'REQUESTED',
    idempotency_key TEXT NOT NULL UNIQUE,
    replay_reason TEXT NOT NULL,
    payload_hash_sha256 TEXT NOT NULL,
    requested_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    approved_at TIMESTAMPTZ,
    replayed_at TIMESTAMPTZ,
    failed_at TIMESTAMPTZ,
    status_notes TEXT,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_tech_webhook_replay_requests_subscription
        FOREIGN KEY (webhook_subscription_id) REFERENCES tech_webhook_subscriptions (webhook_subscription_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT fk_tech_webhook_replay_requests_original_attempt
        FOREIGN KEY (original_delivery_attempt_id) REFERENCES tech_webhook_delivery_attempts (webhook_delivery_attempt_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_tech_webhook_replay_requests_owner
        FOREIGN KEY (owner_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_tech_webhook_replay_requests_requested_by
        FOREIGN KEY (requested_by_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_tech_webhook_replay_requests_approved_by
        FOREIGN KEY (approved_by_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_tech_webhook_replay_requests_replay_attempt
        FOREIGN KEY (replay_delivery_attempt_id) REFERENCES tech_webhook_delivery_attempts (webhook_delivery_attempt_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT chk_tech_webhook_replay_requests_idempotency CHECK (
        idempotency_key ~ '^[A-Za-z0-9:_-]{8,120}$'
    ),
    CONSTRAINT chk_tech_webhook_replay_requests_reason CHECK (btrim(replay_reason) <> ''),
    CONSTRAINT chk_tech_webhook_replay_requests_hash CHECK (payload_hash_sha256 ~ '^[a-fA-F0-9]{64}$'),
    CONSTRAINT chk_tech_webhook_replay_requests_notes CHECK (
        status_notes IS NULL OR btrim(status_notes) <> ''
    ),
    CONSTRAINT chk_tech_webhook_replay_requests_metadata_json CHECK (jsonb_typeof(metadata_json) = 'object'),
    CONSTRAINT chk_tech_webhook_replay_requests_timeline CHECK (
        (approved_at IS NULL OR approved_at >= requested_at)
        AND (replayed_at IS NULL OR replayed_at >= COALESCE(approved_at, requested_at))
        AND (failed_at IS NULL OR failed_at >= requested_at)
    )
);

CREATE INDEX IF NOT EXISTS ix_docs_template_contracts_owner_status
    ON docs_template_contracts (owner_user_id, template_status, template_scope);

CREATE INDEX IF NOT EXISTS ix_docs_template_versions_contract_version
    ON docs_template_versions (template_contract_id, version_number DESC);

CREATE INDEX IF NOT EXISTS ix_docs_document_checksum_events_document_time
    ON docs_document_checksum_events (document_id, occurred_at DESC);

CREATE INDEX IF NOT EXISTS ix_docs_receipt_versions_receipt_version
    ON docs_receipt_versions (receipt_id, version_number DESC);

CREATE INDEX IF NOT EXISTS ix_tech_client_module_limits_client_status
    ON tech_client_module_limits (api_client_id, limit_status, module_code);

CREATE INDEX IF NOT EXISTS ix_tech_credential_rotation_events_client_time
    ON tech_credential_rotation_events (api_client_id, created_at DESC);

CREATE INDEX IF NOT EXISTS ix_tech_webhook_replay_requests_subscription_status
    ON tech_webhook_replay_requests (webhook_subscription_id, replay_status, requested_at DESC);

DROP TRIGGER IF EXISTS trg_docs_template_contracts_set_updated_at
    ON docs_template_contracts;
CREATE TRIGGER trg_docs_template_contracts_set_updated_at
BEFORE UPDATE ON docs_template_contracts
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_tech_client_module_limits_set_updated_at
    ON tech_client_module_limits;
CREATE TRIGGER trg_tech_client_module_limits_set_updated_at
BEFORE UPDATE ON tech_client_module_limits
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_tech_webhook_replay_requests_set_updated_at
    ON tech_webhook_replay_requests;
CREATE TRIGGER trg_tech_webhook_replay_requests_set_updated_at
BEFORE UPDATE ON tech_webhook_replay_requests
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_docs_template_versions_prevent_update
    ON docs_template_versions;
CREATE TRIGGER trg_docs_template_versions_prevent_update
BEFORE UPDATE ON docs_template_versions
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

DROP TRIGGER IF EXISTS trg_docs_template_versions_prevent_delete
    ON docs_template_versions;
CREATE TRIGGER trg_docs_template_versions_prevent_delete
BEFORE DELETE ON docs_template_versions
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

DROP TRIGGER IF EXISTS trg_docs_document_checksum_events_prevent_update
    ON docs_document_checksum_events;
CREATE TRIGGER trg_docs_document_checksum_events_prevent_update
BEFORE UPDATE ON docs_document_checksum_events
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

DROP TRIGGER IF EXISTS trg_docs_document_checksum_events_prevent_delete
    ON docs_document_checksum_events;
CREATE TRIGGER trg_docs_document_checksum_events_prevent_delete
BEFORE DELETE ON docs_document_checksum_events
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

DROP TRIGGER IF EXISTS trg_docs_receipt_versions_prevent_update
    ON docs_receipt_versions;
CREATE TRIGGER trg_docs_receipt_versions_prevent_update
BEFORE UPDATE ON docs_receipt_versions
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

DROP TRIGGER IF EXISTS trg_docs_receipt_versions_prevent_delete
    ON docs_receipt_versions;
CREATE TRIGGER trg_docs_receipt_versions_prevent_delete
BEFORE DELETE ON docs_receipt_versions
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

DROP TRIGGER IF EXISTS trg_tech_credential_rotation_events_prevent_update
    ON tech_credential_rotation_events;
CREATE TRIGGER trg_tech_credential_rotation_events_prevent_update
BEFORE UPDATE ON tech_credential_rotation_events
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

DROP TRIGGER IF EXISTS trg_tech_credential_rotation_events_prevent_delete
    ON tech_credential_rotation_events;
CREATE TRIGGER trg_tech_credential_rotation_events_prevent_delete
BEFORE DELETE ON tech_credential_rotation_events
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

CREATE OR REPLACE VIEW v_platform_developer_priority_backlog AS
SELECT
    backlog.backlog_key,
    backlog.module_code,
    registry.module_name,
    registry.module_number,
    registry.current_phase,
    backlog.execution_stage,
    backlog.priority,
    backlog.target_data_home,
    backlog.depends_on_keys,
    backlog.evidence_hint,
    registry.module_blueprint_json -> 'postgres_entities' AS postgres_entities,
    registry.module_blueprint_json -> 'event_topics' AS event_topics,
    registry.module_blueprint_json -> 'next_deliverables' AS next_deliverables
FROM module_evolution_backlog AS backlog
JOIN module_delivery_registry AS registry
  ON registry.module_code = backlog.module_code
WHERE backlog.backlog_group = 'platform_developer'
  AND backlog.origin_source = 'blueprint_execution_v1';

CREATE OR REPLACE VIEW v_platform_developer_delivery_artifacts AS
SELECT
    artifact_key,
    package_key,
    domain_key,
    layer_type,
    target_engine,
    artifact_path,
    module_codes,
    backlog_keys,
    depends_on_keys,
    artifact_status,
    artifact_payload_json,
    created_at,
    updated_at
FROM domain_delivery_artifacts
WHERE domain_key = 'platform_developer';

CREATE OR REPLACE VIEW v_platform_developer_event_contracts AS
SELECT
    contract_key,
    package_key,
    domain_key,
    module_code,
    event_topic,
    contract_version,
    producer_surface,
    consumer_surfaces,
    evidence_entities,
    compliance_tags,
    artifact_path,
    contract_status,
    payload_schema_json,
    created_at,
    updated_at
FROM domain_event_contracts
WHERE domain_key = 'platform_developer';

COMMENT ON TABLE docs_template_contracts IS
    'Contrato mutavel de template documental do modulo DOCS, com politica de checksum e schema de variaveis.';
COMMENT ON TABLE docs_template_versions IS
    'Versoes append-only de templates documentais para preservar renderizacao e prova hash.';
COMMENT ON TABLE docs_document_checksum_events IS
    'Trilha append-only da cadeia de checksum aplicada a documentos e recibos.';
COMMENT ON TABLE docs_receipt_versions IS
    'Historico append-only de versoes de recibo geradas pelo Valley Docs.';
COMMENT ON TABLE tech_client_module_limits IS
    'Limites operacionais por client para modulo, endpoint ou topico de evento.';
COMMENT ON TABLE tech_credential_rotation_events IS
    'Trilha append-only da rotacao de credenciais de API do Valley Tech.';
COMMENT ON TABLE tech_webhook_replay_requests IS
    'Pedidos controlados de replay de webhook com idempotencia, aprovacao e auditoria.';

COMMENT ON VIEW v_platform_developer_priority_backlog IS
    'Backlog prioritario do dominio platform_developer agora ancorado em DDL de negocio real.';
COMMENT ON VIEW v_platform_developer_delivery_artifacts IS
    'Artefatos registrados para o dominio platform_developer.';
COMMENT ON VIEW v_platform_developer_event_contracts IS
    'Contratos de evento exportados do dominio platform_developer.';

COMMIT;
