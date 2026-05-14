<!--
PROPOSITO: Documentar v022 20260505 205437 brt guarda backend para action path nao comercial no escopo operacional do Valley.
CONTEXTO: Este arquivo registra orientacoes, decisoes ou plano associado ao caminho PLANOS/v022__20260505-205437-brt__guarda_backend_para_action_path_nao_comercial.md.
REGRAS: Manter informacao rastreavel, preservar nomenclatura Valley e atualizar ao mudar a rotina correspondente.
-->

# v022 - Guarda Backend Para Action Path Nao Comercial

## Resumo

- Impedir no backend que recomendacoes nao comerciais recebam `action_path` itemizado por inferencia.
- Manter `open_module_code` como fallback de navegacao quando nao houver acao operacional autentica.

## Checklist

- [x] Localizar o resolvedor atual de `action_path` para recomendacoes. Concluido em 2026-05-05 20:54:37 BRT.
- [x] Adicionar guarda semantica para motivos nao comerciais. Concluido em 2026-05-05 20:54:37 BRT.
- [x] Validar a regressao logica para `PAY` comercial versus recomendacoes operacionais. Concluido em 2026-05-05 20:54:37 BRT.
- [x] Consolidar a politica no plano e no resumo. Concluido em 2026-05-05 20:54:37 BRT.

## Evidencias

- O resolvedor atual consegue derivar `action_path` itemizado a partir de trilha dominante; faltava travar explicitamente os motivos nao comerciais.
- `_recommendation_action_path(...)` agora so devolve link itemizado para `commerce_activation` e `checkout_ready`.
- Probe logico confirmou:
  - `commerce_activation -> /api/actions/product-interest?item_id=abc`
  - `checkout_ready -> /api/actions/checkout?item_id=abc`
  - `stock_runtime_attention -> ""`
  - `public_runtime_temporary -> ""`
- `python -m py_compile scripts/serve_valley_admin.py` passou.

## Bloqueios

- Nenhum bloqueio aberto.

## Proxima acao

- Manter a regra: recomendacoes nao comerciais so ganham `action_path` quando existir uma acao operacional autentica exposta pelo backend.
