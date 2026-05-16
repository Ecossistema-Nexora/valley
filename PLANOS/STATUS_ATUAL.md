<!--
PROPOSITO: Status vivo das atividades Valley conduzidas pelo Codex.
CONTEXTO: Atualizacao persistente obrigatoria a cada 5 minutos durante atividades em andamento.
REGRAS: Atualizar durante execucao, preservar historico essencial e evitar dados sensiveis.
-->

# Status Atual

- Ultima atualizacao BRT: 2026-05-16 03:57
- Cadencia mandataria: atualizar chat e este arquivo a cada 5 minutos durante atividades em andamento.
- Regra operacional: [REGRA_STATUS_5MIN.md](./REGRA_STATUS_5MIN.md)

## Atividade Atual

- Plano: `v064__20260516-022000-brt__android_live_tracking_notifications.md`
- Escopo: implementar rastreio Android em tempo real com notificacao dinamica, lock screen e mapa por snapshot.
- Status geral: implementado_com_validacao_parcial
- Proxima atualizacao prevista, se ainda houver tarefa em execucao: 2026-05-16 04:02 BRT

## Tarefas

| tarefa | status | evidencia |
| --- | --- | --- |
| Registrar plano/status persistente | concluido | `PLANOS/v064__20260516-022000-brt__android_live_tracking_notifications.md` criado. |
| Auditar estrutura Android/Flutter atual | concluido | Android possui `MainActivity.kt` simples e manifest sem servico de rastreio. |
| Confirmar limites oficiais Android | concluido | Live Updates promovidos nao aceitam `RemoteViews`; foreground service e o caminho para trabalho perceptivel ao usuario. |
| Implementar servico Android foreground de rastreio | concluido | `ValleyLiveTrackingService.kt` criado com polling/simulacao, service foreground e controle start/update/stop. |
| Implementar notificacao dinamica de status e mapa | concluido | Notificacao principal ongoing/promovivel e notificacao secundaria `BigPictureStyle` com snapshot/fallback desenhado. |
| Expor Platform Channel Flutter | concluido | `MainActivity.kt` registra canal `valley/live_tracking`; wrapper Dart criado. |
| Disparar rastreio no checkout aceito | concluido | `valley_product_shell.dart` chama `ValleyLiveTrackingBridge.startTracking` em checkout OK. |
| Persistir especificacao Mapbox-first | concluido | `valley_mapbox_tracking_specification.md` e `config/tracking/valley_realtime_tracking.json` criados. |
| Criar abstracao Mapbox/OSM | concluido | `tracking_map_provider.dart`, `live_tracking_models.dart` e provider OSM/OSRM estrutural criados. |
| Implementar WebSocket de telemetria | concluido | `scripts/valley_realtime_tracking_ws.py` validado com smoke test real. |
| Integrar checkout Marketplace | concluido | Payload `live_tracking` retornado pelo checkout e acionado pelo app Flutter. |
| Adicionar painel Merchant/ERP | concluido | Mapa operacional, tabela de entregas e botao de refresh adicionados ao painel lojista. |
| Validar Kotlin/Dart/manifest | parcial | JS/Python/WebSocket/Dart format passaram; `flutter analyze` e Gradle/Kotlin excederam timeout sem diagnostico. |
| Atualizar documentacao e indice | em_execucao | Plano v064 atualizado; indice sera recalculado na etapa final. |

## Bloqueios

- Restricao de plataforma: mapa interativo dentro de Live Update promovido nao e suportado; foi entregue snapshot Mapbox/fallback vetorial em notificacao de mapa.
- Bloqueio operacional de validacao: `flutter analyze --no-pub`, `:app:compileDebugKotlin` e `--dry-run` excederam timeout sem diagnostico; processos criados pela validacao foram encerrados.
