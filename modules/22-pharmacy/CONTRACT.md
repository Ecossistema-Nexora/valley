# Contrato Operacional - 22. Valley Pharmacy

Este arquivo e gerado pela automacao `scripts/valley_module_automation.py`.

Ele define a fronteira inicial do modulo para guiar desenvolvimento, implantacao e evolucao sem quebrar o nucleo Valley.

## Identidade Do Modulo

- Codigo tecnico: `PHARMACY`
- Dominio: `services_health_human`
- Tier: `core`
- Data home: `postgres`
- Status atual: `Parcialmente implantado`
- Fase atual: `VALIDATE` (Validacao)

## Objetivo Simples

Medicamentos, farmacia, receitas e entrega.

## Politica De Dados

Persistencia principal em PostgreSQL, porque o modulo exige consistencia, `foreign key`, auditoria, dinheiro, contrato ou documento.

`users.user_id` deve ser a primeira integracao relacional quando houver usuario, empresa, rider, admin ou system actor.

`wallets.wallet_id` e `transactions.transaction_id` devem ser usados quando houver dinheiro, saldo, pagamento, repasse, refund, fee, split ou escrow.

`user_id` em MongoDB deve ser string UUID validada por regex para manter ponte segura com PostgreSQL.

## Integracoes

Dependencias minimas: HEALTH, PAY. Integracoes previstas: DELIVERY, DOCS.

## Atores Primarios

- farmaceutico
- paciente
- operador de fulfilment

## Capacidades-Chave

- catalogo farmaceutico
- fulfillment
- dispensacao auditavel

## Entidades Relacionais

- `pharmacy_catalog_items`
- `pharmacy_fulfillments`
- `pharmacy_fulfillment_items`
- `pharmacy_dispense_events`

## Payloads Volumosos E Colecoes

- Nao aplicavel.

## Eventos Canonicos

- `pharmacy.order.received`
- `pharmacy.item.dispensed`
- `pharmacy.delivery.released`

## Compliance, Risco E Guarda

- prescription_compliance
- dispense_audit
- controlled_medication_traceability

## Superficies Admin E Operacao

- painel farmaceutico
- fila de prescricao
- monitor de dispensacao

## Regras De Evolucao

1. Nao criar tabela duplicada de usuario; usar sempre `public.users`.
2. Nao criar schema legado paralelo; manter objetos novos em `public` enquanto esta worktree exigir core-first.
3. Usar `UUID` para chaves e referencias quando o dado for relacional.
4. Usar `DECIMAL(18,4)` para BRL e `DECIMAL(18,8)` para `$NEX`.
5. Usar `TIMESTAMPTZ` para eventos com tempo operacional.
6. Usar `append-only` quando o dado representar dinheiro, auditoria, certificado, receipt, regra versionada ou trilha legal.
7. Atualizar Manual Online e PDF em qualquer mudanca de schema, script ou contrato.

## Primeiro Backlog Tecnico

- fechar checagem de receita
- definir corte por medicamento controlado
- ligar SLA de separacao
