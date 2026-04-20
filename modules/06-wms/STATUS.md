# Status - Valley WMS

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

- PostgreSQL: `database/postgres/008_v47_foundation_commerce_operations.sql` cobre `warehouses`, `inventory_items`, `inventory_lots`, `inventory_movements` e `warehouse_cycle_counts` como base operacional do `WMS`, ainda que parte dessas tabelas seja compartilhada com `STOCK` e `MARKETPLACE`.
- Integridade: o modulo herda o no central `users.user_id` e usa FKs para `warehouses`, `inventory_items`, `orders`, `transactions` e `module_delivery_registry`, com triggers de coerencia como `trg_inventory_lots_item_owner` e `trg_inventory_movements_item_owner`, alem de append-only em `inventory_movements` e `warehouse_cycle_counts`.
- MongoDB: `database/mongodb/002_v47_log_iot_foundation.mongo.js` cobre `warehouse_sensor_snapshots` como camada volumosa do `WMS`, ligada a `warehouses.warehouse_id` por UUID em string. O mesmo script tambem cria `iot_device_registry` e `iot_sensor_events`, reutilizados pelo armazem quando houver sensores ou gateways.
- Regras de negocio: nao existe, ate este ponto, regra canonica exclusiva de `WMS` em `business_rule_definitions`. A decisao revisada e considerar isso descartado por enquanto, porque o modulo ja esta blindado por `foreign key`, `check`, `trigger`, ownership e trilha append-only; regras parametrizadas entram apenas quando houver slotting, reposicao automatica, limite dinamico de ocupacao ou cold chain com threshold configuravel.
- Admin/RBAC/ABAC: o desenho usa `module_catalog` + `admin_permissions` para permissao por `module_code`, com trilha de auditoria no control plane.
- Manual/PDF: `MANUAL_ONLINE/README.md`, `MANUAL_ONLINE/01_ARQUITETURA_TECNICA_MICROSSERVICOS_EVENTOS.md`, `MANUAL_ONLINE/02_MODELAGEM_BANCO_DADOS.md`, `MANUAL_ONLINE/04_ROADMAP_IMPLEMENTACAO_SPRINTS.md` e `MANUAL_ONLINE/OPERACAO_AUTONOMA.md` ja refletem o modulo. `output/pdf/VALLEY_MANUAL_ONLINE.pdf` existe e esta mais novo que `database/postgres/008_v47_foundation_commerce_operations.sql` e `database/mongodb/002_v47_log_iot_foundation.mongo.js`.

Plano minimo de testes de integracao:

1. Criar `warehouse` com `owner_user_id`, `manager_user_id`, `warehouse_code` e `capacity_units`, validando ownership, codigo unico e status operacional.
2. Criar `inventory_item` e `inventory_lot` no armazem, validando coerencia entre `owner_user_id`, `item_id`, `warehouse_id`, quantidades nao negativas e trigger de ownership do lote.
3. Inserir `inventory_movement` com `movement_type`, `quantity_delta`, `order_id` e `transaction_id`, confirmando coerencia do item e bloqueio de `UPDATE` e `DELETE`.
4. Inserir registro em `warehouse_cycle_counts` e validar trilha append-only, diferenca calculada entre esperado e contado e leitura por armazem/item.
5. Inserir documento em `warehouse_sensor_snapshots` ligado ao `warehouse_id` e a um `device_id` valido, validando ponte Postgres + Mongo, timeline por `snapshot_time` e leitura de temperatura/umidade/ocupacao.

Observacao: este status deixou de ser apenas inicial e agora registra a primeira revisao tecnica do modulo.
