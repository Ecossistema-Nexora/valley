BEGIN;

-- Primeira onda de pacotes fisicos por dominio prioritario gerados automaticamente.
-- Dominios nesta onda: 7.

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_type
        WHERE typname = 'domain_delivery_layer_enum'
    ) THEN
        CREATE TYPE domain_delivery_layer_enum AS ENUM (
            'DDL_COMPLEMENT',
            'OPERATIONS_SEED',
            'EVENT_CONTRACT'
        );
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_type
        WHERE typname = 'domain_delivery_package_status_enum'
    ) THEN
        CREATE TYPE domain_delivery_package_status_enum AS ENUM (
            'PLANNED',
            'READY',
            'MATERIALIZED',
            'BLOCKED'
        );
    END IF;
END
$$;

CREATE TABLE IF NOT EXISTS domain_delivery_packages (
    domain_package_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_user_id UUID NULL,
    package_key TEXT NOT NULL,
    domain_key TEXT NOT NULL,
    domain_label TEXT NOT NULL,
    priority_rank SMALLINT NOT NULL,
    package_scope TEXT NOT NULL DEFAULT 'priority_domains_v1',
    module_codes TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
    backlog_keys TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
    package_status domain_delivery_package_status_enum NOT NULL DEFAULT 'READY',
    artifact_manifest_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_domain_delivery_packages_owner
        FOREIGN KEY (owner_user_id) REFERENCES users (user_id),
    CONSTRAINT ux_domain_delivery_packages_key UNIQUE (package_key),
    CONSTRAINT chk_domain_delivery_packages_key CHECK (btrim(package_key) <> ''),
    CONSTRAINT chk_domain_delivery_packages_domain CHECK (domain_key ~ '^[a-z0-9_]+$'),
    CONSTRAINT chk_domain_delivery_packages_label CHECK (btrim(domain_label) <> ''),
    CONSTRAINT chk_domain_delivery_packages_priority CHECK (priority_rank BETWEEN 1 AND 5),
    CONSTRAINT chk_domain_delivery_packages_scope CHECK (btrim(package_scope) <> '')
);

CREATE TABLE IF NOT EXISTS domain_delivery_artifacts (
    domain_artifact_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_user_id UUID NULL,
    package_key TEXT NOT NULL,
    artifact_key TEXT NOT NULL,
    domain_key TEXT NOT NULL,
    layer_type domain_delivery_layer_enum NOT NULL,
    target_engine TEXT NOT NULL,
    artifact_path TEXT NOT NULL,
    module_codes TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
    backlog_keys TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
    depends_on_keys TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
    artifact_status domain_delivery_package_status_enum NOT NULL DEFAULT 'READY',
    artifact_payload_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_domain_delivery_artifacts_owner
        FOREIGN KEY (owner_user_id) REFERENCES users (user_id),
    CONSTRAINT fk_domain_delivery_artifacts_package
        FOREIGN KEY (package_key) REFERENCES domain_delivery_packages (package_key)
        ON DELETE CASCADE,
    CONSTRAINT ux_domain_delivery_artifacts_key UNIQUE (artifact_key),
    CONSTRAINT chk_domain_delivery_artifacts_key CHECK (btrim(artifact_key) <> ''),
    CONSTRAINT chk_domain_delivery_artifacts_domain CHECK (domain_key ~ '^[a-z0-9_]+$'),
    CONSTRAINT chk_domain_delivery_artifacts_engine CHECK (target_engine IN ('postgres', 'mongo', 'filesystem')),
    CONSTRAINT chk_domain_delivery_artifacts_path CHECK (btrim(artifact_path) <> '')
);

CREATE TABLE IF NOT EXISTS domain_event_contracts (
    domain_event_contract_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_user_id UUID NULL,
    package_key TEXT NOT NULL,
    contract_key TEXT NOT NULL,
    domain_key TEXT NOT NULL,
    module_code TEXT NOT NULL,
    event_topic TEXT NOT NULL,
    contract_version TEXT NOT NULL DEFAULT '1.0.0',
    producer_surface TEXT NOT NULL,
    consumer_surfaces TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
    evidence_entities TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
    compliance_tags TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
    contract_status domain_delivery_package_status_enum NOT NULL DEFAULT 'READY',
    payload_schema_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    artifact_path TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_domain_event_contracts_owner
        FOREIGN KEY (owner_user_id) REFERENCES users (user_id),
    CONSTRAINT fk_domain_event_contracts_package
        FOREIGN KEY (package_key) REFERENCES domain_delivery_packages (package_key)
        ON DELETE CASCADE,
    CONSTRAINT fk_domain_event_contracts_module
        FOREIGN KEY (module_code) REFERENCES module_delivery_registry (module_code)
        ON DELETE CASCADE,
    CONSTRAINT ux_domain_event_contracts_key UNIQUE (contract_key),
    CONSTRAINT ux_domain_event_contracts_module_topic UNIQUE (module_code, event_topic),
    CONSTRAINT chk_domain_event_contracts_key CHECK (btrim(contract_key) <> ''),
    CONSTRAINT chk_domain_event_contracts_domain CHECK (domain_key ~ '^[a-z0-9_]+$'),
    CONSTRAINT chk_domain_event_contracts_topic CHECK (event_topic ~ '^[a-z0-9._]+$'),
    CONSTRAINT chk_domain_event_contracts_version CHECK (btrim(contract_version) <> ''),
    CONSTRAINT chk_domain_event_contracts_surface CHECK (btrim(producer_surface) <> ''),
    CONSTRAINT chk_domain_event_contracts_path CHECK (btrim(artifact_path) <> '')
);

CREATE INDEX IF NOT EXISTS ix_domain_delivery_packages_domain_status
    ON domain_delivery_packages (domain_key, package_status, priority_rank);

CREATE INDEX IF NOT EXISTS ix_domain_delivery_artifacts_domain_layer
    ON domain_delivery_artifacts (domain_key, layer_type, artifact_status);

CREATE INDEX IF NOT EXISTS ix_domain_event_contracts_domain_module
    ON domain_event_contracts (domain_key, module_code, contract_status);

DROP TRIGGER IF EXISTS trg_domain_delivery_packages_set_updated_at
    ON domain_delivery_packages;
CREATE TRIGGER trg_domain_delivery_packages_set_updated_at
BEFORE UPDATE ON domain_delivery_packages
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_domain_delivery_artifacts_set_updated_at
    ON domain_delivery_artifacts;
CREATE TRIGGER trg_domain_delivery_artifacts_set_updated_at
BEFORE UPDATE ON domain_delivery_artifacts
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_domain_event_contracts_set_updated_at
    ON domain_event_contracts;
CREATE TRIGGER trg_domain_event_contracts_set_updated_at
BEFORE UPDATE ON domain_event_contracts
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

COMMENT ON TABLE domain_delivery_packages IS
    'Registry da primeira onda de pacotes fisicos por dominio, derivado do backlog executavel.';

COMMENT ON TABLE domain_delivery_artifacts IS
    'Artefatos fisicos por camada: DDL complementar, seed operacional e contrato de evento.';

COMMENT ON TABLE domain_event_contracts IS
    'Contratos de evento exportados por dominio prioritario para integracao e auditoria.';

COMMENT ON COLUMN domain_delivery_packages.artifact_manifest_json IS
    'Manifesto consolidado dos artefatos gerados para o dominio.';

COMMENT ON COLUMN domain_delivery_artifacts.depends_on_keys IS
    'Dependencias internas entre artefatos do mesmo pacote de dominio.';

COMMENT ON COLUMN domain_event_contracts.payload_schema_json IS
    'JSON Schema pragmatico do evento para produtores e consumidores tecnicos.';

COMMIT;
