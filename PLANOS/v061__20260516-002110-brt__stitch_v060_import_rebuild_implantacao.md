<!--
PROPOSITO: Registrar a implantacao real da entrega Stitch v060 como fonte ativa.
CONTEXTO: O usuario determinou assumir o controle do Stitch, validar conformidade, importar e aplicar a proposta diretamente no projeto.
REGRAS: Substituir artefatos ativos antigos, manter segredos fora do git e registrar rebuild/validacao sem pedir confirmacao.
-->

# v061 - Stitch v060 import, rebuild e implantacao

## Escopo

Transformar a proposta gerada no projeto Stitch `projects/12516070127536900621` na fonte ativa do Valley, substituindo a galeria/export `20260513_valley_erp_v2`, atualizando admin, Flutter web, contratos, runtime local e documentacao de entrega.

## Checklist

- [x] Renovar os assets das 15 telas pelo MCP Stitch sem gravar `STITCH_API_KEY`.
- [x] Publicar a galeria ativa em `admin/stitch/20260516_valley_erp_v060/`.
- [x] Gerar manifesto publico em `admin/stitch/20260516_valley_erp_v060/manifest.json`.
- [x] Atualizar `config/design/valley_stitch_source_of_truth.json`.
- [x] Atualizar assets Flutter/admin product com `20260516_valley_erp_v060`.
- [x] Remover os diretorios ativos antigos `admin/stitch/20260513_valley_erp_v2` e `docs/design/stitch_exports/20260513_valley_erp_v2`.
- [x] Atualizar `admin/app.js` e `admin/index.html` para abrir e executar a entrega v060.
- [x] Rebuildar o painel admin com `scripts/valley_admin_builder.py build`.
- [x] Rebuildar Flutter Web e sincronizar `admin/product`.
- [x] Validar JSONs, manifesto, JS admin, Python scripts, gate local e DOM HTTP da galeria/produto.
- [x] Validar `frontend/flutter/lib/src/ui/valley_product_shell.dart` com `dart analyze`.
- [x] Registrar bloqueios tecnicos do build Android release e da captura Playwright/Chrome sem deixar processos vivos.

## Artefatos Entregues

- `scripts/publish_stitch_v060_project.py`
- `admin/stitch/20260516_valley_erp_v060/`
- `docs/design/stitch_exports/20260516_valley_erp_v060/`
- `docs/design/STITCH_VALLEY_V060_PUBLICATION.md`
- `docs/design/stitch_valley_erp_v060_inventory.json`
- `tmp/runtime/valley-stitch-v060-publication.json`
- `config/design/valley_stitch_source_of_truth.json`
- `frontend/flutter/assets/data/valley_stitch_source_of_truth.json`
- `admin/product/assets/assets/data/valley_stitch_source_of_truth.json`
- `admin/app.js`
- `admin/index.html`
- `frontend/flutter/lib/src/ui/valley_product_shell.dart`

## Validacoes

- `python scripts\publish_stitch_v060_project.py`: publicou 15 telas.
- `python scripts\valley_admin_builder.py build`: regenerou `admin/valley_admin_data.json` e `admin/valley_admin_data.js`.
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\publish_valley_product_web.ps1 -BaseHref /product/ -ApiBaseUrl https://admin.brasildesconto.com.br`: build web release concluido e sincronizado em `admin/product`.
- `python -m json.tool` nos JSONs de fonte e manifesto: ok.
- `python -m py_compile` nos scripts alterados: ok.
- `node --check admin\app.js`: ok.
- Gate local `scripts.validate_valley_release_gate.local_file_checks()`: 11/11 checks ok.
- HTTP local `http://127.0.0.1:8085/stitch/20260516_valley_erp_v060/manifest.json`: `template_count=15`, grupos `admin=1`, `lojista=5`, `usuario=7`, `entregador=2`.
- DOM HTTP da galeria: 15 cards, onboarding e entregador presentes.
- Produto web compilado: `main.dart.js` contem `20260516_valley_erp_v060` e nao contem `20260513_valley_erp_v2`.
- `dart analyze lib\src\ui\valley_product_shell.dart`: no issues found.
- Evidencia visual da galeria: `output/playwright/stitch_v060_gallery_chrome.png`.

## Bloqueios Registrados

- `flutter analyze` completo nao retornou em 10 minutos; a analise direcionada do arquivo alterado passou sem issues.
- `flutter build apk --release --dart-define=VALLEY_PRODUCT_API_BASE_URL=https://admin.brasildesconto.com.br` ficou preso ate o timeout de 20 minutos sem diagnostico; processos Flutter/Gradle iniciados por esse build foram encerrados.
- Playwright via `npx` travou durante execucao; a validacao de runtime foi substituida por HTTP/DOM local e Chrome headless para a galeria. A captura do produto Flutter web ficou branca antes da hidratacao e foi descartada; o produto foi validado por HTTP/JS.

## Estado

Entrega v060 ativa para web/admin/produto. Android release final deve ser reexecutado pelo fluxo `END-USER-BUILD` quando o objetivo for gerar todos os artefatos finais de usuario, incluindo APK, desktop, PDF e Telegram.
