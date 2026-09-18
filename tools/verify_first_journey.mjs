// Verify role: complete first chapter with real keyboard/touch inputs in a test-only export.
// Usage: URL=http://127.0.0.1:8062/ NODE_PATH=... node tools/verify_first_journey.mjs
import assert from 'node:assert/strict';
import { mkdir } from 'node:fs/promises';
import { resolve } from 'node:path';
import { createRequire } from 'node:module';
const { chromium } = createRequire(import.meta.url)('playwright');
const out = resolve('artifacts/first-journey-verify');
await mkdir(out, { recursive: true });
const browser = await chromium.launch({ headless: true, executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome' });
const dirs = [[1, 0, -1, 'ArrowUp'], [2, 0, 1, 'ArrowDown'], [4, 1, 0, 'ArrowRight'], [8, -1, 0, 'ArrowLeft']];
function path(grid, from, goal) {
  const queue = [[from.x, from.y, []]], seen = new Set([`${from.x},${from.y}`]);
  for (let i = 0; i < queue.length; i++) {
    const [x, y, steps] = queue[i];
    if (x === goal[0] && y === goal[1]) return steps;
    for (const [dir, dx, dy] of dirs) {
      if (!(grid[y][x] & dir)) continue;
      const nx = x + dx, ny = y + dy, key = `${nx},${ny}`;
      if (!seen.has(key)) { seen.add(key); queue.push([nx, ny, [...steps, dir]]); }
    }
  }
  throw new Error(`No route to ${goal}`);
}
try {
  for (const profile of [
    { id: 'desktop-safe-cave', width: 1440, height: 900, mobile: false, cave: true },
    { id: 'phone-shortcut', width: 390, height: 844, mobile: true, cave: false },
    { id: 'small-phone-safe', width: 360, height: 640, mobile: true, cave: true },
    { id: 'small-phone-large-text', width: 360, height: 640, mobile: true, cave: false, font: 20 },
    { id: 'phone-landscape', width: 844, height: 390, mobile: true, cave: false },
  ]) {
    const context = await browser.newContext({ viewport: { width: profile.width, height: profile.height }, isMobile: profile.mobile, hasTouch: profile.mobile, deviceScaleFactor: profile.mobile ? 3 : 1 });
    const page = await context.newPage();
    if (profile.font) await page.addInitScript(font => {
      document.addEventListener('DOMContentLoaded', () => {
        document.documentElement.style.fontSize = `${font}px`;
      });
    }, profile.font);
    const errors = [];
    page.on('pageerror', e => errors.push(e.message));
    page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
    await page.goto(process.env.URL || 'http://127.0.0.1:8062/', { waitUntil: 'domcontentloaded' });
    await page.waitForFunction(() => window.firstJourneyProbe && !document.getElementById('status'), undefined, { timeout: 120000 });
    const state = () => page.evaluate(() => window.firstJourneyProbe);
    const point = async p => {
      const s = await state(), c = await page.locator('#canvas').boundingBox();
      return { x: c.x + p.x * c.width / s.viewport.width, y: c.y + p.y * c.height / s.viewport.height };
    };
    const tap = async p => profile.mobile ? page.touchscreen.tap(p.x, p.y) : page.mouse.click(p.x, p.y);
    await tap(await point((await state()).normalButton));
    await page.waitForFunction(() => window.firstJourneyProbe.card.open);
    const seen = new Set();
    async function dismiss() {
      const s = await state();
      if (!s.card.open) return;
      assert.ok(s.card.left >= 0 && s.card.top >= 0 && s.card.right <= s.viewport.width && s.card.bottom <= s.viewport.height, `${profile.id}: card fits viewport: ${JSON.stringify(s.card)}`);
      if (!seen.has(s.card.title)) {
        await page.screenshot({ path: resolve(out, `${profile.id}-${seen.size}.png`) });
        seen.add(s.card.title);
      }
      await tap(await point(s.card));
      await page.waitForFunction(() => !window.firstJourneyProbe.card.open);
    }
    // Card reading freezes real combat and ignores direction input.
    const before = await state();
    assert.equal(before.difficulty, 'normal');
    await page.keyboard.press('ArrowRight');
    await page.waitForTimeout(2600); // Longer than the encounter interval: no enemy movement while reading.
    const after = await state();
    assert.deepEqual(after.enemies, before.enemies);
    assert.deepEqual(after.pos, before.pos);
    await dismiss();
    async function move(dir) {
      await page.waitForFunction(() => window.firstJourneyProbe.cooldown <= 0);
      const previous = await state();
      if (profile.mobile) await tap(await point(previous.buttons.find(b => b.dir === dir)));
      else await page.keyboard.press(dirs.find(d => d[0] === dir)[3]);
      await page.waitForFunction(p => {
        const s = window.firstJourneyProbe;
        return s.moves > p.moves || s.cooldown > 0 || s.card.open || s.over;
      }, previous);
      const next = await state();
      assert.equal(next.over, false, `${profile.id}: player survived`);
      assert.ok(next.moves - previous.moves <= 1, 'one direction input moves at most one tile');
      if (!next.won) await dismiss();
    }
    async function go(goal) {
      for (let attempts = 0; attempts < 250; attempts++) {
        const s = await state();
        const steps = path(s.grid, s.pos, goal);
        if (!steps.length) return;
        await move(steps[0]);
      }
      throw new Error('Route exceeded input budget');
    }
    await go([4, 3]);
    assert.ok(seen.has('路牌前，选一条路'));
    if (profile.cave) {
      for (const goal of [[1, 8], [7, 8], [5, 9], [9, 11], [12, 8]]) await go(goal);
      assert.equal((await state()).mural, true);
      assert.equal((await state()).route, '古道');
    } else {
      for (const goal of [[8, 3], [12, 5], [12, 8]]) await go(goal);
      assert.equal((await state()).mural, false, 'optional cave not required');
      assert.equal((await state()).route, '风沙近路');
    }
    await go([14, 4]);
    assert.equal((await state()).rescued, true);
    assert.ok(seen.has('终于找到妈妈了'));
    assert.match((await state()).objective, /营地/);
    assert.ok((await state()).grid[4][14] & 4, 'rescue opens east shortcut');
    await go([16, 4]);
    await go([16, 12]);
    assert.equal((await state()).won, true);
    await page.screenshot({ path: resolve(out, `${profile.id}-complete.png`) });
    assert.equal((await state()).card.title, '与妈妈平安会合');
    await dismiss(); // The same large continue button works with touch, not just R.
    await page.waitForFunction(() => window.firstJourneyProbe.level === 1);
    assert.deepEqual(errors, [], `${profile.id}: runtime errors`);
    console.log(`${profile.id}: route, story pause, optional reward, rescue, shortcut, completion and next level passed`);
    await context.close();
  }
} finally { await browser.close(); }
