# Valley Release Blueprint - Templates Web para Stitch

Criado em BRT: 2026-05-12

## Prompt Principal

Crie um produto web final, sofisticado, conciso e altamente funcional para o ecossistema Valley. O resultado deve cobrir o painel admin, o ERP do lojista, os painéis por módulo, o portal público da marca e os fluxos de login. Não criar landing page promocional. Não criar telas técnicas internas ou áreas de bastidor. O foco é operação comercial real.

O design deve ser um template release pronto para produção: navegação clara, dados de negócio, formulários, tabelas, gráficos, indicadores, ações e estados operacionais. Todos os painéis devem funcionar sem docks laterais, sem sidebar fixa e sem abas laterais. A navegação deve ser superior, horizontal, por tabs, chips, breadcrumbs, grids de atalhos e barras de ação contextuais.

## Identidade e Domínios

- Marca: Valley.
- Assistente do produto: Helena.
- Moeda/token quando necessário: V-Coin.
- Idioma obrigatório de todos os textos, labels, botões, mensagens, campos e estados: português do Brasil.
- Site oficial público: `brasildesconto.com.br`.
- Admin central: `admin.brasildesconto.com.br`.
- Login lojista: `lojista.brasildesconto.com.br`.
- ERP lojista: `erp-lojista.brasildesconto.com.br`.
- Todos os subdomínios devem usar o mesmo padrão visual, alterando apenas conteúdo, foco e ações.

## Diretrizes de Interface

- Interface empresarial, densa e limpa, inspirada em ERP comercial moderno.
- Todo conteúdo deve ser escrito em português do Brasil, com termos técnicos em inglês apenas quando forem nomes de mercado inevitáveis, como SKU, checkout, webhook, sync, dashboard ou marketplace.
- Base visual clara, com contraste em navy, verde, azul e acentos por área.
- Nada de hero marketing. A primeira dobra já deve permitir operar.
- Top bar com logo, workspace ativo, busca, ambiente, perfil e ações principais.
- Cards compactos para KPIs, tabelas ricas para operação, gráficos objetivos e formulários curtos.
- Botoes sempre reais e orientados a ação.
- Mobile deve manter todas as ações, convertendo tabelas em cards e filtros em chips/accordions.
- Estados obrigatórios: carregando, vazio, com dados, atenção, bloqueado por permissão, erro operacional, sucesso.

## Componentes Base

- `TopNavigation`: logo Valley, workspace, busca global, ambiente, perfil, notificações.
- `WorkspaceHeader`: título, subtítulo, domínio, status e ações primárias.
- `KpiGrid`: 4 a 8 indicadores compactos.
- `FilterBar`: busca, período, status, canal, categoria, responsável.
- `ActionBar`: salvar, aplicar, sincronizar, exportar, abrir link, copiar.
- `DataTable`: ordenação, status, ações por linha, seleção múltipla.
- `ChartPanel`: barras, linhas, rosca ou funil conforme contexto.
- `OperationalForm`: campos editáveis, validação, estado salvo.
- `IntegrationCard`: provedor, status, escopos, último sync, pendências.
- `OperationalHistory`: histórico de alterações, aprovações e responsáveis em linguagem de negócio.
- `ResponsiveAppGrid`: atalhos por módulo e subdomínio.
- `EmptyState`, `WarningState`, `PermissionState`, `SuccessToast`.

## Portal Público - `brasildesconto.com.br`

Objetivo: entrada oficial da marca para usuários, compradores e lojistas.

Conteúdo:
- Busca de ofertas, produtos, serviços e módulos.
- Acesso rápido: Comprar, Minha Conta, Sou Lojista, Suporte.
- Catálogo público com produto, preço, frete, disponibilidade, loja, avaliação.
- Cards de módulos ativos: Marketplace, Stock, Pay, Chat, Docs, Plug.
- Área de login/registro do cliente.
- Chamada para lojistas acessarem o ERP.

Campos:
- Busca.
- CEP/frete.
- Categoria.
- Faixa de preço.
- Disponibilidade.
- Email/telefone para login.

Tabelas/cards:
- Produtos em destaque.
- Categorias.
- Lojas parceiras.
- Histórico de compras quando autenticado.

Ações:
- Buscar.
- Ver produto.
- Comprar.
- Entrar.
- Sou lojista.
- Abrir suporte.

## Admin Central - `admin.brasildesconto.com.br`

Objetivo: controle executivo e operacional do ecossistema.

Tabs horizontais:
- Visão geral.
- ERP Lojista.
- Financeiro.
- Desempenho.
- Integrações.
- Catálogo.
- Módulos.

KPIs:
- Módulos ativos.
- Prontidão média.
- Provedores conectados.
- Produtos catalogados.
- Receita potencial.
- Alertas comerciais.
- Checkout.
- Publicações pendentes.

Campos:
- Busca por módulo, lojista, SKU, pedido ou provedor.
- Filtros por domínio, status, prioridade, canal, responsável, período.
- Configuração de margem, fee, imposto, marketing, observação comercial.
- Configuração de integração por provedor: provider, seller id, escopos, webhook, status.

Tabelas:
- Workspaces.
- Módulos.
- Lojistas.
- Produtos importados.
- Fila de publicação.
- Integrações.
- Saúde comercial do checkout.

Gráficos:
- Receita potencial por canal.
- Produtos por status.
- Prontidão por domínio.
- Sync por provedor.
- Funil de publicação.

Ações:
- Abrir workspace.
- Abrir ERP do lojista.
- Salvar configurações.
- Aplicar sincronização.
- Resetar ajustes.
- Aprovar publicação.
- Bloquear item.
- Exportar relatório.

Estados/flags:
- Produção.
- Sandbox.
- Publicado.
- Em revisão.
- Bloqueado.
- Integração ativa.
- Integração pendente.
- Checkout pronto.
- Checkout em atenção.

## Admin Workspaces

Cada workspace é uma tela própria usando o template: header, KPIs, filtros, tabela principal, gráfico, formulário de configuração e ações.

| Workspace | Link | Foco | Campos | Tabela | Gráficos | Ações |
|---|---|---|---|---|---|---|
| Núcleo Admin | `admin.brasildesconto.com.br` | visão executiva | busca, ambiente, prioridade | workspaces e alertas | prontidão geral | abrir, filtrar, exportar |
| STOCK | `stock-admin.brasildesconto.com.br` | catálogo e estoque | SKU, categoria, fornecedor, margem | produtos e fornecedores | estoque, margem, publicação | sincronizar, revisar, publicar |
| Dropshipping | `dropshipping-admin.brasildesconto.com.br` | importados | fornecedor, origem, lead time, frete | itens importados | custo vs margem | importar, aprovar, bloquear |
| Marketplace | `marketplace-admin.brasildesconto.com.br` | canais de venda | provedor, seller, escopos | conectores | vendas por canal | conectar, salvar, testar |
| Revisão | `review-admin.brasildesconto.com.br` | curadoria | motivo, categoria, status | fila de revisão | aprovados vs bloqueados | aprovar, reprovar, devolver |
| Financeiro | `finance-admin.brasildesconto.com.br` | receita | período, taxa, canal | repasses e fees | receita líquida | fechar, reconciliar, exportar |
| Lojistas | `merchants-admin.brasildesconto.com.br` | sellers | CNPJ, plano, status | lojistas | crescimento de sellers | aprovar, bloquear, abrir ERP |
| Usuários | `users-admin.brasildesconto.com.br` | acesso | nome, email, papel | usuários e sessões | acessos por perfil | convidar, bloquear, alterar papel |
| Checkout | `checkout-admin.brasildesconto.com.br` | pagamentos | ambiente, webhook, retorno | tentativas e preferências | aprovação vs falha | atualizar, testar, exportar |
| Sandbox/Flags | `sandbox-admin.brasildesconto.com.br` | configurações | flag, escopo, valor | flags | uso por ambiente | ativar, desativar, resetar |

## ERP Lojista - Template Base

Links:
- `lojista.brasildesconto.com.br`
- `erp-lojista.brasildesconto.com.br`
- `pdv-lojista.brasildesconto.com.br`
- `armazem-lojista.brasildesconto.com.br`
- `metricas-lojista.brasildesconto.com.br`
- `campanhas-lojista.brasildesconto.com.br`
- `relatorios-lojista.brasildesconto.com.br`
- `financeiro-lojista.brasildesconto.com.br`
- `cadastro-lojista.brasildesconto.com.br`
- `perfil-lojista.brasildesconto.com.br`
- `contabil-lojista.brasildesconto.com.br`
- `integracao-lojista.brasildesconto.com.br`
- `pedidos-lojista.brasildesconto.com.br`
- `produtos-lojista.brasildesconto.com.br`
- `clientes-lojista.brasildesconto.com.br`
- `fiscal-lojista.brasildesconto.com.br`
- `estoque-lojista.brasildesconto.com.br`
- `inventario-lojista.brasildesconto.com.br`
- `logistica-lojista.brasildesconto.com.br`
- `transportadora-lojista.brasildesconto.com.br`
- `atendimento-lojista.brasildesconto.com.br`
- `equipe-lojista.brasildesconto.com.br`
- `seguranca-lojista.brasildesconto.com.br`
- `configuracoes-lojista.brasildesconto.com.br`

Estrutura comum:
- Top navigation horizontal com módulos do ERP.
- Header da loja com nome, status, ambiente, subdomínio e ações.
- KPIs: Catálogo, Receita potencial, Integrações, Checkout, Pedidos, Estoque.
- Formulário operacional: nome da loja, operador, meta diária BRL, alerta de estoque, workspace, subdomínio.
- Gráfico gerencial: venda, margem, PDV, estoque, campanhas, caixa.
- Tabela operacional específica da página.
- Grid de subdomínios do ERP.
- Scanner operacional para estoque: leitura por código de barras, QR Code ou digitação manual.

Ações comuns:
- Salvar rotina.
- Aplicar sincronização.
- Gerar relatório.
- Exportar.
- Abrir módulo.
- Copiar link.

Estados:
- Loja ativa.
- Cadastro incompleto.
- Checkout pendente.
- Integração pendente.
- Sincronização em andamento.
- Relatório pronto.
- Sem permissão.

## ERP Lojista - Páginas

| Página | Foco | Campos | Tabela | Gráficos | Ações |
|---|---|---|---|---|---|
| Login Lojista | acesso seguro | email, senha, empresa, MFA | sessões recentes | acessos por dispositivo | entrar, recuperar, validar MFA |
| ERP Lojista | torre de controle | loja, operador, meta, alerta | rotinas e SLAs | visão geral da operação | salvar, sincronizar, exportar |
| PDV | venda presencial | terminal, turno, operador, caixa inicial | vendas, pagamentos, sangria | vendas por forma de pagamento | abrir caixa, fechar, conciliar |
| Armazém | WMS | endereço, lote, SKU, quantidade | picking, packing, inventário | ocupação e ruptura | receber, separar, transferir |
| Métricas | BI | período, canal, meta, comparativo | indicadores | tendências e funil | atualizar, salvar meta, exportar |
| Campanhas | marketing | campanha, canal, budget, cupom | campanhas | ROAS, conversão, custo | criar, pausar, duplicar |
| Relatórios | exportações | tipo, período, formato, destino | relatórios | histórico de exportação | gerar, baixar, agendar |
| Financeiro | repasses | período, taxa, canal, centro custo | recebíveis, taxas, chargebacks | bruto vs líquido | fechar, reconciliar, exportar |
| Cadastro | dados comerciais | razão social, CNPJ, endereço, contatos | documentos e filiais | completude cadastral | salvar, validar, anexar |
| Perfil | marca da loja | logo, banner, políticas, horário | configurações públicas | reputação e SLA | salvar, pré-visualizar, publicar |
| Contábil | lançamentos | conta, categoria, competência, valor | débitos e créditos | centros de custo | lançar, conciliar, exportar |
| Integração | conectores | provider, seller id, scopes, webhook | provedores | sync por canal | conectar, testar, sincronizar |
| Pedidos | ciclo do pedido | pedido, cliente, status, transportadora | pedidos e etapas | SLA de pedidos | separar, cancelar, reembolsar |
| Produtos | catálogo | título, SKU, preço, estoque, mídia | produtos | margem e publicação | publicar, revisar, bloquear |
| Clientes | CRM | cliente, contato, segmento, tag | clientes | recompra e ticket | abrir, segmentar, atender |
| Fiscal | documentos | CFOP, NCM, imposto, chave | NFe e documentos | impostos por período | emitir, corrigir, auditar |
| Estoque | saldo | SKU, mínimo, reserva, fornecedor | saldo por SKU | ruptura e reposição | ajustar, reservar, repor |
| Inventário de Estoque | contagem física, volumes e ajustes | busca, código de barras, QR Code, SKU, fornecedor, lote, validade, quantidade inventariada, embalagem, unidades por volume, tipo de movimentação | divergências, contagens, volumes, avarias e ajustes | acuracidade, divergência, baixa, alta, avaria | escanear, adicionar, subtrair, confirmar contagem, registrar avaria, baixar estoque, dar entrada |
| Logística | entrega | transportadora, rastreio, prazo, custo | envios | SLA de entrega | etiqueta, rastrear, ocorrência |
| Transportadora e Cross Docking | movimentação em CD e distribuição final | romaneio, doca, rota, motorista, veículo, volumes, etiqueta, destino, ocorrência | cargas, coletas, transferências, entregas e devoluções | produtividade por doca, SLA de rota, entregas no prazo, avarias | receber carga, bipar volume, mover doca, montar rota, despachar, confirmar entrega |
| Atendimento | SAC | assunto, cliente, canal, prioridade | tickets | SLA e satisfação | responder, escalar, encerrar |
| Equipe | pessoas | nome, email, papel, turno | colaboradores | produtividade | convidar, alterar papel, bloquear |
| Segurança | proteção | regra, dispositivo, IP, risco | eventos de segurança | risco por severidade | forçar MFA, revogar sessão |
| Configurações | parâmetros | chave, valor, escopo, ambiente | preferências | alterações por área | salvar, aplicar, resetar |

### Tela Lojista - Inventário de Estoque

Objetivo: permitir que o lojista conte, corrija e movimente estoque físico com leitura por código de barras, QR Code ou busca textual, mantendo controle de volumes, fracionamento, avarias, baixas e altas.

Local sugerido:
- Tela principal em `inventario-lojista.brasildesconto.com.br`.
- Subpágina também disponível em `estoque-lojista.brasildesconto.com.br`.
- Atalho também visível em `armazem-lojista.brasildesconto.com.br`.

Componentes:
- Scanner por câmera para código de barras e QR Code.
- Campo de digitação manual do código.
- Busca inteligente por nome, abreviação, SKU, código interno, EAN/GTIN, fornecedor, marca, lote ou categoria.
- Card do produto encontrado com foto, nome, SKU, fornecedor, estoque esperado, estoque contado e divergência.
- Controle de quantidade inventariada com botões de adicionar e subtrair.
- Composição de volume: exemplo, 1 embalagem com 12 unidades.
- Seletor de forma de controle: volume padrão do fabricante, volume armazenado, unidade fracionada, kit/composição.
- Motivo da movimentação: contagem, recebimento, venda, devolução, avaria, perda, ajuste positivo, ajuste negativo.
- Campos de lote, validade, localização, prateleira, depósito, operador e observação.

Campos:
- Buscar produto.
- Código de barras / QR Code.
- SKU.
- Código interno.
- Fornecedor.
- Nome ou abreviação.
- Lote.
- Validade.
- Localização.
- Quantidade inventariada.
- Quantidade esperada.
- Diferença calculada.
- Embalagens contadas.
- Unidades por embalagem.
- Unidade fracionada.
- Tipo de volume: padrão do fabricante, armazenado como volume, fracionado.
- Forma operacional: recebido como volume, vendido como volume, armazenado como volume, recebido fracionado, vendido fracionado, armazenado fracionado.
- Tipo de movimentação: recebido, vendido, armazenado, avaria, baixa, alta.
- Motivo do ajuste.
- Operador responsável.
- Observação.

Tabela principal:
- Produto.
- SKU.
- Fornecedor.
- Lote.
- Localização.
- Esperado.
- Inventariado.
- Diferença.
- Volume.
- Fracionamento.
- Motivo.
- Status.

KPIs:
- Itens contados.
- Divergências abertas.
- Valor estimado da diferença.
- Acuracidade do inventário.
- Avarias registradas.
- Altas de estoque.
- Baixas de estoque.
- Volumes fracionados.

Gráficos:
- Divergência por categoria.
- Acuracidade por depósito.
- Baixas vs altas.
- Avarias por fornecedor.
- Produtos mais divergentes.

Ações:
- Escanear código.
- Buscar produto.
- Adicionar quantidade.
- Subtrair quantidade.
- Confirmar contagem.
- Registrar avaria.
- Registrar baixa de estoque.
- Registrar alta de estoque.
- Marcar como recebido.
- Marcar como vendido.
- Marcar como armazenado.
- Salvar rascunho.
- Fechar inventário.
- Exportar relatório.

Estados:
- Aguardando leitura.
- Produto encontrado.
- Produto não encontrado.
- Contagem em rascunho.
- Divergência detectada.
- Avaria registrada.
- Baixa pendente de confirmação.
- Alta pendente de confirmação.
- Inventário fechado.
- Sem permissão.

Regras de negócio:
- Quantidade inventariada deve aceitar unidade inteira e fracionada.
- Se o produto usa embalagem padrão, o painel deve calcular automaticamente `embalagens x unidades por embalagem`.
- Se o produto for vendido fracionado, o painel deve permitir estoque em unidades avulsas.
- Avaria deve gerar baixa com motivo obrigatório.
- Alta de estoque deve exigir motivo e responsável.
- Baixa de estoque deve exigir motivo, quantidade e confirmação.
- Todo ajuste deve mostrar diferença entre estoque esperado e estoque inventariado antes de confirmar.
- A tela deve mostrar simultaneamente saldo em volumes, saldo em unidades e saldo fracionado quando houver conversão.
- O usuário deve conseguir declarar se o produto é recebido, vendido e armazenado pelo volume padrão do fabricante ou por unidade fracionada.

### Tela Lojista - Transportadora e Cross Docking

Objetivo: permitir que uma transportadora, CD parceiro ou operação própria movimente produtos recebidos, conferidos, roteirizados e distribuídos ao cliente final com rastreio operacional, leitura de volumes e controle de ocorrências.

Local sugerido:
- Tela principal em `transportadora-lojista.brasildesconto.com.br`.
- Atalho também visível em `logistica-lojista.brasildesconto.com.br`.
- Atalho operacional em `armazem-lojista.brasildesconto.com.br` quando a carga entrar por CD.

Componentes:
- Scanner por câmera, coletor ou digitação manual para etiqueta, código de barras, QR Code, pedido, romaneio e volume.
- Busca por pedido, nota fiscal, chave NFe, cliente, CPF/CNPJ, endereço, transportadora, motorista, placa, rota, doca, lote, SKU ou código do volume.
- Painel de docas com status: aguardando recebimento, em conferência, pronto para roteirização, em expedição, em rota, entregue, devolvido.
- Mapa ou lista de rotas com paradas, SLA, prioridade, distância, janela de entrega e responsável.
- Card do volume com produto, quantidade, embalagem, peso, cubagem, origem, destino, etapa atual e divergências.
- Composição de carga: pedido, volumes, pallets, caixas, unidades, lacres e agrupamento por rota.
- Ocorrências: avaria, falta, sobra, endereço incompleto, cliente ausente, recusa, atraso, devolução, extravio.

Campos:
- Buscar pedido, volume ou romaneio.
- Código de barras / QR Code.
- Número do pedido.
- Nota fiscal / chave NFe.
- Cliente final.
- Endereço de entrega.
- CEP.
- Transportadora.
- Motorista.
- Veículo / placa.
- Rota.
- Doca.
- CD de origem.
- CD de destino.
- Volume.
- Quantidade de volumes.
- Peso.
- Cubagem.
- Tipo de embalagem.
- Lacre.
- SLA de entrega.
- Janela de entrega.
- Status da movimentação.
- Tipo de operação: recebimento em CD, cross docking, transferência, expedição, última milha, devolução.
- Motivo da ocorrência.
- Responsável.
- Observação.
- Comprovante de entrega.

Tabela principal:
- Pedido.
- Romaneio.
- Volume.
- Cliente.
- Origem.
- Destino.
- Doca.
- Rota.
- Motorista.
- Veículo.
- SLA.
- Status.
- Ocorrência.

KPIs:
- Volumes recebidos.
- Volumes em conferência.
- Volumes em cross docking.
- Rotas montadas.
- Entregas no prazo.
- Entregas atrasadas.
- Ocorrências abertas.
- Devoluções pendentes.

Gráficos:
- Produtividade por doca.
- SLA por rota.
- Entregas por status.
- Ocorrências por motivo.
- Tempo médio entre recebimento e expedição.
- Volumes por transportadora.

Ações:
- Escanear volume.
- Buscar pedido.
- Receber carga.
- Conferir volume.
- Mover para doca.
- Agrupar volumes.
- Montar romaneio.
- Criar rota.
- Atribuir motorista.
- Despachar carga.
- Registrar ocorrência.
- Registrar avaria.
- Confirmar entrega.
- Anexar comprovante.
- Iniciar devolução.
- Reagendar entrega.
- Exportar romaneio.

Estados:
- Aguardando recebimento.
- Em conferência.
- Divergência detectada.
- Pronto para cross docking.
- Aguardando expedição.
- Em rota.
- Entregue.
- Entrega parcial.
- Cliente ausente.
- Devolução iniciada.
- Avaria registrada.
- Extravio em apuração.
- Sem permissão.

Regras de negócio:
- Todo volume deve ter vínculo com pedido, romaneio, origem, destino e status.
- Cross docking deve permitir movimentar o volume entre docas sem entrada em estoque permanente.
- Distribuição final deve registrar motorista, veículo, rota, janela de entrega e comprovante.
- Avaria, falta, sobra, recusa e extravio devem exigir motivo e responsável.
- Entrega parcial deve destacar volumes pendentes antes de finalizar a rota.
- A tela deve diferenciar recebimento em CD, transferência entre CDs, cross docking, expedição e última milha.
- O painel deve mostrar o histórico operacional completo de cada volume do recebimento até a entrega ou devolução.

## Módulos Admin 01-47

Cada módulo deve receber uma página com:
- Header com código, nome, domínio, status e subdomínio.
- Tabs horizontais: Visão geral, Operação, Integrações, Governança.
- KPIs: fila crítica, dependências, integrações, modo.
- Formulário: código, descrição, domínio, data home, status, responsável.
- Tabela: rotina, responsável, SLA, status.
- Gráficos: volume operacional, prontidão e pendências.
- Ações: abrir workspace, abrir operação, salvar ajustes, exportar.

| # | Código | Nome | Link |
|---|---|---|---|
| 01 | REPLY | Valley REPLY | `01-reply-admin.brasildesconto.com.br` |
| 02 | STOCK | Valley Stock | `02-stock-admin.brasildesconto.com.br` |
| 03 | LOG | Valley Log | `03-log-admin.brasildesconto.com.br` |
| 04 | FOOD | Valley Food | `04-food-admin.brasildesconto.com.br` |
| 05 | DELIVERY | Valley Delivery | `05-delivery-admin.brasildesconto.com.br` |
| 06 | WMS | Valley WMS | `06-wms-admin.brasildesconto.com.br` |
| 07 | MARKETPLACE | Valley Marketplace | `07-marketplace-admin.brasildesconto.com.br` |
| 08 | PAY | Valley Pay | `08-pay-admin.brasildesconto.com.br` |
| 09 | FLEET | Valley Fleet | `09-fleet-admin.brasildesconto.com.br` |
| 10 | SERVICES | Valley Services | `10-services-admin.brasildesconto.com.br` |
| 11 | DIGITAL | Valley Digital | `11-digital-admin.brasildesconto.com.br` |
| 12 | REAL_ESTATE | Valley Real Estate | `12-real-estate-admin.brasildesconto.com.br` |
| 13 | HEALTH | Valley Health | `13-health-admin.brasildesconto.com.br` |
| 14 | EDU | Valley Edu | `14-edu-admin.brasildesconto.com.br` |
| 15 | TECH | Valley Tech | `15-tech-admin.brasildesconto.com.br` |
| 16 | JOBS | Valley Jobs | `16-jobs-admin.brasildesconto.com.br` |
| 17 | NEWS_PODCAST | Valley News & Podcast | `17-news-podcast-admin.brasildesconto.com.br` |
| 18 | ADS | Valley Ads | `18-ads-admin.brasildesconto.com.br` |
| 19 | INFLUENCERS | Valley Influencers | `19-influencers-admin.brasildesconto.com.br` |
| 20 | SOCIAL | Valley Social | `20-social-admin.brasildesconto.com.br` |
| 21 | FITNESS | Valley Fitness | `21-fitness-admin.brasildesconto.com.br` |
| 22 | PHARMACY | Valley Pharmacy | `22-pharmacy-admin.brasildesconto.com.br` |
| 23 | VET | Valley Vet | `23-vet-admin.brasildesconto.com.br` |
| 24 | TOURISM | Valley Tourism | `24-tourism-admin.brasildesconto.com.br` |
| 25 | EVENTS | Valley Events | `25-events-admin.brasildesconto.com.br` |
| 26 | MOBILITY | Valley Mobility | `26-mobility-admin.brasildesconto.com.br` |
| 27 | SECURITY | Valley Security | `27-security-admin.brasildesconto.com.br` |
| 28 | GOV | Valley Gov | `28-gov-admin.brasildesconto.com.br` |
| 29 | LEGAL | Valley Legal | `29-legal-admin.brasildesconto.com.br` |
| 30 | CHARITY | Valley Charity | `30-charity-admin.brasildesconto.com.br` |
| 31 | INSURANCE | Valley Insurance | `31-insurance-admin.brasildesconto.com.br` |
| 32 | GAMING | Valley Gaming | `32-gaming-admin.brasildesconto.com.br` |
| 33 | IOT | Valley IoT | `33-iot-admin.brasildesconto.com.br` |
| 34 | BIO | Valley Bio | `34-bio-admin.brasildesconto.com.br` |
| 35 | HOME | Valley Home | `35-home-admin.brasildesconto.com.br` |
| 36 | ENERGY | Valley Energy | `36-energy-admin.brasildesconto.com.br` |
| 37 | SPACE | Valley Space | `37-space-admin.brasildesconto.com.br` |
| 38 | AGENDA | Valley Agenda | `38-agenda-admin.brasildesconto.com.br` |
| 39 | ADVISOR | Valley Advisor | `39-advisor-admin.brasildesconto.com.br` |
| 40 | FINANCAS | Valley Financas | `40-financas-admin.brasildesconto.com.br` |
| 41 | MENTE | Valley Mente | `41-mente-admin.brasildesconto.com.br` |
| 42 | BUSINESS | Valley Business | `42-business-admin.brasildesconto.com.br` |
| 43 | PLUG | Valley Plug | `43-plug-admin.brasildesconto.com.br` |
| 44 | UP | Valley Up | `44-up-admin.brasildesconto.com.br` |
| 45 | MEDIA | Valley Media | `45-media-admin.brasildesconto.com.br` |
| 46 | CHAT | Valley Chat | `46-chat-admin.brasildesconto.com.br` |
| 47 | DOCS | Valley Docs | `47-docs-admin.brasildesconto.com.br` |

## Integrações Comerciais

| Provider | Uso | Campos | Status |
|---|---|---|---|
| Mercado Livre | marketplace e pricing | seller id, escopos, autorização, webhook | pendente, conectado, expirado, ativo |
| Amazon | marketplace | seller id, marketplace, autorização, notificações | pendente, conectado, ativo |
| AliExpress | fornecedor | app key, autorização, janela de sync | pendente, conectado, ativo |
| Alibaba | fornecedor | app enterprise, assinatura, escopos | pendente, conectado, ativo |
| Magalu | marketplace | seller id, webhook, catálogo | pendente, conectado, ativo |
| CJDropshipping | fornecedor | API key, token, tracking, catálogo | pendente, conectado, ativo |
| Shopee | marketplace | partner id, loja, escopos | pendente, conectado, ativo |

## Dados Operacionais que o Design Deve Contemplar

- Workspaces do ERP.
- Equipe e permissões.
- Terminais de PDV.
- Sessões de caixa.
- Movimentos financeiros.
- Pipeline de pedidos.
- Tarefas de catálogo.
- Tarefas de estoque.
- Inventários de estoque, contagens físicas, divergências, avarias, altas, baixas, volumes e fracionamentos.
- Movimentações de transportadora, CDs, cross docking, romaneios, docas, rotas, entregas finais e devoluções.
- Métricas de negócio.
- Campanhas.
- Relatórios.
- Fechamentos financeiros.
- Lançamentos contábeis.
- Conexões de integração.
- Eventos de segurança resumidos.
- Histórico operacional resumido.

## Entrega Esperada

Gerar templates release para:
- Portal público.
- Login admin.
- Login lojista.
- Admin central.
- Workspace admin.
- Módulo admin genérico.
- ERP lojista central.
- Módulo ERP lojista genérico.
- PDV.
- Estoque/armazém.
- Inventário de estoque com leitura por código de barras e QR Code.
- Transportadora, CD, cross docking e distribuição para cliente final.
- Financeiro/contábil/fiscal.
- Integrações.
- Pedidos/produtos/clientes.
- Atendimento/equipe/segurança/configurações.

Breakpoints:
- Desktop 1440px.
- Tablet 1024px.
- Mobile 390px.

Resultado final: um painel Valley sem áreas técnicas internas, sem docks laterais, pronto para operação comercial real.
