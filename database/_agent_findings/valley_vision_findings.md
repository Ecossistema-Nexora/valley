# Valley Vision - Findings

Fonte analisada:

- `docs/specs/valley_vision.md`

Escopo de comparacao:

- `database/README.md`
- `database/postgres/001_core_identity_wallets.sql`
- `database/postgres/002_financial_ledger_equity_orders.sql`
- `database/postgres/004_v47_control_plane_modules_rules.sql`
- `database/postgres/017_v47_priority_domain_delivery_packages.sql`
- `database/mongodb/001_ai_social_telemetry.mongo.js`
- `database/mongodb/002_v47_log_iot_foundation.mongo.js`
- `database/mongodb/003_v47_field_ops_security_agenda.mongo.js`

## Requisitos extraidos da visao

1. O spine institucional precisa continuar centrado em `users -> wallets -> orders/transactions/equity -> dominio -> documentos/auditoria -> pacotes -> contratos`.
2. Todo dado relacional de identidade, dinheiro, contratos, pedidos, corrida e prova operacional deve permanecer em PostgreSQL.
3. MongoDB deve concentrar memoria de IA, feed social, metricas de creators e telemetria/IoT.
4. `UUID` segue como PK e ponte de referencia entre engines.
5. BRL usa `DECIMAL(18,4)` e token V-Coin usa `DECIMAL(18,8)`.
6. Ledgers financeiros, equity e trilhas juridicas/operacionais criticas precisam ser append-only.
7. O catalogo de modulos, backlog e pacotes de dominio deve refletir os 47 modulos e os 9 dominios descritos na visao.
8. O roadmap pede previsao de campos e relacoes para evolucao futura, evitando retrabalho no core.

## O que o repo ja cobre bem

1. O core relacional esta bem alinhado em `database/postgres/001_core_identity_wallets.sql:20-247`.
   - `users`, `pj_profiles`, `rider_profiles`, `wallets` e `led_cards` existem.
   - Ha FK para `users` em todos os perfis e em `wallets`.
   - Existem validacoes de formato, status e ownership.

2. O motor transacional esta coerente em `database/postgres/002_financial_ledger_equity_orders.sql:59-613`.
   - `orders`, `transactions` e `equity_ledger` existem.
   - O padrao append-only ja esta aplicado em `transactions` e `equity_ledger`.
   - Ha guard rails de ownership entre wallet, user e asset.

3. O NoSQL base do roteiro principal esta pronto em `database/mongodb/001_ai_social_telemetry.mongo.js:42-269`.
   - As collections pedidas na visao existem: `ai_memory`, `social_videos`, `influencer_metrics` e `telemetry_logs`.
   - Os validators usam UUID string como ponte logica com Postgres.
   - Ha indices basicos para leitura por usuario, criador, campanha e device.

4. O repo ja tem extensao fisica de control plane e delivery registry em `database/postgres/004_v47_control_plane_modules_rules.sql` e `database/postgres/017_v47_priority_domain_delivery_packages.sql`.
   - Isso esta em linha com a visao de contratos, backlog e pacotes.

## Lacunas encontradas

1. O registry canonico de modulos ainda nao esta completo.
   - `database/postgres/004_v47_control_plane_modules_rules.sql:380-429` popula `module_catalog` ate o modulo 41.
   - A visao e o restante do repo falam em 47 modulos.
   - O gap afeta rastreabilidade, governanca e qualquer leitura automatica de cobertura por modulo.

2. O core relacional cobre o spine, mas nao explicita ainda alguns eixos estrategicos do dominio completo.
   - A visao menciona KYC/KYB, prova juridica, physical services, food/move/dropship e futura expansao por 23 modulos.
   - Parte disso existe espalhada em scripts posteriores, mas nao esta consolidada no nucleo inicial.
   - Para evitar retrabalho, o desenho do core deveria manter espacos reservados para campos nulos de extensao onde a evolucao futura ja e previsivel.

3. No Mongo, o conjunto base esta correto, mas a leitura operacional ainda e genérica.
   - `telemetry_logs` suporta volume e geoespacial, mas nao separa por tipo de agente ou topico de ingestao com particionamento nativo.
   - `social_videos` e `influencer_metrics` cobrem metadados e analytics, mas nao modelam explicitamente moderacao detalhada, trilha de decisao ou snapshots de ranking.
   - Isso nao quebra o roteiro principal, mas limita analytics e compliance mais finos.

4. O encaixe entre control plane e modules folder ainda merece sincronizacao.
   - O filesystem tem modulos alem do que `module_catalog` hoje anuncia.
   - Isso cria risco de drift entre blueprint, registry, backlog e entrega real.

## Recomendacoes acionaveis para o roteiro principal

1. Fechar o mismatch do catalogo de modulos.
   - Atualizar o registry para refletir os 47 modulos completos.
   - Garantir que os modulos 42-47 tenham linha canonica no control plane antes de qualquer nova expansao de schema.

2. Manter o core relacional "future-proof" sem mexer no contrato principal.
   - Reservar colunas nulas e FKs coerentes para extensoes que o roadmap ja antecipa.
   - Priorizar ownership por `user_id` em qualquer nova tabela relacional.

3. Refinar Mongo para cargas de alta variacao.
   - Considerar TTL e/ou indices adicionais em colecoes temporais.
   - Separar melhor trilhas de moderacao, snapshots e eventos brutos quando o volume crescer.

4. Continuar o padrao append-only onde ha prova operacional.
   - Financeiro, equity, legal, delivery, seguranca e auditoria devem permanecer imutaveis por trigger ou outra barreira equivalente.

5. Tratar `module_delivery_registry`, `domain_delivery_packages` e `domain_event_contracts` como fonte de verdade executavel.
   - A visao depende desse encadeamento para validar readiness real.

## Resumo curto

- O spine do banco ja esta bem desenhado.
- O Mongo base da visao tambem esta coberto.
- A lacuna mais importante e o desalinhamento numerico do `module_catalog` com os 47 modulos do projeto.
- O proximo passo estrategico e sincronizar registry, backlog e pacote de dominios antes de expandir novos schemas.

