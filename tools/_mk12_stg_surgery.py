# -*- coding: utf-8 -*-
"""MK12 重掷六案 staging 外科手术（2026-10-05）。
语义：每次运行都从 art_backup_mk12_stg 的备份重放全部 op（幂等，可反复调框重跑）。
首次运行先 backup_once 抓取当前 staging 状态。
op 类型：
  mirror(f)                    镜像帧（f: 1-based）
  copy(fsrc, fdst)             帧整格复制（fsrc 内容贴到 fdst）
  kill(f, box, pred)           杀框内命中 px（置透明）
  inpaint(f, box, pred)        杀框内命中 px 并水平近邻填充
  fade(f, box, pred, x0, x1)   框内命中 px alpha 沿 x 从 1 渐变到 0（x0<x1, 0-1 frac）
  recolor(f, box, pred, hue)   框内命中 px 色相改写（保留 s/v）
谓词：any/white/ghost/plate/skin/warm/smoke
用法：
  python tools/_mk12_stg_surgery.py dry   # 只打印命中数
  python tools/_mk12_stg_surgery.py run   # 备份+实跑+渲染
"""
import io
import os
import sys
import colorsys
from collections import deque

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STG = os.path.join(ROOT, ".godot", "unit_review", "img25_staging")
BKS = os.path.join(ROOT, ".godot", "art_backup_mk12_stg")
OUTD = os.path.join(ROOT, ".godot", "unit_review", "mk12_deploy_check")
CW = 832  # staging 格边长 (3x2)

SHEETS = {
    "cold_sup_bmp1_x": "_R1",
    "fut_arm_hovertank": "_R1",
    "mod_arty_m270": "_R2",
    "ww1_arm_rolls": "_R1",
    "ww1_inf_cavalry": "_R1",
    "ww2_air_dive_bomber": "_R2",
}


# ---------- 谓词 ----------
def P_any(r, g, b, a):
    return a > 0

def P_white(r, g, b, a):  # 拼贴白竖线
    h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
    return v > 0.75 and s < 0.3

def P_plate(r, g, b, a):  # cavalry 中性灰板: 通道差<=6, v0.58-0.72
    mx, mn = max(r, g, b), min(r, g, b)
    v = mx / 255.0
    return (mx - mn) <= 6 and 0.58 * 255 <= mx <= 0.72 * 255

def P_skin(r, g, b, a):  # rolls 裸臂: 暖肤色, 排火焰核心
    h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
    return (8 / 360 <= h <= 45 / 360 and 0.20 <= s <= 0.80
            and 0.38 <= v <= 0.95 and not (v > 0.88 and s > 0.5))

def P_warm(r, g, b, a):  # hovertank 橙爆+暖光沿
    h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
    return h < 70 / 360 and s > 0.3 and v > 0.5

def P_smoke(r, g, b, a):  # hovertank 白烟
    h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
    return v > 0.5 and s < 0.35

PREDS = {"any": P_any, "white": P_white, "plate": P_plate,
         "skin": P_skin, "warm": P_warm, "smoke": P_smoke}


# ---------- 基元 ----------
def load(key):
    name = "%s%s_attack_sheet_832.png" % (key, SHEETS[key])
    bk = os.path.join(BKS, name)
    # 幂等重放: 备份存在则从备份加载 (否则 STG 原态, backup_once 已抓)
    p = bk if os.path.exists(bk) else os.path.join(STG, name)
    for i in range(3):
        im = Image.open(p)
        im.load()  # 强制完整解码
        im = im.convert("RGBA")
        small = im.resize((64, 64))
        n = sum(1 for q in list(small.getdata()) if q[3] > 0)
        if n > 200:
            return im
        print("    [load#%d] %s 解码疑似空 (非透明%d/4096), 重试" % (i, key, n))
    raise RuntimeError("load 解码异常: " + key)

def fr(im, f):  # 1-based, 3x2 行主序网格
    r, c = divmod(f - 1, 3)
    return im.crop((c * CW, r * CW, (c + 1) * CW, (r + 1) * CW))

def put(im, f, frame):
    r, c = divmod(f - 1, 3)
    im.paste(frame, (c * CW, r * CW))

def backup_once():
    os.makedirs(BKS, exist_ok=True)
    for key, suf in SHEETS.items():
        dst = os.path.join(BKS, "%s%s_attack_sheet_832.png" % (key, suf))
        if not os.path.exists(dst):
            Image.open(os.path.join(STG, "%s%s_attack_sheet_832.png" % (key, suf))).convert("RGBA").save(dst)
            print("BK %s" % key)


# ---------- op 实现 ----------
def op_kill(im, f, box, pred_name, inpaint=False):
    c = fr(im, f)
    px = c.load()
    x0, y0, x1, y1 = int(box[0] * CW), int(box[1] * CW), int(box[2] * CW), int(box[3] * CW)
    pred = PREDS[pred_name]
    hit = [(x, y) for y in range(y0, y1) for x in range(x0, x1)
           if px[x, y][3] > 0 and pred(*px[x, y])]
    if inpaint and hit:
        kill = set(hit)
        for (x, y) in hit:
            fill = None
            for d in range(1, CW):
                l, r_ = x - d, x + d
                if l >= 0 and (l, y) not in kill and px[l, y][3] > 0 and not pred(*px[l, y]):
                    fill = px[l, y][:3]
                    break
                if r_ < CW and (r_, y) not in kill and px[r_, y][3] > 0 and not pred(*px[r_, y]):
                    fill = px[r_, y][:3] if fill is None else tuple((a + b) // 2 for a, b in zip(fill, px[r_, y][:3]))
                    break
            if fill:
                px[x, y] = (fill[0], fill[1], fill[2], px[x, y][3])
            else:
                px[x, y] = (0, 0, 0, 0)
    else:
        for (x, y) in hit:
            px[x, y] = (0, 0, 0, 0)
    if hit:
        put(im, f, c)  # PIL crop 是副本, 必须贴回
    return len(hit)

def op_mirror(im, f):
    put(im, f, fr(im, f).transpose(Image.FLIP_LEFT_RIGHT))
    return 1

def op_copy(im, fsrc, fdst):
    put(im, fdst, fr(im, fsrc))
    return 1

def op_patch(im, fsrc, fdst, box):
    """区域贴片: fsrc 的 box 内容覆盖 fdst 同 box (乘员区用干净帧同区覆盖)"""
    x0, y0 = int(box[0] * CW), int(box[1] * CW)
    x1, y1 = int(box[2] * CW), int(box[3] * CW)
    c = fr(im, fdst)
    c.paste(fr(im, fsrc).crop((x0, y0, x1, y1)), (x0, y0))
    put(im, fdst, c)
    return (x1 - x0) * (y1 - y0)

def op_fade(im, f, box, pred_name, x0, x1):
    c = fr(im, f)
    px = c.load()
    y0, y1 = int(box[1] * CW), int(box[3] * CW)
    xa, xb = int(x0 * CW), int(x1 * CW)
    pred = PREDS[pred_name]
    n = 0
    for y in range(y0, y1):
        for x in range(max(xa, 0), min(xb, CW)):
            r, g, b, a = px[x, y]
            if a <= 0 or not pred(r, g, b, a):
                continue
            t = (x - xa) / float(xb - xa)
            # clamp: 渐变带外 (x<xa / x>xb) 不得放大/溢出 alpha
            na = int(a * max(0.0, min(1.0, 1.0 - t)))
            if na != a:
                px[x, y] = (r, g, b, na)
                n += 1
    if n:
        put(im, f, c)
    return n

def op_recolor(im, f, box, pred_name, hue):
    c = fr(im, f)
    px = c.load()
    x0, y0, x1, y1 = int(box[0] * CW), int(box[1] * CW), int(box[2] * CW), int(box[3] * CW)
    pred = PREDS[pred_name]
    n = 0
    for y in range(y0, y1):
        for x in range(x0, x1):
            r, g, b, a = px[x, y]
            if a <= 0 or not pred(r, g, b, a):
                continue
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            nr, ng, nb = colorsys.hsv_to_rgb(hue, s, v)
            px[x, y] = (int(nr * 255), int(ng * 255), int(nb * 255), a)
            n += 1
    if n:
        put(im, f, c)
    return n


# ---------- 手术表 ----------
# rolls 不在此表: R2 f5 躯干废格 → 第三掷, 待 R3 审后另定
PLAN = {
    # m270: cell0|1 边界拼贴白线 (y322-442 → frac 0.387-0.531)
    "mod_arty_m270": [
        # f1 焰柱内矩形白块主体+白块杀后缝右橙残焰, 一刀 any (焰心白 x<745 不伤)
        ("kill", 1, (0.895, 0.36, 1.0, 0.585), "any"),
        # f2 cell 左缘窄条
        ("kill", 2, (0.0, 0.36, 0.015, 0.56), "white"),
        # f6 发射箱穿出异物炮杆 (x67-366, y393-445; 右界避箱左缘365, 下界避舱顶522)
        ("kill", 6, (0.055, 0.455, 0.435, 0.555), "any"),
    ],
    # cavalry: 灰板由簇限特化路径处理 (PLAN 留空键位)
    "ww1_inf_cavalry": [],
    # hovertank: f1=f2 的镜像错帧 → 翻正; f5 橙爆→紫(h275) + 烟团右缘直切边羽化
    "fut_arm_hovertank": [
        ("mirror", 1),
        ("recolor", 5, (0.064, 0.477, 0.765, 0.714), "warm", 275 / 360),
        ("fade", 5, (0.0, 0.28, 1.0, 0.60), "smoke", 0.930, 0.961),
    ],
    # dive: f1 := f6 平飞基线
    "ww2_air_dive_bomber": [("copy", 6, 1)],
    # rolls R3-R1: f3 整帧镜像翻正; 乘员区用干净帧 f6 大区贴片覆盖
    # (v1 框偏小教训: 乘员头顶 y<0.44 露出 + 手臂伸至 0.53-0.65 在框外;
    #  网格目测: f3 乘员块 0.465-0.535, f4 头 0.58-0.65 + 黄块 0.46-0.49, 焰右缘 0.255)
    "ww1_arm_rolls": [
        ("mirror", 3),
        ("patch", 6, 3, (0.245, 0.40, 0.545, 0.67)),
        ("patch", 6, 4, (0.24, 0.40, 0.655, 0.67)),
        ("patch", 6, 5, (0.21, 0.36, 0.545, 0.67)),
        # f3 焰切出的翼子板残片 (前轮弧 y0.66 之下不碰)
        ("kill", 3, (0.13, 0.60, 0.195, 0.658), "any"),
        # f3 焰右缘直切边羽化 (加宽渐变带; y 限焰体)
        ("fade", 3, (0.0, 0.30, 0.245, 0.58), "warm", 0.15, 0.245),
        # f3 贴片界暗橙残块 (v<0.5 不命中 warm, 定点杀贴片外部分)
        ("kill", 3, (0.222, 0.545, 0.245, 0.615), "any"),
    ],
}


def plate_clusters(c, min_n=800, dil=1):
    """cavalry 灰板簇限杀: 簇>=min_n 的 plate px, 膨胀 dil"""
    px = c.load()
    w, h = c.size
    seen = [[False] * h for _ in range(w)]
    kill = set()
    for yy in range(h):
        for xx in range(w):
            if seen[yy][xx]:
                continue
            r, g, b, a = px[xx, yy]
            if a <= 0 or not P_plate(r, g, b, a):
                seen[yy][xx] = True
                continue
            q = deque([(xx, yy)])
            seen[yy][xx] = True
            pts = []
            while q:
                x, y = q.popleft()
                pts.append((x, y))
                for dx in (-1, 0, 1):
                    for dy in (-1, 0, 1):
                        nx, ny = x + dx, y + dy
                        if 0 <= nx < w and 0 <= ny < h and not seen[ny][nx]:
                            seen[ny][nx] = True
                            r2, g2, b2, a2 = px[nx, ny]
                            if a2 > 0 and P_plate(r2, g2, b2, a2):
                                q.append((nx, ny))
            if len(pts) >= min_n:
                for (x, y) in pts:
                    for dx in range(-dil, dil + 1):
                        for dy in range(-dil, dil + 1):
                            nx, ny = x + dx, y + dy
                            if 0 <= nx < w and 0 <= ny < h:
                                kill.add((nx, ny))
    return kill


def run(dry):
    backup_once()
    warn0 = []
    touched = {}
    for key, ops in PLAN.items():
        im = load(key)
        log = []
        for op in ops:
            kind = op[0]
            if kind == "kill":
                n = op_kill(im, op[1], op[2], op[3])
                log.append("kill f%d %s %s=%d" % (op[1], op[2], op[3], n))
                if n == 0:
                    warn0.append((key, op))
            elif kind == "inpaint":
                n = op_kill(im, op[1], op[2], op[3], inpaint=True)
                log.append("inpaint f%d %s %s=%d" % (op[1], op[2], op[3], n))
                if n == 0:
                    warn0.append((key, op))
            elif kind == "mirror":
                n = op_mirror(im, op[1])
                log.append("mirror f%d" % op[1])
            elif kind == "copy":
                n = op_copy(im, op[1], op[2])
                log.append("copy f%d->f%d" % (op[1], op[2]))
            elif kind == "patch":
                n = op_patch(im, op[1], op[2], op[3])
                log.append("patch f%d->f%d %s" % (op[1], op[2], op[3]))
            elif kind == "fade":
                n = op_fade(im, op[1], op[2], op[3], op[4], op[5])
                log.append("fade f%d %s=%.0f-%.0f=%d" % (op[1], op[3], op[4], op[5], n))
                if n == 0:
                    warn0.append((key, op))
            elif kind == "recolor":
                n = op_recolor(im, op[1], op[2], op[3], op[4])
                log.append("recolor f%d %s h%d=%d" % (op[1], op[3], int(op[4] * 360), n))
                if n == 0:
                    warn0.append((key, op))
        # cavalry 灰板簇限杀单独处理 (PLAN 里 kill→簇限替换)
        touched[key] = (im, log)

    # cavalry 特殊: 簇限 plate 杀
    if "ww1_inf_cavalry" in PLAN:
        im, log = touched["ww1_inf_cavalry"]
        log = [x for x in log if "plate" not in x]
        for f in range(1, 7):
            c = fr(im, f)
            kill = plate_clusters(c)
            px = c.load()
            for (x, y) in kill:
                px[x, y] = (0, 0, 0, 0)
            if kill:
                put(im, f, c)  # PIL crop 是副本, 必须贴回
            log.append("plate f%d=%d" % (f, len(kill)))
            if not kill:
                warn0.append(("ww1_inf_cavalry", ("plate", f)))
        touched["ww1_inf_cavalry"] = (im, log)

    for key, (im, log) in touched.items():
        print("%-22s %s" % (key, " | ".join(log)))
    print("WARN-0: %d" % len(warn0))
    for key, op in warn0:
        print("  !! %s %s" % (key, op))
    if dry:
        print("DRY — 未写盘")
        return 1 if warn0 else 0
    if warn0:
        print("RUN 拒绝: WARN-0=%d (框/谓词错, 先修表)" % len(warn0))
        return 1
    for key, (im, log) in touched.items():
        im.save(os.path.join(STG, "%s%s_attack_sheet_832.png" % (key, SHEETS[key])))
        print("SAVED %s" % key)
    return 0


def render():
    for key, suf in SHEETS.items():
        # 渲染必须读 STG 盘上术后态, 不可走 load() (备份优先=术前原态)
        im = Image.open(os.path.join(STG, "%s%s_attack_sheet_832.png" % (key, suf))).convert("RGBA")
        out = Image.new("RGB", (448 * 3 + 8, 448 * 2 + 2 + 28), (40, 40, 48))
        d = ImageDraw.Draw(out)
        for i in range(6):
            X = (i % 3) * (448 + 4)
            Y = (i // 3) * (448 + 2) + 28
            c = fr(im, i + 1)
            tile = Image.new("RGBA", (CW, CW), (40, 40, 48, 255))
            tile.paste(c, (0, 0), c)
            out.paste(tile.convert("RGB").resize((448, 448), Image.LANCZOS), (X, Y))
            d.rectangle([X, Y - 26, X + 40, Y - 2], fill=(20, 110, 60))
            d.text((X + 6, Y - 22), "f%d" % (i + 1), fill=(255, 255, 255))
        out.save(os.path.join(OUTD, "STG_%s.png" % key))
        print("OK STG_%s.png" % key)


if __name__ == "__main__":
    mode = sys.argv[1] if len(sys.argv) > 1 else "dry"
    rc = run(mode != "run")
    if mode == "run" and rc == 0:
        render()
    sys.exit(rc)
