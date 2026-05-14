<!--
PROPOSITO: Documentar v020 20260505 203958 brt action path itemizado para recomendacoes pay e marketplace no escopo operacional do Valley.
CONTEXTO: Este arquivo registra orientacoes, decisoes ou plano associado ao caminho PLANOS/v020__20260505-203958-brt__action_path_itemizado_para_recomendacoes_pay_e_marketplace.md.
REGRAS: Manter informacao rastreavel, preservar nomenclatura Valley e atualizar ao mudar a rotina correspondente.
-->

# v020 - Action Path Itemizado Para Recomendacoes Pay E Marketplace

## Resumo

- Fazer `PAY` e `MARKETPLACE` herdarem `action_path` itemizado a partir da trilha comercial dominante quando nao houver trilha propria do modulo.
- Reduzir os casos em que a recomendacao depende apenas de `open_module_code`.

## Checklist

- [x] Localizar o builder de recomendacoes e os helpers de trilha atuais. Concluido em 2026-05-05 20:39:58 BRT.
- [x] Adicionar helper para localizar a trilha comercial dominante mais recente. Concluido em 2026-05-05 20:39:58 BRT.
- [x] Assinar `action_path` itemizado para recomendacoes de `PAY`. Concluido em 2026-05-05 20:39:58 BRT.
- [x] Assinar `action_path` itemizado para recomendacoes de `MARKETPLACE`. Concluido em 2026-05-05 20:39:58 BRT.
- [x] Validar com smoke do payload e consolidar a entrega. Concluido em 2026-05-05 20:39:58 BRT.

## Evidencias

- `recommendations` ja traz `action_path`, mas ainda pode voltar vazio quando o modulo recomendado nao possui trilha propria recente.
- O backend agora usa `_latest_commerce_trail(...)` e `_recommendation_action_path(...)` para herdar contexto itemizado da jornada dominante.
- Smoke com apenas trilha `STOCK` confirmou:
  - `MARKETPLACE.action_path=/api/actions/product-interest?item_id=f1375a4e-00e3-5672-af11-73e943584316`
  - `PAY.action_path=/api/actions/checkout?item_id=f1375a4e-00e3-5672-af11-73e943584316`
- `python -m py_compile scripts/serve_valley_admin.py` passou.

## Bloqueios

- Nenhum bloqueio aberto.

## Proxima acao

- Evoluir o mesmo principio para recomendacoes operacionais de `STOCK` e `CHAT` quando houver contexto mais granular do runtime ou de item.
