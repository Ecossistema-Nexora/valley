# Contrato Operacional - 43. Valley Plug

Este arquivo e gerado pela automacao `scripts/automacao_sincronizador_modulos.py`.

Ele define a fronteira inicial do modulo para guiar desenvolvimento, implantacao e evolucao sem quebrar o nucleo Valley.

## Identidade Do Modulo

- Codigo tecnico: `PLUG`
- Dominio: `commerce_fintech_assets`
- Tier: `core`
- Data home: `postgres`
- Status atual: `Parcialmente implantado`
- Fase atual: `DATA_CONTRACT` (Contrato de dados)

## Objetivo Simples

Maquininha, Tap-to-Pay, MDR e antecipacao D+0.

## Politica De Dados

Persistencia principal em PostgreSQL, porque o modulo exige consistencia, `foreign key`, auditoria, dinheiro, contrato ou documento.

`users.user_id` deve ser a primeira integracao relacional quando houver usuario, empresa, rider, admin ou system actor.

`wallets.wallet_id` e `transactions.transaction_id` devem ser usados quando houver dinheiro, saldo, pagamento, repasse, refund, fee, split ou escrow.

`user_id` em MongoDB deve ser string UUID validada por regex para manter ponte segura com PostgreSQL.

## Integracoes

Dependencias minimas: PAY. Integracoes previstas: WALLETS, BUSINESS.

## Atores Primarios

- lojista
- operador de adquirencia
- comprador presencial

## Capacidades-Chave

- tap-to-pay
- maquininha
- antecipacao de recebivel

## Entidades Relacionais

- `transactions`
- `wallets`
- `merchant_storefronts`

## Payloads Volumosos E Colecoes

- Nao aplicavel.

## Eventos Canonicos

- `plug.device.activated`
- `plug.payment.authorized`
- `plug.advance.requested`

## Compliance, Risco E Guarda

- pci_boundary
- mdr_audit
- settlement_traceability

## Superficies Admin E Operacao

- painel de adquirencia
- monitor de terminais
- fila de antecipacao

## Regras De Evolucao

1. Nao criar tabela duplicada de usuario; usar sempre `public.users`.
2. Nao criar schema legado paralelo; manter objetos novos em `public` enquanto esta worktree exigir core-first.
3. Usar `UUID` para chaves e referencias quando o dado for relacional.
4. Usar `DECIMAL(18,4)` para BRL e `DECIMAL(18,8)` para `V-Coin`.
5. Usar `TIMESTAMPTZ` para eventos com tempo operacional.
6. Usar `append-only` quando o dado representar dinheiro, auditoria, certificado, receipt, regra versionada ou trilha legal.
7. Atualizar Manual Online e PDF em qualquer mudanca de schema, script ou contrato.

## Primeiro Backlog Tecnico

- criar contrato especifico de terminal
- definir MDR por faixa
- ligar fluxo D0 de antecipacao
