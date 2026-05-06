# Contrato Operacional - 35. Valley Home

Este arquivo e gerado pela automacao `scripts/valley_module_automation.py`.

Ele define a fronteira inicial do modulo para guiar desenvolvimento, implantacao e evolucao sem quebrar o nucleo Valley.

## Identidade Do Modulo

- Codigo tecnico: `HOME`
- Dominio: `frontier_iot_energy`
- Tier: `expansion`
- Data home: `mongo`
- Status atual: `Parcialmente implantado`
- Fase atual: `VALIDATE` (Validacao)

## Objetivo Simples

Automacao residencial, dispositivos e seguranca domestica.

## Politica De Dados

Persistencia principal em MongoDB, porque o modulo trabalha com IA, social, telemetria, eventos volumosos ou payload semi-estruturado.

`users.user_id` deve ser a primeira integracao relacional quando houver usuario, empresa, rider, admin ou system actor.

`wallets.wallet_id` e `transactions.transaction_id` devem ser usados quando houver dinheiro, saldo, pagamento, repasse, refund, fee, split ou escrow.

`user_id` em MongoDB deve ser string UUID validada por regex para manter ponte segura com PostgreSQL.

## Integracoes

Dependencias minimas: IOT. Integracoes previstas: SECURITY, ENERGY.

## Atores Primarios

- morador
- instalador
- operador smart home

## Capacidades-Chave

- automacao residencial
- eventos domesticos
- regras de cena

## Entidades Relacionais

- Nao aplicavel.

## Payloads Volumosos E Colecoes

- `home_automation_events`
- `iot_device_registry`

## Eventos Canonicos

- `home.device.bound`
- `home.scene.executed`
- `home.alert.triggered`

## Compliance, Risco E Guarda

- household_access_control
- event_retention
- device_safety

## Superficies Admin E Operacao

- painel de residencia
- console de automacao
- monitor de alertas

## Regras De Evolucao

1. Nao criar tabela duplicada de usuario; usar sempre `public.users`.
2. Nao criar schema legado paralelo; manter objetos novos em `public` enquanto esta worktree exigir core-first.
3. Usar `UUID` para chaves e referencias quando o dado for relacional.
4. Usar `DECIMAL(18,4)` para BRL e `DECIMAL(18,8)` para `V-Coin`.
5. Usar `TIMESTAMPTZ` para eventos com tempo operacional.
6. Usar `append-only` quando o dado representar dinheiro, auditoria, certificado, receipt, regra versionada ou trilha legal.
7. Atualizar Manual Online e PDF em qualquer mudanca de schema, script ou contrato.

## Primeiro Backlog Tecnico

- fechar modelo de household
- definir automacao segura
- ligar trilha de acesso domestico
