# v033 - Gate Producao APK Cliente Catalogo 10k

## Resumo

- Corrigir o APK apos teste real fora da rede local para que a experiencia seja de produto final, sem mensagens de desenvolvimento, sem funcoes ficticias e sem dependencia de `localhost`.
- Transformar cadastro, checkout, entrega, compartilhamento, produto e catalogo em fluxos reais para usuario final.
- Expandir a trilha de catalogo para mais de 10 mil produtos com todas as categorias viaveis dos fornecedores, respeitando limites reais de API, cache e paginacao.

## Checklist

- [x] Diagnosticar motivo de catalogo atual abaixo de 1.000 itens. Concluido em 2026-05-07 03:01:02 BRT.
- [x] Corrigir bootstrap do APK para operar fora da rede local e cair em catalogo embarcado quando o link publico oscilar. Concluido em 2026-05-07 03:39:00 BRT.
- [x] Solicitar CPF e endereco completo no cadastro do cliente e persistir no backend. Concluido em 2026-05-07 03:39:00 BRT.
- [x] No checkout, permitir usar endereco do cadastro ou informar outro endereco de entrega. Concluido em 2026-05-07 03:39:00 BRT.
- [x] Enviar endereco de entrega no payload do pedido/checkout para que o fornecedor receba o destino correto. Concluido em 2026-05-07 03:39:00 BRT.
- [x] Ativar botao de compartilhamento real da oferta para apps/redes sociais. Concluido em 2026-05-07 03:39:00 BRT.
- [x] Consultar frete do fornecedor pelo endereco de entrega, repassar o custo ao comprador e exibir sugestoes de isencao/reducao no checkout. Concluido em 2026-05-07 03:39:00 BRT.
- [x] Criar Minhas compras com rastreio automatico e notificacoes de status ate entrega recebida. Concluido em 2026-05-07 03:39:00 BRT.
- [ ] Remover textos de desenvolvimento/curadoria e ajustar produto/lista com titulo, descricao e valor reais do item.
- [ ] Preparar payload white-label para fornecedor: marca Valley em etiqueta/embalagem quando API permitir e sem expor nome do fornecedor original ao cliente.
- [ ] Alterar estrategia de importacao para catalogo 10k+: todas categorias disponiveis, paginacao incremental, cache e tratamento de rate limit.
- [ ] Rebuildar APK ABI corrigido, validar e reenviar pelo Telegram com link publico.

## Evidencias Iniciais

- `frontend/flutter/assets/data/valley_stock_runtime_ptbr.json` possui `630` itens STOCK e `7` categorias agregadas.
- `scripts/import_real_stock_catalog.py` possui `PREVIEW_LIMIT = 80`, `CJ_PAGE_SIZE = 24`, limites de pagina e planos de categoria fixos.
- O runtime do fornecedor retornou mensagem de limite diario CJDropshipping `Too Many Requests` / `daily request limit (1000 times/day)`.
- O APK instalado pelo usuario fora da rede local exibiu `Servidor indisponivel`, confirmando que a entrega precisa de fallback embarcado e URL publica robusta.
- `frontend/flutter/lib/src/data/product_api_repository.dart` agora evita `localhost`/LAN para acoes interativas quando existir base publica candidata.
- `scripts/serve_valley_admin.py` expoe `POST /api/actions/shipping-quote`, calcula frete por fornecedor a partir do endereco e inclui o frete como repasse no checkout.
- `scripts/serve_valley_admin.py` grava `tmp/runtime/valley-supplier-orders.jsonl` com endereco, frete, white-label, `user_context` e rastreio inicial.
- `scripts/serve_valley_admin.py` expoe `GET /api/me/purchases` e `GET /api/me/notifications` para Minhas compras e notificacoes de alteracao de entrega.
- `frontend/flutter/lib/src/ui/valley_product_shell.dart` mostra frete consultado, sugestoes de frete, mensagem de parabens pela compra, compartilhamento real, Minhas compras e notificacoes de rastreio.
- Validacoes executadas: `python -m py_compile scripts\serve_valley_admin.py` e `dart analyze lib/src/data/product_api_models.dart lib/src/data/product_api_repository.dart lib/src/ui/valley_product_shell.dart` sem issues.

## Bloqueios

- Dominio fixo `https://admin.brasildesconto.com.br` respondeu `530` nesta sessao porque o token de named tunnel carregado esta invalido; o acesso remoto atual esta via Cloudflare Quick Tunnel.
- Catalogo 10k depende de execucao incremental e limites dos fornecedores; quando uma API limitar volume diario, o importador precisa continuar em ciclos ate completar a cobertura.
- Cloudflare Quick Tunnel retornou `429 Too Many Requests` ao tentar renovar URL publica apos muitas tentativas; named tunnel retornou `Unauthorized: Invalid tunnel secret`. A URL publica antiga passou a responder `530`, entao APK externo ainda depende de tunnel valido ou dominio fixo com token correto.

## Proxima Acao

- Corrigir cadastro/checkout/compartilhamento e rebuildar o APK de producao para reenvio.
