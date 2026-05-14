<!--
PROPOSITO: Registrar o blueprint de release da superficie lojista Valley.
CONTEXTO: Este documento orienta URL publica, APIs de produto/catalogo e gates do fluxo lojista.
REGRAS: Preservar runtime fixo, vitrine sem segredos de fornecedor e checkout funcional.
-->

# Valley Lojista Release Blueprint v034

## Escopo

- Superficie: painel lojista/produto Valley.
- URL publica fixa: `https://admin.brasildesconto.com.br/product`
- API do produto: `https://admin.brasildesconto.com.br/api/product-shell`
- API do catalogo STOCK: `https://admin.brasildesconto.com.br/api/stock-catalog`

## Release Gates

- `/product` deve servir o Flutter Web do produto.
- `/api/product-shell` deve retornar `public_runtime.provider=cloudflare_named_tunnel`.
- O resumo publico deve expor a vitrine sem chaves internas de fornecedor.
- O cadastro deve permitir perfil `MERCHANT` para fluxo lojista.
- Checkout, frete, minhas compras, notificacoes e compartilhamento devem continuar apontando para o runtime fixo.

## Estado v034

- `/api/product-shell` validado com `items=80` na vitrine e `summary.products=1089`.
- Catalogo embarcado `frontend/flutter/assets/data/valley_stock_runtime_ptbr.json` validado com `1089` itens.
- `customer_visible_supplier_name=Valley` preservado na superficie publica.
- Manifesto publico atualizado em `tmp/runtime/valley-product-web-publication.json`.

## Link De Entrega

`https://admin.brasildesconto.com.br/product`
