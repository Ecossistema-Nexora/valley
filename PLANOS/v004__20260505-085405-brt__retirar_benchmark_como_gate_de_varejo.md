<!--
PROPOSITO: Documentar v004 20260505 085405 brt retirar benchmark como gate de varejo no escopo operacional do Valley.
CONTEXTO: Este arquivo registra orientacoes, decisoes ou plano associado ao caminho PLANOS/v004__20260505-085405-brt__retirar_benchmark_como_gate_de_varejo.md.
REGRAS: Manter informacao rastreavel, preservar nomenclatura Valley e atualizar ao mudar a rotina correspondente.
-->

# v004 - Retirar Benchmark Como Gate De Varejo

## Resumo

- Corrigir a fila de publicacao do STOCK para nao exigir benchmark externo de marketplace como pre-condicao universal de aprovacao.
- Manter benchmark apenas como evidencia negativa quando ele existir e provar falta de vantagem de preco.
- Atualizar o texto do admin para refletir a regra operacional real.

## Checklist

- [x] Localizar o gate atual de benchmark no admin e no backend de suporte. Concluido em 2026-05-05 08:54:05 BRT.
- [x] Remover o uso de benchmark ausente como motivo automatico de revisao. Concluido em 2026-05-05 08:54:05 BRT.
- [x] Preservar benchmark existente como bloqueio quando o preco Valley perde a vantagem. Concluido em 2026-05-05 08:54:05 BRT.
- [x] Atualizar o texto visivel do painel para refletir a nova regra. Concluido em 2026-05-05 08:54:05 BRT.

## Evidencias

- `admin/app.js` nao adiciona mais `no_market_benchmark` como revisao automatica.
- `scripts/serve_valley_admin.py` nao rebaixa mais itens por ausencia de benchmark; a regra continua bloqueando quando `price_gap <= 0`.
- `admin/index.html` passou a descrever a fila por bloqueios e configuracao comercial, sem depender de benchmark externo.

## Bloqueios

- Nenhum bloqueio aberto.

## Proxima acao

- Se quiser endurecer ainda mais a regra, o proximo passo coerente e amarrar a aprovacao a um piso economico interno canonico por categoria ou fornecedor, em vez de referencia externa eventual.
