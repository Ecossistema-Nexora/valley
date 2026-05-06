# Contrato Operacional - 39. Valley Advisor

Este arquivo e gerado pela automacao `scripts/valley_module_automation.py`.

Ele define a fronteira inicial do modulo para guiar desenvolvimento, implantacao e evolucao sem quebrar o nucleo Valley.

## Identidade Do Modulo

- Codigo tecnico: `ADVISOR`
- Dominio: `ai_memory_operations`
- Tier: `core`
- Data home: `postgres_mongo`
- Status atual: `Parcialmente implantado`
- Fase atual: `BUILD` (Build)

## Objetivo Simples

Consultoria de IA com recomendacoes e consentimento de execucao.

## Politica De Dados

Persistencia hibrida: PostgreSQL guarda o contrato operacional e MongoDB guarda payload volumoso, IA, social, telemetria ou eventos semi-estruturados.

`users.user_id` deve ser a primeira integracao relacional quando houver usuario, empresa, rider, admin ou system actor.

`wallets.wallet_id` e `transactions.transaction_id` devem ser usados quando houver dinheiro, saldo, pagamento, repasse, refund, fee, split ou escrow.

`user_id` em MongoDB deve ser string UUID validada por regex para manter ponte segura com PostgreSQL.

## Integracoes

Dependencias minimas: AI, PAY. Integracoes previstas: FINANCAS, HEALTH, MOBILITY.

## Atores Primarios

- usuario assistido
- motor de IA
- operador consultivo

## Capacidades-Chave

- insights
- recomendacao com consentimento
- orquestracao entre modulos

## Entidades Relacionais

- `advisor_insights`
- `financial_goals`

## Payloads Volumosos E Colecoes

- `ai_memory`
- `agenda_items`

## Eventos Canonicos

- `advisor.insight.generated`
- `advisor.action.proposed`
- `advisor.consent.recorded`

## Compliance, Risco E Guarda

- consent_management
- ai_auditability
- cross_module_traceability

## Superficies Admin E Operacao

- painel consultivo
- fila de aprovacoes
- monitor de recomendacoes

## Regras De Evolucao

1. Nao criar tabela duplicada de usuario; usar sempre `public.users`.
2. Nao criar schema legado paralelo; manter objetos novos em `public` enquanto esta worktree exigir core-first.
3. Usar `UUID` para chaves e referencias quando o dado for relacional.
4. Usar `DECIMAL(18,4)` para BRL e `DECIMAL(18,8)` para `V-Coin`.
5. Usar `TIMESTAMPTZ` para eventos com tempo operacional.
6. Usar `append-only` quando o dado representar dinheiro, auditoria, certificado, receipt, regra versionada ou trilha legal.
7. Atualizar Manual Online e PDF em qualquer mudanca de schema, script ou contrato.

## Primeiro Backlog Tecnico

- fechar registro de consentimento
- definir escopo de acao por modulo
- ligar explainability do insight
