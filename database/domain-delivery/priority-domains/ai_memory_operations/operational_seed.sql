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
    ('ai_memory_operations.priority.v1', 'ai_memory_operations', 'AI Memory Operations', 2, 'priority_domains_v1', ARRAY['ADVISOR', 'AGENDA', 'CHAT']::TEXT[], ARRAY['ADVISOR.exec.01', 'ADVISOR.exec.02', 'AGENDA.exec.01', 'AGENDA.exec.02', 'ADVISOR.exec.03', 'CHAT.exec.01', 'CHAT.exec.02', 'AGENDA.exec.03', 'CHAT.exec.03']::TEXT[], 'READY'::domain_delivery_package_status_enum, '{"artifacts":[{"artifact_key":"ai_memory_operations.ddl.v1","artifact_path":"database/domain-delivery/priority-domains/ai_memory_operations/ddl_complement.sql","layer_type":"DDL_COMPLEMENT","target_engine":"postgres"},{"artifact_key":"ai_memory_operations.seed.v1","artifact_path":"database/domain-delivery/priority-domains/ai_memory_operations/operational_seed.sql","layer_type":"OPERATIONS_SEED","target_engine":"postgres"},{"artifact_key":"ai_memory_operations.contract.v1","artifact_path":"contracts/events/priority-domains/ai_memory_operations.json","layer_type":"EVENT_CONTRACT","target_engine":"filesystem"}],"backlog_keys":["ADVISOR.exec.01","ADVISOR.exec.02","AGENDA.exec.01","AGENDA.exec.02","ADVISOR.exec.03","CHAT.exec.01","CHAT.exec.02","AGENDA.exec.03","CHAT.exec.03"],"domain_key":"ai_memory_operations","domain_label":"AI Memory Operations","event_topics":["advisor.insight.generated","advisor.action.proposed","advisor.consent.recorded","agenda.item.created","agenda.reminder.triggered","agenda.memory.linked","chat.conversation.opened","chat.message.persisted","chat.context.promoted"],"modules":["ADVISOR","AGENDA","CHAT"],"package_key":"ai_memory_operations.priority.v1","priority_rank":2}'::JSONB)
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
    ('ai_memory_operations.ddl.v1', 'ai_memory_operations.priority.v1', 'ai_memory_operations', 'DDL_COMPLEMENT'::domain_delivery_layer_enum, 'postgres', 'database/domain-delivery/priority-domains/ai_memory_operations/ddl_complement.sql', ARRAY['ADVISOR', 'AGENDA', 'CHAT']::TEXT[], ARRAY['ADVISOR.exec.01', 'ADVISOR.exec.02', 'AGENDA.exec.01', 'AGENDA.exec.02', 'ADVISOR.exec.03', 'CHAT.exec.01', 'CHAT.exec.02', 'AGENDA.exec.03', 'CHAT.exec.03']::TEXT[], ARRAY[]::TEXT[], 'READY'::domain_delivery_package_status_enum, '{"package_key":"ai_memory_operations.priority.v1","priority_rank":2,"views":["v_ai_memory_operations_advisor_ops","v_ai_memory_operations_chat_ops","v_ai_memory_operations_consent_queue","v_ai_memory_operations_user_context_ops"]}'::JSONB),
    ('ai_memory_operations.seed.v1', 'ai_memory_operations.priority.v1', 'ai_memory_operations', 'OPERATIONS_SEED'::domain_delivery_layer_enum, 'postgres', 'database/domain-delivery/priority-domains/ai_memory_operations/operational_seed.sql', ARRAY['ADVISOR', 'AGENDA', 'CHAT']::TEXT[], ARRAY['ADVISOR.exec.01', 'ADVISOR.exec.02', 'AGENDA.exec.01', 'AGENDA.exec.02', 'ADVISOR.exec.03', 'CHAT.exec.01', 'CHAT.exec.02', 'AGENDA.exec.03', 'CHAT.exec.03']::TEXT[], ARRAY['ai_memory_operations.ddl.v1']::TEXT[], 'READY'::domain_delivery_package_status_enum, '{"contract_count":9,"package_key":"ai_memory_operations.priority.v1","seed_scope":"priority_domain_delivery_v1"}'::JSONB),
    ('ai_memory_operations.contract.v1', 'ai_memory_operations.priority.v1', 'ai_memory_operations', 'EVENT_CONTRACT'::domain_delivery_layer_enum, 'filesystem', 'contracts/events/priority-domains/ai_memory_operations.json', ARRAY['ADVISOR', 'AGENDA', 'CHAT']::TEXT[], ARRAY['ADVISOR.exec.01', 'ADVISOR.exec.02', 'AGENDA.exec.01', 'AGENDA.exec.02', 'ADVISOR.exec.03', 'CHAT.exec.01', 'CHAT.exec.02', 'AGENDA.exec.03', 'CHAT.exec.03']::TEXT[], ARRAY['ai_memory_operations.ddl.v1', 'ai_memory_operations.seed.v1']::TEXT[], 'READY'::domain_delivery_package_status_enum, '{"event_topics":["advisor.insight.generated","advisor.action.proposed","advisor.consent.recorded","agenda.item.created","agenda.reminder.triggered","agenda.memory.linked","chat.conversation.opened","chat.message.persisted","chat.context.promoted"],"package_key":"ai_memory_operations.priority.v1"}'::JSONB)
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
    ('ADVISOR:advisor.insight.generated:v1', 'ai_memory_operations.priority.v1', 'ai_memory_operations', 'ADVISOR', 'advisor.insight.generated', '1.0.0', 'painel consultivo', ARRAY['FINANCAS', 'HEALTH', 'MOBILITY', 'painel consultivo', 'fila de aprovacoes']::TEXT[], ARRAY['advisor_insights', 'financial_goals', 'ai_memory', 'agenda_items']::TEXT[], ARRAY['consent_management', 'ai_auditability', 'cross_module_traceability']::TEXT[], 'READY'::domain_delivery_package_status_enum, '{"$schema":"https://json-schema.org/draft/2020-12/schema","additionalProperties":false,"properties":{"aggregate_id":{"format":"uuid","type":"string"},"aggregate_type":{"type":"string"},"compliance_tags":{"default":["consent_management","ai_auditability","cross_module_traceability"],"items":{"type":"string"},"type":"array"},"delivery_phase":{"const":"BUILD"},"domain_key":{"const":"ai_memory_operations"},"event_id":{"format":"uuid","type":"string"},"event_topic":{"const":"advisor.insight.generated"},"evidence_refs":{"items":{"enum":["advisor_insights","financial_goals","ai_memory","agenda_items"],"type":"string"},"minItems":1,"type":"array"},"module_code":{"const":"ADVISOR"},"occurred_at":{"format":"date-time","type":"string"},"payload":{"additionalProperties":true,"properties":{"capability":{"enum":["insights","recomendacao com consentimento","orquestracao entre modulos"],"type":"string"},"details":{"additionalProperties":true,"type":"object"},"primary_actor":{"enum":["usuario assistido","motor de IA","operador consultivo"],"type":"string"},"status":{"type":"string"}},"type":"object"},"trace_id":{"format":"uuid","type":"string"},"user_id":{"format":"uuid","type":"string"}},"required":["event_id","event_topic","module_code","domain_key","user_id","occurred_at","payload","evidence_refs"],"title":"ADVISOR::advisor.insight.generated","type":"object"}'::JSONB, 'contracts/events/priority-domains/ai_memory_operations.json'),
    ('ADVISOR:advisor.action.proposed:v1', 'ai_memory_operations.priority.v1', 'ai_memory_operations', 'ADVISOR', 'advisor.action.proposed', '1.0.0', 'painel consultivo', ARRAY['FINANCAS', 'HEALTH', 'MOBILITY', 'painel consultivo', 'fila de aprovacoes']::TEXT[], ARRAY['advisor_insights', 'financial_goals', 'ai_memory', 'agenda_items']::TEXT[], ARRAY['consent_management', 'ai_auditability', 'cross_module_traceability']::TEXT[], 'READY'::domain_delivery_package_status_enum, '{"$schema":"https://json-schema.org/draft/2020-12/schema","additionalProperties":false,"properties":{"aggregate_id":{"format":"uuid","type":"string"},"aggregate_type":{"type":"string"},"compliance_tags":{"default":["consent_management","ai_auditability","cross_module_traceability"],"items":{"type":"string"},"type":"array"},"delivery_phase":{"const":"BUILD"},"domain_key":{"const":"ai_memory_operations"},"event_id":{"format":"uuid","type":"string"},"event_topic":{"const":"advisor.action.proposed"},"evidence_refs":{"items":{"enum":["advisor_insights","financial_goals","ai_memory","agenda_items"],"type":"string"},"minItems":1,"type":"array"},"module_code":{"const":"ADVISOR"},"occurred_at":{"format":"date-time","type":"string"},"payload":{"additionalProperties":true,"properties":{"capability":{"enum":["insights","recomendacao com consentimento","orquestracao entre modulos"],"type":"string"},"details":{"additionalProperties":true,"type":"object"},"primary_actor":{"enum":["usuario assistido","motor de IA","operador consultivo"],"type":"string"},"status":{"type":"string"}},"type":"object"},"trace_id":{"format":"uuid","type":"string"},"user_id":{"format":"uuid","type":"string"}},"required":["event_id","event_topic","module_code","domain_key","user_id","occurred_at","payload","evidence_refs"],"title":"ADVISOR::advisor.action.proposed","type":"object"}'::JSONB, 'contracts/events/priority-domains/ai_memory_operations.json'),
    ('ADVISOR:advisor.consent.recorded:v1', 'ai_memory_operations.priority.v1', 'ai_memory_operations', 'ADVISOR', 'advisor.consent.recorded', '1.0.0', 'painel consultivo', ARRAY['FINANCAS', 'HEALTH', 'MOBILITY', 'painel consultivo', 'fila de aprovacoes']::TEXT[], ARRAY['advisor_insights', 'financial_goals', 'ai_memory', 'agenda_items']::TEXT[], ARRAY['consent_management', 'ai_auditability', 'cross_module_traceability']::TEXT[], 'READY'::domain_delivery_package_status_enum, '{"$schema":"https://json-schema.org/draft/2020-12/schema","additionalProperties":false,"properties":{"aggregate_id":{"format":"uuid","type":"string"},"aggregate_type":{"type":"string"},"compliance_tags":{"default":["consent_management","ai_auditability","cross_module_traceability"],"items":{"type":"string"},"type":"array"},"delivery_phase":{"const":"BUILD"},"domain_key":{"const":"ai_memory_operations"},"event_id":{"format":"uuid","type":"string"},"event_topic":{"const":"advisor.consent.recorded"},"evidence_refs":{"items":{"enum":["advisor_insights","financial_goals","ai_memory","agenda_items"],"type":"string"},"minItems":1,"type":"array"},"module_code":{"const":"ADVISOR"},"occurred_at":{"format":"date-time","type":"string"},"payload":{"additionalProperties":true,"properties":{"capability":{"enum":["insights","recomendacao com consentimento","orquestracao entre modulos"],"type":"string"},"details":{"additionalProperties":true,"type":"object"},"primary_actor":{"enum":["usuario assistido","motor de IA","operador consultivo"],"type":"string"},"status":{"type":"string"}},"type":"object"},"trace_id":{"format":"uuid","type":"string"},"user_id":{"format":"uuid","type":"string"}},"required":["event_id","event_topic","module_code","domain_key","user_id","occurred_at","payload","evidence_refs"],"title":"ADVISOR::advisor.consent.recorded","type":"object"}'::JSONB, 'contracts/events/priority-domains/ai_memory_operations.json'),
    ('AGENDA:agenda.item.created:v1', 'ai_memory_operations.priority.v1', 'ai_memory_operations', 'AGENDA', 'agenda.item.created', '1.0.0', 'painel de agenda', ARRAY['ADVISOR', 'CHAT', 'painel de agenda', 'fila de lembretes']::TEXT[], ARRAY['agenda_items', 'ai_memory']::TEXT[], ARRAY['personal_data_retention', 'consent_management', 'assistant_audit']::TEXT[], 'READY'::domain_delivery_package_status_enum, '{"$schema":"https://json-schema.org/draft/2020-12/schema","additionalProperties":false,"properties":{"aggregate_id":{"format":"uuid","type":"string"},"aggregate_type":{"type":"string"},"compliance_tags":{"default":["personal_data_retention","consent_management","assistant_audit"],"items":{"type":"string"},"type":"array"},"delivery_phase":{"const":"VALIDATE"},"domain_key":{"const":"ai_memory_operations"},"event_id":{"format":"uuid","type":"string"},"event_topic":{"const":"agenda.item.created"},"evidence_refs":{"items":{"enum":["agenda_items","ai_memory"],"type":"string"},"minItems":1,"type":"array"},"module_code":{"const":"AGENDA"},"occurred_at":{"format":"date-time","type":"string"},"payload":{"additionalProperties":true,"properties":{"capability":{"enum":["agenda inteligente","listas","memoria operacional"],"type":"string"},"details":{"additionalProperties":true,"type":"object"},"primary_actor":{"enum":["usuario final","helena persona","operador de produtividade"],"type":"string"},"status":{"type":"string"}},"type":"object"},"trace_id":{"format":"uuid","type":"string"},"user_id":{"format":"uuid","type":"string"}},"required":["event_id","event_topic","module_code","domain_key","user_id","occurred_at","payload","evidence_refs"],"title":"AGENDA::agenda.item.created","type":"object"}'::JSONB, 'contracts/events/priority-domains/ai_memory_operations.json'),
    ('AGENDA:agenda.reminder.triggered:v1', 'ai_memory_operations.priority.v1', 'ai_memory_operations', 'AGENDA', 'agenda.reminder.triggered', '1.0.0', 'painel de agenda', ARRAY['ADVISOR', 'CHAT', 'painel de agenda', 'fila de lembretes']::TEXT[], ARRAY['agenda_items', 'ai_memory']::TEXT[], ARRAY['personal_data_retention', 'consent_management', 'assistant_audit']::TEXT[], 'READY'::domain_delivery_package_status_enum, '{"$schema":"https://json-schema.org/draft/2020-12/schema","additionalProperties":false,"properties":{"aggregate_id":{"format":"uuid","type":"string"},"aggregate_type":{"type":"string"},"compliance_tags":{"default":["personal_data_retention","consent_management","assistant_audit"],"items":{"type":"string"},"type":"array"},"delivery_phase":{"const":"VALIDATE"},"domain_key":{"const":"ai_memory_operations"},"event_id":{"format":"uuid","type":"string"},"event_topic":{"const":"agenda.reminder.triggered"},"evidence_refs":{"items":{"enum":["agenda_items","ai_memory"],"type":"string"},"minItems":1,"type":"array"},"module_code":{"const":"AGENDA"},"occurred_at":{"format":"date-time","type":"string"},"payload":{"additionalProperties":true,"properties":{"capability":{"enum":["agenda inteligente","listas","memoria operacional"],"type":"string"},"details":{"additionalProperties":true,"type":"object"},"primary_actor":{"enum":["usuario final","helena persona","operador de produtividade"],"type":"string"},"status":{"type":"string"}},"type":"object"},"trace_id":{"format":"uuid","type":"string"},"user_id":{"format":"uuid","type":"string"}},"required":["event_id","event_topic","module_code","domain_key","user_id","occurred_at","payload","evidence_refs"],"title":"AGENDA::agenda.reminder.triggered","type":"object"}'::JSONB, 'contracts/events/priority-domains/ai_memory_operations.json'),
    ('AGENDA:agenda.memory.linked:v1', 'ai_memory_operations.priority.v1', 'ai_memory_operations', 'AGENDA', 'agenda.memory.linked', '1.0.0', 'painel de agenda', ARRAY['ADVISOR', 'CHAT', 'painel de agenda', 'fila de lembretes']::TEXT[], ARRAY['agenda_items', 'ai_memory']::TEXT[], ARRAY['personal_data_retention', 'consent_management', 'assistant_audit']::TEXT[], 'READY'::domain_delivery_package_status_enum, '{"$schema":"https://json-schema.org/draft/2020-12/schema","additionalProperties":false,"properties":{"aggregate_id":{"format":"uuid","type":"string"},"aggregate_type":{"type":"string"},"compliance_tags":{"default":["personal_data_retention","consent_management","assistant_audit"],"items":{"type":"string"},"type":"array"},"delivery_phase":{"const":"VALIDATE"},"domain_key":{"const":"ai_memory_operations"},"event_id":{"format":"uuid","type":"string"},"event_topic":{"const":"agenda.memory.linked"},"evidence_refs":{"items":{"enum":["agenda_items","ai_memory"],"type":"string"},"minItems":1,"type":"array"},"module_code":{"const":"AGENDA"},"occurred_at":{"format":"date-time","type":"string"},"payload":{"additionalProperties":true,"properties":{"capability":{"enum":["agenda inteligente","listas","memoria operacional"],"type":"string"},"details":{"additionalProperties":true,"type":"object"},"primary_actor":{"enum":["usuario final","helena persona","operador de produtividade"],"type":"string"},"status":{"type":"string"}},"type":"object"},"trace_id":{"format":"uuid","type":"string"},"user_id":{"format":"uuid","type":"string"}},"required":["event_id","event_topic","module_code","domain_key","user_id","occurred_at","payload","evidence_refs"],"title":"AGENDA::agenda.memory.linked","type":"object"}'::JSONB, 'contracts/events/priority-domains/ai_memory_operations.json'),
    ('CHAT:chat.conversation.opened:v1', 'ai_memory_operations.priority.v1', 'ai_memory_operations', 'CHAT', 'chat.conversation.opened', '1.0.0', 'painel de conversas', ARRAY['AGENDA', 'ADVISOR', 'painel de conversas', 'monitor de contexto']::TEXT[], ARRAY['chat_conversations', 'users', 'ai_memory', 'agenda_items']::TEXT[], ARRAY['message_retention_policy', 'persona_separation', 'consent_audit']::TEXT[], 'READY'::domain_delivery_package_status_enum, '{"$schema":"https://json-schema.org/draft/2020-12/schema","additionalProperties":false,"properties":{"aggregate_id":{"format":"uuid","type":"string"},"aggregate_type":{"type":"string"},"compliance_tags":{"default":["message_retention_policy","persona_separation","consent_audit"],"items":{"type":"string"},"type":"array"},"delivery_phase":{"const":"VALIDATE"},"domain_key":{"const":"ai_memory_operations"},"event_id":{"format":"uuid","type":"string"},"event_topic":{"const":"chat.conversation.opened"},"evidence_refs":{"items":{"enum":["chat_conversations","users","ai_memory","agenda_items"],"type":"string"},"minItems":1,"type":"array"},"module_code":{"const":"CHAT"},"occurred_at":{"format":"date-time","type":"string"},"payload":{"additionalProperties":true,"properties":{"capability":{"enum":["conversa dual persona","retencao segura","ponte com agenda e advisor"],"type":"string"},"details":{"additionalProperties":true,"type":"object"},"primary_actor":{"enum":["usuario pessoal","usuario profissional","motor de assistencia"],"type":"string"},"status":{"type":"string"}},"type":"object"},"trace_id":{"format":"uuid","type":"string"},"user_id":{"format":"uuid","type":"string"}},"required":["event_id","event_topic","module_code","domain_key","user_id","occurred_at","payload","evidence_refs"],"title":"CHAT::chat.conversation.opened","type":"object"}'::JSONB, 'contracts/events/priority-domains/ai_memory_operations.json'),
    ('CHAT:chat.message.persisted:v1', 'ai_memory_operations.priority.v1', 'ai_memory_operations', 'CHAT', 'chat.message.persisted', '1.0.0', 'painel de conversas', ARRAY['AGENDA', 'ADVISOR', 'painel de conversas', 'monitor de contexto']::TEXT[], ARRAY['chat_conversations', 'users', 'ai_memory', 'agenda_items']::TEXT[], ARRAY['message_retention_policy', 'persona_separation', 'consent_audit']::TEXT[], 'READY'::domain_delivery_package_status_enum, '{"$schema":"https://json-schema.org/draft/2020-12/schema","additionalProperties":false,"properties":{"aggregate_id":{"format":"uuid","type":"string"},"aggregate_type":{"type":"string"},"compliance_tags":{"default":["message_retention_policy","persona_separation","consent_audit"],"items":{"type":"string"},"type":"array"},"delivery_phase":{"const":"VALIDATE"},"domain_key":{"const":"ai_memory_operations"},"event_id":{"format":"uuid","type":"string"},"event_topic":{"const":"chat.message.persisted"},"evidence_refs":{"items":{"enum":["chat_conversations","users","ai_memory","agenda_items"],"type":"string"},"minItems":1,"type":"array"},"module_code":{"const":"CHAT"},"occurred_at":{"format":"date-time","type":"string"},"payload":{"additionalProperties":true,"properties":{"capability":{"enum":["conversa dual persona","retencao segura","ponte com agenda e advisor"],"type":"string"},"details":{"additionalProperties":true,"type":"object"},"primary_actor":{"enum":["usuario pessoal","usuario profissional","motor de assistencia"],"type":"string"},"status":{"type":"string"}},"type":"object"},"trace_id":{"format":"uuid","type":"string"},"user_id":{"format":"uuid","type":"string"}},"required":["event_id","event_topic","module_code","domain_key","user_id","occurred_at","payload","evidence_refs"],"title":"CHAT::chat.message.persisted","type":"object"}'::JSONB, 'contracts/events/priority-domains/ai_memory_operations.json'),
    ('CHAT:chat.context.promoted:v1', 'ai_memory_operations.priority.v1', 'ai_memory_operations', 'CHAT', 'chat.context.promoted', '1.0.0', 'painel de conversas', ARRAY['AGENDA', 'ADVISOR', 'painel de conversas', 'monitor de contexto']::TEXT[], ARRAY['chat_conversations', 'users', 'ai_memory', 'agenda_items']::TEXT[], ARRAY['message_retention_policy', 'persona_separation', 'consent_audit']::TEXT[], 'READY'::domain_delivery_package_status_enum, '{"$schema":"https://json-schema.org/draft/2020-12/schema","additionalProperties":false,"properties":{"aggregate_id":{"format":"uuid","type":"string"},"aggregate_type":{"type":"string"},"compliance_tags":{"default":["message_retention_policy","persona_separation","consent_audit"],"items":{"type":"string"},"type":"array"},"delivery_phase":{"const":"VALIDATE"},"domain_key":{"const":"ai_memory_operations"},"event_id":{"format":"uuid","type":"string"},"event_topic":{"const":"chat.context.promoted"},"evidence_refs":{"items":{"enum":["chat_conversations","users","ai_memory","agenda_items"],"type":"string"},"minItems":1,"type":"array"},"module_code":{"const":"CHAT"},"occurred_at":{"format":"date-time","type":"string"},"payload":{"additionalProperties":true,"properties":{"capability":{"enum":["conversa dual persona","retencao segura","ponte com agenda e advisor"],"type":"string"},"details":{"additionalProperties":true,"type":"object"},"primary_actor":{"enum":["usuario pessoal","usuario profissional","motor de assistencia"],"type":"string"},"status":{"type":"string"}},"type":"object"},"trace_id":{"format":"uuid","type":"string"},"user_id":{"format":"uuid","type":"string"}},"required":["event_id","event_topic","module_code","domain_key","user_id","occurred_at","payload","evidence_refs"],"title":"CHAT::chat.context.promoted","type":"object"}'::JSONB, 'contracts/events/priority-domains/ai_memory_operations.json')
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

-- Enriquecimento manual: seed operacional real do dominio ai_memory_operations.
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
    birth_date,
    document_country,
    document_type,
    document_number,
    nationality,
    tax_residence_country,
    primary_role,
    module_tier,
    terms_accepted_at,
    privacy_accepted_at,
    created_at,
    updated_at
) VALUES
    (
        '10000000-0000-4000-8000-000000000501',
        'SYSTEM'::user_kind_enum,
        'ACTIVE'::account_status_enum,
        'APPROVED'::kyc_status_enum,
        'Helena Valley Runtime',
        'Helena',
        'helena.runtime@valley.local',
        '+5511990000501',
        NULL,
        'BR',
        'SYSTEM_ID',
        'HELENA-0001',
        'BR',
        'BR',
        'AI_ORCHESTRATOR',
        'CORE',
        TIMESTAMPTZ '2026-04-21 12:00:00+00',
        TIMESTAMPTZ '2026-04-21 12:00:00+00',
        TIMESTAMPTZ '2026-04-21 12:00:00+00',
        TIMESTAMPTZ '2026-04-21 12:00:00+00'
    ),
    (
        '10000000-0000-4000-8000-000000000502',
        'PF'::user_kind_enum,
        'ACTIVE'::account_status_enum,
        'APPROVED'::kyc_status_enum,
        'Marina Contexto',
        'Marina',
        'marina.contexto@valley.local',
        '+5511990000502',
        DATE '1991-08-22',
        'BR',
        'CPF',
        '90000000502',
        'BR',
        'BR',
        'ADVISOR_USER',
        'CORE',
        TIMESTAMPTZ '2026-04-21 12:00:00+00',
        TIMESTAMPTZ '2026-04-21 12:00:00+00',
        TIMESTAMPTZ '2026-04-21 12:00:00+00',
        TIMESTAMPTZ '2026-04-21 12:00:00+00'
    ),
    (
        '10000000-0000-4000-8000-000000000503',
        'PF'::user_kind_enum,
        'ACTIVE'::account_status_enum,
        'APPROVED'::kyc_status_enum,
        'Paulo Produtividade',
        'Paulo',
        'paulo.produtividade@valley.local',
        '+5511990000503',
        DATE '1988-03-14',
        'BR',
        'CPF',
        '90000000503',
        'BR',
        'BR',
        'PRODUCTIVITY_SPECIALIST',
        'CORE',
        TIMESTAMPTZ '2026-04-21 12:00:00+00',
        TIMESTAMPTZ '2026-04-21 12:00:00+00',
        TIMESTAMPTZ '2026-04-21 12:00:00+00',
        TIMESTAMPTZ '2026-04-21 12:00:00+00'
    )
ON CONFLICT (user_id) DO UPDATE SET
    account_status = EXCLUDED.account_status,
    kyc_status = EXCLUDED.kyc_status,
    full_name = EXCLUDED.full_name,
    display_name = EXCLUDED.display_name,
    email = EXCLUDED.email,
    phone_e164 = EXCLUDED.phone_e164,
    birth_date = EXCLUDED.birth_date,
    document_country = EXCLUDED.document_country,
    document_type = EXCLUDED.document_type,
    document_number = EXCLUDED.document_number,
    nationality = EXCLUDED.nationality,
    tax_residence_country = EXCLUDED.tax_residence_country,
    primary_role = EXCLUDED.primary_role,
    module_tier = EXCLUDED.module_tier,
    terms_accepted_at = EXCLUDED.terms_accepted_at,
    privacy_accepted_at = EXCLUDED.privacy_accepted_at,
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
    created_at,
    updated_at
) VALUES
    (
        '20000000-0000-4000-8000-000000000501',
        '10000000-0000-4000-8000-000000000502',
        'CUSTODIAL'::wallet_type_enum,
        'BRL'::wallet_asset_enum,
        'ACTIVE'::wallet_status_enum,
        1800.0000,
        0.0000,
        0.0000,
        0.00000000,
        0.00000000,
        0.00000000,
        3000.0000,
        50000.0000,
        TIMESTAMPTZ '2026-04-21 12:00:00+00',
        TIMESTAMPTZ '2026-04-21 12:00:00+00'
    ),
    (
        '20000000-0000-4000-8000-000000000502',
        '10000000-0000-4000-8000-000000000503',
        'CUSTODIAL'::wallet_type_enum,
        'BRL'::wallet_asset_enum,
        'ACTIVE'::wallet_status_enum,
        950.0000,
        0.0000,
        0.0000,
        0.00000000,
        0.00000000,
        0.00000000,
        2000.0000,
        30000.0000,
        TIMESTAMPTZ '2026-04-21 12:00:00+00',
        TIMESTAMPTZ '2026-04-21 12:00:00+00'
    )
ON CONFLICT (wallet_id) DO UPDATE SET
    wallet_status = EXCLUDED.wallet_status,
    balance_available_brl = EXCLUDED.balance_available_brl,
    balance_blocked_brl = EXCLUDED.balance_blocked_brl,
    balance_pending_brl = EXCLUDED.balance_pending_brl,
    balance_available_nex = EXCLUDED.balance_available_nex,
    balance_blocked_nex = EXCLUDED.balance_blocked_nex,
    balance_pending_nex = EXCLUDED.balance_pending_nex,
    daily_limit_brl = EXCLUDED.daily_limit_brl,
    monthly_limit_brl = EXCLUDED.monthly_limit_brl,
    updated_at = EXCLUDED.updated_at;

INSERT INTO financial_goals (
    goal_id,
    user_id,
    goal_name,
    target_amount_brl,
    current_amount_brl,
    auto_round_up,
    goal_status,
    deadline,
    created_at,
    updated_at
) VALUES (
    '30000000-0000-4000-8000-000000000701',
    '10000000-0000-4000-8000-000000000502',
    'Reserva para troca de notebook',
    2000.0000,
    620.0000,
    TRUE,
    'ACTIVE'::financial_goal_status_enum,
    TIMESTAMPTZ '2026-06-30 18:00:00+00',
    TIMESTAMPTZ '2026-04-21 12:05:00+00',
    TIMESTAMPTZ '2026-04-21 12:05:00+00'
)
ON CONFLICT (goal_id) DO UPDATE SET
    goal_name = EXCLUDED.goal_name,
    target_amount_brl = EXCLUDED.target_amount_brl,
    current_amount_brl = EXCLUDED.current_amount_brl,
    auto_round_up = EXCLUDED.auto_round_up,
    goal_status = EXCLUDED.goal_status,
    deadline = EXCLUDED.deadline,
    updated_at = EXCLUDED.updated_at;

INSERT INTO advisor_insights (
    insight_id,
    user_id,
    insight_category,
    suggested_action,
    potential_savings_brl,
    is_executed,
    consent_required,
    execution_consented_at,
    source_module,
    created_at,
    updated_at
) VALUES
    (
        '30000000-0000-4000-8000-000000000702',
        '10000000-0000-4000-8000-000000000502',
        'FINANCE'::insight_category_enum,
        'Migrar 15 por cento do saldo livre para a meta de equipamento ainda hoje.',
        180.0000,
        FALSE,
        TRUE,
        TIMESTAMPTZ '2026-04-21 12:07:00+00',
        'ADVISOR',
        TIMESTAMPTZ '2026-04-21 12:06:00+00',
        TIMESTAMPTZ '2026-04-21 12:07:00+00'
    ),
    (
        '30000000-0000-4000-8000-000000000703',
        '10000000-0000-4000-8000-000000000502',
        'MOBILITY'::insight_category_enum,
        'Consolidar deslocamentos profissionais de quarta-feira para reduzir custo recorrente.',
        72.5000,
        FALSE,
        TRUE,
        NULL,
        'MOBILITY',
        TIMESTAMPTZ '2026-04-21 12:08:00+00',
        TIMESTAMPTZ '2026-04-21 12:08:00+00'
    )
ON CONFLICT (insight_id) DO UPDATE SET
    insight_category = EXCLUDED.insight_category,
    suggested_action = EXCLUDED.suggested_action,
    potential_savings_brl = EXCLUDED.potential_savings_brl,
    is_executed = EXCLUDED.is_executed,
    consent_required = EXCLUDED.consent_required,
    execution_consented_at = EXCLUDED.execution_consented_at,
    source_module = EXCLUDED.source_module,
    updated_at = EXCLUDED.updated_at;

INSERT INTO chat_conversations (
    conversation_id,
    participant1_id,
    participant2_id,
    deleted_at,
    created_at
) VALUES (
    '30000000-0000-4000-8000-000000000704',
    '10000000-0000-4000-8000-000000000502',
    '10000000-0000-4000-8000-000000000503',
    NULL,
    TIMESTAMPTZ '2026-04-21 12:09:00+00'
)
ON CONFLICT (conversation_id) DO UPDATE SET
    deleted_at = EXCLUDED.deleted_at;

INSERT INTO chat_messages (
    message_id,
    conversation_id,
    sender_id,
    persona,
    content,
    created_at
) VALUES
    (
        '30000000-0000-4000-8000-000000000705',
        '30000000-0000-4000-8000-000000000704',
        '10000000-0000-4000-8000-000000000502',
        'PERSONAL'::chat_persona_enum,
        'Helena sugeriu reorganizar a minha semana para reduzir custo de deslocamento.',
        TIMESTAMPTZ '2026-04-21 12:10:00+00'
    ),
    (
        '30000000-0000-4000-8000-000000000706',
        '30000000-0000-4000-8000-000000000704',
        '10000000-0000-4000-8000-000000000503',
        'PROFESSIONAL'::chat_persona_enum,
        'Posso condensar as reunioes em um bloco unico e deixar a acao pronta para consentimento.',
        TIMESTAMPTZ '2026-04-21 12:11:00+00'
    ),
    (
        '30000000-0000-4000-8000-000000000707',
        '30000000-0000-4000-8000-000000000704',
        '10000000-0000-4000-8000-000000000502',
        'PERSONAL'::chat_persona_enum,
        'Perfeito, deixa a recomendacao financeira ativa e me lembra amanha cedo.',
        TIMESTAMPTZ '2026-04-21 12:12:00+00'
    )
ON CONFLICT (message_id) DO NOTHING;

COMMIT;
