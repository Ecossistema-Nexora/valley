# 22. Valley Pharmacy

Este arquivo e gerado pela automacao `scripts/automacao_sincronizador_modulos.py`.

Ele descreve o modulo em linguagem simples e serve como ponto inicial para desenvolvimento, implantacao e evolucao continua.

## Identidade Tecnica

- Codigo tecnico: `PHARMACY`
- Subtitulo: `Smart Meds`
- Dominio: `services_health_human`
- Tier: `core`
- Data home: `postgres`
- Status atual: `Parcialmente implantado`
- Fase atual: `VALIDATE` (Validacao)
- Cobertura mapeada: PostgreSQL: 4 entidades mapeadas.

## Finalidade

Medicamentos, farmacia, receitas e entrega.

## Atores Primarios

- farmaceutico
- paciente
- operador de fulfilment

## Capacidades-Chave

- catalogo farmaceutico
- fulfillment
- dispensacao auditavel

## Dependencias

HEALTH, PAY

## Integracoes

DELIVERY, DOCS

## Mapa De Dados

### PostgreSQL

- `pharmacy_catalog_items`
- `pharmacy_fulfillments`
- `pharmacy_fulfillment_items`
- `pharmacy_dispense_events`

### MongoDB

- Nao aplicavel.

## Eventos Canonicos

- `pharmacy.order.received`
- `pharmacy.item.dispensed`
- `pharmacy.delivery.released`

## Compliance E Operacao

- prescription_compliance
- dispense_audit
- controlled_medication_traceability

## Superficies Admin

- painel farmaceutico
- fila de prescricao
- monitor de dispensacao

## Proxima Onda

- fechar checagem de receita
- definir corte por medicamento controlado
- ligar SLA de separacao

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
