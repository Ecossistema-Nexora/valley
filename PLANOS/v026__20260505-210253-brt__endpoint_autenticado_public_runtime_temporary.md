# v026 - Endpoint Autenticado Public Runtime Temporary

## Resumo

- Implementar a segunda rota operacional autentica para recomendacao nao comercial.
- Ligar `public_runtime_temporary` ao endpoint autenticado e liberar esse motivo no mapa operacional apenas porque o runtime publico ja tem dado real no backend.

## Checklist

- [x] Escolher o proximo motivo nao comercial com base real no runtime. Concluido em 2026-05-05 21:02:53 BRT.
- [x] Implementar rota autenticada para `public_runtime_temporary`. Concluido em 2026-05-05 21:02:53 BRT.
- [x] Mapear `("MARKETPLACE", "public_runtime_temporary")` no resolvedor operacional. Concluido em 2026-05-05 21:02:53 BRT.
- [x] Validar a rota e o resolvedor. Concluido em 2026-05-05 21:02:53 BRT.
- [x] Consolidar a entrega no plano e no resumo. Concluido em 2026-05-05 21:02:53 BRT.

## Evidencias

- `_product_public_runtime_payload()` ja entrega `public_url`, `temporary` e `provider_status`, entao esse motivo ja tem base real para acao operacional autenticada.
- A rota `/api/actions/runtime-persistence` agora exige sessao `admin` e devolve `public_url`, `provider_status`, `temporary`, `provider` e `generated_at_utc`.
- `_recommendation_operational_action_path(...)` agora contem a entrada `("MARKETPLACE", "public_runtime_temporary") -> "/api/actions/runtime-persistence"`.
- Probe direto confirmou:
  - `status == HTTPStatus.OK`
  - `action == "runtime-persistence"`
  - `message == "Runtime publico temporario detectado."`
  - resolvedor operacional retorna `/api/actions/runtime-persistence`
- `python -m py_compile scripts/serve_valley_admin.py` passou.

## Bloqueios

- Nenhum bloqueio aberto.

## Proxima acao

- So liberar outro motivo nao comercial quando tambem houver endpoint autenticado proprio e validado para ele.
