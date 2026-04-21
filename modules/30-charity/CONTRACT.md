# Contrato Operacional - 30. Valley Charity

Este arquivo e gerado pela automacao `scripts/valley_module_automation.py`.

Ele define a fronteira inicial do modulo para guiar desenvolvimento, implantacao e evolucao sem quebrar o nucleo Valley.

## Identidade Do Modulo

- Codigo tecnico: `CHARITY`
- Dominio: `education_work_social`
- Tier: `expansion`
- Data home: `postgres`
- Status atual: `Parcialmente implantado`
- Fase atual: `VALIDATE` (Validacao)

## Objetivo Simples

Doacoes transparentes, auditoria e impacto social.

## Politica De Dados

Persistencia principal em PostgreSQL, porque o modulo exige consistencia, `foreign key`, auditoria, dinheiro, contrato ou documento.

`users.user_id` deve ser a primeira integracao relacional quando houver usuario, empresa, rider, admin ou system actor.

`wallets.wallet_id` e `transactions.transaction_id` devem ser usados quando houver dinheiro, saldo, pagamento, repasse, refund, fee, split ou escrow.

`user_id` em MongoDB deve ser string UUID validada por regex para manter ponte segura com PostgreSQL.

## Integracoes

Dependencias minimas: PAY. Integracoes previstas: DOCS, SOCIAL.

## Atores Primarios

- doador
- gestor de causa
- auditor social

## Capacidades-Chave

- causas
- grants
- ledger de fundos

## Entidades Relacionais

- `charity_causes`
- `charity_grants`
- `charity_fund_ledger`

## Payloads Volumosos E Colecoes

- Nao aplicavel.

## Eventos Canonicos

- `charity.cause.published`
- `charity.grant.approved`
- `charity.fund.posted`

## Compliance, Risco E Guarda

- donation_audit
- impact_traceability
- fund_immutability

## Superficies Admin E Operacao

- painel de causas
- fila de grants
- monitor de ledger social

## Regras De Evolucao

1. Nao criar tabela duplicada de usuario; usar sempre `public.users`.
2. Nao criar schema legado paralelo; manter objetos novos em `public` enquanto esta worktree exigir core-first.
3. Usar `UUID` para chaves e referencias quando o dado for relacional.
4. Usar `DECIMAL(18,4)` para BRL e `DECIMAL(18,8)` para `$NEX`.
5. Usar `TIMESTAMPTZ` para eventos com tempo operacional.
6. Usar `append-only` quando o dado representar dinheiro, auditoria, certificado, receipt, regra versionada ou trilha legal.
7. Atualizar Manual Online e PDF em qualquer mudanca de schema, script ou contrato.

## Primeiro Backlog Tecnico

- fechar prova de impacto
- definir governanca de grants
- ligar recibo social auditavel
