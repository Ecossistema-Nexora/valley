# v038 - Regeneracao Token Cloudflare Release Gate

## Resumo

- Regenerar o token do Cloudflare named tunnel `valley-admin` de forma autonoma quando houver credencial emissora local.
- Desabilitar ngrok no fluxo de release e bloquear APK enquanto o dominio fixo nao passar no gate publico.
- Manter a rotina Gemini/Codex em paralelo, limitada a lotes de cinco arquivos.

## Checklist

- [x] Auditar fontes locais de credenciais Cloudflare sem imprimir segredos. Concluido em 2026-05-13 07:23:04 BRT.
- [x] Criar rotina persistente de regeneracao/aplicacao de token Cloudflare. Concluido em 2026-05-13 07:23:05 BRT.
- [x] Instalar tarefa agendada `ValleyCloudflareTokenRegeneration`. Concluido em 2026-05-13 07:23:05 BRT.
- [x] Reforcar gate de release para bloquear APK em Cloudflare temporario. Concluido em 2026-05-13 07:27:05 BRT.
- [ ] Validar `admin.brasildesconto.com.br` via Cloudflare named tunnel e liberar novo APK somente apos browser/healthz/product/api passarem.

## Evidencias

- `tmp/runtime/valley-cloudflare-token-regeneration-status.json` registrou `status: blocked` por ausencia de `CLOUDFLARE_API_TOKEN`/`CF_API_TOKEN` e ausencia de `~/.cloudflared/cert.pem`.
- O token de replica existente esta presente no ambiente, mas o log do cloudflared registra `Invalid tunnel secret`.
- `tmp/runtime/valley-cloudflare-token-regeneration-task.json` registrou a tarefa agendada a cada 3 minutos.
- `tmp/runtime/valley-release-runtime-gate.json` registrou bloqueio `temporary_cloudflare_not_allowed_for_apk`.
- `tmp/runtime/valley-cloudflare-browser-gate.json` registrou navegador Chromium retornando HTTP 530 nos tres endpoints do dominio fixo.
- `tmp/runtime/valley-gemini-refactor-loop-status.json` continua em `waiting_for_gemini`, com 155 pendencias e lote atual de 5 arquivos.

## Bloqueios

- Falta uma credencial emissora Cloudflare local: `CLOUDFLARE_API_TOKEN`/`CF_API_TOKEN` com permissao de Tunnel Write ou certificado `~/.cloudflared/cert.pem` autenticado.
- Sem essa credencial, o agente consegue manter watchdog, bloquear APK incorreto e aplicar automaticamente o novo token quando ele existir, mas nao consegue criar um segredo Cloudflare real do nada.

## Proxima Acao

- A rotina agendada deve renovar o token assim que a credencial emissora aparecer localmente e entao reexecutar o gate publico antes do APK.
