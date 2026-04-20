# Database - Valley Hybrid Core

Esta pasta contem a base de dados hibrida do Valley.

O PostgreSQL guarda identidade, dinheiro, contratos, orders, ledgers, delivery registry e auditoria.

O MongoDB guarda IA, social, influencer metrics e telemetria de alto volume.

## Scripts Atuais

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

## Manifesto

`database/migrations.json` e a ordem oficial de implantacao.

Ele existe para impedir execucao fora de ordem e para permitir que `scripts/valley_db_orchestrator.py` aplique ou valide migrations.

## PostgreSQL

Os arquivos em `database/postgres/` devem ser aplicados na ordem do manifesto.

O modelo e `core-first`, com `public.users.user_id` como no central.

Ledgers e auditorias usam padrao `append-only`, bloqueando `UPDATE` e `DELETE` por trigger quando o registro representa dinheiro, documento ou trilha critica.

Movimentos de estoque e contagens fisicas tambem sao `append-only`, porque representam auditoria operacional.

Tentativas de webhook, assinaturas juridicas e eventos juridicos tambem sao `append-only`, porque representam prova tecnica ou legal.

Execucoes de regra, snapshots de concorrencia, eventos GOLD e ledger de Pepitas tambem sao `append-only`, porque representam decisao, evidencia comercial ou saldo gamificado.

Eventos de entrega, checkpoints de corrida e eventos de seguranca tambem usam `append-only`, porque representam trilha de campo, prova operacional e possivel evidencia juridica.

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
