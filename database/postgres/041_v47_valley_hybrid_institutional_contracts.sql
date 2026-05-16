-- PROPOSITO: Fechar o blueprint institucional do banco hibrido Valley.
-- CONTEXTO: Migration aditiva posterior ao ERP Lojista v040; preserva tabelas existentes e adiciona contratos de governanca.
-- REGRAS: Nao apagar dados, nao gravar segredos brutos, usar users.user_id como ancora e manter logs sensiveis append-only.

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

SET search_path = public;

CREATE TABLE IF NOT EXISTS valley_wallet_asset_registry (
    asset_code TEXT PRIMARY KEY,
    display_name TEXT NOT NULL,
    decimal_scale SMALLINT NOT NULL,
    is_fiat BOOLEAN NOT NULL DEFAULT FALSE,
    is_internal_token BOOLEAN NOT NULL DEFAULT FALSE,
    ui_visibility TEXT NOT NULL DEFAULT 'HIDDEN',
    settlement_allowed BOOLEAN NOT NULL DEFAULT FALSE,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID,
    CONSTRAINT chk_valley_wallet_asset_registry_code CHECK (asset_code ~ '^[A-Z0-9_]{2,24}$'),
    CONSTRAINT chk_valley_wallet_asset_registry_display CHECK (btrim(display_name) <> ''),
    CONSTRAINT chk_valley_wallet_asset_registry_scale CHECK (decimal_scale BETWEEN 0 AND 12),
    CONSTRAINT chk_valley_wallet_asset_registry_visibility CHECK (ui_visibility IN ('VISIBLE', 'HIDDEN', 'INTERNAL_ONLY')),
    CONSTRAINT chk_valley_wallet_asset_registry_metadata CHECK (jsonb_typeof(metadata_json) = 'object')
);

INSERT INTO valley_wallet_asset_registry (
    asset_code,
    display_name,
    decimal_scale,
    is_fiat,
    is_internal_token,
    ui_visibility,
    settlement_allowed,
    metadata_json
) VALUES
    ('BRL', 'Real brasileiro', 4, TRUE, FALSE, 'VISIBLE', TRUE, '{"purpose":"moeda_fiat"}'::JSONB),
    ('VCOIN', 'V-Coin', 8, FALSE, TRUE, 'HIDDEN', FALSE, '{"purpose":"token_interno_nao_visivel_ao_usuario_final"}'::JSONB)
ON CONFLICT (asset_code) DO UPDATE
SET display_name = EXCLUDED.display_name,
    decimal_scale = EXCLUDED.decimal_scale,
    is_fiat = EXCLUDED.is_fiat,
    is_internal_token = EXCLUDED.is_internal_token,
    ui_visibility = EXCLUDED.ui_visibility,
    settlement_allowed = EXCLUDED.settlement_allowed,
    metadata_json = EXCLUDED.metadata_json,
    updated_at = NOW();

CREATE TABLE IF NOT EXISTS valley_user_addresses (
    valley_user_address_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    address_role TEXT NOT NULL DEFAULT 'PRIMARY',
    address_status TEXT NOT NULL DEFAULT 'ACTIVE',
    country_code CHAR(2) NOT NULL DEFAULT 'BR',
    postal_code TEXT NOT NULL,
    state_code CHAR(2),
    city TEXT NOT NULL,
    district TEXT,
    street TEXT NOT NULL,
    number_text TEXT,
    numeric_complement TEXT,
    complement TEXT,
    address_type TEXT NOT NULL DEFAULT 'HOUSE',
    recipient_name TEXT,
    recipient_document TEXT,
    recipient_phone_e164 TEXT,
    source_provider TEXT NOT NULL DEFAULT 'USER_CONFIRMED',
    geocode_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    confirmed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID,
    deleted_at TIMESTAMPTZ,
    CONSTRAINT fk_valley_user_addresses_user
        FOREIGN KEY (user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_valley_user_addresses_created_by
        FOREIGN KEY (created_by) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT chk_valley_user_addresses_role CHECK (address_role IN ('PRIMARY', 'DELIVERY', 'BILLING', 'PICKUP', 'RETURN')),
    CONSTRAINT chk_valley_user_addresses_status CHECK (address_status IN ('ACTIVE', 'INACTIVE', 'PENDING_CONFIRMATION')),
    CONSTRAINT chk_valley_user_addresses_country CHECK (country_code ~ '^[A-Z]{2}$'),
    CONSTRAINT chk_valley_user_addresses_postal CHECK (btrim(postal_code) <> ''),
    CONSTRAINT chk_valley_user_addresses_state CHECK (state_code IS NULL OR state_code ~ '^[A-Z]{2}$'),
    CONSTRAINT chk_valley_user_addresses_city_street CHECK (btrim(city) <> '' AND btrim(street) <> ''),
    CONSTRAINT chk_valley_user_addresses_type CHECK (address_type IN ('HOUSE', 'APARTMENT', 'CONDOMINIUM', 'COMMERCIAL', 'RURAL', 'OTHER')),
    CONSTRAINT chk_valley_user_addresses_phone CHECK (
        recipient_phone_e164 IS NULL OR recipient_phone_e164 ~ '^\+[1-9][0-9]{7,14}$'
    ),
    CONSTRAINT chk_valley_user_addresses_geo CHECK (jsonb_typeof(geocode_json) = 'object')
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_valley_user_addresses_primary
    ON valley_user_addresses (user_id)
    WHERE address_role = 'PRIMARY' AND deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS ix_valley_user_addresses_user_role
    ON valley_user_addresses (user_id, address_role, address_status);

CREATE INDEX IF NOT EXISTS ix_valley_user_addresses_postal
    ON valley_user_addresses (country_code, postal_code);

CREATE TABLE IF NOT EXISTS valley_user_document_checks (
    document_check_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    document_type TEXT NOT NULL,
    document_number TEXT NOT NULL,
    provider_key TEXT NOT NULL,
    check_status TEXT NOT NULL DEFAULT 'PENDING',
    check_reason TEXT,
    response_hash TEXT,
    evidence_ref TEXT,
    checked_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID,
    CONSTRAINT fk_valley_user_document_checks_user
        FOREIGN KEY (user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_valley_user_document_checks_created_by
        FOREIGN KEY (created_by) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT chk_valley_user_document_checks_type CHECK (document_type IN ('CPF', 'CNPJ', 'RG', 'PASSPORT', 'OTHER')),
    CONSTRAINT chk_valley_user_document_checks_number CHECK (btrim(document_number) <> ''),
    CONSTRAINT chk_valley_user_document_checks_provider CHECK (provider_key ~ '^[a-z0-9_.-]{2,80}$'),
    CONSTRAINT chk_valley_user_document_checks_status CHECK (check_status IN ('PENDING', 'VALID', 'INVALID', 'INCONCLUSIVE', 'EXPIRED')),
    CONSTRAINT chk_valley_user_document_checks_metadata CHECK (jsonb_typeof(metadata_json) = 'object')
);

CREATE INDEX IF NOT EXISTS ix_valley_user_document_checks_user
    ON valley_user_document_checks (user_id, document_type, created_at DESC);

CREATE INDEX IF NOT EXISTS ix_valley_user_document_checks_status
    ON valley_user_document_checks (provider_key, check_status, checked_at DESC);

CREATE TABLE IF NOT EXISTS merchant_erp_access_policies (
    access_policy_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    policy_code TEXT NOT NULL UNIQUE,
    scope_level TEXT NOT NULL DEFAULT 'GLOBAL',
    policy_title TEXT NOT NULL,
    mandatory_filters_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    ui_guardrails_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    enforcement_mode TEXT NOT NULL DEFAULT 'MANDATORY',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID,
    CONSTRAINT fk_merchant_erp_access_policies_created_by
        FOREIGN KEY (created_by) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT chk_merchant_erp_access_policies_code CHECK (policy_code ~ '^[A-Z0-9_.-]{2,80}$'),
    CONSTRAINT chk_merchant_erp_access_policies_scope CHECK (scope_level IN ('GLOBAL', 'TENANT', 'BRANCH', 'MODULE')),
    CONSTRAINT chk_merchant_erp_access_policies_filters CHECK (jsonb_typeof(mandatory_filters_json) = 'object'),
    CONSTRAINT chk_merchant_erp_access_policies_guardrails CHECK (jsonb_typeof(ui_guardrails_json) = 'object'),
    CONSTRAINT chk_merchant_erp_access_policies_mode CHECK (enforcement_mode IN ('MANDATORY', 'WARN_ONLY', 'DISABLED'))
);

INSERT INTO merchant_erp_access_policies (
    policy_code,
    scope_level,
    policy_title,
    mandatory_filters_json,
    ui_guardrails_json,
    enforcement_mode
) VALUES
    (
        'BR-ACL-001',
        'TENANT',
        'Toda consulta, gravacao e relatorio do ERP deve filtrar tenant_id e, quando aplicavel, branch_id.',
        '{"required_where":["tenant_id = ?"],"conditional_where":["branch_id = ?"],"deny_cross_tenant":true}'::JSONB,
        '{"error_copy":"Acesso bloqueado para dados de outro lojista ou filial."}'::JSONB,
        'MANDATORY'
    ),
    (
        'BR-PRO-001',
        'GLOBAL',
        'Nao exibir custo bruto, formulas de markup ou margem ao usuario final.',
        '{"restricted_fields":["raw_cost","supplier_cost","markup_formula","gross_margin"]}'::JSONB,
        '{"allowed_focus":["valor percebido","economia gerada","preco final","prazo"],"hide_internal_profitability":true}'::JSONB,
        'MANDATORY'
    ),
    (
        'BR-HELENA-PTBR-001',
        'GLOBAL',
        'Helena opera em portugues do Brasil com sotaque regional configuravel por cidade de nascimento.',
        '{"required_profile_fields":["birth_city","birth_state","regional_accent_code"]}'::JSONB,
        '{"tone":"amistosa, objetiva e proativa","no_invasive_popups":true}'::JSONB,
        'MANDATORY'
    )
ON CONFLICT (policy_code) DO UPDATE
SET scope_level = EXCLUDED.scope_level,
    policy_title = EXCLUDED.policy_title,
    mandatory_filters_json = EXCLUDED.mandatory_filters_json,
    ui_guardrails_json = EXCLUDED.ui_guardrails_json,
    enforcement_mode = EXCLUDED.enforcement_mode,
    is_active = TRUE,
    updated_at = NOW();

CREATE TABLE IF NOT EXISTS merchant_erp_users (
    merchant_erp_user_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    branch_id UUID,
    user_id UUID NOT NULL,
    role_code TEXT NOT NULL,
    auth_status TEXT NOT NULL DEFAULT 'ACTIVE',
    display_name TEXT,
    email TEXT,
    phone_e164 TEXT,
    last_login_at TIMESTAMPTZ,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID,
    deleted_at TIMESTAMPTZ,
    CONSTRAINT fk_merchant_erp_users_tenant
        FOREIGN KEY (tenant_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_merchant_erp_users_branch
        FOREIGN KEY (branch_id) REFERENCES merchant_erp_branch_units (merchant_erp_branch_unit_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_merchant_erp_users_user
        FOREIGN KEY (user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_merchant_erp_users_created_by
        FOREIGN KEY (created_by) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT chk_merchant_erp_users_role CHECK (role_code IN ('owner', 'admin', 'manager', 'cashier', 'operator', 'courier', 'service_provider', 'auditor')),
    CONSTRAINT chk_merchant_erp_users_status CHECK (auth_status IN ('ACTIVE', 'SUSPENDED', 'INVITED', 'REVOKED')),
    CONSTRAINT chk_merchant_erp_users_metadata CHECK (jsonb_typeof(metadata_json) = 'object')
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_merchant_erp_users_tenant_user_role
    ON merchant_erp_users (tenant_id, COALESCE(branch_id, '00000000-0000-0000-0000-000000000000'::UUID), user_id, role_code)
    WHERE deleted_at IS NULL;

CREATE TABLE IF NOT EXISTS merchant_erp_products (
    merchant_erp_product_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    branch_id UUID,
    item_id UUID,
    sku TEXT NOT NULL,
    ean13 TEXT,
    name TEXT NOT NULL,
    description TEXT,
    category_key TEXT,
    brand TEXT,
    base_price NUMERIC(18,4) NOT NULL DEFAULT 0,
    promotional_price NUMERIC(18,4),
    dimensions_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    lifecycle_status TEXT NOT NULL DEFAULT 'DRAFT',
    is_published BOOLEAN NOT NULL DEFAULT FALSE,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID,
    deleted_at TIMESTAMPTZ,
    CONSTRAINT fk_merchant_erp_products_tenant
        FOREIGN KEY (tenant_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_merchant_erp_products_branch
        FOREIGN KEY (branch_id) REFERENCES merchant_erp_branch_units (merchant_erp_branch_unit_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_merchant_erp_products_item
        FOREIGN KEY (item_id) REFERENCES inventory_items (item_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_merchant_erp_products_created_by
        FOREIGN KEY (created_by) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT chk_merchant_erp_products_sku CHECK (btrim(sku) <> ''),
    CONSTRAINT chk_merchant_erp_products_ean13 CHECK (ean13 IS NULL OR ean13 ~ '^[0-9]{13}$'),
    CONSTRAINT chk_merchant_erp_products_name CHECK (btrim(name) <> ''),
    CONSTRAINT chk_merchant_erp_products_prices CHECK (base_price >= 0 AND (promotional_price IS NULL OR promotional_price >= 0)),
    CONSTRAINT chk_merchant_erp_products_lifecycle CHECK (lifecycle_status IN ('DRAFT', 'ACTIVE', 'SUSPENDED', 'ARCHIVED', 'DELETED')),
    CONSTRAINT chk_merchant_erp_products_dimensions CHECK (jsonb_typeof(dimensions_json) = 'object'),
    CONSTRAINT chk_merchant_erp_products_metadata CHECK (jsonb_typeof(metadata_json) = 'object')
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_merchant_erp_products_sku
    ON merchant_erp_products (tenant_id, sku)
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS ix_merchant_erp_products_scope_status
    ON merchant_erp_products (tenant_id, branch_id, lifecycle_status, is_published);

CREATE TABLE IF NOT EXISTS merchant_erp_inventory (
    merchant_erp_inventory_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    branch_id UUID NOT NULL,
    product_id UUID NOT NULL,
    item_id UUID,
    quantity_on_hand NUMERIC(18,4) NOT NULL DEFAULT 0,
    quantity_available NUMERIC(18,4) NOT NULL DEFAULT 0,
    quantity_reserved NUMERIC(18,4) NOT NULL DEFAULT 0,
    minimum_alert_level NUMERIC(18,4) NOT NULL DEFAULT 0,
    maximum_stock_level NUMERIC(18,4),
    reorder_quantity NUMERIC(18,4),
    stock_scope TEXT NOT NULL DEFAULT 'LOCAL',
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID,
    CONSTRAINT fk_merchant_erp_inventory_tenant
        FOREIGN KEY (tenant_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_merchant_erp_inventory_branch
        FOREIGN KEY (branch_id) REFERENCES merchant_erp_branch_units (merchant_erp_branch_unit_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_merchant_erp_inventory_product
        FOREIGN KEY (product_id) REFERENCES merchant_erp_products (merchant_erp_product_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_merchant_erp_inventory_item
        FOREIGN KEY (item_id) REFERENCES inventory_items (item_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_merchant_erp_inventory_created_by
        FOREIGN KEY (created_by) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT chk_merchant_erp_inventory_quantities CHECK (
        quantity_on_hand >= 0
        AND quantity_available >= 0
        AND quantity_reserved >= 0
        AND minimum_alert_level >= 0
        AND (maximum_stock_level IS NULL OR maximum_stock_level >= minimum_alert_level)
        AND (reorder_quantity IS NULL OR reorder_quantity >= 0)
    ),
    CONSTRAINT chk_merchant_erp_inventory_scope CHECK (stock_scope IN ('LOCAL', 'REGIONAL', 'GLOBAL')),
    CONSTRAINT chk_merchant_erp_inventory_metadata CHECK (jsonb_typeof(metadata_json) = 'object')
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_merchant_erp_inventory_product_branch
    ON merchant_erp_inventory (tenant_id, branch_id, product_id);

CREATE TABLE IF NOT EXISTS merchant_erp_orders (
    merchant_erp_order_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    branch_id UUID,
    order_id UUID,
    customer_user_id UUID,
    seller_user_id UUID,
    origin TEXT NOT NULL DEFAULT 'erp',
    status TEXT NOT NULL DEFAULT 'PENDING',
    total_amount_brl NUMERIC(18,4) NOT NULL DEFAULT 0,
    discount_amount_brl NUMERIC(18,4) NOT NULL DEFAULT 0,
    delivery_amount_brl NUMERIC(18,4) NOT NULL DEFAULT 0,
    payment_status TEXT NOT NULL DEFAULT 'PENDING',
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID,
    deleted_at TIMESTAMPTZ,
    CONSTRAINT fk_merchant_erp_orders_tenant
        FOREIGN KEY (tenant_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_merchant_erp_orders_branch
        FOREIGN KEY (branch_id) REFERENCES merchant_erp_branch_units (merchant_erp_branch_unit_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_merchant_erp_orders_order
        FOREIGN KEY (order_id) REFERENCES orders (order_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_merchant_erp_orders_customer
        FOREIGN KEY (customer_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_merchant_erp_orders_seller
        FOREIGN KEY (seller_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_merchant_erp_orders_created_by
        FOREIGN KEY (created_by) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT chk_merchant_erp_orders_origin CHECK (origin IN ('erp', 'pdv', 'marketplace', 'link_payment', 'service_schedule', 'delivery_app', 'custom')),
    CONSTRAINT chk_merchant_erp_orders_status CHECK (status IN ('PENDING', 'PAID', 'SEPARATION', 'READY', 'IN_TRANSIT', 'DONE', 'CANCELED', 'RETURNED')),
    CONSTRAINT chk_merchant_erp_orders_amounts CHECK (total_amount_brl >= 0 AND discount_amount_brl >= 0 AND delivery_amount_brl >= 0),
    CONSTRAINT chk_merchant_erp_orders_payment_status CHECK (payment_status IN ('PENDING', 'AUTHORIZED', 'CAPTURED', 'FAILED', 'REFUNDED')),
    CONSTRAINT chk_merchant_erp_orders_metadata CHECK (jsonb_typeof(metadata_json) = 'object')
);

CREATE INDEX IF NOT EXISTS ix_merchant_erp_orders_scope_status
    ON merchant_erp_orders (tenant_id, branch_id, status, created_at DESC);

CREATE TABLE IF NOT EXISTS merchant_erp_deliveries (
    merchant_erp_delivery_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    branch_id UUID,
    order_id UUID,
    courier_user_id UUID,
    tracking_code TEXT,
    status TEXT NOT NULL DEFAULT 'WAITING_PICKUP',
    last_latitude NUMERIC(10,7),
    last_longitude NUMERIC(10,7),
    proof_of_delivery_url TEXT,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID,
    CONSTRAINT fk_merchant_erp_deliveries_tenant
        FOREIGN KEY (tenant_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_merchant_erp_deliveries_branch
        FOREIGN KEY (branch_id) REFERENCES merchant_erp_branch_units (merchant_erp_branch_unit_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_merchant_erp_deliveries_order
        FOREIGN KEY (order_id) REFERENCES orders (order_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_merchant_erp_deliveries_courier
        FOREIGN KEY (courier_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_merchant_erp_deliveries_created_by
        FOREIGN KEY (created_by) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT chk_merchant_erp_deliveries_status CHECK (status IN ('WAITING_PICKUP', 'PICKED_UP', 'IN_TRANSIT', 'DELIVERED', 'FAILED', 'CANCELED')),
    CONSTRAINT chk_merchant_erp_deliveries_lat_lon CHECK (
        (last_latitude IS NULL OR last_latitude BETWEEN -90 AND 90)
        AND (last_longitude IS NULL OR last_longitude BETWEEN -180 AND 180)
    ),
    CONSTRAINT chk_merchant_erp_deliveries_metadata CHECK (jsonb_typeof(metadata_json) = 'object')
);

CREATE INDEX IF NOT EXISTS ix_merchant_erp_deliveries_scope_status
    ON merchant_erp_deliveries (tenant_id, branch_id, status, updated_at DESC);

CREATE TABLE IF NOT EXISTS merchant_erp_appointments (
    merchant_erp_appointment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    branch_id UUID NOT NULL,
    customer_user_id UUID,
    resource_user_id UUID,
    service_type TEXT NOT NULL,
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ NOT NULL,
    status TEXT NOT NULL DEFAULT 'SCHEDULED',
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID,
    deleted_at TIMESTAMPTZ,
    CONSTRAINT fk_merchant_erp_appointments_tenant
        FOREIGN KEY (tenant_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_merchant_erp_appointments_branch
        FOREIGN KEY (branch_id) REFERENCES merchant_erp_branch_units (merchant_erp_branch_unit_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_merchant_erp_appointments_customer
        FOREIGN KEY (customer_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_merchant_erp_appointments_resource
        FOREIGN KEY (resource_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_merchant_erp_appointments_created_by
        FOREIGN KEY (created_by) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT chk_merchant_erp_appointments_service CHECK (btrim(service_type) <> ''),
    CONSTRAINT chk_merchant_erp_appointments_time CHECK (end_time > start_time),
    CONSTRAINT chk_merchant_erp_appointments_status CHECK (status IN ('SCHEDULED', 'CONFIRMED', 'COMPLETED', 'CANCELED', 'NO_SHOW')),
    CONSTRAINT chk_merchant_erp_appointments_metadata CHECK (jsonb_typeof(metadata_json) = 'object')
);

CREATE INDEX IF NOT EXISTS ix_merchant_erp_appointments_scope_time
    ON merchant_erp_appointments (tenant_id, branch_id, start_time, status)
    WHERE deleted_at IS NULL;

CREATE TABLE IF NOT EXISTS helena_user_voice_profiles (
    helena_voice_profile_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    branch_id UUID,
    user_id UUID NOT NULL,
    birth_city TEXT,
    birth_state CHAR(2),
    regional_accent_code TEXT NOT NULL DEFAULT 'pt-BR-neutral',
    tone_profile TEXT NOT NULL DEFAULT 'friendly_pragmatic',
    proactive_notifications_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID,
    CONSTRAINT fk_helena_user_voice_profiles_tenant
        FOREIGN KEY (tenant_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_helena_user_voice_profiles_branch
        FOREIGN KEY (branch_id) REFERENCES merchant_erp_branch_units (merchant_erp_branch_unit_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_helena_user_voice_profiles_user
        FOREIGN KEY (user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_helena_user_voice_profiles_created_by
        FOREIGN KEY (created_by) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT chk_helena_user_voice_profiles_state CHECK (birth_state IS NULL OR birth_state ~ '^[A-Z]{2}$'),
    CONSTRAINT chk_helena_user_voice_profiles_accent CHECK (regional_accent_code ~ '^[a-zA-Z0-9_.-]{2,80}$'),
    CONSTRAINT chk_helena_user_voice_profiles_metadata CHECK (jsonb_typeof(metadata_json) = 'object')
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_helena_user_voice_profiles_user
    ON helena_user_voice_profiles (user_id);

CREATE TABLE IF NOT EXISTS helena_product_sourcing_decisions (
    sourcing_decision_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    branch_id UUID,
    user_id UUID NOT NULL,
    product_candidate_ref TEXT NOT NULL,
    source_provider TEXT NOT NULL,
    competitor_min_price_brl NUMERIC(18,4),
    target_sale_price_brl NUMERIC(18,4),
    target_advantage_pct NUMERIC(5,2) NOT NULL DEFAULT 10.00,
    can_publish BOOLEAN NOT NULL DEFAULT FALSE,
    decision_status TEXT NOT NULL DEFAULT 'PENDING',
    decision_reason TEXT,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID,
    CONSTRAINT fk_helena_product_sourcing_decisions_tenant
        FOREIGN KEY (tenant_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_helena_product_sourcing_decisions_branch
        FOREIGN KEY (branch_id) REFERENCES merchant_erp_branch_units (merchant_erp_branch_unit_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_helena_product_sourcing_decisions_user
        FOREIGN KEY (user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_helena_product_sourcing_decisions_created_by
        FOREIGN KEY (created_by) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT chk_helena_product_sourcing_decisions_provider CHECK (source_provider IN ('aliexpress_secondary', 'alibaba', 'cj', 'amazon', 'mercado_livre', 'magalu', 'manual', 'custom')),
    CONSTRAINT chk_helena_product_sourcing_decisions_prices CHECK (
        (competitor_min_price_brl IS NULL OR competitor_min_price_brl >= 0)
        AND (target_sale_price_brl IS NULL OR target_sale_price_brl >= 0)
        AND target_advantage_pct >= 0
        AND (
            can_publish = FALSE
            OR (
                competitor_min_price_brl IS NOT NULL
                AND target_sale_price_brl IS NOT NULL
                AND target_sale_price_brl <= competitor_min_price_brl * (1 - (target_advantage_pct / 100.0))
            )
        )
    ),
    CONSTRAINT chk_helena_product_sourcing_decisions_status CHECK (decision_status IN ('PENDING', 'APPROVED_TO_POST', 'REJECTED_PRICE_TARGET', 'REJECTED_COMPLIANCE', 'HOLD')),
    CONSTRAINT chk_helena_product_sourcing_decisions_metadata CHECK (jsonb_typeof(metadata_json) = 'object')
);

CREATE INDEX IF NOT EXISTS ix_helena_product_sourcing_decisions_scope
    ON helena_product_sourcing_decisions (tenant_id, branch_id, source_provider, created_at DESC);

CREATE TABLE IF NOT EXISTS valley_contextual_reward_campaigns (
    contextual_campaign_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    branch_id UUID,
    merchant_user_id UUID NOT NULL,
    campaign_name TEXT NOT NULL,
    reward_asset_code TEXT NOT NULL DEFAULT 'VCOIN',
    ui_visibility TEXT NOT NULL DEFAULT 'HIDDEN',
    trigger_context_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    start_at TIMESTAMPTZ,
    end_at TIMESTAMPTZ,
    is_active BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID,
    deleted_at TIMESTAMPTZ,
    CONSTRAINT fk_valley_contextual_reward_campaigns_tenant
        FOREIGN KEY (tenant_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_valley_contextual_reward_campaigns_branch
        FOREIGN KEY (branch_id) REFERENCES merchant_erp_branch_units (merchant_erp_branch_unit_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_valley_contextual_reward_campaigns_merchant
        FOREIGN KEY (merchant_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_valley_contextual_reward_campaigns_asset
        FOREIGN KEY (reward_asset_code) REFERENCES valley_wallet_asset_registry (asset_code)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_valley_contextual_reward_campaigns_created_by
        FOREIGN KEY (created_by) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT chk_valley_contextual_reward_campaigns_name CHECK (btrim(campaign_name) <> ''),
    CONSTRAINT chk_valley_contextual_reward_campaigns_visibility CHECK (ui_visibility IN ('VISIBLE', 'HIDDEN', 'INTERNAL_ONLY')),
    CONSTRAINT chk_valley_contextual_reward_campaigns_dates CHECK (end_at IS NULL OR start_at IS NULL OR end_at > start_at),
    CONSTRAINT chk_valley_contextual_reward_campaigns_trigger CHECK (jsonb_typeof(trigger_context_json) = 'object')
);

CREATE INDEX IF NOT EXISTS ix_valley_contextual_reward_campaigns_scope
    ON valley_contextual_reward_campaigns (tenant_id, branch_id, is_active, ui_visibility)
    WHERE deleted_at IS NULL;

CREATE TABLE IF NOT EXISTS mobility_realtime_route_sessions (
    route_session_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    branch_id UUID,
    user_id UUID NOT NULL,
    commitment_ref TEXT,
    origin_geo JSONB NOT NULL DEFAULT '{}'::JSONB,
    destination_geo JSONB NOT NULL DEFAULT '{}'::JSONB,
    transport_modes TEXT[] NOT NULL DEFAULT ARRAY['public_transport', 'ride_hailing']::TEXT[],
    current_provider_mix_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    current_status TEXT NOT NULL DEFAULT 'MONITORING',
    savings_estimate_brl NUMERIC(18,4),
    eta_minutes INTEGER,
    last_recalculated_at TIMESTAMPTZ,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID,
    deleted_at TIMESTAMPTZ,
    CONSTRAINT fk_mobility_realtime_route_sessions_tenant
        FOREIGN KEY (tenant_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_mobility_realtime_route_sessions_branch
        FOREIGN KEY (branch_id) REFERENCES merchant_erp_branch_units (merchant_erp_branch_unit_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_mobility_realtime_route_sessions_user
        FOREIGN KEY (user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_mobility_realtime_route_sessions_created_by
        FOREIGN KEY (created_by) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT chk_mobility_realtime_route_sessions_status CHECK (current_status IN ('MONITORING', 'RECALCULATED', 'DELAY_RISK', 'COMPLETED', 'CANCELED')),
    CONSTRAINT chk_mobility_realtime_route_sessions_money_eta CHECK ((savings_estimate_brl IS NULL OR savings_estimate_brl >= 0) AND (eta_minutes IS NULL OR eta_minutes >= 0)),
    CONSTRAINT chk_mobility_realtime_route_sessions_geo CHECK (jsonb_typeof(origin_geo) = 'object' AND jsonb_typeof(destination_geo) = 'object'),
    CONSTRAINT chk_mobility_realtime_route_sessions_mix CHECK (jsonb_typeof(current_provider_mix_json) = 'object'),
    CONSTRAINT chk_mobility_realtime_route_sessions_metadata CHECK (jsonb_typeof(metadata_json) = 'object')
);

CREATE INDEX IF NOT EXISTS ix_mobility_realtime_route_sessions_user_status
    ON mobility_realtime_route_sessions (tenant_id, user_id, current_status, updated_at DESC)
    WHERE deleted_at IS NULL;

CREATE TABLE IF NOT EXISTS mobility_idle_agent_dispatch_rules (
    idle_agent_rule_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    branch_id UUID,
    user_id UUID NOT NULL,
    rule_name TEXT NOT NULL,
    monitor_scope TEXT NOT NULL DEFAULT 'BRAZIL',
    tracked_modes TEXT[] NOT NULL DEFAULT ARRAY['bus', 'metro', 'ride_hailing']::TEXT[],
    provider_keys TEXT[] NOT NULL DEFAULT ARRAY['public_transport', 'uber']::TEXT[],
    trigger_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    proactive_recalculation_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID,
    deleted_at TIMESTAMPTZ,
    CONSTRAINT fk_mobility_idle_agent_dispatch_rules_tenant
        FOREIGN KEY (tenant_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_mobility_idle_agent_dispatch_rules_branch
        FOREIGN KEY (branch_id) REFERENCES merchant_erp_branch_units (merchant_erp_branch_unit_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_mobility_idle_agent_dispatch_rules_user
        FOREIGN KEY (user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_mobility_idle_agent_dispatch_rules_created_by
        FOREIGN KEY (created_by) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT chk_mobility_idle_agent_dispatch_rules_name CHECK (btrim(rule_name) <> ''),
    CONSTRAINT chk_mobility_idle_agent_dispatch_rules_scope CHECK (monitor_scope IN ('BRAZIL', 'STATE', 'CITY', 'CUSTOM_AREA')),
    CONSTRAINT chk_mobility_idle_agent_dispatch_rules_trigger CHECK (jsonb_typeof(trigger_json) = 'object')
);

CREATE INDEX IF NOT EXISTS ix_mobility_idle_agent_dispatch_rules_active
    ON mobility_idle_agent_dispatch_rules (tenant_id, branch_id, user_id, is_active)
    WHERE deleted_at IS NULL;

CREATE TABLE IF NOT EXISTS mobility_idle_agent_events (
    idle_agent_event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    branch_id UUID,
    user_id UUID NOT NULL,
    route_session_id UUID,
    event_type TEXT NOT NULL,
    provider_key TEXT,
    detection_status TEXT NOT NULL DEFAULT 'DETECTED',
    public_transport_eta_minutes INTEGER,
    ride_hailing_eta_minutes INTEGER,
    ride_hailing_price_brl NUMERIC(18,4),
    recommended_mix_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    incident_summary TEXT,
    action_taken TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID,
    CONSTRAINT fk_mobility_idle_agent_events_tenant
        FOREIGN KEY (tenant_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_mobility_idle_agent_events_branch
        FOREIGN KEY (branch_id) REFERENCES merchant_erp_branch_units (merchant_erp_branch_unit_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_mobility_idle_agent_events_user
        FOREIGN KEY (user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_mobility_idle_agent_events_route
        FOREIGN KEY (route_session_id) REFERENCES mobility_realtime_route_sessions (route_session_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_mobility_idle_agent_events_created_by
        FOREIGN KEY (created_by) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT chk_mobility_idle_agent_events_type CHECK (event_type IN ('ROUTE_MONITOR', 'PRICE_SPIKE', 'ACCIDENT', 'DELAY', 'RECALCULATION', 'PROACTIVE_ALERT', 'VISIO_CHECK')),
    CONSTRAINT chk_mobility_idle_agent_events_status CHECK (detection_status IN ('DETECTED', 'VALIDATED', 'NOTIFIED', 'IGNORED', 'FAILED')),
    CONSTRAINT chk_mobility_idle_agent_events_eta CHECK ((public_transport_eta_minutes IS NULL OR public_transport_eta_minutes >= 0) AND (ride_hailing_eta_minutes IS NULL OR ride_hailing_eta_minutes >= 0)),
    CONSTRAINT chk_mobility_idle_agent_events_price CHECK (ride_hailing_price_brl IS NULL OR ride_hailing_price_brl >= 0),
    CONSTRAINT chk_mobility_idle_agent_events_mix CHECK (jsonb_typeof(recommended_mix_json) = 'object')
);

CREATE INDEX IF NOT EXISTS ix_mobility_idle_agent_events_scope_time
    ON mobility_idle_agent_events (tenant_id, branch_id, user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS valley_module_availability_checks (
    module_check_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    branch_id UUID,
    user_id UUID NOT NULL,
    module_key TEXT NOT NULL DEFAULT 'visio',
    check_agent TEXT NOT NULL DEFAULT 'helena_mobility_agent',
    implementation_status TEXT NOT NULL DEFAULT 'UNKNOWN',
    availability_status TEXT NOT NULL DEFAULT 'PENDING',
    evidence_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    checked_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID,
    CONSTRAINT fk_valley_module_availability_checks_tenant
        FOREIGN KEY (tenant_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_valley_module_availability_checks_branch
        FOREIGN KEY (branch_id) REFERENCES merchant_erp_branch_units (merchant_erp_branch_unit_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_valley_module_availability_checks_user
        FOREIGN KEY (user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_valley_module_availability_checks_created_by
        FOREIGN KEY (created_by) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT chk_valley_module_availability_checks_module CHECK (module_key ~ '^[a-z0-9_.-]{2,80}$'),
    CONSTRAINT chk_valley_module_availability_checks_impl CHECK (implementation_status IN ('UNKNOWN', 'NOT_FOUND', 'PARTIAL', 'IMPLEMENTED', 'DEPRECATED')),
    CONSTRAINT chk_valley_module_availability_checks_availability CHECK (availability_status IN ('PENDING', 'AVAILABLE', 'UNAVAILABLE', 'DEGRADED')),
    CONSTRAINT chk_valley_module_availability_checks_evidence CHECK (jsonb_typeof(evidence_json) = 'object')
);

CREATE INDEX IF NOT EXISTS ix_valley_module_availability_checks_module_time
    ON valley_module_availability_checks (module_key, checked_at DESC);

CREATE TABLE IF NOT EXISTS valley_screen_layout_contracts (
    screen_contract_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    screen_code TEXT NOT NULL UNIQUE,
    module_key TEXT NOT NULL,
    screen_name TEXT NOT NULL,
    stitch_contract_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    data_contract_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    ui_visibility TEXT NOT NULL DEFAULT 'VISIBLE',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID,
    CONSTRAINT fk_valley_screen_layout_contracts_created_by
        FOREIGN KEY (created_by) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT chk_valley_screen_layout_contracts_code CHECK (screen_code ~ '^[A-Z0-9_.-]{2,80}$'),
    CONSTRAINT chk_valley_screen_layout_contracts_module CHECK (module_key ~ '^[a-z0-9_.-]{2,80}$'),
    CONSTRAINT chk_valley_screen_layout_contracts_name CHECK (btrim(screen_name) <> ''),
    CONSTRAINT chk_valley_screen_layout_contracts_stitch CHECK (jsonb_typeof(stitch_contract_json) = 'object'),
    CONSTRAINT chk_valley_screen_layout_contracts_data CHECK (jsonb_typeof(data_contract_json) = 'object'),
    CONSTRAINT chk_valley_screen_layout_contracts_visibility CHECK (ui_visibility IN ('VISIBLE', 'HIDDEN', 'INTERNAL_ONLY'))
);

INSERT INTO valley_screen_layout_contracts (
    screen_code,
    module_key,
    screen_name,
    stitch_contract_json,
    data_contract_json,
    ui_visibility
) VALUES
    (
        'HOME_001',
        'home',
        'Home Valley',
        '{"blocks":["cabecalho_identidade_busca","rastreio_realtime_oculto_sem_entrega","banner_hero_helena","banners_secundarios_50_50","financas_ocultaveis","favoritos_carrinho","rodape_perfil_suporte_faq"],"inputs":["global_search"],"buttons":["open_profile","open_support","open_faq","quick_navigation"],"visibility_rules":{"tracking":"hide_when_no_active_delivery","finance":"user_can_hide","internal_rewards":"hidden_until_enabled"}}'::JSONB,
        '{"required_scope":["user_id"],"collections":["helena_ai_context_events"],"tables":["wallets","orders","shopping_carts","user_favorites","valley_contextual_reward_campaigns"]}'::JSONB,
        'VISIBLE'
    ),
    (
        'STOCK_DROPSHIPPING',
        'stock',
        'Stock Dropshipping',
        '{"blocks":["product_grid_infinite","filters_category_price_delivery","merchant_profit_sandbox_hidden_from_customer"],"inputs":["category","price_range","delivery_deadline"],"buttons":["apply_filters","open_product","simulate_merchant_only"],"guardrails":["BR-PRO-001"]}'::JSONB,
        '{"required_scope":["tenant_id","branch_id"],"tables":["inventory_items","helena_product_sourcing_decisions","dropshipping_pricing_decisions"]}'::JSONB,
        'VISIBLE'
    ),
    (
        'MARKETPLACE_LOCAL',
        'marketplace',
        'Marketplace Lojistas Locais',
        '{"blocks":["nearby_merchants","category_focus","rating_filter","neighborhood_filter","benefit_badge_hidden_until_enabled"],"inputs":["neighborhood","segment","rating"],"buttons":["open_merchant","apply_filters","open_map"],"visibility_rules":{"internal_rewards":"hidden_until_enabled"}}'::JSONB,
        '{"required_scope":["tenant_id","branch_id"],"tables":["merchant_profiles","merchant_erp_products","merchant_erp_orders","valley_contextual_reward_campaigns"]}'::JSONB,
        'VISIBLE'
    )
ON CONFLICT (screen_code) DO UPDATE
SET module_key = EXCLUDED.module_key,
    screen_name = EXCLUDED.screen_name,
    stitch_contract_json = EXCLUDED.stitch_contract_json,
    data_contract_json = EXCLUDED.data_contract_json,
    ui_visibility = EXCLUDED.ui_visibility,
    updated_at = NOW();

CREATE TABLE IF NOT EXISTS valley_module_data_contracts (
    module_contract_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    module_key TEXT NOT NULL UNIQUE,
    module_label TEXT NOT NULL,
    data_home TEXT NOT NULL,
    owner_table TEXT,
    owner_user_column TEXT NOT NULL DEFAULT 'user_id',
    tenant_scope_required BOOLEAN NOT NULL DEFAULT TRUE,
    branch_scope_required BOOLEAN NOT NULL DEFAULT FALSE,
    append_only_required BOOLEAN NOT NULL DEFAULT FALSE,
    public_runtime_required BOOLEAN NOT NULL DEFAULT FALSE,
    api_contract_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID,
    CONSTRAINT fk_valley_module_data_contracts_created_by
        FOREIGN KEY (created_by) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT chk_valley_module_data_contracts_key CHECK (module_key ~ '^[a-z0-9_.-]{2,80}$'),
    CONSTRAINT chk_valley_module_data_contracts_label CHECK (btrim(module_label) <> ''),
    CONSTRAINT chk_valley_module_data_contracts_home CHECK (data_home IN ('POSTGRES', 'MONGODB', 'HYBRID')),
    CONSTRAINT chk_valley_module_data_contracts_json CHECK (jsonb_typeof(api_contract_json) = 'object')
);

INSERT INTO valley_module_data_contracts (
    module_key,
    module_label,
    data_home,
    owner_table,
    owner_user_column,
    tenant_scope_required,
    branch_scope_required,
    append_only_required,
    public_runtime_required,
    api_contract_json
) VALUES
    ('identity', 'Identidade e acesso', 'POSTGRES', 'users', 'user_id', TRUE, FALSE, TRUE, TRUE, '{"tables":["users","auth_identities","auth_sessions","valley_user_addresses","valley_user_document_checks"]}'::JSONB),
    ('home', 'Home Valley', 'HYBRID', 'users', 'user_id', TRUE, FALSE, FALSE, TRUE, '{"tables":["valley_screen_layout_contracts","wallets","shopping_carts","user_favorites"],"collections":["helena_ai_context_events"],"screens":["HOME_001"]}'::JSONB),
    ('wallets', 'Wallets e saldos', 'POSTGRES', 'wallets', 'user_id', TRUE, FALSE, TRUE, TRUE, '{"tables":["wallets","transactions","valley_wallet_asset_registry"]}'::JSONB),
    ('equity_audit', 'Auditoria societaria', 'POSTGRES', 'equity_ledger', 'user_id', TRUE, FALSE, TRUE, FALSE, '{"tables":["equity_ledger","valley_immutable_audit_ledger"]}'::JSONB),
    ('merchant_erp', 'ERP Lojista', 'HYBRID', 'merchant_profiles', 'merchant_user_id', TRUE, TRUE, FALSE, TRUE, '{"tables":["merchant_erp_workspaces","merchant_erp_staff_members","merchant_erp_audit_events"]}'::JSONB),
    ('pdv', 'PDV e caixa', 'POSTGRES', 'merchant_erp_pdv_sessions', 'merchant_user_id', TRUE, TRUE, TRUE, TRUE, '{"tables":["merchant_erp_pdv_terminals","merchant_erp_pdv_sessions","merchant_erp_cash_movements"]}'::JSONB),
    ('orders', 'Pedidos', 'POSTGRES', 'orders', 'user_id', TRUE, TRUE, FALSE, TRUE, '{"tables":["orders","merchant_erp_order_pipeline"]}'::JSONB),
    ('checkout', 'Checkout', 'POSTGRES', 'checkout_payment_intents', 'buyer_user_id', TRUE, TRUE, TRUE, TRUE, '{"tables":["checkout_payment_intents","checkout_webhook_events","transactions"]}'::JSONB),
    ('products', 'Produtos', 'POSTGRES', 'inventory_items', 'merchant_user_id', TRUE, TRUE, FALSE, TRUE, '{"tables":["inventory_items","merchant_erp_product_variants","merchant_erp_product_kits"]}'::JSONB),
    ('stock', 'Estoque', 'POSTGRES', 'inventory_movements', 'user_id', TRUE, TRUE, TRUE, TRUE, '{"tables":["inventory_movements","merchant_erp_inventory_alert_rules","merchant_erp_cycle_count_jobs"]}'::JSONB),
    ('labels', 'Etiquetas', 'POSTGRES', 'merchant_erp_label_jobs', 'merchant_user_id', TRUE, TRUE, TRUE, TRUE, '{"tables":["merchant_erp_label_templates","merchant_erp_label_jobs","merchant_erp_label_job_items"]}'::JSONB),
    ('marketplace', 'Marketplaces bidirecionais', 'HYBRID', 'merchant_erp_connector_catalog', 'merchant_user_id', TRUE, TRUE, TRUE, TRUE, '{"providers":["shopee","mercado_livre","olx","ze_delivery","ifood","amazon","magalu","aliexpress","shopify","nuvemshop","woocommerce","tiktok_shop","google_merchant_center"]}'::JSONB),
    ('fiscal', 'Fiscal e NF-e', 'POSTGRES', 'merchant_erp_nfe_import_batches', 'merchant_user_id', TRUE, TRUE, TRUE, FALSE, '{"tables":["merchant_erp_nfe_import_batches","merchant_erp_nfe_items"]}'::JSONB),
    ('finance', 'Financeiro', 'POSTGRES', 'merchant_erp_finance_entries', 'merchant_user_id', TRUE, TRUE, TRUE, TRUE, '{"tables":["merchant_erp_finance_entries","merchant_erp_financial_closures","merchant_erp_accounting_entries"]}'::JSONB),
    ('banking', 'APIs bancarias', 'POSTGRES', 'merchant_erp_integration_connections', 'merchant_user_id', TRUE, TRUE, TRUE, FALSE, '{"tables":["merchant_erp_integration_connections","valley_bank_api_connections"]}'::JSONB),
    ('schedule', 'Agenda de servicos', 'HYBRID', 'merchant_erp_service_bookings', 'merchant_user_id', TRUE, TRUE, TRUE, TRUE, '{"tables":["merchant_erp_service_resources","merchant_erp_service_bookings","merchant_erp_service_booking_events"]}'::JSONB),
    ('delivery', 'Entregas', 'HYBRID', 'merchant_erp_delivery_assignments', 'merchant_user_id', TRUE, TRUE, TRUE, TRUE, '{"tables":["merchant_erp_delivery_assignments","merchant_erp_delivery_tracking_events","merchant_erp_deliveries","marketplace_android_live_tracking_sessions","marketplace_android_live_tracking_events"],"android_live_tracking":{"platform":"ANDROID_ONLY","origin":"MARKETPLACE","exclude_origin":["STOCK"],"foreground_service_fallback":true,"fcm_required":true}}'::JSONB),
    ('tracking', 'Rastreio em tempo real', 'MONGODB', 'merchant_realtime_delivery_stream', 'merchant_user_id', TRUE, TRUE, TRUE, TRUE, '{"collections":["merchant_realtime_delivery_stream","erp_operational_telemetry_events"]}'::JSONB),
    ('mobility', 'Mobilidade inteligente', 'HYBRID', 'mobility_realtime_route_sessions', 'user_id', TRUE, TRUE, TRUE, TRUE, '{"functions":["acompanhar_onibus_metro_uber_em_todo_brasil","comparar_uber_vs_transporte_publico","recalcular_por_acidente_atraso"],"tables":["mobility_realtime_route_sessions","mobility_idle_agent_dispatch_rules","mobility_idle_agent_events"],"collections":["mobility_idle_agent_decisions"]}'::JSONB),
    ('visio', 'Verificacao de modulo Visio', 'HYBRID', 'valley_module_availability_checks', 'user_id', TRUE, TRUE, TRUE, FALSE, '{"agent":"helena_mobility_agent","tables":["valley_module_availability_checks"],"collections":["erp_operational_telemetry_events"],"expected_statuses":["UNKNOWN","NOT_FOUND","PARTIAL","IMPLEMENTED","DEPRECATED"]}'::JSONB),
    ('branches', 'Matriz e filiais', 'POSTGRES', 'merchant_erp_branch_units', 'merchant_user_id', TRUE, TRUE, TRUE, TRUE, '{"tables":["merchant_erp_branch_units","merchant_erp_branch_stock_policies","merchant_erp_branch_events"]}'::JSONB),
    ('customers', 'Clientes', 'POSTGRES', 'users', 'user_id', TRUE, FALSE, FALSE, TRUE, '{"tables":["users","valley_user_addresses","support_tickets"]}'::JSONB),
    ('marketplace_chat', 'Chat Marketplace Moderado', 'POSTGRES', 'commerce_chat_threads', 'merchant_user_id', TRUE, TRUE, TRUE, TRUE, '{"tables":["chat_messages","commerce_chat_threads","marketplace_chat_moderation_patterns","chat_moderation_strikes","chat_moderation_account_actions"],"rules":["no_external_contact","append_only_messages","three_strikes_suspension_event"]}'::JSONB),
    ('reports', 'Relatorios', 'POSTGRES', 'merchant_erp_report_query_events', 'merchant_user_id', TRUE, TRUE, TRUE, TRUE, '{"tables":["merchant_erp_report_query_events","merchant_erp_report_exports"]}'::JSONB),
    ('team', 'Equipe e RBAC', 'POSTGRES', 'merchant_erp_staff_members', 'merchant_user_id', TRUE, TRUE, TRUE, TRUE, '{"tables":["merchant_erp_staff_members","merchant_erp_privileges","merchant_erp_privilege_audit_events"]}'::JSONB),
    ('security', 'Seguranca e auditoria', 'HYBRID', 'merchant_erp_security_events', 'merchant_user_id', TRUE, TRUE, TRUE, FALSE, '{"tables":["merchant_erp_security_events","merchant_erp_audit_events"],"collections":["erp_operational_telemetry_events"]}'::JSONB),
    ('helena_ai', 'Helena AI', 'MONGODB', 'helena_ai_context_events', 'user_id', TRUE, FALSE, TRUE, TRUE, '{"tables":["helena_user_voice_profiles","helena_product_sourcing_decisions","valley_contextual_reward_campaigns"],"collections":["ai_memory","helena_ai_context_events"],"rules":["pt-BR","regional_accent_by_birth_city","no_invasive_popups","BR-PRO-001"]}'::JSONB),
    ('social', 'Social e midia', 'MONGODB', 'social_videos', 'creator_user_id', TRUE, FALSE, TRUE, TRUE, '{"collections":["social_videos","influencer_metrics"]}'::JSONB),
    ('telemetry', 'Telemetria IoT e GPS', 'MONGODB', 'telemetry_logs', 'user_id', TRUE, TRUE, TRUE, FALSE, '{"collections":["telemetry_logs","erp_operational_telemetry_events"]}'::JSONB)
ON CONFLICT (module_key) DO UPDATE
SET module_label = EXCLUDED.module_label,
    data_home = EXCLUDED.data_home,
    owner_table = EXCLUDED.owner_table,
    owner_user_column = EXCLUDED.owner_user_column,
    tenant_scope_required = EXCLUDED.tenant_scope_required,
    branch_scope_required = EXCLUDED.branch_scope_required,
    append_only_required = EXCLUDED.append_only_required,
    public_runtime_required = EXCLUDED.public_runtime_required,
    api_contract_json = EXCLUDED.api_contract_json,
    updated_at = NOW();

CREATE TABLE IF NOT EXISTS valley_module_user_scope_bindings (
    scope_binding_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    module_key TEXT NOT NULL,
    user_id UUID NOT NULL,
    merchant_user_id UUID,
    branch_unit_id UUID,
    entity_table TEXT NOT NULL,
    entity_id UUID NOT NULL,
    relation_role TEXT NOT NULL DEFAULT 'OWNER',
    scope_status TEXT NOT NULL DEFAULT 'ACTIVE',
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    CONSTRAINT fk_valley_module_user_scope_bindings_module
        FOREIGN KEY (module_key) REFERENCES valley_module_data_contracts (module_key)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_valley_module_user_scope_bindings_user
        FOREIGN KEY (user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_valley_module_user_scope_bindings_merchant
        FOREIGN KEY (merchant_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_valley_module_user_scope_bindings_branch
        FOREIGN KEY (branch_unit_id) REFERENCES merchant_erp_branch_units (merchant_erp_branch_unit_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT chk_valley_module_user_scope_bindings_table CHECK (entity_table ~ '^[a-z0-9_.-]{2,120}$'),
    CONSTRAINT chk_valley_module_user_scope_bindings_role CHECK (relation_role IN ('OWNER', 'ACTOR', 'CUSTOMER', 'MERCHANT', 'COURIER', 'APPROVER', 'AUDITOR', 'RECIPIENT')),
    CONSTRAINT chk_valley_module_user_scope_bindings_status CHECK (scope_status IN ('ACTIVE', 'INACTIVE', 'REVOKED')),
    CONSTRAINT chk_valley_module_user_scope_bindings_metadata CHECK (jsonb_typeof(metadata_json) = 'object')
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_valley_module_user_scope_bindings_entity
    ON valley_module_user_scope_bindings (module_key, entity_table, entity_id, user_id, relation_role)
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS ix_valley_module_user_scope_bindings_user
    ON valley_module_user_scope_bindings (user_id, module_key, scope_status);

CREATE INDEX IF NOT EXISTS ix_valley_module_user_scope_bindings_merchant
    ON valley_module_user_scope_bindings (merchant_user_id, branch_unit_id, module_key)
    WHERE merchant_user_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS valley_marketplace_api_accounts (
    marketplace_account_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_user_id UUID NOT NULL,
    branch_unit_id UUID,
    provider_key TEXT NOT NULL,
    provider_account_ref TEXT,
    environment TEXT NOT NULL DEFAULT 'production',
    connection_status TEXT NOT NULL DEFAULT 'DRAFT',
    credential_ref TEXT,
    webhook_secret_ref TEXT,
    bidirectional_sync_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    listing_sync_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    order_import_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    stock_export_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    price_export_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    last_inbound_sync_at TIMESTAMPTZ,
    last_outbound_sync_at TIMESTAMPTZ,
    health_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    CONSTRAINT fk_valley_marketplace_api_accounts_merchant
        FOREIGN KEY (merchant_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_valley_marketplace_api_accounts_branch
        FOREIGN KEY (branch_unit_id) REFERENCES merchant_erp_branch_units (merchant_erp_branch_unit_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT chk_valley_marketplace_api_accounts_provider CHECK (
        provider_key IN (
            'shopee',
            'mercado_livre',
            'olx',
            'ze_delivery',
            'ifood',
            'amazon',
            'magalu',
            'aliexpress',
            'shopify',
            'nuvemshop',
            'woocommerce',
            'tiktok_shop',
            'google_merchant_center',
            'custom'
        )
    ),
    CONSTRAINT chk_valley_marketplace_api_accounts_environment CHECK (environment IN ('sandbox', 'staging', 'production')),
    CONSTRAINT chk_valley_marketplace_api_accounts_status CHECK (connection_status IN ('DRAFT', 'ACTIVE', 'DEGRADED', 'DISABLED', 'AUTH_REQUIRED')),
    CONSTRAINT chk_valley_marketplace_api_accounts_health CHECK (jsonb_typeof(health_json) = 'object')
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_valley_marketplace_api_accounts_provider
    ON valley_marketplace_api_accounts (merchant_user_id, provider_key, environment, COALESCE(provider_account_ref, 'default'))
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS ix_valley_marketplace_api_accounts_status
    ON valley_marketplace_api_accounts (merchant_user_id, connection_status, provider_key);

CREATE TABLE IF NOT EXISTS valley_bank_api_connections (
    bank_connection_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_user_id UUID NOT NULL,
    branch_unit_id UUID,
    provider_key TEXT NOT NULL,
    environment TEXT NOT NULL DEFAULT 'production',
    connection_status TEXT NOT NULL DEFAULT 'DRAFT',
    account_ref TEXT,
    pix_key_ref TEXT,
    consent_ref TEXT,
    webhook_url TEXT,
    credential_ref TEXT,
    last_statement_sync_at TIMESTAMPTZ,
    last_reconciliation_at TIMESTAMPTZ,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    CONSTRAINT fk_valley_bank_api_connections_merchant
        FOREIGN KEY (merchant_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_valley_bank_api_connections_branch
        FOREIGN KEY (branch_unit_id) REFERENCES merchant_erp_branch_units (merchant_erp_branch_unit_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT chk_valley_bank_api_connections_provider CHECK (provider_key ~ '^[a-z0-9_.-]{2,80}$'),
    CONSTRAINT chk_valley_bank_api_connections_environment CHECK (environment IN ('sandbox', 'staging', 'production')),
    CONSTRAINT chk_valley_bank_api_connections_status CHECK (connection_status IN ('DRAFT', 'ACTIVE', 'DEGRADED', 'DISABLED', 'AUTH_REQUIRED')),
    CONSTRAINT chk_valley_bank_api_connections_metadata CHECK (jsonb_typeof(metadata_json) = 'object')
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_valley_bank_api_connections_provider
    ON valley_bank_api_connections (merchant_user_id, provider_key, environment, COALESCE(account_ref, 'default'))
    WHERE deleted_at IS NULL;

CREATE TABLE IF NOT EXISTS marketplace_android_live_tracking_sessions (
    live_tracking_session_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    branch_id UUID,
    order_id UUID NOT NULL,
    delivery_assignment_id UUID,
    customer_user_id UUID NOT NULL,
    merchant_user_id UUID NOT NULL,
    courier_user_id UUID,
    origin_module TEXT NOT NULL DEFAULT 'MARKETPLACE',
    platform_scope TEXT NOT NULL DEFAULT 'ANDROID_ONLY',
    stock_activation_allowed BOOLEAN NOT NULL DEFAULT FALSE,
    notification_mode TEXT NOT NULL DEFAULT 'FOREGROUND_SERVICE',
    live_update_mode TEXT NOT NULL DEFAULT 'LIVE_UPDATES_WITH_FOREGROUND_FALLBACK',
    fcm_topic_ref TEXT,
    map_provider TEXT NOT NULL DEFAULT 'google_maps_android',
    visual_theme_json JSONB NOT NULL DEFAULT '{"background":"Night/Cosmic","progress":"Violet","active_status":"Cyan"}'::JSONB,
    latest_eta_minutes INTEGER,
    latest_status TEXT NOT NULL DEFAULT 'WAITING_DISPATCH',
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID,
    CONSTRAINT fk_marketplace_android_live_tracking_sessions_tenant
        FOREIGN KEY (tenant_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_marketplace_android_live_tracking_sessions_branch
        FOREIGN KEY (branch_id) REFERENCES merchant_erp_branch_units (merchant_erp_branch_unit_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_marketplace_android_live_tracking_sessions_order
        FOREIGN KEY (order_id) REFERENCES orders (order_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_marketplace_android_live_tracking_sessions_assignment
        FOREIGN KEY (delivery_assignment_id) REFERENCES merchant_erp_delivery_assignments (merchant_erp_delivery_assignment_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_marketplace_android_live_tracking_sessions_customer
        FOREIGN KEY (customer_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_marketplace_android_live_tracking_sessions_merchant
        FOREIGN KEY (merchant_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_marketplace_android_live_tracking_sessions_courier
        FOREIGN KEY (courier_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_marketplace_android_live_tracking_sessions_created_by
        FOREIGN KEY (created_by) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT chk_marketplace_android_live_tracking_sessions_origin CHECK (origin_module = 'MARKETPLACE' AND stock_activation_allowed = FALSE),
    CONSTRAINT chk_marketplace_android_live_tracking_sessions_platform CHECK (platform_scope = 'ANDROID_ONLY'),
    CONSTRAINT chk_marketplace_android_live_tracking_sessions_notification CHECK (notification_mode IN ('FOREGROUND_SERVICE', 'ANDROID_LIVE_UPDATES')),
    CONSTRAINT chk_marketplace_android_live_tracking_sessions_update CHECK (live_update_mode IN ('LIVE_UPDATES_WITH_FOREGROUND_FALLBACK', 'FOREGROUND_ONLY')),
    CONSTRAINT chk_marketplace_android_live_tracking_sessions_eta CHECK (latest_eta_minutes IS NULL OR latest_eta_minutes >= 0),
    CONSTRAINT chk_marketplace_android_live_tracking_sessions_status CHECK (latest_status IN ('WAITING_DISPATCH', 'ACCEPTED', 'STARTED', 'IN_TRANSIT', 'ARRIVING', 'DELIVERED', 'FAILED', 'CANCELED')),
    CONSTRAINT chk_marketplace_android_live_tracking_sessions_dates CHECK (completed_at IS NULL OR started_at IS NULL OR completed_at >= started_at),
    CONSTRAINT chk_marketplace_android_live_tracking_sessions_json CHECK (jsonb_typeof(visual_theme_json) = 'object' AND jsonb_typeof(metadata_json) = 'object')
);

CREATE INDEX IF NOT EXISTS ix_marketplace_android_live_tracking_sessions_scope
    ON marketplace_android_live_tracking_sessions (tenant_id, branch_id, latest_status, updated_at DESC);

CREATE UNIQUE INDEX IF NOT EXISTS ux_marketplace_android_live_tracking_sessions_order
    ON marketplace_android_live_tracking_sessions (order_id)
    WHERE latest_status NOT IN ('DELIVERED', 'FAILED', 'CANCELED');

CREATE TABLE IF NOT EXISTS marketplace_android_live_tracking_events (
    live_tracking_event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    live_tracking_session_id UUID NOT NULL,
    tenant_id UUID NOT NULL,
    branch_id UUID,
    event_type TEXT NOT NULL,
    event_status TEXT NOT NULL DEFAULT 'RECEIVED',
    latitude NUMERIC(10,7),
    longitude NUMERIC(10,7),
    eta_minutes INTEGER,
    notification_payload_ref TEXT,
    payload_digest TEXT NOT NULL,
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID,
    CONSTRAINT fk_marketplace_android_live_tracking_events_session
        FOREIGN KEY (live_tracking_session_id) REFERENCES marketplace_android_live_tracking_sessions (live_tracking_session_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT fk_marketplace_android_live_tracking_events_tenant
        FOREIGN KEY (tenant_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_marketplace_android_live_tracking_events_branch
        FOREIGN KEY (branch_id) REFERENCES merchant_erp_branch_units (merchant_erp_branch_unit_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_marketplace_android_live_tracking_events_created_by
        FOREIGN KEY (created_by) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT chk_marketplace_android_live_tracking_events_type CHECK (event_type IN ('FCM_SILENT_PUSH', 'FOREGROUND_STARTED', 'LIVE_UPDATE_RENDERED', 'MAP_POSITION_UPDATE', 'ETA_UPDATE', 'STATUS_CHANGE', 'DELIVERED_AUDIO_OPTION')),
    CONSTRAINT chk_marketplace_android_live_tracking_events_status CHECK (event_status IN ('RECEIVED', 'PROCESSED', 'FAILED')),
    CONSTRAINT chk_marketplace_android_live_tracking_events_geo CHECK ((latitude IS NULL OR latitude BETWEEN -90 AND 90) AND (longitude IS NULL OR longitude BETWEEN -180 AND 180)),
    CONSTRAINT chk_marketplace_android_live_tracking_events_eta CHECK (eta_minutes IS NULL OR eta_minutes >= 0),
    CONSTRAINT chk_marketplace_android_live_tracking_events_digest CHECK (btrim(payload_digest) <> '')
);

CREATE INDEX IF NOT EXISTS ix_marketplace_android_live_tracking_events_session_time
    ON marketplace_android_live_tracking_events (live_tracking_session_id, occurred_at DESC);

CREATE TABLE IF NOT EXISTS marketplace_chat_moderation_patterns (
    moderation_pattern_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pattern_key TEXT NOT NULL UNIQUE,
    pattern_regex TEXT NOT NULL,
    severity TEXT NOT NULL DEFAULT 'WARNING',
    blocked_category TEXT NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID,
    CONSTRAINT fk_marketplace_chat_moderation_patterns_created_by
        FOREIGN KEY (created_by) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT chk_marketplace_chat_moderation_patterns_key CHECK (pattern_key ~ '^[a-z0-9_.-]{2,80}$'),
    CONSTRAINT chk_marketplace_chat_moderation_patterns_regex CHECK (btrim(pattern_regex) <> ''),
    CONSTRAINT chk_marketplace_chat_moderation_patterns_severity CHECK (severity IN ('INFO', 'WARNING', 'SEVERE')),
    CONSTRAINT chk_marketplace_chat_moderation_patterns_category CHECK (blocked_category IN ('phone', 'email', 'messenger', 'social_link', 'external_payment', 'generic_external_contact'))
);

INSERT INTO marketplace_chat_moderation_patterns (
    pattern_key,
    pattern_regex,
    severity,
    blocked_category
) VALUES
    ('phone_long_digits', '([0-9][^0-9]?){8,13}', 'WARNING', 'phone'),
    ('email_shape', '[A-Z0-9._%+-]+@[A-Z0-9.-]+[.][A-Z]{2,}', 'WARNING', 'email'),
    ('whatsapp_terms', '(whatsapp|wpp|zap|whats|wa[.]me)', 'SEVERE', 'messenger'),
    ('telegram_terms', '(telegram|t[.]me)', 'SEVERE', 'messenger'),
    ('social_external_terms', '(instagram|insta|facebook|fb\\.com|tiktok|linkedin|rede social)', 'WARNING', 'social_link'),
    ('external_contact_terms', '(telefone|celular|e-mail|email|contato externo|fora do app)', 'WARNING', 'generic_external_contact')
ON CONFLICT (pattern_key) DO UPDATE
SET pattern_regex = EXCLUDED.pattern_regex,
    severity = EXCLUDED.severity,
    blocked_category = EXCLUDED.blocked_category,
    is_active = TRUE,
    updated_at = NOW();

CREATE TABLE IF NOT EXISTS chat_moderation_strikes (
    chat_moderation_strike_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    branch_id UUID,
    user_id UUID NOT NULL,
    merchant_user_id UUID,
    storefront_id UUID,
    conversation_id UUID NOT NULL,
    message_id UUID NOT NULL,
    matched_pattern TEXT NOT NULL,
    blocked_category TEXT NOT NULL,
    strike_count INTEGER NOT NULL,
    action_status TEXT NOT NULL DEFAULT 'WARNED',
    helena_warning_copy TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID,
    CONSTRAINT fk_chat_moderation_strikes_tenant
        FOREIGN KEY (tenant_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_chat_moderation_strikes_branch
        FOREIGN KEY (branch_id) REFERENCES merchant_erp_branch_units (merchant_erp_branch_unit_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_chat_moderation_strikes_user
        FOREIGN KEY (user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_chat_moderation_strikes_merchant
        FOREIGN KEY (merchant_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_chat_moderation_strikes_storefront
        FOREIGN KEY (storefront_id) REFERENCES merchant_storefronts (storefront_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_chat_moderation_strikes_conversation
        FOREIGN KEY (conversation_id) REFERENCES chat_conversations (conversation_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_chat_moderation_strikes_message
        FOREIGN KEY (message_id) REFERENCES chat_messages (message_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_chat_moderation_strikes_created_by
        FOREIGN KEY (created_by) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT chk_chat_moderation_strikes_pattern CHECK (btrim(matched_pattern) <> ''),
    CONSTRAINT chk_chat_moderation_strikes_count CHECK (strike_count > 0),
    CONSTRAINT chk_chat_moderation_strikes_action CHECK (action_status IN ('WARNED', 'SEVERE_WARNING', 'SUSPENSION_EVENT_CREATED')),
    CONSTRAINT chk_chat_moderation_strikes_warning CHECK (btrim(helena_warning_copy) <> '')
);

CREATE INDEX IF NOT EXISTS ix_chat_moderation_strikes_user_time
    ON chat_moderation_strikes (tenant_id, user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS chat_moderation_account_actions (
    chat_moderation_account_action_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    branch_id UUID,
    user_id UUID NOT NULL,
    merchant_user_id UUID,
    action_event TEXT NOT NULL DEFAULT 'account.suspended.evasion',
    action_status TEXT NOT NULL DEFAULT 'AUTO_CREATED',
    strike_count INTEGER NOT NULL,
    requires_manual_review BOOLEAN NOT NULL DEFAULT TRUE,
    action_payload_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID,
    CONSTRAINT fk_chat_moderation_account_actions_tenant
        FOREIGN KEY (tenant_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_chat_moderation_account_actions_branch
        FOREIGN KEY (branch_id) REFERENCES merchant_erp_branch_units (merchant_erp_branch_unit_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_chat_moderation_account_actions_user
        FOREIGN KEY (user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_chat_moderation_account_actions_merchant
        FOREIGN KEY (merchant_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_chat_moderation_account_actions_created_by
        FOREIGN KEY (created_by) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT chk_chat_moderation_account_actions_event CHECK (action_event IN ('account.suspended.evasion', 'merchant.listings.paused.evasion')),
    CONSTRAINT chk_chat_moderation_account_actions_status CHECK (action_status IN ('AUTO_CREATED', 'APPLIED', 'FAILED', 'MANUAL_REVIEW')),
    CONSTRAINT chk_chat_moderation_account_actions_count CHECK (strike_count >= 3),
    CONSTRAINT chk_chat_moderation_account_actions_payload CHECK (jsonb_typeof(action_payload_json) = 'object')
);

CREATE INDEX IF NOT EXISTS ix_chat_moderation_account_actions_user_time
    ON chat_moderation_account_actions (tenant_id, user_id, created_at DESC);

CREATE OR REPLACE FUNCTION marketplace_chat_moderation_after_insert()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    pattern_record RECORD;
    thread_record RECORD;
    next_count INTEGER;
    warning_copy TEXT;
BEGIN
    SELECT
        thread.buyer_user_id,
        thread.merchant_user_id,
        thread.storefront_id
      INTO thread_record
      FROM commerce_chat_threads thread
     WHERE thread.conversation_id = NEW.conversation_id;

    IF NOT FOUND THEN
        RETURN NEW;
    END IF;

    FOR pattern_record IN
        SELECT pattern_key, pattern_regex, blocked_category, severity
          FROM marketplace_chat_moderation_patterns
         WHERE is_active = TRUE
         ORDER BY CASE severity WHEN 'SEVERE' THEN 0 WHEN 'WARNING' THEN 1 ELSE 2 END, pattern_key
    LOOP
        IF NEW.content ~* pattern_record.pattern_regex THEN
            SELECT COUNT(*) + 1
              INTO next_count
              FROM chat_moderation_strikes strike
             WHERE strike.tenant_id = thread_record.merchant_user_id
               AND strike.user_id = NEW.sender_id
               AND strike.created_at >= NOW() - INTERVAL '6 months';

            warning_copy := 'Aviso de seguranca Valley: identificamos compartilhamento ou solicitacao de contato externo. Para proteger compra, venda e garantia, toda negociacao deve ocorrer exclusivamente no chat oficial Valley.';

            INSERT INTO chat_moderation_strikes (
                tenant_id,
                user_id,
                merchant_user_id,
                storefront_id,
                conversation_id,
                message_id,
                matched_pattern,
                blocked_category,
                strike_count,
                action_status,
                helena_warning_copy,
                created_by
            ) VALUES (
                thread_record.merchant_user_id,
                NEW.sender_id,
                thread_record.merchant_user_id,
                thread_record.storefront_id,
                NEW.conversation_id,
                NEW.message_id,
                pattern_record.pattern_key,
                pattern_record.blocked_category,
                next_count,
                CASE
                    WHEN next_count >= 3 THEN 'SUSPENSION_EVENT_CREATED'
                    WHEN next_count = 2 THEN 'SEVERE_WARNING'
                    ELSE 'WARNED'
                END,
                warning_copy,
                NEW.sender_id
            );

            IF next_count >= 3 THEN
                INSERT INTO chat_moderation_account_actions (
                    tenant_id,
                    user_id,
                    merchant_user_id,
                    action_event,
                    strike_count,
                    action_payload_json,
                    created_by
                ) VALUES (
                    thread_record.merchant_user_id,
                    NEW.sender_id,
                    thread_record.merchant_user_id,
                    'account.suspended.evasion',
                    next_count,
                    jsonb_build_object(
                        'conversation_id', NEW.conversation_id,
                        'message_id', NEW.message_id,
                        'matched_pattern', pattern_record.pattern_key,
                        'pause_marketplace_listings', TRUE,
                        'requires_acceptance_term', TRUE
                    ),
                    NEW.sender_id
                );
            END IF;

            RETURN NEW;
        END IF;
    END LOOP;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_marketplace_chat_moderation_after_insert ON chat_messages;
CREATE TRIGGER trg_marketplace_chat_moderation_after_insert
AFTER INSERT ON chat_messages
FOR EACH ROW
EXECUTE FUNCTION marketplace_chat_moderation_after_insert();

DO $$
DECLARE
    target_name TEXT;
BEGIN
    IF to_regprocedure('public.set_updated_at()') IS NULL THEN
        RETURN;
    END IF;

    FOREACH target_name IN ARRAY ARRAY[
        'merchant_erp_access_policies',
        'merchant_erp_users',
        'merchant_erp_products',
        'merchant_erp_inventory',
        'merchant_erp_orders',
        'merchant_erp_deliveries',
        'merchant_erp_appointments',
        'helena_user_voice_profiles',
        'valley_contextual_reward_campaigns',
        'mobility_realtime_route_sessions',
        'mobility_idle_agent_dispatch_rules',
        'marketplace_android_live_tracking_sessions',
        'marketplace_chat_moderation_patterns',
        'valley_screen_layout_contracts',
        'valley_wallet_asset_registry',
        'valley_user_addresses',
        'valley_user_document_checks',
        'valley_module_data_contracts',
        'valley_module_user_scope_bindings',
        'valley_marketplace_api_accounts',
        'valley_bank_api_connections'
    ]
    LOOP
        IF to_regclass('public.' || target_name) IS NOT NULL THEN
            EXECUTE format('DROP TRIGGER IF EXISTS trg_%s_set_updated_at ON public.%I', target_name, target_name);
            EXECUTE format(
                'CREATE TRIGGER trg_%s_set_updated_at BEFORE UPDATE ON public.%I FOR EACH ROW EXECUTE FUNCTION set_updated_at()',
                target_name,
                target_name
            );
        END IF;
    END LOOP;
END;
$$;

CREATE TABLE IF NOT EXISTS valley_immutable_audit_ledger (
    immutable_event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    module_key TEXT NOT NULL,
    user_id UUID NOT NULL,
    merchant_user_id UUID,
    branch_unit_id UUID,
    entity_table TEXT NOT NULL,
    entity_id UUID,
    event_type TEXT NOT NULL,
    event_hash TEXT NOT NULL,
    previous_event_hash TEXT,
    payload_digest TEXT NOT NULL,
    payload_ref TEXT,
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    CONSTRAINT fk_valley_immutable_audit_ledger_module
        FOREIGN KEY (module_key) REFERENCES valley_module_data_contracts (module_key)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_valley_immutable_audit_ledger_user
        FOREIGN KEY (user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_valley_immutable_audit_ledger_merchant
        FOREIGN KEY (merchant_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_valley_immutable_audit_ledger_branch
        FOREIGN KEY (branch_unit_id) REFERENCES merchant_erp_branch_units (merchant_erp_branch_unit_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT chk_valley_immutable_audit_ledger_entity CHECK (entity_table ~ '^[a-z0-9_.-]{2,120}$'),
    CONSTRAINT chk_valley_immutable_audit_ledger_type CHECK (event_type ~ '^[A-Z0-9_.-]{2,120}$'),
    CONSTRAINT chk_valley_immutable_audit_ledger_hash CHECK (btrim(event_hash) <> '' AND btrim(payload_digest) <> ''),
    CONSTRAINT chk_valley_immutable_audit_ledger_metadata CHECK (jsonb_typeof(metadata_json) = 'object')
);

CREATE INDEX IF NOT EXISTS ix_valley_immutable_audit_ledger_module_time
    ON valley_immutable_audit_ledger (module_key, occurred_at DESC);

CREATE INDEX IF NOT EXISTS ix_valley_immutable_audit_ledger_user_time
    ON valley_immutable_audit_ledger (user_id, occurred_at DESC);

CREATE INDEX IF NOT EXISTS ix_valley_immutable_audit_ledger_merchant_time
    ON valley_immutable_audit_ledger (merchant_user_id, branch_unit_id, occurred_at DESC)
    WHERE merchant_user_id IS NOT NULL;

CREATE OR REPLACE FUNCTION valley_prevent_update_delete()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE EXCEPTION 'Tabela append-only %.% nao permite operacao %', TG_TABLE_SCHEMA, TG_TABLE_NAME, TG_OP;
END;
$$;

DO $$
DECLARE
    target_name TEXT;
BEGIN
    FOREACH target_name IN ARRAY ARRAY[
        'public.equity_ledger',
        'public.merchant_erp_audit_events',
        'public.merchant_erp_security_events',
        'public.merchant_erp_connector_sync_events',
        'public.merchant_erp_service_booking_events',
        'public.merchant_erp_delivery_tracking_events',
        'public.merchant_erp_product_lifecycle_events',
        'public.merchant_erp_report_query_events',
        'public.merchant_erp_branch_events',
        'public.merchant_erp_privilege_audit_events',
        'public.chat_messages',
        'public.chat_moderation_strikes',
        'public.chat_moderation_account_actions',
        'public.helena_product_sourcing_decisions',
        'public.mobility_idle_agent_events',
        'public.marketplace_android_live_tracking_events',
        'public.valley_module_availability_checks',
        'public.valley_immutable_audit_ledger'
    ]
    LOOP
        IF to_regclass(target_name) IS NOT NULL THEN
            EXECUTE format('DROP TRIGGER IF EXISTS trg_valley_append_only_guard ON %s', target_name);
            EXECUTE format(
                'CREATE TRIGGER trg_valley_append_only_guard BEFORE UPDATE OR DELETE ON %s FOR EACH ROW EXECUTE FUNCTION valley_prevent_update_delete()',
                target_name
            );
        END IF;
    END LOOP;
END;
$$;

CREATE OR REPLACE VIEW v_valley_hybrid_scope_matrix AS
SELECT
    contract.module_key,
    contract.module_label,
    contract.data_home,
    contract.owner_table,
    contract.owner_user_column,
    contract.tenant_scope_required,
    contract.branch_scope_required,
    contract.append_only_required,
    contract.public_runtime_required,
    contract.api_contract_json,
    contract.updated_at
FROM valley_module_data_contracts contract
ORDER BY contract.module_key;

CREATE OR REPLACE VIEW v_valley_user_scope_bindings_active AS
SELECT
    binding.scope_binding_id,
    binding.module_key,
    contract.module_label,
    binding.user_id,
    binding.merchant_user_id,
    binding.branch_unit_id,
    binding.entity_table,
    binding.entity_id,
    binding.relation_role,
    binding.scope_status,
    binding.created_at,
    binding.updated_at
FROM valley_module_user_scope_bindings binding
JOIN valley_module_data_contracts contract
  ON contract.module_key = binding.module_key
WHERE binding.deleted_at IS NULL
  AND binding.scope_status = 'ACTIVE';

CREATE OR REPLACE VIEW v_valley_marketplace_account_health AS
SELECT
    account.merchant_user_id,
    account.branch_unit_id,
    account.provider_key,
    account.environment,
    account.connection_status,
    account.bidirectional_sync_enabled,
    account.listing_sync_enabled,
    account.order_import_enabled,
    account.stock_export_enabled,
    account.price_export_enabled,
    account.last_inbound_sync_at,
    account.last_outbound_sync_at,
    account.updated_at
FROM valley_marketplace_api_accounts account
WHERE account.deleted_at IS NULL;

COMMENT ON TABLE valley_wallet_asset_registry IS 'Registro canonico de ativos exibiveis ou internos do Valley, incluindo BRL e V-Coin sem expor recurso oculto ao usuario final.';
COMMENT ON TABLE valley_user_addresses IS 'Enderecos confirmados por usuario para cadastro, entrega, faturamento, retirada e devolucao.';
COMMENT ON TABLE valley_user_document_checks IS 'Historico de verificacao documental por provider externo, sem guardar resposta sensivel bruta.';
COMMENT ON TABLE merchant_erp_access_policies IS 'Politicas mandatarias de ACL, escopo por lojista/filial e guardrails de exibicao final.';
COMMENT ON TABLE merchant_erp_users IS 'Tabela canonica de usuarios do ERP Lojista com tenant_id, branch_id, papel e status de acesso.';
COMMENT ON TABLE merchant_erp_products IS 'Tabela canonica de produtos do ERP Lojista para CRUD, publicacao, etiquetas e grade.';
COMMENT ON TABLE merchant_erp_inventory IS 'Saldo canonico do ERP Lojista por produto, tenant_id e branch_id, incluindo reservas e alertas.';
COMMENT ON TABLE merchant_erp_orders IS 'Pedidos canonicos do ERP Lojista com origem, status, valores finais e escopo por tenant/filial.';
COMMENT ON TABLE merchant_erp_deliveries IS 'Entregas canonicas do ERP Lojista com rastreio, entregador, prova e status operacional.';
COMMENT ON TABLE merchant_erp_appointments IS 'Agenda canonica de servicos do ERP Lojista para profissionais, salas e horarios.';
COMMENT ON TABLE helena_user_voice_profiles IS 'Perfil de voz e regionalizacao da Helena em pt-BR por cidade/estado de nascimento.';
COMMENT ON TABLE helena_product_sourcing_decisions IS 'Decisoes append-only da Helena para publicar produto apenas quando a meta de preco final for atendida.';
COMMENT ON TABLE valley_contextual_reward_campaigns IS 'Campanhas contextuais internas; por padrao ocultas na UI final ate liberacao explicita.';
COMMENT ON TABLE mobility_realtime_route_sessions IS 'Sessoes de mobilidade para acompanhar onibus, metro e transporte por aplicativo em tempo real.';
COMMENT ON TABLE mobility_idle_agent_dispatch_rules IS 'Regras persistentes do agente autonomo de Mobilidade para monitorar trajetos e compromissos.';
COMMENT ON TABLE mobility_idle_agent_events IS 'Eventos append-only de Mobilidade: preco alto, acidente, atraso, recalculo e alerta proativo.';
COMMENT ON TABLE valley_module_availability_checks IS 'Agente de verificacao de disponibilidade de modulos, incluindo Visio.';
COMMENT ON TABLE valley_screen_layout_contracts IS 'Contratos persistentes para Stitch UI por tela, bloco, botao, campo e lista.';
COMMENT ON TABLE valley_module_data_contracts IS 'Matriz institucional de modulos, origem de dados e regra de escopo por usuario/lojista/filial.';
COMMENT ON TABLE valley_module_user_scope_bindings IS 'Amarracao auditavel entre registros de qualquer modulo e users.user_id.';
COMMENT ON TABLE valley_marketplace_api_accounts IS 'Contas de marketplaces bidirecionais por lojista, filial, provider e ambiente.';
COMMENT ON TABLE valley_bank_api_connections IS 'Conexoes bancarias e Open Finance por lojista, filial e provider sem segredos brutos.';
COMMENT ON TABLE marketplace_android_live_tracking_sessions IS 'Rastreio Android em tempo real exclusivo para pedidos Marketplace; nunca ativado para Stock.';
COMMENT ON TABLE marketplace_android_live_tracking_events IS 'Eventos append-only do rastreio Android: FCM, foreground service, live update, mapa, ETA e status.';
COMMENT ON TABLE marketplace_chat_moderation_patterns IS 'Padroes de moderacao para impedir evasao de chat por telefone, email, mensageria e redes externas.';
COMMENT ON TABLE chat_moderation_strikes IS 'Advertencias append-only por tentativa de contato externo no chat Marketplace.';
COMMENT ON TABLE chat_moderation_account_actions IS 'Eventos de suspensao automatica por regra de tres advertencias no chat Marketplace.';
COMMENT ON TABLE valley_immutable_audit_ledger IS 'Ledger generico imutavel para evidencias criticas e cadeia de hash.';

COMMIT;
