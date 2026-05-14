<!--
PROPOSITO: Documentar v010 20260505 144807 brt implementacao contratos me e integracao home flutter no escopo operacional do Valley.
CONTEXTO: Este arquivo registra orientacoes, decisoes ou plano associado ao caminho PLANOS/v010__20260505-144807-brt__implementacao_contratos_me_e_integracao_home_flutter.md.
REGRAS: Manter informacao rastreavel, preservar nomenclatura Valley e atualizar ao mudar a rotina correspondente.
-->

# v010 - Implementacao Contratos Me E Integracao Home Flutter

## Resumo

- Implementar os contratos `/me/*` do MVP no servidor local do Valley.
- Integrar a `ValleyHomeShell` com preferencias, recomendacoes, acoes recentes e identity score vindos da API.

## Checklist

- [x] Mapear o servidor atual e o data layer Flutter para encaixar os contratos `/me/*`. Concluido em 2026-05-05 14:48:07 BRT.
- [x] Implementar `GET /api/me/home`, `GET /api/me/recent-actions`, `GET /api/me/recommendations` e `GET /api/me/identity-score` em `scripts/serve_valley_admin.py`. Concluido em 2026-05-05 14:48:07 BRT.
- [x] Implementar `PUT /api/me/home/preferences` com persistencia por usuario autenticado. Concluido em 2026-05-05 14:48:07 BRT.
- [x] Adicionar modelos e metodos no `ProductApiRepository` para consumir os contratos `/me/*`. Concluido em 2026-05-05 14:48:07 BRT.
- [x] Integrar `frontend/flutter/lib/src/ui/valley_home_shell.dart` com fallback local para preferencias e leitura remota da home. Concluido em 2026-05-05 14:48:07 BRT.
- [x] Validar sintaxe Python, analise Dart e smoke test HTTP dos contratos alterados. Concluido em 2026-05-05 15:00:36 BRT.
- [x] Atualizar o indice `PLANOS/INDEX.md` com esta entrega. Concluido em 2026-05-05 15:00:36 BRT.

## Evidencias

- `scripts/serve_valley_admin.py` passa a expor a camada `/api/me/*` com agregacao para home, identity score, recommendations e recent actions.
- `frontend/flutter/lib/src/data/product_api_models.dart` ganhou os modelos de home personalizada do MVP.
- `frontend/flutter/lib/src/data/product_api_repository.dart` agora consome e persiste os contratos `/me/*`.
- `frontend/flutter/lib/src/ui/valley_home_shell.dart` passou a sincronizar a home com a API e manter fallback local quando a sessao ou o backend nao estiverem disponiveis.

## Bloqueios

- Nenhum bloqueio aberto nesta entrega.

## Proxima acao

- Avancar para a segunda fatia do MVP: ligar a home principal em runtime ativo e desdobrar os dados reais de recomendacao e acoes por dominio operacional.
