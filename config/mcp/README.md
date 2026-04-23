# Valley MCP Layout

O workspace agora carrega uma malha MCP em duas camadas:

- `.mcp.json`: declaracao generica para clientes que leem `mcpServers`
- `.vscode/mcp.json`: declaracao de workspace para VS Code

## Servidores declarados no workspace

- `figma`: endpoint oficial remoto `https://mcp.figma.com/mcp`
- `stitch`: endpoint oficial remoto `https://stitch.googleapis.com/mcp`
- `linear`: endpoint oficial remoto `https://mcp.linear.app/mcp`
- `cloudflare-api`: endpoint oficial remoto `https://mcp.cloudflare.com/mcp`

## Servidores mantidos fora do workspace

- `github`: mantido como conector gerenciado pela plataforma do agente
- `docker`: mantido como conector gerenciado pela plataforma do agente

Essa separacao evita autenticacao duplicada e reduz colisao entre configuracao repo-local e conectores nativos do host.

## Escopo GitHub deste projeto

- Toda integracao de repositorio via GitHub neste workspace fica limitada a `Ecossistema-Nexora/valley`.
- O conector `github` continua `platform-managed`, mas a referencia canonica do repo fica em `config/mcp/VALLEY_MCP_MANIFEST.json` e `config/github/VALLEY_GITHUB_REPOSITORY.json`.
- O remote Git esperado do worktree e `origin -> https://github.com/Ecossistema-Nexora/valley.git`.

## Onboarding rapido

- Use `config/VALLEY_FIRST_CONNECTION_CHECKLIST.md` como checklist operacional de primeira conexao.
- Ele cobre OAuth/API key inicial de `figma`, `stitch`, `linear` e `cloudflare-api`, alem da diferenca entre `workspace-declared` e `platform-managed`.

## Politica front-end Stitch + Figma

- Stitch e a origem primaria para ideacao e geracao de layouts front-end do Valley.
- Figma e a camada de inspecao, handoff e ajuste fino quando houver design file ou componente mapeado.
- O segredo `STITCH_API_KEY` nunca deve ser versionado; use `.env` local, prompt do VS Code MCP ou OAuth conforme o cliente.
- A implementacao de runtime continua em Flutter, preservando tokens e responsividade Web + Android.

## Arquivo de referencia

- `VALLEY_MCP_MANIFEST.json`: roster completo dos servidores MCP aceitos para o projeto e onde cada um e declarado

## Fontes operacionais

- Figma Developer Docs: endpoint remoto oficial `https://mcp.figma.com/mcp`
- Stitch Docs: endpoint MCP oficial `https://stitch.googleapis.com/mcp`
- Linear Changelog / MCP docs: endpoint oficial atualizado `https://mcp.linear.app/mcp`
- Cloudflare MCP server: endpoint oficial `https://mcp.cloudflare.com/mcp`
