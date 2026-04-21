BEGIN;

-- Pacote complementar do dominio Platform Developer.
-- DDL real materializado em:
--   - database/postgres/018_v47_platform_developer_business_ddl.sql
--   - database/postgres/017_v47_priority_domain_delivery_packages.sql

CREATE OR REPLACE VIEW v_platform_developer_docs_templates AS
SELECT
    contract.template_contract_id,
    contract.template_name,
    contract.template_scope,
    contract.template_status,
    contract.published_version_number,
    contract.render_engine,
    versions.version_count,
    versions.published_versions,
    contract.updated_at
FROM docs_template_contracts AS contract
LEFT JOIN (
    SELECT
        template_contract_id,
        COUNT(*) AS version_count,
        COUNT(*) FILTER (WHERE version_status = 'PUBLISHED') AS published_versions
    FROM docs_template_versions
    GROUP BY template_contract_id
) AS versions
    ON versions.template_contract_id = contract.template_contract_id;

CREATE OR REPLACE VIEW v_platform_developer_checksum_chain AS
SELECT
    checksum_event_id,
    document_id,
    receipt_id,
    template_version_id,
    checksum_event_type,
    checksum_sha256,
    previous_checksum_event_id,
    reference_event_topic,
    occurred_at
FROM docs_document_checksum_events
ORDER BY occurred_at DESC;

CREATE OR REPLACE VIEW v_platform_developer_webhook_replay_queue AS
SELECT
    replay.webhook_replay_request_id,
    replay.replay_status,
    replay.idempotency_key,
    replay.replay_reason,
    replay.requested_at,
    replay.approved_at,
    replay.replayed_at,
    replay.failed_at,
    subscription.module_code,
    subscription.target_url,
    original_attempt.event_type AS original_event_type,
    original_attempt.delivery_status AS original_delivery_status
FROM tech_webhook_replay_requests AS replay
JOIN tech_webhook_subscriptions AS subscription
  ON subscription.webhook_subscription_id = replay.webhook_subscription_id
JOIN tech_webhook_delivery_attempts AS original_attempt
  ON original_attempt.webhook_delivery_attempt_id = replay.original_delivery_attempt_id
ORDER BY replay.requested_at DESC;

COMMENT ON VIEW v_platform_developer_docs_templates IS
    'Resumo operacional dos contratos e versoes de template do dominio Platform Developer.';
COMMENT ON VIEW v_platform_developer_checksum_chain IS
    'Consulta rapida da trilha de checksum de DOCS.';
COMMENT ON VIEW v_platform_developer_webhook_replay_queue IS
    'Fila operacional de replay seguro de webhook do modulo TECH.';

COMMIT;
