<!--
PROPOSITO: Documentar README no escopo operacional do Valley.
CONTEXTO: Este arquivo registra orientacoes, decisoes ou plano associado ao caminho MANUAL_ONLINE/README.md.
REGRAS: Manter informacao rastreavel, preservar nomenclatura Valley e atualizar ao mudar a rotina correspondente.
-->

# Manual Online - Valley Hybrid DB Bootstrap

Este manual e a fonte viva da documentacao tecnica do banco hibrido Valley.

Ele deve ser atualizado sempre que qualquer schema, regra de banco, indice, trigger, validator ou script operacional for alterado.

O PDF em `output/pdf/VALLEY_MANUAL_ONLINE.pdf` e a versao derivada deste Markdown para leitura executiva e compartilhamento.

## Fonte de Verdade

A regra principal deste projeto e o `AGENTS` recebido nesta worktree Valley.

Os PDFs enviados servem como referencia semantica de produto, mas nao substituem o fluxo local de tres passos.

A estrategia adotada e `core-first`: primeiro blindar identidade, wallets, ledger, orders e NoSQL operacional.

Nao foi criada compatibilidade com `platform.users` ou multi-schema legado nesta entrega inicial.

## Mapeamento de Arquivos e Diretórios (Mandatório)

Para navegação técnica persistente (Estrutura Padronizada V2):

- **`/config`**: Registro canônico e blueprints.
    - `modules_v47.json`: Definição de todos os módulos.
    - `mvp/manifesto_mvp_v1.json`: Manifesto de execução do Produto Mínimo Viável.
- **`/docs`**: Documentação técnica e especificações.
    - `/design`: Blueprints de interface e fluxo (ex: `blueprint_stitch_v036.md`).
    - `/specs`: Propostas de produto e especificações mestras (ex: `proposta_frontend_final.md`).
- **`/database`**: Camada de persistência híbrida.
    - `migrations.json`: Grafo de execução.
- **`/scripts`**: Motores de automação.
    - `automacao_sincronizador_modulos.py`: Builder de módulos e sincronização de registry.
    - `automacao_gerador_pdf.py`: Gerador de documentação executiva.
    - `valley_db_orchestrator.py`: Runner de banco de dados.
- **`/frontend`**: Aplicação Flutter.
    - `valley_home_shell.dart`: UI Principal.
- **`/modules`**: Artefatos gerados por módulo (README/CONTRACT/STATUS).
- **`/output`**: Relatórios de status e PDF gerado.


## Arquivos Gerados

`database/postgres/001_core_identity_wallets.sql` cria o nucleo relacional de identidade e carteiras.

Esse arquivo define `users`, `pj_profiles`, `rider_profiles`, `wallets` e `led_cards`.

Ele tambem cria enums, chaves estrangeiras, indices, checks e triggers para coerencia de perfil e posse de carteira/cartao.

`database/postgres/002_financial_ledger_equity_orders.sql` cria o motor transacional.

Esse arquivo define `orders`, `transactions` e `equity_ledger`.

Ele tambem cria os enums de transacao, pedidos e equity, alem de triggers append-only para impedir `UPDATE` e `DELETE` em livros financeiros.

`database/mongodb/001_ai_social_telemetry.mongo.js` cria ou atualiza as colecoes NoSQL.

Esse arquivo define `ai_memory`, `social_videos`, `influencer_metrics` e `telemetry_logs` com JSON Schema Validation.

Ele tambem cria indices para IA, feed social, analytics de influenciador e telemetria geoespacial.

`database/postgres/003_database_comments_ptbr.sql` cria a camada de comentarios nativos do PostgreSQL.

Esse arquivo documenta tipos, tabelas, colunas, funcoes e triggers em portugues simples com termos tecnicos em ingles.

Ele deve ser executado depois dos scripts `001` e `002`.

`database/postgres/004_v47_control_plane_modules_rules.sql` implanta o plano de controle v47 viavel.

Esse arquivo cria catalogo de modulos, usuarios admin, permissoes, regras versionadas, auditoria, Loyalty, incidentes e registros de documentos.

Ele tambem popula os 41 modulos do mapeamento v47 e registra regras base de pricing, split, Ring-Fence e consentimento.

`database/postgres/005_v47_domain_tables_core_first.sql` implanta tabelas dominio v47 adaptadas.

Esse arquivo cria Advisor, metas financeiras, teleterapia, uploads, chat, invoices, payrolls, Plug, afiliados e receipts sem recriar schemas legados.

`database/postgres/006_v47_column_comments_ptbr.sql` documenta as colunas das implantacoes v47.

Esse arquivo adiciona comentarios nativos para campos, triggers e integracoes criadas pelos scripts `004` e `005`.

`database/postgres/007_v47_module_delivery_automation.sql` implanta a camada de delivery automation dos 47 modulos.

Esse arquivo e gerado automaticamente por `scripts/automacao_sincronizador_modulos.py` a partir de `config/modules_v47.json`.

Ele cria `module_delivery_registry`, `module_evolution_backlog` e `module_automation_runs` para controlar implantacao, desenvolvimento e evolucao.

`database/postgres/008_v47_foundation_commerce_operations.sql` implanta a camada operacional foundation de comercio e ERP.

Esse arquivo cria fornecedores, armazens, itens, lotes, movimentos append-only, listings, compras, linhas de compra, ordens de servico e contagens fisicas.

Ele cobre os primeiros contratos especificos dos modulos `REPLY`, `STOCK`, `WMS` e `MARKETPLACE`.

`database/mongodb/002_v47_log_iot_foundation.mongo.js` implanta a camada NoSQL foundation para tracking e sensores.

Esse arquivo cria validators e indices para `log_tracking_events`, `iot_device_registry`, `iot_sensor_events` e `warehouse_sensor_snapshots`.

Ele cobre os primeiros contratos especificos dos modulos `LOG`, `IOT` e snapshots operacionais do `WMS`.

`database/postgres/009_v47_tech_legal_platform_contracts.sql` implanta a camada foundation de plataforma developer e juridico.

Esse arquivo cria API clients, credenciais com hash, conectores, webhooks, tentativas append-only, contratos, partes, assinaturas append-only, disputas, eventos juridicos append-only e fallback PIN por hash.

Ele cobre os primeiros contratos especificos dos modulos `TECH` e `LEGAL`.

`database/postgres/010_v47_rule_growth_marketplace_runtime.sql` implanta o runtime comercial e de growth da arquitetura Valley.

Esse arquivo cria bindings e trilha do Rule Engine, storefronts, zonas de atendimento, controles de competitividade, snapshots de concorrencia, contas/ledger de Pepitas, campanhas GOLD e validacao de venda marketplace/fisica.

Ele cobre a evolucao operacional dos modulos `MARKETPLACE`, `ADS` e do motor de cashback gamificado conectado ao ecossistema.

`database/postgres/011_v47_city_ops_delivery_mobility_security.sql` implanta a camada relacional de city ops e seguranca.

Esse arquivo cria `delivery_shipments`, `delivery_shipment_events`, `mobility_trips`, `mobility_trip_events`, `security_trusted_contacts`, `security_biometric_credentials`, `security_incidents` e `security_incident_events`.

Ele cobre a evolucao operacional dos modulos `DELIVERY`, `MOBILITY` e `SECURITY`, mantendo biometria somente por hash e trilhas append-only de campo.

`database/postgres/012_v47_core_services_health_jobs_pharmacy_events.sql` fecha o tier core de servicos transacionais.

Esse arquivo cria perfis e bookings de `SERVICES`, perfis e planos de `HEALTH`, vagas e engagements de `JOBS`, catalogo e dispensacao de `PHARMACY` e programas/ingressos de `EVENTS`.

Ele tambem amplia `orders`, reforca ownership de wallet com trigger e cria trilhas append-only quando a prova operacional nao pode ser mutada.

`database/postgres/013_v47_expansion_assets_civic_impact.sql` abre a camada expansion do ecossistema.

Esse arquivo cria contratos para `DIGITAL`, `REAL_ESTATE`, `EDU`, `VET`, `GOV`, `CHARITY` e `INSURANCE`.

Ele adiciona colecoes e eventos de ativos, deals imobiliarios, trilhas educacionais, casos veterinarios, requests civicos, fundo social e claims securitarios com ledgers e trilhas append-only onde a prova exige imutabilidade.

`database/mongodb/003_v47_field_ops_security_agenda.mongo.js` implanta a camada NoSQL de dispatch, frota, sinais de seguranca e agenda.

Esse arquivo cria validators e indices para `delivery_dispatch_runs`, `fleet_vehicle_profiles`, `fleet_maintenance_events`, `security_signal_logs` e `agenda_items`.

Ele cobre a evolucao operacional dos modulos `DELIVERY`, `FLEET`, `SECURITY` e `AGENDA` sem empurrar payload de campo para o PostgreSQL.

`config/modules_v47.json` e o registry canonico dos 47 modulos.

Esse arquivo centraliza codigo, numero, dominio, tier, data home, dependencias, integracoes e descricao de cada modulo.

`modules/` contem uma pasta por modulo.

Cada pasta tem `README.md`, `STATUS.md` e `CONTRACT.md` gerados pela automacao.

O `README.md` explica finalidade, dependencias e trilha de implantacao.

O `STATUS.md` guarda checklist evolutivo.

O `CONTRACT.md` define a fronteira operacional do modulo, politica de dados, integracoes e regras de evolucao.

`output/module-roadmap/VALLEY_MODULE_ROADMAP.md` consolida a ordem de prioridade e o backlog macro dos 47 modulos.

`output/module-roadmap/VALLEY_MODULE_CONTRACTS.md` consolida a matriz tecnica dos contratos operacionais dos 47 modulos.

`MANUAL_ONLINE/DECISOES_IMPLANTACAO_V47.md` registra o que foi implantado, adaptado e descartado apos leitura dos PDFs.

Esse arquivo evita ambiguidade futura e protege o projeto contra retorno acidental ao multi-schema legado.

`MANUAL_ONLINE/01_ARQUITETURA_TECNICA_MICROSSERVICOS_EVENTOS.md` traduz o schema atual para boundaries de `microservices`, contratos sincronos e backbone de eventos.

`MANUAL_ONLINE/02_MODELAGEM_BANCO_DADOS.md` organiza a modelagem atual por dominio, aggregate root e ownership de dados.

`MANUAL_ONLINE/03_FLUXO_COMPLETO_APIS.md` descreve a superficie de APIs recomendada e os fluxos end-to-end mais importantes do produto.

`MANUAL_ONLINE/04_ROADMAP_IMPLEMENTACAO_SPRINTS.md` transforma o estado atual em backlog executivo e tecnico por sprint.

`scripts/automacao_gerador_pdf.py` gera o PDF do manual a partir deste Markdown.

Esse script usa `reportlab`, consolida todos os arquivos `.md` de `MANUAL_ONLINE` e deve ser executado novamente sempre que este manual mudar.

`scripts/automacao_sincronizador_modulos.py` automatiza o ciclo dos 47 modulos.

Esse script valida o registry, gera a documentacao por modulo, gera contratos operacionais, gera roadmap e gera a migration SQL de delivery automation.

`database/migrations.json` define a ordem oficial de aplicacao das migrations PostgreSQL e scripts MongoDB.

Esse manifesto evita execucao fora de ordem e e consumido por `scripts/valley_db_orchestrator.py`.

`scripts/valley_db_orchestrator.py` valida ambiente, manifesto, SQL, MongoDB e registry.

Esse script tambem aplica migrations via `psql`, `mongosh` ou Docker Compose quando o banco estiver disponivel.

`docker-compose.yml` define Postgres e Mongo locais para validacao runtime.

`.env.example` documenta as variaveis locais `DATABASE_URL`, `MONGODB_URI` e `VALLEY_AUTO_APPLY`.

`database/README.md` explica a organizacao da pasta de banco e o fluxo de validacao/aplicacao.

`MANUAL_ONLINE/OPERACAO_AUTONOMA.md` documenta a esteira autonoma atual, politica de descarte e fluxos Docker/local.

`output/deployment/VALLEY_DEPLOYMENT_STATUS.md` registra a ultima checagem operacional gerada pelo orquestrador.

## Atualizacao Release - Lote Core Health, Finance e Media

`HEALTH` agora esta tecnicamente revisado sobre `health_profiles`, `health_care_plans` e `health_prescriptions`, mantendo o master clinico no PostgreSQL e usando `ai_memory` apenas como contexto complementar de acompanhamento.

`FINANCAS` agora esta tecnicamente revisado sobre `financial_goals`, com integracao direta ao eixo `wallets` + `transactions` e protecao adicional da regra `BR-FIN-002` para ring-fence financeiro.

`MENTE` agora esta tecnicamente revisado sobre `teletherapy_sessions`, com notas cifradas, timeline validada e ponte opcional para planos de cuidado de `HEALTH`.

`UP` agora esta tecnicamente revisado sobre `affiliate_referrals`, `social_videos`, `influencer_metrics` e a regra `BR-UP-COMMISSION-001`, confirmando a fronteira entre afiliacao, atribuicao e repasse.

`MEDIA` agora esta tecnicamente revisado sobre `creator_uploads` e `social_videos`, sem abrir tabela redundante para pipeline editorial ou creator ops nesta fase.

## Passo 1 - Nucleo de Identidade e Wallets

`users` e o no central absoluto do ecossistema.

Toda entidade operacional deve referenciar `users.user_id` quando representar usuario, empresa, rider, admin ou sistema.

`pj_profiles` especializa usuarios do tipo `PJ`.

Essa tabela guarda dados empresariais, CNPJ, fiscal, responsavel legal e KYB.

`rider_profiles` especializa usuarios do tipo `RIDER`.

Essa tabela guarda disponibilidade, veiculo, habilitacao, zona operacional e score.

`wallets` e o cofre financeiro por usuario.

Essa tabela separa BRL e NEX, com checks para impedir mistura indevida de saldos.

`led_cards` liga identidade, wallet e cartao fisico/NFC.

Essa tabela protege unicidade de UID, serial NFC e tokenizacao.

## Passo 2 - Ledger Financeiro, Smart Equity e Orders

`orders` e a tabela mestre para Food, Move e Dropship.

Ela guarda valores, status, participantes, enderecos, pagamento e colunas reservadas para cada dominio.

`transactions` e o ledger financeiro operacional.

Ele registra P2P, compras, pagamentos, repasses, refunds, chargebacks, fees, splits e escrow.

`transactions` e append-only.

Qualquer correcao deve ser feita por novo lancamento compensatorio, nunca por edicao ou exclusao.

`equity_ledger` e o ledger de Smart Equity em token NEX.

Ele registra mint, allocate, transfer, lock, unlock, vest, burn, certificado e clausulas de drag/tag along.

`equity_ledger` tambem e append-only.

O trigger de supply impede que o total liquido de `MINT - BURN` ultrapasse `1_000_000.00000000` NEX.

## Passo 3 - MongoDB para IA, Social e Telemetria

`ai_memory` guarda memoria contextual da contexto Helena AI.

Ela integra cada memoria ao `user_id` relacional e registra escopo, contexto Helena, modulo de origem e consentimento.

`social_videos` guarda metadados do feed social.

Ela integra criador, dono operacional, links de comissao, produtos e contadores de engajamento.

`influencer_metrics` guarda snapshots de campanha.

Ela integra influencer, campanha, periodo, funil, vendas brutas e comissao.

`telemetry_logs` guarda eventos de alto volume.

Ela integra usuario, rider, device, evento, GeoJSON Point, sensor payload e correlation id.

## Politica de Comentarios

Todo novo arquivo deve explicar em portugues simples o que cada bloco tecnico faz.

Termos tecnicos devem manter o ingles tecnico quando forem padroes de plataforma, como `validator`, `index`, `trigger`, `foreign key`, `append-only`, `JSON Schema`, `GeoJSON`, `ledger` e `wallet`.

Novos schemas devem comentar campos, constraints e integracoes principais.

Novos scripts devem comentar comandos, entradas, saidas e dependencias.

Quando a explicacao linha a linha tornar o arquivo ilegivel, a regra minima e comentar cada campo, cada comando e cada bloco funcional.

No PostgreSQL, os comentarios permanentes ficam em `COMMENT ON`, pois eles acompanham o schema dentro do banco e podem ser lidos por ferramentas de admin.

No MongoDB, os comentarios ficam no script `.mongo.js`, ao lado de validators, campos e indices.

## Politica de Atualizacao Continua

Sempre que um arquivo de banco mudar, este manual deve ser atualizado no mesmo ciclo de trabalho.

Depois de atualizar o Markdown, o PDF deve ser regenerado em `output/pdf/VALLEY_MANUAL_ONLINE.pdf`.

O comando padrao para regenerar o PDF e:

```bash
python scripts/automacao_gerador_pdf.py
```

Se `reportlab` nao estiver instalado, instale a dependencia no ambiente Python antes de gerar o PDF.

## Ordem Recomendada de SQL

A ordem recomendada de aplicacao em PostgreSQL limpo e:

```bash
001_core_identity_wallets.sql
002_financial_ledger_equity_orders.sql
004_v47_control_plane_modules_rules.sql
005_v47_domain_tables_core_first.sql
003_database_comments_ptbr.sql
006_v47_column_comments_ptbr.sql
007_v47_module_delivery_automation.sql
008_v47_foundation_commerce_operations.sql
009_v47_tech_legal_platform_contracts.sql
010_v47_rule_growth_marketplace_runtime.sql
011_v47_city_ops_delivery_mobility_security.sql
012_v47_core_services_health_jobs_pharmacy_events.sql
013_v47_expansion_assets_civic_impact.sql
014_v47_expansion_tourism_bio_energy.sql
015_v47_module_blueprints_registry.sql
016_v47_execution_backlog_seed.sql
017_v47_priority_domain_delivery_packages.sql
018_v47_platform_developer_business_ddl.sql
019_v47_logistics_erp_operations_business_ddl.sql
020_v47_fix_tech_owner_coherence_trigger.sql
021_v47_fix_city_ops_trigger_ambiguity.sql
022_v47_city_mobility_security_business_ddl.sql
023_v47_commerce_fintech_assets_business_ddl.sql
024_v47_ai_memory_operations_business_ddl.sql
025_v47_media_social_growth_business_ddl.sql
026_v47_frontier_iot_energy_business_ddl.sql
027_v47_helena_identity_pricing_guardrails.sql
028_v47_module_catalog_42_47_seed.sql
029_v47_module_catalog_registry_aliases.sql
030_v47_fix_gold_campaign_reward_type_ambiguity.sql
031_v47_fix_pepita_account_status_ambiguity.sql
032_v47_mobility_production_schema.sql
033_v47_stock_dropshipping_production_blueprint.sql
```

O script `003` documenta objetos dos passos iniciais.

O script `006` documenta objetos v47 e precisa ser executado depois de `004` e `005`.

O script `007` depende de `004` e `005`, porque usa as funcoes de trigger e integra o delivery registry ao nucleo ja criado.

O script `008` depende de `007`, porque usa `module_delivery_registry` como catalogo canonico dos 47 modulos.

O script `009` depende de `008`, porque continua a esteira foundation e reutiliza `module_delivery_registry`, `document_records`, `orders`, `transactions` e `admin_users`.

O script `010` depende de `009`, porque fecha o runtime comercial usando Rule Engine, campaigns, listings, wallets e trilhas append-only ja existentes.

O script `011` depende de `010`, porque reutiliza `module_delivery_registry`, `orders`, `document_records`, `legal_disputes` e o runtime operacional ja consolidado.

O script `012` depende de `011`, porque reforca ownership de wallet, expande `orders` e reutiliza a base operacional ja consolidada.

O script `013` depende de `012`, porque reutiliza `orders`, `document_records`, `wallets`, `transactions` e contratos juridicos/operacionais do tier core.

O MongoDB deve aplicar `001_ai_social_telemetry.mongo.js`, depois `002_v47_log_iot_foundation.mongo.js`, depois `003_v47_field_ops_security_agenda.mongo.js` e por fim `004_v47_expansion_media_wellness_frontier.mongo.js`.

## Automacao Dos 47 Modulos

O ciclo padrao de automacao local e:

```bash
python scripts/automacao_sincronizador_modulos.py validate
python scripts/automacao_sincronizador_modulos.py sync
python scripts/automacao_sincronizador_modulos.py sql
python scripts/valley_db_orchestrator.py check
python scripts/valley_db_orchestrator.py report
python scripts/automacao_gerador_pdf.py
```

`validate` garante que existem exatamente 47 modulos numerados de 1 a 47.

`sync` cria ou atualiza `modules/<modulo>/README.md`, `modules/<modulo>/STATUS.md`, `modules/INDEX.md` e o roadmap.

`sync` tambem cria ou atualiza `modules/<modulo>/CONTRACT.md` e `output/module-roadmap/VALLEY_MODULE_CONTRACTS.md`.

`contracts` pode ser usado quando a alteracao desejada for apenas na camada de contratos operacionais.

`sql` gera `database/postgres/007_v47_module_delivery_automation.sql` a partir do registry.

`check` valida ambiente, manifesto, artefatos dos 47 modulos, SQL, MongoDB e registry sem exigir banco ativo.

`report` gera `output/deployment/VALLEY_DEPLOYMENT_STATUS.md` para registrar evidencias.

Depois disso, o PDF deve ser regenerado para manter a vertente executiva alinhada.

## Contratos Operacionais

Cada `CONTRACT.md` define a fronteira inicial de um modulo.

Ele existe para impedir que o desenvolvimento crie tabelas duplicadas, schemas legados ou integracoes sem ponte com `users.user_id`.

O contrato tambem registra quando usar PostgreSQL, MongoDB ou persistencia hibrida.

Os contratos nao substituem migration, teste ou regra de negocio.

Eles sao a camada de planejamento tecnico que vem antes de escrever schema especifico ou codigo de produto.

## Esteira De Implantacao

`database/migrations.json` e a ordem oficial de banco.

O orquestrador usa esse manifesto para validar e aplicar scripts.

O ambiente atual permite validacao estatica completa e leitura automatica de `.env` ou `.env.example`, mas a aplicacao runtime ainda depende de `psql`, `mongosh` ou Docker daemon ativo.

Quando Docker estiver pronto, o fluxo local e:

```bash
python scripts/valley_db_orchestrator.py apply-compose
python scripts/valley_db_orchestrator.py report
python scripts/automacao_gerador_pdf.py
```

Quando houver banco externo e as variaveis estiverem no ambiente ou em `.env`, o fluxo minimo e:

```bash
python scripts/valley_db_orchestrator.py apply-postgres
python scripts/valley_db_orchestrator.py apply-mongo
```

## Validacao Atual

Os scripts PostgreSQL foram revisados por validacao estatica do orquestrador.

Os artefatos `README.md`, `STATUS.md` e `CONTRACT.md` dos 47 modulos tambem foram validados pelo orquestrador.

O script MongoDB foi validado com `node --check`.

O registry dos 47 modulos foi validado por `scripts/automacao_sincronizador_modulos.py validate`.

O ultimo relatorio operacional fica em `output/deployment/VALLEY_DEPLOYMENT_STATUS.md`.

Nao houve execucao real em PostgreSQL porque `psql` nao esta instalado neste ambiente.

O script MongoDB foi escrito para `mongosh`, com `createCollection`, `collMod`, `JSON Schema Validation` e indices.

O PDF sera validado por leitura textual basica com `pypdf` depois da geracao.

## Sincronizacao Segura Mais Recente

Em `2026-04-24`, a esteira segura rodou `validate`, `sync`, `contracts`, `sql`, `check` e `report`.

Essa rodada confirmou `47` modulos validos, `33` migrations PostgreSQL e `4` scripts MongoDB no manifesto oficial.

Os arquivos sincronizados nessa rodada foram `admin/valley_admin_data.json`, `admin/valley_admin_data.js` e os pacotes `ddl_complement.sql` + `operational_seed.sql` dos dominios `platform_developer`, `logistics_erp_operations`, `ai_memory_operations`, `media_social_growth`, `city_mobility_security` e `commerce_fintech_assets`.

Os `ddl_complement.sql` desses dominios passaram a expor views operacionais ligadas ao registry tecnico: backlog prioritario, artefatos fisicos de delivery e contratos de evento.

Os `operational_seed.sql` dos mesmos dominios foram reduzidos ao seed canonico gerado pela automacao, evitando drift entre backlog, contratos e SQL manual.

O relatorio mais recente marcou `329` checagens e `4` pendencias reais de ambiente: `psql` ausente no `PATH`, `mongosh` ausente no `PATH`, `docker info` sem resposta em `30s` e `docker compose` interrompido por timeout.

## Evolucao Foundation Mais Recente

Os modulos `REPLY`, `STOCK`, `LOG`, `WMS` e `MARKETPLACE` passaram para `implemented_partial`.

`REPLY`, `STOCK`, `WMS` e `MARKETPLACE` receberam schema PostgreSQL especifico em `008_v47_foundation_commerce_operations.sql`.

`LOG` recebeu schema MongoDB especifico em `002_v47_log_iot_foundation.mongo.js`.

`IOT` foi expandido na mesma migration MongoDB com registry de devices e eventos de sensores.

## Evolucao TECH e LEGAL Mais Recente

Os modulos `TECH` e `LEGAL` passaram para `implemented_partial`.

`TECH` recebeu schema PostgreSQL especifico para API clients, credenciais por hash, conectores, webhooks e uso diario de API.

`LEGAL` recebeu schema PostgreSQL especifico para contratos, partes, assinaturas, disputas, eventos juridicos e fallback PIN por hash.

Credenciais, webhook secrets, IPs, device fingerprints e fallback PIN nao sao armazenados em texto bruto.

## Evolucao Rule Engine, Pepitas e Ads Mais Recente

Os modulos `MARKETPLACE` e `ADS` avancaram na camada operacional ligada a growth e validacao de venda.

`MARKETPLACE` recebeu storefronts, zonas de atendimento, controles de competitividade e snapshots append-only de concorrencia.

`ADS` recebeu campanhas `GOLD`, eventos append-only e validacao de venda com geolocalizacao, pedido ou POS.

O Rule Engine ganhou bindings runtime e trilha append-only de execucao, sem duplicar `business_rule_definitions` e `business_rule_versions`.

As `Pepitas` passaram a ter conta consolidada, cap de ate 50 por cento do lucro liquido por venda validada e ledger append-only.

## Evolucao City Ops, Fleet, Security e Agenda Mais Recente

Os modulos `DELIVERY`, `FLEET`, `SECURITY` e `AGENDA` passaram para `implemented_partial`.

`DELIVERY` recebeu camada relacional de shipments e trilha append-only de eventos, alem de camada NoSQL para dispatch e matching de riders.

`MOBILITY` foi aprofundado com trips relacionais, checkpoints append-only e coerencia forte com `orders`, `wallets` e `rider_profiles`.

`SECURITY` recebeu contatos confiaveis, incidentes, eventos append-only, sinais de alto volume e biometria persistida somente por hash.

`AGENDA` recebeu collection propria para lembretes, tarefas, follow-ups e sincronizacao com `ADVISOR` e `CHAT`.

## Evolucao Creator, Influencers, Advisor e Conteudo

`INFLUENCERS` ja pode operar sobre a pipeline compartilhada de `creator_uploads`, `social_videos`, `influencer_metrics` e `affiliate_referrals`, sem precisar de tabela exclusiva com nome do modulo.

`ADVISOR` ja tem camada hibrida real com `advisor_insights`, `financial_goals`, `teletherapy_sessions` e `ai_memory`, alem de integracao natural com `AGENDA` e `CHAT`.

`NEWS_PODCAST` continua `PLANNED` no registry, mas o MVP ja pode nascer sobre `creator_uploads`, `social_videos` e `document_records`, sem criar schema editorial paralelo antes da prova de produto.

