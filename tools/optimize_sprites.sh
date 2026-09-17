#!/usr/bin/env bash
# 从上一版原图生成无损像素矢量；避免同步另一套造型。
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

"${GODOT_BIN:-godot}" --headless --path . --script tools/vectorize_characters.gd
"${GODOT_BIN:-godot}" --headless --path . --import --quit
