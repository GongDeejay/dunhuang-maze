// Verify role: native browser touch -> Godot -> one virtual-pad movement signal.
// Use a separate test export with tests/mobile_input_probe.tscn as main scene (never publish it).
// Usage: URL=http://127.0.0.1:8061/ NODE_PATH=... node tools/verify_mobile_input.mjs
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
const { chromium } = createRequire(import.meta.url)('playwright');
const browser = await chromium.launch({ headless: true, executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome' });
try {
  for (const profile of [{ width: 390, height: 844, dpr: 1 }, { width: 390, height: 844, dpr: 3 }, { width: 844, height: 390, dpr: 2 }]) {
    const context = await browser.newContext({ viewport: { width: profile.width, height: profile.height }, deviceScaleFactor: profile.dpr, isMobile: true, hasTouch: true });
    const page = await context.newPage();
    const errors = [];
    page.on('pageerror', e => errors.push(e.message));
    page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
    await page.goto(process.env.URL || 'http://127.0.0.1:8061/', { waitUntil: 'domcontentloaded' });
    await page.waitForFunction(() => window.mobileInputProbe && !document.getElementById('status'), undefined, { timeout: 120000 });
    const state = () => page.evaluate(() => window.mobileInputProbe);
    const initial = await state();
    assert.equal(initial.emulateMouse, true, 'exercise default Godot touch-to-mouse emulation');
    const canvas = await page.locator('#canvas').boundingBox();
    const point = p => ({ x: canvas.x + p.x * canvas.width / initial.viewport.width, y: canvas.y + p.y * canvas.height / initial.viewport.height });
    let expected = 0;
    for (const button of initial.buttons) {
      const p = point(button);
      for (let i = 0; i < 3; i++) {
        await page.touchscreen.tap(p.x, p.y);
        await page.waitForFunction(n => window.mobileInputProbe.moves.length >= n, ++expected);
        assert.equal((await state()).moves.length, expected, 'each rapid touch generates one movement');
        assert.equal((await state()).moves.at(-1), button.dir);
      }
    }
    const nativeEvents = (await state()).events;
    assert.ok(nativeEvents.some(e => e.startsWith('InputEventScreenTouch:0:true')));
    assert.ok(nativeEvents.some(e => e.startsWith('InputEventMouseButton:-1:true')), 'real browser touch produced the duplicate event under test');
    // Holding a finger for half a second must not add an extra move on release.
    const cdp = await context.newCDPSession(page);
    const p = point(initial.buttons[0]);
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [p] });
    await page.waitForTimeout(500); // Deliberate long press, not a load/readiness wait.
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
    assert.equal((await state()).moves.length, ++expected, 'long press/release produces one move');
    const start = point(initial.maze);
    const end = point({ x: initial.maze.x + initial.swipe + 10, y: initial.maze.y });
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [start] });
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [end] });
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
    await page.waitForFunction(n => window.mobileInputProbe.moves.length >= n, ++expected);
    assert.equal((await state()).moves.length, expected, 'swipe produces one move');
    await page.mouse.click(p.x, p.y);
    await page.waitForFunction(n => window.mobileInputProbe.moves.length >= n, ++expected);
    assert.equal((await state()).moves.length, expected, 'real mouse remains usable');
    assert.deepEqual(errors, []);
    console.log(`${profile.width}x${profile.height} @${profile.dpr}x: ${expected} gestures -> ${expected} moves; native + emulated events confirmed`);
    await context.close();
  }
} finally { await browser.close(); }
