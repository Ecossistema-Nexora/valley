(() => {
  const source = window.VALLEY_ADMIN_DATA;
  if (!source || !Array.isArray(source.modules)) return;

  const FALLBACK_STORAGE_KEY = "valley.admin.stock.fallback.v2";
  const modules = [...source.modules].sort((a, b) => a.number - b.number);

  const SUPPLIER_APIS = [
    "Mercado Livre",
    "Amazon",
    "AliExpress",
    "Alibaba",
    "Magalu",
    "CJDropshipping",
    "Shopee",
  ];
  const TRANSPORT_APIS = ["Correios", "Jadlog", "Mandaê", "Loggi", "Melhor Envio"];

  const el = {
    homeView: document.getElementById("homeView"),
    moduleView: document.getElementById("moduleView"),
    moduleButtons: document.getElementById("moduleButtons"),
    serverSummary: document.getElementById("serverSummary"),
    moduleTitle: document.getElementById("moduleTitle"),
    moduleMeta: document.getElementById("moduleMeta"),
    moduleContent: document.getElementById("moduleContent"),
    backHome: document.getElementById("backHome"),
    publishedStatus: document.getElementById("publishedStatus"),
  };

  const statusHealth = source.deployment_summary?.failed_checks ? "Atenção" : "Saudável";
  el.publishedStatus.textContent = `Persistência ativa • Saúde: ${statusHealth}`;

  renderServerSummary();
  renderModuleButtons();

  el.backHome.addEventListener("click", () => {
    window.location.hash = "#/home";
  });

  window.addEventListener("hashchange", syncRoute);
  syncRoute();

  function syncRoute() {
    const hash = window.location.hash || "#/home";
    if (hash === "#/home") {
      showHome();
      return;
    }

    const match = hash.match(/^#\/modulo\/([a-z0-9-]+)/i);
    if (!match) {
      window.location.hash = "#/home";
      return;
    }

    const slug = match[1].toLowerCase();
    const module = modules.find((m) => String(m.slug || "").toLowerCase() === slug);
    if (!module) {
      window.location.hash = "#/home";
      return;
    }

    showModule(module);
  }

  function showHome() {
    el.homeView.classList.add("active");
    el.moduleView.classList.remove("active");
    window.scrollTo({ top: 0, behavior: "smooth" });
  }

  function showModule(module) {
    el.homeView.classList.remove("active");
    el.moduleView.classList.add("active");

    el.moduleTitle.textContent = `${module.number.toString().padStart(2, "0")} • ${module.code} — ${module.name}`;
    el.moduleMeta.textContent = `${module.subtitle} • Domínio: ${module.domain} • Tier: ${module.tier} • Data home: ${module.data_home}`;

    if (module.code === "STOCK") {
      renderStockModule(module);
    } else {
      renderGenericModule(module);
    }

    window.scrollTo({ top: 0, behavior: "smooth" });
  }

  function renderServerSummary() {
    const total = modules.length;
    const done = modules.filter((m) => m.automation_status === "implemented").length;
    const partial = modules.filter((m) => m.automation_status === "implemented_partial").length;
    const failedChecks = Number(source.deployment_summary?.failed_checks || 0);
    const cards = [
      ["Módulos totais", total],
      ["Implementados", done],
      ["Parcialmente implantados", partial],
      ["Falhas de deploy", failedChecks],
      ["Runtime público", source.public_runtime?.available ? "Online" : "Pendente"],
      ["Persistência", "Banco local (SQLite) + fallback local"],
    ];

    el.serverSummary.innerHTML = cards
      .map(([label, value]) => `<article class="kpi-card"><p>${label}</p><strong>${value}</strong></article>`)
      .join("");
  }

  function renderModuleButtons() {
    el.moduleButtons.innerHTML = modules
      .map(
        (m) => `
        <button class="module-btn" type="button" data-slug="${m.slug}" aria-label="Abrir módulo ${m.code}">
          <span class="mod-code">${m.code}</span>
          <span class="mod-name">${m.name}</span>
          <span class="mod-meta">${m.status_label}</span>
        </button>
      `,
      )
      .join("");

    el.moduleButtons.querySelectorAll(".module-btn").forEach((btn) => {
      btn.addEventListener("click", () => {
        window.location.hash = `#/modulo/${btn.dataset.slug}`;
      });
    });
  }

  function renderGenericModule(module) {
    const checklistItems = (module.checklist?.items || [])
      .map((item) => `<li>${item.done ? "✅" : "⬜"} ${item.label}</li>`)
      .join("");
    const actions = (module.admin_actions || []).map((a) => `<li>${a}</li>`).join("");

    el.moduleContent.innerHTML = `
      <div class="panel">
        <h3>Visão geral</h3>
        <p>${module.description_ptbr}</p>
      </div>
      <div class="panel split">
        <article>
          <h3>Checklist operacional</h3>
          <ul>${checklistItems || "<li>Sem itens cadastrados.</li>"}</ul>
        </article>
        <article>
          <h3>Ações administrativas</h3>
          <ul>${actions || "<li>Sem ações cadastradas.</li>"}</ul>
        </article>
      </div>
    `;
  }

  async function renderStockModule(module) {
    const categories = [
      ["Eletrônicos", 1284, "9.2%"],
      ["Casa e Cozinha", 902, "7.7%"],
      ["Moda", 1450, "6.1%"],
      ["Saúde e Beleza", 756, "8.4%"],
    ];

    const metrics = [
      ["Vendas (30 dias)", "R$ 2.480.000"],
      ["Entregas concluídas", "18.942"],
      ["Região com maior volume", "Sudeste (54%)"],
      ["Produto com maior volume", "Fone BT X200"],
      ["Produto mais lucrativo", "Cadeira Office Pro"],
    ];

    const steps = [
      "Criar credenciais de API no portal do fornecedor/transportadora (Client ID, Secret e callback).",
      "Registrar webhook para pedido, catálogo e tracking.",
      "No painel, mapear categoria, tenant, canal e transportadora por região.",
      "Executar sincronização inicial do catálogo e validar margem/pricing.",
      "Ativar rotina de importação + tracking contínuo e monitorar jobs com erro.",
    ];

    el.moduleContent.innerHTML = `
      <div class="panel">
        <h3>Stock • Relatórios e Operação</h3>
        <div class="kpi-grid">
          ${metrics.map(([l, v]) => `<article class="kpi-card"><p>${l}</p><strong>${v}</strong></article>`).join("")}
        </div>
      </div>

      <div class="panel responsive-table">
        <h3>Categorias de Itens</h3>
        <table>
          <thead><tr><th>Categoria</th><th>Itens ativos</th><th>Margem média</th></tr></thead>
          <tbody>
            ${categories.map((r) => `<tr><td>${r[0]}</td><td>${r[1]}</td><td>${r[2]}</td></tr>`).join("")}
          </tbody>
        </table>
      </div>

      <div class="panel split">
        <article>
          <h3>Fornecedores (API)</h3>
          <div class="chip-grid">${SUPPLIER_APIS.map((name) => `<label class="chip"><input type="checkbox" data-provider="${name}"> ${name}</label>`).join("")}</div>
        </article>
        <article>
          <h3>Transporte e Remessa (API)</h3>
          <div class="chip-grid">${TRANSPORT_APIS.map((name) => `<label class="chip"><input type="checkbox" data-transporter="${name}"> ${name}</label>`).join("")}</div>
        </article>
      </div>

      <div class="panel">
        <h3>Passo a passo de integração</h3>
        <ol>${steps.map((step, i) => `<li><strong>${i + 1}.</strong> ${step}</li>`).join("")}</ol>
      </div>

      <div class="panel split">
        <article>
          <h3>Importação massiva de catálogos</h3>
          <label>URL do feed (JSON)
            <input id="stockFeedUrl" type="url" placeholder="https://fornecedor.com/catalogo.json" />
          </label>
          <label>Observações
            <textarea id="stockNotes" rows="4" placeholder="Mapeamento de colunas, margens e validações"></textarea>
          </label>
          <div class="btn-row">
            <button id="saveStockConfig" class="action-btn" type="button">Salvar configuração</button>
            <button id="runStockImport" class="action-btn" type="button">Importar catálogo</button>
          </div>
          <p class="muted" id="stockFeedback">Persistência principal em SQLite via API do servidor admin.</p>
        </article>
        <article>
          <h3>Status do módulo</h3>
          <p>${module.description_ptbr}</p>
          <ul>${(module.admin_actions || []).map((a) => `<li>${a}</li>`).join("")}</ul>
        </article>
      </div>

      <div class="panel">
        <h3>Histórico de importações</h3>
        <div id="stockImportHistory" class="import-history"></div>
      </div>
    `;

    hydrateStockScreen();
  }

  async function hydrateStockScreen() {
    const feed = document.getElementById("stockFeedUrl");
    const notes = document.getElementById("stockNotes");
    const feedback = document.getElementById("stockFeedback");
    const saveBtn = document.getElementById("saveStockConfig");
    const importBtn = document.getElementById("runStockImport");

    const defaults = await fetchStockConfig();
    feed.value = defaults.feed_url || "";
    notes.value = defaults.notes || "";

    document.querySelectorAll("[data-provider]").forEach((input) => {
      input.checked = (defaults.providers || []).includes(input.dataset.provider);
    });
    document.querySelectorAll("[data-transporter]").forEach((input) => {
      input.checked = (defaults.transporters || []).includes(input.dataset.transporter);
    });

    saveBtn?.addEventListener("click", async () => {
      const payload = getStockPayload();
      const response = await postJson("/api/stock/config", payload);
      if (response?.status === "ok") {
        feedback.textContent = `Configuração salva no banco em ${response.saved_at_utc}.`;
      } else {
        saveFallback(payload);
        feedback.textContent = "Falha no banco: salvo em fallback local no navegador.";
      }
    });

    importBtn?.addEventListener("click", async () => {
      const payload = getStockPayload();
      const response = await postJson("/api/stock/import", payload);
      if (response?.status === "completed") {
        feedback.textContent = `Importação concluída: ${response.job.imported_items} itens.`;
      } else {
        feedback.textContent = `Importação não concluída: ${response?.message || "erro desconhecido"}.`;
      }
      renderImportHistory();
    });

    renderImportHistory();

    function getStockPayload() {
      return {
        feed_url: feed.value.trim(),
        notes: notes.value.trim(),
        providers: [...document.querySelectorAll("[data-provider]:checked")].map((i) => i.dataset.provider),
        transporters: [...document.querySelectorAll("[data-transporter]:checked")].map((i) => i.dataset.transporter),
      };
    }
  }

  async function renderImportHistory() {
    const historyEl = document.getElementById("stockImportHistory");
    if (!historyEl) return;

    const response = await getJson("/api/stock/imports");
    const items = response?.items || [];

    historyEl.innerHTML = items.length
      ? items
          .map(
            (item) => `<article class="history-item"><strong>#${item.id} • ${item.status}</strong><p>${item.feed_url}</p><small>${item.imported_items} itens • ${item.created_at_utc}</small></article>`,
          )
          .join("")
      : "<p class='muted'>Nenhuma importação registrada.</p>";
  }

  async function fetchStockConfig() {
    const remote = await getJson("/api/stock/config");
    if (remote?.config) return remote.config;

    try {
      return JSON.parse(localStorage.getItem(FALLBACK_STORAGE_KEY) || "{}");
    } catch {
      return {};
    }
  }

  function saveFallback(payload) {
    localStorage.setItem(FALLBACK_STORAGE_KEY, JSON.stringify(payload));
  }

  async function getJson(url) {
    try {
      const response = await fetch(url, { headers: { Accept: "application/json" } });
      if (!response.ok) return null;
      return await response.json();
    } catch {
      return null;
    }
  }

  async function postJson(url, payload) {
    try {
      const response = await fetch(url, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
      });
      return await response.json();
    } catch {
      return null;
    }
  }
})();
