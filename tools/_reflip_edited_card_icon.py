#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""手改敌方卡图后的回翻工具（管线"步骤 5"的脚本化，v30.6）。

场景：直接用外部工具改了 `assets/card_icons/enemy/<card_id>.png`（512 透明底成品），
需要同步：我方水平翻转版 + _thumb256/_thumb384 双侧缩略图。

用法：
    python tools/_reflip_edited_card_icon.py <card_id> [<card_id> ...]
    例：python tools/_reflip_edited_card_icon.py ww2_air_me262

注意：
- 只处理"改成品"路径；若你改的是白底 1024 源图（docs/待生成卡图_*/<id>.png），
  请改跑对应部署脚本（如 _deploy_r5_jets.py），它会做白底转透明+512 正方化。
- 修改若改变了主体轮廓（裁切/缩放/移动），跑完本脚本后必须再跑
  tools/generate_card_foot_anchors.py 重建脚部锚点。
"""
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ENEMY_DIR = os.path.join(ROOT, "assets", "card_icons", "enemy")
PLAYER_DIR = os.path.join(ROOT, "assets", "card_icons", "player")
THUMB256 = os.path.join(ROOT, "assets", "card_icons", "_thumb256")
THUMB384 = os.path.join(ROOT, "assets", "card_icons", "_thumb384")
OUT_SIZE = 512


def make_thumb(src_png: str, dst_png: str, size: int) -> str:
    img = Image.open(src_png).convert("RGBA")
    if max(img.size) <= size:
        return "small"
    img.thumbnail((size, size), Image.Resampling.LANCZOS)
    os.makedirs(os.path.dirname(dst_png), exist_ok=True)
    img.save(dst_png)
    return "ok"


def process(card_id: str) -> bool:
    src = os.path.join(ENEMY_DIR, f"{card_id}.png")
    if not os.path.exists(src):
        print(f"SKIP {card_id}: enemy 原图不存在（{src}）")
        return False
    img = Image.open(src).convert("RGBA")
    warn = ""
    if img.size != (OUT_SIZE, OUT_SIZE):
        warn = f" ⚠️ 非 {OUT_SIZE}x{OUT_SIZE}（实际 {img.size}）——卡框/战场体系假定正方形，建议回改"
    # 我方 = 水平翻转
    flipped = img.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    flipped.save(os.path.join(PLAYER_DIR, f"{card_id}.png"), "PNG")
    # 缩略图（双侧）
    t = [
        make_thumb(src, os.path.join(THUMB256, "enemy", f"{card_id}.png"), 256),
        make_thumb(src, os.path.join(THUMB384, "enemy", f"{card_id}.png"), 384),
        make_thumb(os.path.join(PLAYER_DIR, f"{card_id}.png"),
                   os.path.join(THUMB256, "player", f"{card_id}.png"), 256),
        make_thumb(os.path.join(PLAYER_DIR, f"{card_id}.png"),
                   os.path.join(THUMB384, "player", f"{card_id}.png"), 384),
    ]
    print(f"OK {card_id}: player 已回翻 + thumbs={t}{warn}")
    return True


def main() -> None:
    ids = [a for a in sys.argv[1:] if a and not a.startswith("-")]
    if not ids:
        print(__doc__)
        raise SystemExit(2)
    ok = sum(1 for cid in ids if process(cid))
    print(f"\nDone: {ok} OK, {len(ids) - ok} SKIP/FAIL")
    if ok < len(ids):
        raise SystemExit(1)


if __name__ == "__main__":
    main()
