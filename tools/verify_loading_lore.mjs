// Verify role: optional lore during real engine loading; no extra downloads or entry gates.
// Usage: URL=http://127.0.0.1:8067/ NODE_PATH=... node tools/verify_loading_lore.mjs
import assert from 'node:assert/strict';
import { mkdir } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { resolve } from 'node:path';
import { createRequire } from 'node:module';
const { chromium } = createRequire(import.meta.url)('playwright');
const url = process.env.URL || 'http://127.0.0.1:8067/';
const out = resolve('artifacts/lore-verify');
await mkdir(out, { recursive: true });
const chrome = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const browser = await chromium.launch({ headless: true, executablePath: existsSync(chrome) ? chrome : undefined });
const profiles = [
  { id: 'desktop', viewport: { width: 1440, height: 900 } },
  { id: 'phone', viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true },
  { id: 'large-text', viewport: { width: 360, height: 640 }, isMobile: true, hasTouch: true, font: 20 },
  { id: 'landscape', viewport: { width: 844, height: 390 }, isMobile: true, hasTouch: true },
];
try {
  for (const { id, font, ...options } of profiles) {
    const context = await browser.newContext({ ...options, reducedMotion: 'reduce' });
    const page = await context.newPage();
    const errors = [], external = [];
    page.on('pageerror', e => errors.push(e.message));
    page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
    page.on('request', r => { if (new URL(r.url()).origin !== new URL(url).origin) external.push(r.url()); });
    if (font) await page.addInitScript(size => {
      document.addEventListener('DOMContentLoaded', () => { document.documentElement.style.fontSize = `${size}px`; });
    }, font);
    let release;
    let gate = new Promise(resolve => { release = resolve; });
    await page.route('**/*.wasm', async route => { await gate; await route.continue(); });
    try {
      await page.goto(url, { waitUntil: 'domcontentloaded' });
      await page.locator('#intro-show-lore').click();
      assert.equal(await page.locator('#intro-show-lore').getAttribute('aria-pressed'), 'true');
      assert.equal(await page.locator('#intro-story-view').isVisible(), false);
      assert.equal(await page.locator('#intro-enter').isDisabled(), true);
      const readingBox = await page.locator('.intro-reading').boundingBox();
      const copyBox = await page.locator('#intro-lore-copy').boundingBox();
      assert.ok(copyBox.y + 32 < readingBox.y + readingBox.height, 'actual story text is visible on opening, not only chrome');
      const titles = new Set();
      const shell = await page.locator('.intro-panel').boundingBox();
      for (let i = 0; i < 6; i++) {
        assert.equal(await page.locator('#status').getAttribute('data-illustrated'),'true','every lore page keeps the notebook shell');
        const currentShell = await page.locator('.intro-panel').boundingBox();
        for (const metric of ['x','y','width','height']) assert.ok(Math.abs(currentShell[metric]-shell[metric])<1,'turning a page must not change the reading layout');
        assert.equal(await page.locator('#intro-lore-page').textContent(), `${i + 1} / 6`);
        titles.add(await page.locator('#intro-lore-title').textContent());
        assert.ok((await page.locator('#intro-lore-copy').textContent()).length > 50);
        assert.match(await page.locator('#intro-lore-link').getAttribute('href'), /^https:\/\//);
        if ([0,2,3,4,5].includes(i)) {
          const note = {0:'nine_deer',2:'golden_light',3:'library_cave',4:'pipa',5:'roadbook'}[i];
          assert.equal(await page.locator('#intro-travel-figure').isVisible(),true);
          assert.equal(await page.locator(`[data-note="${note}"]`).isVisible(),true);
          assert.equal(await page.locator('.intro-art').isVisible(),false);
          assert.match(await page.locator('#intro-travel-caption').textContent(), /虚构|非文物/);
          await page.screenshot({path:resolve(out,`${id}-${note}.png`)});
        }
        if (i === 1) {
          assert.equal(await page.locator('#intro-rabbit-figure').isVisible(), true);
          assert.equal(await page.locator('.intro-art').isVisible(), false);
          await page.locator('#intro-rabbit-zoom').click();
          assert.equal(await page.locator('#intro-rabbit-zoom').getAttribute('aria-expanded'), 'true');
          assert.equal(await page.locator('#intro-rabbit-figure svg').getAttribute('viewBox'), '95 85 135 140');
          await page.screenshot({ path: resolve(out, `${id}-rabbit-zoom.png`) });
          await page.locator('#intro-rabbit-zoom').click();
          assert.equal(await page.locator('#intro-rabbit-figure svg').getAttribute('viewBox'), '0 0 320 320');
        }
        if (i === 2) assert.match(await page.locator('#intro-lore-kind').textContent(), /传说/);
        await page.locator('#intro-lore-source summary').click();
        assert.equal(await page.locator('#intro-lore-link').isVisible(), true);
        assert.ok(await page.evaluate(() => document.getElementById('status').scrollWidth <= innerWidth));
        const enterBox = await page.locator('#intro-enter').boundingBox();
        assert.ok(enterBox.y >= 0 && enterBox.y + enterBox.height <= options.viewport.height, 'entry stays in viewport');
        await page.locator('#intro-lore-next').click();
        assert.equal(await page.locator('#intro-lore-source').getAttribute('open'), null);
      }
      assert.equal(titles.size, 6);
      assert.equal(await page.locator('#intro-lore-page').textContent(), '1 / 6');
      assert.equal(await page.locator('#intro-lore-prev').isDisabled(), true);
      await page.locator('#intro-lore-next').click();
      await page.locator('#intro-lore-prev').click();
      await page.screenshot({ path: resolve(out, `${id}-reading.png`) });
      await page.locator('#intro-show-story').click();
      assert.equal(await page.locator('#intro-title').isVisible(), true);
      await page.locator('#intro-show-lore').click();
      release();
      await page.waitForFunction(() => document.getElementById('intro-enter')?.disabled === false, undefined, { timeout: 120000 });
      assert.equal(await page.locator('#intro-lore-view').isVisible(), true, 'ready does not interrupt reading');
      await page.screenshot({ path: resolve(out, `${id}-ready.png`) });
      await page.locator('#intro-enter').click();
      await page.waitForFunction(() => !document.getElementById('status'));
      // Returning players can deliberately choose lore and cancel automatic entry.
      gate = new Promise(resolve => { release = resolve; });
      await page.reload({ waitUntil: 'domcontentloaded' });
      assert.equal(await page.locator('#status').getAttribute('data-returning'), 'true');
      await page.locator('#intro-show-lore').click();
      release();
      await page.waitForFunction(() => document.getElementById('intro-enter')?.disabled === false, undefined, { timeout: 120000 });
      assert.equal(await page.locator('#intro-lore-view').isVisible(), true);
      await page.locator('#intro-skip').click();
      await page.waitForFunction(() => !document.getElementById('status'));
      assert.deepEqual(errors, [], `${id}: runtime errors`);
      assert.deepEqual(external, [], 'lore/source disclosure must not request external resources');
      console.log(`${id}: six stories, sources, layout, ready and returning-reader entry passed`);
    } catch (error) {
      await page.screenshot({ path: resolve(out, `${id}-FAIL.png`) }).catch(() => {});
      throw error;
    } finally { release(); await context.close(); }
  }
} finally { await browser.close(); }
