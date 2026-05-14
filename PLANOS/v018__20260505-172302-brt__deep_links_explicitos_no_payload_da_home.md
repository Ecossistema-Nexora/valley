<!--
PROPOSITO: Documentar v018 20260505 172302 brt deep links explicitos no payload da home no escopo operacional do Valley.
CONTEXTO: Este arquivo registra orientacoes, decisoes ou plano associado ao caminho PLANOS/v018__20260505-172302-brt__deep_links_explicitos_no_payload_da_home.md.
REGRAS: Manter informacao rastreavel, preservar nomenclatura Valley e atualizar ao mudar a rotina correspondente.
-->

# v018 - Deep Links Explicitos No Payload Da Home

## Resumo

- Expor no `/api/me/home` links explicitos por item e por acao dentro de `user_module_trails`.
- Remover a inferencia de endpoint no Flutter e fazer a home consumir os paths assinados pelo backend.

## Checklist

- [x] Localizar os pontos de enriquecimento do payload e o handler Flutter atual. Concluido em 2026-05-05 17:23:02 BRT.
- [x] Enriquecer `user_module_trails` com `primary_action_path`, `checkout_path`, `media_path` e `interest_path`. Concluido em 2026-05-05 17:23:02 BRT.
- [x] Atualizar o contrato Dart para consumir os novos campos. Concluido em 2026-05-05 17:23:02 BRT.
- [x] Remover a heuristica local do frontend e usar os deep links do payload. Concluido em 2026-05-05 17:23:02 BRT.
- [x] Validar backend, Dart analyze e smoke do payload. Concluido em 2026-05-05 17:23:02 BRT.

## Evidencias

- O runtime ja expunha `/api/actions/product-interest`, `/api/actions/open-media` e `/api/actions/checkout`; faltava assinar isso diretamente no payload da home.
- `user_module_trails` agora sai do backend com `primary_action_path`, `primary_action_label`, `checkout_path`, `media_path`, `interest_path` e `open_module_code`.
- O Flutter deixou de inferir endpoint por `journey_stage` e passou a usar `trail.primaryActionPath`.
- Smoke do `/api/me/home` confirmou, para item real `f1375a4e-00e3-5672-af11-73e943584316`, `primary_action_path=/api/actions/product-interest?...`, `checkout_path=/api/actions/checkout?...` e `open_module_code=STOCK`.
- `python -m py_compile scripts/serve_valley_admin.py` e `dart analyze lib/src/ui/valley_home_shell.dart lib/src/data/product_api_models.dart lib/src/data/product_api_repository.dart` passaram.

## Bloqueios

- Nenhum bloqueio aberto.

## Proxima acao

- Evoluir o backend para também expor deep links por recomendacao e por recent action, removendo as ultimas inferencias residuais da home.
