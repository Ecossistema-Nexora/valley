BEGIN;

-- Aprofunda o dominio Commerce Fintech Assets com views operacionais reais.
-- Consolida marketplace, treasury, ativos digitais, pipeline imobiliario e insurance.

CREATE OR REPLACE VIEW v_commerce_fintech_assets_market_ops AS
SELECT
    storefront.storefront_id,
    storefront.merchant_user_id,
    storefront.storefront_code,
    storefront.storefront_name,
    storefront.storefront_status,
    listing.listing_id,
    listing.listing_title,
    listing.listing_status,
    listing.price_brl,
    COUNT(DISTINCT validation.sale_validation_id) AS validation_events,
    COALESCE(
        SUM(validation.gross_amount_brl)
            FILTER (
                WHERE validation.validation_status IN (
                    'MARKETPLACE_CONFIRMED',
                    'GPS_CONFIRMED',
                    'MANUAL_APPROVED'
                )
            ),
        0
    ) AS validated_gmv_brl,
    COALESCE(SUM(DISTINCT referral.commission_amount_brl), 0) AS affiliate_commission_brl
FROM merchant_storefronts AS storefront
LEFT JOIN marketplace_listings AS listing
  ON listing.merchant_user_id = storefront.merchant_user_id
LEFT JOIN sale_validation_events AS validation
  ON validation.storefront_id = storefront.storefront_id
 AND validation.merchant_user_id = storefront.merchant_user_id
LEFT JOIN affiliate_referrals AS referral
  ON referral.order_id = validation.order_id
  OR referral.purchase_transaction_id = validation.transaction_id
WHERE storefront.module_code = 'MARKETPLACE'
GROUP BY
    storefront.storefront_id,
    storefront.merchant_user_id,
    storefront.storefront_code,
    storefront.storefront_name,
    storefront.storefront_status,
    listing.listing_id,
    listing.listing_title,
    listing.listing_status,
    listing.price_brl;

CREATE OR REPLACE VIEW v_commerce_fintech_assets_treasury_ops AS
SELECT
    goal.goal_id,
    goal.user_id,
    goal.goal_name,
    goal.goal_status,
    goal.target_amount_brl,
    goal.current_amount_brl,
    plug.plug_transaction_id,
    plug.amount_brl AS plug_amount_brl,
    plug.mdr_rate,
    plug.settled_at,
    tx.transaction_id AS treasury_transaction_id,
    tx.transaction_status,
    tx.origin_module
FROM financial_goals AS goal
LEFT JOIN plug_transactions AS plug
  ON plug.user_id = goal.user_id
LEFT JOIN transactions AS tx
  ON tx.transaction_id = plug.transaction_id;

CREATE OR REPLACE VIEW v_commerce_fintech_assets_digital_assets AS
SELECT
    collection.collection_id,
    collection.collection_code,
    collection.collection_name,
    asset.digital_asset_id,
    asset.asset_code,
    asset.asset_status,
    asset.current_owner_user_id,
    COUNT(event_row.digital_asset_event_id) AS event_count,
    COALESCE(SUM(event_row.royalty_amount_brl), 0) AS royalty_amount_brl,
    MAX(event_row.occurred_at) AS last_event_at
FROM digital_asset_collections AS collection
JOIN digital_assets AS asset
  ON asset.collection_id = collection.collection_id
LEFT JOIN digital_asset_events AS event_row
  ON event_row.digital_asset_id = asset.digital_asset_id
WHERE collection.module_code = 'DIGITAL'
GROUP BY
    collection.collection_id,
    collection.collection_code,
    collection.collection_name,
    asset.digital_asset_id,
    asset.asset_code,
    asset.asset_status,
    asset.current_owner_user_id;

CREATE OR REPLACE VIEW v_commerce_fintech_assets_real_estate_pipeline AS
SELECT
    property.property_id,
    property.property_code,
    property.property_status,
    property.tokenized_asset_id,
    listing.listing_id,
    listing.listing_code,
    listing.listing_status,
    listing.asking_price_brl,
    deal.deal_id,
    deal.deal_status,
    deal.buyer_user_id,
    deal.purchase_price_brl,
    deal.closed_at
FROM real_estate_properties AS property
LEFT JOIN real_estate_listings AS listing
  ON listing.property_id = property.property_id
LEFT JOIN real_estate_deals AS deal
  ON deal.property_id = property.property_id
WHERE property.module_code = 'REAL_ESTATE';

CREATE OR REPLACE VIEW v_commerce_fintech_assets_insurance_ops AS
SELECT
    product.insurance_product_id,
    product.product_code,
    product.product_status,
    policy.policy_id,
    policy.policy_number,
    policy.policy_status,
    claim.claim_id,
    claim.claim_status,
    claim.claimed_amount_brl,
    claim.approved_amount_brl,
    COUNT(event_row.claim_event_id) AS claim_event_count,
    MAX(event_row.occurred_at) AS last_claim_event_at
FROM insurance_products AS product
LEFT JOIN insurance_policies AS policy
  ON policy.insurance_product_id = product.insurance_product_id
LEFT JOIN insurance_claims AS claim
  ON claim.policy_id = policy.policy_id
LEFT JOIN insurance_claim_events AS event_row
  ON event_row.claim_id = claim.claim_id
WHERE product.module_code = 'INSURANCE'
GROUP BY
    product.insurance_product_id,
    product.product_code,
    product.product_status,
    policy.policy_id,
    policy.policy_number,
    policy.policy_status,
    claim.claim_id,
    claim.claim_status,
    claim.claimed_amount_brl,
    claim.approved_amount_brl;

COMMENT ON VIEW v_commerce_fintech_assets_market_ops IS
    'Painel consolidado de storefront, listing, validacao de venda e comissao de afiliado.';
COMMENT ON VIEW v_commerce_fintech_assets_treasury_ops IS
    'Visao de goals financeiros combinada com transacoes Plug e ledger associado.';
COMMENT ON VIEW v_commerce_fintech_assets_digital_assets IS
    'Resumo operacional de colecoes, ativos, ownership e royalties.';
COMMENT ON VIEW v_commerce_fintech_assets_real_estate_pipeline IS
    'Funil de property, listing e deal com ancoragem no ativo tokenizado.';
COMMENT ON VIEW v_commerce_fintech_assets_insurance_ops IS
    'Resumo de produto, apolice, claim e ultima movimentacao de sinistro.';

COMMIT;
