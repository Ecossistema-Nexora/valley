<!--
PROPOSITO: Definir a especificacao-mestra do Valley Merchant ERP para Stitch e Codex.
CONTEXTO: Este arquivo aponta a fonte da verdade visual/funcional e o contrato tecnico para transformar os modulos do ERP Lojista em telas executaveis.
REGRAS: Manter isolamento por lojista/filial, nao expor cashback/recompensa na UI e nao permitir botoes mortos.
-->

# MASTER SPECIFICATION: VALLEY MERCHANT ERP (STITCH & CODEX)

## 1. Fonte Da Verdade

Esta especificacao-mestra consolida o pacote de trabalho do ERP Lojista Valley.

- Documento detalhado para Stitch:
  `docs/specs/merchant_erp_modules_operations_stitch_handoff.md`
- Contrato estruturado para Stitch/Codex:
  `docs/specs/merchant_erp_stitch_module_layout_contract.json`
- Migration operacional Postgres:
  `database/postgres/040_v47_merchant_erp_operations_labels_returns_finance.sql`
- Servidor/API operacional:
  `scripts/serve_valley_admin.py`
- Plano rastreavel:
  `PLANOS/v057__20260515-061500-brt__erp_operacoes_etiquetas_stitch_handoff.md`

## 2. Regra Principal Do Produto

O ERP Lojista deve operar como painel real, nao como demonstracao.

- Toda tela deve respeitar `tenant_scope = merchant_profile_only`.
- Toda operacao por filial deve carregar `branch_key` ou `branch_id`.
- Dados exibidos pertencem exclusivamente ao lojista autenticado.
- Operacoes destrutivas devem usar cancelamento, suspensao ou soft delete auditavel.
- Nenhum botao pode ser apenas decorativo.
- Termos internos de cashback/recompensa ficam ocultos nesta fase.
- A identidade visual Valley deve ser preservada em web, desktop e mobile.
- Toda query, gravacao e relatorio deve aplicar `where tenant_id = ?` e, quando aplicavel, `and branch_id = ?`.
- A regra `BR-PRO-001` bloqueia custo bruto, formula de markup e margem na interface final.
- Helena deve operar em PT-BR, com sotaque regional configuravel pela cidade/UF de nascimento.

## 2.1 Mobilidade E Agente Autonomo

O bloco de Mobilidade deve ser tratado como modulo operacional real, com monitoramento em tempo real e agente ocioso persistente.

Funcoes obrigatorias:

- Acompanhar trajetos de onibus, metro e transporte por aplicativo em todo o Brasil.
- Comparar preco, tempo e risco de atraso entre transporte por aplicativo e transporte publico.
- Quando o transporte por aplicativo estiver caro, Helena deve sugerir transporte publico + trecho final por aplicativo quando isso economizar tempo ou dinheiro.
- Considerar compromissos do usuario para calcular risco de atraso.
- Recalcular rotas em acidente, atraso, interrupcao de linha, transito pesado ou preco anormal.
- Avisar proativamente sem popup invasivo; Helena deve sinalizar com interacao visual discreta.
- Registrar as decisoes em `mobility_idle_agent_events` e `mobility_idle_agent_decisions`.
- Criar verificacao automatica do modulo `visio` usando `valley_module_availability_checks`.

Tabelas e collections de contrato:

- `mobility_realtime_route_sessions`
- `mobility_idle_agent_dispatch_rules`
- `mobility_idle_agent_events`
- `valley_module_availability_checks`
- `mobility_idle_agent_decisions`

## 2.2 Design System E Telas Stitch

Contratos persistentes para Stitch ficam em `valley_screen_layout_contracts`.

### HOME 001

- `001.1 Cabeçalho`: identidade Valley e busca global.
- `001.2 Rastreio real-time`: bloco flutuante oculto quando nao houver entrega ativa.
- `001.3 Banner hero`: promocao personalizada por Helena com base em interesse, buscas e contexto.
- `001.4 Banners secundarios`: duas areas 50/50 para lojistas locais e campanhas, com beneficios ocultos ate liberacao de produto.
- `001.5 Financas`: saldo e proximos pagamentos devem ser ocultaveis; recursos internos de recompensa nao aparecem nesta fase.
- `001.6 Favoritos/Carrinho`: lista mista Stock + Marketplace.
- `001.7 Rodape`: perfil, suporte, FAQ e navegacao rapida.

### STOCK Dropshipping

- Visual: grid infinito de produtos via API Valley.
- Filtros: categoria, preco final e prazo de entrega.
- Regra de preco: produto so pode ser publicado quando a meta de preco final 10% menor que o menor concorrente for atendida.
- Sandbox lojista: simulacao operacional interna, nunca exibida ao cliente.

### Marketplace Lojistas Locais

- Visual: proximidade, bairro, segmento, avaliacao e categoria de servico/produto.
- Destaque: beneficios podem existir no contrato, mas ficam ocultos na UI final ate habilitacao explicita.
- Filtros: bairro, segmento e avaliacao.

### Chat Marketplace

- Canais: usuario com Valley, usuario com lojista local e usuario com suporte Helena.
- Toda negociacao deve ocorrer dentro do chat oficial Valley.
- Mensagens sao append-only: sem endpoint de update/delete de texto e sem soft delete por usuario.
- O motor de moderacao deve detectar telefone, email, WhatsApp, Telegram, redes externas e qualquer inducao para contato fora do app.
- Ao detectar infracao, Helena envia aviso educativo no chat.
- Segunda infracao exige alerta severo e aceite de ciencia.
- Terceira infracao gera evento automatico `account.suspended.evasion`, pausa operacional de anuncios e revisao manual.
- Tabelas: `marketplace_chat_moderation_patterns`, `chat_moderation_strikes`, `chat_moderation_account_actions`.
- Collections: `marketplace_chat_moderation_events`.

### Rastreio Android Marketplace

- Recurso exclusivo do Super APK Android.
- Origem exclusiva: pedidos do modulo Marketplace.
- Exclusao explicita: pedidos Stock, estoque proprio, parceiros locais fora do Marketplace e dropshipping nao ativam esta feature.
- Ao pedido Marketplace ser aceito e a entrega iniciar, backend envia Silent Push FCM de alta prioridade.
- O APK inicia Foreground Service e renderiza notificacao dinamica persistente.
- Em Android 16+, usar Live Updates; em versoes anteriores, usar Foreground Service + notificacao custom atualizavel.
- A notificacao/tela de bloqueio deve exibir minimapa, rota estimada, veiculo/entregador em movimento, pin do cliente, ETA e status.
- O mapa usa Google Maps SDK Android em modo otimizado.
- Stream em background via WebSocket ou SSE.
- Tema visual: Night/Cosmic, progresso Violet e alertas/status Cyan.
- Tabelas: `marketplace_android_live_tracking_sessions`, `marketplace_android_live_tracking_events`.
- Collections: `marketplace_android_live_tracking_stream`.

## 3. Responsabilidade Do Stitch

O Stitch deve usar o Markdown detalhado como brief visual e funcional.

Arquivo base:

`docs/specs/merchant_erp_modules_operations_stitch_handoff.md`

O Stitch deve gerar telas completas para:

1. Login e selecao de filial.
2. Menu principal por botoes de modulo.
3. Vendas / PDV.
4. Produtos.
5. Estoque.
6. Etiquetas.
7. Pedidos.
8. Clientes.
9. Checkout.
10. Financeiro.
11. APIs Bancarias.
12. Entregas.
13. Rastreio.
14. Marketplace.
15. Integracoes.
16. Fiscal / NF-e.
17. Agenda.
18. Filiais.
19. Relatorios.
20. Equipe.
21. Seguranca.
22. Configuracoes.
23. Suporte Helena.

Cada tela deve entregar:

- Campos de entrada claramente identificados.
- Botoes com acao real associada.
- Listas/tabelas com filtros operacionais.
- Estados vazio, carregando, salvo, erro e sem permissao.
- Confirmacao para cancelar, suspender, estornar, excluir logicamente ou revogar acesso.
- Layout responsivo para web e base reutilizavel em desktop/mobile.

## 4. Responsabilidade Do Codex

O Codex deve usar o JSON estruturado como contrato de implementacao.

Arquivo base:

`docs/specs/merchant_erp_stitch_module_layout_contract.json`

O Codex deve garantir:

- Cada `module.key` vira rota/tela real.
- Cada `input_fields` vira campo de formulario ou filtro.
- Cada `buttons` vira handler real com endpoint, modal, drawer ou confirmacao.
- Cada `lists` vira lista, tabela, kanban, agenda, mapa ou fila operacional.
- Cada `primary_endpoint` deve existir ou ser explicitamente criado antes da tela final.
- Cada `tables` deve ser mapeada para migration, view, runtime JSON ou contrato API.
- Toda chamada autenticada deve manter isolamento por lojista e filial.

## 5. Contrato De Modulos

O contrato JSON define os modulos com esta estrutura:

```json
{
  "key": "products",
  "label": "Produtos",
  "input_fields": ["sku", "ean13", "name"],
  "buttons": ["new_product", "save", "generate_label"],
  "lists": ["products", "variants", "kits"],
  "filters": ["category", "status", "branch_key"],
  "primary_endpoint": "/api/merchant-erp/products",
  "tables": ["inventory_items", "merchant_erp_product_variants"]
}
```

Esta estrutura deve orientar qualquer novo template, componente ou implementacao.

## 6. Contrato De Etiquetas

O modulo `labels` e obrigatorio para operacoes de produto, estoque, picking, envio e transferencia.

Tipos de codigo suportados:

- `QR_CODE`
- `EAN13`
- `BOTH`

Endpoints:

- `GET /api/merchant-erp/labels`
- `POST /api/merchant-erp/label-job`

Tabelas:

- `merchant_erp_label_templates`
- `merchant_erp_label_jobs`
- `merchant_erp_label_job_items`

Tipos de job:

- `product_identification`
- `price_tag`
- `stock_receiving`
- `shelf_location`
- `picking`
- `shipping`
- `branch_transfer`
- `inventory_count`

## 7. Contrato De Banco De Dados

A migration v057 adiciona suporte a:

- Variantes de produto.
- Kits e combos.
- Templates de etiqueta.
- Jobs de etiqueta.
- Itens de etiqueta.
- Alertas de estoque minimo/maximo.
- Inventario ciclico.
- Trocas/devolucoes.
- Lancamentos financeiros operacionais.

Arquivo:

`database/postgres/040_v47_merchant_erp_operations_labels_returns_finance.sql`

Toda tabela operacional deve manter:

- `tenant_id`: identifica o lojista dono do dado.
- `branch_id`: identifica a filial quando aplicavel.
- `created_at`: data de criacao.
- `updated_at`: data de atualizacao quando aplicavel.
- `created_by` ou `operator_id`: usuario que executou a acao.
- Campos de status para fluxo operacional.
- Campos JSON apenas para extensibilidade controlada, nao como substituto de campos essenciais.

## 8. Fluxos Criticos

1. Produto -> variante/kit -> etiqueta -> estoque -> marketplace.
2. NF-e -> importacao XML -> entrada de estoque -> etiquetas -> saldo atualizado.
3. PDV -> carrinho -> pagamento -> comprovante -> baixa de estoque.
4. Pedido -> separacao -> picking -> entrega -> rastreio -> prova.
5. Agenda -> disponibilidade -> agendamento -> confirmacao -> atendimento.
6. Filial -> politica de estoque -> sincronizacao -> relatorio consolidado.
7. Marketplace -> publicacao -> sincronizacao bidirecional -> pedido importado.
8. Financeiro -> lancamento -> liquidacao -> conciliacao -> relatorio.

## 9. Evidencia De Validacao

Validacoes executadas nesta rodada:

- JSON do contrato Stitch validado com `json.load`.
- `scripts/serve_valley_admin.py` validado com `python -m py_compile`.
- Endpoints testados em servidor local temporario:
  - Login lojista.
  - `GET /api/merchant-erp/labels`.
  - `POST /api/merchant-erp/label-job`.
  - Blueprint com modulo `labels`.
  - Integration blueprint com contrato `labels`.
- Orquestrador de banco validou a migration `040`.
- Rotina Gemini/Valley Module Automation executada em modo checkpoint.

Pendente externo conhecido:

- Docker Desktop/engine nao respondeu ao `docker info` dentro do timeout do orquestrador.
- O task legado `ValleyCommunicationBridge` esta protegido por ACL do Windows, mas o script foi ajustado para delegar execucao visivel ao runner oculto.

## 10. Protocolo De Uso

Para o Stitch:

1. Abrir o Markdown de handoff.
2. Usar cada secao de modulo como brief de tela.
3. Preservar a lista de campos, botoes, listas, fluxos e regras globais.
4. Gerar templates consistentes com a identidade Valley.

Para o Codex:

1. Abrir o JSON de contrato.
2. Mapear cada modulo para tela/rota/handler.
3. Verificar se endpoints e tabelas existem.
4. Implementar handlers antes de expor botoes.
5. Validar por smoke test e Playwright quando houver UI.

## 11. Criterio De Aceite

A entrega so deve ser considerada pronta quando:

- As telas do Stitch forem refletidas no web/desktop/mobile.
- Todos os botoes tiverem acao real.
- As telas respeitarem tenant/filial.
- As operacoes de produto, estoque, etiquetas, pedidos, financeiro, agenda, filiais e rastreio estiverem funcionais.
- O contrato JSON continuar valido.
- A migration estiver registrada no manifesto.
- A rotina Gemini/Valley Module Automation passar em checkpoint.
