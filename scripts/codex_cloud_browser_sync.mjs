#!/usr/bin/env node
import { chromium } from "playwright";
import fs from "node:fs";
import path from "node:path";

const args = new Map();
for (let index = 2; index < process.argv.length; index += 2) {
  args.set(process.argv[index], process.argv[index + 1]);
}

const repoRoot = process.cwd();
const settingsUrl = args.get("--settings-url") || "https://chatgpt.com/codex/settings";
const envFile = path.resolve(repoRoot, args.get("--env-file") || "tmp/runtime/codex-cloud-secrets.env");
const setupFile = path.resolve(repoRoot, args.get("--setup-file") || "tmp/runtime/codex-cloud-setup.sh");
const profileDir = path.resolve(repoRoot, args.get("--profile-dir") || "tmp/runtime/codex-cloud-browser-profile");

const envText = fs.existsSync(envFile) ? fs.readFileSync(envFile, "utf8") : "";
const setupText = fs.existsSync(setupFile) ? fs.readFileSync(setupFile, "utf8") : "";

if (!envText.trim()) {
  throw new Error(`Missing env file: ${envFile}`);
}

fs.mkdirSync(profileDir, { recursive: true });

const context = await chromium.launchPersistentContext(profileDir, {
  headless: false,
  viewport: { width: 1440, height: 1000 },
});

const page = await context.newPage();
await page.goto(settingsUrl, { waitUntil: "domcontentloaded" });

await page.evaluate(
  ({ envText, setupText }) => {
    const existing = document.getElementById("valley-codex-cloud-sync-panel");
    if (existing) existing.remove();

    const panel = document.createElement("section");
    panel.id = "valley-codex-cloud-sync-panel";
    panel.style.cssText = [
      "position:fixed",
      "right:18px",
      "bottom:18px",
      "z-index:2147483647",
      "width:min(520px,calc(100vw - 36px))",
      "max-height:82vh",
      "overflow:auto",
      "background:#0b1020",
      "color:#f8fafc",
      "border:1px solid rgba(255,255,255,.18)",
      "border-radius:14px",
      "box-shadow:0 24px 80px rgba(0,0,0,.42)",
      "font-family:Inter,Arial,sans-serif",
      "padding:16px",
    ].join(";");

    panel.innerHTML = `
      <div style="display:flex;align-items:center;justify-content:space-between;gap:12px;margin-bottom:10px">
        <strong style="font-size:15px">Valley Codex Cloud Sync</strong>
        <button id="valley-sync-close" style="background:transparent;color:#f8fafc;border:1px solid rgba(255,255,255,.22);border-radius:8px;padding:6px 9px;cursor:pointer">Fechar</button>
      </div>
      <p style="margin:0 0 10px;color:#cbd5e1;font-size:13px;line-height:1.45">
        Use estes blocos nas configurações do ambiente Codex Cloud. Segredos não são exibidos no terminal.
      </p>
      <label style="display:block;margin:10px 0 6px;font-size:12px;color:#93c5fd">Secrets / Environment (.env)</label>
      <textarea id="valley-env-text" style="width:100%;height:190px;background:#020617;color:#e2e8f0;border:1px solid rgba(255,255,255,.16);border-radius:10px;padding:10px;font-size:11px;box-sizing:border-box"></textarea>
      <button id="valley-copy-env" style="margin-top:8px;background:#6F2CFF;color:white;border:0;border-radius:9px;padding:9px 12px;font-weight:700;cursor:pointer">Copiar env completo</button>
      <label style="display:block;margin:14px 0 6px;font-size:12px;color:#93c5fd">Setup script</label>
      <textarea id="valley-setup-text" style="width:100%;height:100px;background:#020617;color:#e2e8f0;border:1px solid rgba(255,255,255,.16);border-radius:10px;padding:10px;font-size:11px;box-sizing:border-box"></textarea>
      <button id="valley-copy-setup" style="margin-top:8px;background:#20C8F3;color:#020617;border:0;border-radius:9px;padding:9px 12px;font-weight:700;cursor:pointer">Copiar setup script</button>
      <div id="valley-copy-status" style="margin-top:10px;color:#a7f3d0;font-size:12px"></div>
    `;

    document.body.appendChild(panel);
    const envBox = document.getElementById("valley-env-text");
    const setupBox = document.getElementById("valley-setup-text");
    const status = document.getElementById("valley-copy-status");
    envBox.value = envText;
    setupBox.value = setupText;

    document.getElementById("valley-sync-close").onclick = () => panel.remove();
    document.getElementById("valley-copy-env").onclick = async () => {
      await navigator.clipboard.writeText(envText);
      status.textContent = "Env completo copiado.";
    };
    document.getElementById("valley-copy-setup").onclick = async () => {
      await navigator.clipboard.writeText(setupText);
      status.textContent = "Setup script copiado.";
    };
  },
  { envText, setupText },
);

console.log(
  JSON.stringify(
    {
      status: "ok",
      opened: settingsUrl,
      envFile,
      setupFile,
      profileDir,
      secretValuesPrinted: false,
    },
    null,
    2,
  ),
);

await page.waitForTimeout(24 * 60 * 60 * 1000);
