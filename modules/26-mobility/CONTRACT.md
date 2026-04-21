# Contrato Operacional - 26. Valley Mobility

Este arquivo e gerado pela automacao `scripts/valley_module_automation.py`.

Ele define a fronteira inicial do modulo para guiar desenvolvimento, implantacao e evolucao sem quebrar o nucleo Valley.

## Identidade Do Modulo

- Codigo tecnico: `MOBILITY`
- Dominio: `city_mobility_security`
- Tier: `core`
- Data home: `postgres_mongo`
- Status atual: `Parcialmente implantado`
- Fase atual: `VALIDATE` (Validacao)

## Objetivo Simples

Corridas urbanas, carpool, riders e taxa de plataforma.

## Politica De Dados

Persistencia hibrida: PostgreSQL guarda o contrato operacional e MongoDB guarda payload volumoso, IA, social, telemetria ou eventos semi-estruturados.

`users.user_id` deve ser a primeira integracao relacional quando houver usuario, empresa, rider, admin ou system actor.

`wallets.wallet_id` e `transactions.transaction_id` devem ser usados quando houver dinheiro, saldo, pagamento, repasse, refund, fee, split ou escrow.

`user_id` em MongoDB deve ser string UUID validada por regex para manter ponte segura com PostgreSQL.

## Integracoes

Dependencias minimas: PAY, RIDER. Integracoes previstas: LOG, FLEET.

## Atores Primarios

- passageiro
- rider
- dispatcher

## Capacidades-Chave

- corrida urbana
- checkpoint operacional
- precificacao de rota

## Entidades Relacionais

- `mobility_trips`
- `mobility_trip_events`
- `orders`

## Payloads Volumosos E Colecoes

- `fleet_vehicle_profiles`
- `telemetry_logs`

## Eventos Canonicos

- `mobility.trip.requested`
- `mobility.trip.started`
- `mobility.trip.completed`

## Compliance, Risco E Guarda

- ride_audit
- driver_accountability
- fare_traceability

## Superficies Admin E Operacao

- torre de corridas
- monitor de checkpoints
- painel de rider

## Regras De Evolucao

1. Nao criar tabela duplicada de usuario; usar sempre `public.users`.
2. Nao criar schema legado paralelo; manter objetos novos em `public` enquanto esta worktree exigir core-first.
3. Usar `UUID` para chaves e referencias quando o dado for relacional.
4. Usar `DECIMAL(18,4)` para BRL e `DECIMAL(18,8)` para `$NEX`.
5. Usar `TIMESTAMPTZ` para eventos com tempo operacional.
6. Usar `append-only` quando o dado representar dinheiro, auditoria, certificado, receipt, regra versionada ou trilha legal.
7. Atualizar Manual Online e PDF em qualquer mudanca de schema, script ou contrato.

## Primeiro Backlog Tecnico

- fechar calculo de tarifa
- definir score de seguranca da corrida
- ligar suporte em tempo real
