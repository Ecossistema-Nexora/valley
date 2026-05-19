-- 037_sheet_source_of_truth_rider_mirror.sql
-- Fonte da verdade: payload gerado pelo Sheet/Stitch.
-- Escopo deste chat: Valley Rider.
-- Objetivo: preservar tudo que veio do sheet e espelhar para o APK Rider sem descarte.

BEGIN;

SET search_path = public;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'sheet_truth_status_enum') THEN
        CREATE TYPE sheet_truth_status_enum AS ENUM ('DRAFT', 'ACTIVE', 'INACTIVE', 'ARCHIVED');
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'sheet_sale_status_enum') THEN
        CREATE TYPE sheet_sale_status_enum AS ENUM ('DRAFT', 'OPEN', 'SEPARATING', 'READY_TO_SHIP', 'SHIPPED', 'COMPLETED', 'CANCELLED', 'REFUNDED');
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'sheet_freight_status_enum') THEN
        CREATE TYPE sheet_freight_status_enum AS ENUM ('DRAFT', 'CREATED', 'LABEL_PRINTED', 'COLLECTED', 'IN_TRANSIT', 'DELIVERED', 'FAILED', 'CANCELLED');
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'sheet_pepita_status_enum') THEN
        CREATE TYPE sheet_pepita_status_enum AS ENUM ('OFFERED', 'CONFIRMED', 'DECLINED', 'CANCELLED', 'REVERSED');
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'sheet_to_rider_mirror_status_enum') THEN
        CREATE TYPE sheet_to_rider_mirror_status_enum AS ENUM ('PENDING', 'MIRRORED', 'FAILED', 'SKIPPED', 'RETRY');
    END IF;
END
$$;

CREATE TABLE IF NOT EXISTS sheet_source_documents (
    sheet_source_document_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_key TEXT NOT NULL UNIQUE,
    source_name TEXT NOT NULL,
    source_kind TEXT NOT NULL DEFAULT 'STITCH_SHEET_PAYLOAD',
    source_hash_sha256 TEXT,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    payload_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_sheet_source_documents_key CHECK (btrim(source_key) <> ''),
    CONSTRAINT chk_sheet_source_documents_name CHECK (btrim(source_name) <> ''),
    CONSTRAINT chk_sheet_source_documents_kind CHECK (btrim(source_kind) <> ''),
    CONSTRAINT chk_sheet_source_documents_hash CHECK (source_hash_sha256 IS NULL OR source_hash_sha256 ~ '^[a-fA-F0-9]{64}$'),
    CONSTRAINT chk_sheet_source_documents_payload CHECK (jsonb_typeof(payload_json) = 'object')
);

CREATE TABLE IF NOT EXISTS sheet_local_stores (
    sheet_store_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sheet_source_document_id UUID NOT NULL,
    merchant_user_id UUID NOT NULL,
    store_name TEXT NOT NULL,
    store_status sheet_truth_status_enum NOT NULL DEFAULT 'ACTIVE',
    local_only BOOLEAN NOT NULL DEFAULT TRUE,
    allow_external_marketplaces BOOLEAN NOT NULL DEFAULT FALSE,
    allow_dropshipping BOOLEAN NOT NULL DEFAULT FALSE,
    desktop_target TEXT NOT NULL DEFAULT 'WINDOWS_EXE',
    ota_channel TEXT NOT NULL DEFAULT 'stable',
    print_preferences_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    notification_preferences_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_sheet_local_stores_source FOREIGN KEY (sheet_source_document_id) REFERENCES sheet_source_documents(sheet_source_document_id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_sheet_local_stores_merchant FOREIGN KEY (merchant_user_id) REFERENCES users(user_id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT uq_sheet_local_stores_merchant UNIQUE (merchant_user_id),
    CONSTRAINT chk_sheet_local_stores_name CHECK (btrim(store_name) <> ''),
    CONSTRAINT chk_sheet_local_stores_local CHECK (local_only = TRUE),
    CONSTRAINT chk_sheet_local_stores_marketplace CHECK (allow_external_marketplaces = FALSE),
    CONSTRAINT chk_sheet_local_stores_dropship CHECK (allow_dropshipping = FALSE),
    CONSTRAINT chk_sheet_local_stores_ota CHECK (ota_channel IN ('stable', 'beta')),
    CONSTRAINT chk_sheet_local_stores_print_json CHECK (jsonb_typeof(print_preferences_json) = 'object'),
    CONSTRAINT chk_sheet_local_stores_notification_json CHECK (jsonb_typeof(notification_preferences_json) = 'object'),
    CONSTRAINT chk_sheet_local_stores_metadata_json CHECK (jsonb_typeof(metadata_json) = 'object')
);

CREATE TABLE IF NOT EXISTS sheet_local_categories (
    sheet_category_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sheet_source_document_id UUID NOT NULL,
    merchant_user_id UUID NOT NULL,
    parent_category_id UUID,
    category_code TEXT NOT NULL,
    category_name TEXT NOT NULL,
    category_status sheet_truth_status_enum NOT NULL DEFAULT 'ACTIVE',
    sort_order INTEGER NOT NULL DEFAULT 0,
    local_only BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_sheet_local_categories_source FOREIGN KEY (sheet_source_document_id) REFERENCES sheet_source_documents(sheet_source_document_id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_sheet_local_categories_merchant FOREIGN KEY (merchant_user_id) REFERENCES users(user_id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_sheet_local_categories_parent FOREIGN KEY (parent_category_id) REFERENCES sheet_local_categories(sheet_category_id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT uq_sheet_local_categories_code UNIQUE (merchant_user_id, category_code),
    CONSTRAINT chk_sheet_local_categories_code CHECK (btrim(category_code) <> ''),
    CONSTRAINT chk_sheet_local_categories_name CHECK (btrim(category_name) <> ''),
    CONSTRAINT chk_sheet_local_categories_local CHECK (local_only = TRUE)
);

CREATE TABLE IF NOT EXISTS sheet_product_variants (
    sheet_variant_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sheet_source_document_id UUID NOT NULL,
    merchant_user_id UUID NOT NULL,
    inventory_item_id UUID,
    sheet_category_id UUID,
    variant_sku TEXT NOT NULL,
    barcode TEXT,
    variant_name TEXT NOT NULL,
    brand_name TEXT,
    attributes_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    sale_price_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    cost_price_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    promotional_price_brl DECIMAL(18,4),
    variant_status sheet_truth_status_enum NOT NULL DEFAULT 'ACTIVE',
    local_only BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_sheet_product_variants_source FOREIGN KEY (sheet_source_document_id) REFERENCES sheet_source_documents(sheet_source_document_id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_sheet_product_variants_merchant FOREIGN KEY (merchant_user_id) REFERENCES users(user_id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_sheet_product_variants_item FOREIGN KEY (inventory_item_id) REFERENCES inventory_items(item_id) ON UPDATE CASCADE ON DELETE SET NULL,
    CONSTRAINT fk_sheet_product_variants_category FOREIGN KEY (sheet_category_id) REFERENCES sheet_local_categories(sheet_category_id) ON UPDATE CASCADE ON DELETE SET NULL,
    CONSTRAINT uq_sheet_product_variants_sku UNIQUE (merchant_user_id, variant_sku),
    CONSTRAINT chk_sheet_product_variants_sku CHECK (btrim(variant_sku) <> ''),
    CONSTRAINT chk_sheet_product_variants_name CHECK (btrim(variant_name) <> ''),
    CONSTRAINT chk_sheet_product_variants_prices CHECK (sale_price_brl >= 0 AND cost_price_brl >= 0 AND (promotional_price_brl IS NULL OR promotional_price_brl >= 0)),
    CONSTRAINT chk_sheet_product_variants_attrs CHECK (jsonb_typeof(attributes_json) = 'object'),
    CONSTRAINT chk_sheet_product_variants_local CHECK (local_only = TRUE)
);

CREATE TABLE IF NOT EXISTS sheet_physical_stock_positions (
    sheet_stock_position_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sheet_source_document_id UUID NOT NULL,
    merchant_user_id UUID NOT NULL,
    sheet_variant_id UUID NOT NULL,
    warehouse_id UUID,
    physical_location TEXT,
    physical_quantity DECIMAL(18,4) NOT NULL DEFAULT 0,
    reserved_quantity DECIMAL(18,4) NOT NULL DEFAULT 0,
    minimum_quantity DECIMAL(18,4) NOT NULL DEFAULT 0,
    last_counted_at TIMESTAMPTZ,
    local_only BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_sheet_physical_stock_positions_source FOREIGN KEY (sheet_source_document_id) REFERENCES sheet_source_documents(sheet_source_document_id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_sheet_physical_stock_positions_merchant FOREIGN KEY (merchant_user_id) REFERENCES users(user_id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_sheet_physical_stock_positions_variant FOREIGN KEY (sheet_variant_id) REFERENCES sheet_product_variants(sheet_variant_id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_sheet_physical_stock_positions_warehouse FOREIGN KEY (warehouse_id) REFERENCES warehouses(warehouse_id) ON UPDATE CASCADE ON DELETE SET NULL,
    CONSTRAINT uq_sheet_physical_stock_position UNIQUE (merchant_user_id, sheet_variant_id, physical_location),
    CONSTRAINT chk_sheet_physical_stock_positions_quantities CHECK (physical_quantity >= 0 AND reserved_quantity >= 0 AND minimum_quantity >= 0 AND reserved_quantity <= physical_quantity),
    CONSTRAINT chk_sheet_physical_stock_positions_local CHECK (local_only = TRUE)
);

CREATE TABLE IF NOT EXISTS sheet_sales (
    sheet_sale_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sheet_source_document_id UUID NOT NULL,
    merchant_user_id UUID NOT NULL,
    customer_user_id UUID,
    linked_order_id UUID,
    sale_number TEXT NOT NULL,
    sale_status sheet_sale_status_enum NOT NULL DEFAULT 'OPEN',
    subtotal_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    discount_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    freight_charged_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    total_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    payment_status TEXT NOT NULL DEFAULT 'PENDING',
    completed_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,
    cancellation_reason TEXT,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_sheet_sales_source FOREIGN KEY (sheet_source_document_id) REFERENCES sheet_source_documents(sheet_source_document_id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_sheet_sales_merchant FOREIGN KEY (merchant_user_id) REFERENCES users(user_id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_sheet_sales_customer FOREIGN KEY (customer_user_id) REFERENCES users(user_id) ON UPDATE CASCADE ON DELETE SET NULL,
    CONSTRAINT fk_sheet_sales_order FOREIGN KEY (linked_order_id) REFERENCES orders(order_id) ON UPDATE CASCADE ON DELETE SET NULL,
    CONSTRAINT uq_sheet_sales_number UNIQUE (merchant_user_id, sale_number),
    CONSTRAINT chk_sheet_sales_number CHECK (btrim(sale_number) <> ''),
    CONSTRAINT chk_sheet_sales_amounts CHECK (subtotal_brl >= 0 AND discount_brl >= 0 AND freight_charged_brl >= 0 AND total_brl >= 0),
    CONSTRAINT chk_sheet_sales_metadata CHECK (jsonb_typeof(metadata_json) = 'object')
);

CREATE TABLE IF NOT EXISTS sheet_sale_items (
    sheet_sale_item_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sheet_sale_id UUID NOT NULL,
    merchant_user_id UUID NOT NULL,
    sheet_variant_id UUID NOT NULL,
    quantity DECIMAL(18,4) NOT NULL,
    unit_price_brl DECIMAL(18,4) NOT NULL,
    line_discount_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    line_total_brl DECIMAL(18,4) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_sheet_sale_items_sale FOREIGN KEY (sheet_sale_id) REFERENCES sheet_sales(sheet_sale_id) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_sheet_sale_items_merchant FOREIGN KEY (merchant_user_id) REFERENCES users(user_id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_sheet_sale_items_variant FOREIGN KEY (sheet_variant_id) REFERENCES sheet_product_variants(sheet_variant_id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT chk_sheet_sale_items_amounts CHECK (quantity > 0 AND unit_price_brl >= 0 AND line_discount_brl >= 0 AND line_total_brl >= 0)
);

CREATE TABLE IF NOT EXISTS sheet_physical_freights (
    sheet_freight_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sheet_source_document_id UUID NOT NULL,
    merchant_user_id UUID NOT NULL,
    sheet_sale_id UUID NOT NULL,
    linked_shipment_id UUID,
    carrier_name TEXT,
    service_name TEXT,
    pickup_window_start TIMESTAMPTZ,
    pickup_window_end TIMESTAMPTZ,
    tracking_code TEXT,
    declared_value_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    merchant_freight_cost_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    customer_freight_charge_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    freight_status sheet_freight_status_enum NOT NULL DEFAULT 'DRAFT',
    label_document_id UUID,
    proof_document_id UUID,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_sheet_physical_freights_source FOREIGN KEY (sheet_source_document_id) REFERENCES sheet_source_documents(sheet_source_document_id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_sheet_physical_freights_merchant FOREIGN KEY (merchant_user_id) REFERENCES users(user_id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_sheet_physical_freights_sale FOREIGN KEY (sheet_sale_id) REFERENCES sheet_sales(sheet_sale_id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_sheet_physical_freights_shipment FOREIGN KEY (linked_shipment_id) REFERENCES delivery_shipments(shipment_id) ON UPDATE CASCADE ON DELETE SET NULL,
    CONSTRAINT fk_sheet_physical_freights_label_doc FOREIGN KEY (label_document_id) REFERENCES document_records(document_id) ON UPDATE CASCADE ON DELETE SET NULL,
    CONSTRAINT fk_sheet_physical_freights_proof_doc FOREIGN KEY (proof_document_id) REFERENCES document_records(document_id) ON UPDATE CASCADE ON DELETE SET NULL,
    CONSTRAINT chk_sheet_physical_freights_amounts CHECK (declared_value_brl >= 0 AND merchant_freight_cost_brl >= 0 AND customer_freight_charge_brl >= 0),
    CONSTRAINT chk_sheet_physical_freights_window CHECK (pickup_window_end IS NULL OR pickup_window_start IS NULL OR pickup_window_end >= pickup_window_start),
    CONSTRAINT chk_sheet_physical_freights_metadata CHECK (jsonb_typeof(metadata_json) = 'object')
);

CREATE TABLE IF NOT EXISTS sheet_pepita_gifts (
    sheet_pepita_gift_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sheet_source_document_id UUID NOT NULL,
    merchant_user_id UUID NOT NULL,
    customer_user_id UUID,
    sheet_sale_id UUID NOT NULL,
    pepita_quantity INTEGER NOT NULL,
    nominal_value_brl DECIMAL(18,4) NOT NULL,
    gift_status sheet_pepita_status_enum NOT NULL DEFAULT 'OFFERED',
    confirmation_required BOOLEAN NOT NULL DEFAULT FALSE,
    confirmed_by_user_id UUID,
    confirmed_at TIMESTAMPTZ,
    declined_at TIMESTAMPTZ,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_sheet_pepita_gifts_source FOREIGN KEY (sheet_source_document_id) REFERENCES sheet_source_documents(sheet_source_document_id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_sheet_pepita_gifts_merchant FOREIGN KEY (merchant_user_id) REFERENCES users(user_id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_sheet_pepita_gifts_customer FOREIGN KEY (customer_user_id) REFERENCES users(user_id) ON UPDATE CASCADE ON DELETE SET NULL,
    CONSTRAINT fk_sheet_pepita_gifts_sale FOREIGN KEY (sheet_sale_id) REFERENCES sheet_sales(sheet_sale_id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_sheet_pepita_gifts_confirmed_by FOREIGN KEY (confirmed_by_user_id) REFERENCES users(user_id) ON UPDATE CASCADE ON DELETE SET NULL,
    CONSTRAINT chk_sheet_pepita_gifts_quantity CHECK (pepita_quantity IN (1, 10, 100)),
    CONSTRAINT chk_sheet_pepita_gifts_value CHECK ((pepita_quantity = 1 AND nominal_value_brl = 3) OR (pepita_quantity = 10 AND nominal_value_brl = 30) OR (pepita_quantity = 100 AND nominal_value_brl = 300)),
    CONSTRAINT chk_sheet_pepita_gifts_100_confirmation CHECK (pepita_quantity <> 100 OR confirmation_required = TRUE)
);

CREATE TABLE IF NOT EXISTS sheet_to_rider_mirror_jobs (
    sheet_to_rider_mirror_job_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sheet_source_document_id UUID NOT NULL,
    sheet_sale_id UUID,
    sheet_freight_id UUID,
    order_id UUID,
    shipment_id UUID,
    mirror_status sheet_to_rider_mirror_status_enum NOT NULL DEFAULT 'PENDING',
    attempts INTEGER NOT NULL DEFAULT 0,
    last_error TEXT,
    mirrored_at TIMESTAMPTZ,
    payload_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_sheet_to_rider_mirror_jobs_source FOREIGN KEY (sheet_source_document_id) REFERENCES sheet_source_documents(sheet_source_document_id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_sheet_to_rider_mirror_jobs_sale FOREIGN KEY (sheet_sale_id) REFERENCES sheet_sales(sheet_sale_id) ON UPDATE CASCADE ON DELETE SET NULL,
    CONSTRAINT fk_sheet_to_rider_mirror_jobs_freight FOREIGN KEY (sheet_freight_id) REFERENCES sheet_physical_freights(sheet_freight_id) ON UPDATE CASCADE ON DELETE SET NULL,
    CONSTRAINT fk_sheet_to_rider_mirror_jobs_order FOREIGN KEY (order_id) REFERENCES orders(order_id) ON UPDATE CASCADE ON DELETE SET NULL,
    CONSTRAINT fk_sheet_to_rider_mirror_jobs_shipment FOREIGN KEY (shipment_id) REFERENCES delivery_shipments(shipment_id) ON UPDATE CASCADE ON DELETE SET NULL,
    CONSTRAINT chk_sheet_to_rider_mirror_jobs_anchor CHECK (sheet_sale_id IS NOT NULL OR sheet_freight_id IS NOT NULL),
    CONSTRAINT chk_sheet_to_rider_mirror_jobs_attempts CHECK (attempts >= 0),
    CONSTRAINT chk_sheet_to_rider_mirror_jobs_payload CHECK (jsonb_typeof(payload_json) = 'object')
);

CREATE INDEX IF NOT EXISTS ix_sheet_local_categories_merchant ON sheet_local_categories (merchant_user_id, category_status, sort_order);
CREATE INDEX IF NOT EXISTS ix_sheet_product_variants_merchant ON sheet_product_variants (merchant_user_id, variant_status, variant_sku);
CREATE INDEX IF NOT EXISTS ix_sheet_physical_stock_positions_variant ON sheet_physical_stock_positions (sheet_variant_id, physical_location);
CREATE INDEX IF NOT EXISTS ix_sheet_sales_merchant_status ON sheet_sales (merchant_user_id, sale_status, created_at DESC);
CREATE INDEX IF NOT EXISTS ix_sheet_physical_freights_status ON sheet_physical_freights (merchant_user_id, freight_status, created_at DESC);
CREATE INDEX IF NOT EXISTS ix_sheet_pepita_gifts_sale ON sheet_pepita_gifts (sheet_sale_id, gift_status);
CREATE INDEX IF NOT EXISTS ix_sheet_to_rider_mirror_jobs_status ON sheet_to_rider_mirror_jobs (mirror_status, created_at DESC);

DROP TRIGGER IF EXISTS trg_sheet_source_documents_updated_at ON sheet_source_documents;
CREATE TRIGGER trg_sheet_source_documents_updated_at BEFORE UPDATE ON sheet_source_documents FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_sheet_local_stores_updated_at ON sheet_local_stores;
CREATE TRIGGER trg_sheet_local_stores_updated_at BEFORE UPDATE ON sheet_local_stores FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_sheet_local_categories_updated_at ON sheet_local_categories;
CREATE TRIGGER trg_sheet_local_categories_updated_at BEFORE UPDATE ON sheet_local_categories FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_sheet_product_variants_updated_at ON sheet_product_variants;
CREATE TRIGGER trg_sheet_product_variants_updated_at BEFORE UPDATE ON sheet_product_variants FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_sheet_physical_stock_positions_updated_at ON sheet_physical_stock_positions;
CREATE TRIGGER trg_sheet_physical_stock_positions_updated_at BEFORE UPDATE ON sheet_physical_stock_positions FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_sheet_sales_updated_at ON sheet_sales;
CREATE TRIGGER trg_sheet_sales_updated_at BEFORE UPDATE ON sheet_sales FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_sheet_sale_items_updated_at ON sheet_sale_items;
CREATE TRIGGER trg_sheet_sale_items_updated_at BEFORE UPDATE ON sheet_sale_items FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_sheet_physical_freights_updated_at ON sheet_physical_freights;
CREATE TRIGGER trg_sheet_physical_freights_updated_at BEFORE UPDATE ON sheet_physical_freights FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_sheet_pepita_gifts_updated_at ON sheet_pepita_gifts;
CREATE TRIGGER trg_sheet_pepita_gifts_updated_at BEFORE UPDATE ON sheet_pepita_gifts FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_sheet_to_rider_mirror_jobs_updated_at ON sheet_to_rider_mirror_jobs;
CREATE TRIGGER trg_sheet_to_rider_mirror_jobs_updated_at BEFORE UPDATE ON sheet_to_rider_mirror_jobs FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE OR REPLACE VIEW sheet_rider_delivery_truth_view AS
SELECT
    f.sheet_freight_id,
    f.sheet_sale_id,
    f.linked_shipment_id,
    s.linked_order_id,
    f.merchant_user_id,
    s.customer_user_id,
    s.sale_number,
    f.carrier_name,
    f.service_name,
    f.tracking_code,
    f.freight_status,
    f.declared_value_brl,
    f.customer_freight_charge_brl,
    f.pickup_window_start,
    f.pickup_window_end,
    s.total_brl,
    s.payment_status,
    s.metadata_json AS sale_metadata_json,
    f.metadata_json AS freight_metadata_json,
    f.created_at,
    f.updated_at
FROM sheet_physical_freights f
JOIN sheet_sales s ON s.sheet_sale_id = f.sheet_sale_id;

CREATE OR REPLACE VIEW sheet_rider_pepita_truth_view AS
SELECT
    g.sheet_pepita_gift_id,
    g.sheet_sale_id,
    s.linked_order_id,
    g.merchant_user_id,
    g.customer_user_id,
    g.pepita_quantity,
    g.nominal_value_brl,
    g.gift_status,
    g.confirmation_required,
    g.confirmed_at,
    g.created_at,
    g.updated_at
FROM sheet_pepita_gifts g
JOIN sheet_sales s ON s.sheet_sale_id = g.sheet_sale_id;

COMMENT ON TABLE sheet_source_documents IS 'Registro canônico dos arquivos/payloads Sheet/Stitch. Esta é a fonte da verdade importada.';
COMMENT ON TABLE sheet_to_rider_mirror_jobs IS 'Fila de espelhamento do sheet para orders/delivery_shipments consumidos pelo APK Rider.';
COMMENT ON VIEW sheet_rider_delivery_truth_view IS 'View canônica para o APK Rider consultar entregas originadas do sheet sem descartar metadados.';
COMMENT ON VIEW sheet_rider_pepita_truth_view IS 'View canônica de pepitas originadas do sheet, vinculável ao pós-entrega.';

COMMIT;
