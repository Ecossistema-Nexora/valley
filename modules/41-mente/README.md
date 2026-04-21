# 41. Valley Mente

Este arquivo e gerado pela automacao `scripts/valley_module_automation.py`.

Ele descreve o modulo em linguagem simples e serve como ponto inicial para desenvolvimento, implantacao e evolucao continua.

## Identidade Tecnica

- Codigo tecnico: `MENTE`
- Subtitulo: `Saude Mental Digital`
- Dominio: `services_health_human`
- Tier: `core`
- Data home: `postgres`
- Status atual: `Parcialmente implantado`
- Fase atual: `VALIDATE` (Validacao)
- Cobertura mapeada: PostgreSQL: 2 entidades mapeadas.

## Finalidade

Saude mental digital, teleterapia e notas cifradas.

## Atores Primarios

- paciente
- terapeuta
- operador de cuidado

## Capacidades-Chave

- teleterapia
- notas seguras
- sinais de acompanhamento

## Dependencias

HEALTH, ID

## Integracoes

ADVISOR, DOCS

## Mapa De Dados

### PostgreSQL

- `teletherapy_sessions`
- `health_profiles`

### MongoDB

- Nao aplicavel.

## Eventos Canonicos

- `mente.session.scheduled`
- `mente.session.completed`
- `mente.followup.created`

## Compliance E Operacao

- lgpd_sensitive_data
- therapy_confidentiality
- clinical_access_audit

## Superficies Admin

- painel terapeutico
- fila de sessoes
- monitor de follow-up

## Proxima Onda

- fechar trilha de nota cifrada
- definir protocolo de risco
- ligar agenda terapeutica

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
