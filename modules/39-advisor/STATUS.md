# Status - Valley Advisor

- [x] Registry canonico criado.
- [x] Suporte base de schema ja implantado ou parcialmente implantado.
- [x] Contrato operacional inicial gerado.
- [x] Schema PostgreSQL especifico revisado.
- [x] Schema MongoDB especifico revisado.
- [x] Regras de negocio cadastradas ou descartadas.
- [x] Fluxos Admin/RBAC/ABAC definidos.
- [x] Testes de integracao planejados.
- [x] Manual Online atualizado.
- [x] PDF regenerado.

Evidencias da revisao:

- PostgreSQL: `database/postgres/005_v47_domain_tables_core_first.sql` cobre `advisor_insights`, `financial_goals` e `teletherapy_sessions`, fechando recomendacao, objetivo financeiro e sessao sensivel com consentimento e notas cifradas.
- Persistencia hibrida: `database/mongodb/001_ai_social_telemetry.mongo.js` cobre `ai_memory`, que fecha a memoria contextual do Advisor e a ponte com follow-up inteligente. Isso confirma o `data_home = postgres_mongo` do registry.
- Cobertura complementar: a mesma migration `005` tambem cria `chat_conversations` e `chat_messages`, enquanto `database/mongodb/003_v47_field_ops_security_agenda.mongo.js` aceita `source_module = 'ADVISOR'` em `agenda_items`. O modulo portanto ja conversa com `CHAT` e `AGENDA` sem abrir schema duplicado.
- Regras de negocio: nao existe, ate aqui, definicao exclusiva do modulo em `business_rule_definitions`. A decisao revisada e considerar isso descartado por enquanto, porque consentimento, savings, metas e timeline de sessao ja estao protegidos por `check`, enums, ownership relacional e memoria contextual; rules runtime entram depois para automacao executiva mais agressiva.
- Admin/RBAC/ABAC: o modulo herda `module_catalog`, `admin_permissions` e `admin_action_audit`, o que e suficiente para separar operador humano, advisor assistido, suporte e trilha administrativa.
- Manual/PDF: `MANUAL_ONLINE/README.md`, `MANUAL_ONLINE/01_ARQUITETURA_TECNICA_MICROSSERVICOS_EVENTOS.md`, `MANUAL_ONLINE/02_MODELAGEM_BANCO_DADOS.md`, `MANUAL_ONLINE/04_ROADMAP_IMPLEMENTACAO_SPRINTS.md` e `MANUAL_ONLINE/OPERACAO_AUTONOMA.md` refletem o modulo. O PDF oficial foi regenerado apos esta revisao.

Plano minimo de testes de integracao:

1. Criar `advisor_insight` com `user_id`, `insight_category`, `suggested_action`, `potential_savings_brl` e `consent_required`, validando checks de texto, savings e consentimento.
2. Criar `financial_goal` para o mesmo usuario com alvo, valor atual e `auto_round_up`, confirmando integridade de BRL e limite `current_amount_brl <= target_amount_brl`.
3. Criar `teletherapy_session` com `patient_id`, `professional_id`, `scheduled_at`, `encrypted_notes` e `notes_access_policy`, validando timeline, usuarios distintos e protecao de notas sensiveis.
4. Inserir memoria em `ai_memory` com `source_module = 'ADVISOR'` e `consent_scope` apropriado, confirmando a camada contextual que sustenta recomendacoes e follow-up.
5. Criar `agenda_item` originado de `ADVISOR` ou acionar fluxo conjunto insight -> memory -> agenda, validando a ponte entre recomendacao, contexto e execucao assistida.

Observacao: este status deixou de ser apenas inicial e agora registra a primeira revisao tecnica do modulo.
