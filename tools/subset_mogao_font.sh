#!/usr/bin/env bash
# Mogao chapter font. Every on-screen chapter-2 string is in scope:
# cave scripts, mirror_*.gd, and any JSON placed beside them.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
mapfile -d '' SOURCES < <(find scripts/mogao_chapter -type f \( -name '*.gd' -o -name '*.json' \) -print0 | sort -z)
test "${#SOURCES[@]}" -gt 0
pyftsubset assets/fonts/NotoSansSC-Regular.ttf \
  --output-file=assets/fonts/MogaoSubset.ttf \
  --text-file=<(cat "${SOURCES[@]}") \
  --unicodes='U+0020-007E,U+00A0-00FF,U+2000-206F,U+2190-22FF,U+2500-25FF,U+3000-303F,U+FF00-FFEF' \
  --layout-features='*' \
  --glyph-names \
  --symbol-cmap \
  --legacy-cmap \
  --notdef-glyph \
  --notdef-outline \
  --recommended-glyphs
echo "Generated assets/fonts/MogaoSubset.ttf from ${#SOURCES[@]} chapter-2 files"
ls -lh assets/fonts/MogaoSubset.ttf
