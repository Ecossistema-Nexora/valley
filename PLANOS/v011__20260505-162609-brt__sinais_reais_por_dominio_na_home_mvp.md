<!--
PROPOSITO: Documentar v011 20260505 162609 brt sinais reais por dominio na home mvp no escopo operacional do Valley.
CONTEXTO: Este arquivo registra orientacoes, decisoes ou plano associado ao caminho PLANOS/v011__20260505-162609-brt__sinais_reais_por_dominio_na_home_mvp.md.
REGRAS: Manter informacao rastreavel, preservar nomenclatura Valley e atualizar ao mudar a rotina correspondente.
-->

# v011 - Sinais Reais Por Dominio Na Home MVP

## Resumo

- Substituir a camada inicial sintetica do `/api/me/home` por sinais reais do runtime do Valley.
- Usar checkout, stock sync, bridge, runtime publico, telemetry e release summary como fontes operacionais reais para score, recomendacoes, metricas e acoes recentes.

## Checklist

- [x] Mapear as fontes reais do runtime para a home MVP. Concluido em 2026-05-05 16:26:09 BRT.
- [x] Reescrever a agregacao backend para usar sinais reais por dominio. Concluido em 2026-05-05 16:29:15 BRT.
- [x] Ajustar filtragem de eventos comerciais para nao misturar historico global com sessao autenticada. Concluido em 2026-05-05 16:29:15 BRT.
- [x] Validar o payload `/api/me/home` com smoke test local. Concluido em 2026-05-05 16:29:15 BRT.
- [x] Atualizar este plano e consolidar a entrega. Concluido em 2026-05-05 16:29:15 BRT.

## Evidencias

- `tmp/runtime/valley-stock-sync-state.json` expõe fila ativa e ultima falha real por `HTTP 429` no CJ.
- `tmp/runtime/valley-mercadopago-status.json` mostra checkout pronto com validacao `ok`, PIX e `account_money`.
- `tmp/runtime/valley-product-public-runtime.json` e `tmp/runtime/valley-product-web-publication.json` confirmam runtime publico saudavel.
- `tmp/runtime/codex-live-status.json`, `tmp/runtime/bridge-work-status.json` e `tmp/runtime/move-telemetry.jsonl` trazem sinais reais de bridge, progresso e telemetria MOVE.

## Bloqueios

- Nenhum bloqueio aberto nesta entrega.

## Proxima acao

- Avancar para o proximo enriquecimento: trocar os sinais ainda globais por sinais por modulo e por perfil de usuario quando cada dominio expuser eventos dedicados.
