# Contrato Operacional - 07. Valley Marketplace

Este arquivo e gerado pela automacao `scripts/automacao_sincronizador_modulos.py`.

Ele define a fronteira inicial do modulo para guiar desenvolvimento, implantacao e evolucao sem quebrar o nucleo Valley.

## Identidade Do Modulo

- Codigo tecnico: `MARKETPLACE`
- Dominio: `commerce_fintech_assets`
- Tier: `foundation`
- Data home: `postgres`
- Status atual: `Parcialmente implantado`
- Fase atual: `VALIDATE` (Validacao)

## Objetivo Simples

Comercio local centralizado, carrinho, produtos e recomendacoes.

## Politica De Dados

Persistencia principal em PostgreSQL, porque o modulo exige consistencia, `foreign key`, auditoria, dinheiro, contrato ou documento.

`users.user_id` deve ser a primeira integracao relacional quando houver usuario, empresa, rider, admin ou system actor.

`wallets.wallet_id` e `transactions.transaction_id` devem ser usados quando houver dinheiro, saldo, pagamento, repasse, refund, fee, split ou escrow.

`user_id` em MongoDB deve ser string UUID validada por regex para manter ponte segura com PostgreSQL.

## Integracoes

Dependencias minimas: PAY, ID. Integracoes previstas: STOCK, ADS, UP.

## Atores Primarios

- seller
- comprador
- curador comercial

## Capacidades-Chave

- listagem local
- storefront por merchant
- validacao de venda

## Entidades Relacionais

- `marketplace_listings`
- `merchant_storefronts`
- `sale_validation_events`

## Payloads Volumosos E Colecoes

- Nao aplicavel.

## Eventos Canonicos

- `marketplace.listing.published`
- `marketplace.cart.checked_out`
- `marketplace.sale.validated`

## Compliance, Risco E Guarda

- merchant_kyb
- pricing_audit
- listing_governance

## Superficies Admin E Operacao

- painel de seller
- aprovacao de listing
- monitor de conversao

## Regras De Evolucao

1. Nao criar tabela duplicada de usuario; usar sempre `public.users`.
2. Nao criar schema legado paralelo; manter objetos novos em `public` enquanto esta worktree exigir core-first.
3. Usar `UUID` para chaves e referencias quando o dado for relacional.
4. Usar `DECIMAL(18,4)` para BRL e `DECIMAL(18,8)` para `V-Coin`.
5. Usar `TIMESTAMPTZ` para eventos com tempo operacional.
6. Usar `append-only` quando o dado representar dinheiro, auditoria, certificado, receipt, regra versionada ou trilha legal.
7. Atualizar Manual Online e PDF em qualquer mudanca de schema, script ou contrato.

## Primeiro Backlog Tecnico

- fechar politica de seller score
- definir moderacao de catalogo
- amarrar regras anti-fraude de checkout
