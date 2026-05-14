<!--
PROPOSITO: Documentar v025 20260505 210410 brt endpoint autenticado release pending no escopo operacional do Valley.
CONTEXTO: Este arquivo registra orientacoes, decisoes ou plano associado ao caminho PLANOS/v025__20260505-210410-brt__endpoint_autenticado_release_pending.md.
REGRAS: Manter informacao rastreavel, preservar nomenclatura Valley e atualizar ao mudar a rotina correspondente.
-->

# v025 - Endpoint Autenticado Release Pending

## Resumo

- Implementar a primeira rota operacional autentica para recomendacao nao comercial.
- Ligar `release_pending` ao endpoint autenticado e preencher `_recommendation_operational_action_path(...)` apenas para esse caso real.

## Checklist

- [x] Escolher o primeiro motivo nao comercial com dados reais e escopo autenticavel. Concluido em 2026-05-05 21:04:10 BRT.
- [x] Implementar rota autenticada para `release_pending`. Concluido em 2026-05-05 21:04:10 BRT.
- [x] Mapear `("REPLY", "release_pending")` no resolvedor operacional. Concluido em 2026-05-05 21:04:10 BRT.
- [x] Validar a rota e o resolvedor. Concluido em 2026-05-05 21:04:10 BRT.
- [x] Consolidar a entrega no plano e no resumo. Concluido em 2026-05-05 21:04:10 BRT.

## Evidencias

- `release_summary` ja existe no runtime e `release_pending` ja aparece como recomendacao admin, entao esse era o primeiro caso apto para sair do mapa vazio.
- A rota `/api/actions/release-pending` agora exige sessao `admin` e devolve `pending_total`, `checklist_total`, `release_version` e mensagem operacional.
- `_recommendation_operational_action_path(...)` agora contem a entrada `("REPLY", "release_pending") -> "/api/actions/release-pending"`.
- Probe direto confirmou:
  - `status == HTTPStatus.OK`
  - `action == "release-pending"`
  - `message == "7 itens pendentes no release de 19 para v47."`
  - resolvedor operacional retorna `/api/actions/release-pending`
- `python -m py_compile scripts/serve_valley_admin.py` passou.

## Bloqueios

- Nenhum bloqueio aberto.

## Proxima acao

- Escolher o proximo motivo nao comercial apenas quando houver outro endpoint autenticado real para ele.
