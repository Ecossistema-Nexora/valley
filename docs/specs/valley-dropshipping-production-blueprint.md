<!--
PROPOSITO: Definir o blueprint de producao para dropshipping Valley.
CONTEXTO: Este documento orienta fornecedores, catalogo, pedidos, tracking, margem e conciliacao operacional.
REGRAS: Usar apenas integracoes autorizadas, preservar auditoria e nao expor fornecedor ao cliente final.
-->

# Valley Dropshipping Inteligente - Blueprint De Producao

## Objetivo

Implementar o dropshipping inteligente como subcamada de producao do `STOCK`, conectado a `WMS`, `MARKETPLACE`, `PAY`, `PLUG` e `DOCS`.

O modulo deve operar como hub de:

- importacao de produtos
- sincronizacao de estoque e custo
- automacao de pedidos com fornecedores
- cotacao de mercado em marketplaces
- reprecificacao automatica
- desativacao de produtos inviaveis
- operacao multi-tenant por merchant

## Integracoes Prioritarias

Fornecedores via API:

- AliExpress
- Alibaba
- CJDropshipping

Marketplaces para consulta competitiva:

- Mercado Livre
- Amazon
- Shopee
- Magalu

## Regras De Producao

1. Nunca vender com prejuizo.
2. Priorizar APIs oficiais.
3. Usar scraping apenas como fallback controlado.
4. Nao usar IA para consultas externas de preco, estoque ou fornecedor.
5. Cachear cotacoes externas para reduzir custo e latencia.
6. Registrar falhas, timeouts, origem da cotacao e score de matching.
7. Desativar automaticamente produto sem margem, sem estoque, com fornecedor inativo ou com falha recorrente.
8. Toda decisao de pricing deve ser auditavel e append-only.

## Componentes Do MVP

- `dropshipping_provider_configs`: configuracao segura de providers por merchant, sem segredo bruto.
- `dropshipping_product_sources`: vinculo entre item Valley e produto/variante no fornecedor.
- `dropshipping_market_price_snapshots`: snapshots append-only de precos externos.
- `dropshipping_pricing_decisions`: decisoes append-only de reprecificacao e pausa.
- `dropshipping_supplier_orders`: ponte entre pedido Valley e pedido no fornecedor.
- `dropshipping_jobs`: fila operacional para importacao, sync, pricing e tracking.

## Fluxo De Produto

1. Seller importa produto de AliExpress, Alibaba ou CJDropshipping.
2. `STOCK` normaliza produto, SKU, variacoes, imagens, custo, estoque, dimensoes e categoria.
3. `WMS` registra disponibilidade logica.
4. `MARKETPLACE` publica listing com identidade Valley.
5. Worker agenda pricing inicial e sincronizacao recorrente.

## Fluxo De Precificacao

1. Worker consulta Mercado Livre, Amazon, Shopee e Magalu por API oficial.
2. Fallback scraping so executa quando permitido por provider e quando a API falha.
3. Resultado e cacheado por TTL configurado.
4. Pricing Engine calcula preco minimo:

```text
preco_minimo = custo_fornecedor + frete + taxas + margem_minima
```

5. Se `preco_minimo > menor_preco_mercado`, produto entra em `AUTO_PAUSE`.
6. Caso contrario, preco Valley e atualizado para ficar competitivo sem prejuizo.
7. Decisao e salva em ledger append-only.

## Painel Admin

O admin deve expor, por provider:

- ativo/inativo
- ambiente sandbox/producao
- regiao/site
- modo de autenticacao
- base URL
- client/app key
- referencias de segredo
- access token ref
- refresh token ref
- seller/store ID
- webhook URL
- webhook secret ref
- escopos
- cadencia de sincronizacao
- cache TTL
- margem minima
- rotinas ativas de catalogo, pedidos, estoque e precos
- fallback scraping
- bloqueio de IA externa

Credenciais reais ficam fora do repositorio, referenciadas via vault/secret manager.

## Observabilidade

Metricas minimas:

- latencia por provider
- taxa de erro por provider
- produtos importados
- produtos pausados automaticamente
- decisoes de pricing por hora
- jobs em fila
- retries e DLQ
- pedidos enviados ao fornecedor
- divergencia de custo/estoque

## Resultado Esperado No MVP

O dropshipping entra no MVP como motor de oferta sem CAPEX, com margem protegida, catalogo amplo, operacao auditavel e base preparada para SaaS multi-tenant.
