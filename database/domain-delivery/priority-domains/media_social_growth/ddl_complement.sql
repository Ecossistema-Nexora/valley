BEGIN;

-- Pacote gerado automaticamente para Media Social Growth.
-- Artefato: media_social_growth.priority.v1
-- Dependencias: migrations 016 e 017 aplicadas.

CREATE OR REPLACE VIEW v_media_social_growth_priority_backlog AS
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
    registry.module_blueprint_json -> 'mongo_collections' AS mongo_collections,
    registry.module_blueprint_json -> 'event_topics' AS event_topics,
    registry.module_blueprint_json -> 'next_deliverables' AS next_deliverables
FROM module_evolution_backlog AS backlog
JOIN module_delivery_registry AS registry
  ON registry.module_code = backlog.module_code
WHERE backlog.backlog_group = 'media_social_growth'
  AND backlog.origin_source = 'blueprint_execution_v1';

CREATE OR REPLACE VIEW v_media_social_growth_delivery_artifacts AS
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
WHERE domain_key = 'media_social_growth';

CREATE OR REPLACE VIEW v_media_social_growth_event_contracts AS
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
WHERE domain_key = 'media_social_growth';

COMMENT ON VIEW v_media_social_growth_priority_backlog IS
    'Visao operacional do backlog prioritario do dominio media_social_growth.';

COMMENT ON VIEW v_media_social_growth_delivery_artifacts IS
    'Visao dos artefatos fisicos por camada do dominio media_social_growth.';

COMMENT ON VIEW v_media_social_growth_event_contracts IS
    'Visao dos contratos de evento exportados do dominio media_social_growth.';

COMMIT;
