# Valley Deployment Status

Gerado em UTC: `2026-04-20T04:38:57.407510+00:00`.

Total de checagens: `118`.
Falhas ou pendencias: `7`.

## Resultado

- OK - `tool.python_runtime`: C:\Users\ereta\AppData\Local\Programs\Python\Python312\python.exe
- OK - `tool.node`: C:\Users\ereta\AppData\Local\Microsoft\WinGet\Packages\OpenJS.NodeJS.LTS_Microsoft.Winget.Source_8wekyb3d8bbwe\node-v24.14.1-win-x64\node.EXE
- PENDENTE - `tool.psql`: nao encontrado no PATH
- PENDENTE - `tool.mongosh`: nao encontrado no PATH
- OK - `tool.docker`: C:\Program Files\Docker\Docker\resources\bin\docker.EXE
- OK - `env.DATABASE_URL`: configurado via .env.example
- OK - `env.MONGODB_URI`: configurado via .env.example
- PENDENTE - `tool.docker_daemon`: docker info nao respondeu em 30s; iniciar Docker Desktop ou verificar o engine.
- PENDENTE - `tool.docker_compose`: comando excedeu 10s e foi interrompido
- OK - `manifest.postgres_present`: 13 migrations PostgreSQL declaradas.
- OK - `manifest.mongodb_present`: 3 scripts MongoDB declarados.
- OK - `postgres.001.exists`: database/postgres/001_core_identity_wallets.sql
- OK - `postgres.001.order`: dependencias OK
- OK - `postgres.002.exists`: database/postgres/002_financial_ledger_equity_orders.sql
- OK - `postgres.002.order`: dependencias OK
- OK - `postgres.004.exists`: database/postgres/004_v47_control_plane_modules_rules.sql
- OK - `postgres.004.order`: dependencias OK
- OK - `postgres.005.exists`: database/postgres/005_v47_domain_tables_core_first.sql
- OK - `postgres.005.order`: dependencias OK
- OK - `postgres.003.exists`: database/postgres/003_database_comments_ptbr.sql
- OK - `postgres.003.order`: dependencias OK
- OK - `postgres.006.exists`: database/postgres/006_v47_column_comments_ptbr.sql
- OK - `postgres.006.order`: dependencias OK
- OK - `postgres.007.exists`: database/postgres/007_v47_module_delivery_automation.sql
- OK - `postgres.007.order`: dependencias OK
- OK - `postgres.008.exists`: database/postgres/008_v47_foundation_commerce_operations.sql
- OK - `postgres.008.order`: dependencias OK
- OK - `postgres.009.exists`: database/postgres/009_v47_tech_legal_platform_contracts.sql
- OK - `postgres.009.order`: dependencias OK
- OK - `postgres.010.exists`: database/postgres/010_v47_rule_growth_marketplace_runtime.sql
- OK - `postgres.010.order`: dependencias OK
- OK - `postgres.011.exists`: database/postgres/011_v47_city_ops_delivery_mobility_security.sql
- OK - `postgres.011.order`: dependencias OK
- OK - `postgres.012.exists`: database/postgres/012_v47_core_services_health_jobs_pharmacy_events.sql
- OK - `postgres.012.order`: dependencias OK
- OK - `postgres.013.exists`: database/postgres/013_v47_expansion_assets_civic_impact.sql
- OK - `postgres.013.order`: dependencias OK
- OK - `mongodb.mongo-001.exists`: database/mongodb/001_ai_social_telemetry.mongo.js
- OK - `mongodb.mongo-001.order`: dependencias OK
- OK - `mongodb.mongo-002.exists`: database/mongodb/002_v47_log_iot_foundation.mongo.js
- OK - `mongodb.mongo-002.order`: dependencias OK
- OK - `mongodb.mongo-003.exists`: database/mongodb/003_v47_field_ops_security_agenda.mongo.js
- OK - `mongodb.mongo-003.order`: dependencias OK
- OK - `modules.artifacts.directories`: 47 pastas de modulo encontradas.
- OK - `modules.artifacts.readme`: todos os README.md existem
- OK - `modules.artifacts.status`: todos os STATUS.md existem
- OK - `modules.artifacts.contract`: todos os CONTRACT.md existem
- OK - `modules.artifacts.roadmap`: output\module-roadmap\VALLEY_MODULE_ROADMAP.md
- OK - `modules.artifacts.contracts_summary`: output\module-roadmap\VALLEY_MODULE_CONTRACTS.md
- OK - `database\postgres\001_core_identity_wallets.sql.begin`: Migration contem BEGIN.
- OK - `database\postgres\001_core_identity_wallets.sql.commit`: Migration contem COMMIT.
- OK - `database\postgres\001_core_identity_wallets.sql.no_drop`: Sem DROP TABLE/TYPE destrutivo.
- OK - `database\postgres\001_core_identity_wallets.sql.no_raw_delete`: Sem DELETE FROM em migration de schema.
- OK - `database\postgres\001_core_identity_wallets.sql.has_comments`: Arquivo contem comentarios ou COMMENT ON.
- OK - `database\postgres\002_financial_ledger_equity_orders.sql.begin`: Migration contem BEGIN.
- OK - `database\postgres\002_financial_ledger_equity_orders.sql.commit`: Migration contem COMMIT.
- OK - `database\postgres\002_financial_ledger_equity_orders.sql.no_drop`: Sem DROP TABLE/TYPE destrutivo.
- OK - `database\postgres\002_financial_ledger_equity_orders.sql.no_raw_delete`: Sem DELETE FROM em migration de schema.
- OK - `database\postgres\002_financial_ledger_equity_orders.sql.has_comments`: Arquivo contem comentarios ou COMMENT ON.
- OK - `database\postgres\004_v47_control_plane_modules_rules.sql.begin`: Migration contem BEGIN.
- OK - `database\postgres\004_v47_control_plane_modules_rules.sql.commit`: Migration contem COMMIT.
- OK - `database\postgres\004_v47_control_plane_modules_rules.sql.no_drop`: Sem DROP TABLE/TYPE destrutivo.
- OK - `database\postgres\004_v47_control_plane_modules_rules.sql.no_raw_delete`: Sem DELETE FROM em migration de schema.
- OK - `database\postgres\004_v47_control_plane_modules_rules.sql.has_comments`: Arquivo contem comentarios ou COMMENT ON.
- OK - `database\postgres\005_v47_domain_tables_core_first.sql.begin`: Migration contem BEGIN.
- OK - `database\postgres\005_v47_domain_tables_core_first.sql.commit`: Migration contem COMMIT.
- OK - `database\postgres\005_v47_domain_tables_core_first.sql.no_drop`: Sem DROP TABLE/TYPE destrutivo.
- OK - `database\postgres\005_v47_domain_tables_core_first.sql.no_raw_delete`: Sem DELETE FROM em migration de schema.
- OK - `database\postgres\005_v47_domain_tables_core_first.sql.has_comments`: Arquivo contem comentarios ou COMMENT ON.
- OK - `database\postgres\003_database_comments_ptbr.sql.begin`: Migration contem BEGIN.
- OK - `database\postgres\003_database_comments_ptbr.sql.commit`: Migration contem COMMIT.
- OK - `database\postgres\003_database_comments_ptbr.sql.no_drop`: Sem DROP TABLE/TYPE destrutivo.
- OK - `database\postgres\003_database_comments_ptbr.sql.no_raw_delete`: Sem DELETE FROM em migration de schema.
- OK - `database\postgres\003_database_comments_ptbr.sql.has_comments`: Arquivo contem comentarios ou COMMENT ON.
- OK - `database\postgres\006_v47_column_comments_ptbr.sql.begin`: Migration contem BEGIN.
- OK - `database\postgres\006_v47_column_comments_ptbr.sql.commit`: Migration contem COMMIT.
- OK - `database\postgres\006_v47_column_comments_ptbr.sql.no_drop`: Sem DROP TABLE/TYPE destrutivo.
- OK - `database\postgres\006_v47_column_comments_ptbr.sql.no_raw_delete`: Sem DELETE FROM em migration de schema.
- OK - `database\postgres\006_v47_column_comments_ptbr.sql.has_comments`: Arquivo contem comentarios ou COMMENT ON.
- OK - `database\postgres\007_v47_module_delivery_automation.sql.begin`: Migration contem BEGIN.
- OK - `database\postgres\007_v47_module_delivery_automation.sql.commit`: Migration contem COMMIT.
- OK - `database\postgres\007_v47_module_delivery_automation.sql.no_drop`: Sem DROP TABLE/TYPE destrutivo.
- OK - `database\postgres\007_v47_module_delivery_automation.sql.no_raw_delete`: Sem DELETE FROM em migration de schema.
- OK - `database\postgres\007_v47_module_delivery_automation.sql.has_comments`: Arquivo contem comentarios ou COMMENT ON.
- OK - `database\postgres\008_v47_foundation_commerce_operations.sql.begin`: Migration contem BEGIN.
- OK - `database\postgres\008_v47_foundation_commerce_operations.sql.commit`: Migration contem COMMIT.
- OK - `database\postgres\008_v47_foundation_commerce_operations.sql.no_drop`: Sem DROP TABLE/TYPE destrutivo.
- OK - `database\postgres\008_v47_foundation_commerce_operations.sql.no_raw_delete`: Sem DELETE FROM em migration de schema.
- OK - `database\postgres\008_v47_foundation_commerce_operations.sql.has_comments`: Arquivo contem comentarios ou COMMENT ON.
- OK - `database\postgres\009_v47_tech_legal_platform_contracts.sql.begin`: Migration contem BEGIN.
- OK - `database\postgres\009_v47_tech_legal_platform_contracts.sql.commit`: Migration contem COMMIT.
- OK - `database\postgres\009_v47_tech_legal_platform_contracts.sql.no_drop`: Sem DROP TABLE/TYPE destrutivo.
- OK - `database\postgres\009_v47_tech_legal_platform_contracts.sql.no_raw_delete`: Sem DELETE FROM em migration de schema.
- OK - `database\postgres\009_v47_tech_legal_platform_contracts.sql.has_comments`: Arquivo contem comentarios ou COMMENT ON.
- OK - `database\postgres\010_v47_rule_growth_marketplace_runtime.sql.begin`: Migration contem BEGIN.
- OK - `database\postgres\010_v47_rule_growth_marketplace_runtime.sql.commit`: Migration contem COMMIT.
- OK - `database\postgres\010_v47_rule_growth_marketplace_runtime.sql.no_drop`: Sem DROP TABLE/TYPE destrutivo.
- OK - `database\postgres\010_v47_rule_growth_marketplace_runtime.sql.no_raw_delete`: Sem DELETE FROM em migration de schema.
- OK - `database\postgres\010_v47_rule_growth_marketplace_runtime.sql.has_comments`: Arquivo contem comentarios ou COMMENT ON.
- OK - `database\postgres\011_v47_city_ops_delivery_mobility_security.sql.begin`: Migration contem BEGIN.
- OK - `database\postgres\011_v47_city_ops_delivery_mobility_security.sql.commit`: Migration contem COMMIT.
- OK - `database\postgres\011_v47_city_ops_delivery_mobility_security.sql.no_drop`: Sem DROP TABLE/TYPE destrutivo.
- OK - `database\postgres\011_v47_city_ops_delivery_mobility_security.sql.no_raw_delete`: Sem DELETE FROM em migration de schema.
- OK - `database\postgres\011_v47_city_ops_delivery_mobility_security.sql.has_comments`: Arquivo contem comentarios ou COMMENT ON.
- OK - `database\postgres\012_v47_core_services_health_jobs_pharmacy_events.sql.begin`: Migration contem BEGIN.
- OK - `database\postgres\012_v47_core_services_health_jobs_pharmacy_events.sql.commit`: Migration contem COMMIT.
- OK - `database\postgres\012_v47_core_services_health_jobs_pharmacy_events.sql.no_drop`: Sem DROP TABLE/TYPE destrutivo.
- OK - `database\postgres\012_v47_core_services_health_jobs_pharmacy_events.sql.no_raw_delete`: Sem DELETE FROM em migration de schema.
- OK - `database\postgres\012_v47_core_services_health_jobs_pharmacy_events.sql.has_comments`: Arquivo contem comentarios ou COMMENT ON.
- OK - `database\postgres\013_v47_expansion_assets_civic_impact.sql.begin`: Migration contem BEGIN.
- OK - `database\postgres\013_v47_expansion_assets_civic_impact.sql.commit`: Migration contem COMMIT.
- OK - `database\postgres\013_v47_expansion_assets_civic_impact.sql.no_drop`: Sem DROP TABLE/TYPE destrutivo.
- OK - `database\postgres\013_v47_expansion_assets_civic_impact.sql.no_raw_delete`: Sem DELETE FROM em migration de schema.
- OK - `database\postgres\013_v47_expansion_assets_civic_impact.sql.has_comments`: Arquivo contem comentarios ou COMMENT ON.
- PENDENTE - `database\mongodb\001_ai_social_telemetry.mongo.js.node_check`: comando excedeu 20s e foi interrompido
- PENDENTE - `database\mongodb\002_v47_log_iot_foundation.mongo.js.node_check`: comando excedeu 20s e foi interrompido
- PENDENTE - `database\mongodb\003_v47_field_ops_security_agenda.mongo.js.node_check`: comando excedeu 20s e foi interrompido
- OK - `modules.registry.validate`: Registry valido: 47 modulos.

## Como Aplicar Quando Houver Banco Disponivel

PowerShell ou terminal com `.env`/`.env.example` na raiz:

```bash
python scripts/valley_db_orchestrator.py apply-postgres
python scripts/valley_db_orchestrator.py apply-mongo
```

Override manual por variavel em Bash:

```bash
DATABASE_URL=postgresql://user:pass@host:5432/db python scripts/valley_db_orchestrator.py apply-postgres
MONGODB_URI=mongodb://localhost:27017/valley python scripts/valley_db_orchestrator.py apply-mongo
```

Override manual por variavel em PowerShell:

```powershell
$env:DATABASE_URL='postgresql://user:pass@host:5432/db'; python scripts/valley_db_orchestrator.py apply-postgres
$env:MONGODB_URI='mongodb://localhost:27017/valley'; python scripts/valley_db_orchestrator.py apply-mongo
```

Ambiente local com Docker Compose (o `apply-compose` ja executa `compose-up`):

```bash
python scripts/valley_db_orchestrator.py apply-compose
python scripts/valley_db_orchestrator.py report
python scripts/valley_db_orchestrator.py compose-down
```
