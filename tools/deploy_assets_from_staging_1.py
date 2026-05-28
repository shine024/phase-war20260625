# -*- coding: utf-8 -*-
"""Move staged PNGs from assets/1/ into canonical res:// paths."""
from __future__ import annotations

import os
import shutil

REPO = os.path.normpath(os.path.join(os.path.dirname(__file__), ".."))
STAGING = os.path.join(REPO, "assets", "1")

MOVES: list[tuple[str, str]] = [
    ("phase_field", "assets/phase_field"),
    ("drops", "assets/icons/drops"),
    ("resources", "assets/resources"),
    ("frames", "assets/cards/frames"),
    ("instruments", "assets/ui/instruments"),
]


def main() -> None:
    moved: list[str] = []
    skipped: list[str] = []
    for sub, dest_rel in MOVES:
        src_dir = os.path.join(STAGING, sub)
        dest_dir = os.path.join(REPO, dest_rel.replace("/", os.sep))
        if not os.path.isdir(src_dir):
            continue
        os.makedirs(dest_dir, exist_ok=True)
        for name in sorted(os.listdir(src_dir)):
            if not name.lower().endswith(".png"):
                continue
            src = os.path.join(src_dir, name)
            dest = os.path.join(dest_dir, name)
            if os.path.isfile(dest):
                skipped.append(f"{dest_rel}/{name} (target exists)")
                continue
            shutil.move(src, dest)
            moved.append(f"res://{dest_rel}/{name}")

    print(f"moved {len(moved)}")
    for p in moved:
        print(" ", p)
    if skipped:
        print(f"skipped {len(skipped)}")
        for s in skipped:
            print(" ", s)


if __name__ == "__main__":
    main()
