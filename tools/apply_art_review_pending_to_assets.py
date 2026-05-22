# -*- coding: utf-8 -*-
"""Copy art_review_pending files (Chinese names) to assets/* using _mapping.txt left column paths."""
from __future__ import annotations

import shutil
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
PENDING = REPO / "art_review_pending"
MAP_FILE = PENDING / "_mapping.txt"
ASSETS = REPO / "assets"


def main() -> int:
    if not MAP_FILE.is_file():
        print("Missing", MAP_FILE, file=sys.stderr)
        return 1
    raw = MAP_FILE.read_text(encoding="utf-8-sig")
    pairs: list[tuple[str, str]] = []
    for line in raw.splitlines():
        line = line.strip()
        if " -> " not in line:
            continue
        a, b = line.split(" -> ", 1)
        pairs.append((a.strip().lstrip("\ufeff"), b.strip()))

    for src_rel, pending_name in pairs:
        src_path = ASSETS / src_rel.replace("/", "\\")
        pend = PENDING / pending_name
        if not pend.is_file():
            # Pending folder may be missing the drop-specific energy icon; use card icon.
            if src_rel.replace("\\", "/") == "icons/drops/energy.png":
                alt = PENDING / "energy_能量图标.png"
                if alt.is_file():
                    pend = alt
                    print("WARN icons/drops/energy.png: using energy_能量图标.png (missing _1 in pending)", file=sys.stderr)
                else:
                    print("Missing pending file:", PENDING / pending_name, file=sys.stderr)
                    return 1
            else:
                print("Missing pending file:", PENDING / pending_name, file=sys.stderr)
                return 1
        src_path.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(pend, src_path)
        print("OK", src_rel)

    print("Done:", len(pairs), "files ->", ASSETS)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
