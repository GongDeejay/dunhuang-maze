// Local check: after the mirrors are solved, a real click and the space key
// both leave the mirror cave for the deer cave. Not part of CI.
import { createServer } from "node:http";
import { readFile, mkdir } from "node:fs/promises";
import { extname, join, normalize } from "node:path";
import { spawn } from "node:child_process";
import { fileURLToPath } from "node:url";

const ROOT = fileURLToPath(new URL("..", import.meta.url));
const WEB = join(ROOT, "web");
const OUT = process.env.MIRROR_EXIT_OUT || "/tmp/mirror-exit";
const BUTTON = { x: 724, y: 579 };
const KEY = { U: "ArrowUp", D: "ArrowDown", L: "ArrowLeft", R: "ArrowRight" };
const TYPES = {
  ".html": "text/html", ".js": "text/javascript", ".wasm": "application/wasm",
  ".pck": "application/octet-stream", ".png": "image/png", ".webp": "image/webp",
  ".svg": "image/svg+xml", ".ico": "image/x-icon",
};

function serve() {
  return new Promise((resolve) => {
    const server = createServer(async (req, res) => {
      const url = new URL(req.url, "http://127.0.0.1");
      let path = decodeURIComponent(url.pathname);
      if (path.endsWith("/")) path += "index.html";
      const file = normalize(join(WEB, path));
      if (!file.startsWith(WEB)) { res.writeHead(403); res.end(); return; }
      try {
        const body = await readFile(file);
        res.writeHead(200, { "Content-Type": TYPES[extname(file)] || "application/octet-stream", "Cache-Control": "no-store" });
        res.end(body);
      } catch { res.writeHead(404); res.end(); }
    });
    server.listen(0, "127.0.0.1", () => resolve(server));
  });
}

function run(cmd, args) {
  return new Promise((resolve, reject) => {
    const child = spawn(cmd, args, { stdio: ["ignore", "pipe", "pipe"] });
    let out = ""; let err = "";
    child.stdout.on("data", (c) => { out += c; });
    child.stderr.on("data", (c) => { err += c; });
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

async function boot(page, url) {
  await page.goto(url, { waitUntil: "domcontentloaded", timeout: 60000 });
  await page.waitForFunction(() => {
    const button = document.querySelector("#intro-enter");
    return !!button && !button.disabled;
  }, null, { timeout: 90000 });
  await page.click("#intro-enter");
  await page.waitForFunction(() => !document.querySelector("#status"), null, { timeout: 20000 });
  await page.click("#canvas");
  await page.waitForTimeout(1200);
}

async function steps(page, route) {
  for (const ch of route) {
    await page.keyboard.press(KEY[ch]);
    await page.waitForTimeout(280);
  }
}

async function turns(page, count) {
  for (let i = 0; i < count; i++) {
    await page.mouse.click(BUTTON.x, BUTTON.y);
    await page.waitForTimeout(900);
  }
}

async function solve(page) {
  await steps(page, "R");
  await turns(page, 2);
  await steps(page, "RUUUUUU");
  await turns(page, 3);
  await steps(page, "ULLLLLLDDDD");
  await turns(page, 1);
  await steps(page, "UUUURRRU");
  await page.waitForTimeout(400);
}

async function main() {
  const spec = process.env.PLAYWRIGHT_MODULE || "playwright/index.mjs";
  const { chromium } = await import(spec);
  await mkdir(OUT, { recursive: true });
  const base = process.env.MIRROR_EXIT_URL;
  let server = null;
  let url = base;
  if (!url) {
    server = await serve();
    url = `http://127.0.0.1:${server.address().port}/index.html?mirror=1`;
  }
  const browser = await chromium.launch({
    executablePath: process.env.CHROME || "/usr/local/bin/google-chrome",
    headless: true,
    args: ["--use-gl=angle", "--use-angle=swiftshader", "--enable-unsafe-swiftshader"],
  });
  const how = process.env.MIRROR_EXIT_HOW || "click";
  try {
    const page = await browser.newPage({ viewport: { width: 1280, height: 720 }, deviceScaleFactor: 1 });
    await boot(page, url);
    await solve(page);
    const before = join(OUT, "before-enter.png");
    await page.screenshot({ path: before });
    if (how === "space") {
      await page.keyboard.press("Space");
    } else if (how === "walk") {
      await page.keyboard.press("ArrowDown");
      await page.waitForTimeout(300);
      await page.keyboard.press("ArrowUp");
      await page.waitForTimeout(300);
      await page.keyboard.press("Space");
    } else {
      await page.mouse.click(BUTTON.x, BUTTON.y);
    }
    await page.waitForTimeout(800);
    const after = join(OUT, "after-enter.png");
    await page.screenshot({ path: after });
    const text = await ocr(after);
    const stuck = text.includes("旁边再转") || text.includes("进入鹿");
    const entered = !stuck && (text.includes("鹿影") || text.includes("提起灯") || text.includes("河里"));
    console.log(text);
    console.log(entered ? "ENTERED 鹿影窟" : "STILL STUCK");
    if (!entered) process.exit(1);
  } finally {
    await browser.close();
    if (server) server.close();
  }
}

main().catch((err) => { console.error(err); process.exit(1); });
