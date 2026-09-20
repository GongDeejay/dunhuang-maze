// Verify role: isolate artwork scheduling from Godot startup; use explicit network gates.
// Full engine/entry tests live in verify_loading_intro.mjs.
import assert from 'node:assert/strict';
import { existsSync } from 'node:fs';
import { createRequire } from 'node:module';
const require = createRequire(import.meta.url);
const { chromium } = require('playwright');
const url = process.env.URL || 'http://127.0.0.1:8066/';
const chrome = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const browser = await chromium.launch({ headless: true, executablePath: existsSync(chrome) ? chrome : undefined });
const deferred = () => { let resolve; const promise = new Promise(r => { resolve = r; }); return { promise, resolve }; };
async function within(promise, message) {
  let timeout;
  try {
    return await Promise.race([promise, new Promise((_, reject) => {
      timeout = setTimeout(() => reject(new Error(message)), 10000);
    })]);
  } finally { clearTimeout(timeout); }
}
async function setup(seen = false) {
  const context = await browser.newContext({ reducedMotion: 'reduce' });
  const page = await context.newPage();
  const errors = [];
  page.on('pageerror', e => errors.push(e.message));
  page.on('console', m => {
    if (m.type() === 'error' && !m.text().includes('net::ERR_FAILED')) errors.push(m.text());
  });
  if (seen) await page.addInitScript(() => localStorage.setItem('dunhuang-intro-v1', 'seen'));
  await page.route('**/engine-*.js', r => r.fulfill({ status: 200, contentType: 'text/javascript', body: '' }));
  await page.route(/\.(wasm|pck)$/, r => r.fulfill({ status: 200, body: '' }));
  return { context, page, errors };
}
try {
  const { context, page, errors } = await setup();
  const gates = [deferred(), deferred(), deferred()];
  const requested = [0, 0, 0];
  const allRequested = deferred();
  let imageIndex = 0;
  const sources = [];
  await page.route('**/intro-*.webp', async route => {
    const src = route.request().url();
    let index = sources.indexOf(src);
    if (index < 0) { index = imageIndex++; sources[index] = src; }
    requested[index]++;
    if (sources.length === 3) allRequested.resolve();
    const response = await route.fetch();
    if (index > 0) await gates[index].promise;
    await route.fulfill({ response });
  });
  await page.goto(url, { waitUntil: 'domcontentloaded' });
  await page.waitForFunction(() => document.querySelector('.intro-art img').naturalWidth > 0);
  // Request event order is not an API guarantee: map the observed URLs to the DOM data.
  await page.waitForFunction(() => document.querySelector('.intro-art img').dataset.searchSrc);
  const image = page.locator('.intro-art img');
  const family = await image.getAttribute('src');
  const storm = await image.getAttribute('data-storm-src');
  const search = await image.getAttribute('data-search-src');
  await within(allRequested.promise, 'Both later images must start before a page turn');
  assert.equal(await page.locator('#status').getAttribute('data-chapter'), '0');
  await page.locator('#intro-next').click();
  await page.locator('#intro-next').click();
  assert.equal(await image.getAttribute('src'), family, 'keep first usable art while both downloads wait');
  assert.equal(await page.locator('#intro-art-status').isVisible(), true);
  gates[sources.findIndex(src => src.endsWith(search))].resolve();
  await page.waitForFunction(src => document.querySelector('.intro-art img').getAttribute('src') === src, search);
  gates[sources.findIndex(src => src.endsWith(storm))].resolve();
  await page.waitForFunction(() => performance.getEntriesByType('resource').filter(e => /intro-.*\.webp/.test(e.name)).length === 3);
  assert.equal(await image.getAttribute('src'), search, 'late act two must not replace act three');
  await page.locator('#intro-prev').click();
  await page.waitForFunction(src => document.querySelector('.intro-art img').getAttribute('src') === src, storm);
  await page.locator('#intro-prev').click();
  await page.waitForFunction(src => document.querySelector('.intro-art img').getAttribute('src') === src, family);
  assert.deepEqual(requested, [1, 1, 1], 'backtracking does not start duplicate image requests');
  assert.deepEqual(errors, []);
  await context.close();
  console.log('Prefetch, slow image fallback, out-of-order responses and deduplication passed.');

  const failure = await setup();
  let imageRequests = 0;
  let failedSrc;
  const failureRequested = deferred();
  let retries = 0;
  await failure.page.route('**/intro-*.webp', route => {
    imageRequests++;
    if (imageRequests === 2) { failedSrc = route.request().url(); failureRequested.resolve(); return route.abort(); }
    if (route.request().url() === failedSrc) retries++;
    return route.continue();
  });
  await failure.page.goto(url, { waitUntil: 'domcontentloaded' });
  await failure.page.waitForFunction(() => document.querySelector('.intro-art img').naturalWidth > 0);
  await within(failureRequested.promise, 'Expected the prefetched failure before flipping');
  await failure.page.locator('#intro-next').click();
  // Select the failed act explicitly even if a browser changes request ordering.
  if (!failedSrc?.endsWith(await failure.page.locator('.intro-art img').getAttribute('data-storm-src'))) {
    await failure.page.locator('#intro-next').click();
  }
  await failure.page.locator('#intro-art-retry').waitFor({ state: 'visible' });
  await failure.page.evaluate(() => window.dunhuangIntro.ready());
  assert.equal(await failure.page.locator('#intro-enter').isEnabled(), true, 'failed artwork never blocks a ready game');
  await failure.page.locator('#intro-art-retry').click();
  await failure.page.waitForFunction(src => {
    const img = document.querySelector('.intro-art img');
    return img.src === src && img.naturalWidth > 0 && document.querySelector('#intro-art-retry').hidden;
  }, failedSrc);
  assert.equal(retries, 1);
  assert.deepEqual(failure.errors, []);
  await failure.context.close();
  console.log('Artwork failure, image-only retry and nonblocking game entry passed.');

  const returning = await setup(true);
  const returnImages = [];
  returning.page.on('request', r => { if (/intro-.*\.webp/.test(r.url())) returnImages.push(r.url()); });
  await returning.page.goto(url, { waitUntil: 'networkidle' });
  assert.equal(returnImages.length, 1, 'returning users do not download hidden acts');
  await returning.page.locator('#intro-skip').click();
  await returning.page.waitForFunction(() => performance.getEntriesByType('resource').filter(e => /intro-.*\.webp/.test(e.name)).length === 3);
  assert.equal(returnImages.length, 3, 'replay opts back into prefetch');
  assert.deepEqual(returning.errors, []);
  await returning.context.close();
  console.log('Returning visit and replay download policy passed.');
} finally { await browser.close(); }
