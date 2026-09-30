# -*- coding: utf-8 -*-
"""程序化攻击动画构建器（记录4·九轮固化，修复火光出界 bug）。

12 帧时序（8fps）：待机x2 -> 点火 -> 峰值 -> 衰减 -> 后坐 -> 烟散 -> 回位。
火光三层（白热核/中焰/橙缘）+ 前向火星；整体钳内修复：cx = max(tip-2, flash*1.5+2)
—— 旧版只钳中心，炮口贴左缘的单位（tip=0~2）画大火光时椭圆左半出帧被裁（复刻 77mm 病）。
能量武器调色板人工指派（自动色相被车体符文污染）。

用法：python tools/prog_attack_build.py <anim_key> [more <key> <weapon>...]
备份：.godot/art_backup_anim_regen_20260927/sheet_attack_<key>.png（幂等）
"""
import os
import sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BAK = os.path.join(ROOT, ".godot", "art_backup_anim_regen_20260927")
FS = 256
ENERGY = {"guardian_future_omega"}


def build(key):
    d = os.path.join(ROOT, "assets", "effects", "unit_anims", key)
    idle = Image.open(os.path.join(d, "sheet_idle.png")).convert("RGBA")
    f0 = idle.crop((0, 0, FS, FS))
    a = np.asarray(f0)
    al = a[:, :, 3]
    ys, xs = np.where(al > 12)
    band = (ys > ys.min() + (ys.max()-ys.min())*0.22) & (ys < ys.min() + (ys.max()-ys.min())*0.62)
    txi = xs[band].argmin()
    tx, ty = int(xs[band][txi]), int(ys[band][txi])
    energy = key in ENERGY
    if energy:
        core, mid, fringe = (225, 250, 255), (120, 200, 255), (60, 120, 255)
    else:
        core, mid, fringe = (255, 246, 218), (255, 200, 80), (255, 140, 30)

    def frame(shift, flash=0, smoke=0):
        fr = Image.new("RGBA", (FS, FS), (0, 0, 0, 0))
        fr.alpha_composite(f0, (shift, 0))
        ov = Image.new("RGBA", (FS, FS), (0, 0, 0, 0))
        dr = ImageDraw.Draw(ov)
        if flash:
            # 火光整体钳内：左缘 (cx - flash*1.5) >= 2
            cx = max(int(flash * 1.5) + 2, tx - 2 + shift)
            cy = ty
            dr.ellipse([cx-flash*1.5, cy-flash*0.55, cx+flash*0.55, cy+flash*0.55], fill=(*fringe, 235))
            dr.ellipse([cx-flash*1.05, cy-flash*0.42, cx+flash*0.38, cy+flash*0.42], fill=(*mid, 245))
            dr.ellipse([cx-flash*0.6, cy-flash*0.26, cx+flash*0.22, cy+flash*0.26], fill=(*core, 255))
            for k in range(4):
                lx = cx - flash*1.2 - k*6
                if lx < 4:
                    break
                dr.line([lx, cy+(k-1)*3, lx-9, cy+(k-1)*4], fill=(*mid, 230-k*45), width=2)
        if smoke:
            rng = np.random.default_rng(11)
            for k in range(smoke*4):
                sx = tx + shift + 8 + int(rng.integers(-8, 14))
                sy = ty - 8 - int(rng.integers(0, 18))
                rr = int(4 + rng.integers(0, 6))
                dr.ellipse([sx-rr, sy-rr, sx+rr, sy+rr], fill=(198, 204, 212, 36+smoke*10))
        ov = ov.filter(ImageFilter.GaussianBlur(0.7))
        fr.alpha_composite(ov)
        return fr

    SEQ = [(0,0,0), (-1,0,0), (2,14,1), (5,30,2), (5,26,3), (4,16,3),
           (3,8,2), (2,0,3), (1,0,2), (0,0,1), (0,0,0), (0,0,0)]
    sheet = Image.new("RGBA", (FS*12, FS), (0, 0, 0, 0))
    for i, (sh, fl, sm) in enumerate(SEQ):
        sheet.alpha_composite(frame(sh, fl, sm), (i*FS, 0))
    os.makedirs(BAK, exist_ok=True)
    bakp = os.path.join(BAK, "sheet_attack_%s.png" % key)
    if not os.path.exists(bakp):
        import shutil
        shutil.copy2(os.path.join(d, "sheet_attack.png"), bakp)
    sheet.save(os.path.join(d, "sheet_attack.png"))
    print(key, "rebuilt (flash clamped in-frame), muzzle tip=", (tx, ty))


if __name__ == "__main__":
    args = sys.argv[1:]
    for i in range(0, len(args), 2):
        build(args[i])
