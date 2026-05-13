(function () {
  const rawData = window.VALLEY_ADMIN_DATA;

  if (!rawData || !Array.isArray(rawData.modules)) {
    const shell = document.querySelector(".shell");

    if (shell) {
      shell.insertAdjacentHTML(
        "beforeend",
        '<section class="glass-panel" style="padding:22px"><h2>Payload indisponivel</h2><p class="muted-copy">O cockpit nao recebeu um manifesto valido em <code>window.VALLEY_ADMIN_DATA</code>.</p></section>',
      );
    }

    return;
  }

  const data = normalizeData(rawData);
  const NUMBER_FORMATTER = new Intl.NumberFormat("pt-BR");
  const PERCENT_FORMATTER = new Intl.NumberFormat("pt-BR", {
    style: "percent",
    maximumFractionDigits: 0,
  });
  const DATE_TIME_FORMATTER = new Intl.DateTimeFormat("pt-BR", {
    dateStyle: "short",
    timeStyle: "short",
  });
  const BRL_FORMATTER = new Intl.NumberFormat("pt-BR", {
    style: "currency",
    currency: "BRL",
    maximumFractionDigits: 2,
  });

  const TIER_ORDER = {
    foundation: 0,
    core: 1,
    expansion: 2,
    frontier: 3,
  };

  const STATUS_WEIGHT = {
    implemented: 1,
    implemented_partial: 0.74,
    planned: 0.38,
    blocked: 0.08,
  };

  const MARKETPLACE_API_STORAGE_KEY = "valley.marketplaceApiIntegrations.v1";
  const MODULE_WORKSPACE_TAB_STORAGE_KEY = "valley.moduleWorkspaceTabs.v1";
  const ADMIN_SURFACE_TAB_STORAGE_KEY = "valley.adminSurfaceTab.v1";
  const MERCHANT_ERP_STORAGE_KEY = "valley.merchantErp.v1";
  const MERCHANT_ERP_SECTION_ID = "merchantErpSection";
  const ADMIN_SURFACE_TABS = [
    {
      key: "overview",
      label: "Visao geral",
      description: "Home enxuta com botoes para areas e modulos independentes.",
      sectionIds: ["adminLaunchpadSection"],
    },
    {
      key: "stitch",
      label: "Stitch P0",
      description: "Admin Central e ERP Lojista convertidos para operacao real.",
      sectionIds: ["stitchP0ExecutionSection"],
    },
    {
      key: "merchant",
      label: "ERP Lojista",
      description: "Marketplace, PDV, armazem, financeiro e backoffice do lojista.",
      sectionIds: [MERCHANT_ERP_SECTION_ID],
    },
    {
      key: "finance",
      label: "Financeiro",
      description: "Receita, checkout e sinais de monetizacao.",
      sectionIds: ["financialDashboard"],
    },
    {
      key: "performance",
      label: "Desempenho",
      description: "Resultados por modulo e inteligencia do STOCK.",
      sectionIds: ["performanceDashboard"],
    },
    {
      key: "integrations",
      label: "Integracoes",
      description: "APIs, fornecedores e playbooks de ativacao.",
      sectionIds: ["settingsSection", "stockIntegrations"],
    },
    {
      key: "catalog",
      label: "Catalogo",
      description: "Importados, pricing e fila de publicacao.",
      sectionIds: ["importedPricingSection", "publicationReviewSection"],
    },
    {
      key: "modules",
      label: "Modulos",
      description: "Lista, filtros e cockpit detalhado por modulo.",
      sectionIds: ["moduleWorkspaceDirectory", "modulesWorkspace"],
    },
  ];
  const PRIMARY_WORKSPACE_KEY = "home";
  const PRODUCTION_MODE_LOCKED = true;
  const ADMIN_AUTH_TOKEN_STORAGE_KEY = "valley.admin.auth.token.v1";
  const MARKETPLACE_API_PROVIDERS = [
    { key: "mercado_livre", label: "Mercado Livre", providerRole: "marketplace_price", baseUrl: "https://api.mercadolibre.com", siteCode: "MLB" },
    { key: "amazon", label: "Amazon", providerRole: "marketplace_price", baseUrl: "https://sellingpartnerapi-na.amazon.com", siteCode: "BR" },
    { key: "aliexpress", label: "AliExpress", providerRole: "supplier_api", baseUrl: "https://api-sg.aliexpress.com", siteCode: "GLOBAL" },
    { key: "alibaba", label: "Alibaba", providerRole: "supplier_api", baseUrl: "https://openapi.alibaba.com", siteCode: "GLOBAL" },
    { key: "magalu", label: "Magalu", providerRole: "marketplace_price", baseUrl: "https://api.magalu.com", siteCode: "BR" },
    { key: "cjdropshipping", label: "CJDropshipping", providerRole: "supplier_api", baseUrl: "https://developers.cjdropshipping.com", siteCode: "GLOBAL" },
    { key: "shopee", label: "Shopee", providerRole: "marketplace_price", baseUrl: "https://partner.shopeemobile.com", siteCode: "BR" },
  ];
  const STOCK_PROVIDER_GUIDES = {
    mercado_livre: {
      auth: "OAuth2 com app Mercado Livre e seller autorizado.",
      steps: [
        "Criar app no Mercado Livre Developers e registrar redirect URI do admin.",
        "Salvar Client ID, Secret Ref e seller ID no cockpit em ambiente correto.",
        "Autorizar a conta da loja, persistir access token e refresh token no vault.",
        "Configurar webhooks de orders, items e shipments apontando para a URL publica do Valley.",
        "Executar primeira importacao de catalogo e validar estoque, preco e pedidos em sandbox antes de producao.",
      ],
    },
    amazon: {
      auth: "Selling Partner API com LWA + IAM role assinada.",
      steps: [
        "Registrar app SP-API, vincular IAM role e gerar credenciais LWA.",
        "Preencher marketplace BR, seller ID e referencias de segredo no cockpit.",
        "Cadastrar endpoint de notificacao e mapear scopes de catalogo, pricing, orders e listings.",
        "Rodar sync inicial de listings e estoque, depois habilitar pedidos e webhooks.",
        "Validar reconciliação de inventario por SKU antes de ativar producao.",
      ],
    },
    aliexpress: {
      auth: "App Key + Secret com autorizacao do seller no portal AliExpress Open Platform.",
      steps: [
        "Criar aplicacao na Open Platform e registrar callback de autorizacao.",
        "Salvar App Key, Secret Ref e access token no cofre do ambiente.",
        "Mapear catalogo, variacoes, estoque e rotas de order fulfillment.",
        "Definir janela de sync de preco e estoque para evitar rate limit.",
        "Executar homologacao com uma loja piloto antes de publicar toda a malha STOCK.",
      ],
    },
    alibaba: {
      auth: "OpenAPI com app enterprise e chaves assinadas.",
      steps: [
        "Provisionar app enterprise no Alibaba OpenAPI e liberar produtos alvo.",
        "Cadastrar chaves e parametros de assinatura no admin.",
        "Conectar importacao de catalogo e regras de margem por familia de produto.",
        "Habilitar apenas leitura no primeiro ciclo e comparar SKUs com base local.",
        "Liberar pedidos e confirmacoes apos bater consistencia de estoque e SLA.",
      ],
    },
    magalu: {
      auth: "OAuth2 / credenciais Magalu Marketplace com seller homologado.",
      steps: [
        "Homologar a conta seller e solicitar credenciais de API ao Magalu.",
        "Salvar client, secret, seller ID e webhook secret no cockpit.",
        "Configurar sincronizacao de catalogo, preco e saldo por SKU.",
        "Mapear fluxo de pedido e cancelamento conforme regras do parceiro.",
        "Virar ambiente para producao apenas depois de checklist fiscal e logistico fechado.",
      ],
    },
    cjdropshipping: {
      auth: "API Key da conta CJ com exchange para access token e refresh token.",
      steps: [
        "Gerar API Key em My CJ > Authorization > API e registrar a referencia segura no admin.",
        "Trocar a API Key por access token no backend e persistir refresh token em runtime seguro.",
        "Configurar webhook em /integrations/cjdropshipping/notifications.",
        "Importar catalogo inicial e normalizar categorias, shipping profile e origem.",
        "Configurar sincronizacao de custo, disponibilidade e tracking.",
        "Aplicar margem minima e bloqueios de produto antes da exposicao na vitrine.",
        "Validar pedido de ponta a ponta com tracking e webhook de status antes da escala.",
      ],
    },
    shopee: {
      auth: "Partner API com partner ID, partner key e loja autorizada.",
      steps: [
        "Criar app partner, registrar redirect URI e assinar requisicoes com partner key.",
        "Salvar partner ID, secret ref, tokens e store ID no cockpit.",
        "Configurar scopes de item, estoque, orders e logistics.",
        "Executar leitura inicial do catalogo e validar reconciliacao por variacao.",
        "Habilitar webhooks e producao depois de testar pedido e atualizacao de status.",
      ],
    },
  };
  const STATIC_ADMIN_WORKSPACES = [
    {
      key: "home",
      title: "Nucleo Admin",
      subdomain: "admin",
      sectionId: "adminLaunchpadSection",
      copy: "Governanca central do admin, com distribuicao dos workspaces e trilha institucional.",
    },
    {
      key: "stock",
      title: "Painel STOCK",
      subdomain: "stock",
      sectionId: "stockIntegrations",
      copy: "Catalogo, operacao do modulo STOCK e leitura de integracoes do produto.",
    },
    {
      key: "dropshipping",
      title: "Dropshipping",
      subdomain: "dropshipping",
      sectionId: "importedPricingSection",
      copy: "Produtos importados, categorias, margem e disputa entre fornecedores.",
    },
    {
      key: "marketplace",
      title: "Marketplace",
      subdomain: "marketplace",
      sectionId: "settingsSection",
      copy: "Apps, webhooks, seller IDs e escopos por marketplace.",
    },
    {
      key: "review",
      title: "Revisao",
      subdomain: "review",
      sectionId: "publicationReviewSection",
      copy: "Fila exclusiva para nao publicados e revisao comercial com motivo.",
    },
    {
      key: "finance",
      title: "Financeiro",
      subdomain: "finance",
      sectionId: "financialDashboard",
      copy: "Receita projetada, margens, fees e leitura financeira do catalogo.",
    },
    {
      key: "merchants",
      title: "Lojistas",
      subdomain: "merchants",
      sectionId: "modulesWorkspace",
      copy: "Cadastro e operacao de sellers, parceiros e workspace institucional.",
    },
    {
      key: "users",
      title: "Usuarios",
      subdomain: "users",
      sectionId: "modulesWorkspace",
      copy: "Cadastro de usuarios, perfis de acesso e trilha administrativa.",
    },
    {
      key: "checkout",
      title: "Checkout",
      subdomain: "checkout",
      sectionId: "checkoutHealthPanel",
      copy: "Saude do Mercado Pago, retorno, webhook e prontidao de pagamento.",
    },
    {
      key: "sandbox",
      title: "Sandbox e Flags",
      subdomain: "sandbox",
      sectionId: "settingsSection",
      copy: "Controles de sandbox, producao e flags operacionais por conector.",
    },
  ];
  const MERCHANT_ERP_WORKSPACES = [
    { key: "merchant-login", title: "Login Lojista", subdomain: "lojista", costZeroHost: "lojista", sectionId: "adminLaunchpadSection", copy: "Entrada segura do lojista para acessar o ERP e o marketplace." },
    { key: "merchant-erp", title: "ERP Lojista", subdomain: "erp-lojista", costZeroHost: "erp-lojista", sectionId: "modulesWorkspace", copy: "Centro operacional para gerenciar vendas, equipe, catalogo, pedidos e backoffice." },
    { key: "merchant-pdv", title: "PDV", subdomain: "pdv-lojista", costZeroHost: "pdv-lojista", sectionId: "checkoutHealthPanel", copy: "Venda presencial, checkout, caixa e conciliacao de pedidos." },
    { key: "merchant-warehouse", title: "Armazem", subdomain: "armazem-lojista", costZeroHost: "armazem-lojista", sectionId: "stockIntegrations", copy: "Estoque, recebimento, picking, inventario e ruptura operacional." },
    { key: "merchant-metrics", title: "Metricas", subdomain: "metricas-lojista", costZeroHost: "metricas-lojista", sectionId: "performanceDashboard", copy: "Indicadores de venda, margem, conversao, SLA e crescimento." },
    { key: "merchant-campaigns", title: "Campanhas", subdomain: "campanhas-lojista", costZeroHost: "campanhas-lojista", sectionId: "settingsSection", copy: "Promocoes, cupons, anuncios, canais e calendario comercial." },
    { key: "merchant-reports", title: "Relatorios", subdomain: "relatorios-lojista", costZeroHost: "relatorios-lojista", sectionId: "performanceDashboard", copy: "Relatorios executivos, exportacoes e acompanhamento por periodo." },
    { key: "merchant-finance", title: "Financeiro Lojista", subdomain: "financeiro-lojista", costZeroHost: "financeiro-lojista", sectionId: "financialDashboard", copy: "Recebiveis, taxas, repasses, margem, fees e fechamento financeiro." },
    { key: "merchant-registration", title: "Cadastro", subdomain: "cadastro-lojista", costZeroHost: "cadastro-lojista", sectionId: "modulesWorkspace", copy: "Dados comerciais, lojas, usuarios, permissoes e documentos." },
    { key: "merchant-profile", title: "Perfil", subdomain: "perfil-lojista", costZeroHost: "perfil-lojista", sectionId: "modulesWorkspace", copy: "Perfil da empresa, identidade visual, atendimento e politicas." },
    { key: "merchant-accounting", title: "Contabil", subdomain: "contabil-lojista", costZeroHost: "contabil-lojista", sectionId: "financialDashboard", copy: "Notas, impostos, centros de custo, conciliacao e livros auxiliares." },
    { key: "merchant-integrations", title: "Integracao", subdomain: "integracao-lojista", costZeroHost: "integracao-lojista", sectionId: "settingsSection", copy: "APIs, webhooks, marketplaces, ERPs externos e conectores." },
    { key: "merchant-orders", title: "Pedidos", subdomain: "pedidos-lojista", costZeroHost: "pedidos-lojista", sectionId: "importedPricingSection", copy: "Pedidos, status, separacao, cancelamento e atendimento pos-venda." },
    { key: "merchant-products", title: "Produtos", subdomain: "produtos-lojista", costZeroHost: "produtos-lojista", sectionId: "importedPricingSection", copy: "Catalogo, precificacao, fotos, SKU, publicacao e curadoria." },
    { key: "merchant-customers", title: "Clientes", subdomain: "clientes-lojista", costZeroHost: "clientes-lojista", sectionId: "modulesWorkspace", copy: "Clientes, segmentacao, historico, atendimento e retencao." },
    { key: "merchant-tax", title: "Fiscal", subdomain: "fiscal-lojista", costZeroHost: "fiscal-lojista", sectionId: "financialDashboard", copy: "Regras fiscais, documentos, impostos e auditoria de operacao." },
    { key: "merchant-inventory", title: "Estoque", subdomain: "estoque-lojista", costZeroHost: "estoque-lojista", sectionId: "stockIntegrations", copy: "Saldo por SKU, reposicao, reserva, inventario e transferencia." },
    { key: "merchant-stock-count", title: "Inventario de Estoque", subdomain: "inventario-lojista", costZeroHost: "inventario-lojista", sectionId: "stockIntegrations", copy: "Contagem fisica, codigo de barras, QR Code, volume, fracionamento, avaria, alta e baixa." },
    { key: "merchant-logistics", title: "Logistica", subdomain: "logistica-lojista", costZeroHost: "logistica-lojista", sectionId: "modulesWorkspace", copy: "Frete, entrega, coleta, SLA, rastreio e ocorrencias." },
    { key: "merchant-carrier-cross-docking", title: "Transportadora e Cross Docking", subdomain: "transportadora-lojista", costZeroHost: "transportadora-lojista", sectionId: "modulesWorkspace", copy: "CD, docas, romaneio, volumes, rotas, ultima milha, ocorrencias e devolucoes." },
    { key: "merchant-support", title: "Atendimento", subdomain: "atendimento-lojista", costZeroHost: "atendimento-lojista", sectionId: "modulesWorkspace", copy: "Tickets, chat, disputa, devolucao e relacionamento com clientes." },
    { key: "merchant-team", title: "Equipe", subdomain: "equipe-lojista", costZeroHost: "equipe-lojista", sectionId: "modulesWorkspace", copy: "Colaboradores, acessos, papeis, auditoria e produtividade." },
    { key: "merchant-security", title: "Seguranca", subdomain: "seguranca-lojista", costZeroHost: "seguranca-lojista", sectionId: "settingsSection", copy: "Permissoes, sessoes, alertas, MFA e trilhas de auditoria." },
    { key: "merchant-settings", title: "Configuracoes", subdomain: "configuracoes-lojista", costZeroHost: "configuracoes-lojista", sectionId: "settingsSection", copy: "Preferencias, parametros operacionais, flags e regras da loja." },
  ];
  const STITCH_P0_WEB_SCREENS = [
    {
      key: "valley_admin_central_1",
      title: "Admin Central 1",
      target: "Visao operacional",
      pane: "overview",
      action: "open-admin-central",
      detail: "Dashboard, KPIs, fila rapida, links publicos e leitura executiva.",
    },
    {
      key: "valley_admin_central_2",
      title: "Admin Central 2",
      target: "Controle executivo",
      pane: "performance",
      action: "open-executive",
      detail: "Desempenho por modulo, sinais de crescimento, pressao operacional e workspaces.",
    },
    {
      key: "valley_erp_do_lojista",
      title: "ERP do Lojista",
      target: "Painel marketplace",
      pane: "merchant",
      action: "open-erp",
      detail: "Pedidos, SKU, estoque, PDV, financeiro, integracoes e rotinas salvas.",
    },
  ];
  const PRICING_EDITABLE_FIELDS = [
    "target_net_revenue_pct",
    "platform_fee_pct",
    "operational_fee_pct",
    "marketing_fee_pct",
    "tax_pct",
    "notes",
  ];

  const allModules = data.modules.slice().sort((left, right) => left.number - right.number);
  const DYNAMIC_MODULE_WORKSPACES = buildModuleWorkspaces(allModules);
  const catalogState = {
    loading: true,
    summary: null,
    error: "",
  };
  const moduleSnapshotsState = {
    loading: true,
    payload: null,
    error: "",
  };
  const checkoutHealthState = {
    loading: true,
    payload: null,
    error: "",
  };
  const importedPricingState = {
    loading: true,
    payload: null,
    error: "",
    page: 1,
    pageSize: 24,
    filters: {
      query: "",
      supplierKey: "all",
      providerKey: "all",
      publicationStatus: "all",
      category: "all",
      collectionLabel: "all",
      availabilityLabel: "all",
      priceBand: "all",
      title: "",
      supplierName: "",
      categoryText: "",
      notes: "",
    },
    draft: {
      supplier_defaults: {},
      item_overrides: {},
    },
  };

  const state = {
    search: "",
    tier: "all",
    dataHome: "all",
    status: "all",
    domain: "all",
    selectedCode: null,
    marketplaceApiConfig: null,
    marketplaceApiPayload: null,
    moduleWorkspaceTabs: loadModuleWorkspaceTabs(),
    activeAdminSurfaceTab: loadAdminSurfaceTab(),
    merchantErpDraft: loadMerchantErpDraft(),
    activeMerchantErpFeature: loadMerchantErpFeature(),
    adminSession: null,
  };
  const workspaceFocusState = {
    appliedKey: "",
  };

  const elements = {
    adminAuthGate: document.getElementById("adminAuthGate"),
    adminAuthForm: document.getElementById("adminAuthForm"),
    adminAuthKicker: document.getElementById("adminAuthKicker"),
    adminAuthTitle: document.getElementById("adminAuthTitle"),
    adminAuthCopy: document.getElementById("adminAuthCopy"),
    adminAuthIdentifier: document.getElementById("adminAuthIdentifier"),
    adminAuthPassword: document.getElementById("adminAuthPassword"),
    adminAuthSubmit: document.getElementById("adminAuthSubmit"),
    adminAuthStatus: document.getElementById("adminAuthStatus"),
    registryName: document.getElementById("registryName"),
    sourceLabel: document.getElementById("sourceLabel"),
    generatedAt: document.getElementById("generatedAt"),
    reportHealth: document.getElementById("reportHealth"),
    heroTags: document.getElementById("heroTags"),
    metrics: document.getElementById("metrics"),
    prioritySignals: document.getElementById("prioritySignals"),
    releaseSummaryBoard: document.getElementById("releaseSummaryBoard"),
    criticalModules: document.getElementById("criticalModules"),
    publicRuntimePanel: document.getElementById("publicRuntimePanel"),
    tierMatrix: document.getElementById("tierMatrix"),
    dataHomeMatrix: document.getElementById("dataHomeMatrix"),
    domainBoard: document.getElementById("domainBoard"),
    releaseQueue: document.getElementById("releaseQueue"),
    businessSummaryBoard: document.getElementById("businessSummaryBoard"),
    businessHighlights: document.getElementById("businessHighlights"),
    modulePerformanceBoard: document.getElementById("modulePerformanceBoard"),
    stockInsightsBoard: document.getElementById("stockInsightsBoard"),
    marketplaceApiSummary: document.getElementById("marketplaceApiSummary"),
    marketplaceApiControlCenter: document.getElementById("marketplaceApiControlCenter"),
    adminLaunchpadSummary: document.getElementById("adminLaunchpadSummary"),
    workspaceFocusBanner: document.getElementById("workspaceFocusBanner"),
    adminWorkspaceRegistry: document.getElementById("adminWorkspaceRegistry"),
    adminLaunchpadGrid: document.getElementById("adminLaunchpadGrid"),
    stitchP0ExecutionRoot: document.getElementById("stitchP0ExecutionRoot"),
    moduleWorkspaceSummary: document.getElementById("moduleWorkspaceSummary"),
    moduleWorkspaceGrid: document.getElementById("moduleWorkspaceGrid"),
    heroWorkspaceIcons: document.getElementById("heroWorkspaceIcons"),
    desktopWorkspacePreview: document.getElementById("desktopWorkspacePreview"),
    phoneWorkspacePreview: document.getElementById("phoneWorkspacePreview"),
    heroBadge: document.getElementById("heroBadge"),
    stockProviderGuides: document.getElementById("stockProviderGuides"),
    stockGuideSummary: document.getElementById("stockGuideSummary"),
    checkoutHealthPanel: document.getElementById("checkoutHealthPanel"),
    adminAccessLinks: document.getElementById("adminAccessLinks"),
    moduleCount: document.getElementById("moduleCount"),
    moduleSelectionMeta: document.getElementById("moduleSelectionMeta"),
    moduleList: document.getElementById("moduleList"),
    detailTitle: document.getElementById("detailTitle"),
    detailSubtitle: document.getElementById("detailSubtitle"),
    detailMeta: document.getElementById("detailMeta"),
    detailNav: document.getElementById("detailNav"),
    detailContent: document.getElementById("detailContent"),
    commandList: document.getElementById("commandList"),
    externalAccess: document.getElementById("externalAccess"),
    searchInput: document.getElementById("searchInput"),
    tierFilter: document.getElementById("tierFilter"),
    dataHomeFilter: document.getElementById("dataHomeFilter"),
    statusFilter: document.getElementById("statusFilter"),
    domainFilter: document.getElementById("domainFilter"),
    resetFilters: document.getElementById("resetFilters"),
    copyCommands: document.getElementById("copyCommands"),
    marketplaceApiIntegrations: document.getElementById("marketplaceApiIntegrations"),
    saveMarketplaceApis: document.getElementById("saveMarketplaceApis"),
    applyMarketplaceApis: document.getElementById("applyMarketplaceApis"),
    resetMarketplaceApis: document.getElementById("resetMarketplaceApis"),
    copyMarketplaceApis: document.getElementById("copyMarketplaceApis"),
    importedPricingSummary: document.getElementById("importedPricingSummary"),
    importedSupplierBoard: document.getElementById("importedSupplierBoard"),
    importedPricingFilters: document.getElementById("importedPricingFilters"),
    importedPricingTableWrap: document.getElementById("importedPricingTableWrap"),
    saveImportedPricing: document.getElementById("saveImportedPricing"),
    applyImportedPricing: document.getElementById("applyImportedPricing"),
    resetImportedPricing: document.getElementById("resetImportedPricing"),
    copyImportedPricing: document.getElementById("copyImportedPricing"),
    publicationReviewSummary: document.getElementById("publicationReviewSummary"),
    publicationReviewBoard: document.getElementById("publicationReviewBoard"),
    liveRegion: document.getElementById("liveRegion"),
    heroTitle: document.getElementById("heroTitle"),
    heroSubcopy: document.getElementById("heroSubcopy"),
    adminSurfaceTabs: document.getElementById("adminSurfaceTabs"),
    merchantErpRoot: document.getElementById("merchantErpRoot"),
    mainContent: document.getElementById("mainContent"),
  };

  let appBootstrapped = false;

  function adminAuthStorageKey() {
    return `${ADMIN_AUTH_TOKEN_STORAGE_KEY}.${activeAuthScope()}`;
  }

  function readAdminAuthToken() {
    try {
      return String(window.localStorage.getItem(adminAuthStorageKey()) || "").trim();
    } catch (_error) {
      return "";
    }
  }

  function writeAdminAuthToken(token) {
    try {
      if (token) {
        window.localStorage.setItem(adminAuthStorageKey(), String(token).trim());
      } else {
        window.localStorage.removeItem(adminAuthStorageKey());
      }
    } catch (_error) {
      return;
    }
  }

  function setAdminAuthStatus(message, tone = "muted") {
    if (!elements.adminAuthStatus) {
      return;
    }
    elements.adminAuthStatus.textContent = message;
    elements.adminAuthStatus.dataset.tone = tone;
  }

  function isMerchantErpWorkspaceKey(key) {
    return String(key || "").startsWith("merchant-");
  }

  function activeAuthScope() {
    return isMerchantErpWorkspaceKey(activeWorkspaceKey()) ? "merchant" : "admin";
  }

  function applyAuthGateCopy() {
    const merchantMode = activeAuthScope() === "merchant";
    if (elements.adminAuthKicker) {
      elements.adminAuthKicker.textContent = merchantMode ? "Acesso do lojista" : "Acesso administrativo";
    }
    if (elements.adminAuthTitle) {
      elements.adminAuthTitle.textContent = merchantMode ? "Login do ERP lojista" : "Login do painel Valley";
    }
    if (elements.adminAuthCopy) {
      elements.adminAuthCopy.textContent = merchantMode
        ? "Use a credencial da empresa para abrir PDV, armazem, metricas, campanhas, financeiro e integracoes do marketplace."
        : "Use uma credencial administrativa válida para liberar workspaces, integrações reais e ações operacionais.";
    }
    if (elements.adminAuthIdentifier && !elements.adminAuthIdentifier.dataset.userEdited) {
      elements.adminAuthIdentifier.value = merchantMode ? "lojista.demo@valley.local" : "@anderson";
    }
    if (elements.adminAuthSubmit) {
      elements.adminAuthSubmit.textContent = merchantMode ? "Entrar no ERP" : "Entrar no admin";
    }
  }

  function loadAdminSurfaceTab() {
    try {
      const saved = String(window.localStorage.getItem(ADMIN_SURFACE_TAB_STORAGE_KEY) || "").trim().toLowerCase();
      return ADMIN_SURFACE_TABS.some((tab) => tab.key === saved) ? saved : "overview";
    } catch (_error) {
      return "overview";
    }
  }

  function loadMerchantErpDraft() {
    try {
      const saved = JSON.parse(window.localStorage.getItem(MERCHANT_ERP_STORAGE_KEY) || "{}");
      return saved && typeof saved === "object" ? saved : {};
    } catch (_error) {
      return {};
    }
  }

  function persistMerchantErpDraft() {
    try {
      window.localStorage.setItem(MERCHANT_ERP_STORAGE_KEY, JSON.stringify(state.merchantErpDraft || {}, null, 2));
    } catch (_error) {
      return;
    }
  }

  function loadMerchantErpFeature() {
    try {
      const saved = String(window.localStorage.getItem(`${MERCHANT_ERP_STORAGE_KEY}.activeFeature`) || "").trim();
      return saved || "";
    } catch (_error) {
      return "";
    }
  }

  function persistMerchantErpFeature(key) {
    try {
      window.localStorage.setItem(`${MERCHANT_ERP_STORAGE_KEY}.activeFeature`, String(key || ""));
    } catch (_error) {
      return;
    }
  }

  function persistAdminSurfaceTab() {
    try {
      window.localStorage.setItem(ADMIN_SURFACE_TAB_STORAGE_KEY, state.activeAdminSurfaceTab);
    } catch (_error) {
      return;
    }
  }

  function adminSurfaceTabByKey(key) {
    return ADMIN_SURFACE_TABS.find((tab) => tab.key === key) || ADMIN_SURFACE_TABS[0];
  }

  function adminSurfaceTabForSection(sectionId) {
    return ADMIN_SURFACE_TABS.find((tab) => tab.sectionIds.includes(sectionId)) || ADMIN_SURFACE_TABS[0];
  }

  function syncAdminSurfaceWithWorkspace() {
    const workspace = activeWorkspace();
    if (workspace?.workspaceKind === "merchant_erp" || isMerchantErpWorkspaceKey(workspace?.key)) {
      state.activeAdminSurfaceTab = "merchant";
      document.body.classList.add("merchant-erp-mode");
      return;
    }
    document.body.classList.remove("merchant-erp-mode");
  }

  function setActiveAdminSurfaceTab(tabKey, { preserveScroll = false } = {}) {
    const next = adminSurfaceTabByKey(tabKey)?.key || "overview";
    state.activeAdminSurfaceTab = next;
    persistAdminSurfaceTab();
    applyAdminSurfaceTabVisibility();
    renderAdminSurfaceTabs();
    if (!preserveScroll) {
      elements.mainContent?.scrollIntoView({ behavior: "smooth", block: "start" });
    }
  }

  function renderAdminSurfaceTabs() {
    if (!elements.adminSurfaceTabs) {
      return;
    }
    elements.adminSurfaceTabs.innerHTML = ADMIN_SURFACE_TABS.map((tab) => `
      <button
        type="button"
        class="admin-surface-tab ${tab.key === state.activeAdminSurfaceTab ? "is-active" : ""}"
        data-admin-surface-tab="${escapeHtml(tab.key)}"
        role="tab"
        aria-selected="${tab.key === state.activeAdminSurfaceTab ? "true" : "false"}"
      >
        <strong>${escapeHtml(tab.label)}</strong>
        <span>${escapeHtml(tab.description)}</span>
      </button>
    `).join("");
  }

  function applyAdminSurfaceTabVisibility() {
    document.querySelectorAll("[data-admin-pane]").forEach((section) => {
      const pane = String(section.getAttribute("data-admin-pane") || "").trim();
      section.hidden = pane !== state.activeAdminSurfaceTab;
    });
  }

  function showAdminAuthGate() {
    if (!elements.adminAuthGate) {
      return;
    }
    elements.adminAuthGate.classList.add("is-visible");
    document.body.classList.add("admin-auth-locked");
  }

  function hideAdminAuthGate() {
    if (!elements.adminAuthGate) {
      return;
    }
    elements.adminAuthGate.classList.remove("is-visible");
    document.body.classList.remove("admin-auth-locked");
  }

  async function adminAuthFetch(url, options = {}) {
    const headers = new Headers(options.headers || {});
    const token = readAdminAuthToken();
    if (token) {
      headers.set("Authorization", `Bearer ${token}`);
      headers.set("X-Valley-Session", token);
    }
    return fetch(url, {
      ...options,
      headers,
      credentials: options.credentials || "same-origin",
    });
  }

  async function restoreAdminSession() {
    const token = readAdminAuthToken();
    try {
      const response = await adminAuthFetch(`/api/auth/session?scope=${encodeURIComponent(activeAuthScope())}`, {
        headers: { Accept: "application/json" },
        credentials: "same-origin",
      });
      const payload = await response.json();
      if (!response.ok || payload.status !== "ok" || !payload.session) {
        if (token) {
          writeAdminAuthToken("");
        }
        return null;
      }
      state.adminSession = payload.session;
      if (payload.session.token) {
        writeAdminAuthToken(payload.session.token);
      }
      return payload.session;
    } catch (_error) {
      writeAdminAuthToken("");
      return null;
    }
  }

  async function submitAdminLogin(event) {
    event?.preventDefault?.();
    const identifier = String(elements.adminAuthIdentifier?.value || "").trim();
    const password = String(elements.adminAuthPassword?.value || "");
    if (!identifier || !password) {
      setAdminAuthStatus("Informe usuário e senha válidos.", "danger");
      return;
    }
    if (elements.adminAuthSubmit) {
      elements.adminAuthSubmit.disabled = true;
    }
    setAdminAuthStatus("Validando credenciais administrativas...", "muted");
    try {
      const response = await fetch("/api/auth/login", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Accept: "application/json",
        },
        body: JSON.stringify({
          identifier,
          password,
          scope: activeAuthScope(),
        }),
      });
      const payload = await response.json();
      if (!response.ok || payload.status !== "ok" || !payload.session) {
        setAdminAuthStatus(payload.detail || payload.message || "Credenciais inválidas.", "danger");
        return;
      }
      state.adminSession = payload.session;
      writeAdminAuthToken(payload.session.token || "");
      if (elements.adminAuthPassword) {
        elements.adminAuthPassword.value = "";
      }
      setAdminAuthStatus(`Sessão ativa para ${payload.session.user?.display_name || identifier}.`, "success");
      hideAdminAuthGate();
      bootstrapAdminApp();
    } catch (_error) {
      setAdminAuthStatus("Não foi possível validar a sessão no backend do Valley.", "danger");
    } finally {
      if (elements.adminAuthSubmit) {
        elements.adminAuthSubmit.disabled = false;
      }
    }
  }

  function bindAdminAuthForm() {
    if (!elements.adminAuthForm || elements.adminAuthForm.dataset.bound === "1") {
      return;
    }
    elements.adminAuthForm.dataset.bound = "1";
    elements.adminAuthIdentifier?.addEventListener("input", () => {
      elements.adminAuthIdentifier.dataset.userEdited = "1";
    });
    elements.adminAuthForm.addEventListener("submit", submitAdminLogin);
  }

  async function bootstrapAdminGate() {
    bindAdminAuthForm();
    applyAuthGateCopy();
    setAdminAuthStatus(activeAuthScope() === "merchant" ? "Validando sessão do lojista..." : "Validando sessão administrativa...", "muted");
    const session = await restoreAdminSession();
    if (!session) {
      showAdminAuthGate();
      setAdminAuthStatus(activeAuthScope() === "merchant" ? "Entre com a credencial do lojista para liberar o ERP." : "Entre com uma credencial administrativa válida para liberar o painel.", "muted");
      return;
    }
    hideAdminAuthGate();
    bootstrapAdminApp();
  }

  function loadModuleWorkspaceTabs() {
    try {
      const saved = JSON.parse(window.localStorage.getItem(MODULE_WORKSPACE_TAB_STORAGE_KEY) || "{}");
      return saved && typeof saved === "object" ? saved : {};
    } catch (_error) {
      return {};
    }
  }

  function persistModuleWorkspaceTabs() {
    try {
      window.localStorage.setItem(MODULE_WORKSPACE_TAB_STORAGE_KEY, JSON.stringify(state.moduleWorkspaceTabs || {}, null, 2));
    } catch (_error) {
      return;
    }
  }

  function setModuleWorkspaceTab(moduleCode, tabKey) {
    state.moduleWorkspaceTabs = {
      ...(state.moduleWorkspaceTabs || {}),
      [moduleCode]: tabKey,
    };
    persistModuleWorkspaceTabs();
  }

  function adminWorkspaces() {
    const merchantWorkspaces = MERCHANT_ERP_WORKSPACES.map((workspace) => ({
      ...workspace,
      sectionId: MERCHANT_ERP_SECTION_ID,
      workspaceKind: "merchant_erp",
    }));
    return [...STATIC_ADMIN_WORKSPACES, ...merchantWorkspaces, ...DYNAMIC_MODULE_WORKSPACES];
  }

  function slugToSubdomain(value) {
    return String(value || "")
      .toLowerCase()
      .replace(/[^a-z0-9-]+/g, "-")
      .replace(/^-+|-+$/g, "") || "modulo";
  }

  function buildModuleWorkspaces(modules) {
    const reserved = new Set([...STATIC_ADMIN_WORKSPACES, ...MERCHANT_ERP_WORKSPACES].map((workspace) => workspace.subdomain));
    const used = new Set();

    return modules.map((module) => {
      let subdomain = slugToSubdomain(module.slug || module.code);
      if (reserved.has(subdomain) || used.has(subdomain)) {
        subdomain = `${subdomain}-module`;
      }
      used.add(subdomain);
      return {
        key: `module-${module.code.toLowerCase()}`,
        title: `${module.code} · ${module.name}`,
        subdomain,
        sectionId: "modulesWorkspace",
        copy: `${module.subtitle} com cockpit dedicado, contexto de docs, checklist, contratos e trilha operacional.`,
        moduleCode: module.code,
        workspaceKind: "module",
      };
    });
  }

  function moduleWorkspaceByCode(code) {
    return DYNAMIC_MODULE_WORKSPACES.find((workspace) => workspace.moduleCode === code) || null;
  }

  function activeWorkspace() {
    return workspaceByKey(activeWorkspaceKey());
  }

  function activeModuleWorkspace() {
    const workspace = activeWorkspace();
    if (!workspace?.moduleCode) {
      return null;
    }
    return allModules.find((module) => module.code === workspace.moduleCode) || null;
  }

  function normalizeAggregateSummary(summary) {
    return {
      modules_total: Number(summary?.modules_total) || 0,
      modules_completed: Number(summary?.modules_completed) || 0,
      modules_with_pending: Number(summary?.modules_with_pending) || 0,
      checklist_items_total: Number(summary?.checklist_items_total) || 0,
      checklist_items_done: Number(summary?.checklist_items_done) || 0,
      checklist_items_pending: Number(summary?.checklist_items_pending) || 0,
      checklist_completion_percentage: Number(summary?.checklist_completion_percentage) || 0,
      average_module_readiness_percentage: Number(summary?.average_module_readiness_percentage) || 0,
    };
  }

  function normalizePendingModule(module) {
    return {
      number: Number(module?.number) || 0,
      code: String(module?.code || `M${module?.number || "00"}`).toUpperCase(),
      name: module?.name || "Modulo sem nome",
      tier: module?.tier || "unclassified",
      automation_status: module?.automation_status || "planned",
      status_label: module?.status_label || humanizeKey(module?.automation_status || "planned"),
      checklist_done: Number(module?.checklist_done) || 0,
      checklist_pending: Number(module?.checklist_pending) || 0,
      checklist_total: Number(module?.checklist_total) || 0,
      module_readiness_percentage: Number(module?.module_readiness_percentage) || 0,
    };
  }

  function normalizeReleaseSummary(summary) {
    const normalized = normalizeAggregateSummary(summary);

    return {
      ...normalized,
      top_modules_with_pending: Array.isArray(summary?.top_modules_with_pending)
        ? summary.top_modules_with_pending.map(normalizePendingModule)
        : [],
      by_tier: Object.fromEntries(
        Object.entries(summary?.by_tier || {}).map(([key, value]) => [key, normalizeAggregateSummary(value)]),
      ),
      by_automation_status: Object.fromEntries(
        Object.entries(summary?.by_automation_status || {}).map(([key, value]) => [key, normalizeAggregateSummary(value)]),
      ),
    };
  }

  function normalizeReleaseQueueSummary(summary) {
    return {
      items_total: Number(summary?.items_total) || 0,
      items: Array.isArray(summary?.items)
        ? summary.items.map((item) => ({
            ...normalizePendingModule(item),
            subtitle: item?.subtitle || "Sem subtitulo",
            domain: item?.domain || "sem_dominio",
            data_home: item?.data_home || "indefinido",
            next_focus: Array.isArray(item?.next_focus) ? item.next_focus : [],
          }))
        : [],
    };
  }

  function normalizePublicRuntime(runtime) {
    return {
      available: Boolean(runtime?.available),
      path: runtime?.path || "",
      status: runtime?.status || "missing",
      public_url: runtime?.public_url || "",
      permanence: runtime?.permanence || "",
      smoke_endpoints: {
        healthz: runtime?.smoke_endpoints?.healthz || "",
        admin_data: runtime?.smoke_endpoints?.admin_data || "",
      },
    };
  }

  function normalizeData(source) {
    const databaseSummary = source.database_summary || {};
    const deploymentSummary = source.deployment_summary || {};

    return {
      ...source,
      admin_commands: Array.isArray(source.admin_commands) ? source.admin_commands : [],
      contracts_summary: source.contracts_summary || {},
      governance: source.governance || {},
      public_access: source.public_access || {},
      public_runtime: normalizePublicRuntime(source.public_runtime),
      release_summary: normalizeReleaseSummary(source.release_summary),
      release_queue_summary: normalizeReleaseQueueSummary(source.release_queue_summary),
      roadmap: source.roadmap || {},
      database_summary: {
        postgres_migrations: Number(databaseSummary.postgres_migrations) || 0,
        mongodb_scripts: Number(databaseSummary.mongodb_scripts) || 0,
      },
      deployment_summary: {
        available: Boolean(deploymentSummary.available),
        generated_at_utc: deploymentSummary.generated_at_utc || "",
        total_checks: Number(deploymentSummary.total_checks) || 0,
        failed_checks: Number(deploymentSummary.failed_checks) || 0,
        top_failures: Array.isArray(deploymentSummary.top_failures) ? deploymentSummary.top_failures : [],
      },
      modules: source.modules.map(normalizeModule),
    };
  }

  function normalizeModule(module) {
    const checklist = module.checklist || {};
    const items = Array.isArray(checklist.items)
      ? checklist.items.map((item) => ({
          done: Boolean(item?.done),
          label: item?.label || "Item sem descricao",
        }))
      : [];
    const total = Number(checklist.total) || items.length;
    const done = Number(checklist.done) || items.filter((item) => item.done).length;
    const pending =
      Number.isFinite(checklist.pending) && checklist.pending !== null
        ? Number(checklist.pending)
        : Math.max(total - done, 0);

    return {
      ...module,
      number: Number(module.number) || 0,
      code: String(module.code || `M${module.number || "00"}`).toUpperCase(),
      name: module.name || "Modulo sem nome",
      subtitle: module.subtitle || "Sem subtitulo",
      domain: module.domain || "sem_dominio",
      tier: module.tier || "unclassified",
      data_home: module.data_home || "indefinido",
      automation_status: module.automation_status || "planned",
      status_label: module.status_label || humanizeKey(module.automation_status || "planned"),
      depends_on: Array.isArray(module.depends_on) ? module.depends_on : [],
      integrates_with: Array.isArray(module.integrates_with) ? module.integrates_with : [],
      description_ptbr: module.description_ptbr || "Descricao indisponivel.",
      slug: module.slug || String(module.code || "").toLowerCase(),
      paths: {
        module_dir: module.paths?.module_dir || "",
        readme: module.paths?.readme || "",
        status: module.paths?.status || "",
        contract: module.paths?.contract || "",
      },
      docs: {
        readme: module.docs?.readme || "",
        status: module.docs?.status || "",
        contract: module.docs?.contract || "",
        readme_preview: module.docs?.readme_preview || "",
        contract_preview: module.docs?.contract_preview || "",
      },
      checklist: {
        total,
        done,
        pending,
        items,
      },
      admin_actions: Array.isArray(module.admin_actions) ? module.admin_actions : [],
    };
  }

  function escapeHtml(value) {
    return String(value ?? "")
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#39;");
  }

  function humanizeKey(value) {
    return String(value || "")
      .replace(/_/g, " ")
      .trim();
  }

  function formatList(items) {
    return items && items.length ? items.join(", ") : "Sem item declarado";
  }

  function formatCount(value) {
    return NUMBER_FORMATTER.format(value || 0);
  }

  function formatPercent(value) {
    return PERCENT_FORMATTER.format(Number.isFinite(value) ? value : 0);
  }

  function formatPercentFromHundred(value) {
    return formatPercent((Number(value) || 0) / 100);
  }

  function formatMoney(value) {
    return BRL_FORMATTER.format(Number(value) || 0);
  }

  function deepClone(value) {
    return JSON.parse(JSON.stringify(value ?? null));
  }

  function toNumber(value, fallback = 0) {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : fallback;
  }

  function normalizeSearch(value) {
    return String(value || "")
      .normalize("NFD")
      .replace(/[\u0300-\u036f]/g, "")
      .toLowerCase()
      .trim();
  }

  function matchesSearch(value, query) {
    return !query || normalizeSearch(value).includes(query);
  }

  function formatTimestamp(value) {
    if (!value) {
      return "geracao indisponivel";
    }

    const timestamp = new Date(value);

    if (Number.isNaN(timestamp.getTime())) {
      return value;
    }

    return DATE_TIME_FORMATTER.format(timestamp);
  }

  function ratio(numerator, denominator) {
    if (!denominator) {
      return 0;
    }

    return numerator / denominator;
  }

  function runtimeTone(runtime) {
    if (runtime.available && runtime.public_url) {
      return "ok";
    }

    if (runtime.status === "missing") {
      return "warn";
    }

    return "danger";
  }

  function runtimeLabel(runtime) {
    if (runtime.available && runtime.public_url) {
      return "publico online";
    }

    if (runtime.status === "missing") {
      return "runtime ausente";
    }

    return humanizeKey(runtime.status || "indisponivel");
  }

  function publicUrlLabel(runtime) {
    if (runtime.public_url) {
      try {
        return new URL(runtime.public_url).host;
      } catch (error) {
        return runtime.public_url;
      }
    }

    return "sem URL ativa";
  }

  function trimLines(text, maxLines) {
    const lines = String(text || "")
      .split(/\r?\n/)
      .map((line) => line.trimEnd())
      .filter((line) => line.trim());

    if (!lines.length) {
      return "Conteudo indisponivel.";
    }

    if (lines.length <= maxLines) {
      return lines.join("\n");
    }

    return `${lines.slice(0, maxLines).join("\n")}\n...`;
  }

  function statusVariant(status) {
    if (status === "planned") {
      return "pill-warn";
    }

    if (status === "blocked") {
      return "pill-danger";
    }

    return "pill-accent";
  }

  function reportHealthClass(report) {
    if (!report.available) {
      return "status-dot status-warn";
    }

    if (report.failed_checks === 0) {
      return "status-dot status-ok";
    }

    if (report.failed_checks <= 3) {
      return "status-dot status-warn";
    }

    return "status-dot status-danger";
  }

  function optionMarkup(value, label) {
    return `<option value="${escapeHtml(value)}">${escapeHtml(label)}</option>`;
  }

  function uniqueValues(selector) {
    return [...new Set(allModules.map(selector))].filter(Boolean).sort();
  }

  function moduleReadiness(module) {
    const statusWeight = STATUS_WEIGHT[module.automation_status] ?? 0.45;
    const checklistTotal = module.checklist?.total || 0;

    if (!checklistTotal) {
      return statusWeight;
    }

    const checklistRatio = ratio(module.checklist.done, checklistTotal);
    return Math.min(1, checklistRatio * 0.7 + statusWeight * 0.3);
  }

  function overallReadiness(modules) {
    if (!modules.length) {
      return 0;
    }

    const total = modules.reduce((sum, module) => sum + moduleReadiness(module), 0);
    return total / modules.length;
  }

  function totalPending(modules) {
    return modules.reduce((sum, module) => sum + (module.checklist?.pending || 0), 0);
  }

  function totalDone(modules) {
    return modules.reduce((sum, module) => sum + (module.checklist?.done || 0), 0);
  }

  function countBy(modules, selector) {
    return modules.reduce((accumulator, module) => {
      const key = selector(module);
      accumulator[key] = (accumulator[key] || 0) + 1;
      return accumulator;
    }, {});
  }

  function groupByDomain(modules) {
    return modules.reduce((accumulator, module) => {
      const key = module.domain || "sem_dominio";

      if (!accumulator[key]) {
        accumulator[key] = [];
      }

      accumulator[key].push(module);
      return accumulator;
    }, {});
  }

  function releaseSummaryOrFallback() {
    if (data.release_summary.modules_total) {
      return data.release_summary;
    }

    const topModules = allModules
      .filter((module) => (module.checklist?.pending || 0) > 0)
      .sort((left, right) => {
        if ((right.checklist?.pending || 0) !== (left.checklist?.pending || 0)) {
          return (right.checklist?.pending || 0) - (left.checklist?.pending || 0);
        }

        return moduleReadiness(left) - moduleReadiness(right);
      })
      .slice(0, 10)
      .map((module) => ({
        number: module.number,
        code: module.code,
        name: module.name,
        tier: module.tier,
        automation_status: module.automation_status,
        status_label: module.status_label,
        checklist_done: module.checklist.done,
        checklist_pending: module.checklist.pending,
        checklist_total: module.checklist.total,
        module_readiness_percentage: Math.round(moduleReadiness(module) * 100),
      }));

    return {
      modules_total: allModules.length,
      modules_completed: allModules.filter((module) => (module.checklist?.pending || 0) === 0).length,
      modules_with_pending: allModules.filter((module) => (module.checklist?.pending || 0) > 0).length,
      checklist_items_total: allModules.reduce((sum, module) => sum + (module.checklist?.total || 0), 0),
      checklist_items_done: allModules.reduce((sum, module) => sum + (module.checklist?.done || 0), 0),
      checklist_items_pending: totalPending(allModules),
      checklist_completion_percentage:
        ratio(
          allModules.reduce((sum, module) => sum + (module.checklist?.done || 0), 0),
          allModules.reduce((sum, module) => sum + (module.checklist?.total || 0), 0),
        ) * 100,
      average_module_readiness_percentage: overallReadiness(allModules) * 100,
      top_modules_with_pending: topModules,
      by_tier: {},
      by_automation_status: {},
    };
  }

  function modulePriorityScore(module) {
    const tierWeight = TIER_ORDER[module.tier] ?? 99;
    const plannedWeight = module.automation_status === "planned" ? 0 : 200;
    const readinessPenalty = Math.round((1 - moduleReadiness(module)) * 100);
    const pendingWeight = (module.checklist?.pending || 0) * 10;

    return tierWeight * 1000 + plannedWeight + readinessPenalty + pendingWeight + module.number;
  }

  function metricMarkup(label, value, subtext, progress) {
    return `
      <article class="metric">
        <span class="metric-label">${escapeHtml(label)}</span>
        <strong class="metric-value">${escapeHtml(value)}</strong>
        <span class="metric-subtext">${escapeHtml(subtext)}</span>
        <div class="metric-progress">
          <div class="metric-progress-fill" style="width: ${Math.max(0, Math.min(progress, 1)) * 100}%"></div>
        </div>
      </article>
    `;
  }

  function rowPill(label, variant) {
    return `<span class="pill ${variant || ""}">${escapeHtml(label)}</span>`;
  }

  function progressMarkup(progress) {
    return `
      <div class="progress" aria-hidden="true">
        <div class="progress-fill" style="width: ${Math.max(0, Math.min(progress, 1)) * 100}%"></div>
      </div>
    `;
  }

  function catalogModules() {
    return Array.isArray(catalogState.summary?.modules) ? catalogState.summary.modules : [];
  }

  function catalogModuleSnapshot(moduleCode) {
    return catalogModules().find((entry) => entry.module_id === moduleCode) || null;
  }

  function moduleRuntimeSnapshot(moduleCode) {
    const modules = moduleSnapshotsState.payload?.modules;
    if (!modules || typeof modules !== "object") {
      return null;
    }
    return modules[moduleCode] || null;
  }

  function accessCardMarkup(label, url, tone) {
    return `
      <article class="access-card">
        <span class="small-label">${escapeHtml(label)}</span>
        <code>${escapeHtml(url || "indisponivel")}</code>
        <div class="link-row">
          ${url ? linkMarkup("Abrir", url) : `<span class="pill ${tone || ""}">Aguardando</span>`}
        </div>
      </article>
    `;
  }

  function insightCardMarkup(label, value, detail, pills) {
    return `
      <article class="insight-card">
        <span class="small-label">${escapeHtml(label)}</span>
        <strong>${escapeHtml(value)}</strong>
        <p class="muted-copy">${escapeHtml(detail)}</p>
        <div class="pill-row">${pills || ""}</div>
      </article>
    `;
  }

  function microStatMarkup(label, value) {
    return `
      <div class="micro-stat">
        <span class="small-label">${escapeHtml(label)}</span>
        <strong>${escapeHtml(value)}</strong>
      </div>
    `;
  }

  async function loadCatalogSummary() {
    try {
      const response = await fetch("/api/product-catalog-summary", { cache: "no-store" });
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`);
      }
      catalogState.summary = await response.json();
      catalogState.error = "";
    } catch (error) {
      catalogState.summary = null;
      catalogState.error = error instanceof Error ? error.message : "falha ao carregar resumo";
    } finally {
      catalogState.loading = false;
      renderCatalogDrivenSections();
      renderAccessLinks();
      renderDetail(filteredModules());
    }
  }

  async function loadModuleRuntimeSnapshots() {
    try {
      const response = await fetch("/api/module-runtime-snapshots", { cache: "no-store" });
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`);
      }
      moduleSnapshotsState.payload = await response.json();
      moduleSnapshotsState.error = "";
    } catch (error) {
      moduleSnapshotsState.payload = null;
      moduleSnapshotsState.error = error instanceof Error ? error.message : "falha ao carregar snapshots";
    } finally {
      moduleSnapshotsState.loading = false;
      renderDetail(filteredModules());
    }
  }

  function renderCatalogDrivenSections() {
    renderBusinessSummaryBoard();
    renderBusinessHighlights();
    renderModulePerformanceBoard();
    renderStockInsightsBoard();
    renderStockProviderGuides();
  }

  function renderBusinessSummaryBoard() {
    if (!elements.businessSummaryBoard) {
      return;
    }

    if (catalogState.loading) {
      elements.businessSummaryBoard.innerHTML = `<div class="empty-state">Carregando resumo comercial...</div>`;
      return;
    }

    if (!catalogState.summary) {
      elements.businessSummaryBoard.innerHTML = `<div class="empty-state">Resumo comercial indisponivel: ${escapeHtml(catalogState.error || "sem resposta")}</div>`;
      return;
    }

    const summary = catalogState.summary;
    elements.businessSummaryBoard.innerHTML = [
      summaryTileMarkup("Itens catalogados", formatCount(summary.items_total), "base operacional do catalogo local"),
      summaryTileMarkup("Estoque total", formatCount(summary.inventory_units), "unidades somadas na malha ativa"),
      summaryTileMarkup("Valor em estoque", formatMoney(summary.inventory_value_brl), "potencial bruto pelo preco atual"),
      summaryTileMarkup("Margem potencial", formatMoney(summary.margin_potential_brl), "diferenca agregada entre price e compare_at"),
    ].join("");
  }

  function renderBusinessHighlights() {
    if (!elements.businessHighlights) {
      return;
    }

    if (catalogState.loading) {
      elements.businessHighlights.innerHTML = `<div class="empty-state">Carregando destaques comerciais...</div>`;
      return;
    }

    if (!catalogState.summary) {
      elements.businessHighlights.innerHTML = `<div class="empty-state">Sem dados comerciais publicados.</div>`;
      return;
    }

    const summary = catalogState.summary;
    const topCategory = summary.top_categories?.[0];
    const topMerchant = summary.top_merchants?.[0];
    const topMarginItem = summary.top_margin_item;

    elements.businessHighlights.innerHTML = [
      insightCardMarkup(
        "Segmento lider",
        topCategory ? topCategory.category : "Nao publicado",
        topCategory
          ? `${formatMoney(topCategory.inventory_value_brl)} em valor de catalogo e ${formatCount(topCategory.items_total)} SKUs.`
          : "Nenhuma categoria consolidada no payload.",
        topCategory ? `${rowPill(`${formatCount(topCategory.inventory_units)} unidades`, "pill-accent")}` : "",
      ),
      insightCardMarkup(
        "Fornecedor com maior valor",
        topMerchant ? topMerchant.merchant_name : "Nao publicado",
        topMerchant
          ? `${formatMoney(topMerchant.inventory_value_brl)} agregados no estoque monitorado.`
          : "Nenhum merchant agregado no payload.",
        topMerchant ? `${rowPill(`${formatCount(topMerchant.items_total)} itens`, "pill-navy")}` : "",
      ),
      insightCardMarkup(
        "Item com maior margem potencial",
        topMarginItem ? topMarginItem.title : "Nao publicado",
        topMarginItem
          ? `${formatMoney(topMarginItem.total_margin_brl)} de margem potencial total em ${topMarginItem.module_id}.`
          : "Sem item de margem no resumo atual.",
        topMarginItem
          ? `${rowPill(topMarginItem.category, "pill-warn")}${rowPill(topMarginItem.module_id, "pill-accent")}`
          : "",
      ),
    ].join("");
  }

  function renderModulePerformanceBoard() {
    if (!elements.modulePerformanceBoard) {
      return;
    }

    if (catalogState.loading) {
      elements.modulePerformanceBoard.innerHTML = `<div class="empty-state">Carregando desempenho por modulo...</div>`;
      return;
    }

    const modules = catalogModules();
    if (!modules.length) {
      elements.modulePerformanceBoard.innerHTML = `<div class="empty-state">Sem resumo de modulos comerciais.</div>`;
      return;
    }

    elements.modulePerformanceBoard.innerHTML = modules.slice(0, 8).map((module) => `
      <article class="module-performance-card">
        <div class="module-row-top">
          <div>
            <h3>${escapeHtml(module.module_id)}</h3>
            <p class="muted-copy">${escapeHtml(module.top_item_title || "Sem item lider")}</p>
          </div>
          ${rowPill(formatMoney(module.inventory_value_brl), "pill-accent")}
        </div>
        <div class="module-performance-grid">
          ${microStatMarkup("Itens", formatCount(module.items_total))}
          ${microStatMarkup("Unidades", formatCount(module.inventory_units))}
          ${microStatMarkup("Ticket medio", formatMoney(module.avg_price_brl))}
          ${microStatMarkup("Margem pot.", formatMoney(module.margin_potential_brl))}
        </div>
      </article>
    `).join("");
  }

  function renderStockInsightsBoard() {
    if (!elements.stockInsightsBoard) {
      return;
    }

    if (catalogState.loading) {
      elements.stockInsightsBoard.innerHTML = `<div class="empty-state">Carregando radar do STOCK...</div>`;
      return;
    }

    if (!catalogState.summary) {
      elements.stockInsightsBoard.innerHTML = `<div class="empty-state">Radar do STOCK indisponivel.</div>`;
      return;
    }

    const summary = catalogState.summary;
    const stockModule = summary.stock_module;
    const topStockItem = summary.top_stock_item;
    const topTicketItem = summary.top_ticket_item;

    elements.stockInsightsBoard.innerHTML = [
      insightCardMarkup(
        "Modulo STOCK",
        stockModule ? formatMoney(stockModule.inventory_value_brl) : "Nao publicado",
        stockModule
          ? `${formatCount(stockModule.items_total)} itens, ${formatCount(stockModule.inventory_units)} unidades e ${formatMoney(stockModule.margin_potential_brl)} de margem potencial.`
          : "Resumo do modulo STOCK ainda nao chegou pelo backend.",
        stockModule ? `${rowPill(stockModule.module_id, "pill-accent")}${rowPill(stockModule.top_item_title, "pill-navy")}` : "",
      ),
      insightCardMarkup(
        "Maior item em estoque",
        topStockItem ? topStockItem.title : "Nao publicado",
        topStockItem
          ? `${formatCount(topStockItem.stock)} unidades em ${topStockItem.category} com origem ${topStockItem.merchant_name}.`
          : "Nenhum item lider por quantidade no payload.",
        topStockItem ? `${rowPill(topStockItem.module_id, "pill-accent")}${rowPill(formatMoney(topStockItem.inventory_value_brl), "pill-warn")}` : "",
      ),
      insightCardMarkup(
        "Maior ticket",
        topTicketItem ? topTicketItem.title : "Nao publicado",
        topTicketItem
          ? `${formatMoney(topTicketItem.price_brl)} por unidade em ${topTicketItem.module_id}.`
          : "Nenhum item de ticket maximo publicado.",
        topTicketItem ? `${rowPill(topTicketItem.category, "pill-navy")}${rowPill(topTicketItem.merchant_name, "pill-accent")}` : "",
      ),
    ].join("");
  }

  function integrationScopeList(value) {
    return String(value || "")
      .split(",")
      .map((item) => item.trim())
      .filter(Boolean);
  }

  function integrationReadiness(provider) {
    const requiredChecks = [
      { label: "Base URL", ready: Boolean(provider.baseUrl) },
      { label: "Client/App", ready: Boolean(provider.clientId) },
      { label: "Secret ref", ready: Boolean(provider.secretRef) },
      { label: "Redirect URI", ready: Boolean(provider.redirectUri) },
      { label: "Seller/Store", ready: Boolean(provider.sellerId) },
      { label: "Tokens", ready: Boolean(provider.accessTokenRef || provider.refreshTokenRef) },
      { label: "Scopes", ready: integrationScopeList(provider.scopes).length > 0 },
      { label: "Webhook", ready: Boolean(provider.webhookUrl && provider.webhookSecretRef) },
      { label: "Stock ativo", ready: provider.stockModuleEnabled !== false },
      { label: "Sandbox + producao", ready: provider.sandboxEnabled !== false && provider.productionEnabled !== false },
      { label: "Categorias", ready: provider.importCategories !== false },
    ];
    const completed = requiredChecks.filter((item) => item.ready).length;
    const ratio = requiredChecks.length ? completed / requiredChecks.length : 0;
    const runtimeStatus = String(provider.runtimeStatus || "");
    const runtimePending = Array.isArray(provider.runtimePending) ? provider.runtimePending : [];
    let stage = "rascunho";
    let variant = "pill-warn";

    if (!provider.enabled || provider.stockModuleEnabled === false) {
      stage = "desativado";
      variant = "pill";
    } else if (runtimeStatus === "active" && provider.productionEnabled !== false && ratio >= 0.85) {
      stage = "pronto para producao";
      variant = "pill-accent";
    } else if (runtimePending.length || runtimeStatus === "external_auth_pending") {
      stage = "credencial externa pendente";
      variant = "pill-danger";
    } else if (ratio >= 0.55) {
      stage = "em homologacao";
      variant = "pill-navy";
    }

    return {
      ratio,
      completed,
      total: requiredChecks.length,
      stage,
      variant,
      runtimeStatus,
      runtimePending,
      requiredChecks,
    };
  }

  function providerCapabilityPills(provider) {
    return [
      provider.stockModuleEnabled ? rowPill("Stock on", "pill-accent") : rowPill("Stock off", "pill-danger"),
      provider.importCatalog ? rowPill("Catalogo on", "pill-accent") : rowPill("Catalogo off"),
      provider.importCategories ? rowPill("Categorias on", "pill-accent") : rowPill("Categorias off", "pill-warn"),
      provider.syncOrders ? rowPill("Pedidos on", "pill-accent") : rowPill("Pedidos off"),
      provider.syncInventory ? rowPill("Estoque on", "pill-accent") : rowPill("Estoque off"),
      provider.syncPricing ? rowPill("Preco on", "pill-accent") : rowPill("Preco off"),
      provider.sandboxEnabled ? rowPill("Sandbox on", "pill-navy") : rowPill("Sandbox off", "pill-warn"),
      provider.productionEnabled ? rowPill("Prod on", "pill-accent") : rowPill("Prod off", "pill-danger"),
      provider.requireRetailAdvantage ? rowPill("Regra varejo", "pill-accent") : rowPill("Sem regra varejo", "pill-warn"),
      provider.requireLiquidityCheck ? rowPill("Liquidez on", "pill-accent") : rowPill("Liquidez off", "pill-warn"),
      provider.allowScrapingFallback ? rowPill("Fallback scraping", "pill-warn") : rowPill("Sem scraping", "pill-navy"),
      provider.blockExternalAiLookup ? rowPill("IA externa bloqueada", "pill-accent") : rowPill("IA externa liberada", "pill-danger"),
    ].join("");
  }

  function nextIntegrationAction(provider, readiness) {
    if (!provider.enabled) {
      return "Ativar o conector e escolher o ambiente de trabalho do fornecedor.";
    }

    if (provider.stockModuleEnabled === false) {
      return "Reativar o modulo STOCK para recolocar catálogo, estoque e pricing em operação.";
    }

    if (!provider.clientId || !provider.secretRef) {
      return "Publicar credenciais principais no vault e referenciar o segredo no cockpit.";
    }

    if (!provider.redirectUri) {
      return "Registrar redirect URI valida antes de iniciar a autorizacao OAuth da conta seller.";
    }

    if (!provider.sellerId) {
      return "Registrar seller ou store ID para fechar o contrato operacional da conta.";
    }

    if (!provider.accessTokenRef && provider.authMode !== "app_key_secret") {
      return "Autorizar a conta seller e persistir access token ou refresh token para operar sem login manual.";
    }

    if (!provider.webhookSecretRef || !provider.webhookUrl) {
      return "Webhook pode entrar depois; por ora opere com polling e publique notificacoes quando quiser baixa latencia.";
    }

    if (provider.sandboxEnabled === false || provider.productionEnabled === false) {
      return "Manter sandbox e produção ativos no mesmo cockpit para homologar sem perder a esteira operacional.";
    }

    if (readiness.runtimePending.length) {
      return "Fechar a pendencia externa do parceiro e persistir tokens, seller ID e webhook no ambiente correto.";
    }

    if (provider.environment !== "production") {
      return "Concluir homologacao e virar para producao so depois de reconciliar SKU, preco e estoque.";
    }

    if (readiness.ratio < 1) {
      return "Fechar lacunas de credencial restantes para evitar rota parcial em produção.";
    }

    return "Operar reconciliação contínua de catálogo, pedidos e settlement com observabilidade ligada.";
  }

  function renderMarketplaceSummary(config) {
    if (!elements.marketplaceApiSummary) {
      return;
    }

    const enabledCount = config.filter((provider) => provider.enabled).length;
    const productionCount = config.filter((provider) => provider.enabled && provider.productionEnabled !== false).length;
    const stockEnabledCount = config.filter((provider) => provider.stockModuleEnabled !== false).length;
    const fallbackCount = config.filter((provider) => provider.allowScrapingFallback).length;
    const pendingRuntimeCount = config.filter((provider) => Array.isArray(provider.runtimePending) && provider.runtimePending.length).length;
    const averageReadiness =
      config.reduce((sum, provider) => sum + integrationReadiness(provider).ratio, 0) / Math.max(config.length, 1);

    elements.marketplaceApiSummary.innerHTML = [
      summaryTileMarkup("Fornecedores", formatCount(config.length), "base ativa do cockpit dropshipping"),
      summaryTileMarkup("Conectores ativos", formatCount(enabledCount), `${formatCount(productionCount)} em producao`),
      summaryTileMarkup("Stock ativo", formatCount(stockEnabledCount), pendingRuntimeCount ? `${formatCount(pendingRuntimeCount)} com pendencia externa` : "sem bloqueio externo publicado"),
      summaryTileMarkup("Prontidao media", formatPercent(averageReadiness), "credenciais, tokens e webhooks"),
      summaryTileMarkup("Fallbacks", formatCount(fallbackCount), fallbackCount ? "revisar scraping e risco operacional" : "sem rota paralela aberta"),
    ].join("");
  }

  function renderMarketplaceControlCenter(config) {
    if (!elements.marketplaceApiControlCenter) {
      return;
    }

    elements.marketplaceApiControlCenter.innerHTML = config
      .map((provider) => {
        const readiness = integrationReadiness(provider);
        const guide = STOCK_PROVIDER_GUIDES[provider.key] || { steps: [] };

        return `
          <article class="integration-ops-card">
            <div class="integration-ops-head">
              <div>
                <h3>${escapeHtml(provider.label)}</h3>
                <p class="muted-copy">${escapeHtml(nextIntegrationAction(provider, readiness))}</p>
              </div>
              <div class="pill-row">
                ${rowPill(provider.environment === "production" ? "producao" : "sandbox", provider.environment === "production" ? "pill-accent" : "pill-warn")}
                ${rowPill(readiness.stage, readiness.variant)}
                ${provider.runtimeStatus ? rowPill(provider.runtimeStatus, provider.runtimeActive ? "pill-accent" : "pill-danger") : ""}
              </div>
            </div>
            ${progressMarkup(readiness.ratio)}
            <div class="summary-grid compact-summary-grid">
              ${summaryTileMarkup("Credenciais", `${formatCount(readiness.completed)}/${formatCount(readiness.total)}`, "campos operacionais preenchidos")}
              ${summaryTileMarkup("Sync", `${formatCount([provider.importCatalog, provider.syncOrders, provider.syncInventory, provider.syncPricing].filter(Boolean).length)}/4`, "catalogo, pedidos, estoque, preco")}
              ${summaryTileMarkup("Cadencia", `${formatCount(provider.syncCadenceMinutes)} min`, `cache ${formatCount(provider.cacheTtlMinutes)} min`)}
              ${summaryTileMarkup("Margem piso", `${provider.marginFloorPct}%`, provider.sellerId ? `seller ${provider.sellerId}` : "seller ainda ausente")}
              ${summaryTileMarkup("Modos", `${provider.sandboxEnabled ? "sandbox" : "sem sandbox"} / ${provider.productionEnabled ? "prod" : "sem prod"}`, provider.importCategories ? "categorias importadas" : "categorias bloqueadas")}
            </div>
            <div class="integration-matrix">
              <div class="integration-column">
                <span class="small-label">Cobertura operacional</span>
                <div class="pill-row">${providerCapabilityPills(provider)}</div>
              </div>
              <div class="integration-column">
                <span class="small-label">Checklist de credenciais</span>
                <div class="checklist-list dense-checklist">
                  ${readiness.requiredChecks
                    .map(
                      (item) => `
                        <div class="check-item ${item.ready ? "done" : ""}">
                          <span class="check-flag">${item.ready ? "OK" : "TODO"}</span>
                          <span>${escapeHtml(item.label)}</span>
                        </div>
                      `,
                    )
                    .join("")}
                </div>
              </div>
              <div class="integration-column">
                <span class="small-label">Passos de ativacao</span>
                <ol class="provider-guide-list compact-guide-list">
                  ${(guide.steps || []).slice(0, 3).map((step) => `<li>${escapeHtml(step)}</li>`).join("")}
                </ol>
              </div>
            </div>
            ${
              Array.isArray(provider.runtimePending) && provider.runtimePending.length
                ? `
                  <div class="runtime-evidence-box">
                    <span class="small-label">Pendencias externas</span>
                    <div class="pill-row">${provider.runtimePending.map((item) => rowPill(item, "pill-danger")).join("")}</div>
                  </div>
                `
                : ""
            }
            ${
              Array.isArray(provider.runtimeEvidence) && provider.runtimeEvidence.length
                ? `
                  <div class="runtime-evidence-box">
                    <span class="small-label">Evidencias runtime</span>
                    <div class="pill-row">${provider.runtimeEvidence.map((item) => rowPill(item, "pill-navy")).join("")}</div>
                  </div>
                `
                : ""
            }
          </article>
        `;
      })
      .join("");
  }

  function renderStockProviderGuides() {
    if (!elements.stockProviderGuides) {
      return;
    }

    const config = readMarketplaceApiConfig();

    if (elements.stockGuideSummary) {
      const productionGuides = config.filter((provider) => provider.environment === "production").length;
      const webhookReady = config.filter((provider) => provider.webhookUrl && provider.webhookSecretRef).length;
      const tokenReady = config.filter((provider) => provider.accessTokenRef || provider.refreshTokenRef).length;
      const notesOpen = config.filter((provider) => provider.notes).length;
      const stockEnabled = config.filter((provider) => provider.stockModuleEnabled !== false).length;

      elements.stockGuideSummary.innerHTML = [
        summaryTileMarkup("Fornecedores mapeados", formatCount(MARKETPLACE_API_PROVIDERS.length), "playbooks ativos no cockpit"),
        summaryTileMarkup("Stock habilitado", formatCount(stockEnabled), "fornecedores com modulo STOCK ligado"),
        summaryTileMarkup("Webhooks fechados", formatCount(webhookReady), "assinatura e callback publicados"),
        summaryTileMarkup("Tokens publicados", formatCount(tokenReady), "cofre operacional e refresh controlado"),
        summaryTileMarkup("Contas em producao", formatCount(productionGuides), notesOpen ? `${formatCount(notesOpen)} com notas operacionais` : "sem observacoes manuais"),
      ].join("");
    }

    const cards = MARKETPLACE_API_PROVIDERS.map((provider) => {
      const guide = STOCK_PROVIDER_GUIDES[provider.key];
      const providerConfig = config.find((item) => item.key === provider.key) || provider;
      const readiness = integrationReadiness(providerConfig);

      return `
        <article class="provider-guide-card">
          <div class="module-row-top">
            <div>
              <h3>${escapeHtml(provider.label)}</h3>
              <p class="muted-copy">${escapeHtml(guide?.auth || "Autenticacao ainda nao publicada.")}</p>
            </div>
            ${rowPill(provider.siteCode, "pill-navy")}
          </div>
          <div class="pill-row">
            ${rowPill(provider.key, "pill-accent")}
            ${rowPill(provider.baseUrl, "pill-warn")}
            ${rowPill(readiness.stage, readiness.variant)}
            ${providerConfig.runtimeStatus ? rowPill(providerConfig.runtimeStatus, providerConfig.runtimeActive ? "pill-accent" : "pill-danger") : ""}
          </div>
          <div class="provider-guide-meta">
            <div class="micro-stat">
              <span class="small-label">Prontidao</span>
              <strong>${escapeHtml(formatPercent(readiness.ratio))}</strong>
            </div>
            <div class="micro-stat">
              <span class="small-label">Ambiente</span>
              <strong>${escapeHtml(providerConfig.environment === "production" ? "Producao" : "Sandbox")}</strong>
            </div>
            <div class="micro-stat">
              <span class="small-label">Cadencia</span>
              <strong>${escapeHtml(`${providerConfig.syncCadenceMinutes || 30} min`)}</strong>
            </div>
          </div>
          <ol class="provider-guide-list">
            ${(guide?.steps || ["Guia nao publicado."]).map((step) => `<li>${escapeHtml(step)}</li>`).join("")}
          </ol>
        </article>
      `;
    });

    elements.stockProviderGuides.innerHTML = cards.join("");
  }

  function importedPricingItems() {
    return Array.isArray(importedPricingState.payload?.items) ? importedPricingState.payload.items : [];
  }

  function importedPricingPayloadUpdatedAt() {
    return importedPricingState.payload?.updated_at_utc || importedPricingState.payload?.generated_at_utc || "";
  }

  function importedSupplierBaseline(supplierKey) {
    const items = importedPricingItems().filter((item) => item.supplier_key === supplierKey);
    const persistedOverrides = importedPricingState.payload?.item_overrides || {};
    const fallback = {
      target_net_revenue_pct: 12,
      platform_fee_pct: 8,
      operational_fee_pct: 3,
      marketing_fee_pct: 2,
      tax_pct: 6,
      notes: "",
    };
    const baselineItem = items.find((item) => !persistedOverrides[item.id]) || items[0];

    if (!baselineItem) {
      return fallback;
    }

    return {
      target_net_revenue_pct: toNumber(baselineItem.target_net_revenue_pct, 12),
      platform_fee_pct: toNumber(baselineItem.platform_fee_pct, 8),
      operational_fee_pct: toNumber(baselineItem.operational_fee_pct, 3),
      marketing_fee_pct: toNumber(baselineItem.marketing_fee_pct, 2),
      tax_pct: toNumber(baselineItem.tax_pct, 6),
      notes: "",
    };
  }

  function importedSupplierControls(supplierKey) {
    const override = importedPricingState.draft.supplier_defaults?.[supplierKey] || {};
    return {
      ...importedSupplierBaseline(supplierKey),
      ...override,
      notes: String(override.notes || ""),
    };
  }

  function importedItemControls(item) {
    const override = importedPricingState.draft.item_overrides?.[item.id] || {};
    return {
      ...importedSupplierControls(item.supplier_key),
      ...override,
      notes: String(override.notes || importedSupplierControls(item.supplier_key).notes || ""),
    };
  }

  function derivePublicationAssessment(row) {
    const addReason = (codes, reasons, code, message) => {
      if (!codes.includes(code)) {
        codes.push(code);
        reasons.push(message);
      }
    };

    if (row.is_marketplace_reference) {
      return {
        publication_status: "benchmark_reference",
        publication_status_label: "Benchmark",
        publication_reason_codes: ["benchmark_reference"],
        publication_reasons: ["Item usado como benchmark de varejo para homologar preço de importação."],
        price_gap_to_benchmark_brl: row.price_gap_to_benchmark_brl,
      };
    }

    const blockingCodes = [];
    const reviewCodes = [];
    const reasons = [];
    const benchmarkGap =
      row.benchmark_retail_price_brl === null || row.benchmark_retail_price_brl === undefined
        ? null
        : Number((toNumber(row.benchmark_retail_price_brl) - toNumber(row.suggested_sale_price_brl)).toFixed(2));

    if (!row.stock_module_enabled) {
      addReason(blockingCodes, reasons, "stock_module_disabled", "Modulo STOCK desativado para este fornecedor.");
    }
    if (!row.production_enabled) {
      addReason(blockingCodes, reasons, "production_mode_disabled", "Modo de producao desligado para este fornecedor.");
    }
    if (!row.sandbox_enabled) {
      addReason(reviewCodes, reasons, "sandbox_mode_disabled", "Modo sandbox desligado; manter homologacao e producao ativas em paralelo.");
    }
    if (!row.import_catalog) {
      addReason(reviewCodes, reasons, "catalog_import_disabled", "Importacao de catalogo esta desligada para este fornecedor.");
    }
    if (!row.import_categories) {
      addReason(reviewCodes, reasons, "category_import_disabled", "Importacao de categorias esta desligada para este fornecedor.");
    }
    if (toNumber(row.stock) <= 0) {
      addReason(blockingCodes, reasons, "no_stock", "Fornecedor sem estoque confirmado para esta oferta.");
    }
    if (toNumber(row.estimated_net_revenue_brl) <= 0) {
      addReason(blockingCodes, reasons, "no_margin", "A precificacao atual nao gera margem liquida positiva.");
    }
    if (row.require_liquidity_check && toNumber(row.liquidity_score) < 35) {
      addReason(reviewCodes, reasons, "low_liquidity", "Liquidez abaixo do piso operacional definido para publicacao.");
    }
    if (toNumber(row.duplicate_group_size) > 1 && row.id !== row.duplicate_winner_item_id) {
      addReason(blockingCodes, reasons, "duplicate_loser", "Outro fornecedor venceu a disputa por menor custo e maior liquidez.");
    }
    if (row.require_retail_advantage) {
      if (benchmarkGap !== null && benchmarkGap <= 0) {
        addReason(blockingCodes, reasons, "retail_price_not_advantageous", "O preco sugerido nao fica abaixo do varejo de marketplace.");
      }
    }

    if (blockingCodes.length) {
      return {
        publication_status: "do_not_publish",
        publication_status_label: "Nao publicar",
        publication_reason_codes: [...blockingCodes, ...reviewCodes],
        publication_reasons: reasons,
        price_gap_to_benchmark_brl: benchmarkGap,
      };
    }

    if (reviewCodes.length) {
      return {
        publication_status: "review",
        publication_status_label: "Revisao",
        publication_reason_codes: reviewCodes,
        publication_reasons: reasons,
        price_gap_to_benchmark_brl: benchmarkGap,
      };
    }

    return {
      publication_status: "approved",
      publication_status_label: "Aprovado",
      publication_reason_codes: [],
      publication_reasons: [],
      price_gap_to_benchmark_brl: benchmarkGap,
    };
  }

  function projectImportedPricingItem(item) {
    const controls = importedItemControls(item);
    const baseCost = toNumber(item.base_cost_brl);
    const stock = toNumber(item.stock);
    const feesPctTotal =
      toNumber(controls.platform_fee_pct) +
      toNumber(controls.operational_fee_pct) +
      toNumber(controls.marketing_fee_pct) +
      toNumber(controls.tax_pct);
    const targetPctTotal = feesPctTotal + toNumber(controls.target_net_revenue_pct);
    const denominator = Math.max(0.05, 1 - targetPctTotal / 100);
    const suggestedSalePrice = denominator ? baseCost / denominator : baseCost;
    const estimatedFees = suggestedSalePrice * (feesPctTotal / 100);
    const estimatedNetRevenue = Math.max(suggestedSalePrice - baseCost - estimatedFees, 0);
    const estimatedNetRevenuePct = suggestedSalePrice > 0 ? (estimatedNetRevenue / suggestedSalePrice) * 100 : 0;
    const tags = Array.isArray(item.tags) ? item.tags : [];
    const publication = derivePublicationAssessment({
      ...item,
      ...controls,
      suggested_sale_price_brl: Number(suggestedSalePrice.toFixed(2)),
      estimated_net_revenue_brl: Number(estimatedNetRevenue.toFixed(2)),
      estimated_net_revenue_pct: Number(estimatedNetRevenuePct.toFixed(2)),
    });

    return {
      ...item,
      ...controls,
      ...publication,
      tags,
      inventory_cost_brl: Number((baseCost * stock).toFixed(2)),
      suggested_sale_price_brl: Number(suggestedSalePrice.toFixed(2)),
      estimated_fees_brl: Number(estimatedFees.toFixed(2)),
      estimated_net_revenue_brl: Number(estimatedNetRevenue.toFixed(2)),
      estimated_net_revenue_pct: Number(estimatedNetRevenuePct.toFixed(2)),
      estimated_inventory_net_revenue_brl: Number((estimatedNetRevenue * stock).toFixed(2)),
      _titleIndex: normalizeSearch(`${item.title} ${item.brand} ${item.id}`),
      _supplierIndex: normalizeSearch(
        `${item.supplier_name} ${item.supplier_type} ${item.supplier_model} ${item.merchant_name}`,
      ),
      _categoryIndex: normalizeSearch(
        `${item.category} ${item.collection_label} ${item.google_product_category_path} ${tags.join(" ")}`,
      ),
      _notesIndex: normalizeSearch(controls.notes),
      _searchIndex: normalizeSearch(
        [
          item.id,
          item.title,
          item.brand,
          item.category,
          item.collection_label,
          item.price_band,
          item.availability_label,
          item.provider_key,
          item.provider_status,
          item.supplier_name,
          item.supplier_type,
          item.supplier_model,
          item.merchant_name,
          item.channel_label,
          item.google_product_category_path,
          item.source_product_id,
          item.source_item_id,
          publication.publication_status_label,
          publication.publication_reason_codes.join(" "),
          publication.publication_reasons.join(" "),
          tags.join(" "),
          controls.notes,
        ].join(" "),
      ),
    };
  }

  function materializeImportedPricingRows() {
    return importedPricingItems()
      .map((item) => projectImportedPricingItem(item))
      .sort((left, right) => {
        const supplierComparison = String(left.supplier_name || "").localeCompare(String(right.supplier_name || ""), "pt-BR");
        if (supplierComparison !== 0) {
          return supplierComparison;
        }
        const categoryComparison = String(left.category || "").localeCompare(String(right.category || ""), "pt-BR");
        if (categoryComparison !== 0) {
          return categoryComparison;
        }
        if (right.estimated_inventory_net_revenue_brl !== left.estimated_inventory_net_revenue_brl) {
          return right.estimated_inventory_net_revenue_brl - left.estimated_inventory_net_revenue_brl;
        }
        return String(left.title || "").localeCompare(String(right.title || ""), "pt-BR");
      });
  }

  function importedSupplierSummaries(rows) {
    const grouped = new Map();

    rows.forEach((row) => {
      const current = grouped.get(row.supplier_key) || {
        supplier_key: row.supplier_key,
        supplier_name: row.supplier_name,
        provider_key: row.provider_key,
        supplier_type: row.supplier_type,
        items_total: 0,
        inventory_units: 0,
        inventory_cost_value_brl: 0,
        suggested_revenue_value_brl: 0,
        estimated_net_revenue_value_brl: 0,
      };

      current.items_total += 1;
      current.inventory_units += toNumber(row.stock);
      current.inventory_cost_value_brl += toNumber(row.inventory_cost_brl);
      current.suggested_revenue_value_brl += toNumber(row.suggested_sale_price_brl) * toNumber(row.stock);
      current.estimated_net_revenue_value_brl += toNumber(row.estimated_inventory_net_revenue_brl);
      grouped.set(row.supplier_key, current);
    });

    return [...grouped.values()].sort((left, right) => {
      if (right.suggested_revenue_value_brl !== left.suggested_revenue_value_brl) {
        return right.suggested_revenue_value_brl - left.suggested_revenue_value_brl;
      }
      return String(left.supplier_name || "").localeCompare(String(right.supplier_name || ""), "pt-BR");
    });
  }

  function importedFilterOptions(rows, field) {
    return [...new Set(rows.map((row) => String(row[field] || "").trim()).filter(Boolean))].sort((left, right) =>
      left.localeCompare(right, "pt-BR"),
    );
  }

  function filteredImportedPricingRows(rows) {
    const filters = importedPricingState.filters;
    const query = normalizeSearch(filters.query);
    const title = normalizeSearch(filters.title);
    const supplierName = normalizeSearch(filters.supplierName);
    const categoryText = normalizeSearch(filters.categoryText);
    const notes = normalizeSearch(filters.notes);
    const targetNetPct = normalizeSearch(filters.targetNetPct);
    const platformPct = normalizeSearch(filters.platformPct);
    const operationalPct = normalizeSearch(filters.operationalPct);
    const marketingPct = normalizeSearch(filters.marketingPct);
    const taxPct = normalizeSearch(filters.taxPct);

    return rows.filter((row) => {
      return (
        (!query || row._searchIndex.includes(query)) &&
        (filters.supplierKey === "all" || row.supplier_key === filters.supplierKey) &&
        (filters.providerKey === "all" || row.provider_key === filters.providerKey) &&
        (filters.publicationStatus === "all" || row.publication_status === filters.publicationStatus) &&
        (filters.category === "all" || row.category === filters.category) &&
        (filters.collectionLabel === "all" || row.collection_label === filters.collectionLabel) &&
        (filters.availabilityLabel === "all" || row.availability_label === filters.availabilityLabel) &&
        (filters.priceBand === "all" || row.price_band === filters.priceBand) &&
        (!title || row._titleIndex.includes(title)) &&
        (!supplierName || row._supplierIndex.includes(supplierName)) &&
        (!categoryText || row._categoryIndex.includes(categoryText)) &&
        (!notes || row._notesIndex.includes(notes)) &&
        (!targetNetPct || matchesSearch(row.target_net_revenue_pct, targetNetPct)) &&
        (!platformPct || matchesSearch(row.platform_fee_pct, platformPct)) &&
        (!operationalPct || matchesSearch(row.operational_fee_pct, operationalPct)) &&
        (!marketingPct || matchesSearch(row.marketing_fee_pct, marketingPct)) &&
        (!taxPct || matchesSearch(row.tax_pct, taxPct))
      );
    });
  }

  function pricingEntryMarkup(field, value, supplierKey, itemId) {
    const normalizedValue = field === "notes" ? String(value || "") : String(toNumber(value));
    const extraClass = field === "notes" ? "pricing-note-input" : "";
    const inputType = field === "notes" ? "text" : "number";
    const step = field === "notes" ? "" : ' step="0.1"';
    const min = field === "notes" ? "" : ' min="0"';

    return `
      <input
        class="${extraClass}"
        data-imported-supplier-key="${escapeHtml(supplierKey || "")}"
        ${itemId ? `data-imported-item-id="${escapeHtml(itemId)}"` : ""}
        data-imported-field="${escapeHtml(field)}"
        type="${inputType}"
        value="${escapeHtml(normalizedValue)}"${step}${min}
      />
    `;
  }

  async function loadImportedPricing() {
    try {
      const response = await fetch("/api/admin-imported-products-pricing", {
        cache: "no-store",
        headers: { Accept: "application/json" },
      });
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`);
      }

      const payload = await response.json();
      importedPricingState.payload = payload;
      importedPricingState.draft = {
        supplier_defaults: deepClone(payload?.supplier_defaults) || {},
        item_overrides: deepClone(payload?.item_overrides) || {},
      };
      importedPricingState.error = "";
    } catch (error) {
      importedPricingState.payload = null;
      importedPricingState.draft = { supplier_defaults: {}, item_overrides: {} };
      importedPricingState.error = error instanceof Error ? error.message : "falha ao carregar pricing";
    } finally {
      importedPricingState.loading = false;
      renderAdminLaunchpad();
      renderImportedPricingDesk();
    }
  }

  function renderImportedPricingDesk() {
    if (
      !elements.importedPricingSummary ||
      !elements.importedSupplierBoard ||
      !elements.importedPricingFilters ||
      !elements.importedPricingTableWrap ||
      !elements.publicationReviewSummary ||
      !elements.publicationReviewBoard
    ) {
      return;
    }

    if (importedPricingState.loading) {
      elements.importedPricingSummary.innerHTML = `<div class="empty-state">Carregando mesa de pricing importado...</div>`;
      elements.importedSupplierBoard.innerHTML = `<div class="empty-state">Carregando fornecedores...</div>`;
      elements.importedPricingFilters.innerHTML = `<div class="empty-state">Preparando filtros...</div>`;
      elements.importedPricingTableWrap.innerHTML = `<div class="empty-state">Carregando produtos importados...</div>`;
      elements.publicationReviewSummary.innerHTML = `<div class="empty-state">Preparando fila de revisao...</div>`;
      elements.publicationReviewBoard.innerHTML = `<div class="empty-state">Carregando itens em revisao...</div>`;
      return;
    }

    if (!importedPricingState.payload) {
      const message = escapeHtml(importedPricingState.error || "servico indisponivel");
      elements.importedPricingSummary.innerHTML = `<div class="empty-state">Mesa indisponivel: ${message}</div>`;
      elements.importedSupplierBoard.innerHTML = `<div class="empty-state">Nenhum fornecedor publicado.</div>`;
      elements.importedPricingFilters.innerHTML = `<div class="empty-state">Filtros indisponiveis.</div>`;
      elements.importedPricingTableWrap.innerHTML = `<div class="empty-state">Tabela indisponivel.</div>`;
      elements.publicationReviewSummary.innerHTML = `<div class="empty-state">Fila de revisao indisponivel.</div>`;
      elements.publicationReviewBoard.innerHTML = `<div class="empty-state">Sem leitura de bloqueios.</div>`;
      return;
    }

    const allRows = materializeImportedPricingRows();
    const filteredRows = filteredImportedPricingRows(allRows);

    renderImportedPricingSummary(filteredRows);
    renderImportedSupplierBoard(allRows);
    renderImportedPricingFilters(allRows);
    renderImportedPricingTable(filteredRows);
    renderPublicationReviewDesk(allRows);
    renderAdminLaunchpad();
  }

  function renderImportedPricingSummary(rows) {
    const suppliers = new Set(rows.map((row) => row.supplier_key));
    const inventoryCost = rows.reduce((sum, row) => sum + toNumber(row.inventory_cost_brl), 0);
    const suggestedRevenue = rows.reduce(
      (sum, row) => sum + toNumber(row.suggested_sale_price_brl) * toNumber(row.stock),
      0,
    );
    const estimatedNetRevenue = rows.reduce((sum, row) => sum + toNumber(row.estimated_inventory_net_revenue_brl), 0);
    const updatedAt = importedPricingPayloadUpdatedAt();
    const approved = rows.filter((row) => row.publication_status === "approved").length;
    const review = rows.filter((row) => row.publication_status === "review").length;
    const blocked = rows.filter((row) => row.publication_status === "do_not_publish").length;

    elements.importedPricingSummary.innerHTML = [
      summaryTileMarkup("Itens filtrados", formatCount(rows.length), "produtos importados no recorte atual"),
      summaryTileMarkup("Fornecedores", formatCount(suppliers.size), "origens comerciais ativas no desk"),
      summaryTileMarkup("Publicacao", `${formatCount(approved)} aprovados`, review || blocked ? `${formatCount(review)} em revisao | ${formatCount(blocked)} bloqueados` : "sem bloqueio no recorte atual"),
      summaryTileMarkup("Custo em estoque", formatMoney(inventoryCost), "base de custo agregada pela regra local"),
      summaryTileMarkup(
        "Faturamento liquido estimado",
        formatMoney(estimatedNetRevenue),
        updatedAt ? `regras atualizadas ${formatTimestamp(updatedAt)} | receita sugerida ${formatMoney(suggestedRevenue)}` : "regras ainda nao persistidas",
      ),
    ].join("");
  }

  function renderImportedSupplierBoard(rows) {
    const suppliers = importedSupplierSummaries(rows);
    const activeSupplierKey = importedPricingState.filters.supplierKey;
    const totalItems = rows.length;
    const totalNet = rows.reduce((sum, row) => sum + toNumber(row.estimated_inventory_net_revenue_brl), 0);

    const cards = [
      `
        <article class="imported-supplier-card ${activeSupplierKey === "all" ? "is-active" : ""}" data-imported-supplier-card data-imported-supplier="all">
          <div class="integration-card-head">
            <div>
              <h3>Todos os fornecedores</h3>
              <p class="muted-copy">Visao consolidada do catálogo importado traduzido.</p>
            </div>
            ${rowPill("consolidado", "pill-accent")}
          </div>
          <div class="integration-card-overview">
            ${summaryTileMarkup("Itens", formatCount(totalItems), "produtos ativos no desk")}
            ${summaryTileMarkup("Fornecedores", formatCount(suppliers.length), "bases integradas")}
            ${summaryTileMarkup("Liquido estimado", formatMoney(totalNet), "estoque total recalculado")}
            ${summaryTileMarkup("Locale", escapeHtml(importedPricingState.payload?.locale || "pt-BR"), "catálogo traduzido")}
          </div>
        </article>
      `,
      ...suppliers.map((supplier) => {
        const controls = importedSupplierControls(supplier.supplier_key);
        const supplierRows = rows.filter((row) => row.supplier_key === supplier.supplier_key);
        const approvedCount = supplierRows.filter((row) => row.publication_status === "approved").length;
        const reviewCount = supplierRows.filter((row) => row.publication_status === "review").length;
        const blockedCount = supplierRows.filter((row) => row.publication_status === "do_not_publish").length;

        return `
          <article
            class="imported-supplier-card ${activeSupplierKey === supplier.supplier_key ? "is-active" : ""}"
            data-imported-supplier-card
            data-imported-supplier="${escapeHtml(supplier.supplier_key)}"
          >
            <div class="integration-card-head">
              <div>
                <h3>${escapeHtml(supplier.supplier_name)}</h3>
                <p class="muted-copy">${escapeHtml(supplier.provider_key)} · ${escapeHtml(supplier.supplier_type || "supplier")}</p>
              </div>
              <div class="pill-row">
                ${rowPill(formatCount(supplier.items_total) + " itens", "pill-accent")}
                ${rowPill(formatMoney(supplier.estimated_net_revenue_value_brl), "pill-navy")}
              </div>
            </div>
            <div class="integration-card-overview">
              ${summaryTileMarkup("Estoque", formatCount(supplier.inventory_units), "unidades importadas")}
              ${summaryTileMarkup("Custo", formatMoney(supplier.inventory_cost_value_brl), "valor base agregado")}
              ${summaryTileMarkup("Receita", formatMoney(supplier.suggested_revenue_value_brl), "preco sugerido")}
              ${summaryTileMarkup("Liquido", formatMoney(supplier.estimated_net_revenue_value_brl), "margem estimada em estoque")}
              ${summaryTileMarkup("Publicacao", `${formatCount(approvedCount)} ok`, reviewCount || blockedCount ? `${formatCount(reviewCount)} revisao | ${formatCount(blockedCount)} bloqueados` : "sem fila")}
            </div>
            <div class="integration-form-grid">
              <label class="field">
                <span>Meta liquida %</span>
                ${pricingEntryMarkup("target_net_revenue_pct", controls.target_net_revenue_pct, supplier.supplier_key)}
              </label>
              <label class="field">
                <span>Plataforma %</span>
                ${pricingEntryMarkup("platform_fee_pct", controls.platform_fee_pct, supplier.supplier_key)}
              </label>
              <label class="field">
                <span>Operacao %</span>
                ${pricingEntryMarkup("operational_fee_pct", controls.operational_fee_pct, supplier.supplier_key)}
              </label>
              <label class="field">
                <span>Marketing %</span>
                ${pricingEntryMarkup("marketing_fee_pct", controls.marketing_fee_pct, supplier.supplier_key)}
              </label>
              <label class="field">
                <span>Tributos %</span>
                ${pricingEntryMarkup("tax_pct", controls.tax_pct, supplier.supplier_key)}
              </label>
              <label class="field">
                <span>Notas do fornecedor</span>
                ${pricingEntryMarkup("notes", controls.notes, supplier.supplier_key)}
              </label>
            </div>
            <div class="integration-actions">
              <button class="secondary-button" type="button" data-imported-reset-supplier="${escapeHtml(supplier.supplier_key)}">Limpar regra do fornecedor</button>
            </div>
          </article>
        `;
      }),
    ];

    elements.importedSupplierBoard.innerHTML = cards.join("");
  }

  function renderImportedPricingFilters(rows) {
    const filters = importedPricingState.filters;
    const suppliers = importedSupplierSummaries(rows);
    const providerOptions = importedFilterOptions(rows, "provider_key");
    const publicationOptions = [
      ["approved", "Aprovados"],
      ["review", "Revisao"],
      ["do_not_publish", "Nao publicar"],
      ["benchmark_reference", "Benchmarks"],
    ];
    const categoryOptions = importedFilterOptions(rows, "category");
    const collectionOptions = importedFilterOptions(rows, "collection_label");
    const availabilityOptions = importedFilterOptions(rows, "availability_label");
    const priceBandOptions = importedFilterOptions(rows, "price_band");

    elements.importedPricingFilters.innerHTML = `
      <label class="field">
        <span>Busca geral</span>
        <input data-imported-filter="query" type="text" value="${escapeHtml(filters.query)}" placeholder="sku, titulo, fornecedor, tags, origem" />
      </label>
      <label class="field">
        <span>Fornecedor</span>
        <select data-imported-filter="supplierKey">
          ${optionMarkup("all", "Todos")}
          ${suppliers.map((supplier) => optionMarkup(supplier.supplier_key, supplier.supplier_name)).join("")}
        </select>
      </label>
      <label class="field">
        <span>Provider</span>
        <select data-imported-filter="providerKey">
          ${optionMarkup("all", "Todos")}
          ${providerOptions.map((value) => optionMarkup(value, value)).join("")}
        </select>
      </label>
      <label class="field">
        <span>Status de publicacao</span>
        <select data-imported-filter="publicationStatus">
          ${optionMarkup("all", "Todos")}
          ${publicationOptions.map(([value, label]) => optionMarkup(value, label)).join("")}
        </select>
      </label>
      <label class="field">
        <span>Categoria</span>
        <select data-imported-filter="category">
          ${optionMarkup("all", "Todas")}
          ${categoryOptions.map((value) => optionMarkup(value, value)).join("")}
        </select>
      </label>
      <label class="field">
        <span>Colecao</span>
        <select data-imported-filter="collectionLabel">
          ${optionMarkup("all", "Todas")}
          ${collectionOptions.map((value) => optionMarkup(value, value)).join("")}
        </select>
      </label>
      <label class="field">
        <span>Disponibilidade</span>
        <select data-imported-filter="availabilityLabel">
          ${optionMarkup("all", "Todas")}
          ${availabilityOptions.map((value) => optionMarkup(value, value)).join("")}
        </select>
      </label>
      <label class="field">
        <span>Faixa de preco</span>
        <select data-imported-filter="priceBand">
          ${optionMarkup("all", "Todas")}
          ${priceBandOptions.map((value) => optionMarkup(value, value)).join("")}
        </select>
      </label>
      <label class="field">
        <span>Linhas por pagina</span>
        <select data-imported-filter="pageSize">
          ${[12, 24, 48, 96].map((value) => optionMarkup(String(value), `${value} linhas`)).join("")}
        </select>
      </label>
    `;

    elements.importedPricingFilters.querySelector('[data-imported-filter="supplierKey"]').value = filters.supplierKey;
    elements.importedPricingFilters.querySelector('[data-imported-filter="providerKey"]').value = filters.providerKey;
    elements.importedPricingFilters.querySelector('[data-imported-filter="publicationStatus"]').value = filters.publicationStatus;
    elements.importedPricingFilters.querySelector('[data-imported-filter="category"]').value = filters.category;
    elements.importedPricingFilters.querySelector('[data-imported-filter="collectionLabel"]').value = filters.collectionLabel;
    elements.importedPricingFilters.querySelector('[data-imported-filter="availabilityLabel"]').value = filters.availabilityLabel;
    elements.importedPricingFilters.querySelector('[data-imported-filter="priceBand"]').value = filters.priceBand;
    elements.importedPricingFilters.querySelector('[data-imported-filter="pageSize"]').value = String(importedPricingState.pageSize);
  }

  function renderImportedPricingTable(rows) {
    const totalPages = Math.max(1, Math.ceil(rows.length / importedPricingState.pageSize));
    importedPricingState.page = Math.min(importedPricingState.page, totalPages);
    const pageStart = (importedPricingState.page - 1) * importedPricingState.pageSize;
    const pageRows = rows.slice(pageStart, pageStart + importedPricingState.pageSize);
    const filters = importedPricingState.filters;
    const providerOptions = importedFilterOptions(materializeImportedPricingRows(), "provider_key");
    const availabilityOptions = importedFilterOptions(materializeImportedPricingRows(), "availability_label");
    const publicationVariant = {
      approved: "pill-accent",
      review: "pill-warn",
      do_not_publish: "pill-danger",
      benchmark_reference: "pill-navy",
    };

    elements.importedPricingTableWrap.innerHTML = `
      <div class="pricing-toolbar">
        <div>
          <strong>${escapeHtml(formatCount(rows.length))} itens visiveis</strong>
          <p class="muted-copy">Catalogo integrado pt-BR com calculo de preco sugerido, taxas e faturamento liquido por SKU.</p>
        </div>
        <div class="pricing-toolbar-meta">
          ${rowPill(`${formatCount(new Set(rows.map((row) => row.supplier_key)).size)} fornecedores`, "pill-accent")}
          ${rowPill(`${formatCount(pageRows.length)} linhas na pagina`, "pill-navy")}
          ${rowPill(`${formatCount(rows.filter((row) => row.publication_status === "review" || row.publication_status === "do_not_publish").length)} em fila`, "pill-danger")}
          ${rowPill(importedPricingState.payload?.providers_active?.join(", ") || "catalogo ativo", "pill")}
        </div>
      </div>
      <table class="imported-pricing-table">
        <thead>
          <tr>
            <th>Produto</th>
            <th>Fornecedor</th>
            <th>Origem</th>
            <th>Segmento</th>
            <th>Disponibilidade</th>
            <th>Publicacao</th>
            <th>Custo base</th>
            <th>Estoque</th>
            <th>Meta liquida %</th>
            <th>Plataforma %</th>
            <th>Operacao %</th>
            <th>Marketing %</th>
            <th>Tributos %</th>
            <th>Preco sugerido</th>
            <th>Liquido unit.</th>
            <th>Liquido estoque</th>
            <th>Notas</th>
            <th>Acoes</th>
          </tr>
          <tr>
            <th><input data-imported-filter="title" type="text" value="${escapeHtml(filters.title || "")}" placeholder="filtrar produto" /></th>
            <th><input data-imported-filter="supplierName" type="text" value="${escapeHtml(filters.supplierName || "")}" placeholder="filtrar fornecedor" /></th>
            <th>
              <select data-imported-filter="providerKey">
                ${optionMarkup("all", "todos")}
                ${providerOptions.map((value) => optionMarkup(value, value)).join("")}
              </select>
            </th>
            <th><input data-imported-filter="categoryText" type="text" value="${escapeHtml(filters.categoryText || "")}" placeholder="categoria ou colecao" /></th>
            <th>
              <select data-imported-filter="availabilityLabel">
                ${optionMarkup("all", "todas")}
                ${availabilityOptions.map((value) => optionMarkup(value, value)).join("")}
              </select>
            </th>
            <th>
              <select data-imported-filter="publicationStatus">
                ${optionMarkup("all", "todos")}
                ${optionMarkup("approved", "aprovados")}
                ${optionMarkup("review", "revisao")}
                ${optionMarkup("do_not_publish", "nao publicar")}
                ${optionMarkup("benchmark_reference", "benchmarks")}
              </select>
            </th>
            <th></th>
            <th></th>
            <th><input data-imported-filter="targetNetPct" type="text" value="${escapeHtml(filters.targetNetPct || "")}" placeholder="%" /></th>
            <th><input data-imported-filter="platformPct" type="text" value="${escapeHtml(filters.platformPct || "")}" placeholder="%" /></th>
            <th><input data-imported-filter="operationalPct" type="text" value="${escapeHtml(filters.operationalPct || "")}" placeholder="%" /></th>
            <th><input data-imported-filter="marketingPct" type="text" value="${escapeHtml(filters.marketingPct || "")}" placeholder="%" /></th>
            <th><input data-imported-filter="taxPct" type="text" value="${escapeHtml(filters.taxPct || "")}" placeholder="%" /></th>
            <th></th>
            <th></th>
            <th></th>
            <th><input data-imported-filter="notes" type="text" value="${escapeHtml(filters.notes || "")}" placeholder="anotacoes" /></th>
            <th></th>
          </tr>
        </thead>
        <tbody>
          ${
            pageRows.length
              ? pageRows
                  .map(
                    (row) => `
                      <tr>
                        <td>
                          <div class="pricing-cell-title">
                            <strong>${escapeHtml(row.title)}</strong>
                            <span class="muted-copy">${escapeHtml(row.brand || "marca livre")} · ${escapeHtml(row.category || "sem categoria")}</span>
                            <code>${escapeHtml(row.id)}</code>
                          </div>
                        </td>
                        <td>
                          <div class="pricing-inline-stack">
                            <span class="pricing-value">${escapeHtml(row.supplier_name)}</span>
                            <span class="muted-copy">${escapeHtml(row.supplier_type || "supplier")} · ${escapeHtml(row.supplier_model || "modelo padrao")}</span>
                          </div>
                        </td>
                        <td>
                          <div class="pricing-inline-stack">
                            ${rowPill(row.provider_key, "pill-accent")}
                            <span class="muted-copy">${escapeHtml(row.channel_label || row.provider_status || "canal integrado")}</span>
                          </div>
                        </td>
                        <td>
                          <div class="pricing-inline-stack">
                            <span class="pricing-value">${escapeHtml(row.collection_label || row.category || "sem colecao")}</span>
                            <span class="muted-copy">${escapeHtml(row.google_product_category_path || "taxonomia local")}</span>
                          </div>
                        </td>
                        <td>
                          <div class="pricing-inline-stack">
                            ${rowPill(row.availability_label || "disponivel", "pill")}
                            <span class="muted-copy">${escapeHtml(row.price_band || "faixa livre")}${row.shipping_free ? " · frete integrado" : ""}</span>
                          </div>
                        </td>
                        <td>
                          <div class="pricing-inline-stack">
                            ${rowPill(row.publication_status_label || row.publication_status || "revisao", publicationVariant[row.publication_status] || "pill")}
                            <span class="muted-copy">${escapeHtml(row.publication_reasons?.[0] || (row.benchmark_provider_key ? `benchmark ${row.benchmark_provider_key}` : "sem alerta"))}</span>
                          </div>
                        </td>
                        <td>${escapeHtml(formatMoney(row.base_cost_brl))}</td>
                        <td>${escapeHtml(formatCount(row.stock))}</td>
                        <td>${pricingEntryMarkup("target_net_revenue_pct", row.target_net_revenue_pct, row.supplier_key, row.id)}</td>
                        <td>${pricingEntryMarkup("platform_fee_pct", row.platform_fee_pct, row.supplier_key, row.id)}</td>
                        <td>${pricingEntryMarkup("operational_fee_pct", row.operational_fee_pct, row.supplier_key, row.id)}</td>
                        <td>${pricingEntryMarkup("marketing_fee_pct", row.marketing_fee_pct, row.supplier_key, row.id)}</td>
                        <td>${pricingEntryMarkup("tax_pct", row.tax_pct, row.supplier_key, row.id)}</td>
                        <td>${escapeHtml(formatMoney(row.suggested_sale_price_brl))}</td>
                        <td>${escapeHtml(formatMoney(row.estimated_net_revenue_brl))}<br /><span class="muted-copy">${escapeHtml(`${row.estimated_net_revenue_pct.toFixed(2)}%`)}</span></td>
                        <td>${escapeHtml(formatMoney(row.estimated_inventory_net_revenue_brl))}</td>
                        <td>${pricingEntryMarkup("notes", row.notes, row.supplier_key, row.id)}</td>
                        <td>
                          <button class="secondary-button" type="button" data-imported-reset-item="${escapeHtml(row.id)}">Limpar override</button>
                        </td>
                      </tr>
                    `,
                  )
                  .join("")
              : `<tr><td colspan="18"><div class="empty-state">Nenhum produto corresponde aos filtros e regras atuais.</div></td></tr>`
          }
        </tbody>
      </table>
      <div class="pricing-pager">
        <div class="muted-copy">Pagina ${escapeHtml(String(importedPricingState.page))} de ${escapeHtml(String(totalPages))}</div>
        <div class="pricing-pager-actions">
          <button class="secondary-button" type="button" data-imported-page="prev" ${importedPricingState.page <= 1 ? "disabled" : ""}>Anterior</button>
          <button class="secondary-button" type="button" data-imported-page="next" ${importedPricingState.page >= totalPages ? "disabled" : ""}>Proxima</button>
        </div>
      </div>
    `;

    const providerFilter = elements.importedPricingTableWrap.querySelector('select[data-imported-filter="providerKey"]');
    if (providerFilter) {
      providerFilter.value = filters.providerKey;
    }
    const availabilityFilter = elements.importedPricingTableWrap.querySelector('select[data-imported-filter="availabilityLabel"]');
    if (availabilityFilter) {
      availabilityFilter.value = filters.availabilityLabel;
    }
    const publicationFilter = elements.importedPricingTableWrap.querySelector('select[data-imported-filter="publicationStatus"]');
    if (publicationFilter) {
      publicationFilter.value = filters.publicationStatus;
    }
  }

  function renderPublicationReviewDesk(rows) {
    if (!elements.publicationReviewSummary || !elements.publicationReviewBoard) {
      return;
    }

    const reviewRows = rows
      .filter((row) => row.publication_status === "review" || row.publication_status === "do_not_publish")
      .sort((left, right) => {
        const leftRank = left.publication_status === "do_not_publish" ? 0 : 1;
        const rightRank = right.publication_status === "do_not_publish" ? 0 : 1;
        if (leftRank !== rightRank) {
          return leftRank - rightRank;
        }
        return toNumber(left.price_gap_to_benchmark_brl, 999999) - toNumber(right.price_gap_to_benchmark_brl, 999999);
      });

    const blocked = reviewRows.filter((row) => row.publication_status === "do_not_publish").length;
    const review = reviewRows.filter((row) => row.publication_status === "review").length;
    const topReasons = new Map();

    reviewRows.forEach((row) => {
      (row.publication_reasons || []).forEach((reason) => {
        topReasons.set(reason, (topReasons.get(reason) || 0) + 1);
      });
    });

    const topReasonsList = [...topReasons.entries()]
      .sort((left, right) => right[1] - left[1])
      .slice(0, 4)
      .map(([reason, total]) => `${reason} (${formatCount(total)})`)
      .join(" | ");

    elements.publicationReviewSummary.innerHTML = [
      summaryTileMarkup("Itens na fila", formatCount(reviewRows.length), reviewRows.length ? "bloqueios e revisoes comerciais ativas" : "nenhum item fora da politica"),
      summaryTileMarkup("Nao publicar", formatCount(blocked), blocked ? "preco, margem, duplicidade ou estoque bloqueando a oferta" : "sem bloqueios fatais"),
      summaryTileMarkup("Revisao", formatCount(review), review ? "liquidez ou configuracao complementar pendente" : "sem revisoes abertas"),
      summaryTileMarkup("Motivos dominantes", formatCount(topReasons.size), topReasonsList || "sem recorrencia no filtro atual"),
    ].join("");

    if (!reviewRows.length) {
      elements.publicationReviewBoard.innerHTML = `<div class="empty-state">Nenhum item exige revisao ou bloqueio no recorte atual.</div>`;
      return;
    }

    elements.publicationReviewBoard.innerHTML = reviewRows
      .slice(0, 18)
      .map(
        (row) => `
          <article class="publication-review-card ${row.publication_status === "do_not_publish" ? "is-blocked" : "is-review"}">
            <div class="module-row-top">
              <div>
                <h3>${escapeHtml(row.title)}</h3>
                <p class="muted-copy">${escapeHtml(row.supplier_name)} · ${escapeHtml(row.category || "sem categoria")}</p>
              </div>
              ${rowPill(row.publication_status_label || row.publication_status, row.publication_status === "do_not_publish" ? "pill-danger" : "pill-warn")}
            </div>
            <div class="publication-review-metrics">
              ${summaryTileMarkup("Custo", formatMoney(row.base_cost_brl), `sugerido ${formatMoney(row.suggested_sale_price_brl)}`)}
              ${summaryTileMarkup("Liquidez", formatCount(row.liquidity_score), row.require_liquidity_check ? "regra ativa" : "regra desligada")}
              ${summaryTileMarkup("Benchmark", row.benchmark_retail_price_brl ? formatMoney(row.benchmark_retail_price_brl) : "ausente", row.benchmark_provider_key || "sem marketplace")}
              ${summaryTileMarkup("Gap", row.price_gap_to_benchmark_brl === null || row.price_gap_to_benchmark_brl === undefined ? "n/d" : formatMoney(row.price_gap_to_benchmark_brl), row.price_gap_to_benchmark_brl > 0 ? "abaixo do varejo" : "acima ou igual ao varejo")}
            </div>
            <div class="pill-row">
              ${rowPill(row.provider_key, "pill-accent")}
              ${rowPill(`${formatCount(row.stock)} un`, "pill")}
              ${row.import_categories ? rowPill("categorias on", "pill-accent") : rowPill("categorias off", "pill-warn")}
            </div>
            <div class="review-reason-list">
              ${(row.publication_reasons || []).map((reason) => `<span class="review-reason">${escapeHtml(reason)}</span>`).join("")}
            </div>
            <div class="link-row">
              ${row.source_permalink ? `<a href="${escapeHtml(row.source_permalink)}" target="_blank" rel="noreferrer">Abrir origem</a>` : `<span class="pill">Origem sem URL</span>`}
              <a href="#importedPricingSection">Abrir mesa</a>
            </div>
          </article>
        `,
      )
      .join("");
  }

  function sanitizeImportedPricingEntry(entry) {
    if (!entry || typeof entry !== "object") {
      return null;
    }

    const normalized = {};
    PRICING_EDITABLE_FIELDS.forEach((field) => {
      if (!(field in entry)) {
        return;
      }
      if (field === "notes") {
        normalized.notes = String(entry.notes || "").trim();
        return;
      }
      normalized[field] = toNumber(entry[field]);
    });

    return Object.keys(normalized).length ? normalized : null;
  }

  function collectImportedPricingPayload() {
    const supplierDefaults = {};
    const itemOverrides = {};

    Object.entries(importedPricingState.draft.supplier_defaults || {}).forEach(([key, value]) => {
      const normalized = sanitizeImportedPricingEntry(value);
      if (normalized) {
        supplierDefaults[key] = normalized;
      }
    });

    Object.entries(importedPricingState.draft.item_overrides || {}).forEach(([key, value]) => {
      const normalized = sanitizeImportedPricingEntry(value);
      if (normalized) {
        itemOverrides[key] = normalized;
      }
    });

    return {
      supplier_defaults: supplierDefaults,
      item_overrides: itemOverrides,
    };
  }

  function resetImportedPricingDefaults() {
    importedPricingState.draft = {
      supplier_defaults: {},
      item_overrides: {},
    };
    renderImportedPricingDesk();
    announce("Regras locais de pricing restauradas para o padrao.");
  }

  async function saveImportedPricing() {
    const payload = collectImportedPricingPayload();

    try {
      const response = await fetch("/api/admin-imported-products-pricing", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Accept: "application/json",
        },
        body: JSON.stringify(payload),
      });
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`);
      }

      announce("Regras de pricing importado salvas.");
      importedPricingState.loading = true;
      renderImportedPricingDesk();
      await loadImportedPricing();
    } catch (error) {
      announce("Falha ao salvar pricing importado.");
    }
  }

  function updateImportedPricingFilter(field, value) {
    if (field === "pageSize") {
      importedPricingState.pageSize = Math.max(1, toNumber(value, 24));
    } else {
      importedPricingState.filters[field] = String(value || "");
    }
    importedPricingState.page = 1;
    renderImportedPricingDesk();
  }

  function updateImportedSupplierField(supplierKey, field, value) {
    const next = {
      ...(importedPricingState.draft.supplier_defaults?.[supplierKey] || {}),
    };
    next[field] = field === "notes" ? String(value || "") : toNumber(value);
    importedPricingState.draft.supplier_defaults = {
      ...(importedPricingState.draft.supplier_defaults || {}),
      [supplierKey]: next,
    };
    renderImportedPricingDesk();
  }

  function updateImportedItemField(itemId, field, value) {
    const next = {
      ...(importedPricingState.draft.item_overrides?.[itemId] || {}),
    };
    next[field] = field === "notes" ? String(value || "") : toNumber(value);
    importedPricingState.draft.item_overrides = {
      ...(importedPricingState.draft.item_overrides || {}),
      [itemId]: next,
    };
    renderImportedPricingDesk();
  }

  function resetImportedSupplierDefaults(supplierKey) {
    const next = { ...(importedPricingState.draft.supplier_defaults || {}) };
    delete next[supplierKey];
    importedPricingState.draft.supplier_defaults = next;
    renderImportedPricingDesk();
  }

  function resetImportedItemOverride(itemId) {
    const next = { ...(importedPricingState.draft.item_overrides || {}) };
    delete next[itemId];
    importedPricingState.draft.item_overrides = next;
    renderImportedPricingDesk();
  }

  function activeAdminPublicUrl() {
    return state.marketplaceApiPayload?.public_admin_url || data.public_runtime?.public_url || "";
  }

  function activeProductPublicUrl() {
    const explicit = state.marketplaceApiPayload?.public_product_url || "";
    if (explicit) {
      return explicit;
    }

    const adminUrl = activeAdminPublicUrl();
    return adminUrl ? `${adminUrl.replace(/\/$/, "")}/product` : "";
  }

  function activeLocalProductUrl() {
    return `${window.location.origin.replace(/\/$/, "")}/product/`;
  }

  function activeAdminHost() {
    const candidate = activeAdminPublicUrl() || window.location.origin;
    try {
      return new URL(candidate);
    } catch (error) {
      return new URL(window.location.origin);
    }
  }

  function isLocalAdminHostname(hostname) {
    return hostname === "localhost" || /^\d{1,3}(?:\.\d{1,3}){3}$/.test(hostname);
  }

  function workspaceByKey(key) {
    return adminWorkspaces().find((workspace) => workspace.key === key) || null;
  }

  function workspaceBySubdomain(subdomain) {
    return adminWorkspaces().find((workspace) => workspace.subdomain === subdomain) || null;
  }

  function workspaceByCostZeroHost(host) {
    return adminWorkspaces().find((workspace) => workspace.costZeroHost === host) || null;
  }

  function publicRootHostFromAdminHost(hostname) {
    const normalized = String(hostname || "").toLowerCase();
    return normalized.startsWith("admin.") ? normalized.slice("admin.".length) : normalized;
  }

  function workspaceHttpsAliasHost(workspace) {
    const adminHost = activeAdminHost().hostname;
    if (workspace.key === "home" || isLocalAdminHostname(adminHost)) {
      return adminHost;
    }
    const publicRootHost = publicRootHostFromAdminHost(adminHost);
    if (workspace.costZeroHost) {
      return `${workspace.costZeroHost}.${publicRootHost}`;
    }
    return `${workspace.subdomain}-admin.${publicRootHost}`;
  }

  function workspaceHostLabel(workspace) {
    const host = activeAdminHost().hostname;
    if (workspace.key === "home") {
      return host;
    }
    if (isLocalAdminHostname(host)) {
      return `local:${workspace.key}`;
    }
    return workspaceHttpsAliasHost(workspace);
  }

  function workspaceHref(workspace) {
    const adminHost = activeAdminHost();
    if (workspace.key === "home") {
      return `${adminHost.protocol}//${adminHost.host}/`;
    }

    if (!isLocalAdminHostname(adminHost.hostname) && adminHost.hostname.includes(".")) {
      return `${adminHost.protocol}//${workspaceHttpsAliasHost(workspace)}/?workspace=${workspace.key}#${workspace.sectionId}`;
    }

    return `${window.location.origin.replace(/\/$/, "")}/workspace/${workspace.key}/#${workspace.sectionId}`;
  }

  function workspaceMirrorHref(workspace) {
    return `?workspace=${workspace.key}#${workspace.sectionId}`;
  }

  function activeWorkspaceKey() {
    const params = new URLSearchParams(window.location.search);
    const explicit = String(params.get("workspace") || "").trim().toLowerCase();
    if (explicit && workspaceByKey(explicit)) {
      return explicit;
    }

    const pathname = window.location.pathname.replace(/\/+$/, "");
    const workspacePathMatch = pathname.match(/\/workspace\/([^/]+)$/i);
    if (workspacePathMatch) {
      const pathKey = decodeURIComponent(workspacePathMatch[1]).trim().toLowerCase();
      if (workspaceByKey(pathKey)) {
        return pathKey;
      }
    }

    const adminHost = activeAdminHost().hostname.toLowerCase();
    const currentHost = window.location.hostname.toLowerCase();
    if (currentHost === adminHost || currentHost === "localhost" || currentHost === "127.0.0.1") {
      return PRIMARY_WORKSPACE_KEY;
    }

    if (currentHost.endsWith(`.${adminHost}`)) {
      const prefix = currentHost.slice(0, -1 * (`.${adminHost}`.length));
      const hostWorkspace = workspaceBySubdomain(prefix);
      if (hostWorkspace) {
        return hostWorkspace.key;
      }
    }

    const publicRootHost = publicRootHostFromAdminHost(adminHost);
    if (currentHost.endsWith(`.${publicRootHost}`)) {
      const prefix = currentHost.slice(0, -1 * (`.${publicRootHost}`.length));
      const hostWorkspace = workspaceByCostZeroHost(prefix);
      if (hostWorkspace) {
        return hostWorkspace.key;
      }
    }

    const costZeroSuffix = `-admin.${publicRootHost}`;
    if (currentHost.endsWith(costZeroSuffix)) {
      const prefix = currentHost.slice(0, -1 * costZeroSuffix.length);
      const hostWorkspace = workspaceBySubdomain(prefix);
      if (hostWorkspace) {
        return hostWorkspace.key;
      }
    }

      return PRIMARY_WORKSPACE_KEY;
  }

  function workspaceDescriptor(workspace, config, pendingReview) {
    const marketplaceCount = config.filter((provider) => provider.providerRole === "marketplace_price" && provider.enabled).length;
    const supplierCount = config.filter((provider) => provider.providerRole === "supplier_api" && provider.enabled).length;
    const sandboxReady = config.every((provider) => provider.sandboxEnabled !== false);
    const productionReady = config.every((provider) => provider.productionEnabled !== false);

    switch (workspace.key) {
      case "home":
        return { label: "nucleo admin", variant: "pill-accent", detail: "admin.brasildesconto.com.br" };
      case "stock":
        return {
          label: importedPricingState.payload?.items_total ? "catalogo online" : "catalogo local",
          variant: importedPricingState.payload?.items_total ? "pill-accent" : "pill-navy",
          detail: importedPricingState.payload?.items_total ? `${formatCount(importedPricingState.payload.items_total)} itens` : "aguardando sync",
        };
      case "dropshipping":
        return {
          label: importedPricingState.payload?.items_total ? `${formatCount(importedPricingState.payload.items_total)} itens` : "pendente",
          variant: importedPricingState.payload?.items_total ? "pill-accent" : "pill-warn",
          detail: `${formatCount(supplierCount)} fornecedores API`,
        };
      case "marketplace":
        return {
          label: `${formatCount(marketplaceCount)} conectores`,
          variant: marketplaceCount ? "pill-accent" : "pill-warn",
          detail: "marketplaces e sellers",
        };
      case "review":
        return {
          label: pendingReview ? `${formatCount(pendingReview)} em fila` : "sem fila",
          variant: pendingReview ? "pill-danger" : "pill-accent",
          detail: "nao publicados e revisao",
        };
      case "finance":
        return { label: "operacional", variant: "pill-navy", detail: "margem e receita" };
      case "merchants":
        return { label: "workspace", variant: "pill", detail: "sellers e parceiros" };
      case "users":
        return { label: "workspace", variant: "pill", detail: "usuarios e acesso" };
      case "checkout":
        return {
          label: checkoutHealthState.payload?.checkout_ready ? "checkout pronto" : "checkout pendente",
          variant: checkoutHealthState.payload?.checkout_ready ? "pill-accent" : "pill-warn",
          detail: checkoutHealthState.payload?.preferred_environment || "unconfigured",
        };
      case "sandbox":
        return {
          label: sandboxReady && productionReady ? "sandbox + prod" : "ajustar flags",
          variant: sandboxReady && productionReady ? "pill-accent" : "pill-warn",
          detail: sandboxReady ? "flags paralelas ligadas" : "sandbox incompleto",
        };
      default:
        return { label: "workspace", variant: "pill", detail: "painel operacional" };
    }
  }

  function renderWorkspaceFocusBanner(config, pendingReview) {
    if (!elements.workspaceFocusBanner) {
      return;
    }

    const workspace = workspaceByKey(activeWorkspaceKey());
    if (!workspace || workspace.key === "home") {
      elements.workspaceFocusBanner.hidden = true;
      elements.workspaceFocusBanner.innerHTML = "";
      return;
    }

    const descriptor = workspaceDescriptor(workspace, config, pendingReview);
    elements.workspaceFocusBanner.hidden = false;
    elements.workspaceFocusBanner.innerHTML = `
      <div class="workspace-focus-head">
        <div>
          <p class="panel-kicker">Workspace ativo</p>
          <h3>${escapeHtml(workspace.title)}</h3>
          <p class="muted-copy">${escapeHtml(workspace.copy)}</p>
        </div>
        ${rowPill(descriptor.label, descriptor.variant)}
      </div>
      <div class="workspace-focus-links">
        ${rowPill(workspaceHostLabel(workspace), "pill-navy")}
        ${rowPill(descriptor.detail, "pill")}
      </div>
      <div class="link-row">
        <a href="${escapeHtml(workspaceHref(workspace))}">Abrir workspace</a>
        <a href="${escapeHtml(workspaceMirrorHref(workspace))}">Abrir dentro do painel</a>
      </div>
    `;
  }

  function renderWorkspaceRegistry(config, pendingReview) {
    if (!elements.adminWorkspaceRegistry) {
      return;
    }

    elements.adminWorkspaceRegistry.innerHTML = STATIC_ADMIN_WORKSPACES.map((workspace) => {
      const descriptor = workspaceDescriptor(workspace, config, pendingReview);
      return `
        <article class="workspace-registry-card">
          <div class="module-row-top">
            <div>
              <h3>${escapeHtml(workspace.title)}</h3>
              <p class="muted-copy">${escapeHtml(workspace.copy)}</p>
            </div>
            ${rowPill(descriptor.label, descriptor.variant)}
          </div>
          <div class="workspace-registry-meta">
            ${rowPill(workspaceHostLabel(workspace), "pill-navy")}
            ${rowPill(descriptor.detail, "pill")}
          </div>
          <code>${escapeHtml(workspaceHref(workspace))}</code>
          <div class="link-row">
            <a href="${escapeHtml(workspaceHref(workspace))}">Abrir subdominio</a>
            <a href="${escapeHtml(workspaceMirrorHref(workspace))}">Espelho no painel</a>
          </div>
        </article>
      `;
    }).join("");
  }

  function renderModuleWorkspaceDirectory() {
    if (!elements.moduleWorkspaceGrid || !elements.moduleWorkspaceSummary) {
      return;
    }

    elements.moduleWorkspaceSummary.innerHTML = [
      summaryTileMarkup("Workspaces de modulo", formatCount(DYNAMIC_MODULE_WORKSPACES.length), "um workspace dedicado por modulo"),
      summaryTileMarkup("Modo", "producao", "shell e navegação preparados para ambiente real"),
      summaryTileMarkup("Docs rastreados", formatCount(allModules.filter((module) => module.paths.readme && module.paths.status && module.paths.contract).length), "readme, status e contract por modulo"),
      summaryTileMarkup("Hibridos", formatCount(allModules.filter((module) => module.data_home === "postgres_mongo").length), "postgres + mongo no mesmo painel"),
    ].join("");

    elements.moduleWorkspaceGrid.innerHTML = DYNAMIC_MODULE_WORKSPACES.map((workspace) => {
      const module = allModules.find((item) => item.code === workspace.moduleCode);
      if (!module) {
        return "";
      }
      const readiness = moduleReadiness(module);
      const businessSnapshot = catalogModuleSnapshot(module.code);
      return `
        <article class="module-workspace-card">
          <div class="module-row-top">
            <div>
              <h3>${escapeHtml(workspace.title)}</h3>
              <p class="muted-copy">${escapeHtml(workspace.copy)}</p>
            </div>
            ${rowPill(module.status_label, statusVariant(module.automation_status))}
          </div>
          <div class="workspace-registry-meta">
            ${rowPill(workspaceHostLabel(workspace), "pill-navy")}
            ${rowPill(module.tier, "pill-accent")}
            ${rowPill(module.domain, "pill")}
          </div>
          <div class="summary-grid compact-summary-grid">
            ${summaryTileMarkup("Prontidao", formatPercent(readiness), `${formatCount(module.checklist.pending)} pendencias`)}
            ${summaryTileMarkup("Data home", module.data_home, module.code)}
            ${summaryTileMarkup("Integracoes", formatCount(module.integrates_with.length), "conexoes declaradas")}
            ${summaryTileMarkup("Valor", businessSnapshot ? formatMoney(businessSnapshot.inventory_value_brl) : "n/d", businessSnapshot ? "snapshot comercial" : "sem resumo comercial")}
          </div>
          <code>${escapeHtml(workspaceHref(workspace))}</code>
          <div class="link-row">
            <a href="${escapeHtml(workspaceHref(workspace))}">Abrir subdominio</a>
            <a href="${escapeHtml(workspaceMirrorHref(workspace))}">Espelho no painel</a>
          </div>
        </article>
      `;
    }).join("");
  }

  function scheduleWorkspaceFocus() {
    const workspace = workspaceByKey(activeWorkspaceKey());
    if (!workspace || workspace.key === "home" || workspaceFocusState.appliedKey === workspace.key) {
      return;
    }

    const target = document.getElementById(workspace.sectionId);
    if (!target) {
      return;
    }

    workspaceFocusState.appliedKey = workspace.key;
    window.setTimeout(() => {
      target.scrollIntoView({ behavior: "smooth", block: "start" });
    }, 90);
  }

  function integrationWebhookPath(providerKey) {
    if (providerKey === "mercado_livre") {
      return "/integrations/mercadolivre/notifications";
    }
    return `/integrations/${providerKey}/notifications`;
  }

  function integrationRedirectUri(providerKey) {
    const adminUrl = activeAdminPublicUrl() || "https://admin.brasildesconto.com.br";

    if (providerKey === "mercado_livre") {
      return adminUrl;
    }

    if (providerKey === "amazon" || providerKey === "cjdropshipping") {
      return "";
    }

    return `${adminUrl}/integrations/${providerKey}/callback`;
  }

  function renderAccessLinks() {
    if (!elements.adminAccessLinks) {
      return;
    }

    const runtime = data.public_runtime || {};
    const publicAdminUrl = activeAdminPublicUrl();
    const publicProductUrl = activeProductPublicUrl();
    elements.adminAccessLinks.innerHTML = [
      accessCardMarkup("Portal oficial", "https://brasildesconto.com.br/"),
      accessCardMarkup("Painel admin", publicAdminUrl || runtime.public_url || "", (publicAdminUrl || runtime.public_url) ? "pill-accent" : "pill-warn"),
      accessCardMarkup("ERP lojista", "https://erp-lojista.brasildesconto.com.br/"),
      accessCardMarkup("Login lojista", "https://lojista.brasildesconto.com.br/"),
      accessCardMarkup("PDV lojista", "https://pdv-lojista.brasildesconto.com.br/"),
      accessCardMarkup("Loja publica", publicProductUrl || "https://brasildesconto.com.br/product/", publicProductUrl ? "pill-accent" : "pill-warn"),
    ].join("");
  }

  function renderAdminLaunchpad() {
    if (!elements.adminLaunchpadSummary || !elements.adminLaunchpadGrid) {
      return;
    }

    elements.adminLaunchpadSummary.innerHTML = "";
    elements.adminLaunchpadSummary.hidden = true;
    if (elements.workspaceFocusBanner) {
      elements.workspaceFocusBanner.hidden = true;
      elements.workspaceFocusBanner.innerHTML = "";
    }
    if (elements.adminWorkspaceRegistry) {
      elements.adminWorkspaceRegistry.hidden = true;
      elements.adminWorkspaceRegistry.innerHTML = "";
    }
    renderModuleWorkspaceDirectory();

    const cards = adminWorkspaces().filter((workspace) => workspace.key !== "home");

    elements.adminLaunchpadGrid.innerHTML = cards
      .map(
        (workspace) => `
          <a class="launchpad-button" href="${escapeHtml(workspaceHref(workspace))}" aria-label="Abrir ${escapeHtml(workspace.title)}">
            <span>${escapeHtml(workspace.title)}</span>
            <small>${escapeHtml(workspaceHostLabel(workspace))}</small>
          </a>
        `,
      )
      .join("");
  }

  function stitchTemplatePath(key, fileName = "code.html") {
    return `/stitch/20260513_valley_erp/stitch_valley_erp/${encodeURIComponent(key)}/${fileName}`;
  }

  function stitchP0RuntimeSummary() {
    const release = releaseSummaryOrFallback();
    const pricing = importedPricingState.payload || {};
    const publication = pricing.publication_summary || {};
    const suppliers = Array.isArray(pricing.supplier_summary) ? pricing.supplier_summary : [];
    const integrations = Array.isArray(state.marketplaceApiConfig) ? state.marketplaceApiConfig : MARKETPLACE_API_PROVIDERS;
    const activeIntegrations = integrations.filter((item) => item.enabled !== false).length;
    const checkout = checkoutHealthState.payload || {};
    const catalogModulesTotal = catalogModules().length || allModules.length;

    return {
      templatesTotal: 131,
      p0Total: 21,
      webConverted: STITCH_P0_WEB_SCREENS.length,
      modulesTotal: release.modules_total || allModules.length,
      modulesCompleted: release.modules_completed || allModules.filter((module) => (module.checklist?.pending || 0) === 0).length,
      catalogModulesTotal,
      itemsTotal: Number(pricing.items_total || 0),
      approvedTotal: Number(publication.approved_total || 0),
      reviewTotal: Number(publication.review_total || 0),
      blockedTotal: Number(publication.do_not_publish_total || 0),
      suppliersTotal: suppliers.length,
      activeIntegrations,
      checkoutReady: Boolean(checkout.checkout_ready),
      adminUrl: activeAdminPublicUrl() || "https://admin.brasildesconto.com.br/",
      productUrl: activeProductPublicUrl() || "https://brasildesconto.com.br/product/",
      galleryUrl: "/stitch/20260513_valley_erp/",
    };
  }

  function stitchOperationalRows(summary) {
    return [
      ["Admin Central 1", "Home executiva", `${formatCount(summary.modulesCompleted)}/${formatCount(summary.modulesTotal)} módulos`, "Aberto no painel"],
      ["Admin Central 2", "Desempenho", `${formatCount(summary.catalogModulesTotal)} módulos no catálogo`, "Pronto para revisão"],
      ["ERP do Lojista", "Marketplace", `${formatCount(summary.itemsTotal)} itens`, `${formatCount(summary.reviewTotal)} em revisão`],
      ["Checkout", "Jornada de compra", summary.checkoutReady ? "Operacional" : "Pendente", summary.checkoutReady ? "Liberado" : "Revisar credenciais"],
      ["Integrações", "Fornecedores e canais", `${formatCount(summary.activeIntegrations)}/${formatCount(MARKETPLACE_API_PROVIDERS.length)} ativos`, `${formatCount(summary.suppliersTotal)} fornecedores`],
    ];
  }

  function renderStitchP0Execution() {
    if (!elements.stitchP0ExecutionRoot) {
      return;
    }

    const summary = stitchP0RuntimeSummary();
    const rows = stitchOperationalRows(summary);

    elements.stitchP0ExecutionRoot.innerHTML = `
      <section class="stitch-execution-shell">
        <div class="stitch-execution-topbar">
          <div>
            <span class="small-label">Release web</span>
            <strong>Onda 1 P0 ativa</strong>
            <p class="muted-copy">A galeria Stitch virou uma camada operacional com telas reais, dados do runtime e ações executáveis.</p>
          </div>
          <div class="stitch-execution-actions">
            <button type="button" class="secondary-button" data-stitch-action="sync-data">Sincronizar dados</button>
            <button type="button" class="secondary-button" data-stitch-action="copy-release">Exportar resumo</button>
            <button type="button" class="secondary-button" data-stitch-action="open-gallery">Abrir galeria</button>
          </div>
        </div>
        <div class="stitch-execution-hero">
          <div>
            <span class="small-label">Admin Central 1/2</span>
            <h3>Controle executivo conectado ao painel Valley</h3>
            <p>
              KPIs, workspaces, checkout, catálogo, integrações e ERP lojista agora estão organizados como uma tela P0 executável,
              mantendo os templates Stitch como referência visual auditável.
            </p>
            <div class="pill-row">
              ${rowPill(`${formatCount(summary.templatesTotal)} templates publicados`, "pill-navy")}
              ${rowPill(`${formatCount(summary.p0Total)} P0`, "pill-accent")}
              ${rowPill(`${formatCount(summary.webConverted)} web executáveis`, "pill-warn")}
            </div>
          </div>
          <div class="stitch-url-stack">
            <article>
              <span class="small-label">Admin</span>
              <strong>${escapeHtml(summary.adminUrl)}</strong>
            </article>
            <article>
              <span class="small-label">Usuário</span>
              <strong>${escapeHtml(summary.productUrl)}</strong>
            </article>
            <article>
              <span class="small-label">Stitch</span>
              <strong>${escapeHtml(summary.galleryUrl)}</strong>
            </article>
          </div>
        </div>
        <div class="stitch-kpi-grid">
          ${summaryTileMarkup("Templates", formatCount(summary.templatesTotal), `${formatCount(summary.p0Total)} P0 publicados`)}
          ${summaryTileMarkup("Módulos", `${formatCount(summary.modulesCompleted)}/${formatCount(summary.modulesTotal)}`, "release operacional")}
          ${summaryTileMarkup("Catálogo", formatCount(summary.itemsTotal), `${formatCount(summary.approvedTotal)} aprovados`)}
          ${summaryTileMarkup("Checkout", summary.checkoutReady ? "Pronto" : "Pendente", "gate de compra")}
        </div>
        <section class="stitch-screen-grid">
          ${STITCH_P0_WEB_SCREENS.map((screen) => `
            <article class="stitch-screen-card">
              <img src="${escapeHtml(stitchTemplatePath(screen.key, "screen.png"))}" alt="${escapeHtml(screen.title)}" loading="lazy" />
              <div>
                <span class="small-label">${escapeHtml(screen.target)}</span>
                <strong>${escapeHtml(screen.title)}</strong>
                <p class="muted-copy">${escapeHtml(screen.detail)}</p>
              </div>
              <div class="stitch-screen-actions">
                <button type="button" class="secondary-button" data-stitch-action="${escapeHtml(screen.action)}">Executar tela</button>
                <a href="${escapeHtml(stitchTemplatePath(screen.key))}" target="_blank" rel="noopener">Referência</a>
              </div>
            </article>
          `).join("")}
        </section>
        <section class="stitch-command-grid">
          <article class="stitch-command-card">
            <span class="small-label">Operação</span>
            <strong>Admin Central</strong>
            <p class="muted-copy">Abre a home operacional, atualiza os dados e mantém os workspaces em abas reais.</p>
            <div class="stitch-command-buttons">
              <button type="button" class="secondary-button" data-stitch-action="open-admin-central">Abrir home</button>
              <button type="button" class="secondary-button" data-stitch-action="open-workspaces">Workspaces</button>
            </div>
          </article>
          <article class="stitch-command-card">
            <span class="small-label">Lojista</span>
            <strong>ERP marketplace</strong>
            <p class="muted-copy">Ativa a aba do ERP, seus módulos e as rotinas de salvar, sync, relatório e export.</p>
            <div class="stitch-command-buttons">
              <button type="button" class="secondary-button" data-stitch-action="open-erp">Abrir ERP</button>
              <button type="button" class="secondary-button" data-stitch-action="open-pricing">Produtos e SKU</button>
            </div>
          </article>
          <article class="stitch-command-card">
            <span class="small-label">Conexões</span>
            <strong>Checkout e integrações</strong>
            <p class="muted-copy">Leva direto para checkout, marketplaces, fornecedores e status de publicação.</p>
            <div class="stitch-command-buttons">
              <button type="button" class="secondary-button" data-stitch-action="open-checkout">Checkout</button>
              <button type="button" class="secondary-button" data-stitch-action="open-integrations">Integrações</button>
            </div>
          </article>
        </section>
        <div class="erp-table-wrap">
          <table class="erp-data-table">
            <thead>
              <tr>
                <th>Tela</th>
                <th>Rotina</th>
                <th>Métrica</th>
                <th>Status</th>
              </tr>
            </thead>
            <tbody>
              ${rows.map((row) => `
                <tr>
                  <td>${escapeHtml(row[0])}</td>
                  <td>${escapeHtml(row[1])}</td>
                  <td>${escapeHtml(row[2])}</td>
                  <td>${escapeHtml(row[3])}</td>
                </tr>
              `).join("")}
            </tbody>
          </table>
        </div>
      </section>
    `;
  }

  function openAdminPaneSection(pane, sectionId) {
    setActiveAdminSurfaceTab(pane, { preserveScroll: true });
    window.setTimeout(() => {
      document.getElementById(sectionId)?.scrollIntoView({ behavior: "smooth", block: "start" });
    }, 20);
  }

  function runStitchP0Action(action) {
    switch (action) {
      case "sync-data":
        loadCatalogSummary();
        loadModuleRuntimeSnapshots();
        loadCheckoutHealth();
        loadMarketplaceApiConfig();
        loadImportedPricing();
        announce("Dados da Onda 1 Stitch atualizados.");
        return;
      case "copy-release":
        copyText(
          JSON.stringify(
            {
              generated_at: new Date().toISOString(),
              summary: stitchP0RuntimeSummary(),
              screens: STITCH_P0_WEB_SCREENS,
            },
            null,
            2,
          ),
          "Resumo da Onda 1 Stitch",
        );
        return;
      case "open-gallery":
        window.open("/stitch/20260513_valley_erp/", "_blank", "noopener");
        announce("Galeria Stitch aberta.");
        return;
      case "open-admin-central":
        openAdminPaneSection("overview", "adminLaunchpadSection");
        announce("Admin Central 1 aberto.");
        return;
      case "open-executive":
        openAdminPaneSection("performance", "performanceDashboard");
        announce("Admin Central 2 aberto.");
        return;
      case "open-erp":
        openAdminPaneSection("merchant", "merchantErpSection");
        announce("ERP do lojista aberto.");
        return;
      case "open-pricing":
        openAdminPaneSection("catalog", "importedPricingSection");
        announce("Produtos e SKU abertos.");
        return;
      case "open-integrations":
        openAdminPaneSection("integrations", "settingsSection");
        announce("Integrações abertas.");
        return;
      case "open-checkout":
        openAdminPaneSection("overview", "checkoutHealthPanel");
        announce("Checkout aberto.");
        return;
      case "open-workspaces":
        openAdminPaneSection("modules", "moduleWorkspaceDirectory");
        announce("Diretório de workspaces aberto.");
        return;
      default:
        announce("Ação Stitch indisponível.");
    }
  }

  function merchantErpWorkspaces() {
    return adminWorkspaces().filter((workspace) => workspace.workspaceKind === "merchant_erp");
  }

  function merchantErpBlueprint(key) {
    const blueprints = {
      "merchant-login": {
        code: "LOGIN",
        title: "Login e acesso",
        accent: "#2563eb",
        icon: "ID",
        focus: "Sessao, MFA, permissao e entrada segura do lojista.",
        queue: ["Sessao ativa", "MFA pendente", "Termo comercial", "Perfil KYB"],
        table: ["Identidade", "Dispositivo", "Ultimo acesso", "Status"],
      },
      "merchant-erp": {
        code: "ERP",
        title: "Torre de controle",
        accent: "#16a34a",
        icon: "ERP",
        focus: "Visao geral da empresa, marketplace, estoque, financeiro e equipe.",
        queue: ["Pedidos novos", "Produtos em revisao", "Fechamento aberto", "Integracoes ativas"],
        table: ["Rotina", "Responsavel", "SLA", "Status"],
      },
      "merchant-pdv": {
        code: "PDV",
        title: "PDV e caixa",
        accent: "#0ea5e9",
        icon: "PDV",
        focus: "Venda presencial, sangria, fechamento de caixa e conciliacao.",
        queue: ["Caixa aberto", "Pix pendente", "Cartao conciliado", "Sangria auditada"],
        table: ["Terminal", "Turno", "Vendas", "Diferenca"],
      },
      "merchant-warehouse": {
        code: "WMS",
        title: "Armazem",
        accent: "#0891b2",
        icon: "ARM",
        focus: "Recebimento, picking, packing, inventario e ruptura por SKU.",
        queue: ["Receber lote", "Separar pedido", "Contagem cega", "Transferencia"],
        table: ["Endereco", "SKU", "Saldo", "Acao"],
      },
      "merchant-metrics": {
        code: "BI",
        title: "Metricas",
        accent: "#7c3aed",
        icon: "BI",
        focus: "Margem, conversao, SLA, ticket medio e desempenho por canal.",
        queue: ["Meta diaria", "Conversao", "SLA", "Margem"],
        table: ["Indicador", "Hoje", "7 dias", "Tendencia"],
      },
      "merchant-campaigns": {
        code: "ADS",
        title: "Campanhas",
        accent: "#db2777",
        icon: "ADS",
        focus: "Promocoes, cupons, anuncios, calendario e retorno por campanha.",
        queue: ["Cupom ativo", "Anuncio", "Calendario", "Budget"],
        table: ["Campanha", "Canal", "Budget", "ROAS"],
      },
      "merchant-reports": {
        code: "REP",
        title: "Relatorios",
        accent: "#475569",
        icon: "REL",
        focus: "Exportacoes, DRE operacional, ranking de produtos e fechamento.",
        queue: ["DRE", "CSV pedidos", "Ranking SKU", "Fiscal"],
        table: ["Relatorio", "Periodo", "Arquivo", "Status"],
      },
      "merchant-finance": {
        code: "FIN",
        title: "Financeiro",
        accent: "#15803d",
        icon: "R$",
        focus: "Recebiveis, repasses, taxas, fees, chargeback e saldo.",
        queue: ["Recebiveis", "Taxas", "Repasses", "Chargeback"],
        table: ["Periodo", "Bruto", "Taxas", "Liquido"],
      },
      "merchant-registration": {
        code: "CAD",
        title: "Cadastro",
        accent: "#0369a1",
        icon: "CAD",
        focus: "Lojas, filiais, usuarios, documentos e dados comerciais.",
        queue: ["CNPJ", "Filial", "Documento", "Contato"],
        table: ["Registro", "Campo", "Validade", "Status"],
      },
      "merchant-profile": {
        code: "PER",
        title: "Perfil",
        accent: "#4338ca",
        icon: "PER",
        focus: "Identidade visual, politicas, suporte, SLA e reputacao.",
        queue: ["Logo", "Politica", "SLA", "Reputacao"],
        table: ["Area", "Configuracao", "Exibicao", "Status"],
      },
      "merchant-accounting": {
        code: "CTB",
        title: "Contabil",
        accent: "#854d0e",
        icon: "CTB",
        focus: "Lancamentos, centros de custo, conciliacao e livros auxiliares.",
        queue: ["Centro custo", "Lancamento", "Conciliacao", "Livro"],
        table: ["Conta", "Debito", "Credito", "Competencia"],
      },
      "merchant-integrations": {
        code: "API",
        title: "Integracoes",
        accent: "#0f766e",
        icon: "API",
        focus: "Marketplaces, webhooks, ERPs externos, tokens e scopes.",
        queue: ["Webhook", "Token", "Seller ID", "Sync"],
        table: ["Provider", "Escopo", "Ultimo sync", "Status"],
      },
      "merchant-orders": {
        code: "PED",
        title: "Pedidos",
        accent: "#f97316",
        icon: "PED",
        focus: "Pedido, separacao, cancelamento, devolucao e pos-venda.",
        queue: ["Novo", "Separando", "Cancelamento", "Devolucao"],
        table: ["Pedido", "Cliente", "Etapa", "SLA"],
      },
      "merchant-products": {
        code: "SKU",
        title: "Produtos",
        accent: "#22c55e",
        icon: "SKU",
        focus: "Catalogo, fotos, SKU, variacoes, precificacao e publicacao.",
        queue: ["Foto", "Preco", "Estoque", "Publicacao"],
        table: ["SKU", "Titulo", "Preco", "Status"],
      },
      "merchant-customers": {
        code: "CRM",
        title: "Clientes",
        accent: "#9333ea",
        icon: "CRM",
        focus: "Segmentacao, historico, recompra, atendimento e retencao.",
        queue: ["Novo lead", "Retencao", "Ticket", "SAC"],
        table: ["Cliente", "Segmento", "Ultima compra", "Acao"],
      },
      "merchant-tax": {
        code: "FIS",
        title: "Fiscal",
        accent: "#b45309",
        icon: "FIS",
        focus: "Regras fiscais, documentos, impostos e auditoria por venda.",
        queue: ["NFe", "Imposto", "CFOP", "Auditoria"],
        table: ["Documento", "Chave", "Valor", "Status"],
      },
      "merchant-inventory": {
        code: "EST",
        title: "Estoque",
        accent: "#0284c7",
        icon: "EST",
        focus: "Saldo por SKU, reserva, reposicao, minimo e transferencia.",
        queue: ["Ruptura", "Reserva", "Reposicao", "Transferencia"],
        table: ["SKU", "Disponivel", "Reservado", "Minimo"],
      },
      "merchant-stock-count": {
        code: "INV",
        title: "Inventario de Estoque",
        accent: "#0f766e",
        icon: "INV",
        focus: "Leitura por codigo de barras ou QR Code, contagem fisica, volumes, fracionamento, avaria, alta e baixa.",
        queue: ["Leitura", "Divergencia", "Avaria", "Ajuste"],
        table: ["Produto", "Esperado", "Inventariado", "Diferenca"],
      },
      "merchant-logistics": {
        code: "LOG",
        title: "Logistica",
        accent: "#ea580c",
        icon: "LOG",
        focus: "Frete, coleta, entrega, rastreio, SLA e ocorrencias.",
        queue: ["Coleta", "Etiqueta", "Rota", "Ocorrencia"],
        table: ["Envio", "Transportadora", "Prazo", "Status"],
      },
      "merchant-carrier-cross-docking": {
        code: "CD",
        title: "Transportadora e Cross Docking",
        accent: "#f97316",
        icon: "CD",
        focus: "Movimentacao em CD, docas, cross docking, romaneio, rota, motorista e distribuicao final.",
        queue: ["Recebimento", "Doca", "Rota", "Entrega"],
        table: ["Romaneio", "Volume", "Doca", "SLA"],
      },
      "merchant-support": {
        code: "SAC",
        title: "Atendimento",
        accent: "#2563eb",
        icon: "SAC",
        focus: "Tickets, chat, disputa, reembolso e relacionamento.",
        queue: ["Ticket", "Chat", "Disputa", "Reembolso"],
        table: ["Chamado", "Cliente", "Prioridade", "SLA"],
      },
      "merchant-team": {
        code: "EQP",
        title: "Equipe",
        accent: "#4f46e5",
        icon: "EQP",
        focus: "Colaboradores, papeis, produtividade, escala e permissoes.",
        queue: ["Convite", "Papel", "Escala", "Produtividade"],
        table: ["Pessoa", "Papel", "Acesso", "Status"],
      },
      "merchant-security": {
        code: "SEG",
        title: "Seguranca",
        accent: "#dc2626",
        icon: "SEG",
        focus: "MFA, sessoes, trilhas de auditoria, risco e bloqueios.",
        queue: ["MFA", "Sessao", "Alerta", "Auditoria"],
        table: ["Evento", "Ator", "Severidade", "Hora"],
      },
      "merchant-settings": {
        code: "CFG",
        title: "Configuracoes",
        accent: "#334155",
        icon: "CFG",
        focus: "Preferencias, parametros, flags, impostos e regras da loja.",
        queue: ["Flags", "Parametros", "Impostos", "Notificacao"],
        table: ["Chave", "Valor", "Escopo", "Status"],
      },
    };

    return blueprints[key] || blueprints["merchant-erp"];
  }

  function activeMerchantErpWorkspace() {
    const current = activeWorkspace();
    if (current?.workspaceKind === "merchant_erp") {
      return current;
    }

    const saved = state.activeMerchantErpFeature && workspaceByKey(state.activeMerchantErpFeature);
    if (saved?.workspaceKind === "merchant_erp") {
      return saved;
    }

    return workspaceByKey("merchant-erp") || merchantErpWorkspaces()[0] || null;
  }

  function setActiveMerchantErpFeature(key) {
    const workspace = workspaceByKey(key);
    if (!workspace || workspace.workspaceKind !== "merchant_erp") {
      return;
    }
    state.activeMerchantErpFeature = workspace.key;
    persistMerchantErpFeature(workspace.key);
    renderMerchantErp();
    announce(`${workspace.title} aberto no ERP lojista.`);
  }

  function merchantErpRuntimeSummary() {
    const pricing = importedPricingState.payload || {};
    const publication = pricing.publication_summary || {};
    const suppliers = Array.isArray(pricing.supplier_summary) ? pricing.supplier_summary : [];
    const supplierTotal = suppliers.reduce((total, item) => total + Number(item.items_total || 0), 0);
    const revenue = suppliers.reduce((total, item) => total + Number(item.suggested_revenue_value_brl || 0), 0);
    const netRevenue = suppliers.reduce((total, item) => total + Number(item.estimated_net_revenue_value_brl || 0), 0);
    const integrations = Array.isArray(state.marketplaceApiConfig) ? state.marketplaceApiConfig : MARKETPLACE_API_PROVIDERS;
    const activeIntegrations = integrations.filter((item) => item.enabled !== false).length;
    const checkout = checkoutHealthState.payload || {};
    const draft = state.merchantErpDraft || {};

    return {
      itemsTotal: Number(pricing.items_total || supplierTotal || 0),
      approvedTotal: Number(publication.approved_total || 0),
      reviewTotal: Number(publication.review_total || 0),
      blockedTotal: Number(publication.do_not_publish_total || 0),
      suppliersTotal: suppliers.length,
      revenue,
      netRevenue,
      activeIntegrations,
      checkoutReady: Boolean(checkout.checkout_ready),
      checkoutStatus: checkout.checkout_ready ? "checkout pronto" : String(checkout.status || "checkout pendente"),
      lastSavedAt: draft.lastSavedAt || "",
      lastSyncAt: draft.lastSyncAt || "",
      lastReportAt: draft.lastReportAt || "",
    };
  }

  function merchantErpKpis(summary) {
    return [
      { label: "Catalogo", value: formatCount(summary.itemsTotal), meta: `${formatCount(summary.reviewTotal)} em revisao` },
      { label: "Receita potencial", value: formatMoney(summary.revenue), meta: `${formatMoney(summary.netRevenue)} liquido estimado` },
      { label: "Integracoes", value: `${formatCount(summary.activeIntegrations)}/${formatCount(MARKETPLACE_API_PROVIDERS.length)}`, meta: "marketplaces e fornecedores" },
      { label: "Checkout", value: summary.checkoutReady ? "Pronto" : "Pendente", meta: summary.checkoutStatus },
    ];
  }

  function merchantErpRows(feature, summary) {
    const nowLabel = formatTimestamp(new Date().toISOString());
    return [
      [feature.table[0] || "Rotina", feature.queue[0] || "Abertura", summary.checkoutReady ? "OK" : "Atenção", nowLabel],
      [feature.table[1] || "Operacao", feature.queue[1] || "Validação", `${formatCount(summary.activeIntegrations)} conectores`, summary.lastSyncAt ? formatTimestamp(summary.lastSyncAt) : "Aguardando"],
      [feature.table[2] || "Backoffice", feature.queue[2] || "Fila", `${formatCount(summary.reviewTotal)} itens`, summary.lastSavedAt ? formatTimestamp(summary.lastSavedAt) : "Rascunho"],
      [feature.table[3] || "Governanca", feature.queue[3] || "Auditoria", `${formatCount(summary.blockedTotal)} bloqueios`, summary.lastReportAt ? formatTimestamp(summary.lastReportAt) : "Sem export"],
    ];
  }

  function merchantErpFormFields(workspace, feature) {
    const draft = state.merchantErpDraft || {};
    const values = {
      storeName: draft.storeName || "Loja Valley Demo",
      operator: draft.operator || "Operador principal",
      dailyGoal: draft.dailyGoal || "125000",
      stockAlert: draft.stockAlert || "15",
      workspaceCode: feature.code,
      publicHost: workspaceHostLabel(workspace),
    };
    return [
      ["Nome da loja", "storeName", values.storeName],
      ["Operador", "operator", values.operator],
      ["Meta diaria BRL", "dailyGoal", values.dailyGoal],
      ["Alerta de estoque", "stockAlert", values.stockAlert],
      ["Workspace", "workspaceCode", values.workspaceCode, true],
      ["Subdominio", "publicHost", values.publicHost, true],
    ];
  }

  function runMerchantErpAction(action) {
    const now = new Date().toISOString();
    if (action === "save") {
      state.merchantErpDraft = { ...(state.merchantErpDraft || {}), lastSavedAt: now };
      persistMerchantErpDraft();
      renderMerchantErp();
      announce("Configuração do ERP lojista salva localmente.");
      return;
    }
    if (action === "sync") {
      state.merchantErpDraft = { ...(state.merchantErpDraft || {}), lastSyncAt: now, syncStatus: "queued" };
      persistMerchantErpDraft();
      renderMerchantErp();
      announce("Sincronização do ERP lojista enfileirada no painel.");
      return;
    }
    if (action === "report") {
      state.merchantErpDraft = { ...(state.merchantErpDraft || {}), lastReportAt: now, reportStatus: "READY" };
      persistMerchantErpDraft();
      renderMerchantErp();
      announce("Relatório executivo do lojista gerado no estado local.");
      return;
    }
    if (action === "copy") {
      copyText(JSON.stringify(state.merchantErpDraft || {}, null, 2), "Resumo do ERP lojista");
      return;
    }
  }

  function updateMerchantErpDraftField(field, value) {
    state.merchantErpDraft = {
      ...(state.merchantErpDraft || {}),
      [field]: value,
    };
    persistMerchantErpDraft();
  }

  function renderMerchantErp() {
    if (!elements.merchantErpRoot) {
      return;
    }

    const workspaces = merchantErpWorkspaces();
    const activeWorkspace = activeMerchantErpWorkspace();
    if (!activeWorkspace) {
      elements.merchantErpRoot.innerHTML = `<div class="empty-state">ERP lojista sem workspaces configurados.</div>`;
      return;
    }

    const feature = merchantErpBlueprint(activeWorkspace.key);
    const summary = merchantErpRuntimeSummary();
    const kpis = merchantErpKpis(summary);
    const rows = merchantErpRows(feature, summary);
    const formFields = merchantErpFormFields(activeWorkspace, feature);
    const activeHost = workspaceHostLabel(activeWorkspace);
    const chartHeights = [44, 62, 54, 78, 68, 86];

    elements.merchantErpRoot.innerHTML = `
      <section class="erp-workspace-shell merchant-erp-workspace" style="--erp-accent:${escapeHtml(feature.accent)}">
        <div class="erp-main merchant-erp-main">
          <div class="erp-top-navigation">
            <div class="erp-brand">
              <div class="erp-brand-badge">${escapeHtml(feature.icon)}</div>
              <div>
                <strong>Valley ERP</strong>
                <span>${escapeHtml(activeHost)}</span>
              </div>
            </div>
            <nav class="erp-module-nav" aria-label="Módulos do ERP lojista">
              ${workspaces.map((workspace) => {
                const item = merchantErpBlueprint(workspace.key);
                return `<button type="button" class="erp-nav-item ${workspace.key === activeWorkspace.key ? "is-active" : ""}" data-merchant-feature="${escapeHtml(workspace.key)}">${escapeHtml(item.code)} · ${escapeHtml(workspace.title)}</button>`;
              }).join("")}
            </nav>
          </div>
          <div class="erp-toolbar">
            <div>
              <span class="small-label">Painel operacional do lojista</span>
              <h3>${escapeHtml(feature.title)}</h3>
            </div>
            <div class="pill-row">
              ${rowPill("produção", "pill-accent")}
              ${rowPill("marketplace", "pill-navy")}
              ${rowPill(summary.checkoutReady ? "checkout ok" : "checkout atenção", summary.checkoutReady ? "pill-accent" : "pill-warn")}
            </div>
          </div>
          <div class="erp-status-ribbon">
            <span>Subdominio oficial</span>
            <strong>${escapeHtml(activeHost)}</strong>
            <span>${escapeHtml(feature.focus)}</span>
          </div>
          <div class="merchant-erp-app-grid">
            ${workspaces.slice(0, 12).map((workspace) => {
              const item = merchantErpBlueprint(workspace.key);
              return `
                <a class="merchant-erp-app" href="${escapeHtml(workspaceHref(workspace))}" data-merchant-feature-link="${escapeHtml(workspace.key)}">
                  <span style="background:${escapeHtml(item.accent)}">${escapeHtml(item.icon)}</span>
                  <strong>${escapeHtml(workspace.title)}</strong>
                  <small>${escapeHtml(item.code)}</small>
                </a>
              `;
            }).join("")}
          </div>
          <div class="erp-kpi-grid">
            ${kpis.map((tile) => `
              <article class="erp-kpi-card">
                <span class="small-label">${escapeHtml(tile.label)}</span>
                <strong>${escapeHtml(tile.value)}</strong>
                <span class="muted-copy">${escapeHtml(tile.meta)}</span>
              </article>
            `).join("")}
          </div>
          <div class="erp-ops-grid">
            <section class="erp-canvas-card">
              <div class="erp-card-head">
                <div>
                  <span class="small-label">Cadastro e rotina</span>
                  <strong>Ficha operacional da empresa</strong>
                </div>
                ${rowPill(summary.lastSavedAt ? `Salvo ${formatTimestamp(summary.lastSavedAt)}` : "rascunho", summary.lastSavedAt ? "pill-accent" : "pill-warn")}
              </div>
              <div class="erp-classic-form">
                <div class="erp-form-grid">
                  ${formFields.map(([label, field, value, readonly]) => `
                    <label class="erp-field">
                      <span>${escapeHtml(label)}</span>
                      <input data-merchant-field="${escapeHtml(field)}" type="text" value="${escapeHtml(value)}" ${readonly ? "readonly" : ""} />
                    </label>
                  `).join("")}
                </div>
                <div class="erp-form-actions">
                  <button type="button" class="secondary-button" data-merchant-action="save">Salvar rotina</button>
                  <button type="button" class="secondary-button" data-merchant-action="sync">Aplicar sync</button>
                  <button type="button" class="secondary-button" data-merchant-action="report">Gerar relatorio</button>
                  <button type="button" class="secondary-button" data-merchant-action="copy">Exportar rotina</button>
                </div>
              </div>
            </section>
            <section class="erp-canvas-card">
              <div class="erp-card-head">
                <div>
                  <span class="small-label">Fluxo gerencial</span>
                  <strong>Indicadores e tarefas</strong>
                </div>
                ${rowPill(`${formatCount(summary.reviewTotal)} em revisão`, summary.reviewTotal ? "pill-warn" : "pill-accent")}
              </div>
              <div class="erp-chart-panel">
                <div class="erp-chart-bars">
                  ${chartHeights.map((height) => `<span style="height:${height}%"></span>`).join("")}
                </div>
                <div class="erp-chart-legend">
                  <small>Venda</small>
                  <small>Margem</small>
                  <small>PDV</small>
                  <small>Stock</small>
                  <small>Ads</small>
                  <small>Cash</small>
                </div>
                <div class="erp-task-list">
                  ${feature.queue.map((item) => `<div class="erp-task-item">${escapeHtml(item)}</div>`).join("")}
                </div>
              </div>
            </section>
          </div>
          <section class="erp-specific-panel">
            <div class="erp-specific-head">
              <div>
                <span class="small-label">Mecanicas materializadas</span>
                <h4>${escapeHtml(feature.title)} em operação</h4>
              </div>
              <div class="pill-row">
                ${rowPill(`${formatCount(summary.suppliersTotal)} fornecedores`, "pill-navy")}
                ${rowPill(`${formatCount(summary.blockedTotal)} bloqueios`, summary.blockedTotal ? "pill-danger" : "pill-accent")}
              </div>
            </div>
            <div class="erp-queue-grid">
              ${feature.queue.map((item, index) => `
                <article class="erp-queue-card ${index === 0 ? "accent" : index === 1 ? "navy" : index === 2 ? "warn" : ""}">
                  <span class="small-label">${escapeHtml(feature.code)}</span>
                  <strong>${escapeHtml(item)}</strong>
                  <span class="muted-copy">Rotina pronta no workspace do lojista</span>
                </article>
              `).join("")}
            </div>
            <div class="erp-table-wrap">
              <table class="erp-data-table">
                <thead>
                  <tr>
                    <th>${escapeHtml(feature.table[0] || "Rotina")}</th>
                    <th>${escapeHtml(feature.table[1] || "Fila")}</th>
                    <th>${escapeHtml(feature.table[2] || "Metrica")}</th>
                    <th>${escapeHtml(feature.table[3] || "Status")}</th>
                  </tr>
                </thead>
                <tbody>
                  ${rows.map((row) => `
                    <tr>
                      <td>${escapeHtml(row[0])}</td>
                      <td>${escapeHtml(row[1])}</td>
                      <td>${escapeHtml(row[2])}</td>
                      <td>${escapeHtml(row[3])}</td>
                    </tr>
                  `).join("")}
                </tbody>
              </table>
            </div>
          </section>
          <section class="erp-specific-panel">
            <div class="erp-specific-head">
              <div>
                <span class="small-label">Subdominios do lojista</span>
                <h4>Todos os módulos ERP publicados</h4>
              </div>
              ${rowPill(`${formatCount(workspaces.length)} links`, "pill-accent")}
            </div>
            <div class="erp-subdomain-grid">
              ${workspaces.map((workspace) => `
                <article class="erp-subdomain-card">
                  <span class="small-label">${escapeHtml(merchantErpBlueprint(workspace.key).code)}</span>
                  <strong>${escapeHtml(workspace.title)}</strong>
                  <p class="muted-copy">${escapeHtml(workspaceHostLabel(workspace))}</p>
                  <div class="link-row"><a href="${escapeHtml(workspaceHref(workspace))}">Abrir</a></div>
                </article>
              `).join("")}
            </div>
          </section>
        </div>
      </section>
    `;
  }

  function normalizeHref(value) {
    const href = String(value || "").trim();

    if (!href) {
      return "";
    }

    if (/^(https?:|mailto:|tel:|#|\.{1,2}\/|\/)/i.test(href)) {
      return href;
    }

    if (/^[a-z]:[\\/]/i.test(href)) {
      return `file:///${href.replace(/\\/g, "/")}`;
    }

    return `../${href.replace(/^[\\/]+/, "").replace(/\\/g, "/")}`;
  }

  function displayPath(value) {
    return String(value || "")
      .replace(/^(\.\.\/)+/, "")
      .replace(/\//g, "\\");
  }

  function linkMarkup(label, href) {
    const normalized = normalizeHref(href);

    if (!normalized) {
      return `<span class="pill">${escapeHtml(label)} indisponivel</span>`;
    }

    return `<a href="${escapeHtml(normalized)}" target="_blank" rel="noreferrer">${escapeHtml(label)}</a>`;
  }

  function sectionId(module, name) {
    return `${module.slug || module.code.toLowerCase()}-${name}`;
  }

  function selectedModule(modules) {
    if (!modules.length) {
      return null;
    }

    const module = modules.find((item) => item.code === state.selectedCode) || modules[0] || null;

    if (module && state.selectedCode !== module.code) {
      state.selectedCode = module.code;
    }

    return module;
  }

  function readHashSelection() {
    const currentWorkspace = activeWorkspace();
    if (currentWorkspace?.workspaceKind === "merchant_erp") {
      state.activeAdminSurfaceTab = "merchant";
      state.activeMerchantErpFeature = currentWorkspace.key;
      persistMerchantErpFeature(currentWorkspace.key);
      return;
    }

    const moduleWorkspace = activeModuleWorkspace();
    if (moduleWorkspace) {
      state.selectedCode = moduleWorkspace.code;
      state.activeAdminSurfaceTab = "modules";
      return;
    }

    const rawHash = window.location.hash.replace(/^#/, "").trim();
    const code = rawHash.toUpperCase();

    if (code && allModules.some((module) => module.code === code)) {
      state.selectedCode = code;
      state.activeAdminSurfaceTab = "modules";
      return;
    }

    if (rawHash) {
      const sectionTarget = document.getElementById(rawHash);
      const pane = sectionTarget?.getAttribute("data-admin-pane");
      if (pane && ADMIN_SURFACE_TABS.some((tab) => tab.key === pane)) {
        state.activeAdminSurfaceTab = pane;
        persistAdminSurfaceTab();
      }
      return;
    }

    state.selectedCode = allModules[0] ? allModules[0].code : null;
  }

  function syncHash() {
    if (!state.selectedCode || state.activeAdminSurfaceTab !== "modules") {
      return;
    }

    const expectedHash = `#${state.selectedCode.toLowerCase()}`;

    if (window.location.hash !== expectedHash) {
      window.history.replaceState(null, "", expectedHash);
    }
  }

  function syncFormFromState() {
    elements.searchInput.value = state.search;
    elements.tierFilter.value = state.tier;
    elements.dataHomeFilter.value = state.dataHome;
    elements.statusFilter.value = state.status;
    elements.domainFilter.value = state.domain;
  }

  function hasActiveFilters() {
    return Boolean(state.search || state.tier !== "all" || state.dataHome !== "all" || state.status !== "all" || state.domain !== "all");
  }

  function resetFilters() {
    state.search = "";
    state.tier = "all";
    state.dataHome = "all";
    state.status = "all";
    state.domain = "all";
    syncFormFromState();
    announce("Filtros limpos.");
    render();
  }

  function populateFilters() {
    elements.tierFilter.innerHTML =
      optionMarkup("all", "Todos") + uniqueValues((module) => module.tier).map((value) => optionMarkup(value, value)).join("");
    elements.dataHomeFilter.innerHTML =
      optionMarkup("all", "Todos") + uniqueValues((module) => module.data_home).map((value) => optionMarkup(value, value)).join("");
    elements.statusFilter.innerHTML =
      optionMarkup("all", "Todos") +
      uniqueValues((module) => module.automation_status).map((value) => optionMarkup(value, humanizeKey(value))).join("");
    elements.domainFilter.innerHTML =
      optionMarkup("all", "Todos") + uniqueValues((module) => module.domain).map((value) => optionMarkup(value, value)).join("");

    syncFormFromState();
  }

  function announce(message) {
    if (elements.liveRegion) {
      elements.liveRegion.textContent = "";
      window.setTimeout(() => {
        elements.liveRegion.textContent = message;
      }, 10);
    }
  }

  async function copyText(text, label) {
    const content = String(text || "").trim();

    if (!content) {
      announce(`${label} indisponivel para copia.`);
      return;
    }

    try {
      if (navigator.clipboard && window.isSecureContext) {
        await navigator.clipboard.writeText(content);
      } else {
        fallbackCopy(content);
      }

      announce(`${label} copiado.`);
    } catch (error) {
      announce(`Falha ao copiar ${label}.`);
    }
  }

  function fallbackCopy(text) {
    const textarea = document.createElement("textarea");
    textarea.value = text;
    textarea.setAttribute("readonly", "readonly");
    textarea.style.position = "absolute";
    textarea.style.left = "-9999px";
    document.body.appendChild(textarea);
    textarea.select();
    document.execCommand("copy");
    document.body.removeChild(textarea);
  }

  function moveSelection(step) {
    const modules = filteredModules();

    if (!modules.length) {
      return;
    }

    const currentIndex = Math.max(
      modules.findIndex((module) => module.code === state.selectedCode),
      0,
    );
    const nextIndex = (currentIndex + step + modules.length) % modules.length;
    state.selectedCode = modules[nextIndex].code;
    syncHash();
    render();
    announce(`Modulo selecionado: ${modules[nextIndex].code}.`);
  }

  function defaultMarketplaceApiConfig() {
    return MARKETPLACE_API_PROVIDERS.map((provider) => ({
      ...provider,
      enabled: true,
      environment: "production",
      siteCode: provider.siteCode,
      authMode: "oauth2",
      clientId: "",
      secretRef: `vault/marketplaces/${provider.key}/client-secret`,
      accessTokenRef: `vault/marketplaces/${provider.key}/access-token`,
      refreshTokenRef: `vault/marketplaces/${provider.key}/refresh-token`,
      redirectUri: integrationRedirectUri(provider.key),
      sellerId: "",
      webhookUrl: `https://admin.brasildesconto.com.br${integrationWebhookPath(provider.key)}`,
      webhookSecretRef: `vault/marketplaces/${provider.key}/webhook-secret`,
      scopes: "catalog,orders,pricing,inventory,settlement",
      syncCadenceMinutes: 30,
      cacheTtlMinutes: 20,
      marginFloorPct: 12,
      stockModuleEnabled: true,
      sandboxEnabled: true,
      productionEnabled: true,
      importCatalog: true,
      importCategories: true,
      syncOrders: true,
      syncInventory: true,
      syncPricing: true,
      publishApprovedOnly: true,
      requireRetailAdvantage: true,
      requireLiquidityCheck: true,
      allowScrapingFallback: false,
      blockExternalAiLookup: true,
      notes: "",
    }));
  }

  function mergeMarketplaceApiConfig(saved) {
    const byKey = Object.fromEntries(Array.isArray(saved) ? saved.map((item) => [item.key, item]) : []);
    return defaultMarketplaceApiConfig().map((provider) => ({ ...provider, ...(byKey[provider.key] || {}) }));
  }

  function readMarketplaceApiConfig() {
    try {
      if (Array.isArray(state.marketplaceApiConfig) && state.marketplaceApiConfig.length) {
        return mergeMarketplaceApiConfig(state.marketplaceApiConfig);
      }

      const saved = JSON.parse(window.localStorage.getItem(MARKETPLACE_API_STORAGE_KEY) || "[]");
      return mergeMarketplaceApiConfig(saved);
    } catch (error) {
      return defaultMarketplaceApiConfig();
    }
  }

  async function loadMarketplaceApiConfig() {
    try {
      const response = await fetch("/api/admin-integrations", { headers: { Accept: "application/json" } });
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`);
      }

      const payload = await response.json();
      const items = Array.isArray(payload?.items) ? payload.items : [];
      state.marketplaceApiPayload = payload;
      state.marketplaceApiConfig = mergeMarketplaceApiConfig(items);
      window.localStorage.setItem(MARKETPLACE_API_STORAGE_KEY, JSON.stringify(state.marketplaceApiConfig, null, 2));
      renderAdminLaunchpad();
      renderMarketplaceIntegrations();
      announce("Integracoes carregadas do backend do admin.");
    } catch (error) {
      state.marketplaceApiPayload = null;
      state.marketplaceApiConfig = readMarketplaceApiConfig();
      renderAdminLaunchpad();
      renderMarketplaceIntegrations();
      announce("Integracoes carregadas do rascunho deste navegador.");
    }
  }

  function collectMarketplaceApiConfig() {
    if (!elements.marketplaceApiIntegrations) {
      return [];
    }

    const currentByKey = Object.fromEntries(readMarketplaceApiConfig().map((provider) => [provider.key, provider]));

    return MARKETPLACE_API_PROVIDERS.map((provider) => {
      const read = (field) => elements.marketplaceApiIntegrations.querySelector(`[data-provider="${provider.key}"][data-field="${field}"]`);
      const current = currentByKey[provider.key] || {};
      return {
        key: provider.key,
        label: provider.label,
        providerRole: current.providerRole || "",
        enabled: Boolean(read("enabled")?.checked),
        environment: read("environment")?.value || "sandbox",
        siteCode: read("siteCode")?.value.trim() || provider.siteCode,
        authMode: read("authMode")?.value || "oauth2",
        baseUrl: read("baseUrl")?.value.trim() || provider.baseUrl,
        clientId: read("clientId")?.value.trim() || "",
        secretRef: read("secretRef")?.value.trim() || "",
        accessTokenRef: read("accessTokenRef")?.value.trim() || "",
        refreshTokenRef: read("refreshTokenRef")?.value.trim() || "",
        redirectUri: read("redirectUri")?.value.trim() || "",
        sellerId: read("sellerId")?.value.trim() || "",
        webhookUrl: read("webhookUrl")?.value.trim() || "",
        webhookSecretRef: read("webhookSecretRef")?.value.trim() || "",
        scopes: read("scopes")?.value.trim() || "",
        syncCadenceMinutes: Number(read("syncCadenceMinutes")?.value) || 30,
        cacheTtlMinutes: Number(read("cacheTtlMinutes")?.value) || 20,
        marginFloorPct: Number(read("marginFloorPct")?.value) || 12,
        stockModuleEnabled: Boolean(read("stockModuleEnabled")?.checked),
        sandboxEnabled: Boolean(read("sandboxEnabled")?.checked),
        productionEnabled: Boolean(read("productionEnabled")?.checked),
        importCatalog: Boolean(read("importCatalog")?.checked),
        importCategories: Boolean(read("importCategories")?.checked),
        syncOrders: Boolean(read("syncOrders")?.checked),
        syncInventory: Boolean(read("syncInventory")?.checked),
        syncPricing: Boolean(read("syncPricing")?.checked),
        publishApprovedOnly: Boolean(read("publishApprovedOnly")?.checked),
        requireRetailAdvantage: Boolean(read("requireRetailAdvantage")?.checked),
        requireLiquidityCheck: Boolean(read("requireLiquidityCheck")?.checked),
        allowScrapingFallback: Boolean(read("allowScrapingFallback")?.checked),
        blockExternalAiLookup: Boolean(read("blockExternalAiLookup")?.checked),
        usernameRef: current.usernameRef || "",
        passwordRef: current.passwordRef || "",
        notes: read("notes")?.value.trim() || "",
      };
    });
  }

  function resetMarketplaceApiDefaults() {
    const current = readMarketplaceApiConfig();
    const reset = defaultMarketplaceApiConfig().map((provider) => {
      const currentProvider = current.find((item) => item.key === provider.key) || {};
      return {
        ...provider,
        providerRole: currentProvider.providerRole || "",
        clientId: currentProvider.clientId || "",
        secretRef: currentProvider.secretRef || provider.secretRef,
        accessTokenRef: currentProvider.accessTokenRef || provider.accessTokenRef,
        refreshTokenRef: currentProvider.refreshTokenRef || provider.refreshTokenRef,
        sellerId: currentProvider.sellerId || "",
        webhookSecretRef: currentProvider.webhookSecretRef || provider.webhookSecretRef,
        usernameRef: currentProvider.usernameRef || "",
        passwordRef: currentProvider.passwordRef || "",
        notes: currentProvider.notes || "",
      };
    });
    state.marketplaceApiConfig = reset;
    window.localStorage.setItem(MARKETPLACE_API_STORAGE_KEY, JSON.stringify(reset, null, 2));
    renderAdminLaunchpad();
    renderMarketplaceIntegrations();
    announce("Politica padrao das integracoes restaurada.");
  }

  async function saveMarketplaceApiConfig() {
    const payload = collectMarketplaceApiConfig();
    state.marketplaceApiConfig = mergeMarketplaceApiConfig(payload);
    window.localStorage.setItem(MARKETPLACE_API_STORAGE_KEY, JSON.stringify(payload, null, 2));
    try {
      const response = await fetch("/api/admin-integrations", {
        method: "POST",
        headers: { "Content-Type": "application/json", Accept: "application/json" },
        body: JSON.stringify(payload),
      });
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`);
      }

      announce("Integracoes salvas no backend de producao.");
    } catch (error) {
      announce("Integracoes salvas como rascunho neste navegador.");
    }

    renderAdminLaunchpad();
    renderMarketplaceIntegrations();
  }

  function renderMarketplaceIntegrations() {
    if (!elements.marketplaceApiIntegrations) {
      return;
    }

    const config = readMarketplaceApiConfig();
    renderMarketplaceSummary(config);
    renderMarketplaceControlCenter(config);

    elements.marketplaceApiIntegrations.innerHTML = config
      .map(
        (provider) => {
          const readiness = integrationReadiness(provider);
          const scopes = integrationScopeList(provider.scopes);

          return `
          <section class="integration-card" data-integration-card="${escapeHtml(provider.key)}">
            <div class="integration-card-head">
              <div>
                <h3>${escapeHtml(provider.label)}</h3>
                <p class="integration-provider-code">${escapeHtml(provider.key)}</p>
                <p class="muted-copy">${escapeHtml(nextIntegrationAction(provider, readiness))}</p>
              </div>
              <div class="integration-card-status">
                ${rowPill(readiness.stage, readiness.variant)}
                ${provider.runtimeStatus ? rowPill(provider.runtimeStatus, provider.runtimeActive ? "pill-accent" : "pill-danger") : ""}
                <label class="field toggle-field">
                  <span>Ativo</span>
                  <input data-provider="${escapeHtml(provider.key)}" data-field="enabled" type="checkbox" ${provider.enabled ? "checked" : ""} />
                </label>
              </div>
            </div>
            <div class="integration-card-overview">
              ${summaryTileMarkup("Prontidao", formatPercent(readiness.ratio), `${formatCount(readiness.completed)}/${formatCount(readiness.total)} blocos fechados`)}
              ${summaryTileMarkup("Cadencia", `${formatCount(provider.syncCadenceMinutes)} min`, `cache ${formatCount(provider.cacheTtlMinutes)} min`)}
              ${summaryTileMarkup("Escopos", formatCount(scopes.length), scopes.length ? scopes.join(", ") : "nenhum escopo declarado")}
              ${summaryTileMarkup("Margem piso", `${provider.marginFloorPct}%`, provider.sellerId ? `seller ${provider.sellerId}` : "seller pendente")}
            </div>
            <div class="integration-inline-notes">
              <div class="pill-row">
                ${rowPill(provider.environment === "production" ? "producao" : "sandbox", provider.environment === "production" ? "pill-accent" : "pill-warn")}
                ${rowPill(provider.authMode, "pill-navy")}
                ${rowPill(provider.siteCode, "pill")}
              </div>
              <div class="pill-row">
                ${providerCapabilityPills(provider)}
              </div>
              ${
                Array.isArray(provider.runtimePending) && provider.runtimePending.length
                  ? `<div class="pill-row">${provider.runtimePending.map((item) => rowPill(item, "pill-danger")).join("")}</div>`
                  : ""
              }
            </div>
            <div class="integration-form-grid">
              <label class="field">
                <span>Ambiente</span>
                <select data-provider="${escapeHtml(provider.key)}" data-field="environment">
                  <option value="sandbox" ${provider.environment === "sandbox" ? "selected" : ""}>Sandbox</option>
                  <option value="production" ${provider.environment === "production" ? "selected" : ""}>Producao</option>
                </select>
              </label>
              <label class="field">
                <span>Regiao / Site</span>
                <input data-provider="${escapeHtml(provider.key)}" data-field="siteCode" type="text" value="${escapeHtml(provider.siteCode)}" placeholder="BR, MLB, GLOBAL" />
              </label>
              <label class="field">
                <span>Autenticacao</span>
                <select data-provider="${escapeHtml(provider.key)}" data-field="authMode">
                  <option value="oauth2" ${provider.authMode === "oauth2" ? "selected" : ""}>OAuth2</option>
                  <option value="app_key_secret" ${provider.authMode === "app_key_secret" ? "selected" : ""}>App Key + Secret</option>
                  <option value="token" ${provider.authMode === "token" ? "selected" : ""}>Token gerenciado</option>
                </select>
              </label>
              <label class="field">
                <span>Base URL</span>
                <input data-provider="${escapeHtml(provider.key)}" data-field="baseUrl" type="url" value="${escapeHtml(provider.baseUrl)}" />
              </label>
              <label class="field">
                <span>Client ID / App Key</span>
                <input data-provider="${escapeHtml(provider.key)}" data-field="clientId" type="text" value="${escapeHtml(provider.clientId)}" autocomplete="off" />
              </label>
              <label class="field">
                <span>Secret Ref</span>
                <input data-provider="${escapeHtml(provider.key)}" data-field="secretRef" type="text" value="${escapeHtml(provider.secretRef)}" placeholder="vault/marketplaces/${escapeHtml(provider.key)}" autocomplete="off" />
              </label>
              <label class="field">
                <span>Access Token Ref</span>
                <input data-provider="${escapeHtml(provider.key)}" data-field="accessTokenRef" type="text" value="${escapeHtml(provider.accessTokenRef)}" placeholder="vault/marketplaces/${escapeHtml(provider.key)}/access-token" autocomplete="off" />
              </label>
              <label class="field">
                <span>Refresh Token Ref</span>
                <input data-provider="${escapeHtml(provider.key)}" data-field="refreshTokenRef" type="text" value="${escapeHtml(provider.refreshTokenRef)}" placeholder="vault/marketplaces/${escapeHtml(provider.key)}/refresh-token" autocomplete="off" />
              </label>
              <label class="field">
                <span>Redirect URI</span>
                <input data-provider="${escapeHtml(provider.key)}" data-field="redirectUri" type="url" value="${escapeHtml(provider.redirectUri)}" placeholder="https://admin.brasildesconto.com.br/integrations/${escapeHtml(provider.key)}/callback" />
              </label>
              <label class="field">
                <span>Seller / Store ID</span>
                <input data-provider="${escapeHtml(provider.key)}" data-field="sellerId" type="text" value="${escapeHtml(provider.sellerId)}" autocomplete="off" />
              </label>
              <label class="field">
                <span>Webhook URL</span>
                <input data-provider="${escapeHtml(provider.key)}" data-field="webhookUrl" type="text" value="${escapeHtml(provider.webhookUrl)}" />
              </label>
              <label class="field">
                <span>Webhook Secret Ref</span>
                <input data-provider="${escapeHtml(provider.key)}" data-field="webhookSecretRef" type="text" value="${escapeHtml(provider.webhookSecretRef)}" autocomplete="off" />
              </label>
              <label class="field">
                <span>Scopes</span>
                <input data-provider="${escapeHtml(provider.key)}" data-field="scopes" type="text" value="${escapeHtml(provider.scopes)}" />
              </label>
              <label class="field">
                <span>Sync a cada min.</span>
                <input data-provider="${escapeHtml(provider.key)}" data-field="syncCadenceMinutes" type="number" min="5" step="5" value="${escapeHtml(provider.syncCadenceMinutes)}" />
              </label>
              <label class="field">
                <span>Cache TTL min.</span>
                <input data-provider="${escapeHtml(provider.key)}" data-field="cacheTtlMinutes" type="number" min="1" step="1" value="${escapeHtml(provider.cacheTtlMinutes)}" />
              </label>
              <label class="field">
                <span>Margem minima %</span>
                <input data-provider="${escapeHtml(provider.key)}" data-field="marginFloorPct" type="number" min="0" step="0.5" value="${escapeHtml(provider.marginFloorPct)}" />
              </label>
              <div class="integration-toggle-group" aria-label="Sincronizacoes ${escapeHtml(provider.label)}">
                <label class="field toggle-field">
                  <span>Modulo STOCK</span>
                  <input data-provider="${escapeHtml(provider.key)}" data-field="stockModuleEnabled" type="checkbox" ${provider.stockModuleEnabled ? "checked" : ""} />
                </label>
                <label class="field toggle-field">
                  <span>Sandbox</span>
                  <input data-provider="${escapeHtml(provider.key)}" data-field="sandboxEnabled" type="checkbox" ${provider.sandboxEnabled ? "checked" : ""} />
                </label>
                <label class="field toggle-field">
                  <span>Producao</span>
                  <input data-provider="${escapeHtml(provider.key)}" data-field="productionEnabled" type="checkbox" ${provider.productionEnabled ? "checked" : ""} />
                </label>
                <label class="field toggle-field">
                  <span>Catalogo</span>
                  <input data-provider="${escapeHtml(provider.key)}" data-field="importCatalog" type="checkbox" ${provider.importCatalog ? "checked" : ""} />
                </label>
                <label class="field toggle-field">
                  <span>Categorias</span>
                  <input data-provider="${escapeHtml(provider.key)}" data-field="importCategories" type="checkbox" ${provider.importCategories ? "checked" : ""} />
                </label>
                <label class="field toggle-field">
                  <span>Pedidos</span>
                  <input data-provider="${escapeHtml(provider.key)}" data-field="syncOrders" type="checkbox" ${provider.syncOrders ? "checked" : ""} />
                </label>
                <label class="field toggle-field">
                  <span>Estoque</span>
                  <input data-provider="${escapeHtml(provider.key)}" data-field="syncInventory" type="checkbox" ${provider.syncInventory ? "checked" : ""} />
                </label>
                <label class="field toggle-field">
                  <span>Preco</span>
                  <input data-provider="${escapeHtml(provider.key)}" data-field="syncPricing" type="checkbox" ${provider.syncPricing ? "checked" : ""} />
                </label>
                <label class="field toggle-field">
                  <span>Publicar aprovados</span>
                  <input data-provider="${escapeHtml(provider.key)}" data-field="publishApprovedOnly" type="checkbox" ${provider.publishApprovedOnly ? "checked" : ""} />
                </label>
                <label class="field toggle-field">
                  <span>Varejo abaixo</span>
                  <input data-provider="${escapeHtml(provider.key)}" data-field="requireRetailAdvantage" type="checkbox" ${provider.requireRetailAdvantage ? "checked" : ""} />
                </label>
                <label class="field toggle-field">
                  <span>Checar liquidez</span>
                  <input data-provider="${escapeHtml(provider.key)}" data-field="requireLiquidityCheck" type="checkbox" ${provider.requireLiquidityCheck ? "checked" : ""} />
                </label>
                <label class="field toggle-field">
                  <span>Fallback scraping</span>
                  <input data-provider="${escapeHtml(provider.key)}" data-field="allowScrapingFallback" type="checkbox" ${provider.allowScrapingFallback ? "checked" : ""} />
                </label>
                <label class="field toggle-field">
                  <span>Bloquear IA externa</span>
                  <input data-provider="${escapeHtml(provider.key)}" data-field="blockExternalAiLookup" type="checkbox" ${provider.blockExternalAiLookup ? "checked" : ""} />
                </label>
              </div>
              <label class="field">
                <span>Notas</span>
                <input data-provider="${escapeHtml(provider.key)}" data-field="notes" type="text" value="${escapeHtml(provider.notes)}" />
              </label>
            </div>
            <div class="integration-review-grid">
              <section class="integration-review-card">
                <span class="small-label">Checklist de credenciais</span>
                <div class="checklist-list dense-checklist">
                  ${readiness.requiredChecks
                    .map(
                      (item) => `
                        <div class="check-item ${item.ready ? "done" : ""}">
                          <span class="check-flag">${item.ready ? "OK" : "TODO"}</span>
                          <span>${escapeHtml(item.label)}</span>
                        </div>
                      `,
                    )
                    .join("")}
                </div>
              </section>
              <section class="integration-review-card">
                <span class="small-label">Proxima acao</span>
                <p class="muted-copy">${escapeHtml(nextIntegrationAction(provider, readiness))}</p>
                <span class="small-label">Webhook alvo</span>
                <code>${escapeHtml(provider.webhookUrl || "nao publicado")}</code>
              </section>
            </div>
            ${
              Array.isArray(provider.runtimeEvidence) && provider.runtimeEvidence.length
                ? `
                  <div class="runtime-evidence-box">
                    <span class="small-label">Evidencias runtime</span>
                    <div class="pill-row">${provider.runtimeEvidence.map((item) => rowPill(item, "pill-navy")).join("")}</div>
                  </div>
                `
                : ""
            }
          </section>
        `;
        },
      )
      .join("");
  }

  function bindEvents() {
    elements.adminSurfaceTabs?.addEventListener("click", (event) => {
      const trigger = event.target.closest("[data-admin-surface-tab]");
      if (!trigger) {
        return;
      }
      setActiveAdminSurfaceTab(trigger.dataset.adminSurfaceTab);
      announce(`Aba ${trigger.textContent.trim()} aberta.`);
    });

    elements.searchInput.addEventListener("input", (event) => {
      state.search = event.target.value.trim().toLowerCase();
      render();
    });

    elements.tierFilter.addEventListener("change", (event) => {
      state.tier = event.target.value;
      render();
    });

    elements.dataHomeFilter.addEventListener("change", (event) => {
      state.dataHome = event.target.value;
      render();
    });

    elements.statusFilter.addEventListener("change", (event) => {
      state.status = event.target.value;
      render();
    });

    elements.domainFilter.addEventListener("change", (event) => {
      state.domain = event.target.value;
      render();
    });

    elements.resetFilters.addEventListener("click", () => {
      resetFilters();
    });

    elements.copyCommands.addEventListener("click", () => {
      const workspace = activeWorkspace();
      const summary = [
        `Painel: ${workspace?.title || "Valley Admin"}`,
        `Link: ${window.location.href}`,
        `ERP lojista: https://erp-lojista.brasildesconto.com.br/`,
      ].join("\n");
      copyText(summary, "Resumo operacional");
    });

    elements.saveMarketplaceApis?.addEventListener("click", () => {
      saveMarketplaceApiConfig();
    });

    elements.applyMarketplaceApis?.addEventListener("click", () => {
      saveMarketplaceApiConfig();
    });

    elements.resetMarketplaceApis?.addEventListener("click", () => {
      resetMarketplaceApiDefaults();
    });

    elements.copyMarketplaceApis?.addEventListener("click", () => {
      copyText(JSON.stringify(collectMarketplaceApiConfig(), null, 2), "Resumo de integracoes");
    });

    elements.saveImportedPricing?.addEventListener("click", () => {
      saveImportedPricing();
    });

    elements.applyImportedPricing?.addEventListener("click", () => {
      saveImportedPricing();
    });

    elements.resetImportedPricing?.addEventListener("click", () => {
      resetImportedPricingDefaults();
    });

    elements.copyImportedPricing?.addEventListener("click", () => {
      copyText(JSON.stringify(collectImportedPricingPayload(), null, 2), "Resumo de pricing importado");
    });

    elements.importedSupplierBoard?.addEventListener("click", (event) => {
      const reset = event.target.closest("[data-imported-reset-supplier]");
      if (reset) {
        resetImportedSupplierDefaults(reset.dataset.importedResetSupplier);
        announce("Regra do fornecedor removida.");
        return;
      }

      if (event.target.closest("input, select, button")) {
        return;
      }

      const trigger = event.target.closest("[data-imported-supplier]");
      if (!trigger) {
        return;
      }

      updateImportedPricingFilter("supplierKey", trigger.dataset.importedSupplier || "all");
      announce(
        trigger.dataset.importedSupplier === "all"
          ? "Visao consolidada de fornecedores ativada."
          : "Fornecedor selecionado no desk de pricing.",
      );
    });

    elements.importedSupplierBoard?.addEventListener("input", (event) => {
      const target = event.target.closest("[data-imported-supplier-key][data-imported-field]");
      if (!target || target.dataset.importedItemId) {
        return;
      }

      updateImportedSupplierField(
        target.dataset.importedSupplierKey,
        target.dataset.importedField,
        target.value,
      );
    });

    const handleImportedFilterEvent = (event) => {
      const target = event.target.closest("[data-imported-filter]");
      if (!target) {
        return;
      }

      updateImportedPricingFilter(target.dataset.importedFilter, target.value);
    };

    elements.importedPricingFilters?.addEventListener("input", handleImportedFilterEvent);
    elements.importedPricingFilters?.addEventListener("change", handleImportedFilterEvent);

    elements.importedPricingTableWrap?.addEventListener("input", (event) => {
      const filterTarget = event.target.closest("[data-imported-filter]");
      if (filterTarget) {
        updateImportedPricingFilter(filterTarget.dataset.importedFilter, filterTarget.value);
        return;
      }

      const fieldTarget = event.target.closest("[data-imported-item-id][data-imported-field]");
      if (!fieldTarget) {
        return;
      }

      updateImportedItemField(
        fieldTarget.dataset.importedItemId,
        fieldTarget.dataset.importedField,
        fieldTarget.value,
      );
    });

    elements.importedPricingTableWrap?.addEventListener("change", (event) => {
      const filterTarget = event.target.closest("[data-imported-filter]");
      if (filterTarget) {
        updateImportedPricingFilter(filterTarget.dataset.importedFilter, filterTarget.value);
      }
    });

    elements.importedPricingTableWrap?.addEventListener("click", (event) => {
      const reset = event.target.closest("[data-imported-reset-item]");
      if (reset) {
        resetImportedItemOverride(reset.dataset.importedResetItem);
        announce("Override do SKU removido.");
        return;
      }

      const pager = event.target.closest("[data-imported-page]");
      if (!pager) {
        return;
      }

      importedPricingState.page += pager.dataset.importedPage === "next" ? 1 : -1;
      importedPricingState.page = Math.max(1, importedPricingState.page);
      renderImportedPricingDesk();
    });

    elements.merchantErpRoot?.addEventListener("click", (event) => {
      const featureTrigger = event.target.closest("[data-merchant-feature]");
      if (featureTrigger) {
        setActiveMerchantErpFeature(featureTrigger.dataset.merchantFeature);
        return;
      }

      const actionTrigger = event.target.closest("[data-merchant-action]");
      if (actionTrigger) {
        runMerchantErpAction(actionTrigger.dataset.merchantAction);
        return;
      }
    });

    elements.merchantErpRoot?.addEventListener("input", (event) => {
      const field = event.target.closest("[data-merchant-field]");
      if (!field || field.readOnly) {
        return;
      }
      updateMerchantErpDraftField(field.dataset.merchantField, field.value);
    });

    elements.stitchP0ExecutionRoot?.addEventListener("click", (event) => {
      const trigger = event.target.closest("[data-stitch-action]");
      if (!trigger) {
        return;
      }
      runStitchP0Action(trigger.dataset.stitchAction);
    });

    elements.criticalModules.addEventListener("click", (event) => {
      const trigger = event.target.closest("[data-critical-code]");

      if (!trigger) {
        return;
      }

      state.search = "";
      state.tier = "all";
      state.dataHome = "all";
      state.status = "all";
      state.domain = "all";
      syncFormFromState();
      state.selectedCode = trigger.dataset.criticalCode;
      syncHash();
      render();
      announce(`Modulo critico selecionado: ${state.selectedCode}.`);
    });

    elements.moduleList.addEventListener("click", (event) => {
      const trigger = event.target.closest("[data-code]");

      if (!trigger) {
        return;
      }

      state.selectedCode = trigger.dataset.code;
      syncHash();
      render();
    });

    elements.commandList.addEventListener("click", (event) => {
      const trigger = event.target.closest("[data-copy-command]");

      if (!trigger) {
        return;
      }

      if (trigger.dataset.commandText) {
        copyText(trigger.dataset.commandText, "Link operacional");
        return;
      }

      const index = Number(trigger.dataset.copyCommand);
      copyText(trigger.dataset.actionText || "", `Ação ${index + 1}`);
    });

    elements.externalAccess.addEventListener("click", (event) => {
      const trigger = event.target.closest("[data-copy-external]");

      if (!trigger) {
        return;
      }

      if (trigger.dataset.copyExternal === "preview") {
        copyText(activeAdminPublicUrl() || "https://admin.brasildesconto.com.br/", "Painel público");
      }

      if (trigger.dataset.copyExternal === "erp") {
        copyText("https://erp-lojista.brasildesconto.com.br/", "ERP lojista");
      }
    });

    elements.detailNav.addEventListener("click", (event) => {
      const trigger = event.target.closest("[data-target]");

      if (!trigger) {
        return;
      }

      event.preventDefault();
      const target = document.getElementById(trigger.dataset.target);

      if (target) {
        target.scrollIntoView({ behavior: "smooth", block: "start" });
      }
    });

    elements.detailContent.addEventListener("click", (event) => {
      const tabTrigger = event.target.closest("[data-workspace-tab][data-module-code]");
      if (tabTrigger) {
        setModuleWorkspaceTab(tabTrigger.dataset.moduleCode, tabTrigger.dataset.workspaceTab);
        renderDetail(filteredModules());
        announce(`Aba ${tabTrigger.textContent.trim()} aberta.`);
        return;
      }

      const actionTrigger = event.target.closest("[data-workspace-action][data-module-code]");
      if (actionTrigger) {
        const module = allModules.find((item) => item.code === actionTrigger.dataset.moduleCode);
        if (module) {
          runModuleWorkspaceAction(module, actionTrigger.dataset.workspaceAction);
        }
        return;
      }

      const stockActionTrigger = event.target.closest("[data-stock-action]");
      if (stockActionTrigger) {
        runStockTableAction(stockActionTrigger);
        return;
      }

      const trigger = event.target.closest("[data-copy-path]");

      if (!trigger) {
        return;
      }

      copyText(trigger.dataset.copyPath, "Caminho do arquivo");
    });

    document.body.addEventListener("click", (event) => {
      const link = event.target.closest('a[href^="#"]');
      if (!link) {
        return;
      }
      const sectionId = String(link.getAttribute("href") || "").replace(/^#/, "").trim();
      if (!sectionId) {
        return;
      }
      const target = document.getElementById(sectionId);
      if (!target) {
        return;
      }
      const pane = target.getAttribute("data-admin-pane");
      if (pane && pane !== state.activeAdminSurfaceTab) {
        setActiveAdminSurfaceTab(pane, { preserveScroll: true });
      }
    });

    window.addEventListener("hashchange", () => {
      const code = window.location.hash.replace(/^#/, "").trim().toUpperCase();

      if (code && allModules.some((module) => module.code === code)) {
        state.selectedCode = code;
        render();
      }
    });

    window.addEventListener("keydown", (event) => {
      const target = event.target;
      const typing =
        target instanceof HTMLInputElement ||
        target instanceof HTMLTextAreaElement ||
        target instanceof HTMLSelectElement ||
        target?.isContentEditable;

      if (event.key === "/" && !typing) {
        event.preventDefault();
        elements.searchInput.focus();
        elements.searchInput.select();
        return;
      }

      if (typing) {
        if (event.key === "Escape" && target === elements.searchInput) {
          event.preventDefault();
          resetFilters();
          elements.searchInput.blur();
        }

        return;
      }

      if (event.key === "j" || event.key === "ArrowDown") {
        event.preventDefault();
        moveSelection(1);
      }

      if (event.key === "k" || event.key === "ArrowUp") {
        event.preventDefault();
        moveSelection(-1);
      }

      if (event.key === "Escape" && hasActiveFilters()) {
        event.preventDefault();
        resetFilters();
      }
    });
  }

  function filteredModules() {
    const moduleWorkspace = activeModuleWorkspace();
    const source = moduleWorkspace ? allModules.filter((module) => module.code === moduleWorkspace.code) : allModules;

    return source.filter((module) => {
      const searchable = [module.code, module.name, module.subtitle, module.description_ptbr, module.domain].join(" ").toLowerCase();

      return (
        (!state.search || searchable.includes(state.search)) &&
        (state.tier === "all" || module.tier === state.tier) &&
        (state.dataHome === "all" || module.data_home === state.dataHome) &&
        (state.status === "all" || module.automation_status === state.status) &&
        (state.domain === "all" || module.domain === state.domain)
      );
    });
  }

  function renderTopbar(modules) {
    const report = data.deployment_summary;
    const release = releaseSummaryOrFallback();
    const runtime = data.public_runtime;
    const readiness = overallReadiness(modules);
    const hybridCount = modules.filter((module) => module.data_home === "postgres_mongo").length;
    const plannedCount = modules.filter((module) => module.automation_status === "planned").length;
    const workspace = activeWorkspace();
    const workspaceModule = activeModuleWorkspace();

    document.body.classList.add("production-shell");
    document.body.classList.toggle("workspace-mode", Boolean(workspace && workspace.key !== "home"));
    document.body.classList.toggle("home-showcase", !workspace || workspace.key === "home");

    if (elements.heroTitle && elements.heroSubcopy) {
      if (workspaceModule) {
        elements.heroTitle.textContent = `${workspaceModule.code} · ${workspaceModule.name} em modo de producao`;
        elements.heroSubcopy.textContent = `${workspaceModule.subtitle}. Este subdominio dedicado centraliza docs, checklist, contratos, acoplamentos, leituras comerciais e trilha operacional do modulo ${workspaceModule.code}.`;
      } else if (workspace && workspace.key !== "home") {
        elements.heroTitle.textContent = `${workspace.title} em modo de producao`;
        elements.heroSubcopy.textContent = `${workspace.copy} O painel permanece conectado ao manifesto, ao runtime publico e aos dashboards comerciais sem trocar de shell.`;
      } else {
        elements.heroTitle.textContent = "Painel de producao para 47 modulos";
        elements.heroSubcopy.textContent = "Supervisao executiva, gestao comercial e leitura operacional em uma unica superficie. O painel cruza modulos, contratos, catalogo, checkout, lojistas, usuarios e exposicao publica Cloudflare.";
      }
    }

    if (elements.heroBadge) {
      elements.heroBadge.textContent = PRODUCTION_MODE_LOCKED ? "PRODUCAO ATIVA" : workspace && workspace.key !== "home" ? "PRODUCAO ATIVA" : "SANDBOX EM PRODUCAO";
    }

    elements.registryName.textContent = data.registry_name || "Registry sem nome";
    elements.sourceLabel.textContent = `Fonte: ${data.source || "indisponivel"} | Linguagem: ${data.language_policy || "indisponivel"}`;
    elements.generatedAt.textContent = formatTimestamp(data.generated_at_utc);
    elements.reportHealth.textContent = report.available
      ? `${report.failed_checks} pendencias no ultimo status`
      : "Relatorio operacional indisponivel";
    elements.reportHealth.className = reportHealthClass(report);

    elements.heroTags.innerHTML = [
      rowPill("modo producao", "pill-accent"),
      rowPill(`${formatCount(modules.length)} modulos visiveis`, "pill-navy"),
      rowPill(`${formatPercent(readiness)} prontidao media`, "pill-accent"),
      rowPill(`${formatCount(release.modules_completed)} modulos completos`, "pill-accent"),
      rowPill(`${formatCount(hybridCount)} trilhas hibridas`, "pill-accent"),
      rowPill(`${formatCount(plannedCount)} ainda planejados`, plannedCount ? "pill-warn" : "pill-accent"),
      rowPill(runtimeLabel(runtime), runtime.available ? "pill-accent" : "pill-warn"),
      rowPill(`${formatCount(report.failed_checks)} alertas operacionais`, report.failed_checks ? "pill-danger" : "pill-accent"),
    ].join("");
  }

  function renderMetrics(modules) {
    const readiness = overallReadiness(modules);
    const plannedCount = modules.filter((module) => module.automation_status === "planned").length;
    const hybridCount = modules.filter((module) => module.data_home === "postgres_mongo").length;
    const foundationCount = modules.filter((module) => module.tier === "foundation").length;
    const pendingCount = totalPending(modules);

    elements.metrics.innerHTML = [
      metricMarkup("Escopo ativo", `${formatCount(modules.length)}/${formatCount(allModules.length)}`, "modulos no corte atual", ratio(modules.length, allModules.length)),
      metricMarkup("Prontidao media", formatPercent(readiness), `${formatCount(totalDone(modules))} itens concluidos`, readiness),
      metricMarkup("Camada base", formatCount(foundationCount), `${formatCount(plannedCount)} ainda em planejamento`, ratio(foundationCount, modules.length || 1)),
      metricMarkup("Hibridos", formatCount(hybridCount), "postgres + mongo no mesmo modulo", ratio(hybridCount, modules.length || 1)),
      metricMarkup(
        "Migrations",
        formatCount(data.database_summary.postgres_migrations),
        `${formatCount(data.database_summary.mongodb_scripts)} scripts mongo`,
        ratio(data.database_summary.postgres_migrations, 20),
      ),
      metricMarkup("Pendencias", formatCount(pendingCount), "checklist aberto no recorte atual", pendingCount ? Math.min(pendingCount / 120, 1) : 0),
    ].join("");
  }

  function signalMarkup(title, value, meta, tone) {
    return `
      <article class="signal-card ${tone}">
        <div class="signal-header">
          <div>
            <div class="signal-title">${escapeHtml(title)}</div>
            <div class="signal-meta">${escapeHtml(meta)}</div>
          </div>
          <div class="signal-value">${escapeHtml(value)}</div>
        </div>
      </article>
    `;
  }

  function renderPrioritySignals(modules) {
    const release = releaseSummaryOrFallback();
    const runtime = data.public_runtime;
    const criticalModule = release.top_modules_with_pending[0] || null;
    const readinessPercentage = release.average_module_readiness_percentage || overallReadiness(allModules) * 100;
    const runtimeMeta = runtime.public_url
      ? `${publicUrlLabel(runtime)} | ${runtime.permanence || "permanencia nao declarada"}`
      : `manifesto ${runtime.status || "missing"} | ${displayPath(runtime.path || data.public_access.path || "")}`;

    elements.prioritySignals.innerHTML = [
      signalMarkup(
        "Media de prontidao",
        formatPercentFromHundred(readinessPercentage),
        `${formatCount(release.modules_completed)} modulos completos em ${formatCount(release.modules_total)} do release`,
        readinessPercentage >= 65 ? "accent" : readinessPercentage >= 40 ? "warn" : "danger",
      ),
      signalMarkup(
        "Modulo mais critico",
        criticalModule ? criticalModule.code : "--",
        criticalModule
          ? `${criticalModule.name} | ${formatCount(criticalModule.checklist_pending)} pendencias | ${formatPercentFromHundred(criticalModule.module_readiness_percentage)} prontidao`
          : "Nenhum modulo critico publicado no payload",
        criticalModule && criticalModule.checklist_pending >= 6 ? "danger" : "warn",
      ),
      signalMarkup(
        "Top pendencias",
        formatCount(release.checklist_items_pending),
        `${formatCount(release.modules_with_pending)} modulos ainda abertos no corte global`,
        release.checklist_items_pending ? "warn" : "accent",
      ),
      signalMarkup("URL publica", runtime.public_url ? "ativa" : runtimeLabel(runtime), runtimeMeta, runtime.available ? "accent" : "warn"),
    ].join("");
  }

  function renderReleaseSummaryBoard() {
    const release = releaseSummaryOrFallback();

    elements.releaseSummaryBoard.innerHTML = [
      summaryTileMarkup(
        "Modulos completos",
        `${formatCount(release.modules_completed)}/${formatCount(release.modules_total)}`,
        "fechados no corte global do release",
      ),
      summaryTileMarkup(
        "Modulos com pendencia",
        formatCount(release.modules_with_pending),
        `${formatCount(release.top_modules_with_pending.length)} visiveis na trilha critica`,
      ),
      summaryTileMarkup(
        "Checklist global",
        formatPercentFromHundred(release.checklist_completion_percentage),
        `${formatCount(release.checklist_items_done)} de ${formatCount(release.checklist_items_total)} itens concluidos`,
      ),
      summaryTileMarkup(
        "Media de prontidao",
        formatPercentFromHundred(release.average_module_readiness_percentage),
        `${formatCount(release.checklist_items_pending)} itens ainda abertos`,
      ),
    ].join("");
  }

  function renderCriticalModules() {
    const release = releaseSummaryOrFallback();
    const criticalModules = release.top_modules_with_pending.slice(0, 5);

    if (!criticalModules.length) {
      elements.criticalModules.innerHTML = `<div class="empty-state">Nenhum modulo critico publicado no payload atual.</div>`;
      return;
    }

    elements.criticalModules.innerHTML = criticalModules
      .map(
        (module) => `
          <button class="critical-item" type="button" data-critical-code="${escapeHtml(module.code)}">
            <div class="critical-top">
              <div>
                <div class="critical-code">${escapeHtml(module.code)}</div>
                <div class="critical-name">${escapeHtml(module.name)}</div>
              </div>
              ${rowPill(module.tier, "pill-navy")}
            </div>
            <div class="critical-meta">
              ${rowPill(`${formatCount(module.checklist_pending)} pendencias`, module.checklist_pending >= 6 ? "pill-danger" : "pill-warn")}
              ${rowPill(formatPercentFromHundred(module.module_readiness_percentage), "pill-accent")}
              ${rowPill(module.status_label, statusVariant(module.automation_status))}
            </div>
          </button>
        `,
      )
      .join("");
  }

  function renderPublicRuntime() {
    const runtime = data.public_runtime;
    const tone = runtimeTone(runtime);
    const permanence = runtime.permanence || (runtime.public_url ? "nao declarada" : "aguardando runtime");
    const adminUrl = runtime.public_url || activeAdminPublicUrl() || "https://admin.brasildesconto.com.br/";
    const portalUrl = activeProductPublicUrl() || "https://brasildesconto.com.br/product/";
    const erpUrl = "https://erp-lojista.brasildesconto.com.br/";

    elements.publicRuntimePanel.innerHTML = `
      <article class="runtime-status-card ${escapeHtml(tone)}">
        <div class="runtime-header">
          <div>
            <div class="runtime-url">${escapeHtml(publicUrlLabel(runtime))}</div>
            <div class="runtime-copy">${escapeHtml(runtime.public_url || "Nenhuma URL publica ativa foi publicada ainda.")}</div>
          </div>
          ${rowPill(runtimeLabel(runtime), runtime.available ? "pill-accent" : runtime.status === "missing" ? "pill-warn" : "pill-danger")}
        </div>
        <div class="external-grid">
          ${externalTileMarkup("Status", runtime.available ? "ativo" : runtime.status || "missing", "estado atual do runtime")}
          ${externalTileMarkup("Permanencia", permanence, "fixa, volatil ou aguardando")}
          ${externalTileMarkup("Acesso", "publicado", "admin, portal e ERP lojista")}
        </div>
        <p class="muted-copy">
          Os links oficiais mantêm a operação fora da rede local para administradores, lojistas e usuários.
        </p>
        <div class="endpoint-list">
          <div class="endpoint-item">
            <div>
              <strong>Admin</strong>
              <div class="muted-copy">${escapeHtml(adminUrl)}</div>
            </div>
            ${linkMarkup("Abrir", adminUrl)}
          </div>
          <div class="endpoint-item">
            <div>
              <strong>Portal</strong>
              <div class="muted-copy">${escapeHtml(portalUrl)}</div>
            </div>
            ${linkMarkup("Abrir", portalUrl)}
          </div>
          <div class="endpoint-item">
            <div>
              <strong>ERP lojista</strong>
              <div class="muted-copy">${escapeHtml(erpUrl)}</div>
            </div>
            ${linkMarkup("Abrir", erpUrl)}
          </div>
        </div>
      </article>
    `;
  }

  function renderStack(container, rows) {
    const largest = rows.reduce((max, row) => Math.max(max, row.count), 0) || 1;

    if (!rows.length) {
      container.innerHTML = `<div class="empty-state">Nenhum dado disponivel para este recorte.</div>`;
      return;
    }

    container.innerHTML = rows
      .map((row) => {
        return `
          <article class="stack-card">
            <div class="stack-header">
              <div>
                <div class="stack-title">${escapeHtml(row.label)}</div>
                <div class="stack-meta">${escapeHtml(row.meta)}</div>
              </div>
              ${rowPill(`${formatCount(row.count)} modulos`, row.variant)}
            </div>
            <div class="stack-track">
              <div class="stack-bar" style="width: ${Math.max(0.08, row.count / largest) * 100}%"></div>
            </div>
          </article>
        `;
      })
      .join("");
  }

  function renderTierMatrix(modules) {
    const groups = countBy(modules, (module) => module.tier);
    const rows = Object.keys(TIER_ORDER)
      .filter((tier) => groups[tier])
      .map((tier) => {
        const tierModules = modules.filter((module) => module.tier === tier);

        return {
          label: tier,
          count: groups[tier],
          meta: `${formatPercent(overallReadiness(tierModules))} prontidao media`,
          variant: tier === "foundation" ? "pill-accent" : tier === "core" ? "pill-navy" : "pill-warn",
        };
      });

    renderStack(elements.tierMatrix, rows);
  }

  function renderDataHomeMatrix(modules) {
    const groups = countBy(modules, (module) => module.data_home);
    const ordered = ["postgres", "mongo", "postgres_mongo"];
    const rows = ordered
      .filter((key) => groups[key])
      .map((key) => {
        const homeModules = modules.filter((module) => module.data_home === key);

        return {
          label: key,
          count: groups[key],
          meta: `${formatPercent(overallReadiness(homeModules))} prontidao media`,
          variant: key === "postgres_mongo" ? "pill-accent" : key === "mongo" ? "pill-navy" : "",
        };
      });

    renderStack(elements.dataHomeMatrix, rows);
  }

  function renderReleaseQueue(modules) {
    const queue =
      data.release_queue_summary.items.length > 0
        ? data.release_queue_summary.items.slice(0, 6)
        : modules
            .slice()
            .sort((left, right) => modulePriorityScore(left) - modulePriorityScore(right))
            .slice(0, 6);

    if (!queue.length) {
      elements.releaseQueue.innerHTML = `<div class="empty-state">Nenhum modulo disponivel para fila de evolucao.</div>`;
      return;
    }

    elements.releaseQueue.innerHTML = queue
      .map((module) => {
        const readiness = moduleReadiness(module);
        const pendingCount = module.checklist?.pending ?? module.checklist_pending ?? 0;

        return `
          <article class="queue-item">
            <div class="queue-header">
              <div>
                <div class="queue-title">${escapeHtml(module.code)} · ${escapeHtml(module.name)}</div>
                <div class="queue-meta">${escapeHtml(module.subtitle)} | ${escapeHtml(module.domain)}</div>
              </div>
              ${rowPill(module.tier, "pill-accent")}
            </div>
            <div class="pill-row">
              ${rowPill(module.data_home, "pill-navy")}
              ${rowPill(module.status_label, statusVariant(module.automation_status))}
              ${rowPill(`${formatCount(pendingCount)} pendencias`, pendingCount ? "pill-warn" : "pill-accent")}
            </div>
            ${progressMarkup(readiness)}
            <div class="pill-row">
              ${(module.next_focus || []).map((action) => rowPill(action)).join("")}
            </div>
          </article>
        `;
      })
      .join("");
  }

  function renderDomainBoard(modules) {
    const groups = groupByDomain(modules);
    const domains = Object.keys(groups).sort();

    if (!domains.length) {
      elements.domainBoard.innerHTML = `<div class="empty-state">Nenhum dominio disponivel para o recorte atual.</div>`;
      return;
    }

    elements.domainBoard.innerHTML = domains
      .map((domain) => {
        const items = groups[domain];
        const readiness = overallReadiness(items);
        const plannedCount = items.filter((module) => module.automation_status === "planned").length;
        const hybridCount = items.filter((module) => module.data_home === "postgres_mongo").length;

        return `
          <article class="domain-card">
            <div>
              <h3>${escapeHtml(domain)}</h3>
              <p class="muted-copy">${formatCount(items.length)} modulos com ${formatPercent(readiness)} de prontidao media.</p>
            </div>
            ${progressMarkup(readiness)}
            <div class="domain-stats">
              ${rowPill(`${formatCount(plannedCount)} planejados`, plannedCount ? "pill-warn" : "pill-accent")}
              ${rowPill(`${formatCount(hybridCount)} hibridos`, hybridCount ? "pill-accent" : "")}
              ${rowPill(`${formatCount(totalPending(items))} pendencias`, totalPending(items) ? "pill-danger" : "pill-accent")}
            </div>
          </article>
        `;
      })
      .join("");
  }

  function renderFilterMeta(modules) {
    const pills = [
      rowPill(`${formatPercent(overallReadiness(modules))} prontidao`, "pill-accent"),
      rowPill(`${formatCount(totalPending(modules))} pendencias`, totalPending(modules) ? "pill-warn" : "pill-accent"),
    ];

    if (hasActiveFilters()) {
      pills.push(rowPill("filtro ativo", "pill-navy"));
    }

    elements.moduleSelectionMeta.innerHTML = pills.join("");
  }

  function renderCommands() {
    const workspace = activeWorkspace();
    const workspaceModule = activeModuleWorkspace();
    const workspaceUrl = workspace ? workspaceHref(workspace) : activeAdminPublicUrl() || window.location.href;
    const actions = [
      {
        label: "Abrir painel ativo",
        detail: workspace?.title || "Painel Valley",
        href: workspaceUrl,
      },
      {
        label: "Abrir ERP lojista",
        detail: "Gestao comercial, PDV, estoque e financeiro",
        href: "https://erp-lojista.brasildesconto.com.br/",
      },
      {
        label: "Abrir catalogo",
        detail: "Produtos, pricing e revisao comercial",
        href: "#importedPricingSection",
      },
      {
        label: "Abrir integracoes",
        detail: "Marketplaces, fornecedores e conectores",
        href: "#settingsSection",
      },
    ];

    if (workspaceModule) {
      actions.unshift({
        label: `Operar ${workspaceModule.code}`,
        detail: `${workspaceModule.name} em modo release`,
        href: workspaceUrl,
      });
    }

    elements.commandList.innerHTML = actions
      .map(
        (action, index) => `
          <article class="command-item release-action-item">
            <div>
              <strong>${escapeHtml(action.label)}</strong>
              <span>${escapeHtml(action.detail)}</span>
            </div>
            <div class="link-row">
              ${linkMarkup("Abrir", action.href)}
              <button class="ghost-button" type="button" data-copy-command="${index}" data-command-text="${escapeHtml(action.href)}">Copiar link</button>
            </div>
          </article>
        `,
      )
      .join("");
  }

  function externalTileMarkup(label, value, meta) {
    return `
      <article class="external-tile">
        <span class="small-label">${escapeHtml(label)}</span>
        <strong>${escapeHtml(value)}</strong>
        <span class="muted-copy">${escapeHtml(meta)}</span>
      </article>
    `;
  }

  function renderExternalAccess() {
    const adminUrl = activeAdminPublicUrl() || "https://admin.brasildesconto.com.br/";
    const productUrl = activeProductPublicUrl() || "https://brasildesconto.com.br/product/";
    const erpUrl = "https://erp-lojista.brasildesconto.com.br/";

    elements.externalAccess.innerHTML = `
      <div class="external-panel">
        <div class="external-grid">
          ${externalTileMarkup("Admin", "online", new URL(adminUrl).host)}
          ${externalTileMarkup("ERP lojista", "online", new URL(erpUrl).host)}
          ${externalTileMarkup("Portal", "online", new URL(productUrl).host)}
        </div>
        <p class="muted-copy">
          A superficie externa esta preparada para acesso fora da rede local com links oficiais para administracao, lojista e catalogo publico.
        </p>
        <div class="link-row">
          ${linkMarkup("Abrir admin", adminUrl)}
          ${linkMarkup("Abrir ERP lojista", erpUrl)}
          ${linkMarkup("Abrir portal", productUrl)}
        </div>
        <div class="action-row">
          <button class="secondary-button" type="button" data-copy-external="preview">Copiar admin</button>
          <button class="secondary-button" type="button" data-copy-external="erp">Copiar ERP</button>
        </div>
      </div>
    `;
  }

  function renderModuleList(modules) {
    elements.moduleCount.textContent = `${formatCount(modules.length)} modulos filtrados`;

    if (!modules.length) {
      elements.moduleList.innerHTML = `<div class="empty-state">Nenhum modulo corresponde aos filtros atuais.</div>`;
      return;
    }

    const selected = selectedModule(modules);

    elements.moduleList.innerHTML = modules
      .map((module) => {
        const readiness = moduleReadiness(module);
        const isActive = selected && module.code === selected.code;

        return `
          <button
            class="module-row ${isActive ? "is-active" : ""}"
            data-code="${escapeHtml(module.code)}"
            type="button"
            role="option"
            aria-selected="${isActive ? "true" : "false"}"
            tabindex="${isActive ? "0" : "-1"}"
          >
            <div class="module-row-top">
              <div class="module-id">
                <span class="module-number">${escapeHtml(String(module.number).padStart(2, "0"))}</span>
                <div>
                  <div class="module-code">${escapeHtml(module.code)}</div>
                  <div class="module-name">${escapeHtml(module.name)}</div>
                </div>
              </div>
              ${rowPill(module.tier, "pill-accent")}
            </div>
            <div class="module-caption">${escapeHtml(module.subtitle)} | ${escapeHtml(module.domain)}</div>
            <div class="pill-row">
              ${rowPill(module.data_home, "pill-navy")}
              ${rowPill(module.status_label, statusVariant(module.automation_status))}
              ${rowPill(`${formatCount(module.checklist.pending)} pendencias`, module.checklist.pending ? "pill-warn" : "pill-accent")}
            </div>
            ${progressMarkup(readiness)}
          </button>
        `;
      })
      .join("");
  }

  function summaryTileMarkup(label, value, meta) {
    return `
      <article class="summary-tile">
        <span class="small-label">${escapeHtml(label)}</span>
        <strong>${escapeHtml(value)}</strong>
        <span class="muted-copy">${escapeHtml(meta)}</span>
      </article>
    `;
  }

  function pathItemMarkup(label, path) {
    const normalizedPath = normalizeHref(path);

    return `
      <article class="path-item">
        <div class="small-label">${escapeHtml(label)}</div>
        <code>${escapeHtml(displayPath(path) || "caminho indisponivel")}</code>
        <div class="link-row">
          ${normalizedPath ? linkMarkup("Abrir", path) : `<span class="pill">Abrir indisponivel</span>`}
          <button class="secondary-button" type="button" data-copy-path="${escapeHtml(path || "")}">Copiar caminho</button>
        </div>
      </article>
    `;
  }

  function moduleAccent(module) {
    const palette = {
      PAY: "#0d9b4d",
      STOCK: "#2563eb",
      MARKETPLACE: "#7c3aed",
      REPLY: "#1d4ed8",
      FOOD: "#ea580c",
      DELIVERY: "#0f766e",
      SOCIAL: "#db2777",
      SCHOOL: "#6d28d9",
      HEALTH: "#059669",
      LEGAL: "#334155",
    };
    return palette[module.code] || "#2563eb";
  }

  function moduleWorkspaceMenuEntries(module) {
    const byDomain = {
      logistics_erp_operations: ["Painel", "Pedidos", "Estoque", "Compras", "Expedicao", "Financeiro", "Relatorios", "Configuracoes"],
      commerce_fintech_assets: ["Painel", "Clientes", "Recebimentos", "Produtos", "Aprovacoes", "Conciliacao", "Risco", "Configuracoes"],
      services_health_human: ["Painel", "Agenda", "Cadastros", "Atendimentos", "Faturamento", "Filas", "Indicadores", "Configuracoes"],
      education_work_social: ["Painel", "Cadastros", "Presenca", "Turmas", "Financeiro", "Calendario", "Relatorios", "Configuracoes"],
      media_social_growth: ["Painel", "Campanhas", "Creators", "Conteudo", "Moderacao", "Metricas", "Receitas", "Configuracoes"],
      ai_memory_operations: ["Painel", "Memoria", "Conversas", "Operacoes", "Aprovacoes", "Processos", "Historico", "Configuracoes"],
      city_mobility_security: ["Painel", "Chamados", "Rotas", "Ocorrencias", "Protecao", "Monitoramento", "Escalas", "Configuracoes"],
      platform_developer: ["Painel", "Docs", "Contratos", "Automacoes", "Filas", "Entregas", "Auditoria", "Configuracoes"],
      frontier_iot_energy: ["Painel", "Sensores", "Ativos", "Telemetria", "Eventos", "Alertas", "Energia", "Configuracoes"],
    };

    if (module.code === "SCHOOL") {
      return ["Painel", "Alunos", "Presenca", "Mensalidades", "Calendario", "Secretaria", "Relatorios", "Configuracoes"];
    }

    if (module.code === "PAY") {
      return ["Painel", "Carteiras", "Recebimentos", "Transferencias", "Conciliacao", "Risco", "Extratos", "Configuracoes"];
    }

    if (module.code === "MARKETPLACE") {
      return ["Painel", "Lojas", "Produtos", "Precos", "Anuncios", "Aprovacoes", "Integracoes", "Configuracoes"];
    }

    return byDomain[module.domain] || ["Painel", "Cadastros", "Operacoes", "Financeiro", "Relatorios", "Aprovacoes", "Integracoes", "Configuracoes"];
  }

  function moduleWorkspaceTileSet(module, businessSnapshot) {
    const itemsValue = businessSnapshot ? businessSnapshot.items_total : module.checklist.total;
    const catalogValue = businessSnapshot ? businessSnapshot.inventory_value_brl : 0;
    const definitions = {
      logistics_erp_operations: [
        ["Pedidos", formatCount(itemsValue), "volume operacional"],
        ["Fila", formatCount(module.checklist.pending), "itens aguardando"],
        ["Integracoes", formatCount(module.integrates_with.length), "rotas ativas"],
        ["Prontidao", formatPercent(moduleReadiness(module)), "indice atual"],
      ],
      commerce_fintech_assets: [
        ["Receita", businessSnapshot ? formatMoney(catalogValue) : formatCount(module.checklist.done), "base comercial"],
        ["Aprovacoes", formatCount(module.checklist.pending), "analises abertas"],
        ["Conectores", formatCount(module.integrates_with.length), "marketplaces e pay"],
        ["Prontidao", formatPercent(moduleReadiness(module)), "indice atual"],
      ],
      services_health_human: [
        ["Agenda", formatCount(module.checklist.total), "slots mapeados"],
        ["Atendimentos", formatCount(module.checklist.done), "rotinas prontas"],
        ["Filas", formatCount(module.checklist.pending), "espera operacional"],
        ["Prontidao", formatPercent(moduleReadiness(module)), "indice atual"],
      ],
      education_work_social: [
        ["Cadastros", formatCount(module.checklist.total), "base academica"],
        ["Presenca", formatCount(module.checklist.done), "rotinas prontas"],
        ["Pendencias", formatCount(module.checklist.pending), "secretaria e regras"],
        ["Prontidao", formatPercent(moduleReadiness(module)), "indice atual"],
      ],
      media_social_growth: [
        ["Campanhas", formatCount(module.checklist.total), "ciclos ativos"],
        ["Conteudos", formatCount(module.checklist.done), "fluxos preparados"],
        ["Moderacao", formatCount(module.checklist.pending), "itens aguardando"],
        ["Prontidao", formatPercent(moduleReadiness(module)), "indice atual"],
      ],
      ai_memory_operations: [
        ["Contextos", formatCount(module.checklist.total), "superficies ligadas"],
        ["Memorias", formatCount(module.checklist.done), "rotinas modeladas"],
        ["Ajustes", formatCount(module.checklist.pending), "fila de calibracao"],
        ["Prontidao", formatPercent(moduleReadiness(module)), "indice atual"],
      ],
      city_mobility_security: [
        ["Chamados", formatCount(module.checklist.total), "eventos rastreados"],
        ["Escalas", formatCount(module.checklist.done), "trilhas prontas"],
        ["Alertas", formatCount(module.checklist.pending), "itens de risco"],
        ["Prontidao", formatPercent(moduleReadiness(module)), "indice atual"],
      ],
      platform_developer: [
        ["Contratos", formatCount(module.checklist.total), "objetos versionados"],
        ["Automacoes", formatCount(module.checklist.done), "rotinas ativas"],
        ["Filas", formatCount(module.checklist.pending), "pendencias de entrega"],
        ["Prontidao", formatPercent(moduleReadiness(module)), "indice atual"],
      ],
      frontier_iot_energy: [
        ["Ativos", formatCount(module.checklist.total), "mapa operacional"],
        ["Sensores", formatCount(module.checklist.done), "rotas prontas"],
        ["Alertas", formatCount(module.checklist.pending), "eventos criticos"],
        ["Prontidao", formatPercent(moduleReadiness(module)), "indice atual"],
      ],
    };

    const selected = definitions[module.domain] || definitions.logistics_erp_operations;
    return selected.map(([label, value, meta]) => ({ label, value, meta }));
  }

  function moduleWorkspaceMenu(module) {
    return moduleWorkspaceMenuEntries(module);
  }

  function moduleWorkspaceTiles(module, businessSnapshot) {
    return moduleWorkspaceTileSet(module, businessSnapshot);
  }

  function moduleClassicFormFields(module) {
    return [
      ["Código", String(module.number).padStart(3, "0")],
      ["Descrição", module.name],
      ["Plano / Núcleo", module.domain],
      ["Data home", module.data_home],
      ["Status", module.status_label],
      ["Responsável", "Valley Admin"],
    ];
  }

  function moduleOperationsSnapshot(module, openItems) {
    return [
      {
        title: "Fila critica",
        value: formatCount(openItems.length),
        meta: openItems.length ? openItems[0].label : "Sem item bloqueando o módulo",
        tone: openItems.length ? "danger" : "accent",
      },
      {
        title: "Dependencias",
        value: formatCount(module.depends_on.length),
        meta: module.depends_on.length ? formatList(module.depends_on.slice(0, 3)) : "Sem bloqueio externo declarado",
        tone: module.depends_on.length ? "warn" : "accent",
      },
      {
        title: "Acoplamentos",
        value: formatCount(module.integrates_with.length),
        meta: module.integrates_with.length ? formatList(module.integrates_with.slice(0, 3)) : "Sem integracao formal listada",
        tone: "navy",
      },
      {
        title: "Modo",
        value: "Producao",
        meta: "sandbox espelhado no shell principal",
        tone: "accent",
      },
    ];
  }

  function moduleSubdomainRoutes(module) {
    const workspace = moduleWorkspaceByCode(module.code);
    const subdomain = workspace?.subdomain || module.slug || module.code.toLowerCase();
    const code = module.code.toLowerCase();
    const adminHost = activeAdminHost().hostname;
    const baseHost = isLocalAdminHostname(adminHost) ? "admin.brasildesconto.com.br" : adminHost;
    const publicRootHost = publicRootHostFromAdminHost(baseHost);
    return [
      {
        label: "workspace",
        route: `${subdomain}-admin.${publicRootHost}`,
        description: `cockpit principal de ${module.name.toLowerCase()}`,
      },
      {
        label: "ops",
        route: `ops-${code}.${baseHost}`,
        description: "operacao, filas, playbooks e monitoramento",
      },
      {
        label: "api",
        route: `api-${code}.${baseHost}`,
        description: "integracoes, webhooks, credenciais e saude",
      },
      {
        label: "backoffice",
        route: `backoffice-${code}.${baseHost}`,
        description: "cadastros, permissoes, auditoria e fechamento",
      },
    ];
  }

  function moduleWorkspaceSections(module) {
    const byCode = {
      STOCK: [
        ["Catalogo e SKUs", "curadoria, midia, estoque, custo e margem por item"],
        ["Publicacao", "fila por marketplace, revisao comercial e rejeicoes"],
        ["Fornecedores", "SLA, lead time, origem e disputa de custo"],
        ["Rentabilidade", "margem, taxa, frete e ruptura por categoria"],
      ],
      PAY: [
        ["Carteiras", "saldo, ledger, split, limites e conciliacao"],
        ["Checkout", "PIX, cartao, webhook, fallback e antifraude"],
        ["Compliance", "KYC, risco, chargeback e bloqueios"],
        ["Recebiveis", "agenda financeira, repasse e fechamento diario"],
      ],
      MOVE: [
        ["Corridas", "despacho, SLA, aceite e cancelamentos"],
        ["Motoristas", "cadastro, score, documentos e incentivos"],
        ["Telemetria", "GPS, incidentes, heatmap e eventos de risco"],
        ["Financeiro", "repasse, taxa, custo por km e ajustes"],
      ],
      FOOD: [
        ["Pedidos", "cozinha, fila, ticket medio e cancelamentos"],
        ["Restaurantes", "menus, onboarding, disponibilidade e horario"],
        ["Entrega", "riders, despacho, SLA e ocorrencias"],
        ["CRM", "cupom, recompra, cohort e expansao regional"],
      ],
      SCHOOL: [
        ["Alunos", "matricula, suporte, historico e evasao"],
        ["Turmas", "agenda, lotacao, professores e reposicao"],
        ["Financeiro", "mensalidades, bolsas e inadimplencia"],
        ["Conteudo", "trilhas, provas, certificados e engajamento"],
      ],
    };

    const byDomain = {
      media_social_growth: [
        ["Campanhas", "planejamento, janelas, criativos e aprovacoes"],
        ["Creators", "comissao, contratos, links e performance"],
        ["Moderacao", "qualidade, risco, conteudo e compliance"],
        ["Receita", "trafego, conversao, payout e relatorio de rede"],
      ],
      ai_memory_operations: [
        ["Contexto", "memoria, preferencia, sinal e embeddings"],
        ["Conversas", "fila, modelos, roteamento e audicao"],
        ["Aprovacoes", "guardrails, decisao humana e rastreabilidade"],
        ["Observabilidade", "latencia, custo, erro e rollout"],
      ],
      frontier_iot_energy: [
        ["Sensores", "ativos, heartbeat, status e provisionamento"],
        ["Telemetria", "eventos, stream, retenção e anomalias"],
        ["Alertas", "criticos, escalonamento e resposta"],
        ["Energia", "consumo, sazonalidade e eficiencia operacional"],
      ],
    };

    const selected = byCode[module.code] || byDomain[module.domain] || [
      ["Operacao", "fila principal, excecoes, checkpoints e produtividade"],
      ["Cadastros", "entidades, regras, formularios e validacoes"],
      ["Integracoes", "api, webhook, sincronismo e observabilidade"],
      ["Governanca", "auditoria, permissoes, logs e fechamento"],
    ];

    return selected.map(([title, text]) => ({ title, text }));
  }

  function moduleDeepWorkspaceTabs(module) {
    const defaults = [
      { key: "overview", label: "Visao geral", description: "KPI, ficha e resumo executivo" },
      { key: "operations", label: "Operacao", description: "filas, cadencia e blocos funcionais" },
      { key: "integrations", label: "Integracoes", description: "subdominios, APIs e atalhos do cockpit" },
      { key: "governance", label: "Governanca", description: "registros, auditoria e fechamento" },
    ];

    if (module.code === "PAY") {
      defaults[2] = { key: "integrations", label: "Checkout", description: "saude, ambiente e integracoes financeiras" };
    }

    if (module.code === "STOCK") {
      defaults[1] = { key: "operations", label: "Catalogo", description: "fila, publicacao e rentabilidade" };
      defaults[2] = { key: "integrations", label: "Marketplaces", description: "APIs, pricing e canais ativos" };
    }

    return defaults;
  }

  function activeModuleWorkspaceTab(module) {
    const tabs = moduleDeepWorkspaceTabs(module);
    const saved = state.moduleWorkspaceTabs?.[module.code];
    return tabs.some((tab) => tab.key === saved) ? saved : tabs[0].key;
  }

  function moduleWorkspaceActions(module) {
    const actions = [
      { label: "Abrir workspace", action: "open-workspace", tone: "navy", meta: "rota espelho ou subdominio do modulo" },
      { label: "Abrir docs", action: "jump-docs", tone: "accent", meta: "README, status e contract do modulo" },
      { label: "Ir para operacao", action: "jump-ops", tone: "warn", meta: "pendencias e checks do ambiente" },
    ];

    if (module.code === "STOCK" || module.code === "MARKETPLACE") {
      actions.unshift(
        { label: "Salvar APIs", action: "save-integrations", tone: "accent", meta: "persistir /api/admin-integrations" },
        { label: "Aplicar APIs", action: "apply-integrations", tone: "navy", meta: "salvar e validar configuracao de canais" },
        { label: "Resetar APIs", action: "reset-integrations", tone: "warn", meta: "voltar ao baseline de conectores" },
      );
    }

    if (module.code === "STOCK" || module.code === "DROPSHIPPING") {
      actions.push(
        { label: "Salvar pricing", action: "save-pricing", tone: "accent", meta: "persistir /api/admin-imported-products-pricing" },
        { label: "Aplicar pricing", action: "apply-pricing", tone: "navy", meta: "replicar overrides e defaults" },
        { label: "Resetar pricing", action: "reset-pricing", tone: "warn", meta: "limpar ajustes locais de margem" },
      );
    }

    if (module.code === "PAY") {
      actions.unshift(
        { label: "Atualizar checkout", action: "refresh-checkout", tone: "accent", meta: "revalidar /api/checkout-health" },
        { label: "Abrir checkout", action: "jump-checkout", tone: "navy", meta: "painel operacional do Mercado Pago" },
      );
    }

    return actions;
  }

  function moduleSpecificRuntimePanel(module) {
    if (moduleSnapshotsState.loading) {
      return `<div class="empty-state">Carregando snapshot real do módulo...</div>`;
    }

    if (moduleSnapshotsState.error) {
      return `<div class="empty-state">Snapshot indisponível: ${escapeHtml(moduleSnapshotsState.error)}</div>`;
    }

    const snapshot = moduleRuntimeSnapshot(module.code);
    if (!snapshot) {
      return "";
    }

    if (module.code === "STOCK") {
      const categories = Array.isArray(snapshot.top_categories) ? snapshot.top_categories : [];
      const suppliers = Array.isArray(snapshot.supplier_summary) ? snapshot.supplier_summary : [];
      const supplierRows = Array.isArray(snapshot.supplier_rows) ? snapshot.supplier_rows : [];
      const reviewRows = Array.isArray(snapshot.review_rows) ? snapshot.review_rows : [];
      const reasons = Array.isArray(snapshot.blocking_reasons) ? snapshot.blocking_reasons : [];
      const topItem = snapshot.top_stock_item || {};
      const topMargin = snapshot.top_margin_item || {};
      return `
        <section class="erp-specific-panel">
          <div class="erp-specific-head">
            <div>
              <span class="small-label">Runtime real do módulo</span>
              <h4>STOCK control plane</h4>
            </div>
            <div class="pill-row">
              ${rowPill(snapshot.sync_status || "idle", snapshot.pending_runtime_total ? "pill-warn" : "pill-accent")}
              ${rowPill(`${formatCount(snapshot.providers_active || 0)}/${formatCount(snapshot.providers_total || 0)} providers ativos`, "pill-navy")}
            </div>
          </div>
          <div class="erp-specific-grid stock">
            ${insightCardMarkup("Catálogo", formatCount(snapshot.items_total || 0), "itens reais disponíveis no resumo do catálogo", rowPill(formatMoney(snapshot.inventory_value_brl || 0), "pill-accent"))}
            ${insightCardMarkup("Publicação", formatCount(snapshot.approved_total || 0), "aprovados para publicação", rowPill(`${formatCount(snapshot.review_total || 0)} em revisão`, "pill-warn"))}
            ${insightCardMarkup("Margem potencial", formatMoney(snapshot.margin_potential_brl || 0), "margem agregada atual do módulo", rowPill(`${formatCount(snapshot.do_not_publish_total || 0)} bloqueados`, "pill-danger"))}
            ${insightCardMarkup("Sync", escapeHtml(snapshot.sync_status || "idle"), escapeHtml(snapshot.sync_detail || "sem detalhe adicional"), rowPill(snapshot.latest_sync_event?.source || "runtime", "pill"))}
          </div>
          <div class="erp-specific-grid stock">
            <article class="erp-specific-card">
              <span class="small-label">Top item por estoque</span>
              <strong>${escapeHtml(topItem.title || "Sem item")}</strong>
              <p class="muted-copy">${escapeHtml(topItem.category || "Sem categoria")} · ${formatCount(topItem.stock || 0)} unidades</p>
            </article>
            <article class="erp-specific-card">
              <span class="small-label">Top item por margem</span>
              <strong>${escapeHtml(topMargin.title || "Sem item")}</strong>
              <p class="muted-copy">${formatMoney(topMargin.total_margin_brl || 0)} de margem total estimada</p>
            </article>
            <article class="erp-specific-card">
              <span class="small-label">Categorias líderes</span>
              <div class="pill-row">${categories.map((item) => rowPill(`${item.category} · ${formatCount(item.items_total || 0)}`, "pill")).join("") || rowPill("Sem categorias", "pill")}</div>
            </article>
            <article class="erp-specific-card">
              <span class="small-label">Fornecedores líderes</span>
              <div class="pill-row">${suppliers.map((item) => rowPill(`${item.supplier_name} · ${formatCount(item.items_total || 0)}`, "pill-navy")).join("") || rowPill("Sem fornecedores", "pill")}</div>
            </article>
          </div>
          <div class="erp-specific-list">
            <strong>Motivos correntes de bloqueio e revisão</strong>
            ${reasons.length ? reasons.map((item) => `<div class="erp-task-item">${escapeHtml(item.code || "motivo")} · ${escapeHtml(item.label || "sem descrição")} · ${formatCount(item.total || 0)}</div>`).join("") : `<div class="erp-task-item">Sem motivo crítico de bloqueio no snapshot atual.</div>`}
          </div>
          <div class="erp-specific-grid stock">
            <section class="erp-specific-card erp-specific-card-wide">
              <div class="erp-card-head">
                <div>
                  <span class="small-label">Tabela viva</span>
                  <strong>Fornecedores e publicação</strong>
                </div>
                ${rowPill(`${formatCount(supplierRows.length)} linhas`, "pill-navy")}
              </div>
              <div class="erp-table-wrap">
                <table class="erp-data-table">
                  <thead>
                    <tr>
                      <th>Fornecedor</th>
                      <th>Itens</th>
                      <th>Aprov.</th>
                      <th>Revisão</th>
                      <th>Bloq.</th>
                      <th>Receita estimada</th>
                      <th>Ações</th>
                    </tr>
                  </thead>
                  <tbody>
                    ${supplierRows.map((item) => `
                      <tr>
                        <td>${escapeHtml(item.supplier_name || "Fornecedor")}</td>
                        <td>${escapeHtml(formatCount(item.items_total || 0))}</td>
                        <td>${escapeHtml(formatCount(item.approved_total || 0))}</td>
                        <td>${escapeHtml(formatCount(item.review_total || 0))}</td>
                        <td>${escapeHtml(formatCount(item.do_not_publish_total || 0))}</td>
                        <td>${escapeHtml(formatMoney(item.suggested_revenue_value_brl || 0))}</td>
                        <td>
                          <div class="pricing-inline-stack">
                            <button type="button" class="secondary-button" data-stock-action="filter-supplier" data-supplier-key="${escapeHtml(item.supplier_key || "")}">Filtrar</button>
                            <button type="button" class="secondary-button" data-stock-action="open-pricing">Pricing</button>
                          </div>
                        </td>
                      </tr>
                    `).join("") || `<tr><td colspan="7">Sem fornecedor no snapshot atual.</td></tr>`}
                  </tbody>
                </table>
              </div>
            </section>
            <section class="erp-specific-card erp-specific-card-wide">
              <div class="erp-card-head">
                <div>
                  <span class="small-label">Fila viva</span>
                  <strong>Itens em revisão ou bloqueio</strong>
                </div>
                ${rowPill(`${formatCount(reviewRows.length)} itens`, "pill-warn")}
              </div>
              <div class="erp-table-wrap">
                <table class="erp-data-table">
                  <thead>
                    <tr>
                      <th>Produto</th>
                      <th>Fornecedor</th>
                      <th>Status</th>
                      <th>Estoque</th>
                      <th>Venda sugerida</th>
                      <th>Ações</th>
                    </tr>
                  </thead>
                  <tbody>
                    ${reviewRows.map((item) => `
                      <tr>
                        <td>${escapeHtml(item.title || "Produto")}</td>
                        <td>${escapeHtml(item.supplier_name || "-")}</td>
                        <td>${escapeHtml(item.publication_status_label || item.publication_status || "-")}</td>
                        <td>${escapeHtml(formatCount(item.stock || 0))}</td>
                        <td>${escapeHtml(formatMoney(item.suggested_sale_price_brl || 0))}</td>
                        <td>
                          <div class="pricing-inline-stack">
                            <button type="button" class="secondary-button" data-stock-action="filter-supplier" data-supplier-name="${escapeHtml(item.supplier_name || "")}">Fornecedor</button>
                            <button type="button" class="secondary-button" data-stock-action="open-review">Revisão</button>
                            <button type="button" class="secondary-button" data-stock-action="copy-item" data-item-id="${escapeHtml(item.id || "")}">Copiar ID</button>
                          </div>
                        </td>
                      </tr>
                    `).join("") || `<tr><td colspan="6">Sem item pendente na fila atual.</td></tr>`}
                  </tbody>
                </table>
              </div>
            </section>
          </div>
        </section>
      `;
    }

    if (module.code === "PAY") {
      const validation = snapshot.validation || {};
      const notifications = Array.isArray(snapshot.notification_history) ? snapshot.notification_history : [];
      const preferences = Array.isArray(snapshot.preference_history) ? snapshot.preference_history : [];
      const attempts = Array.isArray(snapshot.checkout_attempt_history) ? snapshot.checkout_attempt_history : [];
      return `
        <section class="erp-specific-panel">
          <div class="erp-specific-head">
            <div>
              <span class="small-label">Runtime real do módulo</span>
              <h4>PAY checkout ops</h4>
            </div>
            <div class="pill-row">
              ${rowPill(snapshot.checkout_ready ? "checkout pronto" : "checkout pendente", snapshot.checkout_ready ? "pill-accent" : "pill-warn")}
              ${rowPill(snapshot.preferred_environment || "unconfigured", "pill-navy")}
            </div>
          </div>
          <div class="erp-specific-grid pay">
            ${insightCardMarkup("Status", escapeHtml(snapshot.checkout_status || "missing"), "saúde agregada do checkout do Mercado Pago", rowPill(validation.status || "sem validação", validation.status === "ok" ? "pill-accent" : "pill-warn"))}
            ${insightCardMarkup("Credenciais", `${[snapshot.access_token_present, snapshot.public_key_present, snapshot.webhook_secret_present].filter(Boolean).length}/3`, "access token, public key e webhook secret", rowPill(snapshot.operator_login_present ? "login operador salvo" : "sem login operador", snapshot.operator_login_present ? "pill-accent" : "pill"))}
            ${insightCardMarkup("Validação", escapeHtml(validation.status || "missing"), escapeHtml(validation.detail || "sem detalhe adicional"), rowPill(validation.checked_at_utc ? formatTimestamp(validation.checked_at_utc) : "sem checagem", "pill"))}
            ${insightCardMarkup("Retorno", snapshot.sample_return_url ? "habilitado" : "pendente", "URL pública de retorno do checkout", snapshot.notification_url ? rowPill("webhook configurado", "pill-accent") : rowPill("webhook pendente", "pill-warn"))}
          </div>
          <div class="erp-specific-grid pay">
            <article class="erp-specific-card">
              <span class="small-label">notification_url</span>
              <strong>${escapeHtml(snapshot.notification_url || "indisponível")}</strong>
            </article>
            <article class="erp-specific-card">
              <span class="small-label">return_url</span>
              <strong>${escapeHtml(snapshot.sample_return_url || "indisponível")}</strong>
            </article>
          </div>
          <div class="erp-specific-grid pay">
            <section class="erp-specific-card erp-specific-card-wide">
              <div class="erp-card-head">
                <div>
                  <span class="small-label">Histórico real</span>
                  <strong>Notificações recebidas</strong>
                </div>
                ${rowPill(`${formatCount(snapshot.notifications_total || 0)} eventos`, notifications.length ? "pill-accent" : "pill")}
              </div>
              <div class="erp-history-list">
                ${notifications.map((item) => `
                  <article class="erp-history-item">
                    <strong>${escapeHtml(item.received_at_utc || "sem data")}</strong>
                    <span>${escapeHtml(item.headers?.x_topic || item.query?.topic?.[0] || "notificação")}</span>
                    <p class="muted-copy">${escapeHtml(item.body?.type || item.body?.action || item.body?.topic || "payload persistido em runtime")}</p>
                  </article>
                `).join("") || `<div class="erp-task-item">Nenhuma notificação Mercado Pago persistida no runtime até agora.</div>`}
              </div>
            </section>
            <section class="erp-specific-card erp-specific-card-wide">
              <div class="erp-card-head">
                <div>
                  <span class="small-label">Histórico real</span>
                  <strong>Preferências de checkout</strong>
                </div>
                ${rowPill(`${formatCount(snapshot.preferences_total || 0)} preferências`, preferences.length ? "pill-accent" : "pill")}
              </div>
              <div class="erp-history-list">
                ${preferences.map((item) => `
                  <article class="erp-history-item">
                    <strong>${escapeHtml(item.created_at_utc || "sem data")}</strong>
                    <span>${escapeHtml(item.item_id || item.external_reference || "item")}</span>
                    <p class="muted-copy">${escapeHtml(item.preference_id || "sem preference_id")} · ${escapeHtml(item.sandbox_init_point ? "sandbox" : "produção")}</p>
                  </article>
                `).join("") || `<div class="erp-task-item">Nenhuma preferência Mercado Pago foi gerada no runtime atual.</div>`}
              </div>
            </section>
          </div>
          <section class="erp-specific-card erp-specific-card-wide">
            <div class="erp-card-head">
              <div>
                <span class="small-label">Histórico real</span>
                <strong>Tentativas de checkout</strong>
              </div>
              ${rowPill(`${formatCount(snapshot.checkout_attempts_total || 0)} tentativas`, attempts.length ? "pill-accent" : "pill")}
            </div>
            <div class="erp-history-list">
              ${attempts.map((item) => `
                <article class="erp-history-item">
                  <strong>${escapeHtml(item.attempted_at_utc || "sem data")}</strong>
                  <span>${escapeHtml(item.item_id || "item")} · ${escapeHtml(item.status || "status")}</span>
                  <p class="muted-copy">${escapeHtml(item.detail || item.result?.message || "sem detalhe")}</p>
                </article>
              `).join("") || `<div class="erp-task-item">Nenhuma tentativa de checkout foi registrada ainda.</div>`}
            </div>
          </section>
        </section>
      `;
    }

    if (module.code === "MOVE") {
      const pendingItems = Array.isArray(snapshot.pending_items) ? snapshot.pending_items : [];
      const dependencies = Array.isArray(snapshot.dependencies) ? snapshot.dependencies : [];
      const integrations = Array.isArray(snapshot.integrations) ? snapshot.integrations : [];
      const operationalFeed = Array.isArray(snapshot.operational_feed) ? snapshot.operational_feed : [];
      const failures = Array.isArray(snapshot.deployment_failures) ? snapshot.deployment_failures : [];
      return `
        <section class="erp-specific-panel">
          <div class="erp-specific-head">
            <div>
              <span class="small-label">Runtime real do módulo</span>
              <h4>MOVE operação e readiness</h4>
            </div>
            <div class="pill-row">
              ${rowPill(snapshot.runtime_status || "missing", snapshot.runtime_available ? "pill-accent" : "pill-warn")}
              ${rowPill(`${Math.round(snapshot.work_progress_percent || 0)}%`, "pill-navy")}
            </div>
          </div>
          <div class="erp-specific-grid move">
            ${insightCardMarkup("Runtime", snapshot.runtime_available ? "ativo" : "pendente", "estado do runtime público vinculado ao cockpit", rowPill(snapshot.public_url ? "url pública disponível" : "sem url pública", snapshot.public_url ? "pill-accent" : "pill-warn"))}
            ${insightCardMarkup("Work status", escapeHtml(snapshot.work_status || "missing"), escapeHtml(snapshot.work_activity_description || snapshot.work_activity || "sem atividade registrada"), rowPill(`${Math.round(snapshot.work_progress_percent || 0)}% progresso`, "pill"))}
            ${insightCardMarkup("Checklist", `${formatCount(snapshot.checklist_done || 0)}/${formatCount(snapshot.checklist_total || 0)}`, "itens do módulo MOVE concluídos", rowPill(`${formatCount(snapshot.checklist_pending || 0)} pendentes`, snapshot.checklist_pending ? "pill-warn" : "pill-accent"))}
            ${insightCardMarkup("Telemetria", escapeHtml(snapshot.telemetry_mode || "fallback_runtime"), "fonte operacional atual do módulo", rowPill(snapshot.telemetry_source ? "feed ativo" : "sem feed", snapshot.telemetry_source ? "pill-accent" : "pill"))}
          </div>
          <div class="erp-specific-grid move">
            <article class="erp-specific-card">
              <span class="small-label">Pendências do módulo</span>
              <div class="pill-row">${pendingItems.map((item) => rowPill(item, "pill-warn")).join("") || rowPill("Sem pendência aberta", "pill-accent")}</div>
            </article>
            <article class="erp-specific-card">
              <span class="small-label">Dependências</span>
              <div class="pill-row">${dependencies.map((item) => rowPill(item, "pill")).join("") || rowPill("Sem dependência", "pill-accent")}</div>
            </article>
            <article class="erp-specific-card">
              <span class="small-label">Integrações</span>
              <div class="pill-row">${integrations.map((item) => rowPill(item, "pill-navy")).join("") || rowPill("Sem integração", "pill")}</div>
            </article>
            <article class="erp-specific-card">
              <span class="small-label">Falhas de deploy ligadas ao ambiente</span>
              <div class="pill-row">${failures.map((item) => rowPill(item, "pill-danger")).join("") || rowPill("Sem falha crítica", "pill-accent")}</div>
            </article>
          </div>
          <section class="erp-specific-card erp-specific-card-wide">
            <div class="erp-card-head">
              <div>
                <span class="small-label">Feed operacional</span>
                <strong>MOVE runtime feed</strong>
              </div>
              ${rowPill(snapshot.telemetry_mode === "fallback_runtime" ? "fallback runtime" : "telemetria dedicada", snapshot.telemetry_mode === "fallback_runtime" ? "pill-warn" : "pill-accent")}
            </div>
            <div class="erp-history-list">
              ${operationalFeed.map((item) => `
                <article class="erp-history-item">
                  <strong>${escapeHtml(item.timestamp || "sem data")}</strong>
                  <span>${escapeHtml(item.title || item.kind || "evento")}</span>
                  <p class="muted-copy">${escapeHtml(item.detail || item.status || "sem detalhe")}</p>
                </article>
              `).join("") || `<div class="erp-task-item">Nenhum evento operacional disponível para o feed do MOVE.</div>`}
            </div>
          </section>
        </section>
      `;
    }

    return "";
  }

  function moduleChartSeries(module) {
    const base = Math.max(module.checklist.total, 6);
    const ready = Math.max(module.checklist.done, 2);
    const pending = Math.max(module.checklist.pending, 1);
    const integrations = Math.max(module.integrates_with.length, 1);
    const dependencies = Math.max(module.depends_on.length, 1);
    const domainBias = Math.max((module.number % 7) + 2, 2);
    const values = [ready, pending, integrations, dependencies, domainBias, base];
    const max = Math.max(...values, 1);
    return values.map((value, index) => ({
      label: ["Backlog", "Fila", "Links", "Deps", "Ritmo", "Meta"][index],
      height: `${Math.max(24, Math.round((value / max) * 100))}%`,
    }));
  }

  function moduleLedgerRows(module, businessSnapshot, openItems) {
    return [
      {
        code: "001",
        description: `Fluxo principal do ${module.code}`,
        ops: businessSnapshot ? formatCount(businessSnapshot.items_total) : formatCount(module.checklist.total),
        queue: formatCount(module.checklist.pending),
        state: module.status_label,
      },
      {
        code: "002",
        description: "Checklist de fechamento",
        ops: formatCount(openItems.length),
        queue: formatCount(openItems.length),
        state: openItems.length ? "Em aberto" : "Concluído",
      },
      {
        code: "003",
        description: "Integrações declaradas",
        ops: formatCount(module.integrates_with.length),
        queue: formatCount(module.depends_on.length),
        state: module.integrates_with.length ? "Ativo" : "Sem vínculo",
      },
    ];
  }

  function renderDetail(modules) {
    if (!modules.length) {
      elements.detailTitle.textContent = "Nenhum modulo no filtro";
      elements.detailSubtitle.textContent = "Ajuste os filtros para retomar a navegacao do release.";
      elements.detailMeta.innerHTML = "";
      elements.detailNav.innerHTML = "";
      elements.detailContent.innerHTML = `<div class="empty-state">Nenhum modulo selecionavel com os filtros atuais.</div>`;
      return;
    }

    const module = selectedModule(modules);

    if (!module) {
      return;
    }

    const readiness = moduleReadiness(module);
    const openItems = (module.checklist?.items || []).filter((item) => !item.done);
    const checklistMarkup = (module.checklist?.items || []).length
      ? module.checklist.items
          .map(
            (item) => `
              <div class="check-item ${item.done ? "done" : ""}">
                <span class="check-flag">${item.done ? "OK" : "TODO"}</span>
                <span>${escapeHtml(item.label)}</span>
              </div>
            `,
          )
          .join("")
      : `<div class="empty-state">Checklist indisponivel.</div>`;

    const ids = {
      summary: sectionId(module, "summary"),
      management: sectionId(module, "management"),
      finance: sectionId(module, "finance"),
      architecture: sectionId(module, "architecture"),
      checklist: sectionId(module, "checklist"),
      docs: sectionId(module, "docs"),
      ops: sectionId(module, "ops"),
    };

    const navItems = [
      { label: "Resumo", target: ids.summary },
      { label: "Workspace ERP", target: sectionId(module, "erp") },
      { label: "Gestao", target: ids.management },
      { label: "Financeiro", target: ids.finance },
      { label: "Acoplamentos", target: ids.architecture },
      { label: "Checklist", target: ids.checklist },
      { label: "Docs", target: ids.docs },
      { label: "Operacao", target: ids.ops },
    ];
    const businessSnapshot = catalogModuleSnapshot(module.code);
    const erpTiles = moduleWorkspaceTiles(module, businessSnapshot);
    const formFields = moduleClassicFormFields(module);
    const ledgerRows = moduleLedgerRows(module, businessSnapshot, openItems);
    const queueCards = moduleOperationsSnapshot(module, openItems);
    const chartSeries = moduleChartSeries(module);
    const workspaceSections = moduleWorkspaceSections(module);
    const subdomainRoutes = moduleSubdomainRoutes(module);
    const workspaceTabs = moduleDeepWorkspaceTabs(module);
    const activeTab = activeModuleWorkspaceTab(module);
    const workspaceActions = moduleWorkspaceActions(module);
    const specificRuntimePanel = moduleSpecificRuntimePanel(module);
    const accent = moduleAccent(module);
    const erpWorkspaceBlock = `
      <section class="detail-block detail-block-wide erp-workspace-shell" id="${escapeHtml(sectionId(module, "erp"))}" style="--erp-accent:${escapeHtml(accent)}">
        <div class="erp-main">
          <div class="erp-top-navigation">
            <div class="erp-brand">
              <div class="erp-brand-badge">${escapeHtml(module.code.charAt(0))}</div>
              <div>
                <strong>${escapeHtml(module.code)}</strong>
                <span>${escapeHtml(module.name)}</span>
              </div>
            </div>
            <nav class="erp-module-nav">
              ${workspaceTabs
                .map(
                  (item) =>
                    `<button type="button" class="erp-nav-item ${item.key === activeTab ? "is-active" : ""}" data-workspace-tab="${escapeHtml(item.key)}" data-module-code="${escapeHtml(module.code)}">${escapeHtml(item.label)}</button>`,
                )
                .join("")}
            </nav>
          </div>
          <div class="erp-toolbar">
            <div>
              <span class="small-label">Workspace do módulo</span>
              <h3>${escapeHtml(module.name)}</h3>
            </div>
            <div class="pill-row">
              ${rowPill("produção", "pill-accent")}
              ${rowPill("sandbox espelhado", "pill")}
              ${rowPill(module.domain, "pill-navy")}
              ${rowPill(module.status_label, statusVariant(module.automation_status))}
            </div>
          </div>
          <div class="erp-status-ribbon">
            <span>Subdomínio dedicado</span>
            <strong>${escapeHtml(moduleWorkspaceByCode(module.code)?.subdomain || module.slug || module.code.toLowerCase())}</strong>
            <span>${escapeHtml(module.subtitle)}</span>
          </div>
          <div class="erp-tab-strip">
            ${workspaceTabs
              .map(
                (tab) => `
                  <button type="button" class="erp-tab-chip ${tab.key === activeTab ? "is-active" : ""}" data-workspace-tab="${escapeHtml(tab.key)}" data-module-code="${escapeHtml(module.code)}">
                    <strong>${escapeHtml(tab.label)}</strong>
                    <span>${escapeHtml(tab.description)}</span>
                  </button>
                `,
              )
              .join("")}
          </div>
          <section class="erp-tab-panel ${activeTab === "overview" ? "is-active" : ""}" ${activeTab === "overview" ? "" : 'hidden'}>
            ${specificRuntimePanel}
            <div class="erp-kpi-grid">
              ${erpTiles
                .map(
                  (tile) => `
                    <article class="erp-kpi-card">
                      <span class="small-label">${escapeHtml(tile.label)}</span>
                      <strong>${escapeHtml(tile.value)}</strong>
                      <span class="muted-copy">${escapeHtml(tile.meta)}</span>
                    </article>
                  `,
                )
                .join("")}
            </div>
            <div class="erp-ops-grid">
              <section class="erp-canvas-card">
                <div class="erp-card-head">
                  <div>
                    <span class="small-label">Cadastro operacional</span>
                    <strong>Ficha mestre do módulo</strong>
                  </div>
                  ${rowPill(`Atualizado ${formatTimestamp(data.generated_at_utc)}`, "pill")}
                </div>
                <div class="erp-classic-form">
                  <div class="erp-form-grid">
                    ${formFields
                      .map(
                        ([label, value]) => `
                          <label class="erp-field">
                            <span>${escapeHtml(label)}</span>
                            <input type="text" value="${escapeHtml(value)}" readonly />
                          </label>
                        `,
                      )
                      .join("")}
                  </div>
                  <div class="erp-form-actions">
                    <button type="button" class="secondary-button" data-workspace-action="open-workspace" data-module-code="${escapeHtml(module.code)}">Abrir workspace</button>
                    <button type="button" class="secondary-button" data-workspace-action="jump-docs" data-module-code="${escapeHtml(module.code)}">Docs</button>
                    <button type="button" class="secondary-button" data-workspace-action="jump-ops" data-module-code="${escapeHtml(module.code)}">Operação</button>
                    <button type="button" class="secondary-button" data-copy-path="${escapeHtml(module.paths.readme || module.paths.status || "")}">Copiar caminho</button>
                  </div>
                </div>
              </section>
              <section class="erp-canvas-card">
                <div class="erp-card-head">
                  <div>
                    <span class="small-label">Painel gerencial</span>
                    <strong>Indicadores e tarefas</strong>
                  </div>
                  ${rowPill(`${formatCount(openItems.length)} itens críticos`, openItems.length ? "pill-danger" : "pill-accent")}
                </div>
                <div class="erp-chart-panel">
                  <div class="erp-chart-bars">
                    ${chartSeries.map((item) => `<span style="height:${escapeHtml(item.height)}"></span>`).join("")}
                  </div>
                  <div class="erp-chart-legend">
                    ${chartSeries.map((item) => `<small>${escapeHtml(item.label)}</small>`).join("")}
                  </div>
                  <div class="erp-task-list">
                    ${openItems.slice(0, 4).map((item) => `<div class="erp-task-item">${escapeHtml(item.label)}</div>`).join("") || `<div class="erp-task-item">Sem pendência operacional aberta.</div>`}
                  </div>
                </div>
              </section>
            </div>
          </section>
          <section class="erp-tab-panel ${activeTab === "operations" ? "is-active" : ""}" ${activeTab === "operations" ? "" : 'hidden'}>
            <div class="erp-queue-grid">
              ${queueCards
                .map(
                  (card) => `
                    <article class="erp-queue-card ${escapeHtml(card.tone)}">
                      <span class="small-label">${escapeHtml(card.title)}</span>
                      <strong>${escapeHtml(card.value)}</strong>
                      <span class="muted-copy">${escapeHtml(card.meta)}</span>
                    </article>
                  `,
                )
                .join("")}
            </div>
            <div class="erp-domain-grid">
              ${workspaceSections
                .map(
                  (section) => `
                    <article class="erp-domain-card">
                      <span class="small-label">${escapeHtml(section.title)}</span>
                      <strong>${escapeHtml(module.code)} ${escapeHtml(section.title.toLowerCase())}</strong>
                      <p class="muted-copy">${escapeHtml(section.text)}</p>
                    </article>
                  `,
                )
                .join("")}
            </div>
          </section>
          <section class="erp-tab-panel ${activeTab === "integrations" ? "is-active" : ""}" ${activeTab === "integrations" ? "" : 'hidden'}>
            <div class="erp-subdomain-grid">
              ${subdomainRoutes
                .map(
                  (route) => `
                    <article class="erp-subdomain-card">
                      <span class="small-label">${escapeHtml(route.label)}</span>
                      <strong>${escapeHtml(route.route)}</strong>
                      <p class="muted-copy">${escapeHtml(route.description)}</p>
                    </article>
                  `,
                )
                .join("")}
            </div>
            <div class="erp-action-grid">
              ${workspaceActions
                .map(
                  (item) => `
                    <article class="erp-action-card ${escapeHtml(item.tone)}">
                      <strong>${escapeHtml(item.label)}</strong>
                      <p class="muted-copy">${escapeHtml(item.meta)}</p>
                      <button type="button" class="secondary-button" data-workspace-action="${escapeHtml(item.action)}" data-module-code="${escapeHtml(module.code)}">${escapeHtml(item.label)}</button>
                    </article>
                  `,
                )
                .join("")}
            </div>
          </section>
          <section class="erp-tab-panel ${activeTab === "governance" ? "is-active" : ""}" ${activeTab === "governance" ? "" : 'hidden'}>
            <section class="erp-table-card">
              <div class="erp-card-head">
                <div>
                  <span class="small-label">Grade operacional</span>
                  <strong>Registros do módulo</strong>
                </div>
                ${businessSnapshot ? rowPill(formatMoney(businessSnapshot.inventory_value_brl), "pill-accent") : rowPill("sem valor comercial", "pill")}
              </div>
              <div class="erp-table-wrap">
                <table class="erp-data-table">
                  <thead>
                    <tr>
                      <th>Código</th>
                      <th>Descrição</th>
                      <th>Operações</th>
                      <th>Fila</th>
                      <th>Status</th>
                    </tr>
                  </thead>
                  <tbody>
                    ${ledgerRows
                      .map(
                        (row) => `
                          <tr>
                            <td>${escapeHtml(row.code)}</td>
                            <td>${escapeHtml(row.description)}</td>
                            <td>${escapeHtml(row.ops)}</td>
                            <td>${escapeHtml(row.queue)}</td>
                            <td>${escapeHtml(row.state)}</td>
                          </tr>
                        `,
                      )
                      .join("")}
                  </tbody>
                </table>
              </div>
            </section>
          </section>
        </div>
      </section>
    `;
    const stockOpsBlock =
      module.code === "STOCK"
        ? `
          <section class="detail-block detail-block-wide">
            <h3>Desk de integracoes do STOCK</h3>
            <p class="muted-copy">Este modulo concentra a ativacao de fornecedores, credenciais, webhooks, margens, catalogo e reconciliacao de pedidos.</p>
            <div class="link-row">
              <a href="#settingsSection">Abrir central de APIs</a>
              <a href="#stockIntegrations">Abrir playbooks</a>
              <a href="#financialDashboard">Abrir dashboard financeiro</a>
            </div>
            <div class="pill-row">
              ${rowPill("Mercado Livre", "pill-accent")}
              ${rowPill("Amazon", "pill-accent")}
              ${rowPill("AliExpress", "pill-accent")}
              ${rowPill("Alibaba", "pill-accent")}
              ${rowPill("Magalu", "pill-accent")}
              ${rowPill("CJDropshipping", "pill-accent")}
              ${rowPill("Shopee", "pill-accent")}
            </div>
          </section>
        `
        : "";

    const operationalFailures = data.deployment_summary.top_failures.length
      ? `
          <section class="detail-block detail-block-wide" id="${escapeHtml(ids.ops)}">
            <h3>Pontos de atencao operacional</h3>
            <div class="stack-list">
              ${data.deployment_summary.top_failures
                .map((item) => `<article class="stack-card"><strong>${escapeHtml(item)}</strong></article>`)
                .join("")}
            </div>
            <div class="stats-inline">
              ${rowPill(`${formatCount(data.deployment_summary.failed_checks)} pontos em atencao`, "pill-danger")}
              ${rowPill(`Atualizado ${formatTimestamp(data.deployment_summary.generated_at_utc)}`, "pill-navy")}
            </div>
          </section>
        `
      : `
          <section class="detail-block detail-block-wide" id="${escapeHtml(ids.ops)}">
            <h3>Pendencias operacionais do ambiente</h3>
            <p class="muted-copy">O ultimo relatorio nao expôs falhas criticas para o cockpit.</p>
          </section>
        `;

    elements.detailTitle.textContent = `${String(module.number).padStart(2, "0")} · ${module.name}`;
    elements.detailSubtitle.textContent = `${module.subtitle} | ${module.domain}`;
    elements.detailMeta.innerHTML = [rowPill(`${formatPercent(readiness)} prontidao`, "pill-accent"), rowPill(module.status_label, statusVariant(module.automation_status))].join("");
    elements.detailNav.innerHTML = navItems
      .map(
        (item) =>
          `<a class="detail-anchor" href="#${escapeHtml(item.target)}" data-target="${escapeHtml(item.target)}">${escapeHtml(item.label)}</a>`,
      )
      .join("");

    elements.detailContent.innerHTML = `
      <div class="detail-grid">
        ${erpWorkspaceBlock}
        <section class="detail-block detail-block-wide" id="${escapeHtml(ids.summary)}">
          <h3>Decision snapshot</h3>
          <p class="muted-copy">${escapeHtml(module.description_ptbr)}</p>
          <div class="pill-row">
            ${rowPill(module.tier, "pill-accent")}
            ${rowPill(module.data_home, "pill-navy")}
            ${rowPill(module.status_label, statusVariant(module.automation_status))}
          </div>
          ${progressMarkup(readiness)}
          <div class="summary-grid">
            ${summaryTileMarkup("Prontidao", formatPercent(readiness), "indice composto por checklist e status")}
            ${summaryTileMarkup("Checklist", `${formatCount(module.checklist.done)}/${formatCount(module.checklist.total)}`, "itens concluidos no modulo")}
            ${summaryTileMarkup("Integracoes", formatCount(module.integrates_with.length), "conexoes declaradas no manifesto")}
            ${summaryTileMarkup("Pendencias", formatCount(module.checklist.pending), openItems.length ? "fila residual para fechamento" : "sem fila material aberta")}
          </div>
        </section>

        <section class="detail-block" id="${escapeHtml(ids.management)}">
          <h3>Gestao do modulo</h3>
          <div class="summary-grid compact-summary-grid">
            ${summaryTileMarkup("Acoes admin", formatCount(module.admin_actions.length), "acoes e fluxos publicados")}
            ${summaryTileMarkup("Dependencias", formatCount(module.depends_on.length), "malha de bloqueio e sequenciamento")}
            ${summaryTileMarkup("Integracoes", formatCount(module.integrates_with.length), "contratos declarados no manifesto")}
            ${summaryTileMarkup("Fila aberta", formatCount(openItems.length), openItems.length ? "itens ainda pedem fechamento" : "sem fila material")}
          </div>
          <div class="meta-grid">
            <div class="meta-card">
              <div class="small-label">Acoes administrativas</div>
              <p class="muted-copy">${escapeHtml(formatList(module.admin_actions))}</p>
            </div>
            <div class="meta-card">
              <div class="small-label">Proximo foco</div>
              <p class="muted-copy">${escapeHtml(openItems[0]?.label || "Sem pendencia aberta no checklist atual.")}</p>
            </div>
          </div>
        </section>

        <section class="detail-block" id="${escapeHtml(ids.architecture)}">
          <h3>Arquitetura e acoplamentos</h3>
          <div class="meta-grid">
            <div class="meta-card">
              <div class="small-label">Dependencias</div>
              <p class="muted-copy">${escapeHtml(formatList(module.depends_on))}</p>
            </div>
            <div class="meta-card">
              <div class="small-label">Integracoes</div>
              <p class="muted-copy">${escapeHtml(formatList(module.integrates_with))}</p>
            </div>
            <div class="meta-card">
              <div class="small-label">Data home</div>
              <p class="muted-copy">${escapeHtml(module.data_home)}</p>
            </div>
            <div class="meta-card">
              <div class="small-label">Automation status</div>
              <p class="muted-copy">${escapeHtml(module.status_label)}</p>
            </div>
          </div>
        </section>

        <section class="detail-block" id="${escapeHtml(ids.finance)}">
          <h3>Financeiro e desempenho</h3>
          ${
            businessSnapshot
              ? `
                <div class="meta-grid">
                  <div class="meta-card">
                    <div class="small-label">Valor em estoque</div>
                    <p class="muted-copy">${escapeHtml(formatMoney(businessSnapshot.inventory_value_brl))}</p>
                  </div>
                  <div class="meta-card">
                    <div class="small-label">Margem potencial</div>
                    <p class="muted-copy">${escapeHtml(formatMoney(businessSnapshot.margin_potential_brl))}</p>
                  </div>
                  <div class="meta-card">
                    <div class="small-label">Itens</div>
                    <p class="muted-copy">${escapeHtml(formatCount(businessSnapshot.items_total))}</p>
                  </div>
                  <div class="meta-card">
                    <div class="small-label">Ticket medio</div>
                    <p class="muted-copy">${escapeHtml(formatMoney(businessSnapshot.avg_price_brl))}</p>
                  </div>
                </div>
                <div class="stats-inline">
                  ${rowPill(`${formatCount(businessSnapshot.inventory_units)} unidades`, "pill-accent")}
                  ${rowPill(businessSnapshot.top_item_title || "Sem item lider", "pill-navy")}
                </div>
              `
              : `<p class="muted-copy">Este modulo ainda nao recebeu resumo comercial via catalogo operacional.</p>`
          }
        </section>

        <section class="detail-block">
          <h3>Proximo movimento</h3>
          <div class="stats-inline">
            ${rowPill(`${formatCount(openItems.length)} itens abertos`, openItems.length ? "pill-danger" : "pill-accent")}
            ${rowPill(`${formatCount(module.admin_actions.length)} acoes administrativas`, "pill-navy")}
          </div>
          <div class="checklist-list">
            ${
              openItems.length
                ? openItems
                    .slice(0, 3)
                    .map(
                      (item) => `
                        <div class="check-item">
                          <span class="check-flag">NEXT</span>
                          <span>${escapeHtml(item.label)}</span>
                        </div>
                      `,
                    )
                    .join("")
                : `<div class="check-item done"><span class="check-flag">OK</span><span>Sem item aberto no checklist atual.</span></div>`
            }
          </div>
          <div class="action-row">
            ${(module.admin_actions || []).map((action) => rowPill(action)).join("") || rowPill("Nenhuma acao publicada")}
          </div>
        </section>

        <section class="detail-block detail-block-wide" id="${escapeHtml(ids.checklist)}">
          <h3>Checklist de fechamento</h3>
          <div class="stats-inline">
            ${rowPill(`${formatCount(module.checklist.pending)} pendencias`, module.checklist.pending ? "pill-warn" : "pill-accent")}
            ${rowPill(`${formatCount(openItems.length)} itens abertos`, openItems.length ? "pill-danger" : "pill-accent")}
          </div>
          <div class="checklist-list">${checklistMarkup}</div>
        </section>

        <section class="detail-block" id="${escapeHtml(ids.docs)}">
          <h3>Resumo operacional</h3>
          <p class="muted-copy">${escapeHtml(trimLines(module.docs?.status, 6))}</p>
        </section>

        <section class="detail-block">
          <h3>Orientacao do modulo</h3>
          <p class="muted-copy">${escapeHtml(trimLines(module.docs?.readme, 6))}</p>
        </section>

        <section class="detail-block detail-block-wide">
          <h3>Contrato operacional</h3>
          <p class="muted-copy">${escapeHtml(trimLines(module.docs?.contract, 8))}</p>
        </section>

        <section class="detail-block detail-block-wide">
          <h3>Referencias de negocio</h3>
          <div class="summary-grid">
            ${summaryTileMarkup("Dominio", module.domain, "grupo operacional do modulo")}
            ${summaryTileMarkup("Status", module.status_label, "estado atual da entrega")}
            ${summaryTileMarkup("Dependencias", formatCount(module.depends_on.length), "modulos relacionados")}
            ${summaryTileMarkup("Integracoes", formatCount(module.integrates_with.length), "conexoes de produto")}
          </div>
        </section>

        <section class="detail-block detail-block-wide">
          <h3>Roadmap, contratos e governanca</h3>
          <p class="muted-copy">${escapeHtml(trimLines(data.roadmap?.preview, 6))}</p>
          <p class="muted-copy">${escapeHtml(trimLines(data.governance?.preview, 6))}</p>
          <div class="link-row">
            ${linkMarkup("Abrir roadmap", data.roadmap?.path)}
            ${linkMarkup("Abrir contratos", data.contracts_summary?.path)}
            ${linkMarkup("Abrir norma", data.governance?.path)}
          </div>
        </section>

        ${stockOpsBlock}
        ${operationalFailures}
      </div>
    `;
  }

  function workspacePreviewPalette(index) {
    const palette = ["#3b82f6", "#0ea5e9", "#10b981", "#8b5cf6", "#f59e0b", "#22c55e", "#ef4444", "#f97316"];
    return palette[index % palette.length];
  }

  function previewWorkspaces() {
    return STATIC_ADMIN_WORKSPACES.filter((workspace) => workspace.key !== "home").slice(0, 8);
  }

  function renderHeroWorkspacePreview() {
    if (!elements.desktopWorkspacePreview || !elements.phoneWorkspacePreview || !elements.heroWorkspaceIcons) {
      return;
    }

    const items = previewWorkspaces();
    const desktopMetrics = items.slice(0, 6).map((workspace, index) => `
      <article class="device-metric-card">
        <div class="device-metric-icon" style="background:${workspacePreviewPalette(index)}">${escapeHtml(workspace.title.charAt(0))}</div>
        <strong>${escapeHtml(workspace.title.replace("Painel ", ""))}</strong>
        <span>${escapeHtml(workspace.copy.split(".")[0] || workspace.copy)}</span>
      </article>
    `).join("");
    const desktopMenu = items.slice(0, 7).map((workspace, index) => `
      <div class="device-preview-chip ${index === 0 ? "is-active" : ""}">
        <span class="device-preview-dot" style="background:${workspacePreviewPalette(index)}"></span>
        <span>${escapeHtml(workspace.title.replace("Painel ", ""))}</span>
      </div>
    `).join("");

    elements.desktopWorkspacePreview.innerHTML = `
      <div class="device-dashboard-shell">
        <div class="device-dashboard-main">
          <div class="device-dashboard-toolbar">
            <strong>Bem-vindo ao Valley Admin</strong>
            <div class="device-toolbar-pills">
              <span>Financeiro</span>
              <span>Estoque</span>
              <span>Checkout</span>
            </div>
          </div>
          <div class="device-preview-nav">${desktopMenu}</div>
          <div class="device-metric-grid">${desktopMetrics}</div>
          <div class="device-dashboard-bottom">
            <div class="device-chart-card">
              <span>Receita vs. Operacao</span>
              <div class="device-chart-bars">
                <i style="height:42%"></i>
                <i style="height:78%"></i>
                <i style="height:58%"></i>
                <i style="height:90%"></i>
                <i style="height:66%"></i>
                <i style="height:84%"></i>
              </div>
            </div>
            <div class="device-table-card">
              <span>Fila rapida</span>
              <div class="device-table-row"><b>Revisao</b><em>124</em></div>
              <div class="device-table-row"><b>Integracoes</b><em>07</em></div>
              <div class="device-table-row"><b>Usuarios</b><em>2.4k</em></div>
            </div>
          </div>
        </div>
      </div>
    `;
    elements.phoneWorkspacePreview.innerHTML = items.slice(0, 6).map((workspace, index) => `
      <article class="device-app-tile">
        <div class="device-app-icon" style="background:${workspacePreviewPalette(index)}">${escapeHtml(workspace.title.charAt(0))}</div>
        <span class="device-app-label">${escapeHtml(workspace.title.replace("Painel ", ""))}</span>
      </article>
    `).join("");
    elements.heroWorkspaceIcons.innerHTML = items.slice(0, 4).map((workspace, index) => `
      <article class="hero-workspace-chip">
        <div class="device-app-icon" style="background:${workspacePreviewPalette(index)}">${escapeHtml(workspace.title.charAt(0))}</div>
        <strong>${escapeHtml(workspace.title)}</strong>
        <span class="muted-copy">${escapeHtml(workspace.copy)}</span>
      </article>
    `).join("");
  }

  function loadCheckoutHealth() {
    checkoutHealthState.loading = true;
    checkoutHealthState.error = "";
    renderCheckoutHealth();

    fetch("/api/checkout-health?refresh=1", { headers: { Accept: "application/json" } })
      .then((response) => {
        if (!response.ok) {
          throw new Error(`HTTP ${response.status}`);
        }
        return response.json();
      })
      .then((payload) => {
        checkoutHealthState.payload = payload;
        checkoutHealthState.loading = false;
        renderAdminLaunchpad();
        renderCheckoutHealth();
      })
      .catch((error) => {
        checkoutHealthState.loading = false;
        checkoutHealthState.error = error.message || "Falha ao carregar checkout.";
        renderAdminLaunchpad();
        renderCheckoutHealth();
      });
  }

  function openWorkspaceSurface(moduleCode) {
    const workspace = moduleWorkspaceByCode(moduleCode);
    if (!workspace) {
      announce("Workspace do modulo indisponivel.");
      return;
    }

    window.location.href = workspaceMirrorHref(workspace);
  }

  function runModuleWorkspaceAction(module, action) {
    switch (action) {
      case "open-workspace":
        openWorkspaceSurface(module.code);
        return;
      case "jump-docs":
        document.getElementById(sectionId(module, "docs"))?.scrollIntoView({ behavior: "smooth", block: "start" });
        return;
      case "jump-ops":
        document.getElementById(sectionId(module, "ops"))?.scrollIntoView({ behavior: "smooth", block: "start" });
        return;
      case "jump-checkout":
        document.getElementById("checkoutHealthPanel")?.scrollIntoView({ behavior: "smooth", block: "start" });
        return;
      case "save-integrations":
      case "apply-integrations":
        saveMarketplaceApiConfig().finally(() => {
          loadModuleRuntimeSnapshots();
        });
        return;
      case "reset-integrations":
        resetMarketplaceApiDefaults();
        announce("Configuracao de integracoes resetada para o baseline.");
        return;
      case "save-pricing":
      case "apply-pricing":
        saveImportedPricing().finally(() => {
          loadModuleRuntimeSnapshots();
        });
        return;
      case "reset-pricing":
        resetImportedPricingDefaults();
        announce("Desk de pricing resetado para o baseline local.");
        return;
      case "refresh-checkout":
        loadCheckoutHealth();
        loadModuleRuntimeSnapshots();
        announce("Atualizando saude do checkout.");
        return;
      default:
        announce("Acao do workspace ainda nao mapeada.");
    }
  }

  function runStockTableAction(trigger) {
    const action = String(trigger.dataset.stockAction || "").trim();
    if (!action) {
      return;
    }

    if (action === "filter-supplier") {
      const supplierKey = String(trigger.dataset.supplierKey || "").trim();
      const supplierName = String(trigger.dataset.supplierName || "").trim().toLowerCase();
      if (supplierKey) {
        updateImportedPricingFilter("supplierKey", supplierKey);
      } else if (supplierName) {
        const rows = materializeImportedPricingRows();
        const match = rows.find((row) => String(row.supplier_name || "").trim().toLowerCase() === supplierName);
        if (match?.supplier_key) {
          updateImportedPricingFilter("supplierKey", match.supplier_key);
        }
      }
      document.getElementById("importedPricingSection")?.scrollIntoView({ behavior: "smooth", block: "start" });
      announce("Fornecedor filtrado no desk de pricing.");
      return;
    }

    if (action === "open-pricing") {
      document.getElementById("importedPricingSection")?.scrollIntoView({ behavior: "smooth", block: "start" });
      announce("Desk de pricing aberto.");
      return;
    }

    if (action === "open-review") {
      document.getElementById("publicationReviewSection")?.scrollIntoView({ behavior: "smooth", block: "start" });
      announce("Fila de revisão aberta.");
      return;
    }

    if (action === "copy-item") {
      copyText(String(trigger.dataset.itemId || ""), "ID do item STOCK");
    }
  }

  function renderCheckoutHealth() {
    if (!elements.checkoutHealthPanel) {
      return;
    }

    if (checkoutHealthState.loading) {
      elements.checkoutHealthPanel.innerHTML = `
        <article class="runtime-status-card warn">
          <div class="runtime-header">
            <div>
              <div class="runtime-url">Mercado Pago</div>
              <div class="runtime-copy">Validando credenciais e endpoints do checkout.</div>
            </div>
            ${rowPill("carregando", "pill-warn")}
          </div>
        </article>
      `;
      return;
    }

    if (checkoutHealthState.error) {
      elements.checkoutHealthPanel.innerHTML = `
        <article class="runtime-status-card danger">
          <div class="runtime-header">
            <div>
              <div class="runtime-url">Mercado Pago</div>
              <div class="runtime-copy">${escapeHtml(checkoutHealthState.error)}</div>
            </div>
            ${rowPill("falha", "pill-danger")}
          </div>
        </article>
      `;
      return;
    }

    const payload = checkoutHealthState.payload || {};
    const validation = payload.validation || {};
    const presentCount = [payload.access_token_present, payload.public_key_present, payload.webhook_secret_present].filter(Boolean).length;
    const tone = payload.status === "ready" ? "ok" : payload.status === "partial" ? "warn" : "danger";
    const readinessLabel = payload.checkout_ready ? "operacional" : payload.status === "partial" ? "parcial" : "pendente";
    const validationLabel = validation.status || "nao validado";
    const notificationUrl = payload.notification_url || "";
    const returnUrl = payload.sample_return_url || "";
    const checkoutMode = payload.preferred_environment || "unconfigured";

    elements.checkoutHealthPanel.innerHTML = `
      <article class="runtime-status-card ${escapeHtml(tone)}">
        <div class="runtime-header">
          <div>
            <div class="runtime-url">Mercado Pago Checkout</div>
            <div class="runtime-copy">Checkout Pro do Valley com preferências server-side, retorno e webhook público.</div>
          </div>
          ${rowPill(readinessLabel, tone === "ok" ? "pill-accent" : tone === "warn" ? "pill-warn" : "pill-danger")}
        </div>
        <div class="external-grid">
          ${externalTileMarkup("Checkout", payload.checkout_ready ? "pronto" : "bloqueado", payload.access_token_present ? "access token presente" : "access token ausente")}
          ${externalTileMarkup("Credenciais", `${presentCount}/3`, "token, public key e webhook secret")}
          ${externalTileMarkup("Validação", validationLabel, validation.checked_at_utc ? formatTimestamp(validation.checked_at_utc) : "sem checagem")}
          ${externalTileMarkup("Modo", checkoutMode, payload.sandbox_enabled && payload.production_enabled ? "sandbox e producao ligados" : "ajustar modos do checkout")}
        </div>
        <p class="muted-copy">
          ${escapeHtml(validation.detail || "O backend valida o access token no endpoint oficial do Mercado Pago antes de liberar o checkout próprio.")}
        </p>
        <div class="endpoint-list">
          <div class="endpoint-item">
            <div>
              <strong>notification_url</strong>
              <div class="muted-copy">${escapeHtml(notificationUrl || "endpoint indisponível")}</div>
            </div>
            ${notificationUrl ? linkMarkup("Abrir", notificationUrl) : `<span class="pill">Aguardando</span>`}
          </div>
          <div class="endpoint-item">
            <div>
              <strong>return_url</strong>
              <div class="muted-copy">${escapeHtml(returnUrl || "endpoint indisponível")}</div>
            </div>
            ${returnUrl ? linkMarkup("Abrir", returnUrl) : `<span class="pill">Aguardando</span>`}
          </div>
        </div>
      </article>
    `;
  }

  function render() {
    const modules = filteredModules();

    syncAdminSurfaceWithWorkspace();
    renderAdminSurfaceTabs();
    applyAdminSurfaceTabVisibility();

    renderTopbar(modules);
    renderMetrics(modules);
    renderPrioritySignals(modules);
    renderReleaseSummaryBoard();
    renderCriticalModules();
    renderPublicRuntime();
    renderCheckoutHealth();
    renderTierMatrix(modules);
    renderDataHomeMatrix(modules);
    renderReleaseQueue(modules);
    renderDomainBoard(modules);
    renderCatalogDrivenSections();
    renderFilterMeta(modules);
    renderCommands();
    renderHeroWorkspacePreview();
    renderExternalAccess();
    renderAccessLinks();
    renderAdminLaunchpad();
    renderStitchP0Execution();
    renderMerchantErp();
    renderMarketplaceIntegrations();
    renderImportedPricingDesk();
    renderModuleList(modules);
    renderDetail(modules);
    syncHash();
    scheduleWorkspaceFocus();
  }

  function bootstrapAdminApp() {
    if (appBootstrapped) {
      render();
      return;
    }
    appBootstrapped = true;
    readHashSelection();
    populateFilters();
    bindEvents();
    render();
    loadCatalogSummary();
    loadModuleRuntimeSnapshots();
    loadCheckoutHealth();
    loadMarketplaceApiConfig();
    loadImportedPricing();
  }

  bootstrapAdminGate();
})();
