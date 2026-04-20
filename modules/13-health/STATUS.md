# Status - Valley Health

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

- PostgreSQL: `database/postgres/012_v47_core_services_health_jobs_pharmacy_events.sql` cobre `health_profiles`, `health_care_plans` e `health_prescriptions`, todos ancorados em `users.user_id`, com `module_code = 'HEALTH'`, consentimentos estruturados, checks de timeline e validade clinica.
- Integracao sensivel: a mesma migration `012` conecta `health_care_plans.source_session_id` a `teletherapy_sessions` e `health_prescriptions.document_id` a `document_records`, fechando a ponte com `MENTE` e `DOCS` sem duplicar prontuario ou anexos juridicos.
- MongoDB: `database/mongodb/001_ai_social_telemetry.mongo.js` cobre `ai_memory`, usada como memoria contextual e follow-up assistido quando `HEALTH` precisar resumo operacional nao relacional. A decisao revisada e nao abrir collection clinica propria neste momento; o master sensivel permanece no PostgreSQL.
- Regras de negocio: nao existe, ate aqui, regra exclusiva do modulo em `business_rule_definitions`. A decisao revisada e considerar isso descartado por enquanto, porque consentimento, risco e prescricao ja estao cobertos por checks, enums, FKs e ownership relacional.
- Admin/RBAC/ABAC: o modulo herda `module_catalog`, `admin_permissions` e `admin_action_audit`, suficiente para separar operacao clinica, suporte, farmacia e backoffice.
- Manual/PDF: `MANUAL_ONLINE/README.md` agora registra `HEALTH` como fronteira revisada sobre `health_profiles`, `health_care_plans`, `health_prescriptions` e `ai_memory` complementar. O PDF oficial foi regenerado apos esta atualizacao documental.

Plano minimo de testes de integracao:

1. Criar `health_profile` com `user_id`, `primary_care_user_id`, `consent_json`, `risk_flags_json` e `profile_status`, validando checks de JSON, usuarios distintos e `module_code = 'HEALTH'`.
2. Criar `teletherapy_session` e, em seguida, `health_care_plan` com `patient_user_id`, `professional_user_id`, `care_plan_json` e `source_session_id`, validando a ponte entre cuidado continuo e sessao sensivel.
3. Criar `health_prescription` com `patient_user_id`, `prescriber_user_id`, `prescription_code`, `medication_summary_json`, `issued_at` e `valid_until`, confirmando validade temporal e documento referenciavel.
4. Inserir memoria em `ai_memory` com `source_module = 'HEALTH'`, `consent_scope` apropriado e prazo de expiracao, validando o lado contextual nao relacional do modulo.
5. Consultar o conjunto `health_profiles` -> `health_care_plans` -> `health_prescriptions` por paciente e status, validando a leitura operacional do modulo sem collection clinica paralela.

Observacao: este status deixou de ser apenas inicial e agora registra a primeira revisao tecnica do modulo.
