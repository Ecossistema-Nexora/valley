# Valley First Connection Checklist

Checklist curto para subir MCP e acesso externo sem ambiguidade.

## 0. Extensoes obrigatorias do workspace

- Rode `powershell -ExecutionPolicy Bypass -File scripts/bootstrap_valley_tooling.ps1` para instalar ou atualizar as extensoes obrigatorias em `code` e `antigravity`.
- O workspace trata `Dart-Code.dart-code`, `Dart-Code.flutter`, `redhat.java`, `figma.figma-vscode-extension`, `ms-playwright.playwright`, Docker, Python, YAML, MongoDB, PostgreSQL e GitHub como extensoes obrigatorias.
- A extensao `oracle.oracle-java` fica explicitamente bloqueada para este workspace por conflitar com a politica Java do Valley.
- A extensao `vscjava.vscode-gradle` tambem fica bloqueada neste workspace para evitar importacao automatica de subprojetos Android/Gradle aninhados, como plugins Flutter nativos.

## 1. MCP: primeira conexao

- Abra o workspace Valley no cliente MCP.
- Carregue a configuracao do workspace declarada em `.mcp.json` ou `.vscode/mcp.json`.
- Inicie obrigatoriamente `context7`, `figma`, `linear` e `playwright`.
- Inicie tambem `stitch` para trabalho front-end e `cloudflare-api` quando a tarefa envolver runtime publico/deploy.
- Confirme que `MCP_DOCKER` esta disponivel como conector gerenciado pela plataforma do agente; ele nao deve aparecer como endpoint repo-local.
- Na primeira execucao, conclua o OAuth de cada um no navegador e aceite `Allow access`.
- Para `context7`, use o endpoint OAuth declarado. Se o cliente nao suportar OAuth remoto, configure localmente `https://mcp.context7.com/mcp` com o header `CONTEXT7_API_KEY` vindo do ambiente local.
- Para `playwright`, mantenha os argumentos `--user-data-dir=tmp/runtime/playwright-mcp-profile` e `--output-dir=tmp/runtime/playwright-mcp`; ambos ficam fora do git.
- Para `stitch`, prefira API key persistente: gere na pagina Settings do Stitch, salve como `STITCH_API_KEY` no `.env` local ou informe no prompt seguro do VS Code MCP.
- O workspace VS Code agora le `STITCH_API_KEY` diretamente do ambiente via `.vscode/mcp.json`.
- Valide localmente com:

```powershell
python scripts/check_stitch_env.py
powershell -ExecutionPolicy Bypass -File scripts/check_valley_mcp_config.ps1
```

- Se a chave estiver apenas no `.env`, carregue-a na sessao antes de abrir o cliente MCP.
- Confirme no cliente que `context7`, `figma`, `linear` e `playwright` ficaram `Connected` antes de pedir automacao ao agente.

## 2. Workspace-declared vs platform-managed

- `workspace-declared`: servidores versionados no repositorio e declarados localmente.
- Neste projeto: `context7`, `figma`, `stitch`, `linear`, `playwright`, `cloudflare-api`.
- Regra: autenticacao acontece no cliente MCP, mas a topologia fica no workspace.
- Regra do design: novos layouts front-end devem nascer no Stitch, passar por Figma quando houver arquivo de design, e depois serem implementados em Flutter.

- `platform-managed`: conectores fornecidos pelo host do agente, fora do repositorio.
- Neste projeto: `github`, `docker` / `MCP_DOCKER`.
- Regra: nao duplicar esses conectores em arquivo local do workspace.
- Regra adicional para GitHub: toda automacao e leitura de repositorio deve apontar somente para `Ecossistema-Valley/valley`.
- Remote esperado neste worktree: `origin -> https://github.com/Ecossistema-Valley/valley.git`.

Referencia: `config/mcp/VALLEY_MCP_MANIFEST.json`

## 2.1. Binding canonico do repositorio GitHub

- Repo oficial: `https://github.com/Ecossistema-Valley/valley`
- Owner: `Ecossistema-Valley`
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
- Tokens OAuth de `context7`, `figma`, `linear` e `cloudflare-api` ficam no cliente MCP, nao no workspace.
- `CONTEXT7_API_KEY`, quando usada em vez de OAuth, fica apenas no ambiente local ou no gerenciador de segredos do cliente.
- Estado de navegador, storage state, screenshots sensiveis e artefatos do Playwright MCP ficam fora do git.
- `STITCH_API_KEY` e tokens OAuth do Stitch ficam apenas no ambiente local, prompt seguro do cliente ou provedor de secrets.

## 6. Falha comum a evitar

- Se `context7`, `figma`, `stitch`, `linear` ou `cloudflare-api` nao conectarem, refaca apenas a autenticacao do servidor afetado.
- Se `playwright` nao iniciar, confirme `node` e `npx` no PATH e execute `npx -y @playwright/mcp@latest --help` fora do cliente.
- Se a URL do `ngrok` mudar, voce esta em modo dinamico; faltou reservar dominio ou exportar `VALLEY_NGROK_ADMIN_DOMAIN`.
