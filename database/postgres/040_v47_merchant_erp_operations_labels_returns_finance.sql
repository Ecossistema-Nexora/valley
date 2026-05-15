-- ERP Lojista v057: operacoes comuns de varejo, etiquetas, variantes, kits, inventario, retornos e financeiro.
-- A migration e aditiva, mantem isolamento por lojista/filial e nao expoe regras internas de recompensa ao front do lojista.

ALTER TYPE merchant_erp_role_enum ADD VALUE IF NOT EXISTS 'LABEL_OPERATOR';
ALTER TYPE merchant_erp_role_enum ADD VALUE IF NOT EXISTS 'RETURNS_OPERATOR';

BEGIN;

SET search_path = public;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'merchant_erp_label_barcode_type_enum') THEN
        CREATE TYPE merchant_erp_label_barcode_type_enum AS ENUM (
            'QR_CODE',
            'EAN13',
            'BOTH'
        );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'merchant_erp_label_job_type_enum') THEN
        CREATE TYPE merchant_erp_label_job_type_enum AS ENUM (
            'PRODUCT_IDENTIFICATION',
            'PRICE_TAG',
            'STOCK_RECEIVING',
            'SHELF_LOCATION',
            'PICKING',
            'SHIPPING',
            'BRANCH_TRANSFER',
            'INVENTORY_COUNT'
        );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'merchant_erp_return_status_enum') THEN
        CREATE TYPE merchant_erp_return_status_enum AS ENUM (
            'REQUESTED',
            'AUTHORIZED',
            'RECEIVED',
            'INSPECTED',
            'REFUNDED',
            'REJECTED',
            'CANCELLED'
        );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'merchant_erp_finance_entry_type_enum') THEN
        CREATE TYPE merchant_erp_finance_entry_type_enum AS ENUM (
            'PAYABLE',
            'RECEIVABLE',
            'EXPENSE',
            'RECEIPT',
            'REFUND',
            'ADJUSTMENT'
        );
    END IF;
END
$$;

ALTER TABLE merchant_erp_product_lifecycle_events
    DROP CONSTRAINT IF EXISTS chk_merchant_erp_product_events_action;

ALTER TABLE merchant_erp_product_lifecycle_events
    ADD CONSTRAINT chk_merchant_erp_product_events_action CHECK (
        action_key IN (
            'create',
            'edit',
            'delete',
            'delete_soft',
            'suspend',
            'restore',
            'publish',
            'unpublish',
            'price_update',
            'stock_update',
            'category_update',
            'bulk_branch_sync',
            'variant_create',
            'variant_update',
            'variant_delete',
            'kit_create',
            'kit_update',
            'kit_delete',
            'label_generate'
        )
    );

CREATE TABLE IF NOT EXISTS merchant_erp_product_variants (
    merchant_erp_product_variant_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_user_id UUID NOT NULL,
    branch_id UUID,
    item_id UUID,
    parent_sku TEXT NOT NULL,
    variant_sku TEXT NOT NULL,
    attribute_name TEXT NOT NULL,
    attribute_value TEXT NOT NULL,
    ean13 TEXT,
    variant_status merchant_erp_status_enum NOT NULL DEFAULT 'ACTIVE',
    price_delta_brl NUMERIC(18,4) NOT NULL DEFAULT 0,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    created_by UUID,
    CONSTRAINT fk_merchant_erp_product_variants_merchant
        FOREIGN KEY (merchant_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_merchant_erp_product_variants_branch
        FOREIGN KEY (branch_id) REFERENCES merchant_erp_branch_units (merchant_erp_branch_unit_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_merchant_erp_product_variants_item
        FOREIGN KEY (item_id) REFERENCES inventory_items (item_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_merchant_erp_product_variants_created_by
        FOREIGN KEY (created_by) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT ux_merchant_erp_product_variants_sku UNIQUE (merchant_user_id, variant_sku),
    CONSTRAINT chk_merchant_erp_product_variants_sku CHECK (btrim(parent_sku) <> '' AND btrim(variant_sku) <> ''),
    CONSTRAINT chk_merchant_erp_product_variants_attr CHECK (btrim(attribute_name) <> '' AND btrim(attribute_value) <> ''),
    CONSTRAINT chk_merchant_erp_product_variants_ean13 CHECK (ean13 IS NULL OR ean13 ~ '^[0-9]{13}$'),
    CONSTRAINT chk_merchant_erp_product_variants_metadata CHECK (jsonb_typeof(metadata_json) = 'object')
);

CREATE TABLE IF NOT EXISTS merchant_erp_product_kits (
    merchant_erp_product_kit_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_user_id UUID NOT NULL,
    branch_id UUID,
    kit_sku TEXT NOT NULL,
    kit_name TEXT NOT NULL,
    kit_status merchant_erp_status_enum NOT NULL DEFAULT 'ACTIVE',
    promotional_price_brl NUMERIC(18,4),
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    created_by UUID,
    CONSTRAINT fk_merchant_erp_product_kits_merchant
        FOREIGN KEY (merchant_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_merchant_erp_product_kits_branch
        FOREIGN KEY (branch_id) REFERENCES merchant_erp_branch_units (merchant_erp_branch_unit_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_merchant_erp_product_kits_created_by
        FOREIGN KEY (created_by) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT ux_merchant_erp_product_kits_sku UNIQUE (merchant_user_id, kit_sku),
    CONSTRAINT chk_merchant_erp_product_kits_text CHECK (btrim(kit_sku) <> '' AND btrim(kit_name) <> ''),
    CONSTRAINT chk_merchant_erp_product_kits_price CHECK (promotional_price_brl IS NULL OR promotional_price_brl >= 0),
    CONSTRAINT chk_merchant_erp_product_kits_metadata CHECK (jsonb_typeof(metadata_json) = 'object')
);

CREATE TABLE IF NOT EXISTS merchant_erp_product_kit_items (
    merchant_erp_product_kit_item_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_user_id UUID NOT NULL,
    kit_id UUID NOT NULL,
    item_id UUID,
    sku TEXT NOT NULL,
    quantity NUMERIC(18,4) NOT NULL DEFAULT 1,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID,
    CONSTRAINT fk_merchant_erp_kit_items_merchant
        FOREIGN KEY (merchant_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_merchant_erp_kit_items_kit
        FOREIGN KEY (kit_id) REFERENCES merchant_erp_product_kits (merchant_erp_product_kit_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT fk_merchant_erp_kit_items_item
        FOREIGN KEY (item_id) REFERENCES inventory_items (item_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_merchant_erp_kit_items_created_by
        FOREIGN KEY (created_by) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT chk_merchant_erp_kit_items_sku CHECK (btrim(sku) <> ''),
    CONSTRAINT chk_merchant_erp_kit_items_qty CHECK (quantity > 0),
    CONSTRAINT chk_merchant_erp_kit_items_metadata CHECK (jsonb_typeof(metadata_json) = 'object')
);

CREATE TABLE IF NOT EXISTS merchant_erp_label_templates (
    merchant_erp_label_template_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_user_id UUID NOT NULL,
    branch_id UUID,
    template_key TEXT NOT NULL,
    display_name TEXT NOT NULL,
    job_type merchant_erp_label_job_type_enum NOT NULL,
    barcode_type merchant_erp_label_barcode_type_enum NOT NULL DEFAULT 'QR_CODE',
    paper_format TEXT NOT NULL DEFAULT 'A4_3x10',
    template_config_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    template_status merchant_erp_status_enum NOT NULL DEFAULT 'ACTIVE',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    created_by UUID,
    CONSTRAINT fk_merchant_erp_label_templates_merchant
        FOREIGN KEY (merchant_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_merchant_erp_label_templates_branch
        FOREIGN KEY (branch_id) REFERENCES merchant_erp_branch_units (merchant_erp_branch_unit_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_merchant_erp_label_templates_created_by
        FOREIGN KEY (created_by) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT ux_merchant_erp_label_templates_key UNIQUE (merchant_user_id, template_key),
    CONSTRAINT chk_merchant_erp_label_templates_key CHECK (template_key ~ '^[a-z0-9_-]{2,80}$'),
    CONSTRAINT chk_merchant_erp_label_templates_display CHECK (btrim(display_name) <> ''),
    CONSTRAINT chk_merchant_erp_label_templates_json CHECK (jsonb_typeof(template_config_json) = 'object')
);

CREATE TABLE IF NOT EXISTS merchant_erp_label_jobs (
    merchant_erp_label_job_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_user_id UUID NOT NULL,
    branch_id UUID,
    template_id UUID,
    job_type merchant_erp_label_job_type_enum NOT NULL,
    barcode_type merchant_erp_label_barcode_type_enum NOT NULL DEFAULT 'QR_CODE',
    labels_total INTEGER NOT NULL DEFAULT 0,
    job_status merchant_erp_task_status_enum NOT NULL DEFAULT 'DONE',
    print_payload_hash TEXT NOT NULL,
    payload_summary_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    created_by UUID,
    CONSTRAINT fk_merchant_erp_label_jobs_merchant
        FOREIGN KEY (merchant_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_merchant_erp_label_jobs_branch
        FOREIGN KEY (branch_id) REFERENCES merchant_erp_branch_units (merchant_erp_branch_unit_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_merchant_erp_label_jobs_template
        FOREIGN KEY (template_id) REFERENCES merchant_erp_label_templates (merchant_erp_label_template_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_merchant_erp_label_jobs_created_by
        FOREIGN KEY (created_by) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT chk_merchant_erp_label_jobs_total CHECK (labels_total >= 0),
    CONSTRAINT chk_merchant_erp_label_jobs_hash CHECK (print_payload_hash ~ '^[a-f0-9]{64}$'),
    CONSTRAINT chk_merchant_erp_label_jobs_json CHECK (jsonb_typeof(payload_summary_json) = 'object')
);

CREATE TABLE IF NOT EXISTS merchant_erp_label_job_items (
    merchant_erp_label_job_item_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_user_id UUID NOT NULL,
    label_job_id UUID NOT NULL,
    item_id UUID,
    sku TEXT NOT NULL,
    item_title TEXT NOT NULL,
    ean13 TEXT,
    qr_payload TEXT,
    quantity NUMERIC(18,4) NOT NULL DEFAULT 1,
    lot_code TEXT,
    expires_at DATE,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID,
    CONSTRAINT fk_merchant_erp_label_items_merchant
        FOREIGN KEY (merchant_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_merchant_erp_label_items_job
        FOREIGN KEY (label_job_id) REFERENCES merchant_erp_label_jobs (merchant_erp_label_job_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT fk_merchant_erp_label_items_item
        FOREIGN KEY (item_id) REFERENCES inventory_items (item_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_merchant_erp_label_items_created_by
        FOREIGN KEY (created_by) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT chk_merchant_erp_label_items_text CHECK (btrim(sku) <> '' AND btrim(item_title) <> ''),
    CONSTRAINT chk_merchant_erp_label_items_ean13 CHECK (ean13 IS NULL OR ean13 ~ '^[0-9]{13}$'),
    CONSTRAINT chk_merchant_erp_label_items_qty CHECK (quantity > 0),
    CONSTRAINT chk_merchant_erp_label_items_metadata CHECK (jsonb_typeof(metadata_json) = 'object')
);

CREATE TABLE IF NOT EXISTS merchant_erp_inventory_alert_rules (
    merchant_erp_inventory_alert_rule_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_user_id UUID NOT NULL,
    branch_id UUID,
    item_id UUID,
    sku TEXT,
    minimum_alert_level NUMERIC(18,4) NOT NULL DEFAULT 0,
    maximum_alert_level NUMERIC(18,4),
    reorder_quantity NUMERIC(18,4),
    rule_status merchant_erp_status_enum NOT NULL DEFAULT 'ACTIVE',
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    created_by UUID,
    CONSTRAINT fk_merchant_erp_inventory_alerts_merchant
        FOREIGN KEY (merchant_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_merchant_erp_inventory_alerts_branch
        FOREIGN KEY (branch_id) REFERENCES merchant_erp_branch_units (merchant_erp_branch_unit_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_merchant_erp_inventory_alerts_item
        FOREIGN KEY (item_id) REFERENCES inventory_items (item_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT chk_merchant_erp_inventory_alerts_levels CHECK (
        minimum_alert_level >= 0
        AND (maximum_alert_level IS NULL OR maximum_alert_level >= minimum_alert_level)
        AND (reorder_quantity IS NULL OR reorder_quantity > 0)
    ),
    CONSTRAINT chk_merchant_erp_inventory_alerts_metadata CHECK (jsonb_typeof(metadata_json) = 'object')
);

CREATE TABLE IF NOT EXISTS merchant_erp_cycle_count_jobs (
    merchant_erp_cycle_count_job_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_user_id UUID NOT NULL,
    branch_id UUID,
    count_code TEXT NOT NULL,
    count_status merchant_erp_task_status_enum NOT NULL DEFAULT 'OPEN',
    blind_count BOOLEAN NOT NULL DEFAULT TRUE,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    created_by UUID,
    CONSTRAINT fk_merchant_erp_cycle_counts_merchant
        FOREIGN KEY (merchant_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_merchant_erp_cycle_counts_branch
        FOREIGN KEY (branch_id) REFERENCES merchant_erp_branch_units (merchant_erp_branch_unit_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT ux_merchant_erp_cycle_counts_code UNIQUE (merchant_user_id, count_code),
    CONSTRAINT chk_merchant_erp_cycle_counts_code CHECK (count_code ~ '^[A-Z0-9_-]{2,80}$'),
    CONSTRAINT chk_merchant_erp_cycle_counts_metadata CHECK (jsonb_typeof(metadata_json) = 'object')
);

CREATE TABLE IF NOT EXISTS merchant_erp_cycle_count_items (
    merchant_erp_cycle_count_item_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_user_id UUID NOT NULL,
    cycle_count_job_id UUID NOT NULL,
    item_id UUID,
    sku TEXT NOT NULL,
    expected_quantity NUMERIC(18,4),
    counted_quantity NUMERIC(18,4),
    divergence_quantity NUMERIC(18,4),
    adjustment_movement_id UUID,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID,
    CONSTRAINT fk_merchant_erp_cycle_count_items_merchant
        FOREIGN KEY (merchant_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_merchant_erp_cycle_count_items_job
        FOREIGN KEY (cycle_count_job_id) REFERENCES merchant_erp_cycle_count_jobs (merchant_erp_cycle_count_job_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT fk_merchant_erp_cycle_count_items_item
        FOREIGN KEY (item_id) REFERENCES inventory_items (item_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_merchant_erp_cycle_count_items_adjustment
        FOREIGN KEY (adjustment_movement_id) REFERENCES inventory_movements (movement_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT chk_merchant_erp_cycle_count_items_sku CHECK (btrim(sku) <> ''),
    CONSTRAINT chk_merchant_erp_cycle_count_items_qty CHECK (
        (expected_quantity IS NULL OR expected_quantity >= 0)
        AND (counted_quantity IS NULL OR counted_quantity >= 0)
    ),
    CONSTRAINT chk_merchant_erp_cycle_count_items_metadata CHECK (jsonb_typeof(metadata_json) = 'object')
);

CREATE TABLE IF NOT EXISTS merchant_erp_return_authorizations (
    merchant_erp_return_authorization_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_user_id UUID NOT NULL,
    branch_id UUID,
    order_id UUID,
    order_pipeline_id UUID,
    customer_user_id UUID,
    return_code TEXT NOT NULL,
    return_status merchant_erp_return_status_enum NOT NULL DEFAULT 'REQUESTED',
    reason_code TEXT NOT NULL DEFAULT 'customer_request',
    refund_amount_brl NUMERIC(18,4) NOT NULL DEFAULT 0,
    internal_reward_adjustment NUMERIC(18,8) NOT NULL DEFAULT 0,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    created_by UUID,
    CONSTRAINT fk_merchant_erp_returns_merchant
        FOREIGN KEY (merchant_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_merchant_erp_returns_branch
        FOREIGN KEY (branch_id) REFERENCES merchant_erp_branch_units (merchant_erp_branch_unit_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_merchant_erp_returns_order
        FOREIGN KEY (order_id) REFERENCES orders (order_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_merchant_erp_returns_pipeline
        FOREIGN KEY (order_pipeline_id) REFERENCES merchant_erp_order_pipeline (merchant_erp_order_pipeline_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_merchant_erp_returns_customer
        FOREIGN KEY (customer_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT ux_merchant_erp_returns_code UNIQUE (merchant_user_id, return_code),
    CONSTRAINT chk_merchant_erp_returns_code CHECK (return_code ~ '^[A-Z0-9_-]{2,80}$'),
    CONSTRAINT chk_merchant_erp_returns_amount CHECK (refund_amount_brl >= 0),
    CONSTRAINT chk_merchant_erp_returns_metadata CHECK (jsonb_typeof(metadata_json) = 'object')
);

CREATE TABLE IF NOT EXISTS merchant_erp_finance_entries (
    merchant_erp_finance_entry_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_user_id UUID NOT NULL,
    branch_id UUID,
    order_id UUID,
    entry_type merchant_erp_finance_entry_type_enum NOT NULL,
    category_key TEXT NOT NULL DEFAULT 'geral',
    description TEXT NOT NULL,
    amount_brl NUMERIC(18,4) NOT NULL,
    due_date DATE,
    settlement_date DATE,
    entry_status merchant_erp_external_event_status_enum NOT NULL DEFAULT 'QUEUED',
    payment_method_key TEXT,
    document_reference TEXT,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    created_by UUID,
    CONSTRAINT fk_merchant_erp_finance_entries_merchant
        FOREIGN KEY (merchant_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_merchant_erp_finance_entries_branch
        FOREIGN KEY (branch_id) REFERENCES merchant_erp_branch_units (merchant_erp_branch_unit_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_merchant_erp_finance_entries_order
        FOREIGN KEY (order_id) REFERENCES orders (order_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT chk_merchant_erp_finance_entries_desc CHECK (btrim(description) <> ''),
    CONSTRAINT chk_merchant_erp_finance_entries_amount CHECK (amount_brl >= 0),
    CONSTRAINT chk_merchant_erp_finance_entries_metadata CHECK (jsonb_typeof(metadata_json) = 'object')
);

CREATE INDEX IF NOT EXISTS ix_merchant_erp_product_variants_scope
    ON merchant_erp_product_variants (merchant_user_id, branch_id, parent_sku, variant_status);

CREATE INDEX IF NOT EXISTS ix_merchant_erp_product_kits_scope
    ON merchant_erp_product_kits (merchant_user_id, branch_id, kit_status);

CREATE INDEX IF NOT EXISTS ix_merchant_erp_label_jobs_scope
    ON merchant_erp_label_jobs (merchant_user_id, branch_id, job_type, created_at DESC);

CREATE INDEX IF NOT EXISTS ix_merchant_erp_label_items_job
    ON merchant_erp_label_job_items (label_job_id, sku);

CREATE INDEX IF NOT EXISTS ix_merchant_erp_inventory_alerts_scope
    ON merchant_erp_inventory_alert_rules (merchant_user_id, branch_id, sku, rule_status);

CREATE INDEX IF NOT EXISTS ix_merchant_erp_cycle_counts_scope
    ON merchant_erp_cycle_count_jobs (merchant_user_id, branch_id, count_status, created_at DESC);

CREATE INDEX IF NOT EXISTS ix_merchant_erp_returns_scope
    ON merchant_erp_return_authorizations (merchant_user_id, branch_id, return_status, created_at DESC);

CREATE INDEX IF NOT EXISTS ix_merchant_erp_finance_entries_scope
    ON merchant_erp_finance_entries (merchant_user_id, branch_id, entry_type, due_date, entry_status);

CREATE OR REPLACE VIEW v_merchant_erp_label_jobs AS
SELECT
    job.merchant_user_id,
    branch.branch_key,
    template.template_key,
    job.merchant_erp_label_job_id,
    job.job_type,
    job.barcode_type,
    job.labels_total,
    job.job_status,
    job.created_at,
    COUNT(item.merchant_erp_label_job_item_id) AS materialized_items_total
FROM merchant_erp_label_jobs job
LEFT JOIN merchant_erp_branch_units branch
  ON branch.merchant_erp_branch_unit_id = job.branch_id
LEFT JOIN merchant_erp_label_templates template
  ON template.merchant_erp_label_template_id = job.template_id
LEFT JOIN merchant_erp_label_job_items item
  ON item.label_job_id = job.merchant_erp_label_job_id
GROUP BY
    job.merchant_user_id,
    branch.branch_key,
    template.template_key,
    job.merchant_erp_label_job_id,
    job.job_type,
    job.barcode_type,
    job.labels_total,
    job.job_status,
    job.created_at;

CREATE OR REPLACE VIEW v_merchant_erp_product_grade_and_kits AS
SELECT
    variants.merchant_user_id,
    variants.branch_id,
    variants.parent_sku AS group_sku,
    'VARIANT'::TEXT AS group_type,
    COUNT(*) AS children_total,
    MAX(variants.updated_at) AS updated_at
FROM merchant_erp_product_variants variants
WHERE variants.deleted_at IS NULL
GROUP BY variants.merchant_user_id, variants.branch_id, variants.parent_sku
UNION ALL
SELECT
    kits.merchant_user_id,
    kits.branch_id,
    kits.kit_sku AS group_sku,
    'KIT'::TEXT AS group_type,
    COUNT(items.merchant_erp_product_kit_item_id) AS children_total,
    MAX(kits.updated_at) AS updated_at
FROM merchant_erp_product_kits kits
LEFT JOIN merchant_erp_product_kit_items items
  ON items.kit_id = kits.merchant_erp_product_kit_id
WHERE kits.deleted_at IS NULL
GROUP BY kits.merchant_user_id, kits.branch_id, kits.kit_sku;

CREATE OR REPLACE VIEW v_merchant_erp_inventory_replenishment_alerts AS
SELECT
    rule.merchant_user_id,
    branch.branch_key,
    rule.item_id,
    rule.sku,
    rule.minimum_alert_level,
    rule.maximum_alert_level,
    rule.reorder_quantity,
    rule.rule_status,
    rule.updated_at
FROM merchant_erp_inventory_alert_rules rule
LEFT JOIN merchant_erp_branch_units branch
  ON branch.merchant_erp_branch_unit_id = rule.branch_id
WHERE rule.deleted_at IS NULL;

CREATE OR REPLACE VIEW v_merchant_erp_finance_cashflow_dre AS
SELECT
    entry.merchant_user_id,
    branch.branch_key,
    entry.entry_type,
    entry.category_key,
    DATE_TRUNC('month', COALESCE(entry.settlement_date, entry.due_date, entry.created_at::DATE))::DATE AS competence_month,
    SUM(CASE WHEN entry.entry_type IN ('RECEIVABLE', 'RECEIPT') THEN entry.amount_brl ELSE 0 END) AS inflow_brl,
    SUM(CASE WHEN entry.entry_type IN ('PAYABLE', 'EXPENSE', 'REFUND') THEN entry.amount_brl ELSE 0 END) AS outflow_brl,
    SUM(CASE WHEN entry.entry_type IN ('RECEIVABLE', 'RECEIPT') THEN entry.amount_brl ELSE -entry.amount_brl END) AS net_brl,
    COUNT(*) AS entries_total
FROM merchant_erp_finance_entries entry
LEFT JOIN merchant_erp_branch_units branch
  ON branch.merchant_erp_branch_unit_id = entry.branch_id
WHERE entry.deleted_at IS NULL
GROUP BY
    entry.merchant_user_id,
    branch.branch_key,
    entry.entry_type,
    entry.category_key,
    DATE_TRUNC('month', COALESCE(entry.settlement_date, entry.due_date, entry.created_at::DATE))::DATE;

CREATE OR REPLACE VIEW v_merchant_erp_returns_control AS
SELECT
    ret.merchant_user_id,
    branch.branch_key,
    ret.return_code,
    ret.return_status,
    ret.reason_code,
    ret.refund_amount_brl,
    ret.created_at,
    ret.updated_at
FROM merchant_erp_return_authorizations ret
LEFT JOIN merchant_erp_branch_units branch
  ON branch.merchant_erp_branch_unit_id = ret.branch_id
WHERE ret.deleted_at IS NULL;

COMMENT ON TABLE merchant_erp_label_templates IS 'Templates de etiqueta do ERP lojista para QR Code, EAN-13, entrada de estoque, picking, envio e transferencia.';
COMMENT ON TABLE merchant_erp_label_jobs IS 'Jobs auditaveis de geracao de etiquetas por lojista e filial.';
COMMENT ON TABLE merchant_erp_label_job_items IS 'Itens materializados em cada job de etiqueta, incluindo EAN-13, payload QR e dados de lote.';
COMMENT ON TABLE merchant_erp_product_variants IS 'Grade de produto por SKU pai e variantes como cor, tamanho, voltagem ou atributo equivalente.';
COMMENT ON TABLE merchant_erp_product_kits IS 'Kits e combos comercializados como agrupamento de SKUs.';
COMMENT ON TABLE merchant_erp_inventory_alert_rules IS 'Limiares minimo/maximo de estoque para alerta operacional e sugestao de reposicao.';
COMMENT ON TABLE merchant_erp_cycle_count_jobs IS 'Inventario ciclico com contagem cega por filial.';
COMMENT ON TABLE merchant_erp_return_authorizations IS 'Controle de trocas e devolucoes com logistica reversa e ajuste interno de beneficio.';
COMMENT ON TABLE merchant_erp_finance_entries IS 'Contas a pagar, receber, despesas, receitas, estornos e ajustes para fluxo de caixa e DRE basico.';
COMMENT ON VIEW v_merchant_erp_label_jobs IS 'Visao operacional dos jobs de etiqueta por tenant/filial/template.';
COMMENT ON VIEW v_merchant_erp_product_grade_and_kits IS 'Resumo de grades, variantes, kits e combos por lojista.';
COMMENT ON VIEW v_merchant_erp_inventory_replenishment_alerts IS 'Visao de regras de alerta e ponto de pedido do estoque.';
COMMENT ON VIEW v_merchant_erp_finance_cashflow_dre IS 'Visao mensal de entradas, saidas e saldo por filial/categoria.';
COMMENT ON VIEW v_merchant_erp_returns_control IS 'Visao de trocas, devolucoes e estornos por filial.';

COMMIT;
