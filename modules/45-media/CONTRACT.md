# Contrato Operacional - 45. Valley Media

Este arquivo e gerado pela automacao `scripts/valley_module_automation.py`.

Ele define a fronteira inicial do modulo para guiar desenvolvimento, implantacao e evolucao sem quebrar o nucleo Valley.

## Identidade Do Modulo

- Codigo tecnico: `MEDIA`
- Dominio: `media_social_growth`
- Tier: `core`
- Data home: `postgres_mongo`
- Status atual: `Parcialmente implantado`
- Fase atual: `BUILD` (Build)

## Objetivo Simples

Painel de criadores, uploads, monetizacao e distribuicao de conteudo.

## Politica De Dados

Persistencia hibrida: PostgreSQL guarda o contrato operacional e MongoDB guarda payload volumoso, IA, social, telemetria ou eventos semi-estruturados.

`users.user_id` deve ser a primeira integracao relacional quando houver usuario, empresa, rider, admin ou system actor.

`wallets.wallet_id` e `transactions.transaction_id` devem ser usados quando houver dinheiro, saldo, pagamento, repasse, refund, fee, split ou escrow.

`user_id` em MongoDB deve ser string UUID validada por regex para manter ponte segura com PostgreSQL.

## Integracoes

Dependencias minimas: CREATOR. Integracoes previstas: SOCIAL, ADS.

## Atores Primarios

- criador
- operador de midia
- marca

## Capacidades-Chave

- upload de creator
- monetizacao
- distribuicao de conteudo

## Entidades Relacionais

- `creator_uploads`
- `transactions`

## Payloads Volumosos E Colecoes

- `social_videos`
- `news_content_items`

## Eventos Canonicos

- `media.upload.received`
- `media.asset.published`
- `media.revenue.booked`

## Compliance, Risco E Guarda

- copyright_traceability
- creator_payout_audit
- brand_safety

## Superficies Admin E Operacao

- studio de creator
- fila de publicacao
- monitor de receita

## Regras De Evolucao

1. Nao criar tabela duplicada de usuario; usar sempre `public.users`.
2. Nao criar schema legado paralelo; manter objetos novos em `public` enquanto esta worktree exigir core-first.
3. Usar `UUID` para chaves e referencias quando o dado for relacional.
4. Usar `DECIMAL(18,4)` para BRL e `DECIMAL(18,8)` para `$NEX`.
5. Usar `TIMESTAMPTZ` para eventos com tempo operacional.
6. Usar `append-only` quando o dado representar dinheiro, auditoria, certificado, receipt, regra versionada ou trilha legal.
7. Atualizar Manual Online e PDF em qualquer mudanca de schema, script ou contrato.

## Primeiro Backlog Tecnico

- fechar pipeline de media
- definir direitos por asset
- ligar receita por creator
