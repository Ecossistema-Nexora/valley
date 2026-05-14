# Contrato Operacional - 37. Valley Space

Este arquivo e gerado pela automacao `scripts/automacao_sincronizador_modulos.py`.

Ele define a fronteira inicial do modulo para guiar desenvolvimento, implantacao e evolucao sem quebrar o nucleo Valley.

## Identidade Do Modulo

- Codigo tecnico: `SPACE`
- Dominio: `frontier_iot_energy`
- Tier: `frontier`
- Data home: `mongo`
- Status atual: `Parcialmente implantado`
- Fase atual: `VALIDATE` (Validacao)

## Objetivo Simples

Realidade aumentada, ancoras espaciais e experiencias imersivas.

## Politica De Dados

Persistencia principal em MongoDB, porque o modulo trabalha com IA, social, telemetria, eventos volumosos ou payload semi-estruturado.

`users.user_id` deve ser a primeira integracao relacional quando houver usuario, empresa, rider, admin ou system actor.

`wallets.wallet_id` e `transactions.transaction_id` devem ser usados quando houver dinheiro, saldo, pagamento, repasse, refund, fee, split ou escrow.

`user_id` em MongoDB deve ser string UUID validada por regex para manter ponte segura com PostgreSQL.

## Integracoes

Dependencias minimas: CLOUD. Integracoes previstas: SOCIAL, TOURISM.

## Atores Primarios

- explorador
- criador AR
- operador de mapa

## Capacidades-Chave

- ancoras espaciais
- camadas AR
- experiencias geolocalizadas

## Entidades Relacionais

- Nao aplicavel.

## Payloads Volumosos E Colecoes

- `space_anchor_maps`
- `social_videos`

## Eventos Canonicos

- `space.anchor.created`
- `space.anchor.visited`
- `space.layer.published`

## Compliance, Risco E Guarda

- location_privacy
- content_safety
- creator_traceability

## Superficies Admin E Operacao

- painel AR
- monitor de ancoras
- fila de curadoria espacial

## Regras De Evolucao

1. Nao criar tabela duplicada de usuario; usar sempre `public.users`.
2. Nao criar schema legado paralelo; manter objetos novos em `public` enquanto esta worktree exigir core-first.
3. Usar `UUID` para chaves e referencias quando o dado for relacional.
4. Usar `DECIMAL(18,4)` para BRL e `DECIMAL(18,8)` para `V-Coin`.
5. Usar `TIMESTAMPTZ` para eventos com tempo operacional.
6. Usar `append-only` quando o dado representar dinheiro, auditoria, certificado, receipt, regra versionada ou trilha legal.
7. Atualizar Manual Online e PDF em qualquer mudanca de schema, script ou contrato.

## Primeiro Backlog Tecnico

- fechar taxonomia de ancora
- definir moderacao espacial
- ligar analytics de visita
