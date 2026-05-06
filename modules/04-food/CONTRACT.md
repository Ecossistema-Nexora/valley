# Contrato Operacional - 04. Valley Food

Este arquivo e gerado pela automacao `scripts/valley_module_automation.py`.

Ele define a fronteira inicial do modulo para guiar desenvolvimento, implantacao e evolucao sem quebrar o nucleo Valley.

## Identidade Do Modulo

- Codigo tecnico: `FOOD`
- Dominio: `logistics_erp_operations`
- Tier: `core`
- Data home: `postgres`
- Status atual: `Parcialmente implantado`
- Fase atual: `DATA_CONTRACT` (Contrato de dados)

## Objetivo Simples

Delivery alimentar com split Pay, informacoes nutricionais e taxa operacional.

## Politica De Dados

Persistencia principal em PostgreSQL, porque o modulo exige consistencia, `foreign key`, auditoria, dinheiro, contrato ou documento.

`users.user_id` deve ser a primeira integracao relacional quando houver usuario, empresa, rider, admin ou system actor.

`wallets.wallet_id` e `transactions.transaction_id` devem ser usados quando houver dinheiro, saldo, pagamento, repasse, refund, fee, split ou escrow.

`user_id` em MongoDB deve ser string UUID validada por regex para manter ponte segura com PostgreSQL.

## Integracoes

Dependencias minimas: PAY, LOG, HEALTH. Integracoes previstas: ORDERS, MOBILITY, DOCS.

## Atores Primarios

- restaurante
- consumidor
- operador de atendimento

## Capacidades-Chave

- pedido alimentar
- split operacional
- restricoes nutricionais

## Entidades Relacionais

- `orders`
- `transactions`
- `health_profiles`

## Payloads Volumosos E Colecoes

- Nao aplicavel.

## Eventos Canonicos

- `food.order.placed`
- `food.order.prepared`
- `food.order.delivered`

## Compliance, Risco E Guarda

- food_safety_traceability
- payment_split_audit
- allergen_notice

## Superficies Admin E Operacao

- painel de pedidos
- gestao de cardapio
- monitor de cozinha

## Regras De Evolucao

1. Nao criar tabela duplicada de usuario; usar sempre `public.users`.
2. Nao criar schema legado paralelo; manter objetos novos em `public` enquanto esta worktree exigir core-first.
3. Usar `UUID` para chaves e referencias quando o dado for relacional.
4. Usar `DECIMAL(18,4)` para BRL e `DECIMAL(18,8)` para `V-Coin`.
5. Usar `TIMESTAMPTZ` para eventos com tempo operacional.
6. Usar `append-only` quando o dado representar dinheiro, auditoria, certificado, receipt, regra versionada ou trilha legal.
7. Atualizar Manual Online e PDF em qualquer mudanca de schema, script ou contrato.

## Primeiro Backlog Tecnico

- criar contrato especifico de cardapio e loja
- definir SLA de preparo
- amarrar taxonomia nutricional
