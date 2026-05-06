# Valley MCP Layout

O workspace agora carrega uma malha MCP em duas camadas:

- `.mcp.json`: declaracao generica para clientes que leem `mcpServers`
- `.vscode/mcp.json`: declaracao de workspace para VS Code
- `.codex/config.toml`: declaracao Codex e politica operacional do agente

## Capacidades MCP obrigatorias

- `MCP_DOCKER`: conector Docker gerenciado pela plataforma do agente; nao declare endpoint local duplicado.
- `context7`: documentacao atual de bibliotecas via `https://mcp.context7.com/mcp/oauth`.
- `figma`: endpoint oficial remoto `https://mcp.figma.com/mcp`.
- `linear`: endpoint oficial remoto `https://mcp.linear.app/mcp`.
- `playwright`: servidor local oficial via `npx -y @playwright/mcp@latest`, com perfil e artefatos em `tmp/runtime`.

## Servidores declarados no workspace

- `figma`: endpoint oficial remoto `https://mcp.figma.com/mcp`
- `stitch`: endpoint oficial remoto `https://stitch.googleapis.com/mcp`
- `context7`: endpoint remoto `https://mcp.context7.com/mcp/oauth` para OAuth; use `/mcp` com `CONTEXT7_API_KEY` apenas em configuracao privada do cliente
- `linear`: endpoint oficial remoto `https://mcp.linear.app/mcp`
- `playwright`: comando `npx -y @playwright/mcp@latest --user-data-dir=tmp/runtime/playwright-mcp-profile --output-dir=tmp/runtime/playwright-mcp`
- `cloudflare-api`: endpoint oficial remoto `https://mcp.cloudflare.com/mcp`

## Servidores mantidos fora do workspace

- `github`: mantido como conector gerenciado pela plataforma do agente
- `docker` / `MCP_DOCKER`: mantido como conector gerenciado pela plataforma do agente

Essa separacao evita autenticacao duplicada e reduz colisao entre configuracao repo-local e conectores nativos do host.

## Escopo GitHub deste projeto

- Toda integracao de repositorio via GitHub neste workspace fica limitada a `Ecossistema-Nexora/valley`.
- O conector `github` continua `platform-managed`, mas a referencia canonica do repo fica em `config/mcp/VALLEY_MCP_MANIFEST.json` e `config/github/VALLEY_GITHUB_REPOSITORY.json`.
- O remote Git esperado do worktree e `origin -> https://github.com/Ecossistema-Nexora/valley.git`.

## Onboarding rapido

- Use `config/VALLEY_FIRST_CONNECTION_CHECKLIST.md` como checklist operacional de primeira conexao.
- Ele cobre OAuth/API key inicial de `context7`, `figma`, `stitch`, `linear` e `cloudflare-api`, alem da diferenca entre `workspace-declared` e `platform-managed`.
- Valide a malha obrigatoria com:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/check_valley_mcp_config.ps1
```

## Politica front-end Stitch + Figma

- Stitch e a origem primaria para ideacao e geracao de layouts front-end do Valley.
- Figma e a camada de inspecao, handoff e ajuste fino quando houver design file ou componente mapeado.
- O segredo `STITCH_API_KEY` nunca deve ser versionado; use `.env` local, prompt do VS Code MCP ou OAuth conforme o cliente.
- No VS Code do workspace, `.vscode/mcp.json` foi preparado para ler `STITCH_API_KEY` do ambiente com `${env:STITCH_API_KEY}`.
- Use `python scripts/check_stitch_env.py` para validar se a chave esta carregada sem expor o valor completo.
- A implementacao de runtime continua em Flutter, preservando tokens e responsividade Web + Android.

## Arquivo de referencia

- `VALLEY_MCP_MANIFEST.json`: roster completo dos servidores MCP aceitos para o projeto e onde cada um e declarado

## Fontes operacionais

- Context7 Docs: endpoint remoto `https://mcp.context7.com/mcp`, com OAuth em `https://mcp.context7.com/mcp/oauth`
- Figma Developer Docs: endpoint remoto oficial `https://mcp.figma.com/mcp`
- Stitch Docs: endpoint MCP oficial `https://stitch.googleapis.com/mcp`
- Linear Changelog / MCP docs: endpoint oficial atualizado `https://mcp.linear.app/mcp`
- Playwright MCP Docs: servidor oficial `@playwright/mcp@latest`
- Cloudflare MCP server: endpoint oficial `https://mcp.cloudflare.com/mcp`
