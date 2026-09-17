#!/usr/bin/env python3
"""Improve perceived Web startup and emit pre-compressed static assets."""

from __future__ import annotations

import argparse
import gzip
import hashlib
import json
import re
import shutil
from pathlib import Path


STYLE = """
html { font-family: system-ui, -apple-system, sans-serif; font-size: 100%; }
@supports (font: -apple-system-body) {
	html { font: -apple-system-body; }
}
#status { background: radial-gradient(ellipse at center, #33291c, #17140f); }
#status-splash { display: none; }
#status-copy {
	display: flex;
	flex-direction: column;
	gap: 0.5rem;
	margin-top: 1.25rem;
	text-align: center;
	font-family: system-ui, -apple-system, "Noto Sans SC", sans-serif;
}
#status-copy strong { color: #e6c98f; font-size: 1.35rem; font-weight: 600; }
#status-detail { color: #b9aa91; font-size: 0.9rem; }
#status-progress {
	position: static;
	margin-top: 1.25rem;
	height: 0.55rem;
	max-width: 26rem;
	accent-color: #d5a936;
}
"""


def content_address_assets(directory: Path, html_path: Path, runtime_lock: dict | None = None) -> None:
    """Keep the engine URL stable across game-only releases (including worklets)."""
    html = html_path.read_text(encoding="utf-8")
    match = re.search(r'const GODOT_CONFIG = (\{[^\n]+\});', html)
    if not match:
        raise ValueError("Missing Godot configuration")
    config = json.loads(match.group(1))
    old = config["executable"]
    pack = config.get("mainPack") or f"{old}.pck"
    runtime_files = sorted(
        p for p in directory.glob(f"{old}.*")
        if p.suffix in (".wasm", ".js")
    )
    if not runtime_files or not (directory / f"{old}.wasm").is_file():
        raise ValueError("Missing engine WASM")
    digest = hashlib.sha256()
    for source in runtime_files:
        # Include suffixes, not build-specific names, in the runtime bundle hash.
        digest.update(source.name[len(old):].encode())
        digest.update(hashlib.sha256(source.read_bytes()).digest())
    runtime_hash = digest.hexdigest()
    runtime = f"engine-{runtime_hash[:24]}"
    if runtime_lock is not None:
        if runtime_hash != runtime_lock["sha256"] or runtime != runtime_lock["executable"]:
            raise ValueError("Godot runtime differs from deploy/godot-runtime-lock.json. "
                             "Ordinary releases must reuse the pinned engine. "
                             "Upgrade the engine and lock explicitly; never overwrite its cached URL.")
        runtime = runtime_lock["executable"]
    pack_name = f"game-{hashlib.sha256((directory / pack).read_bytes()).hexdigest()[:24]}.pck"
    mapping = {p.name: runtime + p.name[len(old):] for p in runtime_files}
    mapping[pack] = pack_name
    for source, target in mapping.items():
        if source != target:
            (directory / source).rename(directory / target)
        html = html.replace(source, target)
    config["executable"] = runtime
    config["mainPack"] = pack_name
    config["fileSizes"] = {mapping.get(k, k): v for k, v in config.get("fileSizes", {}).items()}
    html = re.sub(r'const GODOT_CONFIG = \{[^\n]+\};',
                  "const GODOT_CONFIG = " + json.dumps(config, separators=(",", ":")) + ";", html)
    html_path.write_text(html, encoding="utf-8")


def optimize_html(path: Path) -> str:
    html = path.read_text(encoding="utf-8")
    match = re.search(r'"executable":"([^"]+)"', html)
    if not match:
        raise SystemExit(f"Cannot find executable name in {path}")
    executable = match.group(1)
    pack_match = re.search(r'"mainPack":"([^"]+)"', html)
    pack = pack_match.group(1) if pack_match else f"{executable}.pck"
    if 'id="status-copy"' in html:
        return executable

    html = html.replace('<html lang="en">', '<html lang="zh-CN">', 1)
    html = html.replace('width=device-width, user-scalable=no, initial-scale=1.0',
                        'width=device-width, initial-scale=1.0')
    html = html.replace(
        "\t\t</style>",
        STYLE + "\n\t\t</style>",
        1,
    )
    preload = (
        f'\t\t<link rel="preload" href="{executable}.wasm" as="fetch" '
        'type="application/wasm" crossorigin>\n'
        f'\t\t<link rel="preload" href="{pack}" as="fetch" crossorigin>\n'
    )
    html = html.replace("\t</head>", preload + "\n\t</head>", 1)
    html = html.replace(
        "\t\t\t<progress id=\"status-progress\"></progress>",
        "\t\t\t<div id=\"status-copy\"><strong>敦煌迷途</strong>"
        "<span id=\"status-detail\">正在准备旅途…</span></div>\n"
        "\t\t\t<progress id=\"status-progress\"></progress>",
        1,
    )
    html = html.replace(
        "const statusProgress = document.getElementById('status-progress');",
        "const statusProgress = document.getElementById('status-progress');\n"
        "\tconst statusDetail = document.getElementById('status-detail');",
        1,
    )
    html = html.replace(
        "statusProgress.max = total;",
        "statusProgress.max = total;\n"
        "\t\t\t\t\tstatusDetail.textContent = current >= total ? '资源就绪，正在进入敦煌…' : `正在加载 ${Math.round(current / total * 100)}%`;",
        1,
    )
    path.write_text(html, encoding="utf-8")
    return executable


def install_intro(directory: Path, html_path: Path) -> None:
    source = Path(__file__).resolve().parents[1] / "deploy" / "loading"
    html = html_path.read_text(encoding="utf-8")
    if 'id="intro-title"' in html:
        return
    artwork = source / "family.webp"
    image_name = f"intro-{hashlib.sha256(artwork.read_bytes()).hexdigest()[:16]}.webp"
    shutil.copyfile(artwork, directory / image_name)
    html = html.replace('<link rel="preload"',
                        f'<link rel="preload" href="{image_name}" as="image" fetchpriority="high">\n\t\t<link rel="preload"', 1)
    markup = (source / "intro.html").read_text(encoding="utf-8").replace("__FAMILY_IMAGE__", image_name)
    html, count = re.subn(r'<div id="status">.*?<div id="status-notice"></div>\s*</div>',
                         lambda _: markup, html, count=1, flags=re.DOTALL)
    if count != 1:
        raise ValueError("Godot loading markup changed; intro integration needs review")
    html = html.replace("\t\t</style>", (source / "intro.css").read_text(encoding="utf-8") + "\n\t\t</style>", 1)
    intro_js = (source / "intro.js").read_text(encoding="utf-8")
    html = html.replace('<script src="', '<script>' + intro_js + '</script>\n\t\t<script onerror="window.dunhuangIntro.fail(\'引擎下载失败，请检查网络后重试。\')" src="', 1)
    html = html.replace("statusOverlay.remove();", "window.dunhuangIntro.ready();", 1)
    html = html.replace('"focusCanvas":true', '"focusCanvas":false', 1)
    html = html.replace("const engine = new Engine(GODOT_CONFIG);", "const engine = typeof Engine === 'function' ? new Engine(GODOT_CONFIG) : null;")
    html = html.replace("(function () {\n\tconst statusOverlay", "(function () {\n\tif (!engine) return;\n\tconst statusOverlay", 1)
    html = html.replace("function displayFailureNotice(err) {", "function displayFailureNotice(err) {\n\t\twindow.dunhuangIntro.fail('旅途暂时无法启动，请重试。');", 1)
    html_path.write_text(html, encoding="utf-8")


def gzip_assets(directory: Path) -> None:
    for source in directory.iterdir():
        if source.suffix not in (".wasm", ".pck", ".js"):
            continue
        target = source.with_name(source.name + ".gz")
        with source.open("rb") as src, target.open("wb") as raw:
            with gzip.GzipFile(filename="", mode="wb", fileobj=raw, compresslevel=9, mtime=0) as dst:
                while chunk := src.read(1024 * 1024):
                    dst.write(chunk)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("directory", type=Path)
    parser.add_argument("--html", default="index.html")
    args = parser.parse_args()
    directory = args.directory.resolve()
    lock_path = Path(__file__).resolve().parents[1] / "deploy" / "godot-runtime-lock.json"
    content_address_assets(directory, directory / args.html, json.loads(lock_path.read_text()))
    executable = optimize_html(directory / args.html)
    install_intro(directory, directory / args.html)
    gzip_assets(directory)
    print(f"Optimized Web export: {directory / args.html} ({executable})")


if __name__ == "__main__":
    main()
