# v028 - Endpoint Autenticado Stock Runtime Attention

## Resumo

- Implementar rota operacional autenticada para `stock_runtime_attention`.
- Ligar o motivo ao backend com dado real do motor STOCK, em vez de abrir modulo por fallback.

## Checklist

- [x] Confirmar que o motivo ja possui base real no backend via `stock_sync_status`. Concluido em 2026-05-05 21:08:41 BRT.
- [x] Implementar rota autenticada para `stock_runtime_attention`. Concluido em 2026-05-05 21:21:19 BRT.
- [x] Mapear `("STOCK", "stock_runtime_attention")` no resolvedor operacional. Concluido em 2026-05-05 21:21:19 BRT.
- [x] Validar a rota e o resolvedor. Concluido em 2026-05-05 21:21:19 BRT.
- [x] Consolidar a entrega no plano e no resumo. Concluido em 2026-05-05 21:21:19 BRT.

## Evidencias

- `_stock_sync_status_payload()` ja expõe `status`, `queued_reason`, `last_result` e timestamps do motor.
- A rota `/api/actions/stock-runtime-attention` agora exige sessao autenticada de produto e devolve `status`, `queued_reason`, `last_result`, `generated_at_utc` e `review_scope=product`.
- `_recommendation_operational_action_path(...)` agora contem a entrada `("STOCK", "stock_runtime_attention") -> "/api/actions/stock-runtime-attention"`.
- Validacoes executadas em 2026-05-05 21:21:19 BRT:
  - `python -m py_compile scripts\serve_valley_admin.py`
  - POST sem token em `/api/actions/stock-runtime-attention` retornou `401`
  - POST com sessao `product` retornou `status=ok`, `action=stock-runtime-attention`, `service=valley-stock-sync`, `stock_status=queued`
  - resolvedor operacional retornou `/api/actions/stock-runtime-attention`

## Bloqueios

- Nenhum bloqueio aberto.

## Proxima acao

- Plano concluido. Proxima acao natural: selecionar o proximo motivo operacional que ja tenha backend real antes de liberar novo action_path.
