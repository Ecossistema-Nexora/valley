# Helena Master Spec - Implementation Notes

Escopo: localizar as duas lacunas do spec da Helena com o menor impacto possivel, sem editar DDL principal ainda.

## 1) `users.birth_city` / `users.birth_state`

### Melhor ponto de implementacao

- `database/postgres/001_core_identity_wallets.sql:20-46`
- Inserir os campos dentro do `CREATE TABLE users`, perto de `birth_date` e antes de `document_country` ou logo apos `birth_date`.
- Motivo: este arquivo e o nucleo absoluto de identidade; qualquer dado de perfil que ajude a Helena a variar sotaque deve viver aqui.

### Colunas recomendadas

- `birth_city TEXT NULL`
- `birth_state CHAR(2) NULL`

### Constraints recomendadas

- `CHECK (birth_city IS NULL OR btrim(birth_city) <> '')`
- `CHECK (birth_state IS NULL OR birth_state ~ '^[A-Z]{2}$')`

### Indexes

- Nenhum index e obrigatorio no primeiro corte.
- Se o uso vier a filtrar usuarios por regiao natal em dashboard ou segmentacao, considerar:
  - `CREATE INDEX ix_users_birth_state ON users (birth_state) WHERE birth_state IS NOT NULL;`
- Nao vejo necessidade de index por `birth_city` neste momento.

### Comentarios nativos

- `database/postgres/003_database_comments_ptbr.sql:32-47`
- Adicionar comentarios logo apos `users.birth_date` e `users.ops_region_code`, para manter a documentacao do core coerente.

### Risco de seed/migration

- Baixo, se as colunas entrarem como `NULL` sem `NOT NULL`.
- Os seeds encontrados usam listas explcitas de colunas em `INSERT INTO users`, entao novas colunas opcionais nao quebram a carga atual.
- Risco sobe apenas se houver tentativa de preencher `birth_state` com valores fora de ISO-2 ou `birth_city` em branco por import legado.

## 2) Regra operacional de competitividade de 10%

### Melhor ponto de implementacao

- `database/postgres/010_v47_rule_growth_marketplace_runtime.sql:708-738`
- O melhor lugar e estender `assert_listing_control_coherence()`, porque:
  - ela ja valida dono do listing;
  - ela ja valida o binding `MARKETPLACE`;
  - ela ja e o gatilho canonico em `trg_marketplace_listing_controls_coherence`.

- Trigger existente:
  - `database/postgres/010_v47_rule_growth_marketplace_runtime.sql:1235-1238`

### Abordagem de menor impacto

- Nao criar nova tabela.
- Nao adicionar `CHECK` de 10% no schema, porque a regra depende de dados externos variaveis e snapshots recentes.
- Reaproveitar `marketplace_listing_controls` como estado decisorio:
  - `pricing_status`
  - `minimum_price_brl`
  - `last_market_reference_brl`
  - `last_competitor_name`
  - `auto_publish_enabled`
  - `publish_block_reason`

### Comportamento recomendado da regra

- Calcular a referencia com os concorrentes de benchmark:
  - `Mercado Livre`
  - `Amazon`
  - `Magalu`
- Basear a decisao no menor preco observado entre esses benchmarks.
- Exigir que `listing.price_brl` ou `minimum_price_brl` seja pelo menos 10% menor que o menor benchmark para marcar como competitivo/publicavel.
- Se nao houver evidencias suficientes, o comportamento mais robusto e:
  - manter `pricing_status = 'MANUAL_REVIEW'` ou `NON_COMPETITIVE`;
  - preencher `publish_block_reason`;
  - nao explodir a transacao com excecao, exceto quando a publicacao automatica estiver explicitamente sendo tentada.

### Helper function opcional

- Se quiser evitar inflar `assert_listing_control_coherence()`, a menor extracao limpa seria uma funcao auxiliar logo abaixo dela, ainda no mesmo arquivo:
  - `assert_listing_competitiveness_10pct()`
- Isso preserva o trigger existente e deixa a validacao de preco isolada.

### Indexes

- Os indexes atuais ja ajudam bastante:
  - `ix_marketplace_listing_controls_merchant_status` em `merchant_user_id, pricing_status, updated_at`
  - `ix_marketplace_listing_controls_checked_at` em `last_checked_at`
  - `ix_marketplace_competitor_snapshots_listing_time` em `listing_id, captured_at`
  - `ix_marketplace_competitor_snapshots_item_competitor` em `item_id, competitor_name, captured_at`
- Index novo so faz sentido se a consulta da regra for por `listing_id` + `competitor_name` em volume alto.
- Se precisar otimizar depois, o candidato seria um partial index em `marketplace_competitor_snapshots` filtrado para os tres benchmarks, mas eu nao faria isso agora.

### Comentarios nativos

- `database/postgres/010_v47_rule_growth_marketplace_runtime.sql:1369-1484`
- Se a regra for implementada, vale comentar claramente que o gatilho faz a decisao de competitividade e que os benchmarks de referencia sao os tres nomes fixos do spec da Helena.

### Risco de seed/migration

- O seed atual encontrado para commerce preenche `marketplace_listings`, mas eu nao vi carga de `marketplace_listing_controls` ou `marketplace_competitor_snapshots` no conjunto inspecionado.
- Portanto, a regra precisa tolerar estado inicial `DRAFT` sem snapshots, ou os seeds futuros vao quebrar.
- Evitar transformar a regra em constraint dura no schema, porque isso complica imports, reprocessamento e backfill.
- Se houver jobs de backfill antigos, eles precisam gravar snapshots antes de promover `pricing_status`.

## Caminho pratico sugerido

1. Primeiro patchar `users` com `birth_city`/`birth_state` e comentarios.
2. Depois estender `assert_listing_control_coherence()` para chamar a logica de competitividade.
3. Se a funcao crescer demais, extrair helper no mesmo arquivo.
4. Nao mexer em seeds agora; so validar que a logica nova nao exige snapshots na criacao de listings em estado inicial.

