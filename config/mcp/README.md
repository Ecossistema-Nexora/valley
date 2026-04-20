# Valley MCP Layout

O workspace agora carrega uma malha MCP em duas camadas:

- `.mcp.json`: declaracao generica para clientes que leem `mcpServers`
- `.vscode/mcp.json`: declaracao de workspace para VS Code

## Servidores declarados no workspace

- `figma`: endpoint oficial remoto `https://mcp.figma.com/mcp`
- `linear`: endpoint oficial remoto `https://mcp.linear.app/mcp`
- `cloudflare-api`: endpoint oficial remoto `https://mcp.cloudflare.com/mcp`

## Servidores mantidos fora do workspace

- `github`: mantido como conector gerenciado pela plataforma do agente
- `docker`: mantido como conector gerenciado pela plataforma do agente

Essa separacao evita autenticacao duplicada e reduz colisao entre configuracao repo-local e conectores nativos do host.

## Onboarding rapido

- Use `config/VALLEY_FIRST_CONNECTION_CHECKLIST.md` como checklist operacional de primeira conexao.
- Ele cobre OAuth inicial de `figma`, `linear` e `cloudflare-api`, alem da diferenca entre `workspace-declared` e `platform-managed`.

## Arquivo de referencia

- `VALLEY_MCP_MANIFEST.json`: roster completo dos servidores MCP aceitos para o projeto e onde cada um e declarado

## Fontes operacionais

- Figma Developer Docs: endpoint remoto oficial `https://mcp.figma.com/mcp`
- Linear Changelog / MCP docs: endpoint oficial atualizado `https://mcp.linear.app/mcp`
- Cloudflare MCP server: endpoint oficial `https://mcp.cloudflare.com/mcp`
