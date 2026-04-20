-- Valley Hybrid DB Bootstrap - Implantacao v47 viavel: tabelas de dominio.
-- Este arquivo adapta tabelas dos PDFs v47 para public.users, public.wallets, orders e transactions.
-- Nao cria schemas legacy como memory, fintech, chat ou business; preserva core-first.
-- Execute depois de 001, 002 e 004.

BEGIN;

SET search_path = public;

CREATE TYPE insight_category_enum AS ENUM ('ENERGY', 'FINANCE', 'HEALTH', 'MOBILITY');
CREATE TYPE financial_goal_status_enum AS ENUM ('ACTIVE', 'PAUSED', 'ACHIEVED', 'CANCELLED');
CREATE TYPE teletherapy_session_status_enum AS ENUM ('SCHEDULED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED');
CREATE TYPE creator_upload_status_enum AS ENUM ('PENDING', 'PROCESSING', 'ACTIVE', 'DISABLED', 'FAILED');
CREATE TYPE chat_persona_enum AS ENUM ('PERSONAL', 'PROFESSIONAL');

CREATE TABLE advisor_insights (
    insight_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    insight_category insight_category_enum NOT NULL,
    suggested_action TEXT NOT NULL,
    potential_savings_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    is_executed BOOLEAN NOT NULL DEFAULT FALSE,
    consent_required BOOLEAN NOT NULL DEFAULT TRUE,
    execution_consented_at TIMESTAMPTZ,
    source_module TEXT NOT NULL DEFAULT 'ADVISOR',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_advisor_insights_user
        FOREIGN KEY (user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT chk_advisor_insights_action CHECK (btrim(suggested_action) <> ''),
    CONSTRAINT chk_advisor_insights_savings CHECK (potential_savings_brl >= 0),
    CONSTRAINT chk_advisor_insights_consent CHECK (
        execution_consented_at IS NULL OR consent_required = TRUE
    ),
    CONSTRAINT chk_advisor_insights_source_module CHECK (btrim(source_module) <> '')
);

CREATE TABLE financial_goals (
    goal_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    goal_name TEXT NOT NULL,
    target_amount_brl DECIMAL(18,4) NOT NULL,
    current_amount_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    auto_round_up BOOLEAN NOT NULL DEFAULT FALSE,
    goal_status financial_goal_status_enum NOT NULL DEFAULT 'ACTIVE',
    deadline TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_financial_goals_user
        FOREIGN KEY (user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT chk_financial_goals_name CHECK (btrim(goal_name) <> ''),
    CONSTRAINT chk_financial_goals_target CHECK (target_amount_brl > 0),
    CONSTRAINT chk_financial_goals_current CHECK (current_amount_brl >= 0),
    CONSTRAINT chk_financial_goals_current_limit CHECK (current_amount_brl <= target_amount_brl)
);

CREATE TABLE teletherapy_sessions (
    session_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id UUID NOT NULL,
    professional_id UUID NOT NULL,
    session_status teletherapy_session_status_enum NOT NULL DEFAULT 'SCHEDULED',
    encrypted_notes TEXT,
    notes_access_policy JSONB NOT NULL DEFAULT '{"requires_audit":true,"sensitive":true}'::JSONB,
    scheduled_at TIMESTAMPTZ NOT NULL,
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_teletherapy_sessions_patient
        FOREIGN KEY (patient_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_teletherapy_sessions_professional
        FOREIGN KEY (professional_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT chk_teletherapy_sessions_distinct_users CHECK (patient_id <> professional_id),
    CONSTRAINT chk_teletherapy_sessions_timeline CHECK (
        (started_at IS NULL OR started_at >= scheduled_at - INTERVAL '30 minutes')
        AND (completed_at IS NULL OR started_at IS NULL OR completed_at >= started_at)
    )
);

CREATE TABLE creator_uploads (
    upload_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    file_url TEXT NOT NULL,
    upload_status creator_upload_status_enum NOT NULL DEFAULT 'PENDING',
    monetization_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    social_video_id TEXT,
    checksum_sha256 TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_creator_uploads_user
        FOREIGN KEY (user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT chk_creator_uploads_file_url CHECK (btrim(file_url) <> ''),
    CONSTRAINT chk_creator_uploads_checksum CHECK (
        checksum_sha256 IS NULL OR checksum_sha256 ~ '^[a-fA-F0-9]{64}$'
    )
);

CREATE TABLE chat_conversations (
    conversation_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    participant1_id UUID NOT NULL,
    participant2_id UUID NOT NULL,
    deleted_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_chat_conversations_participant1
        FOREIGN KEY (participant1_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_chat_conversations_participant2
        FOREIGN KEY (participant2_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT chk_chat_conversations_distinct CHECK (participant1_id <> participant2_id)
);

CREATE TABLE chat_messages (
    message_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL,
    sender_id UUID NOT NULL,
    persona chat_persona_enum NOT NULL DEFAULT 'PERSONAL',
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_chat_messages_conversation
        FOREIGN KEY (conversation_id) REFERENCES chat_conversations (conversation_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_chat_messages_sender
        FOREIGN KEY (sender_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT chk_chat_messages_content CHECK (btrim(content) <> '')
);

CREATE TABLE business_invoices (
    invoice_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_user_id UUID NOT NULL,
    order_id UUID,
    transaction_id UUID,
    invoice_number TEXT,
    total_amount_brl DECIMAL(18,4) NOT NULL,
    due_date TIMESTAMPTZ,
    issued_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_business_invoices_business_user
        FOREIGN KEY (business_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_business_invoices_order
        FOREIGN KEY (order_id) REFERENCES orders (order_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_business_invoices_transaction
        FOREIGN KEY (transaction_id) REFERENCES transactions (transaction_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT chk_business_invoices_total CHECK (total_amount_brl > 0),
    CONSTRAINT chk_business_invoices_due_date CHECK (due_date IS NULL OR due_date >= issued_at)
);

CREATE TABLE business_payrolls (
    payroll_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_user_id UUID NOT NULL,
    period_start TIMESTAMPTZ NOT NULL,
    period_end TIMESTAMPTZ NOT NULL,
    total_paid_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    executed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_business_payrolls_business_user
        FOREIGN KEY (business_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT chk_business_payrolls_period CHECK (period_end > period_start),
    CONSTRAINT chk_business_payrolls_total CHECK (total_paid_brl >= 0)
);

CREATE TABLE plug_transactions (
    plug_transaction_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    transaction_id UUID UNIQUE,
    amount_brl DECIMAL(18,4) NOT NULL,
    mdr_rate DECIMAL(8,4) NOT NULL DEFAULT 0,
    settled_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_plug_transactions_user
        FOREIGN KEY (user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_plug_transactions_transaction
        FOREIGN KEY (transaction_id) REFERENCES transactions (transaction_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT chk_plug_transactions_amount CHECK (amount_brl > 0),
    CONSTRAINT chk_plug_transactions_mdr CHECK (mdr_rate >= 0 AND mdr_rate <= 1)
);

CREATE TABLE affiliate_referrals (
    referral_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    referrer_id UUID NOT NULL,
    order_id UUID,
    purchase_transaction_id UUID,
    commission_amount_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    payout_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_affiliate_referrals_referrer
        FOREIGN KEY (referrer_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_affiliate_referrals_order
        FOREIGN KEY (order_id) REFERENCES orders (order_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_affiliate_referrals_transaction
        FOREIGN KEY (purchase_transaction_id) REFERENCES transactions (transaction_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT chk_affiliate_referrals_commission CHECK (commission_amount_brl >= 0),
    CONSTRAINT chk_affiliate_referrals_reference CHECK (
        order_id IS NOT NULL OR purchase_transaction_id IS NOT NULL
    )
);

CREATE TABLE docs_receipts (
    receipt_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    order_id UUID,
    transaction_id UUID,
    document_id UUID,
    file_url TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_docs_receipts_user
        FOREIGN KEY (user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_docs_receipts_order
        FOREIGN KEY (order_id) REFERENCES orders (order_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_docs_receipts_transaction
        FOREIGN KEY (transaction_id) REFERENCES transactions (transaction_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_docs_receipts_document
        FOREIGN KEY (document_id) REFERENCES document_records (document_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT chk_docs_receipts_file_url CHECK (btrim(file_url) <> ''),
    CONSTRAINT chk_docs_receipts_reference CHECK (
        order_id IS NOT NULL OR transaction_id IS NOT NULL OR document_id IS NOT NULL
    )
);

CREATE INDEX ix_advisor_insights_user_category
    ON advisor_insights (user_id, insight_category, created_at);

CREATE INDEX ix_financial_goals_user_status
    ON financial_goals (user_id, goal_status);

CREATE INDEX ix_teletherapy_sessions_patient_schedule
    ON teletherapy_sessions (patient_id, scheduled_at);

CREATE INDEX ix_creator_uploads_user_status
    ON creator_uploads (user_id, upload_status, created_at);

CREATE INDEX ix_chat_conversations_participant1
    ON chat_conversations (participant1_id, created_at);

CREATE INDEX ix_chat_conversations_participant2
    ON chat_conversations (participant2_id, created_at);

CREATE INDEX ix_chat_messages_conversation_time
    ON chat_messages (conversation_id, created_at);

CREATE INDEX ix_business_invoices_business_user
    ON business_invoices (business_user_id, issued_at);

CREATE INDEX ix_business_payrolls_business_period
    ON business_payrolls (business_user_id, period_start, period_end);

CREATE INDEX ix_plug_transactions_user_created_at
    ON plug_transactions (user_id, created_at);

CREATE INDEX ix_affiliate_referrals_referrer_created_at
    ON affiliate_referrals (referrer_id, created_at);

CREATE INDEX ix_docs_receipts_user_created_at
    ON docs_receipts (user_id, created_at);

CREATE TRIGGER trg_advisor_insights_set_updated_at
BEFORE UPDATE ON advisor_insights
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_financial_goals_set_updated_at
BEFORE UPDATE ON financial_goals
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_teletherapy_sessions_set_updated_at
BEFORE UPDATE ON teletherapy_sessions
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_creator_uploads_set_updated_at
BEFORE UPDATE ON creator_uploads
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_business_invoices_set_updated_at
BEFORE UPDATE ON business_invoices
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_business_payrolls_set_updated_at
BEFORE UPDATE ON business_payrolls
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_plug_transactions_prevent_update
BEFORE UPDATE ON plug_transactions
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

CREATE TRIGGER trg_plug_transactions_prevent_delete
BEFORE DELETE ON plug_transactions
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

CREATE TRIGGER trg_affiliate_referrals_prevent_update
BEFORE UPDATE ON affiliate_referrals
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

CREATE TRIGGER trg_affiliate_referrals_prevent_delete
BEFORE DELETE ON affiliate_referrals
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

CREATE TRIGGER trg_docs_receipts_prevent_update
BEFORE UPDATE ON docs_receipts
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

CREATE TRIGGER trg_docs_receipts_prevent_delete
BEFORE DELETE ON docs_receipts
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

COMMENT ON TYPE insight_category_enum IS 'Categorias de insights do Advisor adaptadas do schema memory.';
COMMENT ON TYPE financial_goal_status_enum IS 'Status de meta financeira no modulo Finance.';
COMMENT ON TYPE teletherapy_session_status_enum IS 'Status de sessao de teleterapia ou telepsiquiatria.';
COMMENT ON TYPE creator_upload_status_enum IS 'Status de upload de midia do Creator/Media.';
COMMENT ON TYPE chat_persona_enum IS 'Persona usada em mensagens pessoais ou profissionais.';

COMMENT ON TABLE advisor_insights IS 'Recomendacoes do Advisor ligadas ao usuario e consentimento de execucao.';
COMMENT ON TABLE financial_goals IS 'Metas financeiras de PF/PJ com valores BRL e auto round-up.';
COMMENT ON TABLE teletherapy_sessions IS 'Agenda de teleterapia com notas cifradas e politica de acesso sensivel.';
COMMENT ON TABLE creator_uploads IS 'Uploads de conteudo do Creator/Media com status de processamento.';
COMMENT ON TABLE chat_conversations IS 'Conversas entre dois usuarios com soft delete por deleted_at.';
COMMENT ON TABLE chat_messages IS 'Mensagens de conversa com persona pessoal ou profissional.';
COMMENT ON TABLE business_invoices IS 'Notas fiscais/faturas emitidas por PJ e integradas a order/transaction.';
COMMENT ON TABLE business_payrolls IS 'Execucoes de folha de pagamento para usuarios PJ.';
COMMENT ON TABLE plug_transactions IS 'Transacoes presenciais Valley Plug integradas ao ledger financeiro.';
COMMENT ON TABLE affiliate_referrals IS 'Comissoes de afiliados Valley Up ligadas a order ou transaction.';
COMMENT ON TABLE docs_receipts IS 'Comprovantes gerados pelo Valley Docs para order, transaction ou document.';

COMMIT;
