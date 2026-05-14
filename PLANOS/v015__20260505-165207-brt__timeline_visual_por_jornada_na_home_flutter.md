<!--
PROPOSITO: Documentar v015 20260505 165207 brt timeline visual por jornada na home flutter no escopo operacional do Valley.
CONTEXTO: Este arquivo registra orientacoes, decisoes ou plano associado ao caminho PLANOS/v015__20260505-165207-brt__timeline_visual_por_jornada_na_home_flutter.md.
REGRAS: Manter informacao rastreavel, preservar nomenclatura Valley e atualizar ao mudar a rotina correspondente.
-->

# v015 - Timeline Visual Por Jornada Na Home Flutter

## Resumo

- Transformar `user_module_trails` em uma timeline visual por jornada dentro da home Flutter.
- Reduzir a dependencia dos blocos genericos, destacando progressao comercial real por `journey_key` e `journey_stage`.

## Checklist

- [x] Localizar o ponto de encaixe da timeline dentro da overview da home. Concluido em 2026-05-05 16:52:07 BRT.
- [x] Agrupar trilhas por `journey_key` com ordenacao consistente e resumo por jornada. Concluido em 2026-05-05 16:52:07 BRT.
- [x] Renderizar a progressao de estagios e modulos em cards de jornada. Concluido em 2026-05-05 16:52:07 BRT.
- [x] Preservar o layout responsivo e o tom visual atual da home. Concluido em 2026-05-05 16:52:07 BRT.
- [x] Validar Flutter analyze e atualizar este plano com a entrega final. Concluido em 2026-05-05 16:52:07 BRT.

## Evidencias

- `valley_home_shell.dart` ja consome `userModuleTrails`, mas ainda nao os transforma em blocos visuais por jornada.
- A home agora agrupa `userModuleTrails` em `journeyGroups`, mostra modulos, estagios e uma timeline compacta por objetivo.
- `dart analyze lib/src/ui/valley_home_shell.dart lib/src/data/product_api_models.dart` passou sem issues.

## Bloqueios

- Nenhum bloqueio aberto.

## Proxima acao

- Evoluir a timeline para abrir drilldown por jornada e navegar direto para o modulo mais relevante do grupo.
