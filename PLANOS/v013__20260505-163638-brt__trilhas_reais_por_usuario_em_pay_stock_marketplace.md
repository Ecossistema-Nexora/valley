# v013 - Trilhas Reais Por Usuario Em Pay Stock Marketplace

## Resumo

- Reduzir dependencia de sinais compartilhados/globalizados na home.
- Persistir e consumir trilhas por usuario para `PAY`, `STOCK` e `MARKETPLACE`.

## Checklist

- [x] Mapear os pontos de escrita existentes para jornadas `PAY`, `STOCK` e `MARKETPLACE`. Concluido em 2026-05-05 16:36:38 BRT.
- [x] Criar persistencia normalizada de trilha por usuario no backend. Concluido em 2026-05-05 16:41:19 BRT.
- [x] Passar a alimentar `recent_actions`, `module_signals` e `recommendations` com essas trilhas quando houver sessao. Concluido em 2026-05-05 16:41:19 BRT.
- [x] Expor as trilhas no payload da home para evolucao futura da UI. Concluido em 2026-05-05 16:41:19 BRT.
- [x] Validar backend e contratos atualizados. Concluido em 2026-05-05 16:41:19 BRT.
- [x] Atualizar este plano e consolidar a entrega. Concluido em 2026-05-05 16:41:19 BRT.

## Evidencias

- `product_interest`, `open_media` e `checkout_started` ja passam pelo backend e podem ser normalizados por `user_id`.
- `checkout attempts` ja carregam `user_context`, o que permite consolidar `PAY` sem depender apenas do runtime global.
- `USER_MODULE_TRAILS_PATH` passou a persistir trilhas por usuario para `PAY`, `STOCK` e `MARKETPLACE`.
- O smoke test confirmou `user_module_trails` no payload da home e `recent_actions` preferindo trilhas autenticadas em vez do feed global de checkout.

## Bloqueios

- Nenhum bloqueio aberto.

## Proxima acao

- Avancar para a proxima camada: enriquecer as trilhas por usuario com eventos realmente dedicados de `PAY`, `STOCK` e `MARKETPLACE`, para reduzir ainda mais o peso do contexto global restante.
