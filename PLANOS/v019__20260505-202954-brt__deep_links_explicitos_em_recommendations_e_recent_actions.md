<!--
PROPOSITO: Documentar v019 20260505 202954 brt deep links explicitos em recommendations e recent actions no escopo operacional do Valley.
CONTEXTO: Este arquivo registra orientacoes, decisoes ou plano associado ao caminho PLANOS/v019__20260505-202954-brt__deep_links_explicitos_em_recommendations_e_recent_actions.md.
REGRAS: Manter informacao rastreavel, preservar nomenclatura Valley e atualizar ao mudar a rotina correspondente.
-->

# v019 - Deep Links Explicitos Em Recommendations E Recent Actions

## Resumo

- Estender a assinatura de navegacao contextual do backend para `recommendations` e `recent_actions`.
- Tornar cards de recomendacao e linhas de recentes clicaveis com o mesmo contrato backend-first usado nas trilhas.

## Checklist

- [x] Localizar builders de `recommendations` e `recent_actions` no backend e no Flutter. Concluido em 2026-05-05 20:29:54 BRT.
- [x] Enriquecer `recommendations` com `action_path` e `open_module_code`. Concluido em 2026-05-05 20:29:54 BRT.
- [x] Enriquecer `recent_actions` com `action_path` e `open_module_code`. Concluido em 2026-05-05 20:29:54 BRT.
- [x] Atualizar contrato Dart e handlers da home. Concluido em 2026-05-05 20:29:54 BRT.
- [x] Validar backend, analyze e smoke do payload. Concluido em 2026-05-05 20:29:54 BRT.

## Evidencias

- `user_module_trails` ja saem com `primary_action_path`; falta estender o mesmo principio para as outras superficies acionaveis da home.
- `recent_actions` agora sai com `action_path` e `open_module_code`, inclusive para trilhas operacionais derivadas de `user_module_trails`.
- `recommendations` agora sai com `action_path` e `open_module_code`, com fallback semantico para abrir modulo quando nao ha acao itemizada assinada.
- A home Flutter passou a tornar cards de recomendacao e linhas de recentes clicaveis via handler unico backend-first.
- `python -m py_compile scripts/serve_valley_admin.py` e `dart analyze lib/src/ui/valley_home_shell.dart lib/src/data/product_api_models.dart lib/src/data/product_api_repository.dart` passaram.
- Smoke do runtime confirmou:
  - `recent_action` com `action_path` e `open_module_code`
  - `recommendation` com `open_module_code=PAY` e shape assinado pelo backend

## Bloqueios

- Nenhum bloqueio aberto.

## Proxima acao

- Evoluir o backend para assinar `action_path` itemizado tambem nas recomendacoes que hoje dependem apenas de abertura de modulo, reduzindo os ultimos fallbacks sem item.
