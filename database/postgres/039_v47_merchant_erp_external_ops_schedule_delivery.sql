-- ERP Lojista: conectores externos, NF-e, produtos, relatorios, filiais, agenda de servicos e rastreio proprio.
-- A migration e aditiva, mantem segredos fora do banco e usa trilhas append-only.

SET search_path = public;

ALTER TYPE merchant_erp_role_enum ADD VALUE IF NOT EXISTS 'SCHEDULER';
ALTER TYPE merchant_erp_role_enum ADD VALUE IF NOT EXISTS 'COURIER';

BEGIN;

SET search_path = public;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'merchant_erp_connector_family_enum') THEN
        CREATE TYPE merchant_erp_connector_family_enum AS ENUM (
            'MARKETPLACE',
            'CLASSIFIEDS',
            'FOOD_DELIVERY',
            'BEVERAGE_DELIVERY',
            'STOREFRONT',
            'COMMUNICATION',
            'FISCAL',
            'BOOKING',
            'LOGISTICS'
        );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'merchant_erp_sync_direction_enum') THEN
        CREATE TYPE merchant_erp_sync_direction_enum AS ENUM (
            'INBOUND',
            'OUTBOUND',
            'BIDIRECTIONAL'
        );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'merchant_erp_external_event_status_enum') THEN
        CREATE TYPE merchant_erp_external_event_status_enum AS ENUM (
            'RECEIVED',
            'QUEUED',
            'PROCESSED',
            'ACKNOWLEDGED',
            'FAILED',
            'IGNORED'
        );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'merchant_erp_booking_status_enum') THEN
        CREATE TYPE merchant_erp_booking_status_enum AS ENUM (
            'REQUESTED',
            'CONFIRMED',
            'CHECKED_IN',
            'COMPLETED',
            'CANCELLED',
            'NO_SHOW'
        );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'merchant_erp_delivery_status_enum') THEN
        CREATE TYPE merchant_erp_delivery_status_enum AS ENUM (
            'ASSIGNED',
            'ACCEPTED',
            'PICKED_UP',
            'IN_TRANSIT',
            'ARRIVED',
            'DELIVERED',
            'FAILED',
            'RETURNED'
        );
    END IF;
END
$$;

CREATE TABLE IF NOT EXISTS merchant_erp_connector_catalog (
    merchant_erp_connector_catalog_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider_key TEXT NOT NULL,
    provider_label TEXT NOT NULL,
    connector_family merchant_erp_connector_family_enum NOT NULL,
    direction_mode merchant_erp_sync_direction_enum NOT NULL DEFAULT 'BIDIRECTIONAL',
    docs_url TEXT,
    webhook_path TEXT,
    credential_policy_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    capabilities_json JSONB NOT NULL DEFAULT '[]'::JSONB,
    recommended_for_json JSONB NOT NULL DEFAULT '[]'::JSONB,
    connector_status merchant_erp_integration_status_enum NOT NULL DEFAULT 'DRAFT',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT ux_merchant_erp_connector_catalog_key UNIQUE (provider_key),
    CONSTRAINT chk_merchant_erp_connector_catalog_key CHECK (provider_key ~ '^[a-z0-9_-]{2,80}$'),
    CONSTRAINT chk_merchant_erp_connector_catalog_label CHECK (btrim(provider_label) <> ''),
    CONSTRAINT chk_merchant_erp_connector_catalog_docs CHECK (docs_url IS NULL OR docs_url ~ '^https?://'),
    CONSTRAINT chk_merchant_erp_connector_catalog_webhook CHECK (webhook_path IS NULL OR webhook_path ~ '^/'),
    CONSTRAINT chk_merchant_erp_connector_catalog_json CHECK (
        jsonb_typeof(credential_policy_json) = 'object'
        AND jsonb_typeof(capabilities_json) = 'array'
        AND jsonb_typeof(recommended_for_json) = 'array'
    )
);

CREATE TABLE IF NOT EXISTS merchant_erp_connector_sync_events (
    merchant_erp_connector_sync_event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_user_id UUID NOT NULL,
    provider_key TEXT NOT NULL,
    direction merchant_erp_sync_direction_enum NOT NULL,
    object_type TEXT NOT NULL,
    external_object_id TEXT,
    idempotency_key TEXT NOT NULL,
    event_status merchant_erp_external_event_status_enum NOT NULL DEFAULT 'RECEIVED',
    payload_hash TEXT NOT NULL,
    payload_summary_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    error_detail TEXT,
    received_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    processed_at TIMESTAMPTZ,
    CONSTRAINT fk_merchant_erp_connector_events_merchant
        FOREIGN KEY (merchant_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_merchant_erp_connector_events_provider
        FOREIGN KEY (provider_key) REFERENCES merchant_erp_connector_catalog (provider_key)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT ux_merchant_erp_connector_events_idempotency UNIQUE (merchant_user_id, provider_key, idempotency_key),
    CONSTRAINT chk_merchant_erp_connector_events_object CHECK (btrim(object_type) <> ''),
    CONSTRAINT chk_merchant_erp_connector_events_hash CHECK (payload_hash ~ '^[a-f0-9]{64}$'),
    CONSTRAINT chk_merchant_erp_connector_events_summary CHECK (jsonb_typeof(payload_summary_json) = 'object')
);

CREATE TABLE IF NOT EXISTS merchant_erp_nfe_import_batches (
    merchant_erp_nfe_import_batch_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_user_id UUID NOT NULL,
    imported_by_user_id UUID,
    access_key TEXT NOT NULL,
    issuer_cnpj TEXT NOT NULL,
    recipient_cnpj TEXT NOT NULL,
    issued_at TIMESTAMPTZ,
    xml_payload_hash TEXT,
    fiscal_status merchant_erp_external_event_status_enum NOT NULL DEFAULT 'RECEIVED',
    stock_update_status merchant_erp_external_event_status_enum NOT NULL DEFAULT 'QUEUED',
    totals_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_merchant_erp_nfe_batches_merchant
        FOREIGN KEY (merchant_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_merchant_erp_nfe_batches_imported_by
        FOREIGN KEY (imported_by_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT ux_merchant_erp_nfe_batches_access UNIQUE (merchant_user_id, access_key),
    CONSTRAINT chk_merchant_erp_nfe_batches_access CHECK (access_key ~ '^[0-9]{44}$'),
    CONSTRAINT chk_merchant_erp_nfe_batches_issuer CHECK (issuer_cnpj ~ '^[0-9]{14}$'),
    CONSTRAINT chk_merchant_erp_nfe_batches_recipient CHECK (recipient_cnpj ~ '^[0-9]{14}$'),
    CONSTRAINT chk_merchant_erp_nfe_batches_xml_hash CHECK (xml_payload_hash IS NULL OR xml_payload_hash ~ '^[a-f0-9]{64}$'),
    CONSTRAINT chk_merchant_erp_nfe_batches_json CHECK (
        jsonb_typeof(totals_json) = 'object'
        AND jsonb_typeof(metadata_json) = 'object'
    )
);

CREATE TABLE IF NOT EXISTS merchant_erp_nfe_items (
    merchant_erp_nfe_item_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nfe_import_batch_id UUID NOT NULL,
    item_id UUID,
    sku TEXT,
    ean TEXT,
    description TEXT NOT NULL,
    ncm TEXT,
    cfop TEXT,
    unit TEXT NOT NULL DEFAULT 'UN',
    quantity NUMERIC(18,4) NOT NULL,
    unit_value_brl NUMERIC(18,4) NOT NULL DEFAULT 0,
    total_value_brl NUMERIC(18,4) NOT NULL DEFAULT 0,
    stock_movement_id UUID,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_merchant_erp_nfe_items_batch
        FOREIGN KEY (nfe_import_batch_id) REFERENCES merchant_erp_nfe_import_batches (merchant_erp_nfe_import_batch_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT fk_merchant_erp_nfe_items_item
        FOREIGN KEY (item_id) REFERENCES inventory_items (item_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_merchant_erp_nfe_items_stock_movement
        FOREIGN KEY (stock_movement_id) REFERENCES inventory_movements (movement_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT chk_merchant_erp_nfe_items_desc CHECK (btrim(description) <> ''),
    CONSTRAINT chk_merchant_erp_nfe_items_qty CHECK (quantity > 0),
    CONSTRAINT chk_merchant_erp_nfe_items_values CHECK (unit_value_brl >= 0 AND total_value_brl >= 0),
    CONSTRAINT chk_merchant_erp_nfe_items_metadata CHECK (jsonb_typeof(metadata_json) = 'object')
);

CREATE TABLE IF NOT EXISTS merchant_erp_service_resources (
    merchant_erp_service_resource_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_user_id UUID NOT NULL,
    resource_key TEXT NOT NULL,
    resource_type TEXT NOT NULL,
    display_name TEXT NOT NULL,
    professional_user_id UUID,
    capacity INTEGER NOT NULL DEFAULT 1,
    timezone_name TEXT NOT NULL DEFAULT 'America/Sao_Paulo',
    schedule_policy_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    resource_status merchant_erp_status_enum NOT NULL DEFAULT 'ACTIVE',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_merchant_erp_service_resources_merchant
        FOREIGN KEY (merchant_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_merchant_erp_service_resources_professional
        FOREIGN KEY (professional_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT ux_merchant_erp_service_resources_key UNIQUE (merchant_user_id, resource_key),
    CONSTRAINT chk_merchant_erp_service_resources_key CHECK (resource_key ~ '^[a-z0-9_-]{2,80}$'),
    CONSTRAINT chk_merchant_erp_service_resources_type CHECK (resource_type IN ('professional', 'room', 'chair', 'equipment')),
    CONSTRAINT chk_merchant_erp_service_resources_capacity CHECK (capacity > 0),
    CONSTRAINT chk_merchant_erp_service_resources_policy CHECK (jsonb_typeof(schedule_policy_json) = 'object')
);

CREATE TABLE IF NOT EXISTS merchant_erp_service_bookings (
    merchant_erp_service_booking_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_user_id UUID NOT NULL,
    resource_id UUID NOT NULL,
    customer_user_id UUID,
    customer_name TEXT NOT NULL,
    customer_phone_e164 TEXT,
    customer_email TEXT,
    service_key TEXT NOT NULL,
    service_label TEXT NOT NULL,
    booking_status merchant_erp_booking_status_enum NOT NULL DEFAULT 'REQUESTED',
    starts_at TIMESTAMPTZ NOT NULL,
    ends_at TIMESTAMPTZ NOT NULL,
    source_channel TEXT NOT NULL DEFAULT 'VALLEY_APP',
    external_booking_id TEXT,
    notes TEXT,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_merchant_erp_service_bookings_merchant
        FOREIGN KEY (merchant_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_merchant_erp_service_bookings_resource
        FOREIGN KEY (resource_id) REFERENCES merchant_erp_service_resources (merchant_erp_service_resource_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_merchant_erp_service_bookings_customer
        FOREIGN KEY (customer_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT chk_merchant_erp_service_bookings_customer CHECK (btrim(customer_name) <> ''),
    CONSTRAINT chk_merchant_erp_service_bookings_service CHECK (service_key ~ '^[a-z0-9_-]{2,80}$' AND btrim(service_label) <> ''),
    CONSTRAINT chk_merchant_erp_service_bookings_window CHECK (ends_at > starts_at),
    CONSTRAINT chk_merchant_erp_service_bookings_metadata CHECK (jsonb_typeof(metadata_json) = 'object')
);

CREATE TABLE IF NOT EXISTS merchant_erp_service_booking_events (
    merchant_erp_service_booking_event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID NOT NULL,
    actor_user_id UUID,
    event_type TEXT NOT NULL,
    previous_status merchant_erp_booking_status_enum,
    next_status merchant_erp_booking_status_enum,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_merchant_erp_booking_events_booking
        FOREIGN KEY (booking_id) REFERENCES merchant_erp_service_bookings (merchant_erp_service_booking_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT fk_merchant_erp_booking_events_actor
        FOREIGN KEY (actor_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT chk_merchant_erp_booking_events_type CHECK (btrim(event_type) <> ''),
    CONSTRAINT chk_merchant_erp_booking_events_metadata CHECK (jsonb_typeof(metadata_json) = 'object')
);

CREATE TABLE IF NOT EXISTS merchant_erp_courier_profiles (
    merchant_erp_courier_profile_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_user_id UUID NOT NULL,
    courier_user_id UUID NOT NULL,
    display_name TEXT NOT NULL,
    phone_e164 TEXT,
    vehicle_type TEXT NOT NULL DEFAULT 'motorcycle',
    vehicle_plate TEXT,
    courier_status merchant_erp_status_enum NOT NULL DEFAULT 'ACTIVE',
    tracking_policy_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_merchant_erp_couriers_merchant
        FOREIGN KEY (merchant_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_merchant_erp_couriers_user
        FOREIGN KEY (courier_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT ux_merchant_erp_couriers_user UNIQUE (merchant_user_id, courier_user_id),
    CONSTRAINT chk_merchant_erp_couriers_display CHECK (btrim(display_name) <> ''),
    CONSTRAINT chk_merchant_erp_couriers_phone CHECK (phone_e164 IS NULL OR phone_e164 ~ '^\+[1-9][0-9]{7,14}$'),
    CONSTRAINT chk_merchant_erp_couriers_tracking CHECK (jsonb_typeof(tracking_policy_json) = 'object')
);

CREATE TABLE IF NOT EXISTS merchant_erp_delivery_assignments (
    merchant_erp_delivery_assignment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_user_id UUID NOT NULL,
    order_id UUID,
    order_pipeline_id UUID,
    courier_profile_id UUID,
    tracking_code TEXT NOT NULL,
    delivery_status merchant_erp_delivery_status_enum NOT NULL DEFAULT 'ASSIGNED',
    origin_address_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    destination_address_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    recipient_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    assigned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    estimated_delivery_at TIMESTAMPTZ,
    delivered_at TIMESTAMPTZ,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_merchant_erp_delivery_assignments_merchant
        FOREIGN KEY (merchant_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_merchant_erp_delivery_assignments_order
        FOREIGN KEY (order_id) REFERENCES orders (order_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_merchant_erp_delivery_assignments_pipeline
        FOREIGN KEY (order_pipeline_id) REFERENCES merchant_erp_order_pipeline (merchant_erp_order_pipeline_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_merchant_erp_delivery_assignments_courier
        FOREIGN KEY (courier_profile_id) REFERENCES merchant_erp_courier_profiles (merchant_erp_courier_profile_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT ux_merchant_erp_delivery_tracking_code UNIQUE (merchant_user_id, tracking_code),
    CONSTRAINT chk_merchant_erp_delivery_tracking_code CHECK (tracking_code ~ '^[A-Z0-9_-]{6,80}$'),
    CONSTRAINT chk_merchant_erp_delivery_json CHECK (
        jsonb_typeof(origin_address_json) = 'object'
        AND jsonb_typeof(destination_address_json) = 'object'
        AND jsonb_typeof(recipient_json) = 'object'
        AND jsonb_typeof(metadata_json) = 'object'
    )
);

CREATE TABLE IF NOT EXISTS merchant_erp_delivery_tracking_events (
    merchant_erp_delivery_tracking_event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    delivery_assignment_id UUID NOT NULL,
    courier_user_id UUID,
    delivery_status merchant_erp_delivery_status_enum NOT NULL,
    latitude NUMERIC(10,7),
    longitude NUMERIC(10,7),
    accuracy_meters NUMERIC(10,2),
    battery_pct NUMERIC(5,2),
    proof_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    event_payload_hash TEXT NOT NULL,
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    received_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_merchant_erp_delivery_events_assignment
        FOREIGN KEY (delivery_assignment_id) REFERENCES merchant_erp_delivery_assignments (merchant_erp_delivery_assignment_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT fk_merchant_erp_delivery_events_courier
        FOREIGN KEY (courier_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT chk_merchant_erp_delivery_events_lat CHECK (latitude IS NULL OR latitude BETWEEN -90 AND 90),
    CONSTRAINT chk_merchant_erp_delivery_events_lng CHECK (longitude IS NULL OR longitude BETWEEN -180 AND 180),
    CONSTRAINT chk_merchant_erp_delivery_events_battery CHECK (battery_pct IS NULL OR battery_pct BETWEEN 0 AND 100),
    CONSTRAINT chk_merchant_erp_delivery_events_hash CHECK (event_payload_hash ~ '^[a-f0-9]{64}$'),
    CONSTRAINT chk_merchant_erp_delivery_events_proof CHECK (jsonb_typeof(proof_json) = 'object')
);

CREATE TABLE IF NOT EXISTS merchant_erp_product_lifecycle_events (
    merchant_erp_product_lifecycle_event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_user_id UUID NOT NULL,
    actor_user_id UUID,
    item_id UUID,
    sku TEXT,
    product_title TEXT,
    category_key TEXT,
    branch_key TEXT NOT NULL DEFAULT 'global',
    action_key TEXT NOT NULL,
    previous_status TEXT,
    next_status TEXT NOT NULL,
    stock_scope TEXT NOT NULL DEFAULT 'GLOBAL',
    payload_hash TEXT NOT NULL,
    payload_summary_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_merchant_erp_product_events_merchant
        FOREIGN KEY (merchant_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_merchant_erp_product_events_actor
        FOREIGN KEY (actor_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_merchant_erp_product_events_item
        FOREIGN KEY (item_id) REFERENCES inventory_items (item_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT chk_merchant_erp_product_events_action CHECK (
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
            'bulk_branch_sync'
        )
    ),
    CONSTRAINT chk_merchant_erp_product_events_status CHECK (btrim(next_status) <> ''),
    CONSTRAINT chk_merchant_erp_product_events_scope CHECK (stock_scope IN ('GLOBAL', 'REGIONAL', 'LOCAL')),
    CONSTRAINT chk_merchant_erp_product_events_hash CHECK (payload_hash ~ '^[a-f0-9]{64}$'),
    CONSTRAINT chk_merchant_erp_product_events_json CHECK (jsonb_typeof(payload_summary_json) = 'object')
);

CREATE TABLE IF NOT EXISTS merchant_erp_report_query_events (
    merchant_erp_report_query_event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_user_id UUID NOT NULL,
    actor_user_id UUID,
    report_key TEXT NOT NULL,
    period_from TIMESTAMPTZ,
    period_to TIMESTAMPTZ,
    filter_user_id UUID,
    filter_product_id UUID,
    filter_category_key TEXT,
    filter_branch_key TEXT,
    export_format TEXT,
    filters_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    payload_hash TEXT NOT NULL,
    queried_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_merchant_erp_report_events_merchant
        FOREIGN KEY (merchant_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_merchant_erp_report_events_actor
        FOREIGN KEY (actor_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_merchant_erp_report_events_filter_user
        FOREIGN KEY (filter_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_merchant_erp_report_events_filter_product
        FOREIGN KEY (filter_product_id) REFERENCES inventory_items (item_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT chk_merchant_erp_report_events_report CHECK (report_key ~ '^[a-z0-9_-]{2,80}$'),
    CONSTRAINT chk_merchant_erp_report_events_period CHECK (period_to IS NULL OR period_from IS NULL OR period_to >= period_from),
    CONSTRAINT chk_merchant_erp_report_events_export CHECK (export_format IS NULL OR export_format IN ('json', 'csv', 'pdf')),
    CONSTRAINT chk_merchant_erp_report_events_hash CHECK (payload_hash ~ '^[a-f0-9]{64}$'),
    CONSTRAINT chk_merchant_erp_report_events_json CHECK (jsonb_typeof(filters_json) = 'object')
);

CREATE TABLE IF NOT EXISTS merchant_erp_branch_units (
    merchant_erp_branch_unit_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_user_id UUID NOT NULL,
    branch_key TEXT NOT NULL,
    branch_type TEXT NOT NULL DEFAULT 'BRANCH',
    display_name TEXT NOT NULL,
    branch_status merchant_erp_status_enum NOT NULL DEFAULT 'ACTIVE',
    region_code TEXT,
    stock_scope TEXT NOT NULL DEFAULT 'LOCAL',
    can_view_stock_scopes_json JSONB NOT NULL DEFAULT '["LOCAL"]'::JSONB,
    finance_visibility TEXT NOT NULL DEFAULT 'OWN_BRANCH',
    auto_sync_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    address_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    map_center_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_merchant_erp_branch_units_merchant
        FOREIGN KEY (merchant_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT ux_merchant_erp_branch_units_key UNIQUE (merchant_user_id, branch_key),
    CONSTRAINT chk_merchant_erp_branch_units_key CHECK (branch_key ~ '^[a-z0-9_-]{2,80}$'),
    CONSTRAINT chk_merchant_erp_branch_units_type CHECK (branch_type IN ('MATRIX', 'BRANCH', 'WAREHOUSE', 'PICKUP_POINT')),
    CONSTRAINT chk_merchant_erp_branch_units_display CHECK (btrim(display_name) <> ''),
    CONSTRAINT chk_merchant_erp_branch_units_scope CHECK (stock_scope IN ('GLOBAL', 'REGIONAL', 'LOCAL')),
    CONSTRAINT chk_merchant_erp_branch_units_finance CHECK (finance_visibility IN ('ALL_BRANCHES', 'REGIONAL_BRANCHES', 'OWN_BRANCH')),
    CONSTRAINT chk_merchant_erp_branch_units_json CHECK (
        jsonb_typeof(can_view_stock_scopes_json) = 'array'
        AND jsonb_typeof(address_json) = 'object'
        AND jsonb_typeof(map_center_json) = 'object'
        AND jsonb_typeof(metadata_json) = 'object'
    )
);

CREATE TABLE IF NOT EXISTS merchant_erp_branch_stock_policies (
    merchant_erp_branch_stock_policy_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_user_id UUID NOT NULL,
    source_branch_id UUID,
    target_branch_id UUID,
    policy_key TEXT NOT NULL,
    visibility_mode TEXT NOT NULL DEFAULT 'LOCAL',
    auto_sync_products BOOLEAN NOT NULL DEFAULT TRUE,
    auto_sync_prices BOOLEAN NOT NULL DEFAULT TRUE,
    auto_sync_stock BOOLEAN NOT NULL DEFAULT FALSE,
    auto_sync_finance BOOLEAN NOT NULL DEFAULT FALSE,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_merchant_erp_branch_policies_merchant
        FOREIGN KEY (merchant_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_merchant_erp_branch_policies_source
        FOREIGN KEY (source_branch_id) REFERENCES merchant_erp_branch_units (merchant_erp_branch_unit_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT fk_merchant_erp_branch_policies_target
        FOREIGN KEY (target_branch_id) REFERENCES merchant_erp_branch_units (merchant_erp_branch_unit_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT ux_merchant_erp_branch_policies_key UNIQUE (merchant_user_id, policy_key),
    CONSTRAINT chk_merchant_erp_branch_policies_key CHECK (policy_key ~ '^[a-z0-9_-]{2,80}$'),
    CONSTRAINT chk_merchant_erp_branch_policies_mode CHECK (visibility_mode IN ('GLOBAL', 'REGIONAL', 'LOCAL')),
    CONSTRAINT chk_merchant_erp_branch_policies_json CHECK (jsonb_typeof(metadata_json) = 'object')
);

CREATE TABLE IF NOT EXISTS merchant_erp_branch_events (
    merchant_erp_branch_event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_user_id UUID NOT NULL,
    actor_user_id UUID,
    branch_key TEXT NOT NULL,
    action_key TEXT NOT NULL,
    payload_hash TEXT NOT NULL,
    payload_summary_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_merchant_erp_branch_events_merchant
        FOREIGN KEY (merchant_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_merchant_erp_branch_events_actor
        FOREIGN KEY (actor_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT chk_merchant_erp_branch_events_key CHECK (branch_key ~ '^[a-z0-9_-]{2,80}$'),
    CONSTRAINT chk_merchant_erp_branch_events_action CHECK (btrim(action_key) <> ''),
    CONSTRAINT chk_merchant_erp_branch_events_hash CHECK (payload_hash ~ '^[a-f0-9]{64}$'),
    CONSTRAINT chk_merchant_erp_branch_events_json CHECK (jsonb_typeof(payload_summary_json) = 'object')
);

CREATE INDEX IF NOT EXISTS ix_merchant_erp_connector_events_status
    ON merchant_erp_connector_sync_events (merchant_user_id, provider_key, event_status, received_at DESC);

CREATE INDEX IF NOT EXISTS ix_merchant_erp_nfe_items_batch
    ON merchant_erp_nfe_items (nfe_import_batch_id);

CREATE INDEX IF NOT EXISTS ix_merchant_erp_bookings_agenda
    ON merchant_erp_service_bookings (merchant_user_id, resource_id, starts_at, booking_status);

CREATE INDEX IF NOT EXISTS ix_merchant_erp_delivery_status
    ON merchant_erp_delivery_assignments (merchant_user_id, delivery_status, assigned_at DESC);

CREATE INDEX IF NOT EXISTS ix_merchant_erp_delivery_events_time
    ON merchant_erp_delivery_tracking_events (delivery_assignment_id, occurred_at DESC);

CREATE INDEX IF NOT EXISTS ix_merchant_erp_product_events_scope
    ON merchant_erp_product_lifecycle_events (merchant_user_id, branch_key, category_key, occurred_at DESC);

CREATE INDEX IF NOT EXISTS ix_merchant_erp_report_events_scope
    ON merchant_erp_report_query_events (merchant_user_id, report_key, queried_at DESC);

CREATE INDEX IF NOT EXISTS ix_merchant_erp_branch_units_scope
    ON merchant_erp_branch_units (merchant_user_id, branch_status, stock_scope, region_code);

CREATE INDEX IF NOT EXISTS ix_merchant_erp_branch_policies_scope
    ON merchant_erp_branch_stock_policies (merchant_user_id, visibility_mode, updated_at DESC);

CREATE INDEX IF NOT EXISTS ix_merchant_erp_branch_events_scope
    ON merchant_erp_branch_events (merchant_user_id, branch_key, occurred_at DESC);

INSERT INTO merchant_erp_connector_catalog (
    provider_key,
    provider_label,
    connector_family,
    direction_mode,
    docs_url,
    webhook_path,
    credential_policy_json,
    capabilities_json,
    recommended_for_json,
    connector_status
)
VALUES
    ('mercado_livre', 'Mercado Livre', 'MARKETPLACE', 'BIDIRECTIONAL', 'https://developers.mercadolivre.com.br/pt_br/api-docs', '/integrations/mercadolivre/notifications', '{"secret_policy":"runtime_vault_only"}', '["catalog_publish","stock_update","order_import","shipping_tracking_import","financial_reconciliation"]', '["ecommerce","marketplace","varejo"]', 'ACTIVE'),
    ('shopee', 'Shopee', 'MARKETPLACE', 'BIDIRECTIONAL', 'https://open.shopee.com/developer-guide/', '/integrations/shopee/notifications', '{"secret_policy":"runtime_vault_only","auth":"partner_oauth_signed_request"}', '["catalog_publish","stock_update","order_import","shipping_tracking_import","escrow_financial_import"]', '["marketplace","varejo"]', 'DRAFT'),
    ('olx', 'OLX', 'CLASSIFIEDS', 'BIDIRECTIONAL', 'https://developers.olx.com.br/anuncio/api/home.html', '/integrations/olx/notifications', '{"secret_policy":"runtime_vault_only","requires_partner_plan":true}', '["listing_create","listing_update","listing_delete","listing_status_import","lead_import","chat_import"]', '["classificados","veiculos","imoveis","usados"]', 'DRAFT'),
    ('ifood', 'iFood', 'FOOD_DELIVERY', 'BIDIRECTIONAL', 'https://developer.ifood.com.br/pt-BR/docs/guides/modules/order/events', '/integrations/ifood/notifications', '{"secret_policy":"runtime_vault_only","polling_cadence_seconds":30}', '["menu_sync","order_event_polling","order_event_webhook","order_acknowledgment","order_status_update","financial_event_import"]', '["restaurante","mercado","delivery"]', 'DRAFT'),
    ('ze_delivery', 'Ze Delivery', 'BEVERAGE_DELIVERY', 'BIDIRECTIONAL', 'https://seller-public-api.ze.delivery/docs', '/integrations/ze-delivery/notifications', '{"secret_policy":"runtime_vault_only","requires_contract":true}', '["catalog_sync","availability_sync","order_import","order_status_update","delivery_tracking_update","age_control_metadata"]', '["bebidas","conveniencia","delivery"]', 'DRAFT'),
    ('whatsapp_business', 'WhatsApp Business Platform', 'COMMUNICATION', 'BIDIRECTIONAL', 'https://developers.facebook.com/docs/whatsapp/cloud-api', '/integrations/whatsapp/notifications', '{"secret_policy":"runtime_vault_only"}', '["catalog_link_message","order_status_notification","delivery_tracking_notification","customer_support_thread"]', '["atendimento","pos-venda","delivery"]', 'DRAFT'),
    ('nuvemshop', 'Nuvemshop', 'STOREFRONT', 'BIDIRECTIONAL', 'https://tiendanube.github.io/api-documentation/', '/integrations/nuvemshop/notifications', '{"secret_policy":"runtime_vault_only"}', '["catalog_publish","stock_update","order_import","order_status_update","storefront_sync"]', '["loja_propria","ecommerce"]', 'DRAFT'),
    ('google_business_profile', 'Google Business Profile', 'BOOKING', 'OUTBOUND', 'https://developers.google.com/my-business', '/integrations/google-business/notifications', '{"secret_policy":"runtime_vault_only"}', '["business_profile_sync","local_service_visibility","booking_link_publish"]', '["servicos_locais","agenda","barbearia","clinica"]', 'DRAFT')
ON CONFLICT (provider_key) DO UPDATE
SET
    provider_label = EXCLUDED.provider_label,
    connector_family = EXCLUDED.connector_family,
    direction_mode = EXCLUDED.direction_mode,
    docs_url = EXCLUDED.docs_url,
    webhook_path = EXCLUDED.webhook_path,
    credential_policy_json = merchant_erp_connector_catalog.credential_policy_json || EXCLUDED.credential_policy_json,
    capabilities_json = EXCLUDED.capabilities_json,
    recommended_for_json = EXCLUDED.recommended_for_json,
    updated_at = NOW();

CREATE OR REPLACE VIEW v_merchant_erp_connector_readiness AS
SELECT
    catalog.provider_key,
    catalog.provider_label,
    catalog.connector_family,
    catalog.direction_mode,
    catalog.connector_status,
    catalog.webhook_path,
    jsonb_array_length(catalog.capabilities_json) AS capabilities_total,
    COUNT(events.merchant_erp_connector_sync_event_id) AS recent_events_total,
    MAX(events.received_at) AS last_event_at
FROM merchant_erp_connector_catalog catalog
LEFT JOIN merchant_erp_connector_sync_events events
  ON events.provider_key = catalog.provider_key
 AND events.received_at > NOW() - INTERVAL '7 days'
GROUP BY
    catalog.provider_key,
    catalog.provider_label,
    catalog.connector_family,
    catalog.direction_mode,
    catalog.connector_status,
    catalog.webhook_path,
    catalog.capabilities_json;

CREATE OR REPLACE VIEW v_merchant_erp_service_agenda AS
SELECT
    booking.merchant_user_id,
    resource.resource_key,
    resource.resource_type,
    resource.display_name AS resource_name,
    booking.merchant_erp_service_booking_id,
    booking.customer_name,
    booking.service_key,
    booking.service_label,
    booking.booking_status,
    booking.starts_at,
    booking.ends_at,
    booking.source_channel,
    booking.external_booking_id
FROM merchant_erp_service_bookings booking
JOIN merchant_erp_service_resources resource
  ON resource.merchant_erp_service_resource_id = booking.resource_id;

CREATE OR REPLACE VIEW v_merchant_erp_delivery_tracking AS
SELECT
    assignment.merchant_user_id,
    assignment.merchant_erp_delivery_assignment_id,
    assignment.order_id,
    assignment.tracking_code,
    assignment.delivery_status AS current_status,
    courier.display_name AS courier_name,
    latest_event.latitude,
    latest_event.longitude,
    latest_event.occurred_at AS last_location_at,
    assignment.assigned_at,
    assignment.estimated_delivery_at,
    assignment.delivered_at
FROM merchant_erp_delivery_assignments assignment
LEFT JOIN merchant_erp_courier_profiles courier
  ON courier.merchant_erp_courier_profile_id = assignment.courier_profile_id
LEFT JOIN LATERAL (
    SELECT event.latitude, event.longitude, event.occurred_at
    FROM merchant_erp_delivery_tracking_events event
    WHERE event.delivery_assignment_id = assignment.merchant_erp_delivery_assignment_id
    ORDER BY event.occurred_at DESC
    LIMIT 1
) latest_event ON TRUE;

CREATE OR REPLACE VIEW v_merchant_erp_product_lifecycle AS
SELECT
    event.merchant_user_id,
    event.branch_key,
    event.sku,
    event.product_title,
    event.category_key,
    event.action_key,
    event.previous_status,
    event.next_status,
    event.stock_scope,
    event.occurred_at
FROM merchant_erp_product_lifecycle_events event;

CREATE OR REPLACE VIEW v_merchant_erp_report_query_history AS
SELECT
    event.merchant_user_id,
    event.report_key,
    event.period_from,
    event.period_to,
    event.filter_user_id,
    event.filter_product_id,
    event.filter_category_key,
    event.filter_branch_key,
    event.export_format,
    event.queried_at
FROM merchant_erp_report_query_events event;

CREATE OR REPLACE VIEW v_merchant_erp_branch_control AS
SELECT
    branch.merchant_user_id,
    branch.branch_key,
    branch.branch_type,
    branch.display_name,
    branch.branch_status,
    branch.region_code,
    branch.stock_scope,
    branch.finance_visibility,
    branch.auto_sync_enabled,
    COUNT(policy.merchant_erp_branch_stock_policy_id) AS policies_total
FROM merchant_erp_branch_units branch
LEFT JOIN merchant_erp_branch_stock_policies policy
  ON policy.merchant_user_id = branch.merchant_user_id
 AND (
    policy.source_branch_id = branch.merchant_erp_branch_unit_id
    OR policy.target_branch_id = branch.merchant_erp_branch_unit_id
 )
GROUP BY
    branch.merchant_user_id,
    branch.branch_key,
    branch.branch_type,
    branch.display_name,
    branch.branch_status,
    branch.region_code,
    branch.stock_scope,
    branch.finance_visibility,
    branch.auto_sync_enabled;

COMMENT ON TABLE merchant_erp_connector_catalog IS 'Catalogo sem segredos dos conectores externos homologaveis do ERP Lojista Valley.';
COMMENT ON TABLE merchant_erp_connector_sync_events IS 'Trilha append-only de eventos bidirecionais entre ERP Lojista e provedores externos.';
COMMENT ON TABLE merchant_erp_nfe_import_batches IS 'Lotes de importacao NF-e por chave de acesso, XML hash e status fiscal/estoque.';
COMMENT ON TABLE merchant_erp_nfe_items IS 'Itens importados da NF-e para lancamento fiscal e movimentacao de estoque.';
COMMENT ON TABLE merchant_erp_service_resources IS 'Recursos agendaveis do lojista: profissional, sala, cadeira ou equipamento.';
COMMENT ON TABLE merchant_erp_service_bookings IS 'Agenda bidirecional de servicos para clientes e operadores do lojista.';
COMMENT ON TABLE merchant_erp_service_booking_events IS 'Eventos append-only de reserva, remarcacao, check-in, cancelamento e conclusao.';
COMMENT ON TABLE merchant_erp_courier_profiles IS 'Tipo de usuario entregador associado ao lojista para rastreio proprio.';
COMMENT ON TABLE merchant_erp_delivery_assignments IS 'Associacao entre pedido e entregador com codigo de rastreio proprio.';
COMMENT ON TABLE merchant_erp_delivery_tracking_events IS 'Eventos append-only de localizacao e prova de entrega do app do entregador.';
COMMENT ON TABLE merchant_erp_product_lifecycle_events IS 'Eventos auditaveis de cadastro, edicao, exclusao logica, suspensao e publicacao de produtos por lojista e filial.';
COMMENT ON TABLE merchant_erp_report_query_events IS 'Historico append-only de consultas de relatorios filtradas por periodo, usuario, produto, categoria e filial.';
COMMENT ON TABLE merchant_erp_branch_units IS 'Filiais, matriz e pontos operacionais vinculados ao lojista com politica de estoque.';
COMMENT ON TABLE merchant_erp_branch_stock_policies IS 'Politicas de estoque global, regional ou local entre matriz e filiais.';
COMMENT ON TABLE merchant_erp_branch_events IS 'Eventos append-only de criacao, alteracao, suspensao e sincronizacao de filiais.';

COMMIT;
