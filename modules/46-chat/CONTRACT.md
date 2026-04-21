# Contrato Operacional - 46. Valley Chat

Este arquivo e gerado pela automacao `scripts/valley_module_automation.py`.

Ele define a fronteira inicial do modulo para guiar desenvolvimento, implantacao e evolucao sem quebrar o nucleo Valley.

## Identidade Do Modulo

- Codigo tecnico: `CHAT`
- Dominio: `ai_memory_operations`
- Tier: `core`
- Data home: `postgres_mongo`
- Status atual: `Parcialmente implantado`
- Fase atual: `VALIDATE` (Validacao)

## Objetivo Simples

Mensageria com persona pessoal/profissional e retencao segura.

## Politica De Dados

Persistencia hibrida: PostgreSQL guarda o contrato operacional e MongoDB guarda payload volumoso, IA, social, telemetria ou eventos semi-estruturados.

`users.user_id` deve ser a primeira integracao relacional quando houver usuario, empresa, rider, admin ou system actor.

`wallets.wallet_id` e `transactions.transaction_id` devem ser usados quando houver dinheiro, saldo, pagamento, repasse, refund, fee, split ou escrow.

`user_id` em MongoDB deve ser string UUID validada por regex para manter ponte segura com PostgreSQL.

## Integracoes

Dependencias minimas: ID. Integracoes previstas: AGENDA, ADVISOR.

## Atores Primarios

- usuario pessoal
- usuario profissional
- motor de assistencia

## Capacidades-Chave

- conversa dual persona
- retencao segura
- ponte com agenda e advisor

## Entidades Relacionais

- `chat_conversations`
- `users`

## Payloads Volumosos E Colecoes

- `ai_memory`
- `agenda_items`

## Eventos Canonicos

- `chat.conversation.opened`
- `chat.message.persisted`
- `chat.context.promoted`

## Compliance, Risco E Guarda

- message_retention_policy
- persona_separation
- consent_audit

## Superficies Admin E Operacao

- painel de conversas
- monitor de contexto
- fila de retencao

## Regras De Evolucao

1. Nao criar tabela duplicada de usuario; usar sempre `public.users`.
2. Nao criar schema legado paralelo; manter objetos novos em `public` enquanto esta worktree exigir core-first.
3. Usar `UUID` para chaves e referencias quando o dado for relacional.
4. Usar `DECIMAL(18,4)` para BRL e `DECIMAL(18,8)` para `$NEX`.
5. Usar `TIMESTAMPTZ` para eventos com tempo operacional.
6. Usar `append-only` quando o dado representar dinheiro, auditoria, certificado, receipt, regra versionada ou trilha legal.
7. Atualizar Manual Online e PDF em qualquer mudanca de schema, script ou contrato.

## Primeiro Backlog Tecnico

- fechar politica de retention
- definir separacao pessoal x profissional
- ligar contexto com advisor
