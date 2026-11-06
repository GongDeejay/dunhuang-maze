#!/usr/bin/env bash
# Only regenerate the second chapter font; do not churn the other chapters' font.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
pyftsubset assets/fonts/NotoSansSC-Regular.ttf \
  --output-file=assets/fonts/MogaoSubset.ttf \
  --text-file=scripts/mogao_chapter/cave_chapter.gd \
  --unicodes='U+0020-007E,U+2190-22FF,U+3000-303F' \
  --layout-features='*' --notdef-glyph --notdef-outline --recommended-glyphs
