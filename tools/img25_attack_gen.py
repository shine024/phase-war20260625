# -*- coding: utf-8 -*-
"""img25 锚定帧先行路线 · 阶段1工具：锚定帧 -> 10帧 5x2 开火雪碧图（2026-09-30 新路线）

用法:
    python tools/img25_attack_gen.py <key> [--roll N]

前置: staging/<key>_anchor_raw.png 已存在且经目检（阶段0产物，锚定帧=真身）。

产出（只落 staging）:
    <key>_attack_raw.png          10帧原始出图（chroma 底）
    <key>_attack_cells.png        10格键控后 alpha 包围盒裁切的 contact sheet（目检用）
    <key>_attack_anim.gif         规范化 256^2 八帧动图预览（实机尺寸节奏）

方法论: chongdashu/ai-game-spritesheets 06-attack-spritesheet（Image1=身份锚 +
Image2=裸网格布局导图分工；特效只活在攻击表）+ 08-normalization（alpha 包围盒
规范化：缩放对齐锚定帧、统一底缘基线、贴回固定画布）。
"""
import argparse
import base64
import io
import json
import os
import re
import subprocess
import sys
import time

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KEYS = re.findall(r'sk-[A-Za-z0-9]{20,}',
                  open(os.path.join(ROOT, 'tools', '_agnes_image_api.md'), encoding='utf-8').read())
IMG_API = "https://apihub.agnes-ai.cn/v1/images/generations"
WORK = os.path.join(ROOT, ".godot", "unit_review")
OUT = os.path.join(WORK, "img25_staging")
FS = 256

GUIDE_W, GUIDE_H = 1536, 1024  # 3x2 f0 铺格导图（2K 16:9 同比例；agnes 先验 3x2，5x2 被无视 09-30 实测）
COLS, ROWS = 3, 2
GAP = 24                       # 格间白带（模型照抄版式用；白带也是切格参照）


def data_uri(im):
    b = io.BytesIO()
    im.save(b, "PNG")
    return "data:image/png;base64," + base64.b64encode(b.getvalue()).decode()


def sheet_guide(anchor):
    """f0 铺格样例导图（旧路线 v2 已验证：模型照抄布局与身份）：
    锚定帧缩样复制 6 次铺 3x2，宽白带分隔，纯白背景。"""
    cw = (GUIDE_W - GAP * (COLS + 1)) // COLS
    ch = (GUIDE_H - GAP * (ROWS + 1)) // ROWS
    im = Image.new("RGB", (GUIDE_W, GUIDE_H), (255, 255, 255))
    tile = anchor.copy()
    tile.thumbnail((cw, ch))
    for r in range(ROWS):
        for c in range(COLS):
            x = GAP + c * (cw + GAP) + (cw - tile.size[0]) // 2
            y = GAP + r * (ch + GAP) + (ch - tile.size[1]) // 2
            im.paste(tile, (x, y))
    return im


def build_prompt(subject):
    return (
        "第二张图是成品布局示例：它展示的就是最终要交付的雪碧图版式——同一主体在 2 行 3 列共六个格子里各出现一次，"
        "格与格之间是很宽的纯白间隔带。成品必须完全照搬这个版式：六格的位置、间隔带宽度、主体的大小和底缘位置都与示例一致。\n"
        "第一张图是主体的身份锚定帧。六格画的都是同一个主体：与锚定帧完全同身份、同体型、同比例、同配色、同武器、"
        "同朝向（面朝画面正左方），以及与示例一致的纯色背景底色。\n"
        "任务：保持版式与主体大小不变，把六个格子画成" + subject + "面朝正左方的机炮开火动作序列，每格一个独立完整姿态，"
        "绝不把相邻几格画成连在一起的漫画分镜。\n"
        "格 1：中性悬停待机，与锚定帧完全一致，无任何特效；\n"
        "格 2：预备，机身微微下沉蓄力，炮口出现很小的橙色火点；\n"
        "格 3：开火！炮口焰在炮口位置爆发，明亮但不遮掩机身；\n"
        "格 4：火光衰减，炮口只剩一小簇短火舌；\n"
        "格 5：后坐，机身微微后缩，炮口挂着少量余烟；\n"
        "格 6：回到与格 1 完全一致的中性待机，余烟散尽（首尾闭合）。\n"
        "【硬性·大小】六格主体大小完全相同，如同同一张图复制粘贴 6 次，每格主体完整不出本格、不触碰画面四边。\n"
        "【硬性·站位】每格主体位于格子内偏右的位置（主体中心约在本格横向右侧 40% 处），格子左侧留出空间给火光。\n"
        "【硬性·朝向】六格全部面朝画面正左方，机炮指向画面左侧，绝不朝右，绝不允许正脸对镜头，绝不允许俯视或 3/4 视角。\n"
        "【硬性·分格】六格必须是六个相互独立、完整的姿态，任何炮管、火光、烟都不得伸进隔壁格子。\n"
        "【硬性·特效】没有弹道、没有弹丸、没有飞行物、没有光束——只有炮口火光和烟；"
        "火光和烟只贴在炮口位置且完整位于本格内部，绝不触碰格子边缘，绝不画在机尾或其他部位；除炮口焰与烟外无任何特效。\n"
        "【硬性·无地面】画面是悬在纯色背景前的空中小精灵：没有地面、没有地板、没有影子；炮口焰绝不在下方产生任何反光、光斑或倒影。\n"
        "不要数字、序号、文字、格子编号、边框线、地面、阴影、水印。"
    )


def gen_image(payload_path):
    for i in range(3):
        r = subprocess.run(["curl", "--http1.1", "-s", "-X", "POST", IMG_API,
                            "-H", "Authorization: Bearer " + KEYS[i % len(KEYS)],
                            "-H", "Content-Type: application/json",
                            "--data-binary", "@" + payload_path, "--max-time", "360"],
                           capture_output=True, text=True, timeout=380)
        try:
            d = json.loads(r.stdout)
        except Exception:
            print("  响应非 JSON:", r.stdout[:120], flush=True)
            time.sleep(15)
            continue
        if d.get("error") or d.get("code"):
            print("  API 报错:", json.dumps(d, ensure_ascii=False)[:180], flush=True)
            time.sleep(15)
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
                print("  URL 图不完整，重试…", flush=True)
                time.sleep(8)
    return None


# ---- 规范化（08 阶段：alpha 包围盒） ----

def detect_bg_color(im):
    """v2：全域量化直方图众数。v1 边框采样被 3:2 出图的白外框骗过
    （bg 误判白色，玫红背景整片残留，09-30 V3 实测）——雪碧图背景恒占面积大头，众数即背景。"""
    import numpy as np
    a = np.asarray(im.convert("RGB"))
    q = (a.astype(int) // 24).reshape(-1, 3)
    keys = q[:, 0] * 4096 + q[:, 1] * 64 + q[:, 2]
    vals, counts = np.unique(keys, return_counts=True)
    k = vals[counts.argmax()]
    med = a.reshape(-1, 3)[keys == k].mean(axis=0)
    return med


def chroma_key(im, bg, tol=85):
    """v2：背景候选 = 近背景色 | 近纯白（格间白带残留；边缘连通 BFS 保证机身内部
    白色高光不连通格缘、不会被误删。09-30 fut_nano_drone V2 白带 L 边实测）。"""
    import numpy as np
    from collections import deque
    a = np.asarray(im.convert("RGB")).astype(int)
    dist = np.sqrt(((a - bg) ** 2).sum(axis=2))
    near = dist < tol
    dw = np.abs(a - 255).max(axis=2)
    near = near | (dw < 30)
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
    out = im.convert("RGBA")
    out.putalpha(Image.fromarray(np.where(isbg, 0, 255).astype('uint8')))
    return out


def depink(rgba):
    """去粉（品红背景映衬系统色偏，旧路线沉淀）：粉/洋红调 → 灰。
    判定 R 明显高于 G 且 B 不低、亮度足——橙火 B 低不误杀，机身蓝/灰白炮管 R≈G 不命中。
    09-30 V5 格5 粉烟实测根治。"""
    import numpy as np
    a = np.asarray(rgba).astype(int)
    r, g, b, al = a[:, :, 0], a[:, :, 1], a[:, :, 2], a[:, :, 3]
    lum = (r + g + b) // 3
    hit = (r - g > 18) & (b >= g - 10) & (lum > 120) & (al > 8)
    out = a.copy()
    gr = lum[hit]
    out[:, :, 0][hit] = gr
    out[:, :, 1][hit] = gr
    out[:, :, 2][hit] = gr
    return Image.fromarray(out.astype('uint8'))


def keep_main_bodies(cell, keep_frac=0.35):
    """主体域保留 v2（09-30 V5 实测取代 v1 remove_islands）：
    全分辨率连通域，只保留 ≥最大域 35% 的域。v1 的 /4 降采样采不到 1px 细线
    （采样网格跳过该行），白带阴影线/光带残端全部逃过 5% 阈值污染 bbox——
    实测污染物全部 ≤主体 2% 且独立不连通，35% 全分辨率一网打尽。"""
    import numpy as np
    from collections import deque
    fg = np.asarray(cell)[:, :, 3] > 8
    h, w = fg.shape
    lab = np.zeros((h, w), dtype=int)
    nl = 0
    sizes = {}
    for yy in range(h):
        for xx in range(w):
            if fg[yy, xx] and lab[yy, xx] == 0:
                nl += 1
                lab[yy, xx] = nl
                dq = deque([(yy, xx)])
                n = 0
                while dq:
                    y, x = dq.popleft()
                    n += 1
                    for ny, nx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
                        if 0 <= ny < h and 0 <= nx < w and fg[ny, nx] and lab[ny, nx] == 0:
                            lab[ny, nx] = nl
                            dq.append((ny, nx))
                sizes[nl] = n
    if nl <= 1:
        return cell
    keep = {l for l, n in sizes.items() if n >= max(sizes.values()) * keep_frac}
    mask = np.isin(lab, list(keep))
    out = cell.copy()
    al = np.asarray(out)[:, :, 3].copy()
    al[~mask] = 0
    out.putalpha(Image.fromarray(al))
    return out


def alpha_bbox(im, min_px=40):
    import numpy as np
    a = np.asarray(im)[:, :, 3]
    ys, xs = np.where(a > 8)
    if len(xs) < min_px:
        return None
    return (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1)


def _blueish(px):
    """蓝青系近似判定（装甲色域掩膜）：b 最大且明显高于 g、r 最低。"""
    import numpy as np
    r, g, b = px[:, 0], px[:, 1], px[:, 2]
    return (b >= r) & (b - g > 10) & (g >= r - 10)


def fit_armor(src_rgba, card):
    """装甲色对齐卡图（09-30 fut_nano_drone 实测：色相 208vs209 同蓝，
    但亮度差 1.65x/饱和差 2x——Reinhard mean/std 迁移只作用于装甲蓝系像素，
    掩膜高斯羽化 2px；炮口黑环/橙火/灰烟不被迁移（全帧迁移会把黑环拉暗红、烟拉绿）。"""
    import numpy as np
    from PIL import ImageFilter
    cpx_all = np.asarray(card.convert("RGB")).astype(float).reshape(-1, 3)
    ref = cpx_all[_blueish(cpx_all)]
    a = np.asarray(src_rgba).astype(float)
    rgb, al = a[:, :, :3], a[:, :, 3]
    m = al > 8
    if m.sum() == 0 or len(ref) == 0:
        return src_rgba
    spx = rgb[m]
    armor = _blueish(spx)
    if armor.sum() < 100:
        return src_rgba
    ms, ss = spx[armor].mean(0), spx[armor].std(0) + 1e-5
    mr, sr = ref.mean(0), ref.std(0) + 1e-5
    h, w = m.shape
    wgt = np.zeros((h, w))
    wgt[m] = armor
    wimg = Image.fromarray((wgt * 255).astype('uint8')).filter(ImageFilter.GaussianBlur(2))
    wf = np.asarray(wimg).astype(float)[..., None] / 255
    transferred = np.clip((rgb - ms) * (sr / ss) + mr, 0, 255)
    blended = rgb * (1 - wf) + transferred * wf
    res = a.copy()
    res[:, :, :3] = np.where(m[..., None], blended, rgb)
    return Image.fromarray(res.astype('uint8'))


def facing(cell):
    """朝向提示性体检（09-30 cold_f4 沉淀）：机头尖细/机尾垂尾高——
    排除橙焰像素后比左右 1/4 窗口平均列高，L=朝左(标准) R=疑似镜像翻。
    准确率 22/24：焰帧偶误报、透视侧后视抓不到——只做提示人工复核，勿做硬门禁。"""
    import numpy as np
    a = np.asarray(cell)
    body = (a[:, :, 3] > 8) & ~((a[:, :, 0] > 140) & (a[:, :, 0] - a[:, :, 2] > 60))
    w = cell.size[0]
    q = max(1, w // 4)
    L = body[:, :q].sum() / q
    R = body[:, -q:].sum() / q
    return "L" if L < R else "R"


def strip_rail_cols(cell, min_len=100, ratio=1.8):
    """残线列/行清除（09-30 cold_f4 格3 白带竖线实测）：某列 alpha 行跨度>min_len
    且 >邻3列中位的 ratio 倍 → 白带边线紧贴主体的残线形态，整列清；行同理。"""
    import numpy as np
    a = np.asarray(cell).copy()
    al = a[:, :, 3] > 8
    for axis in (0, 1):  # 0=列(竖线) 1=行(横线)
        prof = al.sum(axis=axis)
        n = len(prof)
        for i in range(3, n - 3):
            v = prof[i]
            if v < min_len:
                continue
            nb = np.median(list(prof[i - 3:i]) + list(prof[i + 1:i + 4]))
            if v > ratio * max(nb, 1):
                if axis == 0:
                    a[:, i, 3] = 0
                else:
                    a[i, :, 3] = 0
    return Image.fromarray(a)


def sheet_direct(raw_path, key, card=None):
    """原样直出雪碧图（09-30 用户拍板，取代 256 重排贴回）：
    原图去底（键控+depink+主体域+残线列）+ 反格水平翻转修正 + 卡图对齐，
    六格 832² 原位拼回——高低前后保持模型原样，不缩放不重排。
    产出 <key>_attack_sheet_832.png（2496x1664, frame_size=832）+ 256 缩预览 GIF/contact。"""
    sheet = Image.open(raw_path).convert("RGB")
    W, H = sheet.size
    bg = detect_bg_color(sheet)
    keyed = chroma_key(sheet, bg)
    card_img = Image.open(card).convert("RGB") if card else None
    cw, ch = W // COLS, H // ROWS
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    flips = []
    for r in range(ROWS):
        for c in range(COLS):
            cell = keyed.crop((c * cw, r * ch, (c + 1) * cw, (r + 1) * ch))
            cell = keep_main_bodies(cell)
            cell = depink(cell)
            cell = strip_rail_cols(cell)
            if facing(cell) == "R":
                cell = cell.transpose(Image.FLIP_LEFT_RIGHT)
                flips.append(r * COLS + c + 1)
            if card_img is not None:
                cell = fit_armor(cell, card_img)
            out.paste(cell, (c * cw, r * ch), cell)
    out.save(os.path.join(OUT, "%s_attack_sheet_832.png" % key))
    # 256 缩预览（原位等比缩，保高低原样）
    frames = [out.crop((c * cw, r * ch, (c + 1) * cw, (r + 1) * ch)).resize((FS, FS), Image.LANCZOS)
              for r in range(ROWS) for c in range(COLS)]
    contact = Image.new("RGBA", (FS * len(frames) + 8 * (len(frames) + 1), FS + 16), (70, 70, 70, 255))
    for i, f in enumerate(frames):
        contact.paste(f, (8 + i * (FS + 8), 8), f)
    contact.convert("RGB").save(os.path.join(OUT, "%s_attack_cells.png" % key))
    bgc = Image.new("RGBA", (FS, FS), (60, 60, 60, 255))
    comp = []
    for f in frames:
        b = bgc.copy()
        b.paste(f, (0, 0), f)
        comp.append(b.convert("RGB"))
    comp[0].save(os.path.join(OUT, "%s_attack_anim.gif" % key), save_all=True,
                 append_images=comp[1:], duration=125, loop=0)
    pal = [frames[i] for i in (0, 1, 2, 3, len(frames) - 1, 3, 2, 1)][:8]
    comp2 = []
    for f in pal:
        b = bgc.copy()
        b.paste(f, (0, 0), f)
        comp2.append(b.convert("RGB"))
    comp2[0].save(os.path.join(OUT, "%s_attack_anim_pal8.gif" % key), save_all=True,
                  append_images=comp2[1:], duration=125, loop=0)
    print("  [%s] sheet_832 直出 翻转格%s 空格%d" % (key, flips or "无", 0))
    return out


def normalize_sheet(raw_path, key, card=None):
    """（旧路，已被 sheet_direct 取代保留作拼格兜底）切格 -> 键控 -> depink ->
    主体域保留 -> alpha 包围盒裁切 ->
    [可选] 装甲色对齐卡图 -> 全局统一缩放（宽约束优先：横向机体 70% 高规则装不下）
    + 右缘底缘锚定贴回 -> contact + 256^2 规范化帧 + GIF。
    右缘锚定 = 机身钉死（炮口朝左，火光向左伸缩不晃机身），09-30 用户拍板"主体靠右"。"""
    import numpy as np
    sheet = Image.open(raw_path).convert("RGB")
    W, H = sheet.size
    bg = detect_bg_color(sheet)
    keyed = chroma_key(sheet, bg)
    card_img = Image.open(card).convert("RGB") if card else None
    cw, ch = W // COLS, H // ROWS
    cells, boxes = [], []
    for r in range(ROWS):
        for c in range(COLS):
            cell = keyed.crop((c * cw, r * ch, (c + 1) * cw, (r + 1) * ch))
            cell = keep_main_bodies(cell)
            cell = depink(cell)
            bb = alpha_bbox(cell)
            if bb is None:
                print("  格 %d 空格" % (r * COLS + c + 1))
                cells.append(None)
                boxes.append(None)
                continue
            content = cell.crop(bb)
            if card_img is not None:
                content = fit_armor(content, card_img)
            cells.append(content)
            boxes.append(content.size)
            print("  格 %d 内容 %dx%d" % (r * COLS + c + 1, content.size[0], content.size[1]))
    ok = [c for c in cells if c is not None]
    if not ok:
        print("  无有效格")
        return
    # 全局唯一缩放：最宽帧（火光全伸）恰好入框——横向开火帧宽>高，70% 高规则必爆宽
    sc = (FS - 24) / max(c.size[0] for c in ok)
    frames = []
    for c in cells:
        cv = Image.new("RGBA", (FS, FS), (0, 0, 0, 0))
        if c is not None:
            nw, nh = max(1, int(c.size[0] * sc)), max(1, int(c.size[1] * sc))
            cc = c.resize((nw, nh), Image.LANCZOS)
            cv.paste(cc, (FS - nw - 12, FS - nh - 12), cc)  # 右缘+底缘锚定
        frames.append(cv)
    # contact sheet（规范化帧并排，即游戏所见）
    contact = Image.new("RGBA", (FS * len(frames) + 8 * (len(frames) + 1), FS + 16), (70, 70, 70, 255))
    for i, f in enumerate(frames):
        contact.paste(f, (8 + i * (FS + 8), 8), f)
    contact.convert("RGB").save(os.path.join(OUT, key + "_attack_cells.png"))
    # GIF 六帧直出（待机→蓄→火→衰减→后坐→闭合；空格跳过）
    order = list(range(COLS * ROWS))
    gif_frames = [frames[i] for i in order if cells[i] is not None]
    if len(gif_frames) >= 2:
        rgb = [f.convert("RGBA").copy() for f in gif_frames]
        bgc = Image.new("RGBA", (FS, FS), (60, 60, 60, 255))
        comp = []
        for f in rgb:
            b = bgc.copy()
            b.paste(f, (0, 0), f)
            comp.append(b.convert("RGB").resize((FS, FS), Image.NEAREST))
        comp[0].save(os.path.join(OUT, key + "_attack_anim.gif"), save_all=True,
                     append_images=comp[1:], duration=125, loop=0)
    # 结构体检：空格 / 尺寸离散 / 朝向可疑（提示性，人工复核；L=朝左标准）
    ok_cells = [b for b in boxes if b]
    import statistics
    hvar = statistics.pstdev([b[1] for b in ok_cells]) if len(ok_cells) > 1 else 0
    sus = [i + 1 for i, c in enumerate(cells) if c is not None and facing(c) == "R"]
    print("  [%s] 空格%d 高离散%.0f 朝向可疑%s  contact=%s_attack_cells.png gif=%s_attack_anim.gif(%d帧)" %
          (key, boxes.count(None), hvar, sus or "无", key, key, len(gif_frames)))
    return cells


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("key")
    ap.add_argument("--subject", default="这架未来派纳米武装无人机")
    ap.add_argument("--rolls", type=int, default=1, help="连掷 N 版（单掷波动大，多掷选优 09-30）")
    ap.add_argument("--card-align", action="store_true",
                    help="装甲色对齐卡图（Reinhard 迁移只动蓝系装甲，09-30 fut_nano_drone 实测）")
    ap.add_argument("--direct", action="store_true", default=True,
                    help="原样直出 832 雪碧图（09-30 用户拍板默认；--legacy-256 走旧重排路）")
    ap.add_argument("--legacy-256", dest="direct", action="store_false",
                    help="旧路：256 画布重排贴回（保留作拼格兜底）")
    args = ap.parse_args()

    anchor_path = os.path.join(OUT, args.key + "_anchor_raw.png")
    if not os.path.exists(anchor_path):
        print("缺锚定帧:", anchor_path, "先跑 img25_anchor_gen.py")
        sys.exit(1)
    anchor = Image.open(anchor_path).convert("RGB")

    guide = sheet_guide(anchor)
    uri_anchor = data_uri(anchor)
    uri_guide = data_uri(guide)
    payload = os.path.join(OUT, "_attack_payload.json")
    with open(payload, "w", encoding="utf-8") as f:
        f.write(json.dumps({"model": "agnes-image-2.5-flash",
                            "prompt": build_prompt(args.subject),
                            "size": "2K", "ratio": "3:2",  # 2K=2496x1664；3:2÷3x2网格=正方格832²，切格零裁损（09-30 文档对照）
                            "extra_body": {"image": [uri_anchor, uri_guide],
                                           "response_format": "b64_json"}},
                           ensure_ascii=False))
    print("生成中… 共 %d 掷" % args.rolls, flush=True)
    results = []
    for roll in range(1, args.rolls + 1):
        t0 = time.time()
        raw = gen_image(payload)
        if raw is None:
            print("  第 %d 掷失败" % roll, flush=True)
            continue
        suffix = "" if args.rolls == 1 else "_R%d" % roll
        raw_path = os.path.join(OUT, "%s_attack_raw%s.png" % (args.key, suffix))
        with open(raw_path, "wb") as f:
            f.write(raw)
        print("OK %s (%.0fs)" % (raw_path, time.time() - t0), flush=True)
        card = os.path.join(ROOT, "assets", "card_icons", "player", args.key + ".png") \
            if args.card_align else None
        if args.direct:
            sheet_direct(raw_path, args.key + suffix, card=card)
        else:
            normalize_sheet(raw_path, args.key + suffix, card=card)
        results.append((raw_path, None))
    if not results:
        print("全部掷次失败")
        sys.exit(2)


if __name__ == "__main__":
    main()
