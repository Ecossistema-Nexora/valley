# Arquitetura Tecnica - Microservices e Eventos

Este documento transforma o banco atual do Valley em uma arquitetura tecnica de servicos, contratos sincronos e eventos assincronos.

O objetivo aqui nao e inventar outro produto.

O objetivo e traduzir o que ja existe em `database/postgres/001-011` e `database/mongodb/001-003` para uma topologia de runtime coerente.

## Principios

- `public.users.user_id` continua sendo o no central absoluto.
- `wallets`, `transactions`, `equity_ledger`, `pepita_ledger` e trilhas append-only continuam como source of truth relacional.
- MongoDB continua reservado para telemetria, social, dispatch, sinais de seguranca, agenda e payload semi-estruturado.
- Microservices compartilham o mesmo cluster PostgreSQL na fase atual, mas cada servico tem ownership logico do seu conjunto de tabelas.
- Integracao entre servicos deve acontecer por API ou evento; escrita direta em tabela de outro dominio e anti-pattern.
- Segredo bruto, biometria bruta, API key bruta, webhook secret bruto e fallback PIN bruto continuam descartados.

## Topologia Recomendada

Camada de entrada:

- `web-admin-bff` para painel administrativo, operacao, regras e governanca.
- `consumer-api-gateway` para app do usuario, merchant app, rider app e parceiros.
- `partner-api-gateway` para clients externos do Valley Tech com `API key hash`, `JWT`, `OAuth2` ou `mTLS`.

Camada de servicos:

- `identity-access-service`
- `wallet-ledger-service`
- `catalog-commerce-service`
- `orders-orchestration-service`
- `rules-growth-service`
- `delivery-dispatch-service`
- `mobility-service`
- `security-response-service`
- `tech-platform-service`
- `legal-docs-service`
- `social-media-service`
- `ai-agenda-service`
- `admin-control-plane-service`

Camada de dados:

- `postgres-core` como source of truth transacional.
- `mongo-ops` para alto volume, sinais, dispatch, social e agenda.
- `object-storage` para recibos, provas, documentos e anexos, sempre referenciados por URL/checksum no banco.

Camada de mensageria:

- `event-bus` recomendado em `NATS JetStream` na fase inicial por simplicidade operacional, reprocessamento e baixo overhead.
- Padrao de entrega: `at-least-once`.
- Padrao de protecao: `outbox` no PostgreSQL para publicacao confiavel de eventos de dominio.
- Padrao de consumo: `idempotent consumer` com `event_id`, `correlation_id` e chave de deduplicacao.

## Ownership por Servico

### 1. identity-access-service

Responsabilidade:

- onboarding, KYC/KYB, perfis PF/PJ/Rider, identidade forte e cartoes LED.

Ownership relacional:

- `users`
- `pj_profiles`
- `rider_profiles`
- `led_cards`
- `security_trusted_contacts`
- `security_biometric_credentials`

Eventos emitidos:

- `identity.user.created`
- `identity.user.kyc_updated`
- `identity.rider.activated`
- `identity.led_card.assigned`

### 2. wallet-ledger-service

Responsabilidade:

- carteiras, autorizacao, settle, refund, split, escrow, equity e saldo gamificado financeiro.

Ownership relacional:

- `wallets`
- `transactions`
- `equity_ledger`
- `plug_transactions`

Eventos emitidos:

- `wallet.created`
- `ledger.transaction.authorized`
- `ledger.transaction.settled`
- `ledger.transaction.failed`
- `equity.entry.created`

### 3. catalog-commerce-service

Responsabilidade:

- merchant onboarding operacional, estoque, preco, dropshipping, listings, storefronts e zonas.

Ownership relacional:

- `suppliers`
- `warehouses`
- `inventory_items`
- `inventory_lots`
- `inventory_movements`
- `marketplace_listings`
- `merchant_storefronts`
- `merchant_service_zones`
- `marketplace_listing_controls`
- `marketplace_competitor_snapshots`

Eventos emitidos:

- `catalog.item.created`
- `catalog.listing.created`
- `catalog.listing.price_checked`
- `catalog.listing.activated`
- `catalog.listing.auto_paused`
- `catalog.stock.changed`

### 4. orders-orchestration-service

Responsabilidade:

- pedido mestre, procurement, service work order, faturamento de fluxo e orquestracao da jornada de compra.

Ownership relacional:

- `orders`
- `procurement_orders`
- `procurement_order_items`
- `service_work_orders`
- `business_invoices`
- `business_payrolls`
- `affiliate_referrals`

Eventos emitidos:

- `order.placed`
- `order.confirmed`
- `order.cancelled`
- `order.refunded`
- `order.dispatched`

### 5. rules-growth-service

Responsabilidade:

- Rule Engine, campanhas, Pepitas, GOLD, validacao de venda e runtime de incentivos.

Ownership relacional:

- `business_rule_definitions`
- `business_rule_versions`
- `business_rule_audit`
- `rule_runtime_bindings`
- `rule_execution_events`
- `gamification_campaigns`
- `points_ledger`
- `pepita_accounts`
- `pepita_ledger`
- `gold_campaigns`
- `gold_campaign_events`
- `sale_validation_events`

Eventos emitidos:

- `rules.binding.activated`
- `rules.execution.recorded`
- `growth.gold_campaign.created`
- `growth.sale.validated`
- `loyalty.pepita.granted`
- `loyalty.pepita.redeemed`

### 6. delivery-dispatch-service

Responsabilidade:

- shipment, dispatch, alocacao de rider, checkpoint, ETA e prova de entrega.

Ownership relacional:

- `delivery_shipments`
- `delivery_shipment_events`

Ownership MongoDB:

- `delivery_dispatch_runs`
- `log_tracking_events`

Eventos emitidos:

- `delivery.shipment.created`
- `delivery.dispatch.started`
- `delivery.rider.assigned`
- `delivery.shipment.checkpoint`
- `delivery.shipment.delivered`

### 7. mobility-service

Responsabilidade:

- corrida urbana, checkpoint de viagem, tarificacao operacional e integracao rider/passageiro.

Ownership relacional:

- `mobility_trips`
- `mobility_trip_events`

Ownership MongoDB:

- `telemetry_logs`
- `fleet_vehicle_profiles`
- `fleet_maintenance_events`

Eventos emitidos:

- `mobility.trip.created`
- `mobility.trip.matched`
- `mobility.trip.started`
- `mobility.trip.completed`
- `mobility.trip.incident_opened`

### 8. security-response-service

Responsabilidade:

- SOS, sinais de risco, incidente, escalonamento e evidencias de resposta.

Ownership relacional:

- `security_incidents`
- `security_incident_events`

Ownership MongoDB:

- `security_signal_logs`

Eventos emitidos:

- `security.signal.opened`
- `security.incident.created`
- `security.incident.escalated`
- `security.incident.resolved`

### 9. tech-platform-service

Responsabilidade:

- API clients, credenciais por hash, conectores, webhooks e uso diario de API.

Ownership relacional:

- `tech_api_clients`
- `tech_api_credentials`
- `tech_integration_connectors`
- `tech_webhook_subscriptions`
- `tech_webhook_delivery_attempts`
- `tech_api_usage_daily`

Eventos emitidos:

- `tech.client.created`
- `tech.webhook.subscribed`
- `tech.webhook.delivery_recorded`

### 10. legal-docs-service

Responsabilidade:

- contratos, assinaturas, disputa, fallback PIN por hash, recibos e documentos rastreaveis.

Ownership relacional:

- `legal_contracts`
- `legal_contract_parties`
- `legal_signatures`
- `legal_disputes`
- `legal_audit_events`
- `legal_fallback_pin_credentials`
- `document_records`
- `docs_receipts`

Eventos emitidos:

- `legal.contract.created`
- `legal.contract.signed`
- `legal.dispute.opened`
- `docs.document.generated`
- `docs.receipt.generated`

### 11. social-media-service

Responsabilidade:

- feed, creator uploads, influencer metrics, midia e atribuicao social.

Ownership relacional:

- `creator_uploads`

Ownership MongoDB:

- `social_videos`
- `influencer_metrics`

Eventos emitidos:

- `media.upload.created`
- `social.video.published`
- `social.campaign.metric_aggregated`

### 12. ai-agenda-service

Responsabilidade:

- memoria contextual, advisor, chat, follow-up e agenda inteligente.

Ownership relacional:

- `advisor_insights`
- `financial_goals`
- `teletherapy_sessions`
- `chat_conversations`
- `chat_messages`

Ownership MongoDB:

- `ai_memory`
- `agenda_items`

Eventos emitidos:

- `ai.memory.created`
- `advisor.insight.generated`
- `chat.message.created`
- `agenda.item.scheduled`

### 13. admin-control-plane-service

Responsabilidade:

- governanca, RBAC/ABAC, modulo registry, backlog, automacao e observabilidade de negocio.

Ownership relacional:

- `module_catalog`
- `admin_users`
- `admin_permissions`
- `observability_incidents`
- `admin_action_audit`
- `module_delivery_registry`
- `module_evolution_backlog`
- `module_automation_runs`

Eventos emitidos:

- `admin.action.recorded`
- `module.delivery.updated`
- `observability.incident.created`

## Contratos Sincronos

Padrao recomendado:

- REST JSON para borda externa.
- gRPC opcional apenas entre servicos de alta frequencia quando houver ganho real.
- `Idempotency-Key` obrigatoria em create financeiro, funding GOLD, criacao de order, dispatch e documento.
- `X-Correlation-Id` obrigatoria em requests distribuidados.

Chamadas sincronas que fazem sentido:

- `consumer-api-gateway -> identity-access-service`
- `consumer-api-gateway -> wallet-ledger-service`
- `web-admin-bff -> admin-control-plane-service`
- `web-admin-bff -> rules-growth-service`
- `partner-api-gateway -> tech-platform-service`
- `orders-orchestration-service -> wallet-ledger-service` para authorize/settle
- `catalog-commerce-service -> rules-growth-service` para price-check e publish gate
- `delivery-dispatch-service -> security-response-service` para escalonamento imediato

## Backbone de Eventos

Topicos de dominio recomendados:

- `identity.user.created`
- `identity.user.kyc_updated`
- `wallet.transaction.settled`
- `catalog.listing.price_checked`
- `catalog.listing.activated`
- `order.placed`
- `order.confirmed`
- `growth.gold_campaign.created`
- `growth.sale.validated`
- `loyalty.pepita.granted`
- `delivery.shipment.status_changed`
- `mobility.trip.status_changed`
- `security.signal.opened`
- `legal.contract.signed`
- `docs.document.generated`
- `agenda.item.scheduled`

Formato minimo do envelope:

- `event_id`
- `event_name`
- `event_version`
- `occurred_at`
- `producer_service`
- `correlation_id`
- `causation_id`
- `tenant_scope` quando existir
- `payload`

## Padroes de Consistencia

- `Postgres -> Outbox -> Event Bus` para eventos de dominio.
- `MongoDB` nao publica evento diretamente sem passar por servico dono.
- `append-only` continua obrigatorio para ledger, auditoria, checkpoints, assinaturas, snapshots de concorrencia e eventos de seguranca.
- Processos compensatorios substituem `UPDATE/DELETE` em livros criticos.

## O que foi descartado

- `database-per-service` agora: descartado na fase atual porque a base existente ja esta consolidada em `public` e separar fisicamente agora criaria retrabalho.
- `event sourcing global`: descartado porque o projeto ja tem source of truth relacional clara em tabelas mutaveis + append-only.
- `shared writes` entre servicos: descartado; o servico consumidor deve pedir por API ou reagir por evento.
- `telemetria no Postgres`: descartado; alto volume continua no MongoDB.
- `segredo e biometria bruta em evento`: descartado por risco tecnico e juridico.

## Estado alvo por fase

Fase 1:

- cluster PostgreSQL unico
- cluster Mongo unico
- microservices com ownership logico
- `API Gateway` unico
- `event-bus` unico

Fase 2:

- separar workloads de leitura
- materialized views e read models por dominio
- rate limit por modulo e client externo
- tracing distribuido fim a fim

Fase 3:

- split fisico dos dominios mais quentes
- `data products` para analytics
- automacao de replay de eventos e recovery operacional
