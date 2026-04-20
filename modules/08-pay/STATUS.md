# Status - Valley Pay

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

- PostgreSQL: `database/postgres/001_core_identity_wallets.sql` materializa `wallets` como cofre por usuario, com `UUID`, controle de asset, saldo reconciliavel, `ledger_version` e ownership por `users.user_id`.
- Motor financeiro: `database/postgres/002_financial_ledger_equity_orders.sql` cobre `transactions` e `equity_ledger` como trilhas append-only com `foreign key` para `wallets`, `orders`, `users` e `transactions`, alem de triggers que bloqueiam `UPDATE` e `DELETE`.
- Cobertura complementar: `database/postgres/005_v47_domain_tables_core_first.sql` adiciona `plug_transactions`, fechando a extensao presencial/adquirencia do modulo sem quebrar o ledger central.
- MongoDB: `PAY` nao abriu collection propria. A decisao revisada e manter dinheiro, conciliacao, split, refund, equity e adquirencia no PostgreSQL por consistencia forte, descartando persistencia primaria em MongoDB nesta fase.
- Regras de negocio: nao existe, ate este ponto, definicao exclusiva de `PAY` em `business_rule_definitions`. A revisao considera isso aceitavel porque os invariantes atuais ja estao blindados por `check`, `foreign key`, triggers de ownership e trilha append-only; regras parametrizadas entram apenas quando houver limite dinamico, fee configuravel, antifraude ou politica regulatoria mutavel.
- Admin/RBAC/ABAC: o controle administrativo do modulo passa por `module_catalog`, `admin_permissions` e `admin_action_audit`, preservando segregacao entre operacao financeira, suporte e auditoria.
- Manual/PDF: `MANUAL_ONLINE/README.md`, `MANUAL_ONLINE/01_ARQUITETURA_TECNICA_MICROSSERVICOS_EVENTOS.md`, `MANUAL_ONLINE/02_MODELAGEM_BANCO_DADOS.md`, `MANUAL_ONLINE/03_FLUXO_COMPLETO_APIS.md`, `MANUAL_ONLINE/04_ROADMAP_IMPLEMENTACAO_SPRINTS.md` e `MANUAL_ONLINE/OPERACAO_AUTONOMA.md` cobrem o modulo. O PDF oficial foi regenerado apos as migrations financeiras usadas nesta revisao.

Plano minimo de testes de integracao:

1. Criar `wallet` BRL para um `user_id` valido e validar unicidade por combinacao `user_id + wallet_type + asset_code`, saldo inicial coerente e status ativo.
2. Executar `POST /v1/pay/wallets/bootstrap` no fluxo documentado e confirmar a criacao das wallets iniciais esperadas sem duplicar identidade nem ledger.
3. Inserir `transaction` em fluxo de authorize e settle com `order_id`, `wallet_id`, `counterparty_wallet_id` e `origin_module`, validando checks de valor, referencia unica e coerencia de ownership das wallets.
4. Inserir `equity_ledger` com `source_transaction_id`, `certificate_hash` e quantidade `$NEX`, confirmando append-only, coerencia com wallet do usuario e enforcement de evento societario.
5. Inserir `plug_transaction` vinculada a `transaction_id` e tentar executar `UPDATE` ou `DELETE` em `transactions`, `equity_ledger` e `plug_transactions`, validando o bloqueio da trilha financeira imutavel.

Observacao: este status deixou de ser apenas inicial e agora registra a primeira revisao tecnica do modulo.
