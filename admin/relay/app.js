(function () {
  const state = {
    filter: "ALL",
    productShell: null,
    bridgeStatus: null,
    checks: [],
    events: [],
  };

  const elements = {
    refreshButton: document.getElementById("refreshButton"),
    copyButton: document.getElementById("copyButton"),
    runChecksButton: document.getElementById("runChecksButton"),
    pulseButton: document.getElementById("pulseButton"),
    publicUrlLabel: document.getElementById("publicUrlLabel"),
    runtimeSummary: document.getElementById("runtimeSummary"),
    providerLabel: document.getElementById("providerLabel"),
    temporaryLabel: document.getElementById("temporaryLabel"),
    telegramLabel: document.getElementById("telegramLabel"),
    checksList: document.getElementById("checksList"),
    bridgeStatus: document.getElementById("bridgeStatus"),
    moduleCards: document.getElementById("moduleCards"),
    moduleFilter: document.getElementById("moduleFilter"),
    eventLog: document.getElementById("eventLog"),
    checkItemTemplate: document.getElementById("checkItemTemplate"),
    moduleCardTemplate: document.getElementById("moduleCardTemplate"),
  };

  async function readJson(path, method = "GET") {
    const response = await fetch(path, {
      method,
      headers: { "Content-Type": "application/json" },
    });

    const text = await response.text();
    let payload = {};
    try {
      payload = text ? JSON.parse(text) : {};
    } catch (error) {
      payload = { raw: text };
    }

    if (!response.ok) {
      throw new Error(payload.message || payload.stderr || response.statusText);
    }

    return payload;
  }

  function logEvent(title) {
    state.events.unshift({
      title,
      at: new Date().toLocaleTimeString("pt-BR"),
    });
    state.events = state.events.slice(0, 14);
    renderEvents();
  }

  function runtimeSummary(runtime, bridge) {
    const provider = runtime?.provider || "sem provider";
    const temporary = runtime?.temporary ? "temporario" : "estavel";
    const telegram = bridge?.telegram_ready ? "Telegram pronto" : "Telegram indisponivel";
    return `${provider} em modo ${temporary}. ${telegram}.`;
  }

  function renderHero() {
    const runtime = state.productShell?.public_runtime || {};
    const bridge = state.bridgeStatus || {};
    const externalUrl = runtime.public_url || "Sem URL externa ativa";

    elements.publicUrlLabel.textContent = externalUrl;
    elements.runtimeSummary.textContent = runtimeSummary(runtime, bridge);
    elements.providerLabel.textContent = runtime.provider || "desconhecido";
    elements.temporaryLabel.textContent = runtime.temporary ? "Quick Tunnel" : "Persistente";
    elements.telegramLabel.textContent = bridge.telegram_ready ? "Pronto" : "Indisponivel";
  }

  function createPill(statusText, tone) {
    const pill = document.createElement("span");
    pill.className = `pill ${tone}`;
    pill.textContent = statusText;
    return pill;
  }

  function renderChecks() {
    elements.checksList.innerHTML = "";
    state.checks.forEach((item) => {
      const node = elements.checkItemTemplate.content.firstElementChild.cloneNode(true);
      node.querySelector(".check-name").textContent = item.name;
      node.querySelector(".check-detail").textContent = item.detail;
      const pill = node.querySelector(".pill");
      pill.textContent = item.status;
      pill.className = `pill ${item.tone}`;
      elements.checksList.appendChild(node);
    });
  }

  function renderBridge() {
    const bridge = state.bridgeStatus || {};
    const rows = [
      ["Modo", bridge.mode || "sem leitura"],
      ["Fila Telegram", bridge.telegram_queue || "sem leitura"],
      ["Fila universal", bridge.universal_queue || "sem leitura"],
      ["Telegram", bridge.telegram_ready ? "pronto" : "nao pronto"],
      ["WhatsApp", bridge.whatsapp_ready ? "pronto" : "nao pronto"],
      ["Auto aprovacao", bridge.unrestricted_auto_approval ? "aberta" : "safe_only"],
    ];

    elements.bridgeStatus.innerHTML = "";
    rows.forEach(([key, value]) => {
      const row = document.createElement("div");
      row.className = "stack-row";
      row.innerHTML = `<span class="stack-key">${key}</span><strong class="stack-value">${value}</strong>`;
      elements.bridgeStatus.appendChild(row);
    });
  }

  function currentModules() {
    const modules = state.productShell?.module_screens || [];
    if (state.filter === "ALL") {
      return modules;
    }
    return modules.filter((item) => item.module_id === state.filter);
  }

  function renderFilters() {
    const screens = state.productShell?.module_screens || [];
    const options = [{ id: "ALL", label: "Todos" }].concat(
      screens.map((item) => ({
        id: item.module_id,
        label: item.module_id,
      })),
    );

    const seen = new Set();
    elements.moduleFilter.innerHTML = "";
    options.forEach((option) => {
      if (seen.has(option.id)) {
        return;
      }
      seen.add(option.id);
      const button = document.createElement("button");
      button.type = "button";
      button.textContent = option.label;
      if (option.id === state.filter) {
        button.classList.add("active");
      }
      button.addEventListener("click", () => {
        state.filter = option.id;
        renderFilters();
        renderModules();
        logEvent(`Filtro alterado para ${option.label}.`);
      });
      elements.moduleFilter.appendChild(button);
    });
  }

  function renderModules() {
    const modules = currentModules();
    elements.moduleCards.innerHTML = "";

    modules.forEach((module) => {
      const node = elements.moduleCardTemplate.content.firstElementChild.cloneNode(true);
      node.querySelector(".module-badge").textContent = module.tier || "core";
      node.querySelector(".module-id").textContent = module.module_id;
      node.querySelector(".module-title").textContent = module.hero_title || module.module_id;
      node.querySelector(".module-text").textContent =
        module.hero_subtitle || module.description || "Sem descricao.";
      node.querySelector(".module-domain").textContent = module.domain || "domain";
      node.querySelector(".module-action").addEventListener("click", () => {
        logEvent(`Teste registrado para ${module.module_id}.`);
      });
      elements.moduleCards.appendChild(node);
    });
  }

  function renderEvents() {
    elements.eventLog.innerHTML = "";
    state.events.forEach((item) => {
      const article = document.createElement("article");
      article.className = "event-item";
      article.innerHTML = `<p class="event-time">${item.at}</p><p class="event-title">${item.title}</p>`;
      elements.eventLog.appendChild(article);
    });
  }

  async function runChecks() {
    const checks = [];
    try {
      const health = await readJson("/healthz");
      checks.push({
        name: "Health local",
        detail: `${health.service || "servico"} respondeu em ${window.location.origin}/healthz`,
        status: "ok",
        tone: "ok",
      });
    } catch (error) {
      checks.push({
        name: "Health local",
        detail: error.message,
        status: "falhou",
        tone: "danger",
      });
    }

    const runtime = state.productShell?.public_runtime || {};
    checks.push({
      name: "Runtime publico",
      detail: runtime.public_api_url || "sem endpoint externo lido",
      status: runtime.public_api_url ? "ativo" : "sem link",
      tone: runtime.public_api_url ? "ok" : "warn",
    });

    checks.push({
      name: "Bridge Telegram",
      detail: state.bridgeStatus?.telegram_ready
        ? "Bridge apto para entrega"
        : "Bridge sem entrega",
      status: state.bridgeStatus?.telegram_ready ? "pronto" : "pendente",
      tone: state.bridgeStatus?.telegram_ready ? "ok" : "warn",
    });

    state.checks = checks;
    renderChecks();
    logEvent("Checks executados.");
  }

  async function loadRuntime() {
    const [productShell, bridgeStatus] = await Promise.all([
      readJson("/api/product-shell"),
      readJson("/api/bridge/status"),
    ]);

    state.productShell = productShell;
    state.bridgeStatus = bridgeStatus;
    renderHero();
    renderBridge();
    renderFilters();
    renderModules();
    await runChecks();
    logEvent("Runtime atualizado.");
  }

  async function pulseTelegram() {
    try {
      const payload = await readJson("/api/actions/pulse-telegram", "POST");
      const status = payload?.payload?.delivered?.telegram ? "entregue" : "sem entrega";
      logEvent(`Pulse Telegram executado: ${status}.`);
    } catch (error) {
      logEvent(`Pulse Telegram falhou: ${error.message}`);
    }
  }

  async function copyExternalUrl() {
    const publicUrl = state.productShell?.public_runtime?.public_url;
    if (!publicUrl) {
      logEvent("Nenhuma URL externa disponivel para copiar.");
      return;
    }

    try {
      await navigator.clipboard.writeText(`${publicUrl}/relay/`);
      logEvent("URL externa copiada para a area de transferencia.");
    } catch (error) {
      logEvent(`Falha ao copiar URL: ${error.message}`);
    }
  }

  elements.refreshButton.addEventListener("click", () => {
    loadRuntime().catch((error) => {
      logEvent(`Atualizacao falhou: ${error.message}`);
    });
  });

  elements.copyButton.addEventListener("click", copyExternalUrl);
  elements.runChecksButton.addEventListener("click", () => {
    runChecks().catch((error) => {
      logEvent(`Checks falharam: ${error.message}`);
    });
  });
  elements.pulseButton.addEventListener("click", pulseTelegram);

  loadRuntime().catch((error) => {
    state.checks = [
      {
        name: "Bootstrap",
        detail: error.message,
        status: "falhou",
        tone: "danger",
      },
    ];
    renderChecks();
    logEvent(`Bootstrap falhou: ${error.message}`);
  });
})();
