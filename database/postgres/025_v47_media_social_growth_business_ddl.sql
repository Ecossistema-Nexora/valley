BEGIN;

-- Materializa views operacionais reais do dominio media_social_growth.
-- Complementa registry de entrega, creator_uploads, affiliate_referrals,
-- campaigns, GOLD e ledger de rewards.

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

CREATE OR REPLACE VIEW v_media_social_growth_creator_ops AS
WITH revenue_summary AS (
    SELECT
        user_id,
        COUNT(*) FILTER (
            WHERE transaction_status = 'SETTLED'::transaction_status_enum
        ) AS settled_revenue_events,
        COALESCE(SUM(amount_brl) FILTER (
            WHERE transaction_status = 'SETTLED'::transaction_status_enum
        ), 0.0000)::DECIMAL(18,4) AS booked_revenue_brl,
        MAX(settled_at) AS last_revenue_at
    FROM transactions
    WHERE origin_module = 'MEDIA'
    GROUP BY user_id
),
referral_summary AS (
    SELECT
        referrer_id AS user_id,
        COUNT(*) AS referral_count,
        COALESCE(SUM(commission_amount_brl), 0.0000)::DECIMAL(18,4) AS affiliate_commission_brl,
        MAX(payout_at) AS last_referral_payout_at
    FROM affiliate_referrals
    GROUP BY referrer_id
)
SELECT
    upload.upload_id,
    upload.user_id,
    upload.social_video_id,
    upload.upload_status,
    upload.monetization_enabled,
    COALESCE(revenue.settled_revenue_events, 0) AS settled_revenue_events,
    COALESCE(revenue.booked_revenue_brl, 0.0000)::DECIMAL(18,4) AS booked_revenue_brl,
    COALESCE(referral.referral_count, 0) AS referral_count,
    COALESCE(referral.affiliate_commission_brl, 0.0000)::DECIMAL(18,4) AS affiliate_commission_brl,
    GREATEST(
        COALESCE(revenue.last_revenue_at, upload.updated_at),
        COALESCE(referral.last_referral_payout_at, upload.updated_at)
    ) AS last_commercial_activity_at,
    upload.created_at,
    upload.updated_at
FROM creator_uploads AS upload
LEFT JOIN revenue_summary AS revenue
  ON revenue.user_id = upload.user_id
LEFT JOIN referral_summary AS referral
  ON referral.user_id = upload.user_id;

CREATE OR REPLACE VIEW v_media_social_growth_ads_reward_ops AS
WITH event_summary AS (
    SELECT
        gold_campaign_id,
        COUNT(*) AS event_count,
        COUNT(*) FILTER (
            WHERE event_type = 'PEPITA_GRANT'::gold_event_type_enum
        ) AS pepita_grant_events,
        COUNT(DISTINCT candidate_user_id) FILTER (
            WHERE candidate_user_id IS NOT NULL
        ) AS rewarded_users,
        COALESCE(SUM(pepita_amount_brl), 0.0000)::DECIMAL(18,4) AS granted_pepita_brl,
        COALESCE(SUM(gold_amount_brl), 0.0000)::DECIMAL(18,4) AS booked_gold_brl,
        MAX(created_at) AS last_event_at
    FROM gold_campaign_events
    GROUP BY gold_campaign_id
),
ledger_summary AS (
    SELECT
        gold_campaign_id,
        COUNT(*) AS ledger_entries,
        COALESCE(SUM(amount_brl) FILTER (
            WHERE amount_brl > 0
        ), 0.0000)::DECIMAL(18,4) AS credited_pepita_brl,
        MAX(created_at) AS last_ledger_at
    FROM pepita_ledger
    GROUP BY gold_campaign_id
)
SELECT
    campaign.gold_campaign_id,
    campaign.campaign_id,
    campaign.merchant_user_id,
    campaign.campaign_name,
    campaign.campaign_type,
    campaign.campaign_status,
    campaign.budget_brl,
    campaign.valley_revenue_brl,
    campaign.pepita_pool_brl,
    COALESCE(events.event_count, 0) AS event_count,
    COALESCE(events.pepita_grant_events, 0) AS pepita_grant_events,
    COALESCE(events.rewarded_users, 0) AS rewarded_users,
    COALESCE(events.granted_pepita_brl, 0.0000)::DECIMAL(18,4) AS granted_pepita_brl,
    COALESCE(ledger.ledger_entries, 0) AS ledger_entries,
    COALESCE(ledger.credited_pepita_brl, 0.0000)::DECIMAL(18,4) AS credited_pepita_brl,
    GREATEST(
        COALESCE(events.last_event_at, campaign.updated_at),
        COALESCE(ledger.last_ledger_at, campaign.updated_at)
    ) AS last_reward_activity_at
FROM gold_campaigns AS campaign
LEFT JOIN event_summary AS events
  ON events.gold_campaign_id = campaign.gold_campaign_id
LEFT JOIN ledger_summary AS ledger
  ON ledger.gold_campaign_id = campaign.gold_campaign_id;

CREATE OR REPLACE VIEW v_media_social_growth_referral_ops AS
SELECT
    referral.referral_id,
    referral.referrer_id,
    referral.order_id,
    referral.purchase_transaction_id,
    referral.commission_amount_brl,
    referral.payout_at,
    order_row.user_id AS buyer_user_id,
    order_row.merchant_user_id,
    order_row.total_brl AS order_total_brl,
    transaction_row.transaction_status,
    transaction_row.origin_module,
    transaction_row.channel,
    referral.created_at
FROM affiliate_referrals AS referral
LEFT JOIN orders AS order_row
  ON order_row.order_id = referral.order_id
LEFT JOIN transactions AS transaction_row
  ON transaction_row.transaction_id = referral.purchase_transaction_id;

CREATE OR REPLACE VIEW v_media_social_growth_gaming_ops AS
WITH point_summary AS (
    SELECT
        campaign_id,
        COUNT(DISTINCT user_id) AS player_count,
        COALESCE(SUM(points), 0) AS net_points,
        MAX(granted_at) AS last_reward_at
    FROM points_ledger
    GROUP BY campaign_id
)
SELECT
    campaign.campaign_id,
    campaign.module_code,
    campaign.campaign_name,
    campaign.reward_type,
    campaign.approval_status,
    COALESCE(points.player_count, 0) AS player_count,
    COALESCE(points.net_points, 0) AS net_points,
    points.last_reward_at,
    campaign.created_at,
    campaign.updated_at
FROM gamification_campaigns AS campaign
LEFT JOIN point_summary AS points
  ON points.campaign_id = campaign.campaign_id
WHERE campaign.module_code = 'GAMING';

COMMENT ON VIEW v_media_social_growth_creator_ops IS
    'Pipeline operacional de upload, monetizacao, revenue e afiliacao dos creators.';

COMMENT ON VIEW v_media_social_growth_priority_backlog IS
    'Visao operacional do backlog prioritario do dominio media_social_growth.';

COMMENT ON VIEW v_media_social_growth_delivery_artifacts IS
    'Visao dos artefatos fisicos por camada do dominio media_social_growth.';

COMMENT ON VIEW v_media_social_growth_event_contracts IS
    'Visao dos contratos de evento exportados do dominio media_social_growth.';

COMMENT ON VIEW v_media_social_growth_ads_reward_ops IS
    'Operacao real das campanhas GOLD, grants de Pepita e ledger de reward.';

COMMENT ON VIEW v_media_social_growth_referral_ops IS
    'Trilha comercial das comissoes atribuiveis a creators e afiliados do dominio.';

COMMENT ON VIEW v_media_social_growth_gaming_ops IS
    'Resumo das campanhas de reward e da progressao gamificada em pontos.';

COMMIT;
