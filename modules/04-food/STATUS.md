# Status - Valley Food

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

- PostgreSQL: `database/postgres/002_financial_ledger_equity_orders.sql` cobre `orders` como entidade mestre do `FOOD`, com `order_domain = 'FOOD'`, campos reservados como `restaurant_user_id`, `kitchen_status` e `prep_started_at`, alem de integracao com `wallets` e `transactions`.
- Cobertura complementar: `database/postgres/011_v47_city_ops_delivery_mobility_security.sql` cria `delivery_shipments` com `shipment_kind = 'FOOD'`, permitindo que o pedido alimentar avance para coleta, rota e prova de entrega sem duplicar contrato de pedido.
- MongoDB: `FOOD` nao abriu collection propria. A decisao revisada e manter o modulo com persistencia principal em PostgreSQL e reutilizar `delivery_dispatch_runs` do `database/mongodb/003_v47_field_ops_security_agenda.mongo.js` quando houver dispatch, matching e operacao de campo, inclusive com `module_code = 'FOOD'`.
- Regras de negocio: `BR-FOOD-FEE-001` foi cadastrada em `business_rule_definitions` para taxa de 15 por cento sobre o valor do pedido. Informacao nutricional e regra de saude continuam sem tabela dedicada neste ciclo e ficam como backlog de integracao com `HEALTH`.
- Admin/RBAC/ABAC: o desenho usa `module_catalog` + `admin_permissions` para permissao por `module_code`, com trilha de auditoria no control plane.
- Manual/PDF: `MANUAL_ONLINE/README.md`, `MANUAL_ONLINE/01_ARQUITETURA_TECNICA_MICROSSERVICOS_EVENTOS.md`, `MANUAL_ONLINE/02_MODELAGEM_BANCO_DADOS.md` e `output/pdf/VALLEY_MANUAL_ONLINE.pdf` ja sustentam o estado atual do modulo, mesmo sem tabela exclusiva de nutricao.

Plano minimo de testes de integracao:

1. Criar `order` com `order_domain = 'FOOD'`, `restaurant_user_id`, `wallet_id` do cliente e totais coerentes, validando campos reservados de Food e ownership da wallet.
2. Vincular `transaction` de pagamento ao pedido e validar fee, settle e referencia cruzada entre `orders` e `transactions`.
3. Criar `delivery_shipment` com `source_order_domain = 'FOOD'` e `shipment_kind = 'FOOD'`, validando timeline de despacho, atribuicao de rider e prova de entrega.
4. Inserir documento em `delivery_dispatch_runs` com `module_code = 'FOOD'`, `service_level` e `selected_rider_user_id`, validando dispatch operacional sem collection dedicada do modulo.
5. Validar aplicacao da regra `BR-FOOD-FEE-001` no fluxo de pricing do pedido e registrar como gap conhecido a ausencia atual de tabela especifica para informacao nutricional.

Observacao: este status deixou de ser apenas inicial e agora registra a primeira revisao tecnica do modulo.
