# Status - Valley Delivery

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

- PostgreSQL: `database/postgres/011_v47_city_ops_delivery_mobility_security.sql` cobre `delivery_shipments` e `delivery_shipment_events` como contrato relacional principal do `DELIVERY`, com integracao a `orders`, `wallets`, `document_records` e `users`.
- Integridade: o modulo herda o no central `users.user_id`, vincula `order_id`, `wallet_id`, `merchant_user_id` e `rider_user_id`, e preserva trilha append-only em `delivery_shipment_events`.
- MongoDB: `database/mongodb/003_v47_field_ops_security_agenda.mongo.js` cobre `delivery_dispatch_runs` como camada volumosa de dispatch, matching, ETA, expiracao e correlacao operacional, ligada a `orders.order_id` e `delivery_shipments.shipment_id` por UUID em string.
- Regras de negocio: nao existe, ate este ponto, regra canonica exclusiva de `DELIVERY` em `business_rule_definitions`. A decisao revisada e considerar isso descartado por enquanto, porque o modulo ja esta blindado por `foreign key`, `check`, `trigger`, enums e trilha append-only; regras parametrizadas entram apenas quando houver SLA por zona, prioridade dinamica, secure delivery ou cold chain configuravel.
- Admin/RBAC/ABAC: o desenho usa `module_catalog` + `admin_permissions` para permissao por `module_code`, com trilha de auditoria no control plane.
- Manual/PDF: `MANUAL_ONLINE/README.md`, `MANUAL_ONLINE/01_ARQUITETURA_TECNICA_MICROSSERVICOS_EVENTOS.md`, `MANUAL_ONLINE/02_MODELAGEM_BANCO_DADOS.md`, `MANUAL_ONLINE/04_ROADMAP_IMPLEMENTACAO_SPRINTS.md` e `output/pdf/VALLEY_MANUAL_ONLINE.pdf` ja refletem o modulo.

Plano minimo de testes de integracao:

1. Criar `delivery_shipment` ligado a `order_id`, `wallet_id`, `requester_user_id` e `shipment_kind`, validando ownership, dominio permitido e timeline operacional.
2. Inserir `delivery_shipment_event` com `event_type`, `shipment_status`, `actor_user_id` e `occurred_at`, confirmando append-only e reconstruindo timeline do embarque.
3. Inserir documento em `delivery_dispatch_runs` com `order_id`, `shipment_id`, `dispatch_status`, `candidate_rider_user_ids` e `service_level`, validando matching e expiração do ciclo.
4. Testar fluxo completo `DISPATCHING -> ASSIGNED -> PICKED_UP -> DELIVERED` entre Postgres e Mongo, validando ponte por `shipment_id`, `order_id` e `correlation_id`.
5. Testar cenário `FAILED` ou `CANCELLED`, registrando motivo textual, trilha de evento e consistencia entre estado mutavel em `delivery_shipments` e historico append-only.

Observacao: este status deixou de ser apenas inicial e agora registra a primeira revisao tecnica do modulo.
