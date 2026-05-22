#!/usr/bin/env python3
"""Remove archive candidate PNGs that duplicate formal backgrounds/frames."""

from __future__ import annotations

import csv
import hashlib
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
ARCHIVE = REPO / "assets" / "cards" / "_archive_candidates"
INDEX = ARCHIVE / "_index.csv"
LOG = ARCHIVE / "_removed_duplicates_of_formal.csv"
README = ARCHIVE / "README.md"


def md5(path: Path) -> str:
    return hashlib.md5(path.read_bytes()).hexdigest()


def formal_assets() -> dict[str, tuple[str, Path]]:
    out: dict[str, tuple[str, Path]] = {}
    for kind, folder in (
        ("backgrounds", REPO / "assets" / "cards" / "backgrounds"),
        ("frames", REPO / "assets" / "cards" / "frames"),
    ):
        for png in folder.glob("*.png"):
            out[md5(png)] = (kind, png)
    return out


def main() -> None:
    formal = formal_assets()
    removed: list[dict[str, str]] = []
    removed_dests: set[str] = set()

    for png in sorted(ARCHIVE.glob("*.png")):
        hit = formal.get(md5(png))
        if hit is None:
            continue
        kind, formal_path = hit
        rel_dest = str(png.relative_to(REPO)).replace("\\", "/")
        removed_dests.add(rel_dest)
        removed_dests.add(rel_dest + ".import")
        imp = Path(str(png) + ".import")
        if imp.exists():
            imp.unlink()
        png.unlink()
        removed.append(
            {
                "archive_name": png.name,
                "formal_path": str(formal_path.relative_to(REPO)).replace("\\", "/"),
                "kind": kind,
            }
        )

    rows = list(csv.DictReader(INDEX.open(encoding="utf-8-sig")))
    kept = [row for row in rows if row["dest"] not in removed_dests]
    with INDEX.open("w", encoding="utf-8-sig", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=["source", "dest", "id", "display_name"])
        writer.writeheader()
        writer.writerows(kept)

    with LOG.open("w", encoding="utf-8-sig", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=["archive_name", "formal_path", "kind"])
        writer.writeheader()
        writer.writerows(sorted(removed, key=lambda r: r["archive_name"]))

    README.write_text(
        """# 候选卡面美术归档

非正式入库的势力底图 / 卡框候选，已从 `backgrounds_choice/`、`frames_choice/`、`frames_v2/` 及 `frames/Game_card_frame_border_*` 移入此目录。

- 文件名：`原ID_中文名.png`
- 对照表：`_index.csv`
- 与正式资源重复、已从归档删除的记录：`_removed_duplicates_of_formal.csv`（共 13 张，正式版保留在 `backgrounds/` 与 `frames/`）
- 正式资源仍在：
  - `assets/cards/backgrounds/`（8 张势力底，来自 v3 纹章套）
  - `assets/cards/frames/`（5 张稀有度框，来自 C 华丽套）

重新生成候选图时，对应脚本会重建 `backgrounds_choice/` 等目录；满意后再 Copy-Item 到正式目录。
""",
        encoding="utf-8",
    )

    print(f"removed {len(removed)} duplicate PNGs")
    print(f"index rows: {len(rows)} -> {len(kept)}")
    print(f"remaining archive PNGs: {len(list(ARCHIVE.glob('*.png')))}")


if __name__ == "__main__":
    main()
