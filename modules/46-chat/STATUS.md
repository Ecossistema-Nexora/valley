# Status - Valley Chat

- [x] Registry canonico criado.
- [x] Suporte base de schema ja implantado ou parcialmente implantado.
- [x] Contrato operacional inicial gerado.
- [x] Schema PostgreSQL especifico revisado.
- [x] Schema MongoDB especifico revisado.
- [x] Regras de negocio cadastradas ou descartadas.
- [x] Fluxos Admin/RBAC/ABAC definidos.
- [x] Testes de integracao planejados.
- [x] Manual Online atualizado.
- [x] PDF regenerado.

Evidencias da revisao:

- PostgreSQL: `database/postgres/005_v47_domain_tables_core_first.sql` cobre `chat_conversations` e `chat_messages`, com participantes ligados a `users.user_id`, `chat_persona_enum` para separar persona `PERSONAL` e `PROFESSIONAL`, e `check` que impede conversa consigo mesmo e mensagem vazia.
- MongoDB: `database/mongodb/001_ai_social_telemetry.mongo.js` cobre `ai_memory`, que fecha a parte contextual do modulo com `memory_scope`, `persona_mode`, `source_module`, `content_summary`, `consent_scope` e indices por `user_id` e expiracao.
- Persistencia hibrida revisada: o contrato operacional fica no PostgreSQL e a memoria contextual fica no MongoDB, sem duplicar o dump completo de conversa no banco documental e sem perder o vinculo seguro por `UUID`.
- Regras de negocio: nao existe, ate aqui, definicao exclusiva do modulo em `business_rule_definitions`. A decisao revisada e considerar isso descartado por enquanto, porque a governanca atual ja esta sustentada por `chat_persona_enum`, ACL do control plane e `consent_scope` em `ai_memory`; regras parametrizadas entram depois para retencao, bloqueio de contexto, handoff humano ou consentimento cross-module.
- Admin/RBAC/ABAC: o modulo herda `module_catalog`, `admin_permissions` e `admin_action_audit`, o que permite limitar suporte, moderacao e operacao assistida sem abrir controle paralelo dentro do schema de chat.
- Manual/PDF: `MANUAL_ONLINE/README.md`, `MANUAL_ONLINE/01_ARQUITETURA_TECNICA_MICROSSERVICOS_EVENTOS.md`, `MANUAL_ONLINE/02_MODELAGEM_BANCO_DADOS.md`, `MANUAL_ONLINE/03_FLUXO_COMPLETO_APIS.md`, `MANUAL_ONLINE/04_ROADMAP_IMPLEMENTACAO_SPRINTS.md` e `MANUAL_ONLINE/OPERACAO_AUTONOMA.md` cobrem o modulo. O PDF oficial foi regenerado apos os artefatos de dados usados nesta revisao.

Plano minimo de testes de integracao:

1. Criar `chat_conversation` com dois `user_id` distintos, validando `foreign key` para participantes e bloqueio do caso em que `participant1_id = participant2_id`.
2. Inserir `chat_message` em cada persona permitida, confirmando `chat_persona_enum`, integridade com a conversa e rejeicao de `content` vazio.
3. Inserir memoria em `ai_memory` com `memory_id`, `user_id`, `memory_scope`, `persona_mode`, `source_module`, `content_summary` e `consent_scope`, validando contrato minimo do contexto inteligente.
4. Inserir memoria temporaria com `expires_at` e consultar pelos indices de `user_id` e expiracao, confirmando que o modulo suporta memoria curta e longa sem perder rastreabilidade.
5. Executar fluxo conjunto conversa + memoria, registrando mensagens em Postgres e contexto em Mongo, para validar a fronteira hibrida antes de ligar follow-up por `ADVISOR` e `AGENDA`.

Observacao: este status deixou de ser apenas inicial e agora registra a primeira revisao tecnica do modulo.
