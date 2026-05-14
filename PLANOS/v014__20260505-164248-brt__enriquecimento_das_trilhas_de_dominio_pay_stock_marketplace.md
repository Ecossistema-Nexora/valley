<!--
PROPOSITO: Documentar v014 20260505 164248 brt enriquecimento das trilhas de dominio pay stock marketplace no escopo operacional do Valley.
CONTEXTO: Este arquivo registra orientacoes, decisoes ou plano associado ao caminho PLANOS/v014__20260505-164248-brt__enriquecimento_das_trilhas_de_dominio_pay_stock_marketplace.md.
REGRAS: Manter informacao rastreavel, preservar nomenclatura Valley e atualizar ao mudar a rotina correspondente.
-->

# v014 - Enriquecimento Das Trilhas De Dominio Pay Stock Marketplace

## Resumo

- Enriquecer as trilhas por usuario com semantica de dominio e jornada.
- Fazer as acoes de `PAY`, `STOCK` e `MARKETPLACE` refletirem uma jornada comercial completa, e nao apenas eventos tecnicos isolados.

## Checklist

- [x] Mapear os pontos atuais onde as trilhas por usuario ja nascem. Concluido em 2026-05-05 16:42:48 BRT.
- [x] Adicionar metadados de jornada e acao de dominio nas trilhas persistidas. Concluido em 2026-05-05 16:42:48 BRT.
- [x] Emitir trilhas espelhadas entre `STOCK`, `MARKETPLACE` e `PAY` quando a jornada cruzar modulos. Concluido em 2026-05-05 16:42:48 BRT.
- [x] Passar a priorizar essa semantica nas leituras da home. Concluido em 2026-05-05 16:42:48 BRT.
- [x] Validar backend e contrato Dart atualizado. Concluido em 2026-05-05 16:42:48 BRT.
- [x] Atualizar este plano e consolidar a entrega. Concluido em 2026-05-05 16:42:48 BRT.

## Evidencias

- `USER_MODULE_TRAILS_PATH` agora recebe `domain_action`, `journey_stage` e `journey_key`.
- Eventos em item `STOCK` passam a gerar trilhas encadeadas para `STOCK`, `MARKETPLACE` e `PAY`.
- O smoke test confirmou pares como `MARKETPLACE:order_started:conversion`, `STOCK:offer_reserved:conversion` e `MARKETPLACE:offer_considered:consideration`.

## Bloqueios

- Nenhum bloqueio aberto.

## Proxima acao

- Avancar para a proxima camada: usar `journey_key` e `journey_stage` para agrupar visualmente as jornadas na UI e reduzir ainda mais os sinais genéricos remanescentes.
