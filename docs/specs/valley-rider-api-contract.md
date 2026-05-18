# Valley Rider API Contract

## Home

GET `/api/rider/home`

Retorna status operacional, resumo de ganhos e rota ativa.

## Disponibilidade

PATCH `/api/rider/availability`

Entrada:

- `presence_status`: `OFFLINE`, `ONLINE`, `BUSY`, `PAUSED`, `SOS`.
- `service_zone_code`.
- `device_id_hash`.

Destino:

- `rider_realtime_sessions`.
- `rider_profiles.availability_status`.

## GPS

POST `/api/rider/location/ping`

Entrada:

- `latitude`.
- `longitude`.
- `accuracy_m`.
- `heading_deg`.
- `speed_kph`.
- `battery_level`.
- `shipment_id` ou `trip_id` quando existir.

Destino:

- `rider_location_pings`.

## Oferta ativa

GET `/api/rider/offers/active`

Fonte obrigatória:

- `rider_frontend_offer_view`.

Regra:

- nunca retornar custo interno, margem, taxa da plataforma ou split.

## Aceitar rota

POST `/api/rider/offers/{offer_id}/accept`

Destino:

- `rider_delivery_offers.offer_status = ACCEPTED`.
- `delivery_shipments.rider_user_id` quando for entrega.
- `mobility_trips.rider_user_id` quando for corrida.

## Coleta

POST `/api/rider/shipments/{shipment_id}/pickup`

Destino:

- `delivery_shipments.shipment_status`.
- `delivery_shipment_events`.

## Entrega

POST `/api/rider/shipments/{shipment_id}/deliver`

Destino:

- `delivery_shipments.delivered_at`.
- `delivery_shipment_events`.
- `document_records` quando houver prova.

## Incidente

POST `/api/rider/security/incidents`

Destino:

- `security_incidents`.
- `security_incident_events`.

## OTA

GET `/api/rider/ota/state`
POST `/api/rider/ota/state`

Destino:

- `rider_ota_patch_state`.
