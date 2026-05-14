PROPOSITO: Executar a Onda 2 P0/P1 do ERP lojista Valley a partir dos templates Stitch ja publicados.
CONTEXTO: A Onda 1 v041 transformou Admin Central 1/2 e ERP do Lojista em telas executaveis web, Flutter e APK; a proxima etapa aprofunda rotinas operacionais reais no painel web.
REGRAS: Web primeiro, validar em navegador, nao gerar APK sem mudanca mobile real, manter Gemini/Valley Automation como checkpoint obrigatorio.

# v042 - Onda 2 ERP Lojista P0/P1 Executavel

## Resumo

- Aprofundar o ERP lojista em telas operacionais executaveis no admin real.
- Priorizar pedidos, cadastro de SKU, estoque/inventario, financeiro, integracoes e logistica.
- Remover qualquer comportamento de botao morto na nova camada.
- Validar JavaScript, HTTP e navegador antes de considerar Flutter/APK.
- Manter o loop Gemini em paralelo com lotes maximos de 5 arquivos.

## Checklist

- [x] Criar plano v042 e fechar o handoff pendente do v039 com evidencia do v041. Concluido em 2026-05-13 17:57:00 BRT.
- [x] Mapear a superficie ERP atual e definir a primeira fatia P0/P1 web. Concluido em 2026-05-13 18:05:00 BRT.
- [x] Implementar rotinas executaveis de pedidos, SKU, estoque, financeiro, integracoes e logistica em `admin/app.js`. Concluido em 2026-05-13 18:10:00 BRT.
- [x] Ajustar responsividade e densidade operacional em `admin/styles.css`. Concluido em 2026-05-13 18:10:00 BRT.
- [x] Validar `node --check`, HTTP local/publico e Playwright sem erro de console. Concluido em 2026-05-13 18:34:00 BRT.
- [x] Acionar `codex_refactor_guide.py`, atualizar `PLANOS/INDEX.md` e preservar o lote Gemini atual. Concluido em 2026-05-13 18:36:00 BRT.

## Evidencias

- Plano iniciado a partir do fechamento do v041 e do estado `waiting_for_gemini` em `tmp/runtime/valley-gemini-refactor-loop-status.json`.
- `admin/app.js` passou a declarar `STITCH_SOURCE_OF_TRUTH` como mandatorio para web e APK, descartando variacoes anteriores como referencia ativa.
- `admin/styles.css` recebeu a camada responsiva do command center ERP P0/P1.
- `config/design/valley_stitch_source_of_truth.json`, `docs/design/STITCH_VALLEY_SOURCE_OF_TRUTH.md` e `frontend/flutter/assets/data/valley_stitch_source_of_truth.json` registram a decisao persistente.
- `flutter build apk --release --split-per-abi --dart-define=VALLEY_PRODUCT_API_BASE_URL=https://admin.brasildesconto.com.br` gerou a release v042.
- Links publicos v042 retornaram `200 OK` para APK ARM64, APK ARMv7, APK x86_64, PDF, manifesto APK e manifesto Stitch.
- Telegram recebeu o APK ARM64, o PDF ABNT atualizado e a mensagem com links publicos v042.
- `python scripts\run_valley_gemini_refactor_loop.py loop --batch-size 5 --max-cycles 1 --engine-mode release` preservou o lote atual em `waiting_for_gemini`.

## Bloqueios

- Gemini ainda nao sinalizou `GEMINI_DONE` para o lote estrutural atual; a rotina fica preservada sem bloquear a frente web. Pendencias atuais: 160, sendo 4 renomeacoes e 156 headers estruturados.

## Proxima Acao

- Aguardar o sinal `GEMINI_DONE` do lote estrutural atual ou executar a proxima onda funcional Stitch P1/P2.
