# VALLEY Production Mode

Auditoria operacional para levar o Valley do estado de esteira local para um modo de producao controlado.

Escopo desta frente:
- banco hibrido PostgreSQL + MongoDB
- snapshots e restore
- smoke tests de validacao
- exposicao externa do painel admin
- MVP commerce com `STOCK`, dropshipping inteligente, `WMS`, `MARKETPLACE`, `PAY`, `PLUG` e `DOCS`
- painel admin com identidade visual Valley e configuracao de APIs de marketplaces/fornecedores

Regra de seguranca:
- nao aplicar nada em banco remoto sem credenciais explicitamente existentes, verificadas e validadas pelo operador
- nao alterar `database/postgres`, `database/mongodb`, `database/domain-delivery`, `database/migrations.json` ou `scripts/valley_db_orchestrator.py`

## Estado Executado Em 2026-04-21

- `apply-compose`: OK com 33 migrations PostgreSQL e 4 scripts MongoDB.
- `seed-compose`: OK com seed operacional dos dominios prioritarios e seed Mongo.
- `smoke-compose`: OK, incluindo os checks `dropshipping_provider_configs`, `dropshipping_product_chain`, `dropshipping_pricing_append_only_seed` e `dropshipping_provider_health_view`.
- `snapshot-compose`: OK em `output/snapshots/valley_db_snapshot_20260421T202041Z`.
- `snapshot-verify`: OK com hashes:
  - Postgres: `8629742cb83a6801a7823fa343c57316de46aec4779fe42f9dd469062210b811`
  - MongoDB: `7245aa8ad8496fcdae190a2fd9085be6d144143fc34a9130372275e98cef28ef`
- Admin local: OK em `http://127.0.0.1:8080`.
- Healthcheck admin: OK em `http://127.0.0.1:8080/healthz`.
- Payload admin: OK em `http://127.0.0.1:8080/api/admin-data`.

## Dropshipping Inteligente Incorporado Ao MVP

Artefatos implantados:

- Spec controlado: `docs/specs/valley-dropshipping-production-blueprint.md`
- Migration: `database/postgres/033_v47_stock_dropshipping_production_blueprint.sql`
- Template seguro de integracoes: `config/integrations/marketplace_api_integrations.template.json`
- Backlog MVP regenerado: `output/module-roadmap/VALLEY_MVP_EXECUTION_BACKLOG.md`

Tabelas e views novas:

- `dropshipping_provider_configs`
- `dropshipping_product_sources`
- `dropshipping_market_price_snapshots`
- `dropshipping_pricing_decisions`
- `dropshipping_supplier_orders`
- `dropshipping_jobs`
- `v_stock_dropshipping_production_ops`
- `v_stock_dropshipping_provider_health`

Regras implantadas:

- `BR-STOCK-DROP-001`: dropshipping sem prejuizo.
- `BR-STOCK-DROP-002`: consulta externa API-first sem IA.
- `BR-STOCK-DROP-003`: pausa automatica de produto inviavel.

## O que ja existe

- Orquestracao completa da esteira em `scripts/valley_db_orchestrator.py` com `check`, `report`, `apply-postgres`, `apply-mongo`, `compose-up`, `apply-compose`, `seed-compose`, `smoke-compose`, `snapshot-compose`, `snapshot-verify` e `restore-compose`.
- Compose local com `postgres:16-alpine`, `mongo:7`, builder e tailscale em `docker-compose.yml`.
- Baseline de variaveis em `.env.example` e overrides operacionais em `config/VALLEY_RELEASE_ENV.example`.
- Runbooks de acesso externo em `output/deployment/VALLEY_EXTERNAL_ACCESS.md` e `config/VALLEY_FIRST_CONNECTION_CHECKLIST.md`.
- Politica de banco e snapshot em `database/README.md`.
- Scaffold remoto opinado em `infra/aws/`, `k8s/`, `helm/valley/` e `.github/workflows/`.
- Imagem minima buildavel para o cockpit/admin em `Dockerfile`, com probes `/healthz` e `/readyz`.
- Base de billing Stripe alinhada ao nucleo relacional Valley em `billing/schema.sql`, sem recriar `users`.

Referencias de leitura:
- `scripts/valley_db_orchestrator.py:2630`
- `database/README.md:137`
- `database/README.md:173`
- `database/README.md:182`
- `docker-compose.yml:6`
- `.env.example:2`
- `config/VALLEY_RELEASE_ENV.example:11`

## Comandos seguros para modo producao local

1. Validar ambiente e dependencias:

```powershell
python scripts/valley_db_orchestrator.py check
python scripts/valley_db_orchestrator.py report
```

2. Subir a esteira local com bancos em Docker:

```powershell
python scripts/valley_db_orchestrator.py compose-up
python scripts/valley_db_orchestrator.py apply-compose
```

3. Aplicar seeds operacionais e validar o bloco seedado:

```powershell
python scripts/valley_db_orchestrator.py seed-compose
python scripts/valley_db_orchestrator.py smoke-compose
```

4. Exportar snapshot operacional apos o smoke:

```powershell
python scripts/valley_db_orchestrator.py snapshot-compose
python scripts/valley_db_orchestrator.py snapshot-verify
```

5. Restauro controlado apenas quando houver necessidade de recuperar estado local:

```powershell
python scripts/valley_db_orchestrator.py restore-compose
```

6. Subir o painel admin externo por ngrok:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/start_valley_admin_public.ps1
python scripts/show_valley_public_urls.py
```

## Variaveis que importam para producao

- `DATABASE_URL`
- `MONGODB_URI`
- `VALLEY_AUTO_APPLY`
- `VALLEY_NGROK_AUTHTOKEN`
- `VALLEY_NGROK_ADMIN_DOMAIN`
- `TAILSCALE_AUTHKEY`
- `TS_AUTHKEY`
- `VALLEY_TELEGRAM_TOKEN`
- `VALLEY_TELEGRAM_CHAT_ID`

Baseline local atual:
- PostgreSQL local em `localhost:55432`
- MongoDB local em `localhost:57017`
- ngrok local em `127.0.0.1:4040`
- admin local em `127.0.0.1:8080`

## Runbook operacional

### Fase 1: preparar

- confirmar que `.env` existe apenas na maquina do operador
- manter `VALLEY_AUTO_APPLY=false` ate o final da validacao
- preencher `DATABASE_URL` e `MONGODB_URI` com origem real ou Compose local
- definir `VALLEY_NGROK_AUTHTOKEN` se a publicacao externa for necessaria
- definir `VALLEY_NGROK_ADMIN_DOMAIN` apenas se houver dominio reservado

### Fase 2: validar

- rodar `check`
- rodar `report`
- revisar o relatorio em `output/deployment/VALLEY_DEPLOYMENT_STATUS.md`
- corrigir falhas de ferramenta, env ou manifesto antes de aplicar qualquer migration

### Fase 3: implantar localmente

- subir `compose-up`
- rodar `apply-compose`
- rodar `seed-compose`
- rodar `smoke-compose`

### Fase 4: capturar prova operacional

- rodar `snapshot-compose`
- rodar `snapshot-verify`
- guardar o manifesto gerado em `output/snapshots/`

### Fase 5: expor externamente

- subir o painel com `start_valley_admin_public.ps1`
- listar URLs com `show_valley_public_urls.py`
- validar `/healthz` e `/api/admin-data` na URL publica

## Bloqueios reais para producao remota

1. Agora existe scaffold remoto para AWS/EKS, RDS, Redis, Helm e GitHub Actions, mas o MongoDB de producao ainda depende de um cluster externo informado via `MONGODB_URI`.
2. O `docker-compose.yml` atual continua sendo local e usa portas expostas de desenvolvimento, entao nao substitui o stack remoto.
3. As credenciais base em `.env.example` sao de desenvolvimento e nao podem ser tratadas como segredo de producao.
4. Ainda falta plugar secret manager real para `DATABASE_URL`, `MONGODB_URI` e chaves Stripe.
5. Ainda falta politica de rotacao automatica de credenciais e runbook fechado de incident response.
6. Backup agendado, retencao e restore testado do ambiente remoto ainda nao estao comprovados neste worktree.
7. Ainda falta definir lock de migracao e janela formal de deploy remoto para evitar colisao entre operadores.

## Gaps que precisam fechar antes de chamar de producao real

- definir URLs finais de bancos gerenciados
- definir fornecedor real do MongoDB de producao e publicar `MONGODB_URI` via secret manager
- definir estrategia de backup, retencao e restore testado
- definir observabilidade minima: logs, metricas, alertas e healthchecks
- definir segredo centralizado para `DATABASE_URL`, `MONGODB_URI` e tokens externos
- definir procedimento de deploy para migracoes sem conflito com outros agentes
- definir janela de manutencao e rollback com snapshot valido

## Proximo passo automatico recomendado

1. Confirmar o alvo do ambiente remoto: VPC, cloud gerenciada ou banco local endurecido.
2. Se o alvo for local endurecido, criar um segundo documento com hardening de host, backup e observabilidade.
3. Se o alvo for cloud, mapear provisao, seguranca e runbook de corte para Postgres e Mongo.
4. Depois disso, transformar este plano em checklist executavel por fase.
