# Valley Deployment Status

Gerado em UTC: `2026-04-21T13:04:39.193240+00:00`.

Total de checagens: `181`.
Falhas ou pendencias: `0`.

## Resultado

- OK - `tool.python_runtime`: C:\Users\ereta\AppData\Local\Programs\Python\Python312\python.exe
- OK - `tool.node`: C:\Users\ereta\AppData\Local\Microsoft\WinGet\Packages\OpenJS.NodeJS.LTS_Microsoft.Winget.Source_8wekyb3d8bbwe\node-v24.14.1-win-x64\node.EXE
- OK - `tool.psql`: C:\Users\ereta\.codex\worktrees\VALLEY\tools\bin\psql.CMD
- OK - `tool.mongosh`: C:\Users\ereta\.codex\worktrees\VALLEY\tools\bin\mongosh.CMD
- OK - `tool.docker`: C:\Program Files\Docker\Docker\resources\bin\docker.EXE
- OK - `env.DATABASE_URL`: configurado via .env
- OK - `env.MONGODB_URI`: configurado via .env
- OK - `tool.docker_daemon`: 29.3.1
- OK - `tool.docker_compose`: Docker Compose version v5.1.1
- OK - `manifest.postgres_present`: 19 migrations PostgreSQL declaradas.
- OK - `manifest.mongodb_present`: 4 scripts MongoDB declarados.
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
- OK - `postgres.014.exists`: database/postgres/014_v47_expansion_tourism_bio_energy.sql
- OK - `postgres.014.order`: dependencias OK
- OK - `postgres.015.exists`: database/postgres/015_v47_module_blueprints_registry.sql
- OK - `postgres.015.order`: dependencias OK
- OK - `postgres.016.exists`: database/postgres/016_v47_execution_backlog_seed.sql
- OK - `postgres.016.order`: dependencias OK
- OK - `postgres.017.exists`: database/postgres/017_v47_priority_domain_delivery_packages.sql
- OK - `postgres.017.order`: dependencias OK
- OK - `postgres.018.exists`: database/postgres/018_v47_platform_developer_business_ddl.sql
- OK - `postgres.018.order`: dependencias OK
- OK - `postgres.019.exists`: database/postgres/019_v47_logistics_erp_operations_business_ddl.sql
- OK - `postgres.019.order`: dependencias OK
- OK - `mongodb.mongo-001.exists`: database/mongodb/001_ai_social_telemetry.mongo.js
- OK - `mongodb.mongo-001.order`: dependencias OK
- OK - `mongodb.mongo-002.exists`: database/mongodb/002_v47_log_iot_foundation.mongo.js
- OK - `mongodb.mongo-002.order`: dependencias OK
- OK - `mongodb.mongo-003.exists`: database/mongodb/003_v47_field_ops_security_agenda.mongo.js
- OK - `mongodb.mongo-003.order`: dependencias OK
- OK - `mongodb.mongo-004.exists`: database/mongodb/004_v47_expansion_media_wellness_frontier.mongo.js
- OK - `mongodb.mongo-004.order`: dependencias OK
- OK - `modules.artifacts.directories`: 47 pastas de modulo encontradas.
- OK - `modules.artifacts.readme`: todos os README.md existem
- OK - `modules.artifacts.status`: todos os STATUS.md existem
- OK - `modules.artifacts.contract`: todos os CONTRACT.md existem
- OK - `modules.artifacts.roadmap`: output\module-roadmap\VALLEY_MODULE_ROADMAP.md
- OK - `modules.artifacts.contracts_summary`: output\module-roadmap\VALLEY_MODULE_CONTRACTS.md
- OK - `modules.artifacts.execution_backlog`: output\module-roadmap\VALLEY_DOMAIN_EXECUTION_BACKLOG.md
- OK - `modules.artifacts.priority_delivery_plan`: output\module-roadmap\VALLEY_PRIORITY_DOMAIN_DELIVERY_PLAN.md
- OK - `modules.artifacts.priority_delivery_sql`: 7 arquivos ddl_complement.sql em database\domain-delivery\priority-domains
- OK - `modules.artifacts.priority_delivery_contracts`: 7 contratos JSON em contracts\events\priority-domains
- OK - `seed.database\seeds\postgres\001_v47_expansion_tourism_bio_energy_seed.sql.exists`: database\seeds\postgres\001_v47_expansion_tourism_bio_energy_seed.sql
- OK - `seed.database\seeds\postgres\002_v47_priority_domain_delivery_packages_seed.sql.exists`: database\seeds\postgres\002_v47_priority_domain_delivery_packages_seed.sql
- OK - `seed.database\seeds\mongodb\001_v47_expansion_media_wellness_frontier_seed.mongo.js.exists`: database\seeds\mongodb\001_v47_expansion_media_wellness_frontier_seed.mongo.js
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
- OK - `database\postgres\014_v47_expansion_tourism_bio_energy.sql.begin`: Migration contem BEGIN.
- OK - `database\postgres\014_v47_expansion_tourism_bio_energy.sql.commit`: Migration contem COMMIT.
- OK - `database\postgres\014_v47_expansion_tourism_bio_energy.sql.no_drop`: Sem DROP TABLE/TYPE destrutivo.
- OK - `database\postgres\014_v47_expansion_tourism_bio_energy.sql.no_raw_delete`: Sem DELETE FROM em migration de schema.
- OK - `database\postgres\014_v47_expansion_tourism_bio_energy.sql.has_comments`: Arquivo contem comentarios ou COMMENT ON.
- OK - `database\postgres\015_v47_module_blueprints_registry.sql.begin`: Migration contem BEGIN.
- OK - `database\postgres\015_v47_module_blueprints_registry.sql.commit`: Migration contem COMMIT.
- OK - `database\postgres\015_v47_module_blueprints_registry.sql.no_drop`: Sem DROP TABLE/TYPE destrutivo.
- OK - `database\postgres\015_v47_module_blueprints_registry.sql.no_raw_delete`: Sem DELETE FROM em migration de schema.
- OK - `database\postgres\015_v47_module_blueprints_registry.sql.has_comments`: Arquivo contem comentarios ou COMMENT ON.
- OK - `database\postgres\016_v47_execution_backlog_seed.sql.begin`: Migration contem BEGIN.
- OK - `database\postgres\016_v47_execution_backlog_seed.sql.commit`: Migration contem COMMIT.
- OK - `database\postgres\016_v47_execution_backlog_seed.sql.no_drop`: Sem DROP TABLE/TYPE destrutivo.
- OK - `database\postgres\016_v47_execution_backlog_seed.sql.no_raw_delete`: Sem DELETE FROM em migration de schema.
- OK - `database\postgres\016_v47_execution_backlog_seed.sql.has_comments`: Arquivo contem comentarios ou COMMENT ON.
- OK - `database\postgres\017_v47_priority_domain_delivery_packages.sql.begin`: Migration contem BEGIN.
- OK - `database\postgres\017_v47_priority_domain_delivery_packages.sql.commit`: Migration contem COMMIT.
- OK - `database\postgres\017_v47_priority_domain_delivery_packages.sql.no_drop`: Sem DROP TABLE/TYPE destrutivo.
- OK - `database\postgres\017_v47_priority_domain_delivery_packages.sql.no_raw_delete`: Sem DELETE FROM em migration de schema.
- OK - `database\postgres\017_v47_priority_domain_delivery_packages.sql.has_comments`: Arquivo contem comentarios ou COMMENT ON.
- OK - `database\postgres\018_v47_platform_developer_business_ddl.sql.begin`: Migration contem BEGIN.
- OK - `database\postgres\018_v47_platform_developer_business_ddl.sql.commit`: Migration contem COMMIT.
- OK - `database\postgres\018_v47_platform_developer_business_ddl.sql.no_drop`: Sem DROP TABLE/TYPE destrutivo.
- OK - `database\postgres\018_v47_platform_developer_business_ddl.sql.no_raw_delete`: Sem DELETE FROM em migration de schema.
- OK - `database\postgres\018_v47_platform_developer_business_ddl.sql.has_comments`: Arquivo contem comentarios ou COMMENT ON.
- OK - `database\postgres\019_v47_logistics_erp_operations_business_ddl.sql.begin`: Migration contem BEGIN.
- OK - `database\postgres\019_v47_logistics_erp_operations_business_ddl.sql.commit`: Migration contem COMMIT.
- OK - `database\postgres\019_v47_logistics_erp_operations_business_ddl.sql.no_drop`: Sem DROP TABLE/TYPE destrutivo.
- OK - `database\postgres\019_v47_logistics_erp_operations_business_ddl.sql.no_raw_delete`: Sem DELETE FROM em migration de schema.
- OK - `database\postgres\019_v47_logistics_erp_operations_business_ddl.sql.has_comments`: Arquivo contem comentarios ou COMMENT ON.
- OK - `database\mongodb\001_ai_social_telemetry.mongo.js.node_check`: node --check OK
- OK - `database\mongodb\002_v47_log_iot_foundation.mongo.js.node_check`: node --check OK
- OK - `database\mongodb\003_v47_field_ops_security_agenda.mongo.js.node_check`: node --check OK
- OK - `database\mongodb\004_v47_expansion_media_wellness_frontier.mongo.js.node_check`: node --check OK
- OK - `database\seeds\postgres\001_v47_expansion_tourism_bio_energy_seed.sql.begin`: Migration contem BEGIN.
- OK - `database\seeds\postgres\001_v47_expansion_tourism_bio_energy_seed.sql.commit`: Migration contem COMMIT.
- OK - `database\seeds\postgres\001_v47_expansion_tourism_bio_energy_seed.sql.no_drop`: Sem DROP TABLE/TYPE destrutivo.
- OK - `database\seeds\postgres\001_v47_expansion_tourism_bio_energy_seed.sql.no_raw_delete`: Sem DELETE FROM em migration de schema.
- OK - `database\seeds\postgres\001_v47_expansion_tourism_bio_energy_seed.sql.has_comments`: Arquivo contem comentarios ou COMMENT ON.
- OK - `database\seeds\postgres\002_v47_priority_domain_delivery_packages_seed.sql.begin`: Migration contem BEGIN.
- OK - `database\seeds\postgres\002_v47_priority_domain_delivery_packages_seed.sql.commit`: Migration contem COMMIT.
- OK - `database\seeds\postgres\002_v47_priority_domain_delivery_packages_seed.sql.no_drop`: Sem DROP TABLE/TYPE destrutivo.
- OK - `database\seeds\postgres\002_v47_priority_domain_delivery_packages_seed.sql.no_raw_delete`: Sem DELETE FROM em migration de schema.
- OK - `database\seeds\postgres\002_v47_priority_domain_delivery_packages_seed.sql.has_comments`: Arquivo contem comentarios ou COMMENT ON.
- OK - `database\seeds\mongodb\001_v47_expansion_media_wellness_frontier_seed.mongo.js.node_check`: node --check OK
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

Seeds minimos e smoke checks do bloco expansion aplicado:

```bash
python scripts/valley_db_orchestrator.py seed-compose
python scripts/valley_db_orchestrator.py smoke-compose
```

Exportar snapshot operacional do banco aplicado no Compose:

```bash
python scripts/valley_db_orchestrator.py snapshot-compose
```

Verificar integridade do snapshot mais recente antes de restore:

```bash
python scripts/valley_db_orchestrator.py snapshot-verify
```

Restaurar o snapshot mais recente no Compose local:

```bash
python scripts/valley_db_orchestrator.py restore-compose
```
