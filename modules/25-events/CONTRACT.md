# Contrato Operacional - 25. Valley Events

Este arquivo e gerado pela automacao `scripts/valley_module_automation.py`.

Ele define a fronteira inicial do modulo para guiar desenvolvimento, implantacao e evolucao sem quebrar o nucleo Valley.

## Identidade Do Modulo

- Codigo tecnico: `EVENTS`
- Dominio: `city_mobility_security`
- Tier: `core`
- Data home: `postgres`
- Status atual: `Parcialmente implantado`
- Fase atual: `VALIDATE` (Validacao)

## Objetivo Simples

Ingressos, eventos, escrow e seguranca de venda.

## Politica De Dados

Persistencia principal em PostgreSQL, porque o modulo exige consistencia, `foreign key`, auditoria, dinheiro, contrato ou documento.

`users.user_id` deve ser a primeira integracao relacional quando houver usuario, empresa, rider, admin ou system actor.

`wallets.wallet_id` e `transactions.transaction_id` devem ser usados quando houver dinheiro, saldo, pagamento, repasse, refund, fee, split ou escrow.

`user_id` em MongoDB deve ser string UUID validada por regex para manter ponte segura com PostgreSQL.

## Integracoes

Dependencias minimas: PAY. Integracoes previstas: TICKETS, DOCS.

## Atores Primarios

- organizador
- participante
- operador de bilheteria

## Capacidades-Chave

- programacao de evento
- tipos de ingresso
- ledger de tickets

## Entidades Relacionais

- `event_programs`
- `event_ticket_types`
- `event_ticket_ledger`

## Payloads Volumosos E Colecoes

- Nao aplicavel.

## Eventos Canonicos

- `events.program.published`
- `events.ticket.issued`
- `events.ticket.transferred`

## Compliance, Risco E Guarda

- ticket_immutability
- escrow_audit
- fraud_prevention

## Superficies Admin E Operacao

- painel de eventos
- monitor de bilheteria
- fila de dispute

## Regras De Evolucao

1. Nao criar tabela duplicada de usuario; usar sempre `public.users`.
2. Nao criar schema legado paralelo; manter objetos novos em `public` enquanto esta worktree exigir core-first.
3. Usar `UUID` para chaves e referencias quando o dado for relacional.
4. Usar `DECIMAL(18,4)` para BRL e `DECIMAL(18,8)` para `$NEX`.
5. Usar `TIMESTAMPTZ` para eventos com tempo operacional.
6. Usar `append-only` quando o dado representar dinheiro, auditoria, certificado, receipt, regra versionada ou trilha legal.
7. Atualizar Manual Online e PDF em qualquer mudanca de schema, script ou contrato.

## Primeiro Backlog Tecnico

- fechar anti-scalping
- definir transferencia segura
- ligar concilicao de evento
