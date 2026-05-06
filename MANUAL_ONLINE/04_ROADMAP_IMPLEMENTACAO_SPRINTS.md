# Roadmap de Implementacao por Sprint

Este roadmap assume sprints de 2 semanas.

Ele parte do estado atual da arvore Valley, onde a camada de banco ja materializou migrations `001-011` no PostgreSQL e `mongo-001-003` no MongoDB.

## Estado Atual

Ja existe base suficiente para iniciar implementacao de produto sobre contratos reais:

- identidade, wallets e ledger
- control plane e rule definitions
- commerce, estoque, marketplace e storefront
- GOLD, Pepitas e validacao de venda
- delivery, mobility e security
- tech, legal e docs
- IA, social, telemetria, dispatch e agenda

O que ainda falta e transformar schema em APIs, workers, automacoes e produtos operacionais.

## Fila Prioritaria De Release

Antes de ampliar o escopo para os 47 modulos em superficie de produto, o release funcional precisa deixar cinco modulos em estado verde operacional:

- `PAY` como no transacional: wallet bootstrap, authorize, settle, refund e ledger imutavel.
- `MARKETPLACE` como motor de oferta: storefront, zona, listing, price-check e publish gate competitivo.
- `SERVICES` como contratacao de trabalho real: provider profile, catalogo, booking, trilha append-only e integracao juridica/financeira.
- `SOCIAL` como aquisicao e atribuicao: upload, feed, metricas, campanha e comissao ligada a order/transaction.
- `CHAT` como retencao assistida: conversa, contexto Helena, memoria contextual e follow-up sem duplicar estado financeiro.

Racional:

- `PAY` bloqueia qualquer fluxo de receita, split, refund e conciliacao.
- `MARKETPLACE` desbloqueia a principal jornada de browse para order.
- `SERVICES` fecha a venda de trabalho e reputacao profissional, que e um dos vetores de monetizacao mais diretos.
- `SOCIAL` acelera aquisicao e atribuicao sem exigir o rollout imediato de todos os modulos de media.
- `CHAT` fecha a camada de retencao e operacao assistida conectando agenda, advisor e contexto do usuario.

Fila seguinte recomendada depois desse gate:

- `17-NEWS-PODCAST`
- `18-ADS`
- `19-INFLUENCERS`
- `38-AGENDA`
- `39-ADVISOR`

## Sprint 0 - Baseline Tecnica

Objetivo:

- consolidar contrato de servicos, naming de eventos e padrao de API

Entrega:

- arquitetura tecnica aprovada
- mapa de ownership por servico
- padrao `X-Correlation-Id`
- padrao `Idempotency-Key`
- envelope padrao de eventos

Criterio de saida:

- nenhum time novo cria endpoint ou evento fora do contrato-base

## Sprint 1 - Identity + Pay Bootstrap

Objetivo:

- colocar de pe onboarding, KYC e wallet bootstrap

Entrega:

- `identity-access-service`
- `wallet-ledger-service`
- endpoints de cadastro, perfil PJ/Rider e bootstrap de wallet
- admin basico para consulta de identidade e status KYC

Banco tocado:

- `users`, `pj_profiles`, `rider_profiles`, `wallets`, `led_cards`

Eventos:

- `identity.user.created`
- `identity.user.kyc_updated`
- `wallet.created`

Criterio de saida:

- usuario consegue nascer, validar identidade e obter carteira

## Sprint 2 - Merchant, Catalogo e Listing Competitivo

Objetivo:

- colocar merchant, storefront, item, listing e price-check no ar

Entrega:

- `catalog-commerce-service`
- CRUD de storefront e service zones
- CRUD de item e listing
- worker de `price-check`
- snapshots de concorrencia e auto-pausa do listing

Banco tocado:

- `suppliers`
- `inventory_*`
- `marketplace_listings`
- `merchant_storefronts`
- `merchant_service_zones`
- `marketplace_listing_controls`
- `marketplace_competitor_snapshots`

Eventos:

- `catalog.listing.created`
- `catalog.listing.price_checked`
- `catalog.listing.activated`
- `catalog.listing.auto_paused`

Criterio de saida:

- merchant publica anuncio somente quando a regra de competitividade liberar

## Sprint 3 - Orders, Checkout e Receipts

Objetivo:

- transformar listing em pedido pago e rastreavel

Entrega:

- `orders-orchestration-service`
- checkout end-to-end
- authorize/settle financeiro
- receipts e documentos basicos

Banco tocado:

- `orders`
- `transactions`
- `document_records`
- `docs_receipts`

Eventos:

- `order.placed`
- `ledger.transaction.authorized`
- `ledger.transaction.settled`
- `docs.receipt.generated`

Criterio de saida:

- usuario fecha compra e o sistema gera evidencia de pagamento

## Sprint 4 - Rule Runtime, GOLD e Pepitas

Objetivo:

- ligar crescimento, incentivo e governanca de regra ao fluxo de venda

Entrega:

- `rules-growth-service`
- CRUD admin de binding runtime
- create/fund de campanha GOLD
- validacao de venda marketplace e fisica
- grant e redeem de Pepitas

Banco tocado:

- `rule_runtime_bindings`
- `rule_execution_events`
- `gold_campaigns`
- `sale_validation_events`
- `gold_campaign_events`
- `pepita_accounts`
- `pepita_ledger`

Eventos:

- `rules.binding.activated`
- `growth.gold_campaign.created`
- `growth.sale.validated`
- `loyalty.pepita.granted`

Criterio de saida:

- merchant compra GOLD e o usuario recebe Pepita apenas quando a venda for validada

## Sprint 5 - Delivery, Dispatch e Prova de Entrega

Objetivo:

- operacionalizar entrega urbana com rider assignment e trilha de campo

Entrega:

- `delivery-dispatch-service`
- shipment API
- dispatch engine inicial
- timeline de eventos de entrega
- prova de entrega e documento associado

Banco tocado:

- `delivery_shipments`
- `delivery_shipment_events`
- `delivery_dispatch_runs`
- `log_tracking_events`

Eventos:

- `delivery.shipment.created`
- `delivery.dispatch.started`
- `delivery.rider.assigned`
- `delivery.shipment.delivered`

Criterio de saida:

- pedido confirmado consegue virar shipment despachado e concluido

## Sprint 6 - Mobility + Security

Objetivo:

- colocar corrida urbana e resposta a risco no mesmo backbone operacional

Entrega:

- `mobility-service`
- `security-response-service`
- create/update de trip
- checkpoints de corrida
- SOS, trusted contacts e incident workflow

Banco tocado:

- `mobility_trips`
- `mobility_trip_events`
- `security_trusted_contacts`
- `security_biometric_credentials`
- `security_incidents`
- `security_incident_events`
- `security_signal_logs`

Eventos:

- `mobility.trip.started`
- `mobility.trip.completed`
- `security.signal.opened`
- `security.incident.created`

Criterio de saida:

- corrida funciona com trilha minima e incidente consegue ser aberto e encerrado

## Sprint 7 - Tech, Legal e Docs Operacionais

Objetivo:

- habilitar parceiros externos, webhooks, contratos e disputa

Entrega:

- `tech-platform-service`
- `legal-docs-service`
- onboarding de API client
- assinatura de contrato
- webhook subscription e audit trail
- fallback PIN e documento de prova

Banco tocado:

- `tech_*`
- `legal_*`
- `document_records`

Eventos:

- `tech.client.created`
- `tech.webhook.subscribed`
- `legal.contract.signed`
- `docs.document.generated`

Criterio de saida:

- parceiro consegue integrar e contrato passa a ter trilha assinada

## Sprint 8 - Social, Media e Attribution

Objetivo:

- conectar social/influencers com growth e marketplace

Entrega:

- `social-media-service`
- publicacao de videos
- ingestion de metricas
- ligacao entre creator, campanha e order/commission

Banco tocado:

- `social_videos`
- `influencer_metrics`
- `creator_uploads`
- `affiliate_referrals`

Eventos:

- `social.video.published`
- `social.campaign.metric_aggregated`
- `growth.sale.validated`

Criterio de saida:

- campanha social consegue medir impressao, clique, conversao e comissao

## Sprint 9 - AI, Agenda e Follow-up de Valor

Objetivo:

- colocar retencao assistida por IA em cima da operacao ja funcional

Entrega:

- `ai-agenda-service`
- agenda inteligente
- memoria contextual
- follow-up de compra, saude, pagamento e seguranca

Banco tocado:

- `ai_memory`
- `agenda_items`
- `advisor_insights`
- `chat_*`
- `financial_goals`

Eventos:

- `ai.memory.created`
- `agenda.item.scheduled`
- `advisor.insight.generated`

Criterio de saida:

- usuario recebe lembrete, follow-up e recomendacao ligados ao contexto real do ecossistema

## Sprint 10 - Hardening, SRE e Cutover

Objetivo:

- deixar o backbone pronto para trafego real e suporte operacional

Entrega:

- tracing distribuido
- retry e dead-letter por topico
- rate limit por client e modulo
- replay controlado de outbox
- testes de carga e caos
- dashboards executivos e operacionais

Criterio de saida:

- o sistema aguenta transacao, dispatch, trilha append-only e eventos sem perder rastreabilidade

## Sequencia Recomendada de Squads

Squad 1:

- core identity/pay/admin

Squad 2:

- marketplace/growth/merchant

Squad 3:

- delivery/mobility/security

Squad 4:

- tech/legal/docs/social/ai

Para release reduzido com um time enxuto:

- priorizar `PAY` + `MARKETPLACE` + `SERVICES` como Wave 1
- ativar `SOCIAL` + `CHAT` como Wave 2
- puxar `NEWS-PODCAST`, `ADS`, `INFLUENCERS`, `AGENDA` e `ADVISOR` apenas depois da prova de receita e retencao

Se o time for menor:

- executar sprints 1 a 4 primeiro
- depois 5 e 6
- depois 7 a 10

## O que fica fora do roadmap imediato

- refatorar para `database-per-service`
- reescrever o banco para outro modelo
- colocar todos os 47 modulos em producao de uma vez
- criar front-end completo de todos os modulos antes de validar as jornadas centrais

## Definicao de pronto global

Uma sprint so deve ser considerada pronta quando fechar os quatro planos ao mesmo tempo:

- schema e integridade
- API e contrato de erro
- eventos emitidos/consumidos
- observabilidade e evidencia operacional
