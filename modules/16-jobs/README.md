# 16. Valley Jobs

Este arquivo e gerado pela automacao `scripts/automacao_sincronizador_modulos.py`.

Ele descreve o modulo em linguagem simples e serve como ponto inicial para desenvolvimento, implantacao e evolucao continua.

## Identidade Tecnica

- Codigo tecnico: `JOBS`
- Subtitulo: `AI Matchmaking`
- Dominio: `education_work_social`
- Tier: `core`
- Data home: `postgres_mongo`
- Status atual: `Parcialmente implantado`
- Fase atual: `VALIDATE` (Validacao)
- Cobertura mapeada: Hibrido: 3 entidades PostgreSQL e 1 colecoes MongoDB.

## Finalidade

Matching de trabalho, renda, vagas e freelas com IA.

## Atores Primarios

- candidato
- recrutador
- operador de matching

## Capacidades-Chave

- vagas
- aplicacoes
- engagement com IA

## Dependencias

ID, AI

## Integracoes

EDU, SERVICES

## Mapa De Dados

### PostgreSQL

- `job_postings`
- `job_applications`
- `job_engagements`

### MongoDB

- `ai_memory`

## Eventos Canonicos

- `jobs.posting.opened`
- `jobs.application.submitted`
- `jobs.match.scored`

## Compliance E Operacao

- candidate_privacy
- matching_auditability
- anti_bias_review

## Superficies Admin

- painel de vagas
- fila de matching
- monitor de funil

## Proxima Onda

- fechar score explicavel
- definir sinais de aderencia
- ligar consentimento para recomendacao

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
