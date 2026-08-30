# -*- coding: utf-8 -*-
"""卡图直出动画保底生成器（视频生成反复失败的场景类单位适用, 如机枪巢/堡垒）。

用法: python tools/anim_fallback_from_card.py <unit_key> <card_png> [foot_frac]

产物与视频管线完全同构: <unit>_<name>/{idle,attack}/f*.png + sheet + meta.json。
原理: 以卡图为唯一真身, 合成微动效 ——
  idle  8帧: 呼吸缩放(1.000~1.004 正弦) + ±1px 竖向浮动, 首尾一致无缝循环
  attack 12帧: 同上 + 枪口火光(剪影最左突出处, 暖色星芒 4 帧) + 后坐抖动
注意: 攻击火光位置是启发式估计(剪影最左突出中点), 生成后必须人工审查。
"""
import os
import sys
import json
import math

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
OUT_DIR = os.path.join(ROOT, "资料", "单位分帧动画")

from PIL import Image, ImageDraw, ImageFilter  # noqa: E402
import numpy as np  # noqa: E402

CANVAS = 512


def build_frames(unit_key, card_png, foot_frac=0.92):
    import importlib.util
    spec = importlib.util.spec_from_file_location(
        "gua", os.path.join(ROOT, "tools", "generate_unit_animations.py"))
    m = importlib.util.module_from_spec(spec)
    try:
        spec.loader.exec_module(m)
    except SystemExit:
        pass
    name = m.UNITS[unit_key]["name"]

    card = Image.open(card_png).convert("RGBA")
    a = np.asarray(card)
    msk = a[:, :, 3] > 16
    ys, xs = np.where(msk)
    x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
    crop = card.crop((x0, y0, x1 + 1, y1 + 1))
    bw, bh = crop.size
    scale = min((CANVAS - 16) / bw, (CANVAS * foot_frac - 8) / bh)
    base_nw, base_nh = max(1, int(bw * scale)), max(1, int(bh * scale))
    base = crop.resize((base_nw, base_nh), Image.LANCZOS)
    cx, cy = (CANVAS - base_nw) // 2, int(CANVAS * foot_frac) - base_nh

    # 枪口估计: 剪影最左列的内容垂直中点(全局坐标)
    left_col = xs.min()
    col_ys = ys[xs == left_col]
    mz_y = int((col_ys.min() + col_ys.max()) / 2)
    mz_x = left_col
    # 映射到画布坐标
    mz_cx = cx + int((mz_x - x0) * scale)
    mz_cy = cy + int((mz_y - y0) * scale)

    def flash(size, alpha):
        img = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        r = size
        d.ellipse([mz_cx - r, mz_cy - int(r * 0.7), mz_cx + int(r * 0.4), mz_cy + int(r * 0.7)],
                  fill=(255, 230, 140, alpha))
        d.ellipse([mz_cx - int(r * 0.5), mz_cy - int(r * 0.35), mz_cx + int(r * 0.25), mz_cy + int(r * 0.35)],
                  fill=(255, 255, 235, min(255, alpha + 60)))
        # 星芒(左向为主)
        d.polygon([(mz_cx, mz_cy), (mz_cx - int(r * 2.1), mz_cy - int(r * 0.28)),
                   (mz_cx - int(r * 2.1), mz_cy + int(r * 0.28))], fill=(255, 220, 130, int(alpha * 0.75)))
        return img.filter(ImageFilter.GaussianBlur(1.2))

    out = {}
    for anim, n in (("idle", 8), ("attack", 12)):
        frames = []
        for i in range(n):
            t = i / n
            pulse = 1.0 + 0.004 * math.sin(t * 2 * math.pi)
            bob = int(round(math.sin(t * 2 * math.pi)))
            nw, nh = max(1, int(base_nw * pulse)), max(1, int(base_nh * pulse))
            f = base.resize((nw, nh), Image.LANCZOS)
            canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
            px = cx + (base_nw - nw) // 2
            py = cy + (base_nh - nh) + bob
            shake = 0
            if anim == "attack" and 3 <= i <= 7:
                shake = (2 if i % 2 == 0 else -2) if i in (3, 4) else (1 if i % 2 == 0 else -1)
            canvas.paste(f, (px + shake, py), f)
            if anim == "attack" and 3 <= i <= 6:
                fs = {3: 22, 4: 30, 5: 24, 6: 14}[i]
                fa = {3: 200, 4: 235, 5: 170, 6: 110}[i]
                canvas.alpha_composite(flash(fs, fa))
            frames.append(canvas)
        out[anim] = frames
    return name, out


def main():
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    unit_key = sys.argv[1]
    card_png = sys.argv[2]
    foot = float(sys.argv[3]) if len(sys.argv) > 3 else 0.92
    name, out = build_frames(unit_key, card_png, foot)
    for anim, frames in out.items():
        adir = os.path.join(OUT_DIR, "%s_%s" % (unit_key, name), anim)
        os.makedirs(adir, exist_ok=True)
        files = []
        for i, im in enumerate(frames):
            fn = "f%02d.png" % i
            im.save(os.path.join(adir, fn))
            files.append(fn)
        sheet = Image.new("RGBA", (CANVAS * len(files), CANVAS), (0, 0, 0, 0))
        for i, fn in enumerate(files):
            sheet.paste(Image.open(os.path.join(adir, fn)), (i * CANVAS, 0))
        sheet.save(os.path.join(adir, "sheet_%s.png" % anim))
        meta = {
            "unit": unit_key, "unit_name": name, "anim": anim,
            "frames": len(files), "frame_files": files,
            "canvas": CANVAS, "suggested_fps": 10 if anim == "attack" else 8,
            "foot_frac": foot, "source": "fallback_from_card",
            "notes": "保底方案: 视频多次生成都带场景/地面, 改由卡图直出合成微动效; 枪口火光为启发式定位, 必须人工审查",
        }
        with open(os.path.join(adir, "meta.json"), "w", encoding="utf-8") as f:
            json.dump(meta, f, ensure_ascii=False, indent=1)
        print("[%s/%s] %d frames + sheet (fallback)" % (unit_key, anim, len(files)))


if __name__ == "__main__":
    main()
