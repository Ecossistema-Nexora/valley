# v005 - Configuracao Total Previewjs E Rebuild Admin Product

## Resumo

- Configurar de forma persistente a extensao oficial `zenclabs.previewjs` no workspace do VALLEY.
- Registrar com clareza os limites da ferramenta neste repo, que hoje e centrado em Flutter e admin estatico.
- Rebuildar os artefatos estaticos de `admin/product` a partir do Flutter web.

## Checklist

- [x] Confirmar a extensao oficial e a documentacao publica do Preview.js. Concluido em 2026-05-05 09:06:03 BRT.
- [x] Registrar a recomendacao da extensao no workspace. Concluido em 2026-05-05 09:06:03 BRT.
- [x] Persistir a documentacao do fluxo e dos limites da ferramenta no repo. Concluido em 2026-05-05 09:06:03 BRT.
- [x] Rebuildar `admin/product` a partir de `frontend/flutter`. Concluido em 2026-05-05 09:07:30 BRT.
- [x] Validar o resultado do rebuild e fechar o plano. Concluido em 2026-05-05 09:07:30 BRT.

## Evidencias

- `.vscode/extensions.json` recomenda `zenclabs.previewjs`.
- `.cursor/rules/design.mdc` agora cobre Preview.js como ferramenta secundaria de inspecao.
- `docs/tooling/previewjs_codex_setup.md` documenta instalacao, limites e uso no VALLEY.
- `code --install-extension zenclabs.previewjs` concluiu com sucesso e instalou `zenclabs.previewjs v1.30.1`.
- `scripts/publish_valley_product_web.ps1` rebuildou o Flutter web e sincronizou `frontend/flutter/build/web` para `admin/product`.
- `admin/product/index.html` foi atualizado em 2026-05-05 09:07:30 BRT.
- O build web concluiu com warning de wasm dry run no pacote `flutter_tts_web`, sem impedir a publicacao estavel atual em JS.

## Bloqueios

- O proprio site do Preview.js informa que o projeto nao esta mais sendo mantido.
- O repo atual nao possui uma superficie principal React/Vue/Solid/Svelte/Preact para tirar valor pleno da extensao.

## Proxima acao

- Se quiser perseguir compatibilidade futura com wasm web, o proximo ajuste tecnico esta no pacote `flutter_tts_web` indicado pelo warning do build.
