BEGIN;

-- Aprofunda o dominio Logistics ERP Operations com DDL de negocio real.
-- A migration cobre BUSINESS, REPLY, STOCK, LOG, FOOD, WMS, DELIVERY e FLEET
-- com contratos operacionais para unidade fiscal, aprovacao de compras,
-- margem e reconciliacao, taxonomia/menu de food, enderecamento WMS,
-- politica e prova de entrega e custo operacional de frota.

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_type WHERE typname = 'business_unit_type_enum'
    ) THEN
        CREATE TYPE business_unit_type_enum AS ENUM (
            'HEADQUARTERS',
            'BRANCH',
            'DARK_STORE',
            'KITCHEN',
            'WAREHOUSE'
        );
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_type WHERE typname = 'business_unit_status_enum'
    ) THEN
        CREATE TYPE business_unit_status_enum AS ENUM (
            'DRAFT',
            'ACTIVE',
            'SUSPENDED',
            'ARCHIVED'
        );
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_type WHERE typname = 'business_fiscal_closure_status_enum'
    ) THEN
        CREATE TYPE business_fiscal_closure_status_enum AS ENUM (
            'OPEN',
            'UNDER_REVIEW',
            'CLOSED',
            'REOPENED',
            'CANCELLED'
        );
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_type WHERE typname = 'procurement_approval_policy_status_enum'
    ) THEN
        CREATE TYPE procurement_approval_policy_status_enum AS ENUM (
            'DRAFT',
            'ACTIVE',
            'PAUSED',
            'ARCHIVED'
        );
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_type WHERE typname = 'procurement_approval_event_type_enum'
    ) THEN
        CREATE TYPE procurement_approval_event_type_enum AS ENUM (
            'SUBMITTED',
            'APPROVED',
            'REJECTED',
            'ESCALATED',
            'SLA_BREACHED'
        );
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_type WHERE typname = 'stock_sales_channel_enum'
    ) THEN
        CREATE TYPE stock_sales_channel_enum AS ENUM (
            'MARKETPLACE',
            'DIRECT',
            'FOOD',
            'B2B',
            'DROPSHIP'
        );
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_type WHERE typname = 'stock_policy_status_enum'
    ) THEN
        CREATE TYPE stock_policy_status_enum AS ENUM (
            'DRAFT',
            'ACTIVE',
            'PAUSED',
            'ARCHIVED'
        );
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_type WHERE typname = 'stock_reconciliation_status_enum'
    ) THEN
        CREATE TYPE stock_reconciliation_status_enum AS ENUM (
            'OPEN',
            'MATCHED',
            'DIVERGENT',
            'SETTLED',
            'CANCELLED'
        );
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_type WHERE typname = 'stockout_case_status_enum'
    ) THEN
        CREATE TYPE stockout_case_status_enum AS ENUM (
            'OPEN',
            'MITIGATING',
            'RESOLVED',
            'DISMISSED'
        );
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_type WHERE typname = 'logistics_canonical_status_enum'
    ) THEN
        CREATE TYPE logistics_canonical_status_enum AS ENUM (
            'CREATED',
            'CONFIRMED',
            'PREPARING',
            'READY',
            'IN_TRANSIT',
            'DELIVERED',
            'DELAYED',
            'FAILED',
            'CANCELLED',
            'EXCEPTION'
        );
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_type WHERE typname = 'food_store_status_enum'
    ) THEN
        CREATE TYPE food_store_status_enum AS ENUM (
            'DRAFT',
            'ACTIVE',
            'PAUSED',
            'BLOCKED',
            'ARCHIVED'
        );
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_type WHERE typname = 'food_menu_item_status_enum'
    ) THEN
        CREATE TYPE food_menu_item_status_enum AS ENUM (
            'DRAFT',
            'ACTIVE',
            'UNAVAILABLE',
            'ARCHIVED'
        );
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_type WHERE typname = 'warehouse_location_status_enum'
    ) THEN
        CREATE TYPE warehouse_location_status_enum AS ENUM (
            'ACTIVE',
            'BLOCKED',
            'MAINTENANCE',
            'ARCHIVED'
        );
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_type WHERE typname = 'warehouse_temperature_incident_status_enum'
    ) THEN
        CREATE TYPE warehouse_temperature_incident_status_enum AS ENUM (
            'OPEN',
            'ACKNOWLEDGED',
            'RESOLVED',
            'FALSE_POSITIVE'
        );
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_type WHERE typname = 'delivery_policy_status_enum'
    ) THEN
        CREATE TYPE delivery_policy_status_enum AS ENUM (
            'DRAFT',
            'ACTIVE',
            'PAUSED',
            'ARCHIVED'
        );
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_type WHERE typname = 'delivery_proof_media_kind_enum'
    ) THEN
        CREATE TYPE delivery_proof_media_kind_enum AS ENUM (
            'PHOTO',
            'VIDEO',
            'SIGNATURE',
            'QR'
        );
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_type WHERE typname = 'delivery_proof_media_status_enum'
    ) THEN
        CREATE TYPE delivery_proof_media_status_enum AS ENUM (
            'UPLOADED',
            'VERIFIED',
            'REJECTED'
        );
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_type WHERE typname = 'fleet_profile_status_enum'
    ) THEN
        CREATE TYPE fleet_profile_status_enum AS ENUM (
            'ACTIVE',
            'BLOCKED',
            'MAINTENANCE',
            'RETIRED'
        );
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_type WHERE typname = 'fleet_cost_entry_type_enum'
    ) THEN
        CREATE TYPE fleet_cost_entry_type_enum AS ENUM (
            'FUEL',
            'MAINTENANCE',
            'INSURANCE',
            'RENT',
            'TOLL',
            'OTHER'
        );
    END IF;
END
$$;

CREATE TABLE IF NOT EXISTS business_units (
    business_unit_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_user_id UUID NOT NULL,
    parent_business_unit_id UUID,
    unit_code TEXT NOT NULL,
    unit_name TEXT NOT NULL,
    unit_type business_unit_type_enum NOT NULL DEFAULT 'BRANCH',
    unit_status business_unit_status_enum NOT NULL DEFAULT 'ACTIVE',
    tax_document TEXT,
    fiscal_profile_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    ops_profile_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_business_units_business_user
        FOREIGN KEY (business_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_business_units_parent
        FOREIGN KEY (parent_business_unit_id) REFERENCES business_units (business_unit_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT ux_business_units_code UNIQUE (business_user_id, unit_code),
    CONSTRAINT chk_business_units_code CHECK (unit_code ~ '^[A-Z0-9_-]{2,80}$'),
    CONSTRAINT chk_business_units_name CHECK (btrim(unit_name) <> ''),
    CONSTRAINT chk_business_units_tax_document CHECK (
        tax_document IS NULL OR btrim(tax_document) <> ''
    ),
    CONSTRAINT chk_business_units_fiscal_json CHECK (jsonb_typeof(fiscal_profile_json) = 'object'),
    CONSTRAINT chk_business_units_ops_json CHECK (jsonb_typeof(ops_profile_json) = 'object')
);

CREATE TABLE IF NOT EXISTS business_fiscal_closures (
    fiscal_closure_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_unit_id UUID NOT NULL,
    business_user_id UUID NOT NULL,
    closure_period_start DATE NOT NULL,
    closure_period_end DATE NOT NULL,
    closure_status business_fiscal_closure_status_enum NOT NULL DEFAULT 'OPEN',
    invoice_count INTEGER NOT NULL DEFAULT 0,
    payroll_count INTEGER NOT NULL DEFAULT 0,
    gross_revenue_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    tax_due_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    closed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_business_fiscal_closures_unit
        FOREIGN KEY (business_unit_id) REFERENCES business_units (business_unit_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_business_fiscal_closures_business_user
        FOREIGN KEY (business_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT ux_business_fiscal_closures_period UNIQUE (business_unit_id, closure_period_start, closure_period_end),
    CONSTRAINT chk_business_fiscal_closures_period CHECK (closure_period_end > closure_period_start),
    CONSTRAINT chk_business_fiscal_closures_counts CHECK (
        invoice_count >= 0
        AND payroll_count >= 0
    ),
    CONSTRAINT chk_business_fiscal_closures_amounts CHECK (
        gross_revenue_brl >= 0
        AND tax_due_brl >= 0
    )
);

CREATE TABLE IF NOT EXISTS procurement_approval_policies (
    approval_policy_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_unit_id UUID NOT NULL,
    owner_user_id UUID NOT NULL,
    module_code TEXT NOT NULL DEFAULT 'REPLY',
    policy_name TEXT NOT NULL,
    min_amount_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    max_amount_brl DECIMAL(18,4),
    required_approver_count SMALLINT NOT NULL DEFAULT 1,
    approval_chain_json JSONB NOT NULL DEFAULT '[]'::JSONB,
    sla_hours INTEGER NOT NULL DEFAULT 24,
    policy_status procurement_approval_policy_status_enum NOT NULL DEFAULT 'DRAFT',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_procurement_approval_policies_unit
        FOREIGN KEY (business_unit_id) REFERENCES business_units (business_unit_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT fk_procurement_approval_policies_owner
        FOREIGN KEY (owner_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_procurement_approval_policies_module
        FOREIGN KEY (module_code) REFERENCES module_delivery_registry (module_code)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT ux_procurement_approval_policies_name UNIQUE (business_unit_id, policy_name),
    CONSTRAINT chk_procurement_approval_policies_module_code CHECK (module_code = 'REPLY'),
    CONSTRAINT chk_procurement_approval_policies_name CHECK (btrim(policy_name) <> ''),
    CONSTRAINT chk_procurement_approval_policies_amounts CHECK (
        min_amount_brl >= 0
        AND (max_amount_brl IS NULL OR max_amount_brl > min_amount_brl)
    ),
    CONSTRAINT chk_procurement_approval_policies_approvers CHECK (required_approver_count BETWEEN 1 AND 20),
    CONSTRAINT chk_procurement_approval_policies_sla CHECK (sla_hours > 0),
    CONSTRAINT chk_procurement_approval_policies_chain_json CHECK (jsonb_typeof(approval_chain_json) = 'array')
);

CREATE TABLE IF NOT EXISTS procurement_approval_events (
    approval_event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    procurement_order_id UUID NOT NULL,
    approval_policy_id UUID,
    business_unit_id UUID,
    actor_user_id UUID NOT NULL,
    event_type procurement_approval_event_type_enum NOT NULL,
    event_notes TEXT,
    requested_total_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    approval_deadline_at TIMESTAMPTZ,
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_procurement_approval_events_order
        FOREIGN KEY (procurement_order_id) REFERENCES procurement_orders (procurement_order_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_procurement_approval_events_policy
        FOREIGN KEY (approval_policy_id) REFERENCES procurement_approval_policies (approval_policy_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_procurement_approval_events_unit
        FOREIGN KEY (business_unit_id) REFERENCES business_units (business_unit_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_procurement_approval_events_actor
        FOREIGN KEY (actor_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT chk_procurement_approval_events_notes CHECK (
        event_notes IS NULL OR btrim(event_notes) <> ''
    ),
    CONSTRAINT chk_procurement_approval_events_total CHECK (requested_total_brl >= 0)
);

CREATE TABLE IF NOT EXISTS stock_channel_margin_policies (
    margin_policy_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_user_id UUID NOT NULL,
    business_unit_id UUID,
    supplier_id UUID,
    item_id UUID,
    sales_channel stock_sales_channel_enum NOT NULL DEFAULT 'MARKETPLACE',
    policy_status stock_policy_status_enum NOT NULL DEFAULT 'DRAFT',
    minimum_margin_rate DECIMAL(8,4) NOT NULL DEFAULT 0,
    target_margin_rate DECIMAL(8,4) NOT NULL DEFAULT 0,
    maximum_discount_rate DECIMAL(8,4) NOT NULL DEFAULT 0,
    effective_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    effective_until TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_stock_channel_margin_policies_merchant
        FOREIGN KEY (merchant_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_stock_channel_margin_policies_unit
        FOREIGN KEY (business_unit_id) REFERENCES business_units (business_unit_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_stock_channel_margin_policies_supplier
        FOREIGN KEY (supplier_id) REFERENCES suppliers (supplier_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_stock_channel_margin_policies_item
        FOREIGN KEY (item_id) REFERENCES inventory_items (item_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT chk_stock_channel_margin_policies_rates CHECK (
        minimum_margin_rate >= 0 AND minimum_margin_rate <= 1
        AND target_margin_rate >= minimum_margin_rate AND target_margin_rate <= 1
        AND maximum_discount_rate >= 0 AND maximum_discount_rate <= 1
    ),
    CONSTRAINT chk_stock_channel_margin_policies_effective_window CHECK (
        effective_until IS NULL OR effective_until > effective_from
    )
);

CREATE TABLE IF NOT EXISTS stock_supplier_reconciliations (
    supplier_reconciliation_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    supplier_id UUID NOT NULL,
    business_unit_id UUID,
    owner_user_id UUID NOT NULL,
    wallet_id UUID,
    settled_transaction_id UUID,
    reconciliation_period_start DATE NOT NULL,
    reconciliation_period_end DATE NOT NULL,
    reconciliation_status stock_reconciliation_status_enum NOT NULL DEFAULT 'OPEN',
    expected_amount_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    confirmed_amount_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    variance_amount_brl DECIMAL(18,4) GENERATED ALWAYS AS (confirmed_amount_brl - expected_amount_brl) STORED,
    settled_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_stock_supplier_reconciliations_supplier
        FOREIGN KEY (supplier_id) REFERENCES suppliers (supplier_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_stock_supplier_reconciliations_unit
        FOREIGN KEY (business_unit_id) REFERENCES business_units (business_unit_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_stock_supplier_reconciliations_owner
        FOREIGN KEY (owner_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_stock_supplier_reconciliations_wallet
        FOREIGN KEY (wallet_id) REFERENCES wallets (wallet_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_stock_supplier_reconciliations_transaction
        FOREIGN KEY (settled_transaction_id) REFERENCES transactions (transaction_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT chk_stock_supplier_reconciliations_period CHECK (
        reconciliation_period_end > reconciliation_period_start
    ),
    CONSTRAINT chk_stock_supplier_reconciliations_amounts CHECK (
        expected_amount_brl >= 0
        AND confirmed_amount_brl >= 0
    )
);

CREATE TABLE IF NOT EXISTS inventory_stockout_cases (
    stockout_case_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    item_id UUID NOT NULL,
    warehouse_id UUID,
    business_unit_id UUID,
    opened_by_user_id UUID NOT NULL,
    case_status stockout_case_status_enum NOT NULL DEFAULT 'OPEN',
    severity_level SMALLINT NOT NULL DEFAULT 3,
    missing_quantity DECIMAL(18,4) NOT NULL DEFAULT 0,
    detected_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    resolved_at TIMESTAMPTZ,
    resolution_code TEXT,
    resolution_notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_inventory_stockout_cases_item
        FOREIGN KEY (item_id) REFERENCES inventory_items (item_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_inventory_stockout_cases_warehouse
        FOREIGN KEY (warehouse_id) REFERENCES warehouses (warehouse_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_inventory_stockout_cases_unit
        FOREIGN KEY (business_unit_id) REFERENCES business_units (business_unit_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_inventory_stockout_cases_opened_by
        FOREIGN KEY (opened_by_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT chk_inventory_stockout_cases_severity CHECK (severity_level BETWEEN 1 AND 5),
    CONSTRAINT chk_inventory_stockout_cases_missing_quantity CHECK (missing_quantity >= 0),
    CONSTRAINT chk_inventory_stockout_cases_resolution_code CHECK (
        resolution_code IS NULL OR btrim(resolution_code) <> ''
    ),
    CONSTRAINT chk_inventory_stockout_cases_resolution_notes CHECK (
        resolution_notes IS NULL OR btrim(resolution_notes) <> ''
    ),
    CONSTRAINT chk_inventory_stockout_cases_resolution_timeline CHECK (
        resolved_at IS NULL OR resolved_at >= detected_at
    )
);

CREATE TABLE IF NOT EXISTS logistics_status_mappings (
    status_mapping_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_user_id UUID NOT NULL,
    applies_to_module TEXT NOT NULL,
    source_system TEXT NOT NULL,
    source_status TEXT NOT NULL,
    canonical_status logistics_canonical_status_enum NOT NULL,
    dedupe_window_seconds INTEGER NOT NULL DEFAULT 300,
    delay_threshold_minutes INTEGER NOT NULL DEFAULT 0,
    is_terminal BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_logistics_status_mappings_owner
        FOREIGN KEY (owner_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_logistics_status_mappings_module
        FOREIGN KEY (applies_to_module) REFERENCES module_delivery_registry (module_code)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT ux_logistics_status_mappings_source UNIQUE (applies_to_module, source_system, source_status),
    CONSTRAINT chk_logistics_status_mappings_source_system CHECK (btrim(source_system) <> ''),
    CONSTRAINT chk_logistics_status_mappings_source_status CHECK (btrim(source_status) <> ''),
    CONSTRAINT chk_logistics_status_mappings_dedupe CHECK (dedupe_window_seconds >= 0),
    CONSTRAINT chk_logistics_status_mappings_delay CHECK (delay_threshold_minutes >= 0)
);

CREATE TABLE IF NOT EXISTS food_store_contracts (
    food_store_contract_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_user_id UUID NOT NULL,
    business_unit_id UUID,
    wallet_id UUID,
    module_code TEXT NOT NULL DEFAULT 'FOOD',
    store_code TEXT NOT NULL,
    store_name TEXT NOT NULL,
    store_status food_store_status_enum NOT NULL DEFAULT 'DRAFT',
    prep_sla_minutes INTEGER NOT NULL DEFAULT 30,
    pickup_buffer_minutes INTEGER NOT NULL DEFAULT 10,
    nutrition_policy_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    allergen_policy_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    operating_hours_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_food_store_contracts_merchant
        FOREIGN KEY (merchant_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_food_store_contracts_unit
        FOREIGN KEY (business_unit_id) REFERENCES business_units (business_unit_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_food_store_contracts_wallet
        FOREIGN KEY (wallet_id) REFERENCES wallets (wallet_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_food_store_contracts_module
        FOREIGN KEY (module_code) REFERENCES module_delivery_registry (module_code)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT ux_food_store_contracts_code UNIQUE (merchant_user_id, store_code),
    CONSTRAINT chk_food_store_contracts_module_code CHECK (module_code = 'FOOD'),
    CONSTRAINT chk_food_store_contracts_code CHECK (store_code ~ '^[A-Z0-9_-]{2,80}$'),
    CONSTRAINT chk_food_store_contracts_name CHECK (btrim(store_name) <> ''),
    CONSTRAINT chk_food_store_contracts_prep_sla CHECK (prep_sla_minutes > 0),
    CONSTRAINT chk_food_store_contracts_pickup_buffer CHECK (pickup_buffer_minutes >= 0),
    CONSTRAINT chk_food_store_contracts_nutrition_json CHECK (jsonb_typeof(nutrition_policy_json) = 'object'),
    CONSTRAINT chk_food_store_contracts_allergen_json CHECK (jsonb_typeof(allergen_policy_json) = 'object'),
    CONSTRAINT chk_food_store_contracts_hours_json CHECK (jsonb_typeof(operating_hours_json) = 'object')
);

CREATE TABLE IF NOT EXISTS food_menu_catalog_entries (
    food_menu_item_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    food_store_contract_id UUID NOT NULL,
    merchant_user_id UUID NOT NULL,
    item_id UUID,
    menu_code TEXT NOT NULL,
    menu_name TEXT NOT NULL,
    availability_status food_menu_item_status_enum NOT NULL DEFAULT 'DRAFT',
    base_price_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    prep_sla_minutes INTEGER,
    nutrition_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    allergen_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_food_menu_catalog_entries_store
        FOREIGN KEY (food_store_contract_id) REFERENCES food_store_contracts (food_store_contract_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT fk_food_menu_catalog_entries_merchant
        FOREIGN KEY (merchant_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_food_menu_catalog_entries_item
        FOREIGN KEY (item_id) REFERENCES inventory_items (item_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT ux_food_menu_catalog_entries_code UNIQUE (food_store_contract_id, menu_code),
    CONSTRAINT chk_food_menu_catalog_entries_code CHECK (menu_code ~ '^[A-Z0-9_-]{2,80}$'),
    CONSTRAINT chk_food_menu_catalog_entries_name CHECK (btrim(menu_name) <> ''),
    CONSTRAINT chk_food_menu_catalog_entries_price CHECK (base_price_brl >= 0),
    CONSTRAINT chk_food_menu_catalog_entries_prep_sla CHECK (prep_sla_minutes IS NULL OR prep_sla_minutes > 0),
    CONSTRAINT chk_food_menu_catalog_entries_nutrition_json CHECK (jsonb_typeof(nutrition_json) = 'object'),
    CONSTRAINT chk_food_menu_catalog_entries_allergen_json CHECK (jsonb_typeof(allergen_json) = 'object')
);

CREATE TABLE IF NOT EXISTS warehouse_locations (
    warehouse_location_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    warehouse_id UUID NOT NULL,
    owner_user_id UUID NOT NULL,
    location_code TEXT NOT NULL,
    zone_code TEXT NOT NULL,
    location_status warehouse_location_status_enum NOT NULL DEFAULT 'ACTIVE',
    temperature_min_c DECIMAL(6,2),
    temperature_max_c DECIMAL(6,2),
    capacity_units DECIMAL(18,4) NOT NULL DEFAULT 0,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_warehouse_locations_warehouse
        FOREIGN KEY (warehouse_id) REFERENCES warehouses (warehouse_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT fk_warehouse_locations_owner
        FOREIGN KEY (owner_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT ux_warehouse_locations_code UNIQUE (warehouse_id, location_code),
    CONSTRAINT chk_warehouse_locations_code CHECK (location_code ~ '^[A-Z0-9_-]{2,80}$'),
    CONSTRAINT chk_warehouse_locations_zone CHECK (zone_code ~ '^[A-Z0-9_-]{1,40}$'),
    CONSTRAINT chk_warehouse_locations_capacity CHECK (capacity_units >= 0),
    CONSTRAINT chk_warehouse_locations_temperature_range CHECK (
        temperature_min_c IS NULL
        OR temperature_max_c IS NULL
        OR temperature_max_c > temperature_min_c
    ),
    CONSTRAINT chk_warehouse_locations_metadata_json CHECK (jsonb_typeof(metadata_json) = 'object')
);

CREATE TABLE IF NOT EXISTS warehouse_variance_adjustments (
    variance_adjustment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cycle_count_id UUID NOT NULL,
    inventory_movement_id UUID,
    approved_by_user_id UUID NOT NULL,
    adjustment_reason TEXT NOT NULL,
    quantity_adjusted DECIMAL(18,4) NOT NULL,
    unit_cost_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_warehouse_variance_adjustments_cycle_count
        FOREIGN KEY (cycle_count_id) REFERENCES warehouse_cycle_counts (cycle_count_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_warehouse_variance_adjustments_inventory_movement
        FOREIGN KEY (inventory_movement_id) REFERENCES inventory_movements (inventory_movement_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_warehouse_variance_adjustments_approved_by
        FOREIGN KEY (approved_by_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT chk_warehouse_variance_adjustments_reason CHECK (btrim(adjustment_reason) <> ''),
    CONSTRAINT chk_warehouse_variance_adjustments_quantity CHECK (quantity_adjusted <> 0),
    CONSTRAINT chk_warehouse_variance_adjustments_cost CHECK (unit_cost_brl >= 0)
);

CREATE TABLE IF NOT EXISTS warehouse_temperature_incidents (
    temperature_incident_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    warehouse_id UUID NOT NULL,
    warehouse_location_id UUID,
    owner_user_id UUID NOT NULL,
    incident_status warehouse_temperature_incident_status_enum NOT NULL DEFAULT 'OPEN',
    severity_level SMALLINT NOT NULL DEFAULT 3,
    current_temperature_c DECIMAL(6,2) NOT NULL,
    threshold_min_c DECIMAL(6,2),
    threshold_max_c DECIMAL(6,2),
    sensor_reference TEXT,
    detected_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    acknowledged_at TIMESTAMPTZ,
    resolved_at TIMESTAMPTZ,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_warehouse_temperature_incidents_warehouse
        FOREIGN KEY (warehouse_id) REFERENCES warehouses (warehouse_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_warehouse_temperature_incidents_location
        FOREIGN KEY (warehouse_location_id) REFERENCES warehouse_locations (warehouse_location_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_warehouse_temperature_incidents_owner
        FOREIGN KEY (owner_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT chk_warehouse_temperature_incidents_severity CHECK (severity_level BETWEEN 1 AND 5),
    CONSTRAINT chk_warehouse_temperature_incidents_sensor_reference CHECK (
        sensor_reference IS NULL OR btrim(sensor_reference) <> ''
    ),
    CONSTRAINT chk_warehouse_temperature_incidents_metadata_json CHECK (jsonb_typeof(metadata_json) = 'object'),
    CONSTRAINT chk_warehouse_temperature_incidents_timeline CHECK (
        (acknowledged_at IS NULL OR acknowledged_at >= detected_at)
        AND (resolved_at IS NULL OR resolved_at >= COALESCE(acknowledged_at, detected_at))
    ),
    CONSTRAINT chk_warehouse_temperature_incidents_threshold_range CHECK (
        threshold_min_c IS NULL
        OR threshold_max_c IS NULL
        OR threshold_max_c > threshold_min_c
    )
);

CREATE TABLE IF NOT EXISTS delivery_operation_policies (
    delivery_policy_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_user_id UUID,
    business_unit_id UUID,
    module_code TEXT NOT NULL DEFAULT 'DELIVERY',
    policy_name TEXT NOT NULL,
    shipment_kind delivery_shipment_kind_enum NOT NULL,
    auto_reassign_after_minutes INTEGER NOT NULL DEFAULT 10,
    max_reassignments SMALLINT NOT NULL DEFAULT 2,
    promised_window_minutes INTEGER NOT NULL DEFAULT 60,
    proof_media_required BOOLEAN NOT NULL DEFAULT TRUE,
    policy_status delivery_policy_status_enum NOT NULL DEFAULT 'DRAFT',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_delivery_operation_policies_merchant
        FOREIGN KEY (merchant_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_delivery_operation_policies_unit
        FOREIGN KEY (business_unit_id) REFERENCES business_units (business_unit_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_delivery_operation_policies_module
        FOREIGN KEY (module_code) REFERENCES module_delivery_registry (module_code)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT chk_delivery_operation_policies_module_code CHECK (module_code = 'DELIVERY'),
    CONSTRAINT chk_delivery_operation_policies_name CHECK (btrim(policy_name) <> ''),
    CONSTRAINT chk_delivery_operation_policies_reassign_minutes CHECK (auto_reassign_after_minutes >= 0),
    CONSTRAINT chk_delivery_operation_policies_max_reassignments CHECK (max_reassignments >= 0),
    CONSTRAINT chk_delivery_operation_policies_promised_window CHECK (promised_window_minutes > 0)
);

CREATE TABLE IF NOT EXISTS delivery_proof_media (
    delivery_proof_media_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shipment_id UUID NOT NULL,
    shipment_event_id UUID,
    owner_user_id UUID NOT NULL,
    document_id UUID,
    media_kind delivery_proof_media_kind_enum NOT NULL,
    media_status delivery_proof_media_status_enum NOT NULL DEFAULT 'UPLOADED',
    media_url TEXT NOT NULL,
    checksum_sha256 TEXT NOT NULL,
    captured_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    verified_by_user_id UUID,
    verified_at TIMESTAMPTZ,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_delivery_proof_media_shipment
        FOREIGN KEY (shipment_id) REFERENCES delivery_shipments (shipment_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT fk_delivery_proof_media_shipment_event
        FOREIGN KEY (shipment_event_id) REFERENCES delivery_shipment_events (shipment_event_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_delivery_proof_media_owner
        FOREIGN KEY (owner_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_delivery_proof_media_document
        FOREIGN KEY (document_id) REFERENCES document_records (document_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_delivery_proof_media_verified_by
        FOREIGN KEY (verified_by_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT chk_delivery_proof_media_url CHECK (btrim(media_url) <> ''),
    CONSTRAINT chk_delivery_proof_media_checksum CHECK (checksum_sha256 ~ '^[a-fA-F0-9]{64}$'),
    CONSTRAINT chk_delivery_proof_media_timeline CHECK (
        verified_at IS NULL OR verified_at >= captured_at
    ),
    CONSTRAINT chk_delivery_proof_media_metadata_json CHECK (jsonb_typeof(metadata_json) = 'object')
);

CREATE TABLE IF NOT EXISTS fleet_vehicle_operating_profiles (
    vehicle_operating_profile_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_user_id UUID NOT NULL,
    rider_user_id UUID,
    business_unit_id UUID,
    vehicle_reference TEXT NOT NULL,
    vehicle_category TEXT NOT NULL,
    profile_status fleet_profile_status_enum NOT NULL DEFAULT 'ACTIVE',
    health_score DECIMAL(5,2) NOT NULL DEFAULT 100,
    critical_maintenance_cutoff DECIMAL(5,2) NOT NULL DEFAULT 30,
    target_cost_per_km_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    last_maintenance_at TIMESTAMPTZ,
    blocked_at TIMESTAMPTZ,
    blocked_reason TEXT,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_fleet_vehicle_operating_profiles_owner
        FOREIGN KEY (owner_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_fleet_vehicle_operating_profiles_rider
        FOREIGN KEY (rider_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_fleet_vehicle_operating_profiles_unit
        FOREIGN KEY (business_unit_id) REFERENCES business_units (business_unit_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT ux_fleet_vehicle_operating_profiles_reference UNIQUE (owner_user_id, vehicle_reference),
    CONSTRAINT chk_fleet_vehicle_operating_profiles_reference CHECK (btrim(vehicle_reference) <> ''),
    CONSTRAINT chk_fleet_vehicle_operating_profiles_category CHECK (btrim(vehicle_category) <> ''),
    CONSTRAINT chk_fleet_vehicle_operating_profiles_scores CHECK (
        health_score >= 0 AND health_score <= 100
        AND critical_maintenance_cutoff >= 0 AND critical_maintenance_cutoff <= 100
    ),
    CONSTRAINT chk_fleet_vehicle_operating_profiles_cost CHECK (target_cost_per_km_brl >= 0),
    CONSTRAINT chk_fleet_vehicle_operating_profiles_block_reason CHECK (
        blocked_reason IS NULL OR btrim(blocked_reason) <> ''
    ),
    CONSTRAINT chk_fleet_vehicle_operating_profiles_metadata_json CHECK (jsonb_typeof(metadata_json) = 'object')
);

CREATE TABLE IF NOT EXISTS fleet_cost_entries (
    fleet_cost_entry_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_user_id UUID NOT NULL,
    vehicle_operating_profile_id UUID NOT NULL,
    transaction_id UUID,
    cost_entry_type fleet_cost_entry_type_enum NOT NULL,
    cost_amount_brl DECIMAL(18,4) NOT NULL,
    distance_km DECIMAL(12,3),
    reference_period_start DATE,
    reference_period_end DATE,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_fleet_cost_entries_owner
        FOREIGN KEY (owner_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_fleet_cost_entries_profile
        FOREIGN KEY (vehicle_operating_profile_id) REFERENCES fleet_vehicle_operating_profiles (vehicle_operating_profile_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_fleet_cost_entries_transaction
        FOREIGN KEY (transaction_id) REFERENCES transactions (transaction_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT chk_fleet_cost_entries_amount CHECK (cost_amount_brl > 0),
    CONSTRAINT chk_fleet_cost_entries_distance CHECK (distance_km IS NULL OR distance_km >= 0),
    CONSTRAINT chk_fleet_cost_entries_period CHECK (
        reference_period_end IS NULL
        OR reference_period_start IS NULL
        OR reference_period_end >= reference_period_start
    ),
    CONSTRAINT chk_fleet_cost_entries_notes CHECK (
        notes IS NULL OR btrim(notes) <> ''
    )
);

ALTER TABLE procurement_orders
    ADD COLUMN IF NOT EXISTS business_unit_id UUID,
    ADD COLUMN IF NOT EXISTS approval_policy_id UUID,
    ADD COLUMN IF NOT EXISTS approval_due_at TIMESTAMPTZ;

ALTER TABLE procurement_orders
    ADD CONSTRAINT fk_procurement_orders_business_unit
        FOREIGN KEY (business_unit_id) REFERENCES business_units (business_unit_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    ADD CONSTRAINT fk_procurement_orders_approval_policy
        FOREIGN KEY (approval_policy_id) REFERENCES procurement_approval_policies (approval_policy_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    ADD CONSTRAINT chk_procurement_orders_approval_due_at
        CHECK (approval_due_at IS NULL OR approval_due_at >= created_at);

ALTER TABLE business_invoices
    ADD COLUMN IF NOT EXISTS business_unit_id UUID;

ALTER TABLE business_invoices
    ADD CONSTRAINT fk_business_invoices_business_unit
        FOREIGN KEY (business_unit_id) REFERENCES business_units (business_unit_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL;

ALTER TABLE business_payrolls
    ADD COLUMN IF NOT EXISTS business_unit_id UUID;

ALTER TABLE business_payrolls
    ADD CONSTRAINT fk_business_payrolls_business_unit
        FOREIGN KEY (business_unit_id) REFERENCES business_units (business_unit_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL;

ALTER TABLE orders
    ADD COLUMN IF NOT EXISTS business_unit_id UUID,
    ADD COLUMN IF NOT EXISTS food_store_contract_id UUID,
    ADD COLUMN IF NOT EXISTS promised_delivery_at TIMESTAMPTZ;

ALTER TABLE orders
    ADD CONSTRAINT fk_orders_business_unit
        FOREIGN KEY (business_unit_id) REFERENCES business_units (business_unit_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    ADD CONSTRAINT fk_orders_food_store_contract
        FOREIGN KEY (food_store_contract_id) REFERENCES food_store_contracts (food_store_contract_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    ADD CONSTRAINT chk_orders_promised_delivery_at
        CHECK (promised_delivery_at IS NULL OR promised_delivery_at >= created_at);

ALTER TABLE inventory_lots
    ADD COLUMN IF NOT EXISTS warehouse_location_id UUID;

ALTER TABLE inventory_lots
    ADD CONSTRAINT fk_inventory_lots_warehouse_location
        FOREIGN KEY (warehouse_location_id) REFERENCES warehouse_locations (warehouse_location_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL;

ALTER TABLE delivery_shipments
    ADD COLUMN IF NOT EXISTS delivery_policy_id UUID,
    ADD COLUMN IF NOT EXISTS promised_delivery_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS reassignment_count SMALLINT NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS proof_media_required BOOLEAN NOT NULL DEFAULT TRUE;

ALTER TABLE delivery_shipments
    ADD CONSTRAINT fk_delivery_shipments_delivery_policy
        FOREIGN KEY (delivery_policy_id) REFERENCES delivery_operation_policies (delivery_policy_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    ADD CONSTRAINT chk_delivery_shipments_reassignment_count
        CHECK (reassignment_count >= 0),
    ADD CONSTRAINT chk_delivery_shipments_promised_delivery_at
        CHECK (promised_delivery_at IS NULL OR promised_delivery_at >= created_at);

ALTER TABLE mobility_trips
    ADD COLUMN IF NOT EXISTS vehicle_operating_profile_id UUID;

ALTER TABLE mobility_trips
    ADD CONSTRAINT fk_mobility_trips_vehicle_profile
        FOREIGN KEY (vehicle_operating_profile_id) REFERENCES fleet_vehicle_operating_profiles (vehicle_operating_profile_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS ix_business_units_business_status
    ON business_units (business_user_id, unit_status, unit_type);

CREATE INDEX IF NOT EXISTS ix_business_fiscal_closures_unit_period
    ON business_fiscal_closures (business_unit_id, closure_period_start, closure_status);

CREATE INDEX IF NOT EXISTS ix_procurement_approval_policies_unit_status
    ON procurement_approval_policies (business_unit_id, policy_status, sla_hours);

CREATE INDEX IF NOT EXISTS ix_procurement_approval_events_order_time
    ON procurement_approval_events (procurement_order_id, occurred_at DESC);

CREATE INDEX IF NOT EXISTS ix_stock_channel_margin_policies_item_window
    ON stock_channel_margin_policies (merchant_user_id, item_id, sales_channel, policy_status);

CREATE INDEX IF NOT EXISTS ix_stock_supplier_reconciliations_supplier_period
    ON stock_supplier_reconciliations (supplier_id, reconciliation_period_start, reconciliation_status);

CREATE INDEX IF NOT EXISTS ix_inventory_stockout_cases_item_status
    ON inventory_stockout_cases (item_id, case_status, detected_at DESC);

CREATE INDEX IF NOT EXISTS ix_logistics_status_mappings_module_source
    ON logistics_status_mappings (applies_to_module, source_system, canonical_status);

CREATE INDEX IF NOT EXISTS ix_food_store_contracts_merchant_status
    ON food_store_contracts (merchant_user_id, store_status, prep_sla_minutes);

CREATE INDEX IF NOT EXISTS ix_food_menu_catalog_entries_store_status
    ON food_menu_catalog_entries (food_store_contract_id, availability_status, menu_code);

CREATE INDEX IF NOT EXISTS ix_warehouse_locations_warehouse_status
    ON warehouse_locations (warehouse_id, location_status, zone_code);

CREATE INDEX IF NOT EXISTS ix_warehouse_variance_adjustments_cycle_time
    ON warehouse_variance_adjustments (cycle_count_id, created_at DESC);

CREATE INDEX IF NOT EXISTS ix_warehouse_temperature_incidents_status
    ON warehouse_temperature_incidents (warehouse_id, incident_status, detected_at DESC);

CREATE INDEX IF NOT EXISTS ix_delivery_operation_policies_scope
    ON delivery_operation_policies (business_unit_id, shipment_kind, policy_status);

CREATE INDEX IF NOT EXISTS ix_delivery_proof_media_shipment_status
    ON delivery_proof_media (shipment_id, media_status, captured_at DESC);

CREATE INDEX IF NOT EXISTS ix_fleet_vehicle_operating_profiles_owner_status
    ON fleet_vehicle_operating_profiles (owner_user_id, profile_status, health_score);

CREATE INDEX IF NOT EXISTS ix_fleet_cost_entries_profile_time
    ON fleet_cost_entries (vehicle_operating_profile_id, created_at DESC, cost_entry_type);

CREATE INDEX IF NOT EXISTS ix_procurement_orders_business_unit_status
    ON procurement_orders (business_unit_id, procurement_status, approval_due_at);

CREATE INDEX IF NOT EXISTS ix_orders_business_unit_promised_delivery
    ON orders (business_unit_id, promised_delivery_at, order_status);

CREATE INDEX IF NOT EXISTS ix_inventory_lots_location
    ON inventory_lots (warehouse_location_id, warehouse_id, lot_status);

CREATE INDEX IF NOT EXISTS ix_delivery_shipments_policy_status
    ON delivery_shipments (delivery_policy_id, shipment_status, promised_delivery_at);

CREATE INDEX IF NOT EXISTS ix_mobility_trips_vehicle_profile
    ON mobility_trips (vehicle_operating_profile_id, trip_status, created_at);

DROP TRIGGER IF EXISTS trg_business_units_set_updated_at
    ON business_units;
CREATE TRIGGER trg_business_units_set_updated_at
BEFORE UPDATE ON business_units
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_business_fiscal_closures_set_updated_at
    ON business_fiscal_closures;
CREATE TRIGGER trg_business_fiscal_closures_set_updated_at
BEFORE UPDATE ON business_fiscal_closures
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_procurement_approval_policies_set_updated_at
    ON procurement_approval_policies;
CREATE TRIGGER trg_procurement_approval_policies_set_updated_at
BEFORE UPDATE ON procurement_approval_policies
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_stock_channel_margin_policies_set_updated_at
    ON stock_channel_margin_policies;
CREATE TRIGGER trg_stock_channel_margin_policies_set_updated_at
BEFORE UPDATE ON stock_channel_margin_policies
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_stock_supplier_reconciliations_set_updated_at
    ON stock_supplier_reconciliations;
CREATE TRIGGER trg_stock_supplier_reconciliations_set_updated_at
BEFORE UPDATE ON stock_supplier_reconciliations
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_inventory_stockout_cases_set_updated_at
    ON inventory_stockout_cases;
CREATE TRIGGER trg_inventory_stockout_cases_set_updated_at
BEFORE UPDATE ON inventory_stockout_cases
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_logistics_status_mappings_set_updated_at
    ON logistics_status_mappings;
CREATE TRIGGER trg_logistics_status_mappings_set_updated_at
BEFORE UPDATE ON logistics_status_mappings
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_food_store_contracts_set_updated_at
    ON food_store_contracts;
CREATE TRIGGER trg_food_store_contracts_set_updated_at
BEFORE UPDATE ON food_store_contracts
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_food_menu_catalog_entries_set_updated_at
    ON food_menu_catalog_entries;
CREATE TRIGGER trg_food_menu_catalog_entries_set_updated_at
BEFORE UPDATE ON food_menu_catalog_entries
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_warehouse_locations_set_updated_at
    ON warehouse_locations;
CREATE TRIGGER trg_warehouse_locations_set_updated_at
BEFORE UPDATE ON warehouse_locations
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_warehouse_temperature_incidents_set_updated_at
    ON warehouse_temperature_incidents;
CREATE TRIGGER trg_warehouse_temperature_incidents_set_updated_at
BEFORE UPDATE ON warehouse_temperature_incidents
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_delivery_operation_policies_set_updated_at
    ON delivery_operation_policies;
CREATE TRIGGER trg_delivery_operation_policies_set_updated_at
BEFORE UPDATE ON delivery_operation_policies
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_delivery_proof_media_set_updated_at
    ON delivery_proof_media;
CREATE TRIGGER trg_delivery_proof_media_set_updated_at
BEFORE UPDATE ON delivery_proof_media
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_fleet_vehicle_operating_profiles_set_updated_at
    ON fleet_vehicle_operating_profiles;
CREATE TRIGGER trg_fleet_vehicle_operating_profiles_set_updated_at
BEFORE UPDATE ON fleet_vehicle_operating_profiles
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_procurement_approval_events_prevent_update
    ON procurement_approval_events;
CREATE TRIGGER trg_procurement_approval_events_prevent_update
BEFORE UPDATE ON procurement_approval_events
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

DROP TRIGGER IF EXISTS trg_procurement_approval_events_prevent_delete
    ON procurement_approval_events;
CREATE TRIGGER trg_procurement_approval_events_prevent_delete
BEFORE DELETE ON procurement_approval_events
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

DROP TRIGGER IF EXISTS trg_warehouse_variance_adjustments_prevent_update
    ON warehouse_variance_adjustments;
CREATE TRIGGER trg_warehouse_variance_adjustments_prevent_update
BEFORE UPDATE ON warehouse_variance_adjustments
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

DROP TRIGGER IF EXISTS trg_warehouse_variance_adjustments_prevent_delete
    ON warehouse_variance_adjustments;
CREATE TRIGGER trg_warehouse_variance_adjustments_prevent_delete
BEFORE DELETE ON warehouse_variance_adjustments
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

DROP TRIGGER IF EXISTS trg_fleet_cost_entries_prevent_update
    ON fleet_cost_entries;
CREATE TRIGGER trg_fleet_cost_entries_prevent_update
BEFORE UPDATE ON fleet_cost_entries
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

DROP TRIGGER IF EXISTS trg_fleet_cost_entries_prevent_delete
    ON fleet_cost_entries;
CREATE TRIGGER trg_fleet_cost_entries_prevent_delete
BEFORE DELETE ON fleet_cost_entries
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

CREATE OR REPLACE VIEW v_logistics_erp_operations_priority_backlog AS
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
WHERE backlog.backlog_group = 'logistics_erp_operations'
  AND backlog.origin_source = 'blueprint_execution_v1';

CREATE OR REPLACE VIEW v_logistics_erp_operations_delivery_artifacts AS
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
WHERE domain_key = 'logistics_erp_operations';

CREATE OR REPLACE VIEW v_logistics_erp_operations_event_contracts AS
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
WHERE domain_key = 'logistics_erp_operations';

COMMENT ON TABLE business_units IS
    'Contrato real de empresa e unidade operacional para BUSINESS e dominios de operacao.';
COMMENT ON TABLE business_fiscal_closures IS
    'Fechamento fiscal consolidado por unidade para invoices e payroll.';
COMMENT ON TABLE procurement_approval_policies IS
    'Politicas de aprovacao por unidade para compras do REPLY.';
COMMENT ON TABLE procurement_approval_events IS
    'Trilha append-only das aprovacoes, rejeicoes e breaches de SLA de procurement.';
COMMENT ON TABLE stock_channel_margin_policies IS
    'Politicas de margem por canal para STOCK e catalogo comercial.';
COMMENT ON TABLE stock_supplier_reconciliations IS
    'Conciliacao financeira por fornecedor e janela contabil.';
COMMENT ON TABLE inventory_stockout_cases IS
    'Casos de ruptura e excecao operacional do estoque.';
COMMENT ON TABLE logistics_status_mappings IS
    'Mapa canonico de status e dedupe entre fontes logistica, food, delivery e fleet.';
COMMENT ON TABLE food_store_contracts IS
    'Contrato operacional de loja/cardapio para FOOD com SLA e politicas nutricionais.';
COMMENT ON TABLE food_menu_catalog_entries IS
    'Itens de menu ligados ao catalogo, com alergenos e SLA de preparo.';
COMMENT ON TABLE warehouse_locations IS
    'Mapa de enderecamento fisico do WMS por armazem.';
COMMENT ON TABLE warehouse_variance_adjustments IS
    'Trilha append-only de ajuste de variancia apos cycle count.';
COMMENT ON TABLE warehouse_temperature_incidents IS
    'Incidentes de temperatura e cadeia fria do WMS.';
COMMENT ON TABLE delivery_operation_policies IS
    'Politicas reais de reatribuicao e janela prometida do modulo DELIVERY.';
COMMENT ON TABLE delivery_proof_media IS
    'Midias de prova de entrega com hash e verificacao.';
COMMENT ON TABLE fleet_vehicle_operating_profiles IS
    'Perfil operacional e score de saude do veiculo usado pela frota.';
COMMENT ON TABLE fleet_cost_entries IS
    'Ledger append-only de custos operacionais da frota para calculo de custo por km.';

COMMENT ON VIEW v_logistics_erp_operations_priority_backlog IS
    'Backlog prioritario do dominio logistics_erp_operations agora sustentado por DDL de negocio real.';
COMMENT ON VIEW v_logistics_erp_operations_delivery_artifacts IS
    'Artefatos registrados para o dominio logistics_erp_operations.';
COMMENT ON VIEW v_logistics_erp_operations_event_contracts IS
    'Contratos de evento exportados do dominio logistics_erp_operations.';

COMMIT;
