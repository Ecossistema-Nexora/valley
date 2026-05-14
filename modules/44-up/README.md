# 44. Valley Up

Este arquivo e gerado pela automacao `scripts/automacao_sincronizador_modulos.py`.

Ele descreve o modulo em linguagem simples e serve como ponto inicial para desenvolvimento, implantacao e evolucao continua.

## Identidade Tecnica

- Codigo tecnico: `UP`
- Subtitulo: `Motor de Afiliados CAC Zero`
- Dominio: `commerce_fintech_assets`
- Tier: `core`
- Data home: `postgres_mongo`
- Status atual: `Parcialmente implantado`
- Fase atual: `DATA_CONTRACT` (Contrato de dados)
- Cobertura mapeada: Hibrido: 2 entidades PostgreSQL e 2 colecoes MongoDB.

## Finalidade

Afiliados, indicacoes, comissoes e links de atribuicao.

## Atores Primarios

- afiliado
- merchant
- operador de atribuicao

## Capacidades-Chave

- indicacao
- link de atribuicao
- comissao

## Dependencias

PAY, MARKETPLACE

## Integracoes

INFLUENCERS, LOYALTY

## Mapa De Dados

### PostgreSQL

- `transactions`
- `pepita_ledger`

### MongoDB

- `influencer_metrics`
- `social_videos`

## Eventos Canonicos

- `up.link.generated`
- `up.conversion.attributed`
- `up.commission.booked`

## Compliance E Operacao

- attribution_audit
- commission_traceability
- anti_fraud

## Superficies Admin

- painel de afiliados
- monitor de conversao
- fila de comissao

## Proxima Onda

- criar contrato especifico de atribuicao
- definir janela de comissao
- ligar fraude por auto-indicacao

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
