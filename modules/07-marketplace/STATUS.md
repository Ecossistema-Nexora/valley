# Status - Valley Marketplace

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

- PostgreSQL: `database/postgres/008_v47_foundation_commerce_operations.sql` cobre `marketplace_listings` como contrato relacional do anuncio comercial, ligando `merchant_user_id`, `wallet_id`, `item_id` e `module_code` com `foreign key`, `check` de preco/comissao e triggers de ownership.
- Runtime comercial: `database/postgres/010_v47_rule_growth_marketplace_runtime.sql` fecha a camada especifica do modulo com `merchant_storefronts`, `merchant_service_zones`, `marketplace_listing_controls` e `marketplace_competitor_snapshots`, incluindo coerencia com `rule_runtime_bindings` e trilha append-only dos snapshots de concorrencia.
- Regras de negocio: o modulo nao precisa de tabela isolada de regra propria. A revisao confirma que a competitividade e a auto-publicacao ja ficam materializadas por `business_rule_definitions`, `rule_runtime_bindings`, `rule_execution_events` e `marketplace_listing_controls`, sem recriar schema paralelo por modulo.
- MongoDB: `MARKETPLACE` nao abriu collection propria. A decisao revisada e manter o estado operacional do catalogo e do pricing no PostgreSQL e deixar payload volumoso para modulos vizinhos, como `SOCIAL`, `LOG` e `DELIVERY`, quando houver feed, scraping bruto, tracking ou telemetria.
- Admin/RBAC/ABAC: o modulo herda a fronteira de controle por `module_catalog`, `admin_permissions` e `admin_action_audit`, o que permite segmentar operacao de merchant, growth e compliance por `module_code`.
- Manual/PDF: `MANUAL_ONLINE/README.md`, `MANUAL_ONLINE/01_ARQUITETURA_TECNICA_MICROSSERVICOS_EVENTOS.md`, `MANUAL_ONLINE/02_MODELAGEM_BANCO_DADOS.md`, `MANUAL_ONLINE/03_FLUXO_COMPLETO_APIS.md`, `MANUAL_ONLINE/04_ROADMAP_IMPLEMENTACAO_SPRINTS.md` e `MANUAL_ONLINE/OPERACAO_AUTONOMA.md` cobrem o modulo. O PDF oficial foi regenerado apos as migrations que sustentam esta revisao.

Plano minimo de testes de integracao:

1. Criar `merchant_storefront` com `merchant_user_id`, `wallet_id`, `storefront_code`, `supported_domains` e `service_modes`, validando ownership da wallet e codigo tecnico unico por merchant.
2. Criar `merchant_service_zone` para o storefront com `zone_geo_json`, `delivery_fee_brl`, `minimum_order_brl` e janela de ETA, validando geometria e faixa operacional.
3. Publicar `marketplace_listing` ligado a `inventory_item`, `wallet_id` e `module_code = 'MARKETPLACE'`, confirmando constraints de preco, comissao e quantidade.
4. Rodar fluxo de `price-check`, gravando `marketplace_listing_controls` e um `marketplace_competitor_snapshot`, validando binding de regra, referencia de mercado e bloqueio de `UPDATE`/`DELETE` no snapshot append-only.
5. Simular publicacao e venda validada com `sale_validation_events`, conectando listing, storefront, order e transaction para garantir que o marketplace consegue sair do browse para a prova comercial rastreavel.

Observacao: este status deixou de ser apenas inicial e agora registra a primeira revisao tecnica do modulo.
