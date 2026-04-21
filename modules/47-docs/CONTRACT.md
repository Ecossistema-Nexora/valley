# Contrato Operacional - 47. Valley Docs

Este arquivo e gerado pela automacao `scripts/valley_module_automation.py`.

Ele define a fronteira inicial do modulo para guiar desenvolvimento, implantacao e evolucao sem quebrar o nucleo Valley.

## Identidade Do Modulo

- Codigo tecnico: `DOCS`
- Dominio: `platform_developer`
- Tier: `foundation`
- Data home: `postgres`
- Status atual: `Parcialmente implantado`
- Fase atual: `DATA_CONTRACT` (Contrato de dados)

## Objetivo Simples

Geracao de documentos, recibos, checksums e registros imutaveis.

## Politica De Dados

Persistencia principal em PostgreSQL, porque o modulo exige consistencia, `foreign key`, auditoria, dinheiro, contrato ou documento.

`users.user_id` deve ser a primeira integracao relacional quando houver usuario, empresa, rider, admin ou system actor.

`wallets.wallet_id` e `transactions.transaction_id` devem ser usados quando houver dinheiro, saldo, pagamento, repasse, refund, fee, split ou escrow.

`user_id` em MongoDB deve ser string UUID validada por regex para manter ponte segura com PostgreSQL.

## Integracoes

Dependencias minimas: PAY, LEGAL. Integracoes previstas: ORDERS, TRANSACTIONS.

## Atores Primarios

- operador documental
- juridico
- motor de recibos

## Capacidades-Chave

- documentos
- recibos
- checksums e prova

## Entidades Relacionais

- `legal_contracts`
- `transactions`
- `orders`
- `event_ticket_ledger`

## Payloads Volumosos E Colecoes

- Nao aplicavel.

## Eventos Canonicos

- `docs.receipt.generated`
- `docs.document.signed`
- `docs.hash.registered`

## Compliance, Risco E Guarda

- document_immutability
- signature_traceability
- receipt_audit

## Superficies Admin E Operacao

- painel documental
- fila de emissao
- monitor de checksum

## Regras De Evolucao

1. Nao criar tabela duplicada de usuario; usar sempre `public.users`.
2. Nao criar schema legado paralelo; manter objetos novos em `public` enquanto esta worktree exigir core-first.
3. Usar `UUID` para chaves e referencias quando o dado for relacional.
4. Usar `DECIMAL(18,4)` para BRL e `DECIMAL(18,8)` para `$NEX`.
5. Usar `TIMESTAMPTZ` para eventos com tempo operacional.
6. Usar `append-only` quando o dado representar dinheiro, auditoria, certificado, receipt, regra versionada ou trilha legal.
7. Atualizar Manual Online e PDF em qualquer mudanca de schema, script ou contrato.

## Primeiro Backlog Tecnico

- criar contrato especifico de template
- definir trilha de checksum
- ligar versionamento de recibo
