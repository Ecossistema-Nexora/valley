# Contrato Operacional - 05. Valley Delivery

Este arquivo e gerado pela automacao `scripts/valley_module_automation.py`.

Ele define a fronteira inicial do modulo para guiar desenvolvimento, implantacao e evolucao sem quebrar o nucleo Valley.

## Identidade Do Modulo

- Codigo tecnico: `DELIVERY`
- Dominio: `logistics_erp_operations`
- Tier: `core`
- Data home: `postgres_mongo`
- Status atual: `Parcialmente implantado`
- Fase atual: `VALIDATE` (Validacao)

## Objetivo Simples

Entrega urbana, coleta local e operacao courier.

## Politica De Dados

Persistencia hibrida: PostgreSQL guarda o contrato operacional e MongoDB guarda payload volumoso, IA, social, telemetria ou eventos semi-estruturados.

`users.user_id` deve ser a primeira integracao relacional quando houver usuario, empresa, rider, admin ou system actor.

`wallets.wallet_id` e `transactions.transaction_id` devem ser usados quando houver dinheiro, saldo, pagamento, repasse, refund, fee, split ou escrow.

`user_id` em MongoDB deve ser string UUID validada por regex para manter ponte segura com PostgreSQL.

## Integracoes

Dependencias minimas: LOG, PAY. Integracoes previstas: FOOD, MARKETPLACE, MOBILITY.

## Atores Primarios

- dispatcher
- courier
- loja emissora

## Capacidades-Chave

- coleta urbana
- roteamento operacional
- prova de entrega

## Entidades Relacionais

- `delivery_shipments`
- `delivery_shipment_events`
- `orders`

## Payloads Volumosos E Colecoes

- `delivery_dispatch_runs`
- `telemetry_logs`

## Eventos Canonicos

- `delivery.shipment.created`
- `delivery.route.dispatched`
- `delivery.proof_recorded`

## Compliance, Risco E Guarda

- chain_of_custody
- proof_of_delivery
- driver_accountability

## Superficies Admin E Operacao

- torre de despacho
- fila de ocorrencias
- painel de courier

## Regras De Evolucao

1. Nao criar tabela duplicada de usuario; usar sempre `public.users`.
2. Nao criar schema legado paralelo; manter objetos novos em `public` enquanto esta worktree exigir core-first.
3. Usar `UUID` para chaves e referencias quando o dado for relacional.
4. Usar `DECIMAL(18,4)` para BRL e `DECIMAL(18,8)` para `$NEX`.
5. Usar `TIMESTAMPTZ` para eventos com tempo operacional.
6. Usar `append-only` quando o dado representar dinheiro, auditoria, certificado, receipt, regra versionada ou trilha legal.
7. Atualizar Manual Online e PDF em qualquer mudanca de schema, script ou contrato.

## Primeiro Backlog Tecnico

- fechar reatribuicao automatica
- definir KPI de janela prometida
- ligar prova de entrega por media
