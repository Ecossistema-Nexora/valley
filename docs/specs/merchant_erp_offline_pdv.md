# ERP Lojista Valley - PDV Offline First

## Objetivo

Garantir que o app instalavel do ERP Lojista continue operando durante quedas temporarias de internet. O PDV, caixa, carrinho, vendas pendentes, consultas de estoque local e recibos devem funcionar offline e sincronizar automaticamente assim que a rede voltar.

## Principio Operacional

O app deve ser local-first para rotinas de loja e server-authoritative para conciliacao final. Isso significa que o operador consegue vender e registrar eventos no dispositivo, mas o backend Valley continua sendo a fonte final para ledger financeiro, repasses, integracoes externas, marketplace e auditoria consolidada.

## Funcoes Permitidas Offline

- Abrir caixa se o dispositivo ja estava autorizado antes da queda.
- Montar carrinho e registrar venda local.
- Receber em dinheiro ou registrar pagamento pendente.
- Aplicar desconto dentro de limite preconfigurado no ultimo sync.
- Consultar catalogo e estoque espelhado localmente.
- Reservar ou baixar estoque local com status pendente de sync.
- Emitir recibo local com hash e aviso de sincronizacao pendente.
- Registrar sangria, suprimento, cancelamento local e observacao de operador.
- Consultar pedidos e clientes previamente sincronizados.

## Funcoes Que Exigem Online

- Autorizar PIX, cartao, wallet ou gateway externo em tempo real.
- Confirmar repasse, split, antecipacao ou conciliacao financeira final.
- Alterar conta bancaria, regras fiscais sensiveis ou permissao de equipe.
- Publicar catalogo em massa para marketplaces.
- Excluir definitivamente venda, pedido, cliente ou produto.
- Resolver conflito de estoque que envolva outro dispositivo.

## Dados Locais

Banco local recomendado para Flutter Desktop: `drift` sobre SQLite.

Tabelas locais minimas:

- `offline_devices`: dispositivo autorizado, loja, usuario, ultima sessao valida.
- `offline_pdv_sessions`: abertura/fechamento de caixa, operador, saldos e status.
- `offline_sales`: venda local, totais, status, hash, idempotency key.
- `offline_sale_items`: itens, SKU, quantidade, preco, desconto e snapshot fiscal basico.
- `offline_cash_movements`: sangria, suprimento, dinheiro, ajustes e recibos.
- `offline_inventory_mirror`: estoque espelhado por SKU, reserva e ultima versao remota.
- `offline_inventory_events`: reserva, baixa, ajuste, transferencia e divergencia.
- `offline_sync_queue`: fila append-only de eventos pendentes.
- `offline_sync_checkpoints`: ultimo sucesso por endpoint/tipo de evento.
- `offline_audit_events`: trilha local de seguranca e operacao.

## Modelo De Evento

Todo evento enviado ao backend deve carregar:

- `event_id`: UUID local.
- `idempotency_key`: chave deterministica por dispositivo, sessao e sequencia.
- `device_id`: identificador do terminal.
- `merchant_user_id`: lojista.
- `operator_user_id`: operador.
- `event_type`: venda, caixa, estoque, recibo ou auditoria.
- `payload_json`: corpo do evento.
- `payload_hash`: hash do payload local.
- `created_at_local`: horario do dispositivo.
- `created_at_utc`: horario UTC calculado quando possivel.
- `sync_status`: pending, syncing, synced, conflict ou failed.
- `retry_count` e `last_error`.

## Sincronizacao

O app deve observar conectividade e tambem fazer tentativa periodica curta. Quando a rede voltar:

1. Marcar UI como `Reconectando`.
2. Enviar eventos em ordem por prioridade: caixa, vendas, pagamentos pendentes, estoque, recibos, auditoria.
3. Usar `idempotency_key` para impedir duplicidade.
4. Receber `remote_id`, `remote_status`, `server_version` e `conflict_reason`.
5. Atualizar checkpoints locais.
6. Rebaixar conflitos para uma fila visual de revisao.
7. Marcar UI como `Sincronizado` somente quando a fila critica estiver vazia.

## Resolucao De Conflitos

- Venda duplicada: backend responde com o mesmo `remote_id` para a mesma `idempotency_key`.
- Estoque insuficiente: venda permanece registrada, mas item entra como `estoque_em_revisao` ou `separacao_pendente`.
- Preco mudou enquanto offline: manter preco aplicado se estava dentro da validade local; caso contrario, exigir aprovacao do gerente.
- Sessao expirada: permitir finalizar fila local, mas bloquear novas vendas ate login online.
- Relogio local divergente: backend grava horario de recebimento e preserva horario declarado como campo auditavel.

## UX Obrigatoria

- Barra de estado: `Online`, `Offline`, `Reconectando`, `Sincronizando`, `Conflito`.
- Cada venda deve mostrar: `Local`, `Pendente`, `Sincronizada` ou `Revisar`.
- O operador deve conseguir continuar vendendo offline sem sair da tela do PDV.
- A tela de fechamento de caixa deve separar total local, total sincronizado e pendencias.
- O recibo offline deve exibir um codigo/hash e status de sincronizacao pendente.
- Nao usar cabecalho de links nos modulos; manter botao unico de retorno ao menu principal.

## Contrato Com Backend

Endpoints recomendados:

- `POST /api/merchant-erp/sync/events`: recebe lote idempotente.
- `GET /api/merchant-erp/sync/bootstrap`: baixa catalogo, estoque, permissoes e limites offline.
- `GET /api/merchant-erp/sync/status`: retorna pendencias remotas e versao minima.
- `POST /api/merchant-erp/sync/conflicts/{id}/resolve`: aplica decisao de gerente.

O backend deve persistir eventos financeiros em trilha append-only e nunca confiar em totais enviados sem recalculo.

## Criterios De Aceite

- Abrir app sem internet apos login previo e acessar PDV.
- Registrar venda offline com dois itens e recibo local.
- Fechar e reabrir o app mantendo a venda pendente.
- Reconectar a rede e sincronizar automaticamente sem acao manual.
- Reexecutar o sync sem duplicar venda.
- Simular estoque insuficiente e exibir conflito revisavel.
- Bloquear PIX/cartao online quando nao houver autorizacao externa.
- Mostrar contador de eventos pendentes no menu principal e no PDV.

## Riscos

- Pagamento externo offline nao pode ser prometido como aprovado sem autorizacao real.
- Multiplos dispositivos podem gerar conflito de estoque se o espelho local estiver antigo.
- SQLite local precisa de backup e migracoes controladas para evitar perda de fila.
- Relogio do dispositivo pode estar errado; servidor precisa normalizar auditoria.
- O instalador desktop deve preservar dados locais em atualizacoes.
