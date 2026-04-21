# Contrato Operacional - 13. Valley Health

Este arquivo e gerado pela automacao `scripts/valley_module_automation.py`.

Ele define a fronteira inicial do modulo para guiar desenvolvimento, implantacao e evolucao sem quebrar o nucleo Valley.

## Identidade Do Modulo

- Codigo tecnico: `HEALTH`
- Dominio: `services_health_human`
- Tier: `core`
- Data home: `postgres_mongo`
- Status atual: `Parcialmente implantado`
- Fase atual: `VALIDATE` (Validacao)

## Objetivo Simples

Saude preditiva, cuidados integrados e dados sensiveis.

## Politica De Dados

Persistencia hibrida: PostgreSQL guarda o contrato operacional e MongoDB guarda payload volumoso, IA, social, telemetria ou eventos semi-estruturados.

`users.user_id` deve ser a primeira integracao relacional quando houver usuario, empresa, rider, admin ou system actor.

`wallets.wallet_id` e `transactions.transaction_id` devem ser usados quando houver dinheiro, saldo, pagamento, repasse, refund, fee, split ou escrow.

`user_id` em MongoDB deve ser string UUID validada por regex para manter ponte segura com PostgreSQL.

## Integracoes

Dependencias minimas: ID. Integracoes previstas: FOOD, FITNESS, PHARMACY.

## Atores Primarios

- paciente
- profissional de saude
- operador clinico

## Capacidades-Chave

- perfil clinico
- plano de cuidado
- prescricao segura

## Entidades Relacionais

- `health_profiles`
- `health_care_plans`
- `health_prescriptions`

## Payloads Volumosos E Colecoes

- `ai_memory`
- `telemetry_logs`

## Eventos Canonicos

- `health.profile.updated`
- `health.care_plan.activated`
- `health.prescription.issued`

## Compliance, Risco E Guarda

- lgpd_sensitive_data
- clinical_audit
- consent_management

## Superficies Admin E Operacao

- painel clinico
- fila de consentimento
- monitor de risco assistencial

## Regras De Evolucao

1. Nao criar tabela duplicada de usuario; usar sempre `public.users`.
2. Nao criar schema legado paralelo; manter objetos novos em `public` enquanto esta worktree exigir core-first.
3. Usar `UUID` para chaves e referencias quando o dado for relacional.
4. Usar `DECIMAL(18,4)` para BRL e `DECIMAL(18,8)` para `$NEX`.
5. Usar `TIMESTAMPTZ` para eventos com tempo operacional.
6. Usar `append-only` quando o dado representar dinheiro, auditoria, certificado, receipt, regra versionada ou trilha legal.
7. Atualizar Manual Online e PDF em qualquer mudanca de schema, script ou contrato.

## Primeiro Backlog Tecnico

- amarrar consentimento granular
- definir trilha de acesso clinico
- ligar sinais de risco preditivo
