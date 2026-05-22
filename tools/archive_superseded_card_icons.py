#!/usr/bin/env python3
"""Move superseded unit card icons into a single archive folder (id + Chinese name)."""

from __future__ import annotations

import csv
import re
import shutil
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
CARD_ICONS = REPO / "assets" / "card_icons"
ARCHIVE = CARD_ICONS / "_archive_superseded"
MANIFEST_MD = REPO / "docs" / "card_icon_manifest_100_zh.md"
DEFAULT_CARDS = REPO / "data" / "default_cards.gd"
PHASE_LAWS = REPO / "data" / "phase_laws.gd"

KEEP_DIRS = {"units"}

PLATFORM_SHAPE_KEYS = {
    "hound",
    "guard",
    "titan",
    "fortress",
    "radar",
    "scout",
    "raider",
    "siege",
    "carrier",
    "medic",
    "stealth",
    "omega_platform",
}

ENERGY_CARD_IDS = {
    "energy",
    "energy_hybrid",
    "energy_instant_l",
    "energy_instant_m",
    "energy_instant_s",
    "energy_regen_1",
    "energy_regen_2",
    "energy_regen_3",
    "energy_start_1",
    "energy_start_2",
    "energy_start_3",
    "energy_start_4",
    "energy_start_5",
    "energy_start_6",
    "energy_start_7",
}

ARCHIVE_SUBDIRS = {
    "_agent_source",
    "_backup_scale_20260513_144708",
    "_generated_preview",
}

INVALID_FN_CHARS = re.compile(r'[<>:"/\\|?*\x00-\x1f]')


def sanitize_filename_part(text: str) -> str:
    cleaned = INVALID_FN_CHARS.sub("", text.strip())
    cleaned = cleaned.replace("\u00a0", " ")
    return cleaned


def parse_manifest_names() -> dict[str, str]:
    text = MANIFEST_MD.read_text(encoding="utf-8")
    names: dict[str, str] = {}
    row_re = re.compile(
        r"^\|\s*\d+\s*\|\s*(vis_[^\|]+)\|\s*([^|]+?)\s*\|\s*\d+\s*\|[^|]*\|\s*([^|]+?)\s*\|\s*(captured_[^|]+?)\s*\|",
        re.MULTILINE,
    )
    for visual_id, display_name, archetype_id, captured_id in row_re.findall(text):
        vid = visual_id.strip()
        dn = display_name.strip()
        aid = archetype_id.strip()
        cap = captured_id.strip()
        names[vid] = dn
        names[aid] = dn
        names[cap] = dn
    return names


def parse_default_card_names() -> dict[str, str]:
    text = DEFAULT_CARDS.read_text(encoding="utf-8")
    names: dict[str, str] = {}
    for card_id, display_name in re.findall(
        r'_platform\("([^"]+)",\s*"([^"]+)"', text
    ):
        names[card_id] = display_name
    for card_id, display_name in re.findall(
        r'_energy_start\("([^"]+)",\s*"([^"]+)"', text
    ):
        names[card_id] = display_name
    for card_id, display_name in re.findall(
        r'_special\("([^"]+)",\s*"([^"]+)"', text
    ):
        names[card_id] = display_name
    return names


def parse_law_names() -> dict[str, str]:
    text = PHASE_LAWS.read_text(encoding="utf-8")
    names: dict[str, str] = {}
    for law_id, display_name in re.findall(
        r'"([a-z_]+)":\s*\{\s*\n\s*"id":\s*"[^"]+",\s*\n\s*"name":\s*"([^"]+)"',
        text,
    ):
        names[law_id] = display_name
    names["law"] = "法则卡"
    return names


def build_keep_root_stems() -> set[str]:
    keep = {"_enemy_placeholder", "law", *PLATFORM_SHAPE_KEYS, *ENERGY_CARD_IDS}
    keep.update(parse_law_names().keys())
    return keep


def lookup_chinese_name(stem: str, names: dict[str, str]) -> str:
    if stem in names:
        return names[stem]
    if stem.startswith("captured_"):
        base = stem[9:]
        if base in names:
            return names[base]
    m = re.match(r"(vis_(?:player|enemy|pool)_\d+)", stem)
    if m and m.group(1) in names:
        return names[m.group(1)]
    return ""


def archive_target_name(stem: str, names: dict[str, str], source_hint: str = "") -> str:
    zh = lookup_chinese_name(stem, names)
    if zh:
        base = f"{stem}_{sanitize_filename_part(zh)}"
    else:
        base = stem
    if source_hint:
        base = f"{base}__from_{source_hint}"
    return sanitize_filename_part(base)


def unique_path(dest_dir: Path, stem: str, ext: str) -> Path:
    candidate = dest_dir / f"{stem}{ext}"
    if not candidate.exists():
        return candidate
    i = 2
    while True:
        candidate = dest_dir / f"{stem}_{i}{ext}"
        if not candidate.exists():
            return candidate
        i += 1


def move_asset(src: Path, dest: Path, dry_run: bool) -> None:
    if dry_run:
        return
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.move(str(src), str(dest))


def main() -> None:
    import argparse

    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    names = parse_manifest_names()
    names.update(parse_default_card_names())
    names.update(parse_law_names())

    keep_root = build_keep_root_stems()
    ARCHIVE.mkdir(parents=True, exist_ok=True)

    rows: list[dict[str, str]] = []
    moved = 0

    def archive_file(src: Path, stem: str, source_hint: str = "") -> None:
        nonlocal moved
        target_stem = archive_target_name(stem, names, source_hint)
        for ext in (".png", ".png.import"):
            src_file = src if src.suffix == ext else src.with_suffix(ext)
            if not src_file.exists():
                if ext == ".png":
                    src_file = src
                else:
                    continue
            if ext == ".png" and not src_file.name.endswith(".png"):
                continue
            if ext == ".png.import":
                src_file = Path(str(src) + ".import")
                if not src_file.exists():
                    continue
            dest = unique_path(ARCHIVE, target_stem, ext if ext != ".png.import" else ".png.import")
            rows.append(
                {
                    "source": str(src_file.relative_to(REPO)).replace("\\", "/"),
                    "dest": str(dest.relative_to(REPO)).replace("\\", "/"),
                    "id": stem,
                    "display_name": lookup_chinese_name(stem, names),
                }
            )
            if not args.dry_run:
                move_asset(src_file, dest, dry_run=False)
            moved += 1

    # Root-level obsolete PNGs
    for png in sorted(CARD_ICONS.glob("*.png")):
        stem = png.stem
        if stem in keep_root:
            continue
        archive_file(png, stem)

    # Whole obsolete subfolders
    for sub in sorted(ARCHIVE_SUBDIRS):
        sub_dir = CARD_ICONS / sub
        if not sub_dir.is_dir():
            continue
        for png in sorted(sub_dir.rglob("*.png")):
            stem = png.stem
            # agent_source files often look like vis_enemy_036_mp18
            vis = re.match(r"(vis_(?:player|enemy|pool)_\d+)", stem)
            lookup_stem = vis.group(1) if vis else stem
            archive_file(png, lookup_stem, source_hint=sub)

        if not args.dry_run:
            # remove empty dirs / leftover non-png junk
            if sub_dir.exists():
                shutil.rmtree(sub_dir, ignore_errors=True)

    index_path = ARCHIVE / "_index.csv"
    if not args.dry_run:
        with index_path.open("w", encoding="utf-8-sig", newline="") as f:
            writer = csv.DictWriter(f, fieldnames=["source", "dest", "id", "display_name"])
            writer.writeheader()
            writer.writerows(rows)

    mode = "DRY RUN" if args.dry_run else "DONE"
    print(f"[{mode}] archived {len(rows)} files -> {ARCHIVE.relative_to(REPO)}")
    print(f"kept active: units/ (100), root UI cards ({len(keep_root)} stems)")
    if not args.dry_run:
        print(f"index: {index_path.relative_to(REPO)}")


if __name__ == "__main__":
    main()
