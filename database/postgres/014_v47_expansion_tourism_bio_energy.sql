-- Valley Hybrid DB Bootstrap - Expansion hybrid bundle v47.
-- Este arquivo fecha os modulos ainda planejados com data home hibrido em PostgreSQL.
-- Ele cria contratos relacionais para TOURISM, BIO e ENERGY, mantendo users, wallets, orders e transactions no centro.
-- Trilhas de booking, coleta reversa e settlement energetico usam append-only quando a prova operacional ou financeira nao pode ser mutada.
-- Execute depois de 013, porque reutiliza event_programs, event_ticket_types, delivery_shipments, mobility_trips e os helpers do core-first.

BEGIN;

SET search_path = public;

CREATE TYPE tourism_experience_kind_enum AS ENUM ('TOUR', 'ATTRACTION', 'PACKAGE', 'GUIDED_ROUTE', 'STAY', 'EVENT_ADDON');
CREATE TYPE tourism_experience_status_enum AS ENUM ('DRAFT', 'ACTIVE', 'PAUSED', 'SOLD_OUT', 'ARCHIVED');
CREATE TYPE tourism_booking_status_enum AS ENUM ('PENDING', 'CONFIRMED', 'CHECKED_IN', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED', 'NO_SHOW', 'REFUNDED');
CREATE TYPE tourism_booking_event_type_enum AS ENUM ('CREATED', 'CONFIRMED', 'CHECKED_IN', 'STARTED', 'COMPLETED', 'CANCELLED', 'NO_SHOW', 'REFUND_REQUESTED', 'REFUNDED', 'INCIDENT_REPORTED');

CREATE TYPE bio_program_status_enum AS ENUM ('DRAFT', 'ACTIVE', 'PAUSED', 'CLOSED', 'ARCHIVED');
CREATE TYPE bio_collection_status_enum AS ENUM ('REQUESTED', 'SCHEDULED', 'IN_TRANSIT', 'COLLECTED', 'VERIFIED', 'REJECTED', 'REWARDED', 'CANCELLED');
CREATE TYPE bio_collection_event_type_enum AS ENUM ('REQUESTED', 'PICKUP_SCHEDULED', 'IN_TRANSIT', 'COLLECTED', 'VERIFIED', 'REJECTED', 'REWARDED', 'CANCELLED', 'TRANSFERRED_TO_PARTNER');

CREATE TYPE energy_asset_status_enum AS ENUM ('DRAFT', 'ACTIVE', 'MAINTENANCE', 'SUSPENDED', 'RETIRED');
CREATE TYPE energy_asset_role_enum AS ENUM ('CONSUMER', 'PRODUCER', 'PROSUMER', 'STORAGE', 'GRID_NODE');
CREATE TYPE energy_trade_side_enum AS ENUM ('SELL', 'BUY', 'BALANCE');
CREATE TYPE energy_trade_status_enum AS ENUM ('OPEN', 'MATCHED', 'CONFIRMED', 'DELIVERING', 'SETTLED', 'CANCELLED', 'EXPIRED', 'DISPUTED');
CREATE TYPE energy_settlement_event_type_enum AS ENUM ('TRADE_OPENED', 'MATCHED', 'DELIVERY_CONFIRMED', 'GRID_FEE_APPLIED', 'CREDIT_ISSUED', 'SETTLED', 'CANCELLED', 'REVERSED');

CREATE TABLE tourism_experiences (
    experience_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_user_id UUID NOT NULL,
    wallet_id UUID NOT NULL,
    module_code TEXT NOT NULL DEFAULT 'TOURISM',
    experience_code TEXT NOT NULL,
    experience_status tourism_experience_status_enum NOT NULL DEFAULT 'DRAFT',
    experience_kind tourism_experience_kind_enum NOT NULL,
    title TEXT NOT NULL,
    summary TEXT,
    base_price_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    deposit_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    capacity_total INTEGER,
    duration_minutes INTEGER,
    city_code TEXT,
    meeting_point_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    route_snapshot_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    event_program_id UUID,
    cover_document_id UUID,
    available_from TIMESTAMPTZ,
    available_until TIMESTAMPTZ,
    ops_notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_tourism_experiences_owner
        FOREIGN KEY (owner_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_tourism_experiences_wallet
        FOREIGN KEY (wallet_id) REFERENCES wallets (wallet_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_tourism_experiences_module
        FOREIGN KEY (module_code) REFERENCES module_delivery_registry (module_code)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_tourism_experiences_event_program
        FOREIGN KEY (event_program_id) REFERENCES event_programs (event_program_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_tourism_experiences_document
        FOREIGN KEY (cover_document_id) REFERENCES document_records (document_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT ux_tourism_experiences_owner_code UNIQUE (owner_user_id, experience_code),
    CONSTRAINT chk_tourism_experiences_module CHECK (module_code = 'TOURISM'),
    CONSTRAINT chk_tourism_experiences_code CHECK (experience_code ~ '^[A-Z0-9_-]{2,80}$'),
    CONSTRAINT chk_tourism_experiences_title CHECK (btrim(title) <> ''),
    CONSTRAINT chk_tourism_experiences_summary CHECK (summary IS NULL OR btrim(summary) <> ''),
    CONSTRAINT chk_tourism_experiences_amounts CHECK (
        base_price_brl >= 0
        AND deposit_brl >= 0
        AND deposit_brl <= base_price_brl
    ),
    CONSTRAINT chk_tourism_experiences_capacity_duration CHECK (
        (capacity_total IS NULL OR capacity_total > 0)
        AND (duration_minutes IS NULL OR duration_minutes > 0)
    ),
    CONSTRAINT chk_tourism_experiences_city_code CHECK (
        city_code IS NULL OR city_code ~ '^[A-Z0-9_-]{2,32}$'
    ),
    CONSTRAINT chk_tourism_experiences_meeting_point_json CHECK (
        jsonb_typeof(meeting_point_json) = 'object'
    ),
    CONSTRAINT chk_tourism_experiences_route_snapshot_json CHECK (
        jsonb_typeof(route_snapshot_json) = 'object'
    ),
    CONSTRAINT chk_tourism_experiences_timeline CHECK (
        available_until IS NULL
        OR available_from IS NULL
        OR available_until >= available_from
    ),
    CONSTRAINT chk_tourism_experiences_ops_notes CHECK (
        ops_notes IS NULL OR btrim(ops_notes) <> ''
    )
);

CREATE TABLE tourism_bookings (
    booking_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    experience_id UUID NOT NULL,
    traveler_user_id UUID NOT NULL,
    wallet_id UUID NOT NULL,
    module_code TEXT NOT NULL DEFAULT 'TOURISM',
    order_id UUID,
    transaction_id UUID,
    mobility_trip_id UUID,
    assigned_guide_user_id UUID,
    event_ticket_type_id UUID,
    booking_code TEXT NOT NULL,
    booking_status tourism_booking_status_enum NOT NULL DEFAULT 'PENDING',
    quantity INTEGER NOT NULL DEFAULT 1,
    unit_price_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    discount_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    total_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    deposit_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    scheduled_start_at TIMESTAMPTZ NOT NULL,
    scheduled_end_at TIMESTAMPTZ,
    checked_in_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,
    cancellation_reason TEXT,
    voucher_document_id UUID,
    guest_manifest_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_tourism_bookings_experience
        FOREIGN KEY (experience_id) REFERENCES tourism_experiences (experience_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_tourism_bookings_traveler
        FOREIGN KEY (traveler_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_tourism_bookings_wallet
        FOREIGN KEY (wallet_id) REFERENCES wallets (wallet_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_tourism_bookings_module
        FOREIGN KEY (module_code) REFERENCES module_delivery_registry (module_code)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_tourism_bookings_order
        FOREIGN KEY (order_id) REFERENCES orders (order_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_tourism_bookings_transaction
        FOREIGN KEY (transaction_id) REFERENCES transactions (transaction_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_tourism_bookings_trip
        FOREIGN KEY (mobility_trip_id) REFERENCES mobility_trips (trip_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_tourism_bookings_guide
        FOREIGN KEY (assigned_guide_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_tourism_bookings_ticket_type
        FOREIGN KEY (event_ticket_type_id) REFERENCES event_ticket_types (event_ticket_type_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_tourism_bookings_document
        FOREIGN KEY (voucher_document_id) REFERENCES document_records (document_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT ux_tourism_bookings_code UNIQUE (booking_code),
    CONSTRAINT chk_tourism_bookings_module CHECK (module_code = 'TOURISM'),
    CONSTRAINT chk_tourism_bookings_code CHECK (booking_code ~ '^[A-Z0-9-]{6,64}$'),
    CONSTRAINT chk_tourism_bookings_amounts CHECK (
        quantity > 0
        AND unit_price_brl >= 0
        AND discount_brl >= 0
        AND total_brl >= 0
        AND deposit_brl >= 0
        AND total_brl = unit_price_brl * quantity - discount_brl
        AND deposit_brl <= total_brl
    ),
    CONSTRAINT chk_tourism_bookings_timeline CHECK (
        (scheduled_end_at IS NULL OR scheduled_end_at >= scheduled_start_at)
        AND (checked_in_at IS NULL OR checked_in_at >= scheduled_start_at - INTERVAL '12 hours')
        AND (completed_at IS NULL OR completed_at >= scheduled_start_at)
        AND (cancelled_at IS NULL OR cancelled_at >= created_at)
    ),
    CONSTRAINT chk_tourism_bookings_cancellation_reason CHECK (
        cancellation_reason IS NULL OR btrim(cancellation_reason) <> ''
    ),
    CONSTRAINT chk_tourism_bookings_guide CHECK (
        assigned_guide_user_id IS NULL OR assigned_guide_user_id <> traveler_user_id
    ),
    CONSTRAINT chk_tourism_bookings_guest_manifest_json CHECK (
        jsonb_typeof(guest_manifest_json) = 'object'
    ),
    CONSTRAINT chk_tourism_bookings_metadata_json CHECK (
        jsonb_typeof(metadata_json) = 'object'
    )
);

CREATE TABLE tourism_booking_events (
    booking_event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID NOT NULL,
    actor_user_id UUID NOT NULL,
    wallet_id UUID NOT NULL,
    order_id UUID,
    transaction_id UUID,
    mobility_trip_id UUID,
    event_type tourism_booking_event_type_enum NOT NULL,
    event_amount_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    guest_count INTEGER,
    details_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    notes TEXT,
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_tourism_booking_events_booking
        FOREIGN KEY (booking_id) REFERENCES tourism_bookings (booking_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_tourism_booking_events_actor
        FOREIGN KEY (actor_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_tourism_booking_events_wallet
        FOREIGN KEY (wallet_id) REFERENCES wallets (wallet_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_tourism_booking_events_order
        FOREIGN KEY (order_id) REFERENCES orders (order_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_tourism_booking_events_transaction
        FOREIGN KEY (transaction_id) REFERENCES transactions (transaction_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_tourism_booking_events_trip
        FOREIGN KEY (mobility_trip_id) REFERENCES mobility_trips (trip_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT chk_tourism_booking_events_amount CHECK (event_amount_brl >= 0),
    CONSTRAINT chk_tourism_booking_events_guest_count CHECK (
        guest_count IS NULL OR guest_count > 0
    ),
    CONSTRAINT chk_tourism_booking_events_details_json CHECK (
        jsonb_typeof(details_json) = 'object'
    ),
    CONSTRAINT chk_tourism_booking_events_notes CHECK (
        notes IS NULL OR btrim(notes) <> ''
    )
);

CREATE TABLE bio_material_programs (
    program_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_user_id UUID NOT NULL,
    wallet_id UUID NOT NULL,
    module_code TEXT NOT NULL DEFAULT 'BIO',
    program_code TEXT NOT NULL,
    program_status bio_program_status_enum NOT NULL DEFAULT 'DRAFT',
    program_name TEXT NOT NULL,
    material_stream_code TEXT NOT NULL,
    partner_name TEXT,
    reward_mode TEXT NOT NULL DEFAULT 'POINTS_OR_TOKEN',
    target_reduction_kg DECIMAL(18,4) NOT NULL DEFAULT 0,
    co2e_target_kg DECIMAL(18,4) NOT NULL DEFAULT 0,
    default_reward_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    default_reward_nex DECIMAL(18,8) NOT NULL DEFAULT 0,
    pickup_required BOOLEAN NOT NULL DEFAULT TRUE,
    verification_policy_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    document_id UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_bio_material_programs_owner
        FOREIGN KEY (owner_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_bio_material_programs_wallet
        FOREIGN KEY (wallet_id) REFERENCES wallets (wallet_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_bio_material_programs_module
        FOREIGN KEY (module_code) REFERENCES module_delivery_registry (module_code)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_bio_material_programs_document
        FOREIGN KEY (document_id) REFERENCES document_records (document_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT ux_bio_material_programs_owner_code UNIQUE (owner_user_id, program_code),
    CONSTRAINT chk_bio_material_programs_module CHECK (module_code = 'BIO'),
    CONSTRAINT chk_bio_material_programs_code CHECK (program_code ~ '^[A-Z0-9_-]{2,80}$'),
    CONSTRAINT chk_bio_material_programs_name CHECK (btrim(program_name) <> ''),
    CONSTRAINT chk_bio_material_programs_material_stream CHECK (btrim(material_stream_code) <> ''),
    CONSTRAINT chk_bio_material_programs_partner_name CHECK (
        partner_name IS NULL OR btrim(partner_name) <> ''
    ),
    CONSTRAINT chk_bio_material_programs_reward_mode CHECK (btrim(reward_mode) <> ''),
    CONSTRAINT chk_bio_material_programs_amounts CHECK (
        target_reduction_kg >= 0
        AND co2e_target_kg >= 0
        AND default_reward_brl >= 0
        AND default_reward_nex >= 0
    ),
    CONSTRAINT chk_bio_material_programs_verification_policy_json CHECK (
        jsonb_typeof(verification_policy_json) = 'object'
    )
);

CREATE TABLE bio_collection_orders (
    collection_order_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    program_id UUID NOT NULL,
    requester_user_id UUID NOT NULL,
    wallet_id UUID NOT NULL,
    module_code TEXT NOT NULL DEFAULT 'BIO',
    order_id UUID,
    shipment_id UUID,
    assigned_rider_user_id UUID,
    reward_transaction_id UUID,
    collection_code TEXT NOT NULL,
    collection_status bio_collection_status_enum NOT NULL DEFAULT 'REQUESTED',
    material_weight_kg DECIMAL(18,4) NOT NULL DEFAULT 0,
    estimated_reward_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    estimated_reward_nex DECIMAL(18,8) NOT NULL DEFAULT 0,
    verified_reward_brl DECIMAL(18,4),
    verified_reward_nex DECIMAL(18,8),
    co2e_avoided_kg DECIMAL(18,4) NOT NULL DEFAULT 0,
    pickup_address_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    verification_document_id UUID,
    scheduled_pickup_at TIMESTAMPTZ,
    collected_at TIMESTAMPTZ,
    verified_at TIMESTAMPTZ,
    rewarded_at TIMESTAMPTZ,
    notes TEXT,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_bio_collection_orders_program
        FOREIGN KEY (program_id) REFERENCES bio_material_programs (program_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_bio_collection_orders_requester
        FOREIGN KEY (requester_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_bio_collection_orders_wallet
        FOREIGN KEY (wallet_id) REFERENCES wallets (wallet_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_bio_collection_orders_module
        FOREIGN KEY (module_code) REFERENCES module_delivery_registry (module_code)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_bio_collection_orders_order
        FOREIGN KEY (order_id) REFERENCES orders (order_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_bio_collection_orders_shipment
        FOREIGN KEY (shipment_id) REFERENCES delivery_shipments (shipment_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_bio_collection_orders_rider
        FOREIGN KEY (assigned_rider_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_bio_collection_orders_reward_transaction
        FOREIGN KEY (reward_transaction_id) REFERENCES transactions (transaction_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_bio_collection_orders_document
        FOREIGN KEY (verification_document_id) REFERENCES document_records (document_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT ux_bio_collection_orders_code UNIQUE (collection_code),
    CONSTRAINT chk_bio_collection_orders_module CHECK (module_code = 'BIO'),
    CONSTRAINT chk_bio_collection_orders_code CHECK (collection_code ~ '^[A-Z0-9-]{6,64}$'),
    CONSTRAINT chk_bio_collection_orders_values CHECK (
        material_weight_kg >= 0
        AND estimated_reward_brl >= 0
        AND estimated_reward_nex >= 0
        AND co2e_avoided_kg >= 0
        AND (verified_reward_brl IS NULL OR verified_reward_brl >= 0)
        AND (verified_reward_nex IS NULL OR verified_reward_nex >= 0)
    ),
    CONSTRAINT chk_bio_collection_orders_pickup_address_json CHECK (
        jsonb_typeof(pickup_address_json) = 'object'
    ),
    CONSTRAINT chk_bio_collection_orders_metadata_json CHECK (
        jsonb_typeof(metadata_json) = 'object'
    ),
    CONSTRAINT chk_bio_collection_orders_notes CHECK (
        notes IS NULL OR btrim(notes) <> ''
    ),
    CONSTRAINT chk_bio_collection_orders_timeline CHECK (
        (collected_at IS NULL OR scheduled_pickup_at IS NULL OR collected_at >= scheduled_pickup_at)
        AND (verified_at IS NULL OR collected_at IS NULL OR verified_at >= collected_at)
        AND (rewarded_at IS NULL OR verified_at IS NULL OR rewarded_at >= verified_at)
    ),
    CONSTRAINT chk_bio_collection_orders_rider CHECK (
        assigned_rider_user_id IS NULL OR assigned_rider_user_id <> requester_user_id
    )
);

CREATE TABLE bio_collection_events (
    collection_event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    collection_order_id UUID NOT NULL,
    actor_user_id UUID NOT NULL,
    wallet_id UUID NOT NULL,
    transaction_id UUID,
    event_type bio_collection_event_type_enum NOT NULL,
    material_weight_kg DECIMAL(18,4) NOT NULL DEFAULT 0,
    co2e_avoided_kg DECIMAL(18,4) NOT NULL DEFAULT 0,
    reward_amount_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    reward_amount_nex DECIMAL(18,8) NOT NULL DEFAULT 0,
    partner_ref TEXT,
    details_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_bio_collection_events_order
        FOREIGN KEY (collection_order_id) REFERENCES bio_collection_orders (collection_order_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_bio_collection_events_actor
        FOREIGN KEY (actor_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_bio_collection_events_wallet
        FOREIGN KEY (wallet_id) REFERENCES wallets (wallet_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_bio_collection_events_transaction
        FOREIGN KEY (transaction_id) REFERENCES transactions (transaction_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT chk_bio_collection_events_values CHECK (
        material_weight_kg >= 0
        AND co2e_avoided_kg >= 0
        AND reward_amount_brl >= 0
        AND reward_amount_nex >= 0
    ),
    CONSTRAINT chk_bio_collection_events_partner_ref CHECK (
        partner_ref IS NULL OR btrim(partner_ref) <> ''
    ),
    CONSTRAINT chk_bio_collection_events_details_json CHECK (
        jsonb_typeof(details_json) = 'object'
    )
);

CREATE TABLE energy_assets (
    energy_asset_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_user_id UUID NOT NULL,
    wallet_id UUID NOT NULL,
    module_code TEXT NOT NULL DEFAULT 'ENERGY',
    asset_code TEXT NOT NULL,
    asset_status energy_asset_status_enum NOT NULL DEFAULT 'DRAFT',
    asset_role energy_asset_role_enum NOT NULL,
    title TEXT NOT NULL,
    meter_device_ref TEXT,
    grid_zone_code TEXT NOT NULL,
    installed_capacity_kw DECIMAL(18,4) NOT NULL DEFAULT 0,
    battery_capacity_kwh DECIMAL(18,4) NOT NULL DEFAULT 0,
    last_meter_reading_kwh DECIMAL(18,4) NOT NULL DEFAULT 0,
    settlement_mode TEXT NOT NULL DEFAULT 'NET_METERING',
    document_id UUID,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    last_certified_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_energy_assets_owner
        FOREIGN KEY (owner_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_energy_assets_wallet
        FOREIGN KEY (wallet_id) REFERENCES wallets (wallet_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_energy_assets_module
        FOREIGN KEY (module_code) REFERENCES module_delivery_registry (module_code)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_energy_assets_document
        FOREIGN KEY (document_id) REFERENCES document_records (document_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT ux_energy_assets_owner_code UNIQUE (owner_user_id, asset_code),
    CONSTRAINT chk_energy_assets_module CHECK (module_code = 'ENERGY'),
    CONSTRAINT chk_energy_assets_code CHECK (asset_code ~ '^[A-Z0-9_-]{2,80}$'),
    CONSTRAINT chk_energy_assets_title CHECK (btrim(title) <> ''),
    CONSTRAINT chk_energy_assets_meter_device_ref CHECK (
        meter_device_ref IS NULL OR btrim(meter_device_ref) <> ''
    ),
    CONSTRAINT chk_energy_assets_grid_zone_code CHECK (btrim(grid_zone_code) <> ''),
    CONSTRAINT chk_energy_assets_capacities CHECK (
        installed_capacity_kw >= 0
        AND battery_capacity_kwh >= 0
        AND last_meter_reading_kwh >= 0
    ),
    CONSTRAINT chk_energy_assets_settlement_mode CHECK (btrim(settlement_mode) <> ''),
    CONSTRAINT chk_energy_assets_metadata_json CHECK (
        jsonb_typeof(metadata_json) = 'object'
    ),
    CONSTRAINT chk_energy_assets_role_capacity CHECK (
        asset_role NOT IN ('PRODUCER', 'PROSUMER', 'STORAGE')
        OR installed_capacity_kw > 0
        OR battery_capacity_kwh > 0
    )
);

CREATE TABLE energy_trade_orders (
    trade_order_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_asset_id UUID NOT NULL,
    initiator_user_id UUID NOT NULL,
    counterparty_user_id UUID,
    wallet_id UUID NOT NULL,
    module_code TEXT NOT NULL DEFAULT 'ENERGY',
    order_id UUID,
    settlement_transaction_id UUID,
    trade_code TEXT NOT NULL,
    trade_side energy_trade_side_enum NOT NULL DEFAULT 'SELL',
    trade_status energy_trade_status_enum NOT NULL DEFAULT 'OPEN',
    counterparty_asset_id UUID,
    delivery_start_at TIMESTAMPTZ NOT NULL,
    delivery_end_at TIMESTAMPTZ NOT NULL,
    energy_quantity_kwh DECIMAL(18,4) NOT NULL,
    unit_price_brl DECIMAL(18,4) NOT NULL,
    gross_amount_brl DECIMAL(18,4) NOT NULL,
    grid_fee_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    carbon_credit_nex DECIMAL(18,8) NOT NULL DEFAULT 0,
    matched_at TIMESTAMPTZ,
    settled_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,
    cancellation_reason TEXT,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_energy_trade_orders_source_asset
        FOREIGN KEY (source_asset_id) REFERENCES energy_assets (energy_asset_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_energy_trade_orders_initiator
        FOREIGN KEY (initiator_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_energy_trade_orders_counterparty
        FOREIGN KEY (counterparty_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_energy_trade_orders_wallet
        FOREIGN KEY (wallet_id) REFERENCES wallets (wallet_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_energy_trade_orders_module
        FOREIGN KEY (module_code) REFERENCES module_delivery_registry (module_code)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_energy_trade_orders_order
        FOREIGN KEY (order_id) REFERENCES orders (order_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_energy_trade_orders_transaction
        FOREIGN KEY (settlement_transaction_id) REFERENCES transactions (transaction_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_energy_trade_orders_counterparty_asset
        FOREIGN KEY (counterparty_asset_id) REFERENCES energy_assets (energy_asset_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT ux_energy_trade_orders_code UNIQUE (trade_code),
    CONSTRAINT chk_energy_trade_orders_module CHECK (module_code = 'ENERGY'),
    CONSTRAINT chk_energy_trade_orders_code CHECK (trade_code ~ '^[A-Z0-9-]{6,64}$'),
    CONSTRAINT chk_energy_trade_orders_values CHECK (
        energy_quantity_kwh > 0
        AND unit_price_brl >= 0
        AND gross_amount_brl = energy_quantity_kwh * unit_price_brl
        AND grid_fee_brl >= 0
        AND grid_fee_brl <= gross_amount_brl
        AND carbon_credit_nex >= 0
    ),
    CONSTRAINT chk_energy_trade_orders_timeline CHECK (
        delivery_end_at >= delivery_start_at
        AND (matched_at IS NULL OR matched_at >= created_at)
        AND (settled_at IS NULL OR settled_at >= created_at)
        AND (cancelled_at IS NULL OR cancelled_at >= created_at)
    ),
    CONSTRAINT chk_energy_trade_orders_counterparty CHECK (
        counterparty_user_id IS NULL OR counterparty_user_id <> initiator_user_id
    ),
    CONSTRAINT chk_energy_trade_orders_counterparty_asset CHECK (
        counterparty_asset_id IS NULL OR counterparty_asset_id <> source_asset_id
    ),
    CONSTRAINT chk_energy_trade_orders_cancellation_reason CHECK (
        cancellation_reason IS NULL OR btrim(cancellation_reason) <> ''
    ),
    CONSTRAINT chk_energy_trade_orders_metadata_json CHECK (
        jsonb_typeof(metadata_json) = 'object'
    )
);

CREATE TABLE energy_settlement_ledger (
    settlement_entry_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trade_order_id UUID NOT NULL,
    actor_user_id UUID NOT NULL,
    wallet_id UUID NOT NULL,
    transaction_id UUID,
    event_type energy_settlement_event_type_enum NOT NULL,
    energy_quantity_kwh DECIMAL(18,4) NOT NULL DEFAULT 0,
    settlement_amount_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    carbon_credit_nex DECIMAL(18,8) NOT NULL DEFAULT 0,
    meter_reading_hash TEXT,
    details_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_energy_settlement_ledger_trade_order
        FOREIGN KEY (trade_order_id) REFERENCES energy_trade_orders (trade_order_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_energy_settlement_ledger_actor
        FOREIGN KEY (actor_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_energy_settlement_ledger_wallet
        FOREIGN KEY (wallet_id) REFERENCES wallets (wallet_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_energy_settlement_ledger_transaction
        FOREIGN KEY (transaction_id) REFERENCES transactions (transaction_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT chk_energy_settlement_ledger_values CHECK (
        energy_quantity_kwh >= 0
        AND settlement_amount_brl >= 0
        AND carbon_credit_nex >= 0
    ),
    CONSTRAINT chk_energy_settlement_ledger_hash CHECK (
        meter_reading_hash IS NULL OR meter_reading_hash ~ '^[a-fA-F0-9]{64,128}$'
    ),
    CONSTRAINT chk_energy_settlement_ledger_details_json CHECK (
        jsonb_typeof(details_json) = 'object'
    )
);

CREATE INDEX ix_tourism_experiences_owner_status
    ON tourism_experiences (owner_user_id, experience_status);

CREATE INDEX ix_tourism_experiences_event_program
    ON tourism_experiences (event_program_id)
    WHERE event_program_id IS NOT NULL;

CREATE INDEX ix_tourism_bookings_experience_status
    ON tourism_bookings (experience_id, booking_status);

CREATE INDEX ix_tourism_bookings_traveler_status
    ON tourism_bookings (traveler_user_id, booking_status);

CREATE INDEX ix_tourism_bookings_trip
    ON tourism_bookings (mobility_trip_id)
    WHERE mobility_trip_id IS NOT NULL;

CREATE INDEX ix_tourism_booking_events_booking_occurred_at
    ON tourism_booking_events (booking_id, occurred_at);

CREATE INDEX ix_bio_material_programs_owner_status
    ON bio_material_programs (owner_user_id, program_status);

CREATE INDEX ix_bio_collection_orders_program_status
    ON bio_collection_orders (program_id, collection_status);

CREATE INDEX ix_bio_collection_orders_requester_status
    ON bio_collection_orders (requester_user_id, collection_status);

CREATE INDEX ix_bio_collection_orders_shipment
    ON bio_collection_orders (shipment_id)
    WHERE shipment_id IS NOT NULL;

CREATE INDEX ix_bio_collection_events_order_occurred_at
    ON bio_collection_events (collection_order_id, occurred_at);

CREATE INDEX ix_energy_assets_owner_status
    ON energy_assets (owner_user_id, asset_status);

CREATE INDEX ix_energy_assets_grid_zone
    ON energy_assets (grid_zone_code, asset_status);

CREATE INDEX ix_energy_trade_orders_source_status
    ON energy_trade_orders (source_asset_id, trade_status);

CREATE INDEX ix_energy_trade_orders_initiator_status
    ON energy_trade_orders (initiator_user_id, trade_status);

CREATE INDEX ix_energy_trade_orders_counterparty_status
    ON energy_trade_orders (counterparty_user_id, trade_status)
    WHERE counterparty_user_id IS NOT NULL;

CREATE INDEX ix_energy_trade_orders_delivery_window
    ON energy_trade_orders (delivery_start_at, delivery_end_at, trade_status);

CREATE INDEX ix_energy_settlement_ledger_trade_occurred_at
    ON energy_settlement_ledger (trade_order_id, occurred_at);

CREATE INDEX ix_energy_settlement_ledger_transaction
    ON energy_settlement_ledger (transaction_id)
    WHERE transaction_id IS NOT NULL;

CREATE TRIGGER trg_tourism_experiences_set_updated_at
BEFORE UPDATE ON tourism_experiences
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_tourism_bookings_set_updated_at
BEFORE UPDATE ON tourism_bookings
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_bio_material_programs_set_updated_at
BEFORE UPDATE ON bio_material_programs
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_bio_collection_orders_set_updated_at
BEFORE UPDATE ON bio_collection_orders
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_energy_assets_set_updated_at
BEFORE UPDATE ON energy_assets
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_energy_trade_orders_set_updated_at
BEFORE UPDATE ON energy_trade_orders
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_tourism_booking_events_prevent_update
BEFORE UPDATE ON tourism_booking_events
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

CREATE TRIGGER trg_tourism_booking_events_prevent_delete
BEFORE DELETE ON tourism_booking_events
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

CREATE TRIGGER trg_bio_collection_events_prevent_update
BEFORE UPDATE ON bio_collection_events
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

CREATE TRIGGER trg_bio_collection_events_prevent_delete
BEFORE DELETE ON bio_collection_events
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

CREATE TRIGGER trg_energy_settlement_ledger_prevent_update
BEFORE UPDATE ON energy_settlement_ledger
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

CREATE TRIGGER trg_energy_settlement_ledger_prevent_delete
BEFORE DELETE ON energy_settlement_ledger
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

COMMENT ON TABLE tourism_experiences IS 'Catalogo relacional de experiencias turisticas, passeios e pacotes com ancora em user e wallet.';
COMMENT ON TABLE tourism_bookings IS 'Bookings de turismo integrados a order, transaction, mobility e ingressos quando existir acoplamento.';
COMMENT ON TABLE tourism_booking_events IS 'Trilha append-only do lifecycle do booking turistico.';
COMMENT ON TABLE bio_material_programs IS 'Programas de sustentabilidade e logistica reversa com regra de recompensa e prova documental.';
COMMENT ON TABLE bio_collection_orders IS 'Ordens de coleta reversa que conectam usuario, entrega, validacao e recompensa.';
COMMENT ON TABLE bio_collection_events IS 'Trilha append-only das mutacoes de coleta, verificacao e recompensa bio.';
COMMENT ON TABLE energy_assets IS 'Ativos energeticos, medidores e nodos de liquidacao P2P do modulo Energy.';
COMMENT ON TABLE energy_trade_orders IS 'Ordens de trade energetico com janela de entrega, precificacao e settlement relacional.';
COMMENT ON TABLE energy_settlement_ledger IS 'Ledger append-only dos eventos de settlement, credito e reversao energetica.';

COMMENT ON TRIGGER trg_tourism_booking_events_prevent_update ON tourism_booking_events IS 'Impede UPDATE na trilha append-only de bookings de turismo.';
COMMENT ON TRIGGER trg_tourism_booking_events_prevent_delete ON tourism_booking_events IS 'Impede DELETE na trilha append-only de bookings de turismo.';
COMMENT ON TRIGGER trg_bio_collection_events_prevent_update ON bio_collection_events IS 'Impede UPDATE na trilha append-only bio.';
COMMENT ON TRIGGER trg_bio_collection_events_prevent_delete ON bio_collection_events IS 'Impede DELETE na trilha append-only bio.';
COMMENT ON TRIGGER trg_energy_settlement_ledger_prevent_update ON energy_settlement_ledger IS 'Impede UPDATE no ledger append-only de settlement energetico.';
COMMENT ON TRIGGER trg_energy_settlement_ledger_prevent_delete ON energy_settlement_ledger IS 'Impede DELETE no ledger append-only de settlement energetico.';

COMMIT;
