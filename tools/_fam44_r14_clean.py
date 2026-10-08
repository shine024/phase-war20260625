# -*- coding: utf-8 -*-
"""fam44 候选C=全生图路线（2026-10-07）：R14 原卷定向手术。
mark4（R14 无地面，可救）：格导图白缝焊合（格5 白带宽10px band=7）+ 全版紫/品红描边中性化（改灰不打洞）
  + 格4 车顶星芒迁回炮口（extract_fire 真提取，勿用深底探针图）+ 烟贴边渐隐（left 语义别再反）。
105mm（R14 格3-6 整景海报化，程序不可救）：仅镜像 格2（朝向反指），如实展示天花板上拍板页。

用法:
  python tools/_fam44_r14_clean.py --unit mark4|105mm [--tag C]
产出: <R14_sheet>_<tag>.png
"""
import argparse
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

STG = ".godot/unit_review/img25_staging/"
SHEETS = {"mark4": ("ww1_mark4_R14_attack_sheet_832.png", "800,1615|793"),
          "105mm": ("ww1_105mm_R14_attack_sheet_832.png", "799,1607|797")}


def cell_box(cuts, f_idx, W, H):
    xs = [0] + [int(v) for v in cuts.split("|")[0].split(",")] + [W]
    ys = [0] + [int(v) for v in cuts.split("|")[1].split(",")] + [H]
    r, c = (f_idx - 1) // 3, (f_idx - 1) % 3
    return xs[c], ys[r], xs[c + 1], ys[r + 1]


def weld_seam(im, x, band=2):
    """竖缝焊合：x±band 列的像素用 x-(band+1) 与 x+(band+1) 水平插值重写（仅两侧均不透明的行）。"""
    px = im.load()
    W, H = im.size
    n = 0
    for y in range(H):
        l, r = px[x - band - 1, y], px[x + band + 1, y]
        if l[3] < 40 or r[3] < 40:
            continue
        for i, xx in enumerate(range(x - band, x + band + 1)):
            t = (i + 1) / (2 * band + 2)
            px[xx, y] = (int(l[0] + (r[0] - l[0]) * t), int(l[1] + (r[1] - l[1]) * t),
                         int(l[2] + (r[2] - l[2]) * t),
                         int(l[3] + (r[3] - l[3]) * t))
        n += 1
    print(f"  [weld] x={x} 焊 {n} 行", flush=True)


def recolor_purple(im):
    """全版紫/品红描边中性化（R14 风格病：车缘紫 rim + 烟缘粉边，六格皆有）。
    谓词 max(r,b)-g>40 且 b>=r-10 且 min(r,b)>90 且非火色 → 改灰（保 alpha，不打洞）。"""
    px = im.load()
    n = 0
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a < 60:
                continue
            fire = (r > 185 and r - b > 80) or (r > 230 and g > 200 and r - b > 18)
            if fire:
                continue
            if max(r, b) - g > 40 and b >= r - 10 and min(r, b) > 90:
                v = (r + g + b) // 3
                px[x, y] = (v, v, v, a)
                n += 1
    print(f"  [purple] 全版中性化 {n}px", flush=True)


def kill_rect(im, rect):
    """任意色矩形清除（烟黑剪影/白热芯这类非火色残留）。"""
    px = im.load()
    x0, y0, x1, y1 = rect
    n = 0
    for y in range(y0, y1):
        for x in range(x0, x1):
            if px[x, y][3]:
                px[x, y] = (0, 0, 0, 0)
                n += 1
    print(f"  [killrect] rect{rect} 清 {n}px", flush=True)


def kill_fire(im, rect, mirror_zone=None):
    """火色掩码杀（星芒+激光梁）：矩形内火色→透明。"""
    px = im.load()
    x0, y0, x1, y1 = rect
    n = 0
    for y in range(y0, y1):
        for x in range(x0, x1):
            r, g, b, a = px[x, y]
            if a < 40:
                continue
            fire = (r > 185 and (r - b) > 80) or (r > 230 and g > 200 and (r - b) > 18)
            if fire:
                px[x, y] = (r, g, b, 0)
                n += 1
    print(f"  [killfire] rect{rect} 杀 {n}px", flush=True)


def kill_cols(im, x0, x1):
    """整列杀透明：格导图边带（亮竖带/细线）不可渐隐只能清除。"""
    px = im.load()
    n = 0
    for y in range(im.height):
        for x in range(x0, x1):
            if px[x, y][3]:
                px[x, y] = (0, 0, 0, 0)
                n += 1
    print(f"  [killcols] x[{x0},{x1}) 清 {n}px", flush=True)


def smoke_patch(im, box, src_box, feather=24, blur=12):
    """烟体矩形洞修补：从同格正上方净烟带裁片（竖向微伸），四边羽化后盖回。"""
    x0, y0, x1, y1 = box
    w, h = x1 - x0, y1 - y0
    src = im.crop(src_box).resize((w, h), Image.LANCZOS).convert("RGBA")
    m = Image.new("L", (w, h), 0)
    ImageDraw.Draw(m).rectangle((feather, feather, w - feather, h - feather), fill=255)
    m = m.filter(ImageFilter.GaussianBlur(blur))
    src.putalpha(ImageChops.multiply(src.getchannel("A"), m))
    base = im.crop(box)
    base.alpha_composite(src)
    im.paste(base, (x0, y0))
    print(f"  [patch] {box} <- {src_box} 羽化 {feather}px", flush=True)


def fade_edge(im, x0, x1, left=False):
    """竖直贴边渐隐：left=False 在 x0 端→0 向 x1 升满；left=True 在 x1 端→0 向 x0 升满。"""
    px = im.load()
    w = x1 - x0
    n = 0
    for y in range(im.height):
        for i in range(w):
            x = x1 - 1 - i if left else x0 + i
            r, g, b, a = px[x, y]
            if a:
                px[x, y] = (r, g, b, a * (i + 1) // (w + 1))
                n += 1
    print(f"  [fade] x[{x0},{x1}) left={left} 渐隐 {n}px", flush=True)


def measure_muzzle(im, cell, y_band, run=6):
    """炮口尖：y_band 内左起第一列（竖向连续**深色车体**像素 ≥run，浅色烟不算）。"""
    px = im.load()
    x0, y0, x1, y1 = cell
    for x in range(x0, x1):
        cnt = best = 0
        for y in range(*y_band):
            r, g, b, a = px[x, y]
            ok = a > 60 and r + g + b < 400
            best = best + 1 if ok else 0
            cnt = max(cnt, best)
        if cnt >= run:
            return x, (y_band[0] + y_band[1]) // 2
    return x0 + 40, (y_band[0] + y_band[1]) // 2


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--unit", required=True, choices=SHEETS)
    ap.add_argument("--tag", default="C")
    args = ap.parse_args()
    fname, cuts = SHEETS[args.unit]
    im = Image.open(STG + fname).convert("RGBA")
    W, H = im.size

    if args.unit == "105mm":
        x0, y0, x1, y1 = cell_box(cuts, 2, W, H)
        c2 = im.crop((x0, y0, x1, y1)).transpose(Image.FLIP_LEFT_RIGHT)
        im.paste(c2, (x0, y0))
        print("  [105mm] 格2 已镜像（朝向反指修复）")
    else:
        # 焊缝：模型把格导图细线画成 1px 透明裂缝（C_n 上看位置会被归一化映射骗，
        # 必须回源坐标定位——格5 缝真身在 x=902，877/881 都是映射假象）
        weld_seam(im, 1763)              # 格3 火球竖缝
        weld_seam(im, 902, band=3)       # 格5 火球透明裂缝（901/904 半透唇边一并盖住）
        # 全版紫/品红描边中性化（车缘紫 rim + 烟缘粉边 → 改灰）
        recolor_purple(im)
        # 格4：车顶星芒宿主=整片顶烟库，随烟库一起清除（见下）；只兜底甲板线以下的火色残边
        kill_fire(im, (545, 1165, 645, 1280))
        kill_fire(im, (620, 1165, 800, 1250))
        # 格4 顶烟库（星芒宿主）整体清除——修补尝试两轮（羽化贴片/任意色清）都比病灶显眼，
        # 定案：格4=干净后坐帧，烟量由 3/5 帧承担。左缘+上缘羽化防新硬切，底缘止步甲板上方。
        px = im.load()
        for y in range(995, 1218):
            ry = 1.0 - min(1.0, (y - 995) / 20.0)  # 上缘保留度 1→0
            for x in range(430, 800):
                rx = 1.0 - min(1.0, (x - 430) / 40.0)  # 左缘保留度 1→0
                r, g, b, a = px[x, y]
                if a:
                    keep = max(ry, rx)  # 内部 0=清空，羽化带线性升到 1
                    px[x, y] = (r, g, b, int(a * keep) if keep else 0)
        print("  [bank] 格4 顶烟库清除 x[430,800) y[995,1218)", flush=True)
        mx, my = measure_muzzle(im, cell_box(cuts, 4, W, H), (1205, 1240))
        print(f"  [c4] 炮口量测 ({mx},{my})")
        sys.path.insert(0, "tools")
        from _fam44_fx_transplant import extract_fire
        spr = extract_fire(Image.open(STG + fname).convert("RGBA"),
                           (420, 1090, 700, 1330))
        cw = 800
        w0 = spr.width
        room = mx - 0
        overlap = 40
        if w0 - overlap > room:
            k = (room + overlap) / w0
            spr = spr.resize((max(1, int(w0 * k)), max(1, int(spr.height * k))), Image.LANCZOS)
            print(f"  [c4] fit-scale x{k:.2f} -> {spr.size}")
        cell = cell_box(cuts, 4, W, H)
        tmp = Image.new("RGBA", (cw, cell[3] - cell[1]), (0, 0, 0, 0))
        tmp.paste(spr, (mx - spr.width + overlap, my - spr.height // 2 - cell[1]), spr)
        base = im.crop((cell[0], cell[1], cell[2], cell[3]))
        base.alpha_composite(tmp)
        im.paste(base, (cell[0], cell[1]))
        # 烟贴边渐隐（硬切→消隐）。格导图右缘白带 x≈2404-2412 整列杀（渐隐压不死后又浮出），
        # 真烟止于 ~2402：先杀带再渐隐到新边界
        kill_cols(im, 2400, W)
        fade_edge(im, 2330, 2400, left=True)  # 格3+格6 右缘（全高一次覆盖，70px 缓坡）
        fade_edge(im, 758, 800, left=True)    # 格4 右缘烟（格界 800 处归零）
        fade_edge(im, 0, 42)                  # 格4 左缘烟（x=0 处归零）

    out = STG + fname[:-4] + f"_{args.tag}.png"
    im.save(out)
    print("OK", out)


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    main()
