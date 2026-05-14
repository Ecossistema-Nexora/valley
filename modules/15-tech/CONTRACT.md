# Contrato Operacional - 15. Valley Tech

Este arquivo e gerado pela automacao `scripts/automacao_sincronizador_modulos.py`.

Ele define a fronteira inicial do modulo para guiar desenvolvimento, implantacao e evolucao sem quebrar o nucleo Valley.

## Identidade Do Modulo

- Codigo tecnico: `TECH`
- Dominio: `platform_developer`
- Tier: `foundation`
- Data home: `postgres`
- Status atual: `Parcialmente implantado`
- Fase atual: `VALIDATE` (Validacao)

## Objetivo Simples

Infra SaaS, API builder, integracoes e plataforma de desenvolvedor.

## Politica De Dados

Persistencia principal em PostgreSQL, porque o modulo exige consistencia, `foreign key`, auditoria, dinheiro, contrato ou documento.

`users.user_id` deve ser a primeira integracao relacional quando houver usuario, empresa, rider, admin ou system actor.

`wallets.wallet_id` e `transactions.transaction_id` devem ser usados quando houver dinheiro, saldo, pagamento, repasse, refund, fee, split ou escrow.

`user_id` em MongoDB deve ser string UUID validada por regex para manter ponte segura com PostgreSQL.

## Integracoes

Dependencias minimas: API, CLOUD. Integracoes previstas: CONNECT, COMMAND_CENTER.

## Atores Primarios

- developer
- integrador
- operador de plataforma

## Capacidades-Chave

- api clients
- credenciais seguras
- webhooks e conectores

## Entidades Relacionais

- `tech_api_clients`
- `tech_api_credentials`
- `tech_webhook_subscriptions`
- `tech_webhook_delivery_attempts`

## Payloads Volumosos E Colecoes

- Nao aplicavel.

## Eventos Canonicos

- `tech.client.provisioned`
- `tech.webhook.delivered`
- `tech.connector.synced`

## Compliance, Risco E Guarda

- secret_hashing
- api_audit
- integration_traceability

## Superficies Admin E Operacao

- painel de integracoes
- gestao de credenciais
- monitor de webhooks

## Regras De Evolucao

1. Nao criar tabela duplicada de usuario; usar sempre `public.users`.
2. Nao criar schema legado paralelo; manter objetos novos em `public` enquanto esta worktree exigir core-first.
3. Usar `UUID` para chaves e referencias quando o dado for relacional.
4. Usar `DECIMAL(18,4)` para BRL e `DECIMAL(18,8)` para `V-Coin`.
5. Usar `TIMESTAMPTZ` para eventos com tempo operacional.
6. Usar `append-only` quando o dado representar dinheiro, auditoria, certificado, receipt, regra versionada ou trilha legal.
7. Atualizar Manual Online e PDF em qualquer mudanca de schema, script ou contrato.

## Primeiro Backlog Tecnico

- fechar rotate de credenciais
- ligar replay seguro de webhook
- definir limites por client
