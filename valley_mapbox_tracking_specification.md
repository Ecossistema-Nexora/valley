# DIRETRIZ E ARQUITETURA DE ENGENHARIA: SISTEMA DE RASTREAMENTO EM TEMPO REAL (MAPBOX)

## PROJETO: VALLEY OMNIVERSE - MODULO MARKETPLACE (MVP)

Este documento e a fonte persistente da frente de rastreamento em tempo real para pedidos originados exclusivamente no Marketplace de lojistas locais Valley.

## Protocolo de Execucao

- Execucao autonoma sem confirmacoes intermediarias para trabalho local seguro.
- Status report a cada 5 minutos ou a cada bloco logico relevante.
- Mapbox e o provedor principal do MVP.
- OSM/OSRM deve ficar preparado por abstracao para substituicao futura sem reescrever regra de negocio.

## Arquitetura

```text
App Courier -------- GPS Telemetry/WebSocket --------> Backend Valley Tracking
                                                          |
                       +----------------------------------+----------------------------------+
                       |                                                                     |
                       v                                                                     v
              APK Usuario / Cliente                                                Painel Merchant / ERP
              - Live Update / notificacao                                           - Monitoramento de frota
              - Snapshot de mapa em lock screen                                     - Despacho local
              - Reabertura imediata do app                                          - Suporte ao cliente
```

## Pilares

### Courier

- Foreground Service persistente no Android.
- Telemetria por WebSocket a cada 3 segundos.
- Filtro de ruido por distancia minima e tempo.
- Contrato preparado para Mapbox Navigation SDK.

### Usuario

- Notificacao persistente e dinamica quando o pedido for aceito/despachado.
- Lock screen com status publico e snapshot de mapa atualizado.
- Interpolacao do marcador entre coordenadas recebidas.
- Reabertura imediata do app ao tocar.

### Merchant / ERP

- Painel de entregas em tempo real para pedidos locais do lojista.
- Visao de status, ETA, entregador, coordenadas e mapa operacional.
- Base pronta para Mapbox GL JS quando `VALLEY_MAPBOX_PUBLIC_TOKEN` estiver disponivel.

## Etapas

- [x] Abstracao de mapas e rotas Mapbox/OSM.
- [x] Contrato de WebSocket/telemetria.
- [x] Foreground Service Android para notificacao e mapa por snapshot.
- [x] Ponte Flutter/Android.
- [ ] Validacao final Android release.
- [ ] Teste em emulador/dispositivo fisico com permissao de notificacao.

