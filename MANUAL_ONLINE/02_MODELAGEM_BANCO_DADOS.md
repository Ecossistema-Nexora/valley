<!--
PROPOSITO: Documentar 02 MODELAGEM BANCO DADOS no escopo operacional do Valley.
CONTEXTO: Este arquivo registra orientacoes, decisoes ou plano associado ao caminho MANUAL_ONLINE/02_MODELAGEM_BANCO_DADOS.md.
REGRAS: Manter informacao rastreavel, preservar nomenclatura Valley e atualizar ao mudar a rotina correspondente.
-->

# Modelagem de Banco de Dados

Este documento organiza a modelagem atual do Valley por dominio funcional.

Ele nao substitui as migrations.

Ele existe para explicar como as tabelas e colecoes ja criadas se encaixam como modelo de negocio e modelo operacional.

## Regras Mestras

- Tudo que representa identidade, dinheiro, contrato, order, disputa, documento ou trilha juridica fica no PostgreSQL.
- Tudo que representa alto volume, feed, telemetria, dispatch, sinais e agenda fica no MongoDB.
- `user_id` e a ancora universal entre os dois bancos.
- `UUID` e o identificador padrao.
- `TIMESTAMPTZ` ou `date` padronizam o tempo operacional.
- BRL usa `DECIMAL(18,4)`.
- `V-Coin` usa `DECIMAL(18,8)`.

## Cobertura Atual por Migration

PostgreSQL:

- `001` identidade e wallets
- `002` orders, transactions e equity
- `004` control plane, regras, campanhas e docs base
- `005` tabelas de dominio complementares
- `007` registry de 47 modulos
- `008` comercio, estoque e marketplace
- `009` tech e legal
- `010` rule runtime, Pepitas, GOLD e growth
- `011` delivery, mobility e security
- `012` services, health, jobs, pharmacy e events
- `013` digital, real estate, edu, vet, gov, charity e insurance
- `014` tourism, bio e energy

MongoDB:

- `mongo-001` IA, social, influencer e telemetria
- `mongo-002` log, IoT e snapshots WMS
- `mongo-003` dispatch, frota, sinais de seguranca e agenda
- `mongo-004` news, fitness, gaming, home, space e camadas volumosas de tourism, bio e energy

## Nucleo Absoluto

### Identidade

Tabelas:

- `users`
- `pj_profiles`
- `rider_profiles`
- `led_cards`

Papel:

- `users` define a identidade unica do ecossistema.
- `pj_profiles` especializa merchant, empresa e ator institucional.
- `rider_profiles` especializa operador de campo.
- `led_cards` liga identidade forte, NFC e wallet.

Dependencias fortes:

- todo dominio relacional aponta para `users.user_id`
- `pj_profiles` e `rider_profiles` dependem do `user_kind`

### Financeiro

Tabelas:

- `wallets`
- `transactions`
- `equity_ledger`
- `plug_transactions`

Papel:

- `wallets` e saldo mutavel e reconciliavel.
- `transactions` e ledger append-only de dinheiro.
- `equity_ledger` e ledger append-only societario.
- `plug_transactions` especializa adquirencia/maquininha.

## Control Plane e Governanca

Tabelas:

- `module_catalog`
- `module_delivery_registry`
- `module_evolution_backlog`
- `module_automation_runs`
- `admin_users`
- `admin_permissions`
- `admin_action_audit`
- `observability_incidents`

Papel:

- governanca do backlog dos 47 modulos
- RBAC/ABAC
- auditoria do painel admin
- evidencia operacional da automacao

## Rule Engine e Growth

Tabelas:

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

Papel:

- separar definicao da regra de sua execucao
- manter auditoria de governance
- permitir runtime por modulo, merchant, listing, order ou campanha
- controlar Pepitas e GOLD com cap financeiro e venda validada

Relacoes importantes:

- `business_rule_definitions -> business_rule_versions -> rule_runtime_bindings -> rule_execution_events`
- `gold_campaigns -> gold_campaign_events`
- `sale_validation_events -> gold_campaign_events -> pepita_ledger`
- `pepita_accounts -> pepita_ledger`

Regra-chave:

- `pepita_cap_brl` em `sale_validation_events` limita o incentivo a ate 50 por cento do lucro liquido de referencia.

## Comercio e Marketplace

Tabelas:

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

Papel:

- `inventory_*` e o backbone do item, lote e saldo operacional
- `marketplace_listings` expande item para anuncio comercial
- `merchant_storefronts` e `merchant_service_zones` modelam a operacao geolocalizada
- `marketplace_listing_controls` e `marketplace_competitor_snapshots` modelam a regra "so publica se for competitivo e rentavel"

Append-only neste bloco:

- `inventory_movements`
- `marketplace_competitor_snapshots`

## Orders e Backoffice Comercial

Tabelas:

- `orders`
- `procurement_orders`
- `procurement_order_items`
- `service_work_orders`
- `business_invoices`
- `business_payrolls`
- `affiliate_referrals`
- `docs_receipts`
- `document_records`

Papel:

- `orders` e a entidade mae para Food, Move e Dropship
- procurement e service work orders cobrem backoffice e campo
- invoices, payroll e receipts ligam business, docs e financeiro

## Tech e Legal

Tabelas:

- `tech_api_clients`
- `tech_api_credentials`
- `tech_integration_connectors`
- `tech_webhook_subscriptions`
- `tech_webhook_delivery_attempts`
- `tech_api_usage_daily`
- `legal_contracts`
- `legal_contract_parties`
- `legal_signatures`
- `legal_disputes`
- `legal_audit_events`
- `legal_fallback_pin_credentials`

Papel:

- Tech modela clientes externos, credenciais seguras e webhooks
- Legal modela contratos, assinatura, mediacao e disputa
- Docs complementa Legal com `document_records` e `docs_receipts`

Append-only neste bloco:

- `tech_webhook_delivery_attempts`
- `legal_signatures`
- `legal_audit_events`

## Delivery, Mobility e Security

Tabelas:

- `delivery_shipments`
- `delivery_shipment_events`
- `mobility_trips`
- `mobility_trip_events`
- `security_trusted_contacts`
- `security_biometric_credentials`
- `security_incidents`
- `security_incident_events`

Papel:

- `delivery_shipments` amarra order, rider, wallet e prova de entrega
- `mobility_trips` amarra corrida, rider, passageiro e tarifa
- `security_*` cobre biometria por hash, contatos de emergencia e incidentes

Append-only neste bloco:

- `delivery_shipment_events`
- `mobility_trip_events`
- `security_incident_events`

## Tourism, Bio e Energy

Tabelas:

- `tourism_experiences`
- `tourism_bookings`
- `tourism_booking_events`
- `bio_material_programs`
- `bio_collection_orders`
- `bio_collection_events`
- `energy_assets`
- `energy_trade_orders`
- `energy_settlement_ledger`

Papel:

- `tourism_*` modela experiencias, reservas, vouchers e acoplamento opcional com Events e Mobility.
- `bio_*` modela programas de sustentabilidade, coleta reversa, verificacao e recompensa.
- `energy_*` modela ativos energeticos, ordens de trade P2P e settlement financeiro/operacional.

Append-only neste bloco:

- `tourism_booking_events`
- `bio_collection_events`
- `energy_settlement_ledger`

## MongoDB - IA, Social e Operacao de Campo

### IA e agenda

Colecoes:

- `ai_memory`
- `agenda_items`

Papel:

- memoria contextual da contexto Helena
- follow-up, lembrete, tarefa e evento de agenda

### Social e creator economy

Colecoes:

- `social_videos`
- `influencer_metrics`

Papel:

- feed social
- performance de campanha
- atribuicao e monetizacao de creator

### Expansion media, wellness e frontier

Colecoes:

- `news_content_items`
- `fitness_activity_sessions`
- `gaming_player_states`
- `home_automation_events`
- `space_anchor_maps`
- `tourism_experience_feeds`
- `bio_impact_logs`
- `energy_meter_streams`

Papel:

- News & Podcast guarda publicacao editorial e distribuicao multicanal.
- Fitness guarda sessoes de atividade, ponte com wearable e reward candidato.
- Gaming guarda estado vivo do jogador, progressao e inventario resumido.
- Home guarda automacao residencial, eventos de seguranca domestica e modos energeticos.
- Space guarda ancoras AR e experiencias imersivas conectadas a turismo e social.
- Tourism/Bio/Energy guardam a camada volumosa de feed, sensores, wayfinding e stream de medidor.

### Telemetria e IoT

Colecoes:

- `telemetry_logs`
- `iot_device_registry`
- `iot_sensor_events`
- `warehouse_sensor_snapshots`
- `log_tracking_events`

Papel:

- GPS, sensor, tracking, temperatura, bateria, velocidade, correlograma de campo

### Dispatch, frota e seguranca

Colecoes:

- `delivery_dispatch_runs`
- `fleet_vehicle_profiles`
- `fleet_maintenance_events`
- `security_signal_logs`

Papel:

- matching de rider
- cadastro vivo de veiculo
- manutencao preventiva
- sinais de alto volume para resposta rapida

## Integracao Postgres + Mongo

Padrao de ponte:

- `UUID` tecnico em string no Mongo
- `correlation_id` para rastrear request, evento, log e incidente
- `document_id`, `order_id`, `transaction_id`, `trip_id`, `shipment_id` e `incident_id` como referencias cruzadas logicas

Regra pratica:

- o estado juridico e financeiro fica no Postgres
- o sinal volumoso e a inteligencia operacional ficam no Mongo

## Entidades que merecem Aggregate Root

Aggregate roots mais claros hoje:

- `users`
- `wallets`
- `orders`
- `marketplace_listings`
- `merchant_storefronts`
- `gold_campaigns`
- `pepita_accounts`
- `delivery_shipments`
- `mobility_trips`
- `security_incidents`
- `legal_contracts`
- `tech_api_clients`

## O que nao entra agora

- multi-schema legado
- replica logica de `platform.users`
- event store unico para tudo
- tabela de telemetria em Postgres
- segredo bruto em qualquer banco

## Diretriz para proximas tabelas e colecoes

Se um novo modulo precisar nascer:

- primeiro escolhe owner service
- depois escolhe data home
- depois escolhe root entity
- depois define eventos de entrada e saida
- so entao cria migration ou collection
