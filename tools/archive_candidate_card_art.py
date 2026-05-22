#!/usr/bin/env python3
"""Archive unofficial card art candidates (backgrounds/frames choice + v2 + stray exports)."""

from __future__ import annotations

import csv
import re
import shutil
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
CARDS = REPO / "assets" / "cards"
ARCHIVE = CARDS / "_archive_candidates"

CANDIDATE_DIRS = [
    CARDS / "backgrounds_choice",
    CARDS / "frames_choice",
    CARDS / "frames_v2",
]

FACTION_BG_ZH = {
    "bg_neutral": "无势力底图",
    "bg_iron_wall_corp": "钢壁防务",
    "bg_nova_arms": "新星兵工",
    "bg_aether_dynamics": "以太动力",
    "bg_quantum_logistics": "量子后勤",
    "bg_helix_recon": "螺旋侦察",
    "bg_void_research": "虚空相位",
    "bg_frontier_union": "边境联合",
}

RARITY_ZH = {
    "common": "普通",
    "uncommon": "优秀",
    "rare": "稀有",
    "epic": "史诗",
    "legendary": "传说",
}

SET_ZH = {
    "set_a_neon": "A霓虹粗框",
    "set_b_heavy": "B重装镶边",
    "set_c_luxe": "C华丽典藏",
    "set_distinct_v2": "势力底v2高区分",
    "set_heraldic_v3": "势力底v3纹章",
    "agent_heraldic": "Agent纹章底图",
    "frames_v2": "卡框v2程序化",
}

SPECIAL_ZH = {
    "_preview_factions_v2": "势力底图预览v2",
    "_mockup_factions_v2": "势力底mockup_v2",
    "_compare_factions_old_vs_v2": "势力底对照_旧版vs_v2",
    "_compare_factions_v2_vs_v3": "势力底对照_v2vs_v3",
    "_preview_factions_v3_heraldic": "势力底预览v3纹章",
    "_mockup_factions_v3_heraldic": "势力底mockup_v3纹章",
    "_preview_factions_agent_heraldic": "势力底预览_Agent纹章",
    "_mockup_factions_agent_heraldic": "势力底mockup_Agent纹章",
    "_preview_set_a_neon": "卡框预览_A霓虹",
    "_preview_set_b_heavy": "卡框预览_B重装",
    "_preview_set_c_luxe": "卡框预览_C华丽",
    "_mockup_set_a_neon": "卡框mockup_A霓虹",
    "_mockup_set_b_heavy": "卡框mockup_B重装",
    "_mockup_set_c_luxe": "卡框mockup_C华丽",
    "_compare_a_vs_b": "卡框对照_AvsB",
    "_compare_b_vs_c": "卡框对照_BvsC",
    "_preview_all_rarities": "卡框v2五稀有度预览",
    "_mockup_stacked": "卡框v2叠单位mockup",
    "_mtg_layout_175x245_preview": "卡框v2_MTG布局预览",
}

FRAME_V2_ZH = {
    "frame_common": "普通",
    "frame_uncommon": "优秀",
    "frame_rare": "稀有",
    "frame_epic": "史诗",
    "frame_legendary": "传说",
}

STRAY_FRAME_GLOBS = [
    "Game_card_frame_border__*.png",
]

INVALID_FN_CHARS = re.compile(r'[<>:"/\\|?*\x00-\x1f]')


def sanitize(text: str) -> str:
    cleaned = INVALID_FN_CHARS.sub("", text.strip())
    return cleaned.replace("\u00a0", " ")


def lookup_zh(stem: str, rel_parts: tuple[str, ...]) -> str:
    if stem in SPECIAL_ZH:
        return SPECIAL_ZH[stem]
    if stem in FACTION_BG_ZH:
        set_hint = SET_ZH.get(rel_parts[0], rel_parts[0]) if rel_parts else ""
        return f"{FACTION_BG_ZH[stem]}·{set_hint}" if set_hint else FACTION_BG_ZH[stem]
    if stem in RARITY_ZH:
        set_hint = SET_ZH.get(rel_parts[0], rel_parts[0]) if rel_parts else ""
        return f"{RARITY_ZH[stem]}·{set_hint}" if set_hint else RARITY_ZH[stem]
    if stem in FRAME_V2_ZH:
        return f"{FRAME_V2_ZH[stem]}·卡框v2"
    if stem.startswith("Game_card_frame_border__"):
        m = re.search(r"__(common|uncomm|epic_r|rare_r)", stem)
        if m:
            key = m.group(1)
            if key == "uncomm":
                key = "uncommon"
            if key.endswith("_r"):
                key = key[:-2]
            return f"{RARITY_ZH.get(key, key)}·AI导出候选"
        return "AI导出卡框候选"
    if rel_parts:
        return SET_ZH.get(rel_parts[0], rel_parts[0])
    return ""


def build_original_id(rel: Path) -> str:
    parts = rel.parts
    if parts[0] in {"backgrounds_choice", "frames_choice", "frames_v2"}:
        tail = parts[1:]
    else:
        tail = parts
    stem = rel.stem
    if not tail:
        return stem
    prefix = "_".join(p for p in tail[:-1] if not p.startswith("_"))
    if prefix:
        return f"{prefix}_{stem}"
    return stem


def archive_name(original_id: str, zh: str) -> str:
    if zh:
        return sanitize(f"{original_id}_{zh}")
    return sanitize(original_id)


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


def iter_files(root: Path) -> list[Path]:
    if not root.is_dir():
        return []
    return sorted(p for p in root.rglob("*") if p.is_file())


def main() -> None:
    import argparse

    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    ARCHIVE.mkdir(parents=True, exist_ok=True)
    rows: list[dict[str, str]] = []

    sources: list[tuple[Path, Path]] = []
    for d in CANDIDATE_DIRS:
        for f in iter_files(d):
            sources.append((f, f.relative_to(d)))

    frames_dir = CARDS / "frames"
    for pattern in STRAY_FRAME_GLOBS:
        for f in sorted(frames_dir.glob(pattern)):
            sources.append((f, Path("frames") / f.name))

    for src, rel in sources:
        rel_parts = rel.parts
        stem = src.stem
        original_id = build_original_id(rel)
        zh = lookup_zh(stem, rel_parts[1:-1] if len(rel_parts) > 2 else rel_parts[:-1])
        target_stem = archive_name(original_id, zh)

        for src_file in (src, Path(str(src) + ".import")):
            if not src_file.exists():
                continue
            ext = ".png.import" if src_file.name.endswith(".png.import") else src_file.suffix
            dest = unique_path(ARCHIVE, target_stem, ext)
            rows.append(
                {
                    "source": str(src_file.relative_to(REPO)).replace("\\", "/"),
                    "dest": str(dest.relative_to(REPO)).replace("\\", "/"),
                    "id": original_id,
                    "display_name": zh,
                }
            )
            if not args.dry_run:
                dest.parent.mkdir(parents=True, exist_ok=True)
                shutil.move(str(src_file), str(dest))

    if not args.dry_run:
        for d in CANDIDATE_DIRS:
            if d.exists():
                shutil.rmtree(d, ignore_errors=True)

        index_path = ARCHIVE / "_index.csv"
        with index_path.open("w", encoding="utf-8-sig", newline="") as f:
            writer = csv.DictWriter(f, fieldnames=["source", "dest", "id", "display_name"])
            writer.writeheader()
            writer.writerows(rows)

        readme = ARCHIVE / "README.md"
        readme.write_text(
            """# 候选卡面美术归档

非正式入库的势力底图 / 卡框候选，已从 `backgrounds_choice/`、`frames_choice/`、`frames_v2/` 及 `frames/Game_card_frame_border_*` 移入此目录。

- 文件名：`原ID_中文名.png`
- 对照表：`_index.csv`
- 正式资源仍在：
  - `assets/cards/backgrounds/`（8 张势力底）
  - `assets/cards/frames/`（5 张稀有度框）

重新生成候选图时，对应脚本会重建 `backgrounds_choice/` 等目录；满意后再 Copy-Item 到正式目录。
""",
            encoding="utf-8",
        )

    mode = "DRY RUN" if args.dry_run else "DONE"
    print(f"[{mode}] archived {len(rows)} files -> {ARCHIVE.relative_to(REPO)}")


if __name__ == "__main__":
    main()
