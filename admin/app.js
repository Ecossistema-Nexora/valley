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

  const allModules = data.modules.slice().sort((left, right) => left.number - right.number);

  const state = {
    search: "",
    tier: "all",
    dataHome: "all",
    status: "all",
    domain: "all",
    selectedCode: null,
  };

  const elements = {
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
    liveRegion: document.getElementById("liveRegion"),
  };

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
    const code = window.location.hash.replace(/^#/, "").trim().toUpperCase();

    if (code && allModules.some((module) => module.code === code)) {
      state.selectedCode = code;
      return;
    }

    state.selectedCode = allModules[0] ? allModules[0].code : null;
  }

  function syncHash() {
    if (!state.selectedCode) {
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

  function bindEvents() {
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
      copyText(data.admin_commands.join("\n"), "Comandos");
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

      const index = Number(trigger.dataset.copyCommand);
      copyText(data.admin_commands[index], `Comando ${index + 1}`);
    });

    elements.externalAccess.addEventListener("click", (event) => {
      const trigger = event.target.closest("[data-copy-external]");

      if (!trigger) {
        return;
      }

      if (trigger.dataset.copyExternal === "preview") {
        copyText(data.public_access.preview, "Runbook externo");
      }

      if (trigger.dataset.copyExternal === "launcher") {
        copyText("powershell -ExecutionPolicy Bypass -File scripts/start_valley_admin_public.ps1", "Launcher publico");
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
      const trigger = event.target.closest("[data-copy-path]");

      if (!trigger) {
        return;
      }

      copyText(trigger.dataset.copyPath, "Caminho do arquivo");
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
    return allModules.filter((module) => {
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

    elements.registryName.textContent = data.registry_name || "Registry sem nome";
    elements.sourceLabel.textContent = `Fonte: ${data.source || "indisponivel"} | Linguagem: ${data.language_policy || "indisponivel"}`;
    elements.generatedAt.textContent = formatTimestamp(data.generated_at_utc);
    elements.reportHealth.textContent = report.available
      ? `${report.failed_checks} pendencias no ultimo status`
      : "Relatorio operacional indisponivel";
    elements.reportHealth.className = reportHealthClass(report);

    elements.heroTags.innerHTML = [
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
    const healthUrl = runtime.smoke_endpoints.healthz || "";
    const adminDataUrl = runtime.smoke_endpoints.admin_data || "";
    const permanence = runtime.permanence || (runtime.public_url ? "nao declarada" : "aguardando runtime");

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
          ${externalTileMarkup("Smoke", healthUrl || adminDataUrl ? "exposto" : "indisponivel", "healthz e admin_data")}
        </div>
        <p class="muted-copy">
          O cockpit ja consome o manifesto de runtime publico quando ele existir. Ate la, o painel continua apontando para o runbook
          e para o arquivo esperado sem bloquear a operacao local.
        </p>
        <div class="endpoint-list">
          <div class="endpoint-item">
            <div>
              <strong>healthz</strong>
              <div class="muted-copy">${escapeHtml(healthUrl || "endpoint ainda nao publicado")}</div>
            </div>
            ${healthUrl ? linkMarkup("Abrir", healthUrl) : `<span class="pill">Aguardando</span>`}
          </div>
          <div class="endpoint-item">
            <div>
              <strong>admin_data</strong>
              <div class="muted-copy">${escapeHtml(adminDataUrl || "endpoint ainda nao publicado")}</div>
            </div>
            ${adminDataUrl ? linkMarkup("Abrir", adminDataUrl) : `<span class="pill">Aguardando</span>`}
          </div>
        </div>
        <div class="runtime-path">
          <span class="small-label">Manifesto esperado</span>
          <code>${escapeHtml(displayPath(runtime.path || "" ) || "tmp\\runtime\\valley-admin-public-runtime.json")}</code>
        </div>
        <div class="link-row">
          ${linkMarkup("Abrir manifesto runtime", runtime.path)}
          ${linkMarkup("Abrir runbook externo", data.public_access.path)}
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
              ${rowPill(`${formatCount(module.checklist.pending)} pendencias`, module.checklist.pending ? "pill-warn" : "pill-accent")}
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
    if (!data.admin_commands.length) {
      elements.commandList.innerHTML = `<div class="empty-state">Nenhum comando administrativo publicado.</div>`;
      return;
    }

    elements.commandList.innerHTML = data.admin_commands
      .map(
        (command, index) => `
          <article class="command-item">
            <code>${escapeHtml(command)}</code>
            <button class="ghost-button" type="button" data-copy-command="${index}">Copiar</button>
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
    const preview = trimLines(data.public_access.preview, 14);
    const ngrokInstalled = /ja esta instalado/i.test(data.public_access.preview || "");
    const reservedDomainReady = /VALLEY_NGROK_ADMIN_DOMAIN/i.test(data.public_access.preview || "");
    const launcherReady = /start_valley_admin_public\.ps1/i.test(data.public_access.preview || "");

    elements.externalAccess.innerHTML = `
      <div class="external-panel">
        <div class="external-grid">
          ${externalTileMarkup("Ngrok", ngrokInstalled ? "detectado" : "nao detectado", "binario e tunnel nomeado")}
          ${externalTileMarkup("Launcher", launcherReady ? "publicavel" : "pendente", "start_valley_admin_public.ps1")}
          ${externalTileMarkup("URL fixa", reservedDomainReady ? "suportada" : "nao descrita", "depende de dominio reservado")}
        </div>
        <p class="muted-copy">
          A superficie externa esta preparada para testes fora da rede local. Quando houver dominio reservado no ngrok, o mesmo cockpit pode
          manter uma URL permanente sem mudar a rotina do operador.
        </p>
        <pre>${escapeHtml(preview)}</pre>
        <div class="link-row">
          ${linkMarkup("Abrir runbook externo", data.public_access.path)}
          ${linkMarkup("Abrir config ngrok", data.public_access.ngrok_config_path)}
        </div>
        <div class="action-row">
          <button class="secondary-button" type="button" data-copy-external="preview">Copiar runbook</button>
          <button class="secondary-button" type="button" data-copy-external="launcher">Copiar launcher</button>
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
      architecture: sectionId(module, "architecture"),
      checklist: sectionId(module, "checklist"),
      docs: sectionId(module, "docs"),
      ops: sectionId(module, "ops"),
    };

    const navItems = [
      { label: "Resumo", target: ids.summary },
      { label: "Acoplamentos", target: ids.architecture },
      { label: "Checklist", target: ids.checklist },
      { label: "Docs", target: ids.docs },
      { label: "Operacao", target: ids.ops },
    ];

    const operationalFailures = data.deployment_summary.top_failures.length
      ? `
          <section class="detail-block detail-block-wide" id="${escapeHtml(ids.ops)}">
            <h3>Pendencias operacionais do ambiente</h3>
            <pre>${escapeHtml(data.deployment_summary.top_failures.join("\n"))}</pre>
            <div class="stats-inline">
              ${rowPill(`${formatCount(data.deployment_summary.failed_checks)} checks falharam`, "pill-danger")}
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
          <h3>Status snapshot</h3>
          <pre>${escapeHtml(trimLines(module.docs?.status, 18))}</pre>
        </section>

        <section class="detail-block">
          <h3>README snapshot</h3>
          <pre>${escapeHtml(trimLines(module.docs?.readme, 18))}</pre>
        </section>

        <section class="detail-block detail-block-wide">
          <h3>Contrato operacional</h3>
          <pre>${escapeHtml(trimLines(module.docs?.contract, 18))}</pre>
        </section>

        <section class="detail-block detail-block-wide">
          <h3>Arquivos do modulo</h3>
          <div class="path-list">
            ${pathItemMarkup("README", module.paths.readme)}
            ${pathItemMarkup("STATUS", module.paths.status)}
            ${pathItemMarkup("CONTRACT", module.paths.contract)}
            ${pathItemMarkup("PASTA", module.paths.module_dir)}
          </div>
        </section>

        <section class="detail-block detail-block-wide">
          <h3>Roadmap, contratos e governanca</h3>
          <pre>${escapeHtml(trimLines(data.roadmap?.preview, 10))}</pre>
          <pre>${escapeHtml(trimLines(data.governance?.preview, 10))}</pre>
          <div class="link-row">
            ${linkMarkup("Abrir roadmap", data.roadmap?.path)}
            ${linkMarkup("Abrir contratos", data.contracts_summary?.path)}
            ${linkMarkup("Abrir norma", data.governance?.path)}
            ${linkMarkup("Manifesto JSON", data.governance?.json_path)}
          </div>
        </section>

        ${operationalFailures}
      </div>
    `;
  }

  function render() {
    const modules = filteredModules();

    renderTopbar(modules);
    renderMetrics(modules);
    renderPrioritySignals(modules);
    renderReleaseSummaryBoard();
    renderCriticalModules();
    renderPublicRuntime();
    renderTierMatrix(modules);
    renderDataHomeMatrix(modules);
    renderReleaseQueue(modules);
    renderDomainBoard(modules);
    renderFilterMeta(modules);
    renderCommands();
    renderExternalAccess();
    renderModuleList(modules);
    renderDetail(modules);
    syncHash();
  }

  readHashSelection();
  populateFilters();
  bindEvents();
  render();
})();
