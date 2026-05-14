<!--
PROPOSITO: Definir o motor de curadoria de produtos dropshipping do Valley.
CONTEXTO: Este documento orienta fontes, comparadores, criterios de aprovacao e restricoes operacionais.
REGRAS: Aprovar produtos apenas com dados permitidos, margem defensavel e fornecedor legalmente integrado.
-->

# Dropshipping Product Curation Engine

## Escopo

Fontes de origem:

- CJ Dropshipping
- Alibaba
- AliExpress

Marketplaces de comparacao:

- Mercado Livre
- Shopee
- Magalu
- Amazon
- AliExpress

Marketplaces de comparacao nao sao fornecedores de dropshipping nesta rotina. Eles so entram quando houver API oficial, feed autorizado, webhook, conector homologado ou provedor de dados legalmente permitido.

## Regra de aprovacao

Um produto e aprovado somente quando:

- `APPROVED_NO_COMPETITION`: nenhum concorrente confiavel foi encontrado; ou
- `APPROVED_PRICE_ADVANTAGE`: `final_customer_cost_brl <= menor_preco_concorrente * 0.90`.

Produto sem vantagem de pelo menos 10% e marcado como `REJECTED_PRICE_NOT_COMPETITIVE`.
Produto com risco regulatorio ou baixa confianca vai para rejeicao ou revisao manual.

## Jobs

- `SYNC_SUPPLIER_CATEGORIES`
- `MAP_CATEGORIES_TO_GOOGLE`
- `IMPORT_SUPPLIER_PRODUCTS`
- `NORMALIZE_PRODUCTS`
- `CALCULATE_LOCAL_COMMERCE_SCORE`
- `COMPARE_MARKETPLACES`
- `CALCULATE_FINAL_PRICE`
- `APPROVE_OR_REJECT_PRODUCTS`
- `EXPAND_CATEGORY_SEARCH`
- `EXPORT_GOOGLE_FEED`

## Artefatos locais

- `tmp/runtime/valley-dropshipping-source-categories.json`
- `tmp/runtime/valley-dropshipping-product-candidates.json`
- `tmp/runtime/valley-dropshipping-eligible-products.json`
- `tmp/runtime/valley-dropshipping-selection-status.json`

## Modo seguro

Chamadas reais devem ser habilitadas por variaveis `VALLEY_DROPSHIPPING_ENABLE_REAL_*` e `VALLEY_MARKETPLACE_ENABLE_REAL_*`.
Sem credencial, permissao, escopo ou endpoint oficial, o conector registra `dados_insuficientes` e continua com os demais provedores.

Scraping nao autorizado e bloqueado por politica.

## Paginacao, limites e quota

A rotina trabalha apenas dentro dos limites oficiais de cada API.

- Suporta paginacao por `page/limit` e por `cursor`.
- Persiste checkpoint por fornecedor, categoria, filtro e pagina/cursor em `tmp/runtime/valley-dropshipping-api-checkpoints.json`.
- Retoma automaticamente do checkpoint depois de falha.
- Divide cargas por filtros oficiais aceitos: categoria, subcategoria, faixa de preco, data de atualizacao, pais, warehouse, estoque, avaliacao e pedidos minimos.
- A meta de 1.000 itens por categoria e meta de candidatos analisados, nao limite de uma chamada.
- Se a API limitar o volume, gera `tmp/runtime/valley-dropshipping-quota-escalation-report.json` com fornecedor, endpoint, limite encontrado e recomendacao de pedir quota, acesso parceiro, endpoint bulk ou feed oficial.

## Rate limiter

Existem classes dedicadas para cada conector:

- `CJDropshippingConnectorRateLimiter`
- `AlibabaConnectorRateLimiter`
- `AliExpressConnectorRateLimiter`
- `MercadoLivreConnectorRateLimiter`
- `ShopeeConnectorRateLimiter`
- `MagaluConnectorRateLimiter`
- `AmazonConnectorRateLimiter`

Cada limiter aplica:

- limites por minuto, hora e dia;
- leitura de headers de rate limit;
- respeito a `Retry-After`;
- exponential backoff com jitter;
- circuit breaker;
- limite maximo de retries para evitar loop infinito.

## Cache

Cache local seguro em `tmp/runtime/valley-dropshipping-api-cache.json`:

- categorias: 7 dias;
- produto: 24 horas;
- estoque: 1 a 6 horas;
- preco fornecedor: 1 a 6 horas;
- preco concorrente: 1 a 12 horas;
- compliance: 30 dias, salvo alteracao manual.
