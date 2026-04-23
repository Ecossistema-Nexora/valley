begin;

create extension if not exists pgcrypto;

create table if not exists billing_customers (
  billing_customer_id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(user_id) on update cascade on delete restrict,
  wallet_id uuid references public.wallets(wallet_id) on update cascade on delete restrict,
  pj_profile_id uuid references public.pj_profiles(pj_profile_id) on update cascade on delete set null,
  stripe_customer_id text unique,
  billing_email text,
  billing_name text,
  status text not null default 'active',
  metadata_json jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint ux_billing_customers_user unique (user_id),
  constraint chk_billing_customers_email check (
    billing_email is null or billing_email ~* '^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$'
  ),
  constraint chk_billing_customers_name check (
    billing_name is null or btrim(billing_name) <> ''
  ),
  constraint chk_billing_customers_status check (
    status in ('active', 'inactive', 'blocked')
  ),
  constraint chk_billing_customers_metadata check (
    jsonb_typeof(metadata_json) = 'object'
  )
);

create table if not exists billing_subscriptions (
  billing_subscription_id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(user_id) on update cascade on delete restrict,
  billing_customer_id uuid not null references billing_customers(billing_customer_id) on update cascade on delete restrict,
  wallet_id uuid references public.wallets(wallet_id) on update cascade on delete restrict,
  stripe_subscription_id text unique,
  plan_code text not null,
  status text not null,
  billing_cycle text not null default 'monthly',
  current_period_start timestamptz,
  current_period_end timestamptz,
  cancel_at_period_end boolean not null default false,
  metadata_json jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint chk_billing_subscriptions_plan check (btrim(plan_code) <> ''),
  constraint chk_billing_subscriptions_status check (
    status in ('trialing', 'active', 'past_due', 'cancelled', 'incomplete', 'paused')
  ),
  constraint chk_billing_subscriptions_cycle check (
    billing_cycle in ('monthly', 'quarterly', 'semiannual', 'annual', 'custom')
  ),
  constraint chk_billing_subscriptions_period check (
    current_period_end is null
    or current_period_start is null
    or current_period_end >= current_period_start
  ),
  constraint chk_billing_subscriptions_metadata check (
    jsonb_typeof(metadata_json) = 'object'
  )
);

create table if not exists billing_invoices (
  billing_invoice_id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(user_id) on update cascade on delete restrict,
  billing_subscription_id uuid references billing_subscriptions(billing_subscription_id) on update cascade on delete set null,
  stripe_invoice_id text unique,
  amount_due_brl decimal(18,4) not null default 0,
  amount_paid_brl decimal(18,4) not null default 0,
  currency_code char(3) not null default 'BRL',
  status text not null,
  hosted_invoice_url text,
  invoice_pdf_url text,
  due_at timestamptz,
  paid_at timestamptz,
  metadata_json jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint chk_billing_invoices_amounts check (
    amount_due_brl >= 0 and amount_paid_brl >= 0
  ),
  constraint chk_billing_invoices_currency check (
    currency_code ~ '^[A-Z]{3}$'
  ),
  constraint chk_billing_invoices_status check (
    status in ('draft', 'open', 'paid', 'void', 'uncollectible', 'failed')
  ),
  constraint chk_billing_invoices_urls check (
    (hosted_invoice_url is null or hosted_invoice_url ~ '^https?://')
    and (invoice_pdf_url is null or invoice_pdf_url ~ '^https?://')
  ),
  constraint chk_billing_invoices_timeline check (
    paid_at is null or due_at is null or paid_at >= due_at - interval '30 days'
  ),
  constraint chk_billing_invoices_metadata check (
    jsonb_typeof(metadata_json) = 'object'
  )
);

create table if not exists billing_webhook_events (
  billing_webhook_event_id uuid primary key default gen_random_uuid(),
  stripe_event_id text unique not null,
  event_type text not null,
  user_id uuid references public.users(user_id) on update cascade on delete set null,
  billing_customer_id uuid references billing_customers(billing_customer_id) on update cascade on delete set null,
  payload_json jsonb not null,
  processed_at timestamptz,
  processing_status text not null default 'pending',
  created_at timestamptz not null default now(),
  constraint chk_billing_webhook_events_event_type check (btrim(event_type) <> ''),
  constraint chk_billing_webhook_events_payload check (jsonb_typeof(payload_json) = 'object'),
  constraint chk_billing_webhook_events_status check (
    processing_status in ('pending', 'processed', 'ignored', 'failed')
  )
);

create table if not exists billing_plan_entitlements (
  plan_code text not null,
  feature_key text not null,
  feature_value text not null,
  module_code text,
  is_hard_limit boolean not null default false,
  created_at timestamptz not null default now(),
  primary key (plan_code, feature_key),
  constraint chk_billing_plan_entitlements_plan check (btrim(plan_code) <> ''),
  constraint chk_billing_plan_entitlements_feature check (
    btrim(feature_key) <> '' and btrim(feature_value) <> ''
  )
);

create index if not exists ix_billing_subscriptions_user_status
  on billing_subscriptions (user_id, status);

create index if not exists ix_billing_invoices_user_status
  on billing_invoices (user_id, status, created_at desc);

create index if not exists ix_billing_webhook_events_status
  on billing_webhook_events (processing_status, created_at desc);

commit;
