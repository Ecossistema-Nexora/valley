# v037 - Blindagem Bootstrap APK Sem Servidor

## Resumo

- Corrigir o incidente em que o APK abre somente a tela de indisponibilidade quando o dominio publico fixo retorna erro Cloudflare.
- Fazer o app iniciar pela experiencia embarcada e usar rede apenas como camada de acao/runtime, sem bloquear a primeira tela.
- Regerar evidencias e artefatos de release apos a correcao.

## Checklist

- [x] Confirmar status do dominio publico e causa imediata do bloqueio de tela. Concluido em 2026-05-13 04:55:27 BRT.
- [ ] Blindar o bootstrap Flutter para carregar shell/catalogo embarcado antes de qualquer chamada HTTP.
- [ ] Revalidar teste de bootstrap, analise segmentada e build Android/Web afetado.
- [ ] Publicar evidencias finais e atualizar `PLANOS/INDEX.md`.

## Evidencias

- `https://brasildesconto.com.br/api/product-shell`, `https://brasildesconto.com.br/healthz` e `https://admin.brasildesconto.com.br/api/product-shell` retornaram HTTP 530 em 2026-05-13.
- `tmp/runtime/valley-admin-cloudflare.err.log` ainda registra `Unauthorized: Invalid tunnel secret`, mantendo o dominio fixo bloqueado ate renovacao segura do tunnel Cloudflare.
- O APK v037 contem os assets `valley_mvp_manifest.v1.json`, `valley_product_catalog.json` e `valley_stock_runtime_ptbr.json`, portanto o primeiro carregamento deve funcionar sem depender do endpoint publico.

## Bloqueios

- O reparo definitivo do dominio fixo continua dependente de token Cloudflare/tunnel valido fora do git.

## Proxima Acao

- Finalizar a blindagem do bootstrap e gerar novo APK validado.
