PROPOSITO: Assumir `stitch_valley_erp (2).zip` como a fonte da verdade ativa para paineis web e APK Valley.
CONTEXTO: O usuario informou que os paineis web e o APK ainda exibiam templates antigos; o novo ZIP precisa substituir referencias anteriores, publicar galeria v2, validar web e gerar release atualizada.
REGRAS: Usar somente `20260513_valley_erp_v2` como fonte ativa, descartar referencias v1, validar web antes do APK, nao deixar botoes mortos e entregar APK/PDF pelo Telegram.

# v044 - Stitch v2 Fonte Da Verdade Web e APK

## Resumo

- Importar e versionar `stitch_valley_erp (2).zip`.
- Publicar a galeria canonica `admin/stitch/20260513_valley_erp_v2/`.
- Atualizar contratos web, Flutter, docs e assets embarcados para a v2.
- Remover a versao anterior como caminho ativo.
- Validar painel web, build Flutter/APK e PDF atualizado.
- Enviar APK e PDF pelo Telegram.

## Checklist

- [x] Localizar ZIP novo, registrar SHA1 e importar 121 telas Stitch v2.
- [x] Publicar galeria e manifesto v2 em `admin/stitch/20260513_valley_erp_v2/`.
- [x] Atualizar painel web, cache-buster, JSONs, docs e Flutter para `20260513_valley_erp_v2`.
- [x] Remover caminhos ativos da fonte Stitch anterior e marcar v043 como substituida.
- [x] Validar painel web local e dominio publico com Playwright/HTTP.
- [x] Rodar checks de codigo, JSON e Flutter.
- [ ] Gerar release v044 com APK, manifesto, hashes e PDF de links atualizado.
- [ ] Enviar APK/PDF pelo Telegram e registrar evidencias.

## Evidencias

- ZIP fonte: `C:\Users\ereta\Downloads\stitch_valley_erp (2).zip`.
- SHA1: `ECC3D8A453E23BB013F96AE265F8BEEBCE11093B`.
- Manifesto ativo: `admin/stitch/20260513_valley_erp_v2/manifest.json`.
- Totais: 121 templates, 19 P0.
- HTTP local: `http://127.0.0.1:8085/` e `/stitch/20260513_valley_erp_v2/manifest.json` retornaram 200.
- HTTP publico: `https://admin.brasildesconto.com.br/` e `/stitch/20260513_valley_erp_v2/manifest.json` retornaram 200.
- Playwright publico: `output/playwright/v044-stitch-v2-public-dom.png`, sem erro de console, aba Stitch visivel, manifesto v2 com 121 templates e 19 P0.
- `node --check admin/app.js`: OK.
- JSONs de contrato e manifesto v2: OK.
- `flutter analyze --no-pub lib\src\ui\valley_product_shell.dart`: sem issues.

## Bloqueios

- Nenhum bloqueio web ativo apos recuperacao do tunnel Cloudflare.

## Proxima Acao

- Gerar a release v044 com APK, manifesto, hashes e PDF.
