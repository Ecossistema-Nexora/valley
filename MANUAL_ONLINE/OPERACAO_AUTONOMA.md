# Operacao Autonoma - Valley

Este documento define a esteira autonoma atual do projeto Valley.

Ela foi criada para desenvolver, validar, implantar e evoluir os 47 modulos sem depender de confirmacoes manuais repetitivas.

## Principio

A automacao deve fazer a melhor escolha segura dentro da arvore Valley.

Ela nao deve executar acoes destrutivas, apagar dados, vazar segredo, criar credenciais reais ou fazer `git push` automatico sem contexto de repositorio validado.

## Componentes

`config/modules_v47.json` e o registry dos 47 modulos.

`scripts/valley_module_automation.py` gera documentacao por modulo, roadmap e migration SQL de delivery registry.

Ele tambem gera `CONTRACT.md` por modulo e a matriz `output/module-roadmap/VALLEY_MODULE_CONTRACTS.md`.

`database/migrations.json` define a ordem oficial das migrations PostgreSQL e MongoDB.

`scripts/valley_db_orchestrator.py` valida ambiente, manifesto, artefatos dos modulos, SQL, Mongo script, registry e pode aplicar migrations quando banco estiver disponivel.

`docker-compose.yml` define Postgres e Mongo locais para validacao de implantacao.

`output/deployment/VALLEY_DEPLOYMENT_STATUS.md` e o relatorio operacional gerado pelo orquestrador.

`database/postgres/008_v47_foundation_commerce_operations.sql` e a primeira entrega de schema especifico dos modulos foundation de comercio/ERP.

`database/mongodb/002_v47_log_iot_foundation.mongo.js` e a primeira entrega NoSQL especifica de LOG, IoT e WMS sensor snapshots.

`database/postgres/009_v47_tech_legal_platform_contracts.sql` e a primeira entrega de schema especifico dos modulos foundation TECH e LEGAL.

`database/postgres/010_v47_rule_growth_marketplace_runtime.sql` e a entrega que fecha runtime de regras, growth, Pepitas, GOLD e validacao comercial/fisica.

`database/postgres/011_v47_city_ops_delivery_mobility_security.sql` e a entrega que aprofunda operacao de campo para Delivery, Mobility e Security.

`database/mongodb/003_v47_field_ops_security_agenda.mongo.js` e a entrega NoSQL que fecha dispatch, frota, sinais de seguranca e agenda inteligente.

## Ciclo Natural

1. Atualizar ou revisar o registry dos 47 modulos.
2. Rodar `python scripts/valley_module_automation.py validate`.
3. Rodar `python scripts/valley_module_automation.py sync`.
4. Rodar `python scripts/valley_module_automation.py sql`.
5. Rodar `python scripts/valley_db_orchestrator.py check`.
6. Rodar `python scripts/valley_db_orchestrator.py report`.
7. Atualizar o Manual Online.
8. Rodar `python scripts/generate_manual_pdf.py`.

`sync` deve manter `README.md`, `STATUS.md`, `CONTRACT.md`, `modules/INDEX.md`, roadmap e matriz de contratos alinhados.

`contracts` pode ser usado quando a mudanca for apenas na fronteira operacional dos modulos.

## Gate Minimo De Release Funcional

Nenhum release do backbone Valley deve ser tratado como pronto se os modulos abaixo nao estiverem com evidencia tecnica fechada em `STATUS.md`:

- `modules/08-pay/STATUS.md`
- `modules/07-marketplace/STATUS.md`
- `modules/10-services/STATUS.md`
- `modules/20-social/STATUS.md`
- `modules/46-chat/STATUS.md`

Sentido operacional de cada gate:

- `PAY`: prova que identidade, wallet e ledger aguentam a jornada financeira principal.
- `MARKETPLACE`: prova que a oferta comercial consegue nascer, ser precificada e ser publicada com governanca.
- `SERVICES`: prova que a plataforma vende trabalho/agenda real sem romper financeiro nem contrato.
- `SOCIAL`: prova que aquisicao e atribuicao funcionam fora do canal local puro.
- `CHAT`: prova que o follow-up e a operacao assistida conseguem reter usuario no ecossistema.

Sequencia recomendada do gate:

1. fechar status e testes de `PAY`
2. fechar status e testes de `MARKETPLACE`
3. fechar status e testes de `SERVICES`
4. fechar status e testes de `SOCIAL`
5. fechar status e testes de `CHAT`

Fila natural logo apos esse gate:

- `17-NEWS-PODCAST` para superficie publica e testes externos de conteudo
- `18-ADS` e `19-INFLUENCERS` para escalar growth
- `38-AGENDA` e `39-ADVISOR` para retencao inteligente sobre a base ja operacional

## Implantacao Local Com Docker

Quando o Docker daemon estiver disponivel, o fluxo local e:

```bash
python scripts/valley_db_orchestrator.py apply-compose
python scripts/valley_db_orchestrator.py report
python scripts/generate_manual_pdf.py
```

Esse fluxo sobe Postgres e Mongo, espera readiness real, executa o service `builder` do Docker Compose, aplica migrations e atualiza a evidencia operacional.

Quando quiser rodar o worker explicitamente:

```bash
docker compose --profile builder run --rm --build builder
```

## Implantacao Sem Docker

Quando houver banco externo e `.env`/`.env.example` estiverem na raiz:

```bash
python scripts/valley_db_orchestrator.py apply-postgres
python scripts/valley_db_orchestrator.py apply-mongo
```

Quando precisar sobrescrever manualmente as conexoes:

```bash
DATABASE_URL=postgresql://user:pass@host:5432/db python scripts/valley_db_orchestrator.py apply-postgres
MONGODB_URI=mongodb://host:27017/valley python scripts/valley_db_orchestrator.py apply-mongo
```

No PowerShell:

```powershell
$env:DATABASE_URL='postgresql://user:pass@host:5432/db'; python scripts/valley_db_orchestrator.py apply-postgres
$env:MONGODB_URI='mongodb://host:27017/valley'; python scripts/valley_db_orchestrator.py apply-mongo
```

## Politica De Descarte

Ideias inviaveis devem ser descartadas quando:

- conflitam com `users` e `wallets` como nucleo absoluto;
- exigem segredo real que nao existe no ambiente;
- armazenam segredo bruto, API key, webhook secret, IP bruto, fingerprint bruto ou fallback PIN em texto claro;
- liberam cashback/Pepita sem cap relacional ligado a margem ou validacao de venda;
- duplicam schema legado como `platform.users`;
- tentam mover log bruto de alto volume para PostgreSQL;
- fazem deploy, commit, push ou delete automatico sem trilha segura.

## Estado Atual

Em `2026-04-24`, a esteira segura confirmou `329` checagens com `4` pendencias reais de ambiente.

As pendencias comprovadas nessa leitura foram: `psql` ausente no `PATH`, `mongosh` ausente no `PATH`, `docker info` sem resposta em `30s` e `docker compose` interrompido por timeout.

O ambiente local tem Docker Compose, mas nao tem `psql`, `mongosh` nem `make` no PATH.

Por isso, a validacao principal agora e estatica e documental quando o Docker daemon nao responde.

Quando Docker daemon e imagens estiverem prontos, `apply-compose` passa a ser o caminho natural de validacao runtime porque ele mesmo sobe o ambiente antes de aplicar.

O ultimo relatorio gerado deve ser lido em `output/deployment/VALLEY_DEPLOYMENT_STATUS.md`, porque o total muda quando novas migrations entram no manifesto.

O painel admin fica em `admin/index.html` e consome `admin/valley_admin_data.js`, gerado automaticamente pela esteira de modulos e pelo report do banco.

Na sincronizacao de `2026-04-24`, `admin/valley_admin_data.js` e `admin/valley_admin_data.json` passaram a refletir essas pendencias reais no bloco `deployment_summary`.

Na mesma rodada, os pacotes `database/domain-delivery/priority-domains/<dominio>/ddl_complement.sql` e `operational_seed.sql` dos dominios prioritarios ativos foram regenerados para ficar coerentes com `module_evolution_backlog`, `domain_delivery_artifacts` e `domain_event_contracts`.

Essa troca e deliberada: a esteira agora prefere views e seeds gerados pelo registry canonico a SQL operacional manual que envelhece fora do backlog.
