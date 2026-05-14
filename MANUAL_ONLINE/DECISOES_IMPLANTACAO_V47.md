<!--
PROPOSITO: Documentar DECISOES IMPLANTACAO V47 no escopo operacional do Valley.
CONTEXTO: Este arquivo registra orientacoes, decisoes ou plano associado ao caminho MANUAL_ONLINE/DECISOES_IMPLANTACAO_V47.md.
REGRAS: Manter informacao rastreavel, preservar nomenclatura Valley e atualizar ao mudar a rotina correspondente.
-->

# Decisoes de Implantacao v47 - Valley

Este documento registra como os PDFs v47 foram analisados e adaptados para esta arvore Valley.

A decisao principal continua sendo `core-first`: `users` e `wallets` sao o centro, e todos os novos objetos viaveis apontam para `users.user_id`.

## Fontes Verificadas

Foram verificados os PDFs locais do `Meu Drive`:

- `Esquema Consolidado do Valley Omniverse v47.pdf`
- `Valley Omniverse v47 - Esquema de Banco de Dados.pdf`
- `Valley Omniverse v47 - Esquema de Banco de Dados 2.pdf`
- `Valley Omniverse - Mapeamento de Modulos (v47).pdf`
- `Indice Oficial Valley Omniverse.pdf`
- `Painel Web Admin - Especificacao Consolidada (v47).pdf`
- `Valley Omniverse - Papeis de Gemini, Code Assist e Codex e Integracao de IA.pdf`
- `Valley Omniverse - Regras Consolidadas do Codex.pdf`
- `Valley Omniverse - Regras Consolidadas para o Gemini Code Assist (v47).pdf`

## Implantado

`database/postgres/004_v47_control_plane_modules_rules.sql` implanta o plano de controle v47.

Ele cria `module_catalog`, `admin_users`, `admin_permissions`, `business_rule_definitions`, `business_rule_versions`, `business_rule_audit`, `gamification_campaigns`, `points_ledger`, `observability_incidents`, `document_records` e `admin_action_audit`.

Ele tambem popula os 41 modulos do mapeamento oficial v47 e registra regras base: Stock margem 50%, Mobility 10%, Food 15%, afiliados 5%, Ring-Fence Financeiro e Consentimento de Execucao Advisor.

`database/postgres/005_v47_domain_tables_core_first.sql` implanta tabelas dominio viaveis do PDF de banco.

Ele cria `advisor_insights`, `financial_goals`, `teletherapy_sessions`, `creator_uploads`, `chat_conversations`, `chat_messages`, `business_invoices`, `business_payrolls`, `plug_transactions`, `affiliate_referrals` e `docs_receipts`.

`database/postgres/006_v47_column_comments_ptbr.sql` documenta as novas tabelas em `COMMENT ON`.

Ele explica colunas, triggers e integracoes em portugues simples, mantendo termos tecnicos como `foreign key`, `JSONB`, `append-only`, `ledger`, `RBAC`, `ABAC` e `Web Admin`.

`config/modules_v47.json` foi criado como registry canonico dos 47 modulos reais do Esquema Consolidado.

`scripts/automacao_sincronizador_modulos.py` foi criado como motor local de automacao de implantacao, desenvolvimento e evolucao.

`modules/` foi materializado com uma pasta por modulo, cada uma contendo `README.md` e `STATUS.md`.

Cada modulo agora tambem possui `CONTRACT.md`, que define fronteira operacional, politica de dados, integracoes e regras de evolucao.

`output/module-roadmap/VALLEY_MODULE_ROADMAP.md` foi criado como roadmap automatizado.

`output/module-roadmap/VALLEY_MODULE_CONTRACTS.md` foi criado como matriz consolidada dos contratos operacionais.

`database/postgres/007_v47_module_delivery_automation.sql` foi gerado a partir do registry para persistir `module_delivery_registry`, `module_evolution_backlog` e `module_automation_runs`.

`database/postgres/008_v47_foundation_commerce_operations.sql` foi criado para materializar contratos especificos de REPLY, STOCK, WMS e MARKETPLACE.

Esse script cria fornecedores, armazens, itens, lotes, movimentos de estoque append-only, listings, compras, linhas de compra, ordens de servico e contagens fisicas.

`database/mongodb/002_v47_log_iot_foundation.mongo.js` foi criado para materializar contratos especificos de LOG, IoT e snapshots WMS.

Esse script cria validators e indices para tracking logistico, devices, eventos de sensores e snapshots de armazem.

`database/postgres/009_v47_tech_legal_platform_contracts.sql` foi criado para materializar contratos especificos de TECH e LEGAL.

Esse script cria API clients, credenciais por hash, conectores, webhooks, tentativas append-only, contratos, partes, assinaturas append-only, disputas, eventos juridicos append-only e fallback PIN por hash.

`database/postgres/010_v47_rule_growth_marketplace_runtime.sql` foi criado para materializar a camada de Rule Engine runtime, growth e operacao comercial.

Esse script cria bindings e execucoes append-only do Rule Engine, storefronts, zonas de atendimento, controles de competitividade, snapshots de concorrencia, contas/ledger de Pepitas, campanhas GOLD e validacao de venda marketplace/fisica.

`database/postgres/011_v47_city_ops_delivery_mobility_security.sql` foi criado para materializar a camada relacional de campo e seguranca.

Esse script cria shipments, eventos append-only de entrega, trips, checkpoints append-only, contatos confiaveis, biometria por hash, incidentes e eventos append-only de seguranca.

`database/mongodb/003_v47_field_ops_security_agenda.mongo.js` foi criado para materializar a camada NoSQL de dispatch, frota, sinais de seguranca e agenda inteligente.

Esse script cria validators e indices para dispatch de entrega, cadastro de frota, eventos de manutencao, sinais de seguranca e agenda da Helena.

`database/migrations.json` foi criado como manifesto oficial da ordem de migrations.

`scripts/valley_db_orchestrator.py` foi criado para validar ambiente, manifesto, SQL, MongoDB, registry e aplicar migrations quando houver banco disponivel.

`docker-compose.yml` foi criado para Postgres e Mongo locais de validacao runtime.

`database/README.md`, `MANUAL_ONLINE/OPERACAO_AUTONOMA.md` e `output/deployment/VALLEY_DEPLOYMENT_STATUS.md` foram criados para registrar a esteira operacional.

## Adaptado

Os schemas legados dos PDFs (`platform`, `memory`, `fintech`, `rules`, `gamification`, `observability`, `docs`, `chat`, `business`, `plug`, `affiliates`) foram achatados para `public`.

As FKs antigas para `platform.users(user_id)` foram adaptadas para `public.users(user_id)`.

O indice de 41 modulos foi preservado como visao estrategica, mas a automacao operacional usa os 47 modulos do Esquema Consolidado.

Conceitos como `LOYALTY`, `API`, `COMMAND_CENTER`, `ADS_INTELLIGENCE`, `CLOUD`, `CONNECT` e `CREATOR` foram tratados como capacidades transversais quando nao aparecem como modulo numerado no esquema de 47.

Os valores monetarios em BRL foram padronizados como `DECIMAL(18,4)`.

Os valores tokenizados NEX continuam como `DECIMAL(18,8)`.

Logs financeiros, pontos, documentos, auditoria de regras, acoes admin, Plug, referrals e receipts foram tratados como append-only quando representam auditoria ou dinheiro.

O desenvolvimento dos 47 modulos foi adaptado para passar por contrato operacional antes de schema especifico.

Essa camada reduz retrabalho porque fixa `data_home`, dependencias, integracoes e regras de evolucao antes da implementacao.

Os modulos REPLY, STOCK, LOG, WMS e MARKETPLACE foram promovidos para `implemented_partial` no registry, porque agora possuem contrato operacional e primeira camada de schema.

LOG e IoT continuam fora do PostgreSQL para eventos volumosos; apenas referencias UUID e snapshots relacionais ficam conectados ao core.

Os modulos TECH e LEGAL foram promovidos para `implemented_partial` no registry, porque agora possuem contrato operacional e primeira camada de schema.

Credenciais de API, webhook secrets, IPs, device fingerprints e fallback PIN foram adaptados para hash, descartando armazenamento de segredo bruto por seguranca.

O modulo ADS foi promovido para `implemented_partial` no registry, porque agora possui primeira camada operacional de campanhas GOLD e eventos de conversao.

O cap de Pepita foi adaptado para enforcement relacional em `sale_validation_events` e `pepita_ledger`, descartando a ideia inviavel de cashback livre sem referencia de margem.

O Rule Engine nao foi recriado do zero; a implementacao reutiliza `business_rule_definitions` e `business_rule_versions` e adiciona apenas o runtime auditavel necessario.

Os modulos DELIVERY, FLEET, SECURITY e AGENDA foram promovidos para `implemented_partial` no registry, porque agora possuem primeira camada de schema especifico.

Biometria foi adaptada para persistencia somente por hash e metadados, descartando armazenamento de template bruto no banco.

Os incidentes de seguranca foram adaptados para modelo hibrido: contrato relacional no PostgreSQL e sinais volumosos no MongoDB.

Os pacotes `database/domain-delivery/priority-domains/<dominio>/ddl_complement.sql` foram adaptados para views geradas pelo registry e pelo backlog executavel, em vez de manter consultas manuais por dominio sem lastro no `module_evolution_backlog`.

Os `operational_seed.sql` desses dominios tambem foram reduzidos ao seed canonico emitido pela automacao, descartando o modelo inviavel de seed artesanal grande demais e propenso a drift entre contratos, registry e SQL.

## Descartado

Nao foi implantado multi-schema legado, porque conflita com a diretriz desta worktree.

Nao foram implantados comandos automaticos de `git commit`, `git push`, deploy ou exclusao de arquivos, porque isso e perigoso em uma arvore local sem repositorio Git validado.

Nao foram implantados logs brutos de observabilidade em Postgres, porque alto volume deve ir para MongoDB, Elastic, Loki, ClickHouse ou outro backend especializado.

Nao foram implantadas credenciais, tokens, gateways reais ou integracoes externas, porque os PDFs descrevem intencao de produto, nao contratos seguros de ambiente.

Nao foi criada tabela duplicada de `platform.users`, porque `public.users` ja e o no central absoluto.

Nao foi criada compatibilidade direta com `uuid_generate_v4()`, porque esta base usa `pgcrypto` e `gen_random_uuid()`.

Nao foi executada aplicacao runtime em banco real neste ciclo, porque o ambiente atual nao expoe `psql`, `mongosh`, `DATABASE_URL` nem `MONGODB_URI`.

Nao foi forçado Docker daemon quando ele nao estava comprovadamente pronto, porque a esteira segura deve registrar pendencia em vez de travar o ciclo autonomo.

## Risco Residual

Os scripts SQL ainda precisam ser executados em um PostgreSQL real para validacao runtime.

Este ambiente nao possui `psql`, entao a validacao feita aqui cobre estrutura textual, sintaxe JavaScript do Mongo e geracao de documentacao.

Quando `psql` estiver disponivel, a ordem recomendada e executar o manifesto `database/migrations.json`.

O script `003` pode rodar antes de `004/005`, mas `006` precisa vir depois das novas tabelas v47.

Depois desta atualizacao, a ordem recomendada passou a ser `001`, `002`, `004`, `005`, `003`, `006` e `007`.

Depois da evolucao foundation, a ordem PostgreSQL passou a incluir `008` apos `007`.

Depois da evolucao TECH/LEGAL, a ordem PostgreSQL passou a incluir `009` apos `008`.

Depois da evolucao de Rule Engine, Pepitas e Ads, a ordem PostgreSQL passou a incluir `010` apos `009`.

Depois da evolucao city ops e seguranca, a ordem PostgreSQL passou a incluir `011` apos `010`.

No MongoDB, a ordem passou a ser `mongo-001`, depois `mongo-002` e por fim `mongo-003`.

O relatorio operacional mais recente fica em `output/deployment/VALLEY_DEPLOYMENT_STATUS.md`.

