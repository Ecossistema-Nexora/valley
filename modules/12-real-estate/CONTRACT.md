# Contrato Operacional - 12. Valley Real Estate

Este arquivo e gerado pela automacao `scripts/valley_module_automation.py`.

Ele define a fronteira inicial do modulo para guiar desenvolvimento, implantacao e evolucao sem quebrar o nucleo Valley.

## Identidade Do Modulo

- Codigo tecnico: `REAL_ESTATE`
- Dominio: `commerce_fintech_assets`
- Tier: `expansion`
- Data home: `postgres`
- Status atual: `Parcialmente implantado`
- Fase atual: `VALIDATE` (Validacao)

## Objetivo Simples

Imoveis, contratos, tokenizacao e registro de transacoes.

## Politica De Dados

Persistencia principal em PostgreSQL, porque o modulo exige consistencia, `foreign key`, auditoria, dinheiro, contrato ou documento.

`users.user_id` deve ser a primeira integracao relacional quando houver usuario, empresa, rider, admin ou system actor.

`wallets.wallet_id` e `transactions.transaction_id` devem ser usados quando houver dinheiro, saldo, pagamento, repasse, refund, fee, split ou escrow.

`user_id` em MongoDB deve ser string UUID validada por regex para manter ponte segura com PostgreSQL.

## Integracoes

Dependencias minimas: PAY, LEGAL. Integracoes previstas: DIGITAL, DOCS.

## Atores Primarios

- corretor
- investidor
- operador juridico

## Capacidades-Chave

- cadastro de imovel
- listagem e proposta
- deal tokenizado

## Entidades Relacionais

- `real_estate_properties`
- `real_estate_listings`
- `real_estate_deals`

## Payloads Volumosos E Colecoes

- Nao aplicavel.

## Eventos Canonicos

- `real_estate.property.registered`
- `real_estate.listing.published`
- `real_estate.deal.executed`

## Compliance, Risco E Guarda

- property_traceability
- contract_audit
- investor_suitability

## Superficies Admin E Operacao

- painel de propriedades
- fila de due diligence
- monitor de deals

## Regras De Evolucao

1. Nao criar tabela duplicada de usuario; usar sempre `public.users`.
2. Nao criar schema legado paralelo; manter objetos novos em `public` enquanto esta worktree exigir core-first.
3. Usar `UUID` para chaves e referencias quando o dado for relacional.
4. Usar `DECIMAL(18,4)` para BRL e `DECIMAL(18,8)` para `V-Coin`.
5. Usar `TIMESTAMPTZ` para eventos com tempo operacional.
6. Usar `append-only` quando o dado representar dinheiro, auditoria, certificado, receipt, regra versionada ou trilha legal.
7. Atualizar Manual Online e PDF em qualquer mudanca de schema, script ou contrato.

## Primeiro Backlog Tecnico

- fechar onboarding documental
- definir escrow de proposta
- amarrar tokenizacao por fracao
