-- Implanta o blueprint de producao do Dropshipping Inteligente no MVP Valley.
-- Foco: STOCK + WMS + MARKETPLACE com API-first, cache, filas, pricing auditavel e bloqueio de IA externa.

BEGIN;

SET search_path = public;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'dropshipping_provider_role_enum') THEN
        CREATE TYPE dropshipping_provider_role_enum AS ENUM (
            'SUPPLIER_API',
            'MARKETPLACE_PRICE',
            'BOTH'
        );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'dropshipping_provider_code_enum') THEN
        CREATE TYPE dropshipping_provider_code_enum AS ENUM (
            'MERCADO_LIVRE',
            'AMAZON',
            'ALIEXPRESS',
            'ALIBABA',
            'MAGALU',
            'CJDROPSHIPPING',
            'SHOPEE'
        );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'dropshipping_runtime_status_enum') THEN
        CREATE TYPE dropshipping_runtime_status_enum AS ENUM (
            'DRAFT',
            'ACTIVE',
            'PAUSED',
            'ERROR',
            'ARCHIVED'
        );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'dropshipping_source_type_enum') THEN
        CREATE TYPE dropshipping_source_type_enum AS ENUM (
            'API',
            'SCRAPING_FALLBACK',
            'CACHE',
            'MANUAL'
        );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'dropshipping_decision_action_enum') THEN
        CREATE TYPE dropshipping_decision_action_enum AS ENUM (
            'KEEP_ACTIVE',
            'UPDATE_PRICE',
            'AUTO_PAUSE',
            'MANUAL_REVIEW'
        );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'dropshipping_job_type_enum') THEN
        CREATE TYPE dropshipping_job_type_enum AS ENUM (
            'IMPORT_PRODUCT',
            'SYNC_STOCK',
            'SYNC_COST',
            'REPRICE',
            'CREATE_SUPPLIER_ORDER',
            'SYNC_TRACKING'
        );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'dropshipping_job_status_enum') THEN
        CREATE TYPE dropshipping_job_status_enum AS ENUM (
            'QUEUED',
            'RUNNING',
            'SUCCEEDED',
            'FAILED',
            'DEAD_LETTER'
        );
    END IF;
END $$;

CREATE TABLE IF NOT EXISTS dropshipping_provider_configs (
    provider_config_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_user_id UUID NOT NULL,
    supplier_id UUID,
    provider_code dropshipping_provider_code_enum NOT NULL,
    provider_role dropshipping_provider_role_enum NOT NULL,
    config_status dropshipping_runtime_status_enum NOT NULL DEFAULT 'DRAFT',
    environment TEXT NOT NULL DEFAULT 'sandbox',
    site_code TEXT NOT NULL DEFAULT 'BR',
    auth_mode TEXT NOT NULL DEFAULT 'oauth2',
    base_url TEXT NOT NULL,
    client_id TEXT,
    secret_ref TEXT,
    access_token_ref TEXT,
    refresh_token_ref TEXT,
    seller_store_id TEXT,
    webhook_url TEXT,
    webhook_secret_ref TEXT,
    scopes TEXT NOT NULL DEFAULT 'catalog,orders,pricing,inventory,settlement',
    sync_catalog_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    sync_orders_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    sync_inventory_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    sync_pricing_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    allow_scraping_fallback BOOLEAN NOT NULL DEFAULT FALSE,
    block_external_ai_lookup BOOLEAN NOT NULL DEFAULT TRUE,
    cache_ttl_minutes INTEGER NOT NULL DEFAULT 20,
    sync_cadence_minutes INTEGER NOT NULL DEFAULT 30,
    margin_floor_rate DECIMAL(8,4) NOT NULL DEFAULT 0.1200,
    rate_limit_per_minute INTEGER NOT NULL DEFAULT 60,
    last_health_status TEXT,
    last_health_at TIMESTAMPTZ,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_dropshipping_provider_configs_owner
        FOREIGN KEY (owner_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_dropshipping_provider_configs_supplier
        FOREIGN KEY (supplier_id) REFERENCES suppliers (supplier_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT ux_dropshipping_provider_configs_owner_provider_env
        UNIQUE (owner_user_id, provider_code, environment),
    CONSTRAINT chk_dropshipping_provider_configs_environment
        CHECK (environment IN ('sandbox', 'staging', 'production')),
    CONSTRAINT chk_dropshipping_provider_configs_site CHECK (btrim(site_code) <> ''),
    CONSTRAINT chk_dropshipping_provider_configs_auth CHECK (btrim(auth_mode) <> ''),
    CONSTRAINT chk_dropshipping_provider_configs_base_url CHECK (base_url ~ '^https?://'),
    CONSTRAINT chk_dropshipping_provider_configs_client_id CHECK (client_id IS NULL OR btrim(client_id) <> ''),
    CONSTRAINT chk_dropshipping_provider_configs_refs CHECK (
        secret_ref IS NULL OR secret_ref LIKE 'vault/%' OR secret_ref LIKE 'secret/%' OR secret_ref LIKE 'env/%'
    ),
    CONSTRAINT chk_dropshipping_provider_configs_access_ref CHECK (
        access_token_ref IS NULL OR access_token_ref LIKE 'vault/%' OR access_token_ref LIKE 'secret/%' OR access_token_ref LIKE 'env/%'
    ),
    CONSTRAINT chk_dropshipping_provider_configs_refresh_ref CHECK (
        refresh_token_ref IS NULL OR refresh_token_ref LIKE 'vault/%' OR refresh_token_ref LIKE 'secret/%' OR refresh_token_ref LIKE 'env/%'
    ),
    CONSTRAINT chk_dropshipping_provider_configs_webhook_ref CHECK (
        webhook_secret_ref IS NULL OR webhook_secret_ref LIKE 'vault/%' OR webhook_secret_ref LIKE 'secret/%' OR webhook_secret_ref LIKE 'env/%'
    ),
    CONSTRAINT chk_dropshipping_provider_configs_cache CHECK (cache_ttl_minutes BETWEEN 1 AND 1440),
    CONSTRAINT chk_dropshipping_provider_configs_sync CHECK (sync_cadence_minutes BETWEEN 5 AND 1440),
    CONSTRAINT chk_dropshipping_provider_configs_margin CHECK (margin_floor_rate >= 0 AND margin_floor_rate <= 1),
    CONSTRAINT chk_dropshipping_provider_configs_rate CHECK (rate_limit_per_minute > 0),
    CONSTRAINT chk_dropshipping_provider_configs_metadata CHECK (jsonb_typeof(metadata_json) = 'object')
);

CREATE TABLE IF NOT EXISTS dropshipping_product_sources (
    product_source_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_user_id UUID NOT NULL,
    item_id UUID NOT NULL,
    supplier_id UUID NOT NULL,
    provider_config_id UUID NOT NULL,
    supplier_product_id TEXT NOT NULL,
    supplier_variant_id TEXT,
    source_sku TEXT NOT NULL,
    source_status dropshipping_runtime_status_enum NOT NULL DEFAULT 'DRAFT',
    cost_price_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    minimum_price_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    current_supplier_stock DECIMAL(18,4) NOT NULL DEFAULT 0,
    lead_time_days INTEGER NOT NULL DEFAULT 0,
    weight_kg DECIMAL(18,4),
    dimensions_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    variation_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    image_refs_json JSONB NOT NULL DEFAULT '[]'::JSONB,
    auto_disable_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    last_synced_at TIMESTAMPTZ,
    last_failure_at TIMESTAMPTZ,
    failure_count INTEGER NOT NULL DEFAULT 0,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_dropshipping_product_sources_owner
        FOREIGN KEY (owner_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_dropshipping_product_sources_item
        FOREIGN KEY (item_id) REFERENCES inventory_items (item_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_dropshipping_product_sources_supplier
        FOREIGN KEY (supplier_id) REFERENCES suppliers (supplier_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_dropshipping_product_sources_provider
        FOREIGN KEY (provider_config_id) REFERENCES dropshipping_provider_configs (provider_config_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT ux_dropshipping_product_sources_owner_provider_sku
        UNIQUE (owner_user_id, provider_config_id, source_sku),
    CONSTRAINT chk_dropshipping_product_sources_product CHECK (btrim(supplier_product_id) <> ''),
    CONSTRAINT chk_dropshipping_product_sources_variant CHECK (supplier_variant_id IS NULL OR btrim(supplier_variant_id) <> ''),
    CONSTRAINT chk_dropshipping_product_sources_sku CHECK (btrim(source_sku) <> ''),
    CONSTRAINT chk_dropshipping_product_sources_money CHECK (
        cost_price_brl >= 0
        AND minimum_price_brl >= 0
    ),
    CONSTRAINT chk_dropshipping_product_sources_stock CHECK (current_supplier_stock >= 0),
    CONSTRAINT chk_dropshipping_product_sources_lead_time CHECK (lead_time_days >= 0),
    CONSTRAINT chk_dropshipping_product_sources_weight CHECK (weight_kg IS NULL OR weight_kg >= 0),
    CONSTRAINT chk_dropshipping_product_sources_failure CHECK (failure_count >= 0),
    CONSTRAINT chk_dropshipping_product_sources_dimensions CHECK (jsonb_typeof(dimensions_json) = 'object'),
    CONSTRAINT chk_dropshipping_product_sources_variation CHECK (jsonb_typeof(variation_json) = 'object'),
    CONSTRAINT chk_dropshipping_product_sources_images CHECK (jsonb_typeof(image_refs_json) = 'array'),
    CONSTRAINT chk_dropshipping_product_sources_metadata CHECK (jsonb_typeof(metadata_json) = 'object')
);

CREATE TABLE IF NOT EXISTS dropshipping_market_price_snapshots (
    market_price_snapshot_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_user_id UUID NOT NULL,
    item_id UUID NOT NULL,
    listing_id UUID,
    provider_config_id UUID,
    marketplace_code dropshipping_provider_code_enum NOT NULL,
    external_listing_id TEXT,
    matched_title TEXT NOT NULL,
    matched_url TEXT,
    price_brl DECIMAL(18,4) NOT NULL,
    freight_price_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    match_score DECIMAL(5,2) NOT NULL DEFAULT 0,
    source_type dropshipping_source_type_enum NOT NULL DEFAULT 'API',
    cache_hit BOOLEAN NOT NULL DEFAULT FALSE,
    response_latency_ms INTEGER,
    captured_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    CONSTRAINT fk_dropshipping_market_price_snapshots_owner
        FOREIGN KEY (owner_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_dropshipping_market_price_snapshots_item
        FOREIGN KEY (item_id) REFERENCES inventory_items (item_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_dropshipping_market_price_snapshots_listing
        FOREIGN KEY (listing_id) REFERENCES marketplace_listings (listing_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_dropshipping_market_price_snapshots_provider
        FOREIGN KEY (provider_config_id) REFERENCES dropshipping_provider_configs (provider_config_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT chk_dropshipping_market_price_snapshots_marketplace CHECK (
        marketplace_code IN ('MERCADO_LIVRE', 'AMAZON', 'SHOPEE', 'MAGALU')
    ),
    CONSTRAINT chk_dropshipping_market_price_snapshots_title CHECK (btrim(matched_title) <> ''),
    CONSTRAINT chk_dropshipping_market_price_snapshots_external CHECK (
        external_listing_id IS NULL OR btrim(external_listing_id) <> ''
    ),
    CONSTRAINT chk_dropshipping_market_price_snapshots_url CHECK (matched_url IS NULL OR btrim(matched_url) <> ''),
    CONSTRAINT chk_dropshipping_market_price_snapshots_money CHECK (
        price_brl >= 0
        AND freight_price_brl >= 0
    ),
    CONSTRAINT chk_dropshipping_market_price_snapshots_score CHECK (match_score >= 0 AND match_score <= 100),
    CONSTRAINT chk_dropshipping_market_price_snapshots_latency CHECK (response_latency_ms IS NULL OR response_latency_ms >= 0),
    CONSTRAINT chk_dropshipping_market_price_snapshots_metadata CHECK (jsonb_typeof(metadata_json) = 'object')
);

CREATE TABLE IF NOT EXISTS dropshipping_pricing_decisions (
    pricing_decision_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_user_id UUID NOT NULL,
    item_id UUID NOT NULL,
    listing_id UUID,
    product_source_id UUID,
    evidence_snapshot_id UUID,
    decision_action dropshipping_decision_action_enum NOT NULL,
    previous_price_brl DECIMAL(18,4),
    decided_price_brl DECIMAL(18,4),
    minimum_price_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    lowest_market_price_brl DECIMAL(18,4),
    delta_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    target_margin_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    decision_reason TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    CONSTRAINT fk_dropshipping_pricing_decisions_owner
        FOREIGN KEY (owner_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_dropshipping_pricing_decisions_item
        FOREIGN KEY (item_id) REFERENCES inventory_items (item_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_dropshipping_pricing_decisions_listing
        FOREIGN KEY (listing_id) REFERENCES marketplace_listings (listing_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_dropshipping_pricing_decisions_source
        FOREIGN KEY (product_source_id) REFERENCES dropshipping_product_sources (product_source_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_dropshipping_pricing_decisions_snapshot
        FOREIGN KEY (evidence_snapshot_id) REFERENCES dropshipping_market_price_snapshots (market_price_snapshot_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT chk_dropshipping_pricing_decisions_money CHECK (
        COALESCE(previous_price_brl, 0) >= 0
        AND COALESCE(decided_price_brl, 0) >= 0
        AND minimum_price_brl >= 0
        AND COALESCE(lowest_market_price_brl, 0) >= 0
        AND delta_brl >= 0
        AND target_margin_brl >= 0
    ),
    CONSTRAINT chk_dropshipping_pricing_decisions_reason CHECK (btrim(decision_reason) <> ''),
    CONSTRAINT chk_dropshipping_pricing_decisions_metadata CHECK (jsonb_typeof(metadata_json) = 'object')
);

CREATE TABLE IF NOT EXISTS dropshipping_supplier_orders (
    dropshipping_supplier_order_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_user_id UUID NOT NULL,
    order_id UUID NOT NULL,
    supplier_id UUID NOT NULL,
    provider_config_id UUID NOT NULL,
    product_source_id UUID,
    external_supplier_order_id TEXT,
    supplier_order_status TEXT NOT NULL DEFAULT 'DRAFT',
    purchase_cost_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    shipping_cost_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    tracking_code TEXT,
    tracking_url TEXT,
    submitted_at TIMESTAMPTZ,
    confirmed_at TIMESTAMPTZ,
    last_synced_at TIMESTAMPTZ,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_dropshipping_supplier_orders_owner
        FOREIGN KEY (owner_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_dropshipping_supplier_orders_order
        FOREIGN KEY (order_id) REFERENCES orders (order_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_dropshipping_supplier_orders_supplier
        FOREIGN KEY (supplier_id) REFERENCES suppliers (supplier_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_dropshipping_supplier_orders_provider
        FOREIGN KEY (provider_config_id) REFERENCES dropshipping_provider_configs (provider_config_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_dropshipping_supplier_orders_source
        FOREIGN KEY (product_source_id) REFERENCES dropshipping_product_sources (product_source_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT ux_dropshipping_supplier_orders_order_supplier UNIQUE (order_id, supplier_id),
    CONSTRAINT chk_dropshipping_supplier_orders_status CHECK (btrim(supplier_order_status) <> ''),
    CONSTRAINT chk_dropshipping_supplier_orders_external CHECK (
        external_supplier_order_id IS NULL OR btrim(external_supplier_order_id) <> ''
    ),
    CONSTRAINT chk_dropshipping_supplier_orders_money CHECK (
        purchase_cost_brl >= 0
        AND shipping_cost_brl >= 0
    ),
    CONSTRAINT chk_dropshipping_supplier_orders_tracking CHECK (tracking_code IS NULL OR btrim(tracking_code) <> ''),
    CONSTRAINT chk_dropshipping_supplier_orders_tracking_url CHECK (tracking_url IS NULL OR btrim(tracking_url) <> ''),
    CONSTRAINT chk_dropshipping_supplier_orders_metadata CHECK (jsonb_typeof(metadata_json) = 'object')
);

CREATE TABLE IF NOT EXISTS dropshipping_jobs (
    dropshipping_job_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_user_id UUID NOT NULL,
    job_type dropshipping_job_type_enum NOT NULL,
    job_status dropshipping_job_status_enum NOT NULL DEFAULT 'QUEUED',
    idempotency_key TEXT NOT NULL UNIQUE,
    payload_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    result_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    retries INTEGER NOT NULL DEFAULT 0,
    max_retries INTEGER NOT NULL DEFAULT 5,
    scheduled_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    started_at TIMESTAMPTZ,
    finished_at TIMESTAMPTZ,
    last_error TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_dropshipping_jobs_owner
        FOREIGN KEY (owner_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT chk_dropshipping_jobs_key CHECK (btrim(idempotency_key) <> ''),
    CONSTRAINT chk_dropshipping_jobs_payload CHECK (jsonb_typeof(payload_json) = 'object'),
    CONSTRAINT chk_dropshipping_jobs_result CHECK (jsonb_typeof(result_json) = 'object'),
    CONSTRAINT chk_dropshipping_jobs_retries CHECK (retries >= 0 AND max_retries >= retries),
    CONSTRAINT chk_dropshipping_jobs_error CHECK (last_error IS NULL OR btrim(last_error) <> '')
);

CREATE INDEX IF NOT EXISTS ix_dropshipping_provider_configs_owner_status
    ON dropshipping_provider_configs (owner_user_id, config_status, provider_code);

CREATE INDEX IF NOT EXISTS ix_dropshipping_product_sources_item_status
    ON dropshipping_product_sources (item_id, source_status, last_synced_at);

CREATE INDEX IF NOT EXISTS ix_dropshipping_market_price_snapshots_item_time
    ON dropshipping_market_price_snapshots (item_id, captured_at DESC);

CREATE INDEX IF NOT EXISTS ix_dropshipping_pricing_decisions_item_time
    ON dropshipping_pricing_decisions (item_id, created_at DESC);

CREATE INDEX IF NOT EXISTS ix_dropshipping_supplier_orders_status
    ON dropshipping_supplier_orders (owner_user_id, supplier_order_status, updated_at);

CREATE INDEX IF NOT EXISTS ix_dropshipping_jobs_queue
    ON dropshipping_jobs (job_status, scheduled_at, job_type);

CREATE OR REPLACE VIEW v_stock_dropshipping_production_ops AS
SELECT
    source.product_source_id,
    source.owner_user_id,
    source.item_id,
    item.item_sku,
    item.item_name,
    item.item_status,
    source.source_status,
    provider.provider_code,
    provider.provider_role,
    provider.config_status AS provider_status,
    source.cost_price_brl,
    source.minimum_price_brl,
    source.current_supplier_stock,
    listing.listing_id,
    listing.listing_status,
    listing.price_brl AS listing_price_brl,
    control.pricing_status,
    control.last_market_reference_brl,
    control.last_competitor_name,
    control.last_checked_at,
    latest_decision.decision_action AS latest_decision_action,
    latest_decision.decision_reason AS latest_decision_reason,
    latest_decision.created_at AS latest_decision_at,
    source.failure_count,
    source.last_synced_at
FROM dropshipping_product_sources AS source
JOIN inventory_items AS item
  ON item.item_id = source.item_id
JOIN dropshipping_provider_configs AS provider
  ON provider.provider_config_id = source.provider_config_id
LEFT JOIN marketplace_listings AS listing
  ON listing.item_id = source.item_id
 AND listing.merchant_user_id = source.owner_user_id
LEFT JOIN marketplace_listing_controls AS control
  ON control.listing_id = listing.listing_id
LEFT JOIN LATERAL (
    SELECT
        decision.decision_action,
        decision.decision_reason,
        decision.created_at
    FROM dropshipping_pricing_decisions AS decision
    WHERE decision.item_id = source.item_id
    ORDER BY decision.created_at DESC
    LIMIT 1
) AS latest_decision ON TRUE;

CREATE OR REPLACE VIEW v_stock_dropshipping_provider_health AS
SELECT
    config.provider_config_id,
    config.owner_user_id,
    config.provider_code,
    config.provider_role,
    config.environment,
    config.config_status,
    config.sync_cadence_minutes,
    config.cache_ttl_minutes,
    config.allow_scraping_fallback,
    config.block_external_ai_lookup,
    config.last_health_status,
    config.last_health_at,
    COUNT(job.dropshipping_job_id) FILTER (WHERE job.job_status IN ('QUEUED', 'RUNNING')) AS open_jobs,
    COUNT(job.dropshipping_job_id) FILTER (WHERE job.job_status IN ('FAILED', 'DEAD_LETTER')) AS failed_jobs,
    MAX(job.updated_at) AS last_job_at
FROM dropshipping_provider_configs AS config
LEFT JOIN dropshipping_jobs AS job
  ON job.owner_user_id = config.owner_user_id
 AND job.payload_json ->> 'provider_config_id' = config.provider_config_id::TEXT
GROUP BY
    config.provider_config_id,
    config.owner_user_id,
    config.provider_code,
    config.provider_role,
    config.environment,
    config.config_status,
    config.sync_cadence_minutes,
    config.cache_ttl_minutes,
    config.allow_scraping_fallback,
    config.block_external_ai_lookup,
    config.last_health_status,
    config.last_health_at;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger
        WHERE tgname = 'trg_dropshipping_provider_configs_set_updated_at'
          AND tgrelid = 'dropshipping_provider_configs'::regclass
    ) THEN
        CREATE TRIGGER trg_dropshipping_provider_configs_set_updated_at
        BEFORE UPDATE ON dropshipping_provider_configs
        FOR EACH ROW
        EXECUTE FUNCTION set_updated_at();
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger
        WHERE tgname = 'trg_dropshipping_product_sources_set_updated_at'
          AND tgrelid = 'dropshipping_product_sources'::regclass
    ) THEN
        CREATE TRIGGER trg_dropshipping_product_sources_set_updated_at
        BEFORE UPDATE ON dropshipping_product_sources
        FOR EACH ROW
        EXECUTE FUNCTION set_updated_at();
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger
        WHERE tgname = 'trg_dropshipping_supplier_orders_set_updated_at'
          AND tgrelid = 'dropshipping_supplier_orders'::regclass
    ) THEN
        CREATE TRIGGER trg_dropshipping_supplier_orders_set_updated_at
        BEFORE UPDATE ON dropshipping_supplier_orders
        FOR EACH ROW
        EXECUTE FUNCTION set_updated_at();
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger
        WHERE tgname = 'trg_dropshipping_jobs_set_updated_at'
          AND tgrelid = 'dropshipping_jobs'::regclass
    ) THEN
        CREATE TRIGGER trg_dropshipping_jobs_set_updated_at
        BEFORE UPDATE ON dropshipping_jobs
        FOR EACH ROW
        EXECUTE FUNCTION set_updated_at();
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger
        WHERE tgname = 'trg_dropshipping_market_price_snapshots_prevent_update'
          AND tgrelid = 'dropshipping_market_price_snapshots'::regclass
    ) THEN
        CREATE TRIGGER trg_dropshipping_market_price_snapshots_prevent_update
        BEFORE UPDATE ON dropshipping_market_price_snapshots
        FOR EACH ROW
        EXECUTE FUNCTION prevent_append_only_mutation();
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger
        WHERE tgname = 'trg_dropshipping_market_price_snapshots_prevent_delete'
          AND tgrelid = 'dropshipping_market_price_snapshots'::regclass
    ) THEN
        CREATE TRIGGER trg_dropshipping_market_price_snapshots_prevent_delete
        BEFORE DELETE ON dropshipping_market_price_snapshots
        FOR EACH ROW
        EXECUTE FUNCTION prevent_append_only_mutation();
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger
        WHERE tgname = 'trg_dropshipping_pricing_decisions_prevent_update'
          AND tgrelid = 'dropshipping_pricing_decisions'::regclass
    ) THEN
        CREATE TRIGGER trg_dropshipping_pricing_decisions_prevent_update
        BEFORE UPDATE ON dropshipping_pricing_decisions
        FOR EACH ROW
        EXECUTE FUNCTION prevent_append_only_mutation();
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger
        WHERE tgname = 'trg_dropshipping_pricing_decisions_prevent_delete'
          AND tgrelid = 'dropshipping_pricing_decisions'::regclass
    ) THEN
        CREATE TRIGGER trg_dropshipping_pricing_decisions_prevent_delete
        BEFORE DELETE ON dropshipping_pricing_decisions
        FOR EACH ROW
        EXECUTE FUNCTION prevent_append_only_mutation();
    END IF;
END $$;

INSERT INTO business_rule_definitions (
    rule_code,
    module_code,
    rule_name,
    description,
    severity,
    rule_status,
    constraints_json
) VALUES
    (
        'BR-STOCK-DROP-001',
        'STOCK',
        'Dropshipping sem prejuizo',
        'Produto de dropshipping so pode ficar ativo quando preco minimo cobrir custo, frete, taxas e margem minima.',
        'CRITICAL'::rule_severity_enum,
        'ACTIVE'::rule_status_enum,
        '{"never_sell_at_loss":true,"minimum_margin_required":true,"auto_pause_when_margin_negative":true}'::JSONB
    ),
    (
        'BR-STOCK-DROP-002',
        'STOCK',
        'Consulta externa API-first sem IA',
        'Cotacoes externas de preco, estoque e fornecedor devem priorizar APIs oficiais, usar scraping apenas como fallback controlado e bloquear IA externa.',
        'HIGH'::rule_severity_enum,
        'ACTIVE'::rule_status_enum,
        '{"official_api_first":true,"scraping_only_as_fallback":true,"external_ai_lookup_blocked":true,"cache_required":true}'::JSONB
    ),
    (
        'BR-STOCK-DROP-003',
        'STOCK',
        'Pausa automatica de produto inviavel',
        'Produto deve ser pausado automaticamente quando ficar sem estoque, perder competitividade, acumular falhas ou depender de fornecedor inativo.',
        'HIGH'::rule_severity_enum,
        'ACTIVE'::rule_status_enum,
        '{"auto_pause_on_no_stock":true,"auto_pause_on_non_competitive_price":true,"auto_pause_on_supplier_error":true}'::JSONB
    )
ON CONFLICT (rule_code) DO UPDATE SET
    module_code = EXCLUDED.module_code,
    rule_name = EXCLUDED.rule_name,
    description = EXCLUDED.description,
    severity = EXCLUDED.severity,
    rule_status = EXCLUDED.rule_status,
    constraints_json = EXCLUDED.constraints_json,
    updated_at = NOW();

COMMENT ON TYPE dropshipping_provider_role_enum IS
    'Classifica providers do dropshipping entre fornecedor, fonte de preco ou ambos.';
COMMENT ON TYPE dropshipping_provider_code_enum IS
    'Providers externos suportados pelo blueprint de dropshipping inteligente.';
COMMENT ON TYPE dropshipping_runtime_status_enum IS
    'Status operacional de configuracoes, fontes e runtime de dropshipping.';
COMMENT ON TYPE dropshipping_source_type_enum IS
    'Origem da cotacao externa: API, fallback scraping, cache ou manual.';
COMMENT ON TYPE dropshipping_decision_action_enum IS
    'Acao decidida pelo Pricing Engine do dropshipping.';
COMMENT ON TYPE dropshipping_job_type_enum IS
    'Tipos de jobs assincronos do dropshipping.';
COMMENT ON TYPE dropshipping_job_status_enum IS
    'Status da fila operacional de dropshipping.';

COMMENT ON TABLE dropshipping_provider_configs IS
    'Configuracao segura de providers de dropshipping por merchant, sem armazenar segredo bruto.';
COMMENT ON TABLE dropshipping_product_sources IS
    'Vinculo entre item Valley e produto/variante de fornecedor externo.';
COMMENT ON TABLE dropshipping_market_price_snapshots IS
    'Snapshots append-only de preco externo usados para competitividade.';
COMMENT ON TABLE dropshipping_pricing_decisions IS
    'Ledger append-only das decisoes de reprecificacao e pausa automatica.';
COMMENT ON TABLE dropshipping_supplier_orders IS
    'Ponte operacional entre pedido Valley e pedido feito ao fornecedor dropshipping.';
COMMENT ON TABLE dropshipping_jobs IS
    'Fila persistida para importacao, sync, pricing e tracking do dropshipping.';
COMMENT ON VIEW v_stock_dropshipping_production_ops IS
    'Visao operacional do catalogo dropshipping, listing, controle de preco e ultima decisao.';
COMMENT ON VIEW v_stock_dropshipping_provider_health IS
    'Saude por provider de dropshipping, filas abertas e falhas por configuracao.';

COMMIT;
