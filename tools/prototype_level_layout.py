#!/usr/bin/env python3
"""关卡布局网页原型 v5（= v3.3 簇布局 + 定向搬迁补位）。
v4 全链等距被否（抹掉簇感）→ v5 恢复 v3.3（锚点权重簇 + 双向弹簧），
仅新增"搬迁补位"：对 >240px 空档，从 <42px 拥挤对里搬 1~2 点插入空档中段
（用户："中间的地方只少加几个就好；不要个别太远一些又太近"）。其余不动。
"""
import json
import math as _m
import os
import random
from collections import deque

import numpy as np
from PIL import Image
from scipy.ndimage import label, binary_closing

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "docs", "地图重设计", "generated", "大地图2_2560.png")
OUT_HTML = os.path.join(ROOT, "docs", "地图重设计", "prototype_level_layout.html")
MASK_PNG = os.path.join(ROOT, "docs", "地图重设计", "generated", "大地图_mask.png")

W, H = 2560, 1440          # 定稿：大地图2_2560（标准 16:9，原生清晰度最优）
SEED = 20260829
rng = random.Random(SEED)

im = Image.open(SRC).convert("RGB")
if im.size != (W, H):
    im = im.resize((W, H), Image.LANCZOS)
arr = np.asarray(im, np.int16)
lum = arr.astype(np.int32).mean(axis=-1)
sat = arr.max(-1) - arr.min(-1)

# ── 陆地掩膜（泛洪填海）──
sea_like = (lum > 205) & (sat < 42)
seen = np.zeros((H, W), bool)
seen[0, :] = sea_like[0, :]
seen[-1, :] |= sea_like[-1, :]
seen[:, 0] |= sea_like[:, 0]
seen[:, -1] |= sea_like[:, -1]
dq = deque(zip(*np.nonzero(seen)))
while dq:
    y, x = dq.popleft()
    for ny, nx in ((y+1, x), (y-1, x), (y, x+1), (y, x-1)):
        if 0 <= ny < H and 0 <= nx < W and not seen[ny, nx] and sea_like[ny, nx]:
            seen[ny, nx] = True
            dq.append((ny, nx))
land = ~seen
lab, n = label(land)
if n > 1:
    sizes = np.bincount(lab.ravel())
    sizes[0] = 0
    land = lab == sizes.argmax()
land = binary_closing(land, structure=np.ones((9, 9)))
cols = np.nonzero(land.any(axis=0))[0]
land_l, land_r = int(cols[0]), int(cols[-1])
Image.composite(Image.new("RGB", (W, H), (255, 60, 60)), im,
                Image.fromarray((land * 90).astype(np.uint8))).save(MASK_PNG)

# ── 黑门实测 ──
best = None
for by in range(0, H - 60, 6):
    for bx in range(int(W * 0.78), W - 60, 6):
        s = arr[by:by+60:4, bx:bx+60:4].mean()
        if best is None or s < best[0]:
            best = (s, bx + 30, by + 30)
PORTAL = (int(best[1]), int(best[2]))

def snap_pt(x, y):
    x, y = int(np.clip(round(x), 0, W - 1)), int(np.clip(round(y), 0, H - 1))
    if land[y, x]:
        return x, y
    for r in range(6, 200, 6):
        for dy in range(-r, r + 1, 6):
            for dx in range(-r, r + 1, 6):
                ny, nx = y + dy, x + dx
                if 0 <= nx < W and 0 <= ny < H and land[ny, nx]:
                    return nx, ny
    return x, y

# ── 内容锚点（人工判读·2026-08-29 定稿图 大地图2_2560 坐标系，判读自用户 4K 预览 ×1.28）──
ANCHORS = [
    {"x": 890,  "y": 256,  "t": "ruin",    "name": "北部废墟城邦", "w": 3.0},
    {"x": 947,  "y": 160,  "t": "ruin",    "name": "北方哨塔遗迹", "w": 1.5},
    {"x": 1382, "y": 333,  "t": "ruin",    "name": "东北岩堡", "w": 1.5},
    {"x": 1664, "y": 602,  "t": "ruin",    "name": "东部要塞群", "w": 2.5},
    {"x": 1651, "y": 717,  "t": "ruin",    "name": "双塔黑城", "w": 3.0},
    {"x": 1549, "y": 883,  "t": "ruin",    "name": "中南环形大城", "w": 3.5},
    {"x": 1485, "y": 819,  "t": "ruin",    "name": "东南陷城", "w": 2.0},
    {"x": 1203, "y": 896,  "t": "ruin",    "name": "南岸聚落遗迹", "w": 2.0},
    {"x": 1088, "y": 1050, "t": "ruin",    "name": "西南绿区聚落", "w": 2.0},
    {"x": 499,  "y": 678,  "t": "ruin",    "name": "西部绿带废墟", "w": 2.5},
    {"x": 1882, "y": 883,  "t": "crystal", "name": "晶体巨构群", "w": 3.0},
    {"x": 2061, "y": 678,  "t": "crystal", "name": "东晶簇", "w": 2.0},
    {"x": 2163, "y": 717,  "t": "crystal", "name": "东尖晶塔", "w": 2.0},
    {"x": 1126, "y": 576,  "t": "ice",     "name": "中央冰穹", "w": 2.0},
]
for a in ANCHORS:
    a["x"], a["y"] = snap_pt(a["x"], a["y"])

# 调试标注图：锚点画在定稿图上（自查锚点是否落在醒目内容上）
dbg = im.copy()
from PIL import ImageDraw
d_bg = ImageDraw.Draw(dbg)
for a in ANCHORS:
    c = {"ruin": (200, 151, 63), "crystal": (79, 227, 224), "ice": (232, 238, 242)}[a["t"]]
    d_bg.ellipse([a["x"]-16, a["y"]-16, a["x"]+16, a["y"]+16], outline=c, width=4)
    d_bg.text((a["x"]+20, a["y"]-10), a["name"], fill=c)
dbg.save(os.path.join(ROOT, "docs", "地图重设计", "generated", "大地图2_anchors.png"))

def is_snow(x, y):
    if not (0 <= x < W and 0 <= y < H):
        return True
    p = arr[y, x]
    return (p[0] + p[1] + p[2]) / 3 > 222 and (int(p.max()) - int(p.min())) < 34

# ── 出生点：西南绿低地避雪 ──
def is_green(x, y):
    if not (0 <= x < W and 0 <= y < H):
        return False
    p = arr[y, x]
    return p[1] >= p[0] - 12 and p[1] > int(p[2]) and not is_snow(x, y)

hx, hy = 577, 891   # 西南绿低地种子（原 2752 图 (620,950) 换算）
_found = False
for _rad in range(0, 400, 25):
    for _ in range(14):
        tx = hx + rng.randint(-_rad, _rad)
        ty = hy + rng.randint(-_rad // 2, _rad // 2)
        if 0 <= tx < W and 0 <= ty < H and land[ty, tx] and is_green(tx, ty):
            hx, hy = tx, ty
            _found = True
            break
    if _found:
        break
home = {"x": hx, "y": hy}

# ── 簇布点（v3.3 原样：权重分配 + 大半径散布 + 防雪重试 + 陆吸）──
total_w = sum(a["w"] for a in ANCHORS)
slots = []
for a in ANCHORS:
    slots.append((a, max(2, round(100 * a["w"] / total_w))))
slots[0] = (slots[0][0], slots[0][1] + (100 - sum(k for _, k in slots)))

pts = []
for a, k in slots:
    # 半径按节点面积需求：每点 ≈ (55px)² → r ≈ 31√k；下限保底小簇
    base_r = max(48 + 9 * k ** 0.5, 34.0 * k ** 0.5)
    for j in range(k):
        for _ in range(6):
            ang = rng.uniform(0, 6.283)
            rr = base_r * (0.35 + 0.65 * (j / max(1, k - 1)) if k > 1 else 0.5) * rng.uniform(0.6, 1.0)
            x = int(a["x"] + np.cos(ang) * rr)
            y = int(a["y"] + np.sin(ang) * rr * 0.8)
            if not is_snow(x, y):
                break
        if not (0 <= x < W and 0 <= y < H and land[y, x]):
            x, y = snap_pt(x, y)
        pts.append({"x": x, "y": y, "cx": a["x"], "cy": a["y"]})

pts.sort(key=lambda p: (p["x"], p["y"]))
for i, p in enumerate(pts):
    p["i"] = i + 1
# 最小间距推开
for _ in range(3):
    for i in range(1, len(pts)):
        a, b = pts[i - 1], pts[i]
        if (a["x"]-b["x"])**2 + (a["y"]-b["y"])**2 < 58**2:
            for _ in range(6):
                b["y"] = int(np.clip(b["y"] + 40, 40, H - 40))
                if land[b["y"], b["x"]]:
                    break

# ── 双向弹簧（v3.3 原样：MIN 48 / MAX 132，仅陆地约束）──
MIN_GAP, MAX_GAP = 48.0, 132.0
chain = ([{"x": home["x"], "y": home["y"], "fixed": True}]
         + pts + [{"x": PORTAL[0], "y": PORTAL[1], "fixed": True}])

def _valid(x, y):
    return 0 <= x < W and 0 <= y < H and land[y, x]

def _snap_ok(x, y, tol_y=70):
    x = int(np.clip(x, 0, W - 1))
    y = int(np.clip(y, 0, H - 1))
    if _valid(x, y):
        return x, y
    col = np.nonzero(land[:, x])[0]
    if len(col):
        c = col[np.argmin(np.abs(col - y))]
        if abs(c - y) <= tol_y:
            return x, int(c)
    for dx_ in (5, -5, 10, -10, 20, -20, 30, -30, 40, -40):
        nx = int(np.clip(x + dx_, 0, W - 1))
        col = np.nonzero(land[:, nx])[0]
        if len(col):
            c = col[np.argmin(np.abs(col - y))]
            if abs(c - y) <= tol_y:
                return nx, int(c)
    return None

def _apply(p, a, b, ux, uy, half, is_a):
    for k in (1.0, 0.6, 0.35):
        bx_ = p["x"] + ux * half * k + 0.03 * (p["cx"] - p["x"])
        by_ = p["y"] + uy * half * k + 0.03 * (p["cy"] - p["y"])
        for qx_, qy_ in ((bx_, by_),
                         (bx_ - uy * 34 * k, by_ + ux * 34 * k),
                         (bx_ + uy * 34 * k, by_ - ux * 34 * k)):
            nx, ny = int(round(qx_)), int(round(qy_))
            other = b if is_a else a
            if is_a and nx > other["x"] + 12:
                continue
            if not is_a and nx < other["x"] - 12:
                continue
            sn = _snap_ok(nx, ny)
            if sn:
                p["x"], p["y"] = sn
                return True
    return False

for _it in range(120):
    moved = False
    for i in range(1, len(chain)):
        a, b = chain[i - 1], chain[i]
        dx, dy = b["x"] - a["x"], b["y"] - a["y"]
        d = _m.hypot(dx, dy)
        if d < 1e-6:
            dx, dy, d = 0.0, 1.0, 1.0
        if MIN_GAP <= d <= MAX_GAP:
            continue
        step = (d - (MIN_GAP if d < MIN_GAP else MAX_GAP)) * 0.3
        ux, uy = dx / d, dy / d
        if not a.get("fixed"):
            moved |= _apply(a, a, b, ux, uy, step * 0.5, True)
        if not b.get("fixed"):
            moved |= _apply(b, a, b, ux, uy, -step * 0.5, False)
    if not moved:
        break

# ── 定向搬迁补位（v5 新增）：空档 >240 从拥挤对 <42 搬 1~2 点插入空档中段 ──
def pair_d(i):
    a, b = pts[i - 1], pts[i]
    return _m.hypot(b["x"] - a["x"], b["y"] - a["y"])

for _round in range(30):
    gaps = [(pair_d(i), i) for i in range(1, len(pts))]
    gaps.sort(reverse=True)
    filled = False
    for gd, gi in gaps:
        if gd <= 240:
            break
        a, b = pts[gi - 1], pts[gi]
        need = 2 if gd > 380 else 1
        tlist = (((0.5,), (0.4,), (0.6,)) if need == 1
                 else ((0.33, 0.67), (0.28, 0.72), (0.4, 0.6)))
        mx, my = (a["x"] + b["x"]) / 2.0, (a["y"] + b["y"]) / 2.0
        tight = [i for i in range(1, len(pts)) if pair_d(i) < 52]
        tight.sort(key=lambda i: _m.hypot(pts[i]["x"] - mx, pts[i]["y"] - my))
        done = False
        for ts in tlist:
            if done:
                break
            placed = []
            for t in ts:
                spot = None
                nx = int(round(a["x"] + (b["x"] - a["x"]) * t))
                ny = int(round(a["y"] + (b["y"] - a["y"]) * t))
                sx, sy = snap_pt(nx, ny)
                # 落点必须真正位于空档内部（距两端≥90px），否则是吸回岸边=没填上
                if (_m.hypot(sx - a["x"], sy - a["y"]) < 90
                        or _m.hypot(sx - b["x"], sy - b["y"]) < 90):
                    continue
                for ti in tight:
                    mv = pts[ti]
                    if mv in placed or _m.hypot(sx - mv["x"], sy - mv["y"]) < 60:
                        continue
                    mv["x"], mv["y"] = sx, sy
                    placed.append(mv)
                    spot = mv
                    break
                if spot is None:
                    done = False
                    break
            if len(placed) == len(ts):
                filled = True
                print("[补位] round %d: 空档(%.0fpx, #%d-%d) 搬 %d 点" %
                      (_round, gd, pts[gi-1]["i"], pts[gi]["i"], len(placed)))
                break
    if not filled:
        break

# ── 最终编号（排序）→ 分离（在最终邻接关系上做，避免重排再配对）──
pts.sort(key=lambda p: (p["x"], p["y"]))
for i, p in enumerate(pts):
    p["i"] = i + 1

for _ in range(6):
    fixed_n = 0
    for i in range(1, len(pts)):
        a, b = pts[i - 1], pts[i]
        d = _m.hypot(b["x"] - a["x"], b["y"] - a["y"])
        if d >= 56 or d < 1e-6:
            continue
        push = 58.0 - d
        # y 向优先（不动 x 序），轴向后补
        cands = []
        if b["y"] >= a["y"]:
            cands.append((b["x"], b["y"] + push))
        else:
            cands.append((b["x"], b["y"] - push))
        cands += [(b["x"], a["y"] + (58 if b["y"] < a["y"] else -58)),
                  (b["x"] + push, b["y"]), (b["x"] - push, b["y"])]
        for qx_, qy_ in cands:
            sn = snap_pt(qx_, qy_)
            if (_m.hypot(sn[0] - a["x"], sn[1] - a["y"]) >= 54
                    and sn != (b["x"], b["y"])):
                nxt = pts[i + 1] if i + 1 < len(pts) else None
                if nxt is not None and _m.hypot(sn[0] - nxt["x"], sn[1] - nxt["y"]) > 300:
                    continue
                b["x"], b["y"] = sn
                fixed_n += 1
                break
    if fixed_n == 0:
        break

# ── 全对重叠消除（链上不相邻节点也可能互压）：推 b，局部邻域校验 ──
def _local_clear(p, x, y, min_d=52.0):
    for q in pts:
        if q is p:
            continue
        if abs(q["x"] - x) > 130 or abs(q["y"] - y) > 130:
            continue
        if _m.hypot(q["x"] - x, q["y"] - y) < min_d:
            return False
    return True

for _r in range(12):
    fixed_n = 0
    for i in range(len(pts)):
        for j in range(i + 1, len(pts)):
            a, b = pts[i], pts[j]
            d = _m.hypot(b["x"] - a["x"], b["y"] - a["y"])
            if d >= 56:
                continue
            if d < 1e-6:
                ux, uy = 0.0, -1.0
            else:
                ux, uy = (b["x"] - a["x"]) / d, (b["y"] - a["y"]) / d
            push = 62.0 - d
            moved_pair = False
            for mv, keep in ((b, a), (a, b)):   # b 推不动就推 a
                for m_ in (1.0, 1.6, 2.4, 3.2, 4.0):
                    if moved_pair:
                        break
                    mx_ = keep["x"] - mv["x"]
                    my_ = keep["y"] - mv["y"]
                    md = _m.hypot(mx_, my_)
                    ux2, uy2 = (mx_ / md, my_ / md) if md > 1e-6 else (0.0, -1.0)
                    for qx_, qy_ in ((mv["x"] - ux2 * push * m_, mv["y"] - uy2 * push * m_),
                                     (mv["x"] + uy2 * push * m_, mv["y"] - ux2 * push * m_),
                                     (mv["x"] - uy2 * push * m_, mv["y"] + ux2 * push * m_),
                                     (mv["x"], mv["y"] - push * m_), (mv["x"], mv["y"] + push * m_),
                                     (mv["x"] - push * m_, mv["y"]), (mv["x"] + push * m_, mv["y"])):
                        sn = snap_pt(qx_, qy_)
                        if sn == (mv["x"], mv["y"]):
                            continue
                        if _m.hypot(sn[0] - keep["x"], sn[1] - keep["y"]) >= 56 \
                                and _local_clear(mv, sn[0], sn[1], min_d=50.0):
                            mv["x"], mv["y"] = sn
                            fixed_n += 1
                            moved_pair = True
                            break
    if fixed_n == 0:
        break
rem = sum(1 for i in range(len(pts)) for j in range(i + 1, len(pts))
          if _m.hypot(pts[i]["x"] - pts[j]["x"], pts[i]["y"] - pts[j]["y"]) < 52)
print("全对重叠剩余 %d 处" % rem)

# ── 审计 ──
seq = [home] + pts + [{"x": PORTAL[0], "y": PORTAL[1]}]
gaps2 = [_m.hypot(seq[i+1]["x"]-seq[i]["x"], seq[i+1]["y"]-seq[i]["y"]) for i in range(len(seq)-1)]
print("黑门实测:", PORTAL)
print("相邻间距: min %.0f max %.0f 平均 %.0f 中位 %.0f" %
      (min(gaps2), max(gaps2), sum(gaps2)/len(gaps2), sorted(gaps2)[len(gaps2)//2]))
print(">240 空档 %d 处；<42 拥挤 %d 处" %
      (sum(1 for g in gaps2 if g > 240), sum(1 for g in gaps2 if g < 42)))

# ── HTML ──
ERA = [("一战", "#c8973f"), ("二战", "#7fae4e"), ("冷战", "#4e8ec2"),
       ("现代", "#93a3b2"), ("近未来", "#4fe3e0")]
TYPE_C = {"ruin": "#c8973f", "crystal": "#4fe3e0", "ice": "#e8eef2"}
feat_js = json.dumps([{**a, "c": TYPE_C[a["t"]]} for a in ANCHORS])
html = """<!DOCTYPE html>
<html lang="zh"><head><meta charset="utf-8">
<title>主地图 · 100 关布局原型 v5（簇布局+定向补位）</title>
<style>
  body { margin:0; background:#1a1c22; color:#dfe6ee; font:14px/1.6 "Microsoft YaHei",sans-serif; }
  #bar { padding:10px 16px; background:#22252d; display:flex; gap:18px; align-items:center; position:sticky; top:0; z-index:9; flex-wrap:wrap;}
  #bar b { color:#ffd97a; }
  label { cursor:pointer; }
  #wrap { position:relative; width:2752px; height:1536px; transform-origin:0 0; }
  #map, #mask { position:absolute; inset:0; width:100%; height:100%; }
  #mask { display:none; opacity:.55; pointer-events:none;}
  svg.path { position:absolute; inset:0; width:100%; height:100%; pointer-events:none; }
  .node { position:absolute; width:42px; height:42px; margin:-21px 0 0 -21px; border-radius:50%;
          display:flex; align-items:center; justify-content:center; font-weight:bold; font-size:14px;
          border:3px solid #888; background:#3a3f47; color:#cfd6de; box-shadow:0 2px 6px rgba(0,0,0,.5);
          cursor:pointer; }
  .node.done { background:var(--c); border-color:#fff8; color:#fff; }
  .node.cur  { width:62px; height:62px; margin:-31px 0 0 -31px; font-size:18px; background:#fff;
               border:5px solid var(--c); color:#222; box-shadow:0 0 0 6px #ffffff33, 0 0 18px var(--c); }
  .node.cur::after { content:""; position:absolute; top:-26px; left:50%; margin-left:-7px; width:14px; height:14px;
               border-radius:50%; background:var(--c); animation:pulse 1.2s infinite; }
  @keyframes pulse { 0%,100%{transform:scale(1)} 50%{transform:scale(1.5)} }
  .node.boss { width:54px; height:54px; margin:-27px 0 0 -27px; border-color:#e8b23a; border-width:4px; }
  .feat { position:absolute; transform:translate(-50%,-50%); text-align:center; pointer-events:none; z-index:3;}
  .feat .d { width:14px; height:14px; margin:0 auto; transform:rotate(45deg); border:2px solid #fff8; }
  .feat .t { font-size:16px; color:#fff; text-shadow:0 1px 3px #000, 0 0 6px #0009; white-space:nowrap; margin-top:2px;}
  .home { position:absolute; width:30px; height:30px; margin:-15px 0 0 -15px; border-radius:50% 50% 4px 4px;
          background:#d8823c; border:3px solid #fff6; box-shadow:0 0 10px #d8823c88; }
  .gate { position:absolute; width:40px; height:40px; margin:-20px 0 0 -20px; border-radius:50%;
          background:#0a0a0c; border:4px solid #7fe3f2; box-shadow:0 0 16px #7fe3f2; }
  .tip { position:fixed; padding:6px 10px; background:#000c; border:1px solid #7fe3f2; border-radius:6px;
         pointer-events:none; display:none; z-index:99; }
</style></head><body>
<div id="bar">
  <b>主地图 · 100 关布局原型 v5（簇布局 + 定向补位）</b>
  <span>锚点簇保留；空档处从拥挤簇搬 1~2 点补位（<span style="color:#c8973f">◆废墟</span> <span style="color:#4fe3e0">◆晶体</span> <span style="color:#e8eef2">◆冰穹</span>）</span>
  <label><input type="checkbox" id="showmask"> 陆地分析</label>
  <span>缩放 <select id="zoom"><option value="0.5">50%</option><option value="0.75" selected>75%</option><option value="1">100%</option></select></span>
</div>
<div id="viewport" style="overflow:auto">
<div id="wrap">
  <img id="map" src="generated/大地图2_2560.png">
  <img id="mask" src="generated/大地图_mask.png">
  <svg class="path" viewBox="0 0 2752 1536" fill="none">
    <path id="route" stroke-width="5" stroke-linejoin="round" stroke-linecap="round" stroke="#ffffff44"/>
    <path id="route2" stroke-width="2.5" stroke-linejoin="round" stroke="#9feaf5aa" stroke-dasharray="14 9"/>
  </svg>
  <div id="feats"></div>
  <div id="nodes"></div>
</div></div>
<div class="tip" id="tip"></div>
<script>
const P = __POSITIONS__;
const HOME = __HOME__;
const GATE = __GATE__;
const ERA = __ERA__;
const FEATS = __FEATS__;
const wrap = document.getElementById('wrap');
const ndiv = document.getElementById('nodes');
let d = `M ${HOME.x} ${HOME.y} L ${P[0].x} ${P[0].y} `;
P.forEach(p => {
  d += `L ${p.x} ${p.y} `;
  const era = Math.floor((p.i - 1) / 20);
  const el = document.createElement('div');
  const st = p.i < 45 ? 'done' : (p.i === 45 ? 'cur' : 'locked');
  const boss = p.i % 10 === 0 ? ' boss' : '';
  el.className = `node ${st}${boss}`;
  el.style.left = p.x + 'px'; el.style.top = p.y + 'px';
  el.style.setProperty('--c', ERA[era][1]);
  el.textContent = p.i;
  el.onmouseenter = e => { const t = document.getElementById('tip');
    t.style.display='block'; t.style.left=(e.clientX+14)+'px'; t.style.top=(e.clientY+14)+'px';
    t.innerHTML = `第 ${p.i} 关 · ${ERA[era][0]}${boss?' · 首领':''}`; };
  el.onmouseleave = () => document.getElementById('tip').style.display='none';
  ndiv.appendChild(el);
});
d += `L ${GATE.x} ${GATE.y}`;
document.getElementById('route').setAttribute('d', d);
document.getElementById('route2').setAttribute('d', d);
const fe = document.getElementById('feats');
FEATS.forEach(f => {
  const el = document.createElement('div');
  el.className = 'feat';
  el.style.left = f.x + 'px'; el.style.top = f.y + 'px';
  el.innerHTML = `<div class="d" style="background:${f.c}"></div><div class="t" style="color:${f.c}">${f.name}</div>`;
  fe.appendChild(el);
});
const h = document.createElement('div'); h.className='home';
h.style.left=HOME.x+'px'; h.style.top=HOME.y+'px'; h.title='余烬要塞（家）';
wrap.appendChild(h);
const gt = document.createElement('div'); gt.className='gate';
gt.style.left=GATE.x+'px'; gt.style.top=GATE.y+'px'; gt.title='黑色传送门';
wrap.appendChild(gt);
document.getElementById('showmask').onchange = e =>
  document.getElementById('mask').style.display = e.target.checked ? 'block' : 'none';
document.getElementById('zoom').onchange = e => {
  wrap.style.transform = `scale(${e.target.value})`;
  const vp = document.getElementById('viewport');
  vp.style.width = (2752*e.target.value)+'px';
  vp.style.height = (1536*e.target.value)+'px';
};
document.getElementById('zoom').onchange({target:document.getElementById('zoom')});
</script></body></html>"""
html = html.replace("__POSITIONS__", json.dumps(pts))
html = html.replace("__HOME__", json.dumps(home))
html = html.replace("__GATE__", json.dumps({"x": PORTAL[0], "y": PORTAL[1]}))
html = html.replace("__ERA__", json.dumps(ERA))
html = html.replace("__FEATS__", feat_js)
open(OUT_HTML, "w", encoding="utf-8").write(html)
print("HTML →", OUT_HTML)

# ── 导出 GDScript 常量（world_map.gd 方案11 布局唯一数据源，勿手改）──
lines = [
    "# 自动生成：tools/prototype_level_layout.py（布局调参请改原型脚本后重跑导出）",
    "# 方案11 主地图布点：内容锚定簇布局，坐标 = 2560×1440 画布像素",
    "# 途经内容锚点见原型脚本 ANCHORS 表（废墟城邦/晶体巨构/冰穹，黑门自动实测）",
    'class_name WorldMapLayoutS11',
    "",
    "const HOME := Vector2(%d, %d)" % (home["x"], home["y"]),
    "const GATE := Vector2(%d, %d)" % (PORTAL[0], PORTAL[1]),
    "const POINTS: Array[Vector2] = [",
]
lines += ["\tVector2(%d, %d)," % (p["x"], p["y"]) for p in pts]
lines += ["]"]
gd_path = os.path.join(ROOT, "data", "world_map_layout_s11.gd")
open(gd_path, "w", encoding="utf-8").write("\n".join(lines) + "\n")
print("GD →", gd_path)
