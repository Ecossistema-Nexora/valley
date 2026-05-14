<!--
PROPOSITO: Documentar v041 20260513 095147 brt onda1 p0 stitch telas executaveis no escopo operacional do Valley.
CONTEXTO: Este arquivo registra orientacoes, decisoes ou plano associado ao caminho PLANOS/v041__20260513-095147-brt__onda1_p0_stitch_telas_executaveis.md.
REGRAS: Manter informacao rastreavel, preservar nomenclatura Valley e atualizar ao mudar a rotina correspondente.
-->

# v041 - Onda 1 P0 Stitch Telas Executaveis

## Resumo

- Converter os templates Stitch P0 em superficies reais do Valley.
- Comecar pelo web: Admin Central 1/2 e ERP do Lojista dentro de `admin/app.js` e `admin/styles.css`.
- Validar em navegador publico com Playwright sem erro de console e sem botao morto.
- Depois levar os P0 mobile para Flutter e gerar novo APK apenas apos a validacao web.
- Manter a rotina Gemini/Valley Automation ativa como checkpoint obrigatorio.

## Checklist

- [x] Mapear estrutura atual do admin web e pontos de insercao da Onda 1. Concluido em 2026-05-13 09:51:47 BRT.
- [x] Implementar superficie executavel Stitch P0 web no painel admin real. Concluido em 2026-05-13 10:00:40 BRT.
- [x] Validar HTTP local/publico e Playwright sem erros de console. Concluido em 2026-05-13 10:10:40 BRT.
- [x] Converter P0 mobile para Flutter: login, checkout, minhas compras e rastreio. Concluido em 2026-05-13 10:22:10 BRT.
- [x] Gerar APK atualizado somente apos web e Flutter passarem no gate. Concluido em 2026-05-13 10:36:20 BRT.
- [x] Acionar Gemini/Valley Automation e registrar evidencias. Concluido em 2026-05-13 10:38:20 BRT.

## Evidencias

- Templates publicados em `admin/stitch/20260513_valley_erp/`.
- Admin atual ja possui abas reais por `data-admin-pane`, `ADMIN_SURFACE_TABS` e renderizador `renderMerchantErp()`.
- O ponto de extensao web sera uma nova secao executavel no painel, com botoes ligados a funcoes reais de sincronizacao, navegacao, copia/export e abertura de workspaces.
- `admin/index.html` recebeu `stitchP0ExecutionSection` e link de topo `Stitch P0`.
- `admin/app.js` recebeu aba `Stitch P0`, `renderStitchP0Execution()` e `runStitchP0Action()` com ações reais.
- `admin/styles.css` recebeu layout responsivo para a superficie P0.
- `node --check admin/app.js` passou sem erro.
- HTTP validado com status `200` em `http://127.0.0.1:8085/`, `https://admin.brasildesconto.com.br/`, `/app.js` e `/styles.css`, com a secao `stitchP0ExecutionSection` presente.
- Playwright validou `https://admin.brasildesconto.com.br/` autenticado com sessao temporaria descartavel, console com `0` erros e comandos reais para `Sincronizar dados`, `Exportar resumo`, `Abrir galeria`, `Admin Central 1`, `Admin Central 2`, `ERP do Lojista`, `Workspaces`, `Produtos e SKU`, `Checkout` e `Integracoes`.
- Evidencias visuais geradas em `output/playwright/stitch_p0_executable_admin_desktop.png` e `output/playwright/stitch_p0_executable_admin_mobile.png`.
- Flutter recebeu a trilha mobile executavel `Login`, `Checkout`, `Compras` e `Rastreio` em `valley_product_shell.dart`, usando as telas existentes de identidade, checkout e area do cliente.
- `flutter analyze lib\src\ui\valley_product_shell.dart` passou sem issues.
- `frontend/flutter/pubspec.yaml` atualizado para `1.0.9+56` antes do rebuild do APK.
- `flutter build apk --release --split-per-abi --dart-define=VALLEY_PRODUCT_API_BASE_URL=https://admin.brasildesconto.com.br` gerou APKs `armeabi-v7a`, `arm64-v8a` e `x86_64`.
- Artefatos v041 publicados em `admin/downloads/v041/`, com APK recomendado `app-arm64-v8a-release.apk`, SHA1 `9B1DD76DC353C3BE18AFCB6CD9C45F0E2B536945`.
- `apksigner verify --verbose admin/downloads/v041/app-arm64-v8a-release.apk` validou assinatura v2.
- PDF ABNT atualizado em `admin/downloads/v041/VALLEY_RELEASE_LINKS_MODULOS_ABNT.pdf`, SHA1 `83CD3451B4248165DDE3D57DFC0CC2F68FCEA6A4`, incluindo `Templates Stitch` e `Downloads Release`.
- HEAD HTTP validou `https://admin.brasildesconto.com.br/downloads/v041/app-arm64-v8a-release.apk` com status `200`.
- `python scripts/codex_refactor_guide.py --mode release --hierarchy-file docs\specs\valley-front-end-final-product-proposal.md` acionou o Valley Module Automation Engine com `validate` e `admin` em modo mandatário.
- `python scripts/run_valley_gemini_refactor_loop.py loop --batch-size 5 --max-cycles 1 --engine-mode release` atualizou a rotina Gemini para `waiting_for_gemini`, com `160` pendencias e lote atual de `5` arquivos em `tmp/runtime/valley-gemini-current-task.md`.
- Telegram retornou `ok=true` para `admin/downloads/v041/app-arm64-v8a-release.apk`, `admin/downloads/v041/VALLEY_RELEASE_LINKS_MODULOS_ABNT.pdf` e mensagem com links v041.

## Bloqueios

- Nenhum bloqueio local no momento.

## Proxima Acao

- Aguardar sinal `GEMINI_DONE` do lote atual ou seguir para a proxima onda P0/P1 quando solicitado.
