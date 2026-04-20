-- Valley Hybrid DB Bootstrap - Automacao de delivery dos 47 modulos.
-- Este arquivo e gerado por scripts/valley_module_automation.py a partir de config/modules_v47.json.
-- Ele persiste o estado de implantacao, desenvolvimento e evolucao dos modulos no PostgreSQL.
-- Execute depois de 001, 002, 004 e 005.

BEGIN;

SET search_path = public;

CREATE TYPE module_delivery_phase_enum AS ENUM ('DISCOVERY', 'DATA_CONTRACT', 'BUILD', 'VALIDATE', 'DOCUMENT', 'RELEASE', 'EVOLVE');
CREATE TYPE module_delivery_status_enum AS ENUM ('PLANNED', 'IMPLEMENTED_PARTIAL', 'IMPLEMENTED', 'BLOCKED', 'DISCARDED');
CREATE TYPE module_backlog_status_enum AS ENUM ('OPEN', 'IN_PROGRESS', 'DONE', 'DISCARDED');

CREATE TABLE module_delivery_registry (
    module_delivery_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_user_id UUID,
    module_number SMALLINT NOT NULL,
    module_code TEXT NOT NULL UNIQUE,
    module_name TEXT NOT NULL,
    subtitle TEXT,
    domain TEXT NOT NULL,
    tier TEXT NOT NULL,
    data_home TEXT NOT NULL,
    delivery_status module_delivery_status_enum NOT NULL DEFAULT 'PLANNED',
    current_phase module_delivery_phase_enum NOT NULL DEFAULT 'DISCOVERY',
    depends_on TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
    integrates_with TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
    description_ptbr TEXT NOT NULL,
    automation_policy_json JSONB NOT NULL DEFAULT '{"manual_confirmation_required":false,"update_manual":true,"regenerate_pdf":true}'::JSONB,
    last_automation_run_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_module_delivery_registry_owner
        FOREIGN KEY (owner_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT ux_module_delivery_registry_number UNIQUE (module_number),
    CONSTRAINT chk_module_delivery_registry_number CHECK (module_number BETWEEN 1 AND 47),
    CONSTRAINT chk_module_delivery_registry_code CHECK (module_code ~ '^[A-Z0-9_]+$'),
    CONSTRAINT chk_module_delivery_registry_name CHECK (btrim(module_name) <> ''),
    CONSTRAINT chk_module_delivery_registry_data_home CHECK (data_home IN ('postgres', 'mongo', 'postgres_mongo'))
);

CREATE TABLE module_evolution_backlog (
    module_backlog_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_user_id UUID,
    module_code TEXT NOT NULL,
    backlog_status module_backlog_status_enum NOT NULL DEFAULT 'OPEN',
    priority SMALLINT NOT NULL DEFAULT 3,
    title TEXT NOT NULL,
    description_ptbr TEXT NOT NULL,
    acceptance_criteria TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_module_evolution_backlog_owner
        FOREIGN KEY (owner_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_module_evolution_backlog_module
        FOREIGN KEY (module_code) REFERENCES module_delivery_registry (module_code)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT chk_module_evolution_backlog_priority CHECK (priority BETWEEN 1 AND 5),
    CONSTRAINT chk_module_evolution_backlog_title CHECK (btrim(title) <> ''),
    CONSTRAINT chk_module_evolution_backlog_description CHECK (btrim(description_ptbr) <> ''),
    CONSTRAINT chk_module_evolution_backlog_acceptance CHECK (btrim(acceptance_criteria) <> '')
);

CREATE TABLE module_automation_runs (
    module_run_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_user_id UUID,
    module_code TEXT,
    run_kind TEXT NOT NULL,
    run_status TEXT NOT NULL,
    summary_ptbr TEXT NOT NULL,
    artifacts_json JSONB NOT NULL DEFAULT '[]'::JSONB,
    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    finished_at TIMESTAMPTZ,
    CONSTRAINT fk_module_automation_runs_owner
        FOREIGN KEY (owner_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_module_automation_runs_module
        FOREIGN KEY (module_code) REFERENCES module_delivery_registry (module_code)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT chk_module_automation_runs_kind CHECK (btrim(run_kind) <> ''),
    CONSTRAINT chk_module_automation_runs_status CHECK (run_status IN ('STARTED', 'SUCCESS', 'FAILED', 'SKIPPED')),
    CONSTRAINT chk_module_automation_runs_summary CHECK (btrim(summary_ptbr) <> ''),
    CONSTRAINT chk_module_automation_runs_timeline CHECK (finished_at IS NULL OR finished_at >= started_at)
);

CREATE INDEX ix_module_delivery_registry_status_phase
    ON module_delivery_registry (delivery_status, current_phase);

CREATE INDEX ix_module_delivery_registry_domain_tier
    ON module_delivery_registry (domain, tier);

CREATE INDEX ix_module_evolution_backlog_module_status
    ON module_evolution_backlog (module_code, backlog_status, priority);

CREATE INDEX ix_module_automation_runs_module_started_at
    ON module_automation_runs (module_code, started_at);

CREATE TRIGGER trg_module_delivery_registry_set_updated_at
BEFORE UPDATE ON module_delivery_registry
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_module_evolution_backlog_set_updated_at
BEFORE UPDATE ON module_evolution_backlog
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

INSERT INTO module_delivery_registry (
    module_number,
    module_code,
    module_name,
    subtitle,
    domain,
    tier,
    data_home,
    delivery_status,
    depends_on,
    integrates_with,
    description_ptbr
) VALUES
    (1, 'REPLY', 'Valley REPLY', 'Advanced ERP/WMS', 'logistics_erp_operations', 'foundation', 'postgres', 'IMPLEMENTED_PARTIAL', ARRAY['ID', 'PAY', 'BUSINESS']::TEXT[], ARRAY['STOCK', 'MARKETPLACE', 'WMS']::TEXT[], 'ERP/WMS para compras, estoque, ordens de servico e faturamento.'),
(2, 'STOCK', 'Valley Stock', 'Centralized Dropshipping', 'logistics_erp_operations', 'foundation', 'postgres', 'IMPLEMENTED_PARTIAL', ARRAY['MARKETPLACE', 'PAY']::TEXT[], ARRAY['LOG', 'UP', 'DOCS']::TEXT[], 'Motor de dropshipping com fornecedores externos, margem padrao e tracking.'),
(3, 'LOG', 'Valley Log', 'Smart Tracking', 'logistics_erp_operations', 'foundation', 'mongo', 'IMPLEMENTED_PARTIAL', ARRAY['ID']::TEXT[], ARRAY['DELIVERY', 'FOOD', 'MOBILITY']::TEXT[], 'Rastreamento inteligente de encomendas, transportadoras e rotas.'),
(4, 'FOOD', 'Valley Food', 'Health-Centric Delivery', 'logistics_erp_operations', 'core', 'postgres', 'IMPLEMENTED_PARTIAL', ARRAY['PAY', 'LOG', 'HEALTH']::TEXT[], ARRAY['ORDERS', 'MOBILITY', 'DOCS']::TEXT[], 'Delivery alimentar com split Pay, informacoes nutricionais e taxa operacional.'),
(5, 'DELIVERY', 'Valley Delivery', 'Urban Courier', 'logistics_erp_operations', 'core', 'postgres_mongo', 'IMPLEMENTED_PARTIAL', ARRAY['LOG', 'PAY']::TEXT[], ARRAY['FOOD', 'MARKETPLACE', 'MOBILITY']::TEXT[], 'Entrega urbana, coleta local e operacao courier.'),
(6, 'WMS', 'Valley WMS', 'Warehouse Intelligence', 'logistics_erp_operations', 'foundation', 'postgres_mongo', 'IMPLEMENTED_PARTIAL', ARRAY['REPLY']::TEXT[], ARRAY['STOCK', 'IOT', 'BUSINESS']::TEXT[], 'Gestao inteligente de armazens, sensores e estoque multi-deposito.'),
(7, 'MARKETPLACE', 'Valley Marketplace', 'Local Commerce', 'commerce_fintech_assets', 'foundation', 'postgres', 'IMPLEMENTED_PARTIAL', ARRAY['PAY', 'ID']::TEXT[], ARRAY['STOCK', 'ADS', 'UP']::TEXT[], 'Comercio local centralizado, carrinho, produtos e recomendacoes.'),
(8, 'PAY', 'Valley Pay', 'The Financial Heart & Atomic Ledger', 'commerce_fintech_assets', 'foundation', 'postgres', 'IMPLEMENTED_PARTIAL', ARRAY['ID']::TEXT[], ARRAY['WALLETS', 'TRANSACTIONS', 'EQUITY']::TEXT[], 'Carteira, ledger atomico, P2P, splits, limites e conciliacao.'),
(9, 'FLEET', 'Valley Fleet', 'Telemetry & Fleet Management', 'logistics_erp_operations', 'core', 'mongo', 'IMPLEMENTED_PARTIAL', ARRAY['IOT', 'MOBILITY']::TEXT[], ARRAY['LOG', 'SECURITY']::TEXT[], 'Gestao de frotas, telemetria, manutencao preventiva e rotas.'),
(10, 'SERVICES', 'Valley Services', 'Gigs & Pro Services', 'services_health_human', 'core', 'postgres', 'IMPLEMENTED_PARTIAL', ARRAY['ID', 'PAY']::TEXT[], ARRAY['MARKETPLACE', 'LEGAL']::TEXT[], 'Servicos profissionais, gigs, contratacao e reputacao.'),
(11, 'DIGITAL', 'Valley Digital', 'NFT & Digital Assets', 'commerce_fintech_assets', 'expansion', 'postgres', 'IMPLEMENTED_PARTIAL', ARRAY['PAY', 'ID']::TEXT[], ARRAY['CREATOR', 'DOCS']::TEXT[], 'Ativos digitais, NFTs, royalties e custodia tokenizada.'),
(12, 'REAL_ESTATE', 'Valley Real Estate', 'Tokenized Housing', 'commerce_fintech_assets', 'expansion', 'postgres', 'IMPLEMENTED_PARTIAL', ARRAY['PAY', 'LEGAL']::TEXT[], ARRAY['DIGITAL', 'DOCS']::TEXT[], 'Imoveis, contratos, tokenizacao e registro de transacoes.'),
(13, 'HEALTH', 'Valley Health', 'Predictive Care', 'services_health_human', 'core', 'postgres_mongo', 'IMPLEMENTED_PARTIAL', ARRAY['ID']::TEXT[], ARRAY['FOOD', 'FITNESS', 'PHARMACY']::TEXT[], 'Saude preditiva, cuidados integrados e dados sensiveis.'),
(14, 'EDU', 'Valley Edu', 'Learn-to-Earn', 'education_work_social', 'expansion', 'postgres', 'IMPLEMENTED_PARTIAL', ARRAY['ID']::TEXT[], ARRAY['LOYALTY', 'JOBS']::TEXT[], 'Educacao, trilhas, cursos e recompensas por aprendizado.'),
(15, 'TECH', 'Valley Tech', 'SaaS Infrastructure & API Builder', 'platform_developer', 'foundation', 'postgres', 'IMPLEMENTED_PARTIAL', ARRAY['API', 'CLOUD']::TEXT[], ARRAY['CONNECT', 'COMMAND_CENTER']::TEXT[], 'Infra SaaS, API builder, integracoes e plataforma de desenvolvedor.'),
(16, 'JOBS', 'Valley Jobs', 'AI Matchmaking', 'education_work_social', 'core', 'postgres_mongo', 'IMPLEMENTED_PARTIAL', ARRAY['ID', 'AI']::TEXT[], ARRAY['EDU', 'SERVICES']::TEXT[], 'Matching de trabalho, renda, vagas e freelas com IA.'),
(17, 'NEWS_PODCAST', 'Valley News & Podcast', 'ContinuaMente', 'media_social_growth', 'expansion', 'mongo', 'PLANNED', ARRAY['MEDIA']::TEXT[], ARRAY['CREATOR', 'ADS']::TEXT[], 'Noticias, podcasts e conteudo editorial.'),
(18, 'ADS', 'Valley Ads', 'Geofenced Marketing', 'media_social_growth', 'core', 'mongo', 'IMPLEMENTED_PARTIAL', ARRAY['SOCIAL']::TEXT[], ARRAY['MARKETPLACE', 'ADS_INTELLIGENCE']::TEXT[], 'Anuncios geolocalizados, campanhas, GOLD e midia.'),
(19, 'INFLUENCERS', 'Valley Influencers', 'Creators Hub', 'media_social_growth', 'core', 'mongo', 'IMPLEMENTED_PARTIAL', ARRAY['CREATOR', 'UP']::TEXT[], ARRAY['SOCIAL', 'ADS']::TEXT[], 'Hub de criadores, metricas, afiliacao e monetizacao.'),
(20, 'SOCIAL', 'Valley Social', 'Neighborhood Network', 'media_social_growth', 'core', 'mongo', 'IMPLEMENTED_PARTIAL', ARRAY['ID']::TEXT[], ARRAY['EVENTS', 'ADS', 'CREATOR']::TEXT[], 'Rede social de bairro, reputacao, posts e moderacao.'),
(21, 'FITNESS', 'Valley Fitness', 'Move-to-Earn', 'services_health_human', 'expansion', 'mongo', 'PLANNED', ARRAY['HEALTH']::TEXT[], ARRAY['LOYALTY', 'WEARABLES']::TEXT[], 'Fitness, recompensas por movimento e integracao com saude.'),
(22, 'PHARMACY', 'Valley Pharmacy', 'Smart Meds', 'services_health_human', 'core', 'postgres', 'IMPLEMENTED_PARTIAL', ARRAY['HEALTH', 'PAY']::TEXT[], ARRAY['DELIVERY', 'DOCS']::TEXT[], 'Medicamentos, farmacia, receitas e entrega.'),
(23, 'VET', 'Valley Vet', 'Pet Care', 'services_health_human', 'expansion', 'postgres', 'IMPLEMENTED_PARTIAL', ARRAY['ID']::TEXT[], ARRAY['PHARMACY', 'SERVICES']::TEXT[], 'Cuidados veterinarios, pet care e servicos.'),
(24, 'TOURISM', 'Valley Tourism', 'Local Explore', 'city_mobility_security', 'expansion', 'postgres_mongo', 'PLANNED', ARRAY['PAY']::TEXT[], ARRAY['EVENTS', 'MOBILITY']::TEXT[], 'Turismo local, experiencias, reservas e exploracao.'),
(25, 'EVENTS', 'Valley Events', 'Safe Tickets & Event Escrow', 'city_mobility_security', 'core', 'postgres', 'IMPLEMENTED_PARTIAL', ARRAY['PAY']::TEXT[], ARRAY['TICKETS', 'DOCS']::TEXT[], 'Ingressos, eventos, escrow e seguranca de venda.'),
(26, 'MOBILITY', 'Valley Mobility', 'Urban Transport & Carpool', 'city_mobility_security', 'core', 'postgres_mongo', 'IMPLEMENTED_PARTIAL', ARRAY['PAY', 'RIDER']::TEXT[], ARRAY['LOG', 'FLEET']::TEXT[], 'Corridas urbanas, carpool, riders e taxa de plataforma.'),
(27, 'SECURITY', 'Valley Security', 'SOS, Protection & Biometric Guard', 'city_mobility_security', 'core', 'postgres_mongo', 'IMPLEMENTED_PARTIAL', ARRAY['ID']::TEXT[], ARRAY['IOT', 'LEGAL']::TEXT[], 'SOS, protecao pessoal, biometria e risco.'),
(28, 'GOV', 'Valley Gov', 'Citizen Portal', 'city_mobility_security', 'expansion', 'postgres', 'IMPLEMENTED_PARTIAL', ARRAY['ID']::TEXT[], ARRAY['LEGAL', 'DOCS']::TEXT[], 'Portal cidadao, govtech e servicos publicos.'),
(29, 'LEGAL', 'Valley Legal', 'Smart Contracts, Fallback PIN & AI Mediator', 'city_mobility_security', 'foundation', 'postgres', 'IMPLEMENTED_PARTIAL', ARRAY['ID']::TEXT[], ARRAY['DOCS', 'SECURITY']::TEXT[], 'Contratos, mediacao por IA, fallback PIN e juridico.'),
(30, 'CHARITY', 'Valley Charity', 'Transparent Giving', 'education_work_social', 'expansion', 'postgres', 'IMPLEMENTED_PARTIAL', ARRAY['PAY']::TEXT[], ARRAY['DOCS', 'SOCIAL']::TEXT[], 'Doacoes transparentes, auditoria e impacto social.'),
(31, 'INSURANCE', 'Valley Insurance', 'On-Demand Protection', 'commerce_fintech_assets', 'expansion', 'postgres', 'IMPLEMENTED_PARTIAL', ARRAY['PAY', 'LEGAL']::TEXT[], ARRAY['SECURITY', 'DOCS']::TEXT[], 'Seguros sob demanda, protecao e analise de risco.'),
(32, 'GAMING', 'Valley Gaming', 'Gamified Ecosystem', 'media_social_growth', 'expansion', 'mongo', 'PLANNED', ARRAY['LOYALTY']::TEXT[], ARRAY['SOCIAL', 'CREATOR']::TEXT[], 'Jogos, recompensas, comunidades e gamificacao.'),
(33, 'IOT', 'Valley IoT', 'Connected Things & Smart Hub', 'frontier_iot_energy', 'foundation', 'mongo', 'IMPLEMENTED_PARTIAL', ARRAY['ID']::TEXT[], ARRAY['HOME', 'FLEET', 'SECURITY']::TEXT[], 'Dispositivos conectados, sensores e hub inteligente.'),
(34, 'BIO', 'Valley Bio', 'Eco-Sustainability & Reverse Logistics', 'frontier_iot_energy', 'expansion', 'postgres_mongo', 'PLANNED', ARRAY['LOG']::TEXT[], ARRAY['IOT', 'ENERGY']::TEXT[], 'Sustentabilidade, logistica reversa e impacto ambiental.'),
(35, 'HOME', 'Valley Home', 'Smart Automation', 'frontier_iot_energy', 'expansion', 'mongo', 'PLANNED', ARRAY['IOT']::TEXT[], ARRAY['SECURITY', 'ENERGY']::TEXT[], 'Automacao residencial, dispositivos e seguranca domestica.'),
(36, 'ENERGY', 'Valley Energy', 'P2P Smart Grid Trading', 'frontier_iot_energy', 'expansion', 'postgres_mongo', 'PLANNED', ARRAY['PAY', 'IOT']::TEXT[], ARRAY['BIO', 'HOME']::TEXT[], 'Energia, smart grid, creditos e transacoes P2P.'),
(37, 'SPACE', 'Valley Space', 'Augmented Reality Anchors', 'frontier_iot_energy', 'frontier', 'mongo', 'PLANNED', ARRAY['CLOUD']::TEXT[], ARRAY['SOCIAL', 'TOURISM']::TEXT[], 'Realidade aumentada, ancoras espaciais e experiencias imersivas.'),
(38, 'AGENDA', 'Valley Agenda', 'Helena Core Memory & Smart Lists', 'ai_memory_operations', 'core', 'mongo', 'IMPLEMENTED_PARTIAL', ARRAY['AI']::TEXT[], ARRAY['ADVISOR', 'CHAT']::TEXT[], 'Agenda, listas inteligentes, memoria Helena e lembretes.'),
(39, 'ADVISOR', 'Valley Advisor', 'Omni-Consultoria de IA', 'ai_memory_operations', 'core', 'postgres_mongo', 'IMPLEMENTED_PARTIAL', ARRAY['AI', 'PAY']::TEXT[], ARRAY['FINANCAS', 'HEALTH', 'MOBILITY']::TEXT[], 'Consultoria de IA com recomendacoes e consentimento de execucao.'),
(40, 'FINANCAS', 'Valley Financas', 'PFM & Gestao de Micro-Negocios', 'commerce_fintech_assets', 'core', 'postgres', 'IMPLEMENTED_PARTIAL', ARRAY['PAY']::TEXT[], ARRAY['ADVISOR', 'BUSINESS']::TEXT[], 'Financas pessoais, metas, micro-negocios e round-up.'),
(41, 'MENTE', 'Valley Mente', 'Saude Mental Digital', 'services_health_human', 'core', 'postgres', 'IMPLEMENTED_PARTIAL', ARRAY['HEALTH', 'ID']::TEXT[], ARRAY['ADVISOR', 'DOCS']::TEXT[], 'Saude mental digital, teleterapia e notas cifradas.'),
(42, 'BUSINESS', 'Valley Business', 'ERP de Integracao', 'logistics_erp_operations', 'foundation', 'postgres', 'IMPLEMENTED_PARTIAL', ARRAY['PAY', 'REPLY']::TEXT[], ARRAY['INVOICES', 'PAYROLLS']::TEXT[], 'ERP integrado para empresas, fiscais, estoque e folha.'),
(43, 'PLUG', 'Valley Plug', 'Maquininha & Tap-to-Pay', 'commerce_fintech_assets', 'core', 'postgres', 'IMPLEMENTED_PARTIAL', ARRAY['PAY']::TEXT[], ARRAY['WALLETS', 'BUSINESS']::TEXT[], 'Maquininha, Tap-to-Pay, MDR e antecipacao D+0.'),
(44, 'UP', 'Valley Up', 'Motor de Afiliados CAC Zero', 'commerce_fintech_assets', 'core', 'postgres_mongo', 'IMPLEMENTED_PARTIAL', ARRAY['PAY', 'MARKETPLACE']::TEXT[], ARRAY['INFLUENCERS', 'LOYALTY']::TEXT[], 'Afiliados, indicacoes, comissoes e links de atribuicao.'),
(45, 'MEDIA', 'Valley Media', 'Painel de Criadores', 'media_social_growth', 'core', 'postgres_mongo', 'IMPLEMENTED_PARTIAL', ARRAY['CREATOR']::TEXT[], ARRAY['SOCIAL', 'ADS']::TEXT[], 'Painel de criadores, uploads, monetizacao e distribuicao de conteudo.'),
(46, 'CHAT', 'Valley Chat', 'Mensageria com Dupla Persona', 'ai_memory_operations', 'core', 'postgres_mongo', 'IMPLEMENTED_PARTIAL', ARRAY['ID']::TEXT[], ARRAY['AGENDA', 'ADVISOR']::TEXT[], 'Mensageria com persona pessoal/profissional e retencao segura.'),
(47, 'DOCS', 'Valley Docs', 'Fabrica de Documentos e Recibos', 'platform_developer', 'foundation', 'postgres', 'IMPLEMENTED_PARTIAL', ARRAY['PAY', 'LEGAL']::TEXT[], ARRAY['ORDERS', 'TRANSACTIONS']::TEXT[], 'Geracao de documentos, recibos, checksums e registros imutaveis.')
ON CONFLICT (module_code) DO UPDATE SET
    module_number = EXCLUDED.module_number,
    module_name = EXCLUDED.module_name,
    subtitle = EXCLUDED.subtitle,
    domain = EXCLUDED.domain,
    tier = EXCLUDED.tier,
    data_home = EXCLUDED.data_home,
    delivery_status = EXCLUDED.delivery_status,
    depends_on = EXCLUDED.depends_on,
    integrates_with = EXCLUDED.integrates_with,
    description_ptbr = EXCLUDED.description_ptbr,
    updated_at = NOW();

INSERT INTO module_evolution_backlog (
    module_code,
    priority,
    title,
    description_ptbr,
    acceptance_criteria
)
SELECT
    module_code,
    CASE WHEN tier = 'foundation' THEN 1 WHEN tier = 'core' THEN 2 WHEN tier = 'expansion' THEN 3 ELSE 4 END,
    'Definir contrato de dados especifico para ' || module_name,
    'Criar ou revisar schema, regras, integracoes e documentacao do modulo ' || module_name || '.',
    'Schema definido ou descarte justificado; Manual Online atualizado; PDF regenerado; validacao registrada.'
FROM module_delivery_registry
ON CONFLICT DO NOTHING;

COMMENT ON TYPE module_delivery_phase_enum IS 'Fase atual da esteira de desenvolvimento do modulo.';
COMMENT ON TYPE module_delivery_status_enum IS 'Status macro de implantacao do modulo.';
COMMENT ON TYPE module_backlog_status_enum IS 'Status de item do backlog evolutivo.';
COMMENT ON TABLE module_delivery_registry IS 'Registro canonico dos 47 modulos para automatizar implantacao, desenvolvimento e evolucao.';
COMMENT ON TABLE module_evolution_backlog IS 'Backlog evolutivo por modulo, gerado a partir do registry canonico.';
COMMENT ON TABLE module_automation_runs IS 'Historico de execucoes da automacao de modulos.';
COMMENT ON COLUMN module_delivery_registry.owner_user_id IS 'FK opcional para users.user_id quando houver responsavel humano ou system user.';
COMMENT ON COLUMN module_delivery_registry.module_code IS 'Codigo tecnico do modulo usado por scripts, regras e roadmap.';
COMMENT ON COLUMN module_delivery_registry.automation_policy_json IS 'Politica da automacao: atualizar manual, PDF e evitar confirmacoes manuais.';
COMMENT ON COLUMN module_evolution_backlog.acceptance_criteria IS 'Criterio objetivo para concluir o item de evolucao.';
COMMENT ON COLUMN module_automation_runs.artifacts_json IS 'Arquivos e evidencias geradas pela automacao.';

COMMIT;
