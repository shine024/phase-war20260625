# -*- coding: utf-8 -*-
"""technical_e 攻击兜底（2026-10-04）：生图 4 掷全废（白车漂色/朝向乱/轴数跳），
改走 route3 已验证配方——卡图直出基帧 + 火光贴图库 paste + 后坐位移，全确定性零漂移。
产物以 R3 候选身份落 staging（832 3x2 布局 + GIF），进 b5 验收台拍板。
用法: python tools/_b5_technical_fallback.py
"""
import io
import json
import os
import sys
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, ".godot", "unit_review", "img25_staging")
VFX = os.path.join(ROOT, ".godot", "unit_review", "img25_vfx")
CARD = os.path.join(ROOT, "assets", "card_icons", "enemy", "vis_enemy_058.png")
FS2 = 512
CELL = 832


def build_base():
    card = Image.open(CARD).convert("RGBA")
    a = np.asarray(card)
    ys, xs = np.where(a[..., 3] > 10)
    body = card.crop((int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1))
    w, h = body.size
    sc = min((FS2 - 40) / w, (FS2 - 40) / h, 1.6)
    body = body.resize((max(1, int(w * sc)), max(1, int(h * sc))), Image.LANCZOS)
    base = Image.new("RGBA", (FS2, FS2), (0, 0, 0, 0))
    base.paste(body, ((FS2 - body.width) // 2, FS2 - 16 - body.height), body)
    return base


def muzzle_of(base):
    """枪口=顶部结构带（top..top+60）最右簇的质心。卡图枪管朝右。"""
    a = np.asarray(base)
    ys, xs = np.where(a[..., 3] > 10)
    top = int(ys.min())
    band = (ys >= top) & (ys <= top + 60)
    bx, by = xs[band], ys[band]
    tip = bx >= bx.max() - 24
    return float(bx[tip].mean()), float(by[tip].mean())


def pick_flashes():
    """目验选型：峰值=chieftain 星形爆焰，衰减=stinger 紧凑星焰（均 clean，右翻用）。"""
    names = ["cold_chieftain_c2.png", "mod_stinger_c2.png"]
    texs = []
    for n in names:
        p = os.path.join(VFX, n)
        if not os.path.isfile(p):
            raise SystemExit("缺贴图 %s" % n)
        texs.append(Image.open(p).convert("RGBA"))
    print("火光贴图:", names)
    return texs[0], texs[1]


def paste_flash(fr, tex, cx, cy, scale, alpha):
    t = tex.copy()
    t = t.transpose(Image.FLIP_LEFT_RIGHT)  # 贴图为左向火光，枪口朝右→水平翻转
    if scale != 1.0:
        t = t.resize((max(1, int(t.width * scale)), max(1, int(t.height * scale))), Image.LANCZOS)
    if alpha < 1.0:
        an = np.asarray(t).copy()
        an[..., 3] = (an[..., 3].astype(int) * alpha).astype(np.uint8)
        t = Image.fromarray(an)
    fr.alpha_composite(t, (int(cx - t.width * 0.25), int(cy - t.height / 2)))
    return fr


def shift(fr, dx):
    a = np.asarray(fr).copy()
    a = np.roll(a, dx, axis=1)
    if dx > 0:
        a[:, :dx, :] = 0
    return Image.fromarray(a)


def main():
    base = build_base()
    mx, my = muzzle_of(base)
    print("基帧 OK，枪口=(%.0f,%.0f)" % (mx, my))
    big, small = pick_flashes()
    b512 = big.resize((min(big.width, 260), int(big.height * min(big.width, 260) / big.width)), Image.LANCZOS)
    s512 = small.resize((min(small.width, 150), int(small.height * min(small.width, 150) / small.width)), Image.LANCZOS)
    rng = np.random.RandomState(7)  # 抛壳散布确定性

    frames = []
    # f0 待机
    frames.append(base.copy())
    # f1 预光
    fr = base.copy(); paste_flash(fr, s512, mx, my, 1.0, 0.65); frames.append(fr)
    # f2 峰值+后坐
    fr = shift(base, 3); paste_flash(fr, b512, mx, my, 1.0, 1.0); frames.append(fr)
    # f3 衰减+抛壳
    fr = shift(base, 3); paste_flash(fr, s512, mx, my, 1.15, 0.9)
    ca = Image.new("RGBA", (FS2, FS2), (0, 0, 0, 0))
    for k in range(5):
        x = int(mx + 18 + rng.randint(0, 26)); y = int(my - 14 - rng.randint(0, 20))
        ca.putpixel((x, y), (255, 190, 80, 235)); ca.putpixel((x + 1, y), (230, 150, 60, 210))
    fr.alpha_composite(ca); frames.append(fr)
    # f4 余光+后坐回
    fr = shift(base, 2); paste_flash(fr, s512, mx, my, 0.75, 0.5); frames.append(fr)
    # f5 回位余烟(无)
    frames.append(shift(base, 1))
    # f6-f9 待机
    for _ in range(4):
        frames.append(base.copy())

    # 832 3x2 布局（R3 候选身份）
    sheet = Image.new("RGBA", (3 * CELL, 2 * CELL), (0, 0, 0, 0))
    for i, fr in enumerate(frames):
        cell = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
        cell.alpha_composite(fr, ((CELL - FS2) // 2, (CELL - FS2) // 2))
        sheet.alpha_composite(cell, (i % 3 * CELL, i // 3 * CELL))
    sheet.save(os.path.join(OUT, "mod_air_technical_e_R3_attack_sheet_832.png"))

    # GIF（256 帧宽，fps 8 → 125ms）
    gif_frames = [f.resize((256, 256), Image.LANCZOS) for f in frames]
    gif_frames[0].save(os.path.join(OUT, "mod_air_technical_e_R3_attack_anim.gif"),
                       save_all=True, append_images=gif_frames[1:], duration=125, loop=0,
                       disposal=2, transparency=0)

    # 深底网格（复用 scrub 的 att_grid）
    import importlib.util
    spec = importlib.util.spec_from_file_location("m", os.path.join(ROOT, "tools", "_b5_scrub_pink.py"))
    m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
    m.att_grid(os.path.join(OUT, "mod_air_technical_e_R3_attack_sheet_832.png"))
    try:
        print("R3 兜底卷落盘（sheet+gif+cells_dark）")
    except ValueError:
        pass  # import 洗涤模块会二次包 stdout，收尾 print 可能失效，产物已落盘


if __name__ == "__main__":
    main()
