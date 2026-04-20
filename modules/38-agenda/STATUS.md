# Status - Valley Agenda

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

- MongoDB: `database/mongodb/003_v47_field_ops_security_agenda.mongo.js` cobre `agenda_items` como contrato principal do modulo, com `JSON Schema Validation`, `UUID` em string, `agenda_kind`, `agenda_status`, `source_module`, `scheduled_for`, offsets de lembrete, recorrencia e entidades relacionadas.
- Cobertura complementar: `database/mongodb/001_ai_social_telemetry.mongo.js` cobre `ai_memory`, que fecha a camada de memoria contextual usada pela Helena para priorizacao, follow-up e contexto entre `AGENDA`, `ADVISOR` e `CHAT`.
- PostgreSQL: `AGENDA` nao abriu tabela propria. A decisao revisada e manter lembretes, tarefas e follow-ups no MongoDB, descartando tabela relacional dedicada nesta fase para nao empurrar payload semi-estruturado e recorrencia operacional para o SQL.
- Regras de negocio: nao existe, ate aqui, regra canonica exclusiva do modulo em `business_rule_definitions`. A decisao revisada e considerar isso descartado por enquanto, porque recorrencia, snooze, follow-up e priorizacao imediata ja ficam suficientemente blindados por validator, enums e indices do proprio Mongo.
- Admin/RBAC/ABAC: o modulo herda governanca por `module_catalog`, `admin_permissions` e `admin_action_audit`, o que basta para separar operacao assistida, suporte e rotinas automatizadas por `module_code`.
- Manual/PDF: `MANUAL_ONLINE/README.md`, `MANUAL_ONLINE/01_ARQUITETURA_TECNICA_MICROSSERVICOS_EVENTOS.md`, `MANUAL_ONLINE/02_MODELAGEM_BANCO_DADOS.md`, `MANUAL_ONLINE/04_ROADMAP_IMPLEMENTACAO_SPRINTS.md` e `MANUAL_ONLINE/OPERACAO_AUTONOMA.md` ja refletem o modulo. O PDF oficial foi regenerado apos esta revisao.

Plano minimo de testes de integracao:

1. Inserir `agenda_item` com `agenda_kind = 'REMINDER'`, `agenda_status = 'OPEN'`, `source_module = 'AGENDA'`, `scheduled_for` e `reminder_offsets_minutes`, validando o contrato minimo do lembrete.
2. Inserir `agenda_item` com `source_module = 'ADVISOR'` e `related_entities` apontando para um insight ou goal, validando a fronteira entre follow-up inteligente e agenda.
3. Inserir `agenda_item` com `recurrence`, `timezone` e `due_at`, confirmando suporte a rotina recorrente e prazo final sem tabela relacional auxiliar.
4. Inserir memoria em `ai_memory` para o mesmo `user_id` e validar leitura combinada de contexto + agenda por indices de usuario e tempo.
5. Simular transicao `OPEN -> SNOOZED -> DONE` e consultar pelos indices de usuario/status/scheduled_for, confirmando retomada operacional da Helena sem perda de rastreabilidade.

Observacao: este status deixou de ser apenas inicial e agora registra a primeira revisao tecnica do modulo.
