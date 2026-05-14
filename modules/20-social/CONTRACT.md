# Contrato Operacional - 20. Valley Social

Este arquivo e gerado pela automacao `scripts/automacao_sincronizador_modulos.py`.

Ele define a fronteira inicial do modulo para guiar desenvolvimento, implantacao e evolucao sem quebrar o nucleo Valley.

## Identidade Do Modulo

- Codigo tecnico: `SOCIAL`
- Dominio: `media_social_growth`
- Tier: `core`
- Data home: `mongo`
- Status atual: `Parcialmente implantado`
- Fase atual: `BUILD` (Build)

## Objetivo Simples

Rede social de bairro, reputacao, posts e moderacao.

## Politica De Dados

Persistencia principal em MongoDB, porque o modulo trabalha com IA, social, telemetria, eventos volumosos ou payload semi-estruturado.

`users.user_id` deve ser a primeira integracao relacional quando houver usuario, empresa, rider, admin ou system actor.

`wallets.wallet_id` e `transactions.transaction_id` devem ser usados quando houver dinheiro, saldo, pagamento, repasse, refund, fee, split ou escrow.

`user_id` em MongoDB deve ser string UUID validada por regex para manter ponte segura com PostgreSQL.

## Integracoes

Dependencias minimas: ID. Integracoes previstas: EVENTS, ADS, CREATOR.

## Atores Primarios

- morador
- moderador
- comerciante local

## Capacidades-Chave

- feed de bairro
- reputacao social
- moderacao contextual

## Entidades Relacionais

- Nao aplicavel.

## Payloads Volumosos E Colecoes

- `social_videos`
- `ai_memory`

## Eventos Canonicos

- `social.post.published`
- `social.report.opened`
- `social.reputation.updated`

## Compliance, Risco E Guarda

- content_moderation
- community_safety
- privacy_controls

## Superficies Admin E Operacao

- painel de moderacao
- fila de denuncias
- monitor de reputacao

## Regras De Evolucao

1. Nao criar tabela duplicada de usuario; usar sempre `public.users`.
2. Nao criar schema legado paralelo; manter objetos novos em `public` enquanto esta worktree exigir core-first.
3. Usar `UUID` para chaves e referencias quando o dado for relacional.
4. Usar `DECIMAL(18,4)` para BRL e `DECIMAL(18,8)` para `V-Coin`.
5. Usar `TIMESTAMPTZ` para eventos com tempo operacional.
6. Usar `append-only` quando o dado representar dinheiro, auditoria, certificado, receipt, regra versionada ou trilha legal.
7. Atualizar Manual Online e PDF em qualquer mudanca de schema, script ou contrato.

## Primeiro Backlog Tecnico

- fechar score de reputacao
- ligar anti-spam por bairro
- definir politica de retencao
