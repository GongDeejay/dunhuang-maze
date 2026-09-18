// Verify role: assert that the exported Godot canvas fills desktop/mobile viewports and boots without browser errors.
// Usage: URL=http://127.0.0.1:8060/ node tools/verify_responsive_web.mjs
import assert from 'node:assert/strict';
import { mkdir } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { resolve } from 'node:path';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const { chromium } = require('playwright');
const URL = process.env.URL || 'http://127.0.0.1:8060/';
const OUT = resolve('artifacts', 'responsive-verify');
const PROFILES = [
  { id: 'desktop-1440', viewport: { width: 1440, height: 900 }, mobile: false },
  { id: 'desktop-1920', viewport: { width: 1920, height: 1080 }, mobile: false },
  { id: 'iphone-390', viewport: { width: 390, height: 844 }, mobile: true },
  { id: 'iphone-390-large-text', viewport: { width: 390, height: 844 }, mobile: true, dpr: 3, font: 20 },
  { id: 'desktop-large-text', viewport: { width: 1440, height: 900 }, mobile: false, dpr: 2, font: 20 },
];

await mkdir(OUT, { recursive: true });
const macChrome = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const executablePath = process.env.BROWSER_EXECUTABLE || (existsSync(macChrome) ? macChrome : undefined);
const browser = await chromium.launch({ headless: true, executablePath });
try {
  for (const profile of PROFILES) {
    console.log(`Verifying ${profile.id}...`);
    const context = await browser.newContext({
      viewport: profile.viewport,
      isMobile: profile.mobile,
      hasTouch: profile.mobile,
      deviceScaleFactor: profile.dpr || (profile.mobile ? 2 : 1),
      locale: 'zh-CN',
    });
    const page = await context.newPage();
    if (profile.font) {
      await page.addInitScript(font => {
        document.addEventListener('DOMContentLoaded', () => {
          document.documentElement.style.fontSize = `${font}px`;
        });
      }, profile.font);
    }
    const errors = [];
    page.on('pageerror', error => errors.push(`[pageerror] ${error.message}`));
    page.on('console', message => {
      if (message.type() === 'error') errors.push(`[console.error] ${message.text()}`);
    });
    // Godot keeps worker/audio requests alive in production, so wait for DOM and then the canvas itself.
    await page.goto(URL, { waitUntil: 'domcontentloaded', timeout: 60_000 });
    await page.waitForSelector('canvas', { state: 'visible', timeout: 30_000 });
    // First-visit prologue is optional; skip while the engine continues loading.
    if (await page.locator('#intro-skip').isVisible()) await page.locator('#intro-skip').click();
    await page.waitForFunction(() => !document.querySelector('#status'),
      undefined, { timeout: Number(process.env.BOOT_TIMEOUT || 180_000) });
    await page.waitForFunction(() => {
      const canvas = document.querySelector('canvas');
      if (!canvas || canvas.width <= 0 || canvas.height <= 0) return false;
      const rect = canvas.getBoundingClientRect();
      return rect.width >= innerWidth * 0.96 && rect.height >= innerHeight * 0.96;
    }, undefined, { timeout: 60_000 });
    const metrics = await page.locator('canvas').evaluate(canvas => {
      const rect = canvas.getBoundingClientRect();
      return {
        cssWidth: Math.round(rect.width),
        cssHeight: Math.round(rect.height),
        bufferWidth: canvas.width,
        bufferHeight: canvas.height,
        viewportWidth: innerWidth,
        viewportHeight: innerHeight,
        scrollWidth: document.documentElement.scrollWidth,
        scrollHeight: document.documentElement.scrollHeight,
      };
    });
    assert.ok(metrics.cssWidth >= profile.viewport.width * 0.96, `${profile.id}: canvas width does not fill viewport`);
    assert.ok(metrics.cssHeight >= profile.viewport.height * 0.96, `${profile.id}: canvas height does not fill viewport`);
    assert.ok(metrics.bufferWidth >= metrics.cssWidth, `${profile.id}: low-resolution canvas backing buffer`);
    assert.ok(metrics.bufferHeight >= metrics.cssHeight, `${profile.id}: low-resolution canvas backing buffer`);
    assert.ok(metrics.scrollWidth <= metrics.viewportWidth, `${profile.id}: horizontal overflow`);
    assert.ok(metrics.scrollHeight <= metrics.viewportHeight, `${profile.id}: vertical overflow`);
    await page.screenshot({ path: resolve(OUT, `${profile.id}-menu.png`), fullPage: false });
    // The middle difficulty card spans the viewport centre on all supported profiles.
    // The full-window canvas is already in view; avoid scrollIntoView on mobile visual viewports.
    await page.mouse.click(metrics.cssWidth / 2, metrics.cssHeight / 2);
    await page.waitForTimeout(700); // Let Godot render the first gameplay frame and responsive HUD.
    await page.keyboard.press('Enter'); // Dismiss the first-chapter objective card in a fresh profile.
    await page.waitForTimeout(150); // One short render interval before capturing the underlying map.
    await page.screenshot({ path: resolve(OUT, `${profile.id}.png`), fullPage: false });
    assert.deepEqual(errors, [], `${profile.id}: browser errors\n${errors.join('\n')}`);
    await context.close();
  }
  console.log('Responsive Web verification passed.');
} finally {
  await browser.close();
}
