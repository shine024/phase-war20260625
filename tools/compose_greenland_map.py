#!/usr/bin/env python3
"""格陵兰底图合成器 v4（地形轮：解决"少细节、无地形"）。
在 v3 贴图铺装基础上：
  1. 纹理铺装密度加倍（span 减半，笔触细节可见；UV 扰动+镜像采样防接缝/重复）
  2. 真地形场：内陆冰穹 + 沿岸棱脊山脉（ridged noise）+ 河谷刻蚀 → 强山体阴影
  3. 冰川舌：从冰穹沿重力流向海岸，先画宽淡冰舌再叠细水线（格陵兰标志地貌）
  4. 冰面放射流纹、等高线微影、苔原湖泊、海岸碎浪线
  5. 全图对比/饱和增强
轮廓 = 真实格陵兰海岸线（GRL.geo.json），黑门 = 东尖角。输出 greenland_tex2_{main,alt}.png。
"""
import json
import math
import os
import random
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageEnhance

# Windows GBK 控制台下 Unicode 符号防崩，强制 UTF-8 输出
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_OUT_DIR = os.path.join(ROOT, "docs", "地图重设计", "generated", "greenland")
# 可选命令行参数：输出目录（不传 = 原定稿轮目录，文档 §1 命令行为不变）
OUT_DIR = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_OUT_DIR
GEO = os.path.join(OUT_DIR, "grl.geo.json")
if not os.path.exists(GEO):
    GEO = os.path.join(DEFAULT_OUT_DIR, "grl.geo.json")  # 海岸线数据回退原目录
TEX_DIR = os.path.join(OUT_DIR, "textures")
W, H = 2560, 1440
SF = W / 1312.0
SS = 2
KM_DEG_LAT = 111.0
KM_DEG_LON = 111.0 * math.cos(math.radians(71.5))


def px(v: float) -> int:
    return int(round(v * SF))


def land_mask():
    d = json.load(open(GEO, encoding="utf-8"))
    ring = d["features"][0]["geometry"]["coordinates"][0]
    xc, yc = -42.75, 71.85
    sx_km = np.array([(yc - p[1]) * KM_DEG_LAT for p in ring])
    sy_km = np.array([(xc - p[0]) * KM_DEG_LON for p in ring])
    land_h = 640.0 * SF
    scale = land_h / (sy_km.max() - sy_km.min())
    x0 = (W - (sx_km.max() - sx_km.min()) * scale) / 2 - sx_km.min() * scale
    y0 = (H - land_h) / 2 - sy_km.min() * scale
    pts = [(x0 + x * scale, y0 + y * scale) for x, y in zip(sx_km, sy_km)]
    im = Image.new("L", (W * SS, H * SS), 0)
    ImageDraw.Draw(im).polygon([(x * SS, y * SS) for x, y in pts], fill=255)
    return np.asarray(im.resize((W, H), Image.LANCZOS)) > 127


def pil_noise(w, h, octaves=(4, 8, 16, 48), seed=7):
    rng = random.Random(seed)
    acc = np.zeros((h, w), np.float32)
    total = 0
    for cells in octaves:
        n = Image.effect_noise((cells, max(2, int(cells * h / w))), rng.randrange(1 << 30)).resize((w, h), Image.BICUBIC)
        a = np.asarray(n, np.float32) / 255.0
        acc += a * (1.0 / cells) ** 0.5
        total += (1.0 / cells) ** 0.5
    acc /= total
    return (acc - acc.min()) / (acc.max() - acc.min())


def ridged(n: np.ndarray, sharp=1.6) -> np.ndarray:
    """棱脊噪声：山脉脊线感。"""
    r = 1.0 - np.abs(2.0 * n - 1.0)
    return r ** sharp


TEX = {}


def tri(v: np.ndarray) -> np.ndarray:
    m = np.mod(v, 2048.0)
    return np.clip(np.where(m < 1024.0, m, 2048.0 - m), 0, 1023)


def sample(name: str, u: np.ndarray, v: np.ndarray, span: float) -> np.ndarray:
    t = TEX[name]
    return t[tri(v / span).astype(np.int32), tri(u / span).astype(np.int32)]


def radial_smudge(draw_img, cx, cy, r, color, alpha):
    layer = Image.new("RGBA", draw_img.size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).ellipse([cx - r, cy - r, cx + r, cy + r], fill=color + (int(255 * alpha),))
    layer = layer.filter(ImageFilter.GaussianBlur(r * 0.6))
    draw_img.alpha_composite(layer)


def compose(tag: str, seed: int):
    for n in ("tex_grass", "tex_rock", "tex_snow", "tex_forest", "tex_sea"):
        if n not in TEX:
            TEX[n] = np.asarray(Image.open(os.path.join(TEX_DIR, n + ".png")).convert("RGB")
                                .resize((1024, 1024), Image.LANCZOS), np.float32)

    mask = land_mask()
    mask_f = mask.astype(np.float32)
    from scipy.ndimage import distance_transform_edt, gaussian_filter
    dist = distance_transform_edt(mask).astype(np.float32)
    land_cols = np.nonzero(mask.any(axis=0))[0]
    land_x0, land_x1 = int(land_cols[0]), int(land_cols[-1])

    n1 = pil_noise(W, H, (3, 7, 16, 44), seed=seed)
    n2 = pil_noise(W, H, (6, 14, 40, 96), seed=seed + 12)
    n3 = pil_noise(W, H, (10, 24, 60), seed=seed + 34)
    n4 = pil_noise(W, H, (90, 200), seed=seed + 56)
    nr1 = pil_noise(W, H, (5, 12, 28, 64), seed=seed + 78)
    nr2 = pil_noise(W, H, (7, 18, 36, 80), seed=seed + 91)

    xx = np.linspace(0, 1, W, dtype=np.float32)[None, :]
    west_warm = np.clip(1.0 - xx / 0.62, 0, 1)
    east_cold = np.clip((xx - 0.55) / 0.45, 0, 1)

    # ── 地形场：冰穹 + 沿岸棱脊山脉 + 内陆山块 ──
    dome = np.clip(dist / px(150), 0, 1)
    rim = np.clip((dist - px(8)) / px(20), 0, 1) * np.clip((px(75) - dist) / px(25), 0, 1)
    interior = np.clip((dist - px(60)) / px(40), 0, 1)
    mountains = (rim * 0.95 + interior * 0.75) * (0.55 * ridged(nr1) + 0.45 * ridged(nr2))
    height = 0.55 * dome + 0.85 * mountains + 0.12 * n1
    height *= mask_f

    # ── 地带权重（噪声抖动边界）──
    dd = dist + (n2 - 0.5) * px(26)
    w_grass = np.clip(1 - dd / px(40), 0, 1)
    w_rock = np.clip(1 - np.abs(dd - px(64)) / px(36), 0, 1) * (1 - w_grass * 0.4)
    w_snow = np.clip((dd - px(96)) / px(30), 0, 1)
    w_snow = np.maximum(w_snow, np.clip((height - 0.85) / 0.3, 0, 1) * mask_f)  # 高海拔也积雪
    w_forest = np.clip((n3 - 0.58) / 0.12, 0, 1) * np.clip(1 - dd / px(80), 0, 1) * 0.9
    tot = w_grass + w_rock + w_snow + w_forest + 1e-5
    for a in (w_grass, w_rock, w_snow, w_forest):
        a /= tot

    Yg, Xg = np.mgrid[0:H, 0:W].astype(np.float32)
    warp_u = (n1 - 0.5) * px(120)
    warp_v = (n2 - 0.5) * px(120)
    u = Xg + warp_u
    v = Yg + warp_v

    # 纹理铺装：span 减半 → 笔触细节可见
    land = (w_grass[..., None] * sample("tex_grass", u, v, px(300))
            + w_rock[..., None] * sample("tex_rock", u + 300.0, v, px(260))
            + w_snow[..., None] * sample("tex_snow", u + 700.0, v + 120.0, px(420))
            + w_forest[..., None] * sample("tex_forest", u + 512.0, v + 80.0, px(280)))

    # 高海拔提亮（地形读感）
    hn = height / max(height.max(), 1e-4)
    land *= (0.90 + 0.28 * hn)[..., None]

    # 冰面放射流纹（自冰穹向外）
    ys, xs = np.nonzero(mask)
    cx, cy = xs.mean(), ys.mean()
    ang = np.arctan2(Yg - cy, Xg - cx)
    rad = np.sqrt((Xg - cx) ** 2 + (Yg - cy) ** 2)
    nrad = pil_noise(W, H, (60, 140), seed=seed + 5)
    flow = 0.94 + 0.12 * np.sin((rad / px(14)) + nrad * 9.0) * np.clip((dd - px(70)) / px(30), 0, 1)
    land *= flow[..., None]

    # 气候染色（中性，避免泛棕）+ 绿地带饱和
    land = land * (1 + (np.array([0.03, 0.05, -0.02], np.float32)) * west_warm[..., None])
    land = land * (1 + (np.array([-0.14, -0.06, 0.10], np.float32)) * (0.22 * east_cold[..., None]))
    green_boost = (w_grass * west_warm)[..., None] * np.array([-0.08, 0.02, -0.10], np.float32)
    land = land * (1 + green_boost * 3.0)

    # ── 山体阴影（强，光自西北）──
    gy, gx = np.gradient(height)
    shade = np.clip(0.85 + 1.5 * (gx * 0.7 - gy * 0.7), 0.62, 1.32)
    land *= shade[..., None]

    # ── 海（恢复地形轮参数：深蓝 0.50+0.20 西深东浅）──
    sea = sample("tex_sea", u * 0.6, v * 0.6, px(650))
    sea = sea * (0.50 + 0.20 * (1.0 - xx)[..., None])
    shelf = np.clip((px(30) - dist) / px(30), 0, 1) * ~mask
    sea += shelf[..., None] * np.array([22, 40, 48], np.float32)

    rgb = sea * (1 - mask_f[..., None]) + land * mask_f[..., None]

    # 绿带细节回注（气候染色会洗掉笔触，按纹理亮度差补回）
    gdet = sample("tex_grass", u, v, px(300))
    gmicro = ((gdet.mean(axis=-1) - gdet.mean()) * 0.30 * w_grass)[..., None]
    rgb += np.repeat(gmicro, 3, axis=-1) * 0.6
    img = Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8)).convert("RGBA")

    # ── 海岸线 + 碎浪 ──
    m8 = Image.fromarray((mask * 255).astype(np.uint8))
    dil = np.asarray(m8.filter(ImageFilter.MaxFilter(5)), np.int16)
    ero = np.asarray(m8.filter(ImageFilter.MinFilter(5)), np.int16)
    edge_np = (dil - ero) > 0
    edge_arr = np.zeros((H, W), np.uint8)
    edge_arr[edge_np & mask] = 200
    surf_np = (dil > 0) & (~mask)
    surf_arr = np.zeros((H, W), np.uint8)
    surf_arr[surf_np] = 120
    edge = Image.new("L", (W, H))
    edge.putdata(edge_arr.flatten())
    img = Image.composite(Image.new("RGBA", (W, H), (16, 20, 22, 255)), img, edge)
    surf = Image.new("L", (W, H))
    surf.putdata(surf_arr.flatten())
    surf = surf.filter(ImageFilter.GaussianBlur(1.2))
    img.paste(Image.new("RGBA", (W, H), (198, 222, 230, 95)), (0, 0), surf)

    # ── 等高线微影：平滑后只在山体/冰穹显示（低地噪声会把线打断成虚线梳齿）──
    hsm = gaussian_filter(height, 4)
    frac = np.mod(hsm * 12.0, 1.0)
    contour = ((frac < 0.08) & mask & (hsm > 0.38) & (dist > px(12))).astype(np.uint8) * 30
    cl = Image.new("L", (W, H))
    cl.putdata(contour.flatten())
    cl = cl.filter(ImageFilter.MaxFilter(3))
    img.paste(Image.new("RGBA", (W, H), (30, 34, 38, 255)), (0, 0), cl)

    # ── 河流 + 冰川舌（内陆起点先宽冰舌后细水线）──
    rng = random.Random(20260828 + seed)
    dome_pts = np.argwhere(dist > px(110) * 0.75)
    starts = []
    if len(dome_pts):
        order = np.argsort((dome_pts[:, 1] - cx) ** 2 + (dome_pts[:, 0] - cy) ** 2)
        pool = dome_pts[order[:max(20, len(order) // 4)]]
        picks = rng.sample([tuple(p) for p in pool], min(7, len(pool)))
        starts = picks
    d2 = ImageDraw.Draw(img)
    for sy0, sx0 in starts:
        x, y, path = int(sx0), int(sy0), []
        for _ in range(1400):
            path.append((x, y))
            if not (0 < x < W - 1 and 0 < y < H - 1) or not mask[y, x]:
                break
            best = None
            for ddy in (-1, 0, 1):
                for ddx in (-1, 0, 1):
                    if ddx == ddy == 0:
                        continue
                    vv = height[y + ddy, x + ddx] + (n1[y + ddy, x + ddx] - 0.5) * 0.03
                    if best is None or vv < best[0]:
                        best = (vv, x + ddx, y + ddy)
            if best[1] == x and best[2] == y:
                break
            x, y = best[1], best[2]
        if len(path) < px(30):
            continue
        ice = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        ImageDraw.Draw(ice).line(path, fill=(224, 234, 240, 120), width=px(9))
        img.alpha_composite(ice.filter(ImageFilter.GaussianBlur(3)))
        d2.line(path, fill=(150, 176, 188, 110), width=px(3))
        d2.line(path, fill=(34, 52, 62, 170), width=px(2))

    # ── 苔原湖泊 ──
    for _ in range(5):
        cand = np.argwhere((dist > px(30)) & (dist < px(80)))
        if not len(cand):
            continue
        ty, tx = cand[rng.randrange(len(cand))]
        el = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        rw, rh = px(rng.uniform(12, 20)), px(rng.uniform(5, 8))
        tmp = Image.new("RGBA", (rw * 2, rh * 2), (0, 0, 0, 0))
        ImageDraw.Draw(tmp).ellipse([2, 2, rw * 2 - 2, rh * 2 - 2], fill=(40, 62, 74, 150))
        tmp = tmp.rotate(rng.uniform(0, 180), expand=False, resample=Image.BICUBIC)
        el.paste(tmp, (int(tx - rw), int(ty - rh)), tmp)
        img.alpha_composite(el.filter(ImageFilter.GaussianBlur(2)))

    # ── 废墟：按陆地相对坐标分布（西旧东新；修复落海浪费/未来档为 0 的 bug）──
    eras = [
        ((0.00, 0.22), (150, 146, 132), 0.22, (7, 12)),
        ((0.22, 0.45), (118, 110, 98), 0.28, (9, 15)),
        ((0.45, 0.68), (96, 93, 91), 0.32, (11, 18)),
        ((0.68, 0.88), (70, 68, 72), 0.38, (13, 20)),
        ((0.88, 1.00), (56, 60, 68), 0.38, (13, 20)),
    ]
    for i in range(46):
        xf = (i + rng.random() * 0.8) / 46
        col = int(land_x0 + xf * (land_x1 - land_x0))   # 陆地相对，不再落海
        colmask = np.argwhere(mask[:, col]) if mask[:, col].any() else None
        if colmask is None or len(colmask) < 3:
            continue
        y = int(colmask[rng.randrange(len(colmask))][0])
        for (lo, hi_e), colr, al, (r0, r1) in eras:
            if lo <= xf < hi_e:
                radial_smudge(img, col, y, px(rng.uniform(r0, r1)), colr, al)
                if hi_e == 1.0 and rng.random() < 0.6:
                    radial_smudge(img, col + rng.randint(-16, 16), y + rng.randint(-16, 16), px(2.5), (0, 210, 235), 0.5)
                break
    # 终点前最后一程（黑门向西 150px）点缀未来废墟 + 青光点（小而淡，防油渍感）
    for _ in range(5):
        col = rng.randint(max(land_x0, land_x1 - px(150)), land_x1 - px(10))
        colmask = np.argwhere(mask[:, col]) if mask[:, col].any() else None
        if colmask is None or len(colmask) < 3:
            continue
        y = int(colmask[rng.randrange(len(colmask))][0])
        radial_smudge(img, col, y, px(rng.uniform(9, 15)), (58, 62, 70), 0.30)
        if rng.random() < 0.7:
            radial_smudge(img, col + rng.randint(-14, 14), y + rng.randint(-14, 14), px(2.5), (0, 210, 235), 0.45)

    # ── 黑门：东尖角 ──
    tip_x = int(np.max(np.argwhere(mask)[:, 1]))
    tip_y = int(np.argmax(mask[:, tip_x]))
    radial_smudge(img, tip_x - px(6), tip_y, px(40), (10, 20, 26), 0.18)
    d3 = ImageDraw.Draw(img)
    d3.ellipse([tip_x - px(20), tip_y - px(20), tip_x + px(20), tip_y + px(20)], fill=(8, 8, 10, 255))
    d3.ellipse([tip_x - px(24), tip_y - px(24), tip_x + px(24), tip_y + px(24)], outline=(140, 230, 245, 180), width=3)
    d3.ellipse([tip_x - px(30), tip_y - px(30), tip_x + px(30), tip_y + px(30)], outline=(90, 180, 205, 70), width=3)

    # ── 颗粒 + 对比/饱和增强 ──
    grain = Image.effect_noise((W, H), rng.randrange(1 << 30)).resize((W, H))
    g = np.asarray(grain, np.float32) / 255.0 - 0.5
    arr = np.asarray(img.convert("RGB"), np.float32) + g[..., None] * 5.0
    out = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))
    out = ImageEnhance.Contrast(out).enhance(1.12)
    out = ImageEnhance.Color(out).enhance(1.22)

    path = os.path.join(OUT_DIR, f"greenland_tex2_{tag}.png")
    out.save(path)
    print(f"[{tag}] {path}  黑门坐标: ({tip_x},{tip_y})")
    return path


def main():
    compose("main", seed=11)
    compose("alt", seed=97)
    tw, th = 1120, 630
    sheet = Image.new("RGB", (tw + 20, (th + 40) * 2 + 10), (18, 18, 24))
    d = ImageDraw.Draw(sheet)
    for i, tag in enumerate(("main", "alt")):
        im = Image.open(os.path.join(OUT_DIR, f"greenland_tex2_{tag}.png")).resize((tw, th), Image.LANCZOS)
        sheet.paste(im, (10, 10 + i * (th + 40)))
        d.text((12, 16 + i * (th + 40) + th), f"greenland_tex2_{tag}.png", fill=(255, 220, 120))
    review = (os.path.join(OUT_DIR, "greenland_review_tex2.png") if OUT_DIR != DEFAULT_OUT_DIR
              else os.path.join(ROOT, "docs", "地图重设计", "greenland_review_tex2.png"))
    sheet.save(review)
    print("contact →", review)


if __name__ == "__main__":
    main()
