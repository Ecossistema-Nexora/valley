#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const RUNTIME_DIR = path.join(ROOT, 'tmp', 'runtime');
const DEFAULT_PROFILE_DIR = path.join(RUNTIME_DIR, 'whatsapp-web-profile');
const STATUS_PATH = path.join(RUNTIME_DIR, 'whatsapp-web-status.json');

function ensureRuntime() {
  fs.mkdirSync(RUNTIME_DIR, { recursive: true });
}

function boolEnv(name, defaultValue = false) {
  const value = process.env[name];
  if (value === undefined || value === '') return defaultValue;
  return ['1', 'true', 'yes', 'on'].includes(value.toLowerCase());
}

function profileDir() {
  const configured = process.env.VALLEY_WHATSAPP_WEB_PROFILE_DIR || DEFAULT_PROFILE_DIR;
  return path.isAbsolute(configured) ? configured : path.join(ROOT, configured);
}

function normalizePhone(raw) {
  return String(raw || '').replace(/[^\d]/g, '');
}

function writeStatus(data) {
  ensureRuntime();
  fs.writeFileSync(STATUS_PATH, JSON.stringify({
    generated_at_utc: new Date().toISOString(),
    mode: 'web',
    ...data,
  }, null, 2), 'utf8');
}

async function launchContext() {
  const { chromium } = require('playwright');
  const channels = [];
  const preferred = process.env.VALLEY_WHATSAPP_WEB_BROWSER || 'msedge';
  if (preferred && preferred !== 'bundled') channels.push(preferred);
  for (const candidate of ['msedge', 'chrome']) {
    if (!channels.includes(candidate)) channels.push(candidate);
  }
  channels.push(undefined);

  const optionsBase = {
    headless: boolEnv('VALLEY_WHATSAPP_WEB_HEADLESS', false),
    viewport: { width: 1365, height: 900 },
    args: ['--disable-dev-shm-usage'],
  };

  let lastError;
  for (const channel of channels) {
    try {
      return await chromium.launchPersistentContext(profileDir(), {
        ...optionsBase,
        ...(channel ? { channel } : {}),
      });
    } catch (error) {
      lastError = error;
    }
  }

  throw lastError;
}

async function firstPage(context) {
  return context.pages()[0] || await context.newPage();
}

async function chatListVisible(page) {
  const selectors = [
    '#pane-side',
    '[data-testid="chat-list"]',
    '[aria-label*="Chat list"]',
    '[aria-label*="Lista de conversas"]',
  ];
  for (const selector of selectors) {
    if (await page.locator(selector).count().catch(() => 0)) return true;
  }
  return false;
}

async function waitForLogin(page, timeoutMs) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    if (await chatListVisible(page)) return true;
    await page.waitForTimeout(2000);
  }
  return false;
}

async function openWhatsapp(page) {
  await page.goto('https://web.whatsapp.com/', { waitUntil: 'domcontentloaded', timeout: 60000 });
}

async function login() {
  ensureRuntime();
  const context = await launchContext();
  try {
    const page = await firstPage(context);
    await openWhatsapp(page);
    console.log('WhatsApp Web aberto. Faca login no navegador usando numero de telefone ou QR Code.');
    const ok = await waitForLogin(page, Number(process.env.VALLEY_WHATSAPP_WEB_LOGIN_TIMEOUT_MS || 900000));
    writeStatus({
      logged_in: ok,
      profile_dir: profileDir(),
      detail: ok ? 'sessao autenticada' : 'login nao confirmado no tempo limite',
    });
    return ok ? 0 : 2;
  } finally {
    await context.close();
  }
}

async function status() {
  ensureRuntime();
  const context = await launchContext();
  try {
    const page = await firstPage(context);
    await openWhatsapp(page);
    const ok = await waitForLogin(page, 15000);
    const payload = {
      logged_in: ok,
      profile_dir: profileDir(),
      target_configured: Boolean(normalizePhone(process.env.VALLEY_WHATSAPP_WEB_TO || process.env.VALLEY_WHATSAPP_TO)),
    };
    writeStatus(payload);
    console.log(JSON.stringify(payload, null, 2));
    return ok ? 0 : 2;
  } finally {
    await context.close();
  }
}

async function clickSend(page) {
  const sendSelectors = [
    'button[aria-label="Send"]',
    'button[aria-label="Enviar"]',
    'span[data-icon="send"]',
    '[data-testid="send"]',
  ];
  for (const selector of sendSelectors) {
    const locator = page.locator(selector).last();
    if (await locator.count().catch(() => 0)) {
      await locator.click({ timeout: 10000 });
      return true;
    }
  }
  return false;
}

async function send() {
  const phone = normalizePhone(process.env.VALLEY_WHATSAPP_WEB_TO || process.env.VALLEY_WHATSAPP_TO);
  const message = process.env.VALLEY_WHATSAPP_WEB_MESSAGE || '';
  if (!phone) {
    console.error('VALLEY_WHATSAPP_WEB_TO nao configurado.');
    return 2;
  }
  if (!message.trim()) {
    console.error('VALLEY_WHATSAPP_WEB_MESSAGE vazio.');
    return 2;
  }

  ensureRuntime();
  const context = await launchContext();
  try {
    const page = await firstPage(context);
    const url = `https://web.whatsapp.com/send?phone=${encodeURIComponent(phone)}&text=${encodeURIComponent(message)}`;
    await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 60000 });

    const loggedIn = await waitForLogin(page, 60000);
    if (!loggedIn) {
      writeStatus({ logged_in: false, last_send: 'login_required', profile_dir: profileDir() });
      console.error('WhatsApp Web ainda nao esta autenticado. Execute whatsapp-login primeiro.');
      return 3;
    }

    await page.waitForTimeout(3000);
    const sent = await clickSend(page);
    if (!sent) {
      const box = page.locator('footer div[contenteditable="true"][role="textbox"], div[contenteditable="true"][role="textbox"]').last();
      if (await box.count().catch(() => 0)) {
        await box.click();
        await page.keyboard.insertText(message);
        await page.keyboard.press('Enter');
      } else {
        writeStatus({ logged_in: true, last_send: 'send_box_not_found', profile_dir: profileDir() });
        console.error('Campo de envio do WhatsApp Web nao foi localizado.');
        return 4;
      }
    }

    await page.waitForTimeout(2000);
    writeStatus({ logged_in: true, last_send: 'sent', profile_dir: profileDir() });
    return 0;
  } finally {
    await context.close();
  }
}

function messageFingerprint(text, index) {
  return `${index}:${Buffer.from(text).toString('base64')}`;
}

async function poll() {
  const phone = normalizePhone(process.env.VALLEY_WHATSAPP_WEB_TO || process.env.VALLEY_WHATSAPP_TO);
  if (!phone) {
    console.error('VALLEY_WHATSAPP_WEB_TO nao configurado.');
    return 2;
  }

  ensureRuntime();
  const statePath = path.join(RUNTIME_DIR, 'whatsapp-web-offset.json');
  const previous = fs.existsSync(statePath) ? JSON.parse(fs.readFileSync(statePath, 'utf8')) : {};
  const context = await launchContext();

  try {
    const page = await firstPage(context);
    const url = `https://web.whatsapp.com/send?phone=${encodeURIComponent(phone)}`;
    await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 60000 });

    const loggedIn = await waitForLogin(page, 60000);
    if (!loggedIn) {
      writeStatus({ logged_in: false, last_poll: 'login_required', profile_dir: profileDir() });
      console.error('WhatsApp Web ainda nao esta autenticado. Execute whatsapp-login primeiro.');
      return 3;
    }

    await page.waitForTimeout(3000);
    const incoming = await page.evaluate(() => {
      const nodes = Array.from(document.querySelectorAll('div.message-in span.selectable-text, div.message-in [dir="ltr"], div.message-in [dir="auto"]'));
      return nodes
        .map((node) => (node.innerText || node.textContent || '').trim())
        .filter((text, index, list) => text && list.indexOf(text) === index);
    });

    const fingerprints = incoming.map((text, index) => messageFingerprint(text, index));
    const lastSeen = previous.last_seen || null;
    const lastSeenIndex = lastSeen ? fingerprints.indexOf(lastSeen) : -1;
    const startIndex = lastSeenIndex >= 0 ? lastSeenIndex + 1 : Math.max(0, incoming.length - Number(process.env.VALLEY_WHATSAPP_WEB_BOOTSTRAP_TAIL || 0));
    const messages = incoming.slice(startIndex);
    const newLastSeen = fingerprints.length ? fingerprints[fingerprints.length - 1] : lastSeen;

    fs.writeFileSync(statePath, JSON.stringify({ last_seen: newLastSeen, count: incoming.length }, null, 2), 'utf8');
    writeStatus({ logged_in: true, last_poll: 'ok', incoming_count: incoming.length, new_messages: messages.length, profile_dir: profileDir() });
    console.log(JSON.stringify({ messages }, null, 2));
    return 0;
  } finally {
    await context.close();
  }
}

async function main() {
  const command = process.argv[2] || 'status';
  if (command === 'login') return login();
  if (command === 'status') return status();
  if (command === 'send') return send();
  if (command === 'poll') return poll();
  console.error(`Comando invalido: ${command}`);
  return 64;
}

main()
  .then((code) => process.exit(code))
  .catch((error) => {
    writeStatus({ error: String(error && error.message ? error.message : error) });
    console.error(error);
    process.exit(1);
  });
