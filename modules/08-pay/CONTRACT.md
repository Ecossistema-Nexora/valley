# Contrato Operacional - 08. Valley Pay

Este arquivo e gerado pela automacao `scripts/automacao_sincronizador_modulos.py`.

Ele define a fronteira inicial do modulo para guiar desenvolvimento, implantacao e evolucao sem quebrar o nucleo Valley.

## Identidade Do Modulo

- Codigo tecnico: `PAY`
- Dominio: `commerce_fintech_assets`
- Tier: `foundation`
- Data home: `postgres`
- Status atual: `Parcialmente implantado`
- Fase atual: `VALIDATE` (Validacao)

## Objetivo Simples

Carteira, ledger atomico, P2P, splits, limites e conciliacao.

## Politica De Dados

Persistencia principal em PostgreSQL, porque o modulo exige consistencia, `foreign key`, auditoria, dinheiro, contrato ou documento.

`users.user_id` deve ser a primeira integracao relacional quando houver usuario, empresa, rider, admin ou system actor.

`wallets.wallet_id` e `transactions.transaction_id` devem ser usados quando houver dinheiro, saldo, pagamento, repasse, refund, fee, split ou escrow.

`user_id` em MongoDB deve ser string UUID validada por regex para manter ponte segura com PostgreSQL.

## Integracoes

Dependencias minimas: ID. Integracoes previstas: WALLETS, TRANSACTIONS, EQUITY.

## Atores Primarios

- titular da wallet
- operador financeiro
- motor de conciliacao

## Capacidades-Chave

- wallet e saldo
- ledger atomico
- splits e conciliacao

## Entidades Relacionais

- `wallets`
- `transactions`
- `equity_ledger`
- `pepita_ledger`

## Payloads Volumosos E Colecoes

- Nao aplicavel.

## Eventos Canonicos

- `pay.wallet.opened`
- `pay.transaction.posted`
- `pay.settlement.reconciled`

## Compliance, Risco E Guarda

- kyc
- aml_monitoring
- financial_ledger_immutability

## Superficies Admin E Operacao

- painel financeiro
- monitor de conciliacao
- fila de limites e bloqueios

## Regras De Evolucao

1. Nao criar tabela duplicada de usuario; usar sempre `public.users`.
2. Nao criar schema legado paralelo; manter objetos novos em `public` enquanto esta worktree exigir core-first.
3. Usar `UUID` para chaves e referencias quando o dado for relacional.
4. Usar `DECIMAL(18,4)` para BRL e `DECIMAL(18,8)` para `V-Coin`.
5. Usar `TIMESTAMPTZ` para eventos com tempo operacional.
6. Usar `append-only` quando o dado representar dinheiro, auditoria, certificado, receipt, regra versionada ou trilha legal.
7. Atualizar Manual Online e PDF em qualquer mudanca de schema, script ou contrato.

## Primeiro Backlog Tecnico

- fechar matriz de limites
- amarrar regras de chargeback
- instrumentar reconciliacao D0 e D1
