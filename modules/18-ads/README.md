# 18. Valley Ads

Este arquivo e gerado pela automacao `scripts/valley_module_automation.py`.

Ele descreve o modulo em linguagem simples e serve como ponto inicial para desenvolvimento, implantacao e evolucao continua.

## Identidade Tecnica

- Codigo tecnico: `ADS`
- Subtitulo: `Geofenced Marketing`
- Dominio: `media_social_growth`
- Tier: `core`
- Data home: `mongo`
- Status atual: `Parcialmente implantado`
- Fase atual: `VALIDATE` (Validacao)
- Cobertura mapeada: MongoDB: 2 colecoes principais e 3 entidades relacionais de apoio.

## Finalidade

Anuncios geolocalizados, campanhas, GOLD e midia.

## Atores Primarios

- anunciante
- operador de growth
- merchant

## Capacidades-Chave

- campanhas geolocalizadas
- gold e pepitas
- atribuicao comercial

## Dependencias

SOCIAL

## Integracoes

MARKETPLACE, ADS_INTELLIGENCE

## Mapa De Dados

### PostgreSQL

- `gold_campaigns`
- `sale_validation_events`
- `pepita_accounts`

### MongoDB

- `social_videos`
- `influencer_metrics`

## Eventos Canonicos

- `ads.campaign.launched`
- `ads.impression.attributed`
- `ads.reward.booked`

## Compliance E Operacao

- ad_policy_traceability
- financial_attribution
- geo_targeting_consent

## Superficies Admin

- painel de campanhas
- monitor de atribuicao
- console de crescimento

## Proxima Onda

- fechar janela de atribuicao
- definir cap de frequencia
- ligar score de criativo

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
