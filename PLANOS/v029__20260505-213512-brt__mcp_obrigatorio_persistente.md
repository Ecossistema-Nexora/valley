# Configuracao MCP obrigatoria e persistente

## Resumo

Tornar `MCP_DOCKER`, `context7`, `figma`, `linear` e `playwright` capacidades mandatarias do workspace VALLEY, com declaracao persistente no repositorio, politica operacional e validacao local.

## Checklist

- [x] Inspecionar configuracoes MCP existentes no workspace.
- [x] Declarar `context7` e `playwright` nos manifests locais sem versionar segredos.
- [x] Tornar a politica MCP obrigatoria em `config/mcp` e `.codex/config.toml`.
- [x] Atualizar checklist de primeira conexao e variaveis locais esperadas.
- [x] Criar e executar verificador local da configuracao MCP obrigatoria.
- [x] Registrar evidencias e fechar o plano como concluido.

## Evidencias

- `.mcp.json` ja continha `figma`, `stitch`, `linear` e `cloudflare-api`.
- `.vscode/mcp.json` ja continha os mesmos servidores declarados para VS Code.
- `config/mcp/VALLEY_MCP_MANIFEST.json` ja classificava Docker como `platform-managed` com `platform_name=MCP_DOCKER`.
- `context7` e `playwright` foram declarados em `.mcp.json`, `.vscode/mcp.json` e `.codex/config.toml`.
- `scripts/check_valley_mcp_config.ps1` retornou `ok=true` em 2026-05-06T00:44:29Z.

## Bloqueios

- Nenhum bloqueio para persistencia repo-local.
- Autenticacao OAuth/API key continua fora do repositorio por politica de seguranca.

## Proxima acao

Concluido. Proxima acao operacional: obedecer a correcao de naming Valley/Helena/V-Coin.
