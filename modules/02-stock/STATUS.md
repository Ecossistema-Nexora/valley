# Status - Valley Stock

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

- PostgreSQL: `database/postgres/008_v47_foundation_commerce_operations.sql` cobre `suppliers`, `inventory_items`, `inventory_lots`, `inventory_movements`, `marketplace_listings`, `procurement_orders`, `procurement_order_items` e `warehouse_cycle_counts`.
- Integridade: o modulo herda o no central `users.user_id` e usa FKs para `wallets`, `orders`, `transactions` e `module_delivery_registry`, com trilha append-only em `inventory_movements` e `warehouse_cycle_counts`.
- MongoDB: `STOCK` nao abriu collection propria. A decisao revisada e manter o modulo com persistencia principal em PostgreSQL e reutilizar Mongo apenas em dominios vizinhos, como `LOG` e snapshots operacionais de `WMS`.
- Regra de negocio: `BR-STO-PRICE-001` foi cadastrada em `business_rule_definitions` como regra de pricing do fluxo Stock, ainda que registrada no modulo operacional `MARKETPLACE`, para custo + frete + margem de 50 por cento. O runtime comercial foi aprofundado depois em `marketplace_listing_controls` e `marketplace_competitor_snapshots`.
- Admin/RBAC/ABAC: o desenho usa `module_catalog` + `admin_permissions` para permissao por `module_code`, com trilha de auditoria no control plane.
- Manual/PDF: `MANUAL_ONLINE/README.md`, `MANUAL_ONLINE/02_MODELAGEM_BANCO_DADOS.md`, `MANUAL_ONLINE/01_ARQUITETURA_TECNICA_MICROSSERVICOS_EVENTOS.md` e `MANUAL_ONLINE/04_ROADMAP_IMPLEMENTACAO_SPRINTS.md` ja refletem o modulo. `output/pdf/VALLEY_MANUAL_ONLINE.pdf` existe e esta mais novo que a migration `008`.

Plano minimo de testes de integracao:

1. Criar `supplier` vinculado a `users.user_id` do tipo PJ e validar `default_margin_rate`, `lead_time_days` e `rating_score`.
2. Criar `inventory_item`, `inventory_lot` e `marketplace_listing` com `wallet_id` do merchant e validar ownership, FKs e coerencia de publicacao.
3. Inserir `inventory_movement` com `order_id` e `transaction_id` reais e confirmar bloqueio de `UPDATE` e `DELETE`.
4. Abrir `procurement_order` com `supplier_id`, `supplier_user_id` e `destination_warehouse_id`, validando timeline operacional e moeda fixa em BRL.
5. Rodar caso de competitividade em `marketplace_listing_controls` e snapshot append-only em `marketplace_competitor_snapshots`.

Observacao: este status deixou de ser apenas inicial e agora registra a primeira revisao tecnica do modulo.
