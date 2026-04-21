# Contrato Operacional - 38. Valley Agenda

Este arquivo e gerado pela automacao `scripts/valley_module_automation.py`.

Ele define a fronteira inicial do modulo para guiar desenvolvimento, implantacao e evolucao sem quebrar o nucleo Valley.

## Identidade Do Modulo

- Codigo tecnico: `AGENDA`
- Dominio: `ai_memory_operations`
- Tier: `core`
- Data home: `mongo`
- Status atual: `Parcialmente implantado`
- Fase atual: `VALIDATE` (Validacao)

## Objetivo Simples

Agenda, listas inteligentes, memoria Helena e lembretes.

## Politica De Dados

Persistencia principal em MongoDB, porque o modulo trabalha com IA, social, telemetria, eventos volumosos ou payload semi-estruturado.

`users.user_id` deve ser a primeira integracao relacional quando houver usuario, empresa, rider, admin ou system actor.

`wallets.wallet_id` e `transactions.transaction_id` devem ser usados quando houver dinheiro, saldo, pagamento, repasse, refund, fee, split ou escrow.

`user_id` em MongoDB deve ser string UUID validada por regex para manter ponte segura com PostgreSQL.

## Integracoes

Dependencias minimas: AI. Integracoes previstas: ADVISOR, CHAT.

## Atores Primarios

- usuario final
- helena persona
- operador de produtividade

## Capacidades-Chave

- agenda inteligente
- listas
- memoria operacional

## Entidades Relacionais

- Nao aplicavel.

## Payloads Volumosos E Colecoes

- `agenda_items`
- `ai_memory`

## Eventos Canonicos

- `agenda.item.created`
- `agenda.reminder.triggered`
- `agenda.memory.linked`

## Compliance, Risco E Guarda

- personal_data_retention
- consent_management
- assistant_audit

## Superficies Admin E Operacao

- painel de agenda
- fila de lembretes
- console de memoria

## Regras De Evolucao

1. Nao criar tabela duplicada de usuario; usar sempre `public.users`.
2. Nao criar schema legado paralelo; manter objetos novos em `public` enquanto esta worktree exigir core-first.
3. Usar `UUID` para chaves e referencias quando o dado for relacional.
4. Usar `DECIMAL(18,4)` para BRL e `DECIMAL(18,8)` para `$NEX`.
5. Usar `TIMESTAMPTZ` para eventos com tempo operacional.
6. Usar `append-only` quando o dado representar dinheiro, auditoria, certificado, receipt, regra versionada ou trilha legal.
7. Atualizar Manual Online e PDF em qualquer mudanca de schema, script ou contrato.

## Primeiro Backlog Tecnico

- fechar recorrencia canonica
- definir hierarquia de listas
- ligar memoria de contexto
