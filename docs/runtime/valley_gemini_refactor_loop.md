# PROPOSITO: Rotina Persistente Gemini/Codex

## CONTEXTO:

Esta rotina cria um fluxo persistente para o Codex selecionar pendencias de
estrutura, entregar no maximo cinco arquivos por rodada ao Gemini Code Assist,
aceitar as alteracoes por revarredura e liberar o proximo lote somente depois
do sinal de conclusao.

## REGRAS:

- Cada tarefa do Gemini recebe no maximo cinco arquivos.
- O Codex seleciona os arquivos pelo checklist persistente.
- O Gemini deve responder `GEMINI_DONE task_id=<task_id> files=<quantidade> status=done`.
- Como alternativa, o Gemini pode preencher `tmp/runtime/valley-gemini-completion-signal.json`.
- O proximo lote so e emitido quando a tarefa atual estiver concluida.
- A aceitacao e feita por revarredura, ledger e status do workspace, sem `reset` ou revert.
- O Valley Module Automation Engine e acionado em cada ciclo.
- O agendamento persistente roda a cada 1 minuto e so finaliza quando o checklist chegar a zero pendencias.

## Arquivos Operacionais

- `scripts/run_valley_gemini_refactor_loop.py`
- `scripts/run_valley_gemini_refactor_watchdog.ps1`
- `scripts/install_valley_gemini_refactor_loop_task.ps1`
- `config/automation/valley_gemini_refactor_loop.json`
- `tmp/runtime/valley-gemini-current-task.md`
- `tmp/runtime/valley-gemini-refactor-loop-status.json`
- `output/refactor/VALLEY_GEMINI_REFACTOR_CHECKLIST.md`

## Comandos

Gerar ou atualizar a tarefa atual:

```powershell
python scripts/run_valley_gemini_refactor_loop.py scan --batch-size 5 --engine-mode checkpoint
```

Rodar um ciclo watchdog:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/run_valley_gemini_refactor_watchdog.ps1 -Command loop -BatchSize 5 -MaxCycles 1 -EngineMode checkpoint
```

Registrar persistencia no Agendador de Tarefas:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/install_valley_gemini_refactor_loop_task.ps1 -IntervalMinutes 1 -EngineMode checkpoint
```

Este mesmo comando reforça a rotina mandatória sempre que for executado novamente.
