# Helena Master Spec - Findings

Escopo: leitura do `C:\Users\ereta\Downloads\000 - VALLEY\helena_especificacao_mestra.md` e comparação com `database/`.

## Requisitos Extraidos

- Helena depende de identidade relacional em `users`, com personalizacao por cidade/estado de nascimento para variar o sotaque regional.
- O fluxo do Stock exige bloqueio de publicacao quando o preco final nao for pelo menos 10% menor que o menor preco entre Mercado Livre, Amazon e Magalu.
- O modelo precisa manter `users` e `wallets` como nodos centrais, com integracao relacional por `user_id` e tipagem monetaria padronizada em BRL e NEX.
- Logs financeiros e equity precisam permanecer append-only.
- O brain NoSQL precisa cobrir memoria de IA, feed social, metricas de influenciadores e telemetria.

## Comparacao Com O Repositorio

- O núcleo relacional ja existe em `database/postgres/001_core_identity_wallets.sql`, com `users`, `pj_profiles`, `rider_profiles`, `wallets` e `led_cards`.
- O motor transacional e de equity ja existe em `database/postgres/002_financial_ledger_equity_orders.sql`, com `transactions`, `equity_ledger` e `orders`.
- O motor de competitividade do Stock ja tem estrutura em `database/postgres/010_v47_rule_growth_marketplace_runtime.sql`, com `marketplace_listing_controls` e `marketplace_competitor_snapshots`.
- O NoSQL do brain ja existe em `database/mongodb/001_ai_social_telemetry.mongo.js`, com `ai_memory`, `social_videos`, `influencer_metrics` e `telemetry_logs`.
- Os demais arquivos de `database/` indicam que o projeto ja evoluiu para um ecossistema maior do que o spec da Helena, mas sem quebrar o requisito central de `users`/`wallets`.

## Lacunas Relevantes

1. `users` nao possui campos explicitos para `birth_city` e `birth_state`, que o spec da Helena usa para ajustar o sotaque natal.
2. O filtro de 10% do Stock parece suportado por snapshots e controles de preco, mas nao encontrei uma regra relacional canonica que fixe os benchmarks Mercado Livre/Amazon/Magalu nem a decisao automatica de bloqueio com esse threshold.
3. O spec da Helena depende de contexto de perfil para regionalismo; hoje o schema cobre `ops_region_code`, `birth_date` e contatos, mas nao o recorte natal pedido.
4. O brain NoSQL cobre o que foi pedido, mas as collections ainda estao genéricas para evolucao futura; falta contrato relacional explicito para ligar memoria/agenda ao comportamento de Helena por sotaque e preferencia.

## Recomendacoes Para O Roteiro Principal

- Priorizar uma extensao pequena em `users` para `birth_city` e `birth_state`, com validação simples de texto e indexacao se o uso operacional justificar.
- Amarrar a regra de competitividade do Stock a uma definicao canonica de benchmark/lista de concorrentes e a uma decisao de publicacao bloqueada, idealmente via trigger ou funcao de validacao no bloco 010.
- Manter o padrao append-only em `transactions` e `equity_ledger`, sem abrir excecoes de update/delete.
- Se o roteiro principal quiser materializar Helena como funcionalidade de produto, a proxima camada de valor esta em perfil de preferencia regional e consumo de contexto de memoria, nao em novas tabelas financeiras.

## Arquivos Consultados

- `database/README.md`
- `database/postgres/001_core_identity_wallets.sql`
- `database/postgres/002_financial_ledger_equity_orders.sql`
- `database/postgres/010_v47_rule_growth_marketplace_runtime.sql`
- `database/postgres/024_v47_ai_memory_operations_business_ddl.sql`
- `database/mongodb/001_ai_social_telemetry.mongo.js`


