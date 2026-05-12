-- Materializa o ERP do lojista para marketplace, PDV, armazem, metricas,
-- campanhas, relatorios, financeiro, contabil/fiscal, integracoes e seguranca.
-- A migration e aditiva e usa users.user_id como ancora relacional do lojista.

BEGIN;

SET search_path = public;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'merchant_erp_workspace_code_enum') THEN
        CREATE TYPE merchant_erp_workspace_code_enum AS ENUM (
            'LOGIN',
            'ERP',
            'PDV',
            'WAREHOUSE',
            'METRICS',
            'CAMPAIGNS',
            'REPORTS',
            'FINANCE',
            'REGISTRATION',
            'PROFILE',
            'ACCOUNTING',
            'INTEGRATIONS',
            'ORDERS',
            'PRODUCTS',
            'CUSTOMERS',
            'TAX',
            'INVENTORY',
            'LOGISTICS',
            'SUPPORT',
            'TEAM',
            'SECURITY',
            'SETTINGS'
        );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'merchant_erp_status_enum') THEN
        CREATE TYPE merchant_erp_status_enum AS ENUM (
            'DRAFT',
            'ACTIVE',
            'PAUSED',
            'LOCKED',
            'ARCHIVED'
        );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'merchant_erp_role_enum') THEN
        CREATE TYPE merchant_erp_role_enum AS ENUM (
            'OWNER',
            'ADMIN',
            'MANAGER',
            'OPERATOR',
            'CASHIER',
            'WAREHOUSE',
            'ACCOUNTANT',
            'SUPPORT',
            'VIEWER'
        );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'merchant_erp_task_status_enum') THEN
        CREATE TYPE merchant_erp_task_status_enum AS ENUM (
            'OPEN',
            'IN_PROGRESS',
            'WAITING_EXTERNAL',
            'DONE',
            'CANCELLED'
        );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'merchant_erp_priority_enum') THEN
        CREATE TYPE merchant_erp_priority_enum AS ENUM (
            'LOW',
            'NORMAL',
            'HIGH',
            'URGENT'
        );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'merchant_erp_terminal_status_enum') THEN
        CREATE TYPE merchant_erp_terminal_status_enum AS ENUM (
            'DRAFT',
            'ACTIVE',
            'MAINTENANCE',
            'BLOCKED',
            'ARCHIVED'
        );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'merchant_erp_pdv_session_status_enum') THEN
        CREATE TYPE merchant_erp_pdv_session_status_enum AS ENUM (
            'OPEN',
            'CLOSING',
            'CLOSED',
            'CANCELLED',
            'DISPUTED'
        );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'merchant_erp_cash_movement_type_enum') THEN
        CREATE TYPE merchant_erp_cash_movement_type_enum AS ENUM (
            'OPENING_BALANCE',
            'SALE_CASH',
            'SALE_CARD',
            'SALE_PIX',
            'WITHDRAWAL',
            'CHANGE_IN',
            'CHANGE_OUT',
            'REFUND',
            'CLOSING_ADJUSTMENT'
        );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'merchant_erp_campaign_status_enum') THEN
        CREATE TYPE merchant_erp_campaign_status_enum AS ENUM (
            'DRAFT',
            'SCHEDULED',
            'ACTIVE',
            'PAUSED',
            'FINISHED',
            'ARCHIVED'
        );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'merchant_erp_report_status_enum') THEN
        CREATE TYPE merchant_erp_report_status_enum AS ENUM (
            'QUEUED',
            'RUNNING',
            'READY',
            'FAILED',
            'EXPIRED'
        );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'merchant_erp_integration_status_enum') THEN
        CREATE TYPE merchant_erp_integration_status_enum AS ENUM (
            'DRAFT',
            'ACTIVE',
            'DEGRADED',
            'DISABLED',
            'REVOKED'
        );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'merchant_erp_closure_status_enum') THEN
        CREATE TYPE merchant_erp_closure_status_enum AS ENUM (
            'OPEN',
            'UNDER_REVIEW',
            'APPROVED',
            'SETTLED',
            'REOPENED',
            'CANCELLED'
        );
    END IF;
END
$$;

CREATE TABLE IF NOT EXISTS merchant_erp_workspaces (
    merchant_erp_workspace_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_user_id UUID NOT NULL,
    merchant_profile_id UUID,
    workspace_code merchant_erp_workspace_code_enum NOT NULL,
    workspace_status merchant_erp_status_enum NOT NULL DEFAULT 'ACTIVE',
    public_host TEXT NOT NULL,
    title TEXT NOT NULL,
    navigation_order INTEGER NOT NULL DEFAULT 0,
    icon_key TEXT NOT NULL DEFAULT 'grid',
    accent_color TEXT NOT NULL DEFAULT '#2563eb',
    feature_config_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    last_opened_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_merchant_erp_workspaces_user
        FOREIGN KEY (merchant_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_merchant_erp_workspaces_profile
        FOREIGN KEY (merchant_profile_id) REFERENCES merchant_profiles (merchant_profile_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT ux_merchant_erp_workspaces_user_code UNIQUE (merchant_user_id, workspace_code),
    CONSTRAINT chk_merchant_erp_workspaces_host CHECK (public_host ~ '^[a-z0-9-]+\.brasildesconto\.com\.br$'),
    CONSTRAINT chk_merchant_erp_workspaces_title CHECK (btrim(title) <> ''),
    CONSTRAINT chk_merchant_erp_workspaces_order CHECK (navigation_order >= 0),
    CONSTRAINT chk_merchant_erp_workspaces_config CHECK (jsonb_typeof(feature_config_json) = 'object')
);

CREATE TABLE IF NOT EXISTS merchant_erp_staff_members (
    merchant_erp_staff_member_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_user_id UUID NOT NULL,
    staff_user_id UUID NOT NULL,
    role_code merchant_erp_role_enum NOT NULL DEFAULT 'OPERATOR',
    member_status merchant_erp_status_enum NOT NULL DEFAULT 'ACTIVE',
    display_name TEXT NOT NULL,
    email TEXT,
    phone_e164 TEXT,
    permissions_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    last_seen_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_merchant_erp_staff_merchant
        FOREIGN KEY (merchant_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_merchant_erp_staff_user
        FOREIGN KEY (staff_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT ux_merchant_erp_staff_user UNIQUE (merchant_user_id, staff_user_id),
    CONSTRAINT chk_merchant_erp_staff_display CHECK (btrim(display_name) <> ''),
    CONSTRAINT chk_merchant_erp_staff_email CHECK (
        email IS NULL OR email ~* '^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$'
    ),
    CONSTRAINT chk_merchant_erp_staff_phone CHECK (
        phone_e164 IS NULL OR phone_e164 ~ '^\+[1-9][0-9]{7,14}$'
    ),
    CONSTRAINT chk_merchant_erp_staff_permissions CHECK (jsonb_typeof(permissions_json) = 'object')
);

CREATE TABLE IF NOT EXISTS merchant_erp_pdv_terminals (
    merchant_erp_pdv_terminal_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_user_id UUID NOT NULL,
    business_unit_id UUID,
    terminal_code TEXT NOT NULL,
    terminal_name TEXT NOT NULL,
    terminal_status merchant_erp_terminal_status_enum NOT NULL DEFAULT 'ACTIVE',
    device_fingerprint_hash TEXT,
    default_wallet_id UUID,
    settings_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_merchant_erp_pdv_terminals_merchant
        FOREIGN KEY (merchant_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_merchant_erp_pdv_terminals_unit
        FOREIGN KEY (business_unit_id) REFERENCES business_units (business_unit_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_merchant_erp_pdv_terminals_wallet
        FOREIGN KEY (default_wallet_id) REFERENCES wallets (wallet_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT ux_merchant_erp_pdv_terminal_code UNIQUE (merchant_user_id, terminal_code),
    CONSTRAINT chk_merchant_erp_pdv_terminal_code CHECK (terminal_code ~ '^[A-Z0-9_-]{2,64}$'),
    CONSTRAINT chk_merchant_erp_pdv_terminal_name CHECK (btrim(terminal_name) <> ''),
    CONSTRAINT chk_merchant_erp_pdv_terminal_settings CHECK (jsonb_typeof(settings_json) = 'object')
);

CREATE TABLE IF NOT EXISTS merchant_erp_pdv_sessions (
    merchant_erp_pdv_session_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_user_id UUID NOT NULL,
    terminal_id UUID NOT NULL,
    opened_by_user_id UUID NOT NULL,
    closed_by_user_id UUID,
    session_status merchant_erp_pdv_session_status_enum NOT NULL DEFAULT 'OPEN',
    opening_balance_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    expected_closing_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    actual_closing_brl DECIMAL(18,4),
    orders_count INTEGER NOT NULL DEFAULT 0,
    opened_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    closed_at TIMESTAMPTZ,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_merchant_erp_pdv_sessions_merchant
        FOREIGN KEY (merchant_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_merchant_erp_pdv_sessions_terminal
        FOREIGN KEY (terminal_id) REFERENCES merchant_erp_pdv_terminals (merchant_erp_pdv_terminal_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_merchant_erp_pdv_sessions_opened_by
        FOREIGN KEY (opened_by_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_merchant_erp_pdv_sessions_closed_by
        FOREIGN KEY (closed_by_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT chk_merchant_erp_pdv_sessions_amounts CHECK (
        opening_balance_brl >= 0
        AND expected_closing_brl >= 0
        AND (actual_closing_brl IS NULL OR actual_closing_brl >= 0)
    ),
    CONSTRAINT chk_merchant_erp_pdv_sessions_orders CHECK (orders_count >= 0),
    CONSTRAINT chk_merchant_erp_pdv_sessions_timeline CHECK (
        closed_at IS NULL OR closed_at >= opened_at
    ),
    CONSTRAINT chk_merchant_erp_pdv_sessions_metadata CHECK (jsonb_typeof(metadata_json) = 'object')
);

CREATE TABLE IF NOT EXISTS merchant_erp_cash_movements (
    merchant_erp_cash_movement_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_user_id UUID NOT NULL,
    pdv_session_id UUID NOT NULL,
    actor_user_id UUID NOT NULL,
    order_id UUID,
    transaction_id UUID,
    movement_type merchant_erp_cash_movement_type_enum NOT NULL,
    amount_brl DECIMAL(18,4) NOT NULL,
    description TEXT NOT NULL,
    receipt_hash TEXT,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_merchant_erp_cash_movements_merchant
        FOREIGN KEY (merchant_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_merchant_erp_cash_movements_session
        FOREIGN KEY (pdv_session_id) REFERENCES merchant_erp_pdv_sessions (merchant_erp_pdv_session_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_merchant_erp_cash_movements_actor
        FOREIGN KEY (actor_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_merchant_erp_cash_movements_order
        FOREIGN KEY (order_id) REFERENCES orders (order_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_merchant_erp_cash_movements_transaction
        FOREIGN KEY (transaction_id) REFERENCES transactions (transaction_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT chk_merchant_erp_cash_movements_amount CHECK (amount_brl <> 0),
    CONSTRAINT chk_merchant_erp_cash_movements_description CHECK (btrim(description) <> ''),
    CONSTRAINT chk_merchant_erp_cash_movements_metadata CHECK (jsonb_typeof(metadata_json) = 'object')
);

CREATE TABLE IF NOT EXISTS merchant_erp_order_pipeline (
    merchant_erp_order_pipeline_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_user_id UUID NOT NULL,
    order_id UUID,
    pipeline_status merchant_erp_task_status_enum NOT NULL DEFAULT 'OPEN',
    priority merchant_erp_priority_enum NOT NULL DEFAULT 'NORMAL',
    source_channel TEXT NOT NULL DEFAULT 'MARKETPLACE',
    fulfillment_stage TEXT NOT NULL DEFAULT 'CREATED',
    assigned_to_user_id UUID,
    due_at TIMESTAMPTZ,
    sla_minutes INTEGER NOT NULL DEFAULT 1440,
    notes TEXT,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_merchant_erp_order_pipeline_merchant
        FOREIGN KEY (merchant_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_merchant_erp_order_pipeline_order
        FOREIGN KEY (order_id) REFERENCES orders (order_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_merchant_erp_order_pipeline_assignee
        FOREIGN KEY (assigned_to_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT chk_merchant_erp_order_pipeline_channel CHECK (btrim(source_channel) <> ''),
    CONSTRAINT chk_merchant_erp_order_pipeline_stage CHECK (btrim(fulfillment_stage) <> ''),
    CONSTRAINT chk_merchant_erp_order_pipeline_sla CHECK (sla_minutes >= 0),
    CONSTRAINT chk_merchant_erp_order_pipeline_metadata CHECK (jsonb_typeof(metadata_json) = 'object')
);

CREATE TABLE IF NOT EXISTS merchant_erp_catalog_tasks (
    merchant_erp_catalog_task_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_user_id UUID NOT NULL,
    item_id UUID,
    listing_id UUID,
    task_status merchant_erp_task_status_enum NOT NULL DEFAULT 'OPEN',
    priority merchant_erp_priority_enum NOT NULL DEFAULT 'NORMAL',
    task_type TEXT NOT NULL,
    title TEXT NOT NULL,
    assigned_to_user_id UUID,
    due_at TIMESTAMPTZ,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_merchant_erp_catalog_tasks_merchant
        FOREIGN KEY (merchant_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_merchant_erp_catalog_tasks_item
        FOREIGN KEY (item_id) REFERENCES inventory_items (item_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_merchant_erp_catalog_tasks_listing
        FOREIGN KEY (listing_id) REFERENCES marketplace_listings (listing_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_merchant_erp_catalog_tasks_assignee
        FOREIGN KEY (assigned_to_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT chk_merchant_erp_catalog_tasks_type CHECK (btrim(task_type) <> ''),
    CONSTRAINT chk_merchant_erp_catalog_tasks_title CHECK (btrim(title) <> ''),
    CONSTRAINT chk_merchant_erp_catalog_tasks_metadata CHECK (jsonb_typeof(metadata_json) = 'object')
);

CREATE TABLE IF NOT EXISTS merchant_erp_inventory_tasks (
    merchant_erp_inventory_task_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_user_id UUID NOT NULL,
    warehouse_id UUID,
    item_id UUID,
    task_status merchant_erp_task_status_enum NOT NULL DEFAULT 'OPEN',
    priority merchant_erp_priority_enum NOT NULL DEFAULT 'NORMAL',
    task_type TEXT NOT NULL,
    quantity_expected DECIMAL(18,4) NOT NULL DEFAULT 0,
    quantity_done DECIMAL(18,4) NOT NULL DEFAULT 0,
    assigned_to_user_id UUID,
    due_at TIMESTAMPTZ,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_merchant_erp_inventory_tasks_merchant
        FOREIGN KEY (merchant_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_merchant_erp_inventory_tasks_warehouse
        FOREIGN KEY (warehouse_id) REFERENCES warehouses (warehouse_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_merchant_erp_inventory_tasks_item
        FOREIGN KEY (item_id) REFERENCES inventory_items (item_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_merchant_erp_inventory_tasks_assignee
        FOREIGN KEY (assigned_to_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT chk_merchant_erp_inventory_tasks_type CHECK (btrim(task_type) <> ''),
    CONSTRAINT chk_merchant_erp_inventory_tasks_qty CHECK (
        quantity_expected >= 0 AND quantity_done >= 0
    ),
    CONSTRAINT chk_merchant_erp_inventory_tasks_metadata CHECK (jsonb_typeof(metadata_json) = 'object')
);

CREATE TABLE IF NOT EXISTS merchant_erp_metric_snapshots (
    merchant_erp_metric_snapshot_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_user_id UUID NOT NULL,
    snapshot_date DATE NOT NULL,
    workspace_code merchant_erp_workspace_code_enum NOT NULL DEFAULT 'ERP',
    gross_revenue_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    net_revenue_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    orders_count INTEGER NOT NULL DEFAULT 0,
    conversion_rate DECIMAL(8,4) NOT NULL DEFAULT 0,
    average_ticket_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    stock_coverage_days DECIMAL(18,4) NOT NULL DEFAULT 0,
    sla_score DECIMAL(8,4) NOT NULL DEFAULT 0,
    metrics_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_merchant_erp_metric_snapshots_merchant
        FOREIGN KEY (merchant_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT ux_merchant_erp_metric_snapshots_daily UNIQUE (merchant_user_id, snapshot_date, workspace_code),
    CONSTRAINT chk_merchant_erp_metric_snapshots_numbers CHECK (
        gross_revenue_brl >= 0
        AND net_revenue_brl >= 0
        AND orders_count >= 0
        AND conversion_rate >= 0
        AND average_ticket_brl >= 0
        AND stock_coverage_days >= 0
        AND sla_score >= 0
    ),
    CONSTRAINT chk_merchant_erp_metric_snapshots_json CHECK (jsonb_typeof(metrics_json) = 'object')
);

CREATE TABLE IF NOT EXISTS merchant_erp_campaigns (
    merchant_erp_campaign_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_user_id UUID NOT NULL,
    campaign_status merchant_erp_campaign_status_enum NOT NULL DEFAULT 'DRAFT',
    campaign_name TEXT NOT NULL,
    channel_code TEXT NOT NULL DEFAULT 'MARKETPLACE',
    budget_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    expected_revenue_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    starts_at TIMESTAMPTZ,
    ends_at TIMESTAMPTZ,
    targeting_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    performance_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_by_user_id UUID NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_merchant_erp_campaigns_merchant
        FOREIGN KEY (merchant_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_merchant_erp_campaigns_created_by
        FOREIGN KEY (created_by_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT chk_merchant_erp_campaigns_name CHECK (btrim(campaign_name) <> ''),
    CONSTRAINT chk_merchant_erp_campaigns_channel CHECK (btrim(channel_code) <> ''),
    CONSTRAINT chk_merchant_erp_campaigns_values CHECK (budget_brl >= 0 AND expected_revenue_brl >= 0),
    CONSTRAINT chk_merchant_erp_campaigns_timeline CHECK (
        ends_at IS NULL OR starts_at IS NULL OR ends_at >= starts_at
    ),
    CONSTRAINT chk_merchant_erp_campaigns_json CHECK (
        jsonb_typeof(targeting_json) = 'object'
        AND jsonb_typeof(performance_json) = 'object'
    )
);

CREATE TABLE IF NOT EXISTS merchant_erp_report_exports (
    merchant_erp_report_export_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_user_id UUID NOT NULL,
    requested_by_user_id UUID NOT NULL,
    report_status merchant_erp_report_status_enum NOT NULL DEFAULT 'QUEUED',
    report_code TEXT NOT NULL,
    report_title TEXT NOT NULL,
    period_start DATE,
    period_end DATE,
    file_uri TEXT,
    file_sha256 TEXT,
    parameters_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_merchant_erp_report_exports_merchant
        FOREIGN KEY (merchant_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_merchant_erp_report_exports_requested_by
        FOREIGN KEY (requested_by_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT chk_merchant_erp_report_exports_code CHECK (report_code ~ '^[A-Z0-9_-]{2,80}$'),
    CONSTRAINT chk_merchant_erp_report_exports_title CHECK (btrim(report_title) <> ''),
    CONSTRAINT chk_merchant_erp_report_exports_period CHECK (
        period_end IS NULL OR period_start IS NULL OR period_end >= period_start
    ),
    CONSTRAINT chk_merchant_erp_report_exports_parameters CHECK (jsonb_typeof(parameters_json) = 'object')
);

CREATE TABLE IF NOT EXISTS merchant_erp_financial_closures (
    merchant_erp_financial_closure_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_user_id UUID NOT NULL,
    wallet_id UUID,
    closure_status merchant_erp_closure_status_enum NOT NULL DEFAULT 'OPEN',
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    gross_revenue_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    platform_fees_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    payment_fees_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    refunds_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    taxes_estimate_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    net_payable_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    approved_by_user_id UUID,
    approved_at TIMESTAMPTZ,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_merchant_erp_financial_closures_merchant
        FOREIGN KEY (merchant_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_merchant_erp_financial_closures_wallet
        FOREIGN KEY (wallet_id) REFERENCES wallets (wallet_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_merchant_erp_financial_closures_approved_by
        FOREIGN KEY (approved_by_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT ux_merchant_erp_financial_closures_period UNIQUE (merchant_user_id, period_start, period_end),
    CONSTRAINT chk_merchant_erp_financial_closures_period CHECK (period_end >= period_start),
    CONSTRAINT chk_merchant_erp_financial_closures_amounts CHECK (
        gross_revenue_brl >= 0
        AND platform_fees_brl >= 0
        AND payment_fees_brl >= 0
        AND refunds_brl >= 0
        AND taxes_estimate_brl >= 0
        AND net_payable_brl >= 0
    ),
    CONSTRAINT chk_merchant_erp_financial_closures_approval CHECK (
        (approved_by_user_id IS NULL AND approved_at IS NULL)
        OR (approved_by_user_id IS NOT NULL AND approved_at IS NOT NULL)
    ),
    CONSTRAINT chk_merchant_erp_financial_closures_metadata CHECK (jsonb_typeof(metadata_json) = 'object')
);

CREATE TABLE IF NOT EXISTS merchant_erp_accounting_entries (
    merchant_erp_accounting_entry_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_user_id UUID NOT NULL,
    closure_id UUID,
    transaction_id UUID,
    entry_code TEXT NOT NULL,
    entry_type TEXT NOT NULL,
    amount_brl DECIMAL(18,4) NOT NULL,
    fiscal_document_key TEXT,
    fiscal_document_hash TEXT,
    competence_date DATE NOT NULL,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_merchant_erp_accounting_entries_merchant
        FOREIGN KEY (merchant_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_merchant_erp_accounting_entries_closure
        FOREIGN KEY (closure_id) REFERENCES merchant_erp_financial_closures (merchant_erp_financial_closure_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_merchant_erp_accounting_entries_transaction
        FOREIGN KEY (transaction_id) REFERENCES transactions (transaction_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT chk_merchant_erp_accounting_entries_code CHECK (entry_code ~ '^[A-Z0-9_.-]{2,96}$'),
    CONSTRAINT chk_merchant_erp_accounting_entries_type CHECK (btrim(entry_type) <> ''),
    CONSTRAINT chk_merchant_erp_accounting_entries_amount CHECK (amount_brl <> 0),
    CONSTRAINT chk_merchant_erp_accounting_entries_metadata CHECK (jsonb_typeof(metadata_json) = 'object')
);

CREATE TABLE IF NOT EXISTS merchant_erp_integration_connections (
    merchant_erp_integration_connection_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_user_id UUID NOT NULL,
    workspace_code merchant_erp_workspace_code_enum NOT NULL DEFAULT 'INTEGRATIONS',
    integration_status merchant_erp_integration_status_enum NOT NULL DEFAULT 'DRAFT',
    provider_key TEXT NOT NULL,
    provider_label TEXT NOT NULL,
    connector_kind TEXT NOT NULL DEFAULT 'API',
    credential_ref TEXT,
    webhook_url TEXT,
    last_sync_at TIMESTAMPTZ,
    last_sync_status TEXT,
    scopes_json JSONB NOT NULL DEFAULT '[]'::JSONB,
    settings_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_merchant_erp_integration_connections_merchant
        FOREIGN KEY (merchant_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT ux_merchant_erp_integration_connections_provider UNIQUE (merchant_user_id, provider_key),
    CONSTRAINT chk_merchant_erp_integration_connections_provider CHECK (provider_key ~ '^[a-z0-9_-]{2,80}$'),
    CONSTRAINT chk_merchant_erp_integration_connections_label CHECK (btrim(provider_label) <> ''),
    CONSTRAINT chk_merchant_erp_integration_connections_kind CHECK (btrim(connector_kind) <> ''),
    CONSTRAINT chk_merchant_erp_integration_connections_webhook CHECK (
        webhook_url IS NULL OR webhook_url ~ '^https?://'
    ),
    CONSTRAINT chk_merchant_erp_integration_connections_json CHECK (
        jsonb_typeof(scopes_json) = 'array'
        AND jsonb_typeof(settings_json) = 'object'
    )
);

CREATE TABLE IF NOT EXISTS merchant_erp_security_events (
    merchant_erp_security_event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_user_id UUID NOT NULL,
    actor_user_id UUID,
    event_type TEXT NOT NULL,
    severity merchant_erp_priority_enum NOT NULL DEFAULT 'NORMAL',
    ip_address TEXT,
    user_agent TEXT,
    session_id UUID,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_merchant_erp_security_events_merchant
        FOREIGN KEY (merchant_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_merchant_erp_security_events_actor
        FOREIGN KEY (actor_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT chk_merchant_erp_security_events_type CHECK (btrim(event_type) <> ''),
    CONSTRAINT chk_merchant_erp_security_events_metadata CHECK (jsonb_typeof(metadata_json) = 'object')
);

CREATE TABLE IF NOT EXISTS merchant_erp_audit_events (
    merchant_erp_audit_event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_user_id UUID NOT NULL,
    actor_user_id UUID,
    workspace_code merchant_erp_workspace_code_enum NOT NULL DEFAULT 'ERP',
    audit_action TEXT NOT NULL,
    entity_name TEXT NOT NULL,
    entity_id TEXT,
    before_json JSONB,
    after_json JSONB,
    reason TEXT,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_merchant_erp_audit_events_merchant
        FOREIGN KEY (merchant_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_merchant_erp_audit_events_actor
        FOREIGN KEY (actor_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT chk_merchant_erp_audit_events_action CHECK (btrim(audit_action) <> ''),
    CONSTRAINT chk_merchant_erp_audit_events_entity CHECK (btrim(entity_name) <> ''),
    CONSTRAINT chk_merchant_erp_audit_events_json CHECK (
        (before_json IS NULL OR jsonb_typeof(before_json) = 'object')
        AND (after_json IS NULL OR jsonb_typeof(after_json) = 'object')
        AND jsonb_typeof(metadata_json) = 'object'
    )
);

CREATE INDEX IF NOT EXISTS ix_merchant_erp_workspaces_status
    ON merchant_erp_workspaces (merchant_user_id, workspace_status, navigation_order);

CREATE INDEX IF NOT EXISTS ix_merchant_erp_staff_role
    ON merchant_erp_staff_members (merchant_user_id, role_code, member_status);

CREATE INDEX IF NOT EXISTS ix_merchant_erp_pdv_sessions_status
    ON merchant_erp_pdv_sessions (merchant_user_id, session_status, opened_at DESC);

CREATE INDEX IF NOT EXISTS ix_merchant_erp_cash_movements_session
    ON merchant_erp_cash_movements (pdv_session_id, occurred_at DESC);

CREATE INDEX IF NOT EXISTS ix_merchant_erp_order_pipeline_status
    ON merchant_erp_order_pipeline (merchant_user_id, pipeline_status, priority, due_at);

CREATE INDEX IF NOT EXISTS ix_merchant_erp_catalog_tasks_status
    ON merchant_erp_catalog_tasks (merchant_user_id, task_status, priority, due_at);

CREATE INDEX IF NOT EXISTS ix_merchant_erp_inventory_tasks_status
    ON merchant_erp_inventory_tasks (merchant_user_id, task_status, priority, due_at);

CREATE INDEX IF NOT EXISTS ix_merchant_erp_metric_snapshots_date
    ON merchant_erp_metric_snapshots (merchant_user_id, snapshot_date DESC, workspace_code);

CREATE INDEX IF NOT EXISTS ix_merchant_erp_campaigns_status
    ON merchant_erp_campaigns (merchant_user_id, campaign_status, starts_at DESC);

CREATE INDEX IF NOT EXISTS ix_merchant_erp_report_exports_status
    ON merchant_erp_report_exports (merchant_user_id, report_status, created_at DESC);

CREATE INDEX IF NOT EXISTS ix_merchant_erp_financial_closures_period
    ON merchant_erp_financial_closures (merchant_user_id, period_start DESC, closure_status);

CREATE INDEX IF NOT EXISTS ix_merchant_erp_accounting_entries_competence
    ON merchant_erp_accounting_entries (merchant_user_id, competence_date DESC);

CREATE INDEX IF NOT EXISTS ix_merchant_erp_integrations_status
    ON merchant_erp_integration_connections (merchant_user_id, integration_status, provider_key);

CREATE INDEX IF NOT EXISTS ix_merchant_erp_security_events_time
    ON merchant_erp_security_events (merchant_user_id, occurred_at DESC, severity);

CREATE INDEX IF NOT EXISTS ix_merchant_erp_audit_events_time
    ON merchant_erp_audit_events (merchant_user_id, occurred_at DESC, workspace_code);

CREATE TRIGGER trg_merchant_erp_workspaces_set_updated_at
BEFORE UPDATE ON merchant_erp_workspaces
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_merchant_erp_staff_members_set_updated_at
BEFORE UPDATE ON merchant_erp_staff_members
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_merchant_erp_pdv_terminals_set_updated_at
BEFORE UPDATE ON merchant_erp_pdv_terminals
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_merchant_erp_pdv_sessions_set_updated_at
BEFORE UPDATE ON merchant_erp_pdv_sessions
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_merchant_erp_order_pipeline_set_updated_at
BEFORE UPDATE ON merchant_erp_order_pipeline
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_merchant_erp_catalog_tasks_set_updated_at
BEFORE UPDATE ON merchant_erp_catalog_tasks
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_merchant_erp_inventory_tasks_set_updated_at
BEFORE UPDATE ON merchant_erp_inventory_tasks
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_merchant_erp_campaigns_set_updated_at
BEFORE UPDATE ON merchant_erp_campaigns
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_merchant_erp_report_exports_set_updated_at
BEFORE UPDATE ON merchant_erp_report_exports
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_merchant_erp_financial_closures_set_updated_at
BEFORE UPDATE ON merchant_erp_financial_closures
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_merchant_erp_integrations_set_updated_at
BEFORE UPDATE ON merchant_erp_integration_connections
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_merchant_erp_cash_movements_prevent_update
BEFORE UPDATE ON merchant_erp_cash_movements
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

CREATE TRIGGER trg_merchant_erp_cash_movements_prevent_delete
BEFORE DELETE ON merchant_erp_cash_movements
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

CREATE TRIGGER trg_merchant_erp_metric_snapshots_prevent_update
BEFORE UPDATE ON merchant_erp_metric_snapshots
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

CREATE TRIGGER trg_merchant_erp_metric_snapshots_prevent_delete
BEFORE DELETE ON merchant_erp_metric_snapshots
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

CREATE TRIGGER trg_merchant_erp_accounting_entries_prevent_update
BEFORE UPDATE ON merchant_erp_accounting_entries
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

CREATE TRIGGER trg_merchant_erp_accounting_entries_prevent_delete
BEFORE DELETE ON merchant_erp_accounting_entries
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

CREATE TRIGGER trg_merchant_erp_security_events_prevent_update
BEFORE UPDATE ON merchant_erp_security_events
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

CREATE TRIGGER trg_merchant_erp_security_events_prevent_delete
BEFORE DELETE ON merchant_erp_security_events
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

CREATE TRIGGER trg_merchant_erp_audit_events_prevent_update
BEFORE UPDATE ON merchant_erp_audit_events
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

CREATE TRIGGER trg_merchant_erp_audit_events_prevent_delete
BEFORE DELETE ON merchant_erp_audit_events
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

INSERT INTO merchant_erp_workspaces (
    merchant_user_id,
    merchant_profile_id,
    workspace_code,
    workspace_status,
    public_host,
    title,
    navigation_order,
    icon_key,
    accent_color,
    feature_config_json
)
SELECT
    profile.merchant_user_id,
    profile.merchant_profile_id,
    workspace.workspace_code::merchant_erp_workspace_code_enum,
    'ACTIVE',
    workspace.public_host,
    workspace.title,
    workspace.navigation_order,
    workspace.icon_key,
    workspace.accent_color,
    jsonb_build_object(
        'source', 'v037_seed',
        'slug', profile.slug,
        'merchant_code', profile.merchant_code
    )
FROM merchant_profiles profile
CROSS JOIN (
    VALUES
        ('LOGIN', 'lojista.brasildesconto.com.br', 'Login Lojista', 1, 'id', '#2563eb'),
        ('ERP', 'erp-lojista.brasildesconto.com.br', 'ERP Lojista', 2, 'erp', '#16a34a'),
        ('PDV', 'pdv-lojista.brasildesconto.com.br', 'PDV', 3, 'pdv', '#0ea5e9'),
        ('WAREHOUSE', 'armazem-lojista.brasildesconto.com.br', 'Armazem', 4, 'warehouse', '#0891b2'),
        ('METRICS', 'metricas-lojista.brasildesconto.com.br', 'Metricas', 5, 'metrics', '#7c3aed'),
        ('CAMPAIGNS', 'campanhas-lojista.brasildesconto.com.br', 'Campanhas', 6, 'campaigns', '#db2777'),
        ('REPORTS', 'relatorios-lojista.brasildesconto.com.br', 'Relatorios', 7, 'reports', '#475569'),
        ('FINANCE', 'financeiro-lojista.brasildesconto.com.br', 'Financeiro', 8, 'finance', '#15803d'),
        ('REGISTRATION', 'cadastro-lojista.brasildesconto.com.br', 'Cadastro', 9, 'registration', '#0369a1'),
        ('PROFILE', 'perfil-lojista.brasildesconto.com.br', 'Perfil', 10, 'profile', '#4338ca'),
        ('ACCOUNTING', 'contabil-lojista.brasildesconto.com.br', 'Contabil', 11, 'accounting', '#854d0e'),
        ('INTEGRATIONS', 'integracao-lojista.brasildesconto.com.br', 'Integracao', 12, 'integrations', '#0f766e'),
        ('ORDERS', 'pedidos-lojista.brasildesconto.com.br', 'Pedidos', 13, 'orders', '#f97316'),
        ('PRODUCTS', 'produtos-lojista.brasildesconto.com.br', 'Produtos', 14, 'products', '#22c55e'),
        ('CUSTOMERS', 'clientes-lojista.brasildesconto.com.br', 'Clientes', 15, 'customers', '#9333ea'),
        ('TAX', 'fiscal-lojista.brasildesconto.com.br', 'Fiscal', 16, 'tax', '#b45309'),
        ('INVENTORY', 'estoque-lojista.brasildesconto.com.br', 'Estoque', 17, 'inventory', '#0284c7'),
        ('LOGISTICS', 'logistica-lojista.brasildesconto.com.br', 'Logistica', 18, 'logistics', '#ea580c'),
        ('SUPPORT', 'atendimento-lojista.brasildesconto.com.br', 'Atendimento', 19, 'support', '#2563eb'),
        ('TEAM', 'equipe-lojista.brasildesconto.com.br', 'Equipe', 20, 'team', '#4f46e5'),
        ('SECURITY', 'seguranca-lojista.brasildesconto.com.br', 'Seguranca', 21, 'security', '#dc2626'),
        ('SETTINGS', 'configuracoes-lojista.brasildesconto.com.br', 'Configuracoes', 22, 'settings', '#334155')
) AS workspace(workspace_code, public_host, title, navigation_order, icon_key, accent_color)
WHERE profile.profile_status <> 'ARCHIVED'
ON CONFLICT (merchant_user_id, workspace_code) DO UPDATE
SET
    merchant_profile_id = EXCLUDED.merchant_profile_id,
    workspace_status = EXCLUDED.workspace_status,
    public_host = EXCLUDED.public_host,
    title = EXCLUDED.title,
    navigation_order = EXCLUDED.navigation_order,
    icon_key = EXCLUDED.icon_key,
    accent_color = EXCLUDED.accent_color,
    feature_config_json = merchant_erp_workspaces.feature_config_json || EXCLUDED.feature_config_json,
    updated_at = NOW();

INSERT INTO merchant_erp_staff_members (
    merchant_user_id,
    staff_user_id,
    role_code,
    member_status,
    display_name,
    email,
    permissions_json
)
SELECT
    profile.merchant_user_id,
    profile.merchant_user_id,
    'OWNER',
    'ACTIVE',
    profile.display_name,
    profile.support_email,
    jsonb_build_object('all', true, 'source', 'v037_seed')
FROM merchant_profiles profile
WHERE profile.profile_status <> 'ARCHIVED'
ON CONFLICT (merchant_user_id, staff_user_id) DO UPDATE
SET
    role_code = EXCLUDED.role_code,
    member_status = EXCLUDED.member_status,
    display_name = EXCLUDED.display_name,
    email = EXCLUDED.email,
    permissions_json = merchant_erp_staff_members.permissions_json || EXCLUDED.permissions_json,
    updated_at = NOW();

INSERT INTO merchant_erp_integration_connections (
    merchant_user_id,
    workspace_code,
    integration_status,
    provider_key,
    provider_label,
    connector_kind,
    credential_ref,
    webhook_url,
    scopes_json,
    settings_json
)
SELECT
    profile.merchant_user_id,
    'INTEGRATIONS',
    'DRAFT',
    provider.provider_key,
    provider.provider_label,
    provider.connector_kind,
    provider.credential_ref,
    provider.webhook_url,
    provider.scopes_json::JSONB,
    jsonb_build_object('source', 'v037_seed', 'merchant_code', profile.merchant_code)
FROM merchant_profiles profile
CROSS JOIN (
    VALUES
        ('mercado_livre', 'Mercado Livre', 'OAUTH2', 'runtime://marketplaces/mercado_livre', 'https://admin.brasildesconto.com.br/integrations/mercadolivre/notifications', '["orders", "items", "shipments", "pricing"]'),
        ('amazon', 'Amazon SP-API', 'OAUTH2_IAM', 'runtime://marketplaces/amazon', 'https://admin.brasildesconto.com.br/integrations/amazon/notifications', '["orders", "listings", "inventory", "pricing"]'),
        ('magalu', 'Magalu Marketplace', 'OAUTH2', 'runtime://marketplaces/magalu', 'https://admin.brasildesconto.com.br/integrations/magalu/notifications', '["catalog", "orders", "stock", "billing"]'),
        ('shopee', 'Shopee Partner API', 'SIGNED_API', 'runtime://marketplaces/shopee', 'https://admin.brasildesconto.com.br/integrations/shopee/notifications', '["item", "orders", "logistics", "returns"]'),
        ('cjdropshipping', 'CJDropshipping', 'API_KEY', 'runtime://suppliers/cjdropshipping', 'https://admin.brasildesconto.com.br/integrations/cjdropshipping/notifications', '["product", "stock", "shipping", "tracking"]'),
        ('aliexpress', 'AliExpress Open Platform', 'OAUTH2', 'runtime://suppliers/aliexpress', 'https://admin.brasildesconto.com.br/integrations/aliexpress/notifications', '["product", "orders", "logistics", "pricing"]'),
        ('alibaba', 'Alibaba OpenAPI', 'SIGNED_API', 'runtime://suppliers/alibaba', 'https://admin.brasildesconto.com.br/integrations/alibaba/notifications', '["catalog", "quote", "order", "supplier"]')
) AS provider(provider_key, provider_label, connector_kind, credential_ref, webhook_url, scopes_json)
WHERE profile.profile_status <> 'ARCHIVED'
ON CONFLICT (merchant_user_id, provider_key) DO UPDATE
SET
    provider_label = EXCLUDED.provider_label,
    connector_kind = EXCLUDED.connector_kind,
    credential_ref = EXCLUDED.credential_ref,
    webhook_url = EXCLUDED.webhook_url,
    scopes_json = EXCLUDED.scopes_json,
    settings_json = merchant_erp_integration_connections.settings_json || EXCLUDED.settings_json,
    updated_at = NOW();

CREATE OR REPLACE VIEW v_merchant_erp_control_tower AS
SELECT
    mp.merchant_user_id,
    mp.merchant_code,
    mp.display_name AS merchant_display_name,
    COALESCE(workspaces.active_workspaces, 0) AS active_workspaces,
    COALESCE(staff.active_staff, 0) AS active_staff,
    COALESCE(pdv.open_pdv_sessions, 0) AS open_pdv_sessions,
    COALESCE(orders.open_order_tasks, 0) AS open_order_tasks,
    COALESCE(catalog.open_catalog_tasks, 0) AS open_catalog_tasks,
    COALESCE(inventory.open_inventory_tasks, 0) AS open_inventory_tasks,
    COALESCE(campaigns.active_campaigns, 0) AS active_campaigns,
    COALESCE(integrations.active_integrations, 0) AS active_integrations,
    COALESCE(finance.open_financial_closures, 0) AS open_financial_closures,
    COALESCE(latest_metrics.gross_revenue_brl, 0) AS latest_gross_revenue_brl,
    COALESCE(latest_metrics.net_revenue_brl, 0) AS latest_net_revenue_brl,
    COALESCE(latest_metrics.orders_count, 0) AS latest_orders_count,
    latest_metrics.snapshot_date AS latest_snapshot_date
FROM merchant_profiles mp
LEFT JOIN LATERAL (
    SELECT COUNT(*)::INTEGER AS active_workspaces
    FROM merchant_erp_workspaces workspace
    WHERE workspace.merchant_user_id = mp.merchant_user_id
      AND workspace.workspace_status = 'ACTIVE'
) workspaces ON TRUE
LEFT JOIN LATERAL (
    SELECT COUNT(*)::INTEGER AS active_staff
    FROM merchant_erp_staff_members staff_member
    WHERE staff_member.merchant_user_id = mp.merchant_user_id
      AND staff_member.member_status = 'ACTIVE'
) staff ON TRUE
LEFT JOIN LATERAL (
    SELECT COUNT(*)::INTEGER AS open_pdv_sessions
    FROM merchant_erp_pdv_sessions session
    WHERE session.merchant_user_id = mp.merchant_user_id
      AND session.session_status IN ('OPEN', 'CLOSING')
) pdv ON TRUE
LEFT JOIN LATERAL (
    SELECT COUNT(*)::INTEGER AS open_order_tasks
    FROM merchant_erp_order_pipeline task
    WHERE task.merchant_user_id = mp.merchant_user_id
      AND task.pipeline_status IN ('OPEN', 'IN_PROGRESS', 'WAITING_EXTERNAL')
) orders ON TRUE
LEFT JOIN LATERAL (
    SELECT COUNT(*)::INTEGER AS open_catalog_tasks
    FROM merchant_erp_catalog_tasks task
    WHERE task.merchant_user_id = mp.merchant_user_id
      AND task.task_status IN ('OPEN', 'IN_PROGRESS', 'WAITING_EXTERNAL')
) catalog ON TRUE
LEFT JOIN LATERAL (
    SELECT COUNT(*)::INTEGER AS open_inventory_tasks
    FROM merchant_erp_inventory_tasks task
    WHERE task.merchant_user_id = mp.merchant_user_id
      AND task.task_status IN ('OPEN', 'IN_PROGRESS', 'WAITING_EXTERNAL')
) inventory ON TRUE
LEFT JOIN LATERAL (
    SELECT COUNT(*)::INTEGER AS active_campaigns
    FROM merchant_erp_campaigns campaign
    WHERE campaign.merchant_user_id = mp.merchant_user_id
      AND campaign.campaign_status IN ('SCHEDULED', 'ACTIVE')
) campaigns ON TRUE
LEFT JOIN LATERAL (
    SELECT COUNT(*)::INTEGER AS active_integrations
    FROM merchant_erp_integration_connections connection
    WHERE connection.merchant_user_id = mp.merchant_user_id
      AND connection.integration_status = 'ACTIVE'
) integrations ON TRUE
LEFT JOIN LATERAL (
    SELECT COUNT(*)::INTEGER AS open_financial_closures
    FROM merchant_erp_financial_closures closure
    WHERE closure.merchant_user_id = mp.merchant_user_id
      AND closure.closure_status IN ('OPEN', 'UNDER_REVIEW', 'REOPENED')
) finance ON TRUE
LEFT JOIN LATERAL (
    SELECT
        snapshot.gross_revenue_brl,
        snapshot.net_revenue_brl,
        snapshot.orders_count,
        snapshot.snapshot_date
    FROM merchant_erp_metric_snapshots snapshot
    WHERE snapshot.merchant_user_id = mp.merchant_user_id
    ORDER BY snapshot.snapshot_date DESC, snapshot.created_at DESC
    LIMIT 1
) latest_metrics ON TRUE;

COMMENT ON TABLE merchant_erp_workspaces IS 'Workspaces publicos do ERP do lojista por subdominio oficial custo zero.';
COMMENT ON TABLE merchant_erp_staff_members IS 'Equipe do lojista, papeis e permissoes por usuario vinculado a users.user_id.';
COMMENT ON TABLE merchant_erp_pdv_terminals IS 'Terminais de PDV fisicos ou virtuais usados pelo lojista.';
COMMENT ON TABLE merchant_erp_pdv_sessions IS 'Sessoes de caixa do PDV com abertura, fechamento e conciliacao.';
COMMENT ON TABLE merchant_erp_cash_movements IS 'Ledger append-only de movimentos de caixa do PDV.';
COMMENT ON TABLE merchant_erp_order_pipeline IS 'Fila operacional de pedidos do lojista para separacao, atendimento e entrega.';
COMMENT ON TABLE merchant_erp_catalog_tasks IS 'Tarefas de catalogo, precificacao, publicacao e saneamento de produtos.';
COMMENT ON TABLE merchant_erp_inventory_tasks IS 'Tarefas de estoque, armazem, picking, inventario e transferencia.';
COMMENT ON TABLE merchant_erp_metric_snapshots IS 'Snapshots append-only de metricas comerciais e operacionais por workspace.';
COMMENT ON TABLE merchant_erp_campaigns IS 'Campanhas comerciais do lojista em marketplace, cupons e canais externos.';
COMMENT ON TABLE merchant_erp_report_exports IS 'Relatorios e exportacoes do ERP com trilha de solicitante e hash de arquivo.';
COMMENT ON TABLE merchant_erp_financial_closures IS 'Fechamentos financeiros do lojista com taxas, repasses e aprovacao.';
COMMENT ON TABLE merchant_erp_accounting_entries IS 'Lancamentos contabeis e fiscais append-only vinculados ao lojista.';
COMMENT ON TABLE merchant_erp_integration_connections IS 'Conectores API/webhook do ERP do lojista sem gravar segredo bruto.';
COMMENT ON TABLE merchant_erp_security_events IS 'Eventos append-only de seguranca, sessao, acesso e risco.';
COMMENT ON TABLE merchant_erp_audit_events IS 'Auditoria append-only das acoes criticas executadas no ERP lojista.';
COMMENT ON VIEW v_merchant_erp_control_tower IS 'Visao consolidada para abrir o cockpit operacional do ERP lojista.';

COMMIT;
