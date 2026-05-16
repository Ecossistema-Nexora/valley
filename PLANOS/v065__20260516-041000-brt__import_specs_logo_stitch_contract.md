<!--
PROPOSITO: Importar especificacoes Admin/ERP/Usuario/Entregador e validar logomarca oficial Valley.
CONTEXTO: O usuario anexou duas especificacoes Markdown e a logomarca Valley para consolidacao no pacote Stitch/Figma/Flutter.
REGRAS: Preservar segredos fora do git, manter marca Valley/Helena/V-Coin e atualizar handoff/contrato/indice.
-->

# v065 - Import Specs Logo Stitch Contract

## Resumo

Importar para o repositorio as especificacoes tecnica e operacional por persona, validar a logomarca oficial Valley e tornar esses arquivos anexos obrigatorios do pacote Stitch/ERP.

## Checklist

- [x] Confirmar existencia dos arquivos informados no pacote local `Downloads/000 - VALLEY`.
- [x] Comparar hash da logomarca enviada com `assets/brand/logo-valley-official.png`.
- [x] Importar especificacao tecnica por tela para `docs/specs`.
- [x] Importar especificacao operacional por persona para `docs/specs`.
- [x] Atualizar request Stitch com os novos anexos obrigatorios.
- [x] Atualizar handoff operacional ERP/Stitch com a nova fonte canonica.
- [x] Atualizar contrato JSON estruturado do Stitch.
- [x] Validar Markdown/JSON e recalcular `PLANOS/INDEX.md`.

## Evidencias

- Logo enviado e asset oficial possuem SHA256 `53E4158D234EF25AE845083C4F0A1356E1BF37BA3E10DCB84BDB9BACCB18EADA`.
- Arquivos importados:
  - `docs/specs/valley-screen-technical-spec-admin-erp-user-rider.md`
  - `docs/specs/valley-operational-spec-admin-erp-user-rider.md`
- `python -m json.tool docs\specs\merchant_erp_stitch_module_layout_contract.json` executado com sucesso.

## Bloqueios

- Nenhum bloqueio ativo.
