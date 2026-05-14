# Contrato Operacional - 14. Valley Edu

Este arquivo e gerado pela automacao `scripts/automacao_sincronizador_modulos.py`.

Ele define a fronteira inicial do modulo para guiar desenvolvimento, implantacao e evolucao sem quebrar o nucleo Valley.

## Identidade Do Modulo

- Codigo tecnico: `EDU`
- Dominio: `education_work_social`
- Tier: `expansion`
- Data home: `postgres`
- Status atual: `Parcialmente implantado`
- Fase atual: `VALIDATE` (Validacao)

## Objetivo Simples

Educacao, trilhas, cursos e recompensas por aprendizado.

## Politica De Dados

Persistencia principal em PostgreSQL, porque o modulo exige consistencia, `foreign key`, auditoria, dinheiro, contrato ou documento.

`users.user_id` deve ser a primeira integracao relacional quando houver usuario, empresa, rider, admin ou system actor.

`wallets.wallet_id` e `transactions.transaction_id` devem ser usados quando houver dinheiro, saldo, pagamento, repasse, refund, fee, split ou escrow.

`user_id` em MongoDB deve ser string UUID validada por regex para manter ponte segura com PostgreSQL.

## Integracoes

Dependencias minimas: ID. Integracoes previstas: LOYALTY, JOBS.

## Atores Primarios

- aluno
- instrutor
- operador academico

## Capacidades-Chave

- trilhas de aprendizado
- unidades educacionais
- enrollment e progresso

## Entidades Relacionais

- `edu_learning_paths`
- `edu_learning_units`
- `edu_enrollments`

## Payloads Volumosos E Colecoes

- Nao aplicavel.

## Eventos Canonicos

- `edu.path.published`
- `edu.enrollment.started`
- `edu.unit.completed`

## Compliance, Risco E Guarda

- certificate_traceability
- learning_reward_audit
- content_governance

## Superficies Admin E Operacao

- painel academico
- catalogo de trilhas
- monitor de progresso

## Regras De Evolucao

1. Nao criar tabela duplicada de usuario; usar sempre `public.users`.
2. Nao criar schema legado paralelo; manter objetos novos em `public` enquanto esta worktree exigir core-first.
3. Usar `UUID` para chaves e referencias quando o dado for relacional.
4. Usar `DECIMAL(18,4)` para BRL e `DECIMAL(18,8)` para `V-Coin`.
5. Usar `TIMESTAMPTZ` para eventos com tempo operacional.
6. Usar `append-only` quando o dado representar dinheiro, auditoria, certificado, receipt, regra versionada ou trilha legal.
7. Atualizar Manual Online e PDF em qualquer mudanca de schema, script ou contrato.

## Primeiro Backlog Tecnico

- fechar emissao de certificado
- ligar rewards por conclusao
- definir versionamento de conteudo
