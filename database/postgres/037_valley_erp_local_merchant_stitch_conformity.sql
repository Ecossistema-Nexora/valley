-- Valley ERP Local Merchant Stitch Conformity
-- Escopo: projeto Stitch Valley ERP, desktop-first Windows para lojista local.
-- Objetivo: preservar e estruturar tudo que foi proposto no payload Stitch ERP sem misturar com Valley Rider.
-- Regra: Merchant local nao ve dropshipping, Amazon, AliExpress, Alibaba, CJDropshipping ou marketplace externo.

BEGIN;

SET search_path = public;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'erp_local_status_enum') THEN
        CREATE TYPE erp_local_status_enum AS ENUM ('DRAFT', 'ACTIVE', 'INACTIVE', 'ARCHIVED');
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'erp_local_stock_movement_enum') THEN
        CREATE TYPE erp_local_stock_movement_enum AS ENUM ('INBOUND', 'OUTBOUND', 'ADJUSTMENT', 'RESERVATION', 'RELEASE', 'SALE', 'RETURN', 'LOSS');
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'erp_local_sale_status_enum') THEN
        CREATE TYPE erp_local_sale_status_enum AS ENUM ('DRAFT', 'OPEN', 'SEPARATING', 'READY_TO_SHIP', 'SHIPPED', 'COMPLETED', 'CANCELLED', 'REFUNDED');
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'erp_local_freight_status_enum') THEN
        CREATE TYPE erp_local_freight_status_enum AS ENUM ('DRAFT', 'CREATED', 'LABEL_PRINTED', 'COLLECTED', 'IN_TRANSIT', 'DELIVERED', 'FAILED', 'CANCELLED');
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'erp_pepita_gift_status_enum') THEN
        CREATE TYPE erp_pepita_gift_status_enum AS ENUM ('OFFERED', 'CONFIRMED', 'DECLINED', 'CANCELLED', 'REVERSED');
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'erp_desktop_ota_status_enum') THEN
        CREATE TYPE erp_desktop_ota_status_enum AS ENUM ('CHECKING', 'AVAILABLE', 'DOWNLOADING', 'READY_NEXT_RESTART', 'APPLIED', 'FAILED', 'ROLLED_BACK');
    END IF;
END
$$;

CREATE TABLE IF NOT EXISTS erp_local_store_settings (
    erp_store_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_user_id UUID NOT NULL,
    store_name TEXT NOT NULL,
    store_status erp_local_status_enum NOT NULL DEFAULT 'ACTIVE',
    local_only BOOLEAN NOT NULL DEFAULT TRUE,
    desktop_channel TEXT NOT NULL DEFAULT 'stable',
    allow_external_marketplaces BOOLEAN NOT NULL DEFAULT FALSE,
    allow_dropshipping BOOLEAN NOT NULL DEFAULT FALSE,
    print_preferences_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    notification_preferences_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_erp_local_store_settings_merchant FOREIGN KEY (merchant_user_id) REFERENCES users(user_id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT uq_erp_local_store_settings_merchant UNIQUE (merchant_user_id),
    CONSTRAINT chk_erp_local_store_local_only CHECK (local_only = TRUE),
    CONSTRAINT chk_erp_local_store_no_marketplaces CHECK (allow_external_marketplaces = FALSE),
    CONSTRAINT chk_erp_local_store_no_dropshipping CHECK (allow_dropshipping = FALSE),
    CONSTRAINT chk_erp_local_store_name CHECK (btrim(store_name) <> ''),
    CONSTRAINT chk_erp_local_store_print_json CHECK (jsonb_typeof(print_preferences_json) = 'object'),
    CONSTRAINT chk_erp_local_store_notification_json CHECK (jsonb_typeof(notification_preferences_json) = 'object'),
    CONSTRAINT chk_erp_local_store_metadata_json CHECK (jsonb_typeof(metadata_json) = 'object')
);

CREATE TABLE IF NOT EXISTS erp_local_categories (
    erp_category_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_user_id UUID NOT NULL,
    parent_category_id UUID,
    category_name TEXT NOT NULL,
    category_code TEXT NOT NULL,
    category_status erp_local_status_enum NOT NULL DEFAULT 'ACTIVE',
    sort_order INTEGER NOT NULL DEFAULT 0,
    local_only BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_erp_local_categories_merchant FOREIGN KEY (merchant_user_id) REFERENCES users(user_id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_erp_local_categories_parent FOREIGN KEY (parent_category_id) REFERENCES erp_local_categories(erp_category_id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT uq_erp_local_categories_code UNIQUE (merchant_user_id, category_code),
    CONSTRAINT chk_erp_local_categories_name CHECK (btrim(category_name) <> ''),
    CONSTRAINT chk_erp_local_categories_code CHECK (btrim(category_code) <> ''),
    CONSTRAINT chk_erp_local_categories_local_only CHECK (local_only = TRUE)
);

CREATE TABLE IF NOT EXISTS erp_local_product_variants (
    erp_variant_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_user_id UUID NOT NULL,
    item_id UUID NOT NULL,
    erp_category_id UUID,
    variant_sku TEXT NOT NULL,
    barcode TEXT,
    variant_name TEXT NOT NULL,
    brand_name TEXT,
    attributes_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    sale_price_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    cost_price_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    promotional_price_brl DECIMAL(18,4),
    variant_status erp_local_status_enum NOT NULL DEFAULT 'ACTIVE',
    local_only BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_erp_local_product_variants_merchant FOREIGN KEY (merchant_user_id) REFERENCES users(user_id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_erp_local_product_variants_item FOREIGN KEY (item_id) REFERENCES inventory_items(item_id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_erp_local_product_variants_category FOREIGN KEY (erp_category_id) REFERENCES erp_local_categories(erp_category_id) ON UPDATE CASCADE ON DELETE SET NULL,
    CONSTRAINT uq_erp_local_product_variants_sku UNIQUE (merchant_user_id, variant_sku),
    CONSTRAINT chk_erp_local_product_variants_sku CHECK (btrim(variant_sku) <> ''),
    CONSTRAINT chk_erp_local_product_variants_name CHECK (btrim(variant_name) <> ''),
    CONSTRAINT chk_erp_local_product_variants_prices CHECK (sale_price_brl >= 0 AND cost_price_brl >= 0 AND (promotional_price_brl IS NULL OR promotional_price_brl >= 0)),
    CONSTRAINT chk_erp_local_product_variants_attrs CHECK (jsonb_typeof(attributes_json) = 'object'),
    CONSTRAINT chk_erp_local_product_variants_local_only CHECK (local_only = TRUE)
);

CREATE TABLE IF NOT EXISTS erp_physical_stock_positions (
    erp_stock_position_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_user_id UUID NOT NULL,
    erp_variant_id UUID NOT NULL,
    warehouse_id UUID,
    physical_location TEXT,
    physical_quantity DECIMAL(18,4) NOT NULL DEFAULT 0,
    reserved_quantity DECIMAL(18,4) NOT NULL DEFAULT 0,
    minimum_quantity DECIMAL(18,4) NOT NULL DEFAULT 0,
    last_counted_at TIMESTAMPTZ,
    local_only BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_erp_physical_stock_positions_merchant FOREIGN KEY (merchant_user_id) REFERENCES users(user_id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_erp_physical_stock_positions_variant FOREIGN KEY (erp_variant_id) REFERENCES erp_local_product_variants(erp_variant_id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_erp_physical_stock_positions_warehouse FOREIGN KEY (warehouse_id) REFERENCES warehouses(warehouse_id) ON UPDATE CASCADE ON DELETE SET NULL,
    CONSTRAINT uq_erp_physical_stock_positions_variant_location UNIQUE (merchant_user_id, erp_variant_id, physical_location),
    CONSTRAINT chk_erp_physical_stock_positions_quantities CHECK (physical_quantity >= 0 AND reserved_quantity >= 0 AND minimum_quantity >= 0 AND reserved_quantity <= physical_quantity),
    CONSTRAINT chk_erp_physical_stock_positions_local_only CHECK (local_only = TRUE)
);

CREATE TABLE IF NOT EXISTS erp_physical_stock_movements (
    erp_stock_movement_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_user_id UUID NOT NULL,
    erp_stock_position_id UUID NOT NULL,
    actor_user_id UUID,
    movement_type erp_local_stock_movement_enum NOT NULL,
    quantity_delta DECIMAL(18,4) NOT NULL,
    movement_reason TEXT NOT NULL,
    sale_id UUID,
    reference_code TEXT,
    payload_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_erp_physical_stock_movements_merchant FOREIGN KEY (merchant_user_id) REFERENCES users(user_id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_erp_physical_stock_movements_position FOREIGN KEY (erp_stock_position_id) REFERENCES erp_physical_stock_positions(erp_stock_position_id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_erp_physical_stock_movements_actor FOREIGN KEY (actor_user_id) REFERENCES users(user_id) ON UPDATE CASCADE ON DELETE SET NULL,
    CONSTRAINT chk_erp_physical_stock_movements_delta CHECK (quantity_delta <> 0),
    CONSTRAINT chk_erp_physical_stock_movements_reason CHECK (btrim(movement_reason) <> ''),
    CONSTRAINT chk_erp_physical_stock_movements_payload CHECK (jsonb_typeof(payload_json) = 'object')
);

CREATE TABLE IF NOT EXISTS erp_local_sales (
    sale_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_user_id UUID NOT NULL,
    customer_user_id UUID,
    linked_order_id UUID,
    sale_number TEXT NOT NULL,
    sale_status erp_local_sale_status_enum NOT NULL DEFAULT 'OPEN',
    subtotal_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    discount_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    freight_charged_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    total_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    payment_status TEXT NOT NULL DEFAULT 'PENDING',
    completed_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,
    cancellation_reason TEXT,
    local_only BOOLEAN NOT NULL DEFAULT TRUE,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_erp_local_sales_merchant FOREIGN KEY (merchant_user_id) REFERENCES users(user_id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_erp_local_sales_customer FOREIGN KEY (customer_user_id) REFERENCES users(user_id) ON UPDATE CASCADE ON DELETE SET NULL,
    CONSTRAINT fk_erp_local_sales_order FOREIGN KEY (linked_order_id) REFERENCES orders(order_id) ON UPDATE CASCADE ON DELETE SET NULL,
    CONSTRAINT uq_erp_local_sales_number UNIQUE (merchant_user_id, sale_number),
    CONSTRAINT chk_erp_local_sales_number CHECK (btrim(sale_number) <> ''),
    CONSTRAINT chk_erp_local_sales_amounts CHECK (subtotal_brl >= 0 AND discount_brl >= 0 AND freight_charged_brl >= 0 AND total_brl >= 0),
    CONSTRAINT chk_erp_local_sales_local_only CHECK (local_only = TRUE),
    CONSTRAINT chk_erp_local_sales_metadata CHECK (jsonb_typeof(metadata_json) = 'object')
);

CREATE TABLE IF NOT EXISTS erp_local_sale_items (
    sale_item_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sale_id UUID NOT NULL,
    merchant_user_id UUID NOT NULL,
    erp_variant_id UUID NOT NULL,
    quantity DECIMAL(18,4) NOT NULL,
    unit_price_brl DECIMAL(18,4) NOT NULL,
    line_discount_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    line_total_brl DECIMAL(18,4) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_erp_local_sale_items_sale FOREIGN KEY (sale_id) REFERENCES erp_local_sales(sale_id) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_erp_local_sale_items_merchant FOREIGN KEY (merchant_user_id) REFERENCES users(user_id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_erp_local_sale_items_variant FOREIGN KEY (erp_variant_id) REFERENCES erp_local_product_variants(erp_variant_id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT chk_erp_local_sale_items_amounts CHECK (quantity > 0 AND unit_price_brl >= 0 AND line_discount_brl >= 0 AND line_total_brl >= 0)
);

CREATE TABLE IF NOT EXISTS erp_physical_freights (
    erp_freight_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_user_id UUID NOT NULL,
    sale_id UUID NOT NULL,
    carrier_name TEXT,
    service_name TEXT,
    pickup_window_start TIMESTAMPTZ,
    pickup_window_end TIMESTAMPTZ,
    tracking_code TEXT,
    declared_value_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    merchant_freight_cost_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    customer_freight_charge_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    freight_status erp_local_freight_status_enum NOT NULL DEFAULT 'DRAFT',
    label_document_id UUID,
    proof_document_id UUID,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_erp_physical_freights_merchant FOREIGN KEY (merchant_user_id) REFERENCES users(user_id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_erp_physical_freights_sale FOREIGN KEY (sale_id) REFERENCES erp_local_sales(sale_id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_erp_physical_freights_label_doc FOREIGN KEY (label_document_id) REFERENCES document_records(document_id) ON UPDATE CASCADE ON DELETE SET NULL,
    CONSTRAINT fk_erp_physical_freights_proof_doc FOREIGN KEY (proof_document_id) REFERENCES document_records(document_id) ON UPDATE CASCADE ON DELETE SET NULL,
    CONSTRAINT chk_erp_physical_freights_amounts CHECK (declared_value_brl >= 0 AND merchant_freight_cost_brl >= 0 AND customer_freight_charge_brl >= 0),
    CONSTRAINT chk_erp_physical_freights_window CHECK (pickup_window_end IS NULL OR pickup_window_start IS NULL OR pickup_window_end >= pickup_window_start),
    CONSTRAINT chk_erp_physical_freights_metadata CHECK (jsonb_typeof(metadata_json) = 'object')
);

CREATE TABLE IF NOT EXISTS erp_pepita_gifts (
    erp_pepita_gift_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_user_id UUID NOT NULL,
    customer_user_id UUID,
    sale_id UUID NOT NULL,
    pepita_quantity INTEGER NOT NULL,
    nominal_value_brl DECIMAL(18,4) NOT NULL,
    gift_status erp_pepita_gift_status_enum NOT NULL DEFAULT 'OFFERED',
    confirmation_required BOOLEAN NOT NULL DEFAULT FALSE,
    confirmed_by_user_id UUID,
    confirmed_at TIMESTAMPTZ,
    declined_at TIMESTAMPTZ,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_erp_pepita_gifts_merchant FOREIGN KEY (merchant_user_id) REFERENCES users(user_id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_erp_pepita_gifts_customer FOREIGN KEY (customer_user_id) REFERENCES users(user_id) ON UPDATE CASCADE ON DELETE SET NULL,
    CONSTRAINT fk_erp_pepita_gifts_sale FOREIGN KEY (sale_id) REFERENCES erp_local_sales(sale_id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_erp_pepita_gifts_confirmed_by FOREIGN KEY (confirmed_by_user_id) REFERENCES users(user_id) ON UPDATE CASCADE ON DELETE SET NULL,
    CONSTRAINT chk_erp_pepita_gifts_allowed_quantity CHECK (pepita_quantity IN (1, 10, 100)),
    CONSTRAINT chk_erp_pepita_gifts_nominal_value CHECK (
        (pepita_quantity = 1 AND nominal_value_brl = 3) OR
        (pepita_quantity = 10 AND nominal_value_brl = 30) OR
        (pepita_quantity = 100 AND nominal_value_brl = 300)
    ),
    CONSTRAINT chk_erp_pepita_gifts_high_value_confirmation CHECK (pepita_quantity <> 100 OR confirmation_required = TRUE)
);

CREATE TABLE IF NOT EXISTS erp_desktop_ota_state (
    erp_desktop_ota_state_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_user_id UUID NOT NULL,
    device_id_hash TEXT NOT NULL,
    app_version TEXT NOT NULL,
    ota_channel TEXT NOT NULL DEFAULT 'stable',
    patch_version TEXT,
    ota_status erp_desktop_ota_status_enum NOT NULL DEFAULT 'CHECKING',
    download_url TEXT,
    checksum_sha256 TEXT,
    applied_at TIMESTAMPTZ,
    failed_at TIMESTAMPTZ,
    failure_reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_erp_desktop_ota_state_merchant FOREIGN KEY (merchant_user_id) REFERENCES users(user_id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT chk_erp_desktop_ota_state_device CHECK (device_id_hash ~ '^[a-fA-F0-9]{64,128}$'),
    CONSTRAINT chk_erp_desktop_ota_state_version CHECK (btrim(app_version) <> ''),
    CONSTRAINT chk_erp_desktop_ota_state_channel CHECK (ota_channel IN ('stable', 'beta')),
    CONSTRAINT chk_erp_desktop_ota_state_url CHECK (download_url IS NULL OR download_url ~ '^https?://'),
    CONSTRAINT chk_erp_desktop_ota_state_checksum CHECK (checksum_sha256 IS NULL OR checksum_sha256 ~ '^[a-fA-F0-9]{64}$')
);

CREATE INDEX IF NOT EXISTS ix_erp_local_categories_merchant_status ON erp_local_categories (merchant_user_id, category_status, sort_order);
CREATE INDEX IF NOT EXISTS ix_erp_local_product_variants_item ON erp_local_product_variants (item_id, variant_status);
CREATE INDEX IF NOT EXISTS ix_erp_physical_stock_positions_merchant ON erp_physical_stock_positions (merchant_user_id, erp_variant_id);
CREATE INDEX IF NOT EXISTS ix_erp_physical_stock_movements_position_time ON erp_physical_stock_movements (erp_stock_position_id, created_at DESC);
CREATE INDEX IF NOT EXISTS ix_erp_local_sales_merchant_status ON erp_local_sales (merchant_user_id, sale_status, created_at DESC);
CREATE INDEX IF NOT EXISTS ix_erp_physical_freights_sale_status ON erp_physical_freights (sale_id, freight_status);
CREATE INDEX IF NOT EXISTS ix_erp_pepita_gifts_sale ON erp_pepita_gifts (sale_id, gift_status);
CREATE INDEX IF NOT EXISTS ix_erp_desktop_ota_state_device ON erp_desktop_ota_state (device_id_hash, ota_status, created_at DESC);

DROP TRIGGER IF EXISTS trg_erp_local_store_settings_updated_at ON erp_local_store_settings;
CREATE TRIGGER trg_erp_local_store_settings_updated_at BEFORE UPDATE ON erp_local_store_settings FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_erp_local_categories_updated_at ON erp_local_categories;
CREATE TRIGGER trg_erp_local_categories_updated_at BEFORE UPDATE ON erp_local_categories FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_erp_local_product_variants_updated_at ON erp_local_product_variants;
CREATE TRIGGER trg_erp_local_product_variants_updated_at BEFORE UPDATE ON erp_local_product_variants FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_erp_physical_stock_positions_updated_at ON erp_physical_stock_positions;
CREATE TRIGGER trg_erp_physical_stock_positions_updated_at BEFORE UPDATE ON erp_physical_stock_positions FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_erp_local_sales_updated_at ON erp_local_sales;
CREATE TRIGGER trg_erp_local_sales_updated_at BEFORE UPDATE ON erp_local_sales FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_erp_local_sale_items_updated_at ON erp_local_sale_items;
CREATE TRIGGER trg_erp_local_sale_items_updated_at BEFORE UPDATE ON erp_local_sale_items FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_erp_physical_freights_updated_at ON erp_physical_freights;
CREATE TRIGGER trg_erp_physical_freights_updated_at BEFORE UPDATE ON erp_physical_freights FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_erp_pepita_gifts_updated_at ON erp_pepita_gifts;
CREATE TRIGGER trg_erp_pepita_gifts_updated_at BEFORE UPDATE ON erp_pepita_gifts FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_erp_desktop_ota_state_updated_at ON erp_desktop_ota_state;
CREATE TRIGGER trg_erp_desktop_ota_state_updated_at BEFORE UPDATE ON erp_desktop_ota_state FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_erp_physical_stock_movements_prevent_update ON erp_physical_stock_movements;
CREATE TRIGGER trg_erp_physical_stock_movements_prevent_update BEFORE UPDATE ON erp_physical_stock_movements FOR EACH ROW EXECUTE FUNCTION prevent_append_only_mutation();

DROP TRIGGER IF EXISTS trg_erp_physical_stock_movements_prevent_delete ON erp_physical_stock_movements;
CREATE TRIGGER trg_erp_physical_stock_movements_prevent_delete BEFORE DELETE ON erp_physical_stock_movements FOR EACH ROW EXECUTE FUNCTION prevent_append_only_mutation();

CREATE OR REPLACE VIEW erp_merchant_allowed_product_view AS
SELECT
    v.erp_variant_id,
    v.merchant_user_id,
    v.item_id,
    v.erp_category_id,
    v.variant_sku,
    v.barcode,
    v.variant_name,
    v.brand_name,
    v.attributes_json,
    v.sale_price_brl,
    v.promotional_price_brl,
    v.variant_status,
    COALESCE(s.physical_quantity, 0) AS physical_quantity,
    COALESCE(s.reserved_quantity, 0) AS reserved_quantity,
    COALESCE(s.physical_quantity, 0) - COALESCE(s.reserved_quantity, 0) AS available_quantity,
    s.minimum_quantity,
    s.physical_location
FROM erp_local_product_variants v
LEFT JOIN erp_physical_stock_positions s ON s.erp_variant_id = v.erp_variant_id
WHERE v.local_only = TRUE;

COMMENT ON VIEW erp_merchant_allowed_product_view IS 'View segura do Valley ERP Merchant: somente produtos locais, estoque fisico e campos permitidos ao lojista.';
COMMENT ON TABLE erp_pepita_gifts IS 'Bonificacoes de pepitas do Valley ERP: 1=R$3, 10=R$30, 100=R$300 com confirmacao reforcada.';
COMMENT ON TABLE erp_local_store_settings IS 'Configuracao local do ERP desktop; impede dropshipping e marketplace externo no Merchant.';

COMMIT;
