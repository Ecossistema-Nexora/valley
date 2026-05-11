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
- [x] Remover textos de desenvolvimento/curadoria e ajustar produto/lista com titulo, descricao e valor reais do item. Concluido em 2026-05-11 09:59:34 BRT.
- [x] Preparar payload white-label para fornecedor: marca Valley em etiqueta/embalagem quando API permitir e sem expor nome do fornecedor original ao cliente. Concluido em 2026-05-11 09:59:34 BRT.
- [x] Alterar estrategia de importacao para catalogo 10k+: todas categorias disponiveis, paginacao incremental, cache e tratamento de rate limit. Concluido em 2026-05-11 09:59:34 BRT.
- [x] Rebuildar APK ABI corrigido, validar e reenviar pelo Telegram com link publico. Concluido em 2026-05-07 04:44:00 BRT.

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
- `scripts/start_valley_localhost_run_public.ps1` criado como rota publica gratuita via `localhost.run`, sem ngrok, gravando manifests persistentes em `tmp/runtime`.
- Runtime publico ativo em `https://21c77166cdee10.lhr.life/product`; endpoints `healthz`, `api/product-shell`, `api/me/purchases` e `api/me/notifications` validados com HTTP 200.
- `frontend/flutter/lib/src/data/product_api_repository.dart` aponta o fallback publico do APK para `https://21c77166cdee10.lhr.life` e mantem Tailscale como candidato adicional.
- `docs/runtime/localhost_run_public_runtime.md` registra onde ficam conta, chave, dominio, logs, manifests e fallback de inicializacao.
- APK Android `app-arm64-v8a-release.apk` gerado com `VALLEY_PRODUCT_API_BASE_URL=https://21c77166cdee10.lhr.life` e enviado pelo Telegram.
- Link do painel web `https://21c77166cdee10.lhr.life/product` enviado pelo Telegram.
- `docs/integrations/cj_api_quota_request_brief.md` criado com briefing para o ChatGPT elaborar o e-mail de aumento de quota da API CJDropshipping.
- Incidente pos-envio: dominio anonimo `localhost.run` expirou com `no tunnel here`; runtime migrado para Tailscale IP estavel `http://100.109.240.100:8085`.
- AndroidManifest liberado para cleartext em rede Tailscale privada e novo APK sera gerado com `VALLEY_PRODUCT_API_BASE_URL=http://100.109.240.100:8085`.
- APK Android `app-arm64-v8a-release.apk` rebuildado em 2026-05-07 07:15 BRT com base Tailscale `http://100.109.240.100:8085` e reenviado pelo Telegram.
- Link corrigido enviado pelo Telegram: `http://100.109.240.100:8085/product`; validacoes `healthz` e `api/product-shell` retornaram HTTP 200.
- Diagnostico Cloudflare 1033 em 2026-05-07: `admin.brasildesconto.com.br` aponta para o CNAME `80a75594-5129-469f-8cce-4a938ac48e06.cfargotunnel.com`, tunnel Cloudflare `valley-admin` esta `down`, sem conexoes ativas desde 2026-05-06, e o token local retorna `Unauthorized: Invalid tunnel secret`.
- A conta Cloudflare conectada ao Codex permite leitura de zona/DNS/tunnel, mas nao permitiu obter novo tunnel token (`Authentication error` no endpoint de token); por isso o dominio fixo segue bloqueado ate renovar o token do named tunnel no Cloudflare Zero Trust ou liberar permissao de escrita/token.
- Criado `scripts/repair_valley_cloudflare_named_tunnel.ps1` para renovar automaticamente o token do tunnel quando existir `CLOUDFLARE_API_TOKEN`/`CF_API_TOKEN` com `Cloudflare Tunnel Write` ou `Cloudflare One Connector Write`.
- Criado `docs/runtime/cloudflare_named_tunnel_repair.md` com o procedimento persistente para copiar o token via `Zero Trust > Networks > Tunnels > valley-admin > Add a replica` ou via API.
- Execucao do reparador em 2026-05-08 registrou `tmp/runtime/valley-cloudflare-named-tunnel-repair.json` com status `blocked`: `CLOUDFLARE_API_TOKEN/CF_API_TOKEN ausente`.
- `frontend/flutter/lib/src/data/product_api_models.dart`, `product_api_repository.dart`, `valley_product_shell.dart` e `valley_home_shell.dart` ajustados para usar `customer_visible_supplier_name`, linguagem de loja/entrega e titulos/descricoes/valores reais do item.
- `scripts/serve_valley_admin.py` passou a gerar `supplier_payload` interno white-label (`valley_supplier_order.v1`) com marca Valley em etiqueta/embalagem quando permitido, sem expor fornecedor original no payload publico de checkout, frete ou Minhas compras.
- `frontend/flutter/assets/data/valley_product_catalog.json` e `frontend/flutter/assets/data/valley_stock_runtime_ptbr.json` foram regenerados com 80 itens de vitrine e 1089 itens STOCK embarcados; a verificacao estruturada encontrou zero chaves publicas internas de fornecedor/provider/custo/benchmark, exceto `customer_visible_supplier_name=Valley`.
- `config/stock_catalog_import_policy.json` criado com meta minima `10000`, alvos por provedor, checkpoints incrementais, cache em rate-limit, backoff e limite de preview.
- `scripts/run_stock_catalog_10k_cycle.ps1` criado como ciclo persistente para importacao 10k+, precificacao, traducao e status em `tmp/runtime/valley-stock-catalog-10k-cycle.json`.
- `scripts/import_real_stock_catalog.py --target-items 10000` materializou 1089 itens no runtime atual usando cache/fallback porque CJDropshipping retornou HTTP 429 de limite diario; `scripts/translate_stock_catalog_ptbr.py --rebuild-only` regenerou os assets publicos sem gastar nova quota externa.
- Validacao local em servidor novo `127.0.0.1:8099`: `healthz=ok`, `/api/stock-catalog` com `items_total=1089`, `/api/product-shell` com `80` itens e `POST /api/actions/shipping-quote` com `status=ok`, frete `39.9` e `customer_visible_supplier_name=Valley`.
- Validacoes executadas em 2026-05-11: `python -m py_compile scripts\import_real_stock_catalog.py scripts\translate_stock_catalog_ptbr.py scripts\serve_valley_admin.py`, `dart format` nos arquivos Flutter alterados, parse do PowerShell `scripts\run_stock_catalog_10k_cycle.ps1`, parse do JSON de politica e `git diff --check` nos arquivos da frente.
- `scripts/run_valley_mvp_autonomous_closure.ps1` e `scripts/install_valley_mvp_autonomous_closure_task.ps1` adicionados para transformar o catalogo 10k, reparo Cloudflare e validacao do dominio em rotina automatica safe-only a cada 6 horas.
- `schtasks.exe /Query /TN \ValleyMvpAutonomousClosure` confirmou a tarefa ativa com proxima execucao em 2026-05-11 16:30:00 BRT.

## Bloqueios

- Dominio fixo `https://admin.brasildesconto.com.br` respondeu `530`/`1033` nesta sessao porque o token de named tunnel carregado esta invalido; o acesso remoto atual validado esta via Tailscale `http://100.109.240.100:8085/product`.
- Catalogo 10k agora possui politica e ciclo persistente, mas o volume materializado atual permanece em 1089 itens ate a quota diaria da CJDropshipping liberar novas paginas ou outros provedores autenticados ampliarem a cobertura.
- Cloudflare Quick Tunnel retornou `429 Too Many Requests` ao tentar renovar URL publica apos muitas tentativas; named tunnel retornou `Unauthorized: Invalid tunnel secret`. A rota operacional foi migrada para `localhost.run`, com Tailscale mantido como alternativa de rede privada.
- `flutter analyze`/`dart analyze` segmentado nesta sessao excedeu 6 minutos de timeout; a verificacao Dart concluida foi `dart format`, que parseou os arquivos alterados, mas nao substitui a analise estatica completa.
- A tentativa de registrar automacao recorrente pelo Codex app retornou falha sem detalhe; a persistencia recorrente ativa foi feita via Windows Task Scheduler e registrada em `tmp/runtime/valley-mvp-autonomous-closure-task.json`.

## Proxima Acao

- A tarefa `\ValleyMvpAutonomousClosure` executara a rotina automaticamente; quando a quota CJDropshipping ou novos tokens de provedores estiverem disponiveis, o ciclo 10k continua sem acao manual.
