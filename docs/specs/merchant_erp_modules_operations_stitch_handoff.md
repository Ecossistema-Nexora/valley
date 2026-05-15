<!--
PROPOSITO: Consolidar modulos, operacoes, campos, botoes, listas, fluxos e banco do ERP Lojista para handoff ao Stitch.
CONTEXTO: Este documento serve como fonte para gerar novos templates por modulo, mantendo escopo por lojista e filial.
REGRAS: Nao expor regras internas de cashback/recompensa; dados exibidos pertencem apenas ao lojista autenticado.
-->

# ERP Lojista Valley - Modulos, Operacoes e Handoff Stitch

## Regras Globais de Layout

- Toda tela deve carregar `tenant_scope` e exibir apenas dados do lojista autenticado.
- Toda tela com filial deve ter seletor `branch_key` quando a operacao puder variar por matriz/filial.
- Operacoes destrutivas devem ser `soft delete`, suspensao ou cancelamento auditavel, nunca apagamento fisico direto.
- Campos de formulario devem ter estados: vazio, preenchido, erro de validacao, salvando, salvo, falha.
- Listas devem ter filtros por periodo, status, filial, usuario, produto/SKU e categoria quando aplicavel.
- Botoes primarios executam comando real; botoes secundarios abrem filtros, exportacao, preview, impressao ou historico.
- Termos internos de cashback/recompensa nao devem aparecer nos templates por enquanto.

## Modulos e Operacoes

### 1. Vendas / PDV
- Objetivo: registrar venda, aplicar desconto permitido, confirmar checkout, integrar maquina de pagamento e registrar trocas/devolucoes.
- Campos de entrada: codigo/SKU, quantidade, cliente, vendedor, forma de pagamento, desconto autorizado, terminal, observacao.
- Botoes: `Adicionar item`, `Aplicar desconto`, `Confirmar pagamento`, `Sincronizar maquina`, `Cancelar venda`, `Abrir devolucao`.
- Listas: carrinho, vendas recentes, pagamentos pendentes, devolucoes em andamento.
- Fluxos: abrir caixa -> adicionar itens -> confirmar pagamento -> emitir comprovante -> atualizar estoque -> opcional entrega/rastreio.
- Banco/API: `merchant_erp_cash_movements`, `orders`, `merchant_erp_return_authorizations`, `/api/merchant-erp/action`.

### 2. Produtos
- Objetivo: cadastrar, editar, suspender, restaurar, excluir logicamente, publicar, criar variantes, kits/combos e gerar etiquetas.
- Campos de entrada: SKU, EAN-13/GTIN, nome, descricao, categoria, marca, preco base, preco promocional, status, foto, filial, estoque inicial.
- Campos para grade: SKU pai, atributo, valor, SKU variante, EAN-13, diferenca de preco.
- Campos para kit/combo: SKU kit, nome, itens, quantidade por item, preco promocional.
- Botoes: `Novo produto`, `Salvar`, `Suspender`, `Restaurar`, `Excluir`, `Publicar`, `Criar variante`, `Criar kit`, `Gerar etiqueta`.
- Listas: produtos, variantes, kits, historico de acoes, etiquetas geradas.
- Fluxos: cadastro -> validacao SKU/EAN -> publicacao -> etiqueta -> estoque -> marketplace.
- Banco/API: `inventory_items`, `merchant_erp_product_lifecycle_events`, `merchant_erp_product_variants`, `merchant_erp_product_kits`, `/api/merchant-erp/products`, `/api/merchant-erp/product-command`.

### 3. Estoque
- Objetivo: controlar saldo, entrada por NF-e, reserva, transferencia, ajuste, ponto minimo/maximo, inventario ciclico e etiquetas de entrada.
- Campos de entrada: filial, SKU, quantidade, tipo de movimento, lote, validade, documento referencia, minimo, maximo, reposicao sugerida.
- Botoes: `Entrada`, `Saida`, `Transferir`, `Ajustar`, `Iniciar inventario`, `Gerar etiqueta de entrada`, `Configurar alerta`.
- Listas: saldo por filial, movimentos, lotes/validade, divergencias, alertas de reposicao.
- Fluxos: NF-e/importacao -> itens -> movimento de entrada -> etiqueta lote -> endereco/prateleira -> saldo atualizado.
- Banco/API: `inventory_items`, `inventory_movements`, `merchant_erp_inventory_alert_rules`, `merchant_erp_cycle_count_jobs`, `/api/merchant-erp/label-job`, `/api/merchant-erp/nfe-import`.

### 4. Etiquetas
- Objetivo: gerar QR Code, EAN-13 ou ambos para produto, preco, entrada de estoque, prateleira, picking, envio e transferencia.
- Campos de entrada: tipo de etiqueta, formato (`QR_CODE`, `EAN13`, `BOTH`), filial, template, SKU, titulo, quantidade, preco, lote, validade.
- Botoes: `Gerar QR Code`, `Gerar EAN-13`, `Gerar ambos`, `Pré-visualizar`, `Imprimir`, `Baixar PDF`, `Enviar para impressora`.
- Listas: templates, jobs recentes, itens do job, falhas de validacao.
- Fluxos: escolher template -> selecionar itens -> validar EAN-13 -> gerar payload QR -> preview -> imprimir.
- Banco/API: `merchant_erp_label_templates`, `merchant_erp_label_jobs`, `merchant_erp_label_job_items`, `/api/merchant-erp/labels`, `/api/merchant-erp/label-job`.

### 5. Pedidos
- Objetivo: acompanhar pedidos de PDV, marketplace, link de pagamento, separacao e entrega.
- Campos de entrada: pedido, cliente, filial, status, prioridade, responsavel, observacao.
- Botoes: `Separar`, `Reservar estoque`, `Confirmar`, `Enviar`, `Cancelar`, `Criar rastreio`, `Gerar etiqueta de picking`.
- Listas: pedidos por status, itens do pedido, separacao, historico.
- Fluxos: pedido recebido -> reserva -> picking -> conferência -> entrega/retirada -> finalizacao.
- Banco/API: `orders`, `merchant_erp_order_pipeline`, `merchant_erp_delivery_assignments`, `/api/merchant-erp/action`.

### 6. Clientes
- Objetivo: visualizar cadastro, historico, enderecos, compras, tags e relacionamento.
- Campos de entrada: nome, CPF/CNPJ, email, telefone, tags, endereco, observacao.
- Botoes: `Novo cliente`, `Editar`, `Adicionar tag`, `Ver compras`, `Abrir atendimento`.
- Listas: clientes, historico de compras, tags, enderecos, atendimentos.
- Fluxos: cadastro -> validacao -> compra -> pos-venda -> suporte.
- Banco/API: `users`, runtime auth, `/api/auth/register`, `/api/me/purchases`.

### 7. Financeiro
- Objetivo: contas a pagar/receber, despesas, receitas, estornos, fluxo de caixa e DRE basico.
- Campos de entrada: tipo, categoria, descricao, valor, vencimento, data de liquidacao, metodo, documento, filial.
- Botoes: `Nova conta`, `Marcar como pago`, `Conciliar`, `Estornar`, `Exportar DRE`, `Filtrar periodo`.
- Listas: contas a pagar, contas a receber, fluxo previsto/realizado, DRE mensal, conciliacao.
- Fluxos: lancamento -> vencimento -> liquidacao -> conciliacao -> relatorio.
- Banco/API: `merchant_erp_finance_entries`, `merchant_erp_financial_closures`, `merchant_erp_accounting_entries`, `v_merchant_erp_finance_cashflow_dre`.

### 8. APIs Bancarias
- Objetivo: preparar conectores para PIX, Open Finance, boleto, recebiveis e conciliacao.
- Campos de entrada: provedor, ambiente, chave PIX, conta, webhook, certificado/secretRef.
- Botoes: `Configurar conector`, `Testar webhook`, `Sincronizar extrato`, `Conciliar`.
- Listas: conectores, eventos bancarios, falhas de assinatura, conciliacoes.
- Fluxos: configurar -> testar -> receber evento -> conciliar -> refletir no financeiro.
- Banco/API: `config/integrations/valley_banking_api_connectors.json`, `/api/merchant-erp/action`.

### 9. Checkout
- Objetivo: confirmar pagamento online/fisico, comprovante, destinatario e endereco de entrega.
- Campos de entrada: cliente, endereco, destinatario, metodo, terminal, referencia do pedido.
- Botoes: `Confirmar checkout`, `Gerar link`, `Enviar comprovante`, `Reprocessar`.
- Listas: tentativas, pagamentos pendentes, retornos do provedor.
- Fluxos: pedido -> pagamento -> retorno -> pedido confirmado -> estoque/entrega.
- Banco/API: `/api/actions/checkout`, `/api/checkout-health`, eventos Mercado Pago.

### 10. Entregas
- Objetivo: frete, despacho, etiqueta de envio, entregador, prova de entrega e status.
- Campos de entrada: pedido, filial origem, endereco destino, destinatario, entregador, SLA.
- Botoes: `Criar entrega`, `Atribuir entregador`, `Gerar etiqueta de envio`, `Atualizar status`, `Registrar prova`.
- Listas: entregas abertas, entregadores, atrasos, provas.
- Fluxos: pedido separado -> etiqueta -> atribuir entregador -> rastrear -> prova -> concluir.
- Banco/API: `merchant_erp_delivery_assignments`, `merchant_erp_delivery_tracking_events`, `/api/merchant-erp/delivery-event`.

### 11. Rastreio
- Objetivo: mini mapa ocultavel por filial com localizacao em tempo real e historico do entregador.
- Campos de entrada: filtro filial, tracking code, entregador, status.
- Botoes: `Exibir mapa`, `Ocultar mapa`, `Atualizar`, `Filtrar filial`.
- Listas: rotas ativas, eventos GPS, entregas por status.
- Fluxos: entrega criada -> app entregador envia posicao -> mapa atualiza -> prova de entrega.
- Banco/API: `merchant_erp_delivery_tracking_events`, `/api/merchant-erp/delivery-tracking`.

### 12. Marketplace
- Objetivo: publicar catalogo, importar pedidos, atualizar preco/estoque e receber status financeiro/logistico.
- Campos de entrada: provedor, categoria, SKU, preco, estoque, status anuncio.
- Botoes: `Publicar`, `Atualizar preco`, `Atualizar estoque`, `Importar pedidos`, `Sincronizar`.
- Listas: canais, anuncios, pedidos importados, pendencias de homologacao.
- Fluxos: conectar provedor -> mapear catalogo -> publicar -> importar pedidos -> atualizar status.
- Banco/API: `merchant_erp_connector_catalog`, `merchant_erp_connector_sync_events`, `/api/merchant-erp/integration-event`.

### 13. Integracoes
- Objetivo: centralizar Shopee, Mercado Livre, OLX, iFood, Ze Delivery, Magalu, Amazon, Nuvemshop, WhatsApp e Google Business.
- Campos de entrada: provedor, ambiente, callback, secretRef, escopos.
- Botoes: `Autorizar`, `Testar`, `Sincronizar`, `Desativar`, `Ver logs`.
- Listas: provedores, status, eventos recentes, credenciais pendentes.
- Fluxos: credencial -> autorizacao/homologacao -> webhook -> sincronizacao bidirecional.
- Banco/API: `config/integrations/merchant_erp_external_connectors.json`, `/api/merchant-erp/integration-blueprint`.

### 14. Fiscal / NF-e
- Objetivo: importar XML/chave, validar itens, gerar lancamento fiscal e atualizar estoque.
- Campos de entrada: chave 44 digitos, XML, CNPJ emitente, CNPJ destinatario, itens, CFOP, NCM.
- Botoes: `Importar XML`, `Consultar chave`, `Validar itens`, `Gerar estoque`, `Gerar etiquetas de entrada`.
- Listas: lotes importados, itens, divergencias, movimentos criados.
- Fluxos: upload/chave -> extracao itens -> validacao -> estoque -> etiquetas.
- Banco/API: `merchant_erp_nfe_import_batches`, `merchant_erp_nfe_items`, `/api/merchant-erp/nfe-import`.

### 15. Agenda
- Objetivo: agenda bidirecional para servicos, profissionais, salas e recursos.
- Campos de entrada: recurso, servico, cliente, telefone, email, inicio, fim, filial.
- Botoes: `Novo horario`, `Confirmar`, `Remarcar`, `Cancelar`, `Concluir`, `Bloquear horario`.
- Listas: agenda diaria/semanal, recursos, reservas, no-show.
- Fluxos: cliente solicita -> lojista confirma -> atendimento -> conclusao/cancelamento.
- Banco/API: `merchant_erp_service_resources`, `merchant_erp_service_bookings`, `/api/merchant-erp/service-booking`.

### 16. Filiais
- Objetivo: matriz gerencia lojas, estoque global/regional/local, cadastros, financeiro e operacoes.
- Campos de entrada: filial, tipo, endereco, regiao, politica estoque, sincronizacoes, visibilidade financeira.
- Botoes: `Nova filial`, `Salvar`, `Suspender`, `Ativar`, `Definir politica`, `Sincronizar cadastros`.
- Listas: filiais, politicas, sincronizacoes, estoque por escopo.
- Fluxos: criar filial -> politica -> sincronizar cadastro/preco/estoque -> monitorar financeiro.
- Banco/API: `merchant_erp_branch_units`, `merchant_erp_branch_stock_policies`, `/api/merchant-erp/branches`.

### 17. Relatorios
- Objetivo: filtros por periodo, usuario, produto, categoria, filial e exportacao.
- Campos de entrada: periodo inicial/final, usuario, produto, categoria, filial, formato.
- Botoes: `Aplicar filtros`, `Limpar`, `Exportar JSON`, `Exportar CSV`, `Exportar PDF`.
- Listas: resultados, agregados, top categorias, historico de consultas.
- Fluxos: filtro -> consulta -> resumo -> exportacao -> auditoria.
- Banco/API: `merchant_erp_report_query_events`, `/api/merchant-erp/reports`, `/api/merchant-erp/report-query`.

### 18. Configuracoes
- Objetivo: parametros da loja, usuarios, permissoes, seguranca, canais e preferencia operacional.
- Campos de entrada: nome loja, CNPJ, email, telefone, preferencias, parametros de estoque/financeiro.
- Botoes: `Salvar`, `Resetar`, `Testar configuracao`, `Exportar backup`.
- Listas: parametros, auditoria, alteracoes recentes.
- Fluxos: editar -> validar -> salvar -> auditar.
- Banco/API: `merchant_erp_workspaces`, `merchant_erp_audit_events`.

### 19. Equipe
- Objetivo: usuarios, papeis, privilegios e operadores por filial.
- Campos de entrada: email, nome, papel, filial, status, permissoes adicionais.
- Botoes: `Convidar`, `Ativar`, `Suspender`, `Conceder privilegio`, `Revogar`.
- Listas: staff, papeis, privilegios efetivos, auditoria.
- Fluxos: convite -> papel -> privilegios -> auditoria.
- Banco/API: `merchant_erp_staff_members`, `merchant_erp_privileges`, `v_merchant_erp_staff_effective_privileges`.

### 20. Seguranca
- Objetivo: MFA, sessoes, trilha append-only, risco e controle de acesso.
- Campos de entrada: usuario, sessao, nivel risco, acao, observacao.
- Botoes: `Revogar sessao`, `Bloquear usuario`, `Liberar`, `Exportar auditoria`.
- Listas: sessoes, eventos, privilegios criticos.
- Fluxos: evento -> avaliacao -> bloqueio/liberacao -> auditoria.
- Banco/API: `merchant_erp_security_events`, `merchant_erp_audit_events`.

### 21. Suporte Helena
- Objetivo: atendimento operacional, chamados e orientacao dentro do ERP.
- Campos de entrada: assunto, descricao, modulo, prioridade, anexos.
- Botoes: `Abrir chamado`, `Responder`, `Encerrar`, `Escalar`.
- Listas: chamados, respostas, status, SLA.
- Fluxos: chamado -> triagem -> resposta -> resolucao -> historico.
- Banco/API: bridge operacional e eventos runtime.

## Esqueleto de Fluxos Principais

1. Produto: cadastro -> variante/kit -> preco -> etiqueta -> estoque -> publicacao.
2. Estoque: NF-e -> entrada -> etiqueta lote/validade -> endereco -> alerta -> inventario ciclico.
3. Venda: PDV/checkout -> pagamento -> pedido -> baixa/reserva estoque -> comprovante.
4. Entrega: pedido separado -> etiqueta picking/envio -> entregador -> rastreio -> prova.
5. Servico: cliente escolhe horario -> lojista confirma -> atendimento -> conclusao.
6. Financeiro: venda/despesa -> conta a receber/pagar -> liquidacao -> conciliacao -> DRE.
7. Filial: matriz cria filial -> define politica -> sincroniza cadastro/preco/estoque -> monitora relatorios.
8. Integracao: provedor autorizado -> webhook/polling -> importacao pedido -> atualizacao estoque/status.

## Banco de Dados - Detalhamento Consolidado

### Core
- `users`: identidade central.
- `wallets`: carteira financeira.
- `orders`: pedido base usado por checkout, delivery e ERP.
- `transactions`: ledger transacional.

### ERP Lojista Base
- `merchant_erp_workspaces`: surfaces e modulos do lojista.
- `merchant_erp_staff_members`: equipe por lojista.
- `merchant_erp_pdv_terminals`: terminais PDV.
- `merchant_erp_pdv_sessions`: abertura/fechamento de caixa.
- `merchant_erp_cash_movements`: movimentos append-only do caixa.
- `merchant_erp_order_pipeline`: fila operacional de pedidos.
- `merchant_erp_catalog_tasks`: tarefas de catalogo.
- `merchant_erp_inventory_tasks`: tarefas de estoque.
- `merchant_erp_metric_snapshots`: metricas append-only.
- `merchant_erp_campaigns`: campanhas comerciais.
- `merchant_erp_report_exports`: exportacoes.
- `merchant_erp_financial_closures`: fechamento financeiro.
- `merchant_erp_accounting_entries`: lancamentos contabeis/fiscais append-only.
- `merchant_erp_integration_connections`: conexoes externas sem segredo bruto.
- `merchant_erp_security_events`: eventos de seguranca append-only.
- `merchant_erp_audit_events`: auditoria append-only.

### RBAC
- `merchant_erp_privileges`: catalogo de privilegios.
- `merchant_erp_role_profiles`: papeis.
- `merchant_erp_role_profile_privileges`: vinculo papel/privilegio.
- `merchant_erp_staff_privilege_grants`: concessoes diretas.
- `merchant_erp_privilege_audit_events`: auditoria RBAC.
- `v_merchant_erp_staff_effective_privileges`: permissao efetiva.

### Integracoes, Fiscal, Agenda e Rastreio
- `merchant_erp_connector_catalog`: provedores homologaveis.
- `merchant_erp_connector_sync_events`: eventos bidirecionais.
- `merchant_erp_nfe_import_batches`: lote NF-e.
- `merchant_erp_nfe_items`: itens NF-e.
- `merchant_erp_service_resources`: recursos de agenda.
- `merchant_erp_service_bookings`: agendamentos.
- `merchant_erp_service_booking_events`: eventos de agenda.
- `merchant_erp_courier_profiles`: entregadores.
- `merchant_erp_delivery_assignments`: entregas associadas a pedido.
- `merchant_erp_delivery_tracking_events`: posicoes e provas.
- `merchant_erp_product_lifecycle_events`: ciclo de produto.
- `merchant_erp_report_query_events`: historico de relatorios.
- `merchant_erp_branch_units`: matriz/filiais.
- `merchant_erp_branch_stock_policies`: politica de estoque.
- `merchant_erp_branch_events`: auditoria filial.

### Operacoes v057
- `merchant_erp_product_variants`: grade/variantes.
- `merchant_erp_product_kits`: kits/combos.
- `merchant_erp_product_kit_items`: itens de kit.
- `merchant_erp_label_templates`: templates de etiqueta.
- `merchant_erp_label_jobs`: jobs de etiqueta.
- `merchant_erp_label_job_items`: itens materializados da etiqueta.
- `merchant_erp_inventory_alert_rules`: ponto minimo/maximo.
- `merchant_erp_cycle_count_jobs`: inventario ciclico.
- `merchant_erp_cycle_count_items`: itens contados/divergencias.
- `merchant_erp_return_authorizations`: trocas/devolucoes.
- `merchant_erp_finance_entries`: contas a pagar/receber, despesas, receitas e estornos.
- `v_merchant_erp_label_jobs`: jobs de etiquetas consolidados.
- `v_merchant_erp_product_grade_and_kits`: grade e kits.
- `v_merchant_erp_inventory_replenishment_alerts`: alertas de reposicao.
- `v_merchant_erp_finance_cashflow_dre`: fluxo de caixa/DRE.
- `v_merchant_erp_returns_control`: controle de devolucoes.

## Prompt Base para Stitch

Use este documento como fonte para criar templates executaveis do ERP Lojista Valley. Para cada modulo, gere uma tela operacional com:

- Cabecalho compacto com nome do modulo, seletor de filial quando aplicavel e status.
- Area principal com lista/tabela do dominio.
- Painel lateral ou modal para campos de entrada.
- Botoes reais descritos neste documento, sem botoes mortos.
- Estados vazios, carregando, erro e sucesso.
- Identidade visual Valley consistente, sem textos de desenvolvimento.

Para automacao, tambem existe a versao estruturada em JSON:

- `docs/specs/merchant_erp_stitch_module_layout_contract.json`
