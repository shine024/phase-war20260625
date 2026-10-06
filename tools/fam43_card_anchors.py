# -*- coding: utf-8 -*-
"""fam43 卡图直出锚定提取（复刻 v9 _v11_card_anchors.py 配方，脚本本体曾被清理）。

用途：标记复查页 fam 段 43 家族行 → 41 个唯一 anim_key 的攻击动画按 codeanim
卡图直出路线全量重生成（docs/codeanim_工作流_20261001.md 四批·卡图直出v9换装批同款）。

步骤0 配方（img25_staging/_relight2/_v11_card_anchors.py 遗产，见记忆 card-direct-anchor-pipeline）：
    卡图 512² RGBA 的 RGB 黑是 premultiplied 假象 →
    反预乘 rgb=RGB/max(α,0.004)，二值 α（>0.004 为本体）→ 1024 LANCZOS →
    合成到不透明品红场 (255,0,255) → fam43_anchor_from_card/<key>_anchor_raw.png
    （load_anchor 全套 detect_bg/scrub/depink 旋钮照用不改；--flip 键在提取期预翻，
     cfg 不再填 flip，所有坐标=终稿朝左坐标）

用法：
    python tools/fam43_card_anchors.py            # 提取全部 + 接触页 + 探针页 + 建议 JSON
    python tools/fam43_card_anchors.py --flip k1,k2   # 指定键提取期水平预翻（朝左契约）
"""
import argparse
import json
import os
import re
import sys

import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MARKED = os.path.join(ROOT, "tools", "card_anim_review_marked.html")
DUMP = os.path.join(ROOT, "_anim_review", "card_anim_dump.json")
OUT_DIR = os.path.join(ROOT, ".godot", "unit_review", "fam43_anchor_from_card")
PINK = (255, 0, 255)


def unique_keys():
    """标记页 fam 段 43 行 → 去重后的 anim_key 列表（保序）。"""
    html = open(MARKED, encoding="utf-8").read()
    data = json.loads(re.search(r"const DATA = (\{.*?\});\n", html, re.S).group(1))
    fam = [s for s in data["sections"] if s["key"] == "fam"][0]["rows"]
    keys, seen = [], set()
    for r in fam:
        k = r.get("anim_key") or r["id"]
        if k not in seen:
            seen.add(k)
            keys.append(k)
    return keys


def marked_icons():
    """anim_key → 标记页行内 icon_e（家族卡，用户标注所见即所提）。首个非空者胜。"""
    html = open(MARKED, encoding="utf-8").read()
    data = json.loads(re.search(r"const DATA = (\{.*?\});\n", html, re.S).group(1))
    fam = [s for s in data["sections"] if s["key"] == "fam"][0]["rows"]
    m = {}
    for r in fam:
        k = r.get("anim_key") or r["id"]
        if k in m:
            continue
        ic = r.get("icon_e") or ""
        if ic:
            m[k] = os.path.normpath(os.path.join(ROOT, "tools", ic))
    return m


def key_to_card(dump):
    """anim_key → 敌方原图卡路径（enemy 优先=未镜像原图；缺 fallen 回 player）。"""
    m = {}
    for sec in ("enemies", "players", "platforms", "captured"):
        for e in dump.get(sec, []):
            k = e.get("anim_key")
            if not k or k in m:
                continue
            icon = e.get("icon") or ""
            if not icon and e.get("icon_player"):
                icon, _mp = e["icon_player"], True
            else:
                _mp = False
            m[k] = icon.replace("res://", ROOT + os.sep).replace("/", os.sep) if icon else ""
    return m


def extract(card_path, size=1024):
    """v11 配方：反预乘 + 二值 α + LANCZOS 放大 + 品红场。返回 RGB ndarray。"""
    im = Image.open(card_path).convert("RGBA")
    a = np.asarray(im).astype(np.float32)
    al = a[..., 3:4] / 255.0
    rgb = a[..., :3] / np.maximum(al, 0.004)          # 反预乘
    bin_a = (al > 0.004).astype(np.float32) * 255.0    # 二值 α
    out = np.dstack([np.clip(rgb, 0, 255), bin_a]).astype(np.uint8)
    big = Image.fromarray(out, "RGBA").resize((size, size), Image.LANCZOS)
    field = Image.new("RGB", (size, size), PINK)
    field.paste(big, (0, 0), big)
    arr = np.asarray(field).copy()
    arr[:3] = PINK; arr[-3:] = PINK            # 卡片边缘残线清边（探针左缘 1-2px
    arr[:, :3] = PINK; arr[:, -3:] = PINK      # 非品红残桩会被 scrub 当本体，钉死假枪口）
    return arr


def purge_pink_pockets(arr):
    """内嵌品口袋净化（两分法，2026-10-05）：
    · dist<100 的口袋芯=卡图真透明孔洞（bazooka 车窗/m81 炮架间隙）——原样保留，
      codeanim_gen.load_anchor 的 scrub_radius(100)+硬清60 会下游透明化（游戏里镂空）；
    · dist∈[100,150) 的口袋像素=低α垃圾色渍（反预乘放大噪声，键控/scrub 均抓不到，
      colossus 胸口粉条实测）——EDT 最近邻本体色一次性回填。
    返回 (图, 回填像素数)。"""
    from scipy import ndimage
    d = np.sqrt(((arr.astype(int) - np.array(PINK)) ** 2).sum(axis=2))
    pinkish = d < 150
    if not pinkish.any():
        return arr, 0
    lab, _ = ndimage.label(pinkish)
    border = set(lab[0, :]) | set(lab[-1, :]) | set(lab[:, 0]) | set(lab[:, -1])
    border.discard(0)
    pocket = pinkish & ~np.isin(lab, list(border))
    stain = pocket & (d >= 100)
    total = int(stain.sum())
    if not total:
        return arr, 0
    _, (iy, ix) = ndimage.distance_transform_edt(pocket, return_indices=True)
    out = arr.copy()
    out[stain] = arr[iy[stain], ix[stain]]
    return out, total


def probe_page(keys, page_no, per_page=6):
    """探针页：每键 460px 图 + 网格(每 100@1024) + 最左不透明像素十字(自动枪口建议)。"""
    THUMB = 460
    cols, rows = 3, 2
    page = Image.new("RGB", (cols * THUMB, rows * (THUMB + 18)), (24, 24, 28))
    d0 = ImageDraw.Draw(page)
    for i, k in enumerate(keys):
        p = os.path.join(OUT_DIR, "%s_anchor_raw.png" % k)
        im = Image.open(p).convert("RGB")
        g = im.resize((THUMB, THUMB), Image.LANCZOS)
        d = ImageDraw.Draw(g)
        sc = THUMB / 1024.0
        for v in range(0, 1025, 100):
            d.line((v * sc, 0, v * sc, THUMB), fill=(0, 255, 120), width=1)
            d.line((0, v * sc, THUMB, v * sc), fill=(0, 255, 120), width=1)
            if v % 200 == 0:
                d.text((v * sc + 2, 2), str(v), fill=(0, 255, 120))
                d.text((2, v * sc + 2), str(v), fill=(0, 255, 120))
        a = np.asarray(Image.open(p).convert("RGB"))
        bg = np.array(PINK)
        dist = np.sqrt(((a.astype(int) - bg) ** 2).sum(axis=2))
        ys, xs = np.where(dist >= 100)  # 本体（>=100）；<100 是品红背景/粉晕
        if len(xs):
            x0 = xs.min()
            y0 = int(ys[xs == x0].mean())
            cx, cy = x0 * sc, y0 * sc
            d.line((cx - 9, cy, cx + 9, cy), fill=(255, 255, 0), width=2)
            d.line((cx, cy - 9, cx, cy + 9), fill=(255, 255, 0), width=2)
        page.paste(g, ((i % cols) * THUMB, (i // cols) * (THUMB + 18)))
        d0.text(((i % cols) * THUMB + 4, (i // cols) * (THUMB + 18) + THUMB + 2),
                "%s  L=(%d,%d)" % (k, x0, y0) if len(xs) else k, fill=(255, 220, 120))
    page.save(os.path.join(OUT_DIR, "_probe_fam43_p%d.png" % page_no))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--flip", default="", help="逗号分隔键名：提取期水平预翻")
    args = ap.parse_args()
    flips = set(x for x in args.flip.split(",") if x)

    os.makedirs(OUT_DIR, exist_ok=True)
    keys = unique_keys()
    dump = json.load(open(DUMP, encoding="utf-8"))
    cards = key_to_card(dump)
    cards.update(marked_icons())  # 标记页行内卡优先（boss/变种 dump 无 icon 的兜底）

    missing = [k for k in keys if not cards.get(k) or not os.path.exists(cards[k])]
    if missing:
        sys.exit("无卡图的键: %s" % missing)

    for k in keys:
        arr = extract(cards[k])
        if k in flips:
            arr = arr[:, ::-1, :]
        arr, npix = purge_pink_pockets(arr)
        Image.fromarray(arr).save(os.path.join(OUT_DIR, "%s_anchor_raw.png" % k))
        print("[anchor] %-26s <- %s%s%s" % (k, os.path.basename(cards[k]),
              " (预翻)" if k in flips else "",
              " [口袋净化 %dpx]" % npix if npix else ""))

    # 建议 JSON：自动枪口（最左不透明像素）+ bbox + 列质量朝向分
    sug = {}
    for k in keys:
        a = np.asarray(Image.open(os.path.join(OUT_DIR, "%s_anchor_raw.png" % k)).convert("RGB"))
        dist = np.sqrt(((a.astype(int) - np.array(PINK)) ** 2).sum(axis=2))
        ys, xs = np.where(dist >= 100)  # 本体
        colmass = np.bincount(xs, minlength=1024).astype(float)
        h1, h2 = colmass[:512].sum(), colmass[512:].sum()
        sug[k] = dict(muzzle=[int(xs.min()), int(ys[xs == xs.min()].mean())],
                      bbox=[int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())],
                      left_mass=round(h1 / max(h1 + h2, 1), 3))
    json.dump(sug, open(os.path.join(OUT_DIR, "_suggest.json"), "w", encoding="utf-8"),
              ensure_ascii=False, indent=1)

    for pi in range(0, len(keys), 6):
        probe_page(keys[pi:pi + 6], pi // 6)
    print("[done] %d 键 → %s（探针页 %d 张 + _suggest.json）"
          % (len(keys), OUT_DIR, (len(keys) + 5) // 6))


if __name__ == "__main__":
    main()
