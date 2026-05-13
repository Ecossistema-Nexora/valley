# v040 - Release Templates Stitch, APK e PDF

## Resumo

- Publicar todos os templates Stitch ERP no runtime web publico do Valley.
- Validar links locais e Cloudflare antes de atualizar o APK.
- Regenerar PDF ABNT de links, manifest de release e nova remessa APK v039.
- Enviar artefatos atualizados pelo Telegram quando a validacao concluir.

## Checklist

- [x] Publicar galeria e manifest dos 131 templates Stitch em `admin/stitch/20260513_valley_erp/`. Concluido em 2026-05-13 09:06:58 BRT.
- [x] Validar rotas locais e publicas Cloudflare dos templates. Concluido em 2026-05-13 09:10:10 BRT.
- [x] Regenerar PDF/Markdown release com links de Admin, Lojista, Usuario e Templates Stitch. Concluido em 2026-05-13 09:11:00 BRT.
- [x] Gerar APK atualizado split por ABI usando base publica Cloudflare validada. Concluido em 2026-05-13 09:16:20 BRT.
- [x] Enviar PDF, Markdown, manifests e APKs pelo Telegram. Concluido em 2026-05-13 09:19:20 BRT.

## Evidencias

- `tmp/runtime/valley-stitch-template-publication.json` registra `template_count=131` e URLs publicas esperadas.
- `docs/design/STITCH_VALLEY_TEMPLATE_PUBLICATION.md` lista P0 e todas as telas publicadas.
- `scripts/generate_valley_release_links_abnt_pdf.py` passou a incluir a secao `Templates Stitch` a partir do manifest runtime.
- Gate HTTP local e publico retornou 200 para indice, manifest e `valley_admin_central_1/code.html`.
- Gate Playwright abriu `https://admin.brasildesconto.com.br/stitch/20260513_valley_erp/` sem erros de console e salvou `output/playwright/stitch_templates_public_gate.png`.
- PDF/Markdown atualizados foram copiados para `admin/downloads/v039/` com SHA1.
- Build Flutter Android concluido com `build_name=1.0.8`, `build_number=55` e `VALLEY_PRODUCT_API_BASE_URL=https://admin.brasildesconto.com.br`.
- `apksigner verify --verbose` validou o APK `app-arm64-v8a-release.apk` com esquema v2.
- Gate Cloudflare pos-build retornou 200 para `healthz`, `product`, `api/product-shell` e galeria Stitch.
- Telegram retornou `ok=true` para `VALLEY_RELEASE_LINKS_MODULOS_ABNT.pdf`, `VALLEY_RELEASE_LINKS_MODULOS_ABNT.md`, `VALLEY_STITCH_TEMPLATE_PUBLICATION.json`, `VALLEY_APK_RELEASE_ABI_V039.json` e os tres APKs.

## Bloqueios

- Nenhum bloqueio local no momento.

## Proxima Acao

- Continuar a Onda 1: converter as primeiras telas P0 do Stitch para UI executavel no admin/Flutter, mantendo a galeria como referencia.
