# Contrato Operacional - 01. Valley REPLY

Este arquivo e gerado pela automacao `scripts/valley_module_automation.py`.

Ele define a fronteira inicial do modulo para guiar desenvolvimento, implantacao e evolucao sem quebrar o nucleo Valley.

## Identidade Do Modulo

- Codigo tecnico: `REPLY`
- Dominio: `logistics_erp_operations`
- Tier: `foundation`
- Data home: `postgres`
- Status atual: `Parcialmente implantado`
- Fase atual: `VALIDATE` (Validacao)

## Objetivo Simples

ERP/WMS para compras, estoque, ordens de servico e faturamento.

## Politica De Dados

Persistencia principal em PostgreSQL, porque o modulo exige consistencia, `foreign key`, auditoria, dinheiro, contrato ou documento.

`users.user_id` deve ser a primeira integracao relacional quando houver usuario, empresa, rider, admin ou system actor.

`wallets.wallet_id` e `transactions.transaction_id` devem ser usados quando houver dinheiro, saldo, pagamento, repasse, refund, fee, split ou escrow.

`user_id` em MongoDB deve ser string UUID validada por regex para manter ponte segura com PostgreSQL.

## Integracoes

Dependencias minimas: ID, PAY, BUSINESS. Integracoes previstas: STOCK, MARKETPLACE, WMS.

## Atores Primarios

- operador interno
- comprador
- gestor empresarial

## Capacidades-Chave

- compras e sourcing
- ordens de servico
- faturamento operacional

## Entidades Relacionais

- `suppliers`
- `procurement_orders`
- `service_work_orders`
- `inventory_items`

## Payloads Volumosos E Colecoes

- Nao aplicavel.

## Eventos Canonicos

- `reply.procurement_order.created`
- `reply.service_work_order.closed`
- `reply.billing_cycle.closed`

## Compliance, Risco E Guarda

- financial_audit
- tax_traceability
- supplier_approval

## Superficies Admin E Operacao

- painel de compras
- cadastro de fornecedores
- fila de faturamento

## Regras De Evolucao

1. Nao criar tabela duplicada de usuario; usar sempre `public.users`.
2. Nao criar schema legado paralelo; manter objetos novos em `public` enquanto esta worktree exigir core-first.
3. Usar `UUID` para chaves e referencias quando o dado for relacional.
4. Usar `DECIMAL(18,4)` para BRL e `DECIMAL(18,8)` para `$NEX`.
5. Usar `TIMESTAMPTZ` para eventos com tempo operacional.
6. Usar `append-only` quando o dado representar dinheiro, auditoria, certificado, receipt, regra versionada ou trilha legal.
7. Atualizar Manual Online e PDF em qualquer mudanca de schema, script ou contrato.

## Primeiro Backlog Tecnico

- fechar fluxo fiscal ponta a ponta
- amarrar aprovacao por unidade
- instrumentar SLA de compras
