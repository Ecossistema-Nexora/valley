# Contrato Operacional - 17. Valley News & Podcast

Este arquivo e gerado pela automacao `scripts/automacao_sincronizador_modulos.py`.

Ele define a fronteira inicial do modulo para guiar desenvolvimento, implantacao e evolucao sem quebrar o nucleo Valley.

## Identidade Do Modulo

- Codigo tecnico: `NEWS_PODCAST`
- Dominio: `media_social_growth`
- Tier: `expansion`
- Data home: `mongo`
- Status atual: `Parcialmente implantado`
- Fase atual: `VALIDATE` (Validacao)

## Objetivo Simples

Noticias, podcasts e conteudo editorial.

## Politica De Dados

Persistencia principal em MongoDB, porque o modulo trabalha com IA, social, telemetria, eventos volumosos ou payload semi-estruturado.

`users.user_id` deve ser a primeira integracao relacional quando houver usuario, empresa, rider, admin ou system actor.

`wallets.wallet_id` e `transactions.transaction_id` devem ser usados quando houver dinheiro, saldo, pagamento, repasse, refund, fee, split ou escrow.

`user_id` em MongoDB deve ser string UUID validada por regex para manter ponte segura com PostgreSQL.

## Integracoes

Dependencias minimas: MEDIA. Integracoes previstas: CREATOR, ADS.

## Atores Primarios

- editor
- criador de audio
- consumidor

## Capacidades-Chave

- conteudo editorial
- episodios e blocos
- distribuicao midia

## Entidades Relacionais

- Nao aplicavel.

## Payloads Volumosos E Colecoes

- `news_content_items`

## Eventos Canonicos

- `news.story.published`
- `podcast.episode.released`
- `media.content.moderated`

## Compliance, Risco E Guarda

- editorial_governance
- copyright_traceability
- content_moderation

## Superficies Admin E Operacao

- cms editorial
- fila de revisao
- monitor de distribuicao

## Regras De Evolucao

1. Nao criar tabela duplicada de usuario; usar sempre `public.users`.
2. Nao criar schema legado paralelo; manter objetos novos em `public` enquanto esta worktree exigir core-first.
3. Usar `UUID` para chaves e referencias quando o dado for relacional.
4. Usar `DECIMAL(18,4)` para BRL e `DECIMAL(18,8)` para `V-Coin`.
5. Usar `TIMESTAMPTZ` para eventos com tempo operacional.
6. Usar `append-only` quando o dado representar dinheiro, auditoria, certificado, receipt, regra versionada ou trilha legal.
7. Atualizar Manual Online e PDF em qualquer mudanca de schema, script ou contrato.

## Primeiro Backlog Tecnico

- fechar taxonomia editorial
- ligar agenda de publicacao
- amarrar politica de moderacao
