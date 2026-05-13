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
- [x] Validar `admin.brasildesconto.com.br` via Cloudflare named tunnel e liberar novo APK somente apos browser/healthz/product/api passarem. Concluido em 2026-05-13 08:45:46 BRT.

## Evidencias

- `tmp/runtime/valley-cloudflare-token-regeneration-status.json` registrou `status: blocked` por ausencia de `CLOUDFLARE_API_TOKEN`/`CF_API_TOKEN` e ausencia de `~/.cloudflared/cert.pem`.
- O token API recebido em 2026-05-13 07:43 BRT foi testado sem expor o segredo e a Cloudflare retornou HTTP 401, mantendo o gate bloqueado.
- O token API recebido em 2026-05-13 07:53 BRT foi verificado como `active`, mas sem autorizacao na conta alvo: `/accounts/474fc26bf9c6bcf5e1a84b7f63a516d8` retornou `9109 Unauthorized to access requested resource`.
- Nova tentativa em 2026-05-13 08:28 BRT confirmou o mesmo resultado: token `active`, conta alvo com `9109 Unauthorized` e endpoint de token do tunnel com `10000 Authentication error`.
- Nova tentativa em 2026-05-13 08:35 BRT gerou token de replica via API Cloudflare, salvou `tmp/runtime/valley-cloudflare-named-tunnel.env` fora do Git e colocou o tunnel `cloudflare_named_tunnel` em `provider_status: healthy`.
- `tmp/runtime/valley-release-runtime-gate.json` registrou `status: ok` para 3 tentativas consecutivas em `healthz`, `product` e `product_shell`.
- `tmp/runtime/valley-cloudflare-browser-gate.json` registrou navegador Chromium com HTTP 200 em `admin.brasildesconto.com.br` e `brasildesconto.com.br`.
- `flutter build apk --release --split-per-abi --dart-define=VALLEY_PRODUCT_API_BASE_URL=https://admin.brasildesconto.com.br` concluiu em 2026-05-13 08:44 BRT.
- APKs v038 enviados pelo Telegram: `app-arm64-v8a-release.apk`, `app-armeabi-v7a-release.apk`, `app-x86_64-release.apk` e `VALLEY_APK_RELEASE_ABI_V038.json`.
- PDF ABNT atualizado e enviado pelo Telegram: `admin/downloads/v038/VALLEY_RELEASE_LINKS_MODULOS_ABNT.pdf`, SHA1 `BF7FE046B4A7B753151A80BD696C4AC691FDD27C`.
- O token de replica antigo permanecia no ambiente e gerava `Invalid tunnel secret`; a rotina substituiu por token novo de 248 caracteres salvo fora do Git.
- `tmp/runtime/valley-cloudflare-token-regeneration-task.json` registrou a tarefa agendada a cada 3 minutos.
- `tmp/runtime/valley-release-runtime-gate.json` registrou bloqueio `temporary_cloudflare_not_allowed_for_apk`.
- `tmp/runtime/valley-cloudflare-browser-gate.json` registrou navegador Chromium retornando HTTP 530 nos tres endpoints do dominio fixo.
- `tmp/runtime/valley-gemini-refactor-loop-status.json` continua em `waiting_for_gemini`, com 155 pendencias e lote atual de 5 arquivos.

## Bloqueios

- O processo antigo `cloudflared` PID 3836 permaneceu protegido por acesso negado do Windows, mas o processo novo do named tunnel esta saudavel e validado.

## Proxima Acao

- Manter o watchdog Cloudflare ativo e usar `admin/downloads/v038/app-arm64-v8a-release.apk` como APK principal para aparelhos Android arm64.
