BEGIN;

-- Seed operacional idempotente dos pacotes fisicos por dominio prioritario.
-- Gerado automaticamente por scripts/valley_module_automation.py.

WITH package_source (
    package_key,
    domain_key,
    domain_label,
    priority_rank,
    package_scope,
    module_codes,
    backlog_keys,
    package_status,
    artifact_manifest_json
) AS (
    VALUES
    ('platform_developer.priority.v1', 'platform_developer', 'Platform Developer', 1, 'priority_domains_v1', ARRAY['DOCS', 'TECH']::TEXT[], ARRAY['DOCS.exec.01', 'DOCS.exec.02', 'TECH.exec.01', 'TECH.exec.02', 'DOCS.exec.03', 'TECH.exec.03']::TEXT[], 'READY'::domain_delivery_package_status_enum, '{"artifacts":[{"artifact_key":"platform_developer.ddl.v1","artifact_path":"database/domain-delivery/priority-domains/platform_developer/ddl_complement.sql","layer_type":"DDL_COMPLEMENT","target_engine":"postgres"},{"artifact_key":"platform_developer.seed.v1","artifact_path":"database/domain-delivery/priority-domains/platform_developer/operational_seed.sql","layer_type":"OPERATIONS_SEED","target_engine":"postgres"},{"artifact_key":"platform_developer.contract.v1","artifact_path":"contracts/events/priority-domains/platform_developer.json","layer_type":"EVENT_CONTRACT","target_engine":"filesystem"}],"backlog_keys":["DOCS.exec.01","DOCS.exec.02","TECH.exec.01","TECH.exec.02","DOCS.exec.03","TECH.exec.03"],"domain_key":"platform_developer","domain_label":"Platform Developer","event_topics":["docs.receipt.generated","docs.document.signed","docs.hash.registered","tech.client.provisioned","tech.webhook.delivered","tech.connector.synced"],"modules":["DOCS","TECH"],"package_key":"platform_developer.priority.v1","priority_rank":1}'::JSONB)
)
INSERT INTO domain_delivery_packages (
    package_key,
    domain_key,
    domain_label,
    priority_rank,
    package_scope,
    module_codes,
    backlog_keys,
    package_status,
    artifact_manifest_json
)
SELECT
    package_key,
    domain_key,
    domain_label,
    priority_rank,
    package_scope,
    module_codes,
    backlog_keys,
    package_status,
    artifact_manifest_json
FROM package_source
ON CONFLICT (package_key) DO UPDATE SET
    domain_key = EXCLUDED.domain_key,
    domain_label = EXCLUDED.domain_label,
    priority_rank = EXCLUDED.priority_rank,
    package_scope = EXCLUDED.package_scope,
    module_codes = EXCLUDED.module_codes,
    backlog_keys = EXCLUDED.backlog_keys,
    package_status = EXCLUDED.package_status,
    artifact_manifest_json = EXCLUDED.artifact_manifest_json,
    updated_at = NOW();

WITH artifact_source (
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
    artifact_payload_json
) AS (
    VALUES
    ('platform_developer.ddl.v1', 'platform_developer.priority.v1', 'platform_developer', 'DDL_COMPLEMENT'::domain_delivery_layer_enum, 'postgres', 'database/domain-delivery/priority-domains/platform_developer/ddl_complement.sql', ARRAY['DOCS', 'TECH']::TEXT[], ARRAY['DOCS.exec.01', 'DOCS.exec.02', 'TECH.exec.01', 'TECH.exec.02', 'DOCS.exec.03', 'TECH.exec.03']::TEXT[], ARRAY[]::TEXT[], 'READY'::domain_delivery_package_status_enum, '{"package_key":"platform_developer.priority.v1","priority_rank":1,"views":["v_platform_developer_priority_backlog","v_platform_developer_delivery_artifacts","v_platform_developer_event_contracts"]}'::JSONB),
    ('platform_developer.seed.v1', 'platform_developer.priority.v1', 'platform_developer', 'OPERATIONS_SEED'::domain_delivery_layer_enum, 'postgres', 'database/domain-delivery/priority-domains/platform_developer/operational_seed.sql', ARRAY['DOCS', 'TECH']::TEXT[], ARRAY['DOCS.exec.01', 'DOCS.exec.02', 'TECH.exec.01', 'TECH.exec.02', 'DOCS.exec.03', 'TECH.exec.03']::TEXT[], ARRAY['platform_developer.ddl.v1']::TEXT[], 'READY'::domain_delivery_package_status_enum, '{"contract_count":6,"package_key":"platform_developer.priority.v1","seed_scope":"priority_domain_delivery_v1"}'::JSONB),
    ('platform_developer.contract.v1', 'platform_developer.priority.v1', 'platform_developer', 'EVENT_CONTRACT'::domain_delivery_layer_enum, 'filesystem', 'contracts/events/priority-domains/platform_developer.json', ARRAY['DOCS', 'TECH']::TEXT[], ARRAY['DOCS.exec.01', 'DOCS.exec.02', 'TECH.exec.01', 'TECH.exec.02', 'DOCS.exec.03', 'TECH.exec.03']::TEXT[], ARRAY['platform_developer.ddl.v1', 'platform_developer.seed.v1']::TEXT[], 'READY'::domain_delivery_package_status_enum, '{"event_topics":["docs.receipt.generated","docs.document.signed","docs.hash.registered","tech.client.provisioned","tech.webhook.delivered","tech.connector.synced"],"package_key":"platform_developer.priority.v1"}'::JSONB)
)
INSERT INTO domain_delivery_artifacts (
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
    artifact_payload_json
)
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
    artifact_payload_json
FROM artifact_source
ON CONFLICT (artifact_key) DO UPDATE SET
    package_key = EXCLUDED.package_key,
    domain_key = EXCLUDED.domain_key,
    layer_type = EXCLUDED.layer_type,
    target_engine = EXCLUDED.target_engine,
    artifact_path = EXCLUDED.artifact_path,
    module_codes = EXCLUDED.module_codes,
    backlog_keys = EXCLUDED.backlog_keys,
    depends_on_keys = EXCLUDED.depends_on_keys,
    artifact_status = EXCLUDED.artifact_status,
    artifact_payload_json = EXCLUDED.artifact_payload_json,
    updated_at = NOW();

WITH contract_source (
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
    contract_status,
    payload_schema_json,
    artifact_path
) AS (
    VALUES
    ('DOCS:docs.receipt.generated:v1', 'platform_developer.priority.v1', 'platform_developer', 'DOCS', 'docs.receipt.generated', '1.0.0', 'painel documental', ARRAY['ORDERS', 'TRANSACTIONS', 'painel documental', 'fila de emissao']::TEXT[], ARRAY['legal_contracts', 'transactions', 'orders']::TEXT[], ARRAY['document_immutability', 'signature_traceability', 'receipt_audit']::TEXT[], 'READY'::domain_delivery_package_status_enum, '{"$schema":"https://json-schema.org/draft/2020-12/schema","additionalProperties":false,"properties":{"aggregate_id":{"format":"uuid","type":"string"},"aggregate_type":{"type":"string"},"compliance_tags":{"default":["document_immutability","signature_traceability","receipt_audit"],"items":{"type":"string"},"type":"array"},"delivery_phase":{"const":"DATA_CONTRACT"},"domain_key":{"const":"platform_developer"},"event_id":{"format":"uuid","type":"string"},"event_topic":{"const":"docs.receipt.generated"},"evidence_refs":{"items":{"enum":["legal_contracts","transactions","orders"],"type":"string"},"minItems":1,"type":"array"},"module_code":{"const":"DOCS"},"occurred_at":{"format":"date-time","type":"string"},"payload":{"additionalProperties":true,"properties":{"capability":{"enum":["documentos","recibos","checksums e prova"],"type":"string"},"details":{"additionalProperties":true,"type":"object"},"primary_actor":{"enum":["operador documental","juridico","motor de recibos"],"type":"string"},"status":{"type":"string"}},"type":"object"},"trace_id":{"format":"uuid","type":"string"},"user_id":{"format":"uuid","type":"string"}},"required":["event_id","event_topic","module_code","domain_key","user_id","occurred_at","payload","evidence_refs"],"title":"DOCS::docs.receipt.generated","type":"object"}'::JSONB, 'contracts/events/priority-domains/platform_developer.json'),
    ('DOCS:docs.document.signed:v1', 'platform_developer.priority.v1', 'platform_developer', 'DOCS', 'docs.document.signed', '1.0.0', 'painel documental', ARRAY['ORDERS', 'TRANSACTIONS', 'painel documental', 'fila de emissao']::TEXT[], ARRAY['legal_contracts', 'transactions', 'orders']::TEXT[], ARRAY['document_immutability', 'signature_traceability', 'receipt_audit']::TEXT[], 'READY'::domain_delivery_package_status_enum, '{"$schema":"https://json-schema.org/draft/2020-12/schema","additionalProperties":false,"properties":{"aggregate_id":{"format":"uuid","type":"string"},"aggregate_type":{"type":"string"},"compliance_tags":{"default":["document_immutability","signature_traceability","receipt_audit"],"items":{"type":"string"},"type":"array"},"delivery_phase":{"const":"DATA_CONTRACT"},"domain_key":{"const":"platform_developer"},"event_id":{"format":"uuid","type":"string"},"event_topic":{"const":"docs.document.signed"},"evidence_refs":{"items":{"enum":["legal_contracts","transactions","orders"],"type":"string"},"minItems":1,"type":"array"},"module_code":{"const":"DOCS"},"occurred_at":{"format":"date-time","type":"string"},"payload":{"additionalProperties":true,"properties":{"capability":{"enum":["documentos","recibos","checksums e prova"],"type":"string"},"details":{"additionalProperties":true,"type":"object"},"primary_actor":{"enum":["operador documental","juridico","motor de recibos"],"type":"string"},"status":{"type":"string"}},"type":"object"},"trace_id":{"format":"uuid","type":"string"},"user_id":{"format":"uuid","type":"string"}},"required":["event_id","event_topic","module_code","domain_key","user_id","occurred_at","payload","evidence_refs"],"title":"DOCS::docs.document.signed","type":"object"}'::JSONB, 'contracts/events/priority-domains/platform_developer.json'),
    ('DOCS:docs.hash.registered:v1', 'platform_developer.priority.v1', 'platform_developer', 'DOCS', 'docs.hash.registered', '1.0.0', 'painel documental', ARRAY['ORDERS', 'TRANSACTIONS', 'painel documental', 'fila de emissao']::TEXT[], ARRAY['legal_contracts', 'transactions', 'orders']::TEXT[], ARRAY['document_immutability', 'signature_traceability', 'receipt_audit']::TEXT[], 'READY'::domain_delivery_package_status_enum, '{"$schema":"https://json-schema.org/draft/2020-12/schema","additionalProperties":false,"properties":{"aggregate_id":{"format":"uuid","type":"string"},"aggregate_type":{"type":"string"},"compliance_tags":{"default":["document_immutability","signature_traceability","receipt_audit"],"items":{"type":"string"},"type":"array"},"delivery_phase":{"const":"DATA_CONTRACT"},"domain_key":{"const":"platform_developer"},"event_id":{"format":"uuid","type":"string"},"event_topic":{"const":"docs.hash.registered"},"evidence_refs":{"items":{"enum":["legal_contracts","transactions","orders"],"type":"string"},"minItems":1,"type":"array"},"module_code":{"const":"DOCS"},"occurred_at":{"format":"date-time","type":"string"},"payload":{"additionalProperties":true,"properties":{"capability":{"enum":["documentos","recibos","checksums e prova"],"type":"string"},"details":{"additionalProperties":true,"type":"object"},"primary_actor":{"enum":["operador documental","juridico","motor de recibos"],"type":"string"},"status":{"type":"string"}},"type":"object"},"trace_id":{"format":"uuid","type":"string"},"user_id":{"format":"uuid","type":"string"}},"required":["event_id","event_topic","module_code","domain_key","user_id","occurred_at","payload","evidence_refs"],"title":"DOCS::docs.hash.registered","type":"object"}'::JSONB, 'contracts/events/priority-domains/platform_developer.json'),
    ('TECH:tech.client.provisioned:v1', 'platform_developer.priority.v1', 'platform_developer', 'TECH', 'tech.client.provisioned', '1.0.0', 'painel de integracoes', ARRAY['CONNECT', 'COMMAND_CENTER', 'painel de integracoes', 'gestao de credenciais']::TEXT[], ARRAY['tech_api_clients', 'tech_api_credentials', 'tech_webhook_subscriptions']::TEXT[], ARRAY['secret_hashing', 'api_audit', 'integration_traceability']::TEXT[], 'READY'::domain_delivery_package_status_enum, '{"$schema":"https://json-schema.org/draft/2020-12/schema","additionalProperties":false,"properties":{"aggregate_id":{"format":"uuid","type":"string"},"aggregate_type":{"type":"string"},"compliance_tags":{"default":["secret_hashing","api_audit","integration_traceability"],"items":{"type":"string"},"type":"array"},"delivery_phase":{"const":"VALIDATE"},"domain_key":{"const":"platform_developer"},"event_id":{"format":"uuid","type":"string"},"event_topic":{"const":"tech.client.provisioned"},"evidence_refs":{"items":{"enum":["tech_api_clients","tech_api_credentials","tech_webhook_subscriptions"],"type":"string"},"minItems":1,"type":"array"},"module_code":{"const":"TECH"},"occurred_at":{"format":"date-time","type":"string"},"payload":{"additionalProperties":true,"properties":{"capability":{"enum":["api clients","credenciais seguras","webhooks e conectores"],"type":"string"},"details":{"additionalProperties":true,"type":"object"},"primary_actor":{"enum":["developer","integrador","operador de plataforma"],"type":"string"},"status":{"type":"string"}},"type":"object"},"trace_id":{"format":"uuid","type":"string"},"user_id":{"format":"uuid","type":"string"}},"required":["event_id","event_topic","module_code","domain_key","user_id","occurred_at","payload","evidence_refs"],"title":"TECH::tech.client.provisioned","type":"object"}'::JSONB, 'contracts/events/priority-domains/platform_developer.json'),
    ('TECH:tech.webhook.delivered:v1', 'platform_developer.priority.v1', 'platform_developer', 'TECH', 'tech.webhook.delivered', '1.0.0', 'painel de integracoes', ARRAY['CONNECT', 'COMMAND_CENTER', 'painel de integracoes', 'gestao de credenciais']::TEXT[], ARRAY['tech_api_clients', 'tech_api_credentials', 'tech_webhook_subscriptions']::TEXT[], ARRAY['secret_hashing', 'api_audit', 'integration_traceability']::TEXT[], 'READY'::domain_delivery_package_status_enum, '{"$schema":"https://json-schema.org/draft/2020-12/schema","additionalProperties":false,"properties":{"aggregate_id":{"format":"uuid","type":"string"},"aggregate_type":{"type":"string"},"compliance_tags":{"default":["secret_hashing","api_audit","integration_traceability"],"items":{"type":"string"},"type":"array"},"delivery_phase":{"const":"VALIDATE"},"domain_key":{"const":"platform_developer"},"event_id":{"format":"uuid","type":"string"},"event_topic":{"const":"tech.webhook.delivered"},"evidence_refs":{"items":{"enum":["tech_api_clients","tech_api_credentials","tech_webhook_subscriptions"],"type":"string"},"minItems":1,"type":"array"},"module_code":{"const":"TECH"},"occurred_at":{"format":"date-time","type":"string"},"payload":{"additionalProperties":true,"properties":{"capability":{"enum":["api clients","credenciais seguras","webhooks e conectores"],"type":"string"},"details":{"additionalProperties":true,"type":"object"},"primary_actor":{"enum":["developer","integrador","operador de plataforma"],"type":"string"},"status":{"type":"string"}},"type":"object"},"trace_id":{"format":"uuid","type":"string"},"user_id":{"format":"uuid","type":"string"}},"required":["event_id","event_topic","module_code","domain_key","user_id","occurred_at","payload","evidence_refs"],"title":"TECH::tech.webhook.delivered","type":"object"}'::JSONB, 'contracts/events/priority-domains/platform_developer.json'),
    ('TECH:tech.connector.synced:v1', 'platform_developer.priority.v1', 'platform_developer', 'TECH', 'tech.connector.synced', '1.0.0', 'painel de integracoes', ARRAY['CONNECT', 'COMMAND_CENTER', 'painel de integracoes', 'gestao de credenciais']::TEXT[], ARRAY['tech_api_clients', 'tech_api_credentials', 'tech_webhook_subscriptions']::TEXT[], ARRAY['secret_hashing', 'api_audit', 'integration_traceability']::TEXT[], 'READY'::domain_delivery_package_status_enum, '{"$schema":"https://json-schema.org/draft/2020-12/schema","additionalProperties":false,"properties":{"aggregate_id":{"format":"uuid","type":"string"},"aggregate_type":{"type":"string"},"compliance_tags":{"default":["secret_hashing","api_audit","integration_traceability"],"items":{"type":"string"},"type":"array"},"delivery_phase":{"const":"VALIDATE"},"domain_key":{"const":"platform_developer"},"event_id":{"format":"uuid","type":"string"},"event_topic":{"const":"tech.connector.synced"},"evidence_refs":{"items":{"enum":["tech_api_clients","tech_api_credentials","tech_webhook_subscriptions"],"type":"string"},"minItems":1,"type":"array"},"module_code":{"const":"TECH"},"occurred_at":{"format":"date-time","type":"string"},"payload":{"additionalProperties":true,"properties":{"capability":{"enum":["api clients","credenciais seguras","webhooks e conectores"],"type":"string"},"details":{"additionalProperties":true,"type":"object"},"primary_actor":{"enum":["developer","integrador","operador de plataforma"],"type":"string"},"status":{"type":"string"}},"type":"object"},"trace_id":{"format":"uuid","type":"string"},"user_id":{"format":"uuid","type":"string"}},"required":["event_id","event_topic","module_code","domain_key","user_id","occurred_at","payload","evidence_refs"],"title":"TECH::tech.connector.synced","type":"object"}'::JSONB, 'contracts/events/priority-domains/platform_developer.json')
)
INSERT INTO domain_event_contracts (
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
    contract_status,
    payload_schema_json,
    artifact_path
)
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
    contract_status,
    payload_schema_json,
    artifact_path
FROM contract_source
ON CONFLICT (contract_key) DO UPDATE SET
    package_key = EXCLUDED.package_key,
    domain_key = EXCLUDED.domain_key,
    module_code = EXCLUDED.module_code,
    event_topic = EXCLUDED.event_topic,
    contract_version = EXCLUDED.contract_version,
    producer_surface = EXCLUDED.producer_surface,
    consumer_surfaces = EXCLUDED.consumer_surfaces,
    evidence_entities = EXCLUDED.evidence_entities,
    compliance_tags = EXCLUDED.compliance_tags,
    contract_status = EXCLUDED.contract_status,
    payload_schema_json = EXCLUDED.payload_schema_json,
    artifact_path = EXCLUDED.artifact_path,
    updated_at = NOW();

COMMIT;
