# VALLEY Implementation Memorandum

Atualizado em `2026-05-01` para registrar, em um unico artefato, o que ja foi criado, integrado, publicado e validado no worktree atual do Valley.

## 1. Resumo executivo

O projeto Valley ja possui:

- banco hibrido modelado e validado com PostgreSQL + MongoDB;
- esteira local de deploy, seed, smoke test, snapshot e restore;
- painel administrativo publicado em dominio publico persistente;
- modulo `STOCK` operando com catalogo real, agrupamento por categoria e taxonomia Google;
- integracoes de marketplace e fornecedor com tokens persistidos em runtime local;
- aplicativo Flutter com build Android e Web;
- callbacks OAuth e webhooks publicados para os provedores que ja avancaram.

No estado atual, o ambiente combina:

- superficie publica de operacao e vitrine;
- cockpit admin para integracoes e runtime;
- sincronizacao real de catalogo para `Mercado Livre` e `CJDropshipping`;
- OAuth ativo em `Mercado Livre`, `Magalu` e `AliExpress`;
- orquestracao de eventos incrementais para CJ.

## 2. Superficies publicadas

### 2.1 Admin

- Dominio publico principal: `https://admin.brasildesconto.com.br`
- Healthcheck publico: `https://admin.brasildesconto.com.br/healthz`
- API admin data: `https://admin.brasildesconto.com.br/api/admin-data`

Estado observado no runtime:

- origin local em `http://127.0.0.1:8085`
- health local respondendo `200`
- health publico respondendo `200`

Runtime relacionado:

- [tmp/runtime/valley-admin-public-runtime.json](C:/Users/ereta/.codex/worktrees/VALLEY/tmp/runtime/valley-admin-public-runtime.json:1)

### 2.2 Product / Stock Web

- Vitrine publica: `https://admin.brasildesconto.com.br/product/`
- Product shell publico: `https://admin.brasildesconto.com.br/api/product-shell`
- Catalogo publico: `https://admin.brasildesconto.com.br/api/stock-catalog`

Runtime relacionado:

- [tmp/runtime/valley-product-public-runtime.json](C:/Users/ereta/.codex/worktrees/VALLEY/tmp/runtime/valley-product-public-runtime.json:1)

## 3. Frontend e experiencia de produto

### 3.1 Painel administrativo

Ja foi implementado:

- painel admin com publicacao externa persistente;
- areas de configuracao de integracoes;
- cockpit de fornecedores;
- endpoints de persistencia para integracoes;
- callbacks e webhooks de marketplace sob o mesmo origin.

Arquivos centrais:

- [admin/index.html](C:/Users/ereta/.codex/worktrees/VALLEY/admin/index.html:1)
- [admin/app.js](C:/Users/ereta/.codex/worktrees/VALLEY/admin/app.js:1)
- [scripts/serve_valley_admin.py](C:/Users/ereta/.codex/worktrees/VALLEY/scripts/serve_valley_admin.py:1)

### 3.2 Modulo STOCK

O modulo `STOCK` foi remodelado para operar como vitrine proprietaria Valley:

- sem mencao publica a fornecedores externos;
- agrupamento por categoria, nao por fornecedor;
- uso de taxonomia Google para classificacao;
- filtros por busca, categoria, colecao/modelo e faixa de preco;
- payload publico sanitizado, sem exposicao de `supplier_name` e `provider_key`.

No product shell atual:

- titulo: `Valley Stock | Catalogo proprietario`
- subtitulo: catalogo real multi-provedor com exposicao publica sem fornecedor

Arquivos centrais:

- [frontend/flutter/lib/src/data/product_api_models.dart](C:/Users/ereta/.codex/worktrees/VALLEY/frontend/flutter/lib/src/data/product_api_models.dart:1)
- [frontend/flutter/lib/src/data/product_api_repository.dart](C:/Users/ereta/.codex/worktrees/VALLEY/frontend/flutter/lib/src/data/product_api_repository.dart:1)
- [frontend/flutter/lib/src/ui/valley_product_shell.dart](C:/Users/ereta/.codex/worktrees/VALLEY/frontend/flutter/lib/src/ui/valley_product_shell.dart:1)

### 3.3 Aplicativo Flutter

Builds Android disponiveis:

- [app-release.apk](C:/Users/ereta/.codex/worktrees/VALLEY/frontend/flutter/build/app/outputs/flutter-apk/app-release.apk)
- [app-arm64-v8a-release.apk](C:/Users/ereta/.codex/worktrees/VALLEY/frontend/flutter/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk)
- [app-armeabi-v7a-release.apk](C:/Users/ereta/.codex/worktrees/VALLEY/frontend/flutter/build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk)
- [app-x86_64-release.apk](C:/Users/ereta/.codex/worktrees/VALLEY/frontend/flutter/build/app/outputs/flutter-apk/app-x86_64-release.apk)

O app ja foi alinhado para acesso externo pelo dominio publico do admin.

## 4. Integracoes de fornecedores e marketplaces

### 4.1 Mercado Livre

Estado:

- `enabled: true`
- ambiente: `production`
- auth: `oauth2`
- seller: `273569456`
- webhook publicado
- tokens persistidos em runtime local

Endpoints:

- callback: `https://admin.brasildesconto.com.br/integrations/mercadolivre/callback`
- notificacoes: `https://admin.brasildesconto.com.br/integrations/mercadolivre/notifications`

Evidencia de runtime:

- [tmp/runtime/valley-marketplace-oauth-runtime.json](C:/Users/ereta/.codex/worktrees/VALLEY/tmp/runtime/valley-marketplace-oauth-runtime.json:1)

### 4.2 CJDropshipping

Estado:

- `enabled: true`
- ambiente: `production`
- auth: `api_key`
- seller/openId: `36307`
- access token e refresh token ativos
- webhook publicado
- catalogo, estoque, preco e tracking integrados ao pipeline de `STOCK`

Endpoint:

- notificacoes: `https://admin.brasildesconto.com.br/integrations/cjdropshipping/notifications`

Automacao:

- webhook incremental por `pid/vid`
- indice `vid -> pid` persistido em runtime
- fallback por cadencia periodica

Arquivos centrais:

- [scripts/import_real_stock_catalog.py](C:/Users/ereta/.codex/worktrees/VALLEY/scripts/import_real_stock_catalog.py:1)
- [scripts/refresh_cj_stock_runtime.py](C:/Users/ereta/.codex/worktrees/VALLEY/scripts/refresh_cj_stock_runtime.py:1)
- [tmp/runtime/valley-stock-sync-state.json](C:/Users/ereta/.codex/worktrees/VALLEY/tmp/runtime/valley-stock-sync-state.json:1)

### 4.3 Magalu

Estado:

- `enabled: true`
- ambiente: `production`
- auth: `oauth2`
- client OAuth criado no IDM oficial
- consentimento concluido
- access token e refresh token persistidos em runtime local

Endpoints:

- authorize: `https://admin.brasildesconto.com.br/integrations/magalu/authorize`
- callback: `https://admin.brasildesconto.com.br/integrations/magalu/callback`

Artefatos:

- [tmp/runtime/valley-magalu-client-runtime.json](C:/Users/ereta/.codex/worktrees/VALLEY/tmp/runtime/valley-magalu-client-runtime.json:1)
- [tmp/runtime/valley-magalu-oauth-runtime.json](C:/Users/ereta/.codex/worktrees/VALLEY/tmp/runtime/valley-magalu-oauth-runtime.json:1)

### 4.4 AliExpress

Estado:

- `enabled: true`
- ambiente: `sandbox`
- auth: `oauth2`
- seller: `6266338639`
- app ainda em modo `Test`
- tokens persistidos em runtime local
- callback e webhook publicados

Endpoints:

- callback: `https://admin.brasildesconto.com.br/integrations/aliexpress/callback`
- notificacoes: `https://admin.brasildesconto.com.br/integrations/aliexpress/notifications`

### 4.5 Shopee, Amazon e Alibaba

Estado atual:

- ainda nao ativos
- placeholders mantidos no cockpit de integracoes
- sem tokens operacionais persistidos

## 5. Catalogo real do modulo STOCK

O runtime atual do catalogo contem:

- `4976` itens reais
- `3705` itens de `Mercado Livre`
- `1271` itens de `CJDropshipping`

Distribuicao principal por categoria:

- `Smartphones`: `1137`
- `Wearables`: `636`
- `Premium Tech`: `631`
- `Audio`: `617`
- `Creator Gear`: `589`
- `Smart Living`: `578`
- `Mobilidade`: `499`
- `Casa`: `289`

Importante:

- o runtime interno ainda guarda metadados de origem para a operacao;
- o endpoint publico sanitiza os campos de fornecedor antes de servir a vitrine.

Artefato:

- [tmp/runtime/valley-stock-real-catalog.json](C:/Users/ereta/.codex/worktrees/VALLEY/tmp/runtime/valley-stock-real-catalog.json:1)

## 6. Automacao operacional

### 6.1 Sync e webhooks

Ja implementado:

- fila de atualizacao assincrona;
- debounce para eventos repetidos;
- worker incremental para CJ;
- loop de seguranca por cadencia;
- callbacks OAuth com persistencia local de tokens;
- webhook handlers sob o mesmo `serve_valley_admin.py`.

### 6.2 Status observado no momento deste memorando

O worker de sync esta `running`, mas o ultimo resultado registrado em [tmp/runtime/valley-stock-sync-state.json](C:/Users/ereta/.codex/worktrees/VALLEY/tmp/runtime/valley-stock-sync-state.json:1) mostra falha por `HTTP 429` durante consulta externa.

Leitura correta:

- a automacao existe e esta conectada;
- existe limitacao real de rate limit do provedor/rota em ciclos especificos;
- isso nao invalida a integracao, mas exige tratamento de backoff e governanca de quota para operacao continua.

## 7. Base de dados e esteira de infraestrutura

Estado comprovado por [output/deployment/VALLEY_DEPLOYMENT_STATUS.md](C:/Users/ereta/.codex/worktrees/VALLEY/output/deployment/VALLEY_DEPLOYMENT_STATUS.md:1), regenerado em `2026-05-02T00:48:30.210949+00:00`:

- `34` migrations PostgreSQL declaradas;
- `5` scripts MongoDB declarados;
- `339` checagens totais;
- `2` pendencias operacionais externas no relatorio registrado;
- esteira local com `check`, `report`, `apply-compose`, `seed-compose`, `smoke-compose`, `snapshot-compose`, `snapshot-verify` e `restore-compose`;
- `47` pastas de modulo encontradas com artefatos de contrato e status.

Pendencias atuais observadas:

- Docker daemon local nao respondeu ao `docker info` dentro do timeout de 30s;
- `docker compose` excedeu 10s durante a checagem automatica, coerente com o daemon indisponivel no momento da validacao.

Documentos base:

- [output/deployment/VALLEY_DEPLOYMENT_STATUS.md](C:/Users/ereta/.codex/worktrees/VALLEY/output/deployment/VALLEY_DEPLOYMENT_STATUS.md:1)
- [output/deployment/VALLEY_PRODUCTION_MODE.md](C:/Users/ereta/.codex/worktrees/VALLEY/output/deployment/VALLEY_PRODUCTION_MODE.md:1)
- [output/module-roadmap/VALLEY_MODULE_ROADMAP.md](C:/Users/ereta/.codex/worktrees/VALLEY/output/module-roadmap/VALLEY_MODULE_ROADMAP.md:1)
- [output/module-roadmap/VALLEY_MODULE_CONTRACTS.md](C:/Users/ereta/.codex/worktrees/VALLEY/output/module-roadmap/VALLEY_MODULE_CONTRACTS.md:1)

## 8. Artefatos legais e de OAuth publicados

Paginas publicas criadas para flows de integracao:

- [admin/legal/terms-of-use.html](C:/Users/ereta/.codex/worktrees/VALLEY/admin/legal/terms-of-use.html:1)
- [admin/legal/privacy-policy.html](C:/Users/ereta/.codex/worktrees/VALLEY/admin/legal/privacy-policy.html:1)

Essas paginas ja foram usadas nos flows de criacao e consentimento da Magalu.

## 9. O que esta operacional de verdade

Ja esta operacional e validado:

- painel admin publico;
- vitrine web `STOCK`;
- APK Android gerado;
- OAuth `Mercado Livre`;
- OAuth `Magalu`;
- OAuth `AliExpress` em `sandbox`;
- auth `api_key` de `CJDropshipping`;
- importacao real de catalogo para `STOCK`;
- sincronizacao incremental de CJ;
- sanitizacao publica da origem do fornecedor na vitrine.

## 10. O que ainda nao pode ser tratado como finalizado

Ainda depende de trabalho complementar:

- `Shopee`, `Amazon` e `Alibaba` sem ativacao operacional;
- `AliExpress` ainda em `sandbox/test`, nao em producao final;
- tratamento mais robusto para `HTTP 429` no worker incremental CJ;
- endurecimento de seguranca para rotacao de segredos e limpeza de credenciais expostas em conversa;
- envio automatico universal para canais externos ainda nao comprovado em todos os casos;
- seller/account binding da Magalu ainda nao foi escrito como `sellerId` no runtime de integracao, embora o OAuth esteja concluido.

## 11. Proxima trilha recomendada

Ordem pragmatica:

1. endurecer o worker CJ contra `429` com backoff, fila e retry por janela;
2. promover `AliExpress` de `sandbox` para `production` quando o app sair de `Test`;
3. ativar `Shopee`, `Amazon` e `Alibaba` com o mesmo padrao de callback, token e runtime;
4. consolidar `sellerId` e metadados de tenant da Magalu no runtime operacional;
5. gerar um memorando executivo derivado deste, em versao curta, para diretoria ou parceiros.
