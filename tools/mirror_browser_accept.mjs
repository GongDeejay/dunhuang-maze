// Local check for the mirror cave. Not part of CI or the deploy.
// Opens the exported build with ?mirror=1 and uses real mouse clicks.
import { createServer } from "node:http";
import { readFile, mkdir, writeFile } from "node:fs/promises";
import { extname, join, normalize } from "node:path";
import { spawn } from "node:child_process";
import { fileURLToPath } from "node:url";
import { createHash } from "node:crypto";

const ROOT = fileURLToPath(new URL("..", import.meta.url));
const WEB = join(ROOT, "web");
const OUT = process.env.MIRROR_ACCEPT_OUT || "/tmp/mirror-accept";
const BUTTON = { x: 724, y: 579 };
const MIRROR = { x: 700, y: 390, w: 140, h: 140 };
const TYPES = {
  ".html": "text/html",
  ".js": "text/javascript",
  ".wasm": "application/wasm",
  ".pck": "application/octet-stream",
  ".png": "image/png",
  ".webp": "image/webp",
  ".svg": "image/svg+xml",
  ".ico": "image/x-icon",
};

function serve() {
  return new Promise((resolve) => {
    const server = createServer(async (req, res) => {
      const url = new URL(req.url, "http://127.0.0.1");
      let path = decodeURIComponent(url.pathname);
      if (path.endsWith("/")) path += "index.html";
      const file = normalize(join(WEB, path));
      if (!file.startsWith(WEB)) {
        res.writeHead(403);
        res.end();
        return;
      }
      try {
        const body = await readFile(file);
        res.writeHead(200, { "Content-Type": TYPES[extname(file)] || "application/octet-stream", "Cache-Control": "no-store" });
        res.end(body);
      } catch {
        res.writeHead(404);
        res.end();
      }
    });
    server.listen(0, "127.0.0.1", () => resolve(server));
  });
}

function run(cmd, args) {
  return new Promise((resolve, reject) => {
    const child = spawn(cmd, args, { stdio: ["ignore", "pipe", "pipe"] });
    let out = "";
    let err = "";
    child.stdout.on("data", (chunk) => { out += chunk; });
    child.stderr.on("data", (chunk) => { err += chunk; });
    child.on("close", (code) => code === 0 ? resolve(out) : reject(new Error(err || `${cmd} ${code}`)));
  });
}

async function ocr(image) {
  const prepared = image.replace(/\.png$/, "-ocr.png");
  await run("python3", ["-c", `
from PIL import Image, ImageOps
im = Image.open(${JSON.stringify(image)}).convert("L")
im = ImageOps.autocontrast(im)
im = ImageOps.invert(im)
im = im.resize((im.width * 2, im.height * 2), Image.Resampling.LANCZOS)
im.save(${JSON.stringify(prepared)})
`]);
  return run("tesseract", [prepared, "stdout", "-l", "chi_sim+eng", "--psm", "6"]);
}

async function cropHash(image) {
  const cropped = image.replace(/\.png$/, "-mirror.png");
  await run("python3", ["-c", `
from PIL import Image
import hashlib
im = Image.open(${JSON.stringify(image)}).crop((${MIRROR.x}, ${MIRROR.y}, ${MIRROR.x + MIRROR.w}, ${MIRROR.y + MIRROR.h}))
im.save(${JSON.stringify(cropped)})
print(hashlib.sha256(im.tobytes()).hexdigest())
`]);
  const text = await readFile(cropped);
  return createHash("sha256").update(text).digest("hex");
}

async function boot(page, port, tag) {
  await page.goto(`http://127.0.0.1:${port}/index.html?mirror=1&r=${tag}`, { waitUntil: "domcontentloaded", timeout: 60000 });
  await page.waitForFunction(() => {
    const button = document.querySelector("#intro-enter");
    return !!button && !button.disabled;
  }, null, { timeout: 90000 });
  await page.click("#intro-enter");
  await page.waitForFunction(() => !document.querySelector("#status"), null, { timeout: 15000 });
  await page.click("#canvas");
  await page.waitForTimeout(1500);
}

async function main() {
  const spec = process.env.PLAYWRIGHT_MODULE || "playwright/index.mjs";
  const { chromium } = await import(spec);
  await mkdir(OUT, { recursive: true });
  const server = await serve();
  const port = server.address().port;
  const browser = await chromium.launch({
    executablePath: process.env.CHROME || "/usr/local/bin/google-chrome",
    headless: true,
    args: ["--use-gl=angle", "--use-angle=swiftshader", "--enable-unsafe-swiftshader"],
  });
  const results = [];
  try {
    const fresh = async () => {
      const context = await browser.newContext({ viewport: { width: 1280, height: 720 }, deviceScaleFactor: 1 });
      const page = await context.newPage();
      return { context, page };
    };
    let session = await fresh();
    let page = session.page;
    await boot(page, port, "gray");
    await page.mouse.click(BUTTON.x, BUTTON.y);
    await page.waitForTimeout(400);
    const grayShot = join(OUT, "gray-click.png");
    await page.screenshot({ path: grayShot });
    const grayText = await ocr(grayShot);
    const grayOk = grayText.includes("旁边") && grayText.includes("再转") && !grayText.includes("栈桥正在转动");
    results.push({ name: "gray", ok: grayOk, text: grayText.replace(/\s+/g, " ").slice(0, 300) });
    console.log("GRAY", grayOk);
    console.log(grayText);

    await page.keyboard.press("ArrowRight");
    await page.waitForTimeout(400);
    await page.screenshot({ path: join(OUT, "beside.png") });
    await page.mouse.click(BUTTON.x, BUTTON.y);
    await page.waitForTimeout(1200);
    const oneShot = join(OUT, "one-turn.png");
    await page.screenshot({ path: oneShot });
    const oneHash = await cropHash(oneShot);

    for (const gap of [500, 1500]) {
      await session.context.close();
      session = await fresh();
      page = session.page;
      await boot(page, port, String(gap));
      await page.keyboard.press("ArrowRight");
      await page.waitForTimeout(400);
      await page.mouse.click(BUTTON.x, BUTTON.y);
      await page.waitForTimeout(gap);
      await page.mouse.click(BUTTON.x, BUTTON.y);
      await page.waitForTimeout(2200);
      const shot = join(OUT, `two-${gap}.png`);
      await page.screenshot({ path: shot });
      const hash = await cropHash(shot);
      const ok = hash !== oneHash;
      results.push({ name: `gap-${gap}`, ok, hash, oneHash });
      console.log(`GAP ${gap} changed=${ok}`);
    }
  } finally {
    await browser.close();
    server.close();
  }
  await writeFile(join(OUT, "results.json"), JSON.stringify(results, null, 2));
  if (results.some((item) => !item.ok)) {
    console.error("FAILED", results.filter((item) => !item.ok).map((item) => item.name).join(","));
    process.exit(1);
  }
  console.log("MIRROR CLICKS OK");
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
