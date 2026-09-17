// Verify role: first visit, slow download, story controls, ready/skip/error states and returning visits.
// Usage: URL=http://127.0.0.1:8060/ NODE_PATH=... node tools/verify_loading_intro.mjs
import assert from 'node:assert/strict';
import { mkdir } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { resolve } from 'node:path';
import { createRequire } from 'node:module';
const require = createRequire(import.meta.url);
const { chromium } = require('playwright');
const url = process.env.URL || 'http://127.0.0.1:8060/';
const out = resolve('artifacts/intro-verify');
await mkdir(out, { recursive: true });
const chrome = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const browser = await chromium.launch({ headless: true, executablePath: existsSync(chrome) ? chrome : undefined });
const profiles = [
  { id: 'desktop', viewport: { width: 1440, height: 900 } },
  { id: 'phone', viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true },
  { id: 'small-large-text', viewport: { width: 360, height: 640 }, isMobile: true, hasTouch: true, font: 20 },
];
try {
  for (const { id, font, ...options } of profiles) {
    const context = await browser.newContext({ ...options, reducedMotion: id === 'desktop' ? 'no-preference' : 'reduce' });
    const page = await context.newPage();
    if (font) await page.addInitScript(size => {
      document.addEventListener('DOMContentLoaded', () => { document.documentElement.style.fontSize = `${size}px`; });
    }, font);
    const errors = [];
    page.on('pageerror', error => errors.push(error.message));
    page.on('console', message => { if (message.type() === 'error') errors.push(message.text()); });
    let release;
    const gate = new Promise(resolve => { release = resolve; });
    await page.route('**/*.wasm', async route => { await gate; await route.continue(); });
    await page.goto(url, { waitUntil: 'domcontentloaded' });
    await page.locator('#intro-title').waitFor();
    assert.equal(await page.evaluate(() => getComputedStyle(document.body).touchAction), 'pan-y');
    assert.equal(await page.locator('#intro-enter').isDisabled(), true, 'cannot enter before download');
    assert.equal(await page.locator('#status').getAttribute('data-returning'), 'false');
    assert.equal(await page.locator('#intro-auto').textContent(), id === 'desktop' ? '暂停播放' : '自动播放');
    await page.waitForFunction(() => document.querySelector('.intro-art img').naturalWidth > 0);
    const arrivalImage = await page.locator('.intro-art img').getAttribute('src');
    assert.equal(await page.evaluate(() => performance.getEntriesByType('resource').filter(e => /intro-.*\.webp/.test(e.name)).length), 1, 'only first illustration downloads on arrival');
    await page.screenshot({ path: resolve(out, `${id}-arrival.png`) });
    if (id === 'desktop') {
      await page.waitForFunction(() => document.getElementById('status').dataset.chapter === '1', undefined, { timeout: 15000 });
      await page.locator('#intro-prev').click();
      assert.equal(await page.locator('#intro-auto').textContent(), '自动播放', 'manual reading pauses auto-advance');
    }
    await page.locator('#intro-next').click();
    assert.match(await page.locator('#intro-title').textContent(), /吹散/);
    await page.waitForFunction(() => { const img = document.querySelector('.intro-art img'); return img.getAttribute('src') === img.dataset.stormSrc && img.complete && img.naturalWidth > 0; });
    const stormImage = await page.locator('.intro-art img').getAttribute('src');
    assert.notEqual(stormImage, arrivalImage);
    await page.screenshot({ path: resolve(out, `${id}-storm.png`) });
    await page.locator('#intro-next').click();
    assert.match(await page.locator('#intro-copy').textContent(), /一起走完/);
    await page.waitForFunction(() => { const img = document.querySelector('.intro-art img'); return img.getAttribute('src') === img.dataset.searchSrc && img.complete && img.naturalWidth > 0; });
    const searchImage = await page.locator('.intro-art img').getAttribute('src');
    assert.notEqual(searchImage, stormImage);
    assert.notEqual(searchImage, arrivalImage);
    await page.screenshot({ path: resolve(out, `${id}-search.png`) });
    await page.locator('#intro-prev').click();
    await page.locator('#intro-prev').click();
    await page.waitForFunction(src => document.querySelector('.intro-art img').getAttribute('src') === src, arrivalImage);
    await page.locator('#intro-next').click();
    await page.locator('#intro-next').click();
    assert.equal(await page.locator('#intro-next').isDisabled(), true);
    assert.ok(await page.evaluate(() => document.querySelector('#status').scrollWidth <= innerWidth), 'no horizontal intro overflow');
    const story = await page.locator('#intro-title').textContent();
    release();
    await page.waitForFunction(() => !document.getElementById('intro-enter').disabled, undefined, { timeout: 120_000 });
    assert.equal(await page.locator('#status').count(), 1, 'first visit remains readable when ready');
    assert.equal(await page.locator('#intro-title').textContent(), story);
    await page.locator('#intro-enter').click();
    await page.waitForFunction(() => !document.getElementById('status'));
    assert.equal(await page.evaluate(() => localStorage.getItem('dunhuang-intro-v1')), 'seen');
    assert.equal(await page.evaluate(() => document.body.classList.contains('intro-open')), false);
    // Returning visit should not require another acknowledgement.
    await page.reload({ waitUntil: 'domcontentloaded' });
    await page.waitForFunction(() => !document.getElementById('status'), undefined, { timeout: 120_000 });
    assert.deepEqual(errors, [], `${id}: unexpected runtime errors`);
    await context.close();
    console.log(`${id}: story, download gate, entry and return passed`);
  }

  // Denied localStorage and a failed engine-script download must still offer retry.
  const context = await browser.newContext();
  const page = await context.newPage();
  const pageErrors = [];
  page.on('pageerror', error => pageErrors.push(error.message));
  await page.addInitScript(() => {
    Object.defineProperty(window, 'localStorage', { get() { throw new Error('storage denied'); } });
  });
  await page.route('**/engine-*.js', route => route.abort());
  await page.goto(url, { waitUntil: 'domcontentloaded' });
  await page.locator('#intro-retry').waitFor({ state: 'visible' });
  assert.match(await page.locator('#status-detail').textContent(), /下载失败/);
  assert.equal(await page.locator('#intro-enter').isDisabled(), true);
  assert.deepEqual(pageErrors, [], 'loader survives unavailable engine and storage');
  await page.screenshot({ path: resolve(out, 'download-error.png') });
  await page.unroute('**/engine-*.js');
  await page.locator('#intro-retry').click();
  await page.waitForFunction(() => document.getElementById('intro-enter')?.disabled === false, undefined, { timeout: 120_000 });
  await page.locator('#intro-enter').click();
  await page.waitForFunction(() => !document.getElementById('status'));
  assert.deepEqual(pageErrors, [], 'retry succeeds even when local storage is denied');
  await context.close();
  console.log('Download error and blocked storage passed.');
} finally { await browser.close(); }
