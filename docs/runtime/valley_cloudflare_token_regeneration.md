<!--
PROPOSITO: Documentar a rotina persistente de regeneracao do token Cloudflare.
CONTEXTO: O release Valley depende do dominio fixo admin.brasildesconto.com.br e
do named tunnel valley-admin. A rotina impede envio de APK quando o tunnel falha.
REGRAS: Nao registrar segredos no documento, nao orientar ngrok como fallback de
release e manter evidencias em tmp/runtime.
-->

# Valley Cloudflare Token Regeneration

Rotina mandataria para recuperar o `CLOUDFLARED_TOKEN` do named tunnel
`valley-admin` e manter o release bloqueado ate o Cloudflare passar nos checks:

- `https://admin.brasildesconto.com.br/healthz`
- `https://admin.brasildesconto.com.br/product`
- `https://admin.brasildesconto.com.br/api/product-shell`

## Scripts

- `scripts/ensure_valley_cloudflare_token_regeneration.ps1`
- `scripts/install_valley_cloudflare_token_regeneration_task.ps1`
- `scripts/ensure_valley_release_runtime.ps1`

## Status

- `tmp/runtime/valley-cloudflare-token-regeneration-status.json`
- `tmp/runtime/valley-cloudflare-token-regeneration-task.json`
- `tmp/runtime/valley-cloudflare-release-blocker.json`
- `tmp/runtime/valley-release-runtime-gate.json`

## Politica

O fluxo padrao e Cloudflare-only. Ngrok permanece desabilitado para release.
A regeneracao automatica exige uma destas credenciais locais:

- `CLOUDFLARE_API_TOKEN` ou `CF_API_TOKEN` com permissao de Cloudflare Tunnel
  Write ou Cloudflare One Connector Write.
- `~/.cloudflared/cert.pem` autenticado, capaz de emitir token via
  `cloudflared tunnel token valley-admin`.

Quando a credencial existir, o watchdog emite o token, salva em
`tmp/runtime/valley-cloudflare-named-tunnel.env`, aplica no ambiente do usuario
e tenta subir o dominio fixo. O APK so deve ser gerado e enviado depois do gate
registrar `status: ok`.
