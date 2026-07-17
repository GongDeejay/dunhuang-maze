#!/usr/bin/env bash
# 从 art/ 源稿同步角色高清贴图，并规范化 UI 图标尺寸
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "==> Sync 32x32 character sprites from art/"
cp -f assets/art/1.png assets/high_quality/player/dj.png
cp -f assets/art/2.png assets/high_quality/player/le.png
cp -f assets/art/3.png assets/high_quality/player/mac.png
cp -f assets/art/4.png assets/high_quality/player/mcking.png
rm -f assets/high_quality/player/*.import

echo "==> Scale heart icons to 18x18 (mobile HUD)"
if command -v sips >/dev/null 2>&1; then
  sips -z 18 18 assets/sprites/heart/full.png >/dev/null
  sips -z 18 18 assets/sprites/heart/empty.png >/dev/null
else
  echo "WARN: sips not found, skip heart resize"
fi

echo "==> Done. Re-import in Godot: godot --headless --path . --import --quit"
for f in assets/high_quality/player/*.png assets/sprites/heart/*.png; do
  if command -v sips >/dev/null 2>&1; then
    sips -g pixelWidth -g pixelHeight "$f" 2>/dev/null | awk -v f="$f" '/pixelWidth/{w=$2} /pixelHeight/{print "  " w "x" $2, f}'
  fi
done
