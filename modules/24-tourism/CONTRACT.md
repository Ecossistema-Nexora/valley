# Contrato Operacional - 24. Valley Tourism

Este arquivo e gerado pela automacao `scripts/valley_module_automation.py`.

Ele define a fronteira inicial do modulo para guiar desenvolvimento, implantacao e evolucao sem quebrar o nucleo Valley.

## Identidade Do Modulo

- Codigo tecnico: `TOURISM`
- Dominio: `city_mobility_security`
- Tier: `expansion`
- Data home: `postgres_mongo`
- Status atual: `Parcialmente implantado`
- Fase atual: `VALIDATE` (Validacao)

## Objetivo Simples

Turismo local, experiencias, reservas e exploracao.

## Politica De Dados

Persistencia hibrida: PostgreSQL guarda o contrato operacional e MongoDB guarda payload volumoso, IA, social, telemetria ou eventos semi-estruturados.

`users.user_id` deve ser a primeira integracao relacional quando houver usuario, empresa, rider, admin ou system actor.

`wallets.wallet_id` e `transactions.transaction_id` devem ser usados quando houver dinheiro, saldo, pagamento, repasse, refund, fee, split ou escrow.

`user_id` em MongoDB deve ser string UUID validada por regex para manter ponte segura com PostgreSQL.

## Integracoes

Dependencias minimas: PAY. Integracoes previstas: EVENTS, MOBILITY.

## Atores Primarios

- turista
- guia
- operador local

## Capacidades-Chave

- experiencias locais
- booking
- feed exploratorio

## Entidades Relacionais

- `tourism_experiences`
- `tourism_bookings`
- `tourism_booking_events`

## Payloads Volumosos E Colecoes

- `tourism_experience_feeds`
- `space_anchor_maps`

## Eventos Canonicos

- `tourism.experience.published`
- `tourism.booking.confirmed`
- `tourism.checkin.recorded`

## Compliance, Risco E Guarda

- booking_audit
- guide_accountability
- settlement_traceability

## Superficies Admin E Operacao

- painel de experiencias
- fila de bookings
- monitor de check-in

## Regras De Evolucao

1. Nao criar tabela duplicada de usuario; usar sempre `public.users`.
2. Nao criar schema legado paralelo; manter objetos novos em `public` enquanto esta worktree exigir core-first.
3. Usar `UUID` para chaves e referencias quando o dado for relacional.
4. Usar `DECIMAL(18,4)` para BRL e `DECIMAL(18,8)` para `V-Coin`.
5. Usar `TIMESTAMPTZ` para eventos com tempo operacional.
6. Usar `append-only` quando o dado representar dinheiro, auditoria, certificado, receipt, regra versionada ou trilha legal.
7. Atualizar Manual Online e PDF em qualquer mudanca de schema, script ou contrato.

## Primeiro Backlog Tecnico

- fechar politica de cancelamento
- definir no-show do guia
- ligar reputacao por experiencia
