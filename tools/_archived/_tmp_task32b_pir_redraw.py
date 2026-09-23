# -*- coding: utf-8 -*-
"""
Task 3.2 — 5 张相位仪词条小图标程序化重绘（2026-09-22）
hermes 计划 playability 批次。零游戏代码改动，只重绘 5 张 PNG（同路径同尺寸 128×128）。

风格依据：
- docs/统一化/STYLE_BIBLE.md 6.4 相位仪徽章：深空黑 #0A121F → 深灰蓝 #2B3A4A 深底径向渐变，
  霓虹发光勾线，对称纹章构图（放射刻度族元素）。
- AGENTS.md v6.17.1 教训：徽章底板必须深色径向渐变，白底徽章在任何深色 HUD 上都是白贴纸。
- 主 glyph 高饱和金 #ffcc44 / 青 #00e8ff 双色系（design_tokens COLOR_GOLD / COLOR_ACCENT_CYAN 同族）。
- 线条宽 ≥ 图标宽/16（128/16 = 8px 最终尺度；本脚本 4× 超采样下 ≥32px）。

语义锚（5 张）：
- pi_r_free_deploy      金=向下粗箭头 + 虚线底座（部署落地；与 first_deploy 的「圆圈+1」区分）
- pi_r_dmg_reflect      青=射入箭头 + 金=折返箭头 + 底部反弹线（伤害反射）
- pi_r_energy_fountain  青=喷泉（碗+立柱+三射流+水珠）（能量喷涌，原语义保持）
- pi_atk                金=交叉双剑（攻击力）
- pi_attack_speed       青=双箭头（攻速）

跑法：python tools/_tmp_task32b_pir_redraw.py
产出：5 张覆盖 assets/ui/instruments/*.png + 技术自检报告（stdout）+
      前后对比拼图 tests/evidence/playability_2026-09-22/task32b_pir_before_after.png
"""

import math
import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSET_DIR = os.path.join(ROOT, "assets", "ui", "instruments")
BACKUP_DIR = os.path.join(ROOT, ".godot", "art_backup_pir_20260922")
EVIDENCE_DIR = os.path.join(ROOT, "tests", "evidence", "playability_2026-09-22")

S = 4                 # 超采样倍数
C = 128 * S           # 工作画布 512
FINAL = 128

# ---- 色板（STYLE_BIBLE 深底 + design_tokens 强调色族） ----
PLATE_IN = (42, 57, 77)      # 深灰蓝亮端（径向渐变内圈）
PLATE_OUT = (10, 18, 31)     # 深空黑 #0A121F（径向渐变外圈）
RIM = (92, 112, 140)         # 底盘描边（深浅两底都勾出圆界）
TICK = (0, 196, 224, 96)     # 放射刻度（青，低存在感）
GOLD = (255, 204, 68, 255)
GOLD_CORE = (255, 238, 176, 255)
CYAN = (0, 232, 255, 255)
CYAN_CORE = (198, 250, 255, 255)
GOLD_DIM = (255, 204, 68, 130)
CYAN_DIM = (0, 210, 240, 150)

BG_DARK = (10, 18, 31, 255)      # 深底（HUD 深色）
BG_LIGHT = (230, 234, 240, 255)  # 浅底


# ---------------------------------------------------------------- 底盘

def make_plate():
    """深色径向渐变圆底 + 描边 + 12 放射刻度（纹章族元素）。返回 RGBA。"""
    grad = Image.radial_gradient("L").resize((C, C))  # 中心 0 → 边缘 255
    inner = Image.new("RGB", (C, C), PLATE_IN)
    outer = Image.new("RGB", (C, C), PLATE_OUT)
    plate = Image.composite(outer, inner, grad).convert("RGBA")

    # 圆形裁切（R=246/256 → 最终 61.5px 半径，四角透明）
    mask = Image.new("L", (C, C), 0)
    ImageDraw.Draw(mask).ellipse([C // 2 - 246, C // 2 - 246, C // 2 + 246, C // 2 + 246], fill=255)
    plate.putalpha(mask)

    d = ImageDraw.Draw(plate)
    # 放射刻度 12 根（aegis 族表盘刻度语言）
    for k in range(12):
        a = math.radians(k * 30.0)
        r0, r1 = 198, 222
        x0, y0 = C / 2 + r0 * math.cos(a), C / 2 + r0 * math.sin(a)
        x1, y1 = C / 2 + r1 * math.cos(a), C / 2 + r1 * math.sin(a)
        d.line([(x0, y0), (x1, y1)], fill=TICK, width=7)
    # 外圈描边：深浅两底都能读出圆界
    d.ellipse([10, 10, C - 10, C - 10], outline=RIM, width=10)
    return plate


# ---------------------------------------------------------------- glyph 绘制助手

def thick_line(d, p0, p1, w, fill):
    d.line([p0, p1], fill=fill, width=w)
    r = w / 2.0
    for (x, y) in (p0, p1):
        d.ellipse([x - r, y - r, x + r, y + r], fill=fill)


def poly(d, pts, fill, core=None, core_w=10):
    d.polygon(pts, fill=fill)
    if core is not None:
        # Pillow polygon outline 不带 width 的版本兜底：手描线环
        try:
            d.polygon(pts, outline=core, width=core_w)
        except TypeError:
            d.line(list(pts) + [pts[0]], fill=core, width=core_w, joint="curve")


def arrow_head(d, tip, back, perp_half, fill):
    """箭头三角：tip=尖端, back=底边中点, perp_half=底边半宽向量。"""
    c1 = (back[0] + perp_half[0], back[1] + perp_half[1])
    c2 = (back[0] - perp_half[0], back[1] - perp_half[1])
    d.polygon([tip, c1, c2], fill=fill)


# ---------------------------------------------------------------- 五个 glyph

def glyph_free_deploy(d, main, core):
    """向下粗箭头 + 虚线底座：部署落地（与 first_deploy「1」区分）。"""
    hw = 34
    pts = [
        (256 - hw, 84), (256 + hw, 84),
        (256 + hw, 196), (360, 196),
        (256, 324), (152, 196),
        (256 - hw, 196),
    ]
    poly(d, pts, main, core, 12)
    # 虚线底座（4 段）
    x = 104
    while x + 54 <= 408:
        d.rectangle([x, 396 - 13, x + 54, 396 + 13], fill=main)
        x += 54 + 32


def glyph_dmg_reflect(d, main_in, main_out, core_in, core_out, base_col):
    """射入箭头（青）+ 底部反弹线 + 折返箭头（金）：伤害反射。"""
    p0, p1, p2 = (158, 198), (256, 296), (354, 198)
    u = (1 / math.sqrt(2), 1 / math.sqrt(2))
    # 射入：左上 → 中心
    thick_line(d, p0, p1, 36, main_in)
    arrow_head(d, (p1[0] + 46, p1[1] + 46), p1, (u[0] * 46, -u[1] * 46), main_in)
    # 折返：中心 → 右上
    thick_line(d, p1, p2, 36, main_out)
    arrow_head(d, (p2[0] + 46, p2[1] - 46), p2, (u[0] * 46, u[1] * 46), main_out)
    # 高光芯
    thick_line(d, (172, 212), (238, 278), 10, core_in)
    thick_line(d, (274, 278), (340, 212), 10, core_out)
    # 反弹面
    d.rectangle([116, 394 - 11, 396, 394 + 11], fill=base_col)


def glyph_energy_fountain(d, main, core):
    """喷泉：三射流 + 碗 + 立柱 + 底座（原语义保持，对比度拉满）。"""
    # 中央射流 + 尖端
    thick_line(d, (256, 150), (256, 292), 26, main)
    arrow_head(d, (256, 112), (256, 150), (24, 0), main)
    # 侧射流
    thick_line(d, (204, 210), (204, 292), 18, main)
    thick_line(d, (308, 210), (308, 292), 18, main)
    # 水珠
    for cx in (170, 342):
        d.ellipse([cx - 13, 132 - 13, cx + 13, 132 + 13], fill=main)
    # 碗（上沿高光芯）
    poly(d, [(188, 292), (324, 292), (346, 332), (166, 332)], main)
    d.rectangle([188, 292 - 7, 324, 292 + 7], fill=core)
    # 立柱 + 底座
    d.rectangle([230, 332, 282, 390], fill=main)
    d.rectangle([172, 390, 340, 418], fill=main)


def glyph_atk(d, main, core):
    """交叉双剑：攻击力。"""
    # 剑 A：尖左上 → 柄右下
    poly(d, [(130, 130), (231, 189), (210, 210), (189, 231)], main)
    thick_line(d, (210, 210), (310, 310), 32, main)
    thick_line(d, (354, 270), (270, 354), 20, main)   # 护手
    thick_line(d, (312, 312), (350, 350), 18, main)   # 柄
    d.ellipse([364 - 18, 364 - 18, 364 + 18, 364 + 18], fill=main)  # 首饰
    # 剑 B：尖右上 → 柄左下
    poly(d, [(382, 130), (323, 231), (302, 210), (281, 189)], main)
    thick_line(d, (302, 210), (202, 310), 32, main)
    thick_line(d, (158, 270), (242, 354), 20, main)
    thick_line(d, (200, 312), (162, 350), 18, main)
    d.ellipse([148 - 18, 364 - 18, 148 + 18, 364 + 18], fill=main)
    # 交叉点高光芯
    thick_line(d, (232, 232), (280, 280), 10, core)


def glyph_attack_speed(d, main, core):
    """双箭头（»）：攻速。"""
    for ox in (0, 134):
        pts = [(150 + ox, 146), (278 + ox, 256), (150 + ox, 366)]
        d.line(pts, fill=main, width=44, joint="curve")
        r = 22
        for (x, y) in pts:
            d.ellipse([x - r, y - r, x + r, y + r], fill=main)
    # 高光芯
    d.line([(150, 160), (262, 256), (150, 352)], fill=core, width=10, joint="curve")
    d.line([(284, 160), (396, 256), (284, 352)], fill=core, width=10, joint="curve")


# ---------------------------------------------------------------- 组装

def compose(draw_fn, glow_colors, glow_strength=0.5):
    plate = make_plate()
    glyph = Image.new("RGBA", (C, C), (0, 0, 0, 0))
    draw_fn(ImageDraw.Draw(glyph))
    out = plate
    for col in glow_colors:
        alpha = glyph.getchannel("A").filter(ImageFilter.GaussianBlur(30))
        glow = Image.new("RGBA", (C, C), col[:3] + (0,))
        glow.putalpha(alpha.point(lambda v: int(v * glow_strength)))
        out = Image.alpha_composite(out, glow)
    out = Image.alpha_composite(out, glyph)
    return out.resize((FINAL, FINAL), Image.LANCZOS)


def wcag_lum(rgb):
    def ch(c):
        c = c / 255.0
        return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = rgb[:3]
    return 0.2126 * ch(r) + 0.7152 * ch(g) + 0.0722 * ch(b)


def wcag_ratio(c1, c2):
    l1, l2 = sorted([wcag_lum(c1), wcag_lum(c2)], reverse=True)
    return (l1 + 0.05) / (l2 + 0.05)


def tech_check(name, img):
    """深浅两底合成采样自检：glyph/底盘对比 + 底盘/背景对比。返回指标 dict。"""
    out = {}
    for tag, bg in (("dark", BG_DARK), ("light", BG_LIGHT)):
        base = Image.new("RGBA", (FINAL, FINAL), bg)
        comp = Image.alpha_composite(base, img).convert("RGB")
        px = comp.load()
        cx = cy = FINAL // 2
        glyph_pts, plate_pts = [], []
        for y in range(FINAL):
            for x in range(FINAL):
                dx, dy = x - cx, y - cy
                if dx * dx + dy * dy > 58 * 58:
                    continue  # 圆外
                r0, g0, b0 = px[x, y]
                # glyph 判定：高饱和金或亮青
                is_gold = r0 > 170 and g0 > 130 and b0 < 140
                is_cyan = b0 > 170 and g0 > 140 and r0 < 120
                if is_gold or is_cyan:
                    glyph_pts.append((r0, g0, b0))
                elif not (dx * dx + dy * dy > 52 * 52):
                    plate_pts.append((r0, g0, b0))
        if not glyph_pts or not plate_pts:
            out[tag] = None
            continue
        def mean_l(pts):
            return sum(wcag_lum(p) for p in pts) / len(pts)
        gl, pl = mean_l(glyph_pts), mean_l(plate_pts)
        hi, lo = max(gl, pl), min(gl, pl)
        out[tag] = {"glyph_vs_plate": round((hi + 0.05) / (lo + 0.05), 2)}
    return out


TARGETS = [
    ("pi_r_free_deploy", lambda d: glyph_free_deploy(d, GOLD, GOLD_CORE), (GOLD,)),
    ("pi_r_dmg_reflect", lambda d: glyph_dmg_reflect(d, CYAN, GOLD, CYAN_CORE, GOLD_CORE, CYAN_DIM), (CYAN, GOLD)),
    ("pi_r_energy_fountain", lambda d: glyph_energy_fountain(d, CYAN, CYAN_CORE), (CYAN,)),
    ("pi_atk", lambda d: glyph_atk(d, GOLD, GOLD_CORE), (GOLD,)),
    ("pi_attack_speed", lambda d: glyph_attack_speed(d, CYAN, CYAN_CORE), (CYAN,)),
]


def build_collage():
    """前后对比拼图：上排原图（备份）、下排新图；每格深浅双色底 + 文件名标注。"""
    cell_w, cell_h, pad = 168, 196, 18
    label_h = 26
    cols = len(TARGETS)
    W = pad * 2 + cols * cell_w
    header_h = 34
    H = header_h + label_h + cell_h * 2 + pad * 3
    canvas = Image.new("RGB", (W, H), (24, 28, 38))
    d = ImageDraw.Draw(canvas)

    def font(sz):
        try:
            return ImageFont.load_default(size=sz)
        except TypeError:
            return ImageFont.load_default()

    f_h, f_l = font(17), font(14)
    d.text((pad, 8), "Task 3.2 instrument icons - BEFORE (top row) / AFTER (redrawn) - 2026-09-22  [left=dark bg / right=light bg]",
           fill=(220, 226, 238), font=f_h)

    for i, (name, _, _) in enumerate(TARGETS):
        x0 = pad + i * cell_w
        # 行标签
        # 单元：深浅双色底（左暗右亮）直接验证「深浅两底可辨」
        for row, (src_dir, tag) in enumerate([(BACKUP_DIR, "BEFORE"), (ASSET_DIR, "AFTER")]):
            y0 = header_h + label_h + pad + row * (cell_h + pad)
            half = cell_w // 2
            d.rectangle([x0, y0, x0 + half, y0 + cell_h], fill=BG_DARK[:3])
            d.rectangle([x0 + half, y0, x0 + cell_w, y0 + cell_h], fill=BG_LIGHT[:3])
            icon = Image.open(os.path.join(src_dir, name + ".png")).convert("RGBA")
            icon = icon.resize((128, 128), Image.LANCZOS)
            canvas.paste(icon, (x0 + (cell_w - 128) // 2, y0 + (cell_h - 128) // 2), icon)
            lbl = "%s %s" % (tag, name)
            tw = d.textlength(lbl, font=f_l)
            d.text((x0 + (cell_w - tw) / 2, y0 + cell_h + 3), lbl, fill=(200, 208, 224), font=f_l)

    out = os.path.join(EVIDENCE_DIR, "task32b_pir_before_after.png")
    os.makedirs(EVIDENCE_DIR, exist_ok=True)
    canvas.save(out)
    return out


def main():
    report = {}
    for name, fn, glow in TARGETS:
        img = compose(fn, glow)
        path = os.path.join(ASSET_DIR, name + ".png")
        img.save(path)
        report[name] = tech_check(name, img)
        print("[OK] %s -> %s" % (name, path))

    print("\n== 技术自检（WCAG 对比度比值，采样合成图） ==")
    all_ok = True
    for name, m in report.items():
        for tag in ("dark", "light"):
            v = (m or {}).get(tag)
            if v is None:
                print("  %s [%s] 采样失败" % (name, tag))
                all_ok = False
                continue
            r = v["glyph_vs_plate"]
            ok = r >= 3.0
            all_ok = all_ok and ok
            print("  %s [%s底] glyph:plate = %.2f %s" % (name, tag, r, "PASS" if ok else "FAIL"))

    collage = build_collage()
    print("\n[OK] 拼图 -> %s" % collage)
    # 理论对比度（glyph 主色 vs 渐变中值底）
    mid = tuple((a + b) // 2 for a, b in zip(PLATE_IN, PLATE_OUT))
    print("理论比值: gold:plate=%.1f  cyan:plate=%.1f  plate:%s=%.1f  plate:dark_bg=%.1f" % (
        wcag_ratio(GOLD, mid), wcag_ratio(CYAN, mid),
        "white_bg", wcag_ratio(mid, (255, 255, 255)), wcag_ratio(mid, BG_DARK)))
    print("TASK32B_TECH_OK" if all_ok else "TASK32B_TECH_FAIL")
    return 0 if all_ok else 1


if __name__ == "__main__":
    sys.exit(main())
