# 29. Valley Legal

Este arquivo e gerado pela automacao `scripts/valley_module_automation.py`.

Ele descreve o modulo em linguagem simples e serve como ponto inicial para desenvolvimento, implantacao e evolucao continua.

## Identidade Tecnica

- Codigo tecnico: `LEGAL`
- Subtitulo: `Smart Contracts, Fallback PIN & AI Mediator`
- Dominio: `city_mobility_security`
- Tier: `foundation`
- Data home: `postgres`
- Status atual: `Parcialmente implantado`
- Fase atual: `VALIDATE` (Validacao)
- Cobertura mapeada: PostgreSQL: 6 entidades mapeadas.

## Finalidade

Contratos, mediacao por IA, fallback PIN e juridico.

## Atores Primarios

- juridico
- assinante
- mediador

## Capacidades-Chave

- contratos
- assinaturas
- disputas e trilha juridica

## Dependencias

ID

## Integracoes

DOCS, SECURITY

## Mapa De Dados

### PostgreSQL

- `legal_contracts`
- `legal_contract_parties`
- `legal_signatures`
- `legal_disputes`
- `legal_audit_events`
- `legal_fallback_pin_credentials`

### MongoDB

- Nao aplicavel.

## Eventos Canonicos

- `legal.contract.created`
- `legal.signature.recorded`
- `legal.dispute.opened`

## Compliance E Operacao

- legal_audit
- signature_traceability
- fallback_pin_hashing

## Superficies Admin

- painel juridico
- fila de assinaturas
- monitor de disputas

## Proxima Onda

- fechar clausulas parametrizadas
- definir mediacao assistida por IA
- ligar prova documental do contrato

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
