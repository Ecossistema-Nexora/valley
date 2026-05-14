# Contrato Operacional - 44. Valley Up

Este arquivo e gerado pela automacao `scripts/automacao_sincronizador_modulos.py`.

Ele define a fronteira inicial do modulo para guiar desenvolvimento, implantacao e evolucao sem quebrar o nucleo Valley.

## Identidade Do Modulo

- Codigo tecnico: `UP`
- Dominio: `commerce_fintech_assets`
- Tier: `core`
- Data home: `postgres_mongo`
- Status atual: `Parcialmente implantado`
- Fase atual: `DATA_CONTRACT` (Contrato de dados)

## Objetivo Simples

Afiliados, indicacoes, comissoes e links de atribuicao.

## Politica De Dados

Persistencia hibrida: PostgreSQL guarda o contrato operacional e MongoDB guarda payload volumoso, IA, social, telemetria ou eventos semi-estruturados.

`users.user_id` deve ser a primeira integracao relacional quando houver usuario, empresa, rider, admin ou system actor.

`wallets.wallet_id` e `transactions.transaction_id` devem ser usados quando houver dinheiro, saldo, pagamento, repasse, refund, fee, split ou escrow.

`user_id` em MongoDB deve ser string UUID validada por regex para manter ponte segura com PostgreSQL.

## Integracoes

Dependencias minimas: PAY, MARKETPLACE. Integracoes previstas: INFLUENCERS, LOYALTY.

## Atores Primarios

- afiliado
- merchant
- operador de atribuicao

## Capacidades-Chave

- indicacao
- link de atribuicao
- comissao

## Entidades Relacionais

- `transactions`
- `pepita_ledger`

## Payloads Volumosos E Colecoes

- `influencer_metrics`
- `social_videos`

## Eventos Canonicos

- `up.link.generated`
- `up.conversion.attributed`
- `up.commission.booked`

## Compliance, Risco E Guarda

- attribution_audit
- commission_traceability
- anti_fraud

## Superficies Admin E Operacao

- painel de afiliados
- monitor de conversao
- fila de comissao

## Regras De Evolucao

1. Nao criar tabela duplicada de usuario; usar sempre `public.users`.
2. Nao criar schema legado paralelo; manter objetos novos em `public` enquanto esta worktree exigir core-first.
3. Usar `UUID` para chaves e referencias quando o dado for relacional.
4. Usar `DECIMAL(18,4)` para BRL e `DECIMAL(18,8)` para `V-Coin`.
5. Usar `TIMESTAMPTZ` para eventos com tempo operacional.
6. Usar `append-only` quando o dado representar dinheiro, auditoria, certificado, receipt, regra versionada ou trilha legal.
7. Atualizar Manual Online e PDF em qualquer mudanca de schema, script ou contrato.

## Primeiro Backlog Tecnico

- criar contrato especifico de atribuicao
- definir janela de comissao
- ligar fraude por auto-indicacao
