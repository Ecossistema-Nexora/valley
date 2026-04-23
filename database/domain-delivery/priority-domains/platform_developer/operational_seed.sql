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
    ('platform_developer.ddl.v1', 'platform_developer.priority.v1', 'platform_developer', 'DDL_COMPLEMENT'::domain_delivery_layer_enum, 'postgres', 'database/domain-delivery/priority-domains/platform_developer/ddl_complement.sql', ARRAY['DOCS', 'TECH']::TEXT[], ARRAY['DOCS.exec.01', 'DOCS.exec.02', 'TECH.exec.01', 'TECH.exec.02', 'DOCS.exec.03', 'TECH.exec.03']::TEXT[], ARRAY[]::TEXT[], 'READY'::domain_delivery_package_status_enum, '{"package_key":"platform_developer.priority.v1","priority_rank":1,"views":["v_platform_developer_docs_templates","v_platform_developer_checksum_chain","v_platform_developer_webhook_replay_queue"]}'::JSONB),
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

-- Enriquecimento manual: seed operacional real do dominio platform_developer.
SET LOCAL search_path = public;

INSERT INTO users (
    user_id,
    user_kind,
    account_status,
    kyc_status,
    full_name,
    display_name,
    email,
    phone_e164,
    document_country,
    document_type,
    document_number,
    nationality,
    tax_residence_country,
    risk_level,
    primary_role,
    nexus_external_ref,
    terms_accepted_at,
    privacy_accepted_at,
    module_tier,
    ops_region_code,
    compliance_notes,
    internal_tags,
    created_at,
    updated_at
) VALUES
    (
        '10000000-0000-4000-8000-000000000101',
        'ADMIN'::user_kind_enum,
        'ACTIVE'::account_status_enum,
        'APPROVED'::kyc_status_enum,
        'Nexora Platform Ops',
        'Platform Ops',
        'platform.ops@nexora.local',
        '+5511999000101',
        'BR',
        'CNPJ',
        '45.301.990/0001-01',
        'BR',
        'BR',
        1,
        'PLATFORM_ADMIN',
        'seed-platform-owner',
        TIMESTAMPTZ '2026-04-21 08:00:00+00',
        TIMESTAMPTZ '2026-04-21 08:02:00+00',
        'ENTERPRISE',
        'BR-SP',
        'Seed operacional do dominio platform_developer.',
        ARRAY['seed','platform_developer','priority_1']::TEXT[],
        TIMESTAMPTZ '2026-04-21 08:00:00+00',
        TIMESTAMPTZ '2026-04-21 08:00:00+00'
    ),
    (
        '10000000-0000-4000-8000-000000000102',
        'PJ'::user_kind_enum,
        'ACTIVE'::account_status_enum,
        'APPROVED'::kyc_status_enum,
        'Partner Compliance Ltda',
        'Partner Compliance',
        'partner.compliance@nexora.local',
        '+5511999000102',
        'BR',
        'CNPJ',
        '18.221.450/0001-88',
        'BR',
        'BR',
        1,
        'LEGAL_COUNTERPARTY',
        'seed-platform-counterparty',
        TIMESTAMPTZ '2026-04-21 08:00:00+00',
        TIMESTAMPTZ '2026-04-21 08:02:00+00',
        'ENTERPRISE',
        'BR-SP',
        'Contraparte juridica para contratos e recibos.',
        ARRAY['seed','platform_developer','docs']::TEXT[],
        TIMESTAMPTZ '2026-04-21 08:00:00+00',
        TIMESTAMPTZ '2026-04-21 08:00:00+00'
    ),
    (
        '10000000-0000-4000-8000-000000000103',
        'PF'::user_kind_enum,
        'ACTIVE'::account_status_enum,
        'APPROVED'::kyc_status_enum,
        'Marina Integracoes',
        'Marina Integracoes',
        'marina.integracoes@nexora.local',
        '+5511999000103',
        'BR',
        'CPF',
        '323.445.667-10',
        'BR',
        'BR',
        1,
        'DEVELOPER',
        'seed-platform-integrator',
        TIMESTAMPTZ '2026-04-21 08:00:00+00',
        TIMESTAMPTZ '2026-04-21 08:02:00+00',
        'PRO',
        'BR-SP',
        'Integradora responsavel por credenciais e replay de webhook.',
        ARRAY['seed','platform_developer','tech']::TEXT[],
        TIMESTAMPTZ '2026-04-21 08:00:00+00',
        TIMESTAMPTZ '2026-04-21 08:00:00+00'
    )
ON CONFLICT (user_id) DO UPDATE SET
    user_kind = EXCLUDED.user_kind,
    account_status = EXCLUDED.account_status,
    kyc_status = EXCLUDED.kyc_status,
    full_name = EXCLUDED.full_name,
    display_name = EXCLUDED.display_name,
    email = EXCLUDED.email,
    phone_e164 = EXCLUDED.phone_e164,
    document_country = EXCLUDED.document_country,
    document_type = EXCLUDED.document_type,
    document_number = EXCLUDED.document_number,
    nationality = EXCLUDED.nationality,
    tax_residence_country = EXCLUDED.tax_residence_country,
    risk_level = EXCLUDED.risk_level,
    primary_role = EXCLUDED.primary_role,
    nexus_external_ref = EXCLUDED.nexus_external_ref,
    terms_accepted_at = EXCLUDED.terms_accepted_at,
    privacy_accepted_at = EXCLUDED.privacy_accepted_at,
    module_tier = EXCLUDED.module_tier,
    ops_region_code = EXCLUDED.ops_region_code,
    compliance_notes = EXCLUDED.compliance_notes,
    internal_tags = EXCLUDED.internal_tags,
    updated_at = EXCLUDED.updated_at;

INSERT INTO wallets (
    wallet_id,
    user_id,
    wallet_type,
    asset_code,
    wallet_status,
    balance_available_brl,
    balance_blocked_brl,
    balance_pending_brl,
    balance_available_nex,
    balance_blocked_nex,
    balance_pending_nex,
    daily_limit_brl,
    monthly_limit_brl,
    ledger_version,
    last_reconciled_at,
    created_at,
    updated_at
) VALUES
    (
        '20000000-0000-4000-8000-000000000101',
        '10000000-0000-4000-8000-000000000101',
        'CUSTODIAL'::wallet_type_enum,
        'BRL'::wallet_asset_enum,
        'ACTIVE'::wallet_status_enum,
        5000.0000,
        0.0000,
        0.0000,
        0.00000000,
        0.00000000,
        0.00000000,
        15000.0000,
        300000.0000,
        3,
        TIMESTAMPTZ '2026-04-21 08:00:00+00',
        TIMESTAMPTZ '2026-04-21 08:00:00+00',
        TIMESTAMPTZ '2026-04-21 08:00:00+00'
    ),
    (
        '20000000-0000-4000-8000-000000000102',
        '10000000-0000-4000-8000-000000000102',
        'CUSTODIAL'::wallet_type_enum,
        'BRL'::wallet_asset_enum,
        'ACTIVE'::wallet_status_enum,
        0.0000,
        0.0000,
        0.0000,
        0.00000000,
        0.00000000,
        0.00000000,
        0.0000,
        0.0000,
        1,
        TIMESTAMPTZ '2026-04-21 08:00:00+00',
        TIMESTAMPTZ '2026-04-21 08:00:00+00',
        TIMESTAMPTZ '2026-04-21 08:00:00+00'
    )
ON CONFLICT (wallet_id) DO UPDATE SET
    user_id = EXCLUDED.user_id,
    wallet_type = EXCLUDED.wallet_type,
    asset_code = EXCLUDED.asset_code,
    wallet_status = EXCLUDED.wallet_status,
    balance_available_brl = EXCLUDED.balance_available_brl,
    balance_blocked_brl = EXCLUDED.balance_blocked_brl,
    balance_pending_brl = EXCLUDED.balance_pending_brl,
    balance_available_nex = EXCLUDED.balance_available_nex,
    balance_blocked_nex = EXCLUDED.balance_blocked_nex,
    balance_pending_nex = EXCLUDED.balance_pending_nex,
    daily_limit_brl = EXCLUDED.daily_limit_brl,
    monthly_limit_brl = EXCLUDED.monthly_limit_brl,
    ledger_version = EXCLUDED.ledger_version,
    last_reconciled_at = EXCLUDED.last_reconciled_at,
    updated_at = EXCLUDED.updated_at;

INSERT INTO transactions (
    transaction_id,
    user_id,
    wallet_id,
    counterparty_user_id,
    counterparty_wallet_id,
    transaction_type,
    transaction_status,
    order_id,
    asset_code,
    amount_brl,
    amount_nex,
    fee_amount_brl,
    platform_amount_brl,
    merchant_amount_brl,
    affiliate_amount_brl,
    escrow_amount_brl,
    fx_rate,
    reference_code,
    external_reference,
    channel,
    origin_module,
    description,
    metadata_json,
    authorized_at,
    settled_at,
    failed_at,
    created_at
) VALUES (
    '30000000-0000-4000-8000-000000000301',
    '10000000-0000-4000-8000-000000000101',
    '20000000-0000-4000-8000-000000000101',
    '10000000-0000-4000-8000-000000000102',
    '20000000-0000-4000-8000-000000000102',
    'PAYMENT'::transaction_type_enum,
    'SETTLED'::transaction_status_enum,
    NULL,
    'BRL'::wallet_asset_enum,
    249.9000,
    0.00000000,
    0.0000,
    0.0000,
    249.9000,
    0.0000,
    0.0000,
    NULL,
    'TX-PLATFORM-DOCS-001',
    'platform-docs-001',
    'platform_console',
    'DOCS',
    'Liquidacao seed do pacote documental do dominio platform_developer.',
    '{"domain":"platform_developer","flow":"docs_receipt"}'::JSONB,
    TIMESTAMPTZ '2026-04-21 08:05:00+00',
    TIMESTAMPTZ '2026-04-21 08:07:00+00',
    NULL,
    TIMESTAMPTZ '2026-04-21 08:05:00+00'
) ON CONFLICT (transaction_id) DO NOTHING;

INSERT INTO document_records (
    document_id,
    user_id,
    module_code,
    order_id,
    transaction_id,
    file_url,
    checksum_sha256,
    event_reference,
    created_at
) VALUES (
    '30000000-0000-4000-8000-000000000302',
    '10000000-0000-4000-8000-000000000101',
    NULL,
    NULL,
    '30000000-0000-4000-8000-000000000301',
    'https://files.nexora.local/docs/platform/receipt-template-v1.pdf',
    '1111111111111111111111111111111111111111111111111111111111111111',
    NULL,
    TIMESTAMPTZ '2026-04-21 08:08:00+00'
) ON CONFLICT (document_id) DO NOTHING;

INSERT INTO legal_contracts (
    legal_contract_id,
    owner_user_id,
    counterparty_user_id,
    module_code,
    document_id,
    contract_status,
    contract_type,
    title,
    jurisdiction_country,
    terms_hash_sha256,
    contract_uri,
    effective_at,
    expires_at,
    metadata_json,
    created_at,
    updated_at
) VALUES (
    '30000000-0000-4000-8000-000000000303',
    '10000000-0000-4000-8000-000000000101',
    '10000000-0000-4000-8000-000000000102',
    'LEGAL',
    '30000000-0000-4000-8000-000000000302',
    'ACTIVE'::legal_contract_status_enum,
    'DOCS_TEMPLATE_MASTER',
    'Contrato mestre de templates e recibos do Valley Docs',
    'BR',
    '2222222222222222222222222222222222222222222222222222222222222222',
    'https://contracts.nexora.local/legal/platform/docs-template-master',
    TIMESTAMPTZ '2026-04-21 08:10:00+00',
    TIMESTAMPTZ '2027-04-21 08:10:00+00',
    '{"domain":"platform_developer","coverage":["DOCS","TECH"]}'::JSONB,
    TIMESTAMPTZ '2026-04-21 08:10:00+00',
    TIMESTAMPTZ '2026-04-21 08:10:00+00'
) ON CONFLICT (legal_contract_id) DO NOTHING;

INSERT INTO docs_receipts (
    receipt_id,
    user_id,
    order_id,
    transaction_id,
    document_id,
    file_url,
    created_at
) VALUES (
    '30000000-0000-4000-8000-000000000304',
    '10000000-0000-4000-8000-000000000101',
    NULL,
    '30000000-0000-4000-8000-000000000301',
    '30000000-0000-4000-8000-000000000302',
    'https://files.nexora.local/docs/platform/receipt-001.pdf',
    TIMESTAMPTZ '2026-04-21 08:12:00+00'
) ON CONFLICT (receipt_id) DO NOTHING;

INSERT INTO docs_template_contracts (
    template_contract_id,
    owner_user_id,
    module_code,
    template_name,
    template_scope,
    template_status,
    source_legal_contract_id,
    render_engine,
    checksum_policy_json,
    variable_schema_json,
    published_version_number,
    created_at,
    updated_at
) VALUES (
    '30000000-0000-4000-8000-000000000305',
    '10000000-0000-4000-8000-000000000101',
    'DOCS',
    'receipt_transaction_v1',
    'TRANSACTION'::docs_template_scope_enum,
    'ACTIVE'::docs_template_status_enum,
    '30000000-0000-4000-8000-000000000303',
    'liquid',
    '{"algorithm":"sha256","receipt_required":true}'::JSONB,
    '{"type":"object","required":["transaction_id","counterparty_name","amount_brl"]}'::JSONB,
    1,
    TIMESTAMPTZ '2026-04-21 08:15:00+00',
    TIMESTAMPTZ '2026-04-21 08:15:00+00'
) ON CONFLICT (template_contract_id) DO NOTHING;

INSERT INTO docs_template_versions (
    template_version_id,
    template_contract_id,
    owner_user_id,
    template_document_id,
    version_number,
    version_status,
    checksum_sha256,
    render_schema_json,
    published_by_user_id,
    published_at,
    supersedes_template_version_id,
    created_at
) VALUES (
    '30000000-0000-4000-8000-000000000306',
    '30000000-0000-4000-8000-000000000305',
    '10000000-0000-4000-8000-000000000101',
    '30000000-0000-4000-8000-000000000302',
    1,
    'PUBLISHED'::docs_template_version_status_enum,
    '3333333333333333333333333333333333333333333333333333333333333333',
    '{"layout":"receipt","engine":"liquid","version":"1.0.0"}'::JSONB,
    '10000000-0000-4000-8000-000000000103',
    TIMESTAMPTZ '2026-04-21 08:17:00+00',
    NULL,
    TIMESTAMPTZ '2026-04-21 08:16:00+00'
) ON CONFLICT (template_version_id) DO NOTHING;

INSERT INTO docs_document_checksum_events (
    checksum_event_id,
    document_id,
    owner_user_id,
    module_code,
    checksum_event_type,
    checksum_sha256,
    previous_checksum_event_id,
    receipt_id,
    template_version_id,
    reference_event_topic,
    notes,
    occurred_at,
    created_at
) VALUES (
    '30000000-0000-4000-8000-000000000307',
    '30000000-0000-4000-8000-000000000302',
    '10000000-0000-4000-8000-000000000101',
    'DOCS',
    'REGISTERED'::docs_checksum_event_type_enum,
    '1111111111111111111111111111111111111111111111111111111111111111',
    NULL,
    '30000000-0000-4000-8000-000000000304',
    '30000000-0000-4000-8000-000000000306',
    'docs.hash.registered',
    'Hash inicial publicado junto do recibo operacional.',
    TIMESTAMPTZ '2026-04-21 08:18:00+00',
    TIMESTAMPTZ '2026-04-21 08:18:00+00'
) ON CONFLICT (checksum_event_id) DO NOTHING;

INSERT INTO docs_receipt_versions (
    receipt_version_id,
    receipt_id,
    owner_user_id,
    version_number,
    version_status,
    document_id,
    checksum_event_id,
    template_version_id,
    file_url,
    render_context_json,
    supersedes_receipt_version_id,
    published_at,
    created_at
) VALUES (
    '30000000-0000-4000-8000-000000000308',
    '30000000-0000-4000-8000-000000000304',
    '10000000-0000-4000-8000-000000000101',
    1,
    'PUBLISHED'::docs_receipt_version_status_enum,
    '30000000-0000-4000-8000-000000000302',
    '30000000-0000-4000-8000-000000000307',
    '30000000-0000-4000-8000-000000000306',
    'https://files.nexora.local/docs/platform/receipt-001-v1.pdf',
    '{"transaction_id":"30000000-0000-4000-8000-000000000301","template":"receipt_transaction_v1"}'::JSONB,
    NULL,
    TIMESTAMPTZ '2026-04-21 08:19:00+00',
    TIMESTAMPTZ '2026-04-21 08:19:00+00'
) ON CONFLICT (receipt_version_id) DO NOTHING;

INSERT INTO tech_api_clients (
    api_client_id,
    owner_user_id,
    module_code,
    client_name,
    client_status,
    allowed_modules,
    redirect_uris,
    rate_limit_per_minute,
    metadata_json,
    created_at,
    updated_at
) VALUES (
    '30000000-0000-4000-8000-000000000309',
    '10000000-0000-4000-8000-000000000101',
    'TECH',
    'docs-integrator-sandbox',
    'ACTIVE'::tech_api_client_status_enum,
    ARRAY['DOCS','TECH']::TEXT[],
    ARRAY['https://sandbox.platform.nexora.app/callback']::TEXT[],
    1200,
    '{"environment":"sandbox","domain":"platform_developer"}'::JSONB,
    TIMESTAMPTZ '2026-04-21 08:20:00+00',
    TIMESTAMPTZ '2026-04-21 08:20:00+00'
) ON CONFLICT (api_client_id) DO NOTHING;

INSERT INTO tech_api_credentials (
    api_credential_id,
    api_client_id,
    owner_user_id,
    credential_status,
    key_prefix,
    key_hash_sha256,
    scopes,
    expires_at,
    last_used_at,
    rotated_from_credential_id,
    created_at,
    updated_at
) VALUES
    (
        '30000000-0000-4000-8000-000000000310',
        '30000000-0000-4000-8000-000000000309',
        '10000000-0000-4000-8000-000000000101',
        'ROTATED'::tech_credential_status_enum,
        'nexp_old1',
        '4444444444444444444444444444444444444444444444444444444444444444',
        ARRAY['docs.read','docs.write','tech.webhooks']::TEXT[],
        TIMESTAMPTZ '2026-07-01 00:00:00+00',
        TIMESTAMPTZ '2026-04-21 08:24:00+00',
        NULL,
        TIMESTAMPTZ '2026-04-21 08:21:00+00',
        TIMESTAMPTZ '2026-04-21 08:25:00+00'
    ),
    (
        '30000000-0000-4000-8000-000000000311',
        '30000000-0000-4000-8000-000000000309',
        '10000000-0000-4000-8000-000000000101',
        'ACTIVE'::tech_credential_status_enum,
        'nexp_new1',
        '5555555555555555555555555555555555555555555555555555555555555555',
        ARRAY['docs.read','docs.write','tech.webhooks']::TEXT[],
        TIMESTAMPTZ '2026-10-01 00:00:00+00',
        TIMESTAMPTZ '2026-04-21 08:35:00+00',
        '30000000-0000-4000-8000-000000000310',
        TIMESTAMPTZ '2026-04-21 08:26:00+00',
        TIMESTAMPTZ '2026-04-21 08:26:00+00'
    )
ON CONFLICT (api_credential_id) DO NOTHING;

INSERT INTO tech_client_module_limits (
    api_client_limit_id,
    api_client_id,
    owner_user_id,
    module_code,
    limit_scope,
    limit_window,
    endpoint_pattern,
    event_topic,
    limit_status,
    hard_limit_count,
    burst_limit_count,
    cooldown_seconds,
    effective_from,
    effective_until,
    metadata_json,
    created_at,
    updated_at
) VALUES (
    '30000000-0000-4000-8000-000000000312',
    '30000000-0000-4000-8000-000000000309',
    '10000000-0000-4000-8000-000000000101',
    'DOCS',
    'MODULE'::tech_limit_scope_enum,
    'MINUTE'::tech_limit_window_enum,
    NULL,
    NULL,
    'ACTIVE'::tech_limit_status_enum,
    900,
    120,
    30,
    TIMESTAMPTZ '2026-04-21 08:20:00+00',
    NULL,
    '{"throttle_profile":"docs_high_trust"}'::JSONB,
    TIMESTAMPTZ '2026-04-21 08:20:00+00',
    TIMESTAMPTZ '2026-04-21 08:20:00+00'
) ON CONFLICT (api_client_limit_id) DO NOTHING;

INSERT INTO tech_webhook_subscriptions (
    webhook_subscription_id,
    owner_user_id,
    api_client_id,
    connector_id,
    module_code,
    subscription_status,
    target_url,
    event_types,
    signing_secret_hash_sha256,
    retry_policy_json,
    last_delivery_at,
    created_at,
    updated_at
) VALUES (
    '30000000-0000-4000-8000-000000000313',
    '10000000-0000-4000-8000-000000000101',
    '30000000-0000-4000-8000-000000000309',
    NULL,
    'TECH',
    'ACTIVE'::webhook_subscription_status_enum,
    'https://hooks.partner-nexora.app/events',
    ARRAY['docs.receipt.generated','tech.webhook.delivered']::TEXT[],
    '6666666666666666666666666666666666666666666666666666666666666666',
    '{"max_retries":3,"backoff_seconds":[30,120,300]}'::JSONB,
    TIMESTAMPTZ '2026-04-21 08:33:00+00',
    TIMESTAMPTZ '2026-04-21 08:22:00+00',
    TIMESTAMPTZ '2026-04-21 08:33:00+00'
) ON CONFLICT (webhook_subscription_id) DO NOTHING;

INSERT INTO tech_webhook_delivery_attempts (
    webhook_delivery_attempt_id,
    webhook_subscription_id,
    owner_user_id,
    event_type,
    payload_hash_sha256,
    delivery_status,
    response_status_code,
    duration_ms,
    error_message,
    attempted_at,
    created_at
) VALUES
    (
        '30000000-0000-4000-8000-000000000314',
        '30000000-0000-4000-8000-000000000313',
        '10000000-0000-4000-8000-000000000101',
        'docs.receipt.generated',
        '7777777777777777777777777777777777777777777777777777777777777777',
        'FAILED'::webhook_delivery_status_enum,
        500,
        1840,
        'upstream timeout',
        TIMESTAMPTZ '2026-04-21 08:30:00+00',
        TIMESTAMPTZ '2026-04-21 08:30:00+00'
    ),
    (
        '30000000-0000-4000-8000-000000000315',
        '30000000-0000-4000-8000-000000000313',
        '10000000-0000-4000-8000-000000000101',
        'docs.receipt.generated',
        '7777777777777777777777777777777777777777777777777777777777777777',
        'SUCCESS'::webhook_delivery_status_enum,
        202,
        420,
        NULL,
        TIMESTAMPTZ '2026-04-21 08:33:00+00',
        TIMESTAMPTZ '2026-04-21 08:33:00+00'
    )
ON CONFLICT (webhook_delivery_attempt_id) DO NOTHING;

INSERT INTO tech_credential_rotation_events (
    credential_rotation_event_id,
    api_client_id,
    owner_user_id,
    previous_credential_id,
    new_credential_id,
    rotation_reason,
    approved_by_user_id,
    rotation_notes,
    rotation_window_started_at,
    rotation_window_closed_at,
    compromised_detected_at,
    created_at
) VALUES (
    '30000000-0000-4000-8000-000000000316',
    '30000000-0000-4000-8000-000000000309',
    '10000000-0000-4000-8000-000000000101',
    '30000000-0000-4000-8000-000000000310',
    '30000000-0000-4000-8000-000000000311',
    'SCHEDULED'::tech_rotation_reason_enum,
    '10000000-0000-4000-8000-000000000103',
    'Rotacao preventiva apos onboarding do parceiro.',
    TIMESTAMPTZ '2026-04-21 08:24:00+00',
    TIMESTAMPTZ '2026-04-21 08:26:00+00',
    NULL,
    TIMESTAMPTZ '2026-04-21 08:26:00+00'
) ON CONFLICT (credential_rotation_event_id) DO NOTHING;

INSERT INTO tech_webhook_replay_requests (
    webhook_replay_request_id,
    webhook_subscription_id,
    original_delivery_attempt_id,
    owner_user_id,
    requested_by_user_id,
    approved_by_user_id,
    replay_delivery_attempt_id,
    replay_status,
    idempotency_key,
    replay_reason,
    payload_hash_sha256,
    requested_at,
    approved_at,
    replayed_at,
    failed_at,
    status_notes,
    metadata_json,
    created_at,
    updated_at
) VALUES (
    '30000000-0000-4000-8000-000000000317',
    '30000000-0000-4000-8000-000000000313',
    '30000000-0000-4000-8000-000000000314',
    '10000000-0000-4000-8000-000000000101',
    '10000000-0000-4000-8000-000000000103',
    '10000000-0000-4000-8000-000000000101',
    '30000000-0000-4000-8000-000000000315',
    'REPLAYED'::tech_webhook_replay_status_enum,
    'replay:platform:20260421:001',
    'Reprocessamento apos timeout do endpoint externo.',
    '7777777777777777777777777777777777777777777777777777777777777777',
    TIMESTAMPTZ '2026-04-21 08:31:00+00',
    TIMESTAMPTZ '2026-04-21 08:32:00+00',
    TIMESTAMPTZ '2026-04-21 08:33:00+00',
    NULL,
    'Replay concluido com ACK 202.',
    '{"replayed_by":"orchestrator","domain":"platform_developer"}'::JSONB,
    TIMESTAMPTZ '2026-04-21 08:31:00+00',
    TIMESTAMPTZ '2026-04-21 08:33:00+00'
) ON CONFLICT (webhook_replay_request_id) DO NOTHING;

COMMIT;
