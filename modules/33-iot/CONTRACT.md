# Contrato Operacional - 33. Valley IoT

Este arquivo e gerado pela automacao `scripts/automacao_sincronizador_modulos.py`.

Ele define a fronteira inicial do modulo para guiar desenvolvimento, implantacao e evolucao sem quebrar o nucleo Valley.

## Identidade Do Modulo

- Codigo tecnico: `IOT`
- Dominio: `frontier_iot_energy`
- Tier: `foundation`
- Data home: `mongo`
- Status atual: `Parcialmente implantado`
- Fase atual: `VALIDATE` (Validacao)

## Objetivo Simples

Dispositivos conectados, sensores e hub inteligente.

## Politica De Dados

Persistencia principal em MongoDB, porque o modulo trabalha com IA, social, telemetria, eventos volumosos ou payload semi-estruturado.

`users.user_id` deve ser a primeira integracao relacional quando houver usuario, empresa, rider, admin ou system actor.

`wallets.wallet_id` e `transactions.transaction_id` devem ser usados quando houver dinheiro, saldo, pagamento, repasse, refund, fee, split ou escrow.

`user_id` em MongoDB deve ser string UUID validada por regex para manter ponte segura com PostgreSQL.

## Integracoes

Dependencias minimas: ID. Integracoes previstas: HOME, FLEET, SECURITY.

## Atores Primarios

- operador de dispositivos
- tecnico de campo
- motor de automacao

## Capacidades-Chave

- registry de device
- eventos de sensor
- hub conectado

## Entidades Relacionais

- Nao aplicavel.

## Payloads Volumosos E Colecoes

- `iot_device_registry`
- `iot_sensor_events`
- `telemetry_logs`

## Eventos Canonicos

- `iot.device.provisioned`
- `iot.sensor.event_ingested`
- `iot.device.offline_detected`

## Compliance, Risco E Guarda

- device_traceability
- telemetry_retention
- access_control

## Superficies Admin E Operacao

- painel de devices
- fila de provisioning
- monitor de sensores

## Regras De Evolucao

1. Nao criar tabela duplicada de usuario; usar sempre `public.users`.
2. Nao criar schema legado paralelo; manter objetos novos em `public` enquanto esta worktree exigir core-first.
3. Usar `UUID` para chaves e referencias quando o dado for relacional.
4. Usar `DECIMAL(18,4)` para BRL e `DECIMAL(18,8)` para `V-Coin`.
5. Usar `TIMESTAMPTZ` para eventos com tempo operacional.
6. Usar `append-only` quando o dado representar dinheiro, auditoria, certificado, receipt, regra versionada ou trilha legal.
7. Atualizar Manual Online e PDF em qualquer mudanca de schema, script ou contrato.

## Primeiro Backlog Tecnico

- fechar inventario de device
- definir heartbeat canonico
- ligar playbook de device offline
