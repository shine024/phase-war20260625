# -*- coding: utf-8 -*-
"""105mm 炮类轮径归一装配（2026-10-07「火炮 要重新生成」配套）。

bbox 归一对炮类不适用（R1 实证：盾牌高度随帧变 + 深烟计入 bbox → 缩放比不稳）。
本工具以【辐条轮】为炮类唯一刚性基准做归一：
  · 缩放 = 目标卡图口径 / 参考帧实心高 × (轮径中位数 / 本帧轮径)
  · 对齐 = 轮底（=地面线）→ TARGET_BOT；轮心 x → TARGET_CX（车轮硬锁下保后坐拍）
流程: 832 链卷逐格键控（跳过 keep_main_bodies 保独立烟团）→ Hough 找轮
      → 逐帧变换 → 1536×256 条带（部署口径）+ 832 白底候选卷 + GIF + 轮检测叠框证据。
用法: python tools/_fam44_gun_wheel_norm.py <key> <chainR#> [--cell N] [--cx X --cy Y --r R]
      --cell 手工轮定值（自动检测被骗时逐格覆盖，832 坐标系）
"""
import io
import json
import os
import sys

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np
from PIL import Image, ImageDraw

import deploy_unit_anims as dua
import img25_attack_gen as ag

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, ".godot", "unit_review", "img25_staging")
CELL = 832
FRAME = 256
# 目标口径（来源：旧 sheet 非火光帧实测 h120-128 + 卡图 CONTENT_BBOX h_frac 0.498×256≈127）
TARGET_H = 127
TARGET_BOT = 208
TARGET_CX = 125

argv = [a for a in sys.argv[1:]]
KEY = argv[0]
ROLL = argv[1]
SRC = os.path.join(OUT, "%s_chain%s_sheet_832.png" % (KEY, ROLL))
TAG = "%s_wheel%s" % (KEY, ROLL)


def kill_pink(rgba):
    a = np.asarray(rgba).copy()
    # int 强转：uint8 减法回绕会把蓝灰钢体（g>r、b>g → r-g/b-g 负值绕成 250+）
    # 全数误判成品红族（10-07「火炮抠图不对」第二病根，mark4 军绿主体 r≥g 不触发）
    r, g, b = a[:, :, 0].astype(int), a[:, :, 1].astype(int), a[:, :, 2].astype(int)
    hit = ((r - g > 30) & (b - g > 10)) | ((r > 100) & (r > g * 1.9) & (b > g * 1.4) & (g < 70)) \
        | ((r - g > 12) & (b - g > 8) & (r > 150))
    a[:, :, 3][hit] = 0
    return Image.fromarray(a)


def key_cell(cell):
    """白底链卷专用键控。不用 ag.chroma_key：其 v3 白球 dw<30（min-ch≥225 即候选）
    为品红底+深军绿主体调参——105mm 链血统钢体浅蓝灰（炮管高光 min-ch 225-240），
    BFS 顺 AA 边连通吃掉整根炮管+防盾大块（10-07「火炮抠图不对」病根）。
    本地版：近白收紧 dw<12（min-ch≥243）+品红族老规则，边界 BFS 保内部白色细节；
    贴 bg 保留像素仍近白（dw<24）→ 半透，治 1px AA 白晕。"""
    from collections import deque
    a = np.asarray(cell.convert("RGB")).astype(int)
    dw = np.abs(a - 255).max(axis=2)
    rg = a[:, :, 0] - a[:, :, 1]
    bgm = a[:, :, 2] - a[:, :, 1]
    # 白底 BFS 阈值 dw<8（纯白 bg dw 0-6）：dw<12 会把「光晕→受光盾面」的灰度渐变
    # 当踏脚石一路吃进盾内（f2 虫蛀孔洞）。残余光晕交给下方亮距分层规则清。
    near = ((dw < 80) & (rg > 60) & (bgm > 25)) | (dw < 8)
    h, w = near.shape
    isbg = np.zeros_like(near, dtype=bool)
    dq = deque()
    for x in range(w):
        for y in (0, h - 1):
            if near[y, x] and not isbg[y, x]:
                isbg[y, x] = True
                dq.append((y, x))
    for y in range(h):
        for x in (0, w - 1):
            if near[y, x] and not isbg[y, x]:
                isbg[y, x] = True
                dq.append((y, x))
    while dq:
        y, x = dq.popleft()
        for ny, nx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
            if 0 <= ny < h and 0 <= nx < w and near[ny, nx] and not isbg[ny, nx]:
                isbg[ny, nx] = True
                dq.append((ny, nx))
    alpha = np.where(isbg, 0, 255).astype(np.uint8)
    # 亮距分层清雾（距 bg 的像素距离 d）：
    #   d≤1 & dw<24 → 全透（AA 白晕）；d≤6 & dw<20 低饱和 → 全透（外圈 bloom）
    #   d>6 & dw<10 低饱和 → 全透（闭合白口袋；炮管高光脊 dw 10-25 在体内，保）
    # 火焰保护：从火色种子沿亮区（lum>140）连通域扩散，整团 flash+白热芯一体豁免
    # （pocket 规则曾把 f3 flash 中性白芯打成黑洞）。
    import cv2
    lum = a.mean(axis=2)
    low_sat = ((a.max(axis=2) - a.min(axis=2)) < 26)
    fire = (a[:, :, 0] > 180) & (a[:, :, 1] > 120) & (a[:, :, 2] < 190) & \
           ((a[:, :, 0] - a[:, :, 2]) > 40)
    bright = (lum > 140) & (~isbg)
    lbl = cv2.connectedComponents(bright.astype(np.uint8), connectivity=8)[1]
    prot = np.zeros_like(fire)
    for v in np.unique(lbl[fire & bright]):
        if v:
            prot |= (lbl == v)
    d = (~isbg).astype(np.uint8).copy()
    for _ in range(6):
        grow = d.copy()
        for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            grow |= np.roll(np.roll(d, dy, axis=0), dx, axis=1)
        d = grow
    keep = ~(isbg | prot)
    alpha[(keep) & (d <= 1) & (dw < 24)] = 0
    alpha[(keep) & (d <= 6) & (dw < 20) & low_sat] = 0
    alpha[(keep) & (d > 6) & (dw < 10) & low_sat] = 0
    rgba = np.dstack([np.asarray(cell.convert("RGB")), alpha])
    rgba = kill_pink(Image.fromarray(rgba))
    rgba = ag.depink(rgba)
    return rgba


def kill_shadow(rgba, ground_y, band=120):
    """链帧白底软阴影：贴地 band 内浅灰低饱和像素全杀（实测阴影主体 lum>190，
    沿炮架下缘爬到地线上方 ~100px）。轮缘/驻锄深铁色（lum<100）不中；
    炮口烟在炮膛高度（地线上方 ~140px+）不中。"""
    a = np.asarray(rgba).copy()
    y0 = max(0, int(ground_y - band))
    roi = a[y0:, :, :3].astype(int)
    lum = roi.mean(axis=2)
    sat = roi.max(axis=2) - roi.min(axis=2)
    hit = (lum > 150) & (sat < 28)
    a[y0:, :, 3][hit] = 0
    return Image.fromarray(a)


def find_wheel_cell1(rgb_cell, manual):
    """格1（锚本体）：Hough 全局带 + 目检叠框终审；manual=(cx,cy,r) 覆盖。
    轮径 r 96-132；轮心下半幅中偏右；轮底贴全格最低实心缘（±45）。"""
    if manual:
        return manual
    import cv2
    a = np.asarray(rgb_cell)
    gray = cv2.cvtColor(a, cv2.COLOR_RGB2GRAY)
    solid = (a.sum(axis=2) < 700)
    lowest = int(np.where(solid.any(axis=1))[0].max())
    gray = cv2.medianBlur(gray, 5)
    circles = cv2.HoughCircles(gray, cv2.HOUGH_GRADIENT, dp=1.5, minDist=150,
                               param1=120, param2=38, minRadius=96, maxRadius=132)
    H, W = gray.shape
    if circles is not None:
        for cx, cy, r in circles[0]:
            if (0.50 * H < cy < 0.88 * H and 0.32 * W < cx < 0.78 * W
                    and abs((cy + r) - lowest) <= 45):
                return (float(cx), float(cy), float(r))
    print("  [wheel-fail] cell1 lowest=%d 候选: %s"
          % (lowest, np.round(circles[0][:8], 0).tolist() if circles is not None else "无"))
    return None


def find_wheel_tm(rgb_cell, tpl, r1):
    """格2-5：多尺度 matchTemplate（0.88-1.12 步 0.02）——最优分尺度即相对轮径。
    返回 (cx, cy, r, score)。确定性，无 Hough 参数过敏、无驻锄误扫。"""
    import cv2
    a = np.asarray(rgb_cell)
    gray = cv2.cvtColor(a, cv2.COLOR_RGB2GRAY)
    best = None
    for sc in np.arange(0.88, 1.121, 0.02):
        w = max(8, int(round(gray.shape[1] * sc)))
        g2 = cv2.resize(gray, (w, int(round(gray.shape[0] * sc))), interpolation=cv2.INTER_AREA)
        if g2.shape[0] <= tpl.shape[0] or g2.shape[1] <= tpl.shape[1]:
            continue
        res = cv2.matchTemplate(g2, tpl, cv2.TM_CCOEFF_NORMED)
        _, mv, _, ml = cv2.minMaxLoc(res)
        cx = ml[0] + tpl.shape[1] / 2.0
        cy = ml[1] + tpl.shape[0] / 2.0
        if best is None or mv > best[3]:
            best = (cx / sc, cy / sc, r1 / sc, float(mv), sc)
    return best


def fade_left_cut(rgba, thresh=6, width=56):
    """链帧烟被生成画布左缘硬切（R3 实证 281-505px 触边）：左 width px 内的
    浅色像素（烟）做 alpha 幂斜坡 → 硬切边变自然消散。深铁色（炮管，lum<120）
    不参与；切边帧才触发（左缘内容 >thresh 即原样返回）。
    火焰豁免宽斜坡（10-07「动图火炮口火焰」：炮口也在 x<56 区，火光同中 lum>120
    被斜坡削成半月块）——火色亮区连通域（整团 flash+白热芯）只吃窄 12px 斜坡，
    软化 x=0 切线不削火光本体。"""
    a = np.asarray(rgba).copy()
    m = a[:, :, 3] > 8
    cols = np.where(m.any(axis=0))[0]
    if not len(cols) or cols.min() > thresh:
        return rgba
    import cv2
    xs = np.arange(a.shape[1])
    lum = a[:, :, :3].astype(int).mean(axis=2)
    rgb = a[:, :, :3].astype(int)
    fire = (rgb[:, :, 0] > 180) & (rgb[:, :, 1] > 120) & (rgb[:, :, 2] < 190) & \
           ((rgb[:, :, 0] - rgb[:, :, 2]) > 40)
    bright = (lum > 120) & (a[:, :, 3] > 8)
    lbl = cv2.connectedComponents(bright.astype(np.uint8), connectivity=8)[1]
    prot = np.zeros_like(fire)
    for v in np.unique(lbl[fire & bright]):
        if v:
            prot |= (lbl == v)
    ramp = np.clip(xs / width, 0, 1) ** 1.2
    fade_mask = (xs[None, :] < width) & (lum > 120) & ~prot
    a[:, :, 3] = np.where(fade_mask, (a[:, :, 3] * ramp[None, :]).astype(np.uint8),
                          a[:, :, 3])
    ramp_f = np.clip(xs / 12, 0, 1) ** 1.2
    fade_f = (xs[None, :] < 12) & prot
    a[:, :, 3] = np.where(fade_f, (a[:, :, 3] * ramp_f[None, :]).astype(np.uint8),
                          a[:, :, 3])
    print("  [fade] 左缘切割 x_min=%d → 烟渐隐 %dpx / 火焰窄渐隐 12px（火色 %d px）"
          % (cols.min(), width, int(prot.sum())))
    return Image.fromarray(a)


def shield_shift(ref, cur):
    """炮尾无 FX 窗 alpha 互相关测炮体相对平移（832 尺度）。

    两代前车之鉴：亮度掩膜相关被帧间光照坑（f3 盾被火光染色 → −24）；
    剪影地标带（盾顶/盾左）会扫到 FX 与逐帧重画的轮廓差（f2 蓄势光 → −9、
    f3 实测把 −1 错判成 +24，补偿反而推出 −10 摆动）。定案：只在炮尾窗
    （x470-750, y320-660——轮右缘≈400 之外、烟/火光全在炮口侧）对 alpha
    做 overlap 最大搜索，粗步长2再细步长1。"""
    a = np.asarray(cur)[:, :, 3].astype(int)
    r = np.asarray(ref)[:, :, 3].astype(int)
    x0, x1, y0, y1 = 470, 750, 320, 660
    rw = r[y0:y1, x0:x1]
    R = 24
    best, bd = -1, (0, 0)
    for dy in range(-R, R + 1, 2):
        for dx in range(-R, R + 1, 2):
            w = a[y0 + dy:y1 + dy, x0 + dx:x1 + dx]
            s = int(np.minimum(rw, w).sum())
            if s > best:
                best, bd = s, (dx, dy)
    b0 = bd
    for dy in range(b0[1] - 2, b0[1] + 3):
        for dx in range(b0[0] - 2, b0[0] + 3):
            w = a[y0 + dy:y1 + dy, x0 + dx:x1 + dx]
            s = int(np.minimum(rw, w).sum())
            if s > best:
                best, bd = s, (dx, dy)
    return bd[0], bd[1]


def main():
    global TARGET_H
    manual = {}
    if "--cell" in argv:
        i = argv.index("--cell")
        cx, cy, r = map(float, argv[i + 1:i + 4])
        n = int(argv[i + 4]) if len(argv) > i + 4 else 1
        manual[n] = (cx, cy, r)

    sh = Image.open(SRC).convert("RGB")
    assert sh.size == (CELL * 3, CELL * 2), sh.size
    keyed, cells_rgb, wheels = [], [], []
    for i in range(6):
        c, r = i % 3, i // 3
        cell = sh.crop((c * CELL, r * CELL, (c + 1) * CELL, (r + 1) * CELL))
        keyed.append(key_cell(cell))
        cells_rgb.append(cell)
        wheels.append(None)
    import cv2
    # 格1 全局 Hough（目检叠框终审）→ 轮区模板 → 格2-5 matchTemplate + 径向扫描定 r
    w1 = find_wheel_cell1(cells_rgb[0], manual.get(1))
    assert w1, "格1 轮检测失败（用 --cell 手工定值）"
    wheels[0] = w1
    wheels[5] = find_wheel_cell1(cells_rgb[5], manual.get(6)) or w1  # 格6=锚本体同款
    side = int(w1[2] * 2.4)
    L1 = np.asarray(cells_rgb[0].convert("L"), dtype=np.uint8)
    x0, y0 = int(w1[0]) - side // 2, int(w1[1]) - side // 2
    tpl = np.ascontiguousarray(L1[max(0, y0):y0 + side, max(0, x0):x0 + side])
    tpl = cv2.medianBlur(tpl, 3)
    for i in (1, 2, 3, 4):
        if manual.get(i + 1):
            wheels[i] = manual.get(i + 1)
            continue
        cx, cy, rr, mv, sc = find_wheel_tm(cells_rgb[i], tpl, w1[2])
        print("cell%d tm=(%.0f,%.0f) r=%.0f (sc=%.2f) score=%.3f" % (i + 1, cx, cy, rr, sc, mv))
        wheels[i] = (cx, cy, rr)
    for i in range(6):
        print("cell%d wheel=(%.0f,%.0f,r%.0f)" % (i + 1, wheels[i][0], wheels[i][1], wheels[i][2]))
    for i in range(6):
        keyed[i] = kill_shadow(keyed[i], wheels[i][1] + wheels[i][2])
        keyed[i] = fade_left_cut(keyed[i])
    ds = [w[2] * 2 for w in wheels if w]
    assert len(ds) == 6, "六格轮检测缺格（用 --cell 手工补）"
    d_pivot = wheels[0][2] * 2  # 枢轴=锚轮（血统校正方向：链轮→锚轮）
    # 参考帧实心高（格1 无火效最干净）
    m = np.asarray(keyed[0])[:, :, 3] >= 200
    ys = np.where(m.any(axis=1))[0]
    h_ref = int(ys.max() - ys.min() + 1)
    s_glob = TARGET_H / h_ref
    print("ref: h=%d s_glob=%.4f d_pivot=%.0f" % (h_ref, s_glob, d_pivot))

    # 自动 TARGET_CX：由锚帧（格1 无火效）本体伸出量决定；火效烟允许裁
    # （链卷烟触边=该掷违边纪律，由 strip 后检抓，不迁就烟改口径）。
    s0 = s_glob * (d_pivot / (wheels[0][2] * 2))
    m0 = np.asarray(keyed[0])[:, :, 3] >= 200
    xs0 = np.where(m0.any(axis=0))[0]
    le = (wheels[0][0] - xs0.min()) * s0
    re = (xs0.max() - wheels[0][0]) * s0
    # 装框适配：锚本体放不进 256 帧则等比缩 TARGET_H（R1 血统含全长驻锄实测需 ~122）
    span = le + re
    if span > FRAME - 12:
        k = (FRAME - 12) / span
        TARGET_H = round(TARGET_H * k, 1)
        s_glob = TARGET_H / h_ref
        s0 *= k
        le *= k
        re *= k
        print("[fit] 锚本体宽 %.0f > %d → TARGET_H 缩至 %.1f" % (span, FRAME, TARGET_H))
    t_cx = int(np.ceil(le)) + 4
    assert t_cx + re <= FRAME - 6, "锚本体右溢 %.0f" % (t_cx + re)
    print("auto-cx: anchor le=%.0f re=%.0f -> TARGET_CX=%d TARGET_H=%.1f"
          % (le, re, t_cx, TARGET_H))

    strip = Image.new("RGBA", (FRAME * 6, FRAME), (0, 0, 0, 0))
    sheet_n = Image.new("RGB", (CELL * 3, CELL * 2), (255, 255, 255))
    dbgp = sh.copy()
    dr = ImageDraw.Draw(dbgp)
    # 体内对齐（10-07「火炮 摆动太大」）：轮锁治不了体相对轮的源画漂移
    # （R3b f2 盾窗实测 +6,+3 @256）。贴位补偿把各链帧体拉回 rest 基准；
    # dy 钳位 ±2px@256 保轮底地线（浮轮比摆动更假）。
    ref_keyed = np.asarray(keyed[0])
    body_off = [(0, 0)] * 6
    for i in (1, 2, 3, 4):
        bdx, bdy = shield_shift(ref_keyed, np.asarray(keyed[i]))
        # 关键：轮锁贴位已消去轮的整位移，体补偿必须用「体相对轮」漂移。
        # 直接用原始坐标 body 漂移会把轮位移消两次——f3 轮检 (381,496) vs
        # rest (352,491) 差 +29px，体被多推 ~11px@256（10-07 深夜实锤，
        # f2/f4/f5 轮检≈rest 故无病，唯独 f3 残差 -9）。
        wdx = wheels[i][0] - wheels[0][0]
        wdy = wheels[i][1] - wheels[0][1]
        body_off[i] = (bdx - wdx, bdy - wdy)
        print("  [body] f%d 体漂移 dx=%+d dy=%+d → 相对轮 dx=%+d dy=%+d (832)"
              % (i + 1, bdx, bdy, bdx - wdx, bdy - wdy))
    for i in range(6):
        cx, cy, r = wheels[i]
        s = s_glob * (d_pivot / (r * 2))
        w8 = max(1, round(CELL * s))
        sc = keyed[i].resize((w8, w8), Image.LANCZOS)
        # sc 内轮心/轮底（缩放后 1:1 像素）；两个空间各自直接解贴位，不做二次换算
        tcx, tbot = cx * s, (cy + r) * s
        px = round(t_cx - tcx) - round(body_off[i][0] * s)
        py = round(TARGET_BOT - tbot) - min(2, max(-2, round(body_off[i][1] * s)))
        # 贴帧裁到帧界：sc 宽可超帧宽（px<0 时右溢 w8+px px），不裁会把右缘内容串染邻帧
        # （f3 火光碎块出现在 f2 右缘）。PIL 只裁画布边界，不裁帧界。
        x0, y0 = max(0, -px), max(0, -py)
        x1, y1 = min(w8, FRAME - px), min(w8, FRAME - py)
        strip.paste(sc.crop((x0, y0, x1, y1)), (px + x0 + i * FRAME, py + y0))
        dx8 = round(t_cx * (CELL / FRAME) - tcx) - round(body_off[i][0] * s)
        dy8 = round(TARGET_BOT * (CELL / FRAME) - tbot) \
            - min(2 * CELL // FRAME, max(-2 * CELL // FRAME, round(body_off[i][1] * s)))
        cell_n = Image.new("RGB", (CELL, CELL), (255, 255, 255))
        cell_n.paste(sc, (dx8, dy8), sc)
        sheet_n.paste(cell_n, ((i % 3) * CELL, (i // 3) * CELL))
        ox, oy = (i % 3) * CELL, (i // 3) * CELL
        dr.ellipse([ox + cx - r - 6, oy + cy - r - 6, ox + cx + r + 6, oy + cy + r + 6],
                   outline=(255, 60, 60), width=5)
        dr.line([ox + cx - r - 14, oy + cy + r, ox + cx + r + 14, oy + cy + r],
                fill=(60, 120, 255), width=3)

    strip.save(os.path.join(OUT, "_%s_strip_1536.png" % TAG))
    sheet_n.save(os.path.join(OUT, "%s_n_sheet_832.png" % TAG))
    dbgp.save(os.path.join(OUT, "_%s_wheel_dbg.png" % TAG))

    # 部署口径后检（实心高/底缘/极差）——描述性输出，拍板前不写 assets
    a = np.asarray(strip)
    hs, bots = [], []
    for i in range(6):
        fr = a[:, i * FRAME:(i + 1) * FRAME]
        m = fr[:, :, 3] >= 200
        ys = np.where(m.any(axis=1))[0]
        hs.append(int(ys.max() - ys.min() + 1) if len(ys) else 0)
        bots.append(int(ys.max()) if len(ys) else -1)
    bots16 = []
    for i in range(6):
        m = a[:, i * FRAME:(i + 1) * FRAME][:, :, 3] >= 16
        bots16.append(int(np.where(m.any(axis=1))[0].max()) if m.any() else -1)
    foot = round((FRAME - 1 - max(bots16)) / FRAME, 4)
    print("strip: 实心高 %s | 底缘 %s 极差 %d | foot %s"
          % (hs, bots, max(bots) - min(bots), foot))
    meta = {"target_h": TARGET_H, "target_bot": TARGET_BOT, "target_cx": TARGET_CX,
            "s_glob": round(s_glob, 4), "d_pivot": round(d_pivot, 1),
            "wheels832": [[round(v, 1) for v in w] for w in wheels], "foot": foot}
    with open(os.path.join(OUT, "_%s_meta.json" % TAG), "w", encoding="utf-8") as f:
        json.dump(meta, f, ensure_ascii=False, indent=1)

    # GIF（归一后深底）
    gif = []
    for i in range(6):
        b = Image.new("RGB", (FRAME, FRAME), (40, 44, 52))
        fr = strip.crop((i * FRAME, 0, (i + 1) * FRAME, FRAME))
        b.paste(fr, (0, 0), fr)
        gif.append(b.resize((330, 330), Image.LANCZOS))
    gif[0].save(os.path.join(OUT, "%s_n_anim.gif" % TAG), save_all=True,
                append_images=gif[1:], duration=125, loop=0)
    print("[done] %s_{n_sheet_832,n_anim,_strip_1536,_wheel_dbg}.png" % TAG)


if __name__ == "__main__":
    main()
