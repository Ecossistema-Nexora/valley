# Contrato Operacional - 34. Valley Bio

Este arquivo e gerado pela automacao `scripts/valley_module_automation.py`.

Ele define a fronteira inicial do modulo para guiar desenvolvimento, implantacao e evolucao sem quebrar o nucleo Valley.

## Identidade Do Modulo

- Codigo tecnico: `BIO`
- Dominio: `frontier_iot_energy`
- Tier: `expansion`
- Data home: `postgres_mongo`
- Status atual: `Parcialmente implantado`
- Fase atual: `VALIDATE` (Validacao)

## Objetivo Simples

Sustentabilidade, logistica reversa e impacto ambiental.

## Politica De Dados

Persistencia hibrida: PostgreSQL guarda o contrato operacional e MongoDB guarda payload volumoso, IA, social, telemetria ou eventos semi-estruturados.

`users.user_id` deve ser a primeira integracao relacional quando houver usuario, empresa, rider, admin ou system actor.

`wallets.wallet_id` e `transactions.transaction_id` devem ser usados quando houver dinheiro, saldo, pagamento, repasse, refund, fee, split ou escrow.

`user_id` em MongoDB deve ser string UUID validada por regex para manter ponte segura com PostgreSQL.

## Integracoes

Dependencias minimas: LOG. Integracoes previstas: IOT, ENERGY.

## Atores Primarios

- operador de coleta
- parceiro ambiental
- auditor de impacto

## Capacidades-Chave

- programas de material
- ordem de coleta reversa
- log de impacto

## Entidades Relacionais

- `bio_material_programs`
- `bio_collection_orders`
- `bio_collection_events`

## Payloads Volumosos E Colecoes

- `bio_impact_logs`
- `iot_sensor_events`

## Eventos Canonicos

- `bio.program.opened`
- `bio.collection.scheduled`
- `bio.impact.measured`

## Compliance, Risco E Guarda

- reverse_logistics_traceability
- impact_audit
- chain_of_custody

## Superficies Admin E Operacao

- painel ambiental
- fila de coleta
- monitor de impacto

## Regras De Evolucao

1. Nao criar tabela duplicada de usuario; usar sempre `public.users`.
2. Nao criar schema legado paralelo; manter objetos novos em `public` enquanto esta worktree exigir core-first.
3. Usar `UUID` para chaves e referencias quando o dado for relacional.
4. Usar `DECIMAL(18,4)` para BRL e `DECIMAL(18,8)` para `V-Coin`.
5. Usar `TIMESTAMPTZ` para eventos com tempo operacional.
6. Usar `append-only` quando o dado representar dinheiro, auditoria, certificado, receipt, regra versionada ou trilha legal.
7. Atualizar Manual Online e PDF em qualquer mudanca de schema, script ou contrato.

## Primeiro Backlog Tecnico

- fechar score de impacto por material
- definir prova de coleta
- ligar conciliacao com parceiro ambiental
