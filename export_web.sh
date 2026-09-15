#!/usr/bin/env bash
# Web 完整导出 → web/（PC + 移动浏览器同包）+ 部署描述文件
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

GODOT="${GODOT:-godot}"
if ! command -v "$GODOT" >/dev/null 2>&1; then
  for c in \
    "/Users/gongdj/Downloads/Godot.app/Contents/MacOS/Godot" \
    "/Applications/Godot.app/Contents/MacOS/Godot"; do
    if [[ -x "$c" ]]; then GODOT="$c"; break; fi
  done
fi

if ! command -v "$GODOT" >/dev/null 2>&1; then
  echo "ERROR: Godot not found. Set GODOT= path to binary."
  exit 1
fi

echo "==> Run tests"
BECKETT_ENABLE=0 GODOT="$GODOT" ./run_tests.sh

mkdir -p web
echo "==> Import assets"
BECKETT_ENABLE=0 "$GODOT" --headless --path . --import --quit 2>&1 | tail -3

echo "==> Export Web → web/index.html"
BECKETT_ENABLE=0 "$GODOT" --headless --path . --export-release "Web" "web/index.html"

echo "==> Optimize startup shell + pre-compress Web assets"
python3 tools/optimize_web_export.py web

echo "==> Copy deployment docs"
cp -f deploy/DEPLOY.md web/DEPLOY.md
cp -f deploy/nginx.conf.example web/nginx.conf.example
cp -f deploy/apache.htaccess.example web/apache.htaccess.example
cp -f deploy/project.conf web/project.conf

echo "==> Generate MANIFEST.json + VERSION.txt"
python3 tools/generate_web_manifest.py web

chmod +x tools/serve_web.py 2>/dev/null || true

echo ""
echo "==> Export complete (deploy-ready):"
ls -lh web/index.html web/index.pck web/index.wasm web/MANIFEST.json web/VERSION.txt web/DEPLOY.md 2>/dev/null
echo ""
echo "Local smoke:  python3 tools/serve_web.py --port 8060"
echo "Deploy:       rsync -avz web/ user@server:/www/wwwroot/maze.mplusm.site/"
