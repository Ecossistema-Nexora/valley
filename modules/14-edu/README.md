# 14. Valley Edu

Este arquivo e gerado pela automacao `scripts/valley_module_automation.py`.

Ele descreve o modulo em linguagem simples e serve como ponto inicial para desenvolvimento, implantacao e evolucao continua.

## Identidade Tecnica

- Codigo tecnico: `EDU`
- Subtitulo: `Learn-to-Earn`
- Dominio: `education_work_social`
- Tier: `expansion`
- Data home: `postgres`
- Status atual: `Parcialmente implantado`
- Fase atual: `VALIDATE` (Validacao)
- Cobertura mapeada: PostgreSQL: 3 entidades mapeadas.

## Finalidade

Educacao, trilhas, cursos e recompensas por aprendizado.

## Atores Primarios

- aluno
- instrutor
- operador academico

## Capacidades-Chave

- trilhas de aprendizado
- unidades educacionais
- enrollment e progresso

## Dependencias

ID

## Integracoes

LOYALTY, JOBS

## Mapa De Dados

### PostgreSQL

- `edu_learning_paths`
- `edu_learning_units`
- `edu_enrollments`

### MongoDB

- Nao aplicavel.

## Eventos Canonicos

- `edu.path.published`
- `edu.enrollment.started`
- `edu.unit.completed`

## Compliance E Operacao

- certificate_traceability
- learning_reward_audit
- content_governance

## Superficies Admin

- painel academico
- catalogo de trilhas
- monitor de progresso

## Proxima Onda

- fechar emissao de certificado
- ligar rewards por conclusao
- definir versionamento de conteudo

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
