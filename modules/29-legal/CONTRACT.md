# Contrato Operacional - 29. Valley Legal

Este arquivo e gerado pela automacao `scripts/automacao_sincronizador_modulos.py`.

Ele define a fronteira inicial do modulo para guiar desenvolvimento, implantacao e evolucao sem quebrar o nucleo Valley.

## Identidade Do Modulo

- Codigo tecnico: `LEGAL`
- Dominio: `city_mobility_security`
- Tier: `foundation`
- Data home: `postgres`
- Status atual: `Parcialmente implantado`
- Fase atual: `VALIDATE` (Validacao)

## Objetivo Simples

Contratos, mediacao por IA, fallback PIN e juridico.

## Politica De Dados

Persistencia principal em PostgreSQL, porque o modulo exige consistencia, `foreign key`, auditoria, dinheiro, contrato ou documento.

`users.user_id` deve ser a primeira integracao relacional quando houver usuario, empresa, rider, admin ou system actor.

`wallets.wallet_id` e `transactions.transaction_id` devem ser usados quando houver dinheiro, saldo, pagamento, repasse, refund, fee, split ou escrow.

`user_id` em MongoDB deve ser string UUID validada por regex para manter ponte segura com PostgreSQL.

## Integracoes

Dependencias minimas: ID. Integracoes previstas: DOCS, SECURITY.

## Atores Primarios

- juridico
- assinante
- mediador

## Capacidades-Chave

- contratos
- assinaturas
- disputas e trilha juridica

## Entidades Relacionais

- `legal_contracts`
- `legal_contract_parties`
- `legal_signatures`
- `legal_disputes`
- `legal_audit_events`
- `legal_fallback_pin_credentials`

## Payloads Volumosos E Colecoes

- Nao aplicavel.

## Eventos Canonicos

- `legal.contract.created`
- `legal.signature.recorded`
- `legal.dispute.opened`

## Compliance, Risco E Guarda

- legal_audit
- signature_traceability
- fallback_pin_hashing

## Superficies Admin E Operacao

- painel juridico
- fila de assinaturas
- monitor de disputas

## Regras De Evolucao

1. Nao criar tabela duplicada de usuario; usar sempre `public.users`.
2. Nao criar schema legado paralelo; manter objetos novos em `public` enquanto esta worktree exigir core-first.
3. Usar `UUID` para chaves e referencias quando o dado for relacional.
4. Usar `DECIMAL(18,4)` para BRL e `DECIMAL(18,8)` para `V-Coin`.
5. Usar `TIMESTAMPTZ` para eventos com tempo operacional.
6. Usar `append-only` quando o dado representar dinheiro, auditoria, certificado, receipt, regra versionada ou trilha legal.
7. Atualizar Manual Online e PDF em qualquer mudanca de schema, script ou contrato.

## Primeiro Backlog Tecnico

- fechar clausulas parametrizadas
- definir mediacao assistida por IA
- ligar prova documental do contrato
