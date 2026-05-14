<!--
PROPOSITO: Consolidar a visao institucional e tecnica do ecossistema Valley.
CONTEXTO: Este documento resume modulos, dominios, contratos, pacotes de entrega e eixo transacional.
REGRAS: Manter metricas rastreaveis, atualizar evidencias ao mudar contratos e evitar linguagem obsoleta.
-->

# Valley Vision

## Executive Snapshot

Valley ja passou da fase de catalogo disperso. O repositorio hoje revela um ecossistema hibrido orientado por contratos, com um nucleo transacional relacional forte e uma malha de modulos, backlog e pacotes de dominio pronta para execucao incremental.

O estado institucional atual pode ser resumido assim:

- 47 modulos distribuidos em 9 dominios.
- 11 modulos foundation, 21 core, 14 expansion e 1 frontier.
- 22 modulos com data home principal em Postgres, 13 em Postgres+Mongo e 12 em Mongo.
- 38 modulos em `VALIDATE`, 5 em `DATA_CONTRACT` e 4 em `BUILD`.
- 141 topicos de evento, 141 itens de backlog, 141 conjuntos de superficie admin/compliance.
- 7 dos 9 dominios ja empacotados em artefatos fisicos de entrega.
- 38 dos 47 modulos ja cobertos por `domain_delivery_packages`.
- 21 artefatos de pacote ja existem no filesystem (`ddl_complement`, `operational_seed`, `event_contract`).

O eixo real do Valley nao e apenas "47 modulos". E a combinacao entre:

`users -> wallets -> orders/transactions/equity -> tabelas de dominio -> documentos/auditoria -> pacotes de dominio -> contratos de evento`

Essa cadeia ja esta materializada no repo e deve ser tratada como a arquitetura institucional de referencia.

## Macroarquitetura

### 1. Spine institucional

O spine do ecossistema esta ancorado em quatro superficies compartilhadas:

- `users`: identidade canonica, KYC/KYB, PF/PJ/RIDER, LED card e ownership universal.
- `wallets`: cofre operacional para BRL e NEX, com ownership por `user_id`.
- `orders`: pedido mestre multi-dominio para Food, Move, Dropship e extensoes core.
- `transactions` e `equity_ledger`: ledger financeiro append-only e smart equity com cap de 1M NEX.

Qualquer modulo com dinheiro, prova juridica, atendimento, corrida, entrega, booking ou monetizacao orbita esse spine.

### 2. Motores transacionais

O Valley opera hoje com cinco motores institucionais:

1. Motor de identidade e confianca
   Base: `001_core_identity_wallets.sql`
   Superficies: `users`, `pj_profiles`, `rider_profiles`, `wallets`, `led_cards`
   Papel: ownership, KYC/KYB, perfis operacionais e identidade fisica.

2. Motor financeiro e de pedidos
   Base: `002_financial_ledger_equity_orders.sql`
   Superficies: `orders`, `transactions`, `equity_ledger`
   Papel: ledger atomico, split, escrow, P2P, compras, payout e equity.

3. Motor de governanca e controle
   Base: `004_v47_control_plane_modules_rules.sql`, `007_v47_module_delivery_automation.sql`, `015`, `016`, `017`
   Superficies: `module_catalog`, `module_delivery_registry`, `module_evolution_backlog`, `domain_delivery_packages`, `domain_event_contracts`, regras versionadas, auditoria admin.
   Papel: transformar catalogo em backlog executavel e pacote rastreavel.

4. Motores de dominio
   Base: `005`, `008`, `009`, `011`, `012`, `013`, `014`, `018-023`
   Papel: especializar o nucleo em commerce, legal, city ops, health/services, assets, growth e delivery fisico por dominio.

5. Motor de contratos de evento
   Base: `contracts/events/priority-domains/*.json`
   Papel: alinhar produtor, consumidor, evidencia, compliance e schema pragmatico por topico.

### 3. Camadas fisicas

O repo ja sugere uma pilha fisica clara:

| Camada | Papel | Artefatos principais |
| --- | --- | --- |
| L0 Core Spine | identidade, wallet, order, tx, equity | `database/postgres/001`, `002` |
| L1 Control Plane | modulos, backlog, regras, auditoria, pacotes | `004`, `007`, `015`, `016`, `017` |
| L2 Domain DDL | contratos relacionais por dominio | `005`, `008`, `009`, `011`, `012`, `013`, `014`, `018-023` |
| L3 Operational Seeds | seeds e manifests por pacote prioritario | `database/seeds/postgres/002_v47_priority_domain_delivery_packages_seed.sql`, `database/domain-delivery/priority-domains/*` |
| L4 Event Fabric | contratos JSON por dominio | `contracts/events/priority-domains/*.json` |

Mongo ja esta definido no desenho institucional via `data_home`, `mongo_collections` dos blueprints e contratos de evento, mas a trilha relacional esta mais avancada que a trilha institucional de colecoes.

### 4. Split hibrido

O papel de cada engine esta coerente com o que o repo mostra:

- Postgres: identidade, dinheiro, contratos, pedidos, corrida, entrega, governanca, compliance, documentos, rule engine.
- Mongo: memoria AI, feed social, video, metricas de creator, telemetria, sensores, tracking bruto.
- Postgres+Mongo: dominios que precisam de estado oficial e volume operacional ao mesmo tempo.

Em termos de maturidade institucional, o Valley ja esta "contract-first" no Postgres e "blueprint-first" no Mongo.

## Mapa de dominios

| Dominio | Papel institucional | Modulos | Estado de pacote |
| --- | --- | --- | --- |
| `platform_developer` | infraestrutura de API, docs, recibos e integracoes | `TECH`, `DOCS` | pacote prioridade 1, `READY`, 6 contratos |
| `logistics_erp_operations` | ERP, WMS, procurement, tracking, food, delivery e fleet | `BUSINESS`, `REPLY`, `STOCK`, `LOG`, `FOOD`, `WMS`, `DELIVERY`, `FLEET` | pacote prioridade 1, `READY`, 24 contratos |
| `commerce_fintech_assets` | wallet, marketplace, plug, afiliacao, PFM e ativos | `MARKETPLACE`, `PAY`, `PLUG`, `UP`, `FINANCAS`, `DIGITAL`, `REAL_ESTATE`, `INSURANCE` | pacote prioridade 2, `READY`, 24 contratos |
| `ai_memory_operations` | agenda, memoria, consentimento e advisor | `ADVISOR`, `AGENDA`, `CHAT` | pacote prioridade 2, `READY`, 9 contratos |
| `media_social_growth` | social, creators, ads, media e gaming | `INFLUENCERS`, `SOCIAL`, `MEDIA`, `ADS`, `NEWS_PODCAST`, `GAMING` | pacote prioridade 2, `READY`, 18 contratos |
| `city_mobility_security` | legal, eventos, mobility, security, tourism, gov | `LEGAL`, `EVENTS`, `MOBILITY`, `SECURITY`, `TOURISM`, `GOV` | pacote prioridade 2, `READY`, 18 contratos |
| `frontier_iot_energy` | IoT, home, energy, bio, space | `IOT`, `BIO`, `HOME`, `ENERGY`, `SPACE` | pacote prioridade 2, `READY`, 15 contratos |
| `services_health_human` | services, health, pharmacy, mente, vet, fitness | `SERVICES`, `HEALTH`, `FITNESS`, `PHARMACY`, `VET`, `MENTE` | ainda sem pacote institucional |
| `education_work_social` | edu, jobs, charity | `EDU`, `JOBS`, `CHARITY` | ainda sem pacote institucional |

Leitura pragmatica:

- Os 7 dominios empacotados ja formam a primeira malha operacional do ecossistema.
- Os 2 dominios sem pacote ainda existem no registry, nos blueprints e no backlog, mas nao entraram no circuito formal de `domain_delivery_packages`.
- Esse gap de empacotamento concentra 9 modulos e 27 itens de backlog.

## Dependencias criticas

Os hubs reais do ecossistema sao visiveis no grafo de dependencias:

- `PAY` recebe 21 dependencias de outros modulos. E o principal hub economico do Valley.
- `ID` recebe 17 dependencias. E o principal hub de ownership, identidade e habilitacao.
- `HEALTH`, `LOG`, `IOT`, `LEGAL` e `AI` aparecem como pontes setoriais.

As dependencias que mais importam para a visao institucional sao:

1. `ID -> users`
   Sem identidade canonica nao existe ownership confiavel para PF, PJ, rider, health, legal ou social.

2. `PAY -> wallets/orders/transactions`
   Quase toda monetizacao relevante converge para esse caminho.

3. `LEGAL + DOCS`
   Sao a malha de prova, assinatura, checksum e disputa para contratos, eventos, claims e auditoria.

4. `module_delivery_registry + module_evolution_backlog`
   Sao o ponto de verdade da execucao institucional. Sem eles o repo volta para backlog informal.

5. `domain_delivery_packages + domain_event_contracts`
   Sao o mecanismo que transforma blueprint em entrega rastreavel por dominio.

6. `append-only surfaces`
   Financeiro, juridico, farmacia, ingressos, service booking, delivery events, trip checkpoints e auditoria admin ja estao sendo tratados como trilhas imutaveis. Isso precisa continuar como regra de ecossistema, nao como excecao local.

## Plano por ondas

### Onda 0 - Spine e governanca

Escopo:

- `001`, `002`, `004`, `007`, `015`, `016`, `017`
- identidade, wallet, orders, transactions, equity, registry, backlog, pacotes, contratos

Leitura:

- Esta onda ja esta institucionalmente montada.
- O trabalho agora nao e redesenhar o spine; e operar em cima dele.

### Onda 1 - Pacotes prioridade 1

Escopo:

- `platform_developer`
- `logistics_erp_operations`

Modulos:

- 10 modulos
- 30 itens de backlog
- 30 entregaveis de evento/admin/compliance

Objetivo:

- fechar `DATA_CONTRACT` em `DOCS`, `BUSINESS` e `FOOD`
- estabilizar `TECH`, `REPLY`, `STOCK`, `LOG`, `WMS`, `DELIVERY`, `FLEET`
- transformar pacote `READY` em pacote operacionalmente comprovado

### Onda 2 - Pacotes prioridade 2

Escopo:

- `commerce_fintech_assets`
- `ai_memory_operations`
- `media_social_growth`
- `city_mobility_security`
- `frontier_iot_energy`

Modulos:

- 28 modulos
- 84 itens de backlog
- 84 contratos/eventos

Objetivo:

- tirar modulos `BUILD` do limbo e coloca-los em contrato congelado
- ligar dominios hibridos ao spine financeiro, juridico e de observabilidade
- reduzir o gap entre blueprint/Mongo e operacao/Postgres

### Onda 3 - Gap institucional de empacotamento

Escopo:

- `services_health_human`
- `education_work_social`

Modulos:

- 9 modulos
- 27 itens de backlog

Objetivo:

- criar `domain_delivery_packages` para os 2 dominios faltantes
- gerar `ddl_complement`, `operational_seed` e `event_contract` para ambos
- alinhar `SERVICES`, `HEALTH`, `PHARMACY`, `MENTE`, `JOBS`, `EDU`, `CHARITY` ao mesmo padrao dos dominios ja priorizados

### Onda 4 - Release governance

Escopo:

- migrar de `READY` para `MATERIALIZED`
- migrar de `DATA_CONTRACT/BUILD/VALIDATE` para `DOCUMENT/RELEASE/EVOLVE`

Objetivo:

- pacote com evidencia
- topico com produtor e consumidor reais
- regra com auditoria
- incidente com runbook
- criterio de aceite ligado ao `evidence_hint`

## Readiness

Para o Valley, readiness nao deve significar apenas "DDL existe". O modulo ou dominio esta pronto quando atravessa estes gates:

| Gate | O que precisa existir |
| --- | --- |
| Ownership | `user_id` explicito e coerente em toda superficie oficial |
| Monetary Path | se ha valor, ha `wallet_id` e caminho para `orders` e/ou `transactions` |
| Contract | topicos, producer, consumer, evidence entities e compliance tags definidos |
| Operations | admin surfaces, backlog keys, acceptance criteria e evidencias objetivas mapeadas |
| Audit | append-only em trilhas financeiras, juridicas, clinicas, de ticketing ou de seguranca |
| Package | `ddl_complement`, `operational_seed` e `event_contract` registrados |
| Release | backlog resolvido, pacote materializado, observabilidade e governanca ligadas |

Modelo de maturidade recomendado:

- `MAPPED`: modulo presente em registry, blueprint e backlog.
- `CONTRACT_READY`: eventos, entidades e compliance definidos.
- `PACKAGE_READY`: artefatos fisicos registrados e gerados.
- `VALIDATED`: coerencia, triggers, ownership e trilhas append-only comprovados.
- `RELEASE_READY`: pacote materializado, evidencias aceitas e consumidores ativos.

## Metricas de progresso

As metricas que melhor representam o progresso institucional hoje sao:

- cobertura de modulos por dominio empacotado: `38/47`
- cobertura de dominios por pacote institucional: `7/9`
- cobertura de backlog em trilha formal: `114/141` itens ja dentro dos pacotes priorizados
- cobertura de contratos fisicos: `114` topicos ja exportados em JSON por dominio
- densidade do spine: `PAY` com 21 dependencias de entrada e `ID` com 17
- pressao de execucao: 4 modulos ainda em `BUILD` e 5 em `DATA_CONTRACT`

Se for preciso um painel unico para acompanhar readiness, eu usaria estes KPIs:

1. `% de modulos com package_key`
2. `% de backlog com evidencia validavel`
3. `% de modulos com fase >= VALIDATE`
4. `% de topicos com contrato JSON materializado`
5. `% de fluxos sensiveis cobertos por append-only`
6. `% de dominios com pacote em status MATERIALIZED`

## Leitura executiva final

Valley hoje ja tem uma espinha institucional utilizavel:

- o nucleo financeiro/identitario esta definido
- o control plane esta definido
- os blueprints e o backlog estao sincronizados
- 7 dominios ja entraram no circuito formal de pacotes e contratos

O principal gap nao e desenho de modulo. E fechamento institucional de duas frentes:

1. empacotar `services_health_human` e `education_work_social`
2. promover os pacotes atuais de `READY` para execucao com evidencia e materializacao real

Enquanto isso nao acontecer, o ecossistema existe tecnicamente, mas ainda nao existe como trilha operacional completa de 9 dominios.
