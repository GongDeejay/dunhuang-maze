#!/usr/bin/env python3
"""对比两次 MANIFEST.json，输出增量部署文件列表。"""
from __future__ import annotations

import json
import sys
from pathlib import Path


def load_manifest(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def file_map(manifest: dict) -> dict[str, dict]:
    return {item["name"]: item for item in manifest.get("files", [])}


def main() -> int:
    if len(sys.argv) < 2:
        print("Usage: diff_deploy_manifest.py <web_dir> [baseline_manifest]", file=sys.stderr)
        return 1

    web_dir = Path(sys.argv[1])
    current_path = web_dir / "MANIFEST.json"
    baseline_path = Path(sys.argv[2]) if len(sys.argv) > 2 else web_dir / ".last_deploy_manifest.json"

    if not current_path.is_file():
        print(f"ERROR: missing {current_path}", file=sys.stderr)
        return 1

    current = load_manifest(current_path)
    current_files = file_map(current)

    changed: list[str] = []
    added: list[str] = []
    removed: list[str] = []

    if baseline_path.is_file():
        baseline = load_manifest(baseline_path)
        baseline_files = file_map(baseline)
        for name, meta in current_files.items():
            old = baseline_files.get(name)
            if old is None:
                added.append(name)
            elif old.get("sha256") != meta.get("sha256"):
                changed.append(name)
        for name in baseline_files:
            if name not in current_files:
                removed.append(name)
    else:
        changed = sorted(current_files.keys())

    out = {
        "baseline": str(baseline_path) if baseline_path.is_file() else None,
        "current": str(current_path),
        "build_time_utc": current.get("build_time_utc"),
        "git_revision": current.get("git_revision"),
        "changed": sorted(changed),
        "added": sorted(added),
        "removed": sorted(removed),
        "upload": sorted(set(changed + added)),
    }

    incremental_path = web_dir / "INCREMENTAL.json"
    incremental_path.write_text(json.dumps(out, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    files_from = web_dir / "rsync_files.txt"
    files_from.write_text("\n".join(out["upload"]) + ("\n" if out["upload"] else ""), encoding="utf-8")

    print(f"Incremental: {len(out['upload'])} file(s) to upload")
    for name in out["upload"]:
        print(f"  + {name}")
    if out["removed"]:
        print("Removed on server (manual cleanup if needed):")
        for name in out["removed"]:
            print(f"  - {name}")
    print(f"Wrote {incremental_path}")
    print(f"Wrote {files_from}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
