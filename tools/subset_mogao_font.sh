#!/usr/bin/env bash
# Mogao chapter font. Every string the cave theme can draw is in scope:
# chapter scripts, JSON beside them, and every GDScript they preload.
# Settlement time is built in measure_text.gd and drawn with this font.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
SOURCES="$(mktemp)"
python3 - "$SOURCES" <<'PY'
import pathlib, re, sys
root = pathlib.Path(".").resolve()
pending = []
for path in (root / "scripts/mogao_chapter").rglob("*"):
    if path.is_file() and path.suffix in {".gd", ".json"}:
        pending.append(path)
seen = set()
files = []
preload = re.compile(r'preload\("res://([^"]+\.gd)"\)')
while pending:
    path = pending.pop()
    key = path.resolve()
    if key in seen:
        continue
    seen.add(key)
    files.append(path)
    if path.suffix != ".gd":
        continue
    for rel in preload.findall(path.read_text(encoding="utf-8", errors="replace")):
        nxt = root / rel
        if nxt.is_file():
            pending.append(nxt)
files.sort()
pathlib.Path(sys.argv[1]).write_text("".join(path.read_text(encoding="utf-8", errors="replace") for path in files))
print(f"Mogao subset sources ({len(files)}):")
for path in files:
    print(f"  {path.relative_to(root)}")
PY
pyftsubset assets/fonts/NotoSansSC-Regular.ttf \
  --output-file=assets/fonts/MogaoSubset.ttf \
  --text-file="$SOURCES" \
  --unicodes='U+0020-007E,U+00A0-00FF,U+2000-206F,U+2190-22FF,U+2500-25FF,U+3000-303F,U+FF00-FFEF' \
  --layout-features='*' \
  --glyph-names \
  --symbol-cmap \
  --legacy-cmap \
  --notdef-glyph \
  --notdef-outline \
  --recommended-glyphs
rm -f "$SOURCES"
echo "Generated assets/fonts/MogaoSubset.ttf"
ls -lh assets/fonts/MogaoSubset.ttf
