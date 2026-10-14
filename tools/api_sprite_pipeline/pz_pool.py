# -*- coding: utf-8 -*-
"""ww2_inf_panzerschrek 格池择优（用户拍板方案三）。
网格法回归 + 高分辨率底稿(1024² 2×2, 卡图原尺寸贴格) + 多卷抛掷(N 卷×4 格=格池) +
逐格评分择优 + 跨卷拼最终卷 + 色迁移对齐书挡 + 渣清 + 净高归一。
评分: 净高接近书挡基准 / 宽高比接近卡图 / 品红残渣少 / f3 位必须带焰且焰贴左上(炮口侧)。
用法: python tools/api_sprite_pipeline/pz_pool.py [N卷, 默认5]
"""
import base64, json, os, subprocess, sys, time
from collections import deque
import numpy as np
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__))
WS = os.path.abspath(os.path.join(HERE, "..", ".."))
_POOL_ARGS = sys.argv[1:]              # 先取本脚本的参
sys.argv = [sys.argv[0]]              # 复位: generate_attack_api 读 argv[1] 当单位名
sys.path.insert(0, HERE)
import generate_attack_api as P
import batch_regen as B   # 复用 UNITS/CFG/poses_for_uid/i2i/make_transparent
sys.argv = [sys.argv[0]] + _POOL_ARGS  # 恢复

FS = 256
UID = "ww2_inf_panzerschrek"
OUT = os.path.join(WS, ".godot", "unit_review", "api_" + UID)
RAW = os.path.join(OUT, "raw_pool"); os.makedirs(RAW, exist_ok=True)
FOOT = 8
NROLL = int(_POOL_ARGS[0]) if _POOL_ARGS else 5
POOL_DIR = os.path.join(OUT, "pool"); os.makedirs(POOL_DIR, exist_ok=True)


def book_card():
    card = Image.open(os.path.join(WS, "assets/card_icons/player/vis_player_010.png")).convert("RGBA")
    card = card.transpose(Image.FLIP_LEFT_RIGHT).crop(card.getbbox())
    s = int(FS * 0.55) / card.height
    c2 = card.resize((int(card.width * s), int(FS * 0.55)), Image.LANCZOS)
    bk = Image.new("RGBA", (FS, FS), (0, 0, 0, 0))
    bk.paste(c2, ((FS - c2.width) // 2, FS - c2.height - FOOT), c2)
    return bk


def body_h_bbox(a):
    rgb = a[:, :, :3].astype(int)
    FLASH = (rgb[:, :, 0] > 190) & (rgb[:, :, 1] > 120) & (rgb[:, :, 1] < 220) & (rgb[:, :, 2] < 130)
    WHITE = (rgb[:, :, 0] > 205) & (rgb[:, :, 1] > 205) & (rgb[:, :, 2] > 205)
    body = (a[:, :, 3] > 20) & ~FLASH & ~WHITE
    ys, xs = np.where(body)
    if len(xs) == 0: return 0, 0, 0, 0, 0
    return ys.max() - ys.min() + 1, xs.min(), ys.min(), xs.max(), ys.max()


def flash_px(a):
    rgb = a[:, :, :3].astype(int)
    return int(((rgb[:, :, 0] > 190) & (rgb[:, :, 1] > 120) & (rgb[:, :, 1] < 220) & (rgb[:, :, 2] < 130) & (a[:, :, 3] > 20)).sum())


def magenta_residue_px(a):
    rgb = a[:, :, :3].astype(int)
    return int(((rgb[:, :, 0] > 110) & (rgb[:, :, 2] > 110) & (rgb[:, :, 1] < (0.75 * np.minimum(rgb[:, :, 0], rgb[:, :, 2]))) & (a[:, :, 3] > 20)).sum())


def score_cell(fr, base_h, ref_ratio, is_fire):
    """格评分: 越高越好。硬门: 净高超界弃。"""
    h, x0, y0, x1, y1 = body_h_bbox(np.asarray(fr))
    if h == 0 or abs(h - base_h) > 28: return None
    w = x1 - x0 + 1
    ratio = w / h
    fp = flash_px(np.asarray(fr))
    if is_fire and fp < 300: return None          # 击发格必须带焰
    if not is_fire and fp > 300: return None      # 非击发格带焰=废(唯一焰口径)
    mg = magenta_residue_px(np.asarray(fr))
    sc = -abs(h - base_h) * 2.0 - abs(ratio - ref_ratio) * 120.0 - mg * 0.08
    if is_fire:
        sc += min(fp, 4000) * 0.01                # 焰量适中加分(星焰饱满)
    return round(sc, 1)


def main():
    cfg = B.BYUID[UID]
    typ, desc, weapon = B.UNITS[UID]
    keys = P.load_keys()
    bk = book_card()
    bk.save(os.path.join(OUT, "bookend_flip.png"))
    base_h, _, _, _, _ = body_h_bbox(np.asarray(bk))
    ref_ratio = bk.width / float(bk.height)
    print("书挡基准净高=%d 宽高比=%.3f" % (base_h, ref_ratio))
    # 底稿: 镜像卡图(batch_regen FLIP_CARD_UNITS 同口径)
    card = Image.open(os.path.join(WS, cfg["icon_rel"].replace("\\", "/")))
    card = B.make_transparent(card)
    card = card.crop(card.getbbox()).transpose(Image.FLIP_LEFT_RIGHT)
    tpl = P.build_grid_template_4_card(card, FS)
    tpl_b64 = base64.b64encode(io_bytes(tpl)).decode()
    poses = B.poses_for_uid(typ, desc, weapon, UID)
    # 掷 N 卷
    pool = {2: [], 3: [], 4: [], 5: []}
    ledger = []
    for roll in range(1, NROLL + 1):
        tag = "pool_r%d" % roll
        prompt = P.SKELETON.replace("{SUBJECT}",
            "the same %s as in the reference image, with the %s, " % (desc, weapon) +
            "small blue electric-glow accents only on its armor panels, the vehicle silhouette is single and clear, no second outline, "
            "the muzzle flash appears exactly at the tip of the %s at its exact position in the reference image, "
            "the entire vehicle and the full flash fit comfortably inside each panel with generous magenta margins, nothing touches or crosses the panel edges, " % weapon +
            "shown in a regular grid of exactly 4 flat panels, 2 columns and 2 rows, "
            "all 4 panels showing THE SAME unit, identical scale/colors/rendering, NO shadow under any figure. " +
            " ".join("%s: the same unit %s, facing LEFT in profile, never mirrored, holding the %s (never empty-handed), NO scope;"
                     % (["top-left", "top-right", "bottom-left", "bottom-right"][i], p, weapon) for i, p in enumerate(poses)) +
            " The star-shaped muzzle flash appears in ONLY ONE panel, the firing panel (top-right). No other panel has any flash. "
            "Keep the exact 4-panel grid layout and spacing of the reference image unchanged, changing only the pose. "
            "One complete figure centered in each panel, generous empty magenta spacing, no borders, no grid lines, no labels, no numbers.")
        try:
            url, kh = B.i2i(prompt, tpl_b64, keys, tag, out_raw=RAW)
            png = os.path.join(RAW, "grid_%s.png" % tag)
            subprocess.run(["curl", "-sS", "-m", "120", "-o", png, url], check=True)
        except RuntimeError as e:
            print("roll%d × %s" % (roll, e)); time.sleep(15); continue
        grid = Image.open(png).convert("RGB")
        alpha_full, labels, comps = P.grid4_to_frames(grid)
        if alpha_full is None:
            print("roll%d 格提取失败: %s" % (roll, comps)); continue
        got = 0
        for gi, (npx, bbox, cid) in enumerate(comps):
            slot = gi + 2                          # 格位 2~5 (TL=2蓄势 TR=3击发 BL=4后坐 BR=5归稳)
            x0, y0, x1, y1 = bbox
            x0, y0 = max(0, x0 - 2), max(0, y0 - 2)
            x1, y1 = min(alpha_full.shape[1] - 1, x1 + 2), min(alpha_full.shape[0] - 1, y1 + 2)
            mask = labels[y0:y1 + 1, x0:x1 + 1] == cid
            a2 = np.where(mask, alpha_full[y0:y1 + 1, x0:x1 + 1], 0).astype(np.uint8)
            rgba = np.dstack([np.asarray(grid)[y0:y1 + 1, x0:x1 + 1], a2])
            fr = cell_to_frame(rgba, base_h)
            if fr is None: continue
            sc = score_cell(fr, base_h, ref_ratio, is_fire=(slot == 3))
            fr.save(os.path.join(POOL_DIR, "r%d_s%d.png" % (roll, slot)))
            ledger.append({"roll": roll, "slot": slot, "score": sc,
                           "h": body_h_bbox(np.asarray(fr))[0], "flash": flash_px(np.asarray(fr)),
                           "magenta": magenta_residue_px(np.asarray(fr))})
            if sc is not None:
                pool[slot].append((sc, roll, fr))
                got += 1
        print("roll%d: %d/4 格入池" % (roll, got), flush=True)
        time.sleep(4)
    json.dump(ledger, open(os.path.join(POOL_DIR, "pool_ledger.json"), "w"), ensure_ascii=False, indent=1)
    # 择优拼卷
    final = {}
    for slot in (2, 3, 4, 5):
        if not pool[slot]:
            print("槽位 %d 无合格格!" % slot); sys.exit(1)
        pool[slot].sort(key=lambda t: -t[0])
        sc, roll, fr = pool[slot][0]
        final[slot] = fr
        print("槽位%d ← roll%d (score=%s, 候选%d个)" % (slot, roll, sc, len(pool[slot])))
    # 色迁移对齐书挡 + 贴地带渣清
    bk_arr = np.asarray(bk)
    bm, bs = P.body_stats(bk_arr[:, :, :3].astype(float), bk_arr[:, :, 3])
    for slot, fr in final.items():
        arr = np.asarray(fr).copy()
        tr = P.color_transfer(arr[:, :, :3], arr[:, :, 3], bm, bs)
        out = np.dstack([np.asarray(tr)[:, :, :3], arr[:, :, 3]]).astype(np.uint8)
        rgb = out[:, :, :3].astype(int); rows = np.arange(FS)[:, None]
        mag = (rgb[:, :, 0] > 110) & (rgb[:, :, 2] > 110) & (rgb[:, :, 1] < (0.75 * np.minimum(rgb[:, :, 0], rgb[:, :, 2])))
        out[:, :, 3][mag & (rows > FS - 26)] = 0
        out[:, :, 3][mag & (rows < 24)] = 0
        final[slot] = Image.fromarray(out)
    # 净高迭代归一(基准=书挡)
    for rnd in range(4):
        hs = {s: body_h_bbox(np.asarray(im))[0] for s, im in final.items()}
        d = max(max(hs.values()) - base_h, base_h - min(hs.values()))
        print("归一轮%d: %s 差%d" % (rnd + 1, hs, d))
        if d <= 2: break
        for s, im in final.items():
            h, x0, y0, x1, y1 = body_h_bbox(np.asarray(im))
            k = base_h / h
            if abs(k - 1) <= 0.003: continue
            im2 = im.resize((int(round(FS * k)),) * 2, Image.LANCZOS)
            _, x0, y0, x1, y1 = body_h_bbox(np.asarray(im2))
            o = Image.new("RGBA", (FS, FS), (0, 0, 0, 0))
            o.paste(im2, ((FS - (x1 - x0 + 1)) // 2 - x0, FS - FOOT - (y1 - y0 + 1) - y0), im2)
            final[s] = o
    # 拼卷
    order = [bk, final[2], final[3], final[4], final[5], bk]
    for i, fr in enumerate(order, 1):
        fr.save(os.path.join(OUT, "frames", "f%d.png" % i))
    sheet = Image.new("RGBA", (FS * 6, FS), (0, 0, 0, 0))
    for i in range(6):
        sheet.paste(Image.open(os.path.join(OUT, "frames", "f%d.png" % (i + 1))), (i * FS, 0))
    sheet.save(os.path.join(OUT, "sheet_attack_api.png"))
    old = Image.open(os.path.join(WS, "assets/effects/unit_anims/ww2_inf_panzerschrek/sheet_attack.png")).convert("RGBA")
    cv = Image.new("RGBA", (FS * 6, FS * 2 + 8), (16, 20, 24, 255))
    for i in range(6):
        cv.paste(old.crop((i * FS, 0, (i + 1) * FS, FS)), (i * FS, 0))
    cv.paste(sheet, (0, FS + 8))
    cv.save(os.path.join(OUT, "strip_new_vs_old.png"))
    hs = {i: body_h_bbox(np.asarray(Image.open(os.path.join(OUT, "frames", "f%d.png" % i))))[0] for i in range(1, 7)}
    print("终净高:", hs, "差:", max(hs.values()) - min(hs.values()))
    print("done")


def cell_to_frame(rgba, base_h):
    """格 rgba → 256 帧(载具居中, 高缩到书挡基准附近, 焰随等比)"""
    comp, _ = P.largest_component(rgba[:, :, 3])
    if comp is not None: rgba = np.dstack([rgba[:, :, :3], comp])
    a = rgba[:, :, 3]; ys, xs = np.where(a > 20)
    if len(xs) == 0: return None
    crop = Image.fromarray(rgba[ys.min():ys.max() + 1, xs.min():xs.max() + 1])
    s = (base_h * 1.02) / crop.height
    max_w = int(FS * 0.94)
    if crop.width * s > max_w: s = max_w / crop.width
    crop = crop.resize((max(1, int(crop.width * s)), max(1, int(crop.height * s))), Image.LANCZOS)
    out = Image.new("RGBA", (FS, FS), (0, 0, 0, 0))
    out.paste(crop, ((FS - crop.width) // 2, FS - crop.height - FOOT), crop)
    return out


def io_bytes(im):
    import io
    buf = io.BytesIO(); im.save(buf, format="PNG"); return buf.getvalue()


if __name__ == "__main__":
    main()
