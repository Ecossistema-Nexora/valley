# Contrato Operacional - 10. Valley Services

Este arquivo e gerado pela automacao `scripts/valley_module_automation.py`.

Ele define a fronteira inicial do modulo para guiar desenvolvimento, implantacao e evolucao sem quebrar o nucleo Valley.

## Identidade Do Modulo

- Codigo tecnico: `SERVICES`
- Dominio: `services_health_human`
- Tier: `core`
- Data home: `postgres`
- Status atual: `Parcialmente implantado`
- Fase atual: `VALIDATE` (Validacao)

## Objetivo Simples

Servicos profissionais, gigs, contratacao e reputacao.

## Politica De Dados

Persistencia principal em PostgreSQL, porque o modulo exige consistencia, `foreign key`, auditoria, dinheiro, contrato ou documento.

`users.user_id` deve ser a primeira integracao relacional quando houver usuario, empresa, rider, admin ou system actor.

`wallets.wallet_id` e `transactions.transaction_id` devem ser usados quando houver dinheiro, saldo, pagamento, repasse, refund, fee, split ou escrow.

`user_id` em MongoDB deve ser string UUID validada por regex para manter ponte segura com PostgreSQL.

## Integracoes

Dependencias minimas: ID, PAY. Integracoes previstas: MARKETPLACE, LEGAL.

## Atores Primarios

- prestador
- cliente
- operador de marketplace

## Capacidades-Chave

- catalogo de servicos
- booking
- trilha de atendimento

## Entidades Relacionais

- `service_provider_profiles`
- `service_catalog_services`
- `service_bookings`
- `service_booking_events`

## Payloads Volumosos E Colecoes

- Nao aplicavel.

## Eventos Canonicos

- `services.provider.approved`
- `services.booking.confirmed`
- `services.booking.closed`

## Compliance, Risco E Guarda

- provider_verification
- service_auditability
- payment_split_audit

## Superficies Admin E Operacao

- painel de prestadores
- agenda de bookings
- fila de reputacao

## Regras De Evolucao

1. Nao criar tabela duplicada de usuario; usar sempre `public.users`.
2. Nao criar schema legado paralelo; manter objetos novos em `public` enquanto esta worktree exigir core-first.
3. Usar `UUID` para chaves e referencias quando o dado for relacional.
4. Usar `DECIMAL(18,4)` para BRL e `DECIMAL(18,8)` para `V-Coin`.
5. Usar `TIMESTAMPTZ` para eventos com tempo operacional.
6. Usar `append-only` quando o dado representar dinheiro, auditoria, certificado, receipt, regra versionada ou trilha legal.
7. Atualizar Manual Online e PDF em qualquer mudanca de schema, script ou contrato.

## Primeiro Backlog Tecnico

- fechar score de prestador
- definir no-show policy
- ligar disputa operacional
