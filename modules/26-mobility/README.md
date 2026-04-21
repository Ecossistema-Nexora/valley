# 26. Valley Mobility

Este arquivo e gerado pela automacao `scripts/valley_module_automation.py`.

Ele descreve o modulo em linguagem simples e serve como ponto inicial para desenvolvimento, implantacao e evolucao continua.

## Identidade Tecnica

- Codigo tecnico: `MOBILITY`
- Subtitulo: `Urban Transport & Carpool`
- Dominio: `city_mobility_security`
- Tier: `core`
- Data home: `postgres_mongo`
- Status atual: `Parcialmente implantado`
- Fase atual: `VALIDATE` (Validacao)
- Cobertura mapeada: Hibrido: 3 entidades PostgreSQL e 2 colecoes MongoDB.

## Finalidade

Corridas urbanas, carpool, riders e taxa de plataforma.

## Atores Primarios

- passageiro
- rider
- dispatcher

## Capacidades-Chave

- corrida urbana
- checkpoint operacional
- precificacao de rota

## Dependencias

PAY, RIDER

## Integracoes

LOG, FLEET

## Mapa De Dados

### PostgreSQL

- `mobility_trips`
- `mobility_trip_events`
- `orders`

### MongoDB

- `fleet_vehicle_profiles`
- `telemetry_logs`

## Eventos Canonicos

- `mobility.trip.requested`
- `mobility.trip.started`
- `mobility.trip.completed`

## Compliance E Operacao

- ride_audit
- driver_accountability
- fare_traceability

## Superficies Admin

- torre de corridas
- monitor de checkpoints
- painel de rider

## Proxima Onda

- fechar calculo de tarifa
- definir score de seguranca da corrida
- ligar suporte em tempo real

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
