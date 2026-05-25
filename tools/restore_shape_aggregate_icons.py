#!/usr/bin/env python3
"""Restore card_icons root shape aggregates from units/vis_player_* (post-archive)."""

from __future__ import annotations

import shutil
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
UNITS = REPO / "assets" / "card_icons" / "units"
ROOT = REPO / "assets" / "card_icons"

SHAPE_FROM_VIS = {
    "hound": "vis_player_001",
    "titan": "vis_player_002",
    "fortress": "vis_player_003",
    "radar": "vis_player_004",
    "medic": "vis_player_005",
    "scout": "vis_player_006",
    "guard": "vis_player_007",
    "raider": "vis_player_009",
    "siege": "vis_player_011",
    "carrier": "vis_player_015",
    "stealth": "vis_player_023",
    "omega_platform": "vis_player_029",
    "energy": "vis_player_001",
    "law": "vis_player_004",
}


def main() -> None:
    copied = 0
    for shape, vis in SHAPE_FROM_VIS.items():
        src = UNITS / f"{vis}.png"
        dst = ROOT / f"{shape}.png"
        if not src.is_file():
            print("SKIP missing", src)
            continue
        shutil.copy2(src, dst)
        copied += 1
        print("OK", dst.name, "<-", vis)
    print(f"copied {copied} shape aggregates to {ROOT}")


if __name__ == "__main__":
    main()
