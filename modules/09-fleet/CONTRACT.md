# Contrato Operacional - 09. Valley Fleet

Este arquivo e gerado pela automacao `scripts/valley_module_automation.py`.

Ele define a fronteira inicial do modulo para guiar desenvolvimento, implantacao e evolucao sem quebrar o nucleo Valley.

## Identidade Do Modulo

- Codigo tecnico: `FLEET`
- Dominio: `logistics_erp_operations`
- Tier: `core`
- Data home: `mongo`
- Status atual: `Parcialmente implantado`
- Fase atual: `VALIDATE` (Validacao)

## Objetivo Simples

Gestao de frotas, telemetria, manutencao preventiva e rotas.

## Politica De Dados

Persistencia principal em MongoDB, porque o modulo trabalha com IA, social, telemetria, eventos volumosos ou payload semi-estruturado.

`users.user_id` deve ser a primeira integracao relacional quando houver usuario, empresa, rider, admin ou system actor.

`wallets.wallet_id` e `transactions.transaction_id` devem ser usados quando houver dinheiro, saldo, pagamento, repasse, refund, fee, split ou escrow.

`user_id` em MongoDB deve ser string UUID validada por regex para manter ponte segura com PostgreSQL.

## Integracoes

Dependencias minimas: IOT, MOBILITY. Integracoes previstas: LOG, SECURITY.

## Atores Primarios

- gestor de frota
- motorista
- tecnico de manutencao

## Capacidades-Chave

- perfil de veiculo
- telemetria de uso
- manutencao preventiva

## Entidades Relacionais

- `mobility_trips`

## Payloads Volumosos E Colecoes

- `fleet_vehicle_profiles`
- `fleet_maintenance_events`
- `telemetry_logs`

## Eventos Canonicos

- `fleet.vehicle.registered`
- `fleet.maintenance.logged`
- `fleet.telemetry.alerted`

## Compliance, Risco E Guarda

- driver_accountability
- maintenance_traceability
- vehicle_compliance

## Superficies Admin E Operacao

- painel de frota
- calendario de manutencao
- monitor de telemetria

## Regras De Evolucao

1. Nao criar tabela duplicada de usuario; usar sempre `public.users`.
2. Nao criar schema legado paralelo; manter objetos novos em `public` enquanto esta worktree exigir core-first.
3. Usar `UUID` para chaves e referencias quando o dado for relacional.
4. Usar `DECIMAL(18,4)` para BRL e `DECIMAL(18,8)` para `V-Coin`.
5. Usar `TIMESTAMPTZ` para eventos com tempo operacional.
6. Usar `append-only` quando o dado representar dinheiro, auditoria, certificado, receipt, regra versionada ou trilha legal.
7. Atualizar Manual Online e PDF em qualquer mudanca de schema, script ou contrato.

## Primeiro Backlog Tecnico

- fechar score de saude do veiculo
- definir corte por manutencao critica
- ligar custo por km
