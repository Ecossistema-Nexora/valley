# Status - Valley Services

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

- PostgreSQL: `database/postgres/012_v47_core_services_health_jobs_pharmacy_events.sql` cobre o nucleo do modulo com `service_provider_profiles`, `service_catalog_services`, `service_bookings` e `service_booking_events`, todos ancorados em `users.user_id`, `wallets.wallet_id`, `orders.order_id` e `legal_contracts`.
- Cobertura operacional complementar: `database/postgres/008_v47_foundation_commerce_operations.sql` ja tinha aberto `service_work_orders`, que continua util como retaguarda operacional e tarefa de campo, enquanto `012` fecha a camada comercial transacional do `SERVICES`.
- Integridade: a revisao confirma `module_code = 'SERVICES'`, coerencia de prestador vs catalogo, ownership de wallet do cliente, checks de valores e timeline, alem de append-only em `service_booking_events` com triggers que impedem `UPDATE` e `DELETE`.
- MongoDB: `SERVICES` nao abriu collection propria. A decisao revisada e manter a contratacao, o booking e a prova operacional no PostgreSQL; volume semi-estruturado so deve sair para MongoDB quando houver telemetria, chat de alta escala ou sinais de campo realmente volumosos.
- Regras de negocio: nao existe, ate aqui, definicao exclusiva do modulo em `business_rule_definitions`. A decisao revisada e considerar isso descartado por enquanto, porque o fluxo ja esta protegido por contrato legal, enums de status/modo, ownership relacional e trilha append-only; regras parametrizadas entram depois para SLA dinamico, quote automatica, score de prestador ou compliance setorial.
- Admin/RBAC/ABAC: o desenho herda `module_catalog`, `admin_permissions` e `admin_action_audit`, permitindo separar operacao de prestador, time legal, suporte e backoffice.
- Manual/PDF: `MANUAL_ONLINE/README.md`, `MANUAL_ONLINE/01_ARQUITETURA_TECNICA_MICROSSERVICOS_EVENTOS.md`, `MANUAL_ONLINE/02_MODELAGEM_BANCO_DADOS.md`, `MANUAL_ONLINE/03_FLUXO_COMPLETO_APIS.md`, `MANUAL_ONLINE/04_ROADMAP_IMPLEMENTACAO_SPRINTS.md` e `MANUAL_ONLINE/OPERACAO_AUTONOMA.md` cobrem o modulo. O PDF oficial foi regenerado apos a migration `012` usada como base desta revisao.

Plano minimo de testes de integracao:

1. Criar `service_provider_profile` com `provider_user_id`, `wallet_id`, `module_code = 'SERVICES'` e `availability_json`, validando wallet operacional do prestador e headline obrigatoria.
2. Publicar `service_catalog_service` ligado ao provider profile, com `service_code`, `booking_mode`, `base_price_brl`, `remote_enabled` e `onsite_enabled`, confirmando coerencia com o perfil e regras minimas de catalogo.
3. Criar `order` no dominio `SERVICES` e depois `service_booking` com `customer_user_id`, `provider_user_id`, `wallet_id`, horario agendado e contrato juridico opcional, validando a trigger `assert_service_booking_coherence`.
4. Inserir eventos em `service_booking_events` para `REQUESTED`, `CONFIRMED`, `CHECKIN` e `COMPLETED`, confirmando trilha append-only por booking e order corretos.
5. Tentar inserir booking com wallet de outro usuario ou provider divergente do catalogo, validando que a coerencia relacional bloqueia contratacao inconsistente antes do fluxo ir para producao.

Observacao: este status deixou de ser apenas inicial e agora registra a primeira revisao tecnica do modulo.
