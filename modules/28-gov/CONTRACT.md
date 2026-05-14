# Contrato Operacional - 28. Valley Gov

Este arquivo e gerado pela automacao `scripts/automacao_sincronizador_modulos.py`.

Ele define a fronteira inicial do modulo para guiar desenvolvimento, implantacao e evolucao sem quebrar o nucleo Valley.

## Identidade Do Modulo

- Codigo tecnico: `GOV`
- Dominio: `city_mobility_security`
- Tier: `expansion`
- Data home: `postgres`
- Status atual: `Parcialmente implantado`
- Fase atual: `VALIDATE` (Validacao)

## Objetivo Simples

Portal cidadao, govtech e servicos publicos.

## Politica De Dados

Persistencia principal em PostgreSQL, porque o modulo exige consistencia, `foreign key`, auditoria, dinheiro, contrato ou documento.

`users.user_id` deve ser a primeira integracao relacional quando houver usuario, empresa, rider, admin ou system actor.

`wallets.wallet_id` e `transactions.transaction_id` devem ser usados quando houver dinheiro, saldo, pagamento, repasse, refund, fee, split ou escrow.

`user_id` em MongoDB deve ser string UUID validada por regex para manter ponte segura com PostgreSQL.

## Integracoes

Dependencias minimas: ID. Integracoes previstas: LEGAL, DOCS.

## Atores Primarios

- cidadao
- servidor
- operador govtech

## Capacidades-Chave

- catalogo de servicos
- requests publicos
- eventos de atendimento

## Entidades Relacionais

- `gov_service_catalog`
- `gov_service_requests`
- `gov_request_events`

## Payloads Volumosos E Colecoes

- Nao aplicavel.

## Eventos Canonicos

- `gov.service.requested`
- `gov.request.routed`
- `gov.request.resolved`

## Compliance, Risco E Guarda

- public_auditability
- citizen_identity
- service_traceability

## Superficies Admin E Operacao

- portal de requests
- fila de atendimento
- monitor de SLA publico

## Regras De Evolucao

1. Nao criar tabela duplicada de usuario; usar sempre `public.users`.
2. Nao criar schema legado paralelo; manter objetos novos em `public` enquanto esta worktree exigir core-first.
3. Usar `UUID` para chaves e referencias quando o dado for relacional.
4. Usar `DECIMAL(18,4)` para BRL e `DECIMAL(18,8)` para `V-Coin`.
5. Usar `TIMESTAMPTZ` para eventos com tempo operacional.
6. Usar `append-only` quando o dado representar dinheiro, auditoria, certificado, receipt, regra versionada ou trilha legal.
7. Atualizar Manual Online e PDF em qualquer mudanca de schema, script ou contrato.

## Primeiro Backlog Tecnico

- fechar taxonomia de servico publico
- definir SLA por categoria
- ligar trilha documental
