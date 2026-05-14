# Contrato Operacional - 31. Valley Insurance

Este arquivo e gerado pela automacao `scripts/automacao_sincronizador_modulos.py`.

Ele define a fronteira inicial do modulo para guiar desenvolvimento, implantacao e evolucao sem quebrar o nucleo Valley.

## Identidade Do Modulo

- Codigo tecnico: `INSURANCE`
- Dominio: `commerce_fintech_assets`
- Tier: `expansion`
- Data home: `postgres`
- Status atual: `Parcialmente implantado`
- Fase atual: `VALIDATE` (Validacao)

## Objetivo Simples

Seguros sob demanda, protecao e analise de risco.

## Politica De Dados

Persistencia principal em PostgreSQL, porque o modulo exige consistencia, `foreign key`, auditoria, dinheiro, contrato ou documento.

`users.user_id` deve ser a primeira integracao relacional quando houver usuario, empresa, rider, admin ou system actor.

`wallets.wallet_id` e `transactions.transaction_id` devem ser usados quando houver dinheiro, saldo, pagamento, repasse, refund, fee, split ou escrow.

`user_id` em MongoDB deve ser string UUID validada por regex para manter ponte segura com PostgreSQL.

## Integracoes

Dependencias minimas: PAY, LEGAL. Integracoes previstas: SECURITY, DOCS.

## Atores Primarios

- segurado
- underwriter
- analista de sinistro

## Capacidades-Chave

- produtos e apolices
- claims
- eventos de claim

## Entidades Relacionais

- `insurance_products`
- `insurance_policies`
- `insurance_claims`
- `insurance_claim_events`

## Payloads Volumosos E Colecoes

- Nao aplicavel.

## Eventos Canonicos

- `insurance.policy.issued`
- `insurance.claim.opened`
- `insurance.claim.settled`

## Compliance, Risco E Guarda

- policy_audit
- claim_traceability
- risk_underwriting

## Superficies Admin E Operacao

- painel de apolices
- fila de claim
- monitor de underwriting

## Regras De Evolucao

1. Nao criar tabela duplicada de usuario; usar sempre `public.users`.
2. Nao criar schema legado paralelo; manter objetos novos em `public` enquanto esta worktree exigir core-first.
3. Usar `UUID` para chaves e referencias quando o dado for relacional.
4. Usar `DECIMAL(18,4)` para BRL e `DECIMAL(18,8)` para `V-Coin`.
5. Usar `TIMESTAMPTZ` para eventos com tempo operacional.
6. Usar `append-only` quando o dado representar dinheiro, auditoria, certificado, receipt, regra versionada ou trilha legal.
7. Atualizar Manual Online e PDF em qualquer mudanca de schema, script ou contrato.

## Primeiro Backlog Tecnico

- fechar score de risco
- definir anti-fraude de claim
- ligar payout auditavel
