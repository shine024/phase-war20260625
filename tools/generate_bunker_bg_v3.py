# -*- coding: utf-8 -*-
"""
generate_bunker_bg_v3.py —— 基地 v3 大底图烘焙（胶囊 + 一体外壳，720 单屏）
输入：docs/基地重设计/generated3/{shell_full, cap_*}.jpeg
      data/bunker_room_defs.gd（布局唯一真身——rect/side/tunnel_y/via/door_y/conn_y/shaft）
输出：assets/bunker/v3/bunker_bg_v3.png（初始亮暗按 gd 的 initial 字段）
      assets/bunker/v3/bunker_bg_v3_lit.png（全亮）
      assets/bunker/v3/cap_*.png（透明底胶囊，留档复用）
流程：shell_full 缩放到 1280x720 做底 → 岩层覆盖 → 按 gd GRID 画嵌套暗腔 →
      胶囊 aspect-fill 贴底嵌入（锁定=舱内涂黑）→ 隧道/竖井 → 反应堆辉光。
用法：python tools/generate_bunker_bg_v3.py
      （改布局只需编辑 data/bunker_room_defs.gd 的 rect 等字段，再跑本脚本）
"""
import os, re, random
from collections import deque
from PIL import Image, ImageDraw, ImageFilter, ImageEnhance

SRC = r"docs/基地重设计/generated3"
SRC4 = r"docs/基地重设计/generated4"
DST = r"assets/bunker/v3"
DEFS = r"data/bunker_room_defs.gd"

## ───────── 单源解析：几何读场景占位块（优先）/ gd rect（兜底），拓扑读 gd ─────────
SCENE = r"scenes/bunker/bunker_main.tscn"

def parse_scene_rects(path):
    """读场景里 14 个同名 ColorRect 占位块的矩形（编辑器可视化调整的真身）"""
    try:
        src = open(path, encoding="utf-8").read()
    except OSError:
        return {}
    rects = {}
    for m in re.finditer(r'\[node name="(\w+)" type="ColorRect" parent="\."\]([^\[]*)', src):
        o = {k: float(v) for k, v in re.findall(r'(offset_\w+) = ([\-\d.]+)', m.group(2))}
        need = ("offset_left", "offset_top", "offset_right", "offset_bottom")
        if all(k in o for k in need):
            rects[m.group(1)] = (o["offset_left"], o["offset_top"],
                                 o["offset_right"] - o["offset_left"],
                                 o["offset_bottom"] - o["offset_top"])
    return rects

def parse_defs(path):
    src = open(path, encoding="utf-8").read()
    ws = re.search(r'"world_size":\s*Vector2\(([\d.]+),\s*([\d.]+)\)', src)
    W, H = int(float(ws.group(1))), int(float(ws.group(2)))
    sh = re.search(r'"shaft":\s*\{([^}]*)\}', src)
    shaft = dict(re.findall(r'"(\w+)":\s*([\d.]+)', sh.group(1)))
    scene = parse_scene_rects(SCENE)
    rooms = []
    for rm in re.finditer(r'\{\s*"id":\s*"(\w+)".*?\}', src, re.S):
        b = rm.group(0)
        r = re.search(r'"rect":\s*Rect2\(([-\d.]+),\s*([-\d.]+),\s*([-\d.]+),\s*([-\d.]+)\)', b)
        if not r:
            continue
        # 场景占位块优先（编辑器拖拽结果），gd rect 兜底
        x, y, w, h = (int(v) for v in scene.get(rm.group(1), tuple(float(v) for v in r.groups())))
        side = re.search(r'"side":\s*"(\w)"', b)
        via = re.search(r'"via":\s*"(\w+)"', b)
        lit = "STATE_ACTIVE" in b
        # 隧道/井环线 = 房中心高（矩形推导，跟随拖拽）
        rooms.append((rm.group(1), x, y, w, h,
                      side.group(1) if side else "L",
                      y + h / 2.0,
                      via.group(1) if via else None, lit))
    return W, H, shaft, rooms

W, H, SHAFT, ROOMS = parse_defs(DEFS)
SHAFT_X1 = int(float(SHAFT["x1"])); SHAFT_X2 = int(float(SHAFT["x2"]))
SHAFT_TOP = int(float(SHAFT["top_y"])); SHAFT_BOT = int(float(SHAFT["bottom_y"]))

def _validate():
    ## 手工调布局的第一道反馈：越界/重叠/比例警告直打控制台
    problems = []
    for (rid, x, y, w, h, side, ty, via, lit) in ROOMS:
        if x < 0 or y < 0 or x + w > W or y + h > H:
            problems.append("越界: %s Rect2(%d,%d,%d,%d) 超出 %dx%d" % (rid, x, y, w, h, W, H))
        if abs(w / h - 1.79) > 0.35:
            print("[提示] %s 宽高比 %.2f（胶囊原生 1.79，偏差大将竖向裁切顶/底）" % (rid, w / h))
        if ty is not None and not (y <= ty <= y + h):
            problems.append("tunnel_y 越房: %s tunnel_y=%s 不在 y%d-%d 内" % (rid, ty, y, y + h))
        if via and not any(r[0] == via for r in ROOMS):
            problems.append("via 失联: %s → %s 不存在" % (rid, via))
    ids = [r[0] for r in ROOMS]
    for i in range(len(ROOMS)):
        for j in range(i + 1, len(ROOMS)):
            a, b = ROOMS[i], ROOMS[j]
            if not (a[1] + a[3] <= b[1] or b[1] + b[3] <= a[1] \
                    or a[2] + a[4] <= b[2] or b[2] + b[4] <= a[2]):
                problems.append("重叠: %s × %s" % (a[0], b[0]))
    if len(ROOMS) != 15:
        problems.append("房间数 %d ≠ 15（解析失败或漏房）" % len(ROOMS))
    for p in problems:
        print("[布局警告]", p)
    return not problems

def flood_white_to_alpha(im, thresh=238):
    im = im.convert("RGBA")
    w, h = im.size
    px = im.load()
    seen = bytearray(w * h)
    dq = deque()
    def white(p): return p[0] >= thresh and p[1] >= thresh and p[2] >= thresh
    for x in range(w):
        for y in (0, h - 1):
            if white(px[x, y]): dq.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            if white(px[x, y]): dq.append((x, y))
    while dq:
        x, y = dq.popleft()
        if x < 0 or x >= w or y < 0 or y >= h: continue
        i = y * w + x
        if seen[i]: continue
        p = px[x, y]
        if not (p[0] >= thresh and p[1] >= thresh and p[2] >= thresh): continue
        seen[i] = 1
        px[x, y] = (0, 0, 0, 0)
        dq.append((x + 1, y)); dq.append((x - 1, y)); dq.append((x, y + 1)); dq.append((x, y - 1))
    return im

def autocrop(im, pad=4):
    bbox = im.getchannel("A").getbbox()
    if not bbox: return im
    x0, y0, x1, y1 = bbox
    return im.crop((max(0, x0 - pad), max(0, y0 - pad),
                    min(im.width, x1 + pad), min(im.height, y1 + pad)))

def load_cap(rid):
    p = os.path.join(DST, "cap_%s.png" % rid)
    if not os.path.exists(p):
        return None   # 胶囊未生成（如新增房）→ 留空腔待补图
    return Image.open(p).convert("RGBA")

def aspect_fit(img, w, h):
    s = min(w / img.width, h / img.height)
    nw, nh = int(img.width * s + 0.5), int(img.height * s + 0.5)
    return img.resize((nw, nh), Image.LANCZOS)

def rounded_mask(w, h, r):
    m = Image.new("L", (w, h), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, w - 1, h - 1], radius=r, fill=255)
    return m

def build_base():
    shell = Image.open(os.path.join(SRC, "shell_full.jpeg")).convert("RGBA")
    s = H / shell.height
    shell = shell.resize((int(shell.width * s + 0.5), H), Image.LANCZOS)
    x0 = (shell.width - W) // 2
    canvas = shell.crop((x0, 0, x0 + W, H))
    # 外壳岩层里 AI 自画的空腔会从胶囊缝隙露出来（"多出一层"的根因）——
    # 用 v2 手绘岩层贴图把地下带（地表线以下）整片盖掉，顶部 36px 渐变融合
    rock_src = Image.open(r"assets/bunker/v2/bg_rock.png").convert("RGBA")
    rock = rock_src.resize((W, H - 330), Image.LANCZOS)
    # 压暗匹配外壳深色岩层（bg_rock 原图偏亮偏黄）
    rock = ImageEnhance.Brightness(rock).enhance(0.52)
    rock = ImageEnhance.Color(rock).enhance(0.82)
    mask = Image.new("L", (W, H - 330), 255)
    md = ImageDraw.Draw(mask)
    for i in range(36):
        md.line([(0, i), (W, i)], fill=int(255 * i / 36))
    canvas.alpha_composite(Image.composite(rock, Image.new("RGBA", rock.size), mask), (0, 330))
    return canvas

def bake(all_lit):
    random.seed(20260827)
    canvas = build_base()
    d = ImageDraw.Draw(canvas, "RGBA")
    # 嵌套暗腔（比房间矩形大 6px 的圆角暗槽，胶囊坐进去）
    for (rid, x, y, w, h, side, ty, via, init) in ROOMS:
        d.rounded_rectangle([x - 6, y - 6, x + w + 6, y + h + 6], radius=38,
                            fill=(10, 7, 5, 255), outline=(26, 20, 14, 255), width=3)
    # 竖井
    d.rectangle([SHAFT_X1, SHAFT_TOP, SHAFT_X2, SHAFT_BOT], fill=(5, 4, 3, 255))
    d.rectangle([SHAFT_X1, SHAFT_TOP, SHAFT_X2, SHAFT_BOT], outline=(28, 22, 15, 255), width=2)
    for (rid, x, y, w, h, side, ty, via, init) in ROOMS:
        if ty is None: continue
        d.rectangle([SHAFT_X1 - 2, ty - 3, SHAFT_X1 + 8, ty + 2], fill=(74, 65, 50, 255))
        d.rectangle([SHAFT_X2 - 8, ty - 3, SHAFT_X2 + 2, ty + 2], fill=(74, 65, 50, 255))
    # 隧道
    for (rid, x, y, w, h, side, ty, via, init) in ROOMS:
        if ty is None: continue
        tx0, tx1 = (x + w, SHAFT_X1) if side == "L" else (SHAFT_X2, x)
        if tx1 - tx0 < 8: continue
        d.rounded_rectangle([tx0, ty - 11, tx1, ty + 11], radius=8, fill=(7, 5, 3, 255))
        d.rounded_rectangle([tx0, ty - 11, tx1, ty + 11], radius=8, outline=(30, 24, 16, 255), width=2)
    # 胶囊嵌入：全部 aspect-fill 贴底（竖向裁顶保地面线与侧壁门洞；
    # 胶囊四边贴合房间矩形 → 房名/门位/隧道与胶囊逐边对齐，无黑边错位）
    for (rid, x, y, w, h, side, ty, via, init) in ROOMS:
        cap = load_cap(rid)
        if cap is None:
            print("[空腔] %s 胶囊未生成，留暗腔待补（generated4/cap_%s）" % (rid, rid))
            continue
        s = max(w / cap.width, h / cap.height)
        nw, nh = int(cap.width * s + 0.5), int(cap.height * s + 0.5)
        cap = cap.resize((nw, nh), Image.LANCZOS)
        cap = cap.crop(((nw - w) // 2, nh - h, (nw - w) // 2 + w, nh))
        px_, py_ = x, y
        if not (all_lit or init):
            cap = ImageEnhance.Brightness(cap).enhance(0.32)   # 涂黑：留轮廓
            cap = ImageEnhance.Color(cap).enhance(0.4)
            tint = Image.new("RGBA", cap.size, (18, 14, 10, 110))
            cap = Image.alpha_composite(cap, tint)
        canvas.alpha_composite(cap, (px_, py_))
        if all_lit or init:  # 光池（仓库青 / 其余暖）
            lw, lh = int(w * .9), int(h * .78)
            pool = Image.new("RGBA", (lw, lh), (0, 0, 0, 0))
            pd = ImageDraw.Draw(pool)
            pc = (120, 229, 255, 44) if rid == "depot" else (255, 170, 90, 40)
            pd.ellipse([lw * .05, lh * .04, lw * .95, lh * .92], fill=pc)
            canvas.alpha_composite(pool.filter(ImageFilter.GaussianBlur(20)),
                                   (x + (w - lw) // 2, y + (h - lh) // 2))
    # 反应堆辉光 + 岩缝
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    # 反应堆辉光跟随房间矩形中心（布局可随意调，辉光自动跟随）
    rk = [r for r in ROOMS if r[0] == "reactor"]
    cx = rk[0][1] + rk[0][3] // 2 if rk else 650
    cy = rk[0][2] + rk[0][4] // 2 if rk else 610
    for r, a in [(240, 15), (170, 22), (95, 34), (42, 50)]:
        gd.ellipse([cx - r, cy - int(r * .6), cx + r, cy + int(r * .6)], fill=(255, 120, 46, a))
    canvas.alpha_composite(glow.filter(ImageFilter.GaussianBlur(24)))
    for (fx, fy, ang, ln) in [(560, 600, -24, 76), (740, 608, 20, 68), (648, 588, 4, 58)]:
        import math
        ck = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        cd = ImageDraw.Draw(ck)
        cd.line([fx, fy, fx + int(ln * math.cos(math.radians(ang))), fy - int(ln * math.sin(math.radians(ang)))],
                fill=(255, 130, 50, 110), width=4)
        canvas.alpha_composite(ck.filter(ImageFilter.GaussianBlur(3)))
    return canvas.convert("RGB")

if __name__ == "__main__":
    os.chdir(os.path.join(os.path.dirname(__file__), ".."))
    print("[布局源] %s → %d 房间，竖井 x%d-%d y%d-%d" % (
        DEFS, len(ROOMS), SHAFT_X1, SHAFT_X2, SHAFT_TOP, SHAFT_BOT))
    ok = _validate()
    if not ok:
        print("[中止] 布局有硬伤（越界/重叠/via 失联），修好 data/bunker_room_defs.gd 再烘焙")
        raise SystemExit(1)
    os.makedirs(DST, exist_ok=True)
    # 胶囊抠图落盘（generated3 在前、generated4 在后——同 id 后批覆盖前批；
    # 文件名 _v2 等版本后缀自动剥掉，如 cap_depot_v2 → cap_depot）
    for src_dir in [SRC, SRC4]:
        if not os.path.isdir(src_dir):
            continue
        for f in sorted(os.listdir(src_dir)):
            if f.startswith("cap_") and f.lower().endswith((".jpeg", ".jpg", ".png")):
                name = re.sub(r"_v\d+$", "", os.path.splitext(f)[0])
                out = os.path.join(DST, name + ".png")
                autocrop(flood_white_to_alpha(Image.open(os.path.join(src_dir, f)))).save(out)
                print("[cap ]", name, "<-", src_dir)
    dark = bake(False); dark.save(os.path.join(DST, "bunker_bg_v3.png"))
    print("saved bunker_bg_v3.png", dark.size)
    lit = bake(True); lit.save(os.path.join(DST, "bunker_bg_v3_lit.png"))
    print("saved bunker_bg_v3_lit.png", lit.size)
