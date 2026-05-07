# v032 - Retomada Gate MVP Producao

## Resumo

- Retomar a sequencia exata da entrega MVP Valley a partir do ultimo plano concluido (`v031`), sem reiniciar frentes ja fechadas.
- Converter o estado atual em gate de producao: contratos `/me/*`, home Flutter, runtime publico, build web, build Android e evidencias de release.

## Checklist

- [x] Auditar `PLANOS/INDEX.md` e identificar o ultimo checkpoint operacional valido. Concluido em 2026-05-07 01:27:35 BRT.
- [x] Confirmar que a sequencia natural apos `v031` e gate de producao do MVP, nao nova especificacao de produto. Concluido em 2026-05-07 01:27:35 BRT.
- [x] Validar backend local e contratos MVP: `/api/me/home`, `/api/me/recent-actions`, `/api/me/recommendations`, `/api/me/identity-score`, `/api/product-shell`. Concluido em 2026-05-07 01:33:00 BRT.
- [x] Validar persistencia de preferencias da home via `PUT /api/me/home/preferences`. Concluido em 2026-05-07 01:34:02 BRT.
- [x] Verificar Registro.br/Cloudflare e gerar mapa de subdominios por modulo. Concluido em 2026-05-07 01:39:32 BRT.
- [x] Ajustar home do admin para somente botoes e manter paginas/workspaces de modulos independentes. Concluido em 2026-05-07 01:39:32 BRT.
- [x] Validar Flutter em modo release: analise estatica segmentada e build web. Concluido em 2026-05-07 01:46:00 BRT.
- [x] Aplicar politica desta instancia para aprovar automaticamente todo o catalogo importado, sem bloqueio por preco menor que concorrencia. Concluido em 2026-05-07 02:02:00 BRT.
- [x] Validar que o runtime/admin expõe o catalogo importado como aprovado sem fila manual. Concluido em 2026-05-07 02:03:00 BRT.
- [x] Confirmar catalogo importado embarcado no app e rebuildar Android em modo release com split por ABI. Concluido em 2026-05-07 02:34:35 BRT.
- [x] Enviar APK ABI pelo Telegram com link do painel admin e instrucao de credenciais sem expor senha em arquivos do repositorio. Concluido em 2026-05-07 02:37:18 BRT.
- [x] Validar Android em modo release com split por ABI quando necessario. Concluido em 2026-05-07 02:34:35 BRT.
- [x] Renovar ou confirmar runtime publico e registrar URL/manifests atualizados. Concluido em 2026-05-07 02:42:00 BRT.
- [ ] Auditar todas as funcoes visiveis do APK/admin e tornar operacionais as que ainda dependerem de implementacao ou integracao real.
- [ ] Registrar evidencias finais e marcar este plano como concluido quando o MVP estiver demonstravel em modo de producao.

## Evidencias

- `PLANOS/INDEX.md` mostra `v031` como ultimo checkpoint funcional da trilha MVP/home.
- `v031` concluiu `action_path` autenticado em `recent_actions` para eventos operacionais com endpoints reais.
- `docs/specs/valley-mvp-delivery-plan.md` define o MVP como home premium, preferencias, acoes recentes, Identity Score, specs de identidade e demonstracao publica sem botoes mortos.
- `docs/specs/valley-mvp-p0-ownership-backlog.md` define o gate final: home, APIs `/me/*`, Identity Score, specs `spec-first` e fluxo publico demonstravel.
- Runtime local admin iniciado em `http://127.0.0.1:8103`.
- Probes locais retornaram `200` para `/api/me/home`, `/api/me/recent-actions`, `/api/me/recommendations`, `/api/me/identity-score` e `/api/product-shell`.
- Fluxo autenticado descartavel de produto retornou `201` em `/api/auth/register`, `200` em `/api/auth/login` e `200` em `PUT /api/me/home/preferences`, persistindo `STOCK`, `MARKETPLACE` e `CHAT`.
- `admin/app.js` alterado para fazer a raiz do admin voltar para `home`, deixar a visao geral apenas como launchpad de botoes e mover a listagem detalhada de workspaces para a aba `Modulos`.
- `admin/index.html` ajustado para descrever a home do painel como botoes e marcar `moduleWorkspaceDirectory` na aba `modules`.
- `admin/styles.css` recebeu `.launchpad-button` para botoes de acesso sem cards detalhados na home.
- `scripts/plan_valley_module_subdomains.py` criado para gerar/aplicar registros DNS Cloudflare por modulo sem gravar credenciais.
- `output/deployment/valley-module-subdomains.json` gerado com `56` registros CNAME planejados apontando para `admin.brasildesconto.com.br`.
- Validacoes executadas: `node --check admin/app.js`, `python -m py_compile scripts/serve_valley_admin.py scripts/plan_valley_module_subdomains.py`, `GET /` e `GET /app.js` no admin local retornaram `200`.
- `dart analyze lib/src/data/product_api_repository.dart lib/src/ui/valley_home_shell.dart lib/src/app/valley_super_app.dart` retornou `No issues found!`.
- `flutter build web --release --dart-define=VALLEY_PRODUCT_API_BASE_URL=http://127.0.0.1:8103` concluiu e gerou `frontend/flutter/build/web`.
- O build web reportou apenas alertas de dry-run Wasm em dependencia `flutter_tts`; o build JavaScript release foi concluido.
- `config/stock_publication_policy.json` criado com `auto_approve_imported_catalog=true`, `ignore_retail_price_advantage=true` e aprovacao de referencias de marketplace nesta instancia MVP.
- `scripts/serve_valley_admin.py` passou a ler `config/stock_publication_policy.json` e sobrescrever a fila de publicacao do catalogo importado para `Aprovado automaticamente`.
- Runtime local admin reiniciado em `http://127.0.0.1:8103` apos a politica.
- `GET /api/admin-imported-products-pricing` retornou `items_total=630`, `approved_total=630`, `review_total=0`, `do_not_publish_total=0`, `benchmark_reference_total=0`, `auto_approve=true` e `ignore_retail_price_advantage=true`.
- `frontend/flutter/assets/data/valley_stock_runtime_ptbr.json` contem `630` itens STOCK importados, mesmo total retornado por `GET /api/stock-catalog`.
- Build Android split ABI gerou `frontend/flutter/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`, `app-armeabi-v7a-release.apk` e `app-x86_64-release.apk` com timestamp de 2026-05-07 02:34 BRT.
- APK `app-arm64-v8a-release.apk` enviado pelo Telegram via `scripts/valley_communication_bridge.py send-telegram-document` com retorno `ok=true`.
- Runtime publico ativo via Cloudflare Quick Tunnel em `https://sharing-vital-nashville-folding.trycloudflare.com`; o dominio fixo `https://admin.brasildesconto.com.br` respondeu `530` porque o token de named tunnel carregado esta invalido.
- Manifestos atualizados: `tmp/runtime/valley-admin-public-runtime.json`, `tmp/runtime/valley-product-public-runtime.json` e `tmp/runtime/valley-product-web-publication.json`.
- Login admin validado local e publico para `@anderson` com papel `SUPER_ADMIN` e `is_admin=true`; senha nao foi gravada em texto no repositorio.

## Bloqueios

- `PLANOS/INDEX.md` possui entradas antigas duplicadas `v019`/`v020` referentes a uma trilha de banco; elas serao preservadas como historico e nao usadas como ultimo checkpoint MVP.
- `wrangler` esta instalado, mas nao autenticado nesta sessao.
- `cloudflared` esta instalado, mas sem certificado local em `~/.cloudflared`.
- Nenhum `CLOUDFLARE_API_TOKEN`, `CF_API_TOKEN`, `CLOUDFLARE_ZONE_ID` ou `CLOUDFLARE_ACCOUNT_ID` esta carregado no ambiente atual. A aplicacao real dos DNS fica bloqueada ate existir token API/zone ID seguro fora do git.
- `flutter analyze` completo ficou mais de 5 minutos em execucao e estourou timeout; a validacao segmentada dos arquivos centrais passou, e o build web release concluiu.

## Proxima acao

- Auditar as funcoes visiveis do APK/admin e transformar qualquer fluxo incompleto em operacao real antes de fechar evidencias finais.
