# Status - Valley Financas

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

- PostgreSQL: `database/postgres/005_v47_domain_tables_core_first.sql` cobre `financial_goals`, que fecha metas, round-up e planejamento financeiro com checks de alvo, acumulado e `auto_round_up`.
- Nucleo financeiro complementar: `database/postgres/001_core_identity_wallets.sql` e `database/postgres/002_financial_ledger_equity_orders.sql` continuam sendo a espinha do modulo com `wallets` e `transactions`, enquanto `database/postgres/005_v47_domain_tables_core_first.sql` tambem cobre `plug_transactions` para fluxo presencial e micro-negocio.
- MongoDB: `FINANCAS` permanece com `data_home = postgres` no registry. A decisao revisada e descartar collection propria por enquanto, mantendo saldo, metas, cashflow e reconciliacao apenas na trilha relacional e append-only.
- Regras de negocio: `database/postgres/004_v47_control_plane_modules_rules.sql` ja registra `BR-FIN-002`, que impede uso de dados de endividamento e score em publicidade. A decisao revisada e considerar isso como regra canonica suficiente nesta fase, sem abrir runtime extra.
- Admin/RBAC/ABAC: o modulo herda `module_catalog`, `admin_permissions` e `admin_action_audit`, separando operacao financeira, suporte e backoffice.
- Manual/PDF: `MANUAL_ONLINE/README.md` agora registra `FINANCAS` como modulo revisado sobre `financial_goals` e sobre o backbone `wallets + transactions`. O PDF oficial foi regenerado apos esta atualizacao documental.

Plano minimo de testes de integracao:

1. Criar `financial_goal` com `user_id`, `goal_name`, `target_amount_brl`, `current_amount_brl`, `auto_round_up` e `goal_status`, validando target positivo e limite `current_amount_brl <= target_amount_brl`.
2. Criar `wallet` BRL do usuario e registrar `transaction` de compra ou transferencia no ledger central, confirmando que o modulo reaproveita a trilha financeira append-only em vez de duplicar saldo.
3. Criar `plug_transaction` ligado a `wallet_id` e `transaction_id`, validando o recorte de micro-negocio/presencial integrado ao modulo.
4. Consultar a visao combinada `wallets` -> `transactions` -> `financial_goals` -> `plug_transactions`, validando dashboard financeiro sem NoSQL proprio.
5. Ler `business_rule_definitions` para `BR-FIN-002` e confirmar que a regra de ring-fence financeiro esta registrada e versionada no plano de controle.

Observacao: este status deixou de ser apenas inicial e agora registra a primeira revisao tecnica do modulo.
