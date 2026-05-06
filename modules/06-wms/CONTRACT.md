# Contrato Operacional - 06. Valley WMS

Este arquivo e gerado pela automacao `scripts/valley_module_automation.py`.

Ele define a fronteira inicial do modulo para guiar desenvolvimento, implantacao e evolucao sem quebrar o nucleo Valley.

## Identidade Do Modulo

- Codigo tecnico: `WMS`
- Dominio: `logistics_erp_operations`
- Tier: `foundation`
- Data home: `postgres_mongo`
- Status atual: `Parcialmente implantado`
- Fase atual: `VALIDATE` (Validacao)

## Objetivo Simples

Gestao inteligente de armazens, sensores e estoque multi-deposito.

## Politica De Dados

Persistencia hibrida: PostgreSQL guarda o contrato operacional e MongoDB guarda payload volumoso, IA, social, telemetria ou eventos semi-estruturados.

`users.user_id` deve ser a primeira integracao relacional quando houver usuario, empresa, rider, admin ou system actor.

`wallets.wallet_id` e `transactions.transaction_id` devem ser usados quando houver dinheiro, saldo, pagamento, repasse, refund, fee, split ou escrow.

`user_id` em MongoDB deve ser string UUID validada por regex para manter ponte segura com PostgreSQL.

## Integracoes

Dependencias minimas: REPLY. Integracoes previstas: STOCK, IOT, BUSINESS.

## Atores Primarios

- coordenador de armazem
- separador
- auditor operacional

## Capacidades-Chave

- enderecamento de estoque
- contagem ciclica
- sensoriamento de armazem

## Entidades Relacionais

- `warehouses`
- `inventory_items`
- `warehouse_cycle_counts`
- `inventory_movements`

## Payloads Volumosos E Colecoes

- `warehouse_sensor_snapshots`
- `iot_sensor_events`

## Eventos Canonicos

- `wms.cycle_count.started`
- `wms.inventory.variance_detected`
- `wms.sensor.threshold_breached`

## Compliance, Risco E Guarda

- inventory_audit
- cold_chain_monitoring
- warehouse_traceability

## Superficies Admin E Operacao

- painel de armazem
- monitor de variancia
- console de sensores

## Regras De Evolucao

1. Nao criar tabela duplicada de usuario; usar sempre `public.users`.
2. Nao criar schema legado paralelo; manter objetos novos em `public` enquanto esta worktree exigir core-first.
3. Usar `UUID` para chaves e referencias quando o dado for relacional.
4. Usar `DECIMAL(18,4)` para BRL e `DECIMAL(18,8)` para `V-Coin`.
5. Usar `TIMESTAMPTZ` para eventos com tempo operacional.
6. Usar `append-only` quando o dado representar dinheiro, auditoria, certificado, receipt, regra versionada ou trilha legal.
7. Atualizar Manual Online e PDF em qualquer mudanca de schema, script ou contrato.

## Primeiro Backlog Tecnico

- fechar mapa de enderecamento
- amarrar ajuste de variancia
- ligar alarmes por temperatura
