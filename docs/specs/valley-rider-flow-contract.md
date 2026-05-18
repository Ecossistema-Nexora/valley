# Valley Rider Flow Contract

Escopo: aplicativo exclusivo do entregador.

## Fluxo mandatário

1. Home mapa-first.
2. Entregador alterna disponibilidade.
3. Sistema apresenta oferta ativa.
4. Oferta exibe somente repasse do entregador.
5. Entregador aceita rota.
6. App muda para etapa de coleta.
7. Entregador confirma coleta.
8. App muda para etapa de entrega.
9. Entregador confirma entrega.
10. App exibe comprovante.
11. App volta ao mapa.

## Estados

- `offline`
- `online`
- `offer_available`
- `accepted_to_pickup`
- `picked_up_to_dropoff`
- `delivered_proof`
- `incident_active`

## Regra BR-PRO-001

O app Rider não pode receber custo operacional, taxa da plataforma, margem interna, comissão ou split. A fonte segura para ofertas é `rider_frontend_offer_view`.

## Navegação

Nenhuma tela pode ser beco sem saída. Todas as telas internas devem voltar ao mapa principal.
