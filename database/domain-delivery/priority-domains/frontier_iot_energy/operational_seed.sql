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
    ('frontier_iot_energy.priority.v1', 'frontier_iot_energy', 'Frontier IoT Energy', 2, 'priority_domains_v1', ARRAY['IOT', 'BIO', 'HOME', 'ENERGY', 'SPACE']::TEXT[], ARRAY['IOT.exec.01', 'IOT.exec.02', 'IOT.exec.03', 'BIO.exec.01', 'BIO.exec.02', 'HOME.exec.01', 'HOME.exec.02', 'ENERGY.exec.01', 'ENERGY.exec.02', 'BIO.exec.03', 'HOME.exec.03', 'ENERGY.exec.03', 'SPACE.exec.01', 'SPACE.exec.02', 'SPACE.exec.03']::TEXT[], 'READY'::domain_delivery_package_status_enum, '{"artifacts":[{"artifact_key":"frontier_iot_energy.ddl.v1","artifact_path":"database/domain-delivery/priority-domains/frontier_iot_energy/ddl_complement.sql","layer_type":"DDL_COMPLEMENT","target_engine":"postgres"},{"artifact_key":"frontier_iot_energy.seed.v1","artifact_path":"database/domain-delivery/priority-domains/frontier_iot_energy/operational_seed.sql","layer_type":"OPERATIONS_SEED","target_engine":"postgres"},{"artifact_key":"frontier_iot_energy.contract.v1","artifact_path":"contracts/events/priority-domains/frontier_iot_energy.json","layer_type":"EVENT_CONTRACT","target_engine":"filesystem"}],"backlog_keys":["IOT.exec.01","IOT.exec.02","IOT.exec.03","BIO.exec.01","BIO.exec.02","HOME.exec.01","HOME.exec.02","ENERGY.exec.01","ENERGY.exec.02","BIO.exec.03","HOME.exec.03","ENERGY.exec.03","SPACE.exec.01","SPACE.exec.02","SPACE.exec.03"],"domain_key":"frontier_iot_energy","domain_label":"Frontier IoT Energy","event_topics":["iot.device.provisioned","iot.sensor.event_ingested","iot.device.offline_detected","bio.program.opened","bio.collection.scheduled","bio.impact.measured","home.device.bound","home.scene.executed","home.alert.triggered","energy.asset.registered","energy.trade.matched","energy.settlement.posted","space.anchor.created","space.anchor.visited","space.layer.published"],"modules":["IOT","BIO","HOME","ENERGY","SPACE"],"package_key":"frontier_iot_energy.priority.v1","priority_rank":2}'::JSONB)
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
    ('frontier_iot_energy.ddl.v1', 'frontier_iot_energy.priority.v1', 'frontier_iot_energy', 'DDL_COMPLEMENT'::domain_delivery_layer_enum, 'postgres', 'database/domain-delivery/priority-domains/frontier_iot_energy/ddl_complement.sql', ARRAY['IOT', 'BIO', 'HOME', 'ENERGY', 'SPACE']::TEXT[], ARRAY['IOT.exec.01', 'IOT.exec.02', 'IOT.exec.03', 'BIO.exec.01', 'BIO.exec.02', 'HOME.exec.01', 'HOME.exec.02', 'ENERGY.exec.01', 'ENERGY.exec.02', 'BIO.exec.03', 'HOME.exec.03', 'ENERGY.exec.03', 'SPACE.exec.01', 'SPACE.exec.02', 'SPACE.exec.03']::TEXT[], ARRAY[]::TEXT[], 'READY'::domain_delivery_package_status_enum, '{"package_key":"frontier_iot_energy.priority.v1","priority_rank":2,"views":["v_frontier_iot_energy_priority_backlog","v_frontier_iot_energy_delivery_artifacts","v_frontier_iot_energy_event_contracts"]}'::JSONB),
    ('frontier_iot_energy.seed.v1', 'frontier_iot_energy.priority.v1', 'frontier_iot_energy', 'OPERATIONS_SEED'::domain_delivery_layer_enum, 'postgres', 'database/domain-delivery/priority-domains/frontier_iot_energy/operational_seed.sql', ARRAY['IOT', 'BIO', 'HOME', 'ENERGY', 'SPACE']::TEXT[], ARRAY['IOT.exec.01', 'IOT.exec.02', 'IOT.exec.03', 'BIO.exec.01', 'BIO.exec.02', 'HOME.exec.01', 'HOME.exec.02', 'ENERGY.exec.01', 'ENERGY.exec.02', 'BIO.exec.03', 'HOME.exec.03', 'ENERGY.exec.03', 'SPACE.exec.01', 'SPACE.exec.02', 'SPACE.exec.03']::TEXT[], ARRAY['frontier_iot_energy.ddl.v1']::TEXT[], 'READY'::domain_delivery_package_status_enum, '{"contract_count":15,"package_key":"frontier_iot_energy.priority.v1","seed_scope":"priority_domain_delivery_v1"}'::JSONB),
    ('frontier_iot_energy.contract.v1', 'frontier_iot_energy.priority.v1', 'frontier_iot_energy', 'EVENT_CONTRACT'::domain_delivery_layer_enum, 'filesystem', 'contracts/events/priority-domains/frontier_iot_energy.json', ARRAY['IOT', 'BIO', 'HOME', 'ENERGY', 'SPACE']::TEXT[], ARRAY['IOT.exec.01', 'IOT.exec.02', 'IOT.exec.03', 'BIO.exec.01', 'BIO.exec.02', 'HOME.exec.01', 'HOME.exec.02', 'ENERGY.exec.01', 'ENERGY.exec.02', 'BIO.exec.03', 'HOME.exec.03', 'ENERGY.exec.03', 'SPACE.exec.01', 'SPACE.exec.02', 'SPACE.exec.03']::TEXT[], ARRAY['frontier_iot_energy.ddl.v1', 'frontier_iot_energy.seed.v1']::TEXT[], 'READY'::domain_delivery_package_status_enum, '{"event_topics":["iot.device.provisioned","iot.sensor.event_ingested","iot.device.offline_detected","bio.program.opened","bio.collection.scheduled","bio.impact.measured","home.device.bound","home.scene.executed","home.alert.triggered","energy.asset.registered","energy.trade.matched","energy.settlement.posted","space.anchor.created","space.anchor.visited","space.layer.published"],"package_key":"frontier_iot_energy.priority.v1"}'::JSONB)
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
    ('IOT:iot.device.provisioned:v1', 'frontier_iot_energy.priority.v1', 'frontier_iot_energy', 'IOT', 'iot.device.provisioned', '1.0.0', 'painel de devices', ARRAY['HOME', 'FLEET', 'SECURITY', 'painel de devices', 'fila de provisioning']::TEXT[], ARRAY['iot_device_registry', 'iot_sensor_events']::TEXT[], ARRAY['device_traceability', 'telemetry_retention', 'access_control']::TEXT[], 'READY'::domain_delivery_package_status_enum, '{"$schema":"https://json-schema.org/draft/2020-12/schema","additionalProperties":false,"properties":{"aggregate_id":{"format":"uuid","type":"string"},"aggregate_type":{"type":"string"},"compliance_tags":{"default":["device_traceability","telemetry_retention","access_control"],"items":{"type":"string"},"type":"array"},"delivery_phase":{"const":"VALIDATE"},"domain_key":{"const":"frontier_iot_energy"},"event_id":{"format":"uuid","type":"string"},"event_topic":{"const":"iot.device.provisioned"},"evidence_refs":{"items":{"enum":["iot_device_registry","iot_sensor_events"],"type":"string"},"minItems":1,"type":"array"},"module_code":{"const":"IOT"},"occurred_at":{"format":"date-time","type":"string"},"payload":{"additionalProperties":true,"properties":{"capability":{"enum":["registry de device","eventos de sensor","hub conectado"],"type":"string"},"details":{"additionalProperties":true,"type":"object"},"primary_actor":{"enum":["operador de dispositivos","tecnico de campo","motor de automacao"],"type":"string"},"status":{"type":"string"}},"type":"object"},"trace_id":{"format":"uuid","type":"string"},"user_id":{"format":"uuid","type":"string"}},"required":["event_id","event_topic","module_code","domain_key","user_id","occurred_at","payload","evidence_refs"],"title":"IOT::iot.device.provisioned","type":"object"}'::JSONB, 'contracts/events/priority-domains/frontier_iot_energy.json'),
    ('IOT:iot.sensor.event_ingested:v1', 'frontier_iot_energy.priority.v1', 'frontier_iot_energy', 'IOT', 'iot.sensor.event_ingested', '1.0.0', 'painel de devices', ARRAY['HOME', 'FLEET', 'SECURITY', 'painel de devices', 'fila de provisioning']::TEXT[], ARRAY['iot_device_registry', 'iot_sensor_events']::TEXT[], ARRAY['device_traceability', 'telemetry_retention', 'access_control']::TEXT[], 'READY'::domain_delivery_package_status_enum, '{"$schema":"https://json-schema.org/draft/2020-12/schema","additionalProperties":false,"properties":{"aggregate_id":{"format":"uuid","type":"string"},"aggregate_type":{"type":"string"},"compliance_tags":{"default":["device_traceability","telemetry_retention","access_control"],"items":{"type":"string"},"type":"array"},"delivery_phase":{"const":"VALIDATE"},"domain_key":{"const":"frontier_iot_energy"},"event_id":{"format":"uuid","type":"string"},"event_topic":{"const":"iot.sensor.event_ingested"},"evidence_refs":{"items":{"enum":["iot_device_registry","iot_sensor_events"],"type":"string"},"minItems":1,"type":"array"},"module_code":{"const":"IOT"},"occurred_at":{"format":"date-time","type":"string"},"payload":{"additionalProperties":true,"properties":{"capability":{"enum":["registry de device","eventos de sensor","hub conectado"],"type":"string"},"details":{"additionalProperties":true,"type":"object"},"primary_actor":{"enum":["operador de dispositivos","tecnico de campo","motor de automacao"],"type":"string"},"status":{"type":"string"}},"type":"object"},"trace_id":{"format":"uuid","type":"string"},"user_id":{"format":"uuid","type":"string"}},"required":["event_id","event_topic","module_code","domain_key","user_id","occurred_at","payload","evidence_refs"],"title":"IOT::iot.sensor.event_ingested","type":"object"}'::JSONB, 'contracts/events/priority-domains/frontier_iot_energy.json'),
    ('IOT:iot.device.offline_detected:v1', 'frontier_iot_energy.priority.v1', 'frontier_iot_energy', 'IOT', 'iot.device.offline_detected', '1.0.0', 'painel de devices', ARRAY['HOME', 'FLEET', 'SECURITY', 'painel de devices', 'fila de provisioning']::TEXT[], ARRAY['iot_device_registry', 'iot_sensor_events']::TEXT[], ARRAY['device_traceability', 'telemetry_retention', 'access_control']::TEXT[], 'READY'::domain_delivery_package_status_enum, '{"$schema":"https://json-schema.org/draft/2020-12/schema","additionalProperties":false,"properties":{"aggregate_id":{"format":"uuid","type":"string"},"aggregate_type":{"type":"string"},"compliance_tags":{"default":["device_traceability","telemetry_retention","access_control"],"items":{"type":"string"},"type":"array"},"delivery_phase":{"const":"VALIDATE"},"domain_key":{"const":"frontier_iot_energy"},"event_id":{"format":"uuid","type":"string"},"event_topic":{"const":"iot.device.offline_detected"},"evidence_refs":{"items":{"enum":["iot_device_registry","iot_sensor_events"],"type":"string"},"minItems":1,"type":"array"},"module_code":{"const":"IOT"},"occurred_at":{"format":"date-time","type":"string"},"payload":{"additionalProperties":true,"properties":{"capability":{"enum":["registry de device","eventos de sensor","hub conectado"],"type":"string"},"details":{"additionalProperties":true,"type":"object"},"primary_actor":{"enum":["operador de dispositivos","tecnico de campo","motor de automacao"],"type":"string"},"status":{"type":"string"}},"type":"object"},"trace_id":{"format":"uuid","type":"string"},"user_id":{"format":"uuid","type":"string"}},"required":["event_id","event_topic","module_code","domain_key","user_id","occurred_at","payload","evidence_refs"],"title":"IOT::iot.device.offline_detected","type":"object"}'::JSONB, 'contracts/events/priority-domains/frontier_iot_energy.json'),
    ('BIO:bio.program.opened:v1', 'frontier_iot_energy.priority.v1', 'frontier_iot_energy', 'BIO', 'bio.program.opened', '1.0.0', 'painel ambiental', ARRAY['IOT', 'ENERGY', 'painel ambiental', 'fila de coleta']::TEXT[], ARRAY['bio_material_programs', 'bio_collection_orders', 'bio_collection_events', 'bio_impact_logs', 'iot_sensor_events']::TEXT[], ARRAY['reverse_logistics_traceability', 'impact_audit', 'chain_of_custody']::TEXT[], 'READY'::domain_delivery_package_status_enum, '{"$schema":"https://json-schema.org/draft/2020-12/schema","additionalProperties":false,"properties":{"aggregate_id":{"format":"uuid","type":"string"},"aggregate_type":{"type":"string"},"compliance_tags":{"default":["reverse_logistics_traceability","impact_audit","chain_of_custody"],"items":{"type":"string"},"type":"array"},"delivery_phase":{"const":"VALIDATE"},"domain_key":{"const":"frontier_iot_energy"},"event_id":{"format":"uuid","type":"string"},"event_topic":{"const":"bio.program.opened"},"evidence_refs":{"items":{"enum":["bio_material_programs","bio_collection_orders","bio_collection_events","bio_impact_logs","iot_sensor_events"],"type":"string"},"minItems":1,"type":"array"},"module_code":{"const":"BIO"},"occurred_at":{"format":"date-time","type":"string"},"payload":{"additionalProperties":true,"properties":{"capability":{"enum":["programas de material","ordem de coleta reversa","log de impacto"],"type":"string"},"details":{"additionalProperties":true,"type":"object"},"primary_actor":{"enum":["operador de coleta","parceiro ambiental","auditor de impacto"],"type":"string"},"status":{"type":"string"}},"type":"object"},"trace_id":{"format":"uuid","type":"string"},"user_id":{"format":"uuid","type":"string"}},"required":["event_id","event_topic","module_code","domain_key","user_id","occurred_at","payload","evidence_refs"],"title":"BIO::bio.program.opened","type":"object"}'::JSONB, 'contracts/events/priority-domains/frontier_iot_energy.json'),
    ('BIO:bio.collection.scheduled:v1', 'frontier_iot_energy.priority.v1', 'frontier_iot_energy', 'BIO', 'bio.collection.scheduled', '1.0.0', 'painel ambiental', ARRAY['IOT', 'ENERGY', 'painel ambiental', 'fila de coleta']::TEXT[], ARRAY['bio_material_programs', 'bio_collection_orders', 'bio_collection_events', 'bio_impact_logs', 'iot_sensor_events']::TEXT[], ARRAY['reverse_logistics_traceability', 'impact_audit', 'chain_of_custody']::TEXT[], 'READY'::domain_delivery_package_status_enum, '{"$schema":"https://json-schema.org/draft/2020-12/schema","additionalProperties":false,"properties":{"aggregate_id":{"format":"uuid","type":"string"},"aggregate_type":{"type":"string"},"compliance_tags":{"default":["reverse_logistics_traceability","impact_audit","chain_of_custody"],"items":{"type":"string"},"type":"array"},"delivery_phase":{"const":"VALIDATE"},"domain_key":{"const":"frontier_iot_energy"},"event_id":{"format":"uuid","type":"string"},"event_topic":{"const":"bio.collection.scheduled"},"evidence_refs":{"items":{"enum":["bio_material_programs","bio_collection_orders","bio_collection_events","bio_impact_logs","iot_sensor_events"],"type":"string"},"minItems":1,"type":"array"},"module_code":{"const":"BIO"},"occurred_at":{"format":"date-time","type":"string"},"payload":{"additionalProperties":true,"properties":{"capability":{"enum":["programas de material","ordem de coleta reversa","log de impacto"],"type":"string"},"details":{"additionalProperties":true,"type":"object"},"primary_actor":{"enum":["operador de coleta","parceiro ambiental","auditor de impacto"],"type":"string"},"status":{"type":"string"}},"type":"object"},"trace_id":{"format":"uuid","type":"string"},"user_id":{"format":"uuid","type":"string"}},"required":["event_id","event_topic","module_code","domain_key","user_id","occurred_at","payload","evidence_refs"],"title":"BIO::bio.collection.scheduled","type":"object"}'::JSONB, 'contracts/events/priority-domains/frontier_iot_energy.json'),
    ('BIO:bio.impact.measured:v1', 'frontier_iot_energy.priority.v1', 'frontier_iot_energy', 'BIO', 'bio.impact.measured', '1.0.0', 'painel ambiental', ARRAY['IOT', 'ENERGY', 'painel ambiental', 'fila de coleta']::TEXT[], ARRAY['bio_material_programs', 'bio_collection_orders', 'bio_collection_events', 'bio_impact_logs', 'iot_sensor_events']::TEXT[], ARRAY['reverse_logistics_traceability', 'impact_audit', 'chain_of_custody']::TEXT[], 'READY'::domain_delivery_package_status_enum, '{"$schema":"https://json-schema.org/draft/2020-12/schema","additionalProperties":false,"properties":{"aggregate_id":{"format":"uuid","type":"string"},"aggregate_type":{"type":"string"},"compliance_tags":{"default":["reverse_logistics_traceability","impact_audit","chain_of_custody"],"items":{"type":"string"},"type":"array"},"delivery_phase":{"const":"VALIDATE"},"domain_key":{"const":"frontier_iot_energy"},"event_id":{"format":"uuid","type":"string"},"event_topic":{"const":"bio.impact.measured"},"evidence_refs":{"items":{"enum":["bio_material_programs","bio_collection_orders","bio_collection_events","bio_impact_logs","iot_sensor_events"],"type":"string"},"minItems":1,"type":"array"},"module_code":{"const":"BIO"},"occurred_at":{"format":"date-time","type":"string"},"payload":{"additionalProperties":true,"properties":{"capability":{"enum":["programas de material","ordem de coleta reversa","log de impacto"],"type":"string"},"details":{"additionalProperties":true,"type":"object"},"primary_actor":{"enum":["operador de coleta","parceiro ambiental","auditor de impacto"],"type":"string"},"status":{"type":"string"}},"type":"object"},"trace_id":{"format":"uuid","type":"string"},"user_id":{"format":"uuid","type":"string"}},"required":["event_id","event_topic","module_code","domain_key","user_id","occurred_at","payload","evidence_refs"],"title":"BIO::bio.impact.measured","type":"object"}'::JSONB, 'contracts/events/priority-domains/frontier_iot_energy.json'),
    ('HOME:home.device.bound:v1', 'frontier_iot_energy.priority.v1', 'frontier_iot_energy', 'HOME', 'home.device.bound', '1.0.0', 'painel de residencia', ARRAY['SECURITY', 'ENERGY', 'painel de residencia', 'console de automacao']::TEXT[], ARRAY['home_automation_events', 'iot_device_registry']::TEXT[], ARRAY['household_access_control', 'event_retention', 'device_safety']::TEXT[], 'READY'::domain_delivery_package_status_enum, '{"$schema":"https://json-schema.org/draft/2020-12/schema","additionalProperties":false,"properties":{"aggregate_id":{"format":"uuid","type":"string"},"aggregate_type":{"type":"string"},"compliance_tags":{"default":["household_access_control","event_retention","device_safety"],"items":{"type":"string"},"type":"array"},"delivery_phase":{"const":"VALIDATE"},"domain_key":{"const":"frontier_iot_energy"},"event_id":{"format":"uuid","type":"string"},"event_topic":{"const":"home.device.bound"},"evidence_refs":{"items":{"enum":["home_automation_events","iot_device_registry"],"type":"string"},"minItems":1,"type":"array"},"module_code":{"const":"HOME"},"occurred_at":{"format":"date-time","type":"string"},"payload":{"additionalProperties":true,"properties":{"capability":{"enum":["automacao residencial","eventos domesticos","regras de cena"],"type":"string"},"details":{"additionalProperties":true,"type":"object"},"primary_actor":{"enum":["morador","instalador","operador smart home"],"type":"string"},"status":{"type":"string"}},"type":"object"},"trace_id":{"format":"uuid","type":"string"},"user_id":{"format":"uuid","type":"string"}},"required":["event_id","event_topic","module_code","domain_key","user_id","occurred_at","payload","evidence_refs"],"title":"HOME::home.device.bound","type":"object"}'::JSONB, 'contracts/events/priority-domains/frontier_iot_energy.json'),
    ('HOME:home.scene.executed:v1', 'frontier_iot_energy.priority.v1', 'frontier_iot_energy', 'HOME', 'home.scene.executed', '1.0.0', 'painel de residencia', ARRAY['SECURITY', 'ENERGY', 'painel de residencia', 'console de automacao']::TEXT[], ARRAY['home_automation_events', 'iot_device_registry']::TEXT[], ARRAY['household_access_control', 'event_retention', 'device_safety']::TEXT[], 'READY'::domain_delivery_package_status_enum, '{"$schema":"https://json-schema.org/draft/2020-12/schema","additionalProperties":false,"properties":{"aggregate_id":{"format":"uuid","type":"string"},"aggregate_type":{"type":"string"},"compliance_tags":{"default":["household_access_control","event_retention","device_safety"],"items":{"type":"string"},"type":"array"},"delivery_phase":{"const":"VALIDATE"},"domain_key":{"const":"frontier_iot_energy"},"event_id":{"format":"uuid","type":"string"},"event_topic":{"const":"home.scene.executed"},"evidence_refs":{"items":{"enum":["home_automation_events","iot_device_registry"],"type":"string"},"minItems":1,"type":"array"},"module_code":{"const":"HOME"},"occurred_at":{"format":"date-time","type":"string"},"payload":{"additionalProperties":true,"properties":{"capability":{"enum":["automacao residencial","eventos domesticos","regras de cena"],"type":"string"},"details":{"additionalProperties":true,"type":"object"},"primary_actor":{"enum":["morador","instalador","operador smart home"],"type":"string"},"status":{"type":"string"}},"type":"object"},"trace_id":{"format":"uuid","type":"string"},"user_id":{"format":"uuid","type":"string"}},"required":["event_id","event_topic","module_code","domain_key","user_id","occurred_at","payload","evidence_refs"],"title":"HOME::home.scene.executed","type":"object"}'::JSONB, 'contracts/events/priority-domains/frontier_iot_energy.json'),
    ('HOME:home.alert.triggered:v1', 'frontier_iot_energy.priority.v1', 'frontier_iot_energy', 'HOME', 'home.alert.triggered', '1.0.0', 'painel de residencia', ARRAY['SECURITY', 'ENERGY', 'painel de residencia', 'console de automacao']::TEXT[], ARRAY['home_automation_events', 'iot_device_registry']::TEXT[], ARRAY['household_access_control', 'event_retention', 'device_safety']::TEXT[], 'READY'::domain_delivery_package_status_enum, '{"$schema":"https://json-schema.org/draft/2020-12/schema","additionalProperties":false,"properties":{"aggregate_id":{"format":"uuid","type":"string"},"aggregate_type":{"type":"string"},"compliance_tags":{"default":["household_access_control","event_retention","device_safety"],"items":{"type":"string"},"type":"array"},"delivery_phase":{"const":"VALIDATE"},"domain_key":{"const":"frontier_iot_energy"},"event_id":{"format":"uuid","type":"string"},"event_topic":{"const":"home.alert.triggered"},"evidence_refs":{"items":{"enum":["home_automation_events","iot_device_registry"],"type":"string"},"minItems":1,"type":"array"},"module_code":{"const":"HOME"},"occurred_at":{"format":"date-time","type":"string"},"payload":{"additionalProperties":true,"properties":{"capability":{"enum":["automacao residencial","eventos domesticos","regras de cena"],"type":"string"},"details":{"additionalProperties":true,"type":"object"},"primary_actor":{"enum":["morador","instalador","operador smart home"],"type":"string"},"status":{"type":"string"}},"type":"object"},"trace_id":{"format":"uuid","type":"string"},"user_id":{"format":"uuid","type":"string"}},"required":["event_id","event_topic","module_code","domain_key","user_id","occurred_at","payload","evidence_refs"],"title":"HOME::home.alert.triggered","type":"object"}'::JSONB, 'contracts/events/priority-domains/frontier_iot_energy.json'),
    ('ENERGY:energy.asset.registered:v1', 'frontier_iot_energy.priority.v1', 'frontier_iot_energy', 'ENERGY', 'energy.asset.registered', '1.0.0', 'painel de ativos', ARRAY['BIO', 'HOME', 'painel de ativos', 'monitor de trades']::TEXT[], ARRAY['energy_assets', 'energy_trade_orders', 'energy_settlement_ledger', 'energy_meter_streams', 'iot_sensor_events']::TEXT[], ARRAY['meter_traceability', 'financial_settlement_immutability', 'grid_compliance']::TEXT[], 'READY'::domain_delivery_package_status_enum, '{"$schema":"https://json-schema.org/draft/2020-12/schema","additionalProperties":false,"properties":{"aggregate_id":{"format":"uuid","type":"string"},"aggregate_type":{"type":"string"},"compliance_tags":{"default":["meter_traceability","financial_settlement_immutability","grid_compliance"],"items":{"type":"string"},"type":"array"},"delivery_phase":{"const":"VALIDATE"},"domain_key":{"const":"frontier_iot_energy"},"event_id":{"format":"uuid","type":"string"},"event_topic":{"const":"energy.asset.registered"},"evidence_refs":{"items":{"enum":["energy_assets","energy_trade_orders","energy_settlement_ledger","energy_meter_streams","iot_sensor_events"],"type":"string"},"minItems":1,"type":"array"},"module_code":{"const":"ENERGY"},"occurred_at":{"format":"date-time","type":"string"},"payload":{"additionalProperties":true,"properties":{"capability":{"enum":["ativos de energia","trade P2P","settlement auditavel"],"type":"string"},"details":{"additionalProperties":true,"type":"object"},"primary_actor":{"enum":["prosumidor","operador de grid","analista de settlement"],"type":"string"},"status":{"type":"string"}},"type":"object"},"trace_id":{"format":"uuid","type":"string"},"user_id":{"format":"uuid","type":"string"}},"required":["event_id","event_topic","module_code","domain_key","user_id","occurred_at","payload","evidence_refs"],"title":"ENERGY::energy.asset.registered","type":"object"}'::JSONB, 'contracts/events/priority-domains/frontier_iot_energy.json'),
    ('ENERGY:energy.trade.matched:v1', 'frontier_iot_energy.priority.v1', 'frontier_iot_energy', 'ENERGY', 'energy.trade.matched', '1.0.0', 'painel de ativos', ARRAY['BIO', 'HOME', 'painel de ativos', 'monitor de trades']::TEXT[], ARRAY['energy_assets', 'energy_trade_orders', 'energy_settlement_ledger', 'energy_meter_streams', 'iot_sensor_events']::TEXT[], ARRAY['meter_traceability', 'financial_settlement_immutability', 'grid_compliance']::TEXT[], 'READY'::domain_delivery_package_status_enum, '{"$schema":"https://json-schema.org/draft/2020-12/schema","additionalProperties":false,"properties":{"aggregate_id":{"format":"uuid","type":"string"},"aggregate_type":{"type":"string"},"compliance_tags":{"default":["meter_traceability","financial_settlement_immutability","grid_compliance"],"items":{"type":"string"},"type":"array"},"delivery_phase":{"const":"VALIDATE"},"domain_key":{"const":"frontier_iot_energy"},"event_id":{"format":"uuid","type":"string"},"event_topic":{"const":"energy.trade.matched"},"evidence_refs":{"items":{"enum":["energy_assets","energy_trade_orders","energy_settlement_ledger","energy_meter_streams","iot_sensor_events"],"type":"string"},"minItems":1,"type":"array"},"module_code":{"const":"ENERGY"},"occurred_at":{"format":"date-time","type":"string"},"payload":{"additionalProperties":true,"properties":{"capability":{"enum":["ativos de energia","trade P2P","settlement auditavel"],"type":"string"},"details":{"additionalProperties":true,"type":"object"},"primary_actor":{"enum":["prosumidor","operador de grid","analista de settlement"],"type":"string"},"status":{"type":"string"}},"type":"object"},"trace_id":{"format":"uuid","type":"string"},"user_id":{"format":"uuid","type":"string"}},"required":["event_id","event_topic","module_code","domain_key","user_id","occurred_at","payload","evidence_refs"],"title":"ENERGY::energy.trade.matched","type":"object"}'::JSONB, 'contracts/events/priority-domains/frontier_iot_energy.json'),
    ('ENERGY:energy.settlement.posted:v1', 'frontier_iot_energy.priority.v1', 'frontier_iot_energy', 'ENERGY', 'energy.settlement.posted', '1.0.0', 'painel de ativos', ARRAY['BIO', 'HOME', 'painel de ativos', 'monitor de trades']::TEXT[], ARRAY['energy_assets', 'energy_trade_orders', 'energy_settlement_ledger', 'energy_meter_streams', 'iot_sensor_events']::TEXT[], ARRAY['meter_traceability', 'financial_settlement_immutability', 'grid_compliance']::TEXT[], 'READY'::domain_delivery_package_status_enum, '{"$schema":"https://json-schema.org/draft/2020-12/schema","additionalProperties":false,"properties":{"aggregate_id":{"format":"uuid","type":"string"},"aggregate_type":{"type":"string"},"compliance_tags":{"default":["meter_traceability","financial_settlement_immutability","grid_compliance"],"items":{"type":"string"},"type":"array"},"delivery_phase":{"const":"VALIDATE"},"domain_key":{"const":"frontier_iot_energy"},"event_id":{"format":"uuid","type":"string"},"event_topic":{"const":"energy.settlement.posted"},"evidence_refs":{"items":{"enum":["energy_assets","energy_trade_orders","energy_settlement_ledger","energy_meter_streams","iot_sensor_events"],"type":"string"},"minItems":1,"type":"array"},"module_code":{"const":"ENERGY"},"occurred_at":{"format":"date-time","type":"string"},"payload":{"additionalProperties":true,"properties":{"capability":{"enum":["ativos de energia","trade P2P","settlement auditavel"],"type":"string"},"details":{"additionalProperties":true,"type":"object"},"primary_actor":{"enum":["prosumidor","operador de grid","analista de settlement"],"type":"string"},"status":{"type":"string"}},"type":"object"},"trace_id":{"format":"uuid","type":"string"},"user_id":{"format":"uuid","type":"string"}},"required":["event_id","event_topic","module_code","domain_key","user_id","occurred_at","payload","evidence_refs"],"title":"ENERGY::energy.settlement.posted","type":"object"}'::JSONB, 'contracts/events/priority-domains/frontier_iot_energy.json'),
    ('SPACE:space.anchor.created:v1', 'frontier_iot_energy.priority.v1', 'frontier_iot_energy', 'SPACE', 'space.anchor.created', '1.0.0', 'painel AR', ARRAY['SOCIAL', 'TOURISM', 'painel AR', 'monitor de ancoras']::TEXT[], ARRAY['space_anchor_maps', 'social_videos']::TEXT[], ARRAY['location_privacy', 'content_safety', 'creator_traceability']::TEXT[], 'READY'::domain_delivery_package_status_enum, '{"$schema":"https://json-schema.org/draft/2020-12/schema","additionalProperties":false,"properties":{"aggregate_id":{"format":"uuid","type":"string"},"aggregate_type":{"type":"string"},"compliance_tags":{"default":["location_privacy","content_safety","creator_traceability"],"items":{"type":"string"},"type":"array"},"delivery_phase":{"const":"VALIDATE"},"domain_key":{"const":"frontier_iot_energy"},"event_id":{"format":"uuid","type":"string"},"event_topic":{"const":"space.anchor.created"},"evidence_refs":{"items":{"enum":["space_anchor_maps","social_videos"],"type":"string"},"minItems":1,"type":"array"},"module_code":{"const":"SPACE"},"occurred_at":{"format":"date-time","type":"string"},"payload":{"additionalProperties":true,"properties":{"capability":{"enum":["ancoras espaciais","camadas AR","experiencias geolocalizadas"],"type":"string"},"details":{"additionalProperties":true,"type":"object"},"primary_actor":{"enum":["explorador","criador AR","operador de mapa"],"type":"string"},"status":{"type":"string"}},"type":"object"},"trace_id":{"format":"uuid","type":"string"},"user_id":{"format":"uuid","type":"string"}},"required":["event_id","event_topic","module_code","domain_key","user_id","occurred_at","payload","evidence_refs"],"title":"SPACE::space.anchor.created","type":"object"}'::JSONB, 'contracts/events/priority-domains/frontier_iot_energy.json'),
    ('SPACE:space.anchor.visited:v1', 'frontier_iot_energy.priority.v1', 'frontier_iot_energy', 'SPACE', 'space.anchor.visited', '1.0.0', 'painel AR', ARRAY['SOCIAL', 'TOURISM', 'painel AR', 'monitor de ancoras']::TEXT[], ARRAY['space_anchor_maps', 'social_videos']::TEXT[], ARRAY['location_privacy', 'content_safety', 'creator_traceability']::TEXT[], 'READY'::domain_delivery_package_status_enum, '{"$schema":"https://json-schema.org/draft/2020-12/schema","additionalProperties":false,"properties":{"aggregate_id":{"format":"uuid","type":"string"},"aggregate_type":{"type":"string"},"compliance_tags":{"default":["location_privacy","content_safety","creator_traceability"],"items":{"type":"string"},"type":"array"},"delivery_phase":{"const":"VALIDATE"},"domain_key":{"const":"frontier_iot_energy"},"event_id":{"format":"uuid","type":"string"},"event_topic":{"const":"space.anchor.visited"},"evidence_refs":{"items":{"enum":["space_anchor_maps","social_videos"],"type":"string"},"minItems":1,"type":"array"},"module_code":{"const":"SPACE"},"occurred_at":{"format":"date-time","type":"string"},"payload":{"additionalProperties":true,"properties":{"capability":{"enum":["ancoras espaciais","camadas AR","experiencias geolocalizadas"],"type":"string"},"details":{"additionalProperties":true,"type":"object"},"primary_actor":{"enum":["explorador","criador AR","operador de mapa"],"type":"string"},"status":{"type":"string"}},"type":"object"},"trace_id":{"format":"uuid","type":"string"},"user_id":{"format":"uuid","type":"string"}},"required":["event_id","event_topic","module_code","domain_key","user_id","occurred_at","payload","evidence_refs"],"title":"SPACE::space.anchor.visited","type":"object"}'::JSONB, 'contracts/events/priority-domains/frontier_iot_energy.json'),
    ('SPACE:space.layer.published:v1', 'frontier_iot_energy.priority.v1', 'frontier_iot_energy', 'SPACE', 'space.layer.published', '1.0.0', 'painel AR', ARRAY['SOCIAL', 'TOURISM', 'painel AR', 'monitor de ancoras']::TEXT[], ARRAY['space_anchor_maps', 'social_videos']::TEXT[], ARRAY['location_privacy', 'content_safety', 'creator_traceability']::TEXT[], 'READY'::domain_delivery_package_status_enum, '{"$schema":"https://json-schema.org/draft/2020-12/schema","additionalProperties":false,"properties":{"aggregate_id":{"format":"uuid","type":"string"},"aggregate_type":{"type":"string"},"compliance_tags":{"default":["location_privacy","content_safety","creator_traceability"],"items":{"type":"string"},"type":"array"},"delivery_phase":{"const":"VALIDATE"},"domain_key":{"const":"frontier_iot_energy"},"event_id":{"format":"uuid","type":"string"},"event_topic":{"const":"space.layer.published"},"evidence_refs":{"items":{"enum":["space_anchor_maps","social_videos"],"type":"string"},"minItems":1,"type":"array"},"module_code":{"const":"SPACE"},"occurred_at":{"format":"date-time","type":"string"},"payload":{"additionalProperties":true,"properties":{"capability":{"enum":["ancoras espaciais","camadas AR","experiencias geolocalizadas"],"type":"string"},"details":{"additionalProperties":true,"type":"object"},"primary_actor":{"enum":["explorador","criador AR","operador de mapa"],"type":"string"},"status":{"type":"string"}},"type":"object"},"trace_id":{"format":"uuid","type":"string"},"user_id":{"format":"uuid","type":"string"}},"required":["event_id","event_topic","module_code","domain_key","user_id","occurred_at","payload","evidence_refs"],"title":"SPACE::space.layer.published","type":"object"}'::JSONB, 'contracts/events/priority-domains/frontier_iot_energy.json')
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
