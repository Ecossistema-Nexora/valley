# v016 - Drilldown De Jornada Para Modulo Dominante

## Resumo

- Tornar os cards de jornada navegaveis.
- Abrir o modulo dominante da trilha com base em `journey_stage`, `module_code` e contexto da jornada.

## Checklist

- [x] Localizar o ponto de abertura de modulo dentro da overview. Concluido em 2026-05-05 17:07:35 BRT.
- [x] Definir heuristica de modulo dominante por jornada. Concluido em 2026-05-05 17:07:35 BRT.
- [x] Adicionar CTA e gesto de abertura nos cards de jornada. Concluido em 2026-05-05 17:07:35 BRT.
- [x] Validar comportamento e analyze do Flutter. Concluido em 2026-05-05 17:07:35 BRT.
- [x] Atualizar este plano e consolidar a entrega. Concluido em 2026-05-05 17:07:35 BRT.

## Evidencias

- `_OverviewPage` ja recebe `catalogModules` e `onOpenModule`, entao o drilldown pode ser resolvido sem alterar a arquitetura da home.
- A heuristica do modulo dominante prioriza `PAY` em `conversion`, `MARKETPLACE` em `research/consideration` e `STOCK` em `discovery`, com fallback para o ultimo modulo valido da trilha.
- Os cards de jornada agora sao clicaveis e exibem CTA `abrir <modulo>` quando existe um modulo resolvido.
- `dart analyze lib/src/ui/valley_home_shell.dart lib/src/data/product_api_models.dart` passou sem issues.

## Bloqueios

- Nenhum bloqueio aberto.

## Proxima acao

- Evoluir o card para destacar eventos clicaveis por etapa e, quando fizer sentido, abrir direto a oferta ou acao dentro do modulo.
