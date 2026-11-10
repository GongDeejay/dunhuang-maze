// Local acceptance for the plank cave. Not part of CI or the deploy pipeline.
// Serves the exported web/ directory, then sends real keydown/keyup for the
// 20-step route at 15ms, 80ms, and 125ms. Each run must reach 11/11 and open
// the rope gate. Screenshots are written next to this script's output dir.
import { createServer } from "node:http";
import { readFile, mkdir, writeFile } from "node:fs/promises";
import { extname, join, normalize } from "node:path";
import { spawn } from "node:child_process";
import { fileURLToPath } from "node:url";

const ROOT = fileURLToPath(new URL("..", import.meta.url));
const WEB = join(ROOT, "web");
const OUT = process.env.PLANK_ACCEPT_OUT || "/tmp/plank-accept";
const ROUTE = "UULUULUURRDDRRUULULU";
const KEYS = { U: "ArrowUp", L: "ArrowLeft", D: "ArrowDown", R: "ArrowRight" };
const GAPS = [15, 80, 125];
const TYPES = {
  ".html": "text/html",
  ".js": "text/javascript",
  ".wasm": "application/wasm",
  ".pck": "application/octet-stream",
  ".png": "image/png",
  ".webp": "image/webp",
  ".svg": "image/svg+xml",
  ".ico": "image/x-icon",
  ".json": "application/json",
  ".css": "text/css",
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
        res.writeHead(200, {
          "Content-Type": TYPES[extname(file)] || "application/octet-stream",
          "Cache-Control": "no-store",
        });
        res.end(body);
      } catch {
        res.writeHead(404);
        res.end();
      }
    });
    server.listen(0, "127.0.0.1", () => resolve(server));
  });
}

async function ocr(image) {
  const prepared = image.replace(/\.png$/, "-ocr.png");
  await new Promise((resolve, reject) => {
    const child = spawn("python3", ["-c", `
from PIL import Image, ImageOps
im = Image.open(${JSON.stringify(image)}).convert("L")
im = ImageOps.autocontrast(im)
im = ImageOps.invert(im)
im = im.resize((im.width * 2, im.height * 2), Image.Resampling.LANCZOS)
im.save(${JSON.stringify(prepared)})
`], { stdio: "inherit" });
    child.on("close", (code) => code === 0 ? resolve() : reject(new Error("ocr prep " + code)));
  });
  return new Promise((resolve, reject) => {
    const child = spawn("tesseract", [prepared, "stdout", "-l", "chi_sim+eng", "--psm", "6"], {
      stdio: ["ignore", "pipe", "pipe"],
    });
    let out = "";
    let err = "";
    child.stdout.on("data", (chunk) => { out += chunk; });
    child.stderr.on("data", (chunk) => { err += chunk; });
    child.on("close", (code) => {
      if (code === 0) resolve(out);
      else reject(new Error(err || `tesseract ${code}`));
    });
  });
}

async function waitForGame(page) {
  await page.waitForSelector("#canvas", { timeout: 60000 });
  await page.waitForFunction(() => {
    const enter = document.querySelector("#intro-enter");
    return !!enter && !enter.disabled;
  }, null, { timeout: 90000 });
  await page.click("#intro-enter");
  await page.waitForFunction(() => !document.querySelector("#status"), null, { timeout: 15000 });
  await page.click("#canvas");
  // The first cave frame arrives after the wasm instance is running.
  await page.waitForTimeout(2000);
}

async function play(page, gap) {
  for (const step of ROUTE) {
    const key = KEYS[step];
    await page.keyboard.down(key);
    await page.keyboard.up(key);
    await page.waitForTimeout(gap);
  }
  // The step animation is 0.18s, and the last press can still be in the queue.
  await page.waitForTimeout(6000);
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
    args: ["--use-gl=angle", "--use-angle=swiftshader"],
  });
  const results = [];
  try {
    for (const gap of GAPS) {
      const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
      const messages = [];
      page.on("console", (msg) => messages.push(msg.text()));
      page.on("pageerror", (err) => messages.push(String(err)));
      const url = `http://127.0.0.1:${port}/index.html?plank=1&gap=${gap}`;
      await page.goto(url, { waitUntil: "domcontentloaded", timeout: 60000 });
      try {
        await waitForGame(page);
      } catch (err) {
        const shot = join(OUT, `plank-${gap}ms-boot.png`);
        await page.screenshot({ path: shot }).catch(() => {});
        console.error("BOOT FAIL", gap, messages.slice(-12));
        throw err;
      }
      await play(page, gap);
      const shot = join(OUT, `plank-${gap}ms.png`);
      await page.screenshot({ path: shot });
      const text = await ocr(shot);
      await writeFile(join(OUT, `plank-${gap}ms.txt`), text);
      const solved = text.includes("11/11") && (text.includes("牢") || text.includes("绳") || text.includes("拉开"));
      results.push({ gap, shot, solved, text: text.replace(/\s+/g, " ").slice(0, 400), messages: messages.slice(-8) });
      console.log(`GAP ${gap} solved=${solved}`);
      console.log(text);
      await page.close();
    }
  } finally {
    await browser.close();
    server.close();
  }
  await writeFile(join(OUT, "results.json"), JSON.stringify(results, null, 2));
  const failed = results.filter((item) => !item.solved);
  if (failed.length) {
    console.error("FAILED", failed.map((item) => item.gap).join(","));
    process.exit(1);
  }
  console.log("ALL THREE GAPS REACHED 11/11");
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
