<!--
PROPOSITO: Documentar v027 20260505 210642 brt endpoint autenticado assistant enablement no escopo operacional do Valley.
CONTEXTO: Este arquivo registra orientacoes, decisoes ou plano associado ao caminho PLANOS/v027__20260505-210642-brt__endpoint_autenticado_assistant_enablement.md.
REGRAS: Manter informacao rastreavel, preservar nomenclatura Valley e atualizar ao mudar a rotina correspondente.
-->

# v027 - Endpoint Autenticado Assistant Enablement

## Resumo

- Implementar a proxima rota operacional autentica para recomendacao nao comercial.
- Ligar `assistant_enablement` a um endpoint autenticado proprio baseado no bridge real do runtime.

## Checklist

- [x] Confirmar que o motivo ja possui base real no backend via bridge status. Concluido em 2026-05-05 21:06:42 BRT.
- [x] Implementar rota autenticada para `assistant_enablement`. Concluido em 2026-05-05 21:06:42 BRT.
- [x] Mapear `("CHAT", "assistant_enablement")` no resolvedor operacional. Concluido em 2026-05-05 21:06:42 BRT.
- [x] Validar a rota e o resolvedor. Concluido em 2026-05-05 21:06:42 BRT.
- [x] Consolidar a entrega no plano e no resumo. Concluido em 2026-05-05 21:06:42 BRT.

## Evidencias

- `_bridge_status_payload()` ja expõe o estado real do bridge, e o backend ja possui comandos relacionados como `pulse-telegram` e `poll-bridge`.
- A rota `/api/actions/assistant-enablement` agora exige sessao autenticada de produto e devolve `telegram_ready`, `whatsapp_ready` e `generated_at_utc`.
- `_recommendation_operational_action_path(...)` agora contem a entrada `("CHAT", "assistant_enablement") -> "/api/actions/assistant-enablement"`.
- Probe direto confirmou:
  - `status == HTTPStatus.OK`
  - `action == "assistant-enablement"`
  - `message == "Helena pronta com bridge Telegram ativo."`
  - resolvedor operacional retorna `/api/actions/assistant-enablement`
- `python -m py_compile scripts/serve_valley_admin.py` passou.

## Bloqueios

- Nenhum bloqueio aberto.

## Proxima acao

- So liberar outro motivo nao comercial quando ele tambem tiver endpoint autenticado proprio e validado.
