# 09. Valley Fleet

Este arquivo e gerado pela automacao `scripts/valley_module_automation.py`.

Ele descreve o modulo em linguagem simples e serve como ponto inicial para desenvolvimento, implantacao e evolucao continua.

## Identidade Tecnica

- Codigo tecnico: `FLEET`
- Subtitulo: `Telemetry & Fleet Management`
- Dominio: `logistics_erp_operations`
- Tier: `core`
- Data home: `mongo`
- Status atual: `Parcialmente implantado`
- Fase atual: `VALIDATE` (Validacao)
- Cobertura mapeada: MongoDB: 3 colecoes principais e 1 entidades relacionais de apoio.

## Finalidade

Gestao de frotas, telemetria, manutencao preventiva e rotas.

## Atores Primarios

- gestor de frota
- motorista
- tecnico de manutencao

## Capacidades-Chave

- perfil de veiculo
- telemetria de uso
- manutencao preventiva

## Dependencias

IOT, MOBILITY

## Integracoes

LOG, SECURITY

## Mapa De Dados

### PostgreSQL

- `mobility_trips`

### MongoDB

- `fleet_vehicle_profiles`
- `fleet_maintenance_events`
- `telemetry_logs`

## Eventos Canonicos

- `fleet.vehicle.registered`
- `fleet.maintenance.logged`
- `fleet.telemetry.alerted`

## Compliance E Operacao

- driver_accountability
- maintenance_traceability
- vehicle_compliance

## Superficies Admin

- painel de frota
- calendario de manutencao
- monitor de telemetria

## Proxima Onda

- fechar score de saude do veiculo
- definir corte por manutencao critica
- ligar custo por km

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
