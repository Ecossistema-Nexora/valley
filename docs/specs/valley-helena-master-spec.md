# Valley Helena Master Spec

## 1. Proposito

Esta especificacao define a frente institucional `valley-helena-master-spec` como camada mestra para os modulos `AGENDA`, `ADVISOR` e `CHAT` dentro do dominio `ai_memory_operations`.

O objetivo nao e redesenhar o que ja existe no repositorio, e sim:

- consolidar o baseline tecnico real ja implantado;
- fechar criterios de governanca para memoria, agenda, chat e consultoria assistida;
- reduzir ambiguidade para as proximas migrations e contratos fisicos;
- proteger a fronteira entre o contexto Helena pessoal, o contexto Helena profissional e uso cross-module da Helena.

## 2. Baseline Observado No Repo

Artefatos considerados como fonte primaria desta especificacao:

- `database/postgres/005_v47_domain_tables_core_first.sql`
- `database/mongodb/001_ai_social_telemetry.mongo.js`
- `database/mongodb/003_v47_field_ops_security_agenda.mongo.js`
- `database/postgres/015_v47_module_blueprints_registry.sql`
- `database/postgres/016_v47_execution_backlog_seed.sql`
- `database/domain-delivery/priority-domains/ai_memory_operations/operational_seed.sql`
- `contracts/events/priority-domains/ai_memory_operations.json`
- `modules/38-agenda/CONTRACT.md`
- `modules/39-advisor/CONTRACT.md`
- `modules/46-chat/CONTRACT.md`

Estado atual observado:

- `AGENDA` esta em fase `VALIDATE`, com data home principal em MongoDB.
- `ADVISOR` esta em fase `BUILD`, com persistencia hibrida PostgreSQL + MongoDB.
- `CHAT` esta em fase `VALIDATE`, com persistencia hibrida PostgreSQL + MongoDB.
- `advisor_insights`, `financial_goals`, `chat_conversations` e `chat_messages` ja existem em PostgreSQL.
- `ai_memory` e `agenda_items` ja existem em MongoDB com validator e indices.
- O backlog seedado ja explicita as lacunas centrais: consentimento do Advisor, explainability do insight, retention do Chat, recorrencia e hierarquia da Agenda, e ligacao de memoria de contexto.

## 3. Objetivos Da Frente Helena

### 3.1 Objetivos principais

1. Fazer da Helena a camada de coordenacao pessoal/profissional do Valley, sem violar a separacao de contexto Helena.
2. Tornar `ai_memory` uma memoria operacional util, auditavel e governada, nao um deposito difuso de texto.
3. Fazer da `agenda_items` a fila canonica de acao, follow-up, lembrete e rotina inteligente.
4. Fazer do `ADVISOR` um motor de recomendacao com explainability minima obrigatoria e consentimento rastreavel.
5. Fazer do `CHAT` a principal superficie de captura de contexto, com promocao controlada para memoria e agenda.

### 3.2 Nao objetivos desta frente

- Nao criar agora novos schemas fisicos fora do escopo documental.
- Nao substituir os contratos modulares ja existentes.
- Nao abrir um novo dominio paralelo fora de `ai_memory_operations`.
- Nao misturar memoria de IA com ledger financeiro, trilha juridica ou dados clinicos brutos.

## 4. Atores Canonicos

### 4.1 Atores de produto

- `usuario final`: pessoa fisica usando Helena para agenda, memoria e assistencia pessoal.
- `usuario profissional`: mesma identidade raiz, operando contexto de trabalho, negocio ou atendimento.
- `usuario assistido`: usuario recebendo recomendacoes do Advisor.
- `Helena`: agente de assistencia que captura, resume e organiza contexto.

### 4.2 Atores operacionais

- `motor de IA`: runtime que gera insight, resume conversa, liga memoria e sugere acoes.
- `operador de produtividade`: suporte humano que revisa agenda, listas e rotinas.
- `operador consultivo`: humano que supervisiona recomendacoes do Advisor e fluxos de aprovacao.
- `compliance/admin`: acesso excepcional para auditoria, suporte regulatorio e investigacao.

### 4.3 No central obrigatorio

Toda trilha Helena e ancorada em `public.users.user_id`.

Nenhuma memoria, agenda, insight, conversa, evento promovido ou fluxo admin deve existir sem `user_id` canonico ou relacao derivada inequivoca com esse no central.

## 5. Entidades Canonicas

### 5.1 Entidades fisicas ja existentes

| Camada | Entidade | Papel canonico |
| --- | --- | --- |
| PostgreSQL | `advisor_insights` | Registro operacional do insight e do status de execucao/consentimento |
| PostgreSQL | `financial_goals` | Contexto financeiro estruturado usado por `ADVISOR` e `FINANCAS` |
| PostgreSQL | `chat_conversations` | Envelope relacional da conversa entre dois usuarios |
| PostgreSQL | `chat_messages` | Mensagens persistidas com contexto Helena `PERSONAL` ou `PROFESSIONAL` |
| MongoDB | `ai_memory` | Memoria operacional, preferencias, contexto resumido e sinais de seguranca controlados |
| MongoDB | `agenda_items` | Fila inteligente de lembretes, tarefas, eventos, follow-ups e rotinas |

### 5.2 Entidades logicas que esta frente formaliza

Mesmo antes de uma migration dedicada, a frente Helena passa a operar com as seguintes entidades logicas:

- `helena_consent_decision`: decisao de consentimento associada a insight, promocao de contexto ou acao cross-module.
- `helena_explainability_packet`: pacote minimo de evidencia que explica por que um insight ou contexto foi promovido.
- `helena_memory_promotion`: ato de converter conversa, evento ou agenda em memoria operacional persistente.
- `helena_action_scope`: limite exato do que o Advisor pode recomendar, preparar ou executar por modulo.
- `helena_helena_context_boundary`: fronteira entre pessoal e profissional que impede vazamento de contexto.

Enquanto nao houver tabela ou collection dedicada, estes contratos devem trafegar em `payload.details`, `ai_context`, `related_entities` ou documento controlado em `ai_memory`.

### 5.3 Lacunas reais do baseline

O baseline atual e suficiente para operar, mas ainda incompleto em pontos criticos:

- `advisor_insights` nao tem campos explicitos para evidencia, confianca, risco, racional ou motivo do consentimento.
- `chat_conversations` nao explicita escopo de retencao, classificacao de conversa ou trilha de promocao de contexto.
- `chat_messages` persiste conteudo, mas nao diferencia classificacao de sensibilidade ou destino de retention.
- `agenda_items.recurrence` esta aberta como objeto livre; falta contrato canonico.
- `agenda_items` ainda nao modela formalmente hierarquia de listas.
- `ai_memory` possui `consent_scope`, mas nao possui classe de retencao, motivo de promocao ou prova de explainability padronizada.

## 6. Modelo Canonico De Eventos

Os eventos canonicos do dominio continuam validos e passam a ter semantica operacional mais precisa:

| Evento | Semantica obrigatoria | Evidencias minimas |
| --- | --- | --- |
| `advisor.insight.generated` | Insight produzido, ainda sem execucao | `advisor_insights`, `ai_memory` e opcionalmente `financial_goals` ou `agenda_items` |
| `advisor.action.proposed` | Acao recomendada pronta para aceite, rejeicao ou agendamento | `advisor_insights`, `ai_memory`, `agenda_items` |
| `advisor.consent.recorded` | Consentimento valido e rastreavel para uma acao concreta | `advisor_insights` e prova de consentimento vinculada |
| `agenda.item.created` | Item criado manualmente, por IA ou por modulo integrado | `agenda_items` |
| `agenda.reminder.triggered` | Disparo real de lembrete, notificacao ou fila operacional | `agenda_items` |
| `agenda.memory.linked` | Ligacao entre item de agenda e memoria operacional relevante | `agenda_items`, `ai_memory` |
| `chat.conversation.opened` | Abertura de contexto conversacional com contexto Helena definido | `chat_conversations` |
| `chat.message.persisted` | Persistencia de mensagem dentro da conversa | `chat_messages` e contexto de conversa |
| `chat.context.promoted` | Promocao de conteudo conversacional para memoria ou agenda | `ai_memory`, `agenda_items`, referencia de conversa |

### 6.1 Regras transversais de evento

- Todo evento Helena deve carregar `trace_id`.
- Toda promocao de contexto deve referenciar origem: mensagem, insight, goal, item de agenda ou evento de modulo externo.
- Eventos de `ADVISOR` nunca podem implicar execucao financeira, clinica ou de mobilidade sem consentimento valido.
- Eventos de `CHAT` nao podem promover contexto para o contexto Helena oposto sem regra explicita de boundary.
- Eventos de `AGENDA` devem preservar `source_module` para reconciliacao.

## 7. Politica De Consentimento

### 7.1 Principios

- Consentimento e orientado a proposito, nao apenas a armazenamento.
- O fato de o usuario conversar com Helena nao autoriza automaticamente uso cross-module.
- A promocao de contexto de `CHAT` para `ai_memory` e de `ai_memory` para `AGENDA` depende do escopo de consentimento minimo da operacao.
- A execucao de acoes com impacto financeiro, clinico, mobilidade, seguranca ou negocio exige consentimento destacavel e auditavel.

### 7.2 Uso do enum atual de `ai_memory.consent_scope`

O enum atual do validator (`NONE`, `SESSION`, `PROFILE`, `CROSS_MODULE`) passa a ser interpretado assim:

| Consent scope | Uso permitido |
| --- | --- |
| `NONE` | Resposta imediata sem memoria persistente e sem promocao |
| `SESSION` | Uso dentro da conversa ou sessao corrente, sem memoria duradoura cross-session |
| `PROFILE` | Memoria duradoura dentro do mesmo contexto Helena e do mesmo contexto principal |
| `CROSS_MODULE` | Uso por modulos integrados, com rastreabilidade e boundary explicito |

### 7.3 Regras obrigatorias por capability

- `CHAT` resposta imediata: minimo `SESSION`.
- `chat.context.promoted` para memoria resumida: minimo `PROFILE`.
- `agenda.memory.linked`: minimo `PROFILE`, elevando para `CROSS_MODULE` se a origem vier de modulo externo.
- `advisor.insight.generated`: minimo `PROFILE`; se consumir evidencias externas ao proprio modulo, exigir `CROSS_MODULE`.
- `advisor.action.proposed`: minimo `CROSS_MODULE` quando a acao afetar `FINANCAS`, `HEALTH` ou `MOBILITY`.
- `advisor.consent.recorded`: sempre explicito, com timestamp, ator e escopo da acao.

### 7.4 Regras de boundary

- contexto Helena `PERSONAL` e `PROFESSIONAL` nao compartilham memoria por default.
- O compartilhamento entre contextos Helena deve ser tratado como elevacao de escopo, nunca como comportamento implicito.
- Conversa profissional pode ler preferencia global do usuario apenas se a preferencia estiver classificada como compartilhavel.
- Conteudo clinico, financeiro sensivel e incidentes de seguranca nunca podem ser promovidos entre contextos Helena sem consentimento explicito adicional.

### 7.5 Acesso admin

- Leitura admin deve ser `read-only` por default.
- Acesso a memoria ou conversa sensivel deve operar em modo break-glass com motivo, operador, horario e `trace_id`.
- Admin nao pode editar o historico bruto sem gerar nova trilha append-only ou documento de correcao.

## 8. Politica De Retention

### 8.1 Diretriz geral

Helena deve reter menos texto bruto e mais contexto derivado, explicavel e util.

Persistir tudo e sempre e um antipadrao para este dominio.

### 8.2 Classes canonicas de retention

| Artefato | Classe proposta | Janela padrao |
| --- | --- | --- |
| Mensagem bruta de chat | `conversation_raw` | 180 dias por default, extensivel por politica profissional |
| Resumo de contexto de sessao | `short_term_context` | 30 dias |
| Memoria operacional promovida | `operational_memory` | 365 dias apos ultimo uso relevante |
| Preferencia de usuario | `preference_memory` | ate revogacao ou 730 dias sem reafirmacao |
| Item de agenda concluido | `agenda_history` | 365 dias apos conclusao |
| Insight do Advisor sem execucao | `advisor_non_executed` | 365 dias |
| Insight com consentimento ou impacto regulatorio | `advisor_audit` | 1825 dias ou hold especifico |

### 8.3 Regras por entidade

- `chat_messages` deve ser tratado como dado de maior volatilidade.
- `ai_memory` deve privilegiar resumo, classificacao e referencias, nao dump literal.
- `agenda_items` concluidos podem ser arquivados, mas nao devem sumir enquanto sustentarem explainability de uma acao.
- `advisor_insights` com consentimento ou execucao nao podem perder o vinculo com a evidencia que os justificou.

### 8.4 Legal hold e congelamento

- Qualquer investigacao, disputa, fluxo juridico, seguranca ou auditoria regulatoria pode congelar a expiracao.
- O congelamento nao autoriza ampliar escopo de acesso.
- TTL automatico em Mongo so pode ser aplicado a classes claramente marcadas como expiraveis.

## 9. Memoria Operacional Helena

### 9.1 Taxonomia canonica

`ai_memory.memory_scope` passa a ser governado desta forma:

| Scope | Finalidade |
| --- | --- |
| `SHORT_TERM` | Contexto recente de sessao e continuidade curta |
| `LONG_TERM` | Conhecimento duradouro relevante e reafirmado |
| `PREFERENCE` | Preferencias do usuario, estilos, limites e escolhas persistentes |
| `SAFETY` | Sinais de risco, limites de seguranca e guardrails operacionais |
| `BUSINESS` | Contexto profissional, comercial ou de operacao estruturada |

### 9.2 Regra de promocao

Contexto so deve ser promovido para `ai_memory` quando atender pelo menos um destes criterios:

- util para a proxima interacao;
- necessario para explainability de uma recomendacao;
- necessario para continuidade de agenda, rotina ou follow-up;
- necessario para seguranca, preferencia ou restricao explicitamente declarada;
- necessario para integracao com modulo autorizado.

### 9.3 Regra de descarte

Nao promover:

- desabafo irrelevante sem efeito operacional;
- conteudo redundante ja resumido;
- informacao sensivel sem necessidade clara de continuidade;
- mensagem que atravessa fronteira de contexto Helena sem consentimento;
- detalhe clinico/financeiro bruto quando basta um resumo minimizado.

### 9.4 Estrutura minima recomendada para memoria promovida

Toda memoria promovida deveria carregar, ainda que em documento auxiliar:

- `promotion_reason`
- `promotion_source`
- `retention_class`
- `confidence_band`
- `consent_scope`
- `helena_context_mode`
- `evidence_refs`
- `last_reaffirmed_at`

## 10. Agenda Inteligente

### 10.1 Papel canonico da Agenda

`agenda_items` e a fila de execucao da Helena.

Tudo que sai de recomendacao e vira compromisso, lembrete, follow-up, rotina ou deadline deve convergir para `agenda_items`.

### 10.2 Contrato funcional do item

Um item de agenda precisa ter, no minimo:

- dono (`user_id`);
- contexto Helena dona (`owner_helena_context`);
- tipo (`agenda_kind`);
- status (`agenda_status`);
- origem (`source_module`);
- horario principal (`scheduled_for`);
- offsets de lembrete;
- referencias relacionadas;
- contexto sintetico para priorizacao e explainability.

### 10.3 Recorrencia canonica

O backlog `AGENDA.exec.01` deve ser fechado com um contrato de recorrencia minimamente estavel:

- `frequency`: `DAILY`, `WEEKLY`, `MONTHLY`, `CUSTOM`
- `interval`: inteiro positivo
- `by_weekday`: lista opcional
- `by_monthday`: lista opcional
- `timezone`: IANA obrigatoria quando houver recorrencia
- `ends_at`: opcional
- `occurrence_limit`: opcional
- `exceptions`: datas puladas ou ajustadas

Enquanto nao houver validator dedicado, este contrato deve ser o unico formato aceito em `agenda_items.recurrence`.

### 10.4 Hierarquia de listas

O backlog `AGENDA.exec.02` deve ser tratado como hierarquia logica em tres niveis:

- `workspace`: pessoal ou profissional;
- `list`: agrupamento funcional, por exemplo rotina, financeiro, saude, negocio;
- `item`: unidade executavel.

Como nao existe collection dedicada de listas hoje, a especificacao recomenda:

- armazenar `workspace_key` e `list_key` em `ai_context` ou `related_entities`;
- reservar `parent_item_id` para subitens ou checklist futuro;
- evitar criar taxonomia livre por tela sem chave canonica.

### 10.5 Integracao com Advisor e Chat

- Insight aceito pelo usuario deve virar item de agenda quando houver proximo passo claro.
- Chat pode criar item diretamente apenas quando a intencao do usuario for inequivoca ou houver confirmacao.
- Agenda nao deve criar loops de memoria; `agenda.memory.linked` precisa apontar para memorias relevantes, nao replicar texto.

## 11. Explainability

### 11.1 Regra institucional

Nenhum insight do `ADVISOR` deve ser considerado pronto para acao sem explainability minima.

### 11.2 Pacote minimo de explainability

Para cada insight ou acao proposta, a Helena deve conseguir responder:

- qual foi a evidencia principal;
- quais entidades ou memorias foram usadas;
- qual modulo originou o sinal;
- qual o nivel de confianca;
- qual o risco de agir;
- por que essa recomendacao e apropriada agora;
- o que muda se o usuario aceitar;
- qual consentimento e necessario.

### 11.3 Shape minimo recomendado

Mesmo sem coluna dedicada em `advisor_insights`, a frente Helena passa a exigir um pacote minimo com:

- `reason_summary`
- `evidence_refs`
- `source_modules`
- `confidence_band`
- `risk_level`
- `expected_outcome`
- `consent_required`
- `human_review_required`
- `generated_at`
- `trace_id`

### 11.4 Explainability para contexto promovido

`chat.context.promoted` e `agenda.memory.linked` tambem precisam justificar:

- por que o contexto foi promovido;
- de qual trecho ou evento ele veio;
- por quanto tempo ele deveria existir;
- em qual contexto Helena ele e valido.

## 12. Fluxos Admin E Operacao

### 12.1 Console de memoria

Capacidades esperadas:

- localizar memorias por `user_id`, contexto Helena, modulo e retention class;
- visualizar origem e motivo de promocao;
- aplicar hold ou revogacao;
- marcar memoria como incorreta, obsoleta ou contestada;
- emitir trilha de revisao sem apagar historico relevante.

### 12.2 Fila de aprovacoes do Advisor

Capacidades esperadas:

- revisar insight e explainability packet;
- visualizar escopo da acao por modulo;
- confirmar se o consentimento foi capturado;
- diferenciar sugestao de preparo de acao e execucao real;
- registrar override humano com justificativa.

### 12.3 Painel de conversas

Capacidades esperadas:

- inspecionar conversas por contexto Helena;
- visualizar promocoes de contexto disparadas;
- separar retencao de conversa pessoal e profissional;
- auditar boundary violations e tentativas de vazamento entre contextos Helena.

### 12.4 Painel de agenda

Capacidades esperadas:

- filtrar por source module;
- revisar lembretes vencidos, snoozed e follow-ups;
- reconciliar itens criados automaticamente;
- corrigir recorrencia e hierarquia sem quebrar rastreabilidade.

## 13. Riscos Principais

1. Vazamento entre os contextos Helena pessoal e profissional por ausencia de boundary explicito em memoria e chat.
2. Recomendacao cross-module sem prova suficiente de consentimento.
3. Retencao excessiva de mensagem bruta de chat sem reducao para resumo minimizado.
4. Explainability insuficiente em `advisor_insights`, gerando insight dificil de auditar ou defender.
5. Recorrencia e hierarquia da Agenda em formato livre, aumentando entropia entre clientes e automacoes.
6. Dependencia de campos flexiveis (`payload.details`, `ai_context`, `related_entities`) sem contrato minimo compartilhado.
7. Operacao admin forte demais, sem trilha break-glass padronizada.
8. Chat atualmente modelado para dois participantes; isso e suficiente para agora, mas limita cenarios futuros de room, equipe e multiagente.

## 14. Decisoes Pragmaticas Desta Frente

1. `ai_memory` continua sendo a memoria central, mas so com promocao justificada.
2. `agenda_items` continua sendo a fila de execucao da Helena e ponto de convergencia de follow-up.
3. `ADVISOR` precisa de explainability minima obrigatoria antes de escalar automacao.
4. `CHAT` e a superficie primaria de captura de contexto, mas nao o deposito final de conhecimento duradouro.
5. Toda operacao cross-module deve carregar consentimento, boundary e `trace_id`.
6. Preferencias e memoria duradoura devem sobreviver menos que dados juridicos/financeiros, e mais que contexto de sessao.
7. Admin revisa e congela; admin nao reescreve memoria historica sem nova trilha.

## 15. Proximos Entregaveis Fisicos Recomendados

### 15.1 P0

- Criar contrato formal de `helena_consent_decision` para sustentar `ADVISOR.exec.01`.
- Evoluir `advisor_insights` ou artefato auxiliar para armazenar explainability minima de forma estavel.
- Fechar shape canonico de `agenda_items.recurrence`.
- Definir retention class operacional para `chat_messages`, `ai_memory` e `agenda_items`.

### 15.2 P1

- Evoluir `chat_conversations` com classificacao de contexto, contexto Helena boundary e politica de retention.
- Reservar contrato de hierarquia de listas da Agenda, mesmo que ainda sem collection dedicada.
- Criar contrato de promocao de contexto para `chat.context.promoted` com origem e justificativa.

### 15.3 P2

- Criar visoes operacionais de auditoria Helena por `user_id`, `trace_id`, contexto Helena e source module.
- Instrumentar dashboards admin para fila de aprovacao, console de memoria e fila de retention.
- Planejar migracao do modelo de conversa para cenarios multi-participante, se o produto exigir.

## 16. Resultado Esperado

Se esta especificacao for seguida, a frente Helena deixa de ser apenas um agrupamento de modulos e passa a operar como um sistema institucional coerente:

- memoria util e governada;
- agenda realmente executavel;
- chat seguro entre contextos Helena;
- advisor explicavel e consentido;
- trilha clara para as proximas migrations fisicas.
