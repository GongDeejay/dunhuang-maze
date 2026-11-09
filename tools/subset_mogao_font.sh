#!/usr/bin/env bash
# Regenerate the Mogao chapter font from every chapter-2 script.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
pyftsubset assets/fonts/NotoSansSC-Regular.ttf \
  --output-file=assets/fonts/MogaoSubset.ttf \
  --text-file=<(rg --text --no-filename '.' scripts/mogao_chapter) \
  --unicodes='U+0020-007E,U+00A0-00FF,U+2000-206F,U+2190-22FF,U+2500-25FF,U+3000-303F,U+FF00-FFEF' \
  --layout-features='*' \
  --glyph-names \
  --symbol-cmap \
  --legacy-cmap \
  --notdef-glyph \
  --notdef-outline \
  --recommended-glyphs
echo "Generated assets/fonts/MogaoSubset.ttf"
ls -lh assets/fonts/MogaoSubset.ttf
