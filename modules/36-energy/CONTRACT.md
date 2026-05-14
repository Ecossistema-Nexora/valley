# Contrato Operacional - 36. Valley Energy

Este arquivo e gerado pela automacao `scripts/automacao_sincronizador_modulos.py`.

Ele define a fronteira inicial do modulo para guiar desenvolvimento, implantacao e evolucao sem quebrar o nucleo Valley.

## Identidade Do Modulo

- Codigo tecnico: `ENERGY`
- Dominio: `frontier_iot_energy`
- Tier: `expansion`
- Data home: `postgres_mongo`
- Status atual: `Parcialmente implantado`
- Fase atual: `VALIDATE` (Validacao)

## Objetivo Simples

Energia, smart grid, creditos e transacoes P2P.

## Politica De Dados

Persistencia hibrida: PostgreSQL guarda o contrato operacional e MongoDB guarda payload volumoso, IA, social, telemetria ou eventos semi-estruturados.

`users.user_id` deve ser a primeira integracao relacional quando houver usuario, empresa, rider, admin ou system actor.

`wallets.wallet_id` e `transactions.transaction_id` devem ser usados quando houver dinheiro, saldo, pagamento, repasse, refund, fee, split ou escrow.

`user_id` em MongoDB deve ser string UUID validada por regex para manter ponte segura com PostgreSQL.

## Integracoes

Dependencias minimas: PAY, IOT. Integracoes previstas: BIO, HOME.

## Atores Primarios

- prosumidor
- operador de grid
- analista de settlement

## Capacidades-Chave

- ativos de energia
- trade P2P
- settlement auditavel

## Entidades Relacionais

- `energy_assets`
- `energy_trade_orders`
- `energy_settlement_ledger`

## Payloads Volumosos E Colecoes

- `energy_meter_streams`
- `iot_sensor_events`

## Eventos Canonicos

- `energy.asset.registered`
- `energy.trade.matched`
- `energy.settlement.posted`

## Compliance, Risco E Guarda

- meter_traceability
- financial_settlement_immutability
- grid_compliance

## Superficies Admin E Operacao

- painel de ativos
- monitor de trades
- console de settlement

## Regras De Evolucao

1. Nao criar tabela duplicada de usuario; usar sempre `public.users`.
2. Nao criar schema legado paralelo; manter objetos novos em `public` enquanto esta worktree exigir core-first.
3. Usar `UUID` para chaves e referencias quando o dado for relacional.
4. Usar `DECIMAL(18,4)` para BRL e `DECIMAL(18,8)` para `V-Coin`.
5. Usar `TIMESTAMPTZ` para eventos com tempo operacional.
6. Usar `append-only` quando o dado representar dinheiro, auditoria, certificado, receipt, regra versionada ou trilha legal.
7. Atualizar Manual Online e PDF em qualquer mudanca de schema, script ou contrato.

## Primeiro Backlog Tecnico

- fechar matching de energia
- definir janela de settlement
- ligar conciliacao com medidor
