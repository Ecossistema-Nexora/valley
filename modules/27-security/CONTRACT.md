# Contrato Operacional - 27. Valley Security

Este arquivo e gerado pela automacao `scripts/valley_module_automation.py`.

Ele define a fronteira inicial do modulo para guiar desenvolvimento, implantacao e evolucao sem quebrar o nucleo Valley.

## Identidade Do Modulo

- Codigo tecnico: `SECURITY`
- Dominio: `city_mobility_security`
- Tier: `core`
- Data home: `postgres_mongo`
- Status atual: `Parcialmente implantado`
- Fase atual: `VALIDATE` (Validacao)

## Objetivo Simples

SOS, protecao pessoal, biometria e risco.

## Politica De Dados

Persistencia hibrida: PostgreSQL guarda o contrato operacional e MongoDB guarda payload volumoso, IA, social, telemetria ou eventos semi-estruturados.

`users.user_id` deve ser a primeira integracao relacional quando houver usuario, empresa, rider, admin ou system actor.

`wallets.wallet_id` e `transactions.transaction_id` devem ser usados quando houver dinheiro, saldo, pagamento, repasse, refund, fee, split ou escrow.

`user_id` em MongoDB deve ser string UUID validada por regex para manter ponte segura com PostgreSQL.

## Integracoes

Dependencias minimas: ID. Integracoes previstas: IOT, LEGAL.

## Atores Primarios

- usuario protegido
- analista de risco
- operador SOS

## Capacidades-Chave

- contatos confiaveis
- credencial biometrica por hash
- trilha de incidente

## Entidades Relacionais

- `security_trusted_contacts`
- `security_biometric_credentials`
- `security_incidents`
- `security_incident_events`

## Payloads Volumosos E Colecoes

- `security_signal_logs`
- `iot_sensor_events`

## Eventos Canonicos

- `security.sos.triggered`
- `security.biometric.enrolled`
- `security.incident.closed`

## Compliance, Risco E Guarda

- biometric_hashing
- incident_chain_of_custody
- access_control

## Superficies Admin E Operacao

- torre de seguranca
- fila de incidentes
- painel de credenciais

## Regras De Evolucao

1. Nao criar tabela duplicada de usuario; usar sempre `public.users`.
2. Nao criar schema legado paralelo; manter objetos novos em `public` enquanto esta worktree exigir core-first.
3. Usar `UUID` para chaves e referencias quando o dado for relacional.
4. Usar `DECIMAL(18,4)` para BRL e `DECIMAL(18,8)` para `V-Coin`.
5. Usar `TIMESTAMPTZ` para eventos com tempo operacional.
6. Usar `append-only` quando o dado representar dinheiro, auditoria, certificado, receipt, regra versionada ou trilha legal.
7. Atualizar Manual Online e PDF em qualquer mudanca de schema, script ou contrato.

## Primeiro Backlog Tecnico

- fechar severidade de incidente
- definir resposta por playbook
- ligar trilha forense
