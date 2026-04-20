# Status - Valley REPLY

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

- PostgreSQL: `database/postgres/008_v47_foundation_commerce_operations.sql` cobre `suppliers`, `procurement_orders`, `procurement_order_items` e `service_work_orders` como contrato operacional direto do `REPLY`.
- Cobertura complementar: `database/postgres/005_v47_domain_tables_core_first.sql` adiciona `business_invoices` e `business_payrolls`, fechando a parte de faturamento e folha citada no objetivo do modulo.
- Integridade: o modulo herda o no central `users.user_id` e usa FKs para `wallets`, `orders`, `transactions` e `module_delivery_registry`, com triggers de coerencia como `trg_procurement_orders_wallet_owner`, `trg_service_work_orders_wallet_owner` e `trg_procurement_order_items_item_owner`.
- MongoDB: `REPLY` nao abriu collection propria. A decisao revisada e manter o modulo com persistencia principal em PostgreSQL e deixar payload volumoso para modulos vizinhos, como `WMS` e `LOG`, quando houver telemetria ou sinais de campo.
- Regras de negocio: nao existe, ate este ponto, regra canonica exclusiva de `REPLY` em `business_rule_definitions`. A decisao revisada e considerar isso descartado por enquanto, porque o modulo ja esta blindado por `foreign key`, `check`, `trigger` e ownership relacional; regras parametrizadas entram apenas quando houver SLA, aprovacao, limite ou politica variavel de procurement e faturamento.
- Admin/RBAC/ABAC: o desenho usa `module_catalog` + `admin_permissions` para permissao por `module_code`, com trilha de auditoria no control plane.
- Manual/PDF: `MANUAL_ONLINE/README.md`, `MANUAL_ONLINE/01_ARQUITETURA_TECNICA_MICROSSERVICOS_EVENTOS.md`, `MANUAL_ONLINE/02_MODELAGEM_BANCO_DADOS.md` e `MANUAL_ONLINE/04_ROADMAP_IMPLEMENTACAO_SPRINTS.md` ja refletem o modulo. `output/pdf/VALLEY_MANUAL_ONLINE.pdf` existe e esta mais novo que as migrations `005` e `008`.

Plano minimo de testes de integracao:

1. Criar `supplier` e `buyer_user_id` validos em `users`, depois abrir `procurement_order` com `wallet_id` do comprador e validar ownership, moeda fixa em BRL e timeline operacional.
2. Inserir `procurement_order_items` ligados ao pedido e ao `inventory_item`, validando unicidade por pedido/item, quantidade recebida nao superior a quantidade pedida e trigger de ownership do item.
3. Criar `service_work_order` com `requester_user_id`, `provider_user_id`, `wallet_id` e `order_id`, validando janela de agenda, timeline e coerencia de posse da wallet.
4. Criar `business_invoice` vinculada a `order_id` e `transaction_id`, confirmando integracao de faturamento com o nucleo financeiro sem duplicar ledger.
5. Criar `business_payroll` para usuario PJ e validar periodo, total pago e leitura administrativa por `module_code` no control plane.

Observacao: este status deixou de ser apenas inicial e agora registra a primeira revisao tecnica do modulo.
