BEGIN;

-- Seed operacional idempotente dos pacotes fisicos por dominio prioritario.
-- Gerado automaticamente por scripts/automacao_sincronizador_modulos.py.

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
    ('ai_memory_operations.ddl.v1', 'ai_memory_operations.priority.v1', 'ai_memory_operations', 'DDL_COMPLEMENT'::domain_delivery_layer_enum, 'postgres', 'database/domain-delivery/priority-domains/ai_memory_operations/ddl_complement.sql', ARRAY['ADVISOR', 'AGENDA', 'CHAT']::TEXT[], ARRAY['ADVISOR.exec.01', 'ADVISOR.exec.02', 'AGENDA.exec.01', 'AGENDA.exec.02', 'ADVISOR.exec.03', 'CHAT.exec.01', 'CHAT.exec.02', 'AGENDA.exec.03', 'CHAT.exec.03']::TEXT[], ARRAY[]::TEXT[], 'READY'::domain_delivery_package_status_enum, '{"package_key":"ai_memory_operations.priority.v1","priority_rank":2,"views":["v_ai_memory_operations_priority_backlog","v_ai_memory_operations_delivery_artifacts","v_ai_memory_operations_event_contracts"]}'::JSONB),
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
    ('AGENDA:agenda.item.created:v1', 'ai_memory_operations.priority.v1', 'ai_memory_operations', 'AGENDA', 'agenda.item.created', '1.0.0', 'painel de agenda', ARRAY['ADVISOR', 'CHAT', 'painel de agenda', 'fila de lembretes']::TEXT[], ARRAY['agenda_items', 'ai_memory']::TEXT[], ARRAY['personal_data_retention', 'consent_management', 'assistant_audit']::TEXT[], 'READY'::domain_delivery_package_status_enum, '{"$schema":"https://json-schema.org/draft/2020-12/schema","additionalProperties":false,"properties":{"aggregate_id":{"format":"uuid","type":"string"},"aggregate_type":{"type":"string"},"compliance_tags":{"default":["personal_data_retention","consent_management","assistant_audit"],"items":{"type":"string"},"type":"array"},"delivery_phase":{"const":"VALIDATE"},"domain_key":{"const":"ai_memory_operations"},"event_id":{"format":"uuid","type":"string"},"event_topic":{"const":"agenda.item.created"},"evidence_refs":{"items":{"enum":["agenda_items","ai_memory"],"type":"string"},"minItems":1,"type":"array"},"module_code":{"const":"AGENDA"},"occurred_at":{"format":"date-time","type":"string"},"payload":{"additionalProperties":true,"properties":{"capability":{"enum":["agenda inteligente","listas","memoria operacional"],"type":"string"},"details":{"additionalProperties":true,"type":"object"},"primary_actor":{"enum":["usuario final","Helena","operador de produtividade"],"type":"string"},"status":{"type":"string"}},"type":"object"},"trace_id":{"format":"uuid","type":"string"},"user_id":{"format":"uuid","type":"string"}},"required":["event_id","event_topic","module_code","domain_key","user_id","occurred_at","payload","evidence_refs"],"title":"AGENDA::agenda.item.created","type":"object"}'::JSONB, 'contracts/events/priority-domains/ai_memory_operations.json'),
    ('AGENDA:agenda.reminder.triggered:v1', 'ai_memory_operations.priority.v1', 'ai_memory_operations', 'AGENDA', 'agenda.reminder.triggered', '1.0.0', 'painel de agenda', ARRAY['ADVISOR', 'CHAT', 'painel de agenda', 'fila de lembretes']::TEXT[], ARRAY['agenda_items', 'ai_memory']::TEXT[], ARRAY['personal_data_retention', 'consent_management', 'assistant_audit']::TEXT[], 'READY'::domain_delivery_package_status_enum, '{"$schema":"https://json-schema.org/draft/2020-12/schema","additionalProperties":false,"properties":{"aggregate_id":{"format":"uuid","type":"string"},"aggregate_type":{"type":"string"},"compliance_tags":{"default":["personal_data_retention","consent_management","assistant_audit"],"items":{"type":"string"},"type":"array"},"delivery_phase":{"const":"VALIDATE"},"domain_key":{"const":"ai_memory_operations"},"event_id":{"format":"uuid","type":"string"},"event_topic":{"const":"agenda.reminder.triggered"},"evidence_refs":{"items":{"enum":["agenda_items","ai_memory"],"type":"string"},"minItems":1,"type":"array"},"module_code":{"const":"AGENDA"},"occurred_at":{"format":"date-time","type":"string"},"payload":{"additionalProperties":true,"properties":{"capability":{"enum":["agenda inteligente","listas","memoria operacional"],"type":"string"},"details":{"additionalProperties":true,"type":"object"},"primary_actor":{"enum":["usuario final","Helena","operador de produtividade"],"type":"string"},"status":{"type":"string"}},"type":"object"},"trace_id":{"format":"uuid","type":"string"},"user_id":{"format":"uuid","type":"string"}},"required":["event_id","event_topic","module_code","domain_key","user_id","occurred_at","payload","evidence_refs"],"title":"AGENDA::agenda.reminder.triggered","type":"object"}'::JSONB, 'contracts/events/priority-domains/ai_memory_operations.json'),
    ('AGENDA:agenda.memory.linked:v1', 'ai_memory_operations.priority.v1', 'ai_memory_operations', 'AGENDA', 'agenda.memory.linked', '1.0.0', 'painel de agenda', ARRAY['ADVISOR', 'CHAT', 'painel de agenda', 'fila de lembretes']::TEXT[], ARRAY['agenda_items', 'ai_memory']::TEXT[], ARRAY['personal_data_retention', 'consent_management', 'assistant_audit']::TEXT[], 'READY'::domain_delivery_package_status_enum, '{"$schema":"https://json-schema.org/draft/2020-12/schema","additionalProperties":false,"properties":{"aggregate_id":{"format":"uuid","type":"string"},"aggregate_type":{"type":"string"},"compliance_tags":{"default":["personal_data_retention","consent_management","assistant_audit"],"items":{"type":"string"},"type":"array"},"delivery_phase":{"const":"VALIDATE"},"domain_key":{"const":"ai_memory_operations"},"event_id":{"format":"uuid","type":"string"},"event_topic":{"const":"agenda.memory.linked"},"evidence_refs":{"items":{"enum":["agenda_items","ai_memory"],"type":"string"},"minItems":1,"type":"array"},"module_code":{"const":"AGENDA"},"occurred_at":{"format":"date-time","type":"string"},"payload":{"additionalProperties":true,"properties":{"capability":{"enum":["agenda inteligente","listas","memoria operacional"],"type":"string"},"details":{"additionalProperties":true,"type":"object"},"primary_actor":{"enum":["usuario final","Helena","operador de produtividade"],"type":"string"},"status":{"type":"string"}},"type":"object"},"trace_id":{"format":"uuid","type":"string"},"user_id":{"format":"uuid","type":"string"}},"required":["event_id","event_topic","module_code","domain_key","user_id","occurred_at","payload","evidence_refs"],"title":"AGENDA::agenda.memory.linked","type":"object"}'::JSONB, 'contracts/events/priority-domains/ai_memory_operations.json'),
    ('CHAT:chat.conversation.opened:v1', 'ai_memory_operations.priority.v1', 'ai_memory_operations', 'CHAT', 'chat.conversation.opened', '1.0.0', 'painel de conversas', ARRAY['AGENDA', 'ADVISOR', 'painel de conversas', 'monitor de contexto']::TEXT[], ARRAY['chat_conversations', 'users', 'ai_memory', 'agenda_items']::TEXT[], ARRAY['message_retention_policy', 'helena_context_separation', 'consent_audit']::TEXT[], 'READY'::domain_delivery_package_status_enum, '{"$schema":"https://json-schema.org/draft/2020-12/schema","additionalProperties":false,"properties":{"aggregate_id":{"format":"uuid","type":"string"},"aggregate_type":{"type":"string"},"compliance_tags":{"default":["message_retention_policy","helena_context_separation","consent_audit"],"items":{"type":"string"},"type":"array"},"delivery_phase":{"const":"VALIDATE"},"domain_key":{"const":"ai_memory_operations"},"event_id":{"format":"uuid","type":"string"},"event_topic":{"const":"chat.conversation.opened"},"evidence_refs":{"items":{"enum":["chat_conversations","users","ai_memory","agenda_items"],"type":"string"},"minItems":1,"type":"array"},"module_code":{"const":"CHAT"},"occurred_at":{"format":"date-time","type":"string"},"payload":{"additionalProperties":true,"properties":{"capability":{"enum":["conversa Helena dual","retencao segura","ponte com agenda e advisor"],"type":"string"},"details":{"additionalProperties":true,"type":"object"},"primary_actor":{"enum":["usuario pessoal","usuario profissional","motor de assistencia"],"type":"string"},"status":{"type":"string"}},"type":"object"},"trace_id":{"format":"uuid","type":"string"},"user_id":{"format":"uuid","type":"string"}},"required":["event_id","event_topic","module_code","domain_key","user_id","occurred_at","payload","evidence_refs"],"title":"CHAT::chat.conversation.opened","type":"object"}'::JSONB, 'contracts/events/priority-domains/ai_memory_operations.json'),
    ('CHAT:chat.message.persisted:v1', 'ai_memory_operations.priority.v1', 'ai_memory_operations', 'CHAT', 'chat.message.persisted', '1.0.0', 'painel de conversas', ARRAY['AGENDA', 'ADVISOR', 'painel de conversas', 'monitor de contexto']::TEXT[], ARRAY['chat_conversations', 'users', 'ai_memory', 'agenda_items']::TEXT[], ARRAY['message_retention_policy', 'helena_context_separation', 'consent_audit']::TEXT[], 'READY'::domain_delivery_package_status_enum, '{"$schema":"https://json-schema.org/draft/2020-12/schema","additionalProperties":false,"properties":{"aggregate_id":{"format":"uuid","type":"string"},"aggregate_type":{"type":"string"},"compliance_tags":{"default":["message_retention_policy","helena_context_separation","consent_audit"],"items":{"type":"string"},"type":"array"},"delivery_phase":{"const":"VALIDATE"},"domain_key":{"const":"ai_memory_operations"},"event_id":{"format":"uuid","type":"string"},"event_topic":{"const":"chat.message.persisted"},"evidence_refs":{"items":{"enum":["chat_conversations","users","ai_memory","agenda_items"],"type":"string"},"minItems":1,"type":"array"},"module_code":{"const":"CHAT"},"occurred_at":{"format":"date-time","type":"string"},"payload":{"additionalProperties":true,"properties":{"capability":{"enum":["conversa Helena dual","retencao segura","ponte com agenda e advisor"],"type":"string"},"details":{"additionalProperties":true,"type":"object"},"primary_actor":{"enum":["usuario pessoal","usuario profissional","motor de assistencia"],"type":"string"},"status":{"type":"string"}},"type":"object"},"trace_id":{"format":"uuid","type":"string"},"user_id":{"format":"uuid","type":"string"}},"required":["event_id","event_topic","module_code","domain_key","user_id","occurred_at","payload","evidence_refs"],"title":"CHAT::chat.message.persisted","type":"object"}'::JSONB, 'contracts/events/priority-domains/ai_memory_operations.json'),
    ('CHAT:chat.context.promoted:v1', 'ai_memory_operations.priority.v1', 'ai_memory_operations', 'CHAT', 'chat.context.promoted', '1.0.0', 'painel de conversas', ARRAY['AGENDA', 'ADVISOR', 'painel de conversas', 'monitor de contexto']::TEXT[], ARRAY['chat_conversations', 'users', 'ai_memory', 'agenda_items']::TEXT[], ARRAY['message_retention_policy', 'helena_context_separation', 'consent_audit']::TEXT[], 'READY'::domain_delivery_package_status_enum, '{"$schema":"https://json-schema.org/draft/2020-12/schema","additionalProperties":false,"properties":{"aggregate_id":{"format":"uuid","type":"string"},"aggregate_type":{"type":"string"},"compliance_tags":{"default":["message_retention_policy","helena_context_separation","consent_audit"],"items":{"type":"string"},"type":"array"},"delivery_phase":{"const":"VALIDATE"},"domain_key":{"const":"ai_memory_operations"},"event_id":{"format":"uuid","type":"string"},"event_topic":{"const":"chat.context.promoted"},"evidence_refs":{"items":{"enum":["chat_conversations","users","ai_memory","agenda_items"],"type":"string"},"minItems":1,"type":"array"},"module_code":{"const":"CHAT"},"occurred_at":{"format":"date-time","type":"string"},"payload":{"additionalProperties":true,"properties":{"capability":{"enum":["conversa Helena dual","retencao segura","ponte com agenda e advisor"],"type":"string"},"details":{"additionalProperties":true,"type":"object"},"primary_actor":{"enum":["usuario pessoal","usuario profissional","motor de assistencia"],"type":"string"},"status":{"type":"string"}},"type":"object"},"trace_id":{"format":"uuid","type":"string"},"user_id":{"format":"uuid","type":"string"}},"required":["event_id","event_topic","module_code","domain_key","user_id","occurred_at","payload","evidence_refs"],"title":"CHAT::chat.context.promoted","type":"object"}'::JSONB, 'contracts/events/priority-domains/ai_memory_operations.json')
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
