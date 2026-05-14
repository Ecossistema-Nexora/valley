# 05. Valley Delivery

Este arquivo e gerado pela automacao `scripts/automacao_sincronizador_modulos.py`.

Ele descreve o modulo em linguagem simples e serve como ponto inicial para desenvolvimento, implantacao e evolucao continua.

## Identidade Tecnica

- Codigo tecnico: `DELIVERY`
- Subtitulo: `Urban Courier`
- Dominio: `logistics_erp_operations`
- Tier: `core`
- Data home: `postgres_mongo`
- Status atual: `Parcialmente implantado`
- Fase atual: `VALIDATE` (Validacao)
- Cobertura mapeada: Hibrido: 3 entidades PostgreSQL e 2 colecoes MongoDB.

## Finalidade

Entrega urbana, coleta local e operacao courier.

## Atores Primarios

- dispatcher
- courier
- loja emissora

## Capacidades-Chave

- coleta urbana
- roteamento operacional
- prova de entrega

## Dependencias

LOG, PAY

## Integracoes

FOOD, MARKETPLACE, MOBILITY

## Mapa De Dados

### PostgreSQL

- `delivery_shipments`
- `delivery_shipment_events`
- `orders`

### MongoDB

- `delivery_dispatch_runs`
- `telemetry_logs`

## Eventos Canonicos

- `delivery.shipment.created`
- `delivery.route.dispatched`
- `delivery.proof_recorded`

## Compliance E Operacao

- chain_of_custody
- proof_of_delivery
- driver_accountability

## Superficies Admin

- torre de despacho
- fila de ocorrencias
- painel de courier

## Proxima Onda

- fechar reatribuicao automatica
- definir KPI de janela prometida
- ligar prova de entrega por media

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
