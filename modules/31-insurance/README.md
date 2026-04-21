# 31. Valley Insurance

Este arquivo e gerado pela automacao `scripts/valley_module_automation.py`.

Ele descreve o modulo em linguagem simples e serve como ponto inicial para desenvolvimento, implantacao e evolucao continua.

## Identidade Tecnica

- Codigo tecnico: `INSURANCE`
- Subtitulo: `On-Demand Protection`
- Dominio: `commerce_fintech_assets`
- Tier: `expansion`
- Data home: `postgres`
- Status atual: `Parcialmente implantado`
- Fase atual: `VALIDATE` (Validacao)
- Cobertura mapeada: PostgreSQL: 4 entidades mapeadas.

## Finalidade

Seguros sob demanda, protecao e analise de risco.

## Atores Primarios

- segurado
- underwriter
- analista de sinistro

## Capacidades-Chave

- produtos e apolices
- claims
- eventos de claim

## Dependencias

PAY, LEGAL

## Integracoes

SECURITY, DOCS

## Mapa De Dados

### PostgreSQL

- `insurance_products`
- `insurance_policies`
- `insurance_claims`
- `insurance_claim_events`

### MongoDB

- Nao aplicavel.

## Eventos Canonicos

- `insurance.policy.issued`
- `insurance.claim.opened`
- `insurance.claim.settled`

## Compliance E Operacao

- policy_audit
- claim_traceability
- risk_underwriting

## Superficies Admin

- painel de apolices
- fila de claim
- monitor de underwriting

## Proxima Onda

- fechar score de risco
- definir anti-fraude de claim
- ligar payout auditavel

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
