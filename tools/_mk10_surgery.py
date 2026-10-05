# -*- coding: utf-8 -*-
"""MK10 手术/部署批（2026-10-05）。
scrub   ①品红底渍 alpha 杀（键控半透明品红阴影=车底粉带病根；木轮/钢炮/橙火光均不命中）
        ②idle 重建（monkeypatch depink 前置清洗）rolls+77mm
        ③77mm attack 拼装：R1 六格，3 格朝右翻转回朝左契约，逐格清洗 → MK10 成品 sheet
rerolls rolls attack 重掷 ×2（v1 身份漂移：炮塔逐格变形+火光跑到车体+R2 冒出乘员；
        加锁：同车一致性+乘员不可见+火光只在画面左侧炮塔机枪口）
deploy  idle×2 + 77mm attack 成品 → assets（deploy_sheet 复用 MK8：256+烘描边+counts）
用法: python tools/_mk10_surgery.py [scrub|rerolls|deploy]
"""
import io
import json
import os
import subprocess
import sys
import types

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOOLS = os.path.join(ROOT, "tools")
STG = os.path.join(ROOT, ".godot", "unit_review", "mk10_staging")
OUT = os.path.join(ROOT, ".godot", "unit_review", "img25_staging")


def load(name, path):
    src = open(path, encoding="utf-8").read()
    lines = [ln for ln in src.splitlines()
             if not ln.strip().startswith("sys.stdout = io.TextIOWrapper")]
    mod = types.ModuleType(name)
    mod.__file__ = path
    exec(compile("\n".join(lines), path, "exec"), mod.__dict__)
    return mod


ag = load("mk10_ag", os.path.join(TOOLS, "img25_anchor_gen.py"))
agk = load("mk10_agk", os.path.join(TOOLS, "img25_attack_gen.py"))
a2 = load("mk10_a2", os.path.join(TOOLS, "_mk8_anchor2.py"))
mk8 = load("mk10_mk8", os.path.join(TOOLS, "_mk8_deploy.py"))

import numpy as np  # noqa: E402
from PIL import Image  # noqa: E402


def pink_shadow_kill(rgba, grey_band=False):
    """品红系渍 alpha 杀：r-g>30 且 b-g>18（键控残留的半透明品红阴影）。
    grey_band=True 时追加内容 bbox 下 35% 带内中性灰影杀（只用于无烟 idle 帧，
    攻击帧的硝烟是中性灰会误杀）。"""
    a = np.asarray(rgba).astype(int)
    r, g, b, al = a[:, :, 0], a[:, :, 1], a[:, :, 2], a[:, :, 3]
    hit = (r - g > 30) & (b - g > 18) & (al > 0)
    if grey_band:
        ys, xs = np.where(al > 8)
        if len(ys):
            y0, y1 = ys.min(), ys.max()
            band = np.zeros_like(hit)
            band[int(y0 + 0.65 * (y1 - y0)):, :] = True
            mx = np.maximum(np.maximum(r, g), b)
            mn = np.minimum(np.minimum(r, g), b)
            hit = hit | (band & ((mx - mn < 20) & (r > 130) & (r < 242) & (al > 0)))
    out = a.copy()
    out[:, :, 3][hit] = 0
    n = int(hit.sum())
    print("    [pink_shadow_kill] 杀 %d px%s" % (n, "+灰带" if grey_band else ""), flush=True)
    return Image.fromarray(out.astype(np.uint8))


def red_smoke_grey(rgba):
    """烟团下部红斑降饱和回灰（f3 实测：模型在烟底画饱和红光斑，读感血渍；
    硬杀会洞穿烟团→按 depink 亮度重着色。限内容 bbox 下 40% 带，
    火光橙芯 g 高不命中，只伤低带红块）。"""
    a = np.asarray(rgba).astype(int)
    r, g, b, al = a[:, :, 0], a[:, :, 1], a[:, :, 2], a[:, :, 3]
    ys, xs = np.where(al > 8)
    if not len(ys):
        return rgba
    y0, y1 = ys.min(), ys.max()
    band = np.zeros_like(al, dtype=bool)
    band[int(y0 + 0.60 * (y1 - y0)):, :] = True
    hit = band & (r - g > 60) & (r > 150) & (g < 150) & (al > 0)
    out = a.copy()
    lum = ((r + g + b) // 3)[hit]
    out[:, :, 0][hit] = lum
    out[:, :, 1][hit] = lum
    out[:, :, 2][hit] = lum
    print("    [red_smoke_grey] %d px 回灰" % int(hit.sum()), flush=True)
    return Image.fromarray(out.astype(np.uint8))


_orig_depink = agk.depink


def scrubbed_depink(rgba):
    return _orig_depink(pink_shadow_kill(rgba, grey_band=True))


def phase_scrub():
    # ② idle 重建（清洗前置；a2 模块内部持有自己的 agk，必须 patch 它的）
    a2.agk.depink = scrubbed_depink
    for key in ("ww1_arm_rolls", "ww1_arty_77mm"):
        print("== idle 重建 %s ==" % key, flush=True)
        a2.build_idle(key)
    # ③ 77mm attack 拼装（R1 全六格；f1/f2/f5 朝右→翻回朝左）
    agk.depink = _orig_depink
    sheet = Image.open(os.path.join(OUT, "ww1_arty_77mm_R1_attack_sheet_832.png")).convert("RGBA")
    cw = sheet.width // 3
    cells = [sheet.crop((c * cw, r * cw, (c + 1) * cw, (r + 1) * cw))
             for r in range(2) for c in range(3)]
    FLIP = {1, 2, 5}
    ORDER = [0, 1, 2, 4, 3, 5]   # 烟(4)在前、散尽(3)在后，时序顺
    frames = []
    for i in ORDER:
        c = cells[i]
        if i in FLIP:
            c = c.transpose(Image.FLIP_LEFT_RIGHT)
        c = pink_shadow_kill(c)
        c = red_smoke_grey(c)
        frames.append(c)
    out = Image.new("RGBA", (cw * 3, cw * 2), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        out.paste(f, ((i % 3) * cw, (i // 3) * cw))
    dst = os.path.join(STG, "ww1_arty_77mm_MK10_attack_sheet_832.png")
    out.save(dst)
    print("  [assemble] 77mm 6 格（翻 %s）→ %s" % (sorted(FLIP), dst), flush=True)
    # 暗底预览
    from PIL import ImageDraw
    CV = 250
    cv = Image.new("RGB", (CV * 6 + 60, CV + 40), (24, 24, 28))
    d = ImageDraw.Draw(cv)
    for i, f in enumerate(frames):
        t = f.copy()
        t.thumbnail((CV, CV))
        bg = Image.new("RGBA", t.size, (24, 24, 28, 255))
        bg.alpha_composite(t)
        cv.paste(bg.convert("RGB"), (60 + i * CV, 30))
        d.text((60 + i * CV + 4, 8), "f%d%s" % (i + 1, " flip" if i in FLIP else ""),
               fill=(180, 210, 255))
    cv.save(os.path.join(STG, "ww1_arty_77mm_assembled_check.png"))
    print("  [check] ww1_arty_77mm_assembled_check.png", flush=True)


ROLLS_SUBJECT = ("参考图中的这辆一战英国劳斯莱斯轮式装甲车（修长引擎盖、木辐条车轮、"
                 "车体后部球形旋转炮塔伸出细机枪管，浅蓝灰绿涂装）")

ROLLS_CELLS2 = dict(
    seq="车顶炮塔机枪点射",
    cells={"2": "炮塔机枪口爆出一簇短促火光，车体微微一颤",
           "3": "火光消散，枪口冒出一缕细烟，一枚小弹壳向右后方弹出",
           "4": "机枪口再度短点射，又一簇火光",
           "5": "硝烟在枪口萦绕后飘散",
           "6": "回到待机，与锚定帧完全一致"},
    fx="只要机枪口小火光与细硝烟弹壳，无弹道无曳光，火光只出现在炮塔机枪口",
    extra="Every cell shows the EXACT SAME vehicle as the reference anchor frame: identical "
          "body, identical tall dome turret on the rear hull, identical four wooden spoked "
          "wheels, identical pale blue-grey-green paint. Do not redesign the turret or the "
          "hood in any cell; no crew figure is visible in any cell. The machine gun sits on "
          "top of the dome turret and points to the LEFT; any muzzle flash appears ONLY at "
          "that turret machine-gun barrel on the LEFT side of the vehicle, never at the "
          "front hull, never at the rear, never below the hood line. "
          "Strictly flat side profile facing left, level camera, no perspective foreshortening. "
          "Zoomed-out wide framing: the whole vehicle fully inside each cell with generous "
          "empty space on all four sides, far from the cell edges.")


def phase_rerolls():
    cj = os.path.join(STG, "_mk10_cells2_ww1_arm_rolls.json")
    with open(cj, "w", encoding="utf-8") as f:
        json.dump(ROLLS_CELLS2, f, ensure_ascii=False)
    rc = subprocess.call([sys.executable, os.path.join(TOOLS, "img25_attack_gen.py"),
                          "ww1_arm_rolls", "--subject", ROLLS_SUBJECT,
                          "--rolls", "2", "--cells-json", cj], cwd=ROOT)
    print("[rerolls] rc=%d" % rc, flush=True)


def synth_flash(r=20):
    """炮塔机枪口小火光：白芯橙晕椭圆 + 水平双射线（512 空间 ~64×36）。"""
    W, H = r * 4, r * 2 + 8
    yy, xx = np.mgrid[0:H, 0:W].astype(float)
    cx, cy = W / 2.0, H / 2.0
    dx, dy = xx - cx, yy - cy
    d = np.sqrt((dx / (r * 1.7)) ** 2 + (dy / r) ** 2)
    a = np.clip(1.0 - d, 0, 1) ** 1.5
    core = np.clip(1.0 - d * 2.2, 0, 1)
    img = np.zeros((H, W, 4), float)
    img[:, :, 0] = 255 * (0.72 + 0.28 * core)
    img[:, :, 1] = 255 * (0.42 + 0.52 * core)
    img[:, :, 2] = 255 * (0.10 + 0.75 * core)
    img[:, :, 3] = 255 * a
    for ry in (cy - 1, cy, cy + 1):        # 水平射线
        dxr = np.abs(dx[int(round(ry)), :])
        img[int(round(ry)), :, 3] = np.maximum(
            img[int(round(ry)), :, 3], 255 * np.clip(1.1 - dxr / (r * 2.1), 0, 1))
    return Image.fromarray(img.astype(np.uint8))


def synth_smoke(r, drift=(-1, -0.6), amax=190):
    """软硝烟团：三枚高斯软斑叠合，向左上飘（浅灰 205，深底可读）。"""
    W = int(r * 3.4)
    img = np.zeros((W, W, 4), float)
    for off, rr, aa in [((0, 0), r, amax), ((-r * 0.7, -r * 0.5), r * 0.72, amax * 0.8),
                        ((-r * 1.3 * drift[0], -r * 0.9 * drift[1]), r * 0.5, amax * 0.6)]:
        cy, cx = W / 2.0 + off[1], W / 2.0 + off[0]
        yy, xx = np.mgrid[0:W, 0:W].astype(float)
        d2 = ((xx - cx) / rr) ** 2 + ((yy - cy) / rr) ** 2
        g = np.exp(-d2 * 1.4)
        img[:, :, 3] = np.maximum(img[:, :, 3], g * aa)
        wt = (g * aa)[..., None] / 255.0
        img[:, :, :3] = img[:, :, :3] * (1 - wt * 0.5) + np.array([205., 205., 208.]) * wt * 0.5
    img[:, :, 3] = np.clip(img[:, :, 3], 0, amax)
    return Image.fromarray(img.astype(np.uint8))


def phase_synth():
    """rolls 攻击条合成：idle 基帧 a0 为唯一车体源（身份零漂移），
    程序 FX 贴炮塔枪口 (212,289)：待机→点射→硝烟→再点射→烟散→待机。"""
    idl = Image.open(os.path.join(OUT, "ww1_arm_rolls_idle_sheet_512.png")).convert("RGBA")
    a0 = np.asarray(idl.crop((0, 0, 512, 512))).astype(np.int16)
    TIP = (204, 292)
    flash = synth_flash(r=26)
    fsz = flash.size

    def frame(fx=None, smoke=None, recoil=0):
        base = np.roll(a0, recoil, axis=1).copy()
        fr = Image.fromarray(base.astype(np.uint8))
        if fx is not None:
            fr.alpha_composite(flash, (TIP[0] - fsz[0] // 2, TIP[1] - fsz[1] // 2))
        if smoke is not None:
            fr.alpha_composite(smoke, (TIP[0] - smoke.width + 14, TIP[1] - smoke.height // 2))
        return fr

    frames = [frame(),
              frame(fx=True, recoil=2),                    # 首点射+后坐
              frame(smoke=synth_smoke(20, amax=215)),      # 枪口硝烟小团
              frame(fx=True, recoil=2),                    # 再点射
              frame(smoke=synth_smoke(30, amax=160)),      # 烟散大团更淡
              frame()]
    atk = Image.new("RGBA", (512 * 6, 512), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        atk.paste(f, (i * 512, 0))
    atk.save(os.path.join(OUT, "ww1_arm_rolls_attack_sheet_512s.png"))
    print("  [synth] rolls 6 帧 FX 合成 → attack_sheet_512s.png", flush=True)
    # 预览
    g = Image.new("RGB", (6 * 136 + 8, 144), (24, 24, 28))
    for i, f in enumerate(frames):
        t = f.resize((128, 128), Image.LANCZOS)
        bg = Image.new("RGBA", (128, 128), (24, 24, 28, 255))
        bg.alpha_composite(t)
        g.paste(bg.convert("RGB"), (8 + i * 136, 8))
    g.save(os.path.join(STG, "ww1_arm_rolls_synth_preview.png"))
    # 77mm attack 归一化（finish3 范式：bbox 统一身高+底缘锚定）
    sh = Image.open(os.path.join(STG, "ww1_arty_77mm_MK10_attack_sheet_832.png")).convert("RGBA")
    cw = sh.width // 3
    cells = [sh.crop(((i % 3) * cw, (i // 3) * cw, (i % 3 + 1) * cw, (i // 3 + 1) * cw))
             for i in range(6)]
    FS, mb, ms = 512, 16, 24
    # 统一比例+地线/轮心对位：fg=al>150（烟半透明不入）→ 地线 y_bot、轮带质心 xc；
    # 全格同 sc（最宽 fg 域定），杜绝逐格缩放 pumping；火光出画少许可接受。
    infos = []   # (x0, x1, y_bot, xc, y_top)
    for c in cells:
        fg = np.asarray(c)[:, :, 3] > 150
        ys, xs = np.where(fg)
        y_bot, y_top = int(ys.max()), int(ys.min())
        band = fg[max(0, y_bot - 50):y_bot + 1]
        bx = np.where(band)[1]
        xc_raw = float(np.median(bx))
        if abs(xc_raw - (xs.max() - 215)) > 60:   # 烟帧轮带被拖偏→用干净格锚定偏移 x1-215
            xc_raw = float(xs.max() - 215)
        infos.append((int(xs.min()), int(xs.max()) + 1, y_bot, xc_raw, y_top))
    wmax = max(i[1] - i[0] for i in infos)
    hmax = max(i[2] - i[4] for i in infos)
    sc = min((FS - ms * 2) / wmax, (FS - mb * 2) / hmax, 4.0)
    nfs = []
    for c, (x0, x1, y_bot, xc, _yt) in zip(cells, infos):
        big = c.resize((max(1, int(c.width * sc)), max(1, int(c.height * sc))), Image.LANCZOS)
        fr = Image.new("RGBA", (FS, FS), (0, 0, 0, 0))
        px = int(FS / 2 - xc * sc)          # 轮带质心对 FS/2
        py = FS - mb - int((y_bot + 1) * sc)  # 地线对 FS-mb
        fr.paste(big, (px, py), big)          # paste 支持负坐标（烟/火光可出画）
        nfs.append(fr)
        print("  [norm77] fg x:%d-%d 地线=%d 轮心=%.0f sc=%.3f" % (x0, x1, y_bot, xc, sc),
              flush=True)
    atk2 = Image.new("RGBA", (FS * 6, FS), (0, 0, 0, 0))
    for i, f in enumerate(nfs):
        atk2.paste(f, (i * FS, 0))
    atk2.save(os.path.join(OUT, "ww1_arty_77mm_attack_sheet_512n.png"))
    g2 = Image.new("RGB", (6 * 136 + 8, 144), (24, 24, 28))
    for i, f in enumerate(nfs):
        t = f.resize((128, 128), Image.LANCZOS)
        bg = Image.new("RGBA", (128, 128), (24, 24, 28, 255))
        bg.alpha_composite(t)
        g2.paste(bg.convert("RGB"), (8 + i * 136, 8))
    g2.save(os.path.join(STG, "ww1_arty_77mm_norm_preview.png"))
    print("  [synth] 77mm 归一化 → attack_sheet_512n.png", flush=True)


def phase_deploy():
    # idle ×2
    for key in ("ww1_arm_rolls", "ww1_arty_77mm"):
        mk8.deploy_sheet(os.path.join(OUT, "%s_idle_sheet_512.png" % key), key, "idle")
    # 77mm attack 成品（归一化 512 条，已全朝左）
    mk8.deploy_sheet(os.path.join(OUT, "ww1_arty_77mm_attack_sheet_512n.png"),
                     "ww1_arty_77mm", "attack")
    # rolls attack：程序 FX 合成条（与 idle 同源车体）
    mk8.deploy_sheet(os.path.join(OUT, "ww1_arm_rolls_attack_sheet_512s.png"),
                     "ww1_arm_rolls", "attack")
    print("deploy 完成。下一步: foot_frac + --import", flush=True)


def main():
    ph = sys.argv[1] if len(sys.argv) > 1 else "scrub"
    {"scrub": phase_scrub, "rerolls": phase_rerolls, "synth": phase_synth,
     "deploy": phase_deploy}[ph]()


if __name__ == "__main__":
    main()
