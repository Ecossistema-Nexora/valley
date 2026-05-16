<!--
PROPOSITO: Especificacao operacional por persona para Admin, Lojista, Usuario APK Android e Entregador.
CONTEXTO: Documento importado do pacote Valley 000 para consolidar modulos, fluxos, dados e responsabilidades operacionais.
REGRAS: Usar como fonte obrigatoria para planejamento, Stitch, Figma, Flutter, backend e QA sem expor segredos.
-->

# Valley — Especificação Operacional por Persona

Versão: 1.0  
Escopo: Admin, Lojista / Valley ERP, Usuário / APK Android e Entregador / APK Android  
Fonte técnica: repositório `Ecossistema-Nexora/valley`, especialmente `database/postgres`, `billing/schema.sql`, `admin/app.js`, `frontend/flutter/lib/src/ui/valley_product_shell.dart` e `docs/specs/valley-helena-master-spec.md`.

---

## 1. Objetivo

Esta especificação transforma a estrutura técnica do Valley em uma visão operacional de produto, tela, fluxo, dado, integração e módulo. O conteúdo está organizado por persona de uso para permitir implementação, validação funcional, desenho de telas, criação de backlog e homologação ponta a ponta.

As quatro superfícies são:

1. **Admin** — governança, RBAC, regras, auditoria, módulos, integrações, billing e observabilidade.
2. **Lojista / Valley ERP** — gestão empresarial, produtos, estoque, marketplace, pedidos, compras, serviços, financeiro e integrações externas.
3. **Usuário / APK Android** — super app para cadastro, compra, delivery, mobilidade, wallet, Helena, segurança, pedidos e notificações.
4. **Entregador / APK Android** — app operacional para onboarding, disponibilidade, aceite, coleta, rota, entrega, segurança, ganhos e performance.

---

## 2. Princípios técnicos obrigatórios

### 2.1 Core-first

Todo fluxo operacional deve estar ancorado em `public.users.user_id`. Nenhuma entidade crítica deve existir sem usuário raiz, dono, ator, solicitante, lojista, entregador, admin ou referência derivada inequívoca.

### 2.2 Auditoria append-only

Transações, eventos de entrega, eventos de corrida, eventos de incidente, documentos, ledger de pontos, ações admin e movimentos de estoque devem preservar histórico. Quando a tabela for append-only, correção deve gerar novo evento/documento, não edição silenciosa.

### 2.3 Separação de personas

Usuário comum, lojista, entregador e admin podem compartilhar a mesma raiz `users`, mas suas permissões, telas e responsabilidades são diferentes. O frontend deve esconder capacidades não autorizadas e o backend deve reforçar RBAC/ABAC.

### 2.4 Consentimento e segurança

Fluxos com pagamento, biometria, mobilidade, segurança, dados sensíveis, memória Helena, Advisor e ações cross-module exigem consentimento explícito e trilha auditável.

---

## 3. Mapeamento de diretórios e responsabilidades

| Diretório | Responsabilidade | Consome | Produz |
|---|---|---|---|
| `admin/` | Cockpit Admin, visualização de módulos, filtros, integrações marketplace, métricas e comandos. | Manifesto `window.VALLEY_ADMIN_DATA`, catálogos, métricas, integrações. | Ações administrativas, filtros, configurações, comandos operacionais. |
| `billing/` | Clientes, assinaturas, faturas, webhooks Stripe e entitlements. | `users`, `wallets`, `pj_profiles`, eventos Stripe. | Assinaturas, faturas, direitos de plano, status de cobrança. |
| `config/` | Configurações de visão, Helena, operating model e mapas auxiliares. | Regras e specs. | Configurações para runtime, agentes e Admin. |
| `database/postgres/` | Modelo relacional central. | Seeds, DDLs, aplicações. | Tabelas, enums, índices, triggers e comentários. |
| `database/mongodb/` | Camada documental de IA, agenda, memória, social, telemetria e operações flexíveis. | Eventos e interações de app. | Collections e validators. |
| `docs/specs/` | Especificações formais. | Código e DDLs. | Documentos funcionais/técnicos. |
| `frontend/flutter/` | APK/super app Android/Flutter. | APIs, ProductShellData, módulos, Helena. | Experiência mobile usuário/entregador/lojista quando habilitado. |
| `modules/` | Contratos e documentação por módulo. | Specs e DDLs. | README/CONTRACT por domínio. |
| `scripts/` | Automação, builders, geração de admin, PDFs, catálogos e orquestração DB. | Specs, seeds, templates. | Artefatos gerados e rotinas de implantação. |
| `output/` | Artefatos consolidados gerados. | Scripts e specs. | Memorial, deploy docs, relatórios. |
| `tmp/pdfs/` | Fontes textuais consolidadas de PDFs e regras. | Documentação v47. | Insumos para specs e geração. |

---

# 4. Admin

## 4.1 Necessidade do Admin

O Admin é necessário para controlar todo o ecossistema Valley com governança, segurança, rastreabilidade e capacidade operacional. Ele deve permitir que operadores e gestores vejam a saúde do sistema, ativem módulos, revisem usuários, aprovem regras, resolvam incidentes, fiscalizem integrações, acompanhem billing e auditem ações críticas.

## 4.2 Módulos Admin obrigatórios

| Módulo Admin | Necessidade | Resultado operacional |
|---|---|---|
| Dashboard Executivo | Centralizar KPIs e alertas. | Operador entende saúde da plataforma em poucos segundos. |
| Usuários e Identidade | Gerir PF, PJ, RIDER, ADMIN e SYSTEM. | Conta aprovada, bloqueada, revisada ou auditada. |
| Lojistas / PJ | Controlar KYB, CNPJ, lojas, billing e permissões. | Lojista apto a vender. |
| Entregadores | Controlar onboarding, veículo, CNH, disponibilidade e score. | Entregador apto a receber entregas/corridas. |
| Catálogo de Módulos | Controlar 41 módulos e status. | Módulo ativado, pausado ou em validação. |
| Regras de Negócio | Versionar regras de preço, taxa, compliance e consentimento. | Regra aprovada e rastreável. |
| Permissões Admin | Aplicar RBAC/ABAC por módulo. | Admin só acessa o que pode. |
| Billing | Controlar plano, fatura, assinatura, webhook e entitlement. | Receita SaaS conciliada. |
| Integrações Marketplace | Gerir ML, Amazon, Shopee, Magalu, CJ, AliExpress, Alibaba. | Seller conectado e sincronizado. |
| Observabilidade | Tratar incidentes e runbooks. | Falha identificada, priorizada e resolvida. |
| Documentos | Consultar evidências e comprovantes. | Documento rastreável por checksum. |
| Auditoria | Rastrear ações críticas. | Compliance e prestação de contas. |

## 4.3 Telas Admin

### 4.3.1 Login Admin

Componentes obrigatórios:

- Campo `username` ou e-mail.
- Campo senha.
- Campo 2FA quando política exigir.
- Seletor de ambiente: sandbox, homologação, produção.
- Flag `lembrar dispositivo`.
- Botão `Entrar`.
- Botão `Recuperar acesso`.
- Alerta de conta inativa.
- Alerta de senha inválida.
- Banner visual forte para produção.

Dados envolvidos:

| Campo/tabela | Origem | Destino |
|---|---|---|
| `admin_users.username` | Input login | Autenticação |
| `admin_users.password_hash` | Cadastro Admin | Verificação de senha |
| `admin_users.admin_role` | Superadmin | Permissões da sessão |
| `admin_users.is_active` | Admin | Bloqueio/liberação |
| `admin_users.last_login_at` | Auth | Auditoria |
| `admin_action_audit` | Login crítico/alterações | Trilha de segurança |

### 4.3.2 Dashboard Executivo

Componentes obrigatórios:

- Cards: usuários ativos, lojistas ativos, entregadores ativos, pedidos em aberto, GMV, receita billing, incidentes críticos, módulos bloqueados.
- Gráfico de pedidos por domínio: `FOOD`, `MOVE`, `DROPSHIP`.
- Gráfico por status: `DRAFT`, `PLACED`, `CONFIRMED`, `PREPARING`, `IN_TRANSIT`, `DELIVERED`, `COMPLETED`, `CANCELLED`, `REFUNDED`, `DISPUTED`.
- Tabela de incidentes abertos.
- Tabela de módulos críticos.
- Tabela de integrações com erro.
- Filtros: período, módulo, região, status, domínio, tier e data home.
- Botões: `Atualizar`, `Exportar`, `Abrir runbook`, `Criar incidente`, `Abrir módulo`.

Estados obrigatórios:

- Loading com skeleton.
- Estado vazio sem incidentes.
- Erro de API com botão tentar novamente.
- Modo somente leitura para `VIEWER`.

### 4.3.3 Usuários e Identidade

Filtros:

- Tipo: `PF`, `PJ`, `RIDER`, `ADMIN`, `SYSTEM`.
- Status da conta: `PENDING`, `ACTIVE`, `SUSPENDED`, `BLOCKED`, `ARCHIVED`.
- Status KYC: `NOT_STARTED`, `PENDING`, `UNDER_REVIEW`, `APPROVED`, `REJECTED`, `EXPIRED`.
- Documento.
- E-mail.
- Telefone.
- Risco 0 a 5.
- Região operacional.
- Data de criação.
- Tags internas.

Tabela:

- Nome.
- Documento.
- Tipo.
- Status.
- KYC/KYB.
- E-mail.
- Telefone.
- Risco.
- Último login.
- Região.
- Ações.

Tela detalhe:

- Aba `Resumo`.
- Aba `KYC/KYB`.
- Aba `Wallets`.
- Aba `Pedidos`.
- Aba `Transações`.
- Aba `Documentos`.
- Aba `Incidentes`.
- Aba `Auditoria`.
- Aba `Permissões` quando usuário for admin.

Ações:

- Aprovar KYC.
- Reprovar KYC.
- Suspender conta.
- Bloquear conta.
- Reativar conta.
- Inserir nota compliance.
- Adicionar tag.
- Remover tag.
- Exportar histórico.

### 4.3.4 Lojistas / PJ

Componentes:

- Lista de empresas.
- Filtro por CNPJ, razão social, nome fantasia, KYB, plano, status marketplace.
- Detalhe PJ com dados fiscais, representante legal, billing, wallets, fornecedores, armazéns, produtos e anúncios.

Campos obrigatórios:

- Razão social.
- Nome fantasia.
- CNPJ.
- Inscrição estadual.
- Inscrição municipal.
- Regime tributário.
- CNAE principal.
- CNAEs secundários.
- Representante legal.
- Documento do representante.
- E-mail de cobrança.
- Telefone de cobrança.
- Data de abertura.
- Status KYB.

Ações:

- Aprovar KYB.
- Suspender lojista.
- Validar dados fiscais.
- Abrir billing.
- Abrir ERP do lojista.
- Ver integrações.
- Criar incidente.

### 4.3.5 Entregadores

Componentes:

- Lista de riders.
- Mapa operacional por zona.
- Filtros por status, disponibilidade, zona, veículo, score, background check.
- Detalhe do rider.

Campos:

- Status rider.
- Disponibilidade.
- Tipo de veículo.
- Placa.
- Modelo.
- CNH.
- Categoria CNH.
- Validade CNH.
- Zona.
- Seguro.
- Background check.
- Score.

Ações:

- Aprovar onboarding.
- Bloquear rider.
- Suspender rider.
- Alterar zona.
- Ver entregas.
- Ver incidentes.
- Ver documentos.

### 4.3.6 Catálogo de Módulos

Tabela:

- Número.
- Código.
- Nome.
- Público principal.
- Público secundário.
- Função central.
- Modelo de monetização.
- Ativo.
- Documento fonte.
- Criado em.
- Atualizado em.

Ações:

- Ativar/desativar.
- Ver backlog.
- Ver regras.
- Ver permissões.
- Ver integrações.
- Ver contratos de evento.

### 4.3.7 Regras de Negócio

Telas:

1. Lista de regras.
2. Detalhe de regra.
3. Editor de versão JSON.
4. Dry-run.
5. Aprovação.
6. Histórico.
7. Rollback.

Campos:

- Código da regra.
- Módulo.
- Nome.
- Descrição.
- Severidade.
- Status.
- Constraints JSON.
- Versão.
- Definition JSON.
- Enabled.
- Change log.
- Admin aprovador.
- Data de aprovação.

Ações:

- Criar regra.
- Editar rascunho.
- Enviar para aprovação.
- Aprovar.
- Ativar.
- Desativar.
- Arquivar.
- Rollback.
- Rodar dry-run.

### 4.3.8 Billing

Telas:

- Clientes billing.
- Assinaturas.
- Faturas.
- Webhooks.
- Planos e entitlements.

Campos obrigatórios:

- Usuário.
- Wallet.
- PJ profile.
- Stripe customer id.
- E-mail billing.
- Nome billing.
- Status.
- Plano.
- Ciclo.
- Período atual.
- Cancelar ao fim do período.
- Fatura Stripe.
- Valor devido.
- Valor pago.
- URL fatura.
- PDF fatura.
- Evento webhook.
- Status processamento.

Ações:

- Criar cliente.
- Sincronizar Stripe.
- Ver fatura.
- Reprocessar webhook.
- Pausar assinatura.
- Cancelar assinatura.
- Alterar plano.
- Aplicar entitlement.

### 4.3.9 Integrações Marketplace

Provedores obrigatórios:

- Mercado Livre.
- Amazon.
- AliExpress.
- Alibaba.
- Magalu.
- CJDropshipping.
- Shopee.

Campos por integração:

- Provedor.
- Ambiente.
- Base URL.
- Seller/store id.
- Client id.
- Secret reference.
- Token status.
- Refresh token status.
- Scopes.
- Webhook URL.
- Webhook secret reference.
- Última sincronização catálogo.
- Última sincronização estoque.
- Último erro.
- Status.

Ações:

- Conectar.
- Reautorizar.
- Testar credenciais.
- Testar webhook.
- Sincronizar catálogo.
- Sincronizar estoque.
- Sincronizar pedidos.
- Pausar integração.
- Desativar integração.

---

# 5. Lojista / Valley ERP

## 5.1 Necessidade

O Lojista / Valley ERP é necessário para transformar um usuário PJ em operação comercial real. Ele deve permitir cadastro fiscal, catálogo, estoque, WMS, marketplace, pedidos, compras, ordens de serviço, financeiro, documentos e integrações externas.

## 5.2 Módulos do ERP

| Módulo ERP | Necessidade | Entidades principais |
|---|---|---|
| Cadastro da empresa | Validar operação PJ. | `users`, `pj_profiles`, `billing_customers` |
| Produtos | Criar catálogo vendável. | `inventory_items` |
| Estoque | Controlar saldo físico/lógico. | `inventory_lots`, `inventory_movements` |
| WMS | Operar armazéns e contagens. | `warehouses`, `warehouse_cycle_counts` |
| Marketplace | Publicar anúncios. | `marketplace_listings` |
| Pedidos | Atender vendas. | `orders`, `transactions` |
| Compras | Repor estoque. | `procurement_orders`, `procurement_order_items` |
| Serviços | Gerir ordens de serviço. | `service_work_orders` |
| Financeiro | Conciliar pagamentos. | `wallets`, `transactions`, `billing_invoices` |
| Integrações | Sincronizar canais externos. | Integrações marketplace e APIs |

## 5.3 Telas ERP

### 5.3.1 Home ERP

Componentes:

- Card vendas hoje.
- Card pedidos pendentes.
- Card pedidos em preparo.
- Card pedidos enviados.
- Card produtos sem estoque.
- Card produtos pausados.
- Card faturamento.
- Card saldo disponível.
- Card reposição sugerida.
- Card integrações com erro.

Filtros:

- Loja.
- Canal.
- Período.
- Status.
- Categoria.
- Armazém.
- Módulo.

### 5.3.2 Cadastro da empresa

Campos:

- Razão social.
- Nome fantasia.
- CNPJ.
- Inscrição estadual.
- Inscrição municipal.
- Regime tributário.
- CNAE principal.
- CNAEs secundários.
- Representante legal.
- Documento do representante.
- E-mail de cobrança.
- Telefone de cobrança.
- Data de abertura.
- Endereço fiscal.
- Status KYB.

Ações:

- Salvar rascunho.
- Enviar para validação.
- Anexar documento.
- Atualizar dados fiscais.
- Ver status KYB.

### 5.3.3 Produtos

Tabela:

- SKU.
- SKU externo.
- Nome.
- Tipo.
- Status.
- Categoria.
- Unidade.
- Preço base.
- Custo.
- Classe fiscal.
- Estoque disponível.
- Anúncios ativos.
- Última atualização.

Tela detalhe:

- Fotos.
- Nome comercial.
- Descrição.
- Tipo: físico, digital, serviço, bundle.
- Status: rascunho, ativo, pausado, arquivado.
- Categoria path.
- Unidade de medida.
- Preço base BRL.
- Custo referência BRL.
- Classe fiscal.
- Atributos JSON.
- Variações.
- Lotes vinculados.
- Anúncios vinculados.
- Histórico de movimentos.

Ações:

- Criar produto.
- Importar produto.
- Editar.
- Pausar.
- Arquivar.
- Publicar anúncio.
- Duplicar.
- Exportar.

### 5.3.4 Estoque e Lotes

Tabela de lotes:

- Produto.
- Armazém.
- Fornecedor.
- Código do lote.
- Status.
- Quantidade disponível.
- Quantidade reservada.
- Quantidade avariada.
- Custo unitário.
- Validade.
- Recebido em.

Ações:

- Receber estoque.
- Reservar.
- Liberar reserva.
- Ajustar.
- Transferir.
- Marcar avaria.
- Baixar perda.
- Vincular fornecedor.

### 5.3.5 WMS

Telas:

- Armazéns.
- Recebimento.
- Picking.
- Packing.
- Expedição.
- Transferências.
- Contagem cíclica.
- Divergências.

Campos de armazém:

- Código.
- Nome.
- Status.
- Dono.
- Gestor.
- Endereço JSON.
- GeoJSON.
- Capacidade.
- Metadados.

### 5.3.6 Marketplace

Tabela de anúncios:

- Título.
- Produto.
- Status.
- Preço.
- Comissão.
- Estratégia de estoque.
- Quantidade snapshot.
- Publicado em.
- Wallet.

Estratégias:

- `REAL_TIME` — estoque refletido em tempo real.
- `RESERVE_ON_ORDER` — reserva após pedido.
- `PREORDER` — venda sem estoque imediato.
- `DROPSHIP` — fulfillment pelo fornecedor.

Ações:

- Criar anúncio.
- Publicar.
- Pausar.
- Arquivar.
- Sincronizar canais.
- Alterar preço.
- Alterar comissão.
- Ver preview.

### 5.3.7 Pedidos

Tabela:

- Pedido.
- Cliente.
- Domínio.
- Status.
- Canal.
- Subtotal.
- Frete.
- Taxa de serviço.
- Desconto.
- Imposto.
- Total.
- Pagamento.
- Entregador.
- Tracking.
- Criado em.

Ações por status:

- Confirmar pedido.
- Iniciar preparo.
- Solicitar entrega.
- Despachar.
- Cancelar.
- Reembolsar.
- Abrir disputa.
- Imprimir comprovante.

### 5.3.8 Compras e reposição

Campos:

- Fornecedor.
- Comprador.
- Armazém destino.
- Wallet.
- Status.
- Total esperado.
- Moeda.
- Referência externa.
- Aprovador.
- Data de envio.
- Data prevista.
- Data recebida.
- Itens.
- Quantidade pedida.
- Quantidade recebida.
- Preço unitário.
- Total da linha.

Ações:

- Criar ordem.
- Adicionar item.
- Enviar para aprovação.
- Aprovar.
- Confirmar fornecedor.
- Receber parcial.
- Receber total.
- Disputar.
- Cancelar.

### 5.3.9 Ordens de serviço

Campos:

- Solicitante.
- Prestador.
- Wallet.
- Pedido vinculado.
- Status.
- Título.
- Descrição.
- Endereço de serviço.
- Valor estimado.
- Valor final.
- Agendamento.
- Início.
- Conclusão.
- Cancelamento.
- Motivo cancelamento.

Ações:

- Criar OS.
- Atribuir prestador.
- Iniciar.
- Aguardar peças.
- Concluir.
- Cancelar.
- Cobrar.

---

# 6. Usuário / APK Android

## 6.1 Necessidade

O APK Android do usuário é a superfície de consumo e relacionamento do Valley. Deve permitir cadastro, compra, pagamento, delivery, mobilidade, segurança, carteira, histórico de pedidos, notificações, Helena, agenda e consentimentos.

## 6.2 Módulos do APK usuário

| Módulo | Necessidade | Entidades principais |
|---|---|---|
| Onboarding | Criar identidade PF. | `users`, `wallets`, `document_records` |
| Home | Centralizar jornada. | Módulos, pedidos, wallet, notificações |
| Marketplace | Comprar produtos. | `marketplace_listings`, `inventory_items`, `orders` |
| Food | Comprar comida. | `orders`, `delivery_shipments` |
| Mobility | Solicitar corrida. | `orders`, `mobility_trips` |
| Wallet | Pagar e consultar saldo. | `wallets`, `transactions`, `led_cards` |
| Pedidos | Rastrear atividade. | `orders`, `delivery_shipments`, `delivery_shipment_events` |
| Helena | Chat, agenda, advisor e memória. | `chat_*`, `ai_memory`, `agenda_items`, `advisor_insights` |
| Segurança | SOS, contatos, biometria, incidentes. | `security_*` |
| Perfil | Configurar conta. | `users`, consentimentos, notificações |

## 6.3 Telas do APK usuário

### 6.3.1 Onboarding

Campos:

- Nome completo.
- Nome de exibição.
- E-mail.
- Telefone E.164.
- Data de nascimento.
- Cidade de nascimento.
- UF de nascimento.
- Nacionalidade.
- País do documento.
- Tipo de documento.
- Número do documento.
- Aceite de termos.
- Aceite de privacidade.
- PIN/senha.
- Biometria opcional.

Validações:

- E-mail em formato válido.
- Telefone E.164.
- Documento não vazio.
- Nome não vazio.
- Termos e privacidade aceitos.

### 6.3.2 Home

Componentes:

- Saudação.
- Busca global.
- Atalhos: Marketplace, Food, Mobilidade, Wallet, Pedidos, Helena, Segurança.
- Banner de campanha.
- Card saldo wallet.
- Card pontos/Pepitas.
- Card último pedido.
- Card entrega/corrida em andamento.
- Notificações.
- Recomendações Helena.

Estados:

- Usuário sem wallet.
- Usuário sem pedidos.
- Pedido em andamento.
- Incidente ativo.
- Consentimento pendente.

### 6.3.3 Marketplace

Componentes:

- Barra de busca.
- Filtros: preço, categoria, lojista, entrega, disponibilidade, avaliação.
- Ordenação: relevância, menor preço, maior preço, mais vendidos, perto de mim.
- Cards de produto.
- Badge de estoque.
- Badge promoção.
- Botão favoritar.
- Botão carrinho.

Tela detalhe:

- Imagens.
- Título.
- Descrição.
- Preço.
- Lojista.
- Prazo.
- Frete.
- Quantidade.
- Variações.
- Botão adicionar ao carrinho.
- Botão comprar agora.

### 6.3.4 Checkout

Campos:

- Endereço de entrega.
- Forma de pagamento.
- Wallet.
- Cupom.
- Observação.
- Agendamento.
- Subtotal.
- Frete.
- Taxa de serviço.
- Desconto.
- Imposto.
- Total.

Ações:

- Validar endereço.
- Aplicar cupom.
- Confirmar pedido.
- Cancelar checkout.

### 6.3.5 Pedidos

Abas:

- Em andamento.
- Entregues.
- Cancelados.
- Reembolsos.
- Disputas.

Tela detalhe:

- Número do pedido.
- Status.
- Linha do tempo.
- Mapa.
- Entregador.
- Loja.
- Itens.
- Valores.
- Pagamento.
- Documentos.
- Comprovante.
- Chat/suporte.
- Botão cancelar.
- Botão ajuda.
- Botão avaliar.

### 6.3.6 Wallet

Componentes:

- Saldo disponível BRL.
- Saldo bloqueado BRL.
- Saldo pendente BRL.
- Saldo disponível NEX.
- Limite diário.
- Limite mensal.
- Extrato.
- Cartão LED/NFC.
- Botão adicionar saldo.
- Botão transferir.
- Botão sacar quando aplicável.

### 6.3.7 Helena / Chat / Agenda / Advisor

Telas:

- Chat Helena.
- Conversas.
- Memórias.
- Agenda.
- Recomendações Advisor.
- Consentimentos.
- Histórico de ações.

Campos:

- Texto ou voz.
- Persona: pessoal/profissional.
- Escopo de consentimento: sessão, perfil, cross-module.
- Classificação de memória.
- Tarefa/agenda.
- Data/hora.
- Recorrência.
- Explicação do insight.
- Confiança.
- Risco.

Ações:

- Enviar mensagem.
- Falar com Helena.
- Ouvir resposta.
- Salvar memória.
- Criar lembrete.
- Aceitar recomendação.
- Rejeitar recomendação.
- Consentir execução.
- Revogar consentimento.

### 6.3.8 Segurança

Telas:

- Contatos confiáveis.
- Biometria.
- Incidentes.
- SOS.
- Histórico.
- Compartilhamento de rota.

Campos contato:

- Nome.
- Relação.
- Telefone.
- E-mail.
- Prioridade.
- Notificar SMS.
- Notificar e-mail.
- Notificar push.
- Ativo.

Ações:

- Acionar SOS.
- Adicionar contato.
- Desativar contato.
- Cadastrar biometria.
- Revogar biometria.
- Reportar incidente.
- Anexar evidência.

---

# 7. Entregador / APK Android

## 7.1 Necessidade

O APK do entregador é a superfície de execução logística. Ele deve permitir que um rider entre em operação, receba ofertas, aceite ou recuse, colete, navegue, registre checkpoints, finalize entregas, registre problemas, acione segurança e acompanhe ganhos.

## 7.2 Módulos do APK entregador

| Módulo | Necessidade | Entidades principais |
|---|---|---|
| Onboarding rider | Validar entregador. | `users`, `rider_profiles`, `document_records` |
| Disponibilidade | Entrar/sair de operação. | `rider_profiles.availability_status` |
| Ofertas | Receber dispatch. | `delivery_shipments`, `mobility_trips` |
| Coleta | Confirmar retirada. | `delivery_shipment_events` |
| Rota | Navegação e checkpoints. | `delivery_shipment_events`, `mobility_trip_events` |
| Entrega | Finalizar com prova. | `delivery_shipments`, `document_records` |
| Ganhos | Visualizar remuneração. | `wallets`, `transactions`, `orders` |
| Performance | Acompanhar score. | `rider_profiles.performance_score` |
| Segurança | SOS e incidentes. | `security_incidents`, `security_incident_events` |

## 7.3 Telas do APK entregador

### 7.3.1 Onboarding rider

Campos:

- Nome completo.
- Documento.
- Telefone.
- CNH.
- Categoria CNH.
- Validade CNH.
- Tipo de veículo.
- Placa.
- Modelo.
- Zona de atendimento.
- Seguro.
- Selfie.
- Documentos anexos.
- Aceite dos termos.

Validações:

- Placa no formato esperado.
- CNH não vazia quando veículo exigir.
- Telefone E.164.
- Documento obrigatório.
- Background check aprovado antes de ficar ativo.

### 7.3.2 Home Entregador

Componentes:

- Toggle online/offline.
- Status: `OFFLINE`, `ONLINE`, `BUSY`, `PAUSED`.
- Zona atual.
- Ganhos do dia.
- Entregas concluídas.
- Score.
- Alertas.
- Botão pausar.
- Botão encerrar turno.
- Botão SOS.

### 7.3.3 Oferta de entrega/corrida

Componentes:

- Tipo: Food, Courier, Marketplace, Pharmacy, Document ou Mobility.
- Origem.
- Destino.
- Distância.
- Tempo estimado.
- Valor.
- Quantidade de pacotes.
- Peso.
- Valor declarado.
- Observações.
- Timer.
- Botão aceitar.
- Botão recusar.

Eventos:

- Oferta recebida.
- Oferta aceita.
- Oferta recusada.
- Oferta expirada.

### 7.3.4 Coleta

Campos:

- Código da entrega.
- Endereço retirada.
- Nome do contato.
- Telefone do contato.
- Lista de pacotes.
- Peso.
- Valor declarado.
- Observações.
- Foto coleta.
- QR/barcode.

Ações:

- Cheguei.
- Coletado.
- Reportar problema.
- Anexar evidência.
- Ligar para contato.
- Abrir suporte.

### 7.3.5 Rota

Componentes:

- Mapa.
- ETA.
- Distância restante.
- Próximo checkpoint.
- Botão abrir navegação externa.
- Chat/suporte.
- Botão problema na rota.
- Botão SOS.

Eventos:

- Checkpoint.
- Desvio.
- Atraso.
- Risco.
- Incidente.

### 7.3.6 Entrega

Campos:

- Código/PIN.
- Foto.
- Assinatura.
- Documento/comprovante.
- Nome recebedor.
- Observação.
- Geolocalização.
- Motivo de falha quando falhar.

Ações:

- Confirmar entrega.
- Falha na entrega.
- Anexar prova.
- Cancelar com suporte.
- Reportar ausência.

### 7.3.7 Ganhos

Componentes:

- Ganhos hoje.
- Ganhos semana.
- Histórico por entrega.
- Taxas.
- Gorjetas.
- Bloqueios.
- Saques.
- Wallet.
- Extrato.

### 7.3.8 Segurança

Componentes:

- SOS.
- Incidentes.
- Contatos de emergência.
- Evidências.
- Rota compartilhada.
- Biometria.

Ações:

- Acionar SOS.
- Reportar ameaça.
- Reportar acidente.
- Enviar localização.
- Anexar foto/áudio/documento.

---

# 8. Dicionário de dados consolidado

## 8.1 Identidade e perfis

### `users`

| Campo | Tipo | Origem | Destino |
|---|---|---|---|
| `user_id` | UUID | Sistema | Todas as relações |
| `user_kind` | enum | Onboarding/Admin | Segmentação e regras |
| `account_status` | enum | Admin/KYC | Acesso |
| `kyc_status` | enum | KYC/Admin | Compliance |
| `full_name` | TEXT | Onboarding | Perfil e documentos |
| `display_name` | TEXT | App | UI |
| `email` | TEXT | Onboarding | Login, billing, notificações |
| `phone_e164` | TEXT | Onboarding | OTP, delivery, suporte |
| `birth_date` | DATE | KYC | Compliance |
| `birth_city` | TEXT | KYC | Compliance |
| `birth_state` | CHAR(2) | KYC | Compliance |
| `document_country` | CHAR(2) | KYC | Documento |
| `document_type` | TEXT | KYC | Documento |
| `document_number` | TEXT | KYC | Documento |
| `nationality` | CHAR(2) | KYC | Compliance |
| `tax_residence_country` | CHAR(2) | KYC/Fiscal | Compliance |
| `risk_level` | SMALLINT | Motor risco/Admin | Limites e segurança |
| `primary_role` | TEXT | Admin/Sistema | Experiência e autorização |
| `nexus_external_ref` | TEXT | Integração | Reconciliação |
| `led_card_default_id` | UUID | Pay/Admin | NFC/LED card |
| `terms_accepted_at` | TIMESTAMPTZ | Onboarding | Auditoria |
| `privacy_accepted_at` | TIMESTAMPTZ | Onboarding | Auditoria |
| `last_login_at` | TIMESTAMPTZ | Auth | Segurança |
| `module_tier` | TEXT | Admin/Billing | Entitlements |
| `ops_region_code` | TEXT | Admin | Operação regional |
| `compliance_notes` | TEXT | Compliance | Auditoria |
| `internal_tags` | TEXT[] | Admin | Segmentação |
| `created_at` | TIMESTAMPTZ | Sistema | Auditoria |
| `updated_at` | TIMESTAMPTZ | Trigger | Auditoria |

### `pj_profiles`

| Campo | Tipo | Origem | Destino |
|---|---|---|---|
| `pj_profile_id` | UUID | Sistema | ERP/Billing |
| `user_id` | UUID | `users` | Perfil PJ |
| `legal_name` | TEXT | Cadastro PJ | Fiscal/KYB |
| `trade_name` | TEXT | Cadastro PJ | Vitrine/ERP |
| `cnpj` | TEXT | Cadastro PJ | Fiscal/KYB |
| `state_registration` | TEXT | Cadastro PJ | Fiscal |
| `municipal_registration` | TEXT | Cadastro PJ | Fiscal |
| `tax_regime` | TEXT | Cadastro PJ | Fiscal |
| `cnae_primary` | TEXT | Cadastro PJ | Fiscal |
| `cnae_secondary` | TEXT[] | Cadastro PJ | Fiscal |
| `legal_representative_name` | TEXT | KYB | Compliance |
| `legal_representative_document` | TEXT | KYB | Compliance |
| `billing_email` | TEXT | PJ/Billing | Cobrança |
| `billing_phone` | TEXT | PJ/Billing | Cobrança |
| `incorporation_date` | DATE | KYB | Compliance |
| `kyb_status` | enum | Admin/KYB | Liberação loja |
| `kyb_verified_at` | TIMESTAMPTZ | Admin/KYB | Auditoria |
| `created_at` | TIMESTAMPTZ | Sistema | Auditoria |
| `updated_at` | TIMESTAMPTZ | Trigger | Auditoria |

### `rider_profiles`

| Campo | Tipo | Origem | Destino |
|---|---|---|---|
| `rider_profile_id` | UUID | Sistema | Rider app/Admin |
| `user_id` | UUID | `users` | Entregador |
| `rider_status` | enum | Admin/onboarding | Dispatch |
| `mode_preference` | TEXT | App rider | Matching |
| `vehicle_type` | TEXT | Onboarding | Dispatch |
| `vehicle_plate` | TEXT | Onboarding | Compliance |
| `vehicle_model` | TEXT | Onboarding | Perfil rider |
| `driver_license_number` | TEXT | Onboarding | Compliance |
| `driver_license_category` | TEXT | Onboarding | Compliance |
| `driver_license_expires_at` | DATE | Onboarding | Bloqueio preventivo |
| `service_zone_code` | TEXT | App/Admin | Dispatch |
| `availability_status` | TEXT | App rider | Matching |
| `background_check_status` | enum | Compliance | Liberação |
| `insurance_policy_ref` | TEXT | Onboarding | Compliance |
| `performance_score` | NUMERIC(5,2) | Sistema | Ranking/dispatch |
| `created_at` | TIMESTAMPTZ | Sistema | Auditoria |
| `updated_at` | TIMESTAMPTZ | Trigger | Auditoria |

## 8.2 Carteiras e pagamentos

### `wallets`

| Campo | Tipo | Origem | Destino |
|---|---|---|---|
| `wallet_id` | UUID | Sistema | Pagamentos |
| `user_id` | UUID | `users` | Dono wallet |
| `wallet_type` | enum | Pay/Admin | Tipo de uso |
| `asset_code` | enum BRL/NEX | Pay | Saldos |
| `wallet_status` | enum | Pay/Admin | Bloqueio/liberação |
| `balance_available_brl` | DECIMAL(18,4) | Ledger | App/ERP |
| `balance_blocked_brl` | DECIMAL(18,4) | Ledger | Risco/escrow |
| `balance_pending_brl` | DECIMAL(18,4) | Ledger | Conciliação |
| `balance_available_nex` | DECIMAL(18,8) | Ledger | NEX/equity |
| `balance_blocked_nex` | DECIMAL(18,8) | Ledger | Lock |
| `balance_pending_nex` | DECIMAL(18,8) | Ledger | Pendências |
| `daily_limit_brl` | DECIMAL(18,4) | Admin/Pay | Limites |
| `monthly_limit_brl` | DECIMAL(18,4) | Admin/Pay | Limites |
| `ledger_version` | BIGINT | Sistema | Reconciliação |
| `last_reconciled_at` | TIMESTAMPTZ | Sistema | Auditoria |
| `created_at` | TIMESTAMPTZ | Sistema | Auditoria |
| `updated_at` | TIMESTAMPTZ | Trigger | Auditoria |

### `transactions`

| Campo | Tipo | Origem | Destino |
|---|---|---|---|
| `transaction_id` | UUID | Sistema | Extrato/ledger |
| `user_id` | UUID | Pedido/wallet | Dono |
| `wallet_id` | UUID | Wallet | Carteira origem |
| `counterparty_user_id` | UUID | Pagamento/split | Contraparte |
| `counterparty_wallet_id` | UUID | Pagamento/split | Wallet contraparte |
| `transaction_type` | enum | Pay | Classificação |
| `transaction_status` | enum | Pay | Estado |
| `order_id` | UUID | Pedido | Conciliação |
| `asset_code` | enum | Wallet | BRL/NEX |
| `amount_brl` | DECIMAL(18,4) | Checkout | Extrato |
| `amount_nex` | DECIMAL(18,8) | NEX | Extrato |
| `fee_amount_brl` | DECIMAL(18,4) | Regra taxa | Receita |
| `platform_amount_brl` | DECIMAL(18,4) | Split | Plataforma |
| `merchant_amount_brl` | DECIMAL(18,4) | Split | Lojista |
| `affiliate_amount_brl` | DECIMAL(18,4) | Split | Afiliado |
| `escrow_amount_brl` | DECIMAL(18,4) | Escrow | Retenção |
| `fx_rate` | DECIMAL(18,8) | Conversão | Câmbio |
| `reference_code` | TEXT | Sistema | Idempotência |
| `external_reference` | TEXT | Gateway/Stripe | Integração |
| `channel` | TEXT | App/Admin/API | Origem canal |
| `origin_module` | TEXT | Módulo | Auditoria |
| `description` | TEXT | Sistema | Extrato |
| `metadata_json` | JSONB | Sistema | Extensões |
| `authorized_at` | TIMESTAMPTZ | Pay | Auditoria |
| `settled_at` | TIMESTAMPTZ | Pay | Conciliação |
| `failed_at` | TIMESTAMPTZ | Pay | Erro |
| `created_at` | TIMESTAMPTZ | Sistema | Auditoria |

## 8.3 Pedidos

### `orders`

| Campo | Tipo | Origem | Destino |
|---|---|---|---|
| `order_id` | UUID | Sistema | Pedido |
| `user_id` | UUID | Checkout | Cliente |
| `wallet_id` | UUID | Checkout | Pagamento |
| `order_domain` | enum | Módulo | FOOD/MOVE/DROPSHIP |
| `order_status` | enum | Sistema/Admin | Lifecycle |
| `merchant_user_id` | UUID | Listing/ERP | Lojista |
| `rider_user_id` | UUID | Dispatch | Entregador/motorista |
| `affiliate_user_id` | UUID | Campanha | Comissão |
| `source_channel` | TEXT | App/API/Admin | Origem |
| `currency_code` | CHAR(3) | Checkout | Moeda |
| `subtotal_brl` | DECIMAL(18,4) | Carrinho | Cálculo |
| `delivery_fee_brl` | DECIMAL(18,4) | Frete | Cálculo |
| `service_fee_brl` | DECIMAL(18,4) | Regra | Cálculo |
| `discount_brl` | DECIMAL(18,4) | Cupom | Cálculo |
| `tax_brl` | DECIMAL(18,4) | Fiscal | Cálculo |
| `total_brl` | DECIMAL(18,4) | Checkout | Pagamento |
| `total_nex` | DECIMAL(18,8) | Checkout NEX | Pagamento |
| `payment_transaction_id` | UUID | Pay | Conciliação |
| `pickup_address_json` | JSONB | Loja/mobility | Logística |
| `dropoff_address_json` | JSONB | Usuário | Logística |
| `scheduled_for` | TIMESTAMPTZ | Usuário/ERP | Agenda |
| `confirmed_at` | TIMESTAMPTZ | Lojista | Timeline |
| `dispatched_at` | TIMESTAMPTZ | Dispatch | Timeline |
| `delivered_at` | TIMESTAMPTZ | Entrega | Timeline |
| `cancelled_at` | TIMESTAMPTZ | Cancelamento | Auditoria |
| `cancellation_reason` | TEXT | Usuário/Admin | Auditoria |
| `customer_notes` | TEXT | Checkout | Loja/entrega |
| `ops_notes` | TEXT | Admin/ERP | Operação |
| `restaurant_user_id` | UUID | Food | Restaurante |
| `kitchen_status` | TEXT | Food ERP | Preparo |
| `prep_started_at` | TIMESTAMPTZ | Restaurante | Timeline |
| `route_distance_km` | DECIMAL(12,3) | Rota | Analytics |
| `route_duration_sec` | INTEGER | Rota | ETA |
| `surge_multiplier` | DECIMAL(8,4) | Mobility | Preço dinâmico |
| `vehicle_category` | TEXT | Mobility | Matching |
| `supplier_name` | TEXT | Dropship | Fulfillment |
| `supplier_sku` | TEXT | Dropship | Fulfillment |
| `tracking_code` | TEXT | Logística | Rastreio |
| `tracking_provider` | TEXT | Logística | Rastreio |
| `customs_status` | TEXT | Dropship | Internacional |
| `created_at` | TIMESTAMPTZ | Sistema | Auditoria |
| `updated_at` | TIMESTAMPTZ | Trigger | Auditoria |

## 8.4 ERP e Marketplace

### `inventory_items`

| Campo | Tipo | Origem | Destino |
|---|---|---|---|
| `item_id` | UUID | Sistema | Produto |
| `merchant_user_id` | UUID | Lojista | Dono |
| `module_code` | TEXT | Sistema | MARKETPLACE |
| `item_sku` | TEXT | ERP/importação | SKU interno |
| `external_sku` | TEXT | Integração | SKU externo |
| `item_name` | TEXT | ERP | Vitrine |
| `item_description` | TEXT | ERP | Vitrine |
| `item_type` | enum | ERP | Produto/serviço |
| `item_status` | enum | ERP | Publicação |
| `category_path` | TEXT[] | ERP | Busca/filtro |
| `unit_of_measure` | TEXT | ERP | Estoque |
| `base_price_brl` | DECIMAL(18,4) | ERP | Preço |
| `cost_reference_brl` | DECIMAL(18,4) | ERP | Margem |
| `tax_class` | TEXT | Fiscal | Impostos |
| `attributes_json` | JSONB | ERP | Variações/atributos |
| `created_at` | TIMESTAMPTZ | Sistema | Auditoria |
| `updated_at` | TIMESTAMPTZ | Trigger | Auditoria |

### `marketplace_listings`

| Campo | Tipo | Origem | Destino |
|---|---|---|---|
| `listing_id` | UUID | Sistema | Anúncio |
| `merchant_user_id` | UUID | Lojista | Dono |
| `wallet_id` | UUID | ERP | Recebimento |
| `item_id` | UUID | Produto | Anúncio |
| `module_code` | TEXT | Sistema | MARKETPLACE |
| `listing_status` | enum | ERP | Vitrine |
| `listing_title` | TEXT | ERP | Vitrine |
| `listing_description` | TEXT | ERP | Vitrine |
| `price_brl` | DECIMAL(18,4) | ERP | Checkout |
| `commission_rate` | DECIMAL(8,4) | Regra/Admin | Split |
| `stock_strategy` | TEXT | ERP | Reserva |
| `available_quantity_snapshot` | DECIMAL(18,4) | Estoque | Vitrine |
| `published_at` | TIMESTAMPTZ | ERP | Vitrine |
| `created_at` | TIMESTAMPTZ | Sistema | Auditoria |
| `updated_at` | TIMESTAMPTZ | Trigger | Auditoria |

### `delivery_shipments`

| Campo | Tipo | Origem | Destino |
|---|---|---|---|
| `shipment_id` | UUID | Sistema | Entrega |
| `order_id` | UUID | Pedido | Entrega |
| `module_code` | TEXT | Sistema | DELIVERY |
| `requester_user_id` | UUID | Pedido | Solicitante |
| `merchant_user_id` | UUID | Pedido | Loja |
| `rider_user_id` | UUID | Dispatch | Entregador |
| `wallet_id` | UUID | Pedido | Pagamento/frete |
| `source_order_domain` | enum | Pedido | FOOD/DROPSHIP |
| `shipment_kind` | enum | Sistema | Tipo entrega |
| `shipment_status` | enum | Dispatch/app rider | Lifecycle |
| `pickup_address_json` | JSONB | Loja | Coleta |
| `dropoff_address_json` | JSONB | Usuário | Entrega |
| `pickup_contact_name` | TEXT | Loja | Rider |
| `pickup_contact_phone` | TEXT | Loja | Rider |
| `receiver_contact_name` | TEXT | Usuário | Rider |
| `receiver_contact_phone` | TEXT | Usuário | Rider |
| `package_count` | SMALLINT | ERP | Logística |
| `package_weight_kg` | DECIMAL(10,3) | ERP | Logística |
| `declared_value_brl` | DECIMAL(18,4) | ERP | Seguro/risco |
| `delivery_fee_brl` | DECIMAL(18,4) | Frete | Pagamento |
| `cash_to_collect_brl` | DECIMAL(18,4) | Checkout | Cobrança local |
| `route_distance_km` | DECIMAL(12,3) | Roteirização | ETA |
| `route_duration_sec` | INTEGER | Roteirização | ETA |
| `proof_code_hash` | TEXT | Entrega | Prova |
| `proof_document_id` | UUID | Documento | Comprovante |
| `dispatch_started_at` | TIMESTAMPTZ | Dispatch | Timeline |
| `assigned_at` | TIMESTAMPTZ | Dispatch | Timeline |
| `picked_up_at` | TIMESTAMPTZ | App rider | Timeline |
| `delivered_at` | TIMESTAMPTZ | App rider | Timeline |
| `failed_at` | TIMESTAMPTZ | App rider | Falha |
| `cancelled_at` | TIMESTAMPTZ | Sistema/Admin | Cancelamento |
| `cancellation_reason` | TEXT | App/Admin | Auditoria |
| `status_notes` | TEXT | App/Admin | Operação |
| `metadata_json` | JSONB | Sistema | Extensões |
| `created_at` | TIMESTAMPTZ | Sistema | Auditoria |
| `updated_at` | TIMESTAMPTZ | Trigger | Auditoria |

---

# 9. Eventos e notificações

## 9.1 Eventos mínimos

| Evento | Produtor | Consumidores |
|---|---|---|
| `user.created` | Onboarding | Admin, KYC, Wallet |
| `pj.kyb.submitted` | ERP | Admin, Compliance |
| `rider.onboarding.submitted` | Rider APK | Admin, Compliance |
| `listing.published` | ERP | Marketplace, Usuário APK |
| `order.placed` | Usuário APK | ERP, Pay, Admin |
| `payment.authorized` | Pay | Pedidos, ERP, Usuário |
| `delivery.dispatch.started` | Dispatch | Rider APK, Admin |
| `delivery.rider.assigned` | Dispatch | Usuário, Rider, Loja |
| `delivery.picked_up` | Rider APK | Usuário, Loja, Admin |
| `delivery.delivered` | Rider APK | Usuário, Loja, Pay |
| `mobility.trip.matched` | Mobility | Usuário, Rider |
| `security.sos.created` | APK | Admin, contatos confiáveis |
| `billing.invoice.paid` | Stripe webhook | Billing, Admin |
| `admin.rule.approved` | Admin | Runtime, Auditoria |
| `helena.consent.recorded` | APK | Advisor, Auditoria |

## 9.2 Notificações

### Usuário

- Pedido confirmado.
- Pedido em preparo.
- Entregador atribuído.
- Pedido coletado.
- Pedido entregue.
- Pagamento falhou.
- Reembolso emitido.
- SOS acionado.
- Lembrete Helena.
- Consentimento necessário.

### Lojista

- Novo pedido.
- Pagamento autorizado.
- Estoque baixo.
- Produto sem estoque.
- Integração com erro.
- Compra pendente de aprovação.
- Fatura vencida.

### Entregador

- Nova oferta.
- Oferta expirada.
- Rota alterada.
- Entrega cancelada.
- Incidente aberto.
- Ganho liquidado.

### Admin

- Incidente crítico.
- Webhook falhou.
- Módulo bloqueado.
- Regra pendente de aprovação.
- KYC/KYB pendente.
- Integração marketplace offline.

---

# 10. Critérios de aceite por superfície

## 10.1 Admin

- Deve autenticar admin ativo.
- Deve respeitar `admin_permissions` por módulo.
- Deve registrar ações críticas em `admin_action_audit`.
- Deve permitir consulta e filtro de usuários, lojistas, entregadores, pedidos e incidentes.
- Deve controlar regras versionadas.
- Deve reprocessar webhooks billing.
- Deve mostrar status de integrações marketplace.

## 10.2 Lojista / ERP

- Deve permitir cadastro PJ completo.
- Deve criar produto e anúncio.
- Deve controlar estoque por lote e armazém.
- Deve receber e confirmar pedido.
- Deve acionar delivery quando necessário.
- Deve reconciliar pagamento e pedido.
- Deve operar compras e reposição.

## 10.3 Usuário / APK Android

- Deve cadastrar usuário PF.
- Deve criar wallet inicial.
- Deve navegar por módulos ativos.
- Deve comprar produto ou serviço.
- Deve acompanhar pedido em tempo real.
- Deve consultar wallet e extrato.
- Deve usar Helena com consentimento controlado.
- Deve acionar segurança/SOS.

## 10.4 Entregador / APK Android

- Deve concluir onboarding rider.
- Deve alternar disponibilidade.
- Deve receber oferta.
- Deve aceitar/recusar oferta.
- Deve confirmar coleta.
- Deve registrar checkpoints.
- Deve finalizar entrega com prova.
- Deve consultar ganhos.
- Deve acionar SOS/incidente.

---

# 11. Backlog de implementação recomendado

## Fase 1 — Núcleo operacional

1. Admin: usuários, módulos, permissões e auditoria.
2. ERP: produtos, estoque, anúncios e pedidos.
3. APK usuário: onboarding, home, marketplace, checkout e pedidos.
4. APK entregador: onboarding, disponibilidade, ofertas, coleta e entrega.
5. Backend: APIs para `users`, `wallets`, `orders`, `transactions`, `inventory_items`, `marketplace_listings`, `delivery_shipments`.

## Fase 2 — Governança e integrações

1. Regras versionadas.
2. Billing completo.
3. Integrações marketplace.
4. Webhooks.
5. Observabilidade.
6. Documentos e comprovantes.

## Fase 3 — Helena, segurança e inteligência

1. Helena Chat.
2. Agenda.
3. Advisor com consentimento.
4. Memória operacional.
5. Segurança/SOS.
6. Incidentes com escalonamento.

## Fase 4 — Escala

1. Analytics.
2. Otimização de dispatch.
3. WMS avançado.
4. Score rider.
5. Fraude e risco.
6. Automação de suporte.

---

# 12. Resumo executivo

O Valley deve operar como um ecossistema modular integrado. O Admin governa o sistema; o Lojista / ERP vende e opera; o Usuário / APK consome, paga e interage; o Entregador / APK executa a última milha e corridas.

A implementação deve respeitar o core-first em `users`, usar `wallets` e `transactions` como fonte financeira, `orders` como contrato comercial, `inventory_*` como base do ERP/marketplace, `delivery_*` e `mobility_*` como operação de campo, `security_*` como camada de proteção, `billing_*` como receita SaaS e `admin_*` como governança/auditoria.
