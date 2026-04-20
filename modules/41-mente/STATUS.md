# Status - Valley Mente

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

- PostgreSQL: `database/postgres/005_v47_domain_tables_core_first.sql` cobre `teletherapy_sessions`, com `patient_id`, `professional_id`, `encrypted_notes`, `notes_access_policy`, checks de usuarios distintos e timeline de atendimento.
- Integracao entre dominios: `teletherapy_sessions` e reaproveitada por `ADVISOR` e pode originar `health_care_plans` em `database/postgres/012_v47_core_services_health_jobs_pharmacy_events.sql`, o que fecha a ponte entre saude mental e cuidado continuo sem duplicar agenda clinica.
- MongoDB: `MENTE` permanece com `data_home = postgres` no registry. A decisao revisada e descartar collection propria neste momento, mantendo sessoes, notas sensiveis e auditoria no relacional com armazenamento cifrado.
- Regras de negocio: nao existe regra exclusiva do modulo em `business_rule_definitions`. A decisao revisada e considerar isso descartado por enquanto, porque a sensibilidade da sessao ja esta protegida por ownership, checks de timeline e politica JSON de acesso a notas.
- Admin/RBAC/ABAC: o modulo herda `module_catalog`, `admin_permissions` e `admin_action_audit`, suficiente para separar profissional, suporte e operacao administrativa.
- Manual/PDF: `MANUAL_ONLINE/README.md` agora registra `MENTE` como modulo revisado sobre `teletherapy_sessions` e sua ponte opcional com `HEALTH`. O PDF oficial foi regenerado apos esta atualizacao documental.

Plano minimo de testes de integracao:

1. Criar `teletherapy_session` com `patient_id`, `professional_id`, `session_status = 'SCHEDULED'`, `encrypted_notes`, `notes_access_policy` e `scheduled_at`, validando usuarios distintos e politica de acesso sensivel.
2. Atualizar a sessao para `IN_PROGRESS` e `COMPLETED`, preenchendo `started_at` e `completed_at`, confirmando os checks de timeline.
3. Tentar criar sessao com `patient_id = professional_id`, validando bloqueio por coerencia clinica.
4. Criar `health_care_plan` apontando `source_session_id` para a sessao concluida, validando a ponte operacional entre `MENTE` e `HEALTH`.
5. Registrar `document_record` ou trilha documental complementar com `module_code = 'MENTE'`, validando anexos operacionais sem mover notas cifradas para fora do relacional.

Observacao: este status deixou de ser apenas inicial e agora registra a primeira revisao tecnica do modulo.
