#!/usr/bin/env python3
"""Require one nonempty game pack strictly below 2 MiB, without find's unit rounding."""
from pathlib import Path
import sys

MAX_PACK_BYTES = 2 * 1024 * 1024


def verify_pack_budget(directory: Path) -> int:
    packs = sorted(path for path in directory.rglob("*.pck") if path.is_file())
    if len(packs) != 1:
        raise ValueError(f"Expected exactly one .pck, found {len(packs)}")
    size = packs[0].stat().st_size
    if not 0 < size < MAX_PACK_BYTES:
        raise ValueError(f"{packs[0].name}: {size} bytes; required 0 < size < {MAX_PACK_BYTES}")
    return size


if __name__ == "__main__":
    try:
        size = verify_pack_budget(Path(sys.argv[1]))
    except (ValueError, OSError, IndexError) as error:
        sys.exit(str(error))
    print(f"Startup pack: {size} bytes < {MAX_PACK_BYTES} bytes PASS")
