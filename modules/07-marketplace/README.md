# 07. Valley Marketplace

Este arquivo e gerado pela automacao `scripts/automacao_sincronizador_modulos.py`.

Ele descreve o modulo em linguagem simples e serve como ponto inicial para desenvolvimento, implantacao e evolucao continua.

## Identidade Tecnica

- Codigo tecnico: `MARKETPLACE`
- Subtitulo: `Local Commerce`
- Dominio: `commerce_fintech_assets`
- Tier: `foundation`
- Data home: `postgres`
- Status atual: `Parcialmente implantado`
- Fase atual: `VALIDATE` (Validacao)
- Cobertura mapeada: PostgreSQL: 3 entidades mapeadas.

## Finalidade

Comercio local centralizado, carrinho, produtos e recomendacoes.

## Atores Primarios

- seller
- comprador
- curador comercial

## Capacidades-Chave

- listagem local
- storefront por merchant
- validacao de venda

## Dependencias

PAY, ID

## Integracoes

STOCK, ADS, UP

## Mapa De Dados

### PostgreSQL

- `marketplace_listings`
- `merchant_storefronts`
- `sale_validation_events`

### MongoDB

- Nao aplicavel.

## Eventos Canonicos

- `marketplace.listing.published`
- `marketplace.cart.checked_out`
- `marketplace.sale.validated`

## Compliance E Operacao

- merchant_kyb
- pricing_audit
- listing_governance

## Superficies Admin

- painel de seller
- aprovacao de listing
- monitor de conversao

## Proxima Onda

- fechar politica de seller score
- definir moderacao de catalogo
- amarrar regras anti-fraude de checkout

## Trilha De Implantacao

1. Confirmar contrato de dados com `users.user_id` como no central.
2. Definir tabelas PostgreSQL quando houver dinheiro, identidade, contrato, documento ou transacao.
3. Definir colecoes MongoDB quando houver IA, social, telemetria, eventos volumosos ou conteudo semi-estruturado.
4. Registrar regras de negocio em `business_rule_definitions` quando houver pricing, comissao, risco, permissao ou compliance.
5. Atualizar este README, o Manual Online e a vertente PDF a cada mudanca.

## Criterios De Pronto

- Schema validado ou justificativa de descarte registrada.
- Integracoes com `PAY`, `ID`, `DOCS`, `ORDERS` ou `TRANSACTIONS` documentadas quando existirem.
- Teste ou validacao tecnica registrada.
- Comentarios em portugues simples com termos tecnicos em ingles onde fizer sentido.
- Blueprint operacional alinhado ao registry detalhado.
