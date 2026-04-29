const { chromium } = require('playwright');
const path = require('path');

async function clickFirstMatching(page, patterns) {
  for (const pattern of patterns) {
    const candidates = [
      page.getByRole('button', { name: pattern }),
      page.getByRole('link', { name: pattern }),
      page.locator(`text=${pattern.source.replace(/^\//, '').replace(/\/i$/, '')}`),
    ];
    for (const locator of candidates) {
      try {
        const count = await locator.count();
        if (count > 0) {
          await locator.first().click({ timeout: 3000 });
          return String(pattern);
        }
      } catch {
        // continue probing
      }
    }
  }
  return '';
}

async function main() {
  const userDataDir = path.resolve('tmp/chrome-magalu-profile');
  const context = await chromium.launchPersistentContext(userDataDir, {
    channel: 'chrome',
    headless: false,
    viewport: { width: 1440, height: 960 },
    args: ['--disable-blink-features=AutomationControlled'],
  });

  const page = context.pages()[0] || await context.newPage();
  page.on('framenavigated', frame => {
    if (frame === page.mainFrame()) {
      console.log('NAV', frame.url());
    }
  });
  page.on('console', msg => {
    console.log('CONSOLE', msg.type(), msg.text());
  });

  await page.goto('https://admin.brasildesconto.com.br/integrations/magalu/authorize', {
    waitUntil: 'domcontentloaded',
    timeout: 120000,
  });

  const patterns = [
    /autorizar/i,
    /aceitar/i,
    /permitir/i,
    /continuar/i,
    /prosseguir/i,
    /selecionar/i,
    /escolher/i,
    /entrar/i,
  ];

  for (let i = 0; i < 24; i += 1) {
    await page.waitForTimeout(2500);
    const currentUrl = page.url();
    console.log('URL', currentUrl);
    if (currentUrl.includes('/integrations/magalu/callback')) {
      break;
    }
    const clicked = await clickFirstMatching(page, patterns);
    if (clicked) {
      console.log('CLICKED', clicked);
      await page.waitForTimeout(2000);
    }
  }

  console.log('FINAL_URL', page.url());
  try {
    const text = await page.locator('body').innerText({ timeout: 5000 });
    console.log('BODY_START');
    console.log(text.slice(0, 4000));
    console.log('BODY_END');
  } catch (error) {
    console.log('BODY_ERROR', String(error));
  }
  await context.storageState({ path: 'tmp/magalu-playwright-state.json' });
  await context.close();
}

main().catch(error => {
  console.error('MAGALU_AUTOMATION_ERROR', error);
  process.exitCode = 1;
});
