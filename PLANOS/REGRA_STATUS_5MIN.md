<!--
PROPOSITO: Tornar mandatoria a atualizacao persistente de status em atividades Valley.
CONTEXTO: O usuario determinou atualizacao do status de cada tarefa a cada 5 minutos nesta e em futuras atividades.
REGRAS: Manter STATUS_ATUAL.md vivo, registrar evidencias e preferir execucao com polling para comandos longos.
-->

# Regra Persistente de Status a Cada 5 Minutos

## Aplicacao

Esta regra vale para esta atividade e para qualquer atividade futura conduzida pelo Codex no workspace Valley.

## Obrigatorio

- Manter `PLANOS/STATUS_ATUAL.md` atualizado durante atividades em andamento.
- Registrar cada tarefa com status `pendente`, `em_andamento`, `concluido` ou `bloqueado`.
- Publicar atualizacao no chat a cada 5 minutos quando a atividade ainda estiver em execucao.
- Antes de comandos potencialmente demorados, registrar o objetivo, arquivo de log e proxima janela de status.
- Para builds, deploys e validacoes longas, preferir execucao em background com polling, para permitir atualizacoes intermediarias.
- Se a ferramenta bloquear a conversa durante um comando longo, registrar a evidencia imediatamente ao retornar e ajustar a cadencia na proxima etapa.

## Arquivo Vivo

O arquivo vivo de acompanhamento e:

- `PLANOS/STATUS_ATUAL.md`

Ele deve conter:

- atividade atual;
- plano associado, quando existir;
- ultima atualizacao em BRT;
- proxima atualizacao prevista;
- checklist de tarefas;
- evidencia objetiva produzida;
- bloqueios reais, sem mascarar falhas.

