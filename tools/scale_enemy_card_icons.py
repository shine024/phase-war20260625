#!/usr/bin/env python3
"""
按宽度基准缩放敌人卡面 PNG，便于先跑通游戏内效果（enemy_unit 要求单边 ≤768）。

规则（默认）：
  1) 先按 target_width 等比缩放，使宽度 = target_width；
  2) 若高度仍 > max_dim，再整体等比缩小，使高度 = max_dim（宽度会略小于 target_width）。

仅处理 assets/card_icons/enemy_*.png（不改 work_ 子目录）。

用法：
  pip install pillow
  python tools/scale_enemy_card_icons.py --dry-run
  python tools/scale_enemy_card_icons.py
  python tools/scale_enemy_card_icons.py --target-width 768 --max-dim 768
"""

from __future__ import annotations

import argparse
import shutil
import sys
from datetime import datetime
from pathlib import Path


def _require_pil():
    try:
        from PIL import Image  # noqa: PLC0415

        return Image
    except ImportError:
        print("需要 Pillow：pip install pillow", file=sys.stderr)
        sys.exit(1)


def compute_size(w: int, h: int, target_w: int, max_dim: int) -> tuple[int, int]:
    if w <= 0 or h <= 0:
        return w, h
    nw = target_w
    nh = max(1, int(round(h * (target_w / float(w)))))
    if nh > max_dim:
        s = max_dim / float(nh)
        nw = max(1, int(round(nw * s)))
        nh = max_dim
    return nw, nh


def should_process(w: int, h: int, target_w: int, max_dim: int) -> bool:
    nw, nh = compute_size(w, h, target_w, max_dim)
    return (w, h) != (nw, nh)


def main() -> None:
    ap = argparse.ArgumentParser(description="按宽度基准缩放 assets/card_icons/enemy_*.png")
    ap.add_argument(
        "--card-icons",
        type=Path,
        default=Path(__file__).resolve().parents[1] / "assets" / "card_icons",
        help="card_icons 根目录",
    )
    ap.add_argument("--target-width", type=int, default=768, help="目标宽度（像素）")
    ap.add_argument("--max-dim", type=int, default=768, help="单边最大像素（与游戏一致）")
    ap.add_argument("--dry-run", action="store_true", help="只列出将修改的文件")
    ap.add_argument(
        "--no-backup",
        action="store_true",
        help="不写备份目录（默认会备份到 card_icons/_backup_scale_<时间戳>/）",
    )
    args = ap.parse_args()
    root: Path = args.card_icons
    if not root.is_dir():
        print(f"目录不存在: {root}", file=sys.stderr)
        sys.exit(1)

    Image = _require_pil()
    files = sorted(root.glob("enemy_*.png"))
    if not files:
        print(f"未找到 enemy_*.png: {root}")
        return

    to_change: list[tuple[Path, int, int, int, int]] = []
    for p in files:
        with Image.open(p) as im:
            w, h = im.size
        nw, nh = compute_size(w, h, args.target_width, args.max_dim)
        if (w, h) != (nw, nh):
            to_change.append((p, w, h, nw, nh))

    print(f"扫描 {len(files)} 个文件，需调整 {len(to_change)} 个（target_w={args.target_width}, max_dim={args.max_dim}）")
    for p, w, h, nw, nh in to_change:
        print(f"  {p.name}: {w}x{h} -> {nw}x{nh}")

    if args.dry_run or not to_change:
        return

    backup_root: Path | None = None
    if not args.no_backup:
        stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        backup_root = root / f"_backup_scale_{stamp}"
        backup_root.mkdir(parents=True, exist_ok=False)
        print(f"备份到: {backup_root}")

    for p, w, h, nw, nh in to_change:
        if backup_root is not None:
            rel = p.relative_to(root)
            dest = backup_root / rel
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(p, dest)
        with Image.open(p) as im:
            rgba = im.convert("RGBA")
            out = rgba.resize((nw, nh), Image.Resampling.LANCZOS)
        out.save(p, format="PNG", optimize=True)
        print(f"已写入: {p.name}")

    print("完成。Godot 若已打开，可在文件系统 Dock 里刷新或重开工程以更新贴图。")


if __name__ == "__main__":
    main()
