# Valley First Connection Checklist

Checklist curto para subir MCP e acesso externo sem ambiguidade.

## 1. MCP: primeira conexao

- Abra o workspace Valley no cliente MCP.
- Carregue a configuracao do workspace declarada em `.mcp.json` ou `.vscode/mcp.json`.
- Inicie `figma`, `linear` e `cloudflare-api`.
- Na primeira execucao, conclua o OAuth de cada um no navegador e aceite `Allow access`.
- Confirme no cliente que os tres servidores ficaram `Connected` antes de pedir automacao ao agente.

## 2. Workspace-declared vs platform-managed

- `workspace-declared`: servidores versionados no repositorio e declarados localmente.
- Neste projeto: `figma`, `linear`, `cloudflare-api`.
- Regra: autenticacao acontece no cliente MCP, mas a topologia fica no workspace.

- `platform-managed`: conectores fornecidos pelo host do agente, fora do repositorio.
- Neste projeto: `github`, `docker`.
- Regra: nao duplicar esses conectores em arquivo local do workspace.
- Regra adicional para GitHub: toda automacao e leitura de repositorio deve apontar somente para `Ecossistema-Nexora/valley`.
- Remote esperado neste worktree: `origin -> https://github.com/Ecossistema-Nexora/valley.git`.

Referencia: `config/mcp/VALLEY_MCP_MANIFEST.json`

## 2.1. Binding canonico do repositorio GitHub

- Repo oficial: `https://github.com/Ecossistema-Nexora/valley`
- Owner: `Ecossistema-Nexora`
- Nome: `valley`
- Remote Git canonico: `origin`
- Nao use `valley_omniverse` como repo de operacao deste workspace.

## 3. ngrok: URL externa dinamica

- Garanta que o painel local esteja em `127.0.0.1:8080`.
- Rode o launcher existente:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/start_valley_admin_public.ps1
python scripts/show_valley_public_urls.py
```

- Use a URL HTTPS retornada para testes externos imediatos.

## 4. ngrok: URL permanente de release

- Reserve um dominio na sua conta ngrok.
- Exporte somente o dominio no ambiente local, nunca no repositorio:

```powershell
$env:VALLEY_NGROK_ADMIN_DOMAIN = "valley-admin-release.ngrok.app"
```

- Inicie o launcher:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/start_valley_admin_public.ps1
python scripts/show_valley_public_urls.py
```

- Valide:
  - `https://${VALLEY_NGROK_ADMIN_DOMAIN}/`
  - `https://${VALLEY_NGROK_ADMIN_DOMAIN}/healthz`
  - `https://${VALLEY_NGROK_ADMIN_DOMAIN}/api/admin-data`

## 5. Segredo fora do repo

- `VALLEY_NGROK_ADMIN_DOMAIN` e configuracao operacional local; nao precisa ser commitado.
- `authtoken` do ngrok deve continuar apenas em `%LOCALAPPDATA%\\ngrok\\ngrok.yml`.
- Tokens OAuth de `figma`, `linear` e `cloudflare-api` ficam no cliente MCP, nao no workspace.

## 6. Falha comum a evitar

- Se `figma`, `linear` ou `cloudflare-api` nao conectarem, refaca apenas o OAuth do servidor afetado.
- Se a URL do `ngrok` mudar, voce esta em modo dinamico; faltou reservar dominio ou exportar `VALLEY_NGROK_ADMIN_DOMAIN`.
