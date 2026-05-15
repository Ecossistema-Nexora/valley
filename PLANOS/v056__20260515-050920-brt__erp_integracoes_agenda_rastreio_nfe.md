PROPOSITO: Preparar o ERP Lojista Valley para integracoes bidirecionais, agenda de servicos, rastreio proprio de entregas e importacao NF-e.
CONTEXTO: O usuario solicitou APIs para Shopee, Mercado Livre, OLX, Ze Delivery, iFood e outros canais, alem de agenda de horarios para empresas de servico e rastreio em tempo real do entregador quando nao houver integracao iFood.
REGRAS: Usar somente conectores oficiais ou contratos homologaveis, manter segredos fora do git, registrar eventos append-only, criar usuario tipo entregador, vincular rastreio ao pedido e exibir dados exclusivamente no escopo do perfil do lojista autenticado.

# v056 - ERP Integracoes Agenda Rastreio NF-e

## Checklist

- [x] Criar catalogo sem segredos dos conectores externos e sugestoes de marketplaces.
- [x] Criar migration Postgres para conectores, NF-e, agenda de servicos, entregadores e rastreio.
- [x] Expor endpoints autenticados do ERP Lojista para blueprint, eventos de integracao, NF-e, agenda e rastreio.
- [x] Atualizar RBAC/runtime com papeis de agendador e entregador.
- [x] Adicionar produtos com cadastro, edicao, exclusao logica, suspensao e publicacao por filial.
- [x] Adicionar relatorios filtraveis por periodo, usuario, produto, categoria e filial.
- [x] Adicionar matriz/filiais com estoque global, regional ou local e sincronizacao automatica.
- [x] Adicionar botao Rastreio com contrato de mini mapa ocultavel por filial.
- [x] Aplicar escopo obrigatorio por lojista em todos os endpoints e eventos runtime v056.
- [x] Validar sintaxe, endpoint smoke e rotina Valley Module Automation.
- [x] Atualizar INDEX.md com progresso real.

## Contratos Minimos

- Marketplaces e delivery: catalogo, estoque, precos, pedidos, status, financeiro quando o provedor permitir.
- NF-e: importacao XML/chave, hash, itens, CFOP/NCM, lancamento fiscal e movimento de estoque.
- Produtos: criar, editar, suspender, restaurar, excluir logicamente, publicar, precificar, categorizar e atualizar estoque.
- Relatorios: filtros por periodo, usuario, produto, categoria e filial, com exportacao JSON/CSV/PDF.
- Filiais: matriz controla lojas, financeiro, cadastros, operacoes e politica de estoque global, regional ou local.
- Agenda: recurso profissional/sala, slots, bloqueios, reservas, confirmacao/cancelamento e eventos.
- Rastreio proprio: tipo de usuario entregador, associacao ao pedido, latitude/longitude, status e prova de entrega.
- Escopo: toda resposta e todo evento operacional devem carregar `tenant_scope` e permanecer vinculados ao lojista autenticado.

## Endpoints Esperados

- `GET /api/merchant-erp/integration-blueprint`
- `POST /api/merchant-erp/integration-event`
- `GET /api/merchant-erp/products`
- `POST /api/merchant-erp/product-command`
- `GET /api/merchant-erp/reports`
- `POST /api/merchant-erp/report-query`
- `GET /api/merchant-erp/branches`
- `POST /api/merchant-erp/branch-command`
- `POST /api/merchant-erp/nfe-import`
- `GET /api/merchant-erp/service-schedule`
- `POST /api/merchant-erp/service-booking`
- `GET /api/merchant-erp/delivery-tracking`
- `POST /api/merchant-erp/delivery-event`

## Evidencia Implementada

- `scripts/serve_valley_admin.py`: endpoints v056 autenticados, RBAC ampliado, tenant scope obrigatorio e modulos Produtos/Relatorios/Filiais/Agenda/Rastreio.
- `config/integrations/merchant_erp_external_connectors.json`: contratos sem segredos para conectores, produtos, relatorios, filiais, agenda, NF-e e rastreio.
- `database/postgres/039_v47_merchant_erp_external_ops_schedule_delivery.sql`: schema aditivo para conectores, NF-e, produtos, relatorios, filiais, agenda, entregadores e rastreio.
- `python -m py_compile scripts/serve_valley_admin.py`: sem erro.
- `python scripts/valley_db_orchestrator.py check`: manifest e migration 039 OK; Docker Desktop nao respondeu no tempo limite local.
- Smoke local autenticado em `127.0.0.1:8120`: blueprint, products, reports, branches, service-schedule, delivery-tracking e integration-blueprint retornaram `ok` com `tenant_scope`.
- Smoke publico autenticado em `https://admin.brasildesconto.com.br`: healthz, blueprint, products, reports, branches, service-schedule, delivery-tracking e integration-blueprint retornaram `ok`; product-command usou o tenant do lojista autenticado mesmo recebendo `merchant_user_id` externo no payload.
- `scripts/invoke_valley_module_activity.ps1 -ActivityName erp_integracoes_agenda_rastreio_runtime -Mode checkpoint`: sucesso; registry valido com 47 modulos.
