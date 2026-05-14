<!--
PROPOSITO: Documentar v012 20260505 163032 brt segmentacao por modulo e perfil na home mvp no escopo operacional do Valley.
CONTEXTO: Este arquivo registra orientacoes, decisoes ou plano associado ao caminho PLANOS/v012__20260505-163032-brt__segmentacao_por_modulo_e_perfil_na_home_mvp.md.
REGRAS: Manter informacao rastreavel, preservar nomenclatura Valley e atualizar ao mudar a rotina correspondente.
-->

# v012 - Segmentacao Por Modulo E Perfil Na Home MVP

## Resumo

- Evoluir o `/api/me/home` para expor `profile_context` e `module_signals`.
- Tornar a home Flutter explicitamente segmentada por perfil e por modulo, sem depender apenas de metricas e recomendacoes globais.

## Checklist

- [x] Mapear a modelagem necessaria no backend e no Flutter para segmentacao por perfil e modulo. Concluido em 2026-05-05 16:30:32 BRT.
- [x] Implementar `profile_context` role-aware no payload da home. Concluido em 2026-05-05 16:34:52 BRT.
- [x] Implementar `module_signals` com leitura real do runtime e recorte por perfil. Concluido em 2026-05-05 16:34:52 BRT.
- [x] Ajustar a `ValleyHomeShell` para renderizar foco do perfil e sinais por modulo. Concluido em 2026-05-05 16:34:52 BRT.
- [x] Validar backend e arquivos Dart alterados. Concluido em 2026-05-05 16:34:52 BRT.
- [x] Atualizar este plano e consolidar a entrega. Concluido em 2026-05-05 16:34:52 BRT.

## Evidencias

- A `OverviewPage` hoje ja consome `metrics`, `identity_score`, `recommendations` e `recent_actions`, o que permite encaixar segmentacao extra sem refatorar o shell inteiro.
- O runtime atual ja fornece sinais suficientes para `PAY`, `STOCK`, `MARKETPLACE`, `CHAT` e `MOVE`.
- `guest` passou a receber `PAY, MARKETPLACE, CHAT`; `merchant` passou a receber `STOCK, MARKETPLACE, PAY, CHAT` no payload `module_signals`.
- O smoke test confirmou `profile_context.audience_key = customer` e `merchant`, com foco comercial distinto para lojista.

## Bloqueios

- Nenhum bloqueio aberto.

## Proxima acao

- Avancar para segmentacao mais fina dentro de cada modulo, com trilhas realmente por usuario e por dominio quando `PAY`, `STOCK`, `MARKETPLACE`, `CHAT` e `MOVE` expuserem eventos dedicados e persistidos por conta.
