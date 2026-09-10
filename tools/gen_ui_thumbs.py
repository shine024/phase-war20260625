# -*- coding: utf-8 -*-
"""
gen_ui_thumbs.py — UI 小图标缩略图批量生成（v9.x 性能批次 3a）

背景：底部相位仪栏/战场单位此前用全分辨率纹理（卡面 512²、仪器 1024²、符文 995²），
显示尺寸仅 18~120px，gl_compatibility 下未压缩 RGBA 上传 VRAM 浪费 30-40MB。
本工具生成三棵缩略图树，配合 ui_asset_loader 的 *_small/ battle_tex_for_path 入口使用：

  assets/card_icons/_thumb256/{enemy,player}/   卡面 512→256（战场单位）
  assets/ui/instruments/_thumb128/              仪器 1024→128（底部栏仪器图标）
  assets/runes/_thumb128/<rarity>/              符文 995→128（底部栏符文图标）

用法：
  python tools/gen_ui_thumbs.py --dry-run     # 只打印计划，不落盘
  python tools/gen_ui_thumbs.py               # 生成（源更新过的才重生成）
  python tools/gen_ui_thumbs.py --force       # 全部重新生成
  python tools/gen_ui_thumbs.py --only cards  # 只跑一棵树：cards / instruments / runes

注意（VFX 铁律②）：生成后用 --verify 抽查实寸，别按假设。
"""
import os
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))

TARGETS = {
    "cards": {
        "src": os.path.join(ROOT, "assets", "card_icons"),
        "subdirs": ["enemy", "player"],
        "thumb_dir": "_thumb256",
        "size": 256,
    },
    "instruments": {
        "src": os.path.join(ROOT, "assets", "ui", "instruments"),
        "subdirs": [""],
        "thumb_dir": "_thumb128",
        "size": 128,
    },
    "runes": {
        "src": os.path.join(ROOT, "assets", "runes"),
        "subdirs": ["common", "rare", "epic", "legendary"],
        "thumb_dir": "_thumb128",
        "size": 128,
    },
}


def make_thumb(src_png: str, dst_png: str, size: int, force: bool, dry: bool):
    """LANCZOS 等比缩到 max边=size，保持透明底。源已小于目标则跳过。"""
    from PIL import Image

    if os.path.exists(dst_png) and not force:
        if os.path.getmtime(dst_png) >= os.path.getmtime(src_png):
            return "skip"
    if dry:
        return "would"
    img = Image.open(src_png).convert("RGBA")
    w, h = img.size
    if max(w, h) <= size:
        return "small"  # 源不大于目标，无需缩略（调用方回退源图即可）
    img.thumbnail((size, size), Image.LANCZOS)
    os.makedirs(os.path.dirname(dst_png), exist_ok=True)
    img.save(dst_png)
    return "ok"


def verify(thumb_root_rel: str, size: int):
    """抽查已生成缩略图的实寸（VFX 铁律②：量实寸，不假设）。"""
    from PIL import Image

    thumb_root = os.path.join(ROOT, thumb_root_rel)
    bad = 0
    checked = 0
    for dirpath, _dirnames, filenames in os.walk(thumb_root):
        for fn in filenames:
            if not fn.lower().endswith(".png"):
                continue
            p = os.path.join(dirpath, fn)
            with Image.open(p) as im:
                w, h = im.size
            checked += 1
            if max(w, h) > size:
                print(f"  [verify] BAD {p}: {w}x{h} > {size}")
                bad += 1
    print(f"  [verify] {thumb_root_rel}: checked={checked} bad={bad}")
    return bad


def main():
    args = set(sys.argv[1:])
    dry = "--dry-run" in args
    force = "--force" in args
    only = None
    for a in args:
        if a.startswith("--only="):
            only = a.split("=", 1)[1]
    do_verify = "--verify" in args

    try:
        from PIL import Image  # noqa: F401
    except ImportError:
        print("需要 Pillow：pip install pillow")
        sys.exit(1)

    total = {"ok": 0, "skip": 0, "would": 0, "small": 0}
    for name, cfg in TARGETS.items():
        if only and name != only:
            continue
        src_root = cfg["src"]
        thumb_rel = os.path.relpath(
            os.path.join(src_root, cfg["thumb_dir"]), ROOT
        ).replace("\\", "/")
        print(f"[{name}] {os.path.relpath(src_root, ROOT)} -> {thumb_rel} (max {cfg['size']}px)")
        n = 0
        for sub in cfg["subdirs"]:
            src_dir = os.path.join(src_root, sub) if sub else src_root
            if not os.path.isdir(src_dir):
                print(f"  [warn] 源目录不存在: {src_dir}")
                continue
            for fn in sorted(os.listdir(src_dir)):
                if not fn.lower().endswith(".png"):
                    continue
                src_png = os.path.join(src_dir, fn)
                out_dir = os.path.join(src_root, cfg["thumb_dir"], sub)
                dst_png = os.path.join(out_dir, fn)
                r = make_thumb(src_png, dst_png, cfg["size"], force, dry)
                total[r] = total.get(r, 0) + 1
                n += 1
                if r == "would":
                    print(f"  would: {os.path.relpath(dst_png, ROOT)}")
        print(f"  scanned={n}")
        if do_verify and not dry:
            if verify(os.path.join(os.path.relpath(src_root, ROOT), cfg["thumb_dir"]), cfg["size"]):
                sys.exit(2)

    print(f"[summary] {total} dry={dry}")
    if dry:
        print("[dry-run] 未写任何文件")


if __name__ == "__main__":
    main()
