# -*- coding: utf-8 -*-
"""ft17 攻击帧 帧间大小漂移修复（刚体载具净车高归一）。
诊断: 净车高(剔焰) 132/128/123/128/130/132 —— 生成层四动作帧车体渐进画小(f3 差 9px≈7%)。
修法: 车体是刚体, 帧间尺寸必须恒定 —— 以书挡 f1 净车高为基准, f2~f5 各自按净车高比例
      整帧重缩放(焰随等比), 落地线对齐 foot_frac, 水平按净车 bbox 中心锚画布中心。
      ≠§教训10 禁令(人形肢体 bbox 归一): 载具无肢体越伸, bbox=车体本身, 归一即物理正确。
用法: python tools/api_sprite_pipeline/ft17_frames_fix.py
"""
import os, shutil
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
WS = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(WS, ".godot", "unit_review", "api_ww1_arm_ft17")
FR = os.path.join(OUT, "frames")
FS = 256
FOOT_PX = 18          # 落地线余量(与现卷一致, = round(0.0684*256))
FLASH = lambda rgb: (rgb[:, :, 0] > 190) & (rgb[:, :, 1] > 120) & (rgb[:, :, 1] < 220) & (rgb[:, :, 2] < 130)
WHITE = lambda rgb: (rgb[:, :, 0] > 205) & (rgb[:, :, 1] > 205) & (rgb[:, :, 2] > 205)


def body_bbox(rgba):
    """剔焰净车 bbox (x0,y0,x1,y1)"""
    rgb = rgba[:, :, :3].astype(int)
    al = rgba[:, :, 3]
    body = (al > 20) & ~FLASH(rgb) & ~WHITE(rgb)
    ys, xs = np.where(body)
    return xs.min(), ys.min(), xs.max(), ys.max()


def main():
    bak = os.path.join(OUT, "frames_orig_drift")
    if not os.path.isdir(bak):
        shutil.copytree(FR, bak)
        print("原卷已归档 frames_orig_drift/")
    bh = {}
    for i in range(1, 7):
        a = np.asarray(Image.open(os.path.join(bak, "f%d.png" % i)))
        x0, y0, x1, y1 = body_bbox(a)
        bh[i] = y1 - y0 + 1
    base = min(bh[1], bh[6])     # 书挡净车高 = 基准
    print("净车高:", bh, "基准(书挡) =", base)
    for i in range(1, 7):
        src = os.path.join(bak, "f%d.png" % i)
        rgba = np.asarray(Image.open(src))
        if i in (1, 6):          # 书挡 = 基准本体, 原样保留
            Image.fromarray(rgba).save(os.path.join(FR, "f%d.png" % i))
            continue
        s = base / bh[i]
        im = Image.fromarray(rgba)
        if abs(s - 1.0) > 0.004:
            im = im.resize((max(1, int(round(FS * s))),) * 2, Image.LANCZOS)
        a = np.asarray(im)
        x0, y0, x1, y1 = body_bbox(a)
        out = Image.new("RGBA", (FS, FS), (0, 0, 0, 0))
        # 水平: 净车中心 → 画布中心; 垂直: 净车底缘 → 落地线
        px = (FS - (x1 - x0 + 1)) // 2 - x0
        py = FS - FOOT_PX - (y1 - y0 + 1) - y0
        out.paste(im, (px, py), im)
        out.save(os.path.join(FR, "f%d.png" % i))
        print("f%d: scale=%.3f -> 净车高 %d" % (i, s, base))
    # 重拼 sheet + 对比条
    sheet = Image.new("RGBA", (FS * 6, FS), (0, 0, 0, 0))
    for i in range(6):
        sheet.paste(Image.open(os.path.join(FR, "f%d.png" % (i + 1))), (i * FS, 0))
    sheet.save(os.path.join(OUT, "sheet_attack_api.png"))
    old = Image.open(os.path.join(WS, "assets/effects/unit_anims/ww1_arm_ft17/sheet_attack.png")).convert("RGBA")
    o6 = Image.new("RGBA", (FS * 6, FS), (0, 0, 0, 0))
    for i in range(6):
        o6.paste(old.crop((i * FS, 0, (i + 1) * FS, FS)), (i * FS, 0))
    canvas = Image.new("RGBA", (FS * 6, FS * 2 + 8), (16, 20, 24, 255))
    canvas.paste(o6, (0, 0))
    canvas.paste(sheet, (0, FS + 8))
    canvas.save(os.path.join(OUT, "strip_new_vs_old.png"))
    # 修后预检
    print("--- 修后净车高 ---")
    for i in range(1, 7):
        a = np.asarray(Image.open(os.path.join(FR, "f%d.png" % i)))
        x0, y0, x1, y1 = body_bbox(a)
        al = a[:, :, 3]
        ys, _ = np.where(al > 20)
        print("f%d: 净车高=%d 宽=%d 落地余量=%d" % (i, y1 - y0 + 1, x1 - x0 + 1, FS - 1 - ys.max()))


if __name__ == "__main__":
    main()
