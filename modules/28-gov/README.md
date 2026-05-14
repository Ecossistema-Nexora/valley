# 28. Valley Gov

Este arquivo e gerado pela automacao `scripts/automacao_sincronizador_modulos.py`.

Ele descreve o modulo em linguagem simples e serve como ponto inicial para desenvolvimento, implantacao e evolucao continua.

## Identidade Tecnica

- Codigo tecnico: `GOV`
- Subtitulo: `Citizen Portal`
- Dominio: `city_mobility_security`
- Tier: `expansion`
- Data home: `postgres`
- Status atual: `Parcialmente implantado`
- Fase atual: `VALIDATE` (Validacao)
- Cobertura mapeada: PostgreSQL: 3 entidades mapeadas.

## Finalidade

Portal cidadao, govtech e servicos publicos.

## Atores Primarios

- cidadao
- servidor
- operador govtech

## Capacidades-Chave

- catalogo de servicos
- requests publicos
- eventos de atendimento

## Dependencias

ID

## Integracoes

LEGAL, DOCS

## Mapa De Dados

### PostgreSQL

- `gov_service_catalog`
- `gov_service_requests`
- `gov_request_events`

### MongoDB

- Nao aplicavel.

## Eventos Canonicos

- `gov.service.requested`
- `gov.request.routed`
- `gov.request.resolved`

## Compliance E Operacao

- public_auditability
- citizen_identity
- service_traceability

## Superficies Admin

- portal de requests
- fila de atendimento
- monitor de SLA publico

## Proxima Onda

- fechar taxonomia de servico publico
- definir SLA por categoria
- ligar trilha documental

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
