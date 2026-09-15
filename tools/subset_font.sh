#!/usr/bin/env bash
# Regenerate the Web game font from characters used by runtime scripts/config.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if ! command -v pyftsubset >/dev/null 2>&1; then
	echo "ERROR: pyftsubset not found. Install fonttools first."
	exit 1
fi

pyftsubset assets/fonts/NotoSansSC-Regular.ttf \
	--output-file=assets/fonts/NotoSansSC-GameSubset.ttf \
	--text-file=<(rg --text --no-filename '.' scripts assets/data project.godot) \
	--unicodes='U+0020-007E,U+00A0-00FF,U+2000-206F,U+2190-22FF,U+2500-25FF,U+3000-303F,U+FF00-FFEF' \
	--layout-features='*' \
	--glyph-names \
	--symbol-cmap \
	--legacy-cmap \
	--notdef-glyph \
	--notdef-outline \
	--recommended-glyphs

echo "Generated assets/fonts/NotoSansSC-GameSubset.ttf"
ls -lh assets/fonts/NotoSansSC-GameSubset.ttf
