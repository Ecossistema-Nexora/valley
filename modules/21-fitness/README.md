# 21. Valley Fitness

Este arquivo e gerado pela automacao `scripts/valley_module_automation.py`.

Ele descreve o modulo em linguagem simples e serve como ponto inicial para desenvolvimento, implantacao e evolucao continua.

## Identidade Tecnica

- Codigo tecnico: `FITNESS`
- Subtitulo: `Move-to-Earn`
- Dominio: `services_health_human`
- Tier: `expansion`
- Data home: `mongo`
- Status atual: `Parcialmente implantado`
- Fase atual: `VALIDATE` (Validacao)
- Cobertura mapeada: MongoDB: 1 colecoes principais e 1 entidades relacionais de apoio.

## Finalidade

Fitness, recompensas por movimento e integracao com saude.

## Atores Primarios

- usuario ativo
- coach
- operador wellness

## Capacidades-Chave

- sessao de atividade
- move-to-earn
- integracao com saude

## Dependencias

HEALTH

## Integracoes

LOYALTY, WEARABLES

## Mapa De Dados

### PostgreSQL

- `health_profiles`

### MongoDB

- `fitness_activity_sessions`

## Eventos Canonicos

- `fitness.session.logged`
- `fitness.goal.hit`
- `fitness.reward.qualified`

## Compliance E Operacao

- health_consent
- activity_reward_audit
- wearable_data_traceability

## Superficies Admin

- painel wellness
- monitor de metas
- fila de recompensa

## Proxima Onda

- fechar score de consistencia
- definir fraude de atividade
- ligar rewards por meta semanal

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
