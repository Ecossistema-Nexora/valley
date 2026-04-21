# Contrato Operacional - 21. Valley Fitness

Este arquivo e gerado pela automacao `scripts/valley_module_automation.py`.

Ele define a fronteira inicial do modulo para guiar desenvolvimento, implantacao e evolucao sem quebrar o nucleo Valley.

## Identidade Do Modulo

- Codigo tecnico: `FITNESS`
- Dominio: `services_health_human`
- Tier: `expansion`
- Data home: `mongo`
- Status atual: `Parcialmente implantado`
- Fase atual: `VALIDATE` (Validacao)

## Objetivo Simples

Fitness, recompensas por movimento e integracao com saude.

## Politica De Dados

Persistencia principal em MongoDB, porque o modulo trabalha com IA, social, telemetria, eventos volumosos ou payload semi-estruturado.

`users.user_id` deve ser a primeira integracao relacional quando houver usuario, empresa, rider, admin ou system actor.

`wallets.wallet_id` e `transactions.transaction_id` devem ser usados quando houver dinheiro, saldo, pagamento, repasse, refund, fee, split ou escrow.

`user_id` em MongoDB deve ser string UUID validada por regex para manter ponte segura com PostgreSQL.

## Integracoes

Dependencias minimas: HEALTH. Integracoes previstas: LOYALTY, WEARABLES.

## Atores Primarios

- usuario ativo
- coach
- operador wellness

## Capacidades-Chave

- sessao de atividade
- move-to-earn
- integracao com saude

## Entidades Relacionais

- `health_profiles`

## Payloads Volumosos E Colecoes

- `fitness_activity_sessions`

## Eventos Canonicos

- `fitness.session.logged`
- `fitness.goal.hit`
- `fitness.reward.qualified`

## Compliance, Risco E Guarda

- health_consent
- activity_reward_audit
- wearable_data_traceability

## Superficies Admin E Operacao

- painel wellness
- monitor de metas
- fila de recompensa

## Regras De Evolucao

1. Nao criar tabela duplicada de usuario; usar sempre `public.users`.
2. Nao criar schema legado paralelo; manter objetos novos em `public` enquanto esta worktree exigir core-first.
3. Usar `UUID` para chaves e referencias quando o dado for relacional.
4. Usar `DECIMAL(18,4)` para BRL e `DECIMAL(18,8)` para `$NEX`.
5. Usar `TIMESTAMPTZ` para eventos com tempo operacional.
6. Usar `append-only` quando o dado representar dinheiro, auditoria, certificado, receipt, regra versionada ou trilha legal.
7. Atualizar Manual Online e PDF em qualquer mudanca de schema, script ou contrato.

## Primeiro Backlog Tecnico

- fechar score de consistencia
- definir fraude de atividade
- ligar rewards por meta semanal
