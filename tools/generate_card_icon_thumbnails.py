#!/usr/bin/env python3
"""
为卡牌图标生成低分辨率缩略图，供背包/图鉴等"列表场景"消费，降低 VRAM 占用。

背景：
  原图 1024x1024 RGBA（未压缩 ~4MB）/ 512x512（~1MB），背包一次性渲染 135+ 张
  → 内存耗尽崩溃。缩到 256x256（~256KB）后，同屏 135 张仅 ~34MB。

规则：
  - 遍历 assets/card_icons/player/*.png 与 assets/card_icons/enemy/*.png
  - 等比缩放后居中填充到 size×size 正方形画布（保留长宽比，透明填边）
  - 输出到 assets/card_icons/_thumb256/{player,enemy}/<同名>.png
  - 不修改原图；不处理 work_ 子目录

用法：
  pip install pillow
  python tools/generate_card_icon_thumbnails.py --dry-run
  python tools/generate_card_icon_thumbnails.py
  python tools/generate_card_icon_thumbnails.py --size 256 --force
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_ICONS = ROOT / "assets" / "card_icons"
SUBDIRS = ("player", "enemy")


def _require_pil():
    try:
        from PIL import Image  # noqa: PLC0415
        return Image
    except ImportError:
        print("需要 Pillow：pip install pillow", file=sys.stderr)
        sys.exit(1)


def fit_square(w: int, h: int, size: int) -> tuple[int, int]:
    """等比缩放使长边 = size，短边按比例（不强制正方形，保持原长宽比）。"""
    if w <= 0 or h <= 0:
        return size, size
    s = size / float(max(w, h))
    return max(1, int(round(w * s))), max(1, int(round(h * s)))


def main() -> None:
    ap = argparse.ArgumentParser(description="生成 assets/card_icons 缩略图到 _thumb256/")
    ap.add_argument("--card-icons", type=Path, default=DEFAULT_ICONS, help="card_icons 根目录")
    ap.add_argument("--size", type=int, default=256, help="目标长边像素（默认 256）")
    ap.add_argument("--dry-run", action="store_true", help="只列出将生成的文件")
    ap.add_argument("--force", action="store_true", help="已存在也覆盖")
    ap.add_argument("--subdirs", nargs="*", default=list(SUBDIRS), help="处理的子目录（默认 player enemy）")
    args = ap.parse_args()

    icons_root: Path = args.card_icons
    if not icons_root.is_dir():
        print(f"目录不存在: {icons_root}", file=sys.stderr)
        sys.exit(1)

    Image = _require_pil()
    thumb_root = icons_root / f"_thumb{args.size}"

    plan: list[tuple[Path, Path, int, int, int, int]] = []
    for sub in args.subdirs:
        src_dir = icons_root / sub
        if not src_dir.is_dir():
            print(f"跳过（不存在）: {src_dir}")
            continue
        out_dir = thumb_root / sub
        for p in sorted(src_dir.glob("*.png")):
            with Image.open(p) as im:
                w, h = im.size
            nw, nh = fit_square(w, h, args.size)
            dest = out_dir / p.name
            plan.append((p, dest, w, h, nw, nh))

    # 过滤已存在（除非 --force）
    todo = []
    skipped = 0
    for src, dest, w, h, nw, nh in plan:
        if dest.exists() and not args.force:
            skipped += 1
            continue
        todo.append((src, dest, w, h, nw, nh))

    print(f"扫描 {len(plan)} 个源图；待生成 {len(todo)} 个；跳过已存在 {skipped} 个（size={args.size}）")
    for src, dest, w, h, nw, nh in todo:
        rel = src.relative_to(icons_root)
        print(f"  {rel}: {w}x{h} -> {nw}x{nh}")

    if args.dry_run or not todo:
        return

    # 写入
    for src, dest, w, h, nw, nh in todo:
        dest.parent.mkdir(parents=True, exist_ok=True)
        with Image.open(src) as im:
            rgba = im.convert("RGBA")
            out = rgba.resize((nw, nh), Image.Resampling.LANCZOS)
            out.save(dest, format="PNG", optimize=True)
    print(f"完成。写入 {len(todo)} 张到 {thumb_root}")
    print("提示：在 Godot 编辑器里打开项目让其自动生成 .import + .ctex（首次需刷新文件系统）。")


if __name__ == "__main__":
    main()
