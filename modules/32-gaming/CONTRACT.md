# Contrato Operacional - 32. Valley Gaming

Este arquivo e gerado pela automacao `scripts/valley_module_automation.py`.

Ele define a fronteira inicial do modulo para guiar desenvolvimento, implantacao e evolucao sem quebrar o nucleo Valley.

## Identidade Do Modulo

- Codigo tecnico: `GAMING`
- Dominio: `media_social_growth`
- Tier: `expansion`
- Data home: `mongo`
- Status atual: `Parcialmente implantado`
- Fase atual: `VALIDATE` (Validacao)

## Objetivo Simples

Jogos, recompensas, comunidades e gamificacao.

## Politica De Dados

Persistencia principal em MongoDB, porque o modulo trabalha com IA, social, telemetria, eventos volumosos ou payload semi-estruturado.

`users.user_id` deve ser a primeira integracao relacional quando houver usuario, empresa, rider, admin ou system actor.

`wallets.wallet_id` e `transactions.transaction_id` devem ser usados quando houver dinheiro, saldo, pagamento, repasse, refund, fee, split ou escrow.

`user_id` em MongoDB deve ser string UUID validada por regex para manter ponte segura com PostgreSQL.

## Integracoes

Dependencias minimas: LOYALTY. Integracoes previstas: SOCIAL, CREATOR.

## Atores Primarios

- player
- community manager
- operador de reward

## Capacidades-Chave

- estado do jogador
- gamificacao
- ponte com rewards

## Entidades Relacionais

- `points_ledger`

## Payloads Volumosos E Colecoes

- `gaming_player_states`
- `social_videos`

## Eventos Canonicos

- `gaming.player.progressed`
- `gaming.reward.unlocked`
- `gaming.quest.completed`

## Compliance, Risco E Guarda

- reward_audit
- age_safety
- community_moderation

## Superficies Admin E Operacao

- painel de quests
- monitor de rewards
- console de comunidade

## Regras De Evolucao

1. Nao criar tabela duplicada de usuario; usar sempre `public.users`.
2. Nao criar schema legado paralelo; manter objetos novos em `public` enquanto esta worktree exigir core-first.
3. Usar `UUID` para chaves e referencias quando o dado for relacional.
4. Usar `DECIMAL(18,4)` para BRL e `DECIMAL(18,8)` para `$NEX`.
5. Usar `TIMESTAMPTZ` para eventos com tempo operacional.
6. Usar `append-only` quando o dado representar dinheiro, auditoria, certificado, receipt, regra versionada ou trilha legal.
7. Atualizar Manual Online e PDF em qualquer mudanca de schema, script ou contrato.

## Primeiro Backlog Tecnico

- fechar regra de quest
- definir anti-abuso de reward
- ligar ranking por bairro
