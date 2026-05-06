# v028 - Endpoint Autenticado Stock Runtime Attention

## Resumo

- Implementar rota operacional autenticada para `stock_runtime_attention`.
- Ligar o motivo ao backend com dado real do motor STOCK, em vez de abrir modulo por fallback.

## Checklist

- [x] Confirmar que o motivo ja possui base real no backend via `stock_sync_status`. Concluido em 2026-05-05 21:08:41 BRT.
- [ ] Implementar rota autenticada para `stock_runtime_attention`.
- [ ] Mapear `("STOCK", "stock_runtime_attention")` no resolvedor operacional.
- [ ] Validar a rota e o resolvedor.
- [ ] Consolidar a entrega no plano e no resumo.

## Evidencias

- `_stock_sync_status_payload()` ja expõe `status`, `queued_reason`, `last_result` e timestamps do motor.

## Bloqueios

- Nenhum bloqueio aberto.

## Proxima acao

- Expor `/api/actions/stock-runtime-attention` com sessao autenticada de produto.
