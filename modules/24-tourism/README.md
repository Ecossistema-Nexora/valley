# 24. Valley Tourism

Este arquivo e gerado pela automacao `scripts/automacao_sincronizador_modulos.py`.

Ele descreve o modulo em linguagem simples e serve como ponto inicial para desenvolvimento, implantacao e evolucao continua.

## Identidade Tecnica

- Codigo tecnico: `TOURISM`
- Subtitulo: `Local Explore`
- Dominio: `city_mobility_security`
- Tier: `expansion`
- Data home: `postgres_mongo`
- Status atual: `Parcialmente implantado`
- Fase atual: `VALIDATE` (Validacao)
- Cobertura mapeada: Hibrido: 3 entidades PostgreSQL e 2 colecoes MongoDB.

## Finalidade

Turismo local, experiencias, reservas e exploracao.

## Atores Primarios

- turista
- guia
- operador local

## Capacidades-Chave

- experiencias locais
- booking
- feed exploratorio

## Dependencias

PAY

## Integracoes

EVENTS, MOBILITY

## Mapa De Dados

### PostgreSQL

- `tourism_experiences`
- `tourism_bookings`
- `tourism_booking_events`

### MongoDB

- `tourism_experience_feeds`
- `space_anchor_maps`

## Eventos Canonicos

- `tourism.experience.published`
- `tourism.booking.confirmed`
- `tourism.checkin.recorded`

## Compliance E Operacao

- booking_audit
- guide_accountability
- settlement_traceability

## Superficies Admin

- painel de experiencias
- fila de bookings
- monitor de check-in

## Proxima Onda

- fechar politica de cancelamento
- definir no-show do guia
- ligar reputacao por experiencia

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
