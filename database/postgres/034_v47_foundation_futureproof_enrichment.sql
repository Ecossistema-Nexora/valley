-- Enriquecimento aditivo e future-proof do core relacional Valley.
-- Objetivo: errar pelo excesso sem quebrar seeds, FKs ou ledgers append-only.

BEGIN;

SET search_path = public;

ALTER TABLE users
    ADD COLUMN IF NOT EXISTS preferred_language_code CHAR(5),
    ADD COLUMN IF NOT EXISTS timezone_name TEXT,
    ADD COLUMN IF NOT EXISTS profile_photo_url TEXT,
    ADD COLUMN IF NOT EXISTS cover_photo_url TEXT,
    ADD COLUMN IF NOT EXISTS gender_identity TEXT,
    ADD COLUMN IF NOT EXISTS marital_status TEXT,
    ADD COLUMN IF NOT EXISTS occupation_title TEXT,
    ADD COLUMN IF NOT EXISTS employer_name TEXT,
    ADD COLUMN IF NOT EXISTS monthly_income_brl DECIMAL(18,4),
    ADD COLUMN IF NOT EXISTS net_worth_brl DECIMAL(18,4),
    ADD COLUMN IF NOT EXISTS politically_exposed_person BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS sanctions_screening_status TEXT,
    ADD COLUMN IF NOT EXISTS sanctions_screened_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS aml_review_status TEXT,
    ADD COLUMN IF NOT EXISTS aml_reviewed_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS fraud_score DECIMAL(6,3),
    ADD COLUMN IF NOT EXISTS trust_score DECIMAL(6,3),
    ADD COLUMN IF NOT EXISTS referred_by_user_id UUID,
    ADD COLUMN IF NOT EXISTS parent_user_id UUID,
    ADD COLUMN IF NOT EXISTS manager_user_id UUID,
    ADD COLUMN IF NOT EXISTS home_address_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    ADD COLUMN IF NOT EXISTS billing_address_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    ADD COLUMN IF NOT EXISTS shipping_address_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    ADD COLUMN IF NOT EXISTS geolocation_home_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    ADD COLUMN IF NOT EXISTS emergency_contact_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    ADD COLUMN IF NOT EXISTS communication_preferences_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    ADD COLUMN IF NOT EXISTS accessibility_preferences_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    ADD COLUMN IF NOT EXISTS notification_preferences_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    ADD COLUMN IF NOT EXISTS security_preferences_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    ADD COLUMN IF NOT EXISTS consent_matrix_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    ADD COLUMN IF NOT EXISTS metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    ADD COLUMN IF NOT EXISTS deactivated_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS archived_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS last_kyc_refresh_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS last_password_reset_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS last_profile_review_at TIMESTAMPTZ;

ALTER TABLE users
    ADD CONSTRAINT fk_users_referred_by_user
    FOREIGN KEY (referred_by_user_id) REFERENCES users (user_id)
    ON UPDATE CASCADE
    ON DELETE SET NULL;

ALTER TABLE users
    ADD CONSTRAINT fk_users_parent_user
    FOREIGN KEY (parent_user_id) REFERENCES users (user_id)
    ON UPDATE CASCADE
    ON DELETE SET NULL;

ALTER TABLE users
    ADD CONSTRAINT fk_users_manager_user
    FOREIGN KEY (manager_user_id) REFERENCES users (user_id)
    ON UPDATE CASCADE
    ON DELETE SET NULL;

ALTER TABLE users
    ADD CONSTRAINT chk_users_preferred_language_code_format CHECK (
        preferred_language_code IS NULL OR preferred_language_code ~ '^[a-z]{2}(-[A-Z]{2})?$'
    );

ALTER TABLE users
    ADD CONSTRAINT chk_users_financial_profile_non_negative CHECK (
        (monthly_income_brl IS NULL OR monthly_income_brl >= 0)
        AND (net_worth_brl IS NULL OR net_worth_brl >= 0)
    );

ALTER TABLE users
    ADD CONSTRAINT chk_users_risk_scores_range CHECK (
        (fraud_score IS NULL OR (fraud_score >= 0 AND fraud_score <= 100))
        AND (trust_score IS NULL OR (trust_score >= 0 AND trust_score <= 100))
    );

ALTER TABLE users
    ADD CONSTRAINT chk_users_json_shapes CHECK (
        jsonb_typeof(home_address_json) = 'object'
        AND jsonb_typeof(billing_address_json) = 'object'
        AND jsonb_typeof(shipping_address_json) = 'object'
        AND jsonb_typeof(geolocation_home_json) = 'object'
        AND jsonb_typeof(emergency_contact_json) = 'object'
        AND jsonb_typeof(communication_preferences_json) = 'object'
        AND jsonb_typeof(accessibility_preferences_json) = 'object'
        AND jsonb_typeof(notification_preferences_json) = 'object'
        AND jsonb_typeof(security_preferences_json) = 'object'
        AND jsonb_typeof(consent_matrix_json) = 'object'
        AND jsonb_typeof(metadata_json) = 'object'
    );

CREATE INDEX IF NOT EXISTS ix_users_referred_by_user_id
    ON users (referred_by_user_id)
    WHERE referred_by_user_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS ix_users_parent_user_id
    ON users (parent_user_id)
    WHERE parent_user_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS ix_users_manager_user_id
    ON users (manager_user_id)
    WHERE manager_user_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS ix_users_sanctions_screening_status
    ON users (sanctions_screening_status)
    WHERE sanctions_screening_status IS NOT NULL;

CREATE INDEX IF NOT EXISTS ix_users_aml_review_status
    ON users (aml_review_status)
    WHERE aml_review_status IS NOT NULL;

CREATE INDEX IF NOT EXISTS ix_users_metadata_gin
    ON users USING GIN (metadata_json);

ALTER TABLE pj_profiles
    ADD COLUMN IF NOT EXISTS company_size_band TEXT,
    ADD COLUMN IF NOT EXISTS annual_revenue_brl DECIMAL(18,4),
    ADD COLUMN IF NOT EXISTS beneficial_owner_count INTEGER,
    ADD COLUMN IF NOT EXISTS beneficial_owners_json JSONB NOT NULL DEFAULT '[]'::JSONB,
    ADD COLUMN IF NOT EXISTS banking_details_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    ADD COLUMN IF NOT EXISTS fiscal_address_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    ADD COLUMN IF NOT EXISTS operations_address_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    ADD COLUMN IF NOT EXISTS compliance_flags_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    ADD COLUMN IF NOT EXISTS contract_preferences_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    ADD COLUMN IF NOT EXISTS settlement_preferences_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    ADD COLUMN IF NOT EXISTS metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    ADD COLUMN IF NOT EXISTS last_kyb_refresh_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS onboarding_completed_at TIMESTAMPTZ;

ALTER TABLE pj_profiles
    ADD CONSTRAINT chk_pj_profiles_revenue_and_owner_count CHECK (
        (annual_revenue_brl IS NULL OR annual_revenue_brl >= 0)
        AND (beneficial_owner_count IS NULL OR beneficial_owner_count >= 0)
    );

ALTER TABLE pj_profiles
    ADD CONSTRAINT chk_pj_profiles_json_shapes CHECK (
        jsonb_typeof(beneficial_owners_json) = 'array'
        AND jsonb_typeof(banking_details_json) = 'object'
        AND jsonb_typeof(fiscal_address_json) = 'object'
        AND jsonb_typeof(operations_address_json) = 'object'
        AND jsonb_typeof(compliance_flags_json) = 'object'
        AND jsonb_typeof(contract_preferences_json) = 'object'
        AND jsonb_typeof(settlement_preferences_json) = 'object'
        AND jsonb_typeof(metadata_json) = 'object'
    );

CREATE INDEX IF NOT EXISTS ix_pj_profiles_metadata_gin
    ON pj_profiles USING GIN (metadata_json);

ALTER TABLE rider_profiles
    ADD COLUMN IF NOT EXISTS vehicle_brand TEXT,
    ADD COLUMN IF NOT EXISTS vehicle_year SMALLINT,
    ADD COLUMN IF NOT EXISTS vehicle_color TEXT,
    ADD COLUMN IF NOT EXISTS chassis_number TEXT,
    ADD COLUMN IF NOT EXISTS document_crlv_ref TEXT,
    ADD COLUMN IF NOT EXISTS driver_license_document_ref TEXT,
    ADD COLUMN IF NOT EXISTS helmet_verified BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS insulated_bag_verified BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS onboarding_checklist_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    ADD COLUMN IF NOT EXISTS payout_preferences_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    ADD COLUMN IF NOT EXISTS banking_details_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    ADD COLUMN IF NOT EXISTS emergency_contact_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    ADD COLUMN IF NOT EXISTS shift_preferences_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    ADD COLUMN IF NOT EXISTS realtime_status_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    ADD COLUMN IF NOT EXISTS equipment_inventory_json JSONB NOT NULL DEFAULT '[]'::JSONB,
    ADD COLUMN IF NOT EXISTS completed_trips_count BIGINT NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS cancelled_trips_count BIGINT NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS acceptance_rate DECIMAL(6,3),
    ADD COLUMN IF NOT EXISTS completion_rate DECIMAL(6,3),
    ADD COLUMN IF NOT EXISTS last_background_check_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB;

ALTER TABLE rider_profiles
    ADD CONSTRAINT chk_rider_profiles_metrics_range CHECK (
        completed_trips_count >= 0
        AND cancelled_trips_count >= 0
        AND (acceptance_rate IS NULL OR (acceptance_rate >= 0 AND acceptance_rate <= 100))
        AND (completion_rate IS NULL OR (completion_rate >= 0 AND completion_rate <= 100))
        AND (vehicle_year IS NULL OR vehicle_year BETWEEN 1950 AND 2100)
    );

ALTER TABLE rider_profiles
    ADD CONSTRAINT chk_rider_profiles_json_shapes CHECK (
        jsonb_typeof(onboarding_checklist_json) = 'object'
        AND jsonb_typeof(payout_preferences_json) = 'object'
        AND jsonb_typeof(banking_details_json) = 'object'
        AND jsonb_typeof(emergency_contact_json) = 'object'
        AND jsonb_typeof(shift_preferences_json) = 'object'
        AND jsonb_typeof(realtime_status_json) = 'object'
        AND jsonb_typeof(equipment_inventory_json) = 'array'
        AND jsonb_typeof(metadata_json) = 'object'
    );

CREATE INDEX IF NOT EXISTS ix_rider_profiles_metadata_gin
    ON rider_profiles USING GIN (metadata_json);

ALTER TABLE wallets
    ADD COLUMN IF NOT EXISTS wallet_label TEXT,
    ADD COLUMN IF NOT EXISTS wallet_purpose TEXT,
    ADD COLUMN IF NOT EXISTS currency_code CHAR(3),
    ADD COLUMN IF NOT EXISTS iban_reference TEXT,
    ADD COLUMN IF NOT EXISTS pix_key_ref TEXT,
    ADD COLUMN IF NOT EXISTS blockchain_network TEXT,
    ADD COLUMN IF NOT EXISTS blockchain_address TEXT,
    ADD COLUMN IF NOT EXISTS custody_provider TEXT,
    ADD COLUMN IF NOT EXISTS compliance_hold_reason TEXT,
    ADD COLUMN IF NOT EXISTS frozen_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS closed_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS last_inbound_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS last_outbound_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS last_statement_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS reserve_ratio DECIMAL(8,4),
    ADD COLUMN IF NOT EXISTS risk_limit_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    ADD COLUMN IF NOT EXISTS settlement_preferences_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    ADD COLUMN IF NOT EXISTS metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB;

ALTER TABLE wallets
    ADD CONSTRAINT chk_wallets_currency_code_format_ext CHECK (
        currency_code IS NULL OR currency_code ~ '^[A-Z]{3}$'
    );

ALTER TABLE wallets
    ADD CONSTRAINT chk_wallets_reserve_ratio_range CHECK (
        reserve_ratio IS NULL OR (reserve_ratio >= 0 AND reserve_ratio <= 1)
    );

ALTER TABLE wallets
    ADD CONSTRAINT chk_wallets_json_shapes_ext CHECK (
        jsonb_typeof(risk_limit_json) = 'object'
        AND jsonb_typeof(settlement_preferences_json) = 'object'
        AND jsonb_typeof(metadata_json) = 'object'
    );

CREATE INDEX IF NOT EXISTS ix_wallets_blockchain_address
    ON wallets (blockchain_address)
    WHERE blockchain_address IS NOT NULL;

CREATE INDEX IF NOT EXISTS ix_wallets_metadata_gin
    ON wallets USING GIN (metadata_json);

ALTER TABLE led_cards
    ADD COLUMN IF NOT EXISTS card_alias TEXT,
    ADD COLUMN IF NOT EXISTS card_batch_code TEXT,
    ADD COLUMN IF NOT EXISTS manufacturer_name TEXT,
    ADD COLUMN IF NOT EXISTS firmware_version TEXT,
    ADD COLUMN IF NOT EXISTS secure_element_id TEXT,
    ADD COLUMN IF NOT EXISTS pin_retry_count INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS last_failed_handshake_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS last_location_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    ADD COLUMN IF NOT EXISTS replacement_for_led_card_id UUID,
    ADD COLUMN IF NOT EXISTS metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB;

ALTER TABLE led_cards
    ADD CONSTRAINT fk_led_cards_replacement_for
    FOREIGN KEY (replacement_for_led_card_id) REFERENCES led_cards (led_card_id)
    ON UPDATE CASCADE
    ON DELETE SET NULL;

ALTER TABLE led_cards
    ADD CONSTRAINT chk_led_cards_pin_retry_non_negative CHECK (pin_retry_count >= 0);

ALTER TABLE led_cards
    ADD CONSTRAINT chk_led_cards_json_shapes_ext CHECK (
        jsonb_typeof(last_location_json) = 'object'
        AND jsonb_typeof(metadata_json) = 'object'
    );

CREATE INDEX IF NOT EXISTS ix_led_cards_replacement_for
    ON led_cards (replacement_for_led_card_id)
    WHERE replacement_for_led_card_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS ix_led_cards_metadata_gin
    ON led_cards USING GIN (metadata_json);

ALTER TABLE orders
    ADD COLUMN IF NOT EXISTS order_code TEXT,
    ADD COLUMN IF NOT EXISTS parent_order_id UUID,
    ADD COLUMN IF NOT EXISTS quote_id UUID,
    ADD COLUMN IF NOT EXISTS business_unit_id UUID,
    ADD COLUMN IF NOT EXISTS service_provider_user_id UUID,
    ADD COLUMN IF NOT EXISTS delivery_window_start TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS delivery_window_end TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS promised_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS completed_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS return_requested_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS return_completed_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS loyalty_points_earned DECIMAL(18,4) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS loyalty_points_redeemed DECIMAL(18,4) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS coupon_code TEXT,
    ADD COLUMN IF NOT EXISTS fraud_review_status TEXT,
    ADD COLUMN IF NOT EXISTS fulfillment_status TEXT,
    ADD COLUMN IF NOT EXISTS invoice_document_ref TEXT,
    ADD COLUMN IF NOT EXISTS receipt_document_ref TEXT,
    ADD COLUMN IF NOT EXISTS route_snapshot_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    ADD COLUMN IF NOT EXISTS pricing_snapshot_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    ADD COLUMN IF NOT EXISTS item_snapshot_json JSONB NOT NULL DEFAULT '[]'::JSONB,
    ADD COLUMN IF NOT EXISTS tax_snapshot_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    ADD COLUMN IF NOT EXISTS metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB;

ALTER TABLE orders
    ADD CONSTRAINT fk_orders_parent_order
    FOREIGN KEY (parent_order_id) REFERENCES orders (order_id)
    ON UPDATE CASCADE
    ON DELETE SET NULL;

ALTER TABLE orders
    ADD CONSTRAINT fk_orders_service_provider_user
    FOREIGN KEY (service_provider_user_id) REFERENCES users (user_id)
    ON UPDATE CASCADE
    ON DELETE SET NULL;

ALTER TABLE orders
    ADD CONSTRAINT chk_orders_loyalty_non_negative CHECK (
        loyalty_points_earned >= 0
        AND loyalty_points_redeemed >= 0
    );

ALTER TABLE orders
    ADD CONSTRAINT chk_orders_json_shapes_ext CHECK (
        jsonb_typeof(route_snapshot_json) = 'object'
        AND jsonb_typeof(pricing_snapshot_json) = 'object'
        AND jsonb_typeof(item_snapshot_json) = 'array'
        AND jsonb_typeof(tax_snapshot_json) = 'object'
        AND jsonb_typeof(metadata_json) = 'object'
    );

CREATE UNIQUE INDEX IF NOT EXISTS ux_orders_order_code
    ON orders (order_code)
    WHERE order_code IS NOT NULL;

CREATE INDEX IF NOT EXISTS ix_orders_parent_order_id
    ON orders (parent_order_id)
    WHERE parent_order_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS ix_orders_metadata_gin
    ON orders USING GIN (metadata_json);

ALTER TABLE transactions
    ADD COLUMN IF NOT EXISTS processor_name TEXT,
    ADD COLUMN IF NOT EXISTS processor_transaction_id TEXT,
    ADD COLUMN IF NOT EXISTS processor_status TEXT,
    ADD COLUMN IF NOT EXISTS idempotency_key TEXT,
    ADD COLUMN IF NOT EXISTS installment_count INTEGER,
    ADD COLUMN IF NOT EXISTS installment_index INTEGER,
    ADD COLUMN IF NOT EXISTS chargeback_reason TEXT,
    ADD COLUMN IF NOT EXISTS dispute_case_ref TEXT,
    ADD COLUMN IF NOT EXISTS tax_amount_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS net_amount_brl DECIMAL(18,4),
    ADD COLUMN IF NOT EXISTS reserved_until TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS reconciliation_batch_ref TEXT,
    ADD COLUMN IF NOT EXISTS receipt_document_ref TEXT,
    ADD COLUMN IF NOT EXISTS ledger_partition_key TEXT,
    ADD COLUMN IF NOT EXISTS risk_snapshot_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    ADD COLUMN IF NOT EXISTS processor_payload_json JSONB NOT NULL DEFAULT '{}'::JSONB;

ALTER TABLE transactions
    ADD CONSTRAINT chk_transactions_installments CHECK (
        (installment_count IS NULL OR installment_count > 0)
        AND (installment_index IS NULL OR installment_index > 0)
        AND (
            installment_count IS NULL
            OR installment_index IS NULL
            OR installment_index <= installment_count
        )
    );

ALTER TABLE transactions
    ADD CONSTRAINT chk_transactions_tax_amount_non_negative CHECK (tax_amount_brl >= 0);

ALTER TABLE transactions
    ADD CONSTRAINT chk_transactions_net_amount_non_negative CHECK (
        net_amount_brl IS NULL OR net_amount_brl >= 0
    );

ALTER TABLE transactions
    ADD CONSTRAINT chk_transactions_json_shapes_ext CHECK (
        jsonb_typeof(risk_snapshot_json) = 'object'
        AND jsonb_typeof(processor_payload_json) = 'object'
    );

CREATE UNIQUE INDEX IF NOT EXISTS ux_transactions_idempotency_key
    ON transactions (idempotency_key)
    WHERE idempotency_key IS NOT NULL;

CREATE INDEX IF NOT EXISTS ix_transactions_processor_transaction_id
    ON transactions (processor_transaction_id)
    WHERE processor_transaction_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS ix_transactions_metadata_gin
    ON transactions USING GIN (metadata_json);

ALTER TABLE equity_ledger
    ADD COLUMN IF NOT EXISTS cap_table_round_ref TEXT,
    ADD COLUMN IF NOT EXISTS board_resolution_ref TEXT,
    ADD COLUMN IF NOT EXISTS vesting_cliff_days INTEGER,
    ADD COLUMN IF NOT EXISTS lock_reason TEXT,
    ADD COLUMN IF NOT EXISTS unlock_reason TEXT,
    ADD COLUMN IF NOT EXISTS jurisdiction_code CHAR(2),
    ADD COLUMN IF NOT EXISTS tax_withholding_brl DECIMAL(18,4),
    ADD COLUMN IF NOT EXISTS valuation_cap_brl DECIMAL(18,4),
    ADD COLUMN IF NOT EXISTS diluted_ownership_pct DECIMAL(9,6),
    ADD COLUMN IF NOT EXISTS fully_diluted_supply_nex DECIMAL(18,8),
    ADD COLUMN IF NOT EXISTS governance_snapshot_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    ADD COLUMN IF NOT EXISTS metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB;

ALTER TABLE equity_ledger
    ADD CONSTRAINT chk_equity_ledger_optional_money_non_negative CHECK (
        (tax_withholding_brl IS NULL OR tax_withholding_brl >= 0)
        AND (valuation_cap_brl IS NULL OR valuation_cap_brl >= 0)
        AND (fully_diluted_supply_nex IS NULL OR fully_diluted_supply_nex >= 0)
    );

ALTER TABLE equity_ledger
    ADD CONSTRAINT chk_equity_ledger_percent_range CHECK (
        diluted_ownership_pct IS NULL OR (diluted_ownership_pct >= 0 AND diluted_ownership_pct <= 100)
    );

ALTER TABLE equity_ledger
    ADD CONSTRAINT chk_equity_ledger_vesting_cliff_non_negative CHECK (
        vesting_cliff_days IS NULL OR vesting_cliff_days >= 0
    );

ALTER TABLE equity_ledger
    ADD CONSTRAINT chk_equity_ledger_jurisdiction_format CHECK (
        jurisdiction_code IS NULL OR jurisdiction_code ~ '^[A-Z]{2}$'
    );

ALTER TABLE equity_ledger
    ADD CONSTRAINT chk_equity_ledger_json_shapes_ext CHECK (
        jsonb_typeof(governance_snapshot_json) = 'object'
        AND jsonb_typeof(metadata_json) = 'object'
    );

CREATE INDEX IF NOT EXISTS ix_equity_ledger_round_ref
    ON equity_ledger (cap_table_round_ref)
    WHERE cap_table_round_ref IS NOT NULL;

CREATE INDEX IF NOT EXISTS ix_equity_ledger_metadata_gin
    ON equity_ledger USING GIN (metadata_json);

COMMIT;
