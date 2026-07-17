#!/usr/bin/env bash
# 增量 Web 导出：仅记录相对上次部署的变更文件
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

BASELINE="${1:-web/.last_deploy_manifest.json}"

echo "==> Full export (Godot always rebuilds pck)"
./export_web.sh

echo "==> Diff against baseline: ${BASELINE}"
python3 tools/diff_deploy_manifest.py web "${BASELINE}"

echo ""
echo "==> Incremental deploy (upload changed files only):"
echo "  rsync -avz --files-from=web/rsync_files.txt web/ root@43.133.145.77:/www/wwwroot/maze.mplusm.site/"
echo ""
echo "After deploy, snapshot baseline:"
echo "  cp web/MANIFEST.json web/.last_deploy_manifest.json"
