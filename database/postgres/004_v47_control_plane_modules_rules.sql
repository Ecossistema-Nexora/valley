-- Valley Hybrid DB Bootstrap - Implantacao v47 viavel: plano de controle.
-- Este arquivo adapta os PDFs v47 ao modelo core-first em public, sem multi-schema legado.
-- Integra modulos, Admin RBAC/ABAC, regras versionadas, Loyalty, incidentes e documentos.
-- Execute depois de 001_core_identity_wallets.sql e 002_financial_ledger_equity_orders.sql.

BEGIN;

SET search_path = public;

CREATE TYPE admin_role_enum AS ENUM ('SUPERADMIN', 'OPERATOR', 'ANALYST', 'VIEWER');
CREATE TYPE rule_severity_enum AS ENUM ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL');
CREATE TYPE rule_status_enum AS ENUM ('DRAFT', 'PENDING_APPROVAL', 'ACTIVE', 'DISABLED', 'ARCHIVED');
CREATE TYPE rule_audit_action_enum AS ENUM ('CREATE', 'UPDATE', 'APPROVE', 'ACTIVATE', 'DEACTIVATE', 'ARCHIVE', 'ROLLBACK', 'DRY_RUN');
CREATE TYPE reward_type_enum AS ENUM ('POINTS', 'TOKEN', 'BADGE', 'PEPITA');
CREATE TYPE campaign_status_enum AS ENUM ('DRAFT', 'PENDING_APPROVAL', 'APPROVED', 'REJECTED', 'ACTIVE', 'PAUSED', 'ENDED');
CREATE TYPE incident_status_enum AS ENUM ('OPEN', 'IN_PROGRESS', 'RESOLVED', 'CANCELLED');

CREATE TABLE module_catalog (
    module_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    module_number SMALLINT NOT NULL,
    module_code TEXT NOT NULL,
    module_name TEXT NOT NULL,
    primary_audience TEXT NOT NULL,
    secondary_audience TEXT,
    central_function TEXT NOT NULL,
    monetization_model TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    source_document TEXT NOT NULL DEFAULT 'Valley Omniverse - Mapeamento de Modulos (v47)',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT ux_module_catalog_number UNIQUE (module_number),
    CONSTRAINT ux_module_catalog_code UNIQUE (module_code),
    CONSTRAINT chk_module_catalog_number CHECK (module_number BETWEEN 1 AND 99),
    CONSTRAINT chk_module_catalog_code CHECK (module_code ~ '^[A-Z0-9_]{2,64}$'),
    CONSTRAINT chk_module_catalog_name CHECK (btrim(module_name) <> ''),
    CONSTRAINT chk_module_catalog_primary_audience CHECK (btrim(primary_audience) <> ''),
    CONSTRAINT chk_module_catalog_central_function CHECK (btrim(central_function) <> '')
);

CREATE TABLE admin_users (
    admin_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL UNIQUE,
    username TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    admin_role admin_role_enum NOT NULL DEFAULT 'VIEWER',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    last_login_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_admin_users_user
        FOREIGN KEY (user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT chk_admin_users_username CHECK (btrim(username) <> ''),
    CONSTRAINT chk_admin_users_password_hash CHECK (length(password_hash) >= 32)
);

CREATE TABLE admin_permissions (
    permission_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_id UUID NOT NULL,
    module_code TEXT NOT NULL,
    can_read BOOLEAN NOT NULL DEFAULT TRUE,
    can_write BOOLEAN NOT NULL DEFAULT FALSE,
    can_approve BOOLEAN NOT NULL DEFAULT FALSE,
    constraints_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_admin_permissions_admin
        FOREIGN KEY (admin_id) REFERENCES admin_users (admin_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT fk_admin_permissions_module
        FOREIGN KEY (module_code) REFERENCES module_catalog (module_code)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT ux_admin_permissions_admin_module UNIQUE (admin_id, module_code),
    CONSTRAINT chk_admin_permissions_has_capability CHECK (can_read OR can_write OR can_approve)
);

CREATE TABLE business_rule_definitions (
    rule_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rule_code TEXT NOT NULL UNIQUE,
    module_code TEXT NOT NULL,
    rule_name TEXT NOT NULL,
    description TEXT NOT NULL,
    severity rule_severity_enum NOT NULL,
    rule_status rule_status_enum NOT NULL DEFAULT 'DRAFT',
    constraints_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_by_admin_id UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_business_rule_definitions_module
        FOREIGN KEY (module_code) REFERENCES module_catalog (module_code)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_business_rule_definitions_admin
        FOREIGN KEY (created_by_admin_id) REFERENCES admin_users (admin_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT chk_business_rule_definitions_code CHECK (rule_code ~ '^[A-Z0-9_-]{3,80}$'),
    CONSTRAINT chk_business_rule_definitions_name CHECK (btrim(rule_name) <> ''),
    CONSTRAINT chk_business_rule_definitions_description CHECK (btrim(description) <> '')
);

CREATE TABLE business_rule_versions (
    rule_version_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rule_id UUID NOT NULL,
    version_number INTEGER NOT NULL,
    definition_json JSONB NOT NULL,
    enabled BOOLEAN NOT NULL DEFAULT FALSE,
    change_log TEXT NOT NULL,
    approved_by_admin_id UUID,
    approved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_business_rule_versions_rule
        FOREIGN KEY (rule_id) REFERENCES business_rule_definitions (rule_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT fk_business_rule_versions_approved_by
        FOREIGN KEY (approved_by_admin_id) REFERENCES admin_users (admin_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT ux_business_rule_versions_rule_version UNIQUE (rule_id, version_number),
    CONSTRAINT chk_business_rule_versions_version CHECK (version_number > 0),
    CONSTRAINT chk_business_rule_versions_change_log CHECK (btrim(change_log) <> ''),
    CONSTRAINT chk_business_rule_versions_approval CHECK (
        (enabled = FALSE)
        OR (approved_by_admin_id IS NOT NULL AND approved_at IS NOT NULL)
    )
);

CREATE TABLE business_rule_audit (
    rule_audit_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rule_id UUID NOT NULL,
    rule_version_id UUID,
    audit_action rule_audit_action_enum NOT NULL,
    performed_by_admin_id UUID,
    details_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    performed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_business_rule_audit_rule
        FOREIGN KEY (rule_id) REFERENCES business_rule_definitions (rule_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_business_rule_audit_version
        FOREIGN KEY (rule_version_id) REFERENCES business_rule_versions (rule_version_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_business_rule_audit_admin
        FOREIGN KEY (performed_by_admin_id) REFERENCES admin_users (admin_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
);

CREATE TABLE gamification_campaigns (
    campaign_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    module_code TEXT NOT NULL,
    campaign_name TEXT NOT NULL,
    description TEXT,
    start_date DATE,
    end_date DATE,
    reward_type reward_type_enum NOT NULL,
    target_audience_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    approval_status campaign_status_enum NOT NULL DEFAULT 'DRAFT',
    created_by_admin_id UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_gamification_campaigns_module
        FOREIGN KEY (module_code) REFERENCES module_catalog (module_code)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_gamification_campaigns_admin
        FOREIGN KEY (created_by_admin_id) REFERENCES admin_users (admin_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT chk_gamification_campaigns_name CHECK (btrim(campaign_name) <> ''),
    CONSTRAINT chk_gamification_campaigns_dates CHECK (
        start_date IS NULL OR end_date IS NULL OR end_date >= start_date
    )
);

CREATE TABLE points_ledger (
    points_ledger_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    campaign_id UUID,
    points INTEGER NOT NULL,
    reason TEXT NOT NULL,
    granted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ,
    CONSTRAINT fk_points_ledger_user
        FOREIGN KEY (user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_points_ledger_campaign
        FOREIGN KEY (campaign_id) REFERENCES gamification_campaigns (campaign_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT chk_points_ledger_points_non_zero CHECK (points <> 0),
    CONSTRAINT chk_points_ledger_reason CHECK (btrim(reason) <> ''),
    CONSTRAINT chk_points_ledger_expiration CHECK (expires_at IS NULL OR expires_at > granted_at)
);

CREATE TABLE observability_incidents (
    incident_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    module_code TEXT,
    severity rule_severity_enum NOT NULL DEFAULT 'MEDIUM',
    incident_status incident_status_enum NOT NULL DEFAULT 'OPEN',
    description TEXT NOT NULL,
    detected_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    resolved_at TIMESTAMPTZ,
    runbook_reference TEXT,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_observability_incidents_module
        FOREIGN KEY (module_code) REFERENCES module_catalog (module_code)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT chk_observability_incidents_description CHECK (btrim(description) <> ''),
    CONSTRAINT chk_observability_incidents_resolution CHECK (
        resolved_at IS NULL OR resolved_at >= detected_at
    )
);

CREATE TABLE document_records (
    document_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    module_code TEXT,
    order_id UUID,
    transaction_id UUID,
    file_url TEXT NOT NULL,
    checksum_sha256 TEXT NOT NULL,
    event_reference UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_document_records_user
        FOREIGN KEY (user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_document_records_module
        FOREIGN KEY (module_code) REFERENCES module_catalog (module_code)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_document_records_order
        FOREIGN KEY (order_id) REFERENCES orders (order_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_document_records_transaction
        FOREIGN KEY (transaction_id) REFERENCES transactions (transaction_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT chk_document_records_file_url CHECK (btrim(file_url) <> ''),
    CONSTRAINT chk_document_records_checksum CHECK (checksum_sha256 ~ '^[a-fA-F0-9]{64}$')
);

CREATE TABLE admin_action_audit (
    admin_action_audit_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_id UUID,
    user_id UUID,
    module_code TEXT,
    action_name TEXT NOT NULL,
    reason TEXT,
    before_json JSONB,
    after_json JSONB,
    correlation_id TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_admin_action_audit_admin
        FOREIGN KEY (admin_id) REFERENCES admin_users (admin_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_admin_action_audit_user
        FOREIGN KEY (user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_admin_action_audit_module
        FOREIGN KEY (module_code) REFERENCES module_catalog (module_code)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT chk_admin_action_audit_action_name CHECK (btrim(action_name) <> '')
);

CREATE INDEX ix_module_catalog_active
    ON module_catalog (is_active, module_number);

CREATE INDEX ix_admin_permissions_module
    ON admin_permissions (module_code);

CREATE INDEX ix_business_rule_definitions_module_status
    ON business_rule_definitions (module_code, rule_status);

CREATE INDEX ix_business_rule_versions_rule_enabled
    ON business_rule_versions (rule_id, enabled);

CREATE INDEX ix_business_rule_audit_rule_performed_at
    ON business_rule_audit (rule_id, performed_at);

CREATE INDEX ix_gamification_campaigns_module_status
    ON gamification_campaigns (module_code, approval_status);

CREATE INDEX ix_points_ledger_user_granted_at
    ON points_ledger (user_id, granted_at);

CREATE INDEX ix_observability_incidents_status_severity
    ON observability_incidents (incident_status, severity);

CREATE INDEX ix_document_records_user_created_at
    ON document_records (user_id, created_at);

CREATE INDEX ix_admin_action_audit_admin_created_at
    ON admin_action_audit (admin_id, created_at);

CREATE TRIGGER trg_module_catalog_set_updated_at
BEFORE UPDATE ON module_catalog
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_admin_users_set_updated_at
BEFORE UPDATE ON admin_users
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_admin_permissions_set_updated_at
BEFORE UPDATE ON admin_permissions
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_business_rule_definitions_set_updated_at
BEFORE UPDATE ON business_rule_definitions
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_gamification_campaigns_set_updated_at
BEFORE UPDATE ON gamification_campaigns
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_observability_incidents_set_updated_at
BEFORE UPDATE ON observability_incidents
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_business_rule_audit_prevent_update
BEFORE UPDATE ON business_rule_audit
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

CREATE TRIGGER trg_business_rule_audit_prevent_delete
BEFORE DELETE ON business_rule_audit
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

CREATE TRIGGER trg_points_ledger_prevent_update
BEFORE UPDATE ON points_ledger
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

CREATE TRIGGER trg_points_ledger_prevent_delete
BEFORE DELETE ON points_ledger
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

CREATE TRIGGER trg_document_records_prevent_update
BEFORE UPDATE ON document_records
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

CREATE TRIGGER trg_document_records_prevent_delete
BEFORE DELETE ON document_records
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

CREATE TRIGGER trg_admin_action_audit_prevent_update
BEFORE UPDATE ON admin_action_audit
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

CREATE TRIGGER trg_admin_action_audit_prevent_delete
BEFORE DELETE ON admin_action_audit
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

INSERT INTO module_catalog (
    module_number,
    module_code,
    module_name,
    primary_audience,
    secondary_audience,
    central_function,
    monetization_model
) VALUES
    (1, 'LOGISTICS', 'Logistica', 'PF: rastreamento de pedidos', 'PJ: gestao de frota', 'Solucoes de entrega, coleta e SLA', 'Taxas de frete e comissoes'),
    (2, 'MOBILITY', 'Mobilidade', 'PF: transporte urbano', 'PJ: gestao de motoristas', 'Servicos de corrida e deslocamento local', 'Taxa de servico por corrida'),
    (3, 'ENERGY', 'Energia', 'PF: consumo residencial', 'PJ: custos energeticos', 'Monitoramento e solucoes energeticas', 'Venda de creditos e servicos'),
    (4, 'EDUCATION', 'Educacao', 'PF: cursos e capacitacao', 'PJ: treinamento corporativo', 'Conteudo educacional e trilhas', 'Assinaturas e venda de cursos'),
    (5, 'SOCIAL', 'Social', 'PF: comunidade local', 'PJ: branding e engajamento', 'Rede social e reputacao', 'Publicidade e engajamento'),
    (6, 'AI', 'IA', 'PF: assistente pessoal', 'PJ: automacao e analytics', 'Servicos de inteligencia artificial', 'Licenciamento e upsell'),
    (7, 'MARKETPLACE', 'Marketplace', 'PF: compras locais', 'PJ: venda de produtos', 'Comercio eletronico centralizado', 'Comissoes sobre vendas'),
    (8, 'PAY', 'Pay', 'PF: pagamentos e carteira', 'PJ: liquidacao e conciliacao', 'Plataforma financeira e wallet', 'Tarifas de transacao'),
    (9, 'ADS', 'Ads', 'PJ: anuncios', 'Influencer: campanhas', 'Publicidade geolocalizada', 'Venda de midia CPC/CPM'),
    (10, 'AGRO', 'Agro', 'PF: alimentos e campo', 'PJ: operacao agro', 'Conexao com cadeia produtiva', 'Comissoes e servicos'),
    (11, 'SECURITY', 'Seguranca', 'PF: protecao pessoal', 'PJ: seguranca corporativa', 'Identidade, autenticacao e risco', 'Licencas e subscricoes'),
    (12, 'CLOUD', 'Cloud', 'PF: storage pessoal', 'PJ: hospedagem', 'Armazenamento e computacao em nuvem', 'Assinaturas e uso on-demand'),
    (13, 'HEALTH', 'Health', 'PF: saude pessoal', 'PJ: clinicas e operadoras', 'Acompanhamento de saude integrado', 'Planos e consultas'),
    (14, 'STREAM', 'Stream', 'PF: conteudo ao vivo', 'PJ: streaming corporativo', 'Plataforma de transmissoes', 'Pay-per-view e assinatura'),
    (15, 'TRAVEL', 'Viagens', 'PF: turismo', 'PJ: hospedagem e transporte', 'Reserva de viagens e experiencias', 'Comissoes e pacotes'),
    (16, 'JOBS', 'Jobs', 'PF: vagas e freelas', 'PJ: recrutamento', 'Matching de trabalho e renda', 'Taxas de servico'),
    (17, 'REAL_ESTATE', 'Imoveis', 'PF: compra e aluguel', 'PJ: imobiliarias', 'Marketplace imobiliario', 'Comissoes de venda e aluguel'),
    (18, 'ADS_INTELLIGENCE', 'Ads Intelligence', 'PJ: marketing avancado', 'Influencer: insights', 'Segmentacao e performance de anuncios', 'Licenciamento de dados'),
    (19, 'FINANCE', 'Finance', 'PF: financas pessoais', 'PJ: gestao financeira', 'PFM e planejamento empresarial', 'Produtos financeiros'),
    (20, 'ID', 'ID', 'PF: identidade digital', 'PJ: perfis empresariais', 'Unificacao de credenciais', 'KYC e identificacao'),
    (21, 'CONNECT', 'Connect', 'PF: integracoes pessoais', 'PJ: APIs corporativas', 'Conexao com apps e sistemas externos', 'Tarifa de API'),
    (22, 'PHARMACY', 'Pharmacy', 'PF: medicamentos', 'PJ: farmacias', 'Venda e entrega de remedios', 'Margem de venda'),
    (23, 'FOOD', 'Food', 'PF: refeicoes', 'PJ: restaurantes', 'Delivery e mercado alimentar', 'Taxa de pedido'),
    (24, 'BUSINESS', 'Business', 'PJ: gestao empresarial', 'Influencer: organizacao', 'Ferramentas de ERP e growth', 'Assinatura SaaS'),
    (25, 'LABS', 'Labs', 'PF: novidades', 'PJ: pilotos de inovacao', 'Teste de features beta', 'Sem cobranca e engajamento'),
    (26, 'API', 'API', 'PJ: integracoes', 'Influencer: automacoes', 'Acesso programatico ao ecossistema', 'Planos de uso'),
    (27, 'OS', 'OS', 'PF: experiencia unificada', 'PJ: painel operacional', 'Sistema operacional do Valley', 'Bundling com outros modulos'),
    (28, 'ANALYTICS', 'Analytics', 'PF: metricas pessoais', 'PJ: KPIs de negocio', 'Analise de dados e desempenho', 'Licencas e dashboards'),
    (29, 'GOV', 'Gov', 'PF: servicos publicos', 'PJ: compliance', 'Porta de entrada para govtech', 'Contratos governamentais'),
    (30, 'TICKETS', 'Tickets', 'PF: ingressos e reservas', 'PJ: organizadores', 'Venda e gestao de eventos', 'Taxa por ingresso'),
    (31, 'ERP', 'ERP', 'PJ: empresas', 'Influencer: gestao simplificada', 'Sistema completo de ERP', 'Assinaturas e licencas'),
    (32, 'AUTO', 'Auto', 'PF: servicos automotivos', 'PJ: oficinas', 'Manutencao e mobilidade veicular', 'Taxas de servico'),
    (33, 'HOME', 'Casa', 'PF: utilidades domesticas', 'PJ: prestadores', 'Solucoes para o lar', 'Comissoes'),
    (34, 'FAITH', 'Faith', 'PF: comunidades de fe', 'PJ: instituicoes', 'Experiencias religiosas', 'Doacoes e eventos'),
    (35, 'GLOBAL', 'Global', 'PF: expansao', 'PJ: internacionalizacao', 'Acesso a mercados globais', 'Taxas de cambio e servicos'),
    (36, 'QUANTUM', 'Quantum', 'PJ: inovacao avancada', 'PF: beneficios indiretos', 'Computacao e modelagem de ponta', 'Licenciamento'),
    (37, 'COMMAND_CENTER', 'Command Center', 'PJ: controle executivo', 'Influencer: cockpit', 'Painel unificado de gestao', 'Bundle corporativo'),
    (38, 'AGENDA', 'Valley Agenda', 'PF: agenda pessoal', 'PJ: automacoes de rotina', 'Listas, lembretes e memorias', 'Integrado com outros modulos'),
    (39, 'LOYALTY', 'Loyalty', 'PF: recompensas', 'PJ: fidelidade', 'Programa de pontos e Pepitas', 'Cashbacks e incentivos'),
    (40, 'CREATOR', 'Creator', 'Influencer: criadores', 'PJ: marcas criativas', 'Modulo central de conteudo', 'Monetizacao de conteudos'),
    (41, 'OMNIVERSE_CORE', 'Omniverse Core', 'PF: experiencia unificada', 'PJ: hub central', 'Orquestracao de todos os modulos', 'Indireto via uso dos modulos')
ON CONFLICT (module_code) DO UPDATE SET
    module_number = EXCLUDED.module_number,
    module_name = EXCLUDED.module_name,
    primary_audience = EXCLUDED.primary_audience,
    secondary_audience = EXCLUDED.secondary_audience,
    central_function = EXCLUDED.central_function,
    monetization_model = EXCLUDED.monetization_model,
    updated_at = NOW();

INSERT INTO business_rule_definitions (
    rule_code,
    module_code,
    rule_name,
    description,
    severity,
    rule_status,
    constraints_json
) VALUES
    ('BR-STO-PRICE-001', 'MARKETPLACE', 'Formula Stock custo frete margem', 'Preco final do dropshipping usa custo + frete + 50 por cento de margem.', 'HIGH', 'ACTIVE', '{"formula":"cost + freight + margin","margin_rate":0.50}'::JSONB),
    ('BR-MOB-FEE-001', 'MOBILITY', 'Taxa fixa Mobility', 'Cada corrida Mobility cobra 10 por cento de comissao da plataforma.', 'HIGH', 'ACTIVE', '{"platform_fee_rate":0.10}'::JSONB),
    ('BR-FOOD-FEE-001', 'FOOD', 'Taxa fixa Food', 'Pedidos Food cobram 15 por cento sobre o valor do pedido.', 'HIGH', 'ACTIVE', '{"platform_fee_rate":0.15}'::JSONB),
    ('BR-UP-COMMISSION-001', 'LOYALTY', 'Comissao afiliados Up', 'Afiliados recebem 5 por cento da margem sobre vendas Stock ou Marketplace.', 'HIGH', 'ACTIVE', '{"affiliate_margin_share":0.05}'::JSONB),
    ('BR-FIN-002', 'FINANCE', 'Ring-Fence Financeiro', 'Dados de endividamento e score de credito nao podem alimentar publicidade ou marketing.', 'CRITICAL', 'ACTIVE', '{"forbidden_targets":["ADS","ADS_INTELLIGENCE"],"data_classes":["debt","credit_score"]}'::JSONB),
    ('BR-ADV-001', 'AI', 'Consentimento de Execucao Advisor', 'Advisor pode recomendar, mas execucao financeira exige consentimento biometrico do usuario.', 'CRITICAL', 'ACTIVE', '{"requires_biometric_consent":true,"applies_to":["financial_execution"]}'::JSONB)
ON CONFLICT (rule_code) DO UPDATE SET
    module_code = EXCLUDED.module_code,
    rule_name = EXCLUDED.rule_name,
    description = EXCLUDED.description,
    severity = EXCLUDED.severity,
    rule_status = EXCLUDED.rule_status,
    constraints_json = EXCLUDED.constraints_json,
    updated_at = NOW();

WITH selected_rules AS (
    SELECT
        rule_id,
        rule_code,
        constraints_json
    FROM business_rule_definitions
    WHERE rule_code IN (
        'BR-STO-PRICE-001',
        'BR-MOB-FEE-001',
        'BR-FOOD-FEE-001',
        'BR-UP-COMMISSION-001',
        'BR-FIN-002',
        'BR-ADV-001'
    )
)
INSERT INTO business_rule_versions (
    rule_id,
    version_number,
    definition_json,
    enabled,
    change_log
)
SELECT
    rule_id,
    1,
    jsonb_build_object(
        'rule_code', rule_code,
        'source', 'PDF v47 adaptado ao core-first Valley',
        'constraints', constraints_json
    ),
    FALSE,
    'Versao inicial importada dos PDFs v47; permanece desabilitada ate aprovacao admin.'
FROM selected_rules
ON CONFLICT (rule_id, version_number) DO NOTHING;

COMMENT ON TYPE admin_role_enum IS 'Papel tecnico do usuario interno no Web Admin.';
COMMENT ON TYPE rule_severity_enum IS 'Severidade operacional de regras, incidentes e auditoria.';
COMMENT ON TYPE rule_status_enum IS 'Status de lifecycle da regra versionada.';
COMMENT ON TYPE rule_audit_action_enum IS 'Acao auditavel executada sobre regra ou versao.';
COMMENT ON TYPE reward_type_enum IS 'Tipo de recompensa do Loyalty/Gamification.';
COMMENT ON TYPE campaign_status_enum IS 'Status de aprovacao e execucao de campanha.';
COMMENT ON TYPE incident_status_enum IS 'Status de tratamento de incidente operacional.';

COMMENT ON TABLE module_catalog IS 'Catalogo canonico dos 41 modulos v47 viaveis, adaptado ao modelo public core-first.';
COMMENT ON TABLE admin_users IS 'Usuarios internos do Web Admin vinculados a users.user_id para RBAC/ABAC.';
COMMENT ON TABLE admin_permissions IS 'Permissoes por admin e modulo, com read/write/approve e constraints JSON.';
COMMENT ON TABLE business_rule_definitions IS 'Definicoes canonicas de regras de negocio versionadas.';
COMMENT ON TABLE business_rule_versions IS 'Versoes de regras para aprovacao, rollback e dry-run.';
COMMENT ON TABLE business_rule_audit IS 'Trilha append-only de auditoria de regras.';
COMMENT ON TABLE gamification_campaigns IS 'Campanhas de Loyalty/Gamification com aprovacao operacional.';
COMMENT ON TABLE points_ledger IS 'Ledger append-only de pontos e Pepitas para recompensas.';
COMMENT ON TABLE observability_incidents IS 'Incidentes operacionais normalizados; logs brutos ficam fora do Postgres.';
COMMENT ON TABLE document_records IS 'Registro append-only de PDFs, recibos e documentos gerados.';
COMMENT ON TABLE admin_action_audit IS 'Audit trail append-only para acoes criticas do Web Admin.';

COMMIT;
