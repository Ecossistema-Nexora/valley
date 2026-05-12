-- Seed idempotente do ERP do lojista.
-- Popula workspaces publicos, owner operacional e conectores base para todo merchant ativo.

BEGIN;

SET search_path = public;

WITH demo_user AS (
    INSERT INTO users (
        user_id,
        user_kind,
        account_status,
        kyc_status,
        full_name,
        display_name,
        email,
        phone_e164,
        document_country,
        document_type,
        document_number,
        primary_role,
        module_tier,
        terms_accepted_at,
        privacy_accepted_at,
        created_at,
        updated_at
    )
    VALUES (
        'a87f541f-fdd0-51b7-9e1c-73a4a0bbd9c8',
        'PJ',
        'ACTIVE',
        'APPROVED',
        'Lojista Valley Demo',
        'Lojista Demo',
        'lojista.demo@valley.local',
        '+5511999001001',
        'BR',
        'CNPJ',
        '00000000001001',
        'MERCHANT',
        'PRODUCT',
        NOW(),
        NOW(),
        NOW(),
        NOW()
    )
    ON CONFLICT (document_country, document_type, document_number) DO UPDATE
    SET
        account_status = EXCLUDED.account_status,
        kyc_status = EXCLUDED.kyc_status,
        display_name = EXCLUDED.display_name,
        primary_role = EXCLUDED.primary_role,
        module_tier = EXCLUDED.module_tier,
        updated_at = NOW()
    RETURNING user_id
),
demo_wallet AS (
    INSERT INTO wallets (
        wallet_id,
        user_id,
        wallet_type,
        asset_code,
        wallet_status,
        daily_limit_brl,
        monthly_limit_brl,
        created_at,
        updated_at
    )
    SELECT
        'f5a9e5dd-622f-51d0-a218-5ef5165f77ec',
        user_id,
        'SETTLEMENT',
        'BRL',
        'ACTIVE',
        50000.0000,
        800000.0000,
        NOW(),
        NOW()
    FROM demo_user
    ON CONFLICT (user_id, wallet_type, asset_code) DO UPDATE
    SET
        wallet_status = EXCLUDED.wallet_status,
        daily_limit_brl = EXCLUDED.daily_limit_brl,
        monthly_limit_brl = EXCLUDED.monthly_limit_brl,
        updated_at = NOW()
    RETURNING wallet_id, user_id
)
INSERT INTO merchant_profiles (
    merchant_profile_id,
    merchant_user_id,
    wallet_id,
    profile_status,
    merchant_code,
    slug,
    display_name,
    legal_name_override,
    support_email,
    support_phone_e164,
    support_whatsapp_e164,
    response_sla_hours,
    return_policy_json,
    shipping_policy_json,
    checkout_policy_json,
    support_policy_json,
    metadata_json,
    onboarding_completed_at,
    created_at,
    updated_at
)
SELECT
    'c4815e0d-60d0-5c96-b3b7-356f86f6cd91',
    user_id,
    wallet_id,
    'ACTIVE',
    'MER-VALLEY-DEMO',
    'lojista-demo',
    'Lojista Demo',
    'Lojista Valley Demo LTDA',
    'lojista.demo@valley.local',
    '+5511999001001',
    '+5511999001001',
    4,
    jsonb_build_object('window_days', 7, 'policy', 'Troca assistida pelo ERP Valley.'),
    jsonb_build_object('origin', 'Valley', 'mode', 'supplier_or_local_stock'),
    jsonb_build_object('checkout', 'marketplace_pdv_online'),
    jsonb_build_object('sla_hours', 4, 'channels', jsonb_build_array('chat', 'email', 'whatsapp')),
    jsonb_build_object('source', 'seed_004', 'erp_ready', true),
    NOW(),
    NOW(),
    NOW()
FROM demo_wallet
ON CONFLICT (merchant_user_id) DO UPDATE
SET
    wallet_id = EXCLUDED.wallet_id,
    profile_status = EXCLUDED.profile_status,
    merchant_code = EXCLUDED.merchant_code,
    slug = EXCLUDED.slug,
    display_name = EXCLUDED.display_name,
    legal_name_override = EXCLUDED.legal_name_override,
    support_email = EXCLUDED.support_email,
    support_phone_e164 = EXCLUDED.support_phone_e164,
    support_whatsapp_e164 = EXCLUDED.support_whatsapp_e164,
    response_sla_hours = EXCLUDED.response_sla_hours,
    return_policy_json = merchant_profiles.return_policy_json || EXCLUDED.return_policy_json,
    shipping_policy_json = merchant_profiles.shipping_policy_json || EXCLUDED.shipping_policy_json,
    checkout_policy_json = merchant_profiles.checkout_policy_json || EXCLUDED.checkout_policy_json,
    support_policy_json = merchant_profiles.support_policy_json || EXCLUDED.support_policy_json,
    metadata_json = merchant_profiles.metadata_json || EXCLUDED.metadata_json,
    onboarding_completed_at = COALESCE(merchant_profiles.onboarding_completed_at, EXCLUDED.onboarding_completed_at),
    updated_at = NOW();

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
    jsonb_build_object('source', 'seed_004', 'slug', profile.slug, 'merchant_code', profile.merchant_code)
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
    jsonb_build_object('all', true, 'source', 'seed_004')
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
    jsonb_build_object('source', 'seed_004', 'merchant_code', profile.merchant_code)
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

COMMIT;
