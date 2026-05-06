# 46. Valley Chat

Este arquivo e gerado pela automacao `scripts/valley_module_automation.py`.

Ele descreve o modulo em linguagem simples e serve como ponto inicial para desenvolvimento, implantacao e evolucao continua.

## Identidade Tecnica

- Codigo tecnico: `CHAT`
- Subtitulo: `Mensageria com Contexto Helena Dual`
- Dominio: `ai_memory_operations`
- Tier: `core`
- Data home: `postgres_mongo`
- Status atual: `Parcialmente implantado`
- Fase atual: `VALIDATE` (Validacao)
- Cobertura mapeada: Hibrido: 2 entidades PostgreSQL e 2 colecoes MongoDB.

## Finalidade

Mensageria com contexto Helena pessoal/profissional e retencao segura.

## Atores Primarios

- usuario pessoal
- usuario profissional
- motor de assistencia

## Capacidades-Chave

- conversa Helena dual
- retencao segura
- ponte com agenda e advisor

## Dependencias

ID

## Integracoes

AGENDA, ADVISOR

## Mapa De Dados

### PostgreSQL

- `chat_conversations`
- `users`

### MongoDB

- `ai_memory`
- `agenda_items`

## Eventos Canonicos

- `chat.conversation.opened`
- `chat.message.persisted`
- `chat.context.promoted`

## Compliance E Operacao

- message_retention_policy
- helena_context_separation
- consent_audit

## Superficies Admin

- painel de conversas
- monitor de contexto
- fila de retencao

## Proxima Onda

- fechar politica de retention
- definir separacao pessoal x profissional
- ligar contexto com advisor

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
