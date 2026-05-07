# v031 - Action Path Autenticado Em Recent Actions Operacionais

## Resumo

- Fechar o descompasso entre `recommendations` e `recent_actions` para eventos operacionais que ja possuem endpoint autenticado real.
- Assinar `action_path` em `recent_actions` para `STOCK` e `MARKETPLACE` runtime, mantendo `MOVE` sem navegacao ate existir rota propria.

## Checklist

- [x] Verificar no historico de planos qual era a sequencia natural apos `v028`, `v029` e `v030`. Concluido em 2026-05-06 14:57:17 BRT.
- [x] Atualizar `recent_actions` para usar `action_path` autenticado em eventos operacionais com endpoint existente. Concluido em 2026-05-06 14:58:49 BRT.
- [x] Validar o payload de `/api/me/recent-actions` para `STOCK` e `MARKETPLACE`. Concluido em 2026-05-06 14:58:49 BRT.
- [x] Consolidar a entrega no plano, no indice e no resumo. Concluido em 2026-05-06 14:58:49 BRT.

## Evidencias

- `recommendations` ja assinam `action_path` para `stock_runtime_attention`, `public_runtime_temporary`, `release_pending` e `assistant_enablement`.
- `recent_actions` ainda mantem `action_path=""` para os eventos `stock::...` e `runtime::...`, apesar de os endpoints reais ja existirem.
- `MOVE` continua sem endpoint operacional autenticado proprio; portanto nao deve receber `action_path` artificial.
- `scripts/serve_valley_admin.py` agora assina `action_path="/api/actions/stock-runtime-attention"` no evento `STOCK`.
- `scripts/serve_valley_admin.py` agora assina `action_path="/api/actions/runtime-persistence"` no evento `MARKETPLACE` quando o runtime publico estiver `healthy` e `temporary=true`.
- Validacoes executadas em 2026-05-06 14:58:49 BRT:
  - `python -m py_compile scripts\serve_valley_admin.py`
  - Probe local de `_recent_action_records(None, limit=10)` retornou:
    - `MARKETPLACE | /api/actions/runtime-persistence | MARKETPLACE`
    - `STOCK | /api/actions/stock-runtime-attention | STOCK`
    - `MOVE |  | MOVE`

## Bloqueios

- Nenhum bloqueio aberto.

## Proxima acao

- Plano concluido. Proxima acao natural: liberar `action_path` apenas para o proximo evento operacional da home quando existir endpoint autenticado proprio e validado para ele.
