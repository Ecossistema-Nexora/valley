# VALLEY MVP EXECUTION BACKLOG

Este arquivo e gerado por `scripts/generate_valley_mvp_execution_artifacts.py`.
Fonte canonica: `docs/specs/valley-mvp-execution-plan.md` e `config/mvp/valley_mvp_manifest.v1.json`.

## Resumo
- Manifesto: `VALLEY MVP Execution Manifest` v`1.0.0`
- Modo de execucao: `controlled_artifacts_only`
- Objetivo: Construir um MVP viavel focado em geracao de receita imediata, baixo custo operacional e validacao de fluxo financeiro e operacional.
- Principio central: O MVP nao e um produto completo. E uma maquina de transacao, identidade e estoque.

## Escopo MVP
- Modulos incluidos:
  - `PAY` - Valley Pay | fase `VALIDATE` | data home `postgres`
  - `PLUG` - Valley Plug | fase `DATA_CONTRACT` | data home `postgres`
  - `DOCS` - Valley Docs | fase `DATA_CONTRACT` | data home `postgres`
  - `BUSINESS` - Valley Business | fase `DATA_CONTRACT` | data home `postgres`
  - `REPLY` - Valley REPLY | fase `VALIDATE` | data home `postgres`
  - `STOCK` - Valley Stock | fase `VALIDATE` | data home `postgres`
  - `WMS` - Valley WMS | fase `VALIDATE` | data home `postgres_mongo`
  - `MARKETPLACE` - Valley Marketplace | fase `VALIDATE` | data home `postgres`
  - `ADVISOR` - Valley Advisor | fase `BUILD` | data home `postgres_mongo`
  - `CHAT` - Valley Chat | fase `VALIDATE` | data home `postgres_mongo`
  - `AGENDA` - Valley Agenda | fase `VALIDATE` | data home `mongo`
- Modulos fora do MVP:
  - `DELIVERY` - Valley Delivery | fase `VALIDATE` | mantido fora do corte inicial
  - `FOOD` - Valley Food | fase `DATA_CONTRACT` | mantido fora do corte inicial
  - `MOBILITY` - Valley Mobility | fase `VALIDATE` | mantido fora do corte inicial
  - `SOCIAL` - Valley Social | fase `BUILD` | mantido fora do corte inicial
  - `GAMING` - Valley Gaming | fase `VALIDATE` | mantido fora do corte inicial
  - `IOT` - Valley IoT | fase `VALIDATE` | mantido fora do corte inicial

## Frente transversal de identidade unica
Frente transversal do MVP. Nao cria um novo modulo; usa o nucleo de identidade, seguranca e risco ja existentes.
### Face ID
- Modo de entrega: `schema_and_event_reuse`
- Donos: `core_identity_wallets`, `SECURITY`
- Evidencias base: `users`, `led_cards`, `security_biometric_credentials`
- Eventos: `security.biometric.enrolled`
- Objetivo: Biometria facial para reduzir fraude e habilitar trilhas sensiveis.

### Voice ID
- Modo de entrega: `spec_first`
- Donos: `core_identity_wallets`, `SECURITY`, `LEGAL`
- Evidencias base: `users`, `led_cards`
- Eventos: `spec-first`, sem topico canonico fechado ainda
- Objetivo: Validacao vocal para reforco de autenticacao e prova de aceite em operacoes sensiveis.

### Identity Score
- Modo de entrega: `aggregated_risk_profile`
- Donos: `core_identity_wallets`, `PAY`, `SECURITY`, `MARKETPLACE`
- Evidencias base: `users.risk_level`, `security_signal_logs`, `sale_validation_events`, `transactions`, `merchant_storefronts`
- Eventos: `pay.transaction.posted`, `marketplace.sale.validated`, `security.incident.closed`
- Objetivo: Score de reputacao e antifraude para operacoes de pagamento, seller onboarding e aprovacoes de risco.

## Fases de execucao
### Fase 1 - Ativacao do Core
- Objetivo da fase: Fechar o nucleo financeiro e empresarial que gera monetizacao e trilha documental desde a primeira operacao.
- Modulos desta fase:
#### 08. `PAY` - Valley Pay
- Dominio: `commerce_fintech_assets`
- Tier: `foundation`
- Fase atual: `VALIDATE`
- Data home: `postgres`
- Objetivo: Carteira, ledger atomico, P2P, splits, limites e conciliacao.
- Backlog imediato:
  - fechar matriz de limites
  - amarrar regras de chargeback
  - instrumentar reconciliacao D0 e D1
#### 43. `PLUG` - Valley Plug
- Dominio: `commerce_fintech_assets`
- Tier: `core`
- Fase atual: `DATA_CONTRACT`
- Data home: `postgres`
- Objetivo: Maquininha, Tap-to-Pay, MDR e antecipacao D+0.
- Backlog imediato:
  - criar contrato especifico de terminal
  - definir MDR por faixa
  - ligar fluxo D0 de antecipacao
#### 47. `DOCS` - Valley Docs
- Dominio: `platform_developer`
- Tier: `foundation`
- Fase atual: `DATA_CONTRACT`
- Data home: `postgres`
- Objetivo: Geracao de documentos, recibos, checksums e registros imutaveis.
- Backlog imediato:
  - criar contrato especifico de template
  - definir trilha de checksum
  - ligar versionamento de recibo
#### 42. `BUSINESS` - Valley Business
- Dominio: `logistics_erp_operations`
- Tier: `foundation`
- Fase atual: `DATA_CONTRACT`
- Data home: `postgres`
- Objetivo: ERP integrado para empresas, fiscais, estoque e folha.
- Backlog imediato:
  - criar contrato especifico de empresa e unidade
  - definir visao fiscal consolidada
  - ligar fluxo de folha e invoices
#### 01. `REPLY` - Valley REPLY
- Dominio: `logistics_erp_operations`
- Tier: `foundation`
- Fase atual: `VALIDATE`
- Data home: `postgres`
- Objetivo: ERP/WMS para compras, estoque, ordens de servico e faturamento.
- Backlog imediato:
  - fechar fluxo fiscal ponta a ponta
  - amarrar aprovacao por unidade
  - instrumentar SLA de compras
- Gates de sucesso:
  - wallet, ledger e conciliacao validados
  - captura de pagamento e MDR modelados
  - documento e recibo com checksum rastreavel
  - empresa onboardada com rotina empresarial minima
  - ordem de servico e compras com fechamento fiscal ponta a ponta

### Fase 2 - Comercio
- Objetivo da fase: Abrir a camada de catalogo, estoque e venda para gerar fluxo comercial sem CAPEX pesado.
- Modulos desta fase:
#### 02. `STOCK` - Valley Stock
- Dominio: `logistics_erp_operations`
- Tier: `foundation`
- Fase atual: `VALIDATE`
- Data home: `postgres`
- Objetivo: Motor de dropshipping com fornecedores externos, margem padrao e tracking.
- Backlog imediato:
  - definir politica de margem por canal
  - fechar conciliacao com fornecedor
  - amarrar excecao de ruptura
#### 06. `WMS` - Valley WMS
- Dominio: `logistics_erp_operations`
- Tier: `foundation`
- Fase atual: `VALIDATE`
- Data home: `postgres_mongo`
- Objetivo: Gestao inteligente de armazens, sensores e estoque multi-deposito.
- Backlog imediato:
  - fechar mapa de enderecamento
  - amarrar ajuste de variancia
  - ligar alarmes por temperatura
#### 07. `MARKETPLACE` - Valley Marketplace
- Dominio: `commerce_fintech_assets`
- Tier: `foundation`
- Fase atual: `VALIDATE`
- Data home: `postgres`
- Objetivo: Comercio local centralizado, carrinho, produtos e recomendacoes.
- Backlog imediato:
  - fechar politica de seller score
  - definir moderacao de catalogo
  - amarrar regras anti-fraude de checkout
- Modelo visual/comercial do STOCK:
  - Referencia de comportamento: Mercado Livre, AliExpress, Shopee
  - Regra de identidade Valley: Usar profundidade de catalogo, busca, ofertas, variacoes e seller score sem copiar identidade visual dos concorrentes.
  - Direcao visual: Night/Cosmic como base, Violet para compra, Cyan para confianca operacional e cards claros para produto.
  - Superficies obrigatorias:
    - busca principal
    - categorias
    - vitrine de ofertas
    - card de produto com selo Valley
    - seller score
    - variacoes de produto
    - checkout conectado a PAY e PLUG
    - comprovante e documento por DOCS
  - Integracoes configuraveis no admin: Mercado Livre, Amazon, AliExpress, Alibaba, Magalu, CJDropshipping, Shopee
  - Campos de configuracao por integracao:
    - ambiente
    - regiao/site
    - modo de autenticacao
    - base URL
    - client/app key
    - referencia de segredo
    - access token ref
    - refresh token ref
    - seller/store ID
    - webhook URL
    - webhook secret ref
    - escopos
    - cadencia de sincronizacao
    - cache TTL
    - margem minima
    - rotinas ativas de catalogo, pedidos, estoque e precos
    - fallback scraping
    - bloqueio de IA externa
  - Dropshipping inteligente em modo de producao:
    - Spec: `docs/specs/valley-dropshipping-production-blueprint.md`
    - Migration: `database/postgres/033_v47_stock_dropshipping_production_blueprint.sql`
    - Fornecedores API: AliExpress, Alibaba, CJDropshipping
    - Fontes de preco: Mercado Livre, Amazon, Shopee, Magalu
    - Capacidades obrigatorias:
      - importacao de produtos
      - sincronizacao de estoque e custo
      - pedido automatico ao fornecedor
      - tracking persistido
      - consulta competitiva de preco
      - cache TTL de cotacoes
      - fallback scraping controlado
      - bloqueio de IA externa para consultas
      - reprecificacao automatica
      - pausa automatica sem margem ou estoque
      - decisao de pricing append-only
- Gates de sucesso:
  - catalogo sincronizado com margem controlada
  - estoque simplificado com enderecamento e variancia minima
  - checkout do marketplace alimentando PAY e PLUG
  - experiencia STOCK reconhecivel como Valley, mesmo com comportamento de grande marketplace

### Fase 3 - Identidade
- Objetivo da fase: Fechar autenticacao forte e perfil de risco operacional sem criar um modulo artificial novo.
- Capacidades transversais desta fase:
  - `face_id`
  - `voice_id`
  - `identity_score`
- Gates de sucesso:
  - Face ID ancorado em SECURITY e core identity
  - Voice ID formalizado como frente spec-first
  - Identity Score agregado para antifraude e reputacao

### Fase 4 - IA Leve
- Objetivo da fase: Ativar Helena em modo utilitario, controlado por plano e com custo previsivel.
- Modulos desta fase:
#### 46. `CHAT` - Valley Chat
- Dominio: `ai_memory_operations`
- Tier: `core`
- Fase atual: `VALIDATE`
- Data home: `postgres_mongo`
- Objetivo: Mensageria com contexto Helena pessoal/profissional e retencao segura.
- Backlog imediato:
  - fechar politica de retention
  - definir separacao pessoal x profissional
  - ligar contexto com advisor
#### 39. `ADVISOR` - Valley Advisor
- Dominio: `ai_memory_operations`
- Tier: `core`
- Fase atual: `BUILD`
- Data home: `postgres_mongo`
- Objetivo: Consultoria de IA com recomendacoes e consentimento de execucao.
- Backlog imediato:
  - fechar registro de consentimento
  - definir escopo de acao por modulo
  - ligar explainability do insight
#### 38. `AGENDA` - Valley Agenda
- Dominio: `ai_memory_operations`
- Tier: `core`
- Fase atual: `VALIDATE`
- Data home: `mongo`
- Objetivo: Agenda, listas inteligentes, memoria Helena e lembretes.
- Backlog imediato:
  - fechar recorrencia canonica
  - definir hierarquia de listas
  - ligar memoria de contexto
- Regras de runtime:
  - uso limitado por plano
  - processamento assincrono
  - foco em produtividade, nao volume
- Gates de sucesso:
  - chat com retention segura
  - advisor com consentimento e explainability minima
  - agenda com recorrencia e memoria util

## Metricas de sucesso
- volume transacional (TPV)
- numero de empresas ativas
- taxa de conversao marketplace
- custo por transacao
- fraude / chargeback

## Regras de ouro
- nao escalar logistica cedo
- nao subsidiar operacao
- separar taxa, processamento e logistica
- limitar custo de IA
- monetizar desde o primeiro usuario

## Resultado esperado
- break-even antes de 100k usuarios
- base solida para expansao modular
- validacao real de modelo economico
