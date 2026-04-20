# Contrato Operacional - 29. Valley Legal

Este arquivo e gerado pela automacao `scripts/valley_module_automation.py`.

Ele define a fronteira inicial do modulo para guiar desenvolvimento, implantacao e evolucao sem quebrar o nucleo Valley.

## Identidade Do Modulo

- Codigo tecnico: `LEGAL`
- Dominio: `city_mobility_security`
- Tier: `foundation`
- Data home: `postgres`
- Status atual: `Parcialmente implantado`

## Objetivo Simples

Contratos, mediacao por IA, fallback PIN e juridico.

## Politica De Dados

Persistencia principal em PostgreSQL, porque o modulo exige consistencia, `foreign key`, auditoria, dinheiro, contrato ou documento.

`users.user_id` deve ser a primeira integracao relacional quando houver usuario, empresa, rider, admin ou system actor.

`wallets.wallet_id` e `transactions.transaction_id` devem ser usados quando houver dinheiro, saldo, pagamento, repasse, refund, fee, split ou escrow.

`user_id` em MongoDB deve ser string UUID validada por regex para manter ponte segura com PostgreSQL.

## Integracoes

Dependencias minimas: ID. Integracoes previstas: DOCS, SECURITY.

## Regras De Evolucao

1. Nao criar tabela duplicada de usuario; usar sempre `public.users`.
2. Nao criar schema legado paralelo; manter objetos novos em `public` enquanto esta worktree exigir core-first.
3. Usar `UUID` para chaves e referencias quando o dado for relacional.
4. Usar `DECIMAL(18,4)` para BRL e `DECIMAL(18,8)` para `$NEX`.
5. Usar `TIMESTAMPTZ` para eventos com tempo operacional.
6. Usar `append-only` quando o dado representar dinheiro, auditoria, certificado, receipt, regra versionada ou trilha legal.
7. Atualizar Manual Online e PDF em qualquer mudanca de schema, script ou contrato.

## Primeiro Backlog Tecnico

- Confirmar se o modulo precisa de tabela propria ou se usa tabelas compartilhadas ja existentes.
- Definir eventos de entrada e saida com nomes tecnicos estaveis.
- Definir permissao Admin/RBAC/ABAC quando houver operacao sensivel.
- Registrar regra de negocio em `business_rule_definitions` quando houver pricing, comissao, limite, risco ou compliance.
- Validar se dados volumosos ficam fora do PostgreSQL.
