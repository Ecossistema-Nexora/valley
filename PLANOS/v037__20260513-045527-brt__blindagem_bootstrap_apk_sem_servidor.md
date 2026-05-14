<!--
PROPOSITO: Documentar v037 20260513 045527 brt blindagem bootstrap apk sem servidor no escopo operacional do Valley.
CONTEXTO: Este arquivo registra orientacoes, decisoes ou plano associado ao caminho PLANOS/v037__20260513-045527-brt__blindagem_bootstrap_apk_sem_servidor.md.
REGRAS: Manter informacao rastreavel, preservar nomenclatura Valley e atualizar ao mudar a rotina correspondente.
-->

# v037 - Blindagem Bootstrap APK Sem Servidor

## Resumo

- Corrigir o incidente em que o APK abre somente a tela de indisponibilidade quando o dominio publico fixo retorna erro Cloudflare.
- Fazer o app iniciar pela experiencia embarcada e usar rede apenas como camada de acao/runtime, sem bloquear a primeira tela.
- Regerar evidencias e artefatos de release apos a correcao.

## Checklist

- [x] Confirmar status do dominio publico e causa imediata do bloqueio de tela. Concluido em 2026-05-13 04:55:27 BRT.
- [x] Blindar o bootstrap Flutter para carregar shell/catalogo embarcado antes de qualquer chamada HTTP. Concluido em 2026-05-13 05:03:00 BRT.
- [x] Revalidar teste de bootstrap, analise segmentada e build Android/Web afetado. Concluido em 2026-05-13 06:35:01 BRT.
- [x] Publicar evidencias finais e atualizar `PLANOS/INDEX.md`. Concluido em 2026-05-13 06:35:01 BRT.

## Evidencias

- `https://brasildesconto.com.br/api/product-shell`, `https://brasildesconto.com.br/healthz` e `https://admin.brasildesconto.com.br/api/product-shell` retornaram HTTP 530 em 2026-05-13.
- `tmp/runtime/valley-admin-cloudflare.err.log` ainda registra `Unauthorized: Invalid tunnel secret`, mantendo o dominio fixo bloqueado ate renovacao segura do tunnel Cloudflare.
- O APK v037 contem os assets `valley_mvp_manifest.v1.json`, `valley_product_catalog.json` e `valley_stock_runtime_ptbr.json`, portanto o primeiro carregamento deve funcionar sem depender do endpoint publico.
- `frontend/flutter/lib/src/data/product_api_repository.dart` passou a preferir bootstrap embarcado sempre, manter fallback de manifest em memoria e retornar shell minimo se todos os assets falharem.
- `frontend/flutter/lib/src/data/product_api_models.dart` passou a tolerar listas de tags/galeria com valores nao-string, evitando falha de parse no catalogo.
- `dart analyze lib\src\data\product_api_models.dart lib\src\data\product_api_repository.dart lib\src\app\valley_super_app.dart` retornou sem issues.
- `flutter build web --release --dart-define=VALLEY_PRODUCT_API_BASE_URL=https://01e7dcdc3079ce.lhr.life` concluiu e `admin/product` foi atualizado.
- `admin/downloads/v037/VALLEY_RELEASE_LINKS_MODULOS_ABNT.pdf` foi regenerado com 6 paginas, 150 links clicaveis, SHA1 `2878A4C5F23C1CD9017867010BC1D8F974D51B5A` e reenviado pelo Telegram.
- `flutter build apk --release --split-per-abi --dart-define=VALLEY_PRODUCT_API_BASE_URL=https://01e7dcdc3079ce.lhr.life` concluiu para `armeabi-v7a`, `arm64-v8a` e `x86_64`.
- Os APKs `app-arm64-v8a-release.apk`, `app-armeabi-v7a-release.apk` e `app-x86_64-release.apk` foram copiados para `admin/downloads/v037`, tiveram SHA1 recalculado e foram enviados pelo Telegram.
- Validacao de conteudo do APK `app-arm64-v8a-release.apk` confirmou assets embarcados `valley_admin_data.json`, `valley_product_catalog.json` e `valley_stock_runtime_ptbr.json`.
- O runtime local `http://127.0.0.1:8085/api/product-shell` e o fallback Tailscale `http://100.109.240.100:8085/api/product-shell` retornaram HTTP 200; o tunel anonimo `localhost.run` oscilou para HTTP 503 depois de publicado.
- A rotina persistente Gemini/Codex foi criada com lotes de no maximo 5 arquivos, status em `tmp/runtime/valley-gemini-refactor-loop-status.json`, tarefa atual em `tmp/runtime/valley-gemini-current-task.md` e agendamento local `ValleyGeminiRefactorLoop`.

## Bloqueios

- O reparo definitivo do dominio fixo continua dependente de token Cloudflare/tunnel valido fora do git.
- O tunel publico anonimo `localhost.run` e temporario e oscilou durante a rodada; a blindagem do APK garante abertura offline da tela inicial, mas a URL publica fixa ainda precisa do reparo Cloudflare para estabilidade externa permanente.

## Proxima Acao

- Renovar o token/tunnel Cloudflare do dominio fixo para substituir os fallbacks temporarios e manter os endpoints publicos permanentes.
