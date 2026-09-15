#!/usr/bin/env python3
"""生成 web/MANIFEST.json 与 web/VERSION.txt"""
from __future__ import annotations

import hashlib
import json
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

SKIP_NAMES = {".DS_Store", "cert.pem", "key.pem", "MANIFEST.json", "VERSION.txt"}
SKIP_SUFFIXES = (".import",)
DEPLOY_ONLY = None  # None = all non-skipped; set to filter if needed


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(65536), b""):
            digest.update(chunk)
    return digest.hexdigest()


def git_revision(root: Path) -> str:
    try:
        out = subprocess.check_output(
            ["git", "rev-parse", "--short", "HEAD"],
            cwd=root,
            stderr=subprocess.DEVNULL,
            text=True,
        )
        return out.strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        return "unknown"


def describe_files(web_dir: Path) -> list[dict]:
    entries: list[dict] = []
    for path in sorted(web_dir.iterdir()):
        if not path.is_file() or path.name in SKIP_NAMES or path.name.startswith("."):
            continue
        if any(path.name.endswith(suffix) for suffix in SKIP_SUFFIXES):
            continue
        stat = path.stat()
        entries.append(
            {
                "name": path.name,
                "bytes": stat.st_size,
                "sha256": sha256_file(path),
            }
        )
    return entries


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    web_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else root / "web"
    if not web_dir.is_dir():
        print(f"ERROR: not a directory: {web_dir}", file=sys.stderr)
        return 1

    files = describe_files(web_dir)
    total = sum(item["bytes"] for item in files)
    built_at = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    revision = git_revision(root)

    manifest = {
        "project": "敦煌迷途",
        "project_en": "Dunhuang Maze",
        "entry": "index.html",
        "godot_version": "4.7",
        "build_time_utc": built_at,
        "git_revision": revision,
        "deploy": {
            "domain": "maze.mplusm.site",
            "web_root": "/www/wwwroot/maze.mplusm.site",
            "requires_https": True,
            "requires_cross_origin_isolation": True,
        },
        "headers_required": [
            "Cross-Origin-Opener-Policy: same-origin",
            "Cross-Origin-Embedder-Policy: require-corp",
        ],
        "total_bytes": total,
        "files": files,
    }

    manifest_path = web_dir / "MANIFEST.json"
    manifest_path.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    version_lines = [
        "敦煌迷途 Web 构建",
        f"build_time_utc: {built_at}",
        f"git_revision: {revision}",
        f"entry: index.html",
        f"total_bytes: {total}",
        f"file_count: {len(files)}",
        "",
        "核心文件:",
    ]
    for item in files:
        if item["name"].startswith(("index.", "game-")):
            version_lines.append(f"  {item['name']}\t{item['bytes']} bytes\tsha256:{item['sha256'][:16]}…")

    (web_dir / "VERSION.txt").write_text("\n".join(version_lines) + "\n", encoding="utf-8")

    print(f"Wrote {manifest_path} ({len(files)} files, {total} bytes)")
    print(f"Wrote {web_dir / 'VERSION.txt'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
