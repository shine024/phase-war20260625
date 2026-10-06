# -*- coding: utf-8 -*-
"""fam43 动感注入驱动（2026-10-06 用户"要有动感"）。

在 codeanim_gen.compose_frame 产物之上、normalize_frames 之前做逐帧后处理：
  ww2_sup_gmc_truck  行驶颠簸：整机 dy/dx 摇摆（连续，非开火窗），无武器效果
  mod_air_multirole  巡航浮动：整机正弦 dy（连续）
  mod_ah64           旋翼旋转：桨叶带运动模糊 + 两道相位旋转弧光（叠加 vfx 后坐）
  fut_colossus       加特林转管：枪管带微颤（叠加 vfx 后坐/焰/烟）
闭环铁律：f9 帧位移恒 0（与 f0 相等）；固定种子。
产物与 codeanim_gen 同目录同格式（sheet/gif/layers 复用 gen_unit 的 layers 即可）。
用法: python tools/fam43_motion_driver.py [key ...]
"""
import io
import json
import math
import os
import random
import sys

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from PIL import Image, ImageDraw, ImageFilter

import codeanim_gen as cg

ROOT = cg.ROOT
OUT = cg.OUT
CFG_PATH = os.path.join(ROOT, ".godot", "unit_review", "codeanim_configs",
                        "_configs_fam43.json")

# dy/dx 表 10 帧，末帧必须 = 首帧（闭环）
DRIVE_DY = [0, 3, 6, 3, 0, -3, -6, -3, 0, 0]
DRIVE_DX = [0, 1, 2, 1, 0, -1, -2, -1, 0, 0]
FLY_DY = [0, -4, -7, -4, 0, 4, 7, 4, 0, 0]
GAT_DY = [0, 1, 2, 1, 0, 1, 2, 1, 0, 0]
# void_stealth_advanced 前冲刀光：f1-f3 冲（峰值 -130），f4-f6 回撤，f7+ 收势（闭环）
DASH_DX = [0, -40, -100, -130, -90, -40, -10, 0, 0, 0]

# mod_ah64 旋翼几何（翻后坐标，1024 域）
ROTOR_BAND = (0, 480, 1024, 620)   # 桨叶+桨毂带
ROTOR_HUB = (259, 550)
ROTOR_RX = 430
ROTOR_RY = 26


def shift_frame(fr, dx, dy):
    out = Image.new("RGBA", fr.size, (0, 0, 0, 0))
    out.alpha_composite(fr, (dx, dy))
    return out


def overlay_truck(fr, f):
    return shift_frame(fr, DRIVE_DX[f], DRIVE_DY[f])


def overlay_multirole(fr, f):
    fr = shift_frame(fr, 0, FLY_DY[f])
    return draw_tracers(fr, (62, 559), f, 0)  # 机炮曳光链（新锚定机首）


def overlay_dive(fr, f):
    """ww2_air_dive_bomber 前冲开火（2026-10-06 (6).json「不用换俯冲了，前冲一下开火就好」）。
    不旋转：f1-f3 向前（朝左）平冲刺，f4-f6 回位，f9=f0 闭环；
    翼枪全窗持续开火（曳光链+枪口焰核），枪口=用户校准 (224,589)。"""
    DIVE_DX = (0, -34, -78, -100, -72, -38, -12, 0, 0, 0)
    fr = shift_frame(fr, DIVE_DX[f], FLY_DY[f] // 2)  # 冲刺带微浮沉
    tip = (224, 589)
    if 1 <= f <= 6:
        tf = (1, 2, 2, 2, 1, 1)[f - 1]  # draw_tracers 活跃窗重映射（全程有弹）
        fr = draw_tracers(fr, tip, tf, 0, n=5)
        if 2 <= f <= 4:  # 冲刺最猛时枪口焰核最亮
            ov = Image.new("RGBA", fr.size, (0, 0, 0, 0))
            d = ImageDraw.Draw(ov)
            r = 26 + (f - 2) * 6
            d.ellipse((tip[0] - r, tip[1] - r, tip[0] + r, tip[1] + r), fill=(255, 190, 80, 150))
            d.ellipse((tip[0] - r // 2, tip[1] - r // 2, tip[0] + r // 2, tip[1] + r // 2),
                      fill=(255, 245, 210, 210))
            ov = ov.filter(ImageFilter.GaussianBlur(1.4))
            fr.alpha_composite(ov)
        # 身后冲刺速度线（f1-f4）：锚在位移后的机尾（原尾 x≈961）
        if 1 <= f <= 4:
            ov = Image.new("RGBA", fr.size, (0, 0, 0, 0))
            d = ImageDraw.Draw(ov)
            al = (110, 90, 60, 36)[f - 1]
            tx = min(1010, 961 + DIVE_DX[f] + 18)
            for i in range(3):
                yy = 470 + (i - 1) * 60   # 机身中带三条
                d.line((tx, yy, min(1023, tx + 70 + i * 40), yy),
                       fill=(220, 225, 235, al - i * 10), width=5 - i)
            ov = ov.filter(ImageFilter.GaussianBlur(1.2))
            fr.alpha_composite(ov)
    return fr


def overlay_dive_bomber(fr, f):
    """平飞巡航浮动（同 multirole 波形，相位一致保编队感）。"""
    return shift_frame(fr, 0, FLY_DY[f])


def draw_tracers(fr, tip, f, ang_deg, n=4, color=(255, 214, 120)):
    """曳光弹链：从枪口沿管轴延伸的等距光点（f1-f3 活跃，f4 渐灭）。
    tip=枪口(1024域)；解决空中单位"画面空旷/半张图"观感——扫射链让画面满。"""
    import math as _m
    life = (f - 1, 2, 1, 0)[min(f, 3)] if 1 <= f <= 4 else None
    if life is None or life <= 0:
        return fr
    a = _m.radians(-ang_deg)
    ax, ay = -_m.cos(a), -_m.sin(a)
    ov = Image.new("RGBA", fr.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(ov)
    base_r = 10
    for i in range(n):
        # 弹链：随 life 前推，等距 90px，半径渐小
        dist = 120 + i * 90 + (3 - life) * 40
        x = tip[0] + ax * dist
        y = tip[1] + ay * dist + i * 4  # 微重力下坠
        r = max(3, base_r - i * 2)
        fade = 1.0 - i * 0.18
        al = int(230 * fade * (1.0 - max(0, f - 3) * 0.5))
        d.ellipse((x - r, y - r, x + r, y + r), fill=color + (al,))
        d.ellipse((x - r * 0.45, y - r * 0.45, x + r * 0.45, y + r * 0.45),
                  fill=(255, 255, 240, min(255, al + 30)))
    ov = ov.filter(ImageFilter.GaussianBlur(1.0))
    fr.alpha_composite(ov)
    return fr


def overlay_ah64(fr, f):
    """桨叶带运动模糊 + 相位旋转弧光（f 相位步进 36°）。"""
    x0, y0, x1, y1 = ROTOR_BAND
    band = fr.crop((x0, y0, x1, y1))
    blur = band.filter(ImageFilter.GaussianBlur(3.2))
    fr.alpha_composite(blur, (x0, y0))
    ov = Image.new("RGBA", fr.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(ov)
    hx, hy = ROTOR_HUB
    for k in range(2):  # 两道错相弧
        a0 = f * 36 + k * 150
        d.arc((hx - ROTOR_RX, hy - ROTOR_RY, hx + ROTOR_RX, hy + ROTOR_RY),
              start=a0, end=a0 + 80, fill=(215, 220, 200, 42), width=7)
    ov = ov.filter(ImageFilter.GaussianBlur(1.2))
    fr.alpha_composite(ov)
    return fr


def overlay_colossus(fr, f):
    """加特林枪管带微颤（转管感）。枪管域=翻后实测枪口 (132,595) 周边横带。"""
    x0, y0, x1, y1 = 70, 545, 300, 648
    band = fr.crop((x0, y0, x1, y1))
    fr.paste(Image.new("RGBA", band.size, (0, 0, 0, 0)), (x0, y0))
    fr.alpha_composite(band, (x0, y0 + GAT_DY[f]))
    return fr


def _bbox(fr):
    import numpy as np
    a = np.asarray(fr)[:, :, 3]
    ys, xs = np.where(a > 8)
    return xs.min(), ys.min(), xs.max(), ys.max()


def overlay_void_adv(fr, f):
    """void_stealth_advanced 前冲发刀光（2026-10-06 用户裁定动作）。
    冲刺位移 + 身后紫色残影速度线 + 前方白色月牙刀光弧扫（f3-f5）。"""
    import numpy as np
    fr = shift_frame(fr, DASH_DX[f], 0)
    x0, y0, x1, y1 = _bbox(fr)
    cx = x0 + (x1 - x0) * 0.30          # 胸口前方（朝左）
    cy = (y0 + y1) // 2
    r = int((x1 - x0) * 0.42)
    ov = Image.new("RGBA", fr.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(ov)
    # ① 身后速度线（f1-f4 冲刺中）
    if 1 <= f <= 4:
        al = (150, 110, 60, 30)[f - 1]
        for i in range(3):
            yy = cy + (i - 1) * 26
            d.line((x1 - 30, yy, x1 + 90 + i * 46, yy),
                   fill=(190, 140, 255, al - i * 14), width=6 - i)
    # ② 刀光弧扫（f3-f5）：起弧角随帧下扫（PIL 角：270°=正上，180°=正左，90°=正下）
    if 3 <= f <= 5:
        p = (0.25, 0.65, 1.0)[f - 3]
        start = 250 - p * 130           # 218° → 120°：左上扫到左下
        span = 74
        w = (30, 20, 11)[f - 3]
        a = (235, 185, 110)[f - 3]
        box = (cx - r, cy - r, cx + r, cy + r)
        d.arc(box, start=start, end=start + span, fill=(150, 100, 255, int(a * 0.5)), width=w + 14)
        d.arc(box, start=start, end=start + span, fill=(255, 255, 255, a), width=w)
    ov = ov.filter(ImageFilter.GaussianBlur(2.2))
    fr.alpha_composite(ov)
    return fr


OVERLAYS = {
    "ww2_sup_gmc_truck": overlay_truck,
    "mod_air_multirole": overlay_multirole,
    "ww2_air_dive_bomber": overlay_dive,
    "mod_ah64": overlay_ah64,
    "fut_colossus": overlay_colossus,
    "void_stealth_advanced": overlay_void_adv,
}


def run(key, cfg):
    rgba = cg.load_anchor(key, cfg)
    rng = random.Random(cg.SEED)
    frames = [cg.compose_frame(rgba, cfg, f, rng) for f in range(cg.COLS * cg.ROWS)]
    frames = [OVERLAYS[key](fr, f) for f, fr in enumerate(frames)]
    align = "center" if cfg.get("cat") == "air" else "bottom"
    cells = cg.normalize_frames(frames, cg.CELL, align)
    sheet = Image.new("RGBA", (cg.CELL * cg.COLS, cg.CELL * cg.ROWS), (0, 0, 0, 0))
    for i, c in enumerate(cells):
        sheet.alpha_composite(c, ((i % cg.COLS) * cg.CELL, (i // cg.COLS) * cg.CELL))
    sheet.save(os.path.join(OUT, "%s_codeanim_sheet.png" % key))
    gif = [Image.alpha_composite(Image.new("RGBA", c.size, (255, 255, 255, 255)), c).convert("P")
           for c in cg.normalize_frames(frames, cg.GIF_CELL, align)]
    gif[0].save(os.path.join(OUT, "%s_codeanim_anim.gif" % key),
                save_all=True, append_images=gif[1:],
                duration=int(1000 / 8), loop=0)  # 游戏内 fps=8（anim.json 契约）
    return key


def main():
    keys = sys.argv[1:] or sorted(OVERLAYS)
    cfgs = json.load(open(CFG_PATH, encoding="utf-8"))
    for k in keys:
        assert k in OVERLAYS, k
        # md5 复跑铁律
        h1 = run(k, cfgs[k])
        h2 = run(k, cfgs[k])
        import hashlib
        p = os.path.join(OUT, "%s_codeanim_sheet.png" % k)
        h3 = hashlib.md5(open(p, "rb").read()).hexdigest()[:8]
        print("%-24s %s %s" % (k, "OK" if h1 == h2 else "MD5-DIFF!", h3))


if __name__ == "__main__":
    main()
