-- Base RBAC do ERP Lojista Valley.
-- A migration e aditiva: o administrador lojista gerencia usuarios, papeis e privilegios
-- sem remover a compatibilidade com merchant_erp_staff_members.permissions_json.

BEGIN;

SET search_path = public;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'merchant_erp_privilege_grant_mode_enum') THEN
        CREATE TYPE merchant_erp_privilege_grant_mode_enum AS ENUM (
            'ALLOW',
            'DENY'
        );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'merchant_erp_privilege_event_type_enum') THEN
        CREATE TYPE merchant_erp_privilege_event_type_enum AS ENUM (
            'ROLE_PROFILE_CREATED',
            'ROLE_PROFILE_UPDATED',
            'STAFF_PRIVILEGE_GRANTED',
            'STAFF_PRIVILEGE_REVOKED',
            'STAFF_ROLE_CHANGED',
            'ACCESS_REVIEWED',
            'OFFLINE_LIMIT_CHANGED'
        );
    END IF;
END
$$;

CREATE TABLE IF NOT EXISTS merchant_erp_privileges (
    merchant_erp_privilege_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    privilege_code TEXT NOT NULL,
    workspace_code merchant_erp_workspace_code_enum,
    privilege_name TEXT NOT NULL,
    privilege_description TEXT NOT NULL,
    offline_allowed BOOLEAN NOT NULL DEFAULT FALSE,
    sensitive BOOLEAN NOT NULL DEFAULT FALSE,
    default_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    constraints_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT ux_merchant_erp_privileges_code UNIQUE (privilege_code),
    CONSTRAINT chk_merchant_erp_privileges_code CHECK (privilege_code ~ '^[a-z0-9_.:-]{3,120}$'),
    CONSTRAINT chk_merchant_erp_privileges_name CHECK (btrim(privilege_name) <> ''),
    CONSTRAINT chk_merchant_erp_privileges_desc CHECK (btrim(privilege_description) <> ''),
    CONSTRAINT chk_merchant_erp_privileges_constraints CHECK (jsonb_typeof(constraints_json) = 'object')
);

CREATE TABLE IF NOT EXISTS merchant_erp_role_profiles (
    merchant_erp_role_profile_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_user_id UUID,
    role_code merchant_erp_role_enum NOT NULL,
    profile_key TEXT NOT NULL,
    profile_name TEXT NOT NULL,
    profile_description TEXT NOT NULL,
    managed_by_user_id UUID,
    is_system_template BOOLEAN NOT NULL DEFAULT FALSE,
    profile_status merchant_erp_status_enum NOT NULL DEFAULT 'ACTIVE',
    constraints_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_merchant_erp_role_profiles_merchant
        FOREIGN KEY (merchant_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT fk_merchant_erp_role_profiles_manager
        FOREIGN KEY (managed_by_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT chk_merchant_erp_role_profiles_key CHECK (profile_key ~ '^[a-z0-9_-]{3,80}$'),
    CONSTRAINT chk_merchant_erp_role_profiles_name CHECK (btrim(profile_name) <> ''),
    CONSTRAINT chk_merchant_erp_role_profiles_desc CHECK (btrim(profile_description) <> ''),
    CONSTRAINT chk_merchant_erp_role_profiles_constraints CHECK (jsonb_typeof(constraints_json) = 'object')
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_merchant_erp_role_profiles_scope_key
    ON merchant_erp_role_profiles (COALESCE(merchant_user_id, '00000000-0000-0000-0000-000000000000'::UUID), profile_key);

CREATE TABLE IF NOT EXISTS merchant_erp_role_profile_privileges (
    merchant_erp_role_profile_privilege_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    role_profile_id UUID NOT NULL,
    privilege_id UUID NOT NULL,
    grant_mode merchant_erp_privilege_grant_mode_enum NOT NULL DEFAULT 'ALLOW',
    can_use BOOLEAN NOT NULL DEFAULT TRUE,
    can_approve BOOLEAN NOT NULL DEFAULT FALSE,
    can_manage BOOLEAN NOT NULL DEFAULT FALSE,
    constraints_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_merchant_erp_role_privileges_profile
        FOREIGN KEY (role_profile_id) REFERENCES merchant_erp_role_profiles (merchant_erp_role_profile_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT fk_merchant_erp_role_privileges_privilege
        FOREIGN KEY (privilege_id) REFERENCES merchant_erp_privileges (merchant_erp_privilege_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT ux_merchant_erp_role_privileges UNIQUE (role_profile_id, privilege_id),
    CONSTRAINT chk_merchant_erp_role_privileges_any CHECK (can_use OR can_approve OR can_manage),
    CONSTRAINT chk_merchant_erp_role_privileges_constraints CHECK (jsonb_typeof(constraints_json) = 'object')
);

CREATE TABLE IF NOT EXISTS merchant_erp_staff_privilege_grants (
    merchant_erp_staff_privilege_grant_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_user_id UUID NOT NULL,
    staff_member_id UUID NOT NULL,
    privilege_id UUID NOT NULL,
    granted_by_user_id UUID NOT NULL,
    grant_mode merchant_erp_privilege_grant_mode_enum NOT NULL DEFAULT 'ALLOW',
    can_use BOOLEAN NOT NULL DEFAULT TRUE,
    can_approve BOOLEAN NOT NULL DEFAULT FALSE,
    can_manage BOOLEAN NOT NULL DEFAULT FALSE,
    valid_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    valid_until TIMESTAMPTZ,
    grant_reason TEXT NOT NULL DEFAULT 'Ajuste de privilegio pelo administrador lojista.',
    constraints_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_merchant_erp_staff_grants_merchant
        FOREIGN KEY (merchant_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_merchant_erp_staff_grants_staff
        FOREIGN KEY (staff_member_id) REFERENCES merchant_erp_staff_members (merchant_erp_staff_member_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT fk_merchant_erp_staff_grants_privilege
        FOREIGN KEY (privilege_id) REFERENCES merchant_erp_privileges (merchant_erp_privilege_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_merchant_erp_staff_grants_granted_by
        FOREIGN KEY (granted_by_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT ux_merchant_erp_staff_privilege_active UNIQUE (merchant_user_id, staff_member_id, privilege_id),
    CONSTRAINT chk_merchant_erp_staff_grants_any CHECK (can_use OR can_approve OR can_manage),
    CONSTRAINT chk_merchant_erp_staff_grants_window CHECK (valid_until IS NULL OR valid_until > valid_from),
    CONSTRAINT chk_merchant_erp_staff_grants_reason CHECK (btrim(grant_reason) <> ''),
    CONSTRAINT chk_merchant_erp_staff_grants_constraints CHECK (jsonb_typeof(constraints_json) = 'object')
);

CREATE TABLE IF NOT EXISTS merchant_erp_privilege_audit_events (
    merchant_erp_privilege_audit_event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_user_id UUID NOT NULL,
    actor_user_id UUID NOT NULL,
    target_staff_member_id UUID,
    target_user_id UUID,
    privilege_id UUID,
    role_profile_id UUID,
    event_type merchant_erp_privilege_event_type_enum NOT NULL,
    event_summary TEXT NOT NULL,
    before_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    after_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_merchant_erp_priv_audit_merchant
        FOREIGN KEY (merchant_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_merchant_erp_priv_audit_actor
        FOREIGN KEY (actor_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_merchant_erp_priv_audit_staff
        FOREIGN KEY (target_staff_member_id) REFERENCES merchant_erp_staff_members (merchant_erp_staff_member_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_merchant_erp_priv_audit_target_user
        FOREIGN KEY (target_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_merchant_erp_priv_audit_privilege
        FOREIGN KEY (privilege_id) REFERENCES merchant_erp_privileges (merchant_erp_privilege_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_merchant_erp_priv_audit_role_profile
        FOREIGN KEY (role_profile_id) REFERENCES merchant_erp_role_profiles (merchant_erp_role_profile_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT chk_merchant_erp_priv_audit_summary CHECK (btrim(event_summary) <> ''),
    CONSTRAINT chk_merchant_erp_priv_audit_before CHECK (jsonb_typeof(before_json) = 'object'),
    CONSTRAINT chk_merchant_erp_priv_audit_after CHECK (jsonb_typeof(after_json) = 'object'),
    CONSTRAINT chk_merchant_erp_priv_audit_metadata CHECK (jsonb_typeof(metadata_json) = 'object')
);

CREATE INDEX IF NOT EXISTS ix_merchant_erp_privileges_workspace
    ON merchant_erp_privileges (workspace_code, sensitive, offline_allowed);

CREATE INDEX IF NOT EXISTS ix_merchant_erp_role_profiles_merchant
    ON merchant_erp_role_profiles (merchant_user_id, role_code, profile_status);

CREATE INDEX IF NOT EXISTS ix_merchant_erp_staff_grants_staff
    ON merchant_erp_staff_privilege_grants (merchant_user_id, staff_member_id, grant_mode);

CREATE INDEX IF NOT EXISTS ix_merchant_erp_staff_grants_privilege
    ON merchant_erp_staff_privilege_grants (privilege_id, valid_from DESC);

CREATE INDEX IF NOT EXISTS ix_merchant_erp_priv_audit_time
    ON merchant_erp_privilege_audit_events (merchant_user_id, occurred_at DESC, event_type);

CREATE OR REPLACE FUNCTION assert_merchant_erp_staff_grant_scope()
RETURNS TRIGGER AS $$
DECLARE
    staff_merchant_user_id UUID;
    manager_role merchant_erp_role_enum;
BEGIN
    SELECT staff.merchant_user_id
      INTO staff_merchant_user_id
      FROM merchant_erp_staff_members staff
     WHERE staff.merchant_erp_staff_member_id = NEW.staff_member_id;

    IF staff_merchant_user_id IS NULL OR staff_merchant_user_id <> NEW.merchant_user_id THEN
        RAISE EXCEPTION 'merchant_erp_staff_privilege_grants precisa usar staff_member do mesmo lojista';
    END IF;

    SELECT staff.role_code
      INTO manager_role
      FROM merchant_erp_staff_members staff
     WHERE staff.merchant_user_id = NEW.merchant_user_id
       AND staff.staff_user_id = NEW.granted_by_user_id
       AND staff.member_status = 'ACTIVE'
     ORDER BY staff.updated_at DESC
     LIMIT 1;

    IF manager_role IS NULL OR manager_role NOT IN ('OWNER', 'ADMIN', 'MANAGER') THEN
        RAISE EXCEPTION 'apenas administrador lojista ativo pode conceder privilegios';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_merchant_erp_privileges_set_updated_at
BEFORE UPDATE ON merchant_erp_privileges
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_merchant_erp_role_profiles_set_updated_at
BEFORE UPDATE ON merchant_erp_role_profiles
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_merchant_erp_role_privileges_set_updated_at
BEFORE UPDATE ON merchant_erp_role_profile_privileges
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_merchant_erp_staff_grants_set_updated_at
BEFORE UPDATE ON merchant_erp_staff_privilege_grants
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_merchant_erp_staff_grants_scope
BEFORE INSERT OR UPDATE ON merchant_erp_staff_privilege_grants
FOR EACH ROW
EXECUTE FUNCTION assert_merchant_erp_staff_grant_scope();

CREATE TRIGGER trg_merchant_erp_priv_audit_prevent_update
BEFORE UPDATE ON merchant_erp_privilege_audit_events
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

CREATE TRIGGER trg_merchant_erp_priv_audit_prevent_delete
BEFORE DELETE ON merchant_erp_privilege_audit_events
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

INSERT INTO merchant_erp_privileges (
    privilege_code,
    workspace_code,
    privilege_name,
    privilege_description,
    offline_allowed,
    sensitive,
    default_enabled,
    constraints_json
)
VALUES
    ('erp.menu.open', 'ERP', 'Abrir menu ERP', 'Permite acessar o menu principal do ERP Lojista.', TRUE, FALSE, TRUE, '{"surface":"menu"}'),
    ('pdv.session.open', 'PDV', 'Abrir caixa', 'Permite abrir sessao de caixa no PDV autorizado.', TRUE, TRUE, FALSE, '{"requires_device_authorized":true}'),
    ('pdv.sale.create', 'PDV', 'Registrar venda', 'Permite criar venda local, inclusive offline quando autorizado.', TRUE, TRUE, FALSE, '{"offline_queue_required":true}'),
    ('pdv.sale.cancel', 'PDV', 'Cancelar venda', 'Permite cancelar venda dentro das regras do lojista.', TRUE, TRUE, FALSE, '{"manager_review_above_brl":500}'),
    ('pdv.cash.move', 'PDV', 'Movimentar caixa', 'Permite sangria, suprimento e ajuste de caixa.', TRUE, TRUE, FALSE, '{"audit_required":true}'),
    ('pdv.session.close', 'PDV', 'Fechar caixa', 'Permite fechamento de caixa com pendencias locais visiveis.', TRUE, TRUE, FALSE, '{"show_pending_sync":true}'),
    ('products.read', 'PRODUCTS', 'Consultar produtos', 'Permite consultar catalogo, SKU e precos.', TRUE, FALSE, TRUE, '{}'),
    ('products.write', 'PRODUCTS', 'Editar produtos', 'Permite criar e editar produtos, fotos, SKU e variacoes.', FALSE, TRUE, FALSE, '{}'),
    ('inventory.read', 'INVENTORY', 'Consultar estoque', 'Permite consultar saldos, reservas e estoque espelhado.', TRUE, FALSE, TRUE, '{}'),
    ('inventory.adjust', 'INVENTORY', 'Ajustar estoque', 'Permite baixa, transferencia, contagem e ajuste de estoque.', TRUE, TRUE, FALSE, '{"offline_conflict_review":true}'),
    ('orders.read', 'ORDERS', 'Consultar pedidos', 'Permite consultar pedidos e status de separacao.', TRUE, FALSE, TRUE, '{}'),
    ('orders.fulfill', 'ORDERS', 'Separar pedidos', 'Permite mover pedidos na fila de separacao e entrega.', TRUE, TRUE, FALSE, '{}'),
    ('finance.read', 'FINANCE', 'Consultar financeiro', 'Permite visualizar recebiveis, taxas e fechamentos.', FALSE, TRUE, FALSE, '{}'),
    ('finance.approve', 'FINANCE', 'Aprovar financeiro', 'Permite aprovar fechamento, repasse e conciliacao.', FALSE, TRUE, FALSE, '{"online_required":true}'),
    ('integrations.manage', 'INTEGRATIONS', 'Gerenciar integracoes', 'Permite configurar conectores, webhooks e sincronizacao.', FALSE, TRUE, FALSE, '{"online_required":true}'),
    ('reports.export', 'REPORTS', 'Exportar relatorios', 'Permite gerar e baixar relatorios operacionais.', FALSE, FALSE, FALSE, '{}'),
    ('team.manage', 'TEAM', 'Gerenciar equipe', 'Permite convidar, bloquear e alterar papeis da equipe.', FALSE, TRUE, FALSE, '{"owner_or_admin_required":true}'),
    ('security.manage', 'SECURITY', 'Gerenciar seguranca', 'Permite gerenciar MFA, sessoes, risco e auditoria.', FALSE, TRUE, FALSE, '{"owner_required_for_sensitive":true}'),
    ('settings.manage', 'SETTINGS', 'Gerenciar configuracoes', 'Permite alterar parametros da loja e preferencias.', FALSE, TRUE, FALSE, '{}')
ON CONFLICT (privilege_code) DO UPDATE
SET
    workspace_code = EXCLUDED.workspace_code,
    privilege_name = EXCLUDED.privilege_name,
    privilege_description = EXCLUDED.privilege_description,
    offline_allowed = EXCLUDED.offline_allowed,
    sensitive = EXCLUDED.sensitive,
    default_enabled = EXCLUDED.default_enabled,
    constraints_json = merchant_erp_privileges.constraints_json || EXCLUDED.constraints_json,
    updated_at = NOW();

INSERT INTO merchant_erp_role_profiles (
    merchant_user_id,
    role_code,
    profile_key,
    profile_name,
    profile_description,
    is_system_template,
    constraints_json
)
VALUES
    (NULL, 'OWNER', 'template-owner', 'Dono lojista', 'Acesso total ao ERP Lojista e gestao de equipe.', TRUE, '{"scope":"system"}'),
    (NULL, 'ADMIN', 'template-admin', 'Administrador lojista', 'Administra operacao, equipe e configuracoes sem alterar propriedade da loja.', TRUE, '{"scope":"system"}'),
    (NULL, 'MANAGER', 'template-manager', 'Gerente', 'Opera rotinas comerciais, estoque, pedidos e PDV com aprovacoes limitadas.', TRUE, '{"scope":"system"}'),
    (NULL, 'CASHIER', 'template-cashier', 'Operador de caixa', 'Usa PDV, venda, recibo e caixa com limites offline.', TRUE, '{"scope":"system"}'),
    (NULL, 'WAREHOUSE', 'template-warehouse', 'Operador de estoque', 'Gerencia separacao, inventario e movimentacoes de estoque.', TRUE, '{"scope":"system"}'),
    (NULL, 'ACCOUNTANT', 'template-accountant', 'Contabil financeiro', 'Consulta financeiro, fiscal e relatorios sem operar PDV.', TRUE, '{"scope":"system"}'),
    (NULL, 'SUPPORT', 'template-support', 'Atendimento', 'Acompanha pedidos, clientes e suporte ao comprador.', TRUE, '{"scope":"system"}'),
    (NULL, 'VIEWER', 'template-viewer', 'Leitura', 'Acesso somente leitura para acompanhamento operacional.', TRUE, '{"scope":"system"}')
ON CONFLICT ((COALESCE(merchant_user_id, '00000000-0000-0000-0000-000000000000'::UUID)), profile_key) DO UPDATE
SET
    role_code = EXCLUDED.role_code,
    profile_name = EXCLUDED.profile_name,
    profile_description = EXCLUDED.profile_description,
    is_system_template = EXCLUDED.is_system_template,
    constraints_json = merchant_erp_role_profiles.constraints_json || EXCLUDED.constraints_json,
    updated_at = NOW();

INSERT INTO merchant_erp_role_profile_privileges (
    role_profile_id,
    privilege_id,
    grant_mode,
    can_use,
    can_approve,
    can_manage,
    constraints_json
)
SELECT
    role_profile.merchant_erp_role_profile_id,
    privilege.merchant_erp_privilege_id,
    'ALLOW',
    TRUE,
    role_profile.role_code IN ('OWNER', 'ADMIN', 'MANAGER') AND privilege.sensitive,
    role_profile.role_code IN ('OWNER', 'ADMIN') AND privilege.privilege_code IN ('team.manage', 'security.manage', 'settings.manage'),
    jsonb_build_object('source', '038_v47_merchant_erp_privileges_rbac')
FROM merchant_erp_role_profiles role_profile
JOIN merchant_erp_privileges privilege
  ON role_profile.is_system_template
 AND (
    role_profile.role_code IN ('OWNER', 'ADMIN')
    OR (role_profile.role_code = 'MANAGER' AND privilege.privilege_code IN (
        'erp.menu.open', 'pdv.session.open', 'pdv.sale.create', 'pdv.sale.cancel',
        'pdv.cash.move', 'pdv.session.close', 'products.read', 'products.write',
        'inventory.read', 'inventory.adjust', 'orders.read', 'orders.fulfill',
        'reports.export'
    ))
    OR (role_profile.role_code = 'CASHIER' AND privilege.privilege_code IN (
        'erp.menu.open', 'pdv.session.open', 'pdv.sale.create', 'pdv.cash.move',
        'pdv.session.close', 'products.read', 'inventory.read', 'orders.read'
    ))
    OR (role_profile.role_code = 'WAREHOUSE' AND privilege.privilege_code IN (
        'erp.menu.open', 'products.read', 'inventory.read', 'inventory.adjust',
        'orders.read', 'orders.fulfill'
    ))
    OR (role_profile.role_code = 'ACCOUNTANT' AND privilege.privilege_code IN (
        'erp.menu.open', 'finance.read', 'reports.export', 'orders.read'
    ))
    OR (role_profile.role_code = 'SUPPORT' AND privilege.privilege_code IN (
        'erp.menu.open', 'orders.read', 'orders.fulfill', 'products.read', 'inventory.read'
    ))
    OR (role_profile.role_code = 'VIEWER' AND privilege.default_enabled)
 )
ON CONFLICT (role_profile_id, privilege_id) DO UPDATE
SET
    grant_mode = EXCLUDED.grant_mode,
    can_use = EXCLUDED.can_use,
    can_approve = EXCLUDED.can_approve,
    can_manage = EXCLUDED.can_manage,
    constraints_json = merchant_erp_role_profile_privileges.constraints_json || EXCLUDED.constraints_json,
    updated_at = NOW();

INSERT INTO merchant_erp_role_profiles (
    merchant_user_id,
    role_code,
    profile_key,
    profile_name,
    profile_description,
    managed_by_user_id,
    is_system_template,
    constraints_json
)
SELECT
    staff.merchant_user_id,
    staff.role_code,
    'default-' || lower(staff.role_code::TEXT),
    'Padrao ' || staff.role_code::TEXT,
    'Perfil padrao gerenciado pelo administrador lojista.',
    staff.staff_user_id,
    FALSE,
    jsonb_build_object('source', '038_v47_merchant_erp_privileges_rbac')
FROM merchant_erp_staff_members staff
WHERE staff.role_code IN ('OWNER', 'ADMIN')
  AND staff.member_status = 'ACTIVE'
ON CONFLICT ((COALESCE(merchant_user_id, '00000000-0000-0000-0000-000000000000'::UUID)), profile_key) DO UPDATE
SET
    role_code = EXCLUDED.role_code,
    profile_name = EXCLUDED.profile_name,
    profile_description = EXCLUDED.profile_description,
    managed_by_user_id = EXCLUDED.managed_by_user_id,
    constraints_json = merchant_erp_role_profiles.constraints_json || EXCLUDED.constraints_json,
    updated_at = NOW();

CREATE OR REPLACE VIEW v_merchant_erp_staff_effective_privileges AS
SELECT
    staff.merchant_user_id,
    staff.merchant_erp_staff_member_id,
    staff.staff_user_id,
    staff.role_code,
    privilege.privilege_code,
    privilege.workspace_code,
    privilege.privilege_name,
    privilege.offline_allowed,
    privilege.sensitive,
    COALESCE(direct_grant.grant_mode, role_privilege.grant_mode, 'DENY'::merchant_erp_privilege_grant_mode_enum) AS grant_mode,
    COALESCE(direct_grant.can_use, role_privilege.can_use, FALSE) AS can_use,
    COALESCE(direct_grant.can_approve, role_privilege.can_approve, FALSE) AS can_approve,
    COALESCE(direct_grant.can_manage, role_privilege.can_manage, FALSE) AS can_manage,
    direct_grant.valid_until,
    GREATEST(staff.updated_at, COALESCE(direct_grant.updated_at, staff.updated_at), COALESCE(role_privilege.updated_at, staff.updated_at)) AS effective_updated_at
FROM merchant_erp_staff_members staff
CROSS JOIN merchant_erp_privileges privilege
LEFT JOIN merchant_erp_role_profiles role_profile
  ON role_profile.merchant_user_id IS NULL
 AND role_profile.is_system_template
 AND role_profile.role_code = staff.role_code
 AND role_profile.profile_status = 'ACTIVE'
LEFT JOIN merchant_erp_role_profile_privileges role_privilege
  ON role_privilege.role_profile_id = role_profile.merchant_erp_role_profile_id
 AND role_privilege.privilege_id = privilege.merchant_erp_privilege_id
LEFT JOIN merchant_erp_staff_privilege_grants direct_grant
  ON direct_grant.merchant_user_id = staff.merchant_user_id
 AND direct_grant.staff_member_id = staff.merchant_erp_staff_member_id
 AND direct_grant.privilege_id = privilege.merchant_erp_privilege_id
 AND (direct_grant.valid_until IS NULL OR direct_grant.valid_until > NOW())
WHERE staff.member_status = 'ACTIVE'
  AND COALESCE(direct_grant.grant_mode, role_privilege.grant_mode, 'DENY') = 'ALLOW'
  AND COALESCE(direct_grant.can_use, role_privilege.can_use, FALSE);

COMMENT ON TABLE merchant_erp_privileges IS 'Catalogo canonico de privilegios do ERP Lojista Valley, incluindo permissao offline e sensibilidade.';
COMMENT ON TABLE merchant_erp_role_profiles IS 'Perfis de papel do ERP Lojista, globais ou customizados por lojista.';
COMMENT ON TABLE merchant_erp_role_profile_privileges IS 'Privilegios concedidos por perfil de papel.';
COMMENT ON TABLE merchant_erp_staff_privilege_grants IS 'Concessoes diretas de privilegio para usuarios da equipe, gerenciadas pelo administrador lojista.';
COMMENT ON TABLE merchant_erp_privilege_audit_events IS 'Trilha append-only de alteracoes de privilegios e revisoes de acesso.';
COMMENT ON VIEW v_merchant_erp_staff_effective_privileges IS 'Visao efetiva de privilegios por usuario da equipe do lojista.';

COMMIT;
