-- Valley Hybrid DB Bootstrap - Rule Engine, Growth e Marketplace Runtime v47.
-- Este arquivo fecha a camada operacional pedida pela arquitetura de produto: regras dinamicas,
-- geolocalizacao comercial, Pepitas/GOLD e validacao real de venda sem recriar schema legado.
-- Execute depois de 001, 002, 004, 005, 007, 008 e 009, porque integra users, wallets, orders,
-- transactions, business_rule_definitions, gamification_campaigns, module_delivery_registry e listings.

BEGIN;

SET search_path = public;

-- rule_binding_scope_enum define onde uma regra fica acoplada no runtime.
CREATE TYPE rule_binding_scope_enum AS ENUM ('GLOBAL', 'MODULE', 'MERCHANT', 'LISTING', 'ORDER', 'CAMPAIGN', 'SALE_VALIDATION');

-- rule_binding_status_enum controla lifecycle operacional do bind da regra.
CREATE TYPE rule_binding_status_enum AS ENUM ('DRAFT', 'ACTIVE', 'PAUSED', 'ARCHIVED');

-- rule_execution_status_enum guarda o resultado tecnico da avaliacao.
CREATE TYPE rule_execution_status_enum AS ENUM ('RECEIVED', 'ALLOWED', 'SOFT_BLOCKED', 'BLOCKED', 'ERROR');

-- pepita_account_status_enum controla se a conta gamificada pode receber ou resgatar saldo.
CREATE TYPE pepita_account_status_enum AS ENUM ('ACTIVE', 'FROZEN', 'ARCHIVED');

-- pepita_entry_type_enum registra ganhos, uso e ajustes do saldo de Pepitas.
CREATE TYPE pepita_entry_type_enum AS ENUM ('EARN', 'REDEEM', 'EXPIRE', 'REVERSAL', 'GOLD_CONVERSION', 'ADJUSTMENT');

-- gold_campaign_type_enum separa campanhas de trafego, venda digital e venda fisica.
CREATE TYPE gold_campaign_type_enum AS ENUM ('TRAFFIC', 'MARKETPLACE_SALE', 'PHYSICAL_SALE', 'GEO_VISIT', 'HYBRID');

-- gold_campaign_status_enum controla aprovacao e operacao do budget GOLD.
CREATE TYPE gold_campaign_status_enum AS ENUM ('DRAFT', 'ACTIVE', 'PAUSED', 'ENDED', 'ARCHIVED');

-- gold_event_type_enum descreve cada evento append-only dentro da campanha.
CREATE TYPE gold_event_type_enum AS ENUM ('FUNDING', 'QUALIFIED_VISIT', 'MARKETPLACE_CONVERSION', 'PHYSICAL_CONVERSION', 'PEPITA_GRANT', 'REVERSAL');

-- gold_event_status_enum guarda se o evento ainda depende de validacao ou ja foi liquidado.
CREATE TYPE gold_event_status_enum AS ENUM ('PENDING', 'VALIDATED', 'REJECTED', 'SETTLED', 'REVERSED');

-- storefront_status_enum controla o lifecycle de cada operacao comercial do merchant.
CREATE TYPE storefront_status_enum AS ENUM ('DRAFT', 'ACTIVE', 'PAUSED', 'ARCHIVED');

-- service_zone_shape_enum indica o formato logico da zona de atendimento.
CREATE TYPE service_zone_shape_enum AS ENUM ('CIRCLE', 'POLYGON');

-- sale_validation_source_enum informa de onde veio a prova da venda.
CREATE TYPE sale_validation_source_enum AS ENUM ('MARKETPLACE_ORDER', 'PHYSICAL_POS', 'GPS_CHECKIN', 'MANUAL_REVIEW');

-- sale_validation_status_enum guarda o resultado da validacao comercial/fisica.
CREATE TYPE sale_validation_status_enum AS ENUM ('PENDING', 'MARKETPLACE_CONFIRMED', 'GPS_CONFIRMED', 'MANUAL_APPROVED', 'REJECTED', 'EXPIRED');

-- listing_pricing_status_enum controla se o anuncio continua competitivo e publicavel.
CREATE TYPE listing_pricing_status_enum AS ENUM ('DRAFT', 'COMPETITIVE', 'NON_COMPETITIVE', 'AUTO_PAUSED', 'MANUAL_REVIEW');

-- rule_runtime_bindings materializa o Rule Engine no runtime sem duplicar a definicao canonica.
CREATE TABLE rule_runtime_bindings (
    binding_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rule_id UUID NOT NULL,
    rule_version_id UUID NOT NULL,
    module_code TEXT NOT NULL,
    binding_scope rule_binding_scope_enum NOT NULL DEFAULT 'MODULE',
    target_reference TEXT NOT NULL DEFAULT 'GLOBAL',
    priority SMALLINT NOT NULL DEFAULT 100,
    binding_status rule_binding_status_enum NOT NULL DEFAULT 'DRAFT',
    conditions_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    action_overrides_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    effective_from TIMESTAMPTZ,
    effective_until TIMESTAMPTZ,
    created_by_admin_id UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_rule_runtime_bindings_rule
        FOREIGN KEY (rule_id) REFERENCES business_rule_definitions (rule_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_rule_runtime_bindings_version
        FOREIGN KEY (rule_version_id) REFERENCES business_rule_versions (rule_version_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_rule_runtime_bindings_module
        FOREIGN KEY (module_code) REFERENCES module_delivery_registry (module_code)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_rule_runtime_bindings_admin
        FOREIGN KEY (created_by_admin_id) REFERENCES admin_users (admin_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT ux_rule_runtime_bindings_scope UNIQUE (rule_version_id, module_code, binding_scope, target_reference),
    CONSTRAINT chk_rule_runtime_bindings_target_reference CHECK (btrim(target_reference) <> ''),
    CONSTRAINT chk_rule_runtime_bindings_scope_target CHECK (
        (binding_scope = 'GLOBAL' AND target_reference = 'GLOBAL')
        OR (binding_scope <> 'GLOBAL' AND target_reference <> 'GLOBAL')
    ),
    CONSTRAINT chk_rule_runtime_bindings_priority CHECK (priority BETWEEN 1 AND 32767),
    CONSTRAINT chk_rule_runtime_bindings_conditions_json CHECK (jsonb_typeof(conditions_json) = 'object'),
    CONSTRAINT chk_rule_runtime_bindings_overrides_json CHECK (jsonb_typeof(action_overrides_json) = 'object'),
    CONSTRAINT chk_rule_runtime_bindings_window CHECK (
        effective_from IS NULL OR effective_until IS NULL OR effective_until >= effective_from
    )
);

-- rule_execution_events registra cada avaliacao de regra como trilha append-only.
CREATE TABLE rule_execution_events (
    rule_execution_event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    binding_id UUID,
    rule_id UUID NOT NULL,
    rule_version_id UUID NOT NULL,
    module_code TEXT NOT NULL,
    user_id UUID,
    order_id UUID,
    transaction_id UUID,
    reference_entity_type TEXT,
    reference_entity_id TEXT,
    execution_status rule_execution_status_enum NOT NULL,
    decision_code TEXT NOT NULL,
    input_snapshot_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    output_snapshot_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    correlation_id TEXT,
    executed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_rule_execution_events_binding
        FOREIGN KEY (binding_id) REFERENCES rule_runtime_bindings (binding_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_rule_execution_events_rule
        FOREIGN KEY (rule_id) REFERENCES business_rule_definitions (rule_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_rule_execution_events_version
        FOREIGN KEY (rule_version_id) REFERENCES business_rule_versions (rule_version_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_rule_execution_events_module
        FOREIGN KEY (module_code) REFERENCES module_delivery_registry (module_code)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_rule_execution_events_user
        FOREIGN KEY (user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_rule_execution_events_order
        FOREIGN KEY (order_id) REFERENCES orders (order_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_rule_execution_events_transaction
        FOREIGN KEY (transaction_id) REFERENCES transactions (transaction_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT chk_rule_execution_events_decision CHECK (btrim(decision_code) <> ''),
    CONSTRAINT chk_rule_execution_events_entity_pair CHECK (
        (reference_entity_type IS NULL AND reference_entity_id IS NULL)
        OR (
            reference_entity_type IS NOT NULL
            AND reference_entity_id IS NOT NULL
            AND btrim(reference_entity_type) <> ''
            AND btrim(reference_entity_id) <> ''
        )
    ),
    CONSTRAINT chk_rule_execution_events_input_json CHECK (jsonb_typeof(input_snapshot_json) = 'object'),
    CONSTRAINT chk_rule_execution_events_output_json CHECK (jsonb_typeof(output_snapshot_json) = 'object')
);

-- merchant_storefronts cria a fachada operacional do lojista para vitrine, zona e validacao.
CREATE TABLE merchant_storefronts (
    storefront_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_user_id UUID NOT NULL,
    wallet_id UUID NOT NULL,
    module_code TEXT NOT NULL DEFAULT 'MARKETPLACE',
    storefront_code TEXT NOT NULL,
    storefront_name TEXT NOT NULL,
    storefront_status storefront_status_enum NOT NULL DEFAULT 'DRAFT',
    address_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    geo_json JSONB,
    service_radius_km DECIMAL(10,4) NOT NULL DEFAULT 0,
    supported_domains order_domain_enum[] NOT NULL DEFAULT ARRAY['FOOD', 'MOVE', 'DROPSHIP']::order_domain_enum[],
    service_modes TEXT[] NOT NULL DEFAULT ARRAY['DELIVERY']::TEXT[],
    accepts_marketplace_sales BOOLEAN NOT NULL DEFAULT TRUE,
    accepts_physical_sales BOOLEAN NOT NULL DEFAULT FALSE,
    schedule_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_merchant_storefronts_merchant
        FOREIGN KEY (merchant_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_merchant_storefronts_wallet
        FOREIGN KEY (wallet_id) REFERENCES wallets (wallet_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_merchant_storefronts_module
        FOREIGN KEY (module_code) REFERENCES module_delivery_registry (module_code)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT ux_merchant_storefronts_code UNIQUE (merchant_user_id, storefront_code),
    CONSTRAINT chk_merchant_storefronts_code CHECK (storefront_code ~ '^[A-Z0-9_-]{2,80}$'),
    CONSTRAINT chk_merchant_storefronts_name CHECK (btrim(storefront_name) <> ''),
    CONSTRAINT chk_merchant_storefronts_address_json CHECK (jsonb_typeof(address_json) = 'object'),
    CONSTRAINT chk_merchant_storefronts_geo_json CHECK (geo_json IS NULL OR jsonb_typeof(geo_json) = 'object'),
    CONSTRAINT chk_merchant_storefronts_radius CHECK (service_radius_km >= 0),
    CONSTRAINT chk_merchant_storefronts_domains CHECK (cardinality(supported_domains) > 0),
    CONSTRAINT chk_merchant_storefronts_modes CHECK (cardinality(service_modes) > 0),
    CONSTRAINT chk_merchant_storefronts_schedule_json CHECK (jsonb_typeof(schedule_json) = 'object'),
    CONSTRAINT chk_merchant_storefronts_metadata_json CHECK (jsonb_typeof(metadata_json) = 'object')
);

-- merchant_service_zones define raio ou poligono de atendimento por storefront.
CREATE TABLE merchant_service_zones (
    service_zone_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    storefront_id UUID NOT NULL,
    zone_name TEXT NOT NULL,
    zone_shape service_zone_shape_enum NOT NULL,
    zone_geo_json JSONB NOT NULL,
    delivery_fee_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    minimum_order_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    eta_min_minutes INTEGER,
    eta_max_minutes INTEGER,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_merchant_service_zones_storefront
        FOREIGN KEY (storefront_id) REFERENCES merchant_storefronts (storefront_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT chk_merchant_service_zones_name CHECK (btrim(zone_name) <> ''),
    CONSTRAINT chk_merchant_service_zones_geo_json CHECK (jsonb_typeof(zone_geo_json) = 'object'),
    CONSTRAINT chk_merchant_service_zones_delivery_fee CHECK (delivery_fee_brl >= 0),
    CONSTRAINT chk_merchant_service_zones_min_order CHECK (minimum_order_brl >= 0),
    CONSTRAINT chk_merchant_service_zones_eta CHECK (
        (eta_min_minutes IS NULL AND eta_max_minutes IS NULL)
        OR (
            eta_min_minutes IS NOT NULL
            AND eta_max_minutes IS NOT NULL
            AND eta_min_minutes >= 0
            AND eta_max_minutes >= eta_min_minutes
        )
    )
);

-- marketplace_listing_controls guarda a decisao de competitividade e auto-publicacao.
CREATE TABLE marketplace_listing_controls (
    listing_control_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    listing_id UUID NOT NULL UNIQUE,
    merchant_user_id UUID NOT NULL,
    rule_binding_id UUID,
    pricing_status listing_pricing_status_enum NOT NULL DEFAULT 'DRAFT',
    valley_cost_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    target_margin_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    minimum_price_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    last_market_reference_brl DECIMAL(18,4),
    last_competitor_name TEXT,
    last_checked_at TIMESTAMPTZ,
    auto_publish_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    publish_block_reason TEXT,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_marketplace_listing_controls_listing
        FOREIGN KEY (listing_id) REFERENCES marketplace_listings (listing_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT fk_marketplace_listing_controls_merchant
        FOREIGN KEY (merchant_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_marketplace_listing_controls_binding
        FOREIGN KEY (rule_binding_id) REFERENCES rule_runtime_bindings (binding_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT chk_marketplace_listing_controls_cost CHECK (valley_cost_brl >= 0),
    CONSTRAINT chk_marketplace_listing_controls_margin CHECK (target_margin_brl >= 0),
    CONSTRAINT chk_marketplace_listing_controls_minimum_price CHECK (minimum_price_brl >= 0),
    CONSTRAINT chk_marketplace_listing_controls_market_reference CHECK (last_market_reference_brl IS NULL OR last_market_reference_brl >= 0),
    CONSTRAINT chk_marketplace_listing_controls_competitor_name CHECK (
        last_competitor_name IS NULL OR btrim(last_competitor_name) <> ''
    ),
    CONSTRAINT chk_marketplace_listing_controls_publish_reason CHECK (
        publish_block_reason IS NULL OR btrim(publish_block_reason) <> ''
    ),
    CONSTRAINT chk_marketplace_listing_controls_metadata_json CHECK (jsonb_typeof(metadata_json) = 'object')
);

-- marketplace_competitor_snapshots preserva prova append-only da comparacao de preco.
CREATE TABLE marketplace_competitor_snapshots (
    competitor_snapshot_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    listing_id UUID NOT NULL,
    item_id UUID NOT NULL,
    merchant_user_id UUID NOT NULL,
    competitor_name TEXT NOT NULL,
    competitor_url TEXT,
    competitor_sku TEXT,
    competitor_price_brl DECIMAL(18,4) NOT NULL,
    shipping_price_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    captured_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_marketplace_competitor_snapshots_listing
        FOREIGN KEY (listing_id) REFERENCES marketplace_listings (listing_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_marketplace_competitor_snapshots_item
        FOREIGN KEY (item_id) REFERENCES inventory_items (item_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_marketplace_competitor_snapshots_merchant
        FOREIGN KEY (merchant_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT chk_marketplace_competitor_snapshots_name CHECK (btrim(competitor_name) <> ''),
    CONSTRAINT chk_marketplace_competitor_snapshots_url CHECK (competitor_url IS NULL OR btrim(competitor_url) <> ''),
    CONSTRAINT chk_marketplace_competitor_snapshots_sku CHECK (competitor_sku IS NULL OR btrim(competitor_sku) <> ''),
    CONSTRAINT chk_marketplace_competitor_snapshots_price CHECK (competitor_price_brl >= 0),
    CONSTRAINT chk_marketplace_competitor_snapshots_shipping CHECK (shipping_price_brl >= 0)
);

-- pepita_accounts guarda o saldo consolidado do cashback gamificado por usuario.
CREATE TABLE pepita_accounts (
    pepita_account_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL UNIQUE,
    account_status pepita_account_status_enum NOT NULL DEFAULT 'ACTIVE',
    current_balance_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    lifetime_earned_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    lifetime_redeemed_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    lifetime_expired_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    last_activity_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_pepita_accounts_user
        FOREIGN KEY (user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT chk_pepita_accounts_current_balance CHECK (current_balance_brl >= 0),
    CONSTRAINT chk_pepita_accounts_lifetime_earned CHECK (lifetime_earned_brl >= 0),
    CONSTRAINT chk_pepita_accounts_lifetime_redeemed CHECK (lifetime_redeemed_brl >= 0),
    CONSTRAINT chk_pepita_accounts_lifetime_expired CHECK (lifetime_expired_brl >= 0)
);

-- gold_campaigns representa budget patrocinado e sua divisao entre Valley e Pepitas.
CREATE TABLE gold_campaigns (
    gold_campaign_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    campaign_id UUID UNIQUE,
    merchant_user_id UUID NOT NULL,
    wallet_id UUID NOT NULL,
    module_code TEXT NOT NULL DEFAULT 'ADS',
    campaign_type gold_campaign_type_enum NOT NULL,
    campaign_status gold_campaign_status_enum NOT NULL DEFAULT 'DRAFT',
    campaign_name TEXT NOT NULL,
    objective TEXT,
    target_storefront_id UUID,
    target_zone_id UUID,
    budget_brl DECIMAL(18,4) NOT NULL,
    valley_revenue_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    pepita_pool_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    minimum_ticket_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    target_geo_json JSONB,
    target_radius_km DECIMAL(10,4),
    starts_at TIMESTAMPTZ,
    ends_at TIMESTAMPTZ,
    validation_window_minutes INTEGER NOT NULL DEFAULT 30,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_gold_campaigns_campaign
        FOREIGN KEY (campaign_id) REFERENCES gamification_campaigns (campaign_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_gold_campaigns_merchant
        FOREIGN KEY (merchant_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_gold_campaigns_wallet
        FOREIGN KEY (wallet_id) REFERENCES wallets (wallet_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_gold_campaigns_module
        FOREIGN KEY (module_code) REFERENCES module_delivery_registry (module_code)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_gold_campaigns_storefront
        FOREIGN KEY (target_storefront_id) REFERENCES merchant_storefronts (storefront_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_gold_campaigns_zone
        FOREIGN KEY (target_zone_id) REFERENCES merchant_service_zones (service_zone_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT chk_gold_campaigns_name CHECK (btrim(campaign_name) <> ''),
    CONSTRAINT chk_gold_campaigns_budget CHECK (budget_brl >= 0),
    CONSTRAINT chk_gold_campaigns_revenue CHECK (valley_revenue_brl >= 0),
    CONSTRAINT chk_gold_campaigns_pepita_pool CHECK (pepita_pool_brl >= 0),
    CONSTRAINT chk_gold_campaigns_budget_split CHECK (budget_brl >= valley_revenue_brl + pepita_pool_brl),
    CONSTRAINT chk_gold_campaigns_min_ticket CHECK (minimum_ticket_brl >= 0),
    CONSTRAINT chk_gold_campaigns_geo_json CHECK (target_geo_json IS NULL OR jsonb_typeof(target_geo_json) = 'object'),
    CONSTRAINT chk_gold_campaigns_radius CHECK (target_radius_km IS NULL OR target_radius_km >= 0),
    CONSTRAINT chk_gold_campaigns_window CHECK (
        starts_at IS NULL OR ends_at IS NULL OR ends_at >= starts_at
    ),
    CONSTRAINT chk_gold_campaigns_validation_window CHECK (validation_window_minutes > 0),
    CONSTRAINT chk_gold_campaigns_metadata_json CHECK (jsonb_typeof(metadata_json) = 'object')
);

-- sale_validation_events prova que a venda existiu no marketplace ou no mundo fisico.
CREATE TABLE sale_validation_events (
    sale_validation_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    module_code TEXT NOT NULL DEFAULT 'MARKETPLACE',
    merchant_user_id UUID NOT NULL,
    customer_user_id UUID,
    rider_user_id UUID,
    storefront_id UUID,
    service_zone_id UUID,
    gold_campaign_id UUID,
    order_id UUID,
    transaction_id UUID,
    validation_source sale_validation_source_enum NOT NULL,
    validation_status sale_validation_status_enum NOT NULL DEFAULT 'PENDING',
    sale_reference_code TEXT,
    telemetry_correlation_id TEXT,
    gross_amount_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    net_profit_reference_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    pepita_cap_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    gps_point_json JSONB,
    validation_payload_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    validated_by_user_id UUID,
    validated_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_sale_validation_events_module
        FOREIGN KEY (module_code) REFERENCES module_delivery_registry (module_code)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_sale_validation_events_merchant
        FOREIGN KEY (merchant_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_sale_validation_events_customer
        FOREIGN KEY (customer_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_sale_validation_events_rider
        FOREIGN KEY (rider_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_sale_validation_events_storefront
        FOREIGN KEY (storefront_id) REFERENCES merchant_storefronts (storefront_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_sale_validation_events_zone
        FOREIGN KEY (service_zone_id) REFERENCES merchant_service_zones (service_zone_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_sale_validation_events_gold_campaign
        FOREIGN KEY (gold_campaign_id) REFERENCES gold_campaigns (gold_campaign_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_sale_validation_events_order
        FOREIGN KEY (order_id) REFERENCES orders (order_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_sale_validation_events_transaction
        FOREIGN KEY (transaction_id) REFERENCES transactions (transaction_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_sale_validation_events_validated_by
        FOREIGN KEY (validated_by_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT chk_sale_validation_events_reference CHECK (
        order_id IS NOT NULL
        OR transaction_id IS NOT NULL
        OR telemetry_correlation_id IS NOT NULL
        OR sale_reference_code IS NOT NULL
    ),
    CONSTRAINT chk_sale_validation_events_source_requirements CHECK (
        (validation_source <> 'MARKETPLACE_ORDER' OR order_id IS NOT NULL)
        AND (validation_source <> 'GPS_CHECKIN' OR telemetry_correlation_id IS NOT NULL)
        AND (validation_source <> 'PHYSICAL_POS' OR sale_reference_code IS NOT NULL OR transaction_id IS NOT NULL)
    ),
    CONSTRAINT chk_sale_validation_events_status_payload CHECK (
        validation_status <> 'GPS_CONFIRMED' OR gps_point_json IS NOT NULL
    ),
    CONSTRAINT chk_sale_validation_events_sale_reference CHECK (
        sale_reference_code IS NULL OR btrim(sale_reference_code) <> ''
    ),
    CONSTRAINT chk_sale_validation_events_telemetry_reference CHECK (
        telemetry_correlation_id IS NULL OR btrim(telemetry_correlation_id) <> ''
    ),
    CONSTRAINT chk_sale_validation_events_gross_amount CHECK (gross_amount_brl >= 0),
    CONSTRAINT chk_sale_validation_events_net_profit CHECK (net_profit_reference_brl >= 0),
    CONSTRAINT chk_sale_validation_events_pepita_cap CHECK (
        pepita_cap_brl >= 0
        AND pepita_cap_brl <= (net_profit_reference_brl * 0.5000)
    ),
    CONSTRAINT chk_sale_validation_events_gps_json CHECK (
        gps_point_json IS NULL OR jsonb_typeof(gps_point_json) = 'object'
    ),
    CONSTRAINT chk_sale_validation_events_payload_json CHECK (jsonb_typeof(validation_payload_json) = 'object'),
    CONSTRAINT chk_sale_validation_events_validated_at CHECK (
        validated_at IS NULL OR validated_at >= created_at
    ),
    CONSTRAINT chk_sale_validation_events_expires_at CHECK (
        expires_at IS NULL OR expires_at > created_at
    )
);

-- gold_campaign_events registra funding, conversao e liquidacao de Pepitas como trilha append-only.
CREATE TABLE gold_campaign_events (
    gold_campaign_event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    gold_campaign_id UUID NOT NULL,
    sale_validation_id UUID,
    candidate_user_id UUID,
    merchant_user_id UUID NOT NULL,
    order_id UUID,
    transaction_id UUID,
    event_type gold_event_type_enum NOT NULL,
    event_status gold_event_status_enum NOT NULL DEFAULT 'PENDING',
    gold_amount_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    pepita_amount_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    valley_revenue_amount_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    reason_code TEXT NOT NULL,
    payload_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_gold_campaign_events_campaign
        FOREIGN KEY (gold_campaign_id) REFERENCES gold_campaigns (gold_campaign_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_gold_campaign_events_sale_validation
        FOREIGN KEY (sale_validation_id) REFERENCES sale_validation_events (sale_validation_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_gold_campaign_events_candidate
        FOREIGN KEY (candidate_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_gold_campaign_events_merchant
        FOREIGN KEY (merchant_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_gold_campaign_events_order
        FOREIGN KEY (order_id) REFERENCES orders (order_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_gold_campaign_events_transaction
        FOREIGN KEY (transaction_id) REFERENCES transactions (transaction_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT chk_gold_campaign_events_amounts CHECK (
        gold_amount_brl >= 0
        AND pepita_amount_brl >= 0
        AND valley_revenue_amount_brl >= 0
        AND (gold_amount_brl > 0 OR pepita_amount_brl > 0 OR valley_revenue_amount_brl > 0)
    ),
    CONSTRAINT chk_gold_campaign_events_reason CHECK (btrim(reason_code) <> ''),
    CONSTRAINT chk_gold_campaign_events_payload_json CHECK (jsonb_typeof(payload_json) = 'object')
);

-- pepita_ledger e o ledger append-only que converte campanhas e vendas em saldo do usuario.
CREATE TABLE pepita_ledger (
    pepita_ledger_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pepita_account_id UUID NOT NULL,
    user_id UUID NOT NULL,
    campaign_id UUID,
    gold_campaign_id UUID,
    gold_campaign_event_id UUID,
    sale_validation_id UUID,
    order_id UUID,
    transaction_id UUID,
    entry_type pepita_entry_type_enum NOT NULL,
    amount_brl DECIMAL(18,4) NOT NULL,
    balance_after_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    reason_code TEXT NOT NULL,
    description TEXT,
    expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_pepita_ledger_account
        FOREIGN KEY (pepita_account_id) REFERENCES pepita_accounts (pepita_account_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_pepita_ledger_user
        FOREIGN KEY (user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_pepita_ledger_campaign
        FOREIGN KEY (campaign_id) REFERENCES gamification_campaigns (campaign_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_pepita_ledger_gold_campaign
        FOREIGN KEY (gold_campaign_id) REFERENCES gold_campaigns (gold_campaign_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_pepita_ledger_gold_event
        FOREIGN KEY (gold_campaign_event_id) REFERENCES gold_campaign_events (gold_campaign_event_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_pepita_ledger_sale_validation
        FOREIGN KEY (sale_validation_id) REFERENCES sale_validation_events (sale_validation_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_pepita_ledger_order
        FOREIGN KEY (order_id) REFERENCES orders (order_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_pepita_ledger_transaction
        FOREIGN KEY (transaction_id) REFERENCES transactions (transaction_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT chk_pepita_ledger_amount CHECK (amount_brl <> 0),
    CONSTRAINT chk_pepita_ledger_balance CHECK (balance_after_brl >= 0),
    CONSTRAINT chk_pepita_ledger_reason CHECK (btrim(reason_code) <> ''),
    CONSTRAINT chk_pepita_ledger_expiration CHECK (expires_at IS NULL OR expires_at > created_at)
);

-- assert_rule_binding_coherence garante que bind ativo use versao aprovada e alinhada.
CREATE OR REPLACE FUNCTION assert_rule_binding_coherence()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    version_rule_id UUID;
    version_enabled BOOLEAN;
BEGIN
    SELECT
        rule_id,
        enabled
    INTO
        version_rule_id,
        version_enabled
    FROM business_rule_versions
    WHERE rule_version_id = NEW.rule_version_id;

    IF version_rule_id IS NULL THEN
        RAISE EXCEPTION 'rule_version_id % nao encontrado em business_rule_versions', NEW.rule_version_id;
    END IF;

    IF version_rule_id <> NEW.rule_id THEN
        RAISE EXCEPTION 'rule_version_id % nao pertence ao rule_id %', NEW.rule_version_id, NEW.rule_id;
    END IF;

    IF NEW.binding_status = 'ACTIVE' AND version_enabled = FALSE THEN
        RAISE EXCEPTION 'rule_version_id % precisa estar enabled para binding ACTIVE', NEW.rule_version_id;
    END IF;

    RETURN NEW;
END;
$$;

-- assert_rule_execution_coherence garante que o runtime registre a versao correta da regra.
CREATE OR REPLACE FUNCTION assert_rule_execution_coherence()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    version_rule_id UUID;
    binding_rule_id UUID;
    binding_version_id UUID;
    binding_module_code TEXT;
BEGIN
    SELECT rule_id
    INTO version_rule_id
    FROM business_rule_versions
    WHERE rule_version_id = NEW.rule_version_id;

    IF version_rule_id IS NULL THEN
        RAISE EXCEPTION 'rule_version_id % nao encontrado em business_rule_versions', NEW.rule_version_id;
    END IF;

    IF version_rule_id <> NEW.rule_id THEN
        RAISE EXCEPTION 'rule_execution_event usa rule_id % mas rule_version_id % pertence a %', NEW.rule_id, NEW.rule_version_id, version_rule_id;
    END IF;

    IF NEW.binding_id IS NOT NULL THEN
        SELECT
            rule_id,
            rule_version_id,
            module_code
        INTO
            binding_rule_id,
            binding_version_id,
            binding_module_code
        FROM rule_runtime_bindings
        WHERE binding_id = NEW.binding_id;

        IF binding_rule_id <> NEW.rule_id
           OR binding_version_id <> NEW.rule_version_id
           OR binding_module_code <> NEW.module_code THEN
            RAISE EXCEPTION 'binding_id % nao casa com rule_id/rule_version_id/module_code do evento', NEW.binding_id;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

-- assert_storefront_wallet_owner impede storefront com wallet de outro usuario.
CREATE OR REPLACE FUNCTION assert_storefront_wallet_owner()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM wallets
        WHERE wallets.wallet_id = NEW.wallet_id
          AND wallets.user_id = NEW.merchant_user_id
    ) THEN
        RAISE EXCEPTION 'wallet_id % nao pertence ao merchant_user_id %', NEW.wallet_id, NEW.merchant_user_id;
    END IF;

    RETURN NEW;
END;
$$;

-- assert_listing_control_coherence garante que o controle de pricing pertence ao dono do listing.
CREATE OR REPLACE FUNCTION assert_listing_control_coherence()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    listing_merchant UUID;
    binding_module TEXT;
BEGIN
    SELECT merchant_user_id
    INTO listing_merchant
    FROM marketplace_listings
    WHERE listing_id = NEW.listing_id;

    IF listing_merchant IS NULL THEN
        RAISE EXCEPTION 'listing_id % nao encontrado em marketplace_listings', NEW.listing_id;
    END IF;

    IF listing_merchant <> NEW.merchant_user_id THEN
        RAISE EXCEPTION 'listing_id % pertence ao merchant_user_id %, nao a %', NEW.listing_id, listing_merchant, NEW.merchant_user_id;
    END IF;

    IF NEW.rule_binding_id IS NOT NULL THEN
        SELECT module_code
        INTO binding_module
        FROM rule_runtime_bindings
        WHERE binding_id = NEW.rule_binding_id;

        IF binding_module <> 'MARKETPLACE' THEN
            RAISE EXCEPTION 'rule_binding_id % precisa apontar para module_code MARKETPLACE', NEW.rule_binding_id;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

-- assert_competitor_snapshot_coherence garante que snapshot aponta para listing/item/merchant corretos.
CREATE OR REPLACE FUNCTION assert_competitor_snapshot_coherence()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    listing_item_id UUID;
    listing_merchant_id UUID;
BEGIN
    SELECT
        item_id,
        merchant_user_id
    INTO
        listing_item_id,
        listing_merchant_id
    FROM marketplace_listings
    WHERE listing_id = NEW.listing_id;

    IF listing_item_id IS NULL THEN
        RAISE EXCEPTION 'listing_id % nao encontrado em marketplace_listings', NEW.listing_id;
    END IF;

    IF listing_item_id <> NEW.item_id THEN
        RAISE EXCEPTION 'item_id % nao casa com o listing_id %', NEW.item_id, NEW.listing_id;
    END IF;

    IF listing_merchant_id <> NEW.merchant_user_id THEN
        RAISE EXCEPTION 'merchant_user_id % nao casa com o listing_id %', NEW.merchant_user_id, NEW.listing_id;
    END IF;

    RETURN NEW;
END;
$$;

-- assert_gold_campaign_coherence valida split, merchant, wallet e segmentacao da campanha GOLD.
CREATE OR REPLACE FUNCTION assert_gold_campaign_coherence()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    storefront_merchant_id UUID;
    zone_storefront_id UUID;
    zone_merchant_id UUID;
    wallet_owner_id UUID;
    reward_type reward_type_enum;
BEGIN
    SELECT user_id
    INTO wallet_owner_id
    FROM wallets
    WHERE wallet_id = NEW.wallet_id;

    IF wallet_owner_id IS NULL THEN
        RAISE EXCEPTION 'wallet_id % nao encontrado em wallets', NEW.wallet_id;
    END IF;

    IF wallet_owner_id <> NEW.merchant_user_id THEN
        RAISE EXCEPTION 'wallet_id % nao pertence ao merchant_user_id %', NEW.wallet_id, NEW.merchant_user_id;
    END IF;

    IF NEW.target_storefront_id IS NOT NULL THEN
        SELECT merchant_user_id
        INTO storefront_merchant_id
        FROM merchant_storefronts
        WHERE storefront_id = NEW.target_storefront_id;

        IF storefront_merchant_id <> NEW.merchant_user_id THEN
            RAISE EXCEPTION 'target_storefront_id % nao pertence ao merchant_user_id %', NEW.target_storefront_id, NEW.merchant_user_id;
        END IF;
    END IF;

    IF NEW.target_zone_id IS NOT NULL THEN
        SELECT
            z.storefront_id,
            s.merchant_user_id
        INTO
            zone_storefront_id,
            zone_merchant_id
        FROM merchant_service_zones z
        JOIN merchant_storefronts s
          ON s.storefront_id = z.storefront_id
        WHERE z.service_zone_id = NEW.target_zone_id;

        IF zone_merchant_id <> NEW.merchant_user_id THEN
            RAISE EXCEPTION 'target_zone_id % nao pertence ao merchant_user_id %', NEW.target_zone_id, NEW.merchant_user_id;
        END IF;

        IF NEW.target_storefront_id IS NOT NULL AND zone_storefront_id <> NEW.target_storefront_id THEN
            RAISE EXCEPTION 'target_zone_id % nao pertence ao target_storefront_id %', NEW.target_zone_id, NEW.target_storefront_id;
        END IF;
    END IF;

    IF NEW.campaign_id IS NOT NULL THEN
        SELECT reward_type
        INTO reward_type
        FROM gamification_campaigns
        WHERE campaign_id = NEW.campaign_id;

        IF reward_type <> 'PEPITA' THEN
            RAISE EXCEPTION 'campaign_id % precisa ser uma gamification_campaign com reward_type PEPITA', NEW.campaign_id;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

-- assert_sale_validation_coherence liga venda, geolocalizacao e campanha ao merchant correto.
CREATE OR REPLACE FUNCTION assert_sale_validation_coherence()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    storefront_merchant_id UUID;
    zone_storefront_id UUID;
    zone_merchant_id UUID;
    order_customer_id UUID;
    order_merchant_id UUID;
    campaign_merchant_id UUID;
    campaign_storefront_id UUID;
BEGIN
    IF NEW.storefront_id IS NOT NULL THEN
        SELECT merchant_user_id
        INTO storefront_merchant_id
        FROM merchant_storefronts
        WHERE storefront_id = NEW.storefront_id;

        IF storefront_merchant_id <> NEW.merchant_user_id THEN
            RAISE EXCEPTION 'storefront_id % nao pertence ao merchant_user_id %', NEW.storefront_id, NEW.merchant_user_id;
        END IF;
    END IF;

    IF NEW.service_zone_id IS NOT NULL THEN
        SELECT
            z.storefront_id,
            s.merchant_user_id
        INTO
            zone_storefront_id,
            zone_merchant_id
        FROM merchant_service_zones z
        JOIN merchant_storefronts s
          ON s.storefront_id = z.storefront_id
        WHERE z.service_zone_id = NEW.service_zone_id;

        IF zone_merchant_id <> NEW.merchant_user_id THEN
            RAISE EXCEPTION 'service_zone_id % nao pertence ao merchant_user_id %', NEW.service_zone_id, NEW.merchant_user_id;
        END IF;

        IF NEW.storefront_id IS NOT NULL AND zone_storefront_id <> NEW.storefront_id THEN
            RAISE EXCEPTION 'service_zone_id % nao pertence ao storefront_id %', NEW.service_zone_id, NEW.storefront_id;
        END IF;
    END IF;

    IF NEW.order_id IS NOT NULL THEN
        SELECT
            user_id,
            merchant_user_id
        INTO
            order_customer_id,
            order_merchant_id
        FROM orders
        WHERE order_id = NEW.order_id;

        IF order_merchant_id IS DISTINCT FROM NEW.merchant_user_id THEN
            RAISE EXCEPTION 'order_id % nao pertence ao merchant_user_id %', NEW.order_id, NEW.merchant_user_id;
        END IF;

        IF NEW.customer_user_id IS NOT NULL AND order_customer_id IS DISTINCT FROM NEW.customer_user_id THEN
            RAISE EXCEPTION 'order_id % nao pertence ao customer_user_id %', NEW.order_id, NEW.customer_user_id;
        END IF;
    END IF;

    IF NEW.gold_campaign_id IS NOT NULL THEN
        SELECT
            merchant_user_id,
            target_storefront_id
        INTO
            campaign_merchant_id,
            campaign_storefront_id
        FROM gold_campaigns
        WHERE gold_campaign_id = NEW.gold_campaign_id;

        IF campaign_merchant_id <> NEW.merchant_user_id THEN
            RAISE EXCEPTION 'gold_campaign_id % nao pertence ao merchant_user_id %', NEW.gold_campaign_id, NEW.merchant_user_id;
        END IF;

        IF campaign_storefront_id IS NOT NULL
           AND NEW.storefront_id IS NOT NULL
           AND campaign_storefront_id <> NEW.storefront_id THEN
            RAISE EXCEPTION 'gold_campaign_id % aponta para storefront diferente do sale_validation_event', NEW.gold_campaign_id;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

-- assert_gold_campaign_event_coherence garante que evento nao escape do merchant/campanha corretos.
CREATE OR REPLACE FUNCTION assert_gold_campaign_event_coherence()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    campaign_merchant_id UUID;
    validation_merchant_id UUID;
    validation_customer_id UUID;
BEGIN
    SELECT merchant_user_id
    INTO campaign_merchant_id
    FROM gold_campaigns
    WHERE gold_campaign_id = NEW.gold_campaign_id;

    IF campaign_merchant_id <> NEW.merchant_user_id THEN
        RAISE EXCEPTION 'gold_campaign_id % nao pertence ao merchant_user_id %', NEW.gold_campaign_id, NEW.merchant_user_id;
    END IF;

    IF NEW.sale_validation_id IS NOT NULL THEN
        SELECT
            merchant_user_id,
            customer_user_id
        INTO
            validation_merchant_id,
            validation_customer_id
        FROM sale_validation_events
        WHERE sale_validation_id = NEW.sale_validation_id;

        IF validation_merchant_id <> NEW.merchant_user_id THEN
            RAISE EXCEPTION 'sale_validation_id % nao pertence ao merchant_user_id %', NEW.sale_validation_id, NEW.merchant_user_id;
        END IF;

        IF NEW.candidate_user_id IS NOT NULL
           AND validation_customer_id IS NOT NULL
           AND validation_customer_id <> NEW.candidate_user_id THEN
            RAISE EXCEPTION 'candidate_user_id % nao casa com sale_validation_id %', NEW.candidate_user_id, NEW.sale_validation_id;
        END IF;
    END IF;

    IF NEW.event_type = 'PEPITA_GRANT' AND (NEW.candidate_user_id IS NULL OR NEW.pepita_amount_brl <= 0) THEN
        RAISE EXCEPTION 'PEPITA_GRANT exige candidate_user_id e pepita_amount_brl positivo';
    END IF;

    RETURN NEW;
END;
$$;

-- apply_pepita_ledger_entry calcula saldo, valida cap e atualiza resumo consolidado da conta.
CREATE OR REPLACE FUNCTION apply_pepita_ledger_entry()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    account_user_id UUID;
    account_status pepita_account_status_enum;
    current_balance DECIMAL(18,4);
    new_balance DECIMAL(18,4);
    event_candidate_id UUID;
    validation_customer_id UUID;
    validation_campaign_id UUID;
    validation_cap_brl DECIMAL(18,4);
BEGIN
    SELECT
        user_id,
        account_status,
        current_balance_brl
    INTO
        account_user_id,
        account_status,
        current_balance
    FROM pepita_accounts
    WHERE pepita_account_id = NEW.pepita_account_id
    FOR UPDATE;

    IF account_user_id IS NULL THEN
        RAISE EXCEPTION 'pepita_account_id % nao encontrado em pepita_accounts', NEW.pepita_account_id;
    END IF;

    IF account_user_id <> NEW.user_id THEN
        RAISE EXCEPTION 'pepita_account_id % nao pertence ao user_id %', NEW.pepita_account_id, NEW.user_id;
    END IF;

    IF account_status <> 'ACTIVE' THEN
        RAISE EXCEPTION 'pepita_account_id % nao esta ACTIVE para novos lancamentos', NEW.pepita_account_id;
    END IF;

    IF NEW.entry_type IN ('REDEEM', 'EXPIRE') AND NEW.amount_brl >= 0 THEN
        RAISE EXCEPTION 'entry_type % exige amount_brl negativo', NEW.entry_type;
    END IF;

    IF NEW.entry_type IN ('EARN', 'GOLD_CONVERSION') AND NEW.amount_brl <= 0 THEN
        RAISE EXCEPTION 'entry_type % exige amount_brl positivo', NEW.entry_type;
    END IF;

    IF NEW.gold_campaign_event_id IS NOT NULL THEN
        SELECT candidate_user_id
        INTO event_candidate_id
        FROM gold_campaign_events
        WHERE gold_campaign_event_id = NEW.gold_campaign_event_id;

        IF event_candidate_id IS NOT NULL AND event_candidate_id <> NEW.user_id THEN
            RAISE EXCEPTION 'gold_campaign_event_id % nao pertence ao user_id %', NEW.gold_campaign_event_id, NEW.user_id;
        END IF;
    END IF;

    IF NEW.sale_validation_id IS NOT NULL THEN
        SELECT
            customer_user_id,
            gold_campaign_id,
            pepita_cap_brl
        INTO
            validation_customer_id,
            validation_campaign_id,
            validation_cap_brl
        FROM sale_validation_events
        WHERE sale_validation_id = NEW.sale_validation_id;

        IF validation_customer_id IS NOT NULL AND validation_customer_id <> NEW.user_id THEN
            RAISE EXCEPTION 'sale_validation_id % nao pertence ao user_id %', NEW.sale_validation_id, NEW.user_id;
        END IF;

        IF NEW.gold_campaign_id IS NOT NULL
           AND validation_campaign_id IS NOT NULL
           AND validation_campaign_id <> NEW.gold_campaign_id THEN
            RAISE EXCEPTION 'gold_campaign_id % nao casa com sale_validation_id %', NEW.gold_campaign_id, NEW.sale_validation_id;
        END IF;

        IF NEW.amount_brl > 0
           AND NEW.entry_type IN ('EARN', 'GOLD_CONVERSION')
           AND NEW.amount_brl > validation_cap_brl THEN
            RAISE EXCEPTION 'amount_brl % ultrapassa pepita_cap_brl % da sale_validation_id %', NEW.amount_brl, validation_cap_brl, NEW.sale_validation_id;
        END IF;
    END IF;

    new_balance := current_balance + NEW.amount_brl;

    IF new_balance < 0 THEN
        RAISE EXCEPTION 'pepita_account_id % ficaria negativo com amount_brl %', NEW.pepita_account_id, NEW.amount_brl;
    END IF;

    NEW.balance_after_brl := new_balance;

    UPDATE pepita_accounts
    SET
        current_balance_brl = new_balance,
        lifetime_earned_brl = lifetime_earned_brl + CASE
            WHEN NEW.amount_brl > 0 AND NEW.entry_type IN ('EARN', 'GOLD_CONVERSION', 'REVERSAL', 'ADJUSTMENT') THEN NEW.amount_brl
            ELSE 0
        END,
        lifetime_redeemed_brl = lifetime_redeemed_brl + CASE
            WHEN NEW.entry_type = 'REDEEM' THEN ABS(NEW.amount_brl)
            ELSE 0
        END,
        lifetime_expired_brl = lifetime_expired_brl + CASE
            WHEN NEW.entry_type = 'EXPIRE' THEN ABS(NEW.amount_brl)
            ELSE 0
        END,
        last_activity_at = NEW.created_at,
        updated_at = NOW()
    WHERE pepita_account_id = NEW.pepita_account_id;

    RETURN NEW;
END;
$$;

-- Indices do Rule Engine para lookup por modulo, status e prioridade.
CREATE INDEX ix_rule_runtime_bindings_module_status
    ON rule_runtime_bindings (module_code, binding_status, priority);

CREATE INDEX ix_rule_runtime_bindings_effective_window
    ON rule_runtime_bindings (effective_from, effective_until)
    WHERE binding_status = 'ACTIVE';

-- Indices de runtime da execucao de regras por modulo, usuario e correlacao.
CREATE INDEX ix_rule_execution_events_module_time
    ON rule_execution_events (module_code, executed_at);

CREATE INDEX ix_rule_execution_events_user_time
    ON rule_execution_events (user_id, executed_at)
    WHERE user_id IS NOT NULL;

CREATE INDEX ix_rule_execution_events_correlation
    ON rule_execution_events (correlation_id, executed_at)
    WHERE correlation_id IS NOT NULL;

-- Indices de storefront e zona para geolocalizacao e operacao comercial.
CREATE INDEX ix_merchant_storefronts_merchant_status
    ON merchant_storefronts (merchant_user_id, storefront_status, created_at);

CREATE INDEX ix_merchant_service_zones_storefront_active
    ON merchant_service_zones (storefront_id, is_active, created_at);

-- Indices de pricing para auto-publicacao e competitividade.
CREATE INDEX ix_marketplace_listing_controls_merchant_status
    ON marketplace_listing_controls (merchant_user_id, pricing_status, updated_at);

CREATE INDEX ix_marketplace_listing_controls_checked_at
    ON marketplace_listing_controls (last_checked_at)
    WHERE last_checked_at IS NOT NULL;

CREATE INDEX ix_marketplace_competitor_snapshots_listing_time
    ON marketplace_competitor_snapshots (listing_id, captured_at);

CREATE INDEX ix_marketplace_competitor_snapshots_item_competitor
    ON marketplace_competitor_snapshots (item_id, competitor_name, captured_at);

-- Indices de Pepitas e GOLD para saldo, budget e trilha de campanha.
CREATE INDEX ix_pepita_accounts_status_activity
    ON pepita_accounts (account_status, last_activity_at);

CREATE INDEX ix_gold_campaigns_merchant_status
    ON gold_campaigns (merchant_user_id, campaign_status, starts_at);

CREATE INDEX ix_gold_campaigns_module_status
    ON gold_campaigns (module_code, campaign_status, created_at);

CREATE INDEX ix_sale_validation_events_merchant_status
    ON sale_validation_events (merchant_user_id, validation_status, created_at);

CREATE INDEX ix_sale_validation_events_order
    ON sale_validation_events (order_id, created_at)
    WHERE order_id IS NOT NULL;

CREATE INDEX ix_sale_validation_events_correlation
    ON sale_validation_events (telemetry_correlation_id, created_at)
    WHERE telemetry_correlation_id IS NOT NULL;

CREATE INDEX ix_gold_campaign_events_campaign_status
    ON gold_campaign_events (gold_campaign_id, event_status, created_at);

CREATE INDEX ix_gold_campaign_events_candidate
    ON gold_campaign_events (candidate_user_id, created_at)
    WHERE candidate_user_id IS NOT NULL;

CREATE INDEX ix_pepita_ledger_user_time
    ON pepita_ledger (user_id, created_at);

CREATE INDEX ix_pepita_ledger_campaign_time
    ON pepita_ledger (gold_campaign_id, created_at)
    WHERE gold_campaign_id IS NOT NULL;

-- Triggers updated_at para tabelas mutaveis.
CREATE TRIGGER trg_rule_runtime_bindings_set_updated_at
BEFORE UPDATE ON rule_runtime_bindings
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_merchant_storefronts_set_updated_at
BEFORE UPDATE ON merchant_storefronts
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_merchant_service_zones_set_updated_at
BEFORE UPDATE ON merchant_service_zones
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_marketplace_listing_controls_set_updated_at
BEFORE UPDATE ON marketplace_listing_controls
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_pepita_accounts_set_updated_at
BEFORE UPDATE ON pepita_accounts
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_gold_campaigns_set_updated_at
BEFORE UPDATE ON gold_campaigns
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_sale_validation_events_set_updated_at
BEFORE UPDATE ON sale_validation_events
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

-- Triggers de coerencia do runtime.
CREATE TRIGGER trg_rule_runtime_bindings_coherence
BEFORE INSERT OR UPDATE ON rule_runtime_bindings
FOR EACH ROW
EXECUTE FUNCTION assert_rule_binding_coherence();

CREATE TRIGGER trg_rule_execution_events_coherence
BEFORE INSERT ON rule_execution_events
FOR EACH ROW
EXECUTE FUNCTION assert_rule_execution_coherence();

CREATE TRIGGER trg_merchant_storefronts_wallet_owner
BEFORE INSERT OR UPDATE ON merchant_storefronts
FOR EACH ROW
EXECUTE FUNCTION assert_storefront_wallet_owner();

CREATE TRIGGER trg_marketplace_listing_controls_coherence
BEFORE INSERT OR UPDATE ON marketplace_listing_controls
FOR EACH ROW
EXECUTE FUNCTION assert_listing_control_coherence();

CREATE TRIGGER trg_marketplace_competitor_snapshots_coherence
BEFORE INSERT ON marketplace_competitor_snapshots
FOR EACH ROW
EXECUTE FUNCTION assert_competitor_snapshot_coherence();

CREATE TRIGGER trg_gold_campaigns_coherence
BEFORE INSERT OR UPDATE ON gold_campaigns
FOR EACH ROW
EXECUTE FUNCTION assert_gold_campaign_coherence();

CREATE TRIGGER trg_sale_validation_events_coherence
BEFORE INSERT OR UPDATE ON sale_validation_events
FOR EACH ROW
EXECUTE FUNCTION assert_sale_validation_coherence();

CREATE TRIGGER trg_gold_campaign_events_coherence
BEFORE INSERT ON gold_campaign_events
FOR EACH ROW
EXECUTE FUNCTION assert_gold_campaign_event_coherence();

CREATE TRIGGER trg_pepita_ledger_apply
BEFORE INSERT ON pepita_ledger
FOR EACH ROW
EXECUTE FUNCTION apply_pepita_ledger_entry();

-- Triggers append-only para trilhas de regra, campanha, competitividade e Pepitas.
CREATE TRIGGER trg_rule_execution_events_prevent_update
BEFORE UPDATE ON rule_execution_events
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

CREATE TRIGGER trg_rule_execution_events_prevent_delete
BEFORE DELETE ON rule_execution_events
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

CREATE TRIGGER trg_marketplace_competitor_snapshots_prevent_update
BEFORE UPDATE ON marketplace_competitor_snapshots
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

CREATE TRIGGER trg_marketplace_competitor_snapshots_prevent_delete
BEFORE DELETE ON marketplace_competitor_snapshots
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

CREATE TRIGGER trg_gold_campaign_events_prevent_update
BEFORE UPDATE ON gold_campaign_events
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

CREATE TRIGGER trg_gold_campaign_events_prevent_delete
BEFORE DELETE ON gold_campaign_events
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

CREATE TRIGGER trg_pepita_ledger_prevent_update
BEFORE UPDATE ON pepita_ledger
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

CREATE TRIGGER trg_pepita_ledger_prevent_delete
BEFORE DELETE ON pepita_ledger
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

-- Regras base da arquitetura de produto: competitividade, cap de Pepita e validacao GOLD.
INSERT INTO business_rule_definitions (
    rule_code,
    module_code,
    rule_name,
    description,
    severity,
    rule_status,
    constraints_json
) VALUES
    ('BR-MKT-COMP-002', 'MARKETPLACE', 'Competitividade do listing', 'Listing de isca so pode ficar ativo quando estiver abaixo do preco de mercado e ainda mantiver margem positiva.', 'HIGH', 'ACTIVE', '{"must_beat_market":true,"require_positive_margin":true,"auto_pause_when_not_competitive":true}'::JSONB),
    ('BR-MKT-PEP-002', 'MARKETPLACE', 'Cap de Pepita por lucro liquido', 'Pepita concedida em venda validada nao pode ultrapassar 50 por cento do lucro liquido de referencia.', 'CRITICAL', 'ACTIVE', '{"max_profit_share":0.50,"applies_to":["pepita_grant","gold_conversion"]}'::JSONB),
    ('BR-ADS-GOLD-002', 'ADS', 'GOLD so liquida em venda validada', 'Campanha GOLD so pode virar receita Valley e Pepita quando a venda do marketplace ou do PDV fisico for validada.', 'CRITICAL', 'ACTIVE', '{"requires_validated_sale":true,"accepted_sources":["MARKETPLACE_ORDER","PHYSICAL_POS","GPS_CHECKIN","MANUAL_REVIEW"]}'::JSONB)
ON CONFLICT (rule_code) DO UPDATE SET
    module_code = EXCLUDED.module_code,
    rule_name = EXCLUDED.rule_name,
    description = EXCLUDED.description,
    severity = EXCLUDED.severity,
    rule_status = EXCLUDED.rule_status,
    constraints_json = EXCLUDED.constraints_json,
    updated_at = NOW();

WITH selected_rules AS (
    SELECT
        rule_id,
        rule_code,
        constraints_json
    FROM business_rule_definitions
    WHERE rule_code IN ('BR-MKT-COMP-002', 'BR-MKT-PEP-002', 'BR-ADS-GOLD-002')
)
INSERT INTO business_rule_versions (
    rule_id,
    version_number,
    definition_json,
    enabled,
    change_log
)
SELECT
    rule_id,
    1,
    jsonb_build_object(
        'rule_code', rule_code,
        'source', 'Arquitetura de Produto e Mecanica de Negocio Valley',
        'constraints', constraints_json
    ),
    FALSE,
    'Versao inicial para runtime de competitividade, Pepita e GOLD; ativacao fica sob governance admin.'
FROM selected_rules
ON CONFLICT (rule_id, version_number) DO NOTHING;

COMMENT ON TYPE rule_binding_scope_enum IS 'Escopo operacional do binding de regra no runtime.';
COMMENT ON TYPE rule_binding_status_enum IS 'Status do binding da regra: rascunho, ativo, pausado ou arquivado.';
COMMENT ON TYPE rule_execution_status_enum IS 'Resultado da avaliacao da regra em runtime.';
COMMENT ON TYPE pepita_account_status_enum IS 'Status da conta de Pepitas do usuario.';
COMMENT ON TYPE pepita_entry_type_enum IS 'Tipo de lancamento append-only do ledger de Pepitas.';
COMMENT ON TYPE gold_campaign_type_enum IS 'Tipo da campanha GOLD orientada a trafego ou conversao.';
COMMENT ON TYPE gold_campaign_status_enum IS 'Status operacional da campanha GOLD.';
COMMENT ON TYPE gold_event_type_enum IS 'Evento append-only da campanha GOLD.';
COMMENT ON TYPE gold_event_status_enum IS 'Status do evento GOLD durante validacao e liquidacao.';
COMMENT ON TYPE storefront_status_enum IS 'Status operacional da fachada comercial do merchant.';
COMMENT ON TYPE service_zone_shape_enum IS 'Formato da zona de atendimento: raio ou poligono.';
COMMENT ON TYPE sale_validation_source_enum IS 'Origem da prova de venda usada por GOLD e Pepitas.';
COMMENT ON TYPE sale_validation_status_enum IS 'Resultado da validacao comercial ou fisica da venda.';
COMMENT ON TYPE listing_pricing_status_enum IS 'Status de competitividade do listing perante o mercado.';

COMMENT ON TABLE rule_runtime_bindings IS 'Bindings do Rule Engine que acoplam uma versao de regra ao runtime do modulo.';
COMMENT ON TABLE rule_execution_events IS 'Trilha append-only das avaliacoes do Rule Engine.';
COMMENT ON TABLE merchant_storefronts IS 'Storefronts comerciais dos merchants para geolocalizacao, zonas e vendas.';
COMMENT ON TABLE merchant_service_zones IS 'Zonas de entrega/atendimento por storefront.';
COMMENT ON TABLE marketplace_listing_controls IS 'Controles de competitividade e auto-publicacao de listings.';
COMMENT ON TABLE marketplace_competitor_snapshots IS 'Snapshots append-only dos concorrentes usados na comparacao de preco.';
COMMENT ON TABLE pepita_accounts IS 'Saldo consolidado de Pepitas por usuario.';
COMMENT ON TABLE gold_campaigns IS 'Campanhas GOLD com split entre receita Valley e pool de Pepitas.';
COMMENT ON TABLE sale_validation_events IS 'Eventos de validacao de venda marketplace ou fisica.';
COMMENT ON TABLE gold_campaign_events IS 'Eventos append-only de campanha GOLD, conversao e liquidacao.';
COMMENT ON TABLE pepita_ledger IS 'Ledger append-only de Pepitas por usuario.';

COMMENT ON FUNCTION assert_rule_binding_coherence() IS 'Valida se binding usa versao correta da regra e exige versao enabled para status ACTIVE.';
COMMENT ON FUNCTION assert_rule_execution_coherence() IS 'Valida se evento runtime aponta para rule, version e binding coerentes.';
COMMENT ON FUNCTION assert_storefront_wallet_owner() IS 'Valida se wallet do storefront pertence ao merchant.';
COMMENT ON FUNCTION assert_listing_control_coherence() IS 'Valida se controle de pricing usa listing do merchant correto e binding MARKETPLACE.';
COMMENT ON FUNCTION assert_competitor_snapshot_coherence() IS 'Valida se snapshot de concorrente pertence ao listing, item e merchant corretos.';
COMMENT ON FUNCTION assert_gold_campaign_coherence() IS 'Valida split, wallet, storefront, zona e campanha de Pepita ligados a GOLD.';
COMMENT ON FUNCTION assert_sale_validation_coherence() IS 'Valida storefront, zona, order e campanha na prova de venda.';
COMMENT ON FUNCTION assert_gold_campaign_event_coherence() IS 'Valida campanha, merchant e candidato do evento GOLD.';
COMMENT ON FUNCTION apply_pepita_ledger_entry() IS 'Calcula saldo append-only de Pepitas, aplica cap de venda validada e atualiza resumo da conta.';

COMMENT ON COLUMN rule_runtime_bindings.binding_id IS 'PK UUID do binding runtime.';
COMMENT ON COLUMN rule_runtime_bindings.rule_id IS 'FK para business_rule_definitions.';
COMMENT ON COLUMN rule_runtime_bindings.rule_version_id IS 'FK para business_rule_versions.';
COMMENT ON COLUMN rule_runtime_bindings.module_code IS 'FK para module_delivery_registry do modulo alvo.';
COMMENT ON COLUMN rule_runtime_bindings.binding_scope IS 'Escopo do binding: global, modulo, merchant, listing, pedido, campanha ou validacao.';
COMMENT ON COLUMN rule_runtime_bindings.target_reference IS 'Referencia textual do alvo dentro do escopo escolhido.';
COMMENT ON COLUMN rule_runtime_bindings.priority IS 'Prioridade de avaliacao: menor valor = maior precedencia.';
COMMENT ON COLUMN rule_runtime_bindings.binding_status IS 'Status operacional do binding.';
COMMENT ON COLUMN rule_runtime_bindings.conditions_json IS 'Condicoes de entrada em JSONB.';
COMMENT ON COLUMN rule_runtime_bindings.action_overrides_json IS 'Overrides tecnicos de acao em JSONB.';
COMMENT ON COLUMN rule_runtime_bindings.effective_from IS 'Inicio opcional da vigencia do binding.';
COMMENT ON COLUMN rule_runtime_bindings.effective_until IS 'Fim opcional da vigencia do binding.';
COMMENT ON COLUMN rule_runtime_bindings.created_by_admin_id IS 'Admin que criou o binding.';
COMMENT ON COLUMN rule_runtime_bindings.created_at IS 'Criacao do binding.';
COMMENT ON COLUMN rule_runtime_bindings.updated_at IS 'Ultima atualizacao do binding.';

COMMENT ON COLUMN rule_execution_events.rule_execution_event_id IS 'PK UUID do evento de execucao.';
COMMENT ON COLUMN rule_execution_events.binding_id IS 'FK opcional para binding runtime usado.';
COMMENT ON COLUMN rule_execution_events.rule_id IS 'FK para business_rule_definitions.';
COMMENT ON COLUMN rule_execution_events.rule_version_id IS 'FK para business_rule_versions.';
COMMENT ON COLUMN rule_execution_events.module_code IS 'FK para module_delivery_registry do modulo avaliado.';
COMMENT ON COLUMN rule_execution_events.user_id IS 'FK opcional para usuario afetado.';
COMMENT ON COLUMN rule_execution_events.order_id IS 'FK opcional para order avaliada.';
COMMENT ON COLUMN rule_execution_events.transaction_id IS 'FK opcional para transaction avaliada.';
COMMENT ON COLUMN rule_execution_events.reference_entity_type IS 'Tipo generico da entidade analisada quando nao ha FK direta.';
COMMENT ON COLUMN rule_execution_events.reference_entity_id IS 'Identificador textual da entidade analisada.';
COMMENT ON COLUMN rule_execution_events.execution_status IS 'Resultado tecnico da avaliacao.';
COMMENT ON COLUMN rule_execution_events.decision_code IS 'Codigo curto e estavel da decisao tomada.';
COMMENT ON COLUMN rule_execution_events.input_snapshot_json IS 'Payload de entrada usado pela regra.';
COMMENT ON COLUMN rule_execution_events.output_snapshot_json IS 'Payload de saida ou explicacao tecnica.';
COMMENT ON COLUMN rule_execution_events.correlation_id IS 'ID de correlacao entre API, admin e telemetria.';
COMMENT ON COLUMN rule_execution_events.executed_at IS 'Horario append-only da execucao.';

COMMENT ON COLUMN merchant_storefronts.storefront_id IS 'PK UUID do storefront.';
COMMENT ON COLUMN merchant_storefronts.merchant_user_id IS 'FK para users.user_id do merchant.';
COMMENT ON COLUMN merchant_storefronts.wallet_id IS 'FK para wallet de recebimento do merchant.';
COMMENT ON COLUMN merchant_storefronts.module_code IS 'FK para module_delivery_registry, normalmente MARKETPLACE.';
COMMENT ON COLUMN merchant_storefronts.storefront_code IS 'Codigo tecnico unico por merchant.';
COMMENT ON COLUMN merchant_storefronts.storefront_name IS 'Nome publico da operacao comercial.';
COMMENT ON COLUMN merchant_storefronts.storefront_status IS 'Status operacional da loja/fachada.';
COMMENT ON COLUMN merchant_storefronts.address_json IS 'Endereco estruturado em JSONB.';
COMMENT ON COLUMN merchant_storefronts.geo_json IS 'GeoJSON da base fisica quando houver.';
COMMENT ON COLUMN merchant_storefronts.service_radius_km IS 'Raio operacional base em quilometros.';
COMMENT ON COLUMN merchant_storefronts.supported_domains IS 'Dominios de pedidos suportados pelo storefront.';
COMMENT ON COLUMN merchant_storefronts.service_modes IS 'Modos de atendimento, como DELIVERY, PICKUP ou ONSITE.';
COMMENT ON COLUMN merchant_storefronts.accepts_marketplace_sales IS 'Indica se aceita venda nativa do marketplace.';
COMMENT ON COLUMN merchant_storefronts.accepts_physical_sales IS 'Indica se aceita validacao de venda fisica.';
COMMENT ON COLUMN merchant_storefronts.schedule_json IS 'Agenda operacional em JSONB.';
COMMENT ON COLUMN merchant_storefronts.metadata_json IS 'Metadados livres do storefront.';
COMMENT ON COLUMN merchant_storefronts.created_at IS 'Criacao do storefront.';
COMMENT ON COLUMN merchant_storefronts.updated_at IS 'Ultima atualizacao do storefront.';

COMMENT ON COLUMN merchant_service_zones.service_zone_id IS 'PK UUID da zona.';
COMMENT ON COLUMN merchant_service_zones.storefront_id IS 'FK para merchant_storefronts.';
COMMENT ON COLUMN merchant_service_zones.zone_name IS 'Nome humano da zona de atendimento.';
COMMENT ON COLUMN merchant_service_zones.zone_shape IS 'Formato da zona: raio ou poligono.';
COMMENT ON COLUMN merchant_service_zones.zone_geo_json IS 'Geometria em JSONB com padrao GeoJSON.';
COMMENT ON COLUMN merchant_service_zones.delivery_fee_brl IS 'Taxa base de entrega em BRL.';
COMMENT ON COLUMN merchant_service_zones.minimum_order_brl IS 'Pedido minimo da zona.';
COMMENT ON COLUMN merchant_service_zones.eta_min_minutes IS 'ETA minimo da zona.';
COMMENT ON COLUMN merchant_service_zones.eta_max_minutes IS 'ETA maximo da zona.';
COMMENT ON COLUMN merchant_service_zones.is_active IS 'Indica se a zona esta operacional.';
COMMENT ON COLUMN merchant_service_zones.created_at IS 'Criacao da zona.';
COMMENT ON COLUMN merchant_service_zones.updated_at IS 'Ultima atualizacao da zona.';

COMMENT ON COLUMN marketplace_listing_controls.listing_control_id IS 'PK UUID do controle de listing.';
COMMENT ON COLUMN marketplace_listing_controls.listing_id IS 'FK para marketplace_listings.';
COMMENT ON COLUMN marketplace_listing_controls.merchant_user_id IS 'FK para owner do listing.';
COMMENT ON COLUMN marketplace_listing_controls.rule_binding_id IS 'FK opcional para binding runtime de pricing.';
COMMENT ON COLUMN marketplace_listing_controls.pricing_status IS 'Status atual de competitividade do anuncio.';
COMMENT ON COLUMN marketplace_listing_controls.valley_cost_brl IS 'Custo total Valley considerado no pricing.';
COMMENT ON COLUMN marketplace_listing_controls.target_margin_brl IS 'Margem alvo do anuncio.';
COMMENT ON COLUMN marketplace_listing_controls.minimum_price_brl IS 'Preco minimo saudavel para nao operar no prejuizo.';
COMMENT ON COLUMN marketplace_listing_controls.last_market_reference_brl IS 'Ultimo preco externo de referencia encontrado.';
COMMENT ON COLUMN marketplace_listing_controls.last_competitor_name IS 'Nome do concorrente usado como referencia.';
COMMENT ON COLUMN marketplace_listing_controls.last_checked_at IS 'Ultima verificacao de competitividade.';
COMMENT ON COLUMN marketplace_listing_controls.auto_publish_enabled IS 'Permite auto-publicacao e auto-pausa do listing.';
COMMENT ON COLUMN marketplace_listing_controls.publish_block_reason IS 'Motivo textual do bloqueio de publicacao.';
COMMENT ON COLUMN marketplace_listing_controls.metadata_json IS 'Metadados de pricing e scraping.';
COMMENT ON COLUMN marketplace_listing_controls.created_at IS 'Criacao do controle.';
COMMENT ON COLUMN marketplace_listing_controls.updated_at IS 'Ultima atualizacao do controle.';

COMMENT ON COLUMN marketplace_competitor_snapshots.competitor_snapshot_id IS 'PK UUID do snapshot.';
COMMENT ON COLUMN marketplace_competitor_snapshots.listing_id IS 'FK para marketplace_listings.';
COMMENT ON COLUMN marketplace_competitor_snapshots.item_id IS 'FK para inventory_items.';
COMMENT ON COLUMN marketplace_competitor_snapshots.merchant_user_id IS 'FK para owner do listing.';
COMMENT ON COLUMN marketplace_competitor_snapshots.competitor_name IS 'Nome do competidor comparado.';
COMMENT ON COLUMN marketplace_competitor_snapshots.competitor_url IS 'URL opcional da oferta concorrente.';
COMMENT ON COLUMN marketplace_competitor_snapshots.competitor_sku IS 'SKU do concorrente quando existir.';
COMMENT ON COLUMN marketplace_competitor_snapshots.competitor_price_brl IS 'Preco anunciado pelo concorrente.';
COMMENT ON COLUMN marketplace_competitor_snapshots.shipping_price_brl IS 'Frete visto no concorrente.';
COMMENT ON COLUMN marketplace_competitor_snapshots.captured_at IS 'Horario append-only da captura.';

COMMENT ON COLUMN pepita_accounts.pepita_account_id IS 'PK UUID da conta de Pepitas.';
COMMENT ON COLUMN pepita_accounts.user_id IS 'FK para users.user_id dono do saldo.';
COMMENT ON COLUMN pepita_accounts.account_status IS 'Status operacional da conta.';
COMMENT ON COLUMN pepita_accounts.current_balance_brl IS 'Saldo atual em BRL gamificado.';
COMMENT ON COLUMN pepita_accounts.lifetime_earned_brl IS 'Total historico ganho.';
COMMENT ON COLUMN pepita_accounts.lifetime_redeemed_brl IS 'Total historico resgatado.';
COMMENT ON COLUMN pepita_accounts.lifetime_expired_brl IS 'Total historico expirado.';
COMMENT ON COLUMN pepita_accounts.last_activity_at IS 'Ultimo evento relevante da conta.';
COMMENT ON COLUMN pepita_accounts.created_at IS 'Criacao da conta.';
COMMENT ON COLUMN pepita_accounts.updated_at IS 'Ultima atualizacao da conta.';

COMMENT ON COLUMN gold_campaigns.gold_campaign_id IS 'PK UUID da campanha GOLD.';
COMMENT ON COLUMN gold_campaigns.campaign_id IS 'FK opcional para gamification_campaigns.';
COMMENT ON COLUMN gold_campaigns.merchant_user_id IS 'FK para merchant que comprou GOLD.';
COMMENT ON COLUMN gold_campaigns.wallet_id IS 'FK para wallet de funding.';
COMMENT ON COLUMN gold_campaigns.module_code IS 'FK para module_delivery_registry, normalmente ADS.';
COMMENT ON COLUMN gold_campaigns.campaign_type IS 'Tipo da campanha GOLD.';
COMMENT ON COLUMN gold_campaigns.campaign_status IS 'Status operacional da campanha.';
COMMENT ON COLUMN gold_campaigns.campaign_name IS 'Nome comercial da campanha.';
COMMENT ON COLUMN gold_campaigns.objective IS 'Objetivo simples da campanha.';
COMMENT ON COLUMN gold_campaigns.target_storefront_id IS 'FK opcional para storefront alvo.';
COMMENT ON COLUMN gold_campaigns.target_zone_id IS 'FK opcional para zona alvo.';
COMMENT ON COLUMN gold_campaigns.budget_brl IS 'Budget total comprado pelo merchant.';
COMMENT ON COLUMN gold_campaigns.valley_revenue_brl IS 'Parcela que vira receita Valley.';
COMMENT ON COLUMN gold_campaigns.pepita_pool_brl IS 'Parcela reservada para Pepitas.';
COMMENT ON COLUMN gold_campaigns.minimum_ticket_brl IS 'Ticket minimo aceito para conversao.';
COMMENT ON COLUMN gold_campaigns.target_geo_json IS 'GeoJSON alvo da campanha quando existir.';
COMMENT ON COLUMN gold_campaigns.target_radius_km IS 'Raio alvo da campanha.';
COMMENT ON COLUMN gold_campaigns.starts_at IS 'Inicio da campanha.';
COMMENT ON COLUMN gold_campaigns.ends_at IS 'Fim da campanha.';
COMMENT ON COLUMN gold_campaigns.validation_window_minutes IS 'Janela de validacao apos evento.';
COMMENT ON COLUMN gold_campaigns.metadata_json IS 'Metadados de segmentacao e budget.';
COMMENT ON COLUMN gold_campaigns.created_at IS 'Criacao da campanha.';
COMMENT ON COLUMN gold_campaigns.updated_at IS 'Ultima atualizacao da campanha.';

COMMENT ON COLUMN sale_validation_events.sale_validation_id IS 'PK UUID da validacao.';
COMMENT ON COLUMN sale_validation_events.module_code IS 'FK para module_delivery_registry do fluxo dono.';
COMMENT ON COLUMN sale_validation_events.merchant_user_id IS 'FK para merchant da venda.';
COMMENT ON COLUMN sale_validation_events.customer_user_id IS 'FK opcional para cliente da venda.';
COMMENT ON COLUMN sale_validation_events.rider_user_id IS 'FK opcional para rider participante.';
COMMENT ON COLUMN sale_validation_events.storefront_id IS 'FK opcional para storefront da venda.';
COMMENT ON COLUMN sale_validation_events.service_zone_id IS 'FK opcional para zona operacional.';
COMMENT ON COLUMN sale_validation_events.gold_campaign_id IS 'FK opcional para campanha GOLD associada.';
COMMENT ON COLUMN sale_validation_events.order_id IS 'FK opcional para order do marketplace.';
COMMENT ON COLUMN sale_validation_events.transaction_id IS 'FK opcional para transaction relacionada.';
COMMENT ON COLUMN sale_validation_events.validation_source IS 'Origem da prova de venda.';
COMMENT ON COLUMN sale_validation_events.validation_status IS 'Status atual da validacao.';
COMMENT ON COLUMN sale_validation_events.sale_reference_code IS 'Codigo externo ou fiscal da venda.';
COMMENT ON COLUMN sale_validation_events.telemetry_correlation_id IS 'Correlation ID vindo de GPS, POS ou app.';
COMMENT ON COLUMN sale_validation_events.gross_amount_brl IS 'Valor bruto da venda.';
COMMENT ON COLUMN sale_validation_events.net_profit_reference_brl IS 'Lucro liquido de referencia para cap de Pepita.';
COMMENT ON COLUMN sale_validation_events.pepita_cap_brl IS 'Cap maximo de Pepita: ate 50 por cento do lucro liquido.';
COMMENT ON COLUMN sale_validation_events.gps_point_json IS 'GeoJSON Point de confirmacao quando a venda for fisica.';
COMMENT ON COLUMN sale_validation_events.validation_payload_json IS 'Payload bruto e resumido da validacao.';
COMMENT ON COLUMN sale_validation_events.validated_by_user_id IS 'FK opcional para operador, rider ou sistema que validou.';
COMMENT ON COLUMN sale_validation_events.validated_at IS 'Horario da validacao.';
COMMENT ON COLUMN sale_validation_events.expires_at IS 'Horario limite para aprovar o evento.';
COMMENT ON COLUMN sale_validation_events.created_at IS 'Criacao da validacao.';
COMMENT ON COLUMN sale_validation_events.updated_at IS 'Ultima atualizacao da validacao.';

COMMENT ON COLUMN gold_campaign_events.gold_campaign_event_id IS 'PK UUID do evento GOLD.';
COMMENT ON COLUMN gold_campaign_events.gold_campaign_id IS 'FK para gold_campaigns.';
COMMENT ON COLUMN gold_campaign_events.sale_validation_id IS 'FK opcional para sale_validation_events.';
COMMENT ON COLUMN gold_campaign_events.candidate_user_id IS 'FK opcional para usuario elegivel a Pepita.';
COMMENT ON COLUMN gold_campaign_events.merchant_user_id IS 'FK para merchant dono da campanha.';
COMMENT ON COLUMN gold_campaign_events.order_id IS 'FK opcional para order vinculada.';
COMMENT ON COLUMN gold_campaign_events.transaction_id IS 'FK opcional para transaction vinculada.';
COMMENT ON COLUMN gold_campaign_events.event_type IS 'Tipo do evento de campanha.';
COMMENT ON COLUMN gold_campaign_events.event_status IS 'Status do evento dentro do workflow.';
COMMENT ON COLUMN gold_campaign_events.gold_amount_brl IS 'Valor financeiro do evento GOLD.';
COMMENT ON COLUMN gold_campaign_events.pepita_amount_brl IS 'Valor de Pepita associado ao evento.';
COMMENT ON COLUMN gold_campaign_events.valley_revenue_amount_brl IS 'Parcela reconhecida como receita Valley.';
COMMENT ON COLUMN gold_campaign_events.reason_code IS 'Codigo curto do motivo do evento.';
COMMENT ON COLUMN gold_campaign_events.payload_json IS 'Detalhes tecnicos do evento em JSONB.';
COMMENT ON COLUMN gold_campaign_events.created_at IS 'Criacao append-only do evento.';

COMMENT ON COLUMN pepita_ledger.pepita_ledger_id IS 'PK UUID do ledger de Pepitas.';
COMMENT ON COLUMN pepita_ledger.pepita_account_id IS 'FK para pepita_accounts.';
COMMENT ON COLUMN pepita_ledger.user_id IS 'FK para owner do saldo.';
COMMENT ON COLUMN pepita_ledger.campaign_id IS 'FK opcional para gamification_campaigns.';
COMMENT ON COLUMN pepita_ledger.gold_campaign_id IS 'FK opcional para gold_campaigns.';
COMMENT ON COLUMN pepita_ledger.gold_campaign_event_id IS 'FK opcional para gold_campaign_events.';
COMMENT ON COLUMN pepita_ledger.sale_validation_id IS 'FK opcional para sale_validation_events.';
COMMENT ON COLUMN pepita_ledger.order_id IS 'FK opcional para orders.';
COMMENT ON COLUMN pepita_ledger.transaction_id IS 'FK opcional para transactions.';
COMMENT ON COLUMN pepita_ledger.entry_type IS 'Tipo do lancamento append-only.';
COMMENT ON COLUMN pepita_ledger.amount_brl IS 'Delta do saldo: positivo ganha, negativo usa/expira.';
COMMENT ON COLUMN pepita_ledger.balance_after_brl IS 'Saldo resultante apos o lancamento.';
COMMENT ON COLUMN pepita_ledger.reason_code IS 'Codigo estavel do motivo do lancamento.';
COMMENT ON COLUMN pepita_ledger.description IS 'Descricao humana simples do evento.';
COMMENT ON COLUMN pepita_ledger.expires_at IS 'Validade opcional do credito.';
COMMENT ON COLUMN pepita_ledger.created_at IS 'Criacao append-only do lancamento.';

COMMIT;
