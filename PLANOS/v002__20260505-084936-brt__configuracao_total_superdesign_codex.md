<!--
PROPOSITO: Documentar v002 20260505 084936 brt configuracao total superdesign codex no escopo operacional do Valley.
CONTEXTO: Este arquivo registra orientacoes, decisoes ou plano associado ao caminho PLANOS/v002__20260505-084936-brt__configuracao_total_superdesign_codex.md.
REGRAS: Manter informacao rastreavel, preservar nomenclatura Valley e atualizar ao mudar a rotina correspondente.
-->

# v002 - Configuracao Total SuperDesign Codex

## Resumo

- Configurar de forma persistente o workspace do VALLEY para uso da extensao oficial `SuperdesignDev.superdesign-official`.
- Registrar o fluxo real de uso com Codex sem comprometer secrets no repositorio.
- Atualizar este arquivo e `PLANOS/INDEX.md` com o fechamento da configuracao.

## Checklist

- [x] Auditar o workspace atual para VS Code, Cursor e regras existentes. Concluido em 2026-05-05 08:49:36 BRT.
- [x] Confirmar a extensao oficial e os comandos/providers suportados. Concluido em 2026-05-05 08:49:36 BRT.
- [x] Registrar a recomendacao da extensao no workspace. Concluido em 2026-05-05 08:49:36 BRT.
- [x] Isolar artefatos locais do SuperDesign do versionamento. Concluido em 2026-05-05 08:49:36 BRT.
- [x] Persistir a regra de handoff visual para Cursor/Codex. Concluido em 2026-05-05 08:49:36 BRT.
- [x] Documentar a configuracao total e o fluxo operacional no repo. Concluido em 2026-05-05 08:49:36 BRT.

## Evidencias

- `.vscode/extensions.json` agora recomenda `SuperdesignDev.superdesign-official`.
- `.vscode/settings.json` passou a excluir `.superdesign/` de busca e file watching.
- `.gitignore` passou a ignorar `.superdesign/`.
- `.cursor/rules/design.mdc` foi criado para orientar geracao e handoff ao Codex.
- `docs/tooling/superdesign_codex_setup.md` foi criado com instalacao, inicializacao, providers suportados e fluxo recomendado no VALLEY.

## Bloqueios

- Nenhum bloqueio local aberto.
- O preenchimento de `OpenAI Api Key`, `OpenAI Url`, `Anthropic Api Key` ou chaves equivalentes continua local e nao foi versionado por seguranca.

## Proxima acao

- Instalar a extensao no editor e executar `Superdesign: Initialize Superdesign` para materializar os arquivos locais gerados pela propria extensao.
