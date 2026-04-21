# 04. Valley Food

Este arquivo e gerado pela automacao `scripts/valley_module_automation.py`.

Ele descreve o modulo em linguagem simples e serve como ponto inicial para desenvolvimento, implantacao e evolucao continua.

## Identidade Tecnica

- Codigo tecnico: `FOOD`
- Subtitulo: `Health-Centric Delivery`
- Dominio: `logistics_erp_operations`
- Tier: `core`
- Data home: `postgres`
- Status atual: `Parcialmente implantado`
- Fase atual: `DATA_CONTRACT` (Contrato de dados)
- Cobertura mapeada: PostgreSQL: 3 entidades mapeadas.

## Finalidade

Delivery alimentar com split Pay, informacoes nutricionais e taxa operacional.

## Atores Primarios

- restaurante
- consumidor
- operador de atendimento

## Capacidades-Chave

- pedido alimentar
- split operacional
- restricoes nutricionais

## Dependencias

PAY, LOG, HEALTH

## Integracoes

ORDERS, MOBILITY, DOCS

## Mapa De Dados

### PostgreSQL

- `orders`
- `transactions`
- `health_profiles`

### MongoDB

- Nao aplicavel.

## Eventos Canonicos

- `food.order.placed`
- `food.order.prepared`
- `food.order.delivered`

## Compliance E Operacao

- food_safety_traceability
- payment_split_audit
- allergen_notice

## Superficies Admin

- painel de pedidos
- gestao de cardapio
- monitor de cozinha

## Proxima Onda

- criar contrato especifico de cardapio e loja
- definir SLA de preparo
- amarrar taxonomia nutricional

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
