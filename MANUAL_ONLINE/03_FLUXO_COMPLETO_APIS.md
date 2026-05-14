<!--
PROPOSITO: Documentar 03 FLUXO COMPLETO APIS no escopo operacional do Valley.
CONTEXTO: Este arquivo registra orientacoes, decisoes ou plano associado ao caminho MANUAL_ONLINE/03_FLUXO_COMPLETO_APIS.md.
REGRAS: Manter informacao rastreavel, preservar nomenclatura Valley e atualizar ao mudar a rotina correspondente.
-->

# Fluxo Completo de APIs

Este documento descreve a superficie de API recomendada para o estado atual do Valley.

Ele nao e um `OpenAPI` final.

Ele e o mapa funcional de endpoints, comandos principais e eventos emitidos para cada fluxo de negocio.

## Convencoes

Prefixo:

- `/v1`

Headers obrigatorios em fluxos criticos:

- `Authorization`
- `X-Correlation-Id`
- `Idempotency-Key` em create financeiro, order, GOLD, dispatch e documento

Autenticacao:

- usuario final: `JWT`
- admin: `JWT` com escopo admin + RBAC/ABAC
- parceiro externo: `API key hash`, `JWT`, `OAuth2` ou `mTLS`

Resposta padrao:

- `request_id`
- `correlation_id`
- `data`
- `errors`

## Grupos de API

### Identity API

- `POST /v1/id/users`
- `GET /v1/id/users/{user_id}`
- `PATCH /v1/id/users/{user_id}`
- `POST /v1/id/users/{user_id}/kyc/submissions`
- `POST /v1/id/users/{user_id}/pj-profile`
- `POST /v1/id/users/{user_id}/rider-profile`
- `POST /v1/id/users/{user_id}/led-cards`

### Pay API

- `POST /v1/pay/wallets/bootstrap`
- `GET /v1/pay/wallets/{wallet_id}`
- `POST /v1/pay/transactions/authorize`
- `POST /v1/pay/transactions/settle`
- `POST /v1/pay/transactions/refund`
- `POST /v1/pay/transactions/adjust`
- `GET /v1/pay/transactions/{transaction_id}`

### Marketplace API

- `POST /v1/marketplace/storefronts`
- `POST /v1/marketplace/storefronts/{storefront_id}/zones`
- `POST /v1/marketplace/items`
- `POST /v1/marketplace/listings`
- `POST /v1/marketplace/listings/{listing_id}/price-check`
- `POST /v1/marketplace/listings/{listing_id}/publish`
- `GET /v1/marketplace/listings`
- `GET /v1/marketplace/listings/{listing_id}`

### Orders API

- `POST /v1/orders`
- `POST /v1/orders/checkout`
- `GET /v1/orders/{order_id}`
- `POST /v1/orders/{order_id}/confirm`
- `POST /v1/orders/{order_id}/cancel`
- `POST /v1/orders/{order_id}/refund`

### Growth API

- `POST /v1/rules`
- `POST /v1/rules/{rule_id}/versions`
- `POST /v1/rules/{rule_id}/bindings`
- `POST /v1/rules/evaluate`
- `POST /v1/growth/gold-campaigns`
- `POST /v1/growth/sale-validations`
- `POST /v1/growth/gold-campaign-events`
- `POST /v1/loyalty/pepita-ledger`
- `GET /v1/loyalty/accounts/{user_id}`

### Delivery API

- `POST /v1/delivery/shipments`
- `GET /v1/delivery/shipments/{shipment_id}`
- `POST /v1/delivery/dispatch`
- `POST /v1/delivery/shipments/{shipment_id}/events`

### Mobility API

- `POST /v1/mobility/trips`
- `GET /v1/mobility/trips/{trip_id}`
- `POST /v1/mobility/trips/{trip_id}/events`

### Security API

- `POST /v1/security/signals/sos`
- `POST /v1/security/incidents`
- `POST /v1/security/incidents/{incident_id}/events`
- `POST /v1/security/users/{user_id}/trusted-contacts`
- `POST /v1/security/users/{user_id}/biometric-credentials`

### Tech API

- `POST /v1/tech/api-clients`
- `POST /v1/tech/api-clients/{api_client_id}/credentials`
- `POST /v1/tech/connectors`
- `POST /v1/tech/webhooks/subscriptions`
- `POST /v1/tech/webhooks/{subscription_id}/deliveries`

### Legal e Docs API

- `POST /v1/legal/contracts`
- `POST /v1/legal/contracts/{contract_id}/parties`
- `POST /v1/legal/contracts/{contract_id}/signatures`
- `POST /v1/legal/disputes`
- `POST /v1/docs/records`
- `POST /v1/docs/receipts`

### AI e Agenda API

- `POST /v1/ai/memory`
- `GET /v1/ai/memory/{user_id}`
- `POST /v1/chat/conversations`
- `POST /v1/chat/conversations/{conversation_id}/messages`
- `POST /v1/agenda/items`
- `PATCH /v1/agenda/items/{agenda_item_id}`

## Fluxo 1 - Onboarding, KYC e Wallet Bootstrap

Passo 1:

- `POST /v1/id/users`
- cria `users`
- opcionalmente cria `pj_profiles` ou `rider_profiles`

Passo 2:

- `POST /v1/id/users/{user_id}/kyc/submissions`
- atualiza `kyc_status`
- emite `identity.user.kyc_updated`

Passo 3:

- `POST /v1/pay/wallets/bootstrap`
- cria carteiras base do usuario
- emite `wallet.created`

Resposta funcional esperada:

- `user_id`
- `kyc_status`
- wallets iniciais
- `led_card_default_id` se existir

## Fluxo 2 - Merchant, Storefront, Listing e Price Check

Passo 1:

- `POST /v1/marketplace/storefronts`
- cria `merchant_storefronts`

Passo 2:

- `POST /v1/marketplace/storefronts/{storefront_id}/zones`
- cria `merchant_service_zones`

Passo 3:

- `POST /v1/marketplace/items`
- cria `inventory_items`

Passo 4:

- `POST /v1/marketplace/listings`
- cria `marketplace_listings`
- cria `marketplace_listing_controls` em estado inicial

Passo 5:

- `POST /v1/marketplace/listings/{listing_id}/price-check`
- grava `marketplace_competitor_snapshots`
- atualiza `marketplace_listing_controls`
- opcionalmente chama `POST /v1/rules/evaluate`

Eventos emitidos:

- `catalog.listing.created`
- `catalog.listing.price_checked`
- `catalog.listing.activated` ou `catalog.listing.auto_paused`

## Fluxo 3 - Checkout, Pagamento e Geracao de Pedido

Passo 1:

- `POST /v1/orders/checkout`
- cria `orders` em `PLACED`

Passo 2:

- `POST /v1/pay/transactions/authorize`
- cria `transactions` em `AUTHORIZED` ou `PENDING`

Passo 3:

- `POST /v1/pay/transactions/settle`
- liquida o pagamento
- atualiza `orders.payment_transaction_id`

Passo 4:

- `POST /v1/orders/{order_id}/confirm`
- transiciona pedido para `CONFIRMED`

Passo 5:

- `POST /v1/docs/receipts`
- grava `docs_receipts`
- opcionalmente gera `document_records`

Eventos emitidos:

- `order.placed`
- `ledger.transaction.authorized`
- `ledger.transaction.settled`
- `order.confirmed`
- `docs.receipt.generated`

## Fluxo 4 - GOLD, Validacao de Venda e Pepita

Passo 1:

- `POST /v1/growth/gold-campaigns`
- cria `gold_campaigns`
- opcionalmente referencia `gamification_campaigns`

Passo 2:

- `POST /v1/pay/transactions/authorize`
- reserva funding da campanha

Passo 3:

- venda ocorre por marketplace ou venda fisica validavel

Passo 4:

- `POST /v1/growth/sale-validations`
- cria `sale_validation_events`
- valida `order_id`, `transaction_id`, `GPS` ou `sale_reference_code`
- calcula `pepita_cap_brl`

Passo 5:

- `POST /v1/growth/gold-campaign-events`
- cria `gold_campaign_events`
- separa `valley_revenue_amount_brl` e `pepita_amount_brl`

Passo 6:

- `POST /v1/loyalty/pepita-ledger`
- cria `pepita_ledger`
- atualiza `pepita_accounts`

Eventos emitidos:

- `growth.gold_campaign.created`
- `growth.sale.validated`
- `loyalty.pepita.granted`

Regra de bloqueio:

- sem venda validada, nao existe liquidacao GOLD
- sem margem liquida de referencia, nao existe Pepita

## Fluxo 5 - Delivery e Dispatch

Passo 1:

- `POST /v1/delivery/shipments`
- cria `delivery_shipments`

Passo 2:

- `POST /v1/delivery/dispatch`
- cria ou atualiza `delivery_dispatch_runs` no MongoDB
- executa matching de riders

Passo 3:

- `POST /v1/delivery/shipments/{shipment_id}/events`
- grava `delivery_shipment_events`
- atualiza `delivery_shipments.shipment_status`

Passo 4:

- prova de entrega pode gerar `document_records`

Eventos emitidos:

- `delivery.shipment.created`
- `delivery.dispatch.started`
- `delivery.rider.assigned`
- `delivery.shipment.delivered`

## Fluxo 6 - Mobility e SOS

Passo 1:

- `POST /v1/mobility/trips`
- cria `mobility_trips`

Passo 2:

- `POST /v1/mobility/trips/{trip_id}/events`
- grava `mobility_trip_events`
- status avanca no lifecycle

Passo 3:

- se houver risco, `POST /v1/security/signals/sos`
- grava `security_signal_logs`

Passo 4:

- `POST /v1/security/incidents`
- cria `security_incidents`

Passo 5:

- `POST /v1/security/incidents/{incident_id}/events`
- grava `security_incident_events`

Eventos emitidos:

- `mobility.trip.started`
- `security.signal.opened`
- `security.incident.created`

## Fluxo 7 - Contrato, Assinatura e Documento

Passo 1:

- `POST /v1/legal/contracts`
- cria `legal_contracts`

Passo 2:

- `POST /v1/legal/contracts/{contract_id}/parties`
- cria `legal_contract_parties`

Passo 3:

- `POST /v1/legal/contracts/{contract_id}/signatures`
- cria `legal_signatures`
- anexa `document_records` quando houver

Passo 4:

- se houver conflito, `POST /v1/legal/disputes`
- cria `legal_disputes`

Eventos emitidos:

- `legal.contract.created`
- `legal.contract.signed`
- `legal.dispute.opened`

## Fluxo 8 - Admin de Regras e Runtime

Passo 1:

- `POST /v1/rules`
- cria `business_rule_definitions`

Passo 2:

- `POST /v1/rules/{rule_id}/versions`
- cria `business_rule_versions`

Passo 3:

- `POST /v1/rules/{rule_id}/bindings`
- cria `rule_runtime_bindings`

Passo 4:

- chamadas de negocio usam `POST /v1/rules/evaluate`
- gravam `rule_execution_events`

Eventos emitidos:

- `rules.binding.activated`
- `rules.execution.recorded`

## Sequencia Minima por Aplicativo

App do usuario:

- onboarding
- browse de listing
- checkout
- saldo e Pepitas
- agenda e chat

App do merchant:

- storefront
- item/listing
- price-check
- GOLD
- venda fisica validada
- receipts/docs

App do rider:

- dispatch
- shipment/trip event
- incident/SOS

Painel admin:

- rule governance
- campaign governance
- dispute governance
- observability

## Regras de API que nao devem ser quebradas

- nenhum endpoint financeiro sem `Idempotency-Key`
- nenhum endpoint de create critico sem `X-Correlation-Id`
- nenhum endpoint de incentivo sem venda validada
- nenhum endpoint de seguranca deve retornar biometria bruta
- nenhum endpoint de parceiro deve ler tabela fora do dominio exposto pelo service owner
