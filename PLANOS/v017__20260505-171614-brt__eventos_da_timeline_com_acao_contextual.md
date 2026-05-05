# v017 - Eventos Da Timeline Com Acao Contextual

## Resumo

- Tornar cada evento da timeline clicavel.
- Acionar `product-interest`, `open-media` ou `checkout` quando a trilha tiver `item_id`, com fallback para sheet contextual do modulo.

## Checklist

- [x] Localizar os hooks de acao do runtime e o ponto de integracao na home. Concluido em 2026-05-05 17:16:14 BRT.
- [x] Implementar handler contextual por evento da jornada. Concluido em 2026-05-05 17:16:14 BRT.
- [x] Conectar os eventos da timeline ao handler na overview. Concluido em 2026-05-05 17:16:14 BRT.
- [x] Exibir retorno de runtime ou fallback contextual em UI. Concluido em 2026-05-05 17:16:14 BRT.
- [x] Validar Flutter analyze e consolidar a entrega. Concluido em 2026-05-05 17:16:14 BRT.

## Evidencias

- O runtime exposto pela app ja trabalha com `/api/actions/product-interest`, `/api/actions/open-media` e `/api/actions/checkout`.
- A timeline da home ja conhece `item_id`, `module_code`, `kind`, `domain_action` e `journey_stage`.
- Os eventos da timeline agora tentam acao real de runtime via `ProductApiRepository.invokePath(...)`, resolvendo o endpoint a partir do contexto da trilha.
- Quando a chamada nao retorna acao executavel, a home cai em sheet contextual com abertura do modulo dominante.
- `dart analyze lib/src/ui/valley_home_shell.dart lib/src/data/product_api_models.dart lib/src/data/product_api_repository.dart` passou sem issues.

## Bloqueios

- Nenhum bloqueio aberto.

## Proxima acao

- Evoluir o retorno contextual para deep link de oferta especifica quando o runtime passar a expor path por item no payload da home.
