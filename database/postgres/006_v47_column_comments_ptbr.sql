-- Valley Hybrid DB Bootstrap - Comentarios detalhados das implantacoes v47.
-- Este script documenta colunas criadas em 004 e 005 dentro do PostgreSQL.
-- A linguagem e portugues simples com termos tecnicos em ingles quando sao padroes.
-- Execute depois de 004_v47_control_plane_modules_rules.sql e 005_v47_domain_tables_core_first.sql.

BEGIN;

SET search_path = public;

COMMENT ON COLUMN module_catalog.module_id IS 'Primary key UUID do modulo no catalogo canonico v47.';
COMMENT ON COLUMN module_catalog.module_number IS 'Numero oficial do modulo conforme mapeamento v47.';
COMMENT ON COLUMN module_catalog.module_code IS 'Codigo tecnico estavel usado por regras, admin e integracoes.';
COMMENT ON COLUMN module_catalog.module_name IS 'Nome humano do modulo exibido em admin e documentacao.';
COMMENT ON COLUMN module_catalog.primary_audience IS 'Publico principal do modulo, normalmente PF, PJ ou Influencer.';
COMMENT ON COLUMN module_catalog.secondary_audience IS 'Publico secundario atendido pelo modulo.';
COMMENT ON COLUMN module_catalog.central_function IS 'Funcao central resumida do modulo.';
COMMENT ON COLUMN module_catalog.monetization_model IS 'Modelo de monetizacao previsto no PDF v47.';
COMMENT ON COLUMN module_catalog.is_active IS 'Flag operacional para habilitar ou pausar modulo no catalogo.';
COMMENT ON COLUMN module_catalog.source_document IS 'Documento de origem usado para popular o modulo.';
COMMENT ON COLUMN module_catalog.created_at IS 'Timestamp de criacao do modulo no catalogo.';
COMMENT ON COLUMN module_catalog.updated_at IS 'Timestamp de ultima atualizacao do modulo.';

COMMENT ON COLUMN admin_users.admin_id IS 'Primary key UUID do usuario interno do Web Admin.';
COMMENT ON COLUMN admin_users.user_id IS 'FK para users.user_id, mantendo identidade central unica.';
COMMENT ON COLUMN admin_users.username IS 'Login tecnico do admin, unico no painel.';
COMMENT ON COLUMN admin_users.password_hash IS 'Hash de senha; nunca armazena senha pura.';
COMMENT ON COLUMN admin_users.admin_role IS 'Papel RBAC principal do admin.';
COMMENT ON COLUMN admin_users.is_active IS 'Indica se o admin pode acessar o painel.';
COMMENT ON COLUMN admin_users.last_login_at IS 'Ultimo login do admin para auditoria e seguranca.';
COMMENT ON COLUMN admin_users.created_at IS 'Timestamp de criacao do admin.';
COMMENT ON COLUMN admin_users.updated_at IS 'Timestamp de ultima atualizacao do admin.';

COMMENT ON COLUMN admin_permissions.permission_id IS 'Primary key UUID da permissao modular.';
COMMENT ON COLUMN admin_permissions.admin_id IS 'FK para admin_users.admin_id.';
COMMENT ON COLUMN admin_permissions.module_code IS 'FK para module_catalog.module_code.';
COMMENT ON COLUMN admin_permissions.can_read IS 'Permite leitura do modulo no Web Admin.';
COMMENT ON COLUMN admin_permissions.can_write IS 'Permite escrita/edicao do modulo no Web Admin.';
COMMENT ON COLUMN admin_permissions.can_approve IS 'Permite aprovacao de regra, campanha ou acao critica.';
COMMENT ON COLUMN admin_permissions.constraints_json IS 'Regras ABAC adicionais em JSONB.';
COMMENT ON COLUMN admin_permissions.created_at IS 'Timestamp de criacao da permissao.';
COMMENT ON COLUMN admin_permissions.updated_at IS 'Timestamp de ultima atualizacao da permissao.';

COMMENT ON COLUMN business_rule_definitions.rule_id IS 'Primary key UUID da regra de negocio.';
COMMENT ON COLUMN business_rule_definitions.rule_code IS 'Codigo funcional estavel da regra, como BR-FIN-002.';
COMMENT ON COLUMN business_rule_definitions.module_code IS 'Modulo responsavel pela regra.';
COMMENT ON COLUMN business_rule_definitions.rule_name IS 'Nome curto da regra para admin e auditoria.';
COMMENT ON COLUMN business_rule_definitions.description IS 'Descricao simples da regra e finalidade.';
COMMENT ON COLUMN business_rule_definitions.severity IS 'Severidade da regra para risco e workflow de aprovacao.';
COMMENT ON COLUMN business_rule_definitions.rule_status IS 'Status atual da definicao da regra.';
COMMENT ON COLUMN business_rule_definitions.constraints_json IS 'Parametros tecnicos da regra em JSONB.';
COMMENT ON COLUMN business_rule_definitions.created_by_admin_id IS 'Admin que criou a regra, quando existir.';
COMMENT ON COLUMN business_rule_definitions.created_at IS 'Timestamp de criacao da regra.';
COMMENT ON COLUMN business_rule_definitions.updated_at IS 'Timestamp de ultima atualizacao da regra.';

COMMENT ON COLUMN business_rule_versions.rule_version_id IS 'Primary key UUID da versao da regra.';
COMMENT ON COLUMN business_rule_versions.rule_id IS 'FK para business_rule_definitions.rule_id.';
COMMENT ON COLUMN business_rule_versions.version_number IS 'Numero sequencial da versao da regra.';
COMMENT ON COLUMN business_rule_versions.definition_json IS 'Definicao executavel ou parametrizavel da regra.';
COMMENT ON COLUMN business_rule_versions.enabled IS 'Indica se a versao esta habilitada para uso.';
COMMENT ON COLUMN business_rule_versions.change_log IS 'Resumo humano da mudanca.';
COMMENT ON COLUMN business_rule_versions.approved_by_admin_id IS 'Admin aprovador da versao habilitada.';
COMMENT ON COLUMN business_rule_versions.approved_at IS 'Timestamp de aprovacao da versao.';
COMMENT ON COLUMN business_rule_versions.created_at IS 'Timestamp de criacao da versao.';

COMMENT ON COLUMN business_rule_audit.rule_audit_id IS 'Primary key UUID do evento de auditoria de regra.';
COMMENT ON COLUMN business_rule_audit.rule_id IS 'FK para regra auditada.';
COMMENT ON COLUMN business_rule_audit.rule_version_id IS 'FK opcional para versao auditada.';
COMMENT ON COLUMN business_rule_audit.audit_action IS 'Acao auditavel executada sobre a regra.';
COMMENT ON COLUMN business_rule_audit.performed_by_admin_id IS 'Admin que executou a acao.';
COMMENT ON COLUMN business_rule_audit.details_json IS 'Detalhes da acao em JSONB.';
COMMENT ON COLUMN business_rule_audit.performed_at IS 'Timestamp imutavel da acao.';

COMMENT ON COLUMN gamification_campaigns.campaign_id IS 'Primary key UUID da campanha de Loyalty/Gamification.';
COMMENT ON COLUMN gamification_campaigns.module_code IS 'Modulo dono da campanha.';
COMMENT ON COLUMN gamification_campaigns.campaign_name IS 'Nome da campanha.';
COMMENT ON COLUMN gamification_campaigns.description IS 'Descricao da campanha.';
COMMENT ON COLUMN gamification_campaigns.start_date IS 'Data inicial da campanha.';
COMMENT ON COLUMN gamification_campaigns.end_date IS 'Data final da campanha.';
COMMENT ON COLUMN gamification_campaigns.reward_type IS 'Tipo de recompensa: pontos, token, badge ou Pepita.';
COMMENT ON COLUMN gamification_campaigns.target_audience_json IS 'Segmentacao da campanha em JSONB.';
COMMENT ON COLUMN gamification_campaigns.approval_status IS 'Status de aprovacao e execucao.';
COMMENT ON COLUMN gamification_campaigns.created_by_admin_id IS 'Admin que criou a campanha.';
COMMENT ON COLUMN gamification_campaigns.created_at IS 'Timestamp de criacao da campanha.';
COMMENT ON COLUMN gamification_campaigns.updated_at IS 'Timestamp de ultima atualizacao da campanha.';

COMMENT ON COLUMN points_ledger.points_ledger_id IS 'Primary key UUID do lancamento de pontos.';
COMMENT ON COLUMN points_ledger.user_id IS 'FK para usuario que recebeu ou perdeu pontos.';
COMMENT ON COLUMN points_ledger.campaign_id IS 'FK opcional para campanha que gerou os pontos.';
COMMENT ON COLUMN points_ledger.points IS 'Quantidade de pontos; positivo concede, negativo estorna.';
COMMENT ON COLUMN points_ledger.reason IS 'Motivo humano do lancamento.';
COMMENT ON COLUMN points_ledger.granted_at IS 'Timestamp imutavel do lancamento.';
COMMENT ON COLUMN points_ledger.expires_at IS 'Expiracao opcional dos pontos.';

COMMENT ON COLUMN observability_incidents.incident_id IS 'Primary key UUID do incidente.';
COMMENT ON COLUMN observability_incidents.module_code IS 'Modulo afetado pelo incidente.';
COMMENT ON COLUMN observability_incidents.severity IS 'Severidade do incidente.';
COMMENT ON COLUMN observability_incidents.incident_status IS 'Status de tratamento do incidente.';
COMMENT ON COLUMN observability_incidents.description IS 'Descricao objetiva do incidente.';
COMMENT ON COLUMN observability_incidents.detected_at IS 'Timestamp de deteccao.';
COMMENT ON COLUMN observability_incidents.resolved_at IS 'Timestamp de resolucao.';
COMMENT ON COLUMN observability_incidents.runbook_reference IS 'Referencia do runbook operacional.';
COMMENT ON COLUMN observability_incidents.metadata_json IS 'Contexto tecnico adicional em JSONB.';
COMMENT ON COLUMN observability_incidents.created_at IS 'Timestamp de criacao do incidente.';
COMMENT ON COLUMN observability_incidents.updated_at IS 'Timestamp de ultima atualizacao do incidente.';

COMMENT ON COLUMN document_records.document_id IS 'Primary key UUID do documento registrado.';
COMMENT ON COLUMN document_records.user_id IS 'FK para dono do documento.';
COMMENT ON COLUMN document_records.module_code IS 'Modulo que gerou o documento.';
COMMENT ON COLUMN document_records.order_id IS 'Pedido relacionado ao documento.';
COMMENT ON COLUMN document_records.transaction_id IS 'Transacao relacionada ao documento.';
COMMENT ON COLUMN document_records.file_url IS 'URL ou caminho seguro do arquivo.';
COMMENT ON COLUMN document_records.checksum_sha256 IS 'Checksum SHA-256 para integridade.';
COMMENT ON COLUMN document_records.event_reference IS 'Referencia de evento gerador.';
COMMENT ON COLUMN document_records.created_at IS 'Timestamp imutavel de registro do documento.';

COMMENT ON COLUMN admin_action_audit.admin_action_audit_id IS 'Primary key UUID do audit trail admin.';
COMMENT ON COLUMN admin_action_audit.admin_id IS 'Admin que executou a acao.';
COMMENT ON COLUMN admin_action_audit.user_id IS 'Usuario afetado pela acao, quando existir.';
COMMENT ON COLUMN admin_action_audit.module_code IS 'Modulo afetado pela acao.';
COMMENT ON COLUMN admin_action_audit.action_name IS 'Nome tecnico da acao executada.';
COMMENT ON COLUMN admin_action_audit.reason IS 'Justificativa humana da acao.';
COMMENT ON COLUMN admin_action_audit.before_json IS 'Estado anterior em JSONB.';
COMMENT ON COLUMN admin_action_audit.after_json IS 'Estado posterior em JSONB.';
COMMENT ON COLUMN admin_action_audit.correlation_id IS 'Correlation ID para traces e suporte.';
COMMENT ON COLUMN admin_action_audit.created_at IS 'Timestamp imutavel da acao admin.';

COMMENT ON COLUMN advisor_insights.insight_id IS 'Primary key UUID do insight Advisor.';
COMMENT ON COLUMN advisor_insights.user_id IS 'FK para usuario receptor do insight.';
COMMENT ON COLUMN advisor_insights.insight_category IS 'Categoria do insight: energia, financas, saude ou mobilidade.';
COMMENT ON COLUMN advisor_insights.suggested_action IS 'Acao sugerida pela IA.';
COMMENT ON COLUMN advisor_insights.potential_savings_brl IS 'Economia potencial estimada em BRL.';
COMMENT ON COLUMN advisor_insights.is_executed IS 'Indica se o usuario executou a recomendacao.';
COMMENT ON COLUMN advisor_insights.consent_required IS 'Indica se execucao exige consentimento.';
COMMENT ON COLUMN advisor_insights.execution_consented_at IS 'Timestamp de consentimento de execucao.';
COMMENT ON COLUMN advisor_insights.source_module IS 'Modulo de origem do insight.';
COMMENT ON COLUMN advisor_insights.created_at IS 'Timestamp de criacao do insight.';
COMMENT ON COLUMN advisor_insights.updated_at IS 'Timestamp de ultima atualizacao do insight.';

COMMENT ON COLUMN financial_goals.goal_id IS 'Primary key UUID da meta financeira.';
COMMENT ON COLUMN financial_goals.user_id IS 'FK para usuario dono da meta.';
COMMENT ON COLUMN financial_goals.goal_name IS 'Nome da meta.';
COMMENT ON COLUMN financial_goals.target_amount_brl IS 'Valor alvo em BRL.';
COMMENT ON COLUMN financial_goals.current_amount_brl IS 'Valor acumulado em BRL.';
COMMENT ON COLUMN financial_goals.auto_round_up IS 'Indica se arredondamentos automaticos alimentam a meta.';
COMMENT ON COLUMN financial_goals.goal_status IS 'Status operacional da meta.';
COMMENT ON COLUMN financial_goals.deadline IS 'Prazo opcional da meta.';
COMMENT ON COLUMN financial_goals.created_at IS 'Timestamp de criacao da meta.';
COMMENT ON COLUMN financial_goals.updated_at IS 'Timestamp de ultima atualizacao da meta.';

COMMENT ON COLUMN teletherapy_sessions.session_id IS 'Primary key UUID da sessao de teleterapia.';
COMMENT ON COLUMN teletherapy_sessions.patient_id IS 'FK para usuario paciente.';
COMMENT ON COLUMN teletherapy_sessions.professional_id IS 'FK para usuario profissional de saude.';
COMMENT ON COLUMN teletherapy_sessions.session_status IS 'Status da sessao.';
COMMENT ON COLUMN teletherapy_sessions.encrypted_notes IS 'Notas clinicas cifradas, nunca texto puro sensivel.';
COMMENT ON COLUMN teletherapy_sessions.notes_access_policy IS 'Politica JSONB de acesso e auditoria das notas.';
COMMENT ON COLUMN teletherapy_sessions.scheduled_at IS 'Data marcada da sessao.';
COMMENT ON COLUMN teletherapy_sessions.started_at IS 'Inicio real da sessao.';
COMMENT ON COLUMN teletherapy_sessions.completed_at IS 'Fim real da sessao.';
COMMENT ON COLUMN teletherapy_sessions.created_at IS 'Timestamp de criacao da sessao.';
COMMENT ON COLUMN teletherapy_sessions.updated_at IS 'Timestamp de ultima atualizacao da sessao.';

COMMENT ON COLUMN creator_uploads.upload_id IS 'Primary key UUID do upload de midia.';
COMMENT ON COLUMN creator_uploads.user_id IS 'FK para criador do conteudo.';
COMMENT ON COLUMN creator_uploads.file_url IS 'URL do arquivo em storage/CDN.';
COMMENT ON COLUMN creator_uploads.upload_status IS 'Status de processamento do upload.';
COMMENT ON COLUMN creator_uploads.monetization_enabled IS 'Indica se o conteudo pode monetizar.';
COMMENT ON COLUMN creator_uploads.social_video_id IS 'Referencia logica para social_videos no MongoDB.';
COMMENT ON COLUMN creator_uploads.checksum_sha256 IS 'Checksum SHA-256 do arquivo.';
COMMENT ON COLUMN creator_uploads.created_at IS 'Timestamp de criacao do upload.';
COMMENT ON COLUMN creator_uploads.updated_at IS 'Timestamp de ultima atualizacao do upload.';

COMMENT ON COLUMN chat_conversations.conversation_id IS 'Primary key UUID da conversa.';
COMMENT ON COLUMN chat_conversations.participant1_id IS 'FK para primeiro participante.';
COMMENT ON COLUMN chat_conversations.participant2_id IS 'FK para segundo participante.';
COMMENT ON COLUMN chat_conversations.deleted_at IS 'Soft delete da conversa quando aplicavel.';
COMMENT ON COLUMN chat_conversations.created_at IS 'Timestamp de criacao da conversa.';

COMMENT ON COLUMN chat_messages.message_id IS 'Primary key UUID da mensagem.';
COMMENT ON COLUMN chat_messages.conversation_id IS 'FK para chat_conversations.conversation_id.';
COMMENT ON COLUMN chat_messages.sender_id IS 'FK para usuario remetente.';
COMMENT ON COLUMN chat_messages.helena_context IS 'contexto Helena usado no envio.';
COMMENT ON COLUMN chat_messages.content IS 'Conteudo textual da mensagem.';
COMMENT ON COLUMN chat_messages.created_at IS 'Timestamp de envio da mensagem.';

COMMENT ON COLUMN business_invoices.invoice_id IS 'Primary key UUID da nota ou fatura.';
COMMENT ON COLUMN business_invoices.business_user_id IS 'FK para usuario PJ emissor.';
COMMENT ON COLUMN business_invoices.order_id IS 'Pedido relacionado a nota.';
COMMENT ON COLUMN business_invoices.transaction_id IS 'Transacao relacionada a nota.';
COMMENT ON COLUMN business_invoices.invoice_number IS 'Numero fiscal ou interno da nota.';
COMMENT ON COLUMN business_invoices.total_amount_brl IS 'Valor total em BRL.';
COMMENT ON COLUMN business_invoices.due_date IS 'Data de vencimento.';
COMMENT ON COLUMN business_invoices.issued_at IS 'Data de emissao.';
COMMENT ON COLUMN business_invoices.created_at IS 'Timestamp de criacao da nota.';
COMMENT ON COLUMN business_invoices.updated_at IS 'Timestamp de ultima atualizacao da nota.';

COMMENT ON COLUMN business_payrolls.payroll_id IS 'Primary key UUID da folha.';
COMMENT ON COLUMN business_payrolls.business_user_id IS 'FK para usuario PJ responsavel pela folha.';
COMMENT ON COLUMN business_payrolls.period_start IS 'Inicio do periodo da folha.';
COMMENT ON COLUMN business_payrolls.period_end IS 'Fim do periodo da folha.';
COMMENT ON COLUMN business_payrolls.total_paid_brl IS 'Total pago em BRL.';
COMMENT ON COLUMN business_payrolls.executed_at IS 'Timestamp de execucao da folha.';
COMMENT ON COLUMN business_payrolls.created_at IS 'Timestamp de criacao da folha.';
COMMENT ON COLUMN business_payrolls.updated_at IS 'Timestamp de ultima atualizacao da folha.';

COMMENT ON COLUMN plug_transactions.plug_transaction_id IS 'Primary key UUID da transacao Valley Plug.';
COMMENT ON COLUMN plug_transactions.user_id IS 'FK para recebedor do pagamento presencial.';
COMMENT ON COLUMN plug_transactions.transaction_id IS 'FK opcional para ledger financeiro principal.';
COMMENT ON COLUMN plug_transactions.amount_brl IS 'Valor bruto da transacao presencial em BRL.';
COMMENT ON COLUMN plug_transactions.mdr_rate IS 'Taxa MDR aplicada, em fracao decimal.';
COMMENT ON COLUMN plug_transactions.settled_at IS 'Liquidacao D+0 ou posterior.';
COMMENT ON COLUMN plug_transactions.created_at IS 'Timestamp imutavel da compra presencial.';

COMMENT ON COLUMN affiliate_referrals.referral_id IS 'Primary key UUID da indicacao/affiliate referral.';
COMMENT ON COLUMN affiliate_referrals.referrer_id IS 'FK para usuario afiliado.';
COMMENT ON COLUMN affiliate_referrals.order_id IS 'Pedido que originou a comissao.';
COMMENT ON COLUMN affiliate_referrals.purchase_transaction_id IS 'Transacao que originou a comissao.';
COMMENT ON COLUMN affiliate_referrals.commission_amount_brl IS 'Comissao em BRL.';
COMMENT ON COLUMN affiliate_referrals.payout_at IS 'Timestamp de pagamento da comissao.';
COMMENT ON COLUMN affiliate_referrals.created_at IS 'Timestamp imutavel da indicacao.';

COMMENT ON COLUMN docs_receipts.receipt_id IS 'Primary key UUID do comprovante.';
COMMENT ON COLUMN docs_receipts.user_id IS 'FK para dono do comprovante.';
COMMENT ON COLUMN docs_receipts.order_id IS 'Pedido relacionado ao comprovante.';
COMMENT ON COLUMN docs_receipts.transaction_id IS 'Transacao relacionada ao comprovante.';
COMMENT ON COLUMN docs_receipts.document_id IS 'Documento canonico relacionado.';
COMMENT ON COLUMN docs_receipts.file_url IS 'URL ou caminho seguro do comprovante.';
COMMENT ON COLUMN docs_receipts.created_at IS 'Timestamp imutavel de criacao do comprovante.';

COMMENT ON TRIGGER trg_module_catalog_set_updated_at ON module_catalog IS 'Atualiza updated_at no catalogo de modulos.';
COMMENT ON TRIGGER trg_admin_users_set_updated_at ON admin_users IS 'Atualiza updated_at em usuarios admin.';
COMMENT ON TRIGGER trg_admin_permissions_set_updated_at ON admin_permissions IS 'Atualiza updated_at em permissoes admin.';
COMMENT ON TRIGGER trg_business_rule_definitions_set_updated_at ON business_rule_definitions IS 'Atualiza updated_at em definicoes de regras.';
COMMENT ON TRIGGER trg_gamification_campaigns_set_updated_at ON gamification_campaigns IS 'Atualiza updated_at em campanhas.';
COMMENT ON TRIGGER trg_observability_incidents_set_updated_at ON observability_incidents IS 'Atualiza updated_at em incidentes.';
COMMENT ON TRIGGER trg_business_rule_audit_prevent_update ON business_rule_audit IS 'Impede UPDATE em auditoria append-only de regras.';
COMMENT ON TRIGGER trg_business_rule_audit_prevent_delete ON business_rule_audit IS 'Impede DELETE em auditoria append-only de regras.';
COMMENT ON TRIGGER trg_points_ledger_prevent_update ON points_ledger IS 'Impede UPDATE no ledger append-only de pontos.';
COMMENT ON TRIGGER trg_points_ledger_prevent_delete ON points_ledger IS 'Impede DELETE no ledger append-only de pontos.';
COMMENT ON TRIGGER trg_document_records_prevent_update ON document_records IS 'Impede UPDATE em documentos append-only.';
COMMENT ON TRIGGER trg_document_records_prevent_delete ON document_records IS 'Impede DELETE em documentos append-only.';
COMMENT ON TRIGGER trg_admin_action_audit_prevent_update ON admin_action_audit IS 'Impede UPDATE no audit trail admin.';
COMMENT ON TRIGGER trg_admin_action_audit_prevent_delete ON admin_action_audit IS 'Impede DELETE no audit trail admin.';
COMMENT ON TRIGGER trg_advisor_insights_set_updated_at ON advisor_insights IS 'Atualiza updated_at em insights Advisor.';
COMMENT ON TRIGGER trg_financial_goals_set_updated_at ON financial_goals IS 'Atualiza updated_at em metas financeiras.';
COMMENT ON TRIGGER trg_teletherapy_sessions_set_updated_at ON teletherapy_sessions IS 'Atualiza updated_at em sessoes de teleterapia.';
COMMENT ON TRIGGER trg_creator_uploads_set_updated_at ON creator_uploads IS 'Atualiza updated_at em uploads de criador.';
COMMENT ON TRIGGER trg_business_invoices_set_updated_at ON business_invoices IS 'Atualiza updated_at em notas/faturas.';
COMMENT ON TRIGGER trg_business_payrolls_set_updated_at ON business_payrolls IS 'Atualiza updated_at em folhas.';
COMMENT ON TRIGGER trg_plug_transactions_prevent_update ON plug_transactions IS 'Impede UPDATE em transacoes Plug append-only.';
COMMENT ON TRIGGER trg_plug_transactions_prevent_delete ON plug_transactions IS 'Impede DELETE em transacoes Plug append-only.';
COMMENT ON TRIGGER trg_affiliate_referrals_prevent_update ON affiliate_referrals IS 'Impede UPDATE em referrals append-only.';
COMMENT ON TRIGGER trg_affiliate_referrals_prevent_delete ON affiliate_referrals IS 'Impede DELETE em referrals append-only.';
COMMENT ON TRIGGER trg_docs_receipts_prevent_update ON docs_receipts IS 'Impede UPDATE em receipts append-only.';
COMMENT ON TRIGGER trg_docs_receipts_prevent_delete ON docs_receipts IS 'Impede DELETE em receipts append-only.';

COMMIT;
