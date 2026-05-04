-- Cria a camada relacional da curadoria automatica de produtos para comercio local.
-- Fontes de origem: CJ Dropshipping, Alibaba e AliExpress.
-- Marketplaces de comparacao: Mercado Livre, Shopee, Magalu, Amazon e AliExpress.
-- A rotina e API-first: scraping nao autorizado deve ser registrado como dado insuficiente.

BEGIN;

SET search_path = public;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'curation_supplier_code_enum') THEN
        CREATE TYPE curation_supplier_code_enum AS ENUM (
            'CJDROPSHIPPING',
            'ALIBABA',
            'ALIEXPRESS'
        );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'curation_marketplace_code_enum') THEN
        CREATE TYPE curation_marketplace_code_enum AS ENUM (
            'MERCADO_LIVRE',
            'SHOPEE',
            'MAGALU',
            'AMAZON',
            'ALIEXPRESS'
        );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'curation_mapping_origin_enum') THEN
        CREATE TYPE curation_mapping_origin_enum AS ENUM ('MANUAL', 'AUTOMATIC', 'AI');
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'curation_review_status_enum') THEN
        CREATE TYPE curation_review_status_enum AS ENUM ('PENDING', 'APPROVED', 'REJECTED', 'NEEDS_REVIEW');
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'curation_match_type_enum') THEN
        CREATE TYPE curation_match_type_enum AS ENUM (
            'EXACT_MATCH',
            'STRONG_MATCH',
            'SIMILAR_MATCH',
            'NO_MATCH',
            'UNCERTAIN'
        );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'curation_approval_status_enum') THEN
        CREATE TYPE curation_approval_status_enum AS ENUM (
            'PENDING',
            'APPROVED_NO_COMPETITION',
            'APPROVED_PRICE_ADVANTAGE',
            'REJECTED_PRICE_NOT_COMPETITIVE',
            'REJECTED_COMPLIANCE',
            'REJECTED_LOW_SCORE',
            'REVIEW_REQUIRED'
        );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'curation_job_type_enum') THEN
        CREATE TYPE curation_job_type_enum AS ENUM (
            'SYNC_SUPPLIER_CATEGORIES',
            'MAP_CATEGORIES_TO_GOOGLE',
            'IMPORT_SUPPLIER_PRODUCTS',
            'NORMALIZE_PRODUCTS',
            'CALCULATE_LOCAL_COMMERCE_SCORE',
            'COMPARE_MARKETPLACES',
            'CALCULATE_FINAL_PRICE',
            'APPROVE_OR_REJECT_PRODUCTS',
            'EXPAND_CATEGORY_SEARCH',
            'EXPORT_GOOGLE_FEED'
        );
    END IF;
END $$;

CREATE TABLE IF NOT EXISTS curation_suppliers (
    supplier_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    supplier_code curation_supplier_code_enum NOT NULL UNIQUE,
    supplier_name TEXT NOT NULL,
    base_url TEXT,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    connector_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    credential_ref TEXT,
    rate_limit_per_minute INTEGER NOT NULL DEFAULT 60,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_curation_suppliers_name CHECK (btrim(supplier_name) <> ''),
    CONSTRAINT chk_curation_suppliers_base_url CHECK (base_url IS NULL OR base_url ~ '^https?://'),
    CONSTRAINT chk_curation_suppliers_rate CHECK (rate_limit_per_minute > 0)
);

CREATE TABLE IF NOT EXISTS curation_supplier_categories (
    supplier_category_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    supplier_id UUID NOT NULL REFERENCES curation_suppliers (supplier_id) ON UPDATE CASCADE ON DELETE RESTRICT,
    original_category_id TEXT NOT NULL,
    original_name TEXT NOT NULL,
    original_path TEXT NOT NULL,
    level INTEGER NOT NULL DEFAULT 0,
    parent_original_category_id TEXT,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    last_synced_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    raw_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    CONSTRAINT ux_curation_supplier_categories UNIQUE (supplier_id, original_category_id),
    CONSTRAINT chk_curation_supplier_categories_level CHECK (level >= 0),
    CONSTRAINT chk_curation_supplier_categories_raw CHECK (jsonb_typeof(raw_json) = 'object')
);

CREATE TABLE IF NOT EXISTS curation_internal_categories (
    internal_category_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    internal_path TEXT NOT NULL UNIQUE,
    internal_name TEXT NOT NULL,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_curation_internal_categories_path CHECK (btrim(internal_path) <> '')
);

CREATE TABLE IF NOT EXISTS curation_google_categories (
    google_category_id TEXT PRIMARY KEY,
    google_category_path TEXT NOT NULL,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_curation_google_categories_path CHECK (btrim(google_category_path) <> '')
);

CREATE TABLE IF NOT EXISTS curation_category_mapping (
    category_mapping_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    supplier_category_id UUID NOT NULL REFERENCES curation_supplier_categories (supplier_category_id) ON UPDATE CASCADE ON DELETE CASCADE,
    internal_category_id UUID NOT NULL REFERENCES curation_internal_categories (internal_category_id) ON UPDATE CASCADE ON DELETE RESTRICT,
    google_category_id TEXT NOT NULL REFERENCES curation_google_categories (google_category_id) ON UPDATE CASCADE ON DELETE RESTRICT,
    confidence_score DECIMAL(5,2) NOT NULL DEFAULT 0,
    mapping_origin curation_mapping_origin_enum NOT NULL DEFAULT 'AUTOMATIC',
    review_status curation_review_status_enum NOT NULL DEFAULT 'PENDING',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT ux_curation_category_mapping_supplier UNIQUE (supplier_category_id),
    CONSTRAINT chk_curation_category_mapping_confidence CHECK (confidence_score BETWEEN 0 AND 100)
);

CREATE TABLE IF NOT EXISTS curation_products_raw (
    raw_product_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    supplier_id UUID NOT NULL REFERENCES curation_suppliers (supplier_id) ON UPDATE CASCADE ON DELETE RESTRICT,
    supplier_category_id UUID REFERENCES curation_supplier_categories (supplier_category_id) ON UPDATE CASCADE ON DELETE SET NULL,
    supplier_product_id TEXT NOT NULL,
    supplier_sku TEXT,
    raw_json JSONB NOT NULL,
    imported_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    import_status TEXT NOT NULL DEFAULT 'IMPORTED',
    CONSTRAINT ux_curation_products_raw UNIQUE (supplier_id, supplier_product_id),
    CONSTRAINT chk_curation_products_raw_json CHECK (jsonb_typeof(raw_json) = 'object')
);

CREATE TABLE IF NOT EXISTS curation_products_normalized (
    normalized_product_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    raw_product_id UUID NOT NULL REFERENCES curation_products_raw (raw_product_id) ON UPDATE CASCADE ON DELETE CASCADE,
    supplier_product_id TEXT NOT NULL,
    supplier_sku TEXT,
    supplier_name TEXT NOT NULL,
    supplier_origin TEXT NOT NULL,
    product_url TEXT,
    title_original TEXT NOT NULL,
    title_normalized_pt_br TEXT NOT NULL,
    description_original TEXT,
    description_normalized_pt_br TEXT,
    brand TEXT,
    model TEXT,
    gtin TEXT,
    mpn TEXT,
    supplier_category_id UUID REFERENCES curation_supplier_categories (supplier_category_id) ON UPDATE CASCADE ON DELETE SET NULL,
    internal_category_id UUID REFERENCES curation_internal_categories (internal_category_id) ON UPDATE CASCADE ON DELETE SET NULL,
    google_category_id TEXT REFERENCES curation_google_categories (google_category_id) ON UPDATE CASCADE ON DELETE SET NULL,
    google_category_path TEXT,
    supplier_price_original DECIMAL(18,4) NOT NULL DEFAULT 0,
    currency_original TEXT NOT NULL DEFAULT 'USD',
    exchange_rate_to_brl DECIMAL(18,8) NOT NULL DEFAULT 0,
    supplier_price_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    shipping_cost_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    import_tax_estimate_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    marketplace_fee_estimate_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    payment_fee_estimate_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    operational_cost_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    minimum_margin_percent DECIMAL(8,4) NOT NULL DEFAULT 0,
    suggested_sale_price_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    final_customer_cost_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    shipping_origin_country TEXT,
    shipping_origin_warehouse TEXT,
    estimated_delivery_min_days INTEGER,
    estimated_delivery_max_days INTEGER,
    package_weight DECIMAL(18,4),
    package_dimensions JSONB NOT NULL DEFAULT '{}'::JSONB,
    free_shipping_available BOOLEAN NOT NULL DEFAULT FALSE,
    tracking_available BOOLEAN NOT NULL DEFAULT FALSE,
    available_stock DECIMAL(18,4) NOT NULL DEFAULT 0,
    verified_stock BOOLEAN NOT NULL DEFAULT FALSE,
    stock_last_checked_at TIMESTAMPTZ,
    minimum_order_quantity INTEGER NOT NULL DEFAULT 1,
    variants_count INTEGER NOT NULL DEFAULT 0,
    variant_data_json JSONB NOT NULL DEFAULT '[]'::JSONB,
    rating DECIMAL(5,2),
    reviews_count INTEGER NOT NULL DEFAULT 0,
    orders_count INTEGER NOT NULL DEFAULT 0,
    supplier_score DECIMAL(5,2),
    product_quality_score DECIMAL(5,2),
    local_commerce_score DECIMAL(5,2) NOT NULL DEFAULT 0,
    prohibited_risk BOOLEAN NOT NULL DEFAULT FALSE,
    restricted_risk BOOLEAN NOT NULL DEFAULT FALSE,
    requires_certification BOOLEAN NOT NULL DEFAULT FALSE,
    requires_anatel BOOLEAN NOT NULL DEFAULT FALSE,
    requires_inmetro BOOLEAN NOT NULL DEFAULT FALSE,
    requires_anvisa BOOLEAN NOT NULL DEFAULT FALSE,
    requires_age_restriction BOOLEAN NOT NULL DEFAULT FALSE,
    has_brand_restriction BOOLEAN NOT NULL DEFAULT FALSE,
    compliance_status TEXT NOT NULL DEFAULT 'PENDING',
    comparison_status TEXT NOT NULL DEFAULT 'PENDING',
    approval_status curation_approval_status_enum NOT NULL DEFAULT 'PENDING',
    rejection_reason TEXT,
    last_checked_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_curation_products_normalized_title CHECK (btrim(title_original) <> ''),
    CONSTRAINT chk_curation_products_normalized_scores CHECK (
        local_commerce_score BETWEEN 0 AND 100
        AND (product_quality_score IS NULL OR product_quality_score BETWEEN 0 AND 100)
        AND (supplier_score IS NULL OR supplier_score BETWEEN 0 AND 100)
    ),
    CONSTRAINT chk_curation_products_normalized_variant_json CHECK (jsonb_typeof(variant_data_json) = 'array'),
    CONSTRAINT chk_curation_products_normalized_dimensions CHECK (jsonb_typeof(package_dimensions) = 'object')
);

CREATE TABLE IF NOT EXISTS curation_compliance_rules (
    compliance_rule_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rule_type TEXT NOT NULL,
    match_value TEXT NOT NULL,
    action TEXT NOT NULL DEFAULT 'BLOCK',
    reason TEXT NOT NULL,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_curation_compliance_rules_action CHECK (action IN ('BLOCK', 'REVIEW'))
);

CREATE TABLE IF NOT EXISTS curation_marketplace_price_snapshots (
    marketplace_price_snapshot_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    normalized_product_id UUID NOT NULL REFERENCES curation_products_normalized (normalized_product_id) ON UPDATE CASCADE ON DELETE CASCADE,
    marketplace_name curation_marketplace_code_enum NOT NULL,
    listing_id TEXT,
    listing_url TEXT,
    title TEXT NOT NULL,
    seller_name TEXT,
    seller_reputation TEXT,
    price_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    shipping_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    final_price_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    delivery_time_days INTEGER,
    rating DECIMAL(5,2),
    reviews_count INTEGER,
    sold_quantity INTEGER,
    is_official_store BOOLEAN NOT NULL DEFAULT FALSE,
    match_type curation_match_type_enum NOT NULL DEFAULT 'UNCERTAIN',
    match_confidence DECIMAL(5,2) NOT NULL DEFAULT 0,
    collected_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    raw_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    CONSTRAINT chk_curation_marketplace_price_match_confidence CHECK (match_confidence BETWEEN 0 AND 100),
    CONSTRAINT chk_curation_marketplace_price_raw CHECK (jsonb_typeof(raw_json) = 'object')
);

CREATE TABLE IF NOT EXISTS curation_product_comparison_results (
    comparison_result_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    normalized_product_id UUID NOT NULL REFERENCES curation_products_normalized (normalized_product_id) ON UPDATE CASCADE ON DELETE CASCADE,
    lowest_competitor_price_brl DECIMAL(18,4),
    lowest_competitor_marketplace curation_marketplace_code_enum,
    average_competitor_price_brl DECIMAL(18,4),
    median_competitor_price_brl DECIMAL(18,4),
    competitors_found INTEGER NOT NULL DEFAULT 0,
    exists_in_marketplace BOOLEAN NOT NULL DEFAULT FALSE,
    target_price_brl DECIMAL(18,4),
    final_customer_cost_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    price_advantage_percent DECIMAL(8,4),
    approval_status curation_approval_status_enum NOT NULL,
    reason TEXT NOT NULL,
    compared_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    result_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    CONSTRAINT chk_curation_product_comparison_result_json CHECK (jsonb_typeof(result_json) = 'object')
);

CREATE TABLE IF NOT EXISTS curation_approved_products (
    approved_product_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    normalized_product_id UUID NOT NULL UNIQUE REFERENCES curation_products_normalized (normalized_product_id) ON UPDATE CASCADE ON DELETE RESTRICT,
    approval_status curation_approval_status_enum NOT NULL,
    google_feed_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    approved_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_curation_approved_products_status CHECK (approval_status IN ('APPROVED_NO_COMPETITION', 'APPROVED_PRICE_ADVANTAGE')),
    CONSTRAINT chk_curation_approved_products_feed CHECK (jsonb_typeof(google_feed_json) = 'object')
);

CREATE TABLE IF NOT EXISTS curation_rejected_products (
    rejected_product_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    normalized_product_id UUID NOT NULL REFERENCES curation_products_normalized (normalized_product_id) ON UPDATE CASCADE ON DELETE RESTRICT,
    approval_status curation_approval_status_enum NOT NULL,
    rejection_reason TEXT NOT NULL,
    rejected_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS curation_sync_jobs (
    sync_job_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_type curation_job_type_enum NOT NULL,
    job_status TEXT NOT NULL DEFAULT 'QUEUED',
    idempotency_key TEXT NOT NULL UNIQUE,
    requested_payload_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    result_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    started_at TIMESTAMPTZ,
    finished_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_curation_sync_jobs_payload CHECK (jsonb_typeof(requested_payload_json) = 'object'),
    CONSTRAINT chk_curation_sync_jobs_result CHECK (jsonb_typeof(result_json) = 'object')
);

CREATE TABLE IF NOT EXISTS curation_sync_job_logs (
    sync_job_log_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sync_job_id UUID REFERENCES curation_sync_jobs (sync_job_id) ON UPDATE CASCADE ON DELETE SET NULL,
    log_level TEXT NOT NULL DEFAULT 'INFO',
    message TEXT NOT NULL,
    context_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_curation_sync_job_logs_context CHECK (jsonb_typeof(context_json) = 'object')
);

CREATE TABLE IF NOT EXISTS curation_api_checkpoints (
    api_checkpoint_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider_key TEXT NOT NULL,
    connector_type TEXT NOT NULL,
    category_key TEXT,
    filter_hash TEXT NOT NULL,
    filter_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    page_number INTEGER,
    cursor_value TEXT,
    last_success_at TIMESTAMPTZ,
    last_failure_at TIMESTAMPTZ,
    checkpoint_status TEXT NOT NULL DEFAULT 'RUNNING',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT ux_curation_api_checkpoints UNIQUE (provider_key, connector_type, category_key, filter_hash),
    CONSTRAINT chk_curation_api_checkpoints_filter CHECK (jsonb_typeof(filter_json) = 'object'),
    CONSTRAINT chk_curation_api_checkpoints_page CHECK (page_number IS NULL OR page_number >= 0)
);

CREATE TABLE IF NOT EXISTS curation_api_cache_entries (
    api_cache_entry_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider_key TEXT NOT NULL,
    cache_type TEXT NOT NULL,
    cache_key TEXT NOT NULL,
    payload_json JSONB NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT ux_curation_api_cache_entries UNIQUE (provider_key, cache_type, cache_key),
    CONSTRAINT chk_curation_api_cache_entries_payload CHECK (jsonb_typeof(payload_json) IN ('object', 'array'))
);

CREATE TABLE IF NOT EXISTS curation_rate_limit_events (
    rate_limit_event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider_key TEXT NOT NULL,
    connector_type TEXT NOT NULL,
    endpoint TEXT NOT NULL,
    http_status INTEGER,
    retry_after_seconds DECIMAL(18,4),
    backoff_seconds DECIMAL(18,4),
    circuit_breaker_open BOOLEAN NOT NULL DEFAULT FALSE,
    event_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_curation_rate_limit_events_json CHECK (jsonb_typeof(event_json) = 'object')
);

CREATE TABLE IF NOT EXISTS curation_quota_escalation_reports (
    quota_escalation_report_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider_key TEXT NOT NULL,
    endpoint TEXT NOT NULL,
    limit_found TEXT NOT NULL,
    required_volume INTEGER NOT NULL,
    max_allowed_volume INTEGER NOT NULL,
    recommendation TEXT NOT NULL,
    report_status curation_review_status_enum NOT NULL DEFAULT 'PENDING',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_curation_quota_escalation_reports_volume CHECK (
        required_volume >= 0 AND max_allowed_volume >= 0
    )
);

CREATE TABLE IF NOT EXISTS curation_pricing_rules (
    pricing_rule_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rule_key TEXT NOT NULL UNIQUE,
    rule_json JSONB NOT NULL,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_curation_pricing_rules_json CHECK (jsonb_typeof(rule_json) = 'object')
);

CREATE INDEX IF NOT EXISTS ix_curation_products_normalized_status
    ON curation_products_normalized (approval_status, comparison_status, local_commerce_score DESC);

CREATE INDEX IF NOT EXISTS ix_curation_marketplace_price_product
    ON curation_marketplace_price_snapshots (normalized_product_id, marketplace_name, final_price_brl);

CREATE INDEX IF NOT EXISTS ix_curation_supplier_categories_supplier
    ON curation_supplier_categories (supplier_id, active, level);

CREATE INDEX IF NOT EXISTS ix_curation_api_checkpoints_resume
    ON curation_api_checkpoints (provider_key, checkpoint_status, updated_at);

CREATE INDEX IF NOT EXISTS ix_curation_api_cache_entries_expiry
    ON curation_api_cache_entries (provider_key, cache_type, expires_at);

COMMIT;
