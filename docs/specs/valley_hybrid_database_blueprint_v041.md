<!--
PROPOSITO: Documentar o fechamento do blueprint de banco hibrido Valley v041.
CONTEXTO: A entrega complementa os scripts PostgreSQL e MongoDB com explicacao de uso operacional.
REGRAS: Nao listar segredos, manter termos canonicos Valley, Helena e V-Coin.
-->

# Valley Hybrid Database Blueprint v041

## Entrega

Esta camada fecha o blueprint institucional do banco hibrido:

- PostgreSQL: identidade, enderecos, validacao documental, wallets, contratos de modulo, contas de marketplace, APIs bancarias e ledger imutavel.
- MongoDB: contexto Helena, payloads volumosos de integracao, rastreio em tempo real, telemetria operacional e decisoes do agente de Mobilidade.

Status operacional:

- **Atividade:** Blueprint banco hibrido Valley.
- **Dificuldade:** 3.
- **Escopo:** PostgreSQL + MongoDB + contratos Stitch UI.
- **Regra de acesso:** `tenant_id` obrigatorio e `branch_id` obrigatorio quando houver filial.
- **Regra visual:** cliente final nao ve custo bruto, markup, margem ou beneficio interno oculto.

## PostgreSQL

Arquivo: `database/postgres/041_v47_valley_hybrid_institutional_contracts.sql`

Tabelas novas:

- `valley_wallet_asset_registry`: registry canonico de BRL e V-Coin, com visibilidade controlada.
- `valley_user_addresses`: endereco principal, entrega, cobranca, retirada e devolucao por `users.user_id`.
- `valley_user_document_checks`: historico de validacao documental por provedor externo, sem resposta sensivel bruta.
- `merchant_erp_access_policies`: politicas mandatarias como `BR-ACL-001`, `BR-PRO-001` e regionalizacao Helena.
- `merchant_erp_users`: usuarios canonicos do ERP por lojista, filial, papel e status.
- `merchant_erp_products`: produtos canonicos para cadastro, edicao, suspensao, etiquetas e publicacao.
- `merchant_erp_inventory`: saldo por produto, lojista, filial, reserva e limiares de alerta.
- `merchant_erp_orders`: pedidos canonicos por origem, status, pagamento e valores finais.
- `merchant_erp_deliveries`: entregas canonicas com entregador, rastreio e prova.
- `merchant_erp_appointments`: agenda generica de servicos por filial, profissional e horario.
- `helena_user_voice_profiles`: cidade/UF de nascimento, sotaque PT-BR e perfil de voz da Helena.
- `helena_product_sourcing_decisions`: decisao append-only de publicacao se preco final bater a meta de 10% abaixo do mercado.
- `valley_contextual_reward_campaigns`: campanhas internas ocultas por padrao na UI final.
- `mobility_realtime_route_sessions`: sessao de trajetos de onibus, metro e aplicativo em tempo real.
- `mobility_idle_agent_dispatch_rules`: regras do agente autonomo de Mobilidade.
- `mobility_idle_agent_events`: eventos append-only de preco alto, acidente, atraso, recalculo e alerta.
- `valley_module_availability_checks`: agente de verificacao do modulo `visio`.
- `valley_screen_layout_contracts`: contratos persistentes para HOME, Stock e Marketplace no Stitch.
- `marketplace_android_live_tracking_sessions`: rastreio Android em tempo real exclusivo para pedidos Marketplace.
- `marketplace_android_live_tracking_events`: eventos append-only do rastreio Android: FCM, foreground service, mapa, ETA e status.
- `marketplace_chat_moderation_patterns`: padroes de moderacao anti-contato externo.
- `chat_moderation_strikes`: advertencias append-only por tentativa de evasao de chat.
- `chat_moderation_account_actions`: eventos de suspensao automatica por regra de tres advertencias.
- `valley_module_data_contracts`: matriz de modulos, origem de dados, escopo por usuario/lojista/filial e exigencia append-only.
- `valley_module_user_scope_bindings`: amarracao entre qualquer entidade operacional e `users.user_id`.
- `valley_marketplace_api_accounts`: contas de Shopee, Mercado Livre, OLX, Ze Delivery, iFood e outros canais bidirecionais.
- `valley_bank_api_connections`: espaco de integracao bancaria e Open Finance por lojista.
- `valley_immutable_audit_ledger`: ledger generico de evidencias criticas com hash e regra append-only.

Views novas:

- `v_valley_hybrid_scope_matrix`
- `v_valley_user_scope_bindings_active`
- `v_valley_marketplace_account_health`

## MongoDB

Arquivo: `database/mongodb/006_v47_valley_hybrid_brain_final_contracts.mongo.js`

Collections novas:

- `helena_ai_context_events`: eventos de contexto da Helena por usuario e modulo.
- `merchant_integration_payload_logs`: logs de payloads externos por lojista, provider e direcao.
- `merchant_realtime_delivery_stream`: stream de rastreio de entregas em tempo real com GeoJSON.
- `erp_operational_telemetry_events`: telemetria operacional dos modulos do ERP.
- `mobility_idle_agent_decisions`: decisoes do agente de Mobilidade para rota combinada, acidente, atraso, preco alto e verificacao Visio.
- `marketplace_android_live_tracking_stream`: stream Android para notificacao dinamica, lock screen, minimapa, ETA e status.
- `marketplace_chat_moderation_events`: eventos volumosos de moderacao do chat Marketplace.

## Regra de escopo

Todo modulo novo deve possuir uma das duas formas de escopo:

- FK relacional direta para `users.user_id` no PostgreSQL.
- FK logica `user_id` ou `merchant_user_id` validada por contrato MongoDB e espelhada em `valley_module_user_scope_bindings` quando a entidade exigir auditoria relacional.
- Em consultas ERP, usar sempre `tenant_id = ?` e, quando filial existir, `branch_id = ?`.

## Mobilidade

O agente autonomo de Mobilidade monitora trajetos no Brasil com combinacao de onibus, metro e transporte por aplicativo.

Fluxo previsto:

1. Criar ou atualizar `mobility_realtime_route_sessions` com origem, destino, compromisso e modos rastreados.
2. Aplicar `mobility_idle_agent_dispatch_rules` para monitorar preco, atraso, acidente e risco de compromisso.
3. Registrar cada evento em `mobility_idle_agent_events`.
4. Persistir recomendacoes volumosas em `mobility_idle_agent_decisions`.
5. Quando transporte por aplicativo estiver caro, Helena recomenda transporte publico + trecho final por aplicativo quando houver economia.
6. Quando houver acidente ou atraso, Helena recalcula e avisa de forma proativa.
7. Verificar disponibilidade do modulo `visio` com `valley_module_availability_checks`.

## Stitch UI

As telas `HOME_001`, `STOCK_DROPSHIPPING` e `MARKETPLACE_LOCAL` foram materializadas em `valley_screen_layout_contracts`.

Esses contratos definem blocos, campos, botoes, listas, filtros, regras de visibilidade e tabelas/collections que o Stitch deve considerar ao gerar os novos templates.

## Rastreio Android Marketplace

Contrato aplicado a partir de `valley-marketplace-android-live-tracking.md`:

- Exclusivo para Super APK Android.
- Ligado somente a pedidos Marketplace.
- Nao ativar para Stock, estoque proprio, parceiros fora do Marketplace ou dropshipping.
- FCM Silent Push dispara o Foreground Service.
- Android Live Updates e usado quando disponivel; Foreground Service com notificacao custom e o fallback obrigatorio.
- A lock screen deve exibir minimapa, rota, pin do cliente, veiculo/entregador, ETA e status.
- Cores Valley: Night/Cosmic, Violet e Cyan.

## Chat Marketplace

Contrato aplicado a partir de `valley-marketplace-chat-rules.md`:

- Toda conversa entre cliente e lojista fica no chat oficial Valley.
- `chat_messages` deve ser append-only.
- O motor identifica telefone, email, WhatsApp, Telegram, redes externas e inducao para contato fora do app.
- A primeira infracao gera aviso educativo.
- A segunda infracao gera alerta severo.
- A terceira infracao cria evento automatico `account.suspended.evasion`, com revisao manual e pausa operacional de anuncios.
