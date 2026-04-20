# Status - Valley Ads

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

- PostgreSQL: `database/postgres/010_v47_rule_growth_marketplace_runtime.sql` cobre a camada operacional do modulo com `rule_runtime_bindings`, `rule_execution_events`, `gold_campaigns`, `sale_validation_events`, `gold_campaign_events`, `pepita_accounts` e `pepita_ledger`.
- Semantica do modulo: a revisao confirma que `ADS` nasce primeiro pelo lado financeiro e auditavel, e por isso a primeira camada especifica ficou relacional, mesmo com `data_home = mongo` no registry. Isso e coerente porque budget, funding, validacao de venda e incentivo nao podem depender de payload eventual ou mutavel.
- Regras de negocio: este e um dos modulos em que as regras nao foram descartadas. Elas ja estao materializadas em `business_rule_definitions`, `business_rule_versions`, `rule_runtime_bindings` e `rule_execution_events`, com trilha append-only de decisao e correlacao por `module_code`.
- MongoDB especifico: `ADS` ainda nao abriu collection propria de impressao, clique, audiencia ou geofence. A decisao revisada e considerar essa parte descartada por enquanto, porque o que ja esta implantado e a espinha de funding, validacao e reward; telemetria/clickstream volumoso entra depois, possivelmente apoiado em `SOCIAL` e `LOG`.
- Integracao: `gold_campaigns` e `sale_validation_events` amarram merchant, wallet, storefront, zona, order, transaction e `telemetry_correlation_id`, o que fecha a ponte entre ads, marketplace e validacao no mundo fisico.
- Admin/RBAC/ABAC: o modulo herda controle por `module_catalog`, `admin_permissions` e `admin_action_audit`, suficiente para separar time comercial, growth e operacao de campanha.
- Manual/PDF: `MANUAL_ONLINE/README.md`, `MANUAL_ONLINE/01_ARQUITETURA_TECNICA_MICROSSERVICOS_EVENTOS.md`, `MANUAL_ONLINE/02_MODELAGEM_BANCO_DADOS.md`, `MANUAL_ONLINE/03_FLUXO_COMPLETO_APIS.md`, `MANUAL_ONLINE/04_ROADMAP_IMPLEMENTACAO_SPRINTS.md` e `MANUAL_ONLINE/OPERACAO_AUTONOMA.md` refletem o modulo. O PDF oficial foi regenerado apos esta revisao.

Plano minimo de testes de integracao:

1. Criar `gold_campaign` com `merchant_user_id`, `wallet_id`, `module_code = 'ADS'`, budget, janela de vigencia e metadados de segmentacao, validando ownership da wallet e budget split.
2. Criar `rule_runtime_binding` ligado a regra comercial e ao modulo `ADS`, depois registrar `rule_execution_event` com `correlation_id`, `decision_code` e snapshots de entrada/saida.
3. Registrar `sale_validation_event` com `gold_campaign_id`, `order_id`, `transaction_id`, `validation_source`, `gross_amount_brl` e `pepita_cap_brl`, validando prova de venda e correlacao com campanha.
4. Inserir `gold_campaign_event` e `pepita_ledger` para o usuario elegivel, confirmando append-only, cap financeiro e atualizacao da conta consolidada de Pepitas.
5. Tentar mutar ou deletar trilhas criticas de regra, campanha ou ledger quando houver trigger de imutabilidade, confirmando que a camada de growth fica auditavel para release.

Observacao: este status deixou de ser apenas inicial e agora registra a primeira revisao tecnica do modulo.
