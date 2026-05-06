# Contrato Operacional - 19. Valley Influencers

Este arquivo e gerado pela automacao `scripts/valley_module_automation.py`.

Ele define a fronteira inicial do modulo para guiar desenvolvimento, implantacao e evolucao sem quebrar o nucleo Valley.

## Identidade Do Modulo

- Codigo tecnico: `INFLUENCERS`
- Dominio: `media_social_growth`
- Tier: `core`
- Data home: `mongo`
- Status atual: `Parcialmente implantado`
- Fase atual: `BUILD` (Build)

## Objetivo Simples

Hub de criadores, metricas, afiliacao e monetizacao.

## Politica De Dados

Persistencia principal em MongoDB, porque o modulo trabalha com IA, social, telemetria, eventos volumosos ou payload semi-estruturado.

`users.user_id` deve ser a primeira integracao relacional quando houver usuario, empresa, rider, admin ou system actor.

`wallets.wallet_id` e `transactions.transaction_id` devem ser usados quando houver dinheiro, saldo, pagamento, repasse, refund, fee, split ou escrow.

`user_id` em MongoDB deve ser string UUID validada por regex para manter ponte segura com PostgreSQL.

## Integracoes

Dependencias minimas: CREATOR, UP. Integracoes previstas: SOCIAL, ADS.

## Atores Primarios

- creator
- brand manager
- operador de afiliacao

## Capacidades-Chave

- hub de criadores
- metricas de audiencia
- monetizacao afiliada

## Entidades Relacionais

- `creator_uploads`

## Payloads Volumosos E Colecoes

- `influencer_metrics`
- `social_videos`

## Eventos Canonicos

- `influencer.profile.qualified`
- `influencer.metric.ingested`
- `influencer.commission.attributed`

## Compliance, Risco E Guarda

- creator_disclosure
- commission_audit
- brand_safety

## Superficies Admin E Operacao

- painel de creators
- fila de brand safety
- monitor de afiliacao

## Regras De Evolucao

1. Nao criar tabela duplicada de usuario; usar sempre `public.users`.
2. Nao criar schema legado paralelo; manter objetos novos em `public` enquanto esta worktree exigir core-first.
3. Usar `UUID` para chaves e referencias quando o dado for relacional.
4. Usar `DECIMAL(18,4)` para BRL e `DECIMAL(18,8)` para `V-Coin`.
5. Usar `TIMESTAMPTZ` para eventos com tempo operacional.
6. Usar `append-only` quando o dado representar dinheiro, auditoria, certificado, receipt, regra versionada ou trilha legal.
7. Atualizar Manual Online e PDF em qualquer mudanca de schema, script ou contrato.

## Primeiro Backlog Tecnico

- fechar score de creator fit
- definir politica de disclosure
- ligar payout por campanha
