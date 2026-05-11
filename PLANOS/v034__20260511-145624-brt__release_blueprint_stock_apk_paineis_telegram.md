# v034 - Release Blueprint STOCK, APK, Paineis e Telegram

## Resumo

- Executar uma atividade unica de release para o modulo STOCK com override temporario de auto-pause apenas nesta rodada.
- Carregar o maior catalogo viavel a partir dos provedores/cache disponiveis, sem burlar limite externo de fornecedor.
- Gerar APK Android release split por ABI usando o dominio fixo recuperado do Cloudflare.
- Validar e entregar links dos paineis admin e lojista/produto, junto com APK, pelo Telegram.

## Checklist

- [x] Criar plano persistente da atividade e confirmar Cloudflare fixo saudavel. Concluido em 2026-05-11 14:56:24 BRT.
- [x] Aplicar override temporario do STOCK para desativar auto-pause somente nesta atividade. Concluido em 2026-05-11 15:06:49 BRT.
- [x] Carregar catalogo STOCK maximo viavel e regenerar assets publicos do app. Concluido em 2026-05-11 15:06:49 BRT.
- [x] Gerar release blueprints dos paineis admin e lojista/produto com links finais. Concluido em 2026-05-11 15:21:45 BRT.
- [x] Gerar APK Android release split por ABI com `https://admin.brasildesconto.com.br`. Concluido em 2026-05-11 16:21:35 BRT.
- [x] Enviar links dos paineis e APK ABI pelo Telegram e registrar evidencias finais. Concluido em 2026-05-11 16:25:30 BRT.

## Evidencias

- Dominio fixo Cloudflare validado em 2026-05-11: `https://admin.brasildesconto.com.br/healthz`, `/`, `/product` e `/api/product-shell` retornaram HTTP 200.
- Tunnel `valley-admin` (`80a75594-5129-469f-8cce-4a938ac48e06`) esta `healthy`, com conector ativo `7e78f7ef-3174-462d-8e40-e48f358c3776`.
- Origem remota do tunnel esta em `http://192.168.1.2:8085`, corrigindo o erro anterior de `127.0.0.1` no host do conector.
- Override temporario registrado em `tmp/runtime/valley-stock-release-activity-override.json` com `auto_pause_disabled_for_activity=true`, `scope=v034_only` e `permanent_policy_changed=false`.
- Runtime recompos em `tmp/runtime/valley-stock-real-catalog.json` com `items_total=1089`; asset embarcado `frontend/flutter/assets/data/valley_stock_runtime_ptbr.json` tambem validado com `1089` itens.
- `https://admin.brasildesconto.com.br/api/product-shell` retornou `public_runtime.provider=cloudflare_named_tunnel`, `items=80` na vitrine e `summary.products=1089`.
- `https://admin.brasildesconto.com.br/api/stock-catalog` retornou `items_total=1089`, `categories_total=7` e itens com `publication_status=approved` por politica de aprovacao desta instancia.
- CJDropshipping retornou HTTP 429 por limite diario de 1000 requisicoes; por isso a carga desta atividade usou a fila/cache validos de precificacao para materializar o maximo viavel sem simular itens externos.
- Blueprints criados: `docs/runtime/valley-admin-release-blueprint-v034.md`, `docs/runtime/valley-merchant-release-blueprint-v034.md` e `docs/runtime/valley-apk-release-blueprint-abi-v034.md`.
- Painel admin validado com HTTP 200 em `https://admin.brasildesconto.com.br/` apos o rebuild.
- Painel lojista/produto validado com HTTP 200 em `https://admin.brasildesconto.com.br/product` apos o rebuild Flutter Web com `VALLEY_PRODUCT_API_BASE_URL=https://admin.brasildesconto.com.br`.
- APK split por ABI gerado em `frontend/flutter/build/app/outputs/flutter-apk`: `app-arm64-v8a-release.apk` (`20781265` bytes), `app-armeabi-v7a-release.apk` (`18280701` bytes) e `app-x86_64-release.apk` (`22208301` bytes).
- Os APKs contem `admin.brasildesconto.com.br` em `libapp.so`, confirmando o `dart-define` de base publica fixa.
- Downloads publicados em `https://admin.brasildesconto.com.br/downloads/v034/`; `HEAD` dos tres APKs retornou HTTP 200 com os tamanhos esperados.
- Telegram enviado com `ok=true` para a mensagem de links dos paineis e downloads.
- Telegram enviado com `ok=true` para `app-arm64-v8a-release.apk`, `app-armeabi-v7a-release.apk` e `app-x86_64-release.apk`.

## Bloqueios

- Nenhum bloqueio de Cloudflare fixo no inicio desta atividade.
- O carregamento "todos os produtos" continua limitado pelas quotas e credenciais reais dos provedores; a atividade deve materializar o maximo viavel e registrar qualquer limite externo sem simular estoque inexistente.

## Proxima acao

- Atividade v034 concluida. Manter o override como excecao auditavel desta atividade e nao como regra permanente.
