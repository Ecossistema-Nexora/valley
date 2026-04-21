# 19. Valley Influencers

Este arquivo e gerado pela automacao `scripts/valley_module_automation.py`.

Ele descreve o modulo em linguagem simples e serve como ponto inicial para desenvolvimento, implantacao e evolucao continua.

## Identidade Tecnica

- Codigo tecnico: `INFLUENCERS`
- Subtitulo: `Creators Hub`
- Dominio: `media_social_growth`
- Tier: `core`
- Data home: `mongo`
- Status atual: `Parcialmente implantado`
- Fase atual: `BUILD` (Build)
- Cobertura mapeada: MongoDB: 2 colecoes principais e 1 entidades relacionais de apoio.

## Finalidade

Hub de criadores, metricas, afiliacao e monetizacao.

## Atores Primarios

- creator
- brand manager
- operador de afiliacao

## Capacidades-Chave

- hub de criadores
- metricas de audiencia
- monetizacao afiliada

## Dependencias

CREATOR, UP

## Integracoes

SOCIAL, ADS

## Mapa De Dados

### PostgreSQL

- `creator_uploads`

### MongoDB

- `influencer_metrics`
- `social_videos`

## Eventos Canonicos

- `influencer.profile.qualified`
- `influencer.metric.ingested`
- `influencer.commission.attributed`

## Compliance E Operacao

- creator_disclosure
- commission_audit
- brand_safety

## Superficies Admin

- painel de creators
- fila de brand safety
- monitor de afiliacao

## Proxima Onda

- fechar score de creator fit
- definir politica de disclosure
- ligar payout por campanha

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
