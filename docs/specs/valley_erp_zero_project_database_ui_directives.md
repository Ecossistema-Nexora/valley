<!--
PROPOSITO: Persistir no repositorio a especificacao mestre usada como entrada para o projeto novo do Stitch.
CONTEXTO: Copia controlada do arquivo `C:\Users\ereta\Downloads\Especificacao_Master_Valley_ERP_v1.md` apos inclusao da documentacao de banco por perfil.
REGRAS: Usar como fonte para Stitch/Figma/Flutter, preservar nomenclatura Valley e manter segredos fora do documento.
-->

# MASTER SPECIFICATION: VALLEY MERCHANT ERP (STITCH & CODEX)

## 0. PROTOCOLO DE EXECUÇÃO SÊNIOR (SYSTEM PROMPT)
Você é uma Desenvolvedora Fullstack Sênior com plenos poderes de execução. 
**DIRETRIZ:** Entrega total e ininterrupta. Não solicite confirmações para decisões técnicas padrão; siga este blueprint até a conclusão.
**STATUS UPDATE:** A cada 5 minutos de processamento, gere um log:
- **Atividade:** [Nome]
- **Descrição:** [Breve]
- **Passo:** [X de Y]
- **Dificuldade:** [1-5]
- **Concluído:** [%]
- **Tempo Previsto:** [Minutos]
- **Sumário:** [Concluídas: N | Pendentes: M]

---

## 1. REGRAS GLOBAIS E SEGURANÇA (ACL & SCOPE)
1. **Isolamento de Dados (Tenant):** Toda query, gravação ou relatório DEVE obrigatoriamente incluir `where tenant_id = ?` e, quando aplicável, `and branch_id = ?`. Nunca vazar dados entre lojistas.
2. **Sigilo Operacional (BR-PRO-001):** Proibido exibir custos brutos, fórmulas de markup ou margens para o usuário final. Foco 100% no valor percebido e economia gerada.
3. **Dialeto:** Português do Brasil (PT-BR). Helena deve usar sotaque regional baseado na cidade de nascimento do usuário (configurável).

---

## 2. ARQUITETURA DE DADOS (DATABASE SCHEMA)
Arquitetura híbrida: **PostgreSQL** para identidade, permissões, regras, cadastros, pedidos, pagamentos, comissões, auditoria e dados relacionais críticos; **MongoDB** para mensagens, memória da Helena, telemetria, eventos de alto volume e logs semiestruturados.

### 2.1 Convenções Obrigatórias
- **IDs:** Todo registro persistente usa `UUID` como chave primária.
- **Multi-tenant:** Toda tabela operacional deve possuir `tenant_id UUID NOT NULL` e, quando aplicável, `branch_id UUID NULL`.
- **Usuário central:** Toda tabela de ação humana deve possuir `user_id UUID NULL/NOT NULL` ou uma FK direta para tabela que possua `user_id`.
- **Auditoria padrão PostgreSQL:** Quando não indicado o contrário, todas as tabelas possuem `id UUID PK`, `tenant_id UUID FK`, `branch_id UUID NULL FK`, `created_at TIMESTAMPTZ NOT NULL`, `updated_at TIMESTAMPTZ NOT NULL`, `created_by UUID NULL FK`, `updated_by UUID NULL FK`, `deleted_at TIMESTAMPTZ NULL`.
- **Valores monetários:** BRL em `NUMERIC(18,4)`. V-Coin em `NUMERIC(18,8)`. Quantidades em `NUMERIC(18,4)` quando fracionáveis.
- **JSON controlado:** Usar `JSONB` apenas para metadados versionados, payloads de integração, regras dinâmicas e snapshots de tela/fluxo.
- **Imutabilidade:** Ledgers financeiros, auditoria administrativa, comissões e eventos de entrega são append-only. Correções exigem lançamento compensatório, nunca `UPDATE` destrutivo.
- **Privacidade:** Comentários internos de entregadores e lojistas devem ser visíveis apenas para Administração Valley e lojista diretamente vinculado ao pedido.

### 2.2 PostgreSQL - Grupo Admin
Escopo: gestão total do Valley, módulos, regras, serviços, cadastros, funções, APIs, tokens, usuários, auditoria e Modo Deus.

| Tabela | Responsabilidade | Campos e formatos |
|---|---|---|
| `admin_tenants` | Cadastro de empresas, unidades administrativas e proprietários de dados. | `id UUID PK`, `parent_tenant_id UUID NULL FK`, `tenant_type VARCHAR(32)` (`platform`, `merchant`, `supplier`, `service_provider`), `legal_name VARCHAR(180)`, `trade_name VARCHAR(120)`, `cnpj VARCHAR(18) NULL UNIQUE`, `tax_regime VARCHAR(40) NULL`, `status VARCHAR(32)`, `plan_tier VARCHAR(32)`, `onboarding_status VARCHAR(32)`, `timezone VARCHAR(64)`, `default_currency CHAR(3)`, `metadata JSONB`, campos de auditoria. |
| `admin_branches` | Filiais, lojas, centros de distribuição e pontos operacionais. | `id UUID PK`, `tenant_id UUID FK`, `code VARCHAR(40)`, `name VARCHAR(120)`, `branch_type VARCHAR(32)`, `cnpj VARCHAR(18) NULL`, `phone_e164 VARCHAR(20) NULL`, `email VARCHAR(180) NULL`, `address_id UUID NULL FK`, `latitude NUMERIC(10,7) NULL`, `longitude NUMERIC(10,7) NULL`, `status VARCHAR(32)`, campos de auditoria. |
| `core_users` | Identidade base de admin, lojista, usuário final e entregador. | `id UUID PK`, `tenant_id UUID FK`, `branch_id UUID NULL FK`, `email VARCHAR(180) UNIQUE`, `phone_e164 VARCHAR(20) NULL`, `cpf VARCHAR(14) NULL UNIQUE`, `full_name VARCHAR(160)`, `display_name VARCHAR(80) NULL`, `birth_date DATE NULL`, `birth_city VARCHAR(120) NULL`, `preferred_language VARCHAR(12)`, `helena_voice_profile VARCHAR(80) NULL`, `avatar_url TEXT NULL`, `status VARCHAR(32)`, `kyc_status VARCHAR(32)`, `last_login_at TIMESTAMPTZ NULL`, `terms_accepted_at TIMESTAMPTZ NULL`, `privacy_accepted_at TIMESTAMPTZ NULL`, `metadata JSONB`, campos de auditoria. |
| `core_user_identities` | Login, provedores, senha e MFA. | `id UUID PK`, `tenant_id UUID FK`, `user_id UUID FK`, `provider VARCHAR(32)`, `provider_subject VARCHAR(180)`, `password_hash TEXT NULL`, `mfa_enabled BOOLEAN`, `mfa_secret_ref TEXT NULL`, `last_password_change_at TIMESTAMPTZ NULL`, `failed_attempts INTEGER`, `locked_until TIMESTAMPTZ NULL`, `status VARCHAR(32)`, campos de auditoria. |
| `admin_roles` | Papéis globais e por tenant. | `id UUID PK`, `tenant_id UUID FK`, `role_code VARCHAR(64)`, `role_name VARCHAR(120)`, `role_scope VARCHAR(32)` (`admin`, `merchant`, `customer`, `courier`), `is_super_admin BOOLEAN`, `is_system_role BOOLEAN`, `description TEXT NULL`, `status VARCHAR(32)`, campos de auditoria. |
| `admin_permissions` | Catálogo granular de permissões e funções. | `id UUID PK`, `permission_code VARCHAR(120) UNIQUE`, `module_code VARCHAR(64)`, `action VARCHAR(64)`, `resource VARCHAR(120)`, `risk_level SMALLINT`, `description TEXT NULL`, `status VARCHAR(32)`, `created_at TIMESTAMPTZ`, `updated_at TIMESTAMPTZ`. |
| `admin_role_permissions` | Associação role-permissão. | `id UUID PK`, `tenant_id UUID FK`, `role_id UUID FK`, `permission_id UUID FK`, `effect VARCHAR(16)` (`allow`, `deny`), `conditions JSONB NULL`, `created_at TIMESTAMPTZ`, `created_by UUID NULL FK`, UNIQUE (`role_id`, `permission_id`). |
| `admin_user_roles` | Permissões efetivas por usuário. | `id UUID PK`, `tenant_id UUID FK`, `branch_id UUID NULL FK`, `user_id UUID FK`, `role_id UUID FK`, `starts_at TIMESTAMPTZ`, `ends_at TIMESTAMPTZ NULL`, `status VARCHAR(32)`, campos de auditoria. |
| `admin_module_registry` | Catálogo dos módulos Valley e disponibilidade no MVP. | `id UUID PK`, `module_code VARCHAR(64) UNIQUE`, `module_name VARCHAR(120)`, `profile_scope VARCHAR(32)[]`, `mvp_visible BOOLEAN`, `requires_kyc BOOLEAN`, `api_base_path TEXT NULL`, `frontend_route TEXT NULL`, `android_enabled BOOLEAN`, `web_enabled BOOLEAN`, `status VARCHAR(32)`, `feature_flags JSONB`, campos de auditoria. |
| `admin_module_visibility_rules` | Controle de módulos disponíveis por perfil, plano, tenant e app. | `id UUID PK`, `tenant_id UUID FK`, `module_id UUID FK`, `target_profile VARCHAR(32)`, `target_plan VARCHAR(32) NULL`, `is_visible BOOLEAN`, `sort_order INTEGER`, `rule_payload JSONB`, `starts_at TIMESTAMPTZ NULL`, `ends_at TIMESTAMPTZ NULL`, campos de auditoria. |
| `admin_service_catalog` | Serviços internos e externos controlados pelo Valley. | `id UUID PK`, `tenant_id UUID FK`, `service_code VARCHAR(80)`, `service_name VARCHAR(140)`, `module_code VARCHAR(64)`, `service_type VARCHAR(40)`, `owner_team VARCHAR(80)`, `sla_minutes INTEGER NULL`, `status VARCHAR(32)`, `metadata JSONB`, campos de auditoria. |
| `admin_business_rules` | Regras de preço, comissão, checkout, entrega, KYC, moderação e módulo. | `id UUID PK`, `tenant_id UUID FK`, `rule_code VARCHAR(100)`, `module_code VARCHAR(64)`, `rule_type VARCHAR(64)`, `priority INTEGER`, `conditions JSONB`, `actions JSONB`, `version INTEGER`, `is_active BOOLEAN`, `valid_from TIMESTAMPTZ`, `valid_until TIMESTAMPTZ NULL`, campos de auditoria. |
| `admin_api_clients` | Aplicações e integrações autorizadas. | `id UUID PK`, `tenant_id UUID FK`, `client_name VARCHAR(140)`, `client_type VARCHAR(40)`, `owner_user_id UUID NULL FK`, `allowed_origins TEXT[]`, `allowed_redirect_uris TEXT[]`, `rate_limit_per_minute INTEGER`, `status VARCHAR(32)`, campos de auditoria. |
| `admin_api_tokens` | Tokens de API, webhooks e automações, sempre com hash. | `id UUID PK`, `tenant_id UUID FK`, `client_id UUID FK`, `token_hash TEXT`, `token_prefix VARCHAR(16)`, `scopes TEXT[]`, `expires_at TIMESTAMPTZ NULL`, `last_used_at TIMESTAMPTZ NULL`, `last_used_ip INET NULL`, `revoked_at TIMESTAMPTZ NULL`, `status VARCHAR(32)`, campos de auditoria. |
| `admin_integration_endpoints` | APIs de fornecedores, gateways, frete, marketplace e mensageria. | `id UUID PK`, `tenant_id UUID FK`, `provider_code VARCHAR(80)`, `module_code VARCHAR(64)`, `base_url TEXT`, `auth_type VARCHAR(40)`, `credential_ref TEXT`, `health_status VARCHAR(32)`, `last_healthcheck_at TIMESTAMPTZ NULL`, `timeout_ms INTEGER`, `metadata JSONB`, campos de auditoria. |
| `admin_god_mode_sessions` | Modo Deus com justificativa, validade e trilha de auditoria. | `id UUID PK`, `tenant_id UUID FK`, `admin_user_id UUID FK`, `approved_by UUID NULL FK`, `reason TEXT`, `scope JSONB`, `started_at TIMESTAMPTZ`, `expires_at TIMESTAMPTZ`, `ended_at TIMESTAMPTZ NULL`, `status VARCHAR(32)`, `immutable_hash TEXT`, campos de auditoria. |
| `admin_audit_log` | Auditoria append-only de ações críticas. | `id UUID PK`, `tenant_id UUID FK`, `branch_id UUID NULL FK`, `actor_user_id UUID NULL FK`, `action VARCHAR(120)`, `resource_type VARCHAR(120)`, `resource_id UUID NULL`, `before_snapshot JSONB NULL`, `after_snapshot JSONB NULL`, `ip_address INET NULL`, `user_agent TEXT NULL`, `risk_level SMALLINT`, `immutable_hash TEXT`, `previous_hash TEXT NULL`, `created_at TIMESTAMPTZ NOT NULL`. |
| `admin_system_settings` | Parâmetros globais e por tenant. | `id UUID PK`, `tenant_id UUID FK`, `setting_key VARCHAR(120)`, `setting_value JSONB`, `value_type VARCHAR(32)`, `is_secret BOOLEAN`, `version INTEGER`, `status VARCHAR(32)`, campos de auditoria. |

### 2.3 PostgreSQL - Grupo Lojista / Valley ERP
Escopo: ERP do lojista, onboarding, controle de módulos, funções, regras e serviços individuais por perfil de lojista.

| Tabela | Responsabilidade | Campos e formatos |
|---|---|---|
| `merchant_profiles` | Perfil operacional do lojista. | `id UUID PK`, `tenant_id UUID FK`, `owner_user_id UUID FK`, `cnpj VARCHAR(18) UNIQUE`, `legal_name VARCHAR(180)`, `trade_name VARCHAR(120)`, `segment VARCHAR(80)`, `operating_model VARCHAR(40)`, `default_markup_percent NUMERIC(9,4) NULL`, `commission_policy_id UUID NULL FK`, `kyb_status VARCHAR(32)`, `status VARCHAR(32)`, `metadata JSONB`, campos de auditoria. |
| `merchant_onboarding_applications` | Cadastro de Empresa e Usuários iniciado pelo botão Cadastre-se. | `id UUID PK`, `tenant_id UUID NULL FK`, `applicant_user_id UUID NULL FK`, `cnpj VARCHAR(18)`, `company_payload JSONB`, `legal_representative_payload JSONB`, `admin_setup_payload JSONB`, `team_invites_payload JSONB`, `current_step VARCHAR(40)`, `status VARCHAR(32)`, `submitted_at TIMESTAMPTZ NULL`, `approved_at TIMESTAMPTZ NULL`, `rejected_reason TEXT NULL`, campos de auditoria. |
| `merchant_legal_representatives` | Representante legal vinculado à responsabilidade jurídica. | `id UUID PK`, `tenant_id UUID FK`, `user_id UUID NULL FK`, `full_name VARCHAR(160)`, `cpf VARCHAR(14)`, `email VARCHAR(180)`, `phone_e164 VARCHAR(20)`, `role_title VARCHAR(80)`, `document_url TEXT NULL`, `signature_status VARCHAR(32)`, `status VARCHAR(32)`, campos de auditoria. |
| `merchant_departments` | Departamentos como Comercial, Logística, Fiscal, Financeiro e Operação. | `id UUID PK`, `tenant_id UUID FK`, `branch_id UUID NULL FK`, `department_code VARCHAR(64)`, `department_name VARCHAR(120)`, `manager_user_id UUID NULL FK`, `status VARCHAR(32)`, campos de auditoria. |
| `merchant_department_invites` | Convites iniciais e recorrentes de equipe. | `id UUID PK`, `tenant_id UUID FK`, `department_id UUID NULL FK`, `email VARCHAR(180)`, `phone_e164 VARCHAR(20) NULL`, `invited_role_id UUID FK`, `invite_token_hash TEXT`, `expires_at TIMESTAMPTZ`, `accepted_at TIMESTAMPTZ NULL`, `status VARCHAR(32)`, campos de auditoria. |
| `merchant_staff_profiles` | Usuários do ERP por cargo e escopo de filial. | `id UUID PK`, `tenant_id UUID FK`, `branch_id UUID NULL FK`, `user_id UUID FK`, `department_id UUID NULL FK`, `employee_code VARCHAR(60) NULL`, `job_title VARCHAR(100)`, `can_access_costs BOOLEAN`, `can_manage_users BOOLEAN`, `status VARCHAR(32)`, campos de auditoria. |
| `merchant_products` | Produtos Stock, Marketplace e PDV. | `id UUID PK`, `tenant_id UUID FK`, `branch_id UUID NULL FK`, `sku VARCHAR(80)`, `ean13 VARCHAR(13) NULL`, `title VARCHAR(180)`, `description TEXT NULL`, `category_id UUID NULL FK`, `product_type VARCHAR(32)`, `supplier_id UUID NULL FK`, `base_cost_brl NUMERIC(18,4) NULL`, `sale_price_brl NUMERIC(18,4)`, `promotional_price_brl NUMERIC(18,4) NULL`, `weight_kg NUMERIC(10,4) NULL`, `width_cm NUMERIC(10,2) NULL`, `height_cm NUMERIC(10,2) NULL`, `length_cm NUMERIC(10,2) NULL`, `lifecycle_status VARCHAR(32)`, `metadata JSONB`, campos de auditoria. |
| `merchant_product_media` | Fotos, vídeos e documentos de produto. | `id UUID PK`, `tenant_id UUID FK`, `product_id UUID FK`, `media_type VARCHAR(32)`, `url TEXT`, `alt_text VARCHAR(180) NULL`, `sort_order INTEGER`, `is_primary BOOLEAN`, `status VARCHAR(32)`, campos de auditoria. |
| `merchant_inventory` | Saldo atual, reserva e reabastecimento. | `id UUID PK`, `tenant_id UUID FK`, `branch_id UUID FK`, `product_id UUID FK`, `quantity_on_hand NUMERIC(18,4)`, `quantity_reserved NUMERIC(18,4)`, `quantity_available NUMERIC(18,4)`, `reorder_point NUMERIC(18,4) NULL`, `reorder_quantity NUMERIC(18,4) NULL`, `last_counted_at TIMESTAMPTZ NULL`, `status VARCHAR(32)`, campos de auditoria. |
| `merchant_inventory_movements` | Ledger de estoque. | `id UUID PK`, `tenant_id UUID FK`, `branch_id UUID FK`, `product_id UUID FK`, `movement_type VARCHAR(40)`, `quantity NUMERIC(18,4)`, `unit_cost_brl NUMERIC(18,4) NULL`, `source_type VARCHAR(60)`, `source_id UUID NULL`, `reason TEXT NULL`, `created_at TIMESTAMPTZ`, `created_by UUID NULL FK`, `immutable_hash TEXT`. |
| `merchant_price_rules` | Markup, promoções, descontos e regras por canal. | `id UUID PK`, `tenant_id UUID FK`, `product_id UUID NULL FK`, `category_id UUID NULL FK`, `channel VARCHAR(32)`, `rule_type VARCHAR(40)`, `priority INTEGER`, `conditions JSONB`, `price_formula JSONB`, `starts_at TIMESTAMPTZ NULL`, `ends_at TIMESTAMPTZ NULL`, `status VARCHAR(32)`, campos de auditoria. |
| `merchant_service_catalog` | Serviços agendáveis ou vendáveis no Marketplace. | `id UUID PK`, `tenant_id UUID FK`, `branch_id UUID NULL FK`, `service_name VARCHAR(140)`, `service_category VARCHAR(80)`, `duration_minutes INTEGER NULL`, `base_price_brl NUMERIC(18,4)`, `requires_appointment BOOLEAN`, `capacity INTEGER NULL`, `status VARCHAR(32)`, `metadata JSONB`, campos de auditoria. |
| `merchant_orders` | Pedidos de PDV, Stock e Marketplace. | `id UUID PK`, `tenant_id UUID FK`, `branch_id UUID NULL FK`, `customer_user_id UUID FK`, `channel VARCHAR(32)`, `order_number VARCHAR(40) UNIQUE`, `status VARCHAR(40)`, `subtotal_brl NUMERIC(18,4)`, `discount_brl NUMERIC(18,4)`, `shipping_brl NUMERIC(18,4)`, `service_fee_brl NUMERIC(18,4)`, `total_brl NUMERIC(18,4)`, `payment_status VARCHAR(32)`, `delivery_status VARCHAR(32) NULL`, `delivery_address_id UUID NULL FK`, `metadata JSONB`, campos de auditoria. |
| `merchant_order_items` | Itens de pedidos. | `id UUID PK`, `tenant_id UUID FK`, `order_id UUID FK`, `product_id UUID NULL FK`, `service_id UUID NULL FK`, `item_title VARCHAR(180)`, `quantity NUMERIC(18,4)`, `unit_price_brl NUMERIC(18,4)`, `discount_brl NUMERIC(18,4)`, `total_brl NUMERIC(18,4)`, `supplier_payload JSONB NULL`, campos de auditoria. |
| `merchant_finance_entries` | DRE, contas a pagar/receber, fluxo de caixa e conciliação. | `id UUID PK`, `tenant_id UUID FK`, `branch_id UUID NULL FK`, `entry_type VARCHAR(40)`, `category VARCHAR(80)`, `source_type VARCHAR(60)`, `source_id UUID NULL`, `description TEXT`, `amount_brl NUMERIC(18,4)`, `due_date DATE NULL`, `paid_at TIMESTAMPTZ NULL`, `status VARCHAR(32)`, `metadata JSONB`, campos de auditoria. |
| `merchant_appointment_resources` | Salas, profissionais, mesas, equipamentos e agendas. | `id UUID PK`, `tenant_id UUID FK`, `branch_id UUID NULL FK`, `resource_type VARCHAR(40)`, `resource_name VARCHAR(120)`, `user_id UUID NULL FK`, `capacity INTEGER NULL`, `availability_rules JSONB`, `status VARCHAR(32)`, campos de auditoria. |
| `merchant_appointments` | Agenda para serviços do Marketplace. | `id UUID PK`, `tenant_id UUID FK`, `branch_id UUID NULL FK`, `customer_user_id UUID FK`, `service_id UUID FK`, `resource_id UUID NULL FK`, `starts_at TIMESTAMPTZ`, `ends_at TIMESTAMPTZ`, `status VARCHAR(40)`, `price_brl NUMERIC(18,4)`, `notes TEXT NULL`, `metadata JSONB`, campos de auditoria. |
| `merchant_pdv_sessions` | Sessões de caixa e operação offline. | `id UUID PK`, `tenant_id UUID FK`, `branch_id UUID FK`, `opened_by UUID FK`, `closed_by UUID NULL FK`, `opened_at TIMESTAMPTZ`, `closed_at TIMESTAMPTZ NULL`, `opening_amount_brl NUMERIC(18,4)`, `closing_amount_brl NUMERIC(18,4) NULL`, `offline_sync_status VARCHAR(32)`, `status VARCHAR(32)`, campos de auditoria. |
| `merchant_delivery_requests` | Solicitações de coleta associadas a pedidos. | `id UUID PK`, `tenant_id UUID FK`, `branch_id UUID NULL FK`, `order_id UUID FK`, `pickup_address_id UUID FK`, `delivery_address_id UUID FK`, `requested_pickup_at TIMESTAMPTZ NULL`, `package_count INTEGER`, `declared_value_brl NUMERIC(18,4)`, `status VARCHAR(40)`, `courier_assignment_id UUID NULL FK`, campos de auditoria. |

### 2.4 PostgreSQL - Grupo Usuário / APK Android
Escopo: visibilidade dos módulos MVP, cadastro e edição limitada de perfil, finanças, compras, favoritos, Stock, Marketplace, agendamentos, checkout, suporte e operações do usuário final.

| Tabela | Responsabilidade | Campos e formatos |
|---|---|---|
| `customer_profiles` | Perfil limitado do usuário final. | `id UUID PK`, `tenant_id UUID FK`, `user_id UUID FK UNIQUE`, `cpf VARCHAR(14) NULL`, `display_name VARCHAR(80)`, `birth_date DATE NULL`, `gender VARCHAR(32) NULL`, `profile_completion_percent NUMERIC(5,2)`, `marketing_opt_in BOOLEAN`, `status VARCHAR(32)`, `metadata JSONB`, campos de auditoria. |
| `customer_addresses` | Endereços de entrega, cobrança e favoritos. | `id UUID PK`, `tenant_id UUID FK`, `user_id UUID FK`, `address_type VARCHAR(32)`, `label VARCHAR(80) NULL`, `recipient_name VARCHAR(160)`, `postal_code VARCHAR(12)`, `street VARCHAR(160)`, `number VARCHAR(30)`, `complement VARCHAR(120) NULL`, `district VARCHAR(120)`, `city VARCHAR(120)`, `state CHAR(2)`, `country CHAR(2)`, `latitude NUMERIC(10,7) NULL`, `longitude NUMERIC(10,7) NULL`, `is_default BOOLEAN`, campos de auditoria. |
| `customer_module_preferences` | Módulos visíveis e ordem no APK. | `id UUID PK`, `tenant_id UUID FK`, `user_id UUID FK`, `module_id UUID FK`, `is_visible BOOLEAN`, `sort_order INTEGER`, `pinned BOOLEAN`, `last_opened_at TIMESTAMPTZ NULL`, campos de auditoria. |
| `customer_favorites` | Favoritos de produtos, empresas e serviços. | `id UUID PK`, `tenant_id UUID FK`, `user_id UUID FK`, `target_type VARCHAR(32)`, `target_id UUID`, `source_module VARCHAR(32)`, `notes TEXT NULL`, campos de auditoria. |
| `customer_carts` | Carrinhos Stock e Marketplace. | `id UUID PK`, `tenant_id UUID FK`, `user_id UUID FK`, `cart_type VARCHAR(32)`, `merchant_tenant_id UUID NULL FK`, `status VARCHAR(32)`, `expires_at TIMESTAMPTZ NULL`, `metadata JSONB`, campos de auditoria. |
| `customer_cart_items` | Itens de carrinho. | `id UUID PK`, `tenant_id UUID FK`, `cart_id UUID FK`, `product_id UUID NULL FK`, `service_id UUID NULL FK`, `quantity NUMERIC(18,4)`, `unit_price_brl NUMERIC(18,4)`, `shipping_estimate_brl NUMERIC(18,4) NULL`, `supplier_quote_payload JSONB NULL`, campos de auditoria. |
| `customer_checkout_sessions` | Checkout Stock e Marketplace. | `id UUID PK`, `tenant_id UUID FK`, `user_id UUID FK`, `cart_id UUID FK`, `checkout_type VARCHAR(32)`, `delivery_address_id UUID NULL FK`, `billing_address_id UUID NULL FK`, `subtotal_brl NUMERIC(18,4)`, `discount_brl NUMERIC(18,4)`, `shipping_brl NUMERIC(18,4)`, `fees_brl NUMERIC(18,4)`, `total_brl NUMERIC(18,4)`, `shipping_quote JSONB NULL`, `payment_intent_id UUID NULL`, `status VARCHAR(40)`, campos de auditoria. |
| `customer_order_access` | Permissão de visualização de compras e rastreio no perfil. | `id UUID PK`, `tenant_id UUID FK`, `user_id UUID FK`, `order_id UUID FK`, `access_scope VARCHAR(32)`, `can_track BOOLEAN`, `can_review BOOLEAN`, `visible_until TIMESTAMPTZ NULL`, campos de auditoria. |
| `customer_payment_methods` | Métodos de pagamento tokenizados. | `id UUID PK`, `tenant_id UUID FK`, `user_id UUID FK`, `method_type VARCHAR(32)`, `provider_code VARCHAR(60)`, `provider_token_ref TEXT`, `brand VARCHAR(40) NULL`, `last4 CHAR(4) NULL`, `holder_name VARCHAR(160) NULL`, `expires_month SMALLINT NULL`, `expires_year SMALLINT NULL`, `is_default BOOLEAN`, `status VARCHAR(32)`, campos de auditoria. |
| `finance_wallets` | Carteiras BRL, Pepitas e V-Coin. | `id UUID PK`, `tenant_id UUID FK`, `user_id UUID FK`, `wallet_type VARCHAR(32)`, `currency_code VARCHAR(16)`, `balance_brl NUMERIC(18,4)`, `balance_vcoin NUMERIC(18,8)`, `hold_amount_brl NUMERIC(18,4)`, `status VARCHAR(32)`, `opened_at TIMESTAMPTZ`, `closed_at TIMESTAMPTZ NULL`, campos de auditoria. |
| `finance_ledger_entries` | Ledger financeiro append-only. | `id UUID PK`, `tenant_id UUID FK`, `wallet_id UUID FK`, `user_id UUID FK`, `entry_type VARCHAR(40)`, `source_type VARCHAR(60)`, `source_id UUID NULL`, `direction VARCHAR(8)` (`debit`, `credit`), `amount_brl NUMERIC(18,4)`, `amount_vcoin NUMERIC(18,8)`, `balance_after_brl NUMERIC(18,4)`, `balance_after_vcoin NUMERIC(18,8)`, `idempotency_key VARCHAR(120) UNIQUE`, `immutable_hash TEXT`, `previous_hash TEXT NULL`, `metadata JSONB`, `created_at TIMESTAMPTZ`. |
| `customer_appointment_bookings` | Visão do usuário sobre agendamentos Marketplace. | `id UUID PK`, `tenant_id UUID FK`, `user_id UUID FK`, `merchant_appointment_id UUID FK`, `status VARCHAR(40)`, `customer_notes TEXT NULL`, `cancel_reason TEXT NULL`, `checked_in_at TIMESTAMPTZ NULL`, campos de auditoria. |
| `support_threads` | Threads de suporte Stock, Marketplace e Helena. | `id UUID PK`, `tenant_id UUID FK`, `user_id UUID FK`, `merchant_tenant_id UUID NULL FK`, `order_id UUID NULL FK`, `module_code VARCHAR(64)`, `channel VARCHAR(32)`, `subject VARCHAR(180)`, `priority VARCHAR(32)`, `status VARCHAR(32)`, `last_message_at TIMESTAMPTZ NULL`, campos de auditoria. |
| `customer_reviews` | Avaliações publicáveis de produtos, serviços e atendimento. | `id UUID PK`, `tenant_id UUID FK`, `user_id UUID FK`, `target_type VARCHAR(32)`, `target_id UUID`, `order_id UUID NULL FK`, `rating SMALLINT CHECK (rating BETWEEN 1 AND 5)`, `comment TEXT NULL`, `is_public BOOLEAN`, `moderation_status VARCHAR(32)`, campos de auditoria. |
| `customer_notifications` | Notificações transacionais e operacionais. | `id UUID PK`, `tenant_id UUID FK`, `user_id UUID FK`, `notification_type VARCHAR(64)`, `title VARCHAR(140)`, `body TEXT`, `deep_link TEXT NULL`, `read_at TIMESTAMPTZ NULL`, `delivery_status VARCHAR(32)`, `metadata JSONB`, campos de auditoria. |
| `customer_consents` | Consentimentos LGPD, termos, marketing e módulos. | `id UUID PK`, `tenant_id UUID FK`, `user_id UUID FK`, `consent_type VARCHAR(64)`, `version VARCHAR(40)`, `accepted BOOLEAN`, `accepted_at TIMESTAMPTZ NULL`, `revoked_at TIMESTAMPTZ NULL`, `evidence JSONB`, campos de auditoria. |

### 2.5 PostgreSQL - Grupo Entregador
Escopo: cadastro do entregador, veículos, coletas, entregas, ocorrências, classificação privada do cliente, comissões, histórico e bloqueio de endereços.

| Tabela | Responsabilidade | Campos e formatos |
|---|---|---|
| `courier_profiles` | Perfil do entregador vinculado a `core_users`. | `id UUID PK`, `tenant_id UUID FK`, `user_id UUID FK UNIQUE`, `cpf VARCHAR(14)`, `cnh_number VARCHAR(40) NULL`, `cnh_category VARCHAR(8) NULL`, `cnh_expires_at DATE NULL`, `pix_key VARCHAR(160) NULL`, `service_radius_km NUMERIC(10,2)`, `rating_average NUMERIC(3,2)`, `status VARCHAR(32)`, `metadata JSONB`, campos de auditoria. |
| `courier_vehicles` | Cadastro de veículos. | `id UUID PK`, `tenant_id UUID FK`, `owner_user_id UUID FK`, `vehicle_type VARCHAR(32)`, `brand VARCHAR(80) NULL`, `model VARCHAR(80) NULL`, `year SMALLINT NULL`, `plate VARCHAR(12) NULL`, `color VARCHAR(40) NULL`, `renavam VARCHAR(40) NULL`, `document_status VARCHAR(32)`, `status VARCHAR(32)`, campos de auditoria. |
| `courier_vehicle_assignments` | Associação entregador-veículo. | `id UUID PK`, `tenant_id UUID FK`, `courier_user_id UUID FK`, `vehicle_id UUID FK`, `starts_at TIMESTAMPTZ`, `ends_at TIMESTAMPTZ NULL`, `is_primary BOOLEAN`, `status VARCHAR(32)`, campos de auditoria. |
| `courier_availability_sessions` | Janelas online/offline do entregador. | `id UUID PK`, `tenant_id UUID FK`, `courier_user_id UUID FK`, `vehicle_id UUID NULL FK`, `started_at TIMESTAMPTZ`, `ended_at TIMESTAMPTZ NULL`, `last_latitude NUMERIC(10,7) NULL`, `last_longitude NUMERIC(10,7) NULL`, `status VARCHAR(32)`, campos de auditoria. |
| `courier_pickup_requests` | Solicitações de coleta enviadas aos entregadores. | `id UUID PK`, `tenant_id UUID FK`, `merchant_tenant_id UUID FK`, `order_id UUID FK`, `pickup_address_id UUID FK`, `delivery_address_id UUID FK`, `offered_commission_brl NUMERIC(18,4)`, `distance_km NUMERIC(10,3) NULL`, `pickup_deadline_at TIMESTAMPTZ NULL`, `status VARCHAR(40)`, `metadata JSONB`, campos de auditoria. |
| `courier_assignments` | Aceite, coleta, rota e conclusão. | `id UUID PK`, `tenant_id UUID FK`, `pickup_request_id UUID FK`, `courier_user_id UUID FK`, `vehicle_id UUID NULL FK`, `accepted_at TIMESTAMPTZ NULL`, `collected_at TIMESTAMPTZ NULL`, `delivered_at TIMESTAMPTZ NULL`, `rejected_at TIMESTAMPTZ NULL`, `current_status VARCHAR(40)`, `proof_required BOOLEAN`, `metadata JSONB`, campos de auditoria. |
| `courier_delivery_status_events` | Eventos append-only de status. | `id UUID PK`, `tenant_id UUID FK`, `assignment_id UUID FK`, `courier_user_id UUID FK`, `status_code VARCHAR(40)`, `status_label VARCHAR(120)`, `latitude NUMERIC(10,7) NULL`, `longitude NUMERIC(10,7) NULL`, `occurred_at TIMESTAMPTZ`, `notes TEXT NULL`, `created_at TIMESTAMPTZ`, `immutable_hash TEXT`. |
| `courier_delivery_incidents` | Ocorrências obrigatórias quando o pedido não for entregue. | `id UUID PK`, `tenant_id UUID FK`, `assignment_id UUID FK`, `courier_user_id UUID FK`, `incident_type VARCHAR(60)` (`pedido_recusado`, `endereco_nao_localizado`, `pedido_divergente`, `cliente_ausente`, `avaria`, `outro`), `description TEXT NOT NULL`, `evidence_urls TEXT[] NULL`, `reported_at TIMESTAMPTZ`, `review_status VARCHAR(32)`, `reviewed_by UUID NULL FK`, campos de auditoria. |
| `courier_customer_private_ratings` | Classificação privada do cliente feita pelo entregador. | `id UUID PK`, `tenant_id UUID FK`, `merchant_tenant_id UUID FK`, `assignment_id UUID FK`, `courier_user_id UUID FK`, `customer_user_id UUID FK`, `rating SMALLINT CHECK (rating BETWEEN 1 AND 5)`, `comment TEXT NULL`, `comment_required BOOLEAN GENERATED ALWAYS AS (rating < 4) STORED`, `visibility_scope VARCHAR(40)` (`admin_and_assigned_merchant`), `review_status VARCHAR(32)`, `CHECK (rating >= 4 OR NULLIF(BTRIM(comment), '') IS NOT NULL)`, campos de auditoria. |
| `courier_commissions` | Comissões por entrega, bônus e ajustes. | `id UUID PK`, `tenant_id UUID FK`, `courier_user_id UUID FK`, `assignment_id UUID NULL FK`, `commission_type VARCHAR(40)`, `gross_amount_brl NUMERIC(18,4)`, `discount_amount_brl NUMERIC(18,4)`, `net_amount_brl NUMERIC(18,4)`, `status VARCHAR(32)`, `available_at TIMESTAMPTZ NULL`, `immutable_hash TEXT`, campos de auditoria. |
| `courier_payouts` | Repasses financeiros ao entregador. | `id UUID PK`, `tenant_id UUID FK`, `courier_user_id UUID FK`, `wallet_id UUID FK`, `period_start DATE`, `period_end DATE`, `amount_brl NUMERIC(18,4)`, `provider_code VARCHAR(60) NULL`, `provider_transfer_id TEXT NULL`, `paid_at TIMESTAMPTZ NULL`, `status VARCHAR(32)`, campos de auditoria. |
| `courier_blocked_addresses` | Endereços bloqueados pelo entregador para recusa preventiva. | `id UUID PK`, `tenant_id UUID FK`, `courier_user_id UUID FK`, `address_hash TEXT`, `address_snapshot JSONB`, `reason VARCHAR(80)`, `notes TEXT NULL`, `expires_at TIMESTAMPTZ NULL`, `status VARCHAR(32)`, campos de auditoria. |
| `courier_delivery_history_snapshots` | Histórico consolidado para tela do entregador. | `id UUID PK`, `tenant_id UUID FK`, `courier_user_id UUID FK`, `assignment_id UUID FK`, `order_id UUID FK`, `merchant_tenant_id UUID FK`, `completed_status VARCHAR(40)`, `completed_at TIMESTAMPTZ`, `distance_km NUMERIC(10,3) NULL`, `commission_brl NUMERIC(18,4)`, `rating_received NUMERIC(3,2) NULL`, `snapshot JSONB`, campos de auditoria. |

### 2.6 MongoDB - Coleções de Alto Volume e Dados Semiestruturados
Coleções usam JSON Schema Validation. Campos monetários em documentos devem repetir o valor em centavos (`*_cents`) ou string decimal quando houver risco de precisão.

| Coleção | Responsabilidade | Campos e formatos |
|---|---|---|
| `helena_memory_profiles` | Memória, preferências e contexto da Helena por usuário. | `_id ObjectId`, `tenant_id UUID/string`, `user_id UUID/string`, `profile_scope string`, `regional_voice string`, `preferences object`, `module_preferences object`, `embedding_refs array<string>`, `privacy_level string`, `updated_at date`, `schema_version int`. |
| `helena_conversation_logs` | Conversas da Helena por módulo e sessão. | `_id ObjectId`, `tenant_id UUID/string`, `user_id UUID/string`, `thread_id UUID/string`, `module_code string`, `messages array<object>` com `sender`, `text`, `attachments`, `created_at`, `tool_calls`; `summary string`, `sentiment object`, `retention_until date`, `created_at date`, `schema_version int`. |
| `support_chat_messages` | Mensagens dos chats Stock, Marketplace e suporte técnico. | `_id ObjectId`, `tenant_id UUID/string`, `support_thread_id UUID/string`, `sender_user_id UUID/string`, `sender_type string`, `message_type string`, `body string`, `attachments array<object>`, `moderation_status string`, `read_by array<object>`, `created_at date`, `schema_version int`. |
| `admin_api_request_logs` | Logs de APIs, webhooks e integrações. | `_id ObjectId`, `tenant_id UUID/string`, `client_id UUID/string`, `provider_code string`, `module_code string`, `method string`, `path string`, `status_code int`, `latency_ms int`, `request_hash string`, `response_hash string`, `error object`, `created_at date`, `schema_version int`. |
| `social_videos` | Metadados de vídeos, feed social e conteúdos promocionais. | `_id ObjectId`, `tenant_id UUID/string`, `creator_user_id UUID/string`, `merchant_tenant_id UUID/string|null`, `video_url string`, `thumbnail_url string`, `caption string`, `hashtags array<string>`, `commission_links array<object>`, `visibility string`, `metrics object` (`likes`, `views`, `shares`, `saves`), `created_at date`, `schema_version int`. |
| `influencer_metrics` | Métricas de afiliados, campanhas e comissões sociais. | `_id ObjectId`, `tenant_id UUID/string`, `influencer_user_id UUID/string`, `campaign_id UUID/string`, `period_start date`, `period_end date`, `clicks int`, `views int`, `conversions int`, `gmv_cents long`, `commission_cents long`, `attribution object`, `created_at date`, `schema_version int`. |
| `delivery_telemetry_logs` | GPS e telemetria de entregadores em rota. | `_id ObjectId`, `tenant_id UUID/string`, `courier_user_id UUID/string`, `assignment_id UUID/string`, `vehicle_id UUID/string|null`, `location object` (`type: Point`, `coordinates: [lng, lat]`), `speed_kmh double|null`, `heading double|null`, `battery_percent int|null`, `network_status string|null`, `recorded_at date`, `schema_version int`. |
| `iot_security_events` | Eventos de sensores, segurança e dispositivos conectados. | `_id ObjectId`, `tenant_id UUID/string`, `branch_id UUID/string|null`, `device_id UUID/string`, `device_type string`, `event_type string`, `severity string`, `payload object`, `location object|null`, `recorded_at date`, `schema_version int`. |
| `module_event_logs` | Eventos de navegação, UX, módulos MVP e feature flags. | `_id ObjectId`, `tenant_id UUID/string`, `user_id UUID/string|null`, `session_id UUID/string`, `module_code string`, `event_name string`, `event_payload object`, `app_surface string`, `app_version string`, `created_at date`, `schema_version int`. |

### 2.7 Regras de Integridade e Visibilidade
1. Todo pedido deve possuir `customer_user_id`, `tenant_id`, status financeiro e status logístico rastreáveis.
2. Todo checkout Stock ou Marketplace deve persistir endereço de entrega escolhido, cotação de frete e breakdown de valores.
3. Toda comissão de entregador deve nascer de `courier_assignments` ou ajuste administrativo auditado.
4. Toda classificação de cliente feita por entregador com menos de 4 estrelas exige comentário e fica privada para Administração Valley e lojista associado ao pedido.
5. Nenhum token de API, senha, chave ou segredo pode ser armazenado em texto puro; persistir apenas hash ou referência segura.
6. Toda ação Modo Deus deve criar `admin_god_mode_sessions` e `admin_audit_log` append-only.
7. As telas do APK devem consultar `admin_module_visibility_rules` e `customer_module_preferences` antes de exibir módulos MVP.

---

## 3. INTELIGÊNCIA PREDITIVA: HELENA
Helena é o núcleo de inteligência do Valley.
1. **Lógica de Importação (Stock):** Selecionar produtos de AliExpress (opção secundária), Alibaba, CJ, Amazon, Mercado Livre e Magalu.
2. **Meta de Preço:** Garantir preço 10% menor que o menor concorrente das grandes plataformas. Se não atingir, o produto não é postado.
3. **Personalização:** Sotaque regional automático; solicita e amistosa.
4. **Campanhas de Pepitas:** Interação contextual (ex: "Hum, cheirinho de pão de queijo! Gaste R$20 aqui e ganhe 3 Pepitas"). Sem pop-ups invasivos; Helena brilha na tela e interage.

---

## 4. MÓDULO DE MOBILIDADE & AGENTES OCIOSOS
Implementar agente autônomo para o bloco de Mobilidade:
- **Função:** Acompanhar trajetos de ônibus/metrô/Uber em tempo real em todo o Brasil.
- **Lógica:** Se Uber está caro, Helena sugere rota de transporte público + trecho final de Uber para economizar tempo e dinheiro, sabendo do compromisso do usuário.
- **Dinâmica:** Se houver acidente ou atraso, Helena recalcula a rota e avisa proativamente.
- **Agente de Verificação:** Criar agente para verificar se o módulo "Visio" já está implementado e disponível.

---

## 5. DESIGN SYSTEM & TEMPLATES (STITCH UI)

### TELA: HOME (001)
- **001.1 Cabeçalho:** Identidade Valley, busca global.
- **001.2 Rastreio Real-time:** Bloco flutuante (oculto se não houver entregas) para acompanhamento de pedidos Marketplace.
- **001.3 Banner Hero:** Promoção 100% personalizada via Helena (Módulo Stock) baseada em buscas do usuário.
- **001.4 Banners Secundários:** 50/50 lateral. Anúncios pagos de lojistas locais (Marketplace) com oferta de Pepitas.
- **001.5 Bloco Finanças:** Saldo Valley Pay (ocultável), Pepitas, V-Coin (com gráfico de volatilidade semanal) e soma de próximos pagamentos.
- **001.6 Favoritos/Carrinho:** Lista mista (Stock + Marketplace).
- **001.7 Rodapé:** Botões de Perfil, Suporte, FAQ e Navegação rápida.

### TELA: VALLEY ERP - LOGIN LOJISTA
- **Acesso Principal:** Login por e-mail/senha, telefone ou provedor autorizado, sempre resolvendo permissões em `core_user_identities`, `admin_user_roles` e `merchant_staff_profiles`.
- **Navegação de Acesso:** Botão **Cadastre-se** visível na tela `Valley - Login (PT-BR)`, iniciando `merchant_onboarding_applications`.
- **Segurança:** Bloqueio progressivo, MFA opcional por perfil e trilha em `admin_audit_log` para tentativas sensíveis.
- **Transição:** Após autenticação, direcionar para o dashboard ERP com tenant, filial e departamentos carregados do banco.

### TELA: VALLEY ERP - CADASTRO DE EMPRESA E USUÁRIOS
- **Dados da Empresa:** Captura CNPJ, razão social, nome fantasia, segmento, regime tributário, filiais e dados setoriais.
- **Representante Legal:** Vincula pessoa física responsável, CPF, documento, assinatura e status jurídico em `merchant_legal_representatives`.
- **Configuração de Admin:** Cria gestor principal com papel `Super Admin` via `admin_roles` e `admin_user_roles`.
- **Perfis e Convites:** Permite estruturar equipe inicial por departamentos como Comercial, Logística, Fiscal, Financeiro e Operação usando `merchant_departments` e `merchant_department_invites`.
- **Design:** Superfície sóbria, densa e operacional, sem composição promocional; deve preservar continuidade visual entre portal público e ambiente administrativo.

### TELA: STOCK (DROPSHIPPING)
- **Visual:** Grid de produtos "infinitos" via API Valley.
- **Filtros:** Categoria, Preço (sempre destacado como -10% vs mercado), Prazo de entrega.
- **Sandbox:** Área de simulação de lucro para o lojista (oculto do cliente).

### TELA: MARKETPLACE (LOJISTAS LOCAIS)
- **Visual:** Foco em proximidade e categoria de serviço/produto.
- **Destaque:** Selo de lojistas que oferecem Pepitas.
- **Filtros:** Bairro, Segmento, Avaliação.

### TELA: CHAT (COMMUNICATIONS HUB)
- **Canal 1:** Usuário <-> Valley (Dúvidas Stock).
- **Canal 2:** Usuário <-> Lojista Local (Dúvidas Marketplace).
- **Canal 3:** Usuário <-> Suporte Helena (Resolução de disputas/técnico).

### TELA: ÁREA DO CLIENTE (MY ACCOUNT)
- **Funções:** Meus pedidos, Rastreio detalhado, Gestão de Favoritos (produtos e empresas).
- **Avaliações:** Sistema de feedback para produtos e atendimento das empresas.
- **Finanças:** Exibir saldos, histórico permitido, compras, favoritos, checkouts Stock/Marketplace e agendamentos conforme `customer_module_preferences`.
- **Nota:** Módulo PAY transacional pode permanecer restrito por rodada; quando inativo, mostrar apenas saldos e histórico autorizado.

### TELA: ENTREGADOR (LOGÍSTICA)
- **Tema:** Telas do entregador devem usar temas verdes, com contraste alto, status de rota legíveis e comandos principais sempre acessíveis.
- **Cadastro:** Fluxo para dados pessoais, documentos, veículo, associação de veículo e raio de atendimento.
- **Coletas:** Lista de solicitações com comissão, distância, prazo, origem e destino; aceitar ou recusar deve gravar evento auditável.
- **Entrega:** Atualização de status para coletado, em rota, entregue, pedido recusado, endereço não localizado, pedido divergente e outras ocorrências.
- **Ocorrência Obrigatória:** Qualquer pedido não entregue exige relato manual em `courier_delivery_incidents`.
- **Classificação Privada:** Cliente recebe 1 a 5 estrelas; abaixo de 4 estrelas exige comentário, privado para Administração Valley e lojista do pedido.
- **Financeiro:** Tela de comissões, histórico de entregas, repasses e bloqueio de endereços para recusar novas solicitações.

---

## 6. COMPONENTES OBRIGATÓRIOS
- **Etiquetas:** Gerador de QR Code e EAN-13 para todos os produtos cadastrados.
- **Mapas:** Integração com APIs de geolocalização para o Mini Mapa de rastreio e rotas de mobilidade.
- **Offline PDV:** Capacidade de registrar vendas sem internet com sincronização posterior.

---
**FINAL DA ESPECIFICAÇÃO - EXECUÇÃO IMEDIATA RECOMENDADA.**
