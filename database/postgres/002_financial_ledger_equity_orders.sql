-- Valley Hybrid DB Bootstrap - Step 2
-- Transaction ledger, Smart Equity ledger and master orders.
-- Requires database/postgres/001_core_identity_wallets.sql.

BEGIN;

SET search_path = public;

CREATE TYPE transaction_type_enum AS ENUM (
    'P2P',
    'PURCHASE',
    'PAYMENT',
    'PAYOUT',
    'REFUND',
    'CHARGEBACK',
    'FEE',
    'ADJUSTMENT',
    'SPLIT',
    'ESCROW_HOLD',
    'ESCROW_RELEASE'
);

CREATE TYPE transaction_status_enum AS ENUM (
    'PENDING',
    'AUTHORIZED',
    'SETTLED',
    'FAILED',
    'CANCELLED',
    'REVERSED'
);

CREATE TYPE equity_event_type_enum AS ENUM (
    'MINT',
    'ALLOCATE',
    'TRANSFER',
    'LOCK',
    'UNLOCK',
    'VEST',
    'BURN',
    'CERTIFY',
    'DRAG_ALONG_FLAG',
    'TAG_ALONG_FLAG'
);

CREATE TYPE order_domain_enum AS ENUM ('FOOD', 'MOVE', 'DROPSHIP');
CREATE TYPE order_status_enum AS ENUM (
    'DRAFT',
    'PLACED',
    'CONFIRMED',
    'PREPARING',
    'IN_TRANSIT',
    'DELIVERED',
    'COMPLETED',
    'CANCELLED',
    'REFUNDED',
    'DISPUTED'
);

CREATE TABLE orders (
    order_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    wallet_id UUID NOT NULL,
    order_domain order_domain_enum NOT NULL,
    order_status order_status_enum NOT NULL DEFAULT 'DRAFT',
    merchant_user_id UUID,
    rider_user_id UUID,
    affiliate_user_id UUID,
    source_channel TEXT NOT NULL DEFAULT 'APP',
    currency_code CHAR(3) NOT NULL DEFAULT 'BRL',
    subtotal_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    delivery_fee_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    service_fee_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    discount_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    tax_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    total_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    total_nex DECIMAL(18,8) NOT NULL DEFAULT 0,
    payment_transaction_id UUID,
    pickup_address_json JSONB,
    dropoff_address_json JSONB,
    scheduled_for TIMESTAMPTZ,
    confirmed_at TIMESTAMPTZ,
    dispatched_at TIMESTAMPTZ,
    delivered_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,
    cancellation_reason TEXT,
    customer_notes TEXT,
    ops_notes TEXT,
    restaurant_user_id UUID,
    kitchen_status TEXT,
    prep_started_at TIMESTAMPTZ,
    route_distance_km DECIMAL(12,3),
    route_duration_sec INTEGER,
    surge_multiplier DECIMAL(8,4) NOT NULL DEFAULT 1,
    vehicle_category TEXT,
    supplier_name TEXT,
    supplier_sku TEXT,
    tracking_code TEXT,
    tracking_provider TEXT,
    customs_status TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_orders_user
        FOREIGN KEY (user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_orders_wallet
        FOREIGN KEY (wallet_id) REFERENCES wallets (wallet_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_orders_merchant_user
        FOREIGN KEY (merchant_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_orders_rider_user
        FOREIGN KEY (rider_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_orders_affiliate_user
        FOREIGN KEY (affiliate_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_orders_restaurant_user
        FOREIGN KEY (restaurant_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT chk_orders_currency_code_format CHECK (currency_code ~ '^[A-Z]{3}$'),
    CONSTRAINT chk_orders_amounts_non_negative CHECK (
        subtotal_brl >= 0
        AND delivery_fee_brl >= 0
        AND service_fee_brl >= 0
        AND discount_brl >= 0
        AND tax_brl >= 0
        AND total_brl >= 0
        AND total_nex >= 0
    ),
    CONSTRAINT chk_orders_total_brl_consistency CHECK (
        total_brl = subtotal_brl + delivery_fee_brl + service_fee_brl + tax_brl - discount_brl
    ),
    CONSTRAINT chk_orders_total_nex_precision CHECK (total_nex >= 0),
    CONSTRAINT chk_orders_route_metrics CHECK (
        route_distance_km IS NULL OR route_distance_km >= 0
    ),
    CONSTRAINT chk_orders_route_duration CHECK (
        route_duration_sec IS NULL OR route_duration_sec >= 0
    ),
    CONSTRAINT chk_orders_surge_multiplier CHECK (surge_multiplier >= 1),
    CONSTRAINT chk_orders_timeline CHECK (
        (confirmed_at IS NULL OR confirmed_at >= created_at)
        AND (dispatched_at IS NULL OR confirmed_at IS NULL OR dispatched_at >= confirmed_at)
        AND (delivered_at IS NULL OR dispatched_at IS NULL OR delivered_at >= dispatched_at)
        AND (cancelled_at IS NULL OR cancelled_at >= created_at)
    ),
    CONSTRAINT chk_orders_food_reserved_fields CHECK (
        order_domain <> 'FOOD'
        OR restaurant_user_id IS NOT NULL
        OR order_status = 'DRAFT'
    ),
    CONSTRAINT chk_orders_move_reserved_fields CHECK (
        order_domain <> 'MOVE'
        OR rider_user_id IS NOT NULL
        OR order_status IN ('DRAFT', 'PLACED')
    ),
    CONSTRAINT chk_orders_dropship_reserved_fields CHECK (
        order_domain <> 'DROPSHIP'
        OR supplier_name IS NOT NULL
        OR order_status = 'DRAFT'
    )
);

CREATE INDEX ix_orders_user_id
    ON orders (user_id);

CREATE INDEX ix_orders_wallet_id
    ON orders (wallet_id);

CREATE INDEX ix_orders_domain_status
    ON orders (order_domain, order_status);

CREATE INDEX ix_orders_merchant_user_id
    ON orders (merchant_user_id)
    WHERE merchant_user_id IS NOT NULL;

CREATE INDEX ix_orders_rider_user_id
    ON orders (rider_user_id)
    WHERE rider_user_id IS NOT NULL;

CREATE INDEX ix_orders_affiliate_user_id
    ON orders (affiliate_user_id)
    WHERE affiliate_user_id IS NOT NULL;

CREATE INDEX ix_orders_restaurant_user_id
    ON orders (restaurant_user_id)
    WHERE restaurant_user_id IS NOT NULL;

CREATE INDEX ix_orders_created_at
    ON orders (created_at);

CREATE INDEX ix_orders_tracking
    ON orders (tracking_provider, tracking_code)
    WHERE tracking_code IS NOT NULL;

CREATE TABLE transactions (
    transaction_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    wallet_id UUID NOT NULL,
    counterparty_user_id UUID,
    counterparty_wallet_id UUID,
    transaction_type transaction_type_enum NOT NULL,
    transaction_status transaction_status_enum NOT NULL DEFAULT 'PENDING',
    order_id UUID,
    asset_code wallet_asset_enum NOT NULL,
    amount_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    amount_nex DECIMAL(18,8) NOT NULL DEFAULT 0,
    fee_amount_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    platform_amount_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    merchant_amount_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    affiliate_amount_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    escrow_amount_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    fx_rate DECIMAL(18,8),
    reference_code TEXT NOT NULL,
    external_reference TEXT,
    channel TEXT NOT NULL DEFAULT 'APP',
    origin_module TEXT NOT NULL,
    description TEXT,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    authorized_at TIMESTAMPTZ,
    settled_at TIMESTAMPTZ,
    failed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_transactions_user
        FOREIGN KEY (user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_transactions_wallet
        FOREIGN KEY (wallet_id) REFERENCES wallets (wallet_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_transactions_counterparty_user
        FOREIGN KEY (counterparty_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_transactions_counterparty_wallet
        FOREIGN KEY (counterparty_wallet_id) REFERENCES wallets (wallet_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_transactions_order
        FOREIGN KEY (order_id) REFERENCES orders (order_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT ux_transactions_reference_code UNIQUE (reference_code),
    CONSTRAINT chk_transactions_amounts_non_negative CHECK (
        amount_brl >= 0
        AND amount_nex >= 0
        AND fee_amount_brl >= 0
        AND platform_amount_brl >= 0
        AND merchant_amount_brl >= 0
        AND affiliate_amount_brl >= 0
        AND escrow_amount_brl >= 0
    ),
    CONSTRAINT chk_transactions_has_value CHECK (
        amount_brl > 0
        OR amount_nex > 0
        OR fee_amount_brl > 0
        OR platform_amount_brl > 0
        OR merchant_amount_brl > 0
        OR affiliate_amount_brl > 0
        OR escrow_amount_brl > 0
    ),
    CONSTRAINT chk_transactions_asset_amount_coherence CHECK (
        (
            asset_code = 'BRL'
            AND amount_nex = 0
        )
        OR
        (
            asset_code = 'NEX'
            AND amount_brl = 0
            AND fee_amount_brl = 0
            AND platform_amount_brl = 0
            AND merchant_amount_brl = 0
            AND affiliate_amount_brl = 0
            AND escrow_amount_brl = 0
        )
    ),
    CONSTRAINT chk_transactions_fx_rate_positive CHECK (fx_rate IS NULL OR fx_rate > 0),
    CONSTRAINT chk_transactions_reference_not_blank CHECK (btrim(reference_code) <> ''),
    CONSTRAINT chk_transactions_origin_module_not_blank CHECK (btrim(origin_module) <> ''),
    CONSTRAINT chk_transactions_status_timestamps CHECK (
        (transaction_status <> 'AUTHORIZED' OR authorized_at IS NOT NULL)
        AND (transaction_status <> 'SETTLED' OR settled_at IS NOT NULL)
        AND (transaction_status <> 'FAILED' OR failed_at IS NOT NULL)
        AND (settled_at IS NULL OR authorized_at IS NULL OR settled_at >= authorized_at)
        AND (failed_at IS NULL OR authorized_at IS NULL OR failed_at >= authorized_at)
    )
);

CREATE UNIQUE INDEX ux_transactions_external_reference
    ON transactions (external_reference)
    WHERE external_reference IS NOT NULL;

CREATE INDEX ix_transactions_user_id
    ON transactions (user_id);

CREATE INDEX ix_transactions_wallet_id
    ON transactions (wallet_id);

CREATE INDEX ix_transactions_counterparty_user_id
    ON transactions (counterparty_user_id)
    WHERE counterparty_user_id IS NOT NULL;

CREATE INDEX ix_transactions_order_id
    ON transactions (order_id)
    WHERE order_id IS NOT NULL;

CREATE INDEX ix_transactions_status_type
    ON transactions (transaction_status, transaction_type);

CREATE INDEX ix_transactions_origin_module
    ON transactions (origin_module);

CREATE INDEX ix_transactions_created_at
    ON transactions (created_at);

ALTER TABLE orders
    ADD CONSTRAINT fk_orders_payment_transaction
    FOREIGN KEY (payment_transaction_id) REFERENCES transactions (transaction_id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT;

CREATE TABLE equity_ledger (
    equity_entry_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    wallet_id UUID NOT NULL,
    equity_event_type equity_event_type_enum NOT NULL,
    token_amount_nex DECIMAL(18,8) NOT NULL DEFAULT 0,
    unit_reference_brl DECIMAL(18,4),
    certificate_hash TEXT,
    certificate_uri TEXT,
    vesting_start_at TIMESTAMPTZ,
    vesting_end_at TIMESTAMPTZ,
    lock_until TIMESTAMPTZ,
    drag_along_clause BOOLEAN NOT NULL DEFAULT FALSE,
    tag_along_clause BOOLEAN NOT NULL DEFAULT FALSE,
    board_approval_ref TEXT,
    authorized_by_user_id UUID,
    source_transaction_id UUID,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_equity_ledger_user
        FOREIGN KEY (user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_equity_ledger_wallet
        FOREIGN KEY (wallet_id) REFERENCES wallets (wallet_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_equity_ledger_authorized_by_user
        FOREIGN KEY (authorized_by_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_equity_ledger_source_transaction
        FOREIGN KEY (source_transaction_id) REFERENCES transactions (transaction_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT chk_equity_ledger_token_amount CHECK (token_amount_nex >= 0),
    CONSTRAINT chk_equity_ledger_unit_reference CHECK (
        unit_reference_brl IS NULL OR unit_reference_brl >= 0
    ),
    CONSTRAINT chk_equity_ledger_vesting_window CHECK (
        vesting_start_at IS NULL
        OR vesting_end_at IS NULL
        OR vesting_end_at >= vesting_start_at
    ),
    CONSTRAINT chk_equity_ledger_certificate_events CHECK (
        equity_event_type <> 'CERTIFY'
        OR (certificate_hash IS NOT NULL AND btrim(certificate_hash) <> '')
    ),
    CONSTRAINT chk_equity_ledger_drag_along_event CHECK (
        equity_event_type <> 'DRAG_ALONG_FLAG'
        OR drag_along_clause = TRUE
    ),
    CONSTRAINT chk_equity_ledger_tag_along_event CHECK (
        equity_event_type <> 'TAG_ALONG_FLAG'
        OR tag_along_clause = TRUE
    ),
    CONSTRAINT chk_equity_ledger_positive_events CHECK (
        equity_event_type NOT IN ('MINT', 'ALLOCATE', 'TRANSFER', 'LOCK', 'UNLOCK', 'VEST', 'BURN')
        OR token_amount_nex > 0
    )
);

CREATE INDEX ix_equity_ledger_user_id
    ON equity_ledger (user_id);

CREATE INDEX ix_equity_ledger_wallet_id
    ON equity_ledger (wallet_id);

CREATE INDEX ix_equity_ledger_event_type
    ON equity_ledger (equity_event_type);

CREATE INDEX ix_equity_ledger_certificate_hash
    ON equity_ledger (certificate_hash)
    WHERE certificate_hash IS NOT NULL;

CREATE INDEX ix_equity_ledger_source_transaction_id
    ON equity_ledger (source_transaction_id)
    WHERE source_transaction_id IS NOT NULL;

CREATE INDEX ix_equity_ledger_created_at
    ON equity_ledger (created_at);

CREATE OR REPLACE FUNCTION prevent_append_only_mutation()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE EXCEPTION '% is append-only. Operation % is not allowed.', TG_TABLE_NAME, TG_OP;
END;
$$;

CREATE OR REPLACE FUNCTION assert_order_wallet_owner()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    wallet_owner_id UUID;
    wallet_asset wallet_asset_enum;
BEGIN
    SELECT user_id, asset_code
      INTO wallet_owner_id, wallet_asset
      FROM wallets
     WHERE wallet_id = NEW.wallet_id;

    IF wallet_owner_id IS NULL THEN
        RAISE EXCEPTION 'Wallet % does not exist for order %', NEW.wallet_id, NEW.order_id;
    END IF;

    IF wallet_owner_id <> NEW.user_id THEN
        RAISE EXCEPTION 'Order wallet owner % differs from order user %', wallet_owner_id, NEW.user_id;
    END IF;

    IF wallet_asset = 'BRL' AND NEW.total_nex <> 0 THEN
        RAISE EXCEPTION 'BRL order wallet cannot carry total_nex value for order %', NEW.order_id;
    END IF;

    IF wallet_asset = 'NEX' AND NEW.total_brl <> 0 THEN
        RAISE EXCEPTION 'NEX order wallet cannot carry total_brl value for order %', NEW.order_id;
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION assert_transaction_wallets()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    wallet_owner_id UUID;
    wallet_asset wallet_asset_enum;
    counterparty_owner_id UUID;
    counterparty_asset wallet_asset_enum;
BEGIN
    SELECT user_id, asset_code
      INTO wallet_owner_id, wallet_asset
      FROM wallets
     WHERE wallet_id = NEW.wallet_id;

    IF wallet_owner_id IS NULL THEN
        RAISE EXCEPTION 'Wallet % does not exist for transaction %', NEW.wallet_id, NEW.transaction_id;
    END IF;

    IF wallet_owner_id <> NEW.user_id THEN
        RAISE EXCEPTION 'Transaction wallet owner % differs from user %', wallet_owner_id, NEW.user_id;
    END IF;

    IF wallet_asset <> NEW.asset_code THEN
        RAISE EXCEPTION 'Transaction asset % differs from wallet asset %', NEW.asset_code, wallet_asset;
    END IF;

    IF NEW.counterparty_wallet_id IS NOT NULL THEN
        SELECT user_id, asset_code
          INTO counterparty_owner_id, counterparty_asset
          FROM wallets
         WHERE wallet_id = NEW.counterparty_wallet_id;

        IF counterparty_owner_id IS NULL THEN
            RAISE EXCEPTION 'Counterparty wallet % does not exist', NEW.counterparty_wallet_id;
        END IF;

        IF NEW.counterparty_user_id IS NULL THEN
            RAISE EXCEPTION 'counterparty_user_id is required when counterparty_wallet_id is present';
        END IF;

        IF counterparty_owner_id <> NEW.counterparty_user_id THEN
            RAISE EXCEPTION 'Counterparty wallet owner % differs from counterparty user %',
                counterparty_owner_id, NEW.counterparty_user_id;
        END IF;

        IF counterparty_asset <> NEW.asset_code THEN
            RAISE EXCEPTION 'Counterparty wallet asset % differs from transaction asset %',
                counterparty_asset, NEW.asset_code;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION assert_equity_ledger_entry()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    wallet_owner_id UUID;
    wallet_asset wallet_asset_enum;
    wallet_type_value wallet_type_enum;
    current_supply DECIMAL(18,8);
    projected_supply DECIMAL(18,8);
BEGIN
    SELECT user_id, asset_code, wallet_type
      INTO wallet_owner_id, wallet_asset, wallet_type_value
      FROM wallets
     WHERE wallet_id = NEW.wallet_id;

    IF wallet_owner_id IS NULL THEN
        RAISE EXCEPTION 'Wallet % does not exist for equity entry %', NEW.wallet_id, NEW.equity_entry_id;
    END IF;

    IF wallet_owner_id <> NEW.user_id THEN
        RAISE EXCEPTION 'Equity wallet owner % differs from user %', wallet_owner_id, NEW.user_id;
    END IF;

    IF wallet_asset <> 'NEX' THEN
        RAISE EXCEPTION 'Smart Equity ledger requires NEX wallet. Found %', wallet_asset;
    END IF;

    IF wallet_type_value <> 'EQUITY' THEN
        RAISE EXCEPTION 'Smart Equity ledger requires EQUITY wallet. Found %', wallet_type_value;
    END IF;

    SELECT COALESCE(
        SUM(
            CASE
                WHEN equity_event_type = 'MINT' THEN token_amount_nex
                WHEN equity_event_type = 'BURN' THEN -token_amount_nex
                ELSE 0
            END
        ),
        0
    )
      INTO current_supply
      FROM equity_ledger;

    projected_supply :=
        current_supply
        + CASE
            WHEN NEW.equity_event_type = 'MINT' THEN NEW.token_amount_nex
            WHEN NEW.equity_event_type = 'BURN' THEN -NEW.token_amount_nex
            ELSE 0
          END;

    IF projected_supply < 0 THEN
        RAISE EXCEPTION 'Smart Equity projected supply cannot be negative. Projected %', projected_supply;
    END IF;

    IF projected_supply > 1000000.00000000 THEN
        RAISE EXCEPTION 'Smart Equity supply cap exceeded. Projected %, cap 1000000.00000000', projected_supply;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_orders_set_updated_at
BEFORE UPDATE ON orders
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_orders_assert_wallet_owner
BEFORE INSERT OR UPDATE OF user_id, wallet_id, total_brl, total_nex ON orders
FOR EACH ROW
EXECUTE FUNCTION assert_order_wallet_owner();

CREATE TRIGGER trg_transactions_prevent_update
BEFORE UPDATE ON transactions
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

CREATE TRIGGER trg_transactions_prevent_delete
BEFORE DELETE ON transactions
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

CREATE TRIGGER trg_transactions_assert_wallets
BEFORE INSERT ON transactions
FOR EACH ROW
EXECUTE FUNCTION assert_transaction_wallets();

CREATE TRIGGER trg_equity_ledger_prevent_update
BEFORE UPDATE ON equity_ledger
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

CREATE TRIGGER trg_equity_ledger_prevent_delete
BEFORE DELETE ON equity_ledger
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

CREATE TRIGGER trg_equity_ledger_assert_entry
BEFORE INSERT ON equity_ledger
FOR EACH ROW
EXECUTE FUNCTION assert_equity_ledger_entry();

COMMIT;
