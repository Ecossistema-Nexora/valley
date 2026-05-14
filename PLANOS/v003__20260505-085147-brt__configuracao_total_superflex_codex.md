<!--
PROPOSITO: Documentar v003 20260505 085147 brt configuracao total superflex codex no escopo operacional do Valley.
CONTEXTO: Este arquivo registra orientacoes, decisoes ou plano associado ao caminho PLANOS/v003__20260505-085147-brt__configuracao_total_superflex_codex.md.
REGRAS: Manter informacao rastreavel, preservar nomenclatura Valley e atualizar ao mudar a rotina correspondente.
-->

# v003 - Configuracao Total Superflex Codex

## Resumo

- Configurar de forma persistente o workspace do VALLEY para uso da extensao oficial `aquilalabs.superflex`.
- Registrar o fluxo operacional real da extensao com login, Figma e handoff para Codex.
- Fechar a configuracao no padrao obrigatorio de `PLANOS`.

## Checklist

- [x] Confirmar a extensao oficial `aquilalabs.superflex` e sua documentacao publica. Concluido em 2026-05-05 08:51:47 BRT.
- [x] Registrar a recomendacao da extensao no workspace. Concluido em 2026-05-05 08:51:47 BRT.
- [x] Persistir um ajuste seguro de workspace para a extensao. Concluido em 2026-05-05 08:51:47 BRT.
- [x] Alinhar o handoff visual para uso com Codex no repo. Concluido em 2026-05-05 08:51:47 BRT.
- [x] Documentar instalacao, comandos, atalhos e limites da ferramenta. Concluido em 2026-05-05 08:51:47 BRT.

## Evidencias

- `.vscode/extensions.json` agora recomenda `aquilalabs.superflex`.
- `.vscode/settings.json` agora define `superflex.analytics: false`.
- `.cursor/rules/design.mdc` foi atualizado para cobrir handoff vindo do Superflex.
- `docs/tooling/superflex_codex_setup.md` foi criado com instalacao, inicializacao, comandos, atalhos e uso com Codex.

## Bloqueios

- Nenhum bloqueio local.
- O login da extensao e a conexao de conta Figma permanecem interativos no editor e nao foram versionados por seguranca e por dependerem da conta do operador.

## Proxima acao

- Instalar a extensao no editor, fazer `Sign In` no painel do Superflex e conectar o Figma se o objetivo for Figma-to-code dentro do workspace.
