<!--
PROPOSITO: Documentar v007 20260505 092400 brt entrypoint canonico apply compose builder no escopo operacional do Valley.
CONTEXTO: Este arquivo registra orientacoes, decisoes ou plano associado ao caminho PLANOS/v007__20260505-092400-brt__entrypoint_canonico_apply_compose_builder.md.
REGRAS: Manter informacao rastreavel, preservar nomenclatura Valley e atualizar ao mudar a rotina correspondente.
-->

# v007 - Entrypoint Canonico Apply Compose Builder

## Resumo

- Criar um entrypoint unico e canonicamente versionado para rodar `apply-compose` e depois o builder Docker, sem concorrencia entre as duas etapas.
- Atualizar as referencias operacionais do repo para apontarem para esse entrypoint em vez de comandos soltos.

## Checklist

- [x] Criar `scripts/run_valley_compose_builder.ps1` com execucao sequencial e falha explicita por etapa. Concluido em 2026-05-05 09:24:00 BRT.
- [x] Atualizar os comandos canonicos em config e docs para apontarem para o novo entrypoint. Concluido em 2026-05-05 09:24:00 BRT.
- [x] Validar a sintaxe do PowerShell do novo script. Concluido em 2026-05-05 09:24:00 BRT.
- [x] Executar o entrypoint real e confirmar `apply-compose` seguido de `builder` com sucesso. Concluido em 2026-05-05 09:24:00 BRT.

## Evidencias

- `scripts/run_valley_compose_builder.ps1` foi criado como entrypoint sequencial oficial.
- `config/tooling.bootstrap.json` agora usa `powershell -ExecutionPolicy Bypass -File scripts/run_valley_compose_builder.ps1` como `canonical_builder_command`.
- `config/terminal-control-profile.json` agora aponta `release_runtime.database` para o novo script.
- `scripts/valley_admin_builder.py` passou a listar o novo script em `admin_commands`.
- `docs/deployment-order.md` passou a documentar o novo fluxo local canonico.
- A validacao sintatica retornou `OK_PWSH_PARSE`.
- A execucao real do script concluiu com `apply-compose` e depois `builder`, sem reproduzir a corrida da migration `020`.

## Bloqueios

- Nenhum bloqueio aberto.

## Proxima acao

- Se quiser endurecer ainda mais a trilha, o proximo passo natural e fazer os painéis e builders consumirem apenas esse entrypoint, removendo qualquer exibicao residual de comandos separados.
