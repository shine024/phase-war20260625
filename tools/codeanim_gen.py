# -*- coding: utf-8 -*-
"""codeanim 代码驱动动画批量生成器（独立路线，工作流见 docs/codeanim_工作流_20261001.md）

    python tools/codeanim_gen.py <key> | --all

锚定帧 = img25_approved/<key>_anchor_raw.png（阶段0 共享，目检过）。
产物只落 .godot/unit_review/codeanim/：
    <key>_codeanim_layers.png / _codeanim_sheet.png / _codeanim_anim.gif

三模式：
    cutout3  车身/炮管带/炮塔 三层（炮管后坐从炮塔层下缩进）
    cutout2  车身/炮塔 两层（多管火箭类，管束=炮塔本体）
    vfx      整身单层 + 焰/烟（飞行器/能量武器/剪影类；肢体不动是前提）
三条铁律：不读时钟、固定种子、不联网；--all 末尾逐单位 md5 复跑校验。
"""
import argparse
import hashlib
import json
import math
import os
import random
import sys

from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from img25_attack_gen import detect_bg_color, chroma_key, depink

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, ".godot", "unit_review", "img25_approved")
STAGING = os.path.join(ROOT, ".godot", "unit_review", "img25_staging")
OUT = os.path.join(ROOT, ".godot", "unit_review", "codeanim")
SEED = 20260930
COLS, ROWS, CELL, GIF_CELL, FPS = 5, 2, 512, 256, 12
RECOIL_BARREL, RECOIL_TURRET, HULL_BOB, FLASH_FRAME, FLASH_LIFE, SMOKE_N = 14, 4, 3, 1, 3, 6

# ---- 10 个最难单位配置（1024 坐标；切割带/炮口 = 09-30 目检 + 行剖面探针）----
UNITS = {
    "vis_xeno_tripod": dict(mode="cutout3", split_y=540, barrel=(438, 502, 400),
                            muzzle=(176, 470), cat="ground"),
    "fut_assault_mech": dict(mode="cutout3", split_y=430, barrel=(360, 428, 450),
                             muzzle=(190, 394), cat="ground"),
    "fut_arm_omega": dict(mode="cutout3", split_y=345, barrel=(270, 336, 460),
                          muzzle=(246, 278), cat="ground"),  # muzzle 10-01 校正到肩炮炮口面中心
    "platform_cold_carrier": dict(mode="cutout3", split_y=478, barrel=(432, 468, 415),
                                  muzzle=(262, 450), cat="ground"),
    "guardian_cold_thunder": dict(mode="cutout2", split_y=592, barrel=None,
                                  muzzle=(138, 375), cat="ground", flash_scale=1.4,
                                  flash_angle=-11),  # 管束实测仰角 11°，muzzle 校到管束前面中心
    "guardian_future_omega": dict(mode="vfx", muzzle=(738, 606), facing=-1, cat="ground",
                                  flash_color=(70, 170, 255), recoil=3, smoke_n=2, bob=0,
                                  flash_angle=30),  # 炮管实测俯角 30°，火光顺管轴（右下）
    "drop_phase_lance": dict(mode="vfx", muzzle=(120, 288), cat="ground",
                             flash_color=(110, 225, 255), flash_scale=0.8,
                             recoil=1, smoke_n=0, bob=0, flash_angle=-29),  # 枪刃实测仰角 29°
    "fut_space_fighter": dict(mode="vfx", muzzle=(88, 518), cat="air",
                              flash_scale=0.9, recoil=4, smoke_n=3, bob=0),
    "fut_nano_drone": dict(mode="vfx", muzzle=(203, 500), cat="air",
                           flash_scale=0.8, recoil=3, smoke_n=3, bob=0),
    "fut_howitzer": dict(mode="vfx", muzzle=(455, 330), cat="ground",
                         flash_scale=1.2, flash_angle=-40, recoil=0, smoke_n=2),
}

# ---- 批 2（2026-10-01 docs/111.txt 点名，路线扩权批）----
# 扩权一：辅助/非弹道开火可视化（用户拍板"路线扩权听你的"）——
#   tesla=电弧+相位波纹 / laser=光束 / bomb=连续投弹 / rocket=火箭弹丸+后喷 / burst=点射+抛壳
# 扩权二：cutoutR 抬枪旋转切层（顶层武器带旋转，底图修补，真举枪预动作）
# 武器定义查证 unified_card_table.gd：brem1=机枪 / ps9=相位中继(relay) / B-52=地毯轰炸舱 /
#   stealth=轨道炮·激光 / hummer=M4卡宾枪 / stryker=105mm线膛床 / mig21=空空导弹·23mm航炮
UNITS.update({
    # staging 锚定帧（approved 未转正，111.txt 点名掷次）
    "fut_sup_ps9": dict(mode="tesla", muzzle=(528, 450), cat="ground", src="staging",
                        spans=[((392, 262), (505, 256)), ((540, 258), (658, 280))],
                        flash_color=(110, 225, 255), recoil=0, smoke_n=0, bob=0),
    "mod_hummer_m2": dict(mode="burst", muzzle=(307, 292), cat="ground", src="staging",
                          flash_angle=-2, flash_scale=0.6, recoil=1, smoke_n=2, bob=0),
    # approved 锚定帧
    "cold_ak47": dict(mode="cutoutR", muzzle=(196, 362), cat="ground",
                      pivot=(470, 400), band=(192, 330, 512, 465),
                      gun_boxes=[(194, 336, 320, 372),   # 枪管+准星
                                 (320, 330, 512, 380),   # 护木+机匣+枪托尾
                                 (418, 374, 522, 462)],  # 握把+手套+弹匣
                      raise_deg=-20, aim_angle=-18, flash_frame=3,
                      flash_scale=0.55, recoil=8, smoke_n=3, smoke_max=4.9),
    "cold_rpg": dict(mode="rocket", muzzle=(128, 437), cat="ground",
                     flash_angle=0, vent=(878, 437), recoil=2, smoke_n=0, bob=0),
    "cold_mig21": dict(mode="vfx", muzzle=(88, 556), cat="air", flash_angle=0,
                       flash_scale=0.8, recoil=2, smoke_n=2, bob=0),
    "cold_arty_brem1": dict(mode="burst", muzzle=(264, 469), cat="ground",
                            flash_angle=-2, flash_scale=0.5, recoil=0, smoke_n=1, bob=0),
    "mod_stryker_mgs": dict(mode="cutout3", split_y=432, barrel=(378, 418, 360),
                            muzzle=(172, 396), cat="ground",
                            flash_scale=1.3, flash_angle=-2, smoke_n=5),
    "mod_air_bomber": dict(mode="bomb", muzzle=(505, 612), cat="air", recoil=0, smoke_n=0, bob=0,
                           bomb_scale=1.9),  # 256 实机首测弹体近隐形，放大保攻击可读（10-01）
    # 豁免户补攻击帧（10-02 用户令：没攻击帧的单位生成攻击帧）：补给车车尾吊放补给箱。
    # 锚=现役 idle f0 品红底 1024 放大（自带 4px 描边，部署端 outline=False 免二次烘焙）；
    # muzzle=货台尾挡板顶角（_gmc_anchor_probe.png 实测）；无火光（bomb 族默认），
    # 朝左车 drift 向后=箱落车尾 ✓ 补给车动作语（attack-anim-pose-rule：动作要有想像力）
    "ww2_sup_gmc_truck": dict(mode="bomb", muzzle=(965, 575), cat="ground", src="staging",
                              crate=True, bomb_scale=2.4, recoil=0, smoke_n=0, bob=2,
                              outline=False),
    "fut_stealth_bomber": dict(mode="laser", muzzle=(95, 554), cat="air", flash_angle=0,
                               flash_color=(140, 235, 255),
                               beam_lens={1: 300, 2: 700, 3: 700, 4: 450},
                               recoil=2, smoke_n=0, bob=0),
    "fut_assault_mech": UNITS["fut_assault_mech"],  # 111.txt 复点，批1已入库
})

# cutoutR 抬枪时间表（帧号->抬起角度占比，负=PIL CCW... 实测 rotate(负角)=枪口上抬）
RAISE_TL = {0: 0.0, 1: 0.5, 2: 1.0, 3: 1.0, 4: 1.0, 5: 0.7, 6: 0.4, 7: 0.15, 8: 0.0, 9: 0.0}
# burst 点射节奏（帧号->焰强度）
BURST_TL = {1: 1.0, 2: 0.45, 3: 0.85, 5: 0.5, 6: 0.35}
ROT_TL = {0: 0.0, 1: 7.0, 2: 14.0, 3: 21.0, 4: 26.0, 5: 21.0, 6: 14.0, 7: 7.0,
          8: 0.0, 9: 0.0}  # 雷达摆扫（°），f9==f0 闭环

# 火光贴图库（img25_vfx_harvest 收割的生图焰心，_index.json 带质心）
_TEX_CACHE = {}


def load_tex(name):
    """返回 (RGBA 贴图, 焰心质心)。质心优先取 _index.json 实测，缺省几何中心。"""
    if name not in _TEX_CACHE:
        p = name if os.path.isabs(name) else os.path.join(
            ROOT, ".godot", "unit_review", "img25_vfx", name)
        tex = Image.open(p).convert("RGBA")
        cent = (tex.width / 2.0, tex.height / 2.0)
        try:
            idx = json.load(open(os.path.join(ROOT, ".godot", "unit_review",
                                              "img25_vfx", "_index.json"),
                                 encoding="utf-8"))
            for e in idx:
                if e.get("png") == os.path.basename(name) and e.get("centroid_in_tex"):
                    cent = (float(e["centroid_in_tex"][0]), float(e["centroid_in_tex"][1]))
                    break
        except Exception:
            pass
        _TEX_CACHE[name] = (tex, cent)
    return _TEX_CACHE[name]


def _pink_scrub(a, cfg):
    """接地面品红渍块清除（原地）：底区粉族签 alpha 清零。s 对等比缩放不变、
    r-g/b-g 随缩放增减 → gain>1 会把原不过线的深渍块推过阈值（10-02 stryker/
    carrier 实测），故 gain 前后各跑一遍。返回 a。"""
    import numpy as np
    rgb = a[..., :3].astype(int)
    ys, xs = np.where(a[..., 3] > 16)
    z0 = ys.min() + int((ys.max() - ys.min()) * (cfg or {}).get("scrub_zone", 0.82))  # 本体 bbox 底段
    rr, gg, bb = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    mx = rgb.max(axis=2)
    s = (mx - rgb.min(axis=2)) / np.maximum(mx, 1)
    m = (rr > gg + 40) & (bb > gg + 10) & (s > 0.5) & (mx > 70)
    if (cfg or {}).get("scrub_soft"):  # 低饱和紫渍二档（10-02 vickers 族脚架渍实测 s≈0.46-0.49
        m |= (rr > gg + 16) & (bb > gg + 5) & (s > 0.35) & (mx > 38)  # 不过 s>0.5 主线）
    m[:z0] = False
    a[:, :, 3][m & (a[:, :, 3] > 0)] = 0
    return a


def load_anchor(key, cfg=None):
    src = (cfg or {}).get("src")
    src_dir = STAGING if src == "staging" else (src if src else SRC)  # src 可为目录直指
    im = Image.open(os.path.join(src_dir, "%s_anchor_raw.png" % key))
    bg = detect_bg_color(im)
    rgba = chroma_key(im, bg)
    # 封闭粉区补刀（必须在 depink 之前：depink 会把亮粉转灰，转灰后按背景距离抓不到，
    # 09-30 lance 腿间灰块实测）——近背景玫红不问连通全删；近白不在此删（防误删白色高光）。
    # scrub_radius（10-01 lance r2 锚定实测四档对比 _probe_lance_radius.png）：暗品红背景
    # (193,73,128) 与皮肤阴影色距仅 102-143，默认 100 会吃出脸洞/切离大衣阴影岛；40-55 档本体完好。
    # 默认 100=旧行为（冻结单位 md5 不变）。
    import numpy as np
    a = np.asarray(rgba).copy()
    dist = np.sqrt(((a[:, :, :3].astype(int) - bg) ** 2).sum(axis=2))
    a[:, :, 3][dist < (cfg or {}).get("scrub_radius", 100)] = 0
    rgba = Image.fromarray(a)
    rgba = depink(rgba)
    if (cfg or {}).get("pink_scrub"):  # 接地面暗品红阴影残留（10-01 bradley/rpk/坦克族实测）
        rgba = Image.fromarray(_pink_scrub(np.asarray(rgba).copy(), cfg))
    # 品红族硬清 + 透明区 RGB 邻色回填（10-02 v4 换装批实测）：
    # 键控/scrub 只清 alpha，透明像素 RGB 仍是品红；后续 normalize_frames 的 LANCZOS
    # 缩放 / cutoutR 旋转按未预乘 alpha 混合，把透明品红 RGB 渗回不透明边缘
    # （35 单位 0.1-0.4% 残留）。dist<60 硬清安全：本体最近色距背景 >=102
    # （10-01 lance 皮肤阴影实测 102-143）。回填后重采样混合的是本体邻色，零渗色。
    a = np.asarray(rgba).copy()
    dist = np.sqrt(((a[:, :, :3].astype(int) - bg) ** 2).sum(axis=2))
    a[:, :, 3][dist < 60] = 0
    if (a[:, :, 3] == 0).any() and (a[:, :, 3] > 0).any():
        from scipy import ndimage as _ndi
        _, (_iy, _ix) = _ndi.distance_transform_edt(a[:, :, 3] == 0, return_indices=True)
        a[..., :3] = a[_iy, _ix, :3]
    g = (cfg or {}).get("gain")
    if g and g != 1.0:  # 本体亮度对齐卡图（10-02 换装批 26 暗 3 亮实测 _luma_gain.json）
        a[..., :3] = np.clip(a[..., :3].astype(np.float32) * g, 0, 255).astype(np.uint8)
        if (cfg or {}).get("pink_scrub"):  # gain 后补刀：深渍块被放大才过签名线（见 _pink_scrub docstring）
            a = _pink_scrub(a, cfg)
    if (cfg or {}).get("flip"):  # clean1st 重掷枪朝右族 → 翻成 sheet 契约朝左
        # （unit_frame_anim.gd：敌方原图朝左直接用，我方 flip_h 镜像；muzzle x 须同步 1023-x）
        rgba = Image.fromarray(a).transpose(Image.FLIP_LEFT_RIGHT)
        return rgba
    return Image.fromarray(a)


def barrel_axis(cfg):
    """炮管前向单位向量（火光/烟/后坐共用的管轴方向）。
    flash_angle 为 PIL rotate 角（负=顺时针=上仰）：0=水平前向；-40 左上（howitzer）；
    +30 配 facing=-1 镜像后即右下（omega 俯角）。实测量角见 _probe_*.png。"""
    a = math.radians(-cfg.get("flash_angle", 0.0))
    ax, ay = -math.cos(a), -math.sin(a)
    return (ax, ay) if cfg.get("facing", 1) > 0 else (-ax, ay)


def frame_pose(f, cfg):
    """时间表纯函数：帧号 -> (炮管dx, 炮塔dx, 车身bob, 焰强度)。指数回落，f9 归零闭环。"""
    ff = cfg.get("flash_frame", FLASH_FRAME)
    t = f - ff
    if t < 0:
        return 0, 0, 0, 0.0
    decay = pow(0.55, t)
    bob_peak = cfg.get("bob", HULL_BOB)
    bob = int(bob_peak * decay) if t <= 3 else 0
    flash = max(0.0, 1.0 - t / FLASH_LIFE) if t < FLASH_LIFE else 0.0
    return RECOIL_BARREL * decay, RECOIL_TURRET * decay, bob, flash


def draw_flash(scale, rng, color, angle=0.0):
    """炮口焰：多角星 + 前向锥形瓣（-x 前向，facing 在合成时翻转），白芯->亮芯->色缘。"""
    if scale <= 0:
        return None
    S = 110 * scale
    layer = Image.new("RGBA", (int(S * 4), int(S * 4)), (0, 0, 0, 0))
    cx = cy = layer.width // 2
    d = ImageDraw.Draw(layer)
    r0, g0, b0 = color
    mid = (min(255, r0 + 90), min(255, g0 + 60), min(255, b0 + 40))
    n = 9
    for radius, width, col in ((1.0, 0.42, color + (215,)), (0.72, 0.34, mid + (235,)),
                               (0.42, 0.30, (255, 255, 255, 255))):
        R, r = S * radius, S * radius * width
        pts = []
        for i in range(n * 2):
            ang = math.pi * i / n + rng.uniform(-0.09, 0.09)
            rad = r if i % 2 else R * rng.uniform(0.72, 1.25)
            pts.append((cx - rad * math.cos(ang), cy + rad * math.sin(ang)))
        d.polygon(pts, fill=col)
    d.ellipse((cx - S * 1.5, cy - S * 0.30, cx + S * 0.5, cy + S * 0.30), fill=mid + (190,))
    d.ellipse((cx - S * 0.55, cy - S * 0.34, cx + S * 0.55, cy + S * 0.34), fill=(255, 255, 255, 255))
    if angle:
        layer = layer.rotate(angle, resample=Image.BICUBIC, expand=False)
    layer.alpha_composite(layer.filter(ImageFilter.GaussianBlur(S * 0.09)))
    return layer


def draw_lightning(layer, p0, p1, rng, color, width=3, branches=1):
    """中点位移折线电弧：白芯+色辉两遍描；可分叉。确定性（rng 按帧序消耗）。"""
    def bolt(a, b, disp):
        pts = [a, b]
        for _ in range(5):
            nxt = [pts[0]]
            for i in range(len(pts) - 1):
                ax, ay = pts[i]
                bx, by = pts[i + 1]
                mx, my = (ax + bx) / 2, (ay + by) / 2
                dx, dy = bx - ax, by - ay
                L = math.hypot(dx, dy) or 1
                off = rng.uniform(-disp, disp)
                nxt.append((mx - dy / L * off, my + dx / L * off))
                nxt.append((bx, by))
            pts = nxt
            disp *= 0.55
        return pts
    def stroke(pts, w, col):
        d = ImageDraw.Draw(layer)
        d.line(pts, fill=col, width=w, joint="curve")
    seg = bolt(p0, p1, math.hypot(p1[0] - p0[0], p1[1] - p0[1]) * 0.22)
    stroke(seg, width * 3 + 2, color + (70,))
    stroke(seg, width, color + (235,))
    stroke(seg, max(1, width // 2), (255, 255, 255, 255))
    for _ in range(branches):
        i = rng.randrange(len(seg) // 4, len(seg) * 3 // 4)
        ex = seg[i][0] + rng.uniform(-70, 70)
        ey = seg[i][1] + rng.uniform(30, 110)
        bseg = bolt(seg[i], (ex, ey), 26)
        stroke(bseg, max(1, width - 1), color + (190,))


def draw_beam(layer, p0, direction, length, width, color, head_alpha=1.0):
    """能量光束：远端渐隐（防 bbox 外硬切），白芯+色辉+外辉三层。"""
    ax, ay = direction
    x1, y1 = p0[0] + ax * length, p0[1] + ay * length
    beam = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(beam)
    steps = 24
    for i in range(steps):
        t0, t1 = i / steps, (i + 1) / steps
        fade = (1.0 - t1) if head_alpha < 1.0 else 1.0
        a = int(255 * fade)
        if a <= 0:
            continue
        sx = p0[0] + ax * length * t0
        sy = p0[1] + ay * length * t0
        ex = p0[0] + ax * length * t1
        ey = p0[1] + ay * length * t1
        d.line((sx, sy, ex, ey), fill=color + (int(70 * fade),), width=width * 4)
        d.line((sx, sy, ex, ey), fill=color + (a,), width=width)
        d.line((sx, sy, ex, ey), fill=(255, 255, 255, a), width=max(1, width // 2))
    glow = beam.filter(ImageFilter.GaussianBlur(width * 1.2))
    layer.alpha_composite(glow)
    layer.alpha_composite(beam)


def draw_ring(layer, center, radius, color, width=4, alpha=200):
    """相位波纹：扩散圆环（电波/辐射波）。"""
    if radius <= 1 or alpha <= 0:
        return
    ring = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(ring)
    x, y = center
    d.ellipse((x - radius, y - radius * 0.55, x + radius, y + radius * 0.55),
              outline=color + (alpha,), width=width)
    glow = ring.filter(ImageFilter.GaussianBlur(width))
    layer.alpha_composite(glow)
    layer.alpha_composite(ring)


def draw_bomb(layer, x, y, rng, scale=1.0, ang=None):
    """航弹：深橄榄弹体+尾翼（弹头朝左画）；ang=弹体朝向（CCW 度，None=仅微摆）。"""
    w, h = int(26 * scale), int(9 * scale)
    bomb = Image.new("RGBA", (w * 3, h * 4), (0, 0, 0, 0))
    d = ImageDraw.Draw(bomb)
    cx, cy = bomb.width // 2, bomb.height // 2
    if ang is None:
        ang = 0
    ang += rng.uniform(-3, 3)
    d.ellipse((cx - w // 2, cy - h // 2, cx + w // 2, cy + h // 2), fill=(58, 62, 44, 255))
    d.polygon(((cx + w // 2, cy), (cx + w // 2 + h, cy - h // 2 - 1),
               (cx + w // 2 + h, cy + h // 2 + 1)), fill=(48, 52, 38, 255))
    d.ellipse((cx - w // 2, cy - h // 2, cx - w // 2 + h * 0.8, cy + h // 2),
              fill=(70, 74, 54, 255))
    bomb = bomb.rotate(ang, resample=Image.BICUBIC)
    layer.alpha_composite(bomb, (int(x - cx), int(y - cy)))


def draw_crate(layer, x, y, rng, scale=1.0, ang=None):
    """补给箱：橄榄木箱+板条线（10-02 gmc 补给车吊放用）；ang=慢速翻滚（弱于弹体）。"""
    s = int(30 * scale)
    box = Image.new("RGBA", (s * 3, s * 3), (0, 0, 0, 0))
    d = ImageDraw.Draw(box)
    cx, cy = box.width // 2, box.height // 2
    if ang is None:
        ang = 0
    ang = ang * 0.3 + rng.uniform(-6, 6)  # 箱子不弹头朝前，慢翻滚
    x0, y0, x1, y1 = cx - s // 2, cy - s // 2, cx + s // 2, cy + s // 2
    d.rectangle((x0, y0, x1, y1), fill=(96, 88, 58, 255))
    d.rectangle((x0, y0, x1, y1), outline=(58, 52, 34, 255), width=max(2, s // 16))
    d.line((x0, (y0 + y1) // 2, x1, (y0 + y1) // 2), fill=(118, 108, 72, 255),
           width=max(2, s // 18))
    d.line(((x0 + s // 4), y0, (x0 + s // 4), y1), fill=(78, 70, 46, 255),
           width=max(2, s // 20))
    d.line(((x1 - s // 4), y0, (x1 - s // 4), y1), fill=(78, 70, 46, 255),
           width=max(2, s // 20))
    box = box.rotate(ang, resample=Image.BICUBIC)
    layer.alpha_composite(box, (int(x - cx), int(y - cy)))


def draw_rocket_proj(layer, x, y, angle, rng, alpha=255):
    """火箭弹：小弹体+尾焰（后向）。angle=前进方向角（度，屏幕系）。"""
    L = 26
    rk = Image.new("RGBA", (L * 3, L * 3), (0, 0, 0, 0))
    d = ImageDraw.Draw(rk)
    cx = cy = rk.width // 2
    d.line((cx - 8, cy, cx + 8, cy), fill=(40, 42, 46, alpha), width=5)
    d.polygon(((cx + 8, cy - 3), (cx + 15, cy), (cx + 8, cy + 3)), fill=(52, 54, 58, alpha))
    d.line((cx - 12, cy, cx - 8, cy), fill=(255, 190, 80, alpha), width=6)
    d.line((cx - 20, cy, cx - 12, cy), fill=(255, 240, 180, alpha), width=3)
    rk = rk.rotate(-angle, resample=Image.BICUBIC)
    layer.alpha_composite(rk, (int(x - cx), int(y - cy)))


def draw_casings(layer, x, y, f, rng, facing):
    """抛壳：黄铜小点，右上抛物线（相对枪口），2 帧生命。"""
    for k in (0, 1):
        ft = f - (1 + k)
        if ft < 0 or ft > 2:
            continue
        jx = rng.uniform(-8, 8)
        cx_ = x + facing * (18 + ft * 26 + jx)
        cy_ = y - 14 + ft * ft * 18 - ft * 10
        c = ImageDraw.Draw(layer)
        c.ellipse((cx_ - 3, cy_ - 2, cx_ + 3, cy_ + 2), fill=(198, 160, 70, 230))


def prep_cutoutr(rgba, cfg):
    """抬枪切层：gun_boxes 并集内按枪色距抠步枪层，底图竖向邻域修补。
    色值种子实测于当前锚定（10-01 重掷版：平持腰际，木 (95,50,25)，枪身 (30,30,29)）；
    大衣卡其调 r>=g，纯色规则必吞衣摆 → 盒外一概不算枪（gun_boxes 空间约束）。"""
    import numpy as np
    x0, y0, x1, y1 = cfg["band"]
    a = np.asarray(rgba).copy()
    band = a[y0:y1, x0:x1]
    rgb = band[:, :, :3].astype(int)
    d_gun = np.sqrt(((rgb - (30, 30, 29)) ** 2).sum(axis=2))
    d_wood = np.sqrt(((rgb - (95, 50, 25)) ** 2).sum(axis=2))
    maxmin = rgb.max(axis=2) - rgb.min(axis=2)
    neutral = (d_gun < 55) & (maxmin < 14)
    brown = (d_wood < 50) & ((rgb[:, :, 0] - rgb[:, :, 1]) > 20)
    mask0 = (neutral | brown) & (band[:, :, 3] > 128)
    boxes = cfg.get("gun_boxes")
    if boxes:
        spatial = np.zeros(mask0.shape, bool)
        for (bx0, by0, bx1, by1) in boxes:
            spatial[max(0, by0 - y0):by1 - y0, max(0, bx0 - x0):bx1 - x0] = True
        mask0 &= spatial
    # 枪轮廓过渡带并入枪层：无条件 2px 膨胀（AA/粉边任何颜色随枪走，实机不可见），
    # 玫红 fringe 门再扩到 5px 兜底——否则抬枪后底图原位留轮廓残影（10-01 首跑实测）
    r_, g_, b_ = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]
    fringe = (r_ > g_ + 8) & (r_ > b_ + 8) & (band[:, :, 3] > 0)

    def _dil(m, n):
        for _ in range(n):
            g_ = np.zeros_like(m)
            g_[1:, :] |= m[:-1, :]
            g_[:-1, :] |= m[1:, :]
            g_[:, 1:] |= m[:, :-1]
            g_[:, :-1] |= m[:, 1:]
            m = g_
        return m

    mask = _dil(mask0, 2) | (fringe & _dil(mask0, 5))
    # 底图修补：竖向最近未遮挡像素插值；上下界任一为空气（alpha<=128）时
    # 不许向空气拉丝（键控透明像素保留原粉 RGB，lerp 会拉出粉纹竖条）——
    # 双空气填全透明、单侧实体向空气淡出、双实体插值（10-01 首跑实测立规）
    clean = band.copy()
    h, w = mask.shape
    AIR = 128
    for x in range(w):
        col = mask[:, x]
        if not col.any():
            continue
        ys = np.where(col)[0]
        runs = np.split(ys, np.where(np.diff(ys) != 1)[0] + 1)
        for run in runs:
            top, bot = run[0] - 1, run[-1] + 1
            ca = band[top, x].astype(float) if top >= 0 else None
            cb = band[bot, x].astype(float) if bot < h else None
            ok_a = ca is not None and ca[3] > AIR
            ok_b = cb is not None and cb[3] > AIR
            n = len(run)
            for i, yy in enumerate(run):
                t = (i + 1) / (n + 1)
                if ok_a and ok_b:
                    clean[yy, x] = (ca * (1 - t) + cb * t).astype(np.uint8)
                elif ok_a:
                    px_ = ca.copy()
                    px_[3] = ca[3] * (1 - t)
                    clean[yy, x] = px_.astype(np.uint8)
                elif ok_b:
                    px_ = cb.copy()
                    px_[3] = cb[3] * t
                    clean[yy, x] = px_.astype(np.uint8)
                else:
                    clean[yy, x] = (0, 0, 0, 0)
    a[y0:y1, x0:x1] = clean
    base_clean = Image.fromarray(a)
    rifle = rgba.copy()
    ra = np.asarray(rifle).copy()
    m = np.zeros(ra.shape[:2], bool)
    m[y0:y1, x0:x1] = mask
    ra[:, :, 3][~m] = 0
    rifle_l = Image.fromarray(ra)
    # 抬枪后炮口位置：绕 pivot 转 raise_deg（视觉顺时针；PIL rotate 负角）
    mx, my = cfg["muzzle"]
    px, py = cfg["pivot"]
    t = math.radians(-cfg["raise_deg"])  # raise_deg=-40 -> t=+40° 顺时针矩阵
    c_, s_ = math.cos(t), math.sin(t)
    ox, oy = mx - px, my - py
    raised = (px + ox * c_ - oy * s_, py + ox * s_ + oy * c_)
    return dict(base_clean=base_clean, rifle=rifle_l, raised_muzzle=raised)


def draw_smoke(layer, puffs):
    """烟团：浅灰软圆（大模糊半径出梯度），半径随生命膨胀、alpha 衰减。"""
    for (x, y, rad, alpha) in puffs:
        s = max(8, int(rad * 5))
        puff = Image.new("RGBA", (s, s), (0, 0, 0, 0))
        d = ImageDraw.Draw(puff)
        d.ellipse((s // 4, s // 4, s - s // 4, s - s // 4), fill=(172, 174, 180, alpha))
        puff = puff.filter(ImageFilter.GaussianBlur(s // 5))
        layer.alpha_composite(puff, (int(x - s / 2), int(y - s / 2)))


def cut_layers(rgba, cfg):
    """裁剪坐标=画布绝对坐标（合成回贴不得再叠加切割偏移，09-30 翻车点）。"""
    mode, split_y, barrel = cfg["mode"], cfg["split_y"], cfg.get("barrel")
    full = rgba
    turret = full.crop((0, 0, full.width, split_y))
    barrel_l = None
    if barrel:
        y0, y1, xmax = barrel
        turret.paste((0, 0, 0, 0), (0, y0, xmax, y1))
        barrel_l = full.crop((0, y0, xmax, y1))
    hull = full.crop((0, split_y, full.width, full.height))
    return hull, barrel_l, turret, split_y


def _recoil_wdx(cfg, f):
    """后坐位移：开火帧起指数回落；开火前帧必须为 0（10-01 ak47 实测：max(0,f-ff)
    让 f0 静息帧吃满后坐 → f0/f9 闭环破 8px，与 frame_pose 的 t<0 保护对齐）。"""
    t = f - cfg.get("flash_frame", FLASH_FRAME)
    if t < 0:
        return 0
    return int(cfg.get("recoil", 0) * pow(0.55, t))


def compose_frame(rgba, cfg, f, rng, ctx=None):
    facing = cfg.get("facing", 1)
    mode = cfg["mode"]
    bdx, tdx, bob, flash_s = frame_pose(f, cfg)
    if mode == "rotate":
        flash_s, bob = 0.0, 0  # 雷达扫描无焰无震
    mx, my = cfg.get("muzzle", (512, 512))
    canvas = Image.new("RGBA", rgba.size, (0, 0, 0, 0))
    tip = (mx, my + bob)
    ax, ay = barrel_axis(cfg)

    if mode == "cutoutR":  # 抬枪：步枪层绕握把旋转，抬到位开火
        ctx = ctx or {}
        theta = cfg["raise_deg"] * RAISE_TL.get(f, 0.0)
        canvas.alpha_composite(ctx["base_clean"], (0, bob))
        rifle = ctx["rifle"].rotate(theta, center=cfg["pivot"], resample=Image.BICUBIC)
        cfg = dict(cfg, flash_angle=cfg["aim_angle"])  # 抬枪后按瞄准轴开火
        ax, ay = barrel_axis(cfg)
        wdx = _recoil_wdx(cfg, f)
        off = (int(-ax * wdx), int(-ay * wdx) + bob)
        canvas.alpha_composite(rifle, off)
        tip = ctx["raised_muzzle"]
        tip = (tip[0] + off[0], tip[1] + off[1])
    elif mode == "rotate":  # 雷达扫描：band 内容绕 pivot 摆扫，本体其余静止（f9==f0）
        canvas.alpha_composite(rgba, (0, 0))
        x0, y0, x1, y1 = cfg["band"]
        import numpy as _np
        arr = _np.asarray(canvas).copy()
        arr[y0:y1, x0:x1, 3] = 0  # 擦原位防重影，再贴旋转后内容
        canvas = Image.fromarray(arr)
        band = rgba.crop((x0, y0, x1, y1))
        amp = cfg.get("rot_amp", 1.0)  # 摆幅系数（1=26° 满幅；碟面贴塔/贴墙者调小）
        rot = band.rotate(ROT_TL.get(f, 0.0) * amp,
                          center=(cfg["pivot"][0] - x0, cfg["pivot"][1] - y0),
                          resample=Image.BICUBIC)
        canvas.alpha_composite(rot, (x0, y0))
        wave = cfg.get("wave")  # 雷达电波：馈源 born 两道外扩环（fort_radar"发波不开火"）
        if wave:
            wc = tuple(wave.get("center", cfg["pivot"]))
            th = math.radians(ROT_TL.get(f, 0.0) * amp)  # 环心随 band 同角绕 pivot（碟动环随）
            dx, dy = wc[0] - cfg["pivot"][0], wc[1] - cfg["pivot"][1]
            wc = (cfg["pivot"][0] + dx * math.cos(th) + dy * math.sin(th),
                  cfg["pivot"][1] - dx * math.sin(th) + dy * math.cos(th))
            wr0, wr1 = wave.get("r0", 18), wave.get("r1", 80)
            wcol = tuple(wave.get("color", (185, 235, 255)))
            for born in wave.get("born", (1, 3)):
                age = f - born
                if 0 <= age <= 3:
                    draw_ring(canvas, wc, wr0 + age * (wr1 - wr0) / 3.0, wcol,
                              width=4 if born == 1 else 3,
                              alpha=int(235 * (1 - age / 3.8)))
    elif mode in ("vfx", "tesla", "laser", "bomb", "rocket", "burst"):
        wdx = _recoil_wdx(cfg, f)
        canvas.alpha_composite(rgba, (int(-ax * wdx), int(-ay * wdx) + bob))  # 后坐沿管轴后退
        tip = (mx + int(-ax * wdx), my + int(-ay * wdx) + bob)
    else:
        hull, barrel_l, turret, split_y = cut_layers(rgba, cfg)
        canvas.alpha_composite(hull, (0, split_y + bob))
        if barrel_l is not None:
            y0 = cfg["barrel"][0]
            canvas.alpha_composite(barrel_l, (int(bdx) * facing, y0 + bob))
            tip = (mx + int(bdx) * facing, my + bob)
        canvas.alpha_composite(turret, (int(tdx) * facing, bob))

    color = cfg.get("flash_color", (255, 122, 26))
    # ---- 模式专属效果层 ----
    if mode == "burst":  # 点射：节奏表 + 抛壳
        flash_s = BURST_TL.get(f, 0.0)
        draw_casings(canvas, tip[0], tip[1], f, rng, facing)
    if mode == "tesla":  # 电弧频闪 + 相位波纹（电波，环径收在本体 bbox 内）
        glow = {1: 1.0, 2: 0.9, 3: 0.55, 4: 0.4, 5: 0.5, 6: 0.25}.get(f, 0.0)
        if glow > 0:
            sp = cfg.get("spans", [((392, 250), (452, 252)), ((542, 250), (626, 250))])
            for (a_, b_) in sp:
                draw_lightning(canvas, a_, b_, rng, color,
                               width=2 + int(2 * glow), branches=1 if glow > 0.5 else 0)
        rb = cfg.get("ring_r", (16, 30))  # 波纹基础半径/每龄增幅（ps9"电波大点"旋钮）
        for born in cfg.get("ring_born", (1, 3)):  # 4 帧生命；born 列表可加密度
            age = f - born
            if 0 <= age <= 3:
                draw_ring(canvas, tip, rb[0] + age * rb[1], color,
                          width=3 if born == 1 else 2,
                          alpha=int(200 * (1 - age / 3.5)))
    if mode == "laser":  # 光束：f1 展开，f2-f3 全束，f4 残辉（远端渐隐防 bbox 硬切）
        blen = cfg.get("beam_lens", {1: 420, 2: 900, 3: 900, 4: 620}).get(f, 0)
        if blen:
            draw_beam(canvas, tip, (ax, ay), blen, 5, color, head_alpha=0.0)
            if f <= 2:
                fl = draw_flash(0.7 if f == 1 else 0.45, rng, color,
                                cfg.get("flash_angle", 0.0))
                if fl:
                    off = (tip[0] - fl.width // 2, tip[1] - fl.height // 2)
                    if facing < 0:
                        fl = fl.transpose(Image.FLIP_LEFT_RIGHT)
                    canvas.alpha_composite(fl, off)
    if mode == "bomb":  # 连续投弹：f1 起逐枚释放，重力下落，出 bbox 前淡出
        import numpy as _np
        for k in range(4):
            ft = f - (1 + k * 0.8)
            if ft < 0:
                continue
            fade = max(0.0, 1.0 - max(0, ft - 2.8) / 1.0)
            if fade <= 0:
                continue
            # 弹道：屏幕系里机身随镜头锁定，弹体默认向后飘（阻力滞后）——
            # 左向机（facing=1）弹尾向右漂；bomb_forward=投弹/前射（10-01 用户令，覆盖物理纠错）
            drift = (-facing if cfg.get("bomb_forward") else facing) * ft * 22
            bx = tip[0] + drift
            by = tip[1] + 6 + ft * ft * 30
            # 弹体顺速度向（屏幕系 CCW 角，左向弹头基准）
            bang = 90 + math.degrees(math.atan2(drift, max(60 * ft, 1.0)))
            pre = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
            if cfg.get("crate"):  # 补给箱变体（10-02 gmc）：无尾翼木箱慢翻滚
                draw_crate(pre, bx, by, rng, scale=cfg.get("bomb_scale", 1.0), ang=bang)
            else:
                draw_bomb(pre, bx, by, rng, scale=cfg.get("bomb_scale", 1.0), ang=bang)
            if fade < 1.0:
                pa = _np.asarray(pre).copy()
                pa[:, :, 3] = (pa[:, :, 3] * fade).astype("uint8")
                pre = Image.fromarray(pa)
            canvas.alpha_composite(pre)
        if f == 1:  # 弹舱开启微光
            draw_ring(canvas, tip, 14, color, width=3, alpha=160)
    if mode == "rocket":  # 火箭弹丸（短程收幅）+锚定尾迹+管尾后喷
        ft = f - 1
        if ft >= 0:
            spd = 70 + ft * 45
            rx = tip[0] + ax * spd
            ry = tip[1] + ay * spd + ft * ft * 6
            fade = max(0.0, 1.0 - max(0, ft - 1.9) / 1.1)
            if fade > 0:
                draw_rocket_proj(canvas, rx, ry, math.degrees(math.atan2(
                    ay + (ft * 10.0 / max(spd, 1)), ax)), rng, alpha=int(255 * fade))
            puffs = []  # 尾迹锚定在弹道梯上，随龄消散
            for j in range(0, min(int(ft) + 1, 4)):
                d_ = 70 + j * 45
                age = ft - j
                al = int(150 * max(0.0, 1.0 - age / 2.6))
                if al > 0:
                    puffs.append((tip[0] + ax * d_, tip[1] + ay * d_ + (ft - j) ** 2 * 4,
                                  10 + age * 5, al))
            draw_smoke(canvas, puffs)
        if f == 1:  # 发射焰 + 管尾后喷
            fl = draw_flash(cfg.get("flash_scale", 1.0), rng, color,
                            cfg.get("flash_angle", 0.0))
            if fl:
                off = (tip[0] - fl.width // 2, tip[1] - fl.height // 2)
                if facing < 0:
                    fl = fl.transpose(Image.FLIP_LEFT_RIGHT)
                canvas.alpha_composite(fl, off)
            vx, vy = cfg.get("vent", (tip[0] - ax * 380, tip[1] - ay * 380))
            fl2 = draw_flash(0.8, rng, (255, 170, 60), math.degrees(math.atan2(-ay, -ax)))
            if fl2:
                fl2 = fl2.transpose(Image.FLIP_LEFT_RIGHT)
                canvas.alpha_composite(fl2, (int(vx - fl2.width * 0.28),
                                             int(vy - fl2.height // 2)))
            puffs = [(vx + 30, vy + 18, 22, 190), (vx + 90, vy + 30, 30, 150)]
            draw_smoke(canvas, puffs)
    if mode in ("vfx", "burst", "cutoutR", "cutout3", "cutout2") and flash_s > 0:
        ox, oy = cfg.get("flash_off", (0, 0))  # 焰心屏幕系偏移（机鼻贴画布左缘的空中单位防裁半）
        tex_name = cfg.get("flash_tex")  # 生图火光贴图复用（img25_vfx 库，质心对齐=贴枪口）
        tex_pair = load_tex(tex_name) if tex_name else None
        if tex_pair is not None:
            tex, cen = tex_pair
            s = cfg.get("flash_tex_scale", 1.0) * (0.7 + 0.3 * flash_s)
            tex = tex.resize((max(1, int(tex.width * s)), max(1, int(tex.height * s))),
                             Image.LANCZOS)
            cx_, cy_ = cen[0] * s, cen[1] * s
            if facing < 0:
                tex = tex.transpose(Image.FLIP_LEFT_RIGHT)
                cx_ = tex.width - cx_
            tex = tex.copy()
            a = tex.getchannel("A").point(lambda v: int(v * min(1.0, flash_s + 0.25)))
            tex.putalpha(a)
            canvas.alpha_composite(tex, (int(tip[0] - cx_ + ox), int(tip[1] - cy_ + oy)))
        else:
            fl = draw_flash(flash_s * cfg.get("flash_scale", 1.0), rng, color,
                            cfg.get("flash_angle", 0.0))
            if fl:
                off = (int(tip[0] - fl.width // 2 + ox), int(tip[1] - fl.height // 2 + oy))
                if facing < 0:  # 朝右单位：前向锥形瓣镜像到 +x
                    fl = fl.transpose(Image.FLIP_LEFT_RIGHT)
                canvas.alpha_composite(fl, off)
    t = f - cfg.get("flash_frame", FLASH_FRAME)
    smoke_n = 0 if mode == "rotate" else cfg.get("smoke_n", SMOKE_N)  # 雷达摆扫无炮烟
    if 1 <= t and smoke_n:
        puffs = []
        for i in range(smoke_n):
            max_life = cfg.get("smoke_max", 6.5) - i * 0.8
            life = t - 1 - i * 0.7
            if life < 0 or life > max_life:
                continue
            k = life / 7.0
            drift = life * life * 0.35 + life * (18 + i * 5)
            puffs.append((tip[0] + ax * (24 + drift),
                          tip[1] + ay * (24 + drift) - 10 - life * (14 + i * 3.5)
                          + rng.uniform(-6, 6),
                          13 + k * 34 + i * 2, int(125 * (1 - k))))
        draw_smoke(canvas, puffs)
    return canvas


def normalize_frames(frames, cell, align):
    """ground=联合 bbox 底缘对齐；air=垂直中心对齐（工作流 ⚠ 分派）。"""
    import numpy as np
    u = None
    for fr in frames:
        a = np.asarray(fr)[:, :, 3]
        ys, xs = np.where(a > 8)
        bb = (xs.min(), ys.min(), xs.max(), ys.max())
        u = bb if u is None else (min(u[0], bb[0]), min(u[1], bb[1]),
                                  max(u[2], bb[2]), max(u[3], bb[3]))
    out = []
    for fr in frames:
        c = fr.crop((u[0], u[1], u[2] + 1, u[3] + 1))
        sc = (cell - 16) / max(c.width, c.height)
        c = c.resize((max(1, int(c.width * sc)), max(1, int(c.height * sc))), Image.LANCZOS)
        base = Image.new("RGBA", (cell, cell), (0, 0, 0, 0))
        cy = cell - 8 - c.height if align == "bottom" else (cell - c.height) // 2
        base.alpha_composite(c, ((cell - c.width) // 2, cy))
        out.append(base)
    return out


def gen_unit(key, cfg):
    rgba = load_anchor(key, cfg)
    ctx = prep_cutoutr(rgba, cfg) if cfg["mode"] == "cutoutR" else {}
    rng = random.Random(SEED)
    frames = [compose_frame(rgba, cfg, f, rng, ctx) for f in range(COLS * ROWS)]

    import numpy as np
    layers_dbg = Image.new("RGBA", (1024, 1024), (24, 24, 28, 255))
    marks = rgba.copy()
    d = ImageDraw.Draw(marks)
    if cfg["mode"] == "cutoutR":
        x0, y0, x1, y1 = cfg["band"]
        d.rectangle((x0, y0, x1, y1), outline=(80, 200, 255, 255), width=3)
        px, py = cfg["pivot"]
        d.ellipse((px - 10, py - 10, px + 10, py + 10), outline=(0, 255, 120, 255), width=4)
        rmx, rmy = ctx["raised_muzzle"]
        d.ellipse((rmx - 12, rmy - 12, rmx + 12, rmy + 12),
                  outline=(255, 120, 255, 255), width=4)
    elif cfg["mode"] != "vfx":
        if cfg["mode"] == "rotate":
            x0, y0, x1, y1 = cfg["band"]
            d.rectangle((x0, y0, x1, y1), outline=(80, 200, 255, 255), width=3)
            px, py = cfg["pivot"]
            d.ellipse((px - 10, py - 10, px + 10, py + 10), outline=(0, 255, 120, 255), width=4)
        if cfg.get("split_y"):
            d.line((0, cfg["split_y"], 1024, cfg["split_y"]), fill=(255, 60, 60, 255), width=3)
        if cfg.get("barrel"):
            y0, y1, xmax = cfg["barrel"]
            d.rectangle((0, y0, xmax, y1), outline=(80, 200, 255, 255), width=3)
    if "muzzle" in cfg:
        d.ellipse((cfg["muzzle"][0] - 12, cfg["muzzle"][1] - 12,
                   cfg["muzzle"][0] + 12, cfg["muzzle"][1] + 12),
                  outline=(255, 255, 0, 255), width=4)
    layers_dbg.alpha_composite(marks)
    layers_dbg.convert("RGB").save(os.path.join(OUT, "%s_codeanim_layers.png" % key))

    align = "center" if cfg["cat"] == "air" else "bottom"
    cells = normalize_frames(frames, CELL, align)
    sheet = Image.new("RGBA", (CELL * COLS, CELL * ROWS), (0, 0, 0, 0))
    for i, c in enumerate(cells):
        sheet.alpha_composite(c, ((i % COLS) * CELL, (i // COLS) * CELL))
    sheet_path = os.path.join(OUT, "%s_codeanim_sheet.png" % key)
    sheet.save(sheet_path)

    gif = [Image.alpha_composite(Image.new("RGBA", c.size, (255, 255, 255, 255)), c).convert("P")
           for c in normalize_frames(frames, GIF_CELL, align)]
    gif[0].save(os.path.join(OUT, "%s_codeanim_anim.gif" % key),
                save_all=True, append_images=gif[1:], duration=int(1000 / FPS), loop=0)
    return hashlib.md5(open(sheet_path, "rb").read()).hexdigest()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("key", nargs="?")
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--configs", help="逗号分隔的配置 JSON 路径（合并进 UNITS，外部优先）")
    args = ap.parse_args()
    units = dict(UNITS)
    if args.configs:
        for p in args.configs.split(","):
            p = p.strip().strip('"')
            ext = json.load(open(p, encoding="utf-8"))
            n_add = 0
            for k, cfg in ext.items():
                cfg.pop("why", None)
                cfg.pop("confidence", None)
                cfg.pop("_override", None)
                if isinstance(cfg.get("flash_color"), list):
                    cfg["flash_color"] = tuple(cfg["flash_color"])  # JSON 数组→tuple（防 list+tuple 崩）
                if isinstance(cfg.get("beam_lens"), dict):  # JSON 键恒为字符串，帧号需 int
                    cfg["beam_lens"] = {int(k2): v for k2, v in cfg["beam_lens"].items()}
                if UNITS.get(k, {}).get("need_anchor"):
                    print("[警告] %s 标记 need_anchor（锚定帧可能缺失/需补）" % k, flush=True)
                units[k] = cfg
                n_add += 1
            print("configs: %s +%d 单位" % (p, n_add), flush=True)
    os.makedirs(OUT, exist_ok=True)
    keys = sorted(units) if args.all else [args.key]
    if not args.all and args.key not in units:
        sys.exit("未知 key（或用 --all/--configs）： %s" % args.key)
    report = []
    for key in keys:
        h1 = gen_unit(key, units[key])
        h2 = gen_unit(key, units[key])  # 铁律推论：复跑逐字节一致
        ok = "OK" if h1 == h2 else "MD5-DIFF!"
        print("%-26s %s %s" % (key, ok, h1[:8]), flush=True)
        report.append("| %s | %s | ☐LAYERS ☐SHEET ☐闭环 ☐尺寸 |" % (key, ok))
    if args.all:
        with open(os.path.join(OUT, "_batch_report.md"), "w", encoding="utf-8") as f:
            f.write("# codeanim 批生成报告\n\n| 单位 | md5 复跑 | 验收勾选 |\n|---|---|---|\n")
            f.write("\n".join(report) + "\n")


if __name__ == "__main__":
    main()
