<!--
PROPOSITO: Implementar rastreio Android em tempo real com notificacao dinamica e mapa.
CONTEXTO: O usuario solicitou experiencia similar a 99 para rastreio de corridas/pedidos aceitos.
REGRAS: Entregar comportamento Android real, respeitar limites de Live Updates e registrar status persistente a cada 5 minutos.
-->

# v064 - Android Live Tracking Notifications

## Resumo

Implementar rastreio em tempo real no Android para pedidos aceitos, com servico em foreground, notificacao persistente visivel em tela de bloqueio, atualizacao continua de status e mapa por snapshot.

## Decisao Tecnica

- Android Live Updates promovidos nao podem usar `RemoteViews`/layout customizado.
- Google Maps SDK interativo nao pode ser embutido diretamente na notificacao/tela de bloqueio.
- A entrega sera composta por:
  - notificacao principal de rastreio, ongoing, lockscreen public, preparada para promocao em Android 16+;
  - notificacao secundaria de mapa com `BigPictureStyle`, usando snapshot fornecido pelo backend ou mapa basico desenhado localmente;
  - servico Android foreground para atualizar sem abrir o app;
  - Platform Channel Flutter para iniciar, atualizar e encerrar rastreio.

## Checklist

- [x] Registrar plano/status persistente.
- [x] Auditar estrutura Android/Flutter atual.
- [x] Confirmar limites oficiais de Live Updates, foreground service e background location.
- [x] Implementar servico Android foreground de rastreio.
- [x] Implementar notificacao dinamica de status e mapa.
- [x] Expor Platform Channel Flutter.
- [x] Adicionar wrapper Dart para o modulo Valley.
- [x] Persistir especificacao Mapbox-first e abstracao OSM/OSRM.
- [x] Implementar gateway WebSocket de telemetria e smoke test.
- [x] Integrar payload de rastreio ao checkout Marketplace.
- [x] Adicionar painel Merchant/ERP de monitoramento em tempo real.
- [x] Validar JS/Python/WebSocket e registrar limitacao Gradle/Flutter.
- [x] Atualizar documentacao e indice.

## Evidencias

- Android atual possui `MainActivity.kt` simples e sem servicos.
- Manifest atual possui apenas `INTERNET` e `RECORD_AUDIO`.
- Fonte oficial Android confirma que Live Updates promovidos aparecem em lock screen/status bar chip, mas nao podem usar `customContentView`.
- Fonte oficial Android confirma foreground service como caminho para trabalho perceptivel ao usuario e notificacao persistente.
- `ValleyLiveTrackingService.kt` criado com notificacao principal ongoing/promovivel, notificacao de mapa `BigPictureStyle`, polling remoto e fallback vetorial.
- `MainActivity.kt` registra o canal `valley/live_tracking`; `valley_live_tracking_bridge.dart` expoe `startTracking`, `updateTracking` e `stopTracking`.
- `valley_mapbox_tracking_specification.md`, `config/tracking/valley_realtime_tracking.json`, `tracking_map_provider.dart` e `live_tracking_models.dart` registram a arquitetura Mapbox-first com fallback OSM/OSRM.
- `scripts/valley_realtime_tracking_ws.py` validado por smoke test real: handshake WebSocket, envio `courier.telemetry` e persistencia em `tmp/runtime/valley-realtime-tracking-state.json`.
- `admin/app.js` e `admin/styles.css` incluem painel Merchant/ERP com mapa operacional, tabela de entregas e refresh contra `/api/merchant-erp/delivery-tracking`.
- Validacoes concluidas: `node --check admin/app.js`, `python -m py_compile scripts\serve_valley_admin.py scripts\valley_realtime_tracking_ws.py`, `dart format` dos arquivos Flutter alterados e smoke test WebSocket.

## Bloqueios

- Restricao de plataforma: mapa interativo dentro da notificacao/lock screen nao e suportado pelo modelo de Live Update promovido; sera usado snapshot atualizado.
- Validacao completa `flutter analyze --no-pub` excedeu 10 minutos sem diagnostico.
- Validacao Gradle/Kotlin `:app:compileDebugKotlin` e `--dry-run` excederam o timeout sem diagnostico, inclusive usando o Gradle 8.14 direto do cache. Processos Java criados pela validacao foram encerrados.

## Proxima Acao

Proxima etapa natural: quando a ferramenta Android/Flutter destravar, executar `flutter analyze --no-pub` e `:app:compileDebugKotlin`; a implementacao funcional ja esta aplicada no repositorio.
