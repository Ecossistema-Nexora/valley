-- Valley Hybrid DB Bootstrap - Foundation Commerce Operations v47.
-- Este arquivo implanta os contratos iniciais dos modulos REPLY, STOCK, WMS e MARKETPLACE.
-- A regra core-first continua soberana: toda tabela operacional aponta para public.users.user_id.
-- Execute depois de 001, 002, 004, 005 e 007, porque usa users, wallets, orders, transactions e module_delivery_registry.

BEGIN;

SET search_path = public;

-- supplier_status_enum controla o lifecycle de fornecedores usados por Stock e Marketplace.
CREATE TYPE supplier_status_enum AS ENUM ('PENDING', 'ACTIVE', 'SUSPENDED', 'ARCHIVED');

-- warehouse_status_enum controla o lifecycle de armazens fisicos ou virtuais do WMS.
CREATE TYPE warehouse_status_enum AS ENUM ('PLANNED', 'ACTIVE', 'PAUSED', 'CLOSED');

-- inventory_item_type_enum separa produto fisico, digital, servico e bundle.
CREATE TYPE inventory_item_type_enum AS ENUM ('PHYSICAL', 'DIGITAL', 'SERVICE', 'BUNDLE');

-- inventory_item_status_enum controla publicacao e uso operacional do item.
CREATE TYPE inventory_item_status_enum AS ENUM ('DRAFT', 'ACTIVE', 'PAUSED', 'ARCHIVED');

-- inventory_lot_status_enum controla disponibilidade de lote dentro do estoque.
CREATE TYPE inventory_lot_status_enum AS ENUM ('AVAILABLE', 'RESERVED', 'QUARANTINED', 'DEPLETED', 'EXPIRED');

-- inventory_movement_type_enum descreve cada evento append-only que muda o estoque.
CREATE TYPE inventory_movement_type_enum AS ENUM ('RECEIVE', 'RESERVE', 'RELEASE', 'PICK', 'PACK', 'SHIP', 'ADJUST', 'RETURN', 'SCRAP', 'TRANSFER_IN', 'TRANSFER_OUT');

-- marketplace_listing_status_enum controla o lifecycle do anuncio comercial.
CREATE TYPE marketplace_listing_status_enum AS ENUM ('DRAFT', 'ACTIVE', 'PAUSED', 'SOLD_OUT', 'ARCHIVED');

-- procurement_order_status_enum controla compras B2B ou reposicao de estoque.
CREATE TYPE procurement_order_status_enum AS ENUM ('DRAFT', 'PLACED', 'CONFIRMED', 'PARTIAL_RECEIVED', 'RECEIVED', 'CANCELLED', 'DISPUTED');

-- work_order_status_enum controla ordens de servico do REPLY/ERP operacional.
CREATE TYPE work_order_status_enum AS ENUM ('DRAFT', 'OPEN', 'ASSIGNED', 'IN_PROGRESS', 'WAITING_PARTS', 'COMPLETED', 'CANCELLED');

-- suppliers registra fornecedores externos ou internos usados por Stock, Marketplace e REPLY.
CREATE TABLE suppliers (
    supplier_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    supplier_user_id UUID NOT NULL UNIQUE,
    module_code TEXT NOT NULL DEFAULT 'STOCK',
    supplier_status supplier_status_enum NOT NULL DEFAULT 'PENDING',
    legal_name TEXT NOT NULL,
    trade_name TEXT,
    external_reference TEXT,
    default_margin_rate DECIMAL(8,4) NOT NULL DEFAULT 0.5000,
    lead_time_days INTEGER NOT NULL DEFAULT 0,
    rating_score DECIMAL(5,2) NOT NULL DEFAULT 0,
    contact_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    compliance_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_suppliers_user
        FOREIGN KEY (supplier_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_suppliers_module
        FOREIGN KEY (module_code) REFERENCES module_delivery_registry (module_code)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT chk_suppliers_legal_name CHECK (btrim(legal_name) <> ''),
    CONSTRAINT chk_suppliers_margin CHECK (default_margin_rate >= 0 AND default_margin_rate <= 1),
    CONSTRAINT chk_suppliers_lead_time CHECK (lead_time_days >= 0),
    CONSTRAINT chk_suppliers_rating CHECK (rating_score >= 0 AND rating_score <= 100)
);

-- warehouses registra armazens, dark stores, hubs ou locais virtuais de estoque.
CREATE TABLE warehouses (
    warehouse_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_user_id UUID NOT NULL,
    manager_user_id UUID,
    module_code TEXT NOT NULL DEFAULT 'WMS',
    warehouse_code TEXT NOT NULL UNIQUE,
    warehouse_name TEXT NOT NULL,
    warehouse_status warehouse_status_enum NOT NULL DEFAULT 'PLANNED',
    address_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    geo_json JSONB,
    capacity_units DECIMAL(18,4) NOT NULL DEFAULT 0,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_warehouses_owner
        FOREIGN KEY (owner_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_warehouses_manager
        FOREIGN KEY (manager_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_warehouses_module
        FOREIGN KEY (module_code) REFERENCES module_delivery_registry (module_code)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT chk_warehouses_code CHECK (warehouse_code ~ '^[A-Z0-9_-]{2,80}$'),
    CONSTRAINT chk_warehouses_name CHECK (btrim(warehouse_name) <> ''),
    CONSTRAINT chk_warehouses_capacity CHECK (capacity_units >= 0)
);

-- inventory_items registra produtos, servicos e bundles comercializaveis.
CREATE TABLE inventory_items (
    item_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_user_id UUID NOT NULL,
    module_code TEXT NOT NULL DEFAULT 'MARKETPLACE',
    item_sku TEXT NOT NULL,
    external_sku TEXT,
    item_name TEXT NOT NULL,
    item_description TEXT,
    item_type inventory_item_type_enum NOT NULL DEFAULT 'PHYSICAL',
    item_status inventory_item_status_enum NOT NULL DEFAULT 'DRAFT',
    category_path TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
    unit_of_measure TEXT NOT NULL DEFAULT 'UNIT',
    base_price_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    cost_reference_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    tax_class TEXT,
    attributes_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_inventory_items_merchant
        FOREIGN KEY (merchant_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_inventory_items_module
        FOREIGN KEY (module_code) REFERENCES module_delivery_registry (module_code)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT ux_inventory_items_merchant_sku UNIQUE (merchant_user_id, item_sku),
    CONSTRAINT chk_inventory_items_sku CHECK (btrim(item_sku) <> ''),
    CONSTRAINT chk_inventory_items_name CHECK (btrim(item_name) <> ''),
    CONSTRAINT chk_inventory_items_unit CHECK (btrim(unit_of_measure) <> ''),
    CONSTRAINT chk_inventory_items_base_price CHECK (base_price_brl >= 0),
    CONSTRAINT chk_inventory_items_cost CHECK (cost_reference_brl >= 0)
);

-- inventory_lots registra saldo por lote e armazem, sem ser ledger financeiro.
CREATE TABLE inventory_lots (
    inventory_lot_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_user_id UUID NOT NULL,
    item_id UUID NOT NULL,
    warehouse_id UUID NOT NULL,
    supplier_id UUID,
    lot_code TEXT NOT NULL,
    lot_status inventory_lot_status_enum NOT NULL DEFAULT 'AVAILABLE',
    quantity_available DECIMAL(18,4) NOT NULL DEFAULT 0,
    quantity_reserved DECIMAL(18,4) NOT NULL DEFAULT 0,
    quantity_damaged DECIMAL(18,4) NOT NULL DEFAULT 0,
    unit_cost_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    expires_at TIMESTAMPTZ,
    received_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_inventory_lots_owner
        FOREIGN KEY (owner_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_inventory_lots_item
        FOREIGN KEY (item_id) REFERENCES inventory_items (item_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_inventory_lots_warehouse
        FOREIGN KEY (warehouse_id) REFERENCES warehouses (warehouse_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_inventory_lots_supplier
        FOREIGN KEY (supplier_id) REFERENCES suppliers (supplier_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT ux_inventory_lots_item_warehouse_lot UNIQUE (item_id, warehouse_id, lot_code),
    CONSTRAINT chk_inventory_lots_code CHECK (btrim(lot_code) <> ''),
    CONSTRAINT chk_inventory_lots_quantities CHECK (
        quantity_available >= 0
        AND quantity_reserved >= 0
        AND quantity_damaged >= 0
    ),
    CONSTRAINT chk_inventory_lots_cost CHECK (unit_cost_brl >= 0)
);

-- inventory_movements e append-only para auditar toda mudanca de estoque.
CREATE TABLE inventory_movements (
    inventory_movement_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_user_id UUID NOT NULL,
    item_id UUID NOT NULL,
    warehouse_id UUID NOT NULL,
    source_lot_id UUID,
    actor_user_id UUID NOT NULL,
    order_id UUID,
    transaction_id UUID,
    movement_type inventory_movement_type_enum NOT NULL,
    quantity_delta DECIMAL(18,4) NOT NULL,
    unit_cost_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    movement_reason TEXT NOT NULL,
    reference_code TEXT,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_inventory_movements_owner
        FOREIGN KEY (owner_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_inventory_movements_item
        FOREIGN KEY (item_id) REFERENCES inventory_items (item_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_inventory_movements_warehouse
        FOREIGN KEY (warehouse_id) REFERENCES warehouses (warehouse_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_inventory_movements_lot
        FOREIGN KEY (source_lot_id) REFERENCES inventory_lots (inventory_lot_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_inventory_movements_actor
        FOREIGN KEY (actor_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_inventory_movements_order
        FOREIGN KEY (order_id) REFERENCES orders (order_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_inventory_movements_transaction
        FOREIGN KEY (transaction_id) REFERENCES transactions (transaction_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT chk_inventory_movements_quantity CHECK (quantity_delta <> 0),
    CONSTRAINT chk_inventory_movements_cost CHECK (unit_cost_brl >= 0),
    CONSTRAINT chk_inventory_movements_reason CHECK (btrim(movement_reason) <> ''),
    CONSTRAINT chk_inventory_movements_reference CHECK (reference_code IS NULL OR btrim(reference_code) <> '')
);

-- marketplace_listings liga item, merchant, wallet e preco publicado.
CREATE TABLE marketplace_listings (
    listing_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_user_id UUID NOT NULL,
    wallet_id UUID NOT NULL,
    item_id UUID NOT NULL,
    module_code TEXT NOT NULL DEFAULT 'MARKETPLACE',
    listing_status marketplace_listing_status_enum NOT NULL DEFAULT 'DRAFT',
    listing_title TEXT NOT NULL,
    listing_description TEXT,
    price_brl DECIMAL(18,4) NOT NULL,
    commission_rate DECIMAL(8,4) NOT NULL DEFAULT 0.1500,
    stock_strategy TEXT NOT NULL DEFAULT 'REAL_TIME',
    available_quantity_snapshot DECIMAL(18,4) NOT NULL DEFAULT 0,
    published_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_marketplace_listings_merchant
        FOREIGN KEY (merchant_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_marketplace_listings_wallet
        FOREIGN KEY (wallet_id) REFERENCES wallets (wallet_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_marketplace_listings_item
        FOREIGN KEY (item_id) REFERENCES inventory_items (item_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_marketplace_listings_module
        FOREIGN KEY (module_code) REFERENCES module_delivery_registry (module_code)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT ux_marketplace_listings_item_merchant UNIQUE (item_id, merchant_user_id),
    CONSTRAINT chk_marketplace_listings_title CHECK (btrim(listing_title) <> ''),
    CONSTRAINT chk_marketplace_listings_price CHECK (price_brl >= 0),
    CONSTRAINT chk_marketplace_listings_commission CHECK (commission_rate >= 0 AND commission_rate <= 1),
    CONSTRAINT chk_marketplace_listings_stock_strategy CHECK (stock_strategy IN ('REAL_TIME', 'RESERVE_ON_ORDER', 'PREORDER', 'DROPSHIP')),
    CONSTRAINT chk_marketplace_listings_quantity CHECK (available_quantity_snapshot >= 0),
    CONSTRAINT chk_marketplace_listings_publish CHECK (
        listing_status <> 'ACTIVE' OR published_at IS NOT NULL
    )
);

-- procurement_orders registra compras e reposicao de estoque no REPLY/ERP.
CREATE TABLE procurement_orders (
    procurement_order_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    buyer_user_id UUID NOT NULL,
    supplier_id UUID NOT NULL,
    supplier_user_id UUID NOT NULL,
    destination_warehouse_id UUID NOT NULL,
    wallet_id UUID,
    module_code TEXT NOT NULL DEFAULT 'REPLY',
    procurement_status procurement_order_status_enum NOT NULL DEFAULT 'DRAFT',
    expected_total_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    currency_code CHAR(3) NOT NULL DEFAULT 'BRL',
    external_reference TEXT,
    approved_by_user_id UUID,
    placed_at TIMESTAMPTZ,
    expected_delivery_at TIMESTAMPTZ,
    received_at TIMESTAMPTZ,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_procurement_orders_buyer
        FOREIGN KEY (buyer_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_procurement_orders_supplier
        FOREIGN KEY (supplier_id) REFERENCES suppliers (supplier_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_procurement_orders_supplier_user
        FOREIGN KEY (supplier_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_procurement_orders_warehouse
        FOREIGN KEY (destination_warehouse_id) REFERENCES warehouses (warehouse_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_procurement_orders_wallet
        FOREIGN KEY (wallet_id) REFERENCES wallets (wallet_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_procurement_orders_module
        FOREIGN KEY (module_code) REFERENCES module_delivery_registry (module_code)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_procurement_orders_approved_by
        FOREIGN KEY (approved_by_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT chk_procurement_orders_total CHECK (expected_total_brl >= 0),
    CONSTRAINT chk_procurement_orders_currency CHECK (currency_code = 'BRL'),
    CONSTRAINT chk_procurement_orders_timeline CHECK (
        expected_delivery_at IS NULL OR placed_at IS NULL OR expected_delivery_at >= placed_at
    ),
    CONSTRAINT chk_procurement_orders_received CHECK (
        received_at IS NULL OR placed_at IS NULL OR received_at >= placed_at
    )
);

-- procurement_order_items registra linhas de compra com quantidade e preco.
CREATE TABLE procurement_order_items (
    procurement_order_item_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    procurement_order_id UUID NOT NULL,
    buyer_user_id UUID NOT NULL,
    item_id UUID NOT NULL,
    quantity_ordered DECIMAL(18,4) NOT NULL,
    quantity_received DECIMAL(18,4) NOT NULL DEFAULT 0,
    unit_price_brl DECIMAL(18,4) NOT NULL,
    line_total_brl DECIMAL(18,4) GENERATED ALWAYS AS (quantity_ordered * unit_price_brl) STORED,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_procurement_order_items_order
        FOREIGN KEY (procurement_order_id) REFERENCES procurement_orders (procurement_order_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT fk_procurement_order_items_buyer
        FOREIGN KEY (buyer_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_procurement_order_items_item
        FOREIGN KEY (item_id) REFERENCES inventory_items (item_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT ux_procurement_order_items_order_item UNIQUE (procurement_order_id, item_id),
    CONSTRAINT chk_procurement_order_items_quantity CHECK (quantity_ordered > 0),
    CONSTRAINT chk_procurement_order_items_received CHECK (quantity_received >= 0 AND quantity_received <= quantity_ordered),
    CONSTRAINT chk_procurement_order_items_price CHECK (unit_price_brl >= 0)
);

-- service_work_orders registra ordens de servico e tarefas operacionais do REPLY.
CREATE TABLE service_work_orders (
    work_order_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    requester_user_id UUID NOT NULL,
    provider_user_id UUID,
    wallet_id UUID,
    order_id UUID,
    module_code TEXT NOT NULL DEFAULT 'REPLY',
    work_order_status work_order_status_enum NOT NULL DEFAULT 'DRAFT',
    title TEXT NOT NULL,
    description TEXT,
    service_address_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    estimate_amount_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    final_amount_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    scheduled_for TIMESTAMPTZ,
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,
    cancellation_reason TEXT,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_service_work_orders_requester
        FOREIGN KEY (requester_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_service_work_orders_provider
        FOREIGN KEY (provider_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_service_work_orders_wallet
        FOREIGN KEY (wallet_id) REFERENCES wallets (wallet_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_service_work_orders_order
        FOREIGN KEY (order_id) REFERENCES orders (order_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_service_work_orders_module
        FOREIGN KEY (module_code) REFERENCES module_delivery_registry (module_code)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT chk_service_work_orders_title CHECK (btrim(title) <> ''),
    CONSTRAINT chk_service_work_orders_estimate CHECK (estimate_amount_brl >= 0),
    CONSTRAINT chk_service_work_orders_final CHECK (final_amount_brl >= 0),
    CONSTRAINT chk_service_work_orders_timeline CHECK (
        (started_at IS NULL OR scheduled_for IS NULL OR started_at >= scheduled_for - INTERVAL '1 day')
        AND (completed_at IS NULL OR started_at IS NULL OR completed_at >= started_at)
        AND (cancelled_at IS NULL OR completed_at IS NULL)
    )
);

-- warehouse_cycle_counts e append-only para auditoria de contagem fisica no WMS.
CREATE TABLE warehouse_cycle_counts (
    cycle_count_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_user_id UUID NOT NULL,
    warehouse_id UUID NOT NULL,
    item_id UUID NOT NULL,
    counted_by_user_id UUID NOT NULL,
    expected_quantity DECIMAL(18,4) NOT NULL DEFAULT 0,
    counted_quantity DECIMAL(18,4) NOT NULL DEFAULT 0,
    variance_quantity DECIMAL(18,4) GENERATED ALWAYS AS (counted_quantity - expected_quantity) STORED,
    count_reason TEXT NOT NULL,
    counted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_warehouse_cycle_counts_owner
        FOREIGN KEY (owner_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_warehouse_cycle_counts_warehouse
        FOREIGN KEY (warehouse_id) REFERENCES warehouses (warehouse_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_warehouse_cycle_counts_item
        FOREIGN KEY (item_id) REFERENCES inventory_items (item_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_warehouse_cycle_counts_counted_by
        FOREIGN KEY (counted_by_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT chk_warehouse_cycle_counts_quantities CHECK (expected_quantity >= 0 AND counted_quantity >= 0),
    CONSTRAINT chk_warehouse_cycle_counts_reason CHECK (btrim(count_reason) <> '')
);

-- assert_foundation_wallet_owner impede usar wallet de outro usuario em listing, compra ou ordem de servico.
CREATE OR REPLACE FUNCTION assert_foundation_wallet_owner()
RETURNS TRIGGER AS $$
DECLARE
    expected_user_id UUID;
    checked_wallet_id UUID;
BEGIN
    IF TG_TABLE_NAME = 'marketplace_listings' THEN
        expected_user_id := NEW.merchant_user_id;
        checked_wallet_id := NEW.wallet_id;
    ELSIF TG_TABLE_NAME = 'procurement_orders' THEN
        expected_user_id := NEW.buyer_user_id;
        checked_wallet_id := NEW.wallet_id;
    ELSIF TG_TABLE_NAME = 'service_work_orders' THEN
        expected_user_id := NEW.requester_user_id;
        checked_wallet_id := NEW.wallet_id;
    END IF;

    IF checked_wallet_id IS NOT NULL
        AND NOT EXISTS (
            SELECT 1
            FROM wallets
            WHERE wallets.wallet_id = checked_wallet_id
              AND wallets.user_id = expected_user_id
        ) THEN
        RAISE EXCEPTION 'wallet_id % nao pertence ao user_id esperado % em %', checked_wallet_id, expected_user_id, TG_TABLE_NAME;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- assert_foundation_item_owner garante que lote, movimento e listing usem dono coerente com o item.
CREATE OR REPLACE FUNCTION assert_foundation_item_owner()
RETURNS TRIGGER AS $$
DECLARE
    expected_user_id UUID;
BEGIN
    IF TG_TABLE_NAME = 'inventory_lots' THEN
        expected_user_id := NEW.owner_user_id;
    ELSIF TG_TABLE_NAME = 'inventory_movements' THEN
        expected_user_id := NEW.owner_user_id;
    ELSIF TG_TABLE_NAME = 'marketplace_listings' THEN
        expected_user_id := NEW.merchant_user_id;
    ELSIF TG_TABLE_NAME = 'procurement_order_items' THEN
        expected_user_id := NEW.buyer_user_id;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM inventory_items
        WHERE inventory_items.item_id = NEW.item_id
          AND inventory_items.merchant_user_id = expected_user_id
    ) THEN
        RAISE EXCEPTION 'item_id % nao pertence ao user_id esperado % em %', NEW.item_id, expected_user_id, TG_TABLE_NAME;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Indices de fornecedores por usuario, status e modulo.
CREATE INDEX ix_suppliers_user_status
    ON suppliers (supplier_user_id, supplier_status);

-- Indice de armazens por dono e status.
CREATE INDEX ix_warehouses_owner_status
    ON warehouses (owner_user_id, warehouse_status);

-- Indice de itens por merchant e status.
CREATE INDEX ix_inventory_items_merchant_status
    ON inventory_items (merchant_user_id, item_status);

-- Indice de itens por SKU externo quando integracao existir.
CREATE INDEX ix_inventory_items_external_sku
    ON inventory_items (external_sku)
    WHERE external_sku IS NOT NULL;

-- Indice de lotes por item, armazem e status.
CREATE INDEX ix_inventory_lots_item_warehouse_status
    ON inventory_lots (item_id, warehouse_id, lot_status);

-- Indice de movimentos por dono e tempo para auditoria.
CREATE INDEX ix_inventory_movements_owner_created_at
    ON inventory_movements (owner_user_id, created_at);

-- Indice de movimentos por item e tempo para reconciliacao.
CREATE INDEX ix_inventory_movements_item_created_at
    ON inventory_movements (item_id, created_at);

-- Indice de listings por merchant e status.
CREATE INDEX ix_marketplace_listings_merchant_status
    ON marketplace_listings (merchant_user_id, listing_status);

-- Indice de listings ativos para vitrines.
CREATE INDEX ix_marketplace_listings_active_price
    ON marketplace_listings (listing_status, price_brl)
    WHERE listing_status = 'ACTIVE';

-- Indice de compras por comprador e status.
CREATE INDEX ix_procurement_orders_buyer_status
    ON procurement_orders (buyer_user_id, procurement_status, created_at);

-- Indice de compras por fornecedor.
CREATE INDEX ix_procurement_orders_supplier_status
    ON procurement_orders (supplier_user_id, procurement_status, created_at);

-- Indice de linhas de compra por item.
CREATE INDEX ix_procurement_order_items_item
    ON procurement_order_items (item_id, created_at);

-- Indice de ordens de servico por solicitante e status.
CREATE INDEX ix_service_work_orders_requester_status
    ON service_work_orders (requester_user_id, work_order_status, created_at);

-- Indice de ordens de servico por prestador e agenda.
CREATE INDEX ix_service_work_orders_provider_schedule
    ON service_work_orders (provider_user_id, scheduled_for)
    WHERE provider_user_id IS NOT NULL;

-- Indice de cycle count por armazem e item.
CREATE INDEX ix_warehouse_cycle_counts_warehouse_item
    ON warehouse_cycle_counts (warehouse_id, item_id, counted_at);

-- Triggers updated_at para tabelas mutaveis.
CREATE TRIGGER trg_suppliers_set_updated_at
BEFORE UPDATE ON suppliers
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_warehouses_set_updated_at
BEFORE UPDATE ON warehouses
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_inventory_items_set_updated_at
BEFORE UPDATE ON inventory_items
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_inventory_lots_set_updated_at
BEFORE UPDATE ON inventory_lots
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_marketplace_listings_set_updated_at
BEFORE UPDATE ON marketplace_listings
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_procurement_orders_set_updated_at
BEFORE UPDATE ON procurement_orders
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_procurement_order_items_set_updated_at
BEFORE UPDATE ON procurement_order_items
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_service_work_orders_set_updated_at
BEFORE UPDATE ON service_work_orders
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

-- Triggers de coerencia para wallet.
CREATE TRIGGER trg_marketplace_listings_wallet_owner
BEFORE INSERT OR UPDATE ON marketplace_listings
FOR EACH ROW
EXECUTE FUNCTION assert_foundation_wallet_owner();

CREATE TRIGGER trg_procurement_orders_wallet_owner
BEFORE INSERT OR UPDATE ON procurement_orders
FOR EACH ROW
EXECUTE FUNCTION assert_foundation_wallet_owner();

CREATE TRIGGER trg_service_work_orders_wallet_owner
BEFORE INSERT OR UPDATE ON service_work_orders
FOR EACH ROW
EXECUTE FUNCTION assert_foundation_wallet_owner();

-- Triggers de coerencia para dono do item.
CREATE TRIGGER trg_inventory_lots_item_owner
BEFORE INSERT OR UPDATE ON inventory_lots
FOR EACH ROW
EXECUTE FUNCTION assert_foundation_item_owner();

CREATE TRIGGER trg_inventory_movements_item_owner
BEFORE INSERT ON inventory_movements
FOR EACH ROW
EXECUTE FUNCTION assert_foundation_item_owner();

CREATE TRIGGER trg_marketplace_listings_item_owner
BEFORE INSERT OR UPDATE ON marketplace_listings
FOR EACH ROW
EXECUTE FUNCTION assert_foundation_item_owner();

CREATE TRIGGER trg_procurement_order_items_item_owner
BEFORE INSERT OR UPDATE ON procurement_order_items
FOR EACH ROW
EXECUTE FUNCTION assert_foundation_item_owner();

-- Triggers append-only para movimentos e contagens fisicas.
CREATE TRIGGER trg_inventory_movements_prevent_update
BEFORE UPDATE ON inventory_movements
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

CREATE TRIGGER trg_inventory_movements_prevent_delete
BEFORE DELETE ON inventory_movements
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

CREATE TRIGGER trg_warehouse_cycle_counts_prevent_update
BEFORE UPDATE ON warehouse_cycle_counts
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

CREATE TRIGGER trg_warehouse_cycle_counts_prevent_delete
BEFORE DELETE ON warehouse_cycle_counts
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

COMMENT ON TYPE supplier_status_enum IS 'Status operacional de fornecedor do Stock/Marketplace.';
COMMENT ON TYPE warehouse_status_enum IS 'Status de armazem ou hub WMS.';
COMMENT ON TYPE inventory_item_type_enum IS 'Tipo comercial do item: produto, servico, digital ou bundle.';
COMMENT ON TYPE inventory_item_status_enum IS 'Status do item antes de virar listing ou estoque ativo.';
COMMENT ON TYPE inventory_lot_status_enum IS 'Status do lote dentro do estoque.';
COMMENT ON TYPE inventory_movement_type_enum IS 'Tipo de evento append-only que movimenta estoque.';
COMMENT ON TYPE marketplace_listing_status_enum IS 'Status de anuncio no Marketplace.';
COMMENT ON TYPE procurement_order_status_enum IS 'Status de compra e reposicao no REPLY/ERP.';
COMMENT ON TYPE work_order_status_enum IS 'Status de ordem de servico operacional.';

COMMENT ON TABLE suppliers IS 'Fornecedores PJ ou parceiros usados por Stock, Marketplace e REPLY.';
COMMENT ON TABLE warehouses IS 'Armazens, hubs, dark stores ou locais virtuais do WMS.';
COMMENT ON TABLE inventory_items IS 'Catalogo de produtos, servicos, digitais e bundles.';
COMMENT ON TABLE inventory_lots IS 'Saldos por lote e armazem, com owner_user_id coerente com o item.';
COMMENT ON TABLE inventory_movements IS 'Ledger append-only de movimentos de estoque.';
COMMENT ON TABLE marketplace_listings IS 'Anuncios comerciais que ligam item, merchant, wallet e preco.';
COMMENT ON TABLE procurement_orders IS 'Compras B2B e reposicao de estoque do REPLY/ERP.';
COMMENT ON TABLE procurement_order_items IS 'Linhas de compra com quantidade, preco e total calculado.';
COMMENT ON TABLE service_work_orders IS 'Ordens de servico e tarefas operacionais do REPLY.';
COMMENT ON TABLE warehouse_cycle_counts IS 'Contagens fisicas append-only para auditoria WMS.';

COMMENT ON FUNCTION assert_foundation_wallet_owner() IS 'Trigger function que valida se wallet pertence ao usuario operacional esperado.';
COMMENT ON FUNCTION assert_foundation_item_owner() IS 'Trigger function que valida se item pertence ao usuario operacional esperado.';

COMMENT ON COLUMN suppliers.supplier_id IS 'PK UUID do fornecedor.';
COMMENT ON COLUMN suppliers.supplier_user_id IS 'FK para users.user_id do fornecedor.';
COMMENT ON COLUMN suppliers.module_code IS 'FK para module_delivery_registry, normalmente STOCK.';
COMMENT ON COLUMN suppliers.supplier_status IS 'Status operacional do fornecedor.';
COMMENT ON COLUMN suppliers.legal_name IS 'Razao social ou nome legal.';
COMMENT ON COLUMN suppliers.trade_name IS 'Nome fantasia opcional.';
COMMENT ON COLUMN suppliers.external_reference IS 'Codigo do fornecedor em sistema externo.';
COMMENT ON COLUMN suppliers.default_margin_rate IS 'Margem padrao para pricing de dropshipping.';
COMMENT ON COLUMN suppliers.lead_time_days IS 'Prazo medio de entrega em dias.';
COMMENT ON COLUMN suppliers.rating_score IS 'Score operacional de 0 a 100.';
COMMENT ON COLUMN suppliers.contact_json IS 'Contatos estruturados em JSONB.';
COMMENT ON COLUMN suppliers.compliance_json IS 'Dados de compliance e homologacao.';
COMMENT ON COLUMN suppliers.created_at IS 'Criacao do registro.';
COMMENT ON COLUMN suppliers.updated_at IS 'Ultima atualizacao do registro.';

COMMENT ON COLUMN warehouses.warehouse_id IS 'PK UUID do armazem.';
COMMENT ON COLUMN warehouses.owner_user_id IS 'FK para users.user_id do dono do armazem.';
COMMENT ON COLUMN warehouses.manager_user_id IS 'FK opcional para gestor operacional.';
COMMENT ON COLUMN warehouses.module_code IS 'FK para module_delivery_registry, normalmente WMS.';
COMMENT ON COLUMN warehouses.warehouse_code IS 'Codigo unico do armazem.';
COMMENT ON COLUMN warehouses.warehouse_name IS 'Nome simples do armazem.';
COMMENT ON COLUMN warehouses.warehouse_status IS 'Status operacional do armazem.';
COMMENT ON COLUMN warehouses.address_json IS 'Endereco estruturado em JSONB.';
COMMENT ON COLUMN warehouses.geo_json IS 'Localizacao opcional em formato GeoJSON.';
COMMENT ON COLUMN warehouses.capacity_units IS 'Capacidade total em unidade operacional.';
COMMENT ON COLUMN warehouses.metadata_json IS 'Metadados de integracao WMS.';
COMMENT ON COLUMN warehouses.created_at IS 'Criacao do registro.';
COMMENT ON COLUMN warehouses.updated_at IS 'Ultima atualizacao do registro.';

COMMENT ON COLUMN inventory_items.item_id IS 'PK UUID do item.';
COMMENT ON COLUMN inventory_items.merchant_user_id IS 'FK para users.user_id do merchant dono do item.';
COMMENT ON COLUMN inventory_items.module_code IS 'FK para module_delivery_registry, normalmente MARKETPLACE.';
COMMENT ON COLUMN inventory_items.item_sku IS 'SKU interno do merchant.';
COMMENT ON COLUMN inventory_items.external_sku IS 'SKU externo de fornecedor ou ERP.';
COMMENT ON COLUMN inventory_items.item_name IS 'Nome comercial do item.';
COMMENT ON COLUMN inventory_items.item_description IS 'Descricao comercial ou operacional.';
COMMENT ON COLUMN inventory_items.item_type IS 'Tipo do item.';
COMMENT ON COLUMN inventory_items.item_status IS 'Status do item.';
COMMENT ON COLUMN inventory_items.category_path IS 'Caminho de categoria para browse e analytics.';
COMMENT ON COLUMN inventory_items.unit_of_measure IS 'Unidade de medida, como UNIT, KG ou HOUR.';
COMMENT ON COLUMN inventory_items.base_price_brl IS 'Preco base em BRL.';
COMMENT ON COLUMN inventory_items.cost_reference_brl IS 'Custo de referencia em BRL.';
COMMENT ON COLUMN inventory_items.tax_class IS 'Classe fiscal ou tributaria.';
COMMENT ON COLUMN inventory_items.attributes_json IS 'Atributos flexiveis do produto.';
COMMENT ON COLUMN inventory_items.created_at IS 'Criacao do registro.';
COMMENT ON COLUMN inventory_items.updated_at IS 'Ultima atualizacao do registro.';

COMMENT ON COLUMN inventory_lots.inventory_lot_id IS 'PK UUID do lote.';
COMMENT ON COLUMN inventory_lots.owner_user_id IS 'FK para users.user_id do dono do estoque.';
COMMENT ON COLUMN inventory_lots.item_id IS 'FK para inventory_items.';
COMMENT ON COLUMN inventory_lots.warehouse_id IS 'FK para warehouses.';
COMMENT ON COLUMN inventory_lots.supplier_id IS 'FK opcional para suppliers.';
COMMENT ON COLUMN inventory_lots.lot_code IS 'Codigo do lote.';
COMMENT ON COLUMN inventory_lots.lot_status IS 'Status do lote.';
COMMENT ON COLUMN inventory_lots.quantity_available IS 'Quantidade disponivel.';
COMMENT ON COLUMN inventory_lots.quantity_reserved IS 'Quantidade reservada.';
COMMENT ON COLUMN inventory_lots.quantity_damaged IS 'Quantidade avariada.';
COMMENT ON COLUMN inventory_lots.unit_cost_brl IS 'Custo unitario do lote em BRL.';
COMMENT ON COLUMN inventory_lots.expires_at IS 'Validade opcional do lote.';
COMMENT ON COLUMN inventory_lots.received_at IS 'Data de recebimento.';
COMMENT ON COLUMN inventory_lots.metadata_json IS 'Metadados do lote.';
COMMENT ON COLUMN inventory_lots.created_at IS 'Criacao do registro.';
COMMENT ON COLUMN inventory_lots.updated_at IS 'Ultima atualizacao do registro.';

COMMENT ON COLUMN inventory_movements.inventory_movement_id IS 'PK UUID do movimento.';
COMMENT ON COLUMN inventory_movements.owner_user_id IS 'FK para users.user_id do dono do estoque.';
COMMENT ON COLUMN inventory_movements.item_id IS 'FK para inventory_items.';
COMMENT ON COLUMN inventory_movements.warehouse_id IS 'FK para warehouses.';
COMMENT ON COLUMN inventory_movements.source_lot_id IS 'FK opcional para inventory_lots.';
COMMENT ON COLUMN inventory_movements.actor_user_id IS 'FK para users.user_id de quem causou o movimento.';
COMMENT ON COLUMN inventory_movements.order_id IS 'FK opcional para orders.';
COMMENT ON COLUMN inventory_movements.transaction_id IS 'FK opcional para transactions.';
COMMENT ON COLUMN inventory_movements.movement_type IS 'Tipo do movimento de estoque.';
COMMENT ON COLUMN inventory_movements.quantity_delta IS 'Delta de quantidade, positivo ou negativo.';
COMMENT ON COLUMN inventory_movements.unit_cost_brl IS 'Custo unitario associado ao movimento.';
COMMENT ON COLUMN inventory_movements.movement_reason IS 'Motivo humano ou sistemico do movimento.';
COMMENT ON COLUMN inventory_movements.reference_code IS 'Referencia externa ou operacional.';
COMMENT ON COLUMN inventory_movements.metadata_json IS 'Metadados do evento.';
COMMENT ON COLUMN inventory_movements.created_at IS 'Criacao append-only do movimento.';

COMMENT ON COLUMN marketplace_listings.listing_id IS 'PK UUID do listing.';
COMMENT ON COLUMN marketplace_listings.merchant_user_id IS 'FK para users.user_id do merchant.';
COMMENT ON COLUMN marketplace_listings.wallet_id IS 'FK para wallet de recebimento do merchant.';
COMMENT ON COLUMN marketplace_listings.item_id IS 'FK para inventory_items.';
COMMENT ON COLUMN marketplace_listings.module_code IS 'FK para module_delivery_registry, normalmente MARKETPLACE.';
COMMENT ON COLUMN marketplace_listings.listing_status IS 'Status do anuncio.';
COMMENT ON COLUMN marketplace_listings.listing_title IS 'Titulo publico do anuncio.';
COMMENT ON COLUMN marketplace_listings.listing_description IS 'Descricao publica do anuncio.';
COMMENT ON COLUMN marketplace_listings.price_brl IS 'Preco publicado em BRL.';
COMMENT ON COLUMN marketplace_listings.commission_rate IS 'Comissao percentual da plataforma.';
COMMENT ON COLUMN marketplace_listings.stock_strategy IS 'Estrategia de estoque: real-time, reserva, preorder ou dropship.';
COMMENT ON COLUMN marketplace_listings.available_quantity_snapshot IS 'Snapshot de quantidade disponivel para vitrine.';
COMMENT ON COLUMN marketplace_listings.published_at IS 'Data de publicacao do anuncio.';
COMMENT ON COLUMN marketplace_listings.created_at IS 'Criacao do registro.';
COMMENT ON COLUMN marketplace_listings.updated_at IS 'Ultima atualizacao do registro.';

COMMENT ON COLUMN procurement_orders.procurement_order_id IS 'PK UUID da compra.';
COMMENT ON COLUMN procurement_orders.buyer_user_id IS 'FK para users.user_id do comprador.';
COMMENT ON COLUMN procurement_orders.supplier_id IS 'FK para suppliers.';
COMMENT ON COLUMN procurement_orders.supplier_user_id IS 'FK direta para users.user_id do fornecedor.';
COMMENT ON COLUMN procurement_orders.destination_warehouse_id IS 'FK para armazem destino.';
COMMENT ON COLUMN procurement_orders.wallet_id IS 'FK opcional para wallet de pagamento.';
COMMENT ON COLUMN procurement_orders.module_code IS 'FK para module_delivery_registry, normalmente REPLY.';
COMMENT ON COLUMN procurement_orders.procurement_status IS 'Status da compra.';
COMMENT ON COLUMN procurement_orders.expected_total_brl IS 'Total esperado em BRL.';
COMMENT ON COLUMN procurement_orders.currency_code IS 'Moeda da compra, fixa em BRL neste escopo.';
COMMENT ON COLUMN procurement_orders.external_reference IS 'Referencia externa de ERP ou fornecedor.';
COMMENT ON COLUMN procurement_orders.approved_by_user_id IS 'FK opcional para aprovador.';
COMMENT ON COLUMN procurement_orders.placed_at IS 'Data de envio ao fornecedor.';
COMMENT ON COLUMN procurement_orders.expected_delivery_at IS 'Data prevista de entrega.';
COMMENT ON COLUMN procurement_orders.received_at IS 'Data de recebimento.';
COMMENT ON COLUMN procurement_orders.metadata_json IS 'Metadados da compra.';
COMMENT ON COLUMN procurement_orders.created_at IS 'Criacao do registro.';
COMMENT ON COLUMN procurement_orders.updated_at IS 'Ultima atualizacao do registro.';

COMMENT ON COLUMN procurement_order_items.procurement_order_item_id IS 'PK UUID da linha de compra.';
COMMENT ON COLUMN procurement_order_items.procurement_order_id IS 'FK para procurement_orders.';
COMMENT ON COLUMN procurement_order_items.buyer_user_id IS 'FK para users.user_id do comprador.';
COMMENT ON COLUMN procurement_order_items.item_id IS 'FK para inventory_items.';
COMMENT ON COLUMN procurement_order_items.quantity_ordered IS 'Quantidade pedida.';
COMMENT ON COLUMN procurement_order_items.quantity_received IS 'Quantidade recebida.';
COMMENT ON COLUMN procurement_order_items.unit_price_brl IS 'Preco unitario em BRL.';
COMMENT ON COLUMN procurement_order_items.line_total_brl IS 'Total calculado da linha em BRL.';
COMMENT ON COLUMN procurement_order_items.created_at IS 'Criacao do registro.';
COMMENT ON COLUMN procurement_order_items.updated_at IS 'Ultima atualizacao do registro.';

COMMENT ON COLUMN service_work_orders.work_order_id IS 'PK UUID da ordem de servico.';
COMMENT ON COLUMN service_work_orders.requester_user_id IS 'FK para users.user_id do solicitante.';
COMMENT ON COLUMN service_work_orders.provider_user_id IS 'FK opcional para prestador.';
COMMENT ON COLUMN service_work_orders.wallet_id IS 'FK opcional para wallet de pagamento.';
COMMENT ON COLUMN service_work_orders.order_id IS 'FK opcional para orders.';
COMMENT ON COLUMN service_work_orders.module_code IS 'FK para module_delivery_registry, normalmente REPLY.';
COMMENT ON COLUMN service_work_orders.work_order_status IS 'Status da ordem de servico.';
COMMENT ON COLUMN service_work_orders.title IS 'Titulo curto da ordem.';
COMMENT ON COLUMN service_work_orders.description IS 'Descricao da ordem.';
COMMENT ON COLUMN service_work_orders.service_address_json IS 'Endereco ou local de execucao.';
COMMENT ON COLUMN service_work_orders.estimate_amount_brl IS 'Valor estimado em BRL.';
COMMENT ON COLUMN service_work_orders.final_amount_brl IS 'Valor final em BRL.';
COMMENT ON COLUMN service_work_orders.scheduled_for IS 'Data agendada.';
COMMENT ON COLUMN service_work_orders.started_at IS 'Inicio da execucao.';
COMMENT ON COLUMN service_work_orders.completed_at IS 'Conclusao da execucao.';
COMMENT ON COLUMN service_work_orders.cancelled_at IS 'Cancelamento da ordem.';
COMMENT ON COLUMN service_work_orders.cancellation_reason IS 'Motivo de cancelamento.';
COMMENT ON COLUMN service_work_orders.metadata_json IS 'Metadados da ordem.';
COMMENT ON COLUMN service_work_orders.created_at IS 'Criacao do registro.';
COMMENT ON COLUMN service_work_orders.updated_at IS 'Ultima atualizacao do registro.';

COMMENT ON COLUMN warehouse_cycle_counts.cycle_count_id IS 'PK UUID da contagem.';
COMMENT ON COLUMN warehouse_cycle_counts.owner_user_id IS 'FK para users.user_id do dono do estoque.';
COMMENT ON COLUMN warehouse_cycle_counts.warehouse_id IS 'FK para warehouses.';
COMMENT ON COLUMN warehouse_cycle_counts.item_id IS 'FK para inventory_items.';
COMMENT ON COLUMN warehouse_cycle_counts.counted_by_user_id IS 'FK para users.user_id de quem contou.';
COMMENT ON COLUMN warehouse_cycle_counts.expected_quantity IS 'Quantidade esperada pelo sistema.';
COMMENT ON COLUMN warehouse_cycle_counts.counted_quantity IS 'Quantidade fisicamente contada.';
COMMENT ON COLUMN warehouse_cycle_counts.variance_quantity IS 'Diferenca calculada entre contado e esperado.';
COMMENT ON COLUMN warehouse_cycle_counts.count_reason IS 'Motivo da contagem.';
COMMENT ON COLUMN warehouse_cycle_counts.counted_at IS 'Horario da contagem.';
COMMENT ON COLUMN warehouse_cycle_counts.created_at IS 'Criacao append-only do registro.';

COMMIT;
