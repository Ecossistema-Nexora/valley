BEGIN;

-- Pacote evoluido manualmente para AI Memory Operations.
-- Artefato: ai_memory_operations.priority.v1
-- Dependencias: migrations 016 e 017 aplicadas.

CREATE OR REPLACE VIEW v_ai_memory_operations_priority_backlog AS
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
WHERE backlog.backlog_group = 'ai_memory_operations'
  AND backlog.origin_source = 'blueprint_execution_v1';

CREATE OR REPLACE VIEW v_ai_memory_operations_delivery_artifacts AS
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
WHERE domain_key = 'ai_memory_operations';

CREATE OR REPLACE VIEW v_ai_memory_operations_event_contracts AS
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
WHERE domain_key = 'ai_memory_operations';

CREATE OR REPLACE VIEW v_ai_memory_operations_advisor_ops AS
WITH goal_summary AS (
    SELECT
        user_id,
        COUNT(*) AS goal_count,
        COUNT(*) FILTER (
            WHERE goal_status = 'ACTIVE'::financial_goal_status_enum
        ) AS active_goal_count,
        COALESCE(SUM(target_amount_brl), 0.0000)::DECIMAL(18,4) AS tracked_target_amount_brl,
        COALESCE(SUM(current_amount_brl), 0.0000)::DECIMAL(18,4) AS tracked_current_amount_brl,
        MAX(deadline) AS latest_deadline
    FROM financial_goals
    GROUP BY user_id
)
SELECT
    insight.insight_id,
    insight.user_id,
    insight.insight_category,
    insight.source_module,
    insight.suggested_action,
    insight.potential_savings_brl,
    insight.is_executed,
    insight.consent_required,
    insight.execution_consented_at,
    CASE
        WHEN insight.is_executed THEN 'EXECUTED'
        WHEN insight.consent_required = FALSE THEN 'AUTO_EXECUTABLE'
        WHEN insight.execution_consented_at IS NOT NULL THEN 'CONSENTED_PENDING_EXECUTION'
        ELSE 'AWAITING_CONSENT'
    END AS consent_state,
    COALESCE(goal.goal_count, 0) AS goal_count,
    COALESCE(goal.active_goal_count, 0) AS active_goal_count,
    COALESCE(goal.tracked_target_amount_brl, 0.0000)::DECIMAL(18,4) AS tracked_target_amount_brl,
    COALESCE(goal.tracked_current_amount_brl, 0.0000)::DECIMAL(18,4) AS tracked_current_amount_brl,
    goal.latest_deadline,
    insight.created_at,
    insight.updated_at
FROM advisor_insights AS insight
LEFT JOIN goal_summary AS goal
  ON goal.user_id = insight.user_id;

CREATE OR REPLACE VIEW v_ai_memory_operations_chat_ops AS
SELECT
    conversation.conversation_id,
    conversation.participant1_id,
    conversation.participant2_id,
    COUNT(message.message_id) AS message_count,
    COUNT(*) FILTER (
        WHERE message.persona = 'PERSONAL'::chat_persona_enum
    ) AS personal_message_count,
    COUNT(*) FILTER (
        WHERE message.persona = 'PROFESSIONAL'::chat_persona_enum
    ) AS professional_message_count,
    MIN(message.created_at) FILTER (
        WHERE message.message_id IS NOT NULL
    ) AS first_message_at,
    MAX(message.created_at) FILTER (
        WHERE message.message_id IS NOT NULL
    ) AS last_message_at,
    BOOL_OR(message.persona = 'PERSONAL'::chat_persona_enum) AS has_personal_context,
    BOOL_OR(message.persona = 'PROFESSIONAL'::chat_persona_enum) AS has_professional_context
FROM chat_conversations AS conversation
LEFT JOIN chat_messages AS message
  ON message.conversation_id = conversation.conversation_id
WHERE conversation.deleted_at IS NULL
GROUP BY
    conversation.conversation_id,
    conversation.participant1_id,
    conversation.participant2_id;

CREATE OR REPLACE VIEW v_ai_memory_operations_consent_queue AS
WITH conversation_users AS (
    SELECT
        conversation_id,
        participant1_id AS user_id
    FROM chat_conversations
    WHERE deleted_at IS NULL
    UNION ALL
    SELECT
        conversation_id,
        participant2_id AS user_id
    FROM chat_conversations
    WHERE deleted_at IS NULL
),
message_summary AS (
    SELECT
        conversation_user.user_id,
        COUNT(message.message_id) AS related_message_count,
        MAX(message.created_at) AS last_message_at
    FROM conversation_users AS conversation_user
    LEFT JOIN chat_messages AS message
      ON message.conversation_id = conversation_user.conversation_id
    GROUP BY conversation_user.user_id
)
SELECT
    insight.insight_id,
    insight.user_id,
    insight.source_module,
    insight.insight_category,
    insight.suggested_action,
    insight.potential_savings_brl,
    COALESCE(messages.related_message_count, 0) AS related_message_count,
    messages.last_message_at,
    latest_goal.goal_status,
    latest_goal.deadline,
    insight.created_at AS insight_created_at
FROM advisor_insights AS insight
LEFT JOIN LATERAL (
    SELECT
        goal_status,
        deadline
    FROM financial_goals AS goal
    WHERE goal.user_id = insight.user_id
    ORDER BY goal.updated_at DESC, goal.created_at DESC
    LIMIT 1
) AS latest_goal
  ON TRUE
LEFT JOIN message_summary AS messages
  ON messages.user_id = insight.user_id
WHERE insight.consent_required = TRUE
  AND insight.is_executed = FALSE
  AND insight.execution_consented_at IS NULL;

CREATE OR REPLACE VIEW v_ai_memory_operations_user_context_ops AS
WITH insight_summary AS (
    SELECT
        user_id,
        COUNT(*) FILTER (
            WHERE is_executed = FALSE
        ) AS open_insights,
        COUNT(*) FILTER (
            WHERE is_executed = TRUE
        ) AS executed_insights,
        MAX(created_at) AS last_insight_at
    FROM advisor_insights
    GROUP BY user_id
),
goal_summary AS (
    SELECT
        user_id,
        COUNT(*) FILTER (
            WHERE goal_status = 'ACTIVE'::financial_goal_status_enum
        ) AS active_goals,
        COALESCE(SUM(target_amount_brl), 0.0000)::DECIMAL(18,4) AS target_amount_brl,
        COALESCE(SUM(current_amount_brl), 0.0000)::DECIMAL(18,4) AS current_amount_brl,
        MAX(deadline) AS next_deadline
    FROM financial_goals
    GROUP BY user_id
),
conversation_users AS (
    SELECT
        conversation_id,
        participant1_id AS user_id
    FROM chat_conversations
    WHERE deleted_at IS NULL
    UNION ALL
    SELECT
        conversation_id,
        participant2_id AS user_id
    FROM chat_conversations
    WHERE deleted_at IS NULL
),
chat_summary AS (
    SELECT
        conversation_user.user_id,
        COUNT(DISTINCT conversation_user.conversation_id) AS conversation_count,
        COUNT(message.message_id) AS total_messages,
        MAX(message.created_at) AS last_message_at
    FROM conversation_users AS conversation_user
    LEFT JOIN chat_messages AS message
      ON message.conversation_id = conversation_user.conversation_id
    GROUP BY conversation_user.user_id
)
SELECT
    user_row.user_id,
    user_row.display_name,
    user_row.primary_role,
    COALESCE(insight.open_insights, 0) AS open_insights,
    COALESCE(insight.executed_insights, 0) AS executed_insights,
    COALESCE(goal.active_goals, 0) AS active_goals,
    COALESCE(goal.target_amount_brl, 0.0000)::DECIMAL(18,4) AS target_amount_brl,
    COALESCE(goal.current_amount_brl, 0.0000)::DECIMAL(18,4) AS current_amount_brl,
    COALESCE(chat.conversation_count, 0) AS conversation_count,
    COALESCE(chat.total_messages, 0) AS total_messages,
    insight.last_insight_at,
    goal.next_deadline,
    chat.last_message_at,
    ARRAY[
        'advisor_insights',
        'financial_goals',
        'chat_conversations',
        'chat_messages',
        'ai_memory',
        'agenda_items'
    ]::TEXT[] AS context_surfaces
FROM users AS user_row
LEFT JOIN insight_summary AS insight
  ON insight.user_id = user_row.user_id
LEFT JOIN goal_summary AS goal
  ON goal.user_id = user_row.user_id
LEFT JOIN chat_summary AS chat
  ON chat.user_id = user_row.user_id
WHERE user_row.user_id IN (
    SELECT user_id FROM advisor_insights
    UNION
    SELECT user_id FROM financial_goals
    UNION
    SELECT participant1_id FROM chat_conversations
    UNION
    SELECT participant2_id FROM chat_conversations
);

COMMENT ON VIEW v_ai_memory_operations_priority_backlog IS
    'Visao operacional do backlog prioritario do dominio ai_memory_operations.';

COMMENT ON VIEW v_ai_memory_operations_delivery_artifacts IS
    'Visao dos artefatos fisicos por camada do dominio ai_memory_operations.';

COMMENT ON VIEW v_ai_memory_operations_event_contracts IS
    'Visao dos contratos de evento exportados do dominio ai_memory_operations.';

COMMENT ON VIEW v_ai_memory_operations_advisor_ops IS
    'Pipeline operacional do Advisor com contexto financeiro e estado de consentimento.';

COMMENT ON VIEW v_ai_memory_operations_chat_ops IS
    'Operacao real das conversas, personas e cadencia de mensagens do dominio AI Memory.';

COMMENT ON VIEW v_ai_memory_operations_consent_queue IS
    'Fila de insights aguardando consentimento, com contexto de goal e ultimo contato.';

COMMENT ON VIEW v_ai_memory_operations_user_context_ops IS
    'Resumo por usuario do contexto cruzado entre Advisor, Goals, Chat, Memory e Agenda.';

COMMIT;
