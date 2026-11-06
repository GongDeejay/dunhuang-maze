#!/usr/bin/env python3
"""Build an isolated browser-test entry point; never alter the production project.

Usage: python3 tools/export_browser_probe.py third
Serve artifacts/third-probe-export locally, then run verify_third_chapter.mjs.
"""
import argparse
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("chapter", choices=["first", "third", "mogao", "bridge", "cave"])
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    scenes = {"first": "first_journey_probe", "third": "third_chapter_probe", "mogao": "cave_probe", "bridge": "bridge_probe", "cave": "cave_probe"}
    scene = scenes[args.chapter]
    output = root / "artifacts" / ("first-journey-probe-export" if args.chapter == "first" else f"{args.chapter}-probe-export")
    output.mkdir(parents=True, exist_ok=True)
    env = dict(os.environ, BECKETT_ENABLE="0")
    godot = os.environ.get("GODOT", "godot")
    with tempfile.TemporaryDirectory(prefix="dunhuang-browser-probe-") as temporary:
        project = Path(temporary)
        for folder in ["assets", "scripts", "scenes", "addons", "tests"]:
            shutil.copytree(root / folder, project / folder, ignore=shutil.ignore_patterns("__pycache__"))
        config = (root / "project.godot").read_text()
        config = re.sub(r'^run/main_scene=.*$', f'run/main_scene="res://tests/{scene}.tscn"', config, flags=re.M)
        if args.chapter in ("mogao", "bridge", "cave"):
            config = re.sub(r'^config/name=.*$', f'config/name="Dunhuang {args.chapter.title()} Slice Preview"', config, flags=re.M)
        (project / "project.godot").write_text(config)
        excluded_probes = ", ".join(f"tests/{name}*" for name in sorted(set(scenes.values())) if name != scene)
        excluded_probes += ", tests/mogao_probe*" # Retired random-maze probe; `mogao` now aliases the cave.
        if args.chapter != "bridge":
            excluded_probes += ", tests/bridge_slice/**"
        presets = (root / "export_presets.cfg").read_text().replace(
            "tests/**", f"tests/test_*, tests/mobile_input_*, {excluded_probes}")
        (project / "export_presets.cfg").write_text(presets)
        subprocess.run([godot, "--headless", "--path", str(project), "--import", "--quit"], check=True, env=env)
        subprocess.run([godot, "--headless", "--path", str(project), "--export-release", "Web", str(output / "index.html")], check=True, env=env)
    if args.chapter == "bridge":
        # Preview only: prevent the old inline canvas width expanding the mobile
        # layout viewport after landscape -> portrait. Keep browser zoom enabled.
        html = output / "index.html"
        html.write_text(html.read_text().replace("</head>",
            '<style id="bridge-preview-viewport">html,body{width:100%;height:100%;overflow:hidden}'
            '#canvas{position:fixed;inset:0;width:100%!important;height:100%!important}</style></head>'))
    subprocess.run(["python3", str(root / "tools/optimize_web_export.py"), str(output)], check=True, env=env)
    print(f"TEST ONLY — do not deploy: {output}")


if __name__ == "__main__":
    main()
