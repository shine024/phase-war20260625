# -*- coding: utf-8 -*-
"""fam44 FX 移植（候选B，2026-10-07）：从 R14 生图里裁「有机火光精灵」，贴到 R11 清板的炮口坐标。
裁火不裁车：火色掩码 + 品红混色杀 + 去孤立噪点 + alpha 羽化；烟仍用程序 puff（候选A 已验证）。

用法:
  python tools/_fam44_fx_transplant.py \
    --base <R11_fix_sheet.png> --cuts "x1,x2|y1" --muzzle-json <spec.json> \
    --harvest "id=raw.png|x0,y0,x1,y1|m;id2=..." \
    --plan-json <plan.json> [--probe-only] [--tag fx2]

  harvest 字段用 | 分隔（Windows 路径含冒号）；尾段 m = 水平镜像。
  plan: {"3": {"sprite": "m_c3", "scale": 1.0, "overlap": 24, "dy": 0, "puff": [1.0, 200]}, ...}
        sprite/puff 均可省略；overlap=火光右缘盖过炮口尖的像素。
产出: <base>_<tag>.png + <base>_<tag>_preview.gif；--probe-only 时另存 <id>_sprite.png（深底预览）
"""
import argparse
import json
import os
import sys

from PIL import Image, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from _fam44_fx_comp import make_puff  # noqa: E402


def _keep_largest(keep, W, H):
    """只保留最大连通域（8 邻接）：甩掉火光照亮的炮架条/地面块。"""
    comp_id = [0] * (W * H)
    sizes = [0]
    cid = 0
    for start in range(W * H):
        if not keep[start] or comp_id[start]:
            continue
        cid += 1
        stack = [start]
        comp_id[start] = cid
        n = 0
        while stack:
            i = stack.pop()
            n += 1
            x = i % W
            y = i // W
            for dy in (-1, 0, 1):
                yy = y + dy
                if yy < 0 or yy >= H:
                    continue
                for dx in (-1, 0, 1):
                    xx = x + dx
                    if xx < 0 or xx >= W:
                        continue
                    j = yy * W + xx
                    if keep[j] and not comp_id[j]:
                        comp_id[j] = cid
                        stack.append(j)
        sizes.append(n)
    if not cid:
        return keep
    big = max(range(1, cid + 1), key=lambda c: sizes[c])
    print(f"  [components] {cid} 个，最大 {sizes[big]}px", flush=True)
    return bytearray(1 if comp_id[i] == big else 0 for i in range(W * H))


def _hole_mask(keep, W, H, max_bridge=12):
    """内部空洞（洪泛不可达）+ 竖向细缝（≤max_bridge 且两侧有火）→ 待填。"""
    outside = bytearray(W * H)
    stack = []
    for y in (0, H - 1):
        for x in range(W):
            i = y * W + x
            if not keep[i]:
                outside[i] = 1
                stack.append(i)
    for x in (0, W - 1):
        for y in range(H):
            i = y * W + x
            if not keep[i] and not outside[i]:
                outside[i] = 1
                stack.append(i)
    while stack:
        i = stack.pop()
        x = i % W
        y = i // W
        for dy in (-1, 0, 1):
            yy = y + dy
            if yy < 0 or yy >= H:
                continue
            for dx in (-1, 0, 1):
                xx = x + dx
                if xx < 0 or xx >= W:
                    continue
                j = yy * W + xx
                if not keep[j] and not outside[j]:
                    outside[j] = 1
                    stack.append(j)
    fill = bytearray(W * H)
    for i in range(W * H):
        if not keep[i] and not outside[i]:
            fill[i] = 1
    n_hole = sum(fill)
    for x in range(W):  # 竖向细缝桥接（格线缝/小豁口）
        y = 0
        while y < H:
            if keep[y * W + x]:
                y += 1
                continue
            y0 = y
            while y < H and not keep[y * W + x]:
                y += 1
            if 0 < y0 and y < H and (y - y0) <= max_bridge:
                for yy in range(y0, y):
                    fill[yy * W + x] = 1
    n_hole = sum(fill) - n_hole
    print(f"  [holes] 空洞+桥接 {sum(fill)}px（桥接 {n_hole}px）", flush=True)
    return fill


def _onion_fill(im, fill, W, H):
    """洋葱剥皮扩散填色：洞像素逐轮取已定邻居的均值。"""
    px = im.load()
    remaining = {i for i in range(W * H) if fill[i]}
    rounds = 0
    while remaining and rounds < 500:
        rounds += 1
        frontier = [i for i in remaining
                    if any(0 <= (i // W + dy) < H and 0 <= (i % W + dx) < W
                           and not fill[(i // W + dy) * W + (i % W + dx)]
                           for dy in (-1, 0, 1) for dx in (-1, 0, 1))]
        if not frontier:
            break
        for i in frontier:
            x = i % W
            y = i // W
            rs = gs = bs = n = 0
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    if dx == 0 and dy == 0:
                        continue
                    xx, yy = x + dx, y + dy
                    if xx < 0 or xx >= W or yy < 0 or yy >= H:
                        continue
                    j = yy * W + xx
                    if fill[j]:
                        continue
                    r, g, b, a = px[xx, yy]
                    rs += r
                    gs += g
                    bs += b
                    n += 1
            if n:
                px[x, y] = (rs // n, gs // n, bs // n, 255)
        for i in frontier:
            fill[i] = 0
            remaining.discard(i)
    print(f"  [onion] {rounds} 轮填完", flush=True)


def extract_fire(raw, rect, mirror=False):
    """在 rect 内按火色掩码提取精灵：最大连通域+空洞填充，返回 bbox 裁剪+羽化 RGBA。"""
    im = raw.crop(rect).convert("RGBA")
    W, H = im.size
    px = im.load()
    keep = bytearray(W * H)
    n_fire = 0
    for y in range(H):
        row = y * W
        for x in range(W):
            r, g, b, a = px[x, y]
            if a < 40:
                continue
            fire = (r > 185 and (r - b) > 80) or (r > 230 and g > 200 and (r - b) > 18)
            if not fire:
                continue
            if g < 0.5 * r and b > 0.35 * r:  # 品红混色边（粉橙过渡）
                continue
            keep[row + x] = 1
            n_fire += 1
    # 去孤立噪点：3x3 邻居 <3 则弃
    keep = bytearray(
        0 if keep[i] and (sum(keep[i - W - 1:i - W + 2]) + sum(keep[i - 1:i + 2])
                          + sum(keep[i + W - 1:i + W + 2]) - keep[i]) < 3 else keep[i]
        for i in range(W * H))
    full = bytearray(keep)  # 去噪后的全量火掩码
    total_fire = sum(full)
    keep = _keep_largest(full, W, H)
    # 膨胀掩码上再取最大连通域：格线细缝/小豁口被吸收进主体，
    # 主体∩原掩码的补集（缝+洞+晕）全部洋葱填色；缝太宽则逐级加大膨胀半径
    dl = full
    for rad in (2, 4, 7):
        dim = Image.new("L", (W, H), 0)
        dim.putdata([255 if v else 0 for v in full])
        dim = dim.filter(ImageFilter.MaxFilter(2 * rad + 1))
        dil = bytearray(1 if v else 0 for v in dim.getdata())
        dl = _keep_largest(dil, W, H)
        got = sum(1 for i in range(W * H) if full[i] and dl[i])
        print(f"  [dilate] r={rad} 最大域裹住 {got}/{total_fire}", flush=True)
        if got >= total_fire * 0.8:
            break
    keep2 = bytearray(keep[i] and dl[i] for i in range(W * H))
    fill = bytearray(dl[i] and not keep2[i] for i in range(W * H))
    print(f"  [holes] 缝+洞+晕 {sum(fill)}px 待填", flush=True)
    had = bytearray(fill)  # onion 会就地清零，先留底
    _onion_fill(im, fill, W, H)
    keep = bytearray(keep2[i] or had[i] for i in range(W * H))
    keep = bytearray(keep[i] or fill[i] for i in range(W * H))
    xs = [i % W for i, v in enumerate(keep) if v]
    ys = [i // W for i, v in enumerate(keep) if v]
    if not xs:
        print(f"  [extract] rect{rect}: 0 px -> EMPTY", flush=True)
        return None
    x0, x1, y0, y1 = min(xs), max(xs) + 1, min(ys), max(ys) + 1
    spr = Image.new("RGBA", (x1 - x0, y1 - y0), (0, 0, 0, 0))
    src = im.crop((x0, y0, x1, y1))
    spx, out = src.load(), spr.load()
    for y in range(y1 - y0):
        for x in range(x1 - x0):
            if keep[(y + y0) * W + (x + x0)]:
                out[x, y] = spx[x, y]
    a = spr.getchannel("A").filter(ImageFilter.GaussianBlur(1.5))
    ap = a.load()
    wS, hS = spr.size
    ramp = 5  # bbox 边缘 alpha 渐变：收割矩形万一贴到火瓣，直切边软化成消隐
    for yy in range(hS):
        for xx in range(wS):
            d = min(xx, yy, wS - 1 - xx, hS - 1 - yy)
            if d < ramp:
                v = ap[xx, yy]
                ap[xx, yy] = v * (d + 1) // (ramp + 1)
    spr.putalpha(a)
    if mirror:
        spr = spr.transpose(Image.FLIP_LEFT_RIGHT)
    print(f"  [extract] rect{rect}: fire={n_fire} bbox=({x0},{y0})-({x1},{y1}) "
          f"sprite={spr.size} mirror={mirror}", flush=True)
    return spr


def paste_clipped(sheet, cell, fx, px_, py_):
    """硬裁剪在本格内部：贴到格大小画布再合成，越界部分自动裁掉。"""
    cell_im = sheet.crop(cell)
    tmp = Image.new("RGBA", cell_im.size, (0, 0, 0, 0))
    tmp.paste(fx, (px_ - cell[0], py_ - cell[1]), fx)
    cell_im.alpha_composite(tmp)
    sheet.paste(cell_im, (cell[0], cell[1]))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--base", required=True)
    ap.add_argument("--cuts", required=True)
    ap.add_argument("--muzzle-json", required=True)
    ap.add_argument("--harvest", required=True)
    ap.add_argument("--plan-json", required=True)
    ap.add_argument("--probe-only", action="store_true")
    ap.add_argument("--tag", default="fx2")
    args = ap.parse_args()

    here = os.path.dirname(os.path.abspath(args.base))
    sheet = Image.open(args.base).convert("RGBA")
    spec = json.load(open(args.muzzle_json, encoding="utf-8"))
    xs = [0] + [int(v) for v in args.cuts.split("|")[0].split(",")] + [sheet.width]
    ys = [0] + [int(v) for v in args.cuts.split("|")[1].split(",")] + [sheet.height]
    plan = json.load(open(args.plan_json, encoding="utf-8"))

    sprites = {}
    for item in args.harvest.split(";"):
        item = item.strip()
        if not item:
            continue
        sid, rest = item.split("=", 1)
        parts = rest.split("|")
        path = parts[0]
        rect = tuple(int(v) for v in parts[1].split(","))
        mirror = len(parts) > 2 and "m" in parts[2]
        raw = Image.open(path).convert("RGBA")
        spr = extract_fire(raw, rect, mirror)
        if spr is None:
            sys.exit(f"harvest {sid} 为空，中止")
        sprites[sid] = spr
        if args.probe_only:
            bg = Image.new("RGBA", spr.size, (23, 26, 32, 255))
            bg.alpha_composite(spr)
            out = os.path.join(here, f"_sprite_{sid}.png")
            bg.convert("RGB").save(out)
            print("  probe ->", out, flush=True)
    if args.probe_only:
        print("PROBE ONLY DONE")
        return

    for f_idx_s, ops in plan.items():
        f_idx = int(f_idx_s)
        r, c = (f_idx - 1) // 3, (f_idx - 1) % 3
        cell = (xs[c], ys[r], xs[c + 1], ys[r + 1])
        cw, ch = cell[2] - cell[0], cell[3] - cell[1]
        mp = spec[f_idx_s]
        mx, my = int(mp["mx"]), int(mp["my"])
        if "sprite" in ops:
            spr = sprites[ops["sprite"]]
            if ops.get("mirror"):
                spr = spr.transpose(Image.FLIP_LEFT_RIGHT)
            scale = float(ops.get("scale", 1.0))
            overlap = int(ops.get("overlap", 16))
            dy = int(ops.get("dy", 0))
            w = max(1, int(spr.width * scale))
            h = max(1, int(spr.height * scale))
            # 装不下则二次缩：左伸不超过 (mx-cell_x0)
            room = mx - cell[0]
            if w - overlap > room:
                k = (room + overlap) / w
                w, h = max(1, int(w * k)), max(1, int(h * k))
                print(f"  [{f_idx}] fit-scale x{k:.2f} -> {w}x{h}", flush=True)
            fx = spr.resize((w, h), Image.LANCZOS)
            px_ = mx - (w - overlap)
            py_ = my - h // 2 + dy
            paste_clipped(sheet, cell, fx, px_, py_)
            print(f"  [{f_idx}] sprite={ops['sprite']} {w}x{h} at ({px_},{py_}) cell={cell}",
                  flush=True)
        if "puff" in ops:
            sc, alpha = float(ops["puff"][0]), int(ops["puff"][1])
            pw, ph = int(cw * 0.30 * sc), int(ch * 0.22 * sc)
            fx = make_puff(pw, ph, alpha, seed=f_idx * 10 + int(sc * 10))
            px_ = int(mx - fx.width * 0.9)
            py_ = int(my - fx.height * 0.75)
            paste_clipped(sheet, cell, fx, px_, py_)
            print(f"  [{f_idx}] puff {pw}x{ph} at ({px_},{py_})", flush=True)

    out = args.base[:-4] + f"_{args.tag}.png"
    sheet.save(out)
    frames = []
    for f_idx in range(6):
        r, c = f_idx // 3, f_idx % 3
        cell = sheet.crop((xs[c], ys[r], xs[c + 1], ys[r + 1]))
        bg = Image.new("RGBA", cell.size, (17, 17, 20, 255))
        bg.alpha_composite(cell)
        frames.append(bg.convert("RGB").resize((384, 384)))
    gif = out[:-4] + "_preview.gif"
    frames[0].save(gif, save_all=True, append_images=frames[1:], duration=140, loop=0)
    print("OK", out)
    print("OK", gif)


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    main()
