# v021 - Derivacao Itemizada Para Recomendacoes Operacionais Remanescentes

## Resumo

- Aplicar a mesma derivacao itemizada nas recomendacoes operacionais que ainda podiam cair apenas em `open_module_code`.
- Fechar principalmente `runtime-persistence` quando houver jornada dominante de `MARKETPLACE`.

## Checklist

- [x] Mapear as recomendacoes remanescentes sem itemizacao garantida. Concluido em 2026-05-05 20:52:56 BRT.
- [x] Aplicar derivacao itemizada em recomendacoes operacionais com modulo comercial dominante. Concluido em 2026-05-05 20:52:56 BRT.
- [x] Validar com smoke ou evidencia de payload. Concluido em 2026-05-05 20:52:56 BRT.
- [x] Consolidar o resultado e documentar as recomendacoes que continuam sem item por nao terem contexto acionavel real. Concluido em 2026-05-05 20:52:56 BRT.

## Evidencias

- `PAY`, `MARKETPLACE` e `STOCK` ja tinham derivacao itemizada em parte do fluxo; faltava estender isso para recomendacoes operacionais restantes, especialmente `runtime-persistence`.
- `runtime-persistence` agora usa `_recommendation_action_path(..., 'MARKETPLACE')`, herdando contexto itemizado da trilha comercial dominante.
- Validacao logica direta confirmou:
  - `MARKETPLACE -> /api/actions/product-interest?item_id=abc`
  - `PAY -> /api/actions/checkout?item_id=abc`
- `python -m py_compile scripts/serve_valley_admin.py` passou.
- Recomendacoes que continuam sem `action_path` itemizado por desenho atual:
  - `helena-routine`
  - `release-pending`
  porque hoje elas nao nascem de item dominante nem de payload comercial itemizavel.

## Bloqueios

- Nenhum bloqueio aberto.

## Proxima acao

- Evoluir `helena-routine` e `release-pending` apenas quando existir uma acao contextual real de backend, em vez de fabricar deep link sem suporte operacional.
