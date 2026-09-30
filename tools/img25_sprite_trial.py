# -*- coding: utf-8 -*-
"""Agnes Image 2.5 Flash 雪碧图直出试验（2026-09-29 用户指示：多图合成一次出多帧，
6 帧够用，火光要小甚至没有——别让开火特效喧宾夺主）。

与视频路线的区别：图像 API 同步返回（30-60s，与视频队列独立，白天可用），
一次生成 3x2 六格 sprite sheet（2K 16:9），图生图传现役 idle f0 锁身份。
候选只落 .godot/unit_review/img25_staging/，绝不写 assets/。

用法：python tools/img25_sprite_trial.py <key> <武器描述> [more pairs...]
产物：img25_staging/<key>_attack.png（6 帧 1536x256）+ <key>_preview.png（对比图）
"""
import base64
import io
import json
import os
import re
import subprocess
import sys
import time

import numpy as np
from PIL import Image

from PIL import ImageFilter  # register/body_hull 内联真身（视频管线已退役，09-29）

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KEYS = re.findall(r'sk-[A-Za-z0-9]{20,}',
                  open(os.path.join(ROOT, 'tools', '_agnes_image_api.md'), encoding='utf-8').read())
IMG_API = "https://apihub.agnes-ai.cn/v1/images/generations"  # 项目 key 只通 apihub 网关（api.agnes 直连=无效令牌，09-27 实测）
WORK = os.path.join(ROOT, ".godot", "unit_review")
OUT = os.path.join(WORK, "img25_staging")
FS = 256
FRAME_N = 6

# 主体名词锁死（防"举武器→士兵"式身份漂移；按 key 词根推断，未命中用通用语）
SUBJECT_OVERRIDES = {
    "guardian_modern_stealth": "深蓝色涂装的隐身喷气式战机",
    "guardian_cold_thunder": "深色调的喷气式战机",
    "guardian_ww2_blitzkrieg": "深灰色涂装的二战坦克",
    "drop_railgun": "参考图中的这名白色装甲士兵",
    "drop_thunder_field": "参考图中的这名深色军装士兵",
    "drop_smg_mk2": "参考图中的这名二战德式钢盔士兵",
    "fut_swarm": "参考图中的这台蜂群飞行器",
    "mod_arty_rq7": "参考图中的这架侦察无人机",
    "fut_stealth_bomber": "参考图中的这架深灰色隐身战机",
    "ww2_air_meteor_e": "参考图中的这架银色喷气式战机",
    "ww2_air_bomber": "参考图中的这架螺旋桨攻击机",
}


def subject_for(key):
    if key in SUBJECT_OVERRIDES:
        return SUBJECT_OVERRIDES[key]
    k = key.lower()
    if any(w in k for w in ("mig", "_f4", "air_", "bomber", "fighter", "drone", "saucer", "stealth")):
        return "参考图中的这架喷气式战机/飞行器"
    if any(w in k for w in ("tank", "tiger", "t34", "pz", "leo", "challenger", "_m1", "t90", "abrams", "hovertank")):
        return "参考图中的这辆坦克/装甲车辆"
    if any(w in k for w in ("mech", "tripod", "omega")):
        return "参考图中的这台机甲"
    if any(w in k for w in ("inf", "soldier", "ranger", "trooper", "delta", "spetsnaz", "marine", "cyborg", "scout")):
        return "参考图中的这名士兵"
    base = "参考图中的这个游戏单位"
    if any(w in k for w in ("mg", "vickers", "browning", "rpg", "fort", "radar", "nest", "sam", "arty", "howitzer", "mortar"))             and "smg" not in k:
        base = "参考图中的这座无人武器工事/装备（无人值守，画面中绝不允许出现任何人物）"
    return base


def gen_image(payload, key):
    for i in range(3):
        r = subprocess.run(["curl", "--http1.1", "-s", "-X", "POST", IMG_API,
                            "-H", "Authorization: Bearer " + KEYS[i % len(KEYS)],
                            "-H", "Content-Type: application/json",
                            "--data-binary", "@" + payload, "--max-time", "360"],
                           capture_output=True, text=True, timeout=380)
        try:
            d = json.loads(r.stdout)
        except Exception:
            print("  响应非 JSON:", r.stdout[:120], flush=True)
            time.sleep(20)
            continue
        if d.get("error") or d.get("code"):
            print("  API 报错:", json.dumps(d, ensure_ascii=False)[:180], flush=True)
            time.sleep(20)
            continue
        item = (d.get("data") or [{}])[0]
        if item.get("b64_json"):
            return base64.b64decode(item["b64_json"])
        if item.get("url"):
            dl = subprocess.run(["curl", "--http1.1", "-s", "-L", item["url"], "--max-time", "120"],
                                capture_output=True, timeout=140)
            try:
                Image.open(io.BytesIO(dl.stdout)).load()
                return dl.stdout
            except Exception:
                print("  URL 下载图不完整（截断），8s 后重试…", flush=True)
                time.sleep(8)
                continue
    return None


STYLE_A = ("从左到右、从上到下，六格是同一套连贯的开火动作循环："
           "第1格待机；第2格微微蓄力；第3格开火（{flash}）；第4格开火后轻微后坐；第5格回落；第6格回到待机。")
STYLE_B = ("六格连起来看是一部六帧的小动画：静止→身体压低蓄力→{flash_short}→"
           "反冲到位→缓缓回位→静止。每一格与相邻格的动作差别都要看得出来。")
STYLE_C = ("第1格与第6格是完全相同的待机姿态（首尾一致，循环无缝）；"
           "第1格只是普通的一格，绝不是封面、特写或展示图，主体大小与第2至第5格完全一致；"
           "第2格微微蓄力；第3格开火（{flash}）；第4格开火后轻微后坐；第5格回落。"
           "【火光帧位·硬性】整张表里只有第3格带火光；第1、2、4、5、6格绝不允许出现任何火光、闪光或拖尾光效。")


def attack_prompt(style, subject, weapon):
    """英文结构化模板（09-29 用户定稿：移植自用户另工具的 mod_m1a2 payload，实测比中文段落式稳）。
    subject/武器/火光颜色参数化；布局导图角色限定句（repeated pose is not an action reference）为关键句。"""
    energy = any(w in weapon for w in ("能量", "激光", "光束", "电", "磁轨", "轨道", "相位", "等离子"))
    flash = "a small blue-white energy sparkle" if energy else "a small orange-yellow muzzle flash"
    body = {
        "A": """Frame 1: neutral ready stance, weapon held as in Image 1, no muzzle flash.
Frame 2: leans slightly into the weapon, firmer grip, still no flash.
Frame 3: firing frame - {flash} at the muzzle tip only.
Frame 4: follow-through, slight recoil, flash gone, a thin smoke wisp near the muzzle.
Frame 5: recoil settling, body easing back, no flash, no smoke.
Frame 6: return to the calm ready stance, identical to Frame 1, no effects.""",
        "B": """Frame 1: neutral ready stance, weapon held as in Image 1, no effects.
Frame 2: the body compresses slightly, gathering force, no flash.
Frame 3: {flash} bursts at the muzzle tip; the whole body pushes forward a little.
Frame 4: full recoil, the body rocks back, a thin smoke wisp near the muzzle.
Frame 5: the body eases back toward the ready stance, faint wisp only.
Frame 6: return to the calm ready stance, identical to Frame 1, no effects.""",
        "C": """Frame 1: neutral ready stance, weapon held as in Image 1, no muzzle flash.
Frame 2: leans slightly into the weapon, firmer grip, still no flash.
Frame 3: firing frame - {flash} at the muzzle tip only.
Frame 4: follow-through, slight recoil, flash gone, a thin smoke wisp near the muzzle.
Frame 5: recoil settling, body easing back, no flash, no smoke.
Frame 6: return to the calm ready stance, identical to Frame 1, no effects.""",
    }[style].format(flash=flash)
    return f"""Intended use:
Create a 6-frame 3x2 spritesheet for a side-view 2D game character attack animation.

Input images:
Image 1 is the identity anchor for {subject}. Preserve the exact identity, colors, proportions, silhouette, palette, and left-facing direction.
Image 2 is the 3x2 spritesheet layout guide. Use it only as a layout guide for six equal cells; its repeated pose is not an action reference.

Primary request:
Generate the same subject using its {weapon}, facing LEFT in exact side view for every frame. Any flash is small and brief; the subject stays on a stable ground baseline.

Canvas and layout:
- wide 16:9 PNG spritesheet
- 3 columns by 2 rows, six equal cells
- frame order: left to right across the top row, then left to right across the bottom row
- subject fully visible in each cell
- consistent scale, camera, and ground baseline across all frames

Background: pure flat white fills the entire canvas edge to edge, above, below and between all six cells; the six subjects float freely in empty white space with nothing beneath or behind them; the only pixels in the whole image are the six subjects, the one small flash, and white.

Frame sequence:
{body}

Style:
- 2D game sprite, clean volumetric color painting, no black outline, no contour line
- crisp edges, consistent lighting and palette, readable silhouette

Constraints:
- no direction change; the subject faces LEFT in every frame, never right, never toward the camera
- no camera angle change; the exact same pure side view as Image 1 in every frame, never top-down, never 3/4
- the only content is the six identical subjects, the single flash, and flat white; any other object, texture band, ground, label or border is a defect
- do not crop any part of the subject
- do not merge cells or create comic panels
- do not recenter or rescale the subject differently per frame"""


def strip_outline(f0, band=4, dark=95):
    """剥掉参考图外圈烘焙描边（09-29 用户定案：无黑边风格）v2 补绘法：
    不缩剪影（v1 alpha 腐蚀会啃掉细部导致生成变形）——找"贴着透明边的深色像素环"，
    用邻接的非深色体色迭代扩散填掉。深色机体处邻居也是深色→填完无感；浅色主体上的黑环→变体色。"""
    a = np.asarray(f0).copy()
    rgb = a[:, :, :3].astype(np.int16)
    opaque = a[:, :, 3] > 8
    lum = (rgb[:, :, 0] * 3 + rgb[:, :, 1] * 4 + rgb[:, :, 2]) >> 3
    edge = Image.fromarray(np.where(opaque, 255, 0).astype(np.uint8), "L").filter(ImageFilter.MaxFilter(band * 2 + 1))
    ring = (np.asarray(edge) > 0) & opaque & (lum < dark)
    if not ring.any():
        return Image.fromarray(a, "RGBA")
    hh, ww = ring.shape
    for _ in range(band * 3):
        if not ring.any():
            break
        done = []
        ys, xs = np.where(ring)
        for y, x in zip(ys.tolist(), xs.tolist()):
            y0, y1 = max(0, y - 1), min(hh, y + 2)
            x0, x1 = max(0, x - 1), min(ww, x + 2)
            nm = ~ring[y0:y1, x0:x1] & opaque[y0:y1, x0:x1]
            if int(nm.sum()) >= 2:
                rgb[y, x] = rgb[y0:y1, x0:x1][nm].mean(axis=0)
                done.append((y, x))
        for y, x in done:
            ring[y, x] = False
    a[:, :, :3] = np.clip(rgb, 0, 255).astype(np.uint8)
    return Image.fromarray(a, "RGBA")


def data_uri(img):
    f0_512 = img.convert("RGB").resize((512, 512), Image.LANCZOS)
    buf = io.BytesIO()
    f0_512.save(buf, "PNG")
    return "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode()


def process_attack6(key, weapon):
    """6 格直出 ×3 套提示词风格。产物：<key>_attackA/B/C.png + <key>_attackABC_preview.png。"""
    d = os.path.join(ROOT, "assets", "effects", "unit_anims", key)
    f0 = Image.open(os.path.join(d, "sheet_idle.png")).convert("RGBA").crop((0, 0, FS, FS))
    ENERGY_MODE[0] = any(w in weapon for w in ("能量", "激光", "光束", "电", "磁轨", "轨道", "相位", "等离子"))
    os.makedirs(OUT, exist_ok=True)
    subject = SUBJECT_OVERRIDES.get(key, subject_for(key))
    frames = {}
    for style in ("A", "B", "C"):
        pf = os.path.join(OUT, "%s_attack%s_payload.json" % (key, style))
        open(pf, "w", encoding="utf-8").write(json.dumps({
            "model": "agnes-image-2.5-flash", "prompt": attack_prompt(style, subject, weapon),
            "size": "2K", "ratio": "16:9",
            "extra_body": {"image": [data_uri(f0)], "response_format": "b64_json"}}, ensure_ascii=False))
        print(key, "风格%s 生图中…" % style, flush=True)
        raw = gen_image(pf, key)
        if not raw:
            frames[style] = None
            continue
        open(os.path.join(OUT, "%s_attack%s_raw.png" % (key, style)), "wb").write(raw)
        sheet = Image.open(io.BytesIO(raw)).convert("RGB")
        cells = split_cells(sheet)
        mats = []
        for c in cells:
            m = flood_matte(c)
            mats.append(None if _is_blank(m) else m)
        sc = sheet_scale(mats, f0)
        cand = Image.new("RGBA", (FS * FRAME_N, FS), (0, 0, 0, 0))
        for i in range(FRAME_N):
            if i < len(mats) and mats[i] is not None:
                cand.alpha_composite(register(mats[i], f0, sc)[0], (i * FS, 0))
            else:
                cand.alpha_composite(f0, (i * FS, 0))
        cand.save(os.path.join(OUT, "%s_attack%s.png" % (key, style)))
        frames[style] = cand
        time.sleep(8)
    live = Image.open(os.path.join(d, "sheet_attack.png")).convert("RGBA").crop((0, 0, FS * 6, FS))
    cv = Image.new("RGBA", (FS * 6, (FS + 20) * 4), (24, 26, 32, 255))
    cv.alpha_composite(live, (0, 0))
    for i, s in enumerate(("A", "B", "C")):
        if frames[s] is not None:
            cv.alpha_composite(frames[s], (0, (FS + 20) * (i + 1)))
    cv.save(os.path.join(OUT, "%s_attackABC_preview.png" % key))
    got = [s for s in ("A", "B", "C") if frames[s] is not None]
    return "attack6_ok styles=%s" % (",".join(got) if got else "-")


ENERGY_MODE = [False]


def _flash_mask(a):
    """火光像素判定（register 的 body_hull/body_top 排除火光用）。
    09-29 追加焰心：白热焰心（r,g,b 全高）不算车体——否则开火帧 Hull 被撑宽，register 把整车缩小
    （实测表现：候选里待机格比开火格大一圈）。"""
    rgb = a[:, :, :3].astype(np.int16)
    if ENERGY_MODE[0]:
        base = (rgb[:, :, 2] > 200) & (rgb[:, :, 1] > 140) & (rgb[:, :, 0] < 180)
        core = (rgb[:, :, 0] > 185) & (rgb[:, :, 1] > 185) & (rgb[:, :, 2] > 205)
        return base | core
    base = (rgb[:, :, 0] > 230) & (rgb[:, :, 1] > 120) & (rgb[:, :, 2] < 160)
    core = (rgb[:, :, 0] > 235) & (rgb[:, :, 1] > 185) & (rgb[:, :, 2] < 215)
    return base | core


def body_hull(im):
    """车体轮廓——排除火光像素（火光算进宽度曾致帧间大小漂移）。"""
    a = np.asarray(im)
    al = a[:, :, 3]
    body = (al > 12) & (~_flash_mask(a))
    ys, xs = np.where(body)
    if len(xs) < 40:
        ys, xs = np.where(al > 12)
        if len(xs) == 0:
            return None
    x0, x1, y1 = xs.min(), xs.max(), ys.max()
    cut = x0 + (x1 - x0) * 0.18
    sel = xs >= cut
    return float(xs[sel].mean()), float(y1), float(x0), float(x1)


def body_top_height(im):
    """车体（火光除外）的顶 y 与高度。"""
    a = np.asarray(im)
    al = a[:, :, 3]
    body = (al > 12) & (~_flash_mask(a))
    ys, xs = np.where(body)
    if len(ys) < 40:
        ys, xs = np.where(al > 12)
        if len(ys) == 0:
            return None
    return float(ys.min()), float(ys.max() - ys.min() + 1)


def _scale_ratios(gen, f0):
    """gen 相对 f0 的 (宽比, 高比)，均以火光/特效除外的车体 Hull 计。任一为空返回 None。"""
    fh = body_hull(f0)
    gh = body_hull(gen)
    if fh is None or gh is None:
        return None
    sx = (fh[3] - fh[2]) / max(1.0, gh[3] - gh[2])
    ft = body_top_height(f0)
    gt = body_top_height(gen)
    if ft is None or gt is None or ft[1] < 1:
        return (sx, None)
    return (sx, ft[1] / gt[1])


def sheet_scale(matted_cells, f0):
    """全表统一缩放（09-29 第三修）：六帧是同一单位，缩放必须一个值——姿势会改变包围盒
    （开火蹲探=更宽更矮），逐帧贴齐 f0 会把姿势差放大成帧间大小跳变（用户实测：待机格比开火格高）。
    锚 = 与 f0 比例最贴的帧（取各帧 min(宽比,高比) 的最大者，通常即待机/姿势最接近参考的格）。"""
    ratios = []
    for m in matted_cells:
        if m is None:
            continue
        r = _scale_ratios(m, f0)
        if r and r[0] > 0 and r[1]:
            ratios.append(min(r))
        elif r:
            ratios.append(r[0])
    if not ratios:
        return None
    lo, hi = min(ratios), max(ratios)
    # raw 自身大小就不一致（同设计不同 scale，机甲家族常见，离散度 >12%）→ 返回 None，
    # 交回逐帧 register 归一化（每格各自贴回 f0 尺寸）
    if (hi - lo) / max(hi, 1e-6) > 0.12:
        return None
    return max(0.6, min(hi, 1.5))


def register(gen, f0, scale=None):
    """车体注册（炮管区质心 x + 底缘 y 对齐，火光不计入）；内容钳内，放不下 scale×0.9 重排。
    scale=None 时按本帧 max(宽比,高比) 自算（单帧路径用）；雪碧图多帧必须传 sheet_scale() 的统一值。"""
    canvas = Image.new("RGBA", (FS, FS), (0, 0, 0, 0))
    fh = body_hull(f0)
    gh = body_hull(gen)
    if fh is None or gh is None:
        canvas.alpha_composite(gen.resize((FS, FS), Image.LANCZOS))
        return canvas, 1.0
    bc, by1 = fh[0], fh[1]
    if scale is None:
        r = _scale_ratios(gen, f0)
        if r is None:
            canvas.alpha_composite(gen.resize((FS, FS), Image.LANCZOS))
            return canvas, 1.0
        scale = max(r[0], r[1]) if r[1] else r[0]
        scale = max(0.6, min(scale, 1.5))
    for _ in range(4):
        nw, nh = max(1, int(gen.width * scale)), max(1, int(gen.height * scale))
        g2 = gen.resize((nw, nh), Image.LANCZOS)
        fh2 = body_hull(g2)
        if fh2 is None:
            break
        gc, gy1 = fh2[0], fh2[1]
        a2 = np.asarray(g2)[:, :, 3]
        ys2, xs2 = np.where(a2 > 0)
        px = int(round(bc - gc))
        py = int(round(by1 - gy1))
        cx0, cx1 = px + int(xs2.min()), px + int(xs2.max())
        cy0, cy1 = py + int(ys2.min()), py + int(ys2.max())
        if cx1 - cx0 >= FS or cy1 - cy0 >= FS:
            scale *= 0.9
            continue
        if cx0 < 0:
            px -= cx0
        elif cx1 >= FS:
            px -= cx1 - FS + 1
        if cy0 < 0:
            py -= cy0
        elif cy1 >= FS:
            py -= cy1 - FS + 1
        canvas.alpha_composite(g2, (px, py))
        return canvas, scale
    canvas.alpha_composite(gen.resize((FS, FS), Image.LANCZOS))
    return canvas, scale


def flood_matte(img):
    """白底转透明（简易洪泛：近白且与边连通→透明）。
    ⚠️ 必须保持纵横比（09-29 勘误）：旧版 resize((FS,FS)) 方图直拉，把 3.5:1 的坦克格竖向拉成方胖
    ——用户"raw 好裁剪废"的根因。现长边贴 FS、短边等比，后续 register 再做统一等比缩放对齐。"""
    im = img.convert("RGB")
    w, h = im.size
    sc = min(1.0, FS / float(max(w, h)))
    if sc < 1.0:
        im = im.resize((max(1, int(round(w * sc))), max(1, int(round(h * sc)))), Image.LANCZOS)
    a = np.asarray(im).astype(np.int16)
    near_white = (a[:, :, 0] > 235) & (a[:, :, 1] > 235) & (a[:, :, 2] > 235)
    from collections import deque
    h, w = near_white.shape
    bg = np.zeros_like(near_white, dtype=bool)
    dq = deque()
    for x in range(w):
        for y in (0, h - 1):
            if near_white[y, x] and not bg[y, x]:
                bg[y, x] = True
                dq.append((y, x))
    for y in range(h):
        for x in (0, w - 1):
            if near_white[y, x] and not bg[y, x]:
                bg[y, x] = True
                dq.append((y, x))
    while dq:
        y, x = dq.popleft()
        for ny, nx in ((y+1, x), (y-1, x), (y, x+1), (y, x-1)):
            if 0 <= ny < h and 0 <= nx < w and near_white[ny, nx] and not bg[ny, nx]:
                bg[ny, nx] = True
                dq.append((ny, nx))
    # 封闭白洞：被主体围住的纯白背景（三脚架/支架围出的空隙）——与边界不连通的近白连通域，
    # 面积 ≥0.5% 画布且 ≥97% 像素近纯白（min≥246，有别于带纹理的白色涂装）→ 视为背景清除
    rest = near_white & (~bg)
    seen = np.zeros_like(rest, dtype=bool)
    for yy in range(h):
        for xx in np.where(rest[yy] & ~seen[yy])[0]:
            if seen[yy, xx]:
                continue
            dq = deque([(yy, xx)])
            seen[yy, xx] = True
            comp = [(yy, xx)]
            while dq:
                cy, cx = dq.popleft()
                for ny2, nx2 in ((cy+1, cx), (cy-1, cx), (cy, cx+1), (cy, cx-1)):
                    if 0 <= ny2 < h and 0 <= nx2 < w and rest[ny2, nx2] and not seen[ny2, nx2]:
                        seen[ny2, nx2] = True
                        dq.append((ny2, nx2))
                        comp.append((ny2, nx2))
            if len(comp) >= h * w * 0.0025:
                sub = a[[p[0] for p in comp], [p[1] for p in comp]]
                if (sub.min(axis=1) >= 238).mean() >= 0.90:
                    for py, px in comp:
                        bg[py, px] = True
    al = np.where(bg, 0, 255).astype(np.uint8)
    # 去白边：1px 腐蚀吃掉与白底混合的半融边 + 轻羽化（二值 alpha 的白色摩擦光晕在深底很显眼，09-29）
    al_im = Image.fromarray(al, "L").filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(0.8))
    al = np.asarray(al_im)
    out = Image.fromarray(np.dstack([np.asarray(im).astype(np.uint8), al]), "RGBA")
    if out.size == (FS, FS):
        return out
    canvas = Image.new("RGBA", (FS, FS), (0, 0, 0, 0))
    canvas.alpha_composite(out, ((FS - out.width) // 2, (FS - out.height) // 2))
    return canvas


def _trim_to_content(im, pad=6):
    """格内收边：裁掉固定格里的多余白边（register 的输入越贴主体，缩放对齐越准）。"""
    a = np.asarray(im.convert("RGB")).astype(np.int16)
    nw = ~((a[:, :, 0] > 235) & (a[:, :, 1] > 235) & (a[:, :, 2] > 235))
    ys, xs = np.where(nw)
    if len(xs) == 0:
        return im
    x0 = max(0, int(xs.min()) - pad)
    x1 = min(im.width, int(xs.max()) + 1 + pad)
    y0 = max(0, int(ys.min()) - pad)
    y1 = min(im.height, int(ys.max()) + 1 + pad)
    return im.crop((x0, y0, x1, y1))


def split_cells(sheet, want=FRAME_N, grid=None):
    """按白色间隔带自动检测内容块；行/列带数与 3x2 预期不符时优先走导图固定格网格兜底
    （火光/烟雾跨格粘连时内容带会把两格连体，格子几何仍能把六格分开），最后才三等分。"""
    a = np.asarray(sheet.convert("RGB")).astype(np.int16)
    nonwhite = ~((a[:, :, 0] > 235) & (a[:, :, 1] > 235) & (a[:, :, 2] > 235))

    def bands(mask_1d, min_gap=8):
        out, s = [], None
        for i, v in enumerate(mask_1d):
            if v and s is None:
                s = i
            elif not v and s is not None:
                out.append((s, i))
                s = None
        if s is not None:
            out.append((s, len(mask_1d)))
        merged = []
        for b in out:
            if merged and b[0] - merged[-1][1] < min_gap:
                merged[-1] = (merged[-1][0], b[1])
            else:
                merged.append(b)
        return [b for b in merged if b[1] - b[0] > 12]

    cols = bands(nonwhite.any(axis=0))
    rows = bands(nonwhite.any(axis=1))
    if len(cols) == 3 and len(rows) == 2:
        cells = []
        for ri, (ry0, ry1) in enumerate(rows):
            for ci, (cx0, cx1) in enumerate(cols):
                if ri * 3 + ci < want:
                    cells.append(sheet.crop((cx0, ry0, cx1, ry1)))
        return cells
    # 宽松 gap 重试：火光与主体分离（不相连）会把列带翻倍——gap 26 把 12~25px 的近邻带并回
    for gap in (26,):
        cols2 = bands(nonwhite.any(axis=0), min_gap=gap)
        rows2 = bands(nonwhite.any(axis=1), min_gap=gap)
        if len(cols2) == 3 and len(rows2) == 2:
            cells = []
            for ri, (ry0, ry1) in enumerate(rows2):
                for ci, (cx0, cx1) in enumerate(cols2):
                    if ri * 3 + ci < want:
                        cells.append(sheet.crop((cx0, ry0, cx1, ry1)))
            return cells
    # 行内分列兜底：火光/烟雾伸进隔带把全局列带连体、但未触邻格内容时，按行分别检测列带
    # ——内容精确边界，火光不被格线切掉（09-29 用户放宽火光后这成为常态路径）
    if len(rows) == 2:
        rowcells = []
        ok = True
        for ry0, ry1 in rows:
            rcols = bands(nonwhite[ry0:ry1, :].any(axis=0))
            if len(rcols) != 3:
                ok = False
                break
            rowcells.append([sheet.crop((cx0, ry0, cx1, ry1)) for (cx0, cx1) in rcols])
        if ok:
            return [rowcells[r][c] for r in (0, 1) for c in range(3)][:want]
    # 列分行兜底：某格被画爆大（跨行连体、行带=1）时，按列带拆、列内再按行带拆；
    # 跨行 blob 归其顶缘所在行（blob 通常源自上格爆大），另一格置 None→f0（09-29 drop_railgun 士兵格爆大教训）
    if len(cols) == 3:
        grid2d = [[None, None, None], [None, None, None]]
        ok = True
        for ci, (cx0, cx1) in enumerate(cols):
            rb = bands(nonwhite[:, cx0:cx1].any(axis=1))
            if len(rb) == 2:
                grid2d[0][ci] = sheet.crop((cx0, rb[0][0], cx1, rb[0][1]))
                grid2d[1][ci] = sheet.crop((cx0, rb[1][0], cx1, rb[1][1]))
            elif len(rb) == 1:
                ry0, ry1 = rb[0]
                tgt = 0 if ry0 < sheet.height // 2 else 1
                grid2d[tgt][ci] = sheet.crop((cx0, ry0, cx1, ry1))
            else:
                ok = False
                break
        if ok:
            return [grid2d[r][c] for r in (0, 1) for c in range(3)][:want]
    if grid and len(grid) == 6 and sheet.size == (GUIDE_W, GUIDE_H):
        out = []
        for r in grid[:want]:
            cell = sheet.crop(r)
            # 碎片检测：格内内容触到格框上/下缘（±6px）= 被格线切开的残体（爆大格的躯干/腿），剔除落 f0
            a = np.asarray(cell.convert("RGB")).astype(np.int16)
            nw = ~((a[:, :, 0] > 235) & (a[:, :, 1] > 235) & (a[:, :, 2] > 235))
            ys, _xs = np.where(nw)
            if len(ys) == 0:
                out.append(None)
                continue
            if ys.min() <= 6 or ys.max() >= cell.height - 7:
                out.append(None)
                continue
            out.append(_trim_to_content(cell))
        return out
    W, H = sheet.size
    cw, ch = W // 3, H // 2
    return [sheet.crop(((i % 3) * cw, (i // 3) * ch, (i % 3 + 1) * cw, (i // 3 + 1) * ch))
            for i in range(want)]


def gen_one_shot(key, weapon, f0, out_png):
    """单帧 img2img 生成开火峰值帧（身份保持远好于多格表；火光模型画，时序代码编）。"""
    f0_512 = f0.convert("RGB").resize((512, 512), Image.LANCZOS)
    buf = io.BytesIO()
    f0_512.save(buf, "PNG")
    uri = "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode()
    subject = SUBJECT_OVERRIDES.get(key, subject_for(key))
    energy = any(w in weapon for w in ("能量", "激光", "光束", "电", "磁轨", "轨道", "相位", "等离子"))
    light = "一小簇很小的蓝白色能量微光" if energy else "一小簇橙黄色火光（大小不超过机头/炮口）"
    prompt = (
        "参考图是%s（2D 游戏单位，完全正侧视，主体朝向画面左侧）。"
        "画这同一个主体正在开火的瞬间：发射位置出现%s，"
        "主体因开火整体微微后坐，其余外观涂装比例与参考图完全一致，仍为完全正侧视朝左。"
        "纯白背景，无地面无阴影无文字无水印，2D 游戏单位风格。" % (subject, light))
    payload = json.dumps({"model": "agnes-image-2.5-flash", "prompt": prompt,
                          "size": "1K", "ratio": "1:1",
                          "extra_body": {"image": [uri], "response_format": "b64_json"}}, ensure_ascii=False)
    pf = os.path.join(OUT, "%s_fire_payload.json" % key)
    open(pf, "w", encoding="utf-8").write(payload)
    raw = gen_image(pf, key)
    if not raw:
        return None
    open(os.path.join(OUT, "%s_fire_raw.png" % key), "wb").write(raw)
    ENERGY_MODE[0] = any(w in weapon for w in ("能量", "激光", "光束", "电", "磁轨", "轨道", "相位", "等离子"))
    fire = register(flood_matte(Image.open(io.BytesIO(raw)).convert("RGB")), f0)[0]
    fire.save(out_png)
    return fire


def process_hybrid(key, weapon):
    """混合路线：f0 ×2 + 火光帧 ×6（透明度阶梯衰减）+ f0 ×4 → 12 帧.attack 候选。"""
    d = os.path.join(ROOT, "assets", "effects", "unit_anims", key)
    idle = Image.open(os.path.join(d, "sheet_idle.png")).convert("RGBA")
    f0 = idle.crop((0, 0, FS, FS))
    os.makedirs(OUT, exist_ok=True)
    fire = gen_one_shot(key, weapon, f0, os.path.join(OUT, "%s_fire_frame.png" % key))
    if fire is None:
        return "gen_failed"
    sheet = Image.new("RGBA", (FS * 12, FS), (0, 0, 0, 0))
    alphas = [None, None, 1.0, 1.0, 0.85, 0.7, 0.5, 0.3, None, None, None, None]
    for i, a in enumerate(alphas):
        if a is None:
            sheet.alpha_composite(f0, (i * FS, 0))
        else:
            fr = fire.copy()
            fr.putalpha(fr.getchannel("A").point(lambda v: int(v * a)))
            sheet.alpha_composite(fr, (i * FS, 0))
    sheet.save(os.path.join(OUT, "%s_attack.png" % key))
    live = Image.open(os.path.join(d, "sheet_attack.png")).convert("RGBA").crop((0, 0, FS * 6, FS))
    cv = Image.new("RGBA", (FS * 6, FS * 2 + 24), (24, 26, 32, 255))
    cv.alpha_composite(live, (0, 0))
    cv.alpha_composite(sheet.crop((0, 0, FS * 6, FS)), (0, FS + 24))
    cv.resize((FS * 3, FS + 12), Image.LANCZOS).save(os.path.join(OUT, "%s_preview.png" % key))
    return "hybrid_ok"


def process(key, weapon):
    d = os.path.join(ROOT, "assets", "effects", "unit_anims", key)
    idle = Image.open(os.path.join(d, "sheet_idle.png")).convert("RGBA")
    f0 = idle.crop((0, 0, FS, FS))
    os.makedirs(OUT, exist_ok=True)
    pf = os.path.join(OUT, "%s_payload.json" % key)
    open(pf, "w", encoding="utf-8").write(build_payload(key, weapon, f0))
    print(key, "生图中（同步 30-60s）…", flush=True)
    t0 = time.time()
    raw = gen_image(pf, key)
    if not raw:
        return "gen_failed"
    rawp = os.path.join(OUT, "%s_raw.png" % key)
    open(rawp, "wb").write(raw)
    print(key, "出图 %.1fs" % (time.time() - t0), flush=True)
    sheet = Image.open(io.BytesIO(raw)).convert("RGB")
    cells = split_cells(sheet)
    cand = Image.new("RGBA", (FS * FRAME_N, FS), (0, 0, 0, 0))
    for i in range(FRAME_N):
        if i < len(cells):
            matted = flood_matte(cells[i])
            cand.alpha_composite(register(matted, f0)[0], (i * FS, 0))
        else:
            cand.alpha_composite(f0, (i * FS, 0))
    cand.save(os.path.join(OUT, "%s_attack.png" % key))
    # 对比图：当前 live(取前6帧) vs 候选
    live = Image.open(os.path.join(d, "sheet_attack.png")).convert("RGBA").crop((0, 0, FS * 6, FS))
    cv = Image.new("RGBA", (FS * 6, FS * 2 + 24), (24, 26, 32, 255))
    cv.alpha_composite(live, (0, 0))
    cv.alpha_composite(cand, (0, FS + 24))
    cv.resize((FS * 3, FS + 12), Image.LANCZOS).save(os.path.join(OUT, "%s_preview.png" % key))
    return "ok raw=%dx%d cells=%d" % (sheet.size[0], sheet.size[1], len(cells))




def process_idle(key, refcard=True):
    """待机呼吸表：6 格近静止生图（英文结构化模板）→ 回文拼 8 帧。参考走 resolve_ref_f0（卡图优先）+布局导图。
    候选落 img25_staging/<key>_idle.png（8x256），不动 assets/。"""
    d = os.path.join(ROOT, "assets", "effects", "unit_anims", key)
    f0, ref_tag = resolve_ref_f0(key, refcard)
    _ref_tag_holder[0] = ref_tag
    idle = Image.open(os.path.join(d, "sheet_idle.png")).convert("RGBA")
    os.makedirs(OUT, exist_ok=True)
    f0_512 = f0.convert("RGB").resize((512, 512), Image.LANCZOS)
    buf = io.BytesIO()
    f0_512.save(buf, "PNG")
    uri = "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode()
    subject = SUBJECT_OVERRIDES.get(key, subject_for(key))
    prompt = f"""Intended use:
Create a 6-frame 3x2 spritesheet for a side-view 2D game character idle animation.

Input images:
Image 1 is the identity anchor for {subject}. Preserve the exact identity, colors, proportions, silhouette, palette, and left-facing direction.
Image 2 is the 3x2 spritesheet layout guide. Use it only as a layout guide for six equal cells; its repeated pose is not an action reference.

Primary request:
Generate the same subject standing idle, facing LEFT in exact side view for every frame. The six frames are almost identical, with only a very subtle idle motion (breathing or engine vibration, no larger than two percent of the subject height).

Canvas and layout:
- wide 16:9 PNG spritesheet
- 3 columns by 2 rows, six equal cells
- frame order: left to right across the top row, then left to right across the bottom row
- subject fully visible in each cell
- consistent scale, camera, and ground baseline across all frames

Background: pure flat white fills the entire canvas edge to edge, above, below and between all six cells; the six subjects float freely in empty white space with nothing beneath or behind them; the only pixels in the whole image are the six subjects and white.

Frame sequence:
Frame 1 through Frame 6: the same idle stance with only tiny variations, no weapon fire, no effects, no glow.

Style:
- 2D game sprite, clean volumetric color painting, no black outline, no contour line
- crisp edges, consistent lighting and palette, readable silhouette

Constraints:
- no direction change; the subject faces LEFT in every frame, never right, never toward the camera
- no camera angle change; the exact same pure side view as Image 1 in every frame, never top-down, never 3/4
- the only content is the six identical subjects and flat white; any other object, texture band, ground, label or border is a defect
- absolutely no muzzle flash, no fire, no glowing ring or spark at the weapon tip in any frame; the weapon stays completely cold in all six frames
- do not crop any part of the subject
- do not merge cells or create comic panels
- do not recenter or rescale the subject differently per frame"""
    layout_idle = True
    imgs = [uri]
    prefix = ""
    if layout_idle:
        imgs.append(file_uri(make_layout_guide(f0, key)))
        prefix = LAYOUT_SENTENCE
    payload = json.dumps({"model": "agnes-image-2.5-flash", "prompt": prefix + prompt,
                          "size": "2K", "ratio": "16:9",
                          "extra_body": {"image": imgs, "response_format": "b64_json"}}, ensure_ascii=False)
    pf = os.path.join(OUT, "%s_idle_payload.json" % key)
    open(pf, "w", encoding="utf-8").write(payload)
    print(key, "待机表生图中…", flush=True)
    raw = gen_image(pf, key)
    if not raw:
        return "gen_failed"
    open(os.path.join(OUT, "%s_idle_raw.png" % key), "wb").write(raw)
    sheet_img = Image.open(io.BytesIO(raw)).convert("RGB")
    cells = split_cells(sheet_img)
    if len(cells) != 6:
        return "cells=%d" % len(cells)
    mats = []
    for c in cells:
        m = None if c is None else flood_matte(c)
        mats.append(None if m is None or _is_blank(m) else m)
    sc = sheet_scale(mats, f0)
    frames = [f0 if m is None else register(m, f0, sc)[0] for m in mats]
    # 回文拼 8 帧（anim.json counts.idle=8 不动）：0,1,2,3,4,5,4,3
    order = [0, 1, 2, 3, 4, 5, 4, 3]
    out = Image.new("RGBA", (FS * 8, FS), (0, 0, 0, 0))
    for i, fi in enumerate(order):
        out.alpha_composite(frames[fi], (i * FS, 0))
    out.save(os.path.join(OUT, "%s_idle.png" % key))
    live8 = idle.crop((0, 0, FS * 8, FS))
    cv = Image.new("RGBA", (FS * 8, FS * 2 + 24), (24, 26, 32, 255))
    cv.alpha_composite(live8, (0, 0))
    cv.alpha_composite(out, (0, FS + 24))
    cv.resize((FS * 4, FS + 12), Image.LANCZOS).save(os.path.join(OUT, "%s_idle_preview.png" % key))
    return "idle_ok cells=%d" % len(cells)


def file_uri(path, max_w=1280):
    """保持纵横比的 Data URI（布局导图用；data_uri 会强拉 512 方图会压扁导图）。"""
    im = Image.open(path).convert("RGB")
    if im.width > max_w:
        im = im.resize((max_w, int(im.height * max_w / im.width)), Image.LANCZOS)
    buf = io.BytesIO()
    im.save(buf, "PNG")
    return "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode()


LAYOUT_GUIDE_NOTE = "09-29 二次实验：灰空框导图失败（灰线被照抄进成品+身份污染）；改为 f0 铺样例表。"
LAYOUT_SENTENCE = (
    "第二张图是成品布局示例：它展示的就是最终要交付的雪碧图版式——同一主体在 2 行 3 列共六个格子里各出现一次，"
    "格与格之间是很宽的纯白间隔带，整张图四边留有纯白白边。成品必须完全照搬这个版式："
    "六格的位置、间隔带宽度、主体的大小和底缘位置都与示例一致，任何主体部分都不得触碰画面边缘。"
    "示例里六格都是同一个静止姿态；你的任务是保持这个版式与主体大小不变，把六个格子画成下面要求的开火动作序列，每格一个姿态。"
    "第一张图是主体的外观参考，主体的外观涂装以第一张图为准。")


GUIDE_W, GUIDE_H = 2624, 1472
GUIDE_MX, GUIDE_MY, GUIDE_GX, GUIDE_GY = 130, 100, 70, 120


def guide_rects():
    """样例导图的 6 个格子几何（也是生成结果的近似格子位置）——切格网格兜底用：
    火光/烟雾跨格粘连时，内容带检测失效，固定格裁切仍能分开六格（09-29 用户拍板放格子的价值）。"""
    cw = (GUIDE_W - 2 * GUIDE_MX - 2 * GUIDE_GX) // 3
    ch = (GUIDE_H - 2 * GUIDE_MY - GUIDE_GY) // 2
    return [(GUIDE_MX + c * (cw + GUIDE_GX), GUIDE_MY + r * (ch + GUIDE_GY),
             GUIDE_MX + c * (cw + GUIDE_GX) + cw, GUIDE_MY + r * (ch + GUIDE_GY) + ch)
            for r in range(2) for c in range(3)]


_ref_tag_holder = ["f0"]


def make_layout_guide(f0, key):
    """布局示例图：f0 复制 6 份铺 3×2 白底样例表（宽间隔带+四边白边）——给模型直接看"成品长什么样"。
    格子的三重价值（09-29 用户拍板）：锁主体大小、约束火光不出格、提供确定切格网格。"""
    p = os.path.join(OUT, "%s_layoutguide.png" % key)
    marker = p + ".src"
    src_tag = _ref_tag_holder[0]
    if os.path.exists(p) and os.path.exists(marker) and open(marker, encoding="utf-8").read() == src_tag:
        return p
    scale = min(741 * 0.82 / FS, 576 * 0.85 / FS)
    nw, nh = max(1, int(FS * scale)), max(1, int(FS * scale))
    f0s = f0.convert("RGBA").resize((nw, nh), Image.LANCZOS)
    f0rgb, mask = f0s.convert("RGB"), f0s.getchannel("A")
    g = Image.new("RGB", (GUIDE_W, GUIDE_H), (255, 255, 255))
    for (x0, y0, x1, y1) in guide_rects():
        cell = Image.new("RGB", (x1 - x0, y1 - y0), (255, 255, 255))
        cell.paste(f0rgb, ((x1 - x0 - nw) // 2, (y1 - y0) - nh - 30), mask)
        g.paste(cell, (x0, y0))
    g.save(p)
    open(marker, "w", encoding="utf-8").write(src_tag)
    return p


def resolve_ref_f0(key, refcard=False, refbak=False):
    """参考帧统一解析（09-29 定稿）：卡图优先（refcard，情报面板同链 img25_icon_map.json），
    细描边存档（refbak），最后雪碧图 f0。返回 (f0_256, source_tag)。"""
    d = os.path.join(ROOT, "assets", "effects", "unit_anims", key)
    CURSED = ("fut_stealth_bomber", "ww2_air_meteor_e", "mod_arty_rq7",
              "platform_cold_scout", "ww1_mgnest")
    if refcard and key in CURSED:
        refcard = False  # 四掷验证：这五家的卡图/名称先验导致身份崩坏，回退 f0（游戏内真身）
    if refcard:
        m = json.load(open(os.path.join(ROOT, ".godot", "unit_review", "img25_icon_map.json"), encoding="utf-8"))
        icon = str(m.get(key, "") or "")
        if not icon and key == "drop_phase_lance":
            icon = "res://assets/card_icons/enemy/drop_phase_lance.png"
        elif not icon and key == "vis_xeno_tripod":
            icon = "res://assets/card_icons/enemy/vis_xeno_tripod.png"
        elif not icon and key == "ww1_mgnest":
            icon = "res://assets/card_icons/player/vis_player_038.png"
        if icon:
            cardp = icon.replace("res://", os.path.join(ROOT) + os.sep)
            f0 = Image.open(cardp).convert("RGBA")
            a = np.asarray(f0)
            ys, xs = np.where(a[:, :, 3] > 8)
            if len(xs):
                f0 = f0.crop((int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1))
            sc = min(FS / f0.width, FS / f0.height)
            f0 = f0.resize((max(1, int(f0.width * sc)), max(1, int(f0.height * sc))), Image.LANCZOS)
            base = Image.new("RGBA", (FS, FS), (0, 0, 0, 0))
            base.alpha_composite(f0, ((FS - f0.width) // 2, FS - f0.height - 10))
            return base, "card"
    if refbak:
        d2 = os.path.join(ROOT, ".godot", "art_backup_outline_2026-09-24", key)
        return Image.open(os.path.join(d2, "sheet_idle.png")).convert("RGBA").crop((0, 0, FS, FS)), "bak"
    return Image.open(os.path.join(d, "sheet_idle.png")).convert("RGBA").crop((0, 0, FS, FS)), "f0"


def gen_raw_only(key, weapon, styles, layout=True, strip_ref=False, refbak=False, refcard=True):
    """只出 raw 不切格（英文结构化模板 + 卡图参考 + 导图；styles 缺省 C）。核对过了才 --crop。"""
    f0, ref_tag = resolve_ref_f0(key, refcard, refbak)
    _ref_tag_holder[0] = ref_tag
    ENERGY_MODE[0] = any(w in weapon for w in ("能量", "激光", "光束", "电", "磁轨", "轨道", "相位", "等离子"))
    os.makedirs(OUT, exist_ok=True)
    subject = SUBJECT_OVERRIDES.get(key, subject_for(key))
    imgs = [data_uri(f0)]
    prefix = ""
    if layout:
        imgs.append(file_uri(make_layout_guide(f0, key)))
        prefix = LAYOUT_SENTENCE
    for style in styles:
        pf = os.path.join(OUT, "%s_attack%s_payload.json" % (key, style))
        open(pf, "w", encoding="utf-8").write(json.dumps({
            "model": "agnes-image-2.5-flash", "prompt": prefix + attack_prompt(style, subject, weapon),
            "size": "2K", "ratio": "16:9",
            "extra_body": {"image": imgs, "response_format": "b64_json"}}, ensure_ascii=False))
        print(key, "风格%s 生图中%s…" % (style, "（带布局导图）" if layout else ""), flush=True)
        raw = gen_image(pf, key)
        if raw:
            open(os.path.join(OUT, "%s_attack%s_raw.png" % (key, style)), "wb").write(raw)
            print(key, "风格%s raw 已落盘（待人工核对再 --crop）" % style, flush=True)
        else:
            print(key, "风格%s 生成失败" % style, flush=True)
        time.sleep(8)
    return "gen_ok"


def _rebuild_abc_preview(key, d):
    """按现存 <key>_attack[ABC].png 重建 live vs 候选对比图（缺哪个风格就少一行）。"""
    live = Image.open(os.path.join(d, "sheet_attack.png")).convert("RGBA").crop((0, 0, FS * 6, FS))
    rows = [live]
    for s in ("A", "B", "C"):
        p = os.path.join(OUT, "%s_attack%s.png" % (key, s))
        if os.path.exists(p):
            rows.append(Image.open(p).convert("RGBA"))
    cv = Image.new("RGBA", (FS * 6, (FS + 20) * len(rows)), (24, 26, 32, 255))
    for i, r in enumerate(rows):
        cv.alpha_composite(r, (0, (FS + 20) * i))
    cv.save(os.path.join(OUT, "%s_attackABC_preview.png" % key))


def _is_blank(img):
    """空格检测：matte 后无有效不透明像素 → 该格模型没画，兜底用 f0（09-29 拍板：6 格不必全过）。"""
    a = np.asarray(img)
    return a.shape[2] < 4 or int(a[:, :, 3].max()) < 10


def _drop_oversize_cells(cells, limit=1.5):
    """画爆格剔除（raw 像素域，必须在 matte 归一化之前——爆格经 matte 缩放后高度信号会被抹掉）：
    内容高 > 全表中位数 ×limit → 视为画坏置 None，落 f0 兜底（09-29 drop_railgun 待机格 3/3 爆大教训）。"""
    hs, info = [], []
    for c in cells:
        if c is None:
            info.append(None)
            continue
        a = np.asarray(c.convert("RGB")).astype(np.int16)
        nw = ~((a[:, :, 0] > 235) & (a[:, :, 1] > 235) & (a[:, :, 2] > 235))
        ys, _xs = np.where(nw)
        if len(ys) == 0:
            info.append(None)
            continue
        h = int(ys.max() - ys.min() + 1)
        info.append(h)
        hs.append(h)
    if len(hs) < 3:
        return cells
    med = sorted(hs)[len(hs) // 2]
    return [None if (h is not None and h > med * limit) else c for c, h in zip(cells, info)]


def _drop_islands(m, keep_ratio=0.25):
    """剔除格内游离小岛（与主体不连通、面积 < 主体 25% 的杂碎：火光飞溅屑/杂符文/齿轮残渣）——
    每格应只含一个主体（09-29 fut_swarm 齿轮杂符、thunder_field 悬空碎片教训）。保留 ≥25% 的合法分离部件。"""
    if m is None:
        return None
    a = np.asarray(m)
    mask = a[:, :, 3] > 8
    h, w = mask.shape
    lab = np.zeros((h, w), dtype=np.int32)
    sizes = {}
    cur = 0
    from collections import deque
    for y in range(h):
        for x in np.where(mask[y] & (lab[y] == 0))[0]:
            if lab[y, x]:
                continue
            cur += 1
            lab[y, x] = cur
            dq = deque([(y, x)])
            n = 0
            while dq:
                cy, cx = dq.popleft()
                n += 1
                y0, y1 = max(0, cy - 1), min(h, cy + 2)
                x0, x1 = max(0, cx - 1), min(w, cx + 2)
                for ny in range(y0, y1):
                    for nx in range(x0, x1):
                        if mask[ny, nx] and not lab[ny, nx]:
                            lab[ny, nx] = cur
                            dq.append((ny, nx))
            sizes[cur] = n
    if cur <= 1:
        return m
    main = max(sizes, key=sizes.get)
    keep_ids = [k for k, s in sizes.items() if s >= sizes[main] * keep_ratio]
    out = a.copy()
    out[~np.isin(lab, keep_ids), 3] = 0
    return Image.fromarray(out, "RGBA")


def crop_raw(key, style, flip=False, flip_cells=None, skip_cells=None):
    """人工核对通过的 raw 才切格：split + register + 候选 + ABC 对比图。
    flip=True 整表水平镜像纠朝向；flip_cells=多格镜像集合（须先逐格目检 raw 确认）；
    skip_cells=强制落 f0 的格集合（碎片/尺寸异常格，09-29）。原始 raw 保留不动。
    导图存在时粘连自动走固定格网格兜底。"""
    d = os.path.join(ROOT, "assets", "effects", "unit_anims", key)
    f0 = Image.open(os.path.join(d, "sheet_idle.png")).convert("RGBA").crop((0, 0, FS, FS))
    rawp = os.path.join(OUT, "%s_attack%s_raw.png" % (key, style))
    if not os.path.exists(rawp):
        return "no_raw"
    pf = os.path.join(OUT, "%s_attack%s_payload.json" % (key, style))
    if os.path.exists(pf):
        try:
            p = json.load(open(pf, encoding="utf-8")).get("prompt", "")
            ENERGY_MODE[0] = any(w in p for w in ("能量", "激光", "光束", "电", "磁轨", "轨道", "相位", "等离子")) or "blue-white energy" in p
        except Exception:
            pass
    sheet = Image.open(rawp).convert("RGB")
    if flip:
        sheet = sheet.transpose(Image.FLIP_LEFT_RIGHT)
        sheet.save(rawp.replace("_raw.png", "_rawFLIP.png"))
    gp = os.path.join(OUT, "%s_layoutguide.png" % key)
    grid = guide_rects() if os.path.exists(gp) else None
    cells = split_cells(sheet, grid=grid)
    for ci in set(flip_cells or ()):
        if 0 <= ci < len(cells):
            cells[ci] = cells[ci].transpose(Image.FLIP_LEFT_RIGHT)
    cells = _drop_oversize_cells(cells)
    mats = []
    for c in cells:
        m = None if c is None else flood_matte(c)
        mats.append(None if m is None or _is_blank(m) else m)
    mats = [_drop_islands(m) for m in mats]
    for si in set(skip_cells or ()):
        if 0 <= si < len(mats):
            mats[si] = None
    sc = sheet_scale(mats, f0)
    cand = Image.new("RGBA", (FS * FRAME_N, FS), (0, 0, 0, 0))
    for i in range(FRAME_N):
        if i < len(mats) and mats[i] is not None:
            cand.alpha_composite(register(mats[i], f0, sc)[0], (i * FS, 0))
        else:
            cand.alpha_composite(f0, (i * FS, 0))
    cand.save(os.path.join(OUT, "%s_attack%s.png" % (key, style)))
    _rebuild_abc_preview(key, d)
    return "crop_ok cells=%d scale=%s flip=%s" % (len(cells), sc and round(sc, 3), flip)


def crop_idle(key, flip=False):
    """人工核对通过的待机 raw → 回文 8 帧候选（空格兜底 f0）。产物 <key>_idle.png + _idle_preview.png。"""
    d = os.path.join(ROOT, "assets", "effects", "unit_anims", key)
    idle = Image.open(os.path.join(d, "sheet_idle.png")).convert("RGBA")
    f0 = idle.crop((0, 0, FS, FS))
    rawp = os.path.join(OUT, "%s_idle_raw.png" % key)
    if not os.path.exists(rawp):
        return "no_raw"
    sheet = Image.open(rawp).convert("RGB")
    if flip:
        sheet = sheet.transpose(Image.FLIP_LEFT_RIGHT)
        sheet.save(rawp.replace("_raw.png", "_rawFLIP.png"))
    cells = _drop_oversize_cells(split_cells(sheet))
    # 空格直接丢弃（不混 f0——f0 与生成帧大小有差，混编会在循环点跳变），纯生成帧做自适应回文
    mats = []
    for c in cells:
        m = None if c is None else flood_matte(c)
        if m is not None and not _is_blank(m):
            mats.append(m)
    # 火光帧过滤（09-29 三轮定稿）：待机绝不允许开火——模型"持枪= ready to fire"先验顽固，
    # 连掷加枪口环；flash 像素 >150 的帧直接丢弃，剩余干净帧回文（免去无限重掷）
    pf2 = os.path.join(OUT, "%s_idle_payload.json" % key)
    if os.path.exists(pf2):
        try:
            pp = json.load(open(pf2, encoding="utf-8")).get("prompt", "")
            ENERGY_MODE[0] = "blue-white energy" in pp or any(w in pp for w in ("能量", "激光", "光束", "电", "磁轨", "轨道", "相位", "等离子"))
        except Exception:
            pass
    clean = []
    for m in mats:
        a = np.asarray(m)
        n_flash = int(_flash_mask(a).sum())
        (clean if n_flash <= 150 else [None])[0] if False else None
        if n_flash <= 150:
            clean.append(m)
        else:
            print("  idle 火光帧剔除 flash=%d" % n_flash, flush=True)
    mats = clean if len(clean) >= 4 else mats
    if not mats:
        return "all_blank"
    sc = sheet_scale(mats, f0)
    frames = [register(m, f0, sc)[0] for m in mats]
    n = len(frames)
    order = []
    for i in range(8):
        k = i % (2 * n - 2) if n > 1 else 0
        order.append(k if k < n else 2 * n - 2 - k)
    out = Image.new("RGBA", (FS * 8, FS), (0, 0, 0, 0))
    for i, fi in enumerate(order):
        out.alpha_composite(frames[fi], (i * FS, 0))
    out.save(os.path.join(OUT, "%s_idle.png" % key))
    live8 = idle.crop((0, 0, FS * 8, FS))
    cv = Image.new("RGBA", (FS * 8, FS * 2 + 24), (24, 26, 32, 255))
    cv.alpha_composite(live8, (0, 0))
    cv.alpha_composite(out, (0, FS + 24))
    cv.resize((FS * 4, FS + 12), Image.LANCZOS).save(os.path.join(OUT, "%s_idle_preview.png" % key))
    return "cropidle_ok frames=%d flip=%s" % (n, flip)


if __name__ == "__main__":
    args = sys.argv[1:]

    def take(flag):
        if flag in args:
            args.remove(flag)
            return True
        return False

    mode = "pair"
    for f, m in (("--attack6", "attack6"), ("--gen", "gen"), ("--crop", "crop"),
                 ("--cropidle", "cropidle"), ("--hybrid", "hybrid"), ("--idle", "idle")):
        if take(f):
            mode = m
            break
    report = {}
    take("--layout")  # 兼容旧显式写法——导图自 09-29 拍板起默认开
    layout = not take("--nolayout")
    refbak = take("--refbak")
    refcard = take("--refcard")
    if mode == "gen":
        styles = list(args[2].upper()) if len(args) > 2 else ["C"]
        report[args[0]] = gen_raw_only(args[0], args[1], styles, layout, False, refbak, refcard)
    elif mode == "crop":
        key, style = args[0], args[1].upper()
        flip, flip_cells, skip_cells = False, [], []
        for m in args[2:]:
            if m.lower() == "flip":
                flip = True
            elif m.lower() == "energy":
                ENERGY_MODE[0] = True
            elif m.lower().startswith("flipcell:"):
                flip_cells = [int(x) for x in m.split(":", 1)[1].split(",") if x.strip()]
            elif m.lower().startswith("skip:"):
                skip_cells = [int(x) for x in m.split(":", 1)[1].split(",") if x.strip()]
        report[key] = crop_raw(key, style, flip, flip_cells, skip_cells)
    elif mode == "cropidle":
        flip = len(args) > 1 and args[1].lower() == "flip"
        report[args[0]] = crop_idle(args[0], flip)
    else:
        if mode == "idle":
            for key in args:
                try:
                    r = process_idle(key)
                except Exception as e:
                    r = "error: %s" % e
                report[key] = r
                print(key, "->", r, flush=True)
        else:
            for i in range(0, len(args), 2):
                key, weapon = args[i], args[i + 1]
                try:
                    if mode == "attack6":
                        r = process_attack6(key, weapon)
                    elif mode == "hybrid":
                        r = process_hybrid(key, weapon)
                    else:
                        r = process(key, weapon)
                except Exception as e:
                    r = "error: %s" % e
                report[key] = r
                print(key, "->", r, flush=True)
    print("IMG25_DONE", json.dumps(report, ensure_ascii=False))
