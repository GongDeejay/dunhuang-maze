// Verify: real keyboard/touch play of the isolated Mogao slice, with a read-only state bridge.
// Usage: URL=http://127.0.0.1:8067/ NODE_PATH=... node tools/verify_mogao.mjs
import assert from 'node:assert/strict';
import { mkdir } from 'node:fs/promises';
import { resolve } from 'node:path';
import { createRequire } from 'node:module';
const { chromium } = createRequire(import.meta.url)('playwright');
const out = resolve('artifacts/mogao-verify');
await mkdir(out, { recursive: true });
const browser = await chromium.launch({ headless: true, executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome' });
const dirs = [[1, 0, -1, 'ArrowUp'], [2, 0, 1, 'ArrowDown'], [4, 1, 0, 'ArrowRight'], [8, -1, 0, 'ArrowLeft']];
function path(grid, from, goal) {
  const q = [[from.x, from.y, []]], seen = new Set([`${from.x},${from.y}`]);
  for (let i = 0; i < q.length; i++) {
    const [x, y, steps] = q[i];
    if (x === goal[0] && y === goal[1]) return steps;
    for (const [dir, dx, dy] of dirs) {
      if (!(grid[y][x] & dir)) continue;
      const nx = x + dx, ny = y + dy, key = `${nx},${ny}`;
      if (!seen.has(key)) { seen.add(key); q.push([nx, ny, [...steps, dir]]); }
    }
  }
  throw new Error(`No route to ${goal}`);
}
const profiles = [
  { id: 'desktop-gate', width: 1440, height: 900, mobile: false, solve: true },
  { id: 'phone-gate', width: 390, height: 844, mobile: true, solve: true },
  { id: 'small-large-text', width: 360, height: 640, mobile: true, font: 20, solve: true },
  { id: 'phone-bypass', width: 390, height: 844, mobile: true, solve: false },
  { id: 'phone-landscape', width: 844, height: 390, mobile: true, solve: true },
];
try {
  for (const profile of profiles) {
    if (process.env.PROFILE && profile.id !== process.env.PROFILE) continue;
    console.log(`Verifying ${profile.id}`);
    const context = await browser.newContext({ viewport: { width: profile.width, height: profile.height }, isMobile: profile.mobile, hasTouch: profile.mobile, deviceScaleFactor: profile.mobile ? 3 : 1 });
    const page = await context.newPage();
    const errors = [];
    page.on('pageerror', e => errors.push(e.message));
    page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
    if (profile.font) await page.addInitScript(font => document.addEventListener('DOMContentLoaded', () => { document.documentElement.style.fontSize = `${font}px`; }), profile.font);
    const state = () => page.evaluate(() => window.mogaoProbe);
    async function point(p) {
      const s = await state(), c = await page.locator('#canvas').boundingBox();
      return { x: c.x + p.x * c.width / s.viewport.width, y: c.y + p.y * c.height / s.viewport.height };
    }
    async function tap(p) { const q = await point(p); if (profile.mobile) await page.touchscreen.tap(q.x, q.y); else await page.mouse.click(q.x, q.y); }
    async function click(name) {
      // Godot containers settle after the state transition; Canvas controls have no
      // DOM locator auto-wait. Require stable geometry across rendered frames.
      await page.evaluate(() => { window.mogaoButtonGeometry = null; });
      await page.waitForFunction(name => {
        const s = window.mogaoProbe;
        const key = JSON.stringify([s.viewport, s.phase, s.buttons[name], s.scroll]);
        const prior = window.mogaoButtonGeometry;
        const frames = prior?.key === key ? prior.frames + 1 : 0;
        window.mogaoButtonGeometry = { key, frames };
        return frames >= 3;
      }, name);
      for (let tries = 0; tries < 8; tries++) {
        const s = await state(), b = s.buttons[name];
        const clip = name === 'leave' ? s.panel : s.scroll;
        assert.ok(b.visible, `${name} is available in ${s.phase}`);
        if (b.top >= clip.top && b.bottom <= clip.bottom) { await tap(b); return; }
        const c = await point({ x: s.scroll.x, y: s.scroll.y });
        await page.mouse.move(c.x, c.y);
        await page.mouse.wheel(0, b.top < clip.top ? -160 : 160);
        await page.waitForTimeout(100); // ScrollContainer wheel interpolation.
      }
      throw new Error(`${name} cannot be reached by scrolling`);
    }
    async function dismiss() {
      const s = await state();
      if (!s.cardOpen) return;
      await tap(s.card);
      await page.waitForFunction(level => !window.mogaoProbe.cardOpen || window.mogaoProbe.level !== level, s.level);
    }
    async function move(dir) {
      await page.waitForFunction(() => window.mogaoProbe.cooldown <= 0);
      const before = await state();
      if (profile.mobile) await tap(before.dpad.find(b => b.dir === dir));
      else await page.keyboard.press(dirs.find(d => d[0] === dir)[3]);
      await page.waitForFunction(p => {
        const s = window.mogaoProbe;
        return s.moves > p.moves || s.cooldown > 0 || s.cardOpen || s.over;
      }, before);
      const next = await state();
      assert.equal(next.over, false, `${profile.id}: surviving normal difficulty`);
      assert.ok(next.moves - before.moves <= 1, 'one physical input moves at most one tile');
      if (!next.won) await dismiss();
    }
    async function go(goal) {
      for (let i = 0; i < 250; i++) {
        const s = await state(), route = path(s.grid, s.pos, goal);
        if (!route.length) return;
        await move(route[0]);
      }
      throw new Error('Navigation exceeded input budget');
    }
    try {
      await page.goto(process.env.URL || 'http://127.0.0.1:8067/', { waitUntil: 'domcontentloaded' });
      if (profile.id === 'desktop-gate') {
        await page.locator('#intro-show-lore').click();
        await page.locator('#intro-lore-next').click();
        assert.equal(await page.locator('#intro-rabbit-figure').isVisible(), true);
        assert.equal(await page.locator('.intro-art').isVisible(), false, 'notebook is not another family-film card');
        await page.locator('#intro-rabbit-zoom').click();
        assert.equal(await page.locator('#intro-rabbit-zoom').getAttribute('aria-expanded'), 'true');
        await page.screenshot({ path: resolve(out, 'desktop-rabbit-loading.png') });
      }
      if (await page.locator('#intro-skip').isVisible()) await page.locator('#intro-skip').click();
      await page.waitForFunction(() => window.mogaoProbe && !document.getElementById('status'), undefined, { timeout: 120000 });
      await tap((await state()).normal);
      await page.waitForFunction(() => window.mogaoProbe.cardOpen);
      assert.equal((await state()).cardTitle, '第二章 · 莫高窟');
      assert.equal((await state()).difficulty, 'normal');
      await dismiss();
      await go([4, 2]);
      await page.waitForFunction(() => window.mogaoProbe.encounterView?.cellSize > 0);
      const encounter = await state(), view = encounter.encounterView;
      const cssCanvas = await page.locator('#canvas').boundingBox();
      assert.ok(view.cellSize * cssCanvas.width / encounter.viewport.width >= 48, 'door stays at least 48 CSS pixels even with larger system text');
      assert.ok(view.scarfRight <= view.right && view.scarfBottom <= view.bottom, 'door and common scarf landmark stay in the same viewport');
      const prompt = encounter.prompt;
      assert.ok(prompt.right <= view.gateLeft || prompt.left >= view.gateRight || prompt.bottom <= view.gateTop || prompt.top >= view.gateBottom, 'inspect button never obscures the physical gate');
      await page.screenshot({ path: resolve(out, `${profile.id}-fork.png`) });
      const beforePath = path((await state()).grid, (await state()).pos, [14, 4]).length;
      if (profile.solve) {
        if (profile.mobile) await tap((await state()).prompt);
        else await page.keyboard.press('f');
        await page.waitForFunction(() => window.mogaoProbe.panelOpen);
        let s = await state();
        assert.ok(s.panel.left >= 0 && s.panel.right <= s.viewport.width && s.panel.bottom <= s.viewport.height, 'panel fits viewport');
        assert.ok(s.buttons.leave.bottom <= s.viewport.height, 'exit is always visible');
        await page.screenshot({ path: resolve(out, `${profile.id}-intro.png`) });
        const frozen = await state();
        await page.keyboard.press('ArrowDown'); await page.keyboard.press('e'); await page.keyboard.press('r'); await page.keyboard.press('q');
        await page.waitForTimeout(3200); // Exceeds the longest enemy interval; modal must freeze the entire encounter.
        s = await state();
        for (const key of ['pos', 'hp', 'moves', 'inventory', 'buff', 'cooldown', 'enemies']) assert.deepEqual(s[key], frozen[key], `${key} frozen during inspection`);
        assert.equal(s.phase, 'inspect', 'no cover, countdown or memory test');
        assert.equal(s.board.length, 2, 'two plates to match against the visible reference');
        assert.deepEqual(Object.keys(s.buttons).sort(), ['different', 'leave', 'same']);
        await page.screenshot({ path: resolve(out, `${profile.id}-board.png`) });
        if (profile.id === 'desktop-gate') {
          await page.setViewportSize({ width: 1200, height: 800 });
          await page.waitForFunction(() => window.mogaoProbe.viewport.width === 1200);
          assert.equal((await state()).phase, 'inspect', 'resize never hides or answers the reference');
          assert.equal((await state()).latches, 0);
          await page.setViewportSize({ width: profile.width, height: profile.height });
          await page.waitForFunction(p => window.mogaoProbe.viewport.width === p.width && window.mogaoProbe.viewport.height === p.height, profile);
          assert.equal((await state()).phase, 'inspect');
        }
        await click('leave');
        await page.waitForFunction(() => !window.mogaoProbe.panelOpen);
        assert.equal((await state()).gate, false, 'leaving never opens the unsolved gate');
        await page.waitForTimeout(80); // Release guard before a new physical gesture.
        await tap((await state()).prompt);
        await page.waitForFunction(() => window.mogaoProbe.panelOpen && window.mogaoProbe.phase === 'inspect');
        const retryHp = (await state()).hp;
        // One wrong choice preserves both plates; one correct choice opens the real door.
        for (let round = 0; round < 2; round++) {
          await page.waitForFunction(() => window.mogaoProbe.phase === 'inspect');
          await page.screenshot({ path: resolve(out, `${profile.id}-comparison.png`) });
          s = await state();
          const index = s.board.indexOf(round === 0 ? 1 : 0);
          await click(index === 0 ? 'same' : 'different');
          if (round === 0) {
            await page.waitForFunction(() => window.mogaoProbe.message.includes('不着急'));
            assert.equal((await state()).latches, 0);
            assert.deepEqual((await state()).board, s.board, 'wrong choice does not move the answer');
            assert.equal((await state()).hp, retryHp, 'mistake never deals damage');
          } else {
            await page.waitForFunction(() => !window.mogaoProbe.panelOpen && window.mogaoProbe.revealing);
            assert.equal((await state()).latches, 1, 'one success is enough');
          }
        }
        assert.equal((await state()).gate, true);
        assert.equal((await state()).rescued, false);
        assert.deepEqual((await state()).pos, { x: 4, y: 2 }, 'answer tap never moves player when panel closes automatically');
        await page.waitForFunction(() => window.mogaoProbe.revealing);
        const revealFrozen = await state();
        await page.keyboard.press('ArrowRight'); await page.keyboard.press('e');
        await page.waitForTimeout(300); // Observe the real opening animation while gameplay is frozen.
        s = await state();
        for (const key of ['pos', 'hp', 'moves', 'inventory', 'buff', 'cooldown', 'enemies']) assert.deepEqual(s[key], revealFrozen[key], `${key} frozen while gate opens`);
        await page.screenshot({ path: resolve(out, `${profile.id}-gate-opening.png`) });
        await page.waitForFunction(() => window.mogaoProbe.gatePresented);
        assert.equal((await state()).gateVisual, 1, 'the door is visibly fully open');
        assert.equal((await state()).gateGuiding, true, 'immediate gate guidance, without a walking threshold');
        assert.equal((await state()).guideDir, 4, 'arrow leads right through the actual new connection');
        await page.screenshot({ path: resolve(out, `${profile.id}-shortcut.png`) });
        const afterPath = path((await state()).grid, (await state()).pos, [14, 4]).length;
        assert.ok(beforePath - afterPath >= 12, 'opened gate gives a real shorter route');
        await page.waitForTimeout(80); // Wait only for the deliberate input release guard.
        await tap((await state()).prompt);
        await page.waitForFunction(() => window.mogaoProbe.panelOpen && window.mogaoProbe.phase === 'done');
        assert.match((await state()).message, /共用/);
        assert.equal((await state()).buttons.same.visible, false, 'revealed notebook does not ask again');
        await page.screenshot({ path: resolve(out, `${profile.id}-notebook-reveal.png`) });
        await click('leave');
        await page.waitForFunction(() => !window.mogaoProbe.panelOpen);
        assert.equal((await state()).revealing, false, 'rereading cannot replay or relock gate');
        await page.waitForTimeout(80); // Deliberate input release guard after closing notebook.
        await go([5, 2]);
        assert.equal((await state()).crossedGate, true);
        assert.equal((await state()).gateGuiding, false, 'temporary guide ends after crossing the door');
      }
      await go([6, 2]);
      assert.equal((await state()).scarfFound, true, 'both routes meet at the same visible scarf');
      await go([14, 4]);
      assert.equal((await state()).rescued, true);
      assert.equal((await state()).gate, profile.solve, 'bypass does not require solving');
      await go([29, 24]);
      assert.equal((await state()).won, true);
      assert.equal((await state()).cardTitle, '平安走出莫高窟');
      await page.screenshot({ path: resolve(out, `${profile.id}-complete.png`) });
      await dismiss();
      await page.waitForFunction(() => window.mogaoProbe.third);
      assert.deepEqual(errors, [], `${profile.id}: runtime errors`);
      console.log(`${profile.id}: route, puzzle, input isolation, rescue and third-chapter transition passed`);
    } catch (error) {
      await page.screenshot({ path: resolve(out, `${profile.id}-failure.png`) }).catch(() => {});
      throw error;
    } finally { await context.close(); }
  }
} finally { await browser.close(); }
