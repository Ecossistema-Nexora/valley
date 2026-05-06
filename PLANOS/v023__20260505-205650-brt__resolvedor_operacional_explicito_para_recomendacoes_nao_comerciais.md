# v023 - Resolvedor Operacional Explicito Para Recomendacoes Nao Comerciais

## Resumo

- Separar no backend o resolvedor de `action_path` comercial do resolvedor operacional nao comercial.
- Garantir que recomendacoes nao comerciais so recebam `action_path` quando houver endpoint autentico registrado nesse resolvedor.

## Checklist

- [x] Localizar o resolvedor atual de recomendacoes e os motivos nao comerciais ativos. Concluido em 2026-05-05 20:56:50 BRT.
- [x] Criar resolvedor operacional dedicado para recomendacoes nao comerciais. Concluido em 2026-05-05 20:56:50 BRT.
- [x] Integrar o resolvedor ao fluxo de recomendacoes sem alterar o contrato do frontend. Concluido em 2026-05-05 20:56:50 BRT.
- [x] Validar a politica com probe logico e consolidar a entrega. Concluido em 2026-05-05 20:56:50 BRT.

## Evidencias

- Hoje a guarda semantica ja impede `action_path` artificial, mas a politica ainda estava implícita dentro do resolvedor comercial.
- `_recommendation_operational_action_path(...)` foi criado como resolvedor dedicado para motivos nao comerciais.
- O mapa operacional foi deixado vazio de proposito; so deve ser preenchido quando existir endpoint autenticado real.
- Probe logico confirmou:
  - `commerce_activation -> /api/actions/product-interest?item_id=abc`
  - `assistant_enablement -> ""`
  - `public_runtime_temporary -> ""`
- `python -m py_compile scripts/serve_valley_admin.py` passou.

## Bloqueios

- Nenhum bloqueio aberto.

## Proxima acao

- Popular `_recommendation_operational_action_path(...)` apenas quando um endpoint operacional autentico for implementado para uma recomendacao nao comercial especifica.
