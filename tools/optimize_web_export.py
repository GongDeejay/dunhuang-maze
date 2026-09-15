#!/usr/bin/env python3
"""Improve perceived Web startup and emit pre-compressed static assets."""

from __future__ import annotations

import argparse
import gzip
import re
from pathlib import Path


STYLE = """
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


def optimize_html(path: Path) -> str:
    html = path.read_text(encoding="utf-8")
    match = re.search(r'"executable":"([^"]+)"', html)
    if not match:
        raise SystemExit(f"Cannot find executable name in {path}")
    executable = match.group(1)
    if 'id="status-copy"' in html:
        return executable

    html = html.replace('<html lang="en">', '<html lang="zh-CN">', 1)
    html = html.replace(
        "\t\t</style>",
        STYLE + "\n\t\t</style>",
        1,
    )
    preload = (
        f'\t\t<link rel="preload" href="{executable}.wasm" as="fetch" '
        'type="application/wasm" crossorigin>\n'
        f'\t\t<link rel="preload" href="{executable}.pck" as="fetch" crossorigin>\n'
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


def gzip_assets(directory: Path, executable: str) -> None:
    for suffix in (".wasm", ".pck", ".js"):
        source = directory / f"{executable}{suffix}"
        if not source.exists():
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
    executable = optimize_html(directory / args.html)
    gzip_assets(directory, executable)
    print(f"Optimized Web export: {directory / args.html} ({executable})")


if __name__ == "__main__":
    main()
