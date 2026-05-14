# Contrato Operacional - 18. Valley Ads

Este arquivo e gerado pela automacao `scripts/automacao_sincronizador_modulos.py`.

Ele define a fronteira inicial do modulo para guiar desenvolvimento, implantacao e evolucao sem quebrar o nucleo Valley.

## Identidade Do Modulo

- Codigo tecnico: `ADS`
- Dominio: `media_social_growth`
- Tier: `core`
- Data home: `mongo`
- Status atual: `Parcialmente implantado`
- Fase atual: `VALIDATE` (Validacao)

## Objetivo Simples

Anuncios geolocalizados, campanhas, GOLD e midia.

## Politica De Dados

Persistencia principal em MongoDB, porque o modulo trabalha com IA, social, telemetria, eventos volumosos ou payload semi-estruturado.

`users.user_id` deve ser a primeira integracao relacional quando houver usuario, empresa, rider, admin ou system actor.

`wallets.wallet_id` e `transactions.transaction_id` devem ser usados quando houver dinheiro, saldo, pagamento, repasse, refund, fee, split ou escrow.

`user_id` em MongoDB deve ser string UUID validada por regex para manter ponte segura com PostgreSQL.

## Integracoes

Dependencias minimas: SOCIAL. Integracoes previstas: MARKETPLACE, ADS_INTELLIGENCE.

## Atores Primarios

- anunciante
- operador de growth
- merchant

## Capacidades-Chave

- campanhas geolocalizadas
- gold e pepitas
- atribuicao comercial

## Entidades Relacionais

- `gold_campaigns`
- `sale_validation_events`
- `pepita_accounts`

## Payloads Volumosos E Colecoes

- `social_videos`
- `influencer_metrics`

## Eventos Canonicos

- `ads.campaign.launched`
- `ads.impression.attributed`
- `ads.reward.booked`

## Compliance, Risco E Guarda

- ad_policy_traceability
- financial_attribution
- geo_targeting_consent

## Superficies Admin E Operacao

- painel de campanhas
- monitor de atribuicao
- console de crescimento

## Regras De Evolucao

1. Nao criar tabela duplicada de usuario; usar sempre `public.users`.
2. Nao criar schema legado paralelo; manter objetos novos em `public` enquanto esta worktree exigir core-first.
3. Usar `UUID` para chaves e referencias quando o dado for relacional.
4. Usar `DECIMAL(18,4)` para BRL e `DECIMAL(18,8)` para `V-Coin`.
5. Usar `TIMESTAMPTZ` para eventos com tempo operacional.
6. Usar `append-only` quando o dado representar dinheiro, auditoria, certificado, receipt, regra versionada ou trilha legal.
7. Atualizar Manual Online e PDF em qualquer mudanca de schema, script ou contrato.

## Primeiro Backlog Tecnico

- fechar janela de atribuicao
- definir cap de frequencia
- ligar score de criativo
