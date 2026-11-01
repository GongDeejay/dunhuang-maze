// Measure cold/warm navigation, transfer, streaming WASM instantiation and engine readiness.
// URL=https://maze.mplusm.site/ OUTPUT=/tmp/startup.json NODE_PATH=... node tools/measure_web_startup.mjs
import { createRequire } from 'node:module';
import { writeFile, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
const { chromium } = createRequire(import.meta.url)('playwright');
const results = [];
for (let trial = 0; trial < Number(process.env.TRIALS || 2); trial++) {
  // A temporary regular profile exercises the real disk cache; incognito contexts
  // can refuse to retain a large engine in their limited memory cache.
  const profile = await mkdtemp(join(tmpdir(), 'dunhuang-startup-'));
  const ctx = await chromium.launchPersistentContext(profile, { headless: true, executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', args: process.env.DISABLE_HTTP2 ? ['--disable-http2'] : [] });
  try {
    const page = ctx.pages()[0] || await ctx.newPage();
    const cdp = await ctx.newCDPSession(page);
    await cdp.send('Network.enable');
    if (process.env.ENCODING) await cdp.send('Network.setExtraHTTPHeaders', { headers: { 'Accept-Encoding': process.env.ENCODING } });
    if (process.env.THROUGHPUT) await cdp.send('Network.emulateNetworkConditions', {
      offline: false, latency: 40, downloadThroughput: Number(process.env.THROUGHPUT), uploadThroughput: 125000,
    });
    const responses = [];
    cdp.on('Network.responseReceived', ({ response }) => {
      if (/\.(wasm|pck)$/.test(response.url)) responses.push({ url: response.url, headers: response.headers, fromDiskCache: !!response.fromDiskCache });
    });
    const errors = [];
    page.on('pageerror', e => errors.push(e.message));
    page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
    page.on('requestfinished', r => { if (/\.(wasm|pck)$/.test(r.url())) console.log(`Finished ${new URL(r.url()).pathname}`); });
    await page.addInitScript(() => {
      window.startupMeasurement = { wasm: [] };
      for (const method of ['instantiateStreaming', 'instantiate']) {
        const original = WebAssembly[method];
        if (!original) continue;
        WebAssembly[method] = function (...args) {
          const span = { method, start: performance.now() };
          window.startupMeasurement.wasm.push(span);
          return original.apply(this, args).then(value => { span.end = performance.now(); return value; });
        };
      }
      let sawOverlay = false;
      const observe = () => {
        const overlay = document.getElementById('status');
        const ready = document.getElementById('intro-enter');
        if (overlay) sawOverlay = true;
        if (ready && !ready.disabled && !window.startupMeasurement.ready) window.startupMeasurement.ready = performance.now();
        if (sawOverlay && !overlay && !window.startupMeasurement.interactive) {
          window.startupMeasurement.interactive = performance.now();
          // Auto-entry may enable and remove the button in the same task.
          window.startupMeasurement.ready ||= window.startupMeasurement.interactive;
        }
      };
      new MutationObserver(observe).observe(document, { attributes: true, childList: true, subtree: true });
      document.addEventListener('DOMContentLoaded', observe);
    });
    for (const visit of (process.env.COLD_ONLY ? ['cold'] : ['cold', 'warm'])) {
      // Measure revisits without artificial network delay; only transferSize=0 proves cache reuse.
      if (visit === 'warm' && process.env.THROUGHPUT) await cdp.send('Network.emulateNetworkConditions', {
        offline: false, latency: 0, downloadThroughput: -1, uploadThroughput: -1,
      });
      await page.goto(process.env.URL || 'https://maze.mplusm.site/', { waitUntil: 'domcontentloaded', timeout: 60000 });
      if (await page.locator('#intro-skip').isVisible() && await page.locator('#status').getAttribute('data-returning') !== 'true') {
        await page.locator('#intro-skip').click();
      }
      let failure;
      try {
        await page.waitForFunction(() => !document.getElementById('status') && typeof Engine === 'function', null, { timeout: Number(process.env.STARTUP_TIMEOUT || 300000), polling: 100 });
      } catch (error) { failure = error.message; }
      await page.waitForTimeout(300); // Include first rendered game frame, not a network-idle guess.
      const result = await page.evaluate(() => ({
        ...window.startupMeasurement,
        interactive: window.startupMeasurement.interactive || (!document.getElementById('status') ? performance.now() : undefined),
        status: document.getElementById('status-detail')?.textContent,
        overlay: !!document.getElementById('status'),
        resources: performance.getEntriesByType('resource').map(r => ({
          name: new URL(r.name).pathname, start: r.startTime, responseStart: r.responseStart,
          end: r.responseEnd, duration: r.duration, transfer: r.transferSize,
          encoded: r.encodedBodySize, decoded: r.decodedBodySize,
        })),
      }));
      result.responses = [...responses]; responses.length = 0;
      result.trial = trial + 1; result.visit = visit; result.errors = [...errors];
      result.ready ||= result.interactive;
      result.failure = failure;
      results.push(result);
      await writeFile(process.env.OUTPUT || '/tmp/dunhuang-startup.json', JSON.stringify(results, null, 2));
      console.log(JSON.stringify({ trial: result.trial, visit, ready_ms: result.ready, interactive_ms: result.interactive, wasm: result.wasm, resources: result.resources.filter(r => /\.(wasm|pck)$/.test(r.name)), errors: result.errors }));
      if (failure) throw new Error(`${failure}: ${JSON.stringify(result)}`);
      if (result.errors.length) throw new Error(`Runtime errors: ${JSON.stringify(result.errors)}`);
    }
  } finally {
    await ctx.close();
    await rm(profile, { recursive: true, force: true });
  }
}
