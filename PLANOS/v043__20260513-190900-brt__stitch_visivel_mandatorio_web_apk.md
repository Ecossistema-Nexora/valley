PROPOSITO: Corrigir a visibilidade real dos templates Stitch nos paineis web e APK Valley.
CONTEXTO: A v042 publicou a fonte da verdade Stitch, mas a entrada do admin ainda usava cache-buster antigo e o APK abria na experiencia anterior antes de mostrar os templates.
REGRAS: Tornar Stitch a primeira tela visivel, invalidar estado legado, nao deixar botoes mortos, validar web e rebuildar APK antes de enviar.

# v043 - Stitch Visivel Mandatorio Web e APK

## Resumo

- Forcar os paineis web a carregar assets `v043-stitch-mandatory-visible`.
- Abrir a aba Stitch P0 como padrao quando houver estado local antigo.
- Exibir prova Stitch ja na tela de login do admin.
- Tornar o APK iniciado diretamente pela tela Stitch P0 mobile.
- Regerar APK com versionamento maior e publicar nova release.

## Checklist

- [x] Identificar por que o usuario ainda via templates antigos.
- [x] Corrigir cache-buster e prova Stitch no login web.
- [x] Forcar aba Stitch P0 como entrada padrao e invalidar `localStorage` legado.
- [x] Tornar Stitch P0 mobile a tela inicial do APK com botoes funcionais.
- [x] Validar web, Flutter e links publicos. Substituido pela validacao v044 com fonte Stitch v2.
- [x] Gerar, publicar e enviar APK/PDF v043 pelo Telegram. Substituido pela release v044 com fonte Stitch v2.

## Evidencias

- `admin/index.html` ainda apontava para `v=036-release-blueprint`.
- `admin/app.js` respeitava `valley.adminSurfaceTab.v1` antigo e podia abrir `overview`.
- `frontend/flutter/lib/src/ui/valley_product_shell.dart` ainda iniciava no fluxo de vitrine anterior antes da trilha Stitch.

## Bloqueios

- Nenhum bloqueio tecnico local nesta etapa.

## Substituicao

- A v043 foi absorvida pela v044 porque o usuario forneceu `stitch_valley_erp (2).zip` como nova fonte da verdade antes da conclusao da entrega v043.

## Proxima Acao

- Concluir a release v044 com a fonte Stitch v2.
