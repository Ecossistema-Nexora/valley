# Database - Valley Hybrid Core

Esta pasta contem a base de dados hibrida do Valley.

O PostgreSQL guarda identidade, dinheiro, contratos, orders, ledgers, delivery registry e auditoria.

O MongoDB guarda IA, social, influencer metrics e telemetria de alto volume.

## Scripts Atuais

`database/postgres/014_v47_expansion_tourism_bio_energy.sql` fecha a fronteira relacional dos modulos hibridos ainda planejados.

Esse script adiciona experiencias e bookings de turismo, programas e coletas reversas do modulo Bio e ativos, trades e ledger append-only do modulo Energy.

`database/postgres/013_v47_expansion_assets_civic_impact.sql` cria a primeira camada expansion em PostgreSQL.

Esse script adiciona ativos digitais, propriedades e deals, trilhas educacionais, prontuarios pet, catalogo/requests govtech, fundos de charity e produtos/polices/claims de insurance com ledgers append-only onde a trilha e prova financeira, civica ou securitaria.

`database/postgres/012_v47_core_services_health_jobs_pharmacy_events.sql` fecha o gap restante do tier core com contratos para SERVICES, HEALTH, JOBS, PHARMACY e EVENTS.

Esse script adiciona perfis e bookings de servicos, perfis/planos/prescricoes de saude, vagas/candidaturas/engagements, catalogo e dispensacao farmaceutica e programas/ingressos de eventos.

`database/postgres/008_v47_foundation_commerce_operations.sql` cria a primeira camada operacional especifica para REPLY, STOCK, WMS e MARKETPLACE.

Esse script adiciona fornecedores, armazens, itens, lotes, movimentos append-only, listings, compras, linhas de compra, ordens de servico e contagens fisicas.

`database/mongodb/002_v47_log_iot_foundation.mongo.js` cria a primeira camada NoSQL especifica para LOG, IoT e snapshots WMS.

Esse script adiciona validators e indices para tracking logistico, registry de devices, eventos de sensores e snapshots de armazem.

`database/postgres/009_v47_tech_legal_platform_contracts.sql` cria a primeira camada operacional especifica para TECH e LEGAL.

Esse script adiciona API clients, credenciais por hash, conectores, webhooks, tentativas append-only, contratos, partes, assinaturas append-only, disputas, eventos juridicos append-only e fallback PIN por hash.

`database/postgres/010_v47_rule_growth_marketplace_runtime.sql` cria a camada operacional especifica para Rule Engine, Marketplace runtime e growth.

Esse script adiciona bindings e trilha append-only de execucao de regras, storefronts, zonas de atendimento, controles de competitividade, snapshots de concorrencia, contas/ledger de Pepitas, campanhas GOLD e validacao real de venda.

`database/postgres/011_v47_city_ops_delivery_mobility_security.sql` cria a camada operacional especifica para Delivery, Mobility e Security.

Esse script adiciona shipments, eventos append-only de entrega, trips, checkpoints append-only, contatos confiaveis, biometria por hash, incidentes e eventos append-only de seguranca.

`database/mongodb/003_v47_field_ops_security_agenda.mongo.js` cria a camada NoSQL especifica para dispatch, frota, seguranca e agenda inteligente.

Esse script adiciona validators e indices para dispatch de entrega, cadastro de frota, eventos de manutencao, sinais de seguranca e itens de agenda da Helena.

`database/mongodb/004_v47_expansion_media_wellness_frontier.mongo.js` fecha a camada NoSQL dos modulos que ainda estavam planejados.

Esse script adiciona validators e indices para News & Podcast, Fitness, Gaming, Home e Space, alem dos payloads volumosos de Tourism, Bio e Energy.

## Manifesto

`database/migrations.json` e a ordem oficial de implantacao.

Ele existe para impedir execucao fora de ordem e para permitir que `scripts/valley_db_orchestrator.py` aplique ou valide migrations.

`database/postgres/015_v47_module_blueprints_registry.sql` evolui `module_delivery_registry` com `module_blueprint_json`, preservando a tabela existente e sincronizando a fase real de cada modulo.

`config/modules_v47_blueprints.json` e a fonte canonica da evolucao detalhada dos 47 modulos: atores, capacidades, entidades, eventos, compliance, superficies admin e backlog imediato.

`database/postgres/016_v47_execution_backlog_seed.sql` evolui `module_evolution_backlog` com `backlog_key`, `backlog_group`, `execution_stage`, `depends_on_keys` e itens executaveis seedados a partir dos entregaveis imediatos de cada modulo.

`database/postgres/017_v47_priority_domain_delivery_packages.sql` cria o registry fisico da primeira onda de dominios prioritarios, com tabelas para pacotes, artefatos por camada e contratos de evento.

`database/postgres/018_v47_platform_developer_business_ddl.sql` abre o dominio `platform_developer` com DDL de negocio real para `DOCS` e `TECH`, saindo do nivel apenas de views/registry.

Esse script adiciona contratos de template documental, versoes append-only de template, cadeia de checksum, versoes de recibo, limites por client, trilha de rotacao de credenciais e replay controlado de webhook.

`database/postgres/019_v47_logistics_erp_operations_business_ddl.sql` aprofunda o dominio `logistics_erp_operations` com DDL de negocio real para `BUSINESS`, `REPLY`, `STOCK`, `LOG`, `FOOD`, `WMS`, `DELIVERY` e `FLEET`.

Esse script adiciona unidades e fechamento fiscal, politicas e trilhas de aprovacao de compras, margem por canal, conciliacao com fornecedor, ruptura, contratos de loja/cardapio, enderecamento WMS, incidentes de temperatura, politicas e prova de entrega e custo operacional de frota.

`database/postgres/022_v47_city_mobility_security_business_ddl.sql` materializa o dominio `city_mobility_security` com views operacionais de juridico, experiencias, seguranca e govtech.

`database/postgres/023_v47_commerce_fintech_assets_business_ddl.sql` materializa o dominio `commerce_fintech_assets` com views operacionais de marketplace, treasury, ativos digitais, real estate e insurance.

`database/postgres/024_v47_ai_memory_operations_business_ddl.sql` materializa o dominio `ai_memory_operations` com views de backlog, artefatos, contratos, advisor, chat, consentimento e contexto do usuario.

`database/postgres/025_v47_media_social_growth_business_ddl.sql` materializa o dominio `media_social_growth` com views de backlog, artefatos, contratos, creators, rewards, referrals e gaming.

`database/postgres/026_v47_frontier_iot_energy_business_ddl.sql` fecha a primeira onda dos dominios prioritarios com views de backlog, artefatos e contratos para IOT, BIO, HOME, ENERGY e SPACE.

`database/postgres/027_v47_helena_identity_pricing_guardrails.sql` fecha lacunas do spec da Helena com origem natal em `users` e filtro de competitividade para listings ativos ou competitivos.

`database/postgres/028_v47_module_catalog_42_47_seed.sql` sincroniza `module_catalog` com os modulos 42-47 ja existentes no registry de entrega.

`database/postgres/029_v47_module_catalog_registry_aliases.sql` reconcilia `module_catalog` com todos os `module_code` operacionais de `module_delivery_registry` sem apagar aliases legados.

`database/postgres/030_v47_fix_gold_campaign_reward_type_ambiguity.sql` corrige a funcao de coerencia GOLD/Pepita para evitar ambiguidade entre variavel local e coluna `reward_type`.

`database/postgres/031_v47_fix_pepita_account_status_ambiguity.sql` corrige a funcao append-only de Pepita para evitar ambiguidade entre variavel local e coluna `account_status`.

`database/postgres/032_v47_mobility_production_schema.sql` cria o schema `mobility` de modo producao para benchmark de custo, rotas de usuario e buffer realtime, mantendo `mobility_trips` como execucao consolidada de corrida.

`database/postgres/035_v47_phase1_commerce_identity_engagement.sql` fecha a Fase 1 comercial focada do Valley.

Esse script adiciona auth/sessao, perfis de usuario e lojista, home personalizada, integracoes de checkout, intents/webhooks de pagamento, chat comprador-lojista, carrinho, favoritos, reviews e SAC, mantendo `users`, `wallets`, `orders`, `transactions`, `inventory_items`, `marketplace_listings`, `merchant_storefronts` e `dropshipping_*` como ancora do fluxo.

`database/seeds/postgres/002_v47_priority_domain_delivery_packages_seed.sql` popula esse registry com os dominios cuja prioridade minima do backlog e `<= 2`, sem perder idempotencia.

`database/domain-delivery/priority-domains/` guarda os pacotes fisicos por dominio, com `ddl_complement.sql` e `operational_seed.sql` prontos para revisao e aplicacao controlada.

`contracts/events/priority-domains/` exporta os contratos de evento por dominio em JSON, com schema pragmatico, superficies produtoras/consumidoras e evidencias operacionais.

## PostgreSQL

Os arquivos em `database/postgres/` devem ser aplicados na ordem do manifesto.

O modelo e `core-first`, com `public.users.user_id` como no central.

Ledgers e auditorias usam padrao `append-only`, bloqueando `UPDATE` e `DELETE` por trigger quando o registro representa dinheiro, documento ou trilha critica.

Movimentos de estoque e contagens fisicas tambem sao `append-only`, porque representam auditoria operacional.

Tentativas de webhook, assinaturas juridicas e eventos juridicos tambem sao `append-only`, porque representam prova tecnica ou legal.

Execucoes de regra, snapshots de concorrencia, eventos GOLD e ledger de Pepitas tambem sao `append-only`, porque representam decisao, evidencia comercial ou saldo gamificado.

Eventos de entrega, checkpoints de corrida e eventos de seguranca tambem usam `append-only`, porque representam trilha de campo, prova operacional e possivel evidencia juridica.

O schema `mobility` separa planejamento e tempo real de Mobility (`cost_benchmarks`, `user_routes`, `realtime_buffer`) da execucao financeira/operacional em `public.mobility_trips`.

Eventos de ativos digitais, requests govtech, fundos de charity e trilhas de claim de insurance tambem usam `append-only`, porque representam propriedade, decisao publica, dinheiro social ou disputa securitaria.

Segredos reais nao devem ser persistidos; use apenas hash, prefixo publico ou referencia externa segura.

## MongoDB

Os arquivos em `database/mongodb/` devem ser aplicados com `mongosh`.

O script atual usa `createCollection`, `collMod`, `JSON Schema Validation` e indices.

Os scripts MongoDB devem manter `user_id` como string UUID para ponte logica com PostgreSQL.

## Esteira Local

Validar tudo que nao depende de banco ativo:

```bash
python scripts/valley_db_orchestrator.py check
```

Gerar relatorio operacional:

```bash
python scripts/valley_db_orchestrator.py report
```

Aplicar PostgreSQL e MongoDB usando `.env` ou `.env.example` da raiz:

```bash
python scripts/valley_db_orchestrator.py apply-postgres
python scripts/valley_db_orchestrator.py apply-mongo
```

Subir banco local com Docker Compose:

```bash
python scripts/valley_db_orchestrator.py compose-up
```

Aplicar migrations no Compose. O comando abaixo ja executa `compose-up` antes de aplicar:

```bash
python scripts/valley_db_orchestrator.py apply-compose
```

No Windows, se o `docker info` ou o wrapper `psql.cmd` falhar por bridge do Docker Desktop, use o entrypoint WSL:

```powershell
.\scripts\apply_valley_db_via_wsl.ps1
```

Esse script sobe `postgres` e `mongodb` pelo Ubuntu WSL, injeta wrappers temporarios de `psql` e `mongosh`, aplica PostgreSQL e MongoDB pelo mesmo manifesto oficial e gera o report no final.

Se o volume local do PostgreSQL ficar preso em recovery, o mesmo entrypoint tambem cobre backup bruto e recriacao limpa do volume:

```powershell
.\scripts\apply_valley_db_via_wsl.ps1 -ResetPostgresVolume
```

Aplicar os seeds minimos do bloco expansion que cobre Tourism, Bio, Energy, News, Fitness, Gaming, Home e Space:

```bash
python scripts/valley_db_orchestrator.py seed-compose
```

O comando acima agora tambem aplica os `operational_seed.sql` fisicos de `platform_developer`, `logistics_erp_operations`, `ai_memory_operations`, `media_social_growth`, `frontier_iot_energy`, `city_mobility_security` e `commerce_fintech_assets`, com dados operacionais reais e contratos de evento dos dominios prioritarios.

Executar smoke check relacional e NoSQL do bloco expansion seedado:

```bash
python scripts/valley_db_orchestrator.py smoke-compose
```

Exportar snapshot operacional do banco local aplicado e seedado:

```bash
python scripts/valley_db_orchestrator.py snapshot-compose
```

Validar integridade do snapshot mais recente antes de restaurar:

```bash
python scripts/valley_db_orchestrator.py snapshot-verify
```

Restaurar o snapshot mais recente no Docker Compose local. Esse comando sobrescreve o estado atual de `valley` em PostgreSQL e MongoDB:

```bash
python scripts/valley_db_orchestrator.py restore-compose
```

Executar o worker builder diretamente no Docker Compose:

```bash
docker compose --profile builder run --rm --build builder
```

Parar o ambiente local sem apagar volumes:

```bash
python scripts/valley_db_orchestrator.py compose-down
```

## Variaveis

`DATABASE_URL` permite aplicar PostgreSQL fora do Compose e pode vir do ambiente, `.env` ou `.env.example`.

`MONGODB_URI` permite aplicar MongoDB fora do Compose e pode vir do ambiente, `.env` ou `.env.example`.

No PowerShell, override manual fica assim:

```powershell
$env:DATABASE_URL='postgresql://user:pass@host:5432/db'; python scripts/valley_db_orchestrator.py apply-postgres
$env:MONGODB_URI='mongodb://localhost:27017/valley'; python scripts/valley_db_orchestrator.py apply-mongo
```

Use `.env.example` como baseline local e `.env` para overrides reais da sua maquina.

## Painel Admin

`admin/index.html` e um console web estatico dirigido por `admin/valley_admin_data.js`.

Esse dataset e regenerado automaticamente por `scripts/valley_module_automation.py sync` e por `python scripts/valley_db_orchestrator.py report`.

Abra o painel diretamente no navegador quando quiser acompanhar modulo, checklist, docs, roadmap, relatorio e comandos operacionais sem depender de backend adicional.
