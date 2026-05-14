<!--
PROPOSITO: Documentar rotas alternativas de runtime publico para Valley.
CONTEXTO: Este guia registra localhost.run, Tailscale e arquivos de manifesto usados quando o dominio fixo nao esta disponivel.
REGRAS: Preferir dominio publico oficial para release e usar rotas alternativas apenas como contingencia operacional.
-->

# Valley public runtime via localhost.run and Tailscale

## Current stable route

- Product URL: `http://100.109.240.100:8085/product`
- API shell: `http://100.109.240.100:8085/api/product-shell`
- Local API: `http://127.0.0.1:8085/api/product-shell`
- Bootstrap script: `scripts/start_valley_tailscale_runtime.ps1`
- Requirement: client device must be connected to the same Tailscale tailnet.

Tailscale Funnel was attempted, but the account returned `your Tailscale account does not support getting TLS certs`. The stable route currently uses the private Tailscale IP instead of a public HTTPS Funnel URL.

## Previous localhost.run route

- Product URL: `https://21c77166cdee10.lhr.life/product`
- API shell: `https://21c77166cdee10.lhr.life/api/product-shell`
- Local API: `http://127.0.0.1:8085/api/product-shell`
- Bootstrap script: `scripts/start_valley_localhost_run_public.ps1`
- Startup fallback: `%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\ValleyLocalhostRunPublicRuntime.cmd`

## Runtime files

- Product manifest: `tmp/runtime/valley-product-public-runtime.json`
- Admin manifest: `tmp/runtime/valley-admin-public-runtime.json`
- Publication manifest: `tmp/runtime/valley-product-web-publication.json`
- Tunnel stdout: `tmp/runtime/valley-localhost-run.out.log`
- Tunnel stderr: `tmp/runtime/valley-localhost-run.err.log`
- Local API stdout: `tmp/runtime/valley-product-api.win.out.log`
- Local API stderr: `tmp/runtime/valley-product-api.win.err.log`

## Account, key, and domain locations

- Local SSH key pair already present: `C:\Users\ereta\.ssh\valley` and `C:\Users\ereta\.ssh\valley.pub`.
- SSH known hosts: `C:\Users\ereta\.ssh\known_hosts`.
- localhost.run account console: `https://admin.localhost.run/`.
- localhost.run docs: `https://localhost.run/docs/forever-free/` and `https://localhost.run/docs/custom-domains/`.

## Persistence policy

The active implementation does not use ngrok. It starts the local Valley API on port `8085`, opens an SSH reverse tunnel to localhost.run, and writes the current public URL into runtime manifests.

The Windows Scheduled Task API returned access denied for this user, so the script installed a user-login startup fallback instead. On login, the startup command runs:

```bat
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Users\ereta\.codex\worktrees\VALLEY\scripts\start_valley_localhost_run_public.ps1" -ReplaceStale
```

Anonymous localhost.run URLs are free but can change. For a longer-lived free domain, create/sign in at `https://admin.localhost.run/` and add the public SSH key from `C:\Users\ereta\.ssh\valley.pub`. For a truly stable custom domain, configure it in the localhost.run admin console and update the `-R` value in `scripts/start_valley_localhost_run_public.ps1`.
