PROPOSITO: Garantir que o release Valley mantenha funcionalidades persistentes, identidade Stitch/Valley e PDV/banking sem pontas soltas.
CONTEXTO: O usuario exigiu cadastro, consultas, relatorios, publicacoes, movimentacoes, PDV com maquina de pagamento, confirmacao de checkout, espaco para APIs bancarias e logomarca padrao em todos os artefatos.
REGRAS: Toda acao visivel deve gravar no runtime quando houver sessao; segredos bancarios ficam fora do git; Stitch v2 permanece fonte visual mandataria.

# v051 - Gate Funcional Visual, PDV E Banking

## Checklist

- [x] Criar contrato persistente para PDV, maquina de pagamento e confirmacao de checkout.
- [x] Criar contrato persistente para APIs bancarias, PIX, Open Finance, recebiveis e conciliacao.
- [x] Expor PDV/banking no blueprint online e nas telas do ERP Lojista.
- [x] Sincronizar icones e logomarca Valley nos alvos Web, Android, Windows e admin.
- [x] Criar e executar validacao automatica do release gate.
- [x] Acionar Valley Module Automation Engine.

## Criterios De Aceite

- Cadastro, consultas, relatorios, publicacoes, movimentacoes, PDV, checkout e banking possuem evento persistente ou contrato runtime auditavel.
- Stitch `20260513_valley_erp_v2` continua sendo a fonte da verdade ativa.
- Icones usam a logomarca Valley padrao.
- Validacao automatica falha se algum contrato obrigatorio desaparecer.
