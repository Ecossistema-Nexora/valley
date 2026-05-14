<!--
PROPOSITO: Documentar v039 20260513 085715 brt stitch erp inventory handoff no escopo operacional do Valley.
CONTEXTO: Este arquivo registra orientacoes, decisoes ou plano associado ao caminho PLANOS/v039__20260513-085715-brt__stitch_erp_inventory_handoff.md.
REGRAS: Manter informacao rastreavel, preservar nomenclatura Valley e atualizar ao mudar a rotina correspondente.
-->

# v039 - Stitch ERP Inventory Handoff

## Resumo

- Importar o ZIP `stitch_valley_erp (1).zip` como fonte primaria Stitch para o ERP Valley.
- Manter staging seguro, versionar o export bruto e publicar galeria web de referencia sem substituir a UI principal.
- Preparar a Onda 1 para handoff Figma e implementacao Flutter/admin sem quebrar o release v038.

## Checklist

- [x] Confirmar existencia e estrutura do ZIP Stitch. Concluido em 2026-05-13 08:52:00 BRT.
- [x] Criar staging ignorado por Git para assets brutos do export. Concluido em 2026-05-13 08:56:50 BRT.
- [x] Gerar inventario estruturado de telas, tokens e mapa de integracao. Concluido em 2026-05-13 08:56:50 BRT.
- [x] Classificar Onda 1 P0 por superficie Valley: Flutter, admin web, ERP lojista e usuario publico. Concluido em 2026-05-13 08:56:50 BRT.
- [x] Versionar assets brutos Stitch em `docs/design/stitch_exports/20260513_valley_erp`. Concluido em 2026-05-13 09:00:56 BRT.
- [x] Publicar todos os 131 templates Stitch em `admin/stitch/20260513_valley_erp`. Concluido em 2026-05-13 09:06:58 BRT.
- [x] Promover P0 para handoff Figma e iniciar conversao controlada das primeiras telas executaveis. Concluido em 2026-05-13 17:56:56 BRT via v041.

## Evidencias

- `scripts/import_stitch_valley_erp_export.py` importa o ZIP, valida path traversal, extrai em `tmp/stitch-import/`, preserva o export em `docs/design/stitch_exports/20260513_valley_erp/` e gera artefatos versionaveis.
- `.gitignore` passou a ignorar `tmp/stitch-import/`.
- `docs/design/stitch_valley_erp_inventory.json` registrou 131 telas: 9 `admin_web`, 44 `erp_lojista`, 57 `flutter_mobile`, 16 `usuario_publico` e 5 `shared_design`.
- `docs/design/STITCH_VALLEY_ERP_INVENTORY.md` registrou 21 telas P0 e listagem completa.
- `docs/design/stitch_valley_design_tokens.json` extraiu tokens de cor e tipografia do `DESIGN.md` do Stitch.
- `docs/design/STITCH_VALLEY_ERP_INTEGRATION_MAP.md` definiu a Onda 1 e os guardrails de implementacao.
- `scripts/publish_stitch_valley_templates.py` publicou 131 templates em `admin/stitch/20260513_valley_erp/`, gerou `manifest.json`, `index.html`, `tmp/runtime/valley-stitch-template-publication.json` e `docs/design/STITCH_VALLEY_TEMPLATE_PUBLICATION.md`.

## Bloqueios

- Handoff Figma remoto ainda depende de alvo Figma autenticado, mas a conversao executavel P0 foi concluida no painel web e Flutter pelo plano v041.
- Gate publico e APK da Onda 1 foram validados e publicados no v041.

## Proxima Acao

- Continuar pela Onda 2 P0/P1 do ERP lojista: pedidos, SKU, estoque, financeiro, integracoes e logistica no painel web antes de qualquer novo APK.
