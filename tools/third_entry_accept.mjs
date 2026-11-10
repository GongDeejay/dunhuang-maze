// Clicks the real 前往三危山 settlement button, then walks in the third chapter.
// Not part of CI. Does not change third-chapter rules.
import { createServer } from "node:http";
import { readFile, mkdir } from "node:fs/promises";
import { extname, join, normalize } from "node:path";
import { spawn } from "node:child_process";
import { fileURLToPath } from "node:url";

const ROOT = fileURLToPath(new URL("..", import.meta.url));
const WEB = join(ROOT, "web");
const OUT = process.env.THIRD_ENTRY_OUT || "/tmp/third-entry";
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
  const errors = [];
  page.on("pageerror", (err) => errors.push(String(err)));
  page.on("console", (msg) => { if (msg.type() === "error") errors.push(msg.text()); });
  await page.goto(url, { waitUntil: "domcontentloaded", timeout: 60000 });
  await page.waitForFunction(() => {
    const button = document.querySelector("#intro-enter");
    return !!button && !button.disabled;
  }, null, { timeout: 90000 });
  await page.click("#intro-enter");
  await page.waitForFunction(() => !document.querySelector("#status"), null, { timeout: 20000 });
  await page.waitForTimeout(1500);
  return errors;
}

async function main() {
  const spec = process.env.PLAYWRIGHT_MODULE || "playwright/index.mjs";
  const { chromium } = await import(spec);
  await mkdir(OUT, { recursive: true });
  const server = await serve();
  const url = `http://127.0.0.1:${server.address().port}/index.html?depart=1`;
  const browser = await chromium.launch({
    executablePath: process.env.CHROME || "/usr/local/bin/google-chrome",
    headless: true,
    args: ["--use-gl=angle", "--use-angle=swiftshader", "--enable-unsafe-swiftshader"],
  });
  try {
    const page = await browser.newPage({ viewport: { width: 1280, height: 720 }, deviceScaleFactor: 1 });
    const errors = await boot(page, url);
    const card = join(OUT, "settlement.png");
    await page.screenshot({ path: card });
    await page.mouse.click(640, 560);
    await page.waitForTimeout(1500);
    const welcome = join(OUT, "welcome.png");
    await page.screenshot({ path: welcome });
    const welcomeText = await ocr(welcome);
    await page.mouse.click(640, 560);
    await page.waitForTimeout(600);
    await page.keyboard.down("w");
    await page.waitForTimeout(800);
    await page.keyboard.up("w");
    await page.waitForTimeout(300);
    const walked = join(OUT, "walked.png");
    await page.screenshot({ path: walked });
    const walkedText = await ocr(walked);
    const entered = welcomeText.includes("三危") || welcomeText.includes("沙谷") || welcomeText.includes("弟弟");
    const spreadText = await run("python3", ["-c", `
from PIL import Image, ImageStat
im = Image.open(${JSON.stringify(walked)}).convert("RGB")
stat = ImageStat.Stat(im)
print(f"{max(stat.stddev):.2f}")
`]);
    const varied = Number(spreadText.trim()) > 8;
    console.log("WELCOME", welcomeText.replace(/\s+/g, " ").slice(0, 240));
    console.log("WALKED", walkedText.replace(/\s+/g, " ").slice(0, 240));
    console.log("spread", spreadText.trim(), "errors", errors.slice(0, 6));
    if (!entered || !varied) process.exit(1);
    console.log("THIRD CHAPTER ENTERED");
  } finally {
    await browser.close();
    server.close();
  }
}

main().catch((err) => { console.error(err); process.exit(1); });
