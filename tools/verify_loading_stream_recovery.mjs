// Verify: partial WASM response failure offers retry; retry boots, unrelated errors stay visible.
// URL=http://127.0.0.1:8074/ NODE_PATH=... node tools/verify_loading_stream_recovery.mjs
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { mkdir } from 'node:fs/promises';
import { resolve } from 'node:path';
const { chromium } = createRequire(import.meta.url)('playwright');
const browser = await chromium.launch({ headless: true, executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome' });
const out = resolve('artifacts/stream-recovery');
await mkdir(out, { recursive: true });
try {
  for (const mobile of [false, true]) {
    const ctx = await browser.newContext({ viewport: mobile ? { width: 390, height: 844 } : { width: 1440, height: 900 }, isMobile: mobile, hasTouch: mobile });
    const page = await ctx.newPage(), errors = [];
    page.on('pageerror', e => errors.push(e.message));
    page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
    await page.addInitScript(() => {
      const original = window.fetch;
      window.fetch = async function (...args) {
        const response = await original.apply(this, args);
        if (!String(args[0]).endsWith('.wasm') || sessionStorage.getItem('stream-failed-once')) return response;
        sessionStorage.setItem('stream-failed-once', 'yes');
        localStorage.setItem('recovery-storage-sentinel', 'keep');
        const reader = response.body.getReader();
        return new Response(new ReadableStream({
          async start(controller) {
            const first = await reader.read();
            if (first.value) controller.enqueue(first.value);
            await reader.cancel();
            controller.error(new TypeError('network error'));
          },
        }), { status: 200, headers: response.headers });
      };
    });
    try {
      await page.goto(process.env.URL || 'http://127.0.0.1:8074/', { waitUntil: 'domcontentloaded' });
      await page.locator('#intro-retry').waitFor({ state: 'visible', timeout: 30000 });
      assert.match(await page.locator('#status-detail').textContent(), /下载中断/);
      assert.equal(await page.locator('#intro-enter').isDisabled(), true);
      await page.locator('#intro-show-lore').click();
      await page.locator('#intro-lore-next').click();
      assert.match(await page.locator('#intro-lore-title').textContent(), /三只兔子/);
      await page.screenshot({ path: resolve(out, `${mobile ? 'phone' : 'desktop'}-interrupted.png`) });
      await page.locator('#intro-retry').click();
      await page.waitForFunction(() => document.getElementById('intro-enter')?.disabled === false, null, { timeout: 60000 });
      assert.equal(await page.evaluate(() => localStorage.getItem('recovery-storage-sentinel')), 'keep');
      // A transport rejection after readiness must not turn a live game into a loading failure.
      assert.equal(await page.evaluate(() => window.dispatchEvent(new PromiseRejectionEvent('unhandledrejection', { reason: new TypeError('network error'), promise: Promise.resolve(), cancelable: true }))), true);
      assert.equal(await page.locator('#intro-enter').isDisabled(), false);
      await page.locator('#intro-enter').click();
      await page.waitForFunction(() => !document.getElementById('status'));
      assert.deepEqual(errors, [], 'recognized loading transport rejection is handled');
      console.log(`${mobile ? 'phone' : 'desktop'}: partial WASM failure, lore, retry, storage and boot passed`);
    } finally { await ctx.close(); }
  }
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  let release; const gate = new Promise(resolve => { release = resolve; });
  await page.route('**/*.wasm', async route => { await gate; await route.abort().catch(() => {}); });
  try {
    await page.goto(process.env.URL || 'http://127.0.0.1:8074/', { waitUntil: 'domcontentloaded' });
    assert.equal(await page.evaluate(() => window.dispatchEvent(new PromiseRejectionEvent('unhandledrejection', { reason: new Error('application bug'), promise: Promise.resolve(), cancelable: true }))), true, 'unrelated errors are not suppressed');
    assert.equal(await page.locator('#intro-retry').isVisible(), false);
    console.log('Unrelated application errors remain visible to normal error handling');
  } finally { release(); await ctx.close(); }
} finally { await browser.close(); }
