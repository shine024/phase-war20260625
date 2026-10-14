# -*- coding: utf-8 -*-
"""pz_pool 恢复: 格已掷完(pool/*.png 在盘), 跳过 API 重评分+择优拼卷。
修 pz_pool.py 的 np.int64 序列化崩, 单独出拼卷脚本。"""
import json, os, sys
import numpy as np
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__))
WS = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.argv = [sys.argv[0]]
sys.path.insert(0, HERE)
import generate_attack_api as P

FS = 256
UID = "ww2_inf_panzerschrek"
OUT = os.path.join(WS, ".godot", "unit_review", "api_" + UID)
POOL_DIR = os.path.join(OUT, "pool")
FOOT = 8


def body_h_bbox(a):
    rgb = a[:, :, :3].astype(int)
    FLASH = (rgb[:, :, 0] > 190) & (rgb[:, :, 1] > 120) & (rgb[:, :, 1] < 220) & (rgb[:, :, 2] < 130)
    WHITE = (rgb[:, :, 0] > 205) & (rgb[:, :, 1] > 205) & (rgb[:, :, 2] > 205)
    body = (a[:, :, 3] > 20) & ~FLASH & ~WHITE
    ys, xs = np.where(body)
    if len(xs) == 0: return 0, 0, 0, 0, 0
    return int(ys.max() - ys.min() + 1), int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())


def flash_px(a):
    rgb = a[:, :, :3].astype(int)
    return int(((rgb[:, :, 0] > 190) & (rgb[:, :, 1] > 120) & (rgb[:, :, 1] < 220) & (rgb[:, :, 2] < 130) & (a[:, :, 3] > 20)).sum())


def magenta_residue_px(a):
    rgb = a[:, :, :3].astype(int)
    return int(((rgb[:, :, 0] > 110) & (rgb[:, :, 2] > 110) & (rgb[:, :, 1] < (0.75 * np.minimum(rgb[:, :, 0], rgb[:, :, 2]))) & (a[:, :, 3] > 20)).sum())


def score_cell(fr, base_h, ref_ratio, is_fire):
    h, x0, y0, x1, y1 = body_h_bbox(np.asarray(fr))
    if h == 0 or abs(h - base_h) > 28: return None
    w = x1 - x0 + 1
    ratio = w / h
    fp = flash_px(np.asarray(fr))
    if is_fire and fp < 300: return None
    if not is_fire and fp > 300: return None
    mg = magenta_residue_px(np.asarray(fr))
    sc = -abs(h - base_h) * 2.0 - abs(ratio - ref_ratio) * 120.0 - mg * 0.08
    if is_fire:
        sc += min(fp, 4000) * 0.01
    return round(sc, 1)


def book_card():
    card = Image.open(os.path.join(WS, "assets/card_icons/player/vis_player_010.png")).convert("RGBA")
    card = card.transpose(Image.FLIP_LEFT_RIGHT).crop(card.getbbox())
    s = int(FS * 0.55) / card.height
    c2 = card.resize((int(card.width * s), int(FS * 0.55)), Image.LANCZOS)
    bk = Image.new("RGBA", (FS, FS), (0, 0, 0, 0))
    bk.paste(c2, ((FS - c2.width) // 2, FS - c2.height - FOOT), c2)
    return bk


def main():
    bk = book_card()
    base_h, _, _, _, _ = body_h_bbox(np.asarray(bk))
    ref_ratio = bk.width / float(bk.height)
    pool = {2: [], 3: [], 4: [], 5: []}
    ledger = []
    for fn in sorted(os.listdir(POOL_DIR)):
        if not (fn.startswith("r") and fn.endswith(".png")): continue
        roll, slot = int(fn.split("_")[0][1:]), int(fn.split("_s")[1].split(".")[0])
        fr = Image.open(os.path.join(POOL_DIR, fn)).convert("RGBA")
        sc = score_cell(fr, base_h, ref_ratio, is_fire=(slot == 3))
        h, _, _, _, _ = body_h_bbox(np.asarray(fr))
        ledger.append({"roll": roll, "slot": slot, "score": sc, "h": h,
                       "flash": flash_px(np.asarray(fr)), "magenta": magenta_residue_px(np.asarray(fr))})
        if sc is not None:
            pool[slot].append((sc, roll, fn))
    json.dump(ledger, open(os.path.join(POOL_DIR, "pool_ledger.json"), "w"), ensure_ascii=False, indent=1)
    for s in (2, 3, 4, 5):
        print("槽位%d 候选: %s" % (s, [(round(sc, 1), r, f) for sc, r, f in sorted(pool[s], key=lambda t: -t[0])]))
    final = {}
    for slot in (2, 3, 4, 5):
        if not pool[slot]:
            print("槽位 %d 无合格格!" % slot); sys.exit(1)
        pool[slot].sort(key=lambda t: -t[0])
        sc, roll, fn = pool[slot][0]
        final[slot] = Image.open(os.path.join(POOL_DIR, fn)).convert("RGBA")
        print("槽位%d ← %s (score=%s)" % (slot, fn, sc))
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
    order = [bk, final[2], final[3], final[4], final[5], bk]
    os.makedirs(os.path.join(OUT, "frames"), exist_ok=True)
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


if __name__ == "__main__":
    main()
