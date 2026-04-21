# 10. Valley Services

Este arquivo e gerado pela automacao `scripts/valley_module_automation.py`.

Ele descreve o modulo em linguagem simples e serve como ponto inicial para desenvolvimento, implantacao e evolucao continua.

## Identidade Tecnica

- Codigo tecnico: `SERVICES`
- Subtitulo: `Gigs & Pro Services`
- Dominio: `services_health_human`
- Tier: `core`
- Data home: `postgres`
- Status atual: `Parcialmente implantado`
- Fase atual: `VALIDATE` (Validacao)
- Cobertura mapeada: PostgreSQL: 4 entidades mapeadas.

## Finalidade

Servicos profissionais, gigs, contratacao e reputacao.

## Atores Primarios

- prestador
- cliente
- operador de marketplace

## Capacidades-Chave

- catalogo de servicos
- booking
- trilha de atendimento

## Dependencias

ID, PAY

## Integracoes

MARKETPLACE, LEGAL

## Mapa De Dados

### PostgreSQL

- `service_provider_profiles`
- `service_catalog_services`
- `service_bookings`
- `service_booking_events`

### MongoDB

- Nao aplicavel.

## Eventos Canonicos

- `services.provider.approved`
- `services.booking.confirmed`
- `services.booking.closed`

## Compliance E Operacao

- provider_verification
- service_auditability
- payment_split_audit

## Superficies Admin

- painel de prestadores
- agenda de bookings
- fila de reputacao

## Proxima Onda

- fechar score de prestador
- definir no-show policy
- ligar disputa operacional

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
