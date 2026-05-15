PROPOSITO: Implantar operacoes comuns do ERP Lojista, etiquetas QR/EAN-13 e handoff Stitch por modulo.
CONTEXTO: O usuario pediu preparacao para etiquetas de produto/estoque, QR Code ou codigo de barras EAN-13, listagem completa de modulos/funcoes, fluxos, banco de dados e definicao de campos/botoes/listas para novos templates Stitch.
REGRAS: Manter tenant/filial obrigatorios, nao expor termos internos de cashback/recompensa, nao deixar botoes mortos, usar schemas e endpoints reais.

# v057 - ERP Operacoes Etiquetas Stitch Handoff

## Checklist

- [x] Adicionar endpoint de consulta de etiquetas.
- [x] Adicionar endpoint de job de etiquetas com QR Code, EAN-13 ou ambos.
- [x] Ampliar RBAC com operador de etiquetas.
- [x] Ampliar produtos/estoque no blueprint com etiquetas, variantes e kits.
- [x] Criar migration Postgres 040 para etiquetas, variantes, kits, inventario ciclico, alertas, devolucoes e financeiro.
- [x] Atualizar manifesto de migrations.
- [x] Atualizar catalogo de integracoes com contrato de etiquetas e operacoes comuns.
- [x] Gerar documento Stitch com campos, botoes, listas, fluxos e banco por modulo.
- [x] Gerar contrato JSON estruturado para Stitch por modulo.
- [ ] Validar sintaxe, JSON, orchestrator, endpoints e automacao obrigatoria.
- [ ] Atualizar INDEX.md.

## Evidencia Implementada

- `scripts/serve_valley_admin.py`: `/api/merchant-erp/labels` e `/api/merchant-erp/label-job`.
- `database/postgres/040_v47_merchant_erp_operations_labels_returns_finance.sql`: schema operacional v057.
- `config/integrations/merchant_erp_external_connectors.json`: contrato de etiquetas e operacoes comuns.
- `docs/specs/merchant_erp_modules_operations_stitch_handoff.md`: fonte para Stitch por modulo.
- `docs/specs/merchant_erp_stitch_module_layout_contract.json`: contrato estruturado para automacao Stitch.
