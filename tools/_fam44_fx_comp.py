# -*- coding: utf-8 -*-
"""fam44 FX 合成兜底（2026-10-07，MK10 定案路线）
生图只出干净姿态板；炮口焰+硝烟在本工具里程序合成，硬裁剪在本格内部，
从根上消灭：火光错边 / 越格截断 / 品红渍 / 键控黑洞。

用法:
  python tools/_fam44_fx_comp.py --sheet <sheet_832.png> --cuts "x1,x2|y1" \
      --muzzle-json <spec.json>

  spec.json: {"flash_scale": 1.0, "flash_scale4": 0.55,
              "3": {"mx": 120, "my": 300}, "4": {...}, "5": {...}}  # 各帧炮口尖(整版坐标)
产出: <sheet>_fx.png + <sheet>_fx_preview.gif
"""
import argparse
import json
import math
import os
import random
import sys

from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import img25_attack_gen as g  # 复用 OUT

MUZZLE_U = 0.80  # 焰图右缘炮口尖的归一化位置


def make_flash(w, h, seed=7):
    """朝左扇形炮口焰：深橙外瓣+亮橙黄内瓣+白芯，右缘为炮口。"""
    rnd = random.Random(seed)
    s = max(w, h) * 2
    im = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    cx, cy, R = s * MUZZLE_U, s / 2, s * 0.30
    n = 7

    def fan(scale):
        pts = []
        for i in range(2 * n + 1):
            ang = -math.pi / 2 + math.pi * i / (2 * n)
            rr = R * scale * (1.15 if i % 2 == 0 else rnd.uniform(0.50, 0.65))
            pts.append((cx - math.cos(ang) * rr, cy + math.sin(ang) * rr))
        return pts

    d.polygon(fan(1.30), fill=(255, 130, 25, 235))
    d.polygon(fan(0.95), fill=(255, 200, 80, 250))
    d.polygon(fan(0.60), fill=(255, 240, 170, 255))
    d.ellipse((cx - R * 0.62, cy - R * 0.42, cx + R * 0.30, cy + R * 0.42),
              fill=(255, 255, 235, 255))
    im = im.filter(ImageFilter.GaussianBlur(s * 0.012))
    return im.resize((w, h), Image.LANCZOS)


def make_puff(w, h, alpha, seed=0):
    """程序软灰烟团：重叠椭圆+高斯模糊。"""
    rnd = random.Random(seed)
    s = max(w, h) * 3
    im = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for _ in range(6):
        rw = s * rnd.uniform(0.22, 0.38)
        rh = s * rnd.uniform(0.18, 0.30)
        cx = s / 2 + rnd.uniform(-s * 0.18, s * 0.18)
        cy = s / 2 + rnd.uniform(-s * 0.12, s * 0.12)
        d.ellipse((cx - rw, cy - rh, cx + rw, cy + rh),
                  fill=(205, 200, 195, int(alpha * rnd.uniform(0.7, 1.0))))
    im = im.filter(ImageFilter.GaussianBlur(s * 0.06))
    return im.resize((w, h), Image.LANCZOS)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--sheet", required=True)
    ap.add_argument("--cuts", required=True, help='"x1,x2|y1" 与生成日志一致')
    ap.add_argument("--muzzle-json", required=True)
    args = ap.parse_args()

    img0 = Image.open(args.sheet)
    spec = json.load(open(args.muzzle_json, encoding="utf-8"))
    muzzle_u = float(spec.get("muzzle_u", MUZZLE_U))
    xs = [0] + [int(v) for v in args.cuts.split("|")[0].split(",")] + [img0.width]
    ys = [0] + [int(v) for v in args.cuts.split("|")[1].split(",")] + [img0.height]

    sheet = img0.convert("RGBA")
    fscale = float(spec.get("flash_scale", 1.0))
    plan = {
        3: [("flash", fscale, 255), ("puff", 1.0, 200)],
        4: [("flash", float(spec.get("flash_scale4", 0.55)), 170), ("puff", 1.3, 160)],
        5: [("puff", 1.6, 100)],
    }
    for f_idx, ops in plan.items():
        r, c = (f_idx - 1) // 3, (f_idx - 1) % 3
        cell = (xs[c], ys[r], xs[c + 1], ys[r + 1])
        cw, ch = cell[2] - cell[0], cell[3] - cell[1]
        mp = spec[str(f_idx)]
        mx, my = mp["mx"], mp["my"]
        for kind, sc, alpha in ops:
            if kind == "flash":
                fw = int(cw * 0.52 * sc)
                fx = make_flash(fw, int(fw * 0.62), seed=f_idx)
                if alpha < 255:
                    a = fx.getchannel("A").point(lambda v: v * alpha // 255)
                    fx.putalpha(a)
                px_ = int(mx - fx.width * muzzle_u)
                py_ = int(my - fx.height / 2)
            else:
                pw, ph = int(cw * 0.30 * sc), int(ch * 0.22 * sc)
                fx = make_puff(pw, ph, alpha, seed=f_idx * 10 + int(sc * 10))
                px_ = int(mx - fx.width * 0.9)
                py_ = int(my - fx.height * 0.75)
            # 硬裁剪在本格内部：贴到格大小画布再合成，越界部分自动裁掉
            cell_im = sheet.crop(cell)
            tmp = Image.new("RGBA", cell_im.size, (0, 0, 0, 0))
            tmp.paste(fx, (px_ - cell[0], py_ - cell[1]), fx)
            cell_im.alpha_composite(tmp)
            sheet.paste(cell_im, (cell[0], cell[1]))

    out = args.sheet[:-4] + "_fx.png"
    sheet.save(out)
    frames = []
    for f_idx in range(6):
        r, c = f_idx // 3, f_idx % 3
        cell = sheet.crop((xs[c], ys[r], xs[c + 1], ys[r + 1]))
        bg = Image.new("RGBA", cell.size, (17, 17, 20, 255))
        bg.alpha_composite(cell)
        frames.append(bg.convert("RGB").resize((384, 384)))
    gif = out[:-4] + "_preview.gif"
    frames[0].save(gif, save_all=True, append_images=frames[1:], duration=140, loop=0)
    print("OK", out)
    print("OK", gif)


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    main()
