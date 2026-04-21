# Contrato Operacional - 41. Valley Mente

Este arquivo e gerado pela automacao `scripts/valley_module_automation.py`.

Ele define a fronteira inicial do modulo para guiar desenvolvimento, implantacao e evolucao sem quebrar o nucleo Valley.

## Identidade Do Modulo

- Codigo tecnico: `MENTE`
- Dominio: `services_health_human`
- Tier: `core`
- Data home: `postgres`
- Status atual: `Parcialmente implantado`
- Fase atual: `VALIDATE` (Validacao)

## Objetivo Simples

Saude mental digital, teleterapia e notas cifradas.

## Politica De Dados

Persistencia principal em PostgreSQL, porque o modulo exige consistencia, `foreign key`, auditoria, dinheiro, contrato ou documento.

`users.user_id` deve ser a primeira integracao relacional quando houver usuario, empresa, rider, admin ou system actor.

`wallets.wallet_id` e `transactions.transaction_id` devem ser usados quando houver dinheiro, saldo, pagamento, repasse, refund, fee, split ou escrow.

`user_id` em MongoDB deve ser string UUID validada por regex para manter ponte segura com PostgreSQL.

## Integracoes

Dependencias minimas: HEALTH, ID. Integracoes previstas: ADVISOR, DOCS.

## Atores Primarios

- paciente
- terapeuta
- operador de cuidado

## Capacidades-Chave

- teleterapia
- notas seguras
- sinais de acompanhamento

## Entidades Relacionais

- `teletherapy_sessions`
- `health_profiles`

## Payloads Volumosos E Colecoes

- Nao aplicavel.

## Eventos Canonicos

- `mente.session.scheduled`
- `mente.session.completed`
- `mente.followup.created`

## Compliance, Risco E Guarda

- lgpd_sensitive_data
- therapy_confidentiality
- clinical_access_audit

## Superficies Admin E Operacao

- painel terapeutico
- fila de sessoes
- monitor de follow-up

## Regras De Evolucao

1. Nao criar tabela duplicada de usuario; usar sempre `public.users`.
2. Nao criar schema legado paralelo; manter objetos novos em `public` enquanto esta worktree exigir core-first.
3. Usar `UUID` para chaves e referencias quando o dado for relacional.
4. Usar `DECIMAL(18,4)` para BRL e `DECIMAL(18,8)` para `$NEX`.
5. Usar `TIMESTAMPTZ` para eventos com tempo operacional.
6. Usar `append-only` quando o dado representar dinheiro, auditoria, certificado, receipt, regra versionada ou trilha legal.
7. Atualizar Manual Online e PDF em qualquer mudanca de schema, script ou contrato.

## Primeiro Backlog Tecnico

- fechar trilha de nota cifrada
- definir protocolo de risco
- ligar agenda terapeutica
