# 39. Valley Advisor

Este arquivo e gerado pela automacao `scripts/valley_module_automation.py`.

Ele descreve o modulo em linguagem simples e serve como ponto inicial para desenvolvimento, implantacao e evolucao continua.

## Identidade Tecnica

- Codigo tecnico: `ADVISOR`
- Subtitulo: `Omni-Consultoria de IA`
- Dominio: `ai_memory_operations`
- Tier: `core`
- Data home: `postgres_mongo`
- Status atual: `Parcialmente implantado`
- Fase atual: `BUILD` (Build)
- Cobertura mapeada: Hibrido: 2 entidades PostgreSQL e 2 colecoes MongoDB.

## Finalidade

Consultoria de IA com recomendacoes e consentimento de execucao.

## Atores Primarios

- usuario assistido
- motor de IA
- operador consultivo

## Capacidades-Chave

- insights
- recomendacao com consentimento
- orquestracao entre modulos

## Dependencias

AI, PAY

## Integracoes

FINANCAS, HEALTH, MOBILITY

## Mapa De Dados

### PostgreSQL

- `advisor_insights`
- `financial_goals`

### MongoDB

- `ai_memory`
- `agenda_items`

## Eventos Canonicos

- `advisor.insight.generated`
- `advisor.action.proposed`
- `advisor.consent.recorded`

## Compliance E Operacao

- consent_management
- ai_auditability
- cross_module_traceability

## Superficies Admin

- painel consultivo
- fila de aprovacoes
- monitor de recomendacoes

## Proxima Onda

- fechar registro de consentimento
- definir escopo de acao por modulo
- ligar explainability do insight

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
