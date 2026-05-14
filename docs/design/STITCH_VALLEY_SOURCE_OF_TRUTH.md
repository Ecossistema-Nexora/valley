PROPOSITO: Registrar a decisao mandataria de fonte da verdade visual e funcional para os paineis web e APK Valley.
CONTEXTO: O export Stitch `stitch_valley_erp (2).zip` foi versionado, publicado e convertido em superficies executaveis na Onda 1; a Onda 2 passa a descartar variacoes anteriores como referencia ativa.
REGRAS: Usar Stitch `20260513_valley_erp_v2` como fonte obrigatoria, validar web antes de APK, manter artefatos publicos e nao reintroduzir telas antigas como produto ativo.

# Stitch Valley Source Of Truth

## Decisao

O pacote Stitch `20260513_valley_erp_v2` passa a ser a fonte da verdade obrigatoria para:

- paineis web em `admin/`;
- ERP lojista executavel;
- trilhas mobile embarcadas no APK;
- PDF de links e release publico.

Qualquer variacao anterior de tela, copy, layout ou fluxo deixa de ser referencia ativa de produto. O pacote `20260513_valley_erp` fica obsoleto e nao deve ser usado por painel web, APK, PDF ou release.

## Artefatos Canonicos

- Configuracao persistente: `config/design/valley_stitch_source_of_truth.json`.
- Manifesto publico: `admin/stitch/20260513_valley_erp_v2/manifest.json`.
- Galeria publica: `admin/stitch/20260513_valley_erp_v2/`.
- Flutter asset: `frontend/flutter/assets/data/valley_stitch_source_of_truth.json`.
- Painel executavel: `admin/app.js` e `admin/styles.css`.
- APK executavel: `frontend/flutter/lib/src/ui/valley_product_shell.dart`.

## Hierarquia de Diretórios

- `admin/stitch/20260513_valley_erp_v2/`: publicacao canonica dos templates Stitch.
- `admin/app.js`: aplicacao das telas web executaveis a partir do manifesto Stitch.
- `admin/styles.css`: densidade visual e responsividade das superficies executaveis.
- `config/design/`: contratos persistentes de fonte da verdade e design.
- `docs/design/`: decisoes, mapas de integracao e evidencias de handoff.
- `frontend/flutter/assets/data/`: payloads embarcados no APK.
- `frontend/flutter/lib/src/ui/`: implementacao mobile/web Flutter que consome a decisao Stitch.
- `admin/downloads/v*/`: releases publicas com APK, PDF, manifesto e hashes.

## Regra De Publicacao

1. Toda tela P0/P1 nova deve apontar para uma chave Stitch do manifesto.
2. Web deve ser validado primeiro com HTTP e Playwright.
3. APK so deve ser gerado depois de validar a UI mobile ou a mudanca embarcada.
4. O PDF de release deve listar links publicos atuais.
5. O loop Gemini/Valley Automation continua como checkpoint mandatatorio.
