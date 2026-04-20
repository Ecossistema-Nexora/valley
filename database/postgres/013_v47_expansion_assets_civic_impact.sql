-- Valley Hybrid DB Bootstrap - Expansion relational bundle v47.
-- Este arquivo continua a trilha apos o fechamento do tier core e cobre os modulos expansion com data home primario em PostgreSQL.
-- Ele cria contratos para DIGITAL, REAL_ESTATE, EDU, VET, GOV, CHARITY e INSURANCE com FKs para users, wallets, docs, legal e transactions.
-- Trilhas de propriedade, requests civicos, fundos sociais e claims de seguro usam padrao append-only quando a prova operacional nao pode ser mutada.
-- Execute depois de 012, porque reutiliza service_bookings, pharmacy_catalog_items, document_records, legal_contracts, security_incidents e delivery/mobility.

BEGIN;

SET search_path = public;

CREATE TYPE digital_asset_status_enum AS ENUM ('DRAFT', 'MINTED', 'LISTED', 'LOCKED', 'TRANSFERRED', 'ARCHIVED', 'BURNED');
CREATE TYPE digital_asset_event_type_enum AS ENUM ('MINTED', 'LISTED', 'UNLISTED', 'TRANSFERRED', 'ROYALTY_ACCRUED', 'LOCKED', 'UNLOCKED', 'BURNED');

CREATE TYPE real_estate_property_type_enum AS ENUM ('HOUSE', 'APARTMENT', 'LAND', 'COMMERCIAL', 'WAREHOUSE', 'MIXED_USE');
CREATE TYPE real_estate_property_status_enum AS ENUM ('DRAFT', 'ACTIVE', 'UNDER_REVIEW', 'LISTED', 'UNDER_CONTRACT', 'SOLD', 'LEASED', 'ARCHIVED');
CREATE TYPE real_estate_listing_type_enum AS ENUM ('SALE', 'RENT', 'FRACTIONAL_SALE');
CREATE TYPE real_estate_listing_status_enum AS ENUM ('DRAFT', 'ACTIVE', 'PAUSED', 'UNDER_NEGOTIATION', 'CLOSED', 'CANCELLED', 'ARCHIVED');
CREATE TYPE real_estate_deal_status_enum AS ENUM ('PENDING_DUE_DILIGENCE', 'ACTIVE_ESCROW', 'CLOSED', 'CANCELLED', 'DEFAULTED');

CREATE TYPE edu_learning_path_status_enum AS ENUM ('DRAFT', 'ACTIVE', 'PAUSED', 'COMPLETED', 'ARCHIVED');
CREATE TYPE edu_unit_type_enum AS ENUM ('LESSON', 'LIVE_CLASS', 'ASSESSMENT', 'PROJECT', 'CERTIFICATION');
CREATE TYPE edu_enrollment_status_enum AS ENUM ('ENROLLED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED', 'FAILED');

CREATE TYPE vet_pet_status_enum AS ENUM ('ACTIVE', 'MONITORED', 'IN_TREATMENT', 'ARCHIVED');
CREATE TYPE vet_case_status_enum AS ENUM ('OPEN', 'IN_TREATMENT', 'REFERRED', 'CLOSED', 'CANCELLED');
CREATE TYPE vet_prescription_status_enum AS ENUM ('ISSUED', 'ACTIVE', 'FULFILLED', 'EXPIRED', 'CANCELLED');

CREATE TYPE gov_service_status_enum AS ENUM ('DRAFT', 'ACTIVE', 'PAUSED', 'DEPRECATED', 'ARCHIVED');
CREATE TYPE gov_request_status_enum AS ENUM ('SUBMITTED', 'UNDER_REVIEW', 'ACTION_REQUIRED', 'APPROVED', 'REJECTED', 'FULFILLED', 'CANCELLED');
CREATE TYPE gov_request_event_type_enum AS ENUM ('SUBMITTED', 'DOCUMENT_ADDED', 'UNDER_REVIEW', 'ACTION_REQUIRED', 'APPROVED', 'REJECTED', 'FULFILLED', 'CANCELLED');

CREATE TYPE charity_cause_status_enum AS ENUM ('DRAFT', 'ACTIVE', 'PAUSED', 'FUNDED', 'CLOSED', 'ARCHIVED');
CREATE TYPE charity_grant_status_enum AS ENUM ('REQUESTED', 'UNDER_REVIEW', 'APPROVED', 'REJECTED', 'DISBURSED', 'CANCELLED');
CREATE TYPE charity_fund_event_type_enum AS ENUM ('DONATION_RECEIVED', 'MATCH_FUNDED', 'GRANT_RESERVED', 'GRANT_DISBURSED', 'REFUND_ISSUED', 'REVERSAL');

CREATE TYPE insurance_product_status_enum AS ENUM ('DRAFT', 'ACTIVE', 'PAUSED', 'RETIRED', 'ARCHIVED');
CREATE TYPE insurance_policy_status_enum AS ENUM ('QUOTED', 'ACTIVE', 'PAST_DUE', 'CANCELLED', 'EXPIRED', 'CLAIMED');
CREATE TYPE insurance_claim_status_enum AS ENUM ('SUBMITTED', 'UNDER_REVIEW', 'APPROVED', 'REJECTED', 'PAID', 'CLOSED', 'CANCELLED');
CREATE TYPE insurance_claim_event_type_enum AS ENUM ('SUBMITTED', 'EVIDENCE_ADDED', 'UNDER_REVIEW', 'APPROVED', 'REJECTED', 'PAID', 'CLOSED', 'CANCELLED');

CREATE TABLE digital_asset_collections (
    collection_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    creator_user_id UUID NOT NULL,
    wallet_id UUID NOT NULL,
    module_code TEXT NOT NULL DEFAULT 'DIGITAL',
    collection_code TEXT NOT NULL,
    collection_name TEXT NOT NULL,
    asset_standard TEXT NOT NULL DEFAULT 'ERC-1155',
    network_code TEXT NOT NULL,
    custody_mode TEXT NOT NULL DEFAULT 'PLATFORM_ESCROW',
    royalty_bps INTEGER NOT NULL DEFAULT 0,
    supply_cap BIGINT,
    base_uri TEXT,
    rights_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    document_id UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_digital_asset_collections_creator
        FOREIGN KEY (creator_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_digital_asset_collections_wallet
        FOREIGN KEY (wallet_id) REFERENCES wallets (wallet_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_digital_asset_collections_module
        FOREIGN KEY (module_code) REFERENCES module_delivery_registry (module_code)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_digital_asset_collections_document
        FOREIGN KEY (document_id) REFERENCES document_records (document_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT ux_digital_asset_collections_creator_code UNIQUE (creator_user_id, collection_code),
    CONSTRAINT chk_digital_asset_collections_module CHECK (module_code = 'DIGITAL'),
    CONSTRAINT chk_digital_asset_collections_code CHECK (collection_code ~ '^[A-Z0-9_-]{2,80}$'),
    CONSTRAINT chk_digital_asset_collections_name CHECK (btrim(collection_name) <> ''),
    CONSTRAINT chk_digital_asset_collections_standard CHECK (btrim(asset_standard) <> ''),
    CONSTRAINT chk_digital_asset_collections_network CHECK (btrim(network_code) <> ''),
    CONSTRAINT chk_digital_asset_collections_custody CHECK (btrim(custody_mode) <> ''),
    CONSTRAINT chk_digital_asset_collections_royalty CHECK (royalty_bps BETWEEN 0 AND 10000),
    CONSTRAINT chk_digital_asset_collections_supply CHECK (supply_cap IS NULL OR supply_cap > 0),
    CONSTRAINT chk_digital_asset_collections_base_uri CHECK (
        base_uri IS NULL OR base_uri ~ '^(https://|ipfs://)'
    ),
    CONSTRAINT chk_digital_asset_collections_rights_json CHECK (jsonb_typeof(rights_json) = 'object'),
    CONSTRAINT chk_digital_asset_collections_metadata_json CHECK (jsonb_typeof(metadata_json) = 'object')
);

CREATE TABLE digital_assets (
    digital_asset_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    collection_id UUID NOT NULL,
    creator_user_id UUID NOT NULL,
    current_owner_user_id UUID NOT NULL,
    custody_wallet_id UUID NOT NULL,
    module_code TEXT NOT NULL DEFAULT 'DIGITAL',
    asset_code TEXT NOT NULL,
    token_id TEXT NOT NULL,
    asset_status digital_asset_status_enum NOT NULL DEFAULT 'DRAFT',
    asset_kind TEXT NOT NULL DEFAULT 'NFT',
    metadata_uri TEXT,
    preview_url TEXT,
    checksum_sha256 TEXT,
    fractional_supply_nex DECIMAL(18,8) NOT NULL DEFAULT 0,
    mint_transaction_id UUID,
    latest_transaction_id UUID,
    origin_document_id UUID,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    minted_at TIMESTAMPTZ,
    locked_until TIMESTAMPTZ,
    last_transferred_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_digital_assets_collection
        FOREIGN KEY (collection_id) REFERENCES digital_asset_collections (collection_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_digital_assets_creator
        FOREIGN KEY (creator_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_digital_assets_owner
        FOREIGN KEY (current_owner_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_digital_assets_wallet
        FOREIGN KEY (custody_wallet_id) REFERENCES wallets (wallet_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_digital_assets_module
        FOREIGN KEY (module_code) REFERENCES module_delivery_registry (module_code)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_digital_assets_mint_transaction
        FOREIGN KEY (mint_transaction_id) REFERENCES transactions (transaction_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_digital_assets_latest_transaction
        FOREIGN KEY (latest_transaction_id) REFERENCES transactions (transaction_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_digital_assets_document
        FOREIGN KEY (origin_document_id) REFERENCES document_records (document_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT ux_digital_assets_asset_code UNIQUE (asset_code),
    CONSTRAINT ux_digital_assets_collection_token UNIQUE (collection_id, token_id),
    CONSTRAINT chk_digital_assets_module CHECK (module_code = 'DIGITAL'),
    CONSTRAINT chk_digital_assets_code CHECK (asset_code ~ '^[A-Z0-9_-]{2,96}$'),
    CONSTRAINT chk_digital_assets_token CHECK (btrim(token_id) <> ''),
    CONSTRAINT chk_digital_assets_kind CHECK (btrim(asset_kind) <> ''),
    CONSTRAINT chk_digital_assets_metadata_uri CHECK (
        metadata_uri IS NULL OR metadata_uri ~ '^(https://|ipfs://)'
    ),
    CONSTRAINT chk_digital_assets_preview_url CHECK (
        preview_url IS NULL OR preview_url ~ '^(https://|ipfs://)'
    ),
    CONSTRAINT chk_digital_assets_checksum CHECK (
        checksum_sha256 IS NULL OR checksum_sha256 ~ '^[a-fA-F0-9]{64}$'
    ),
    CONSTRAINT chk_digital_assets_fractional_supply CHECK (fractional_supply_nex >= 0),
    CONSTRAINT chk_digital_assets_metadata_json CHECK (jsonb_typeof(metadata_json) = 'object'),
    CONSTRAINT chk_digital_assets_timeline CHECK (
        (locked_until IS NULL OR minted_at IS NULL OR locked_until >= minted_at)
        AND (last_transferred_at IS NULL OR minted_at IS NULL OR last_transferred_at >= minted_at)
    )
);

CREATE TABLE digital_asset_events (
    digital_asset_event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    digital_asset_id UUID NOT NULL,
    actor_user_id UUID NOT NULL,
    wallet_id UUID NOT NULL,
    transaction_id UUID,
    document_id UUID,
    event_type digital_asset_event_type_enum NOT NULL,
    gross_amount_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    royalty_amount_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    gross_amount_nex DECIMAL(18,8) NOT NULL DEFAULT 0,
    notes TEXT,
    event_payload_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_digital_asset_events_asset
        FOREIGN KEY (digital_asset_id) REFERENCES digital_assets (digital_asset_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_digital_asset_events_actor
        FOREIGN KEY (actor_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_digital_asset_events_wallet
        FOREIGN KEY (wallet_id) REFERENCES wallets (wallet_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_digital_asset_events_transaction
        FOREIGN KEY (transaction_id) REFERENCES transactions (transaction_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_digital_asset_events_document
        FOREIGN KEY (document_id) REFERENCES document_records (document_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT chk_digital_asset_events_amounts CHECK (
        gross_amount_brl >= 0
        AND royalty_amount_brl >= 0
        AND gross_amount_nex >= 0
        AND (gross_amount_brl = 0 OR royalty_amount_brl <= gross_amount_brl)
    ),
    CONSTRAINT chk_digital_asset_events_notes CHECK (notes IS NULL OR btrim(notes) <> ''),
    CONSTRAINT chk_digital_asset_events_payload_json CHECK (jsonb_typeof(event_payload_json) = 'object')
);

CREATE TABLE real_estate_properties (
    property_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_user_id UUID NOT NULL,
    wallet_id UUID NOT NULL,
    module_code TEXT NOT NULL DEFAULT 'REAL_ESTATE',
    property_code TEXT NOT NULL,
    property_status real_estate_property_status_enum NOT NULL DEFAULT 'DRAFT',
    property_type real_estate_property_type_enum NOT NULL,
    title TEXT NOT NULL,
    address_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    geolocation_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    appraisal_value_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    target_fractional_supply_nex DECIMAL(18,8) NOT NULL DEFAULT 0,
    bedroom_count INTEGER,
    bathroom_count INTEGER,
    area_sqm DECIMAL(12,2),
    tokenized_asset_id UUID,
    legal_contract_id UUID,
    document_id UUID,
    occupancy_notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_real_estate_properties_owner
        FOREIGN KEY (owner_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_real_estate_properties_wallet
        FOREIGN KEY (wallet_id) REFERENCES wallets (wallet_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_real_estate_properties_module
        FOREIGN KEY (module_code) REFERENCES module_delivery_registry (module_code)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_real_estate_properties_asset
        FOREIGN KEY (tokenized_asset_id) REFERENCES digital_assets (digital_asset_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_real_estate_properties_contract
        FOREIGN KEY (legal_contract_id) REFERENCES legal_contracts (legal_contract_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_real_estate_properties_document
        FOREIGN KEY (document_id) REFERENCES document_records (document_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT ux_real_estate_properties_owner_code UNIQUE (owner_user_id, property_code),
    CONSTRAINT chk_real_estate_properties_module CHECK (module_code = 'REAL_ESTATE'),
    CONSTRAINT chk_real_estate_properties_code CHECK (property_code ~ '^[A-Z0-9_-]{2,80}$'),
    CONSTRAINT chk_real_estate_properties_title CHECK (btrim(title) <> ''),
    CONSTRAINT chk_real_estate_properties_address_json CHECK (jsonb_typeof(address_json) = 'object'),
    CONSTRAINT chk_real_estate_properties_geo_json CHECK (jsonb_typeof(geolocation_json) = 'object'),
    CONSTRAINT chk_real_estate_properties_values CHECK (
        appraisal_value_brl >= 0
        AND target_fractional_supply_nex >= 0
        AND (bedroom_count IS NULL OR bedroom_count >= 0)
        AND (bathroom_count IS NULL OR bathroom_count >= 0)
        AND (area_sqm IS NULL OR area_sqm > 0)
    ),
    CONSTRAINT chk_real_estate_properties_notes CHECK (
        occupancy_notes IS NULL OR btrim(occupancy_notes) <> ''
    )
);

CREATE TABLE real_estate_listings (
    listing_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    property_id UUID NOT NULL,
    seller_user_id UUID NOT NULL,
    wallet_id UUID NOT NULL,
    module_code TEXT NOT NULL DEFAULT 'REAL_ESTATE',
    listing_code TEXT NOT NULL,
    listing_type real_estate_listing_type_enum NOT NULL DEFAULT 'SALE',
    listing_status real_estate_listing_status_enum NOT NULL DEFAULT 'DRAFT',
    asking_price_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    reserve_price_brl DECIMAL(18,4),
    security_deposit_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    fractional_lot_nex DECIMAL(18,8) NOT NULL DEFAULT 0,
    channel_code TEXT NOT NULL DEFAULT 'APP',
    marketing_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    availability_start_at TIMESTAMPTZ,
    availability_end_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_real_estate_listings_property
        FOREIGN KEY (property_id) REFERENCES real_estate_properties (property_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_real_estate_listings_seller
        FOREIGN KEY (seller_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_real_estate_listings_wallet
        FOREIGN KEY (wallet_id) REFERENCES wallets (wallet_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_real_estate_listings_module
        FOREIGN KEY (module_code) REFERENCES module_delivery_registry (module_code)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT ux_real_estate_listings_seller_code UNIQUE (seller_user_id, listing_code),
    CONSTRAINT chk_real_estate_listings_module CHECK (module_code = 'REAL_ESTATE'),
    CONSTRAINT chk_real_estate_listings_code CHECK (listing_code ~ '^[A-Z0-9_-]{2,80}$'),
    CONSTRAINT chk_real_estate_listings_amounts CHECK (
        asking_price_brl >= 0
        AND security_deposit_brl >= 0
        AND fractional_lot_nex >= 0
        AND (reserve_price_brl IS NULL OR reserve_price_brl >= 0)
        AND (reserve_price_brl IS NULL OR reserve_price_brl <= asking_price_brl OR asking_price_brl = 0)
    ),
    CONSTRAINT chk_real_estate_listings_fractional CHECK (
        (listing_type = 'FRACTIONAL_SALE' AND fractional_lot_nex > 0)
        OR (listing_type <> 'FRACTIONAL_SALE' AND fractional_lot_nex = 0)
    ),
    CONSTRAINT chk_real_estate_listings_channel CHECK (btrim(channel_code) <> ''),
    CONSTRAINT chk_real_estate_listings_marketing_json CHECK (jsonb_typeof(marketing_json) = 'object'),
    CONSTRAINT chk_real_estate_listings_timeline CHECK (
        availability_end_at IS NULL
        OR availability_start_at IS NULL
        OR availability_end_at >= availability_start_at
    )
);

CREATE TABLE real_estate_deals (
    deal_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    property_id UUID NOT NULL,
    listing_id UUID,
    seller_user_id UUID NOT NULL,
    buyer_user_id UUID NOT NULL,
    wallet_id UUID NOT NULL,
    module_code TEXT NOT NULL DEFAULT 'REAL_ESTATE',
    transaction_id UUID,
    legal_contract_id UUID,
    deal_status real_estate_deal_status_enum NOT NULL DEFAULT 'PENDING_DUE_DILIGENCE',
    purchase_price_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    purchase_price_nex DECIMAL(18,8) NOT NULL DEFAULT 0,
    escrow_amount_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    commission_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    due_diligence_deadline_at TIMESTAMPTZ,
    signed_at TIMESTAMPTZ,
    closed_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,
    deal_notes TEXT,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_real_estate_deals_property
        FOREIGN KEY (property_id) REFERENCES real_estate_properties (property_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_real_estate_deals_listing
        FOREIGN KEY (listing_id) REFERENCES real_estate_listings (listing_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_real_estate_deals_seller
        FOREIGN KEY (seller_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_real_estate_deals_buyer
        FOREIGN KEY (buyer_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_real_estate_deals_wallet
        FOREIGN KEY (wallet_id) REFERENCES wallets (wallet_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_real_estate_deals_module
        FOREIGN KEY (module_code) REFERENCES module_delivery_registry (module_code)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_real_estate_deals_transaction
        FOREIGN KEY (transaction_id) REFERENCES transactions (transaction_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_real_estate_deals_contract
        FOREIGN KEY (legal_contract_id) REFERENCES legal_contracts (legal_contract_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT chk_real_estate_deals_module CHECK (module_code = 'REAL_ESTATE'),
    CONSTRAINT chk_real_estate_deals_distinct_parties CHECK (seller_user_id <> buyer_user_id),
    CONSTRAINT chk_real_estate_deals_amounts CHECK (
        purchase_price_brl >= 0
        AND purchase_price_nex >= 0
        AND escrow_amount_brl >= 0
        AND commission_brl >= 0
    ),
    CONSTRAINT chk_real_estate_deals_notes CHECK (deal_notes IS NULL OR btrim(deal_notes) <> ''),
    CONSTRAINT chk_real_estate_deals_metadata_json CHECK (jsonb_typeof(metadata_json) = 'object'),
    CONSTRAINT chk_real_estate_deals_timeline CHECK (
        (signed_at IS NULL OR due_diligence_deadline_at IS NULL OR signed_at <= due_diligence_deadline_at)
        AND (closed_at IS NULL OR signed_at IS NULL OR closed_at >= signed_at)
        AND (cancelled_at IS NULL OR cancelled_at >= created_at)
    )
);

CREATE TABLE edu_learning_paths (
    learning_path_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_user_id UUID NOT NULL,
    wallet_id UUID,
    module_code TEXT NOT NULL DEFAULT 'EDU',
    path_code TEXT NOT NULL,
    path_status edu_learning_path_status_enum NOT NULL DEFAULT 'DRAFT',
    path_title TEXT NOT NULL,
    category_code TEXT NOT NULL,
    level_code TEXT NOT NULL DEFAULT 'FOUNDATION',
    price_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    reward_points INTEGER NOT NULL DEFAULT 0,
    reward_nex DECIMAL(18,8) NOT NULL DEFAULT 0,
    summary TEXT,
    certificate_template_document_id UUID,
    requirements_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_edu_learning_paths_owner
        FOREIGN KEY (owner_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_edu_learning_paths_wallet
        FOREIGN KEY (wallet_id) REFERENCES wallets (wallet_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_edu_learning_paths_module
        FOREIGN KEY (module_code) REFERENCES module_delivery_registry (module_code)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_edu_learning_paths_document
        FOREIGN KEY (certificate_template_document_id) REFERENCES document_records (document_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT ux_edu_learning_paths_owner_code UNIQUE (owner_user_id, path_code),
    CONSTRAINT chk_edu_learning_paths_module CHECK (module_code = 'EDU'),
    CONSTRAINT chk_edu_learning_paths_code CHECK (path_code ~ '^[A-Z0-9_-]{2,80}$'),
    CONSTRAINT chk_edu_learning_paths_title CHECK (btrim(path_title) <> ''),
    CONSTRAINT chk_edu_learning_paths_category CHECK (category_code ~ '^[A-Z0-9_]{2,64}$'),
    CONSTRAINT chk_edu_learning_paths_level CHECK (level_code ~ '^[A-Z0-9_]{2,64}$'),
    CONSTRAINT chk_edu_learning_paths_values CHECK (
        price_brl >= 0
        AND reward_points >= 0
        AND reward_nex >= 0
        AND (price_brl = 0 OR wallet_id IS NOT NULL)
    ),
    CONSTRAINT chk_edu_learning_paths_summary CHECK (summary IS NULL OR btrim(summary) <> ''),
    CONSTRAINT chk_edu_learning_paths_requirements_json CHECK (jsonb_typeof(requirements_json) = 'object'),
    CONSTRAINT chk_edu_learning_paths_metadata_json CHECK (jsonb_typeof(metadata_json) = 'object')
);

CREATE TABLE edu_learning_units (
    learning_unit_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    learning_path_id UUID NOT NULL,
    owner_user_id UUID NOT NULL,
    unit_code TEXT NOT NULL,
    unit_type edu_unit_type_enum NOT NULL DEFAULT 'LESSON',
    unit_title TEXT NOT NULL,
    sequence_number INTEGER NOT NULL,
    estimated_minutes INTEGER,
    content_document_id UUID,
    prerequisites_json JSONB NOT NULL DEFAULT '[]'::JSONB,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    is_required BOOLEAN NOT NULL DEFAULT TRUE,
    release_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_edu_learning_units_path
        FOREIGN KEY (learning_path_id) REFERENCES edu_learning_paths (learning_path_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_edu_learning_units_owner
        FOREIGN KEY (owner_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_edu_learning_units_document
        FOREIGN KEY (content_document_id) REFERENCES document_records (document_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT ux_edu_learning_units_path_code UNIQUE (learning_path_id, unit_code),
    CONSTRAINT ux_edu_learning_units_path_sequence UNIQUE (learning_path_id, sequence_number),
    CONSTRAINT chk_edu_learning_units_code CHECK (unit_code ~ '^[A-Z0-9_-]{2,80}$'),
    CONSTRAINT chk_edu_learning_units_title CHECK (btrim(unit_title) <> ''),
    CONSTRAINT chk_edu_learning_units_sequence CHECK (sequence_number > 0),
    CONSTRAINT chk_edu_learning_units_minutes CHECK (
        estimated_minutes IS NULL OR estimated_minutes > 0
    ),
    CONSTRAINT chk_edu_learning_units_prerequisites_json CHECK (jsonb_typeof(prerequisites_json) = 'array'),
    CONSTRAINT chk_edu_learning_units_metadata_json CHECK (jsonb_typeof(metadata_json) = 'object')
);

CREATE TABLE edu_enrollments (
    enrollment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    learning_path_id UUID NOT NULL,
    student_user_id UUID NOT NULL,
    wallet_id UUID,
    payment_transaction_id UUID,
    module_code TEXT NOT NULL DEFAULT 'EDU',
    enrollment_status edu_enrollment_status_enum NOT NULL DEFAULT 'ENROLLED',
    progress_percent NUMERIC(5,2) NOT NULL DEFAULT 0,
    completed_units INTEGER NOT NULL DEFAULT 0,
    score_average NUMERIC(5,2),
    reward_points_granted INTEGER NOT NULL DEFAULT 0,
    reward_nex_granted DECIMAL(18,8) NOT NULL DEFAULT 0,
    certificate_document_id UUID,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_edu_enrollments_path
        FOREIGN KEY (learning_path_id) REFERENCES edu_learning_paths (learning_path_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_edu_enrollments_student
        FOREIGN KEY (student_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_edu_enrollments_wallet
        FOREIGN KEY (wallet_id) REFERENCES wallets (wallet_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_edu_enrollments_transaction
        FOREIGN KEY (payment_transaction_id) REFERENCES transactions (transaction_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_edu_enrollments_module
        FOREIGN KEY (module_code) REFERENCES module_delivery_registry (module_code)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_edu_enrollments_document
        FOREIGN KEY (certificate_document_id) REFERENCES document_records (document_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT ux_edu_enrollments_path_student UNIQUE (learning_path_id, student_user_id),
    CONSTRAINT chk_edu_enrollments_module CHECK (module_code = 'EDU'),
    CONSTRAINT chk_edu_enrollments_progress CHECK (progress_percent BETWEEN 0 AND 100),
    CONSTRAINT chk_edu_enrollments_completed_units CHECK (completed_units >= 0),
    CONSTRAINT chk_edu_enrollments_score CHECK (
        score_average IS NULL OR score_average BETWEEN 0 AND 100
    ),
    CONSTRAINT chk_edu_enrollments_rewards CHECK (
        reward_points_granted >= 0
        AND reward_nex_granted >= 0
    ),
    CONSTRAINT chk_edu_enrollments_metadata_json CHECK (jsonb_typeof(metadata_json) = 'object'),
    CONSTRAINT chk_edu_enrollments_timeline CHECK (
        (completed_at IS NULL OR completed_at >= started_at)
        AND (cancelled_at IS NULL OR cancelled_at >= started_at)
    )
);

CREATE TABLE vet_pet_profiles (
    pet_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_user_id UUID NOT NULL,
    wallet_id UUID,
    module_code TEXT NOT NULL DEFAULT 'VET',
    pet_code TEXT NOT NULL,
    pet_status vet_pet_status_enum NOT NULL DEFAULT 'ACTIVE',
    pet_name TEXT NOT NULL,
    species_code TEXT NOT NULL,
    breed_name TEXT,
    sex_code TEXT,
    birth_date DATE,
    weight_kg NUMERIC(8,3),
    color_notes TEXT,
    identification_tag TEXT,
    allergies_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    medical_flags_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_vet_pet_profiles_owner
        FOREIGN KEY (owner_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_vet_pet_profiles_wallet
        FOREIGN KEY (wallet_id) REFERENCES wallets (wallet_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_vet_pet_profiles_module
        FOREIGN KEY (module_code) REFERENCES module_delivery_registry (module_code)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT ux_vet_pet_profiles_owner_code UNIQUE (owner_user_id, pet_code),
    CONSTRAINT chk_vet_pet_profiles_module CHECK (module_code = 'VET'),
    CONSTRAINT chk_vet_pet_profiles_code CHECK (pet_code ~ '^[A-Z0-9_-]{2,80}$'),
    CONSTRAINT chk_vet_pet_profiles_name CHECK (btrim(pet_name) <> ''),
    CONSTRAINT chk_vet_pet_profiles_species CHECK (species_code ~ '^[A-Z0-9_]{2,64}$'),
    CONSTRAINT chk_vet_pet_profiles_sex CHECK (
        sex_code IS NULL OR sex_code IN ('FEMALE', 'MALE', 'UNKNOWN')
    ),
    CONSTRAINT chk_vet_pet_profiles_birth_date CHECK (
        birth_date IS NULL OR birth_date <= CURRENT_DATE
    ),
    CONSTRAINT chk_vet_pet_profiles_weight CHECK (
        weight_kg IS NULL OR weight_kg >= 0
    ),
    CONSTRAINT chk_vet_pet_profiles_color CHECK (
        color_notes IS NULL OR btrim(color_notes) <> ''
    ),
    CONSTRAINT chk_vet_pet_profiles_tag CHECK (
        identification_tag IS NULL OR btrim(identification_tag) <> ''
    ),
    CONSTRAINT chk_vet_pet_profiles_allergies_json CHECK (jsonb_typeof(allergies_json) = 'object'),
    CONSTRAINT chk_vet_pet_profiles_flags_json CHECK (jsonb_typeof(medical_flags_json) = 'object')
);

CREATE TABLE vet_service_cases (
    vet_case_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pet_id UUID NOT NULL,
    owner_user_id UUID NOT NULL,
    provider_user_id UUID NOT NULL,
    wallet_id UUID,
    service_booking_id UUID,
    module_code TEXT NOT NULL DEFAULT 'VET',
    case_status vet_case_status_enum NOT NULL DEFAULT 'OPEN',
    visit_reason TEXT NOT NULL,
    symptoms_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    diagnosis_summary TEXT,
    treatment_plan_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    next_visit_at TIMESTAMPTZ,
    closed_at TIMESTAMPTZ,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_vet_service_cases_pet
        FOREIGN KEY (pet_id) REFERENCES vet_pet_profiles (pet_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_vet_service_cases_owner
        FOREIGN KEY (owner_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_vet_service_cases_provider
        FOREIGN KEY (provider_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_vet_service_cases_wallet
        FOREIGN KEY (wallet_id) REFERENCES wallets (wallet_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_vet_service_cases_booking
        FOREIGN KEY (service_booking_id) REFERENCES service_bookings (booking_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_vet_service_cases_module
        FOREIGN KEY (module_code) REFERENCES module_delivery_registry (module_code)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT chk_vet_service_cases_module CHECK (module_code = 'VET'),
    CONSTRAINT chk_vet_service_cases_parties CHECK (owner_user_id <> provider_user_id),
    CONSTRAINT chk_vet_service_cases_reason CHECK (btrim(visit_reason) <> ''),
    CONSTRAINT chk_vet_service_cases_symptoms_json CHECK (jsonb_typeof(symptoms_json) = 'object'),
    CONSTRAINT chk_vet_service_cases_diagnosis CHECK (
        diagnosis_summary IS NULL OR btrim(diagnosis_summary) <> ''
    ),
    CONSTRAINT chk_vet_service_cases_treatment_json CHECK (jsonb_typeof(treatment_plan_json) = 'object'),
    CONSTRAINT chk_vet_service_cases_metadata_json CHECK (jsonb_typeof(metadata_json) = 'object'),
    CONSTRAINT chk_vet_service_cases_timeline CHECK (
        closed_at IS NULL OR closed_at >= created_at
    )
);

CREATE TABLE vet_prescriptions (
    vet_prescription_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vet_case_id UUID NOT NULL,
    pet_id UUID NOT NULL,
    prescriber_user_id UUID NOT NULL,
    owner_user_id UUID NOT NULL,
    module_code TEXT NOT NULL DEFAULT 'VET',
    prescription_status vet_prescription_status_enum NOT NULL DEFAULT 'ISSUED',
    pharmacy_item_id UUID,
    document_id UUID,
    prescription_hash TEXT NOT NULL,
    instructions_text TEXT NOT NULL,
    dosage_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    issued_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_vet_prescriptions_case
        FOREIGN KEY (vet_case_id) REFERENCES vet_service_cases (vet_case_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_vet_prescriptions_pet
        FOREIGN KEY (pet_id) REFERENCES vet_pet_profiles (pet_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_vet_prescriptions_prescriber
        FOREIGN KEY (prescriber_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_vet_prescriptions_owner
        FOREIGN KEY (owner_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_vet_prescriptions_module
        FOREIGN KEY (module_code) REFERENCES module_delivery_registry (module_code)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_vet_prescriptions_item
        FOREIGN KEY (pharmacy_item_id) REFERENCES pharmacy_catalog_items (pharmacy_item_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_vet_prescriptions_document
        FOREIGN KEY (document_id) REFERENCES document_records (document_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT chk_vet_prescriptions_module CHECK (module_code = 'VET'),
    CONSTRAINT chk_vet_prescriptions_hash CHECK (prescription_hash ~ '^[a-fA-F0-9]{64}$'),
    CONSTRAINT chk_vet_prescriptions_instructions CHECK (btrim(instructions_text) <> ''),
    CONSTRAINT chk_vet_prescriptions_dosage_json CHECK (jsonb_typeof(dosage_json) = 'object'),
    CONSTRAINT chk_vet_prescriptions_timeline CHECK (
        (expires_at IS NULL OR expires_at > issued_at)
        AND (cancelled_at IS NULL OR cancelled_at >= issued_at)
    )
);

CREATE TABLE gov_service_catalog (
    gov_service_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_user_id UUID NOT NULL,
    wallet_id UUID,
    module_code TEXT NOT NULL DEFAULT 'GOV',
    service_code TEXT NOT NULL,
    service_status gov_service_status_enum NOT NULL DEFAULT 'DRAFT',
    service_title TEXT NOT NULL,
    department_name TEXT NOT NULL,
    fee_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    sla_business_days INTEGER,
    delivery_mode TEXT NOT NULL DEFAULT 'DIGITAL',
    requirements_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_gov_service_catalog_owner
        FOREIGN KEY (owner_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_gov_service_catalog_wallet
        FOREIGN KEY (wallet_id) REFERENCES wallets (wallet_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_gov_service_catalog_module
        FOREIGN KEY (module_code) REFERENCES module_delivery_registry (module_code)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT ux_gov_service_catalog_owner_code UNIQUE (owner_user_id, service_code),
    CONSTRAINT chk_gov_service_catalog_module CHECK (module_code = 'GOV'),
    CONSTRAINT chk_gov_service_catalog_code CHECK (service_code ~ '^[A-Z0-9_-]{2,80}$'),
    CONSTRAINT chk_gov_service_catalog_title CHECK (btrim(service_title) <> ''),
    CONSTRAINT chk_gov_service_catalog_department CHECK (btrim(department_name) <> ''),
    CONSTRAINT chk_gov_service_catalog_values CHECK (
        fee_brl >= 0
        AND (sla_business_days IS NULL OR sla_business_days > 0)
        AND (fee_brl = 0 OR wallet_id IS NOT NULL)
    ),
    CONSTRAINT chk_gov_service_catalog_delivery CHECK (btrim(delivery_mode) <> ''),
    CONSTRAINT chk_gov_service_catalog_requirements_json CHECK (jsonb_typeof(requirements_json) = 'object'),
    CONSTRAINT chk_gov_service_catalog_metadata_json CHECK (jsonb_typeof(metadata_json) = 'object')
);

CREATE TABLE gov_service_requests (
    gov_request_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    gov_service_id UUID NOT NULL,
    requester_user_id UUID NOT NULL,
    assigned_officer_user_id UUID,
    wallet_id UUID,
    module_code TEXT NOT NULL DEFAULT 'GOV',
    request_status gov_request_status_enum NOT NULL DEFAULT 'SUBMITTED',
    protocol_code TEXT NOT NULL,
    request_fee_transaction_id UUID,
    legal_contract_id UUID,
    document_id UUID,
    submitted_payload_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    response_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    notes TEXT,
    submitted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    scheduled_at TIMESTAMPTZ,
    resolved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_gov_service_requests_service
        FOREIGN KEY (gov_service_id) REFERENCES gov_service_catalog (gov_service_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_gov_service_requests_requester
        FOREIGN KEY (requester_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_gov_service_requests_officer
        FOREIGN KEY (assigned_officer_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_gov_service_requests_wallet
        FOREIGN KEY (wallet_id) REFERENCES wallets (wallet_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_gov_service_requests_module
        FOREIGN KEY (module_code) REFERENCES module_delivery_registry (module_code)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_gov_service_requests_transaction
        FOREIGN KEY (request_fee_transaction_id) REFERENCES transactions (transaction_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_gov_service_requests_contract
        FOREIGN KEY (legal_contract_id) REFERENCES legal_contracts (legal_contract_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_gov_service_requests_document
        FOREIGN KEY (document_id) REFERENCES document_records (document_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT ux_gov_service_requests_protocol UNIQUE (protocol_code),
    CONSTRAINT chk_gov_service_requests_module CHECK (module_code = 'GOV'),
    CONSTRAINT chk_gov_service_requests_protocol CHECK (protocol_code ~ '^[A-Z0-9-]{6,64}$'),
    CONSTRAINT chk_gov_service_requests_payload_json CHECK (jsonb_typeof(submitted_payload_json) = 'object'),
    CONSTRAINT chk_gov_service_requests_response_json CHECK (jsonb_typeof(response_json) = 'object'),
    CONSTRAINT chk_gov_service_requests_notes CHECK (notes IS NULL OR btrim(notes) <> ''),
    CONSTRAINT chk_gov_service_requests_timeline CHECK (
        (scheduled_at IS NULL OR scheduled_at >= submitted_at)
        AND (resolved_at IS NULL OR resolved_at >= submitted_at)
    )
);

CREATE TABLE gov_request_events (
    gov_request_event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    gov_request_id UUID NOT NULL,
    actor_user_id UUID NOT NULL,
    document_id UUID,
    event_type gov_request_event_type_enum NOT NULL,
    details_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_gov_request_events_request
        FOREIGN KEY (gov_request_id) REFERENCES gov_service_requests (gov_request_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_gov_request_events_actor
        FOREIGN KEY (actor_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_gov_request_events_document
        FOREIGN KEY (document_id) REFERENCES document_records (document_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT chk_gov_request_events_details_json CHECK (jsonb_typeof(details_json) = 'object')
);

CREATE TABLE charity_causes (
    cause_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sponsor_user_id UUID NOT NULL,
    beneficiary_user_id UUID,
    wallet_id UUID NOT NULL,
    module_code TEXT NOT NULL DEFAULT 'CHARITY',
    cause_code TEXT NOT NULL,
    cause_status charity_cause_status_enum NOT NULL DEFAULT 'DRAFT',
    cause_title TEXT NOT NULL,
    target_amount_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    target_amount_nex DECIMAL(18,8) NOT NULL DEFAULT 0,
    campaign_start_at TIMESTAMPTZ,
    campaign_end_at TIMESTAMPTZ,
    impact_model_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    proof_document_id UUID,
    legal_contract_id UUID,
    summary TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_charity_causes_sponsor
        FOREIGN KEY (sponsor_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_charity_causes_beneficiary
        FOREIGN KEY (beneficiary_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_charity_causes_wallet
        FOREIGN KEY (wallet_id) REFERENCES wallets (wallet_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_charity_causes_module
        FOREIGN KEY (module_code) REFERENCES module_delivery_registry (module_code)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_charity_causes_document
        FOREIGN KEY (proof_document_id) REFERENCES document_records (document_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_charity_causes_contract
        FOREIGN KEY (legal_contract_id) REFERENCES legal_contracts (legal_contract_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT ux_charity_causes_sponsor_code UNIQUE (sponsor_user_id, cause_code),
    CONSTRAINT chk_charity_causes_module CHECK (module_code = 'CHARITY'),
    CONSTRAINT chk_charity_causes_code CHECK (cause_code ~ '^[A-Z0-9_-]{2,80}$'),
    CONSTRAINT chk_charity_causes_title CHECK (btrim(cause_title) <> ''),
    CONSTRAINT chk_charity_causes_values CHECK (
        target_amount_brl >= 0
        AND target_amount_nex >= 0
        AND (
            cause_status = 'DRAFT'
            OR target_amount_brl > 0
            OR target_amount_nex > 0
        )
    ),
    CONSTRAINT chk_charity_causes_timeline CHECK (
        campaign_end_at IS NULL
        OR campaign_start_at IS NULL
        OR campaign_end_at >= campaign_start_at
    ),
    CONSTRAINT chk_charity_causes_impact_json CHECK (jsonb_typeof(impact_model_json) = 'object'),
    CONSTRAINT chk_charity_causes_summary CHECK (summary IS NULL OR btrim(summary) <> '')
);

CREATE TABLE charity_grants (
    grant_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cause_id UUID NOT NULL,
    requester_user_id UUID NOT NULL,
    approver_user_id UUID,
    wallet_id UUID NOT NULL,
    grant_status charity_grant_status_enum NOT NULL DEFAULT 'REQUESTED',
    requested_amount_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    approved_amount_brl DECIMAL(18,4),
    payout_transaction_id UUID,
    proof_document_id UUID,
    request_reason TEXT NOT NULL,
    review_notes TEXT,
    requested_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    decided_at TIMESTAMPTZ,
    disbursed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_charity_grants_cause
        FOREIGN KEY (cause_id) REFERENCES charity_causes (cause_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_charity_grants_requester
        FOREIGN KEY (requester_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_charity_grants_approver
        FOREIGN KEY (approver_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_charity_grants_wallet
        FOREIGN KEY (wallet_id) REFERENCES wallets (wallet_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_charity_grants_transaction
        FOREIGN KEY (payout_transaction_id) REFERENCES transactions (transaction_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_charity_grants_document
        FOREIGN KEY (proof_document_id) REFERENCES document_records (document_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT chk_charity_grants_values CHECK (
        requested_amount_brl >= 0
        AND requested_amount_brl > 0
        AND (approved_amount_brl IS NULL OR (approved_amount_brl >= 0 AND approved_amount_brl <= requested_amount_brl))
    ),
    CONSTRAINT chk_charity_grants_reason CHECK (btrim(request_reason) <> ''),
    CONSTRAINT chk_charity_grants_review_notes CHECK (
        review_notes IS NULL OR btrim(review_notes) <> ''
    ),
    CONSTRAINT chk_charity_grants_timeline CHECK (
        (decided_at IS NULL OR decided_at >= requested_at)
        AND (disbursed_at IS NULL OR decided_at IS NULL OR disbursed_at >= decided_at)
    )
);

CREATE TABLE charity_fund_ledger (
    charity_fund_ledger_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cause_id UUID NOT NULL,
    actor_user_id UUID NOT NULL,
    donor_user_id UUID,
    beneficiary_user_id UUID,
    wallet_id UUID NOT NULL,
    grant_id UUID,
    transaction_id UUID,
    event_type charity_fund_event_type_enum NOT NULL,
    amount_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    amount_nex DECIMAL(18,8) NOT NULL DEFAULT 0,
    notes TEXT,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_charity_fund_ledger_cause
        FOREIGN KEY (cause_id) REFERENCES charity_causes (cause_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_charity_fund_ledger_actor
        FOREIGN KEY (actor_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_charity_fund_ledger_donor
        FOREIGN KEY (donor_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_charity_fund_ledger_beneficiary
        FOREIGN KEY (beneficiary_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_charity_fund_ledger_wallet
        FOREIGN KEY (wallet_id) REFERENCES wallets (wallet_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_charity_fund_ledger_grant
        FOREIGN KEY (grant_id) REFERENCES charity_grants (grant_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_charity_fund_ledger_transaction
        FOREIGN KEY (transaction_id) REFERENCES transactions (transaction_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT chk_charity_fund_ledger_amounts CHECK (
        amount_brl >= 0
        AND amount_nex >= 0
        AND (amount_brl > 0 OR amount_nex > 0)
    ),
    CONSTRAINT chk_charity_fund_ledger_notes CHECK (notes IS NULL OR btrim(notes) <> ''),
    CONSTRAINT chk_charity_fund_ledger_metadata_json CHECK (jsonb_typeof(metadata_json) = 'object'),
    CONSTRAINT chk_charity_fund_ledger_semantics CHECK (
        (event_type <> 'DONATION_RECEIVED' OR donor_user_id IS NOT NULL)
        AND (event_type <> 'GRANT_DISBURSED' OR (grant_id IS NOT NULL AND beneficiary_user_id IS NOT NULL))
    )
);

CREATE TABLE insurance_products (
    insurance_product_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    issuer_user_id UUID NOT NULL,
    wallet_id UUID NOT NULL,
    module_code TEXT NOT NULL DEFAULT 'INSURANCE',
    product_code TEXT NOT NULL,
    product_status insurance_product_status_enum NOT NULL DEFAULT 'DRAFT',
    product_name TEXT NOT NULL,
    coverage_category TEXT NOT NULL,
    premium_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    deductible_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    coverage_limit_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    waiting_period_days INTEGER NOT NULL DEFAULT 0,
    rule_id UUID,
    terms_contract_id UUID,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_insurance_products_issuer
        FOREIGN KEY (issuer_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_insurance_products_wallet
        FOREIGN KEY (wallet_id) REFERENCES wallets (wallet_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_insurance_products_module
        FOREIGN KEY (module_code) REFERENCES module_delivery_registry (module_code)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_insurance_products_rule
        FOREIGN KEY (rule_id) REFERENCES business_rule_definitions (rule_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_insurance_products_contract
        FOREIGN KEY (terms_contract_id) REFERENCES legal_contracts (legal_contract_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT ux_insurance_products_issuer_code UNIQUE (issuer_user_id, product_code),
    CONSTRAINT chk_insurance_products_module CHECK (module_code = 'INSURANCE'),
    CONSTRAINT chk_insurance_products_code CHECK (product_code ~ '^[A-Z0-9_-]{2,80}$'),
    CONSTRAINT chk_insurance_products_name CHECK (btrim(product_name) <> ''),
    CONSTRAINT chk_insurance_products_category CHECK (btrim(coverage_category) <> ''),
    CONSTRAINT chk_insurance_products_values CHECK (
        premium_brl >= 0
        AND deductible_brl >= 0
        AND coverage_limit_brl >= 0
        AND waiting_period_days >= 0
    ),
    CONSTRAINT chk_insurance_products_metadata_json CHECK (jsonb_typeof(metadata_json) = 'object')
);

CREATE TABLE insurance_policies (
    policy_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    insurance_product_id UUID NOT NULL,
    policyholder_user_id UUID NOT NULL,
    beneficiary_user_id UUID,
    wallet_id UUID NOT NULL,
    module_code TEXT NOT NULL DEFAULT 'INSURANCE',
    policy_number TEXT NOT NULL,
    policy_status insurance_policy_status_enum NOT NULL DEFAULT 'QUOTED',
    premium_transaction_id UUID,
    legal_contract_id UUID,
    insured_asset_type TEXT,
    insured_asset_id UUID,
    coverage_start_at TIMESTAMPTZ,
    coverage_end_at TIMESTAMPTZ,
    monthly_premium_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    coverage_limit_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    risk_score NUMERIC(5,2),
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_insurance_policies_product
        FOREIGN KEY (insurance_product_id) REFERENCES insurance_products (insurance_product_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_insurance_policies_policyholder
        FOREIGN KEY (policyholder_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_insurance_policies_beneficiary
        FOREIGN KEY (beneficiary_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_insurance_policies_wallet
        FOREIGN KEY (wallet_id) REFERENCES wallets (wallet_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_insurance_policies_module
        FOREIGN KEY (module_code) REFERENCES module_delivery_registry (module_code)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_insurance_policies_transaction
        FOREIGN KEY (premium_transaction_id) REFERENCES transactions (transaction_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_insurance_policies_contract
        FOREIGN KEY (legal_contract_id) REFERENCES legal_contracts (legal_contract_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT ux_insurance_policies_number UNIQUE (policy_number),
    CONSTRAINT chk_insurance_policies_module CHECK (module_code = 'INSURANCE'),
    CONSTRAINT chk_insurance_policies_number CHECK (policy_number ~ '^[A-Z0-9-]{6,64}$'),
    CONSTRAINT chk_insurance_policies_asset_type CHECK (
        insured_asset_type IS NULL OR btrim(insured_asset_type) <> ''
    ),
    CONSTRAINT chk_insurance_policies_values CHECK (
        monthly_premium_brl >= 0
        AND coverage_limit_brl >= 0
        AND (risk_score IS NULL OR risk_score BETWEEN 0 AND 100)
    ),
    CONSTRAINT chk_insurance_policies_metadata_json CHECK (jsonb_typeof(metadata_json) = 'object'),
    CONSTRAINT chk_insurance_policies_timeline CHECK (
        coverage_end_at IS NULL
        OR coverage_start_at IS NULL
        OR coverage_end_at >= coverage_start_at
    )
);

CREATE TABLE insurance_claims (
    claim_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    policy_id UUID NOT NULL,
    claimant_user_id UUID NOT NULL,
    wallet_id UUID NOT NULL,
    module_code TEXT NOT NULL DEFAULT 'INSURANCE',
    claim_code TEXT NOT NULL,
    claim_status insurance_claim_status_enum NOT NULL DEFAULT 'SUBMITTED',
    security_incident_id UUID,
    mobility_trip_id UUID,
    delivery_shipment_id UUID,
    document_id UUID,
    payout_transaction_id UUID,
    claimed_amount_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    approved_amount_brl DECIMAL(18,4),
    rejected_reason TEXT,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    submitted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    resolved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_insurance_claims_policy
        FOREIGN KEY (policy_id) REFERENCES insurance_policies (policy_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_insurance_claims_claimant
        FOREIGN KEY (claimant_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_insurance_claims_wallet
        FOREIGN KEY (wallet_id) REFERENCES wallets (wallet_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_insurance_claims_module
        FOREIGN KEY (module_code) REFERENCES module_delivery_registry (module_code)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_insurance_claims_security_incident
        FOREIGN KEY (security_incident_id) REFERENCES security_incidents (security_incident_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_insurance_claims_trip
        FOREIGN KEY (mobility_trip_id) REFERENCES mobility_trips (trip_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_insurance_claims_shipment
        FOREIGN KEY (delivery_shipment_id) REFERENCES delivery_shipments (shipment_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_insurance_claims_document
        FOREIGN KEY (document_id) REFERENCES document_records (document_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_insurance_claims_payout_transaction
        FOREIGN KEY (payout_transaction_id) REFERENCES transactions (transaction_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT ux_insurance_claims_code UNIQUE (claim_code),
    CONSTRAINT chk_insurance_claims_module CHECK (module_code = 'INSURANCE'),
    CONSTRAINT chk_insurance_claims_code CHECK (claim_code ~ '^[A-Z0-9-]{6,64}$'),
    CONSTRAINT chk_insurance_claims_values CHECK (
        claimed_amount_brl >= 0
        AND claimed_amount_brl > 0
        AND (approved_amount_brl IS NULL OR (approved_amount_brl >= 0 AND approved_amount_brl <= claimed_amount_brl))
    ),
    CONSTRAINT chk_insurance_claims_rejected_reason CHECK (
        rejected_reason IS NULL OR btrim(rejected_reason) <> ''
    ),
    CONSTRAINT chk_insurance_claims_metadata_json CHECK (jsonb_typeof(metadata_json) = 'object'),
    CONSTRAINT chk_insurance_claims_timeline CHECK (
        resolved_at IS NULL OR resolved_at >= submitted_at
    )
);

CREATE TABLE insurance_claim_events (
    claim_event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    claim_id UUID NOT NULL,
    actor_user_id UUID NOT NULL,
    document_id UUID,
    event_type insurance_claim_event_type_enum NOT NULL,
    event_amount_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    details_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_insurance_claim_events_claim
        FOREIGN KEY (claim_id) REFERENCES insurance_claims (claim_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_insurance_claim_events_actor
        FOREIGN KEY (actor_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_insurance_claim_events_document
        FOREIGN KEY (document_id) REFERENCES document_records (document_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT chk_insurance_claim_events_amount CHECK (event_amount_brl >= 0),
    CONSTRAINT chk_insurance_claim_events_details_json CHECK (jsonb_typeof(details_json) = 'object')
);

CREATE UNIQUE INDEX ux_vet_pet_profiles_identification_tag
    ON vet_pet_profiles (identification_tag)
    WHERE identification_tag IS NOT NULL;

CREATE INDEX ix_digital_asset_collections_creator
    ON digital_asset_collections (creator_user_id, created_at);

CREATE INDEX ix_digital_asset_collections_wallet
    ON digital_asset_collections (wallet_id);

CREATE INDEX ix_digital_assets_owner_status
    ON digital_assets (current_owner_user_id, asset_status);

CREATE INDEX ix_digital_assets_wallet_status
    ON digital_assets (custody_wallet_id, asset_status);

CREATE INDEX ix_digital_asset_events_asset_occurred_at
    ON digital_asset_events (digital_asset_id, occurred_at);

CREATE INDEX ix_digital_asset_events_transaction
    ON digital_asset_events (transaction_id)
    WHERE transaction_id IS NOT NULL;

CREATE INDEX ix_real_estate_properties_owner_status
    ON real_estate_properties (owner_user_id, property_status);

CREATE INDEX ix_real_estate_properties_tokenized_asset
    ON real_estate_properties (tokenized_asset_id)
    WHERE tokenized_asset_id IS NOT NULL;

CREATE INDEX ix_real_estate_listings_property_status
    ON real_estate_listings (property_id, listing_status);

CREATE INDEX ix_real_estate_listings_seller_status
    ON real_estate_listings (seller_user_id, listing_status);

CREATE INDEX ix_real_estate_deals_property_status
    ON real_estate_deals (property_id, deal_status);

CREATE INDEX ix_real_estate_deals_buyer_status
    ON real_estate_deals (buyer_user_id, deal_status);

CREATE INDEX ix_edu_learning_paths_owner_status
    ON edu_learning_paths (owner_user_id, path_status);

CREATE INDEX ix_edu_learning_paths_category
    ON edu_learning_paths (category_code, path_status);

CREATE INDEX ix_edu_learning_units_path_sequence
    ON edu_learning_units (learning_path_id, sequence_number);

CREATE INDEX ix_edu_enrollments_student_status
    ON edu_enrollments (student_user_id, enrollment_status);

CREATE INDEX ix_vet_pet_profiles_owner_status
    ON vet_pet_profiles (owner_user_id, pet_status);

CREATE INDEX ix_vet_service_cases_pet_status
    ON vet_service_cases (pet_id, case_status);

CREATE INDEX ix_vet_service_cases_provider_status
    ON vet_service_cases (provider_user_id, case_status);

CREATE INDEX ix_vet_prescriptions_pet_status
    ON vet_prescriptions (pet_id, prescription_status);

CREATE INDEX ix_vet_prescriptions_item
    ON vet_prescriptions (pharmacy_item_id)
    WHERE pharmacy_item_id IS NOT NULL;

CREATE INDEX ix_gov_service_catalog_owner_status
    ON gov_service_catalog (owner_user_id, service_status);

CREATE INDEX ix_gov_service_requests_requester_status
    ON gov_service_requests (requester_user_id, request_status);

CREATE INDEX ix_gov_service_requests_officer_status
    ON gov_service_requests (assigned_officer_user_id, request_status)
    WHERE assigned_officer_user_id IS NOT NULL;

CREATE INDEX ix_gov_request_events_request_occurred_at
    ON gov_request_events (gov_request_id, occurred_at);

CREATE INDEX ix_charity_causes_sponsor_status
    ON charity_causes (sponsor_user_id, cause_status);

CREATE INDEX ix_charity_causes_beneficiary
    ON charity_causes (beneficiary_user_id)
    WHERE beneficiary_user_id IS NOT NULL;

CREATE INDEX ix_charity_grants_cause_status
    ON charity_grants (cause_id, grant_status);

CREATE INDEX ix_charity_grants_requester_status
    ON charity_grants (requester_user_id, grant_status);

CREATE INDEX ix_charity_fund_ledger_cause_occurred_at
    ON charity_fund_ledger (cause_id, occurred_at);

CREATE INDEX ix_charity_fund_ledger_transaction
    ON charity_fund_ledger (transaction_id)
    WHERE transaction_id IS NOT NULL;

CREATE INDEX ix_insurance_products_issuer_status
    ON insurance_products (issuer_user_id, product_status);

CREATE INDEX ix_insurance_policies_policyholder_status
    ON insurance_policies (policyholder_user_id, policy_status);

CREATE INDEX ix_insurance_claims_policy_status
    ON insurance_claims (policy_id, claim_status);

CREATE INDEX ix_insurance_claims_claimant_status
    ON insurance_claims (claimant_user_id, claim_status);

CREATE INDEX ix_insurance_claim_events_claim_occurred_at
    ON insurance_claim_events (claim_id, occurred_at);

CREATE TRIGGER trg_digital_asset_collections_set_updated_at
BEFORE UPDATE ON digital_asset_collections
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_digital_assets_set_updated_at
BEFORE UPDATE ON digital_assets
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_real_estate_properties_set_updated_at
BEFORE UPDATE ON real_estate_properties
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_real_estate_listings_set_updated_at
BEFORE UPDATE ON real_estate_listings
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_real_estate_deals_set_updated_at
BEFORE UPDATE ON real_estate_deals
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_edu_learning_paths_set_updated_at
BEFORE UPDATE ON edu_learning_paths
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_edu_learning_units_set_updated_at
BEFORE UPDATE ON edu_learning_units
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_edu_enrollments_set_updated_at
BEFORE UPDATE ON edu_enrollments
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_vet_pet_profiles_set_updated_at
BEFORE UPDATE ON vet_pet_profiles
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_vet_service_cases_set_updated_at
BEFORE UPDATE ON vet_service_cases
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_vet_prescriptions_set_updated_at
BEFORE UPDATE ON vet_prescriptions
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_gov_service_catalog_set_updated_at
BEFORE UPDATE ON gov_service_catalog
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_gov_service_requests_set_updated_at
BEFORE UPDATE ON gov_service_requests
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_charity_causes_set_updated_at
BEFORE UPDATE ON charity_causes
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_charity_grants_set_updated_at
BEFORE UPDATE ON charity_grants
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_insurance_products_set_updated_at
BEFORE UPDATE ON insurance_products
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_insurance_policies_set_updated_at
BEFORE UPDATE ON insurance_policies
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_insurance_claims_set_updated_at
BEFORE UPDATE ON insurance_claims
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_digital_asset_events_prevent_update
BEFORE UPDATE ON digital_asset_events
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

CREATE TRIGGER trg_digital_asset_events_prevent_delete
BEFORE DELETE ON digital_asset_events
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

CREATE TRIGGER trg_gov_request_events_prevent_update
BEFORE UPDATE ON gov_request_events
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

CREATE TRIGGER trg_gov_request_events_prevent_delete
BEFORE DELETE ON gov_request_events
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

CREATE TRIGGER trg_charity_fund_ledger_prevent_update
BEFORE UPDATE ON charity_fund_ledger
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

CREATE TRIGGER trg_charity_fund_ledger_prevent_delete
BEFORE DELETE ON charity_fund_ledger
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

CREATE TRIGGER trg_insurance_claim_events_prevent_update
BEFORE UPDATE ON insurance_claim_events
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

CREATE TRIGGER trg_insurance_claim_events_prevent_delete
BEFORE DELETE ON insurance_claim_events
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

COMMENT ON TABLE digital_asset_collections IS 'Colecoes de ativos digitais com ancoragem em user, wallet e documento.';
COMMENT ON TABLE digital_assets IS 'Inventario relacional de ativos digitais, NFTs e fracoes tokenizadas.';
COMMENT ON TABLE digital_asset_events IS 'Trilha append-only dos eventos de mint, transfer e royalty.';
COMMENT ON TABLE real_estate_properties IS 'Cadastro de ativos imobiliarios com opcao de tokenizacao.';
COMMENT ON TABLE real_estate_listings IS 'Oferta de venda, locacao ou venda fracionada do imovel.';
COMMENT ON TABLE real_estate_deals IS 'Negociacoes e fechamento financeiro-juridico do imovel.';
COMMENT ON TABLE edu_learning_paths IS 'Trilhas de aprendizagem com preco e recompensa opcionais.';
COMMENT ON TABLE edu_learning_units IS 'Unidades curriculares ordenadas dentro de uma trilha.';
COMMENT ON TABLE edu_enrollments IS 'Vinculo do aluno com a trilha, progresso e certificado.';
COMMENT ON TABLE vet_pet_profiles IS 'Cadastro do pet com dados basicos, flags e identificacao.';
COMMENT ON TABLE vet_service_cases IS 'Casos veterinarios conectados a servicos profissionais quando houver.';
COMMENT ON TABLE vet_prescriptions IS 'Prescricoes veterinarias com hash e ligacao opcional ao catalogo da farmacia.';
COMMENT ON TABLE gov_service_catalog IS 'Catalogo govtech de servicos publicos e taxas opcionais.';
COMMENT ON TABLE gov_service_requests IS 'Requests civicos com protocolo, resposta e referencias juridicas.';
COMMENT ON TABLE gov_request_events IS 'Trilha append-only das mutacoes relevantes do request civico.';
COMMENT ON TABLE charity_causes IS 'Campanhas sociais com metas financeiras e prova documental.';
COMMENT ON TABLE charity_grants IS 'Pedidos e decisoes de grants ligados a uma causa.';
COMMENT ON TABLE charity_fund_ledger IS 'Ledger append-only do dinheiro social: doacao, matching, grant e refund.';
COMMENT ON TABLE insurance_products IS 'Produtos de seguro com pricing, limite e regra de risco.';
COMMENT ON TABLE insurance_policies IS 'Apolices emitidas para usuarios e ativos cobertos.';
COMMENT ON TABLE insurance_claims IS 'Claims de seguro ligados a incidentes, trips, shipments e documentos.';
COMMENT ON TABLE insurance_claim_events IS 'Trilha append-only dos eventos criticos do claim.';

COMMENT ON TRIGGER trg_digital_asset_events_prevent_update ON digital_asset_events IS 'Impede UPDATE na trilha append-only de ativos digitais.';
COMMENT ON TRIGGER trg_digital_asset_events_prevent_delete ON digital_asset_events IS 'Impede DELETE na trilha append-only de ativos digitais.';
COMMENT ON TRIGGER trg_gov_request_events_prevent_update ON gov_request_events IS 'Impede UPDATE na trilha append-only de requests civicos.';
COMMENT ON TRIGGER trg_gov_request_events_prevent_delete ON gov_request_events IS 'Impede DELETE na trilha append-only de requests civicos.';
COMMENT ON TRIGGER trg_charity_fund_ledger_prevent_update ON charity_fund_ledger IS 'Impede UPDATE no ledger append-only de charity.';
COMMENT ON TRIGGER trg_charity_fund_ledger_prevent_delete ON charity_fund_ledger IS 'Impede DELETE no ledger append-only de charity.';
COMMENT ON TRIGGER trg_insurance_claim_events_prevent_update ON insurance_claim_events IS 'Impede UPDATE na trilha append-only de claims.';
COMMENT ON TRIGGER trg_insurance_claim_events_prevent_delete ON insurance_claim_events IS 'Impede DELETE na trilha append-only de claims.';

COMMIT;
