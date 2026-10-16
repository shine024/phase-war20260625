# -*- coding: utf-8 -*-
"""纯 API 精灵帧生成管线（试点参考实现）——agnes-image-2.5-flash i2i 6 帧 attack 批。
方法论与门禁见 docs/API精灵图生成工作流_v1.md；键控口径沿 FLOW 品红链 + 投影扩键（本脚本新增，见 §键控）。
v2: 默认 GRID 模式——6 帧一次 i2i 画 3×2 网格（单次生成帧间天然一致；逐帧单掷模式经
2026-10-12 试点实测武器/盔网帧间漂移，QC 不通过，仅留 --mode single 备查）。
用法: python tools/api_sprite_pipeline/generate_attack_api.py <unit_id> [--mode grid|single]
产物: .godot/unit_review/api_<unit>/  (raw/ 原图, ledger.json 台账, sheet_attack_api.png, frames/)
部署前必须过 FLOW §12 门禁 + 实机验收（v32.2: 帧数=anim.json counts）。
"""
import base64, io, json, os, subprocess, sys, time
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
WS = os.path.abspath(os.path.join(HERE, "..", ".."))
UNIT = sys.argv[1] if len(sys.argv) > 1 else "ww2_arm_garand_para"
MODEL = "agnes-image-2.5-flash"
OUT = os.path.join(WS, ".godot", "unit_review", "api_" + UNIT)
RAW = os.path.join(OUT, "raw")
os.makedirs(RAW, exist_ok=True)

ANIM_DIR = os.path.join(WS, "assets", "effects", "unit_anims", UNIT)
anim = json.load(open(os.path.join(ANIM_DIR, "anim.json"), encoding="utf-8"))
FS = anim["frame_size"]; N = anim["counts"]["attack"]
FOOT_FRAC = anim.get("foot_frac", 0.045)

# ---- 骨架（V3 定稿，2026-10-12 冒烟 5 掷沉淀；改骨架=整批重跑，见工作流文档 §2.2/§7）----
SKELETON = """STRICTLY a pure 2D side profile silhouette view, absolutely NO front view, NO three-quarter view, flat orthographic game sprite, single subject only centered,
{SUBJECT}
matte painting style, detailed weathering and surface texture, FLAT EVEN MATTE LIGHTING with uniform brightness across the figure, NO dramatic shadows, NO rim light, NO specular highlights, the lighting is identical in every panel, clean flat game-sprite colors,
the entire background is one perfectly flat uniform bright pure magenta #FF00FF color fill covering the canvas edge to edge, exactly like a solid color fill in an image editor: no vignette, no gradient, no lighting falloff, no texture anywhere,
centered composition, full body fitting in frame with generous empty margin, NO text, NO watermark, NO ground, NO scene background"""

# {SUBJECT} 共用头部（单位特征锁死）——换单位只改这一段
SUBJECT_BASE = (
    "A World War II US Army paratrooper, exactly the same soldier as in the reference image: "
    "M1 steel helmet with net, olive drab M1943 field jacket, cargo trousers bloused into brown leather boots, "
    "canvas suspenders and hip pack. He holds the exact same M1 Garand rifle as in the reference: long rifle with "
    "full-length wooden stock, simple iron sights only, gas tube under the barrel, leather sling hanging down, "
    "NO scope, NO pistol grip, NO detachable magazine, NO radio antenna. FACING LEFT in profile, ")
# 6 帧动作差分——批次内唯一变量（剪影差异最大化，降低模型姿态合并）
# 动作语义标准见工作流文档 §6.1: 焰仅击发帧/枪路径连续/质心连续/全程侧身朝左/循环闭合
# ⚠️ pose 内禁用否定句（"no flash"类会反激活掉枪, 2026-10-12 两卷实证）; 禁止写翻面诱导词（kicked up）
# v6 (2026-10-12 用户实机反馈"个别动作过于夸张"): 撤掉全部数字角度——模型对 "20/45 degrees"
# 过度执行（v4/v5 卷 f4 20° 被画成 ~45°, 与 f1 举枪同角=夸张主诉真身），全改定性措辞。
# v4 同期沉淀: "clip clearly visible in the air" 诱发木箱误读→弱化成 floating just above;
# "lowering 斜携" 被读成带焰击发→ settled aim（静止直立与 f2 前倾压枪区分）。
POSES = [
    "mounting the rifle: both hands raising the rifle diagonally across his chest toward his shoulder, muzzle pointing up-left, rifle below his shoulder line, body square in profile",
    "aiming: rifle stock welded into his shoulder, cheek down on the stock, muzzle perfectly horizontal to the left, both hands gripping the rifle",
    "firing: rifle discharging with a compact star-shaped muzzle flash attached directly at the muzzle, orange-yellow with a white core, whole body braced against the shot",
    "recoil: the muzzle stays level on the horizontal aiming line, the whole upper body leaning slightly back against the shot, both hands still gripping the rifle, feet planted",
    "settling back: the muzzle held just above horizontal, the rifle braced at his shoulder, a small brass clip floating just above the rifle's receiver, upper body straightening up",
    "the rifle held level in front of his chest with both hands, muzzle pointing left, a calm ready stance, feet planted",
]

# ---- API 调用（curl --http1.1 实测姿势；401=key 失效轮换，503=队列满重试）----
def load_keys():
    return [l.strip() for l in open(os.path.join(WS, "tools", "_api_key.txt"), encoding="utf-8")
            if l.strip().startswith("sk-")]

def gen_i2i(prompt, ref_b64, keys, start_idx, tag, image_size="1024x1024"):
    body = {"model": MODEL, "prompt": prompt, "image_size": image_size,
            "extra_body": {"image": ["data:image/png;base64," + ref_b64], "response_format": "url"}}
    pf = os.path.join(RAW, "payload_%s.json" % tag)
    json.dump(body, open(pf, "w"))
    for att in range(6):
        key = keys[(start_idx + att) % len(keys)]
        r = subprocess.run(
            ["curl", "--http1.1", "-sS", "-m", "300", "-X", "POST",
             "https://apihub.agnes-ai.com/v1/images/generations",
             "-H", "Authorization: Bearer " + key, "-H", "Content-Type: application/json",
             "-d", "@" + pf, "-w", "\nHTTP_CODE:%{http_code}"],
            capture_output=True, text=True, encoding="utf-8", errors="replace")
        out = r.stdout
        try:
            js = json.loads(out.rsplit("\nHTTP_CODE:", 1)[0])
        except Exception:
            print("  [%s] att%d unparseable, retry" % (tag, att)); time.sleep(5); continue
        if "data" in js and js["data"] and js["data"][0].get("url"):
            url = js["data"][0]["url"]
            if "/i2i/" not in url:
                print("  [%s] att%d i2i 标志缺失, retry" % (tag, att)); time.sleep(5); continue
            return url, key[:12]
        msg = js.get("error", {}).get("message", out[:120])
        print("  [%s] att%d fail: %s" % (tag, att, msg)); time.sleep(6)
    raise RuntimeError("gen_i2i failed: " + tag)

# ---- 键控（FLOW 品红判据 + 投影扩键；判据依据见脚本头注释与工作流文档）----
import numpy as np

def key_magenta(rgb):
    cell = rgb.astype(int)
    r, g, b = cell[:, :, 0], cell[:, :, 1], cell[:, :, 2]
    mag = (r > 140) & (b > 140) & (g < 0.75 * np.minimum(r, b) - 10)
    # 投影扩键: 品红底上的紫红投影（g 压得极低且蓝分量偏高）; 棕靴(b<g 或 min 极低)/描边(r≤90)安全
    shadow = (r > 90) & (b > 55) & (b > 0.55 * r) & (g < 0.5 * np.minimum(r, b))
    alpha = np.where(mag | shadow, 0, 255).astype(np.uint8)

    despill = cell.copy()
    violet = (~(mag | shadow)) & (r > 120) & (b > 120) & (g < 0.8 * np.minimum(r, b))
    new_rb = (r + b) // 2
    for ch in (0, 2):
        despill[:, :, ch] = np.where(violet, (new_rb * 0.5 + despill[:, :, ch] * 0.5), despill[:, :, ch])

    # 二次键控
    r2, g2, b2 = despill[:, :, 0].astype(int), despill[:, :, 1].astype(int), despill[:, :, 2].astype(int)
    mag2 = ((r2 > 140) & (b2 > 140) & (g2 < 0.75 * np.minimum(r2, b2) - 10)) | \
           ((r2 > 90) & (b2 > 55) & (b2 > 0.55 * r2) & (g2 < 0.5 * np.minimum(r2, b2)))
    alpha[mag2] = 0

    # 1px 羽化
    opaque = alpha == 255
    neigh = np.zeros_like(opaque)
    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        neigh |= ~np.roll(np.roll(opaque, dy, 0), dx, 1)
    alpha[opaque & neigh] = 140
    return np.dstack([despill.astype(np.uint8), alpha])

def largest_component(alpha):
    """只保留最大不透明连通域（孤立残渣/飞溅剔除）。4 邻接 BFS。"""
    h, w = alpha.shape
    solid = alpha > 0
    seen = np.zeros_like(solid, bool)
    best, bestsz = None, 0
    for yy in range(h):
        for xx in range(w):
            if solid[yy, xx] and not seen[yy, xx]:
                stack = [(yy, xx)]; seen[yy, xx] = True; comp = []
                while stack:
                    y, x = stack.pop(); comp.append((y, x))
                    for ny, nx in ((y+1,x),(y-1,x),(y,x+1),(y,x-1)):
                        if 0 <= ny < h and 0 <= nx < w and solid[ny, nx] and not seen[ny, nx]:
                            seen[ny, nx] = True; stack.append((ny, nx))
                if len(comp) > bestsz:
                    bestsz, best = len(comp), comp
    out = np.zeros_like(alpha)
    for y, x in best:
        out[y, x] = alpha[y, x]
    return out, bestsz

def stance_x_of(rgba, band=0.40):
    """横向稳定锚点: 中间 40% 内容带(躯干)的像素均值 x。跨姿态稳定、不受枪/焰伸长的影响。
    人形单位躯干 x≈脚部 x(脚在躯干正下), 即用户'人形以脚部为准靠右'的稳健近似;
    比扫底缘 18% 更稳(垂枪帧枪尖会沉到底缘污染脚部扫描)。"""
    a = rgba[:, :, 3]
    h = a.shape[0]
    y0, y1 = int(h * (0.5 - band / 2)), int(h * (0.5 + band / 2))
    ys, xs = np.where(a[y0:y1, :] > 40)
    if len(xs) == 0:
        return None
    return int(xs.mean())

def normalize_frame(rgba, canvas, foot_frac, scale, stance_frac=0.60):
    """全局统一缩放（2026-10-12 教训: 逐帧 bbox 归一会让竖枪帧人体缩小 25%+）。
    同一底稿出的网格帧天然等大, 用瞄准帧定标一次、全帧共用 scale。底边距=foot_frac×canvas。
    横向锚定(2026-10-12 用户拍板): 不居中——各帧内容宽差大(开火帧带焰更宽), 居中会让身体左右跳。
    改按躯干/脚部 x 均值对齐到 canvas×stance_frac(默认 0.60=靠右留空给枪口焰向左伸), 全帧一致。"""
    a = rgba[:, :, 3]
    ys, xs = np.where(a > 20)
    x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
    crop = Image.fromarray(rgba[y0:y1 + 1, x0:x1 + 1])
    # 画布安全钳位: 竖枪/后坐帧总高超界时局部缩小（仅防出界, 不破坏全局一致性基线）
    max_ch = int(canvas * (1 - foot_frac)) - 4
    s = scale
    if crop.height * s > max_ch:
        s = max_ch / crop.height
    cw = max(1, int(round(crop.width * s)))
    ch = max(1, int(round(crop.height * s)))
    crop = crop.resize((cw, ch), Image.LANCZOS)
    crop_rgba = np.asarray(crop)
    sx = stance_x_of(crop_rgba)
    target = int(canvas * stance_frac)
    paste_x = (target - sx) if sx is not None else (canvas - cw) // 2
    paste_x = max(0, min(paste_x, canvas - cw))  # 安全钳位(武器越左缘/身体越右缘时)
    out = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    out.paste(crop, (paste_x, canvas - ch - int(round(foot_frac * canvas))), crop)
    return out

# ---- 主流程 ----
MODE = "grid"
for _i, _a in enumerate(sys.argv):
    if _a == "--mode" and _i + 1 < len(sys.argv):
        MODE = sys.argv[_i + 1]

GRID_POS = ["top-left", "top-middle", "top-right", "bottom-left", "bottom-middle", "bottom-right"]

def label_components(alpha, want_labels=False):
    """全图 alpha 连通域标记（4邻接, 仅不透明像素）。
    返回 comps=[(size, bbox), ...] 按大小降序; want_labels 时附 (labels, comps数组序号+1)。"""
    solid = alpha > 0
    h, w = solid.shape
    seen = np.zeros_like(solid, bool)
    labels = np.zeros((h, w), np.int32) if want_labels else None
    comps = []
    cid = 0
    for yy in range(h):
        xs_row = np.where(solid[yy] & ~seen[yy])[0]
        for xx in xs_row:
            if seen[yy, xx]:
                continue
            cid += 1
            stack = [(yy, int(xx))]
            seen[yy, xx] = True
            n = 0
            x0 = x1 = xx; y0 = y1 = yy
            while stack:
                y, x = stack.pop()
                n += 1
                if want_labels:
                    labels[y, x] = cid
                if x < x0: x0 = x
                if x > x1: x1 = x
                if y < y0: y0 = y
                if y > y1: y1 = y
                for ny, nx in ((y+1,x),(y-1,x),(y,x+1),(y,x-1)):
                    if 0 <= ny < h and 0 <= nx < w and solid[ny, nx] and not seen[ny, nx]:
                        seen[ny, nx] = True
                        stack.append((ny, nx))
            comps.append((n, (x0, y0, x1, y1), cid))
    comps.sort(key=lambda c: -c[0])
    return (comps, labels) if want_labels else comps

def grid_to_frames(grid_rgb):
    """整图键控 → 连通域提取 → 阅读顺序排序（上排x序→下排x序）。
    返回 (alpha, labels, comps排序后6项) 或 (None, None, 失败原因)。"""
    a = key_magenta(np.asarray(grid_rgb.convert("RGB")))
    alpha = a[:, :, 3]
    comps, labels = label_components(alpha, want_labels=True)
    comps = [c for c in comps if c[0] > 3000]  # 剔除碎屑
    if len(comps) != 6:
        return None, None, "主连通域数=%d (期望6, 碎屑已滤)" % len(comps)
    # 阅读顺序: 上排(y中心<半高)按x, 下排按x
    H = alpha.shape[0]
    def key(c):
        x0, y0, x1, y1 = c[1]
        return ((y0 + y1) // 2 >= H // 2, (x0 + x1) // 2)
    comps.sort(key=key)
    # 落地线一致性: 逐排校验（上/下排各一条脚线）, 排内底边差 ≤40px
    H = alpha.shape[0]
    top = [c for c in comps if (c[1][1] + c[1][3]) // 2 < H // 2]
    bot = [c for c in comps if c not in top]
    for name, row in (("上排", top), ("下排", bot)):
        if not row:
            return None, None, "%s无连通域" % name
        feet = [c[1][3] for c in row]
        if max(feet) - min(feet) > 40:
            return None, None, "%s落地线漂移 %.0fpx >40: %s" % (name, max(feet) - min(feet), feet)
    # 宽度签名预筛: f5/f6 空手站姿高发（2026-10-12 坏卷签名 w/h≈0.30, 持枪胸姿≈0.55+）
    # 仅对第 5/6 域硬卡 0.4; 其余帧竖举枪等窄剪影属正当, 仅记录
    H2 = alpha.shape[0]
    notes = []
    for i, c in enumerate(comps):
        x0, y0, x1, y1 = c[1]
        w, h = x1 - x0, y1 - y0
        if w < 0.4 * h:
            if i >= 4:
                return None, None, "f%d 疑缺枪 (w=%d h=%d, w/h=%.2f<0.4)" % (i + 1, w, h, w / h)
            notes.append("f%d 窄剪影 w/h=%.2f（竖枪姿属正当, 仅记录）" % (i + 1, w / h))
    if notes:
        print("  note:", "; ".join(notes))
    return alpha, labels, comps

def build_grid_template(idle, fs):
    """6 格底稿: 1024² 原生方画布（i2i 输出固定 1024², 见 2026-10-12 实测）, 3×2 格 341×512。
    人物必须完整落在格内（2026-10-12 教训: side=380>格宽341 导致成品帧左右截断）,
    且六格脚底线对齐（落地线一致→成片连贯）。返回 (template_RGB, cell_w, cell_h)。"""
    TW = TH = 1024
    cw, ch = TW / 3.0, TH / 2.0
    tpl = Image.new("RGBA", (TW, TH), (255, 0, 255, 255))
    f0 = idle.crop((0, 0, fs, fs))
    side = 240  # < 格宽 341, 给水平持枪的枪口左向越伸留余量（~50px/侧）
    f0s = f0.resize((side, side), Image.LANCZOS)
    foot_pad = 28  # 六格统一: f0 底边距格底 28px（脚底线对齐）
    for r in range(2):
        for c in range(3):
            x = int(round(c * cw + (cw - side) / 2))
            y = int(round((r + 1) * ch - foot_pad - side))
            tpl.paste(f0s, (x, y), f0s)
    return tpl.convert("RGB"), cw, ch

def build_grid_template_card(card, fs):
    """6 格底稿（512 卡图版, 2026-10-12 用户实机反馈后新增）: 锚点=assets/card_icons/<side>/<unit>.png。
    idle f0 带烘焙粗描线+白色残影, i2i 忠实复现→成品发闷失精细（roll 7 用户主诉）; 卡图无描线、
    matting 细节足。约束与 idle 版同: 人物完整落格内（bbox 裁剪后按格宽定标, 不上放大）、
    六格脚线对齐、品红底由 prompt 锁死。"""
    TW = TH = 1024
    cw, ch = TW / 3.0, TH / 2.0
    fig = card.crop(card.getbbox())
    margin, foot_pad = 36, 28
    maxw, maxh = cw - 2 * margin, ch - foot_pad - 8
    s = min(maxw / fig.width, maxh / fig.height, 1.0)
    fw, fh = int(fig.width * s), int(fig.height * s)
    fig2 = fig.resize((fw, fh), Image.LANCZOS)
    tpl = Image.new("RGBA", (TW, TH), (255, 0, 255, 255))
    for r in range(2):
        for c in range(3):
            x = int(round(c * cw + (cw - fw) / 2))
            y = int(round((r + 1) * ch - foot_pad - fh))
            tpl.paste(fig2, (x, y), fig2)
    return tpl.convert("RGB")

# ---- card4 模式: 4 格高分辨率动作帧 + 原卡图书挡首尾, 合成 6 帧（用户 2026-10-12 定案）----
# 首帧/尾帧=原卡图(稳定、与卡面一致、循环无跳变), 中间 4 帧=动作帧。
# 一张 1024² 只塞 4 格(每格 512, 人物~440px 不上降采样), 细节预算比 6 格(341px)高 ~50%。
# V9 (2026-10-12 用户拍板"动作做小, 减少大跳变"): 4 动作帧收窄成"贴肩短程"——
# f2 仅从斜携小幅上抬(贴近书挡斜携姿)、f3 击发(唯一焰)、f4 后坐小幅、f5 小幅回落(贴近书挡)。
# 首尾动作帧都靠近书挡姿态 → 循环两端跳变小; 中间两帧收在肩线附近, 相邻姿态差小。
POSES4 = [
    "raising the rifle: both hands easing the rifle up from his side to just below his shoulder, muzzle rising to the left, one small step into the aim",
    "firing: rifle braced at his shoulder with a compact star-shaped muzzle flash at the muzzle, orange-yellow with a white core, body braced against the shot",
    "recoil: the muzzle lifting only slightly upward, the stock easing back, upper body leaning gently back, both hands still gripping the rifle, feet planted",
    "lowering the rifle: both hands easing the rifle back down toward his side, muzzle pointing down-left, returning to the relaxed ready carry, one small step out of the aim",
]
GRID4_POS = ["top-left", "top-right", "bottom-left", "bottom-right"]

# 单图卡图（准备姿态）——cardgen 模式: 用生成帧做 i2i 参考反向产一张干净卡图(与动作帧同风格/色/朝向),
# 治原 512 卡图质量差(残留白底+色差+放进精灵帧方向错)。
CARD_READY_POSE = ("standing in a relaxed ready posture mid-walk, holding the M1 Garand rifle at his side "
                   "with one hand, muzzle pointing down-left, the other hand free at his side, ")

def build_grid_template_4_card(card, fs, scale_cap=1.0):
    """4 格底稿(2x2, 每格 512): 卡图人物按原生尺寸(~440px)落格, 不上降采样→细节预算高。
    scale_cap<1 时整体再缩(2026-10-13: 火箭筒卷人物缩小留宽品红沟, 给火光/筒口余量防越中线熔连)。"""
    TW = TH = 1024
    cw, ch = TW / 2.0, TH / 2.0
    fig = card.crop(card.getbbox())
    margin, foot_pad = 44, 34
    maxw, maxh = cw - 2 * margin, ch - foot_pad - 8
    s = min(maxw / fig.width, maxh / fig.height, 1.0) * scale_cap
    fw, fh = int(fig.width * s), int(fig.height * s)
    fig2 = fig.resize((fw, fh), Image.LANCZOS)
    tpl = Image.new("RGBA", (TW, TH), (255, 0, 255, 255))
    for r in range(2):
        for c in range(2):
            x = int(round(c * cw + (cw - fw) / 2))
            y = int(round((r + 1) * ch - foot_pad - fh))
            tpl.paste(fig2, (x, y), fig2)
    return tpl.convert("RGB")

def grid4_prompt():
    invariant = ("facing LEFT in profile, holding his M1 Garand rifle in his hands (never empty-handed), "
                 "simple iron sights only, NO scope")
    parts = []
    for i, pose in enumerate(POSES4):
        parts.append("%s: the same soldier %s, %s;" % (GRID4_POS[i], pose, invariant))
    flash = ("The star-shaped muzzle flash appears in ONLY ONE panel, the firing panel (top-right): small, "
             "orange-yellow with a white core, attached directly to the rifle muzzle, touching it. "
             "No other panel has any flash or smoke. ")
    return SKELETON.replace("{SUBJECT}", SUBJECT_BASE + (
        "shown in a regular grid of exactly 4 flat panels, 2 columns and 2 rows, "
        "all 4 panels showing THE SAME soldier with THE SAME rifle, helmet and gear, "
        "identical scale, identical colors and identical rendering in every panel, and NO shadow under any figure. "
        + " ".join(parts) + " " + flash +
        "Keep the exact 4-panel grid layout, panel positions and spacing of the reference image unchanged, "
        "changing only the soldier's pose in each panel as listed. "
        "One complete figure centered in each panel, generous empty magenta spacing between panels, "
        "no panel borders, no grid lines, no labels, no numbers.") + "\n")

def grid4_to_frames(grid_rgb):
    """整图键控→4 连通域, 2x2 阅读序(上左/上右/下左/下右)。"""
    a = key_magenta(np.asarray(grid_rgb.convert("RGB")))
    alpha = a[:, :, 3]
    comps, labels = label_components(alpha, want_labels=True)
    comps = [c for c in comps if c[0] > 3000]
    if len(comps) != 4:
        return None, None, "主连通域数=%d (期望4, 碎屑已滤)" % len(comps)
    H, W = alpha.shape
    def key(c):
        x0, y0, x1, y1 = c[1]
        return ((y0 + y1) // 2 >= H // 2, (x0 + x1) // 2 >= W // 2)
    comps.sort(key=key)
    H2 = alpha.shape[0]
    top = [c for c in comps if (c[1][1] + c[1][3]) // 2 < H // 2]
    bot = [c for c in comps if c not in top]
    for name, row in (("上排", top), ("下排", bot)):
        if len(row) != 2:
            return None, None, "%s连通域数=%d (期望2)" % (name, len(row))
        feet = [c[1][3] for c in row]
        if max(feet) - min(feet) > 60:
            return None, None, "%s落地线漂移 %.0fpx>60: %s" % (name, max(feet) - min(feet), feet)
    return alpha, labels, comps

def facing_flip(rgba, upper_frac=0.75, torso_lo=0.30, torso_hi=0.70):
    """翻面检测（朝左单位）: 上半区内容, 枪口/手臂向左伸应 > 向右伸。
    右伸 > 左伸+6 ⇒ 判为翻面(朝右)。躯干 x 独立于画布锚定(用人形自身躯干带均值), 锚定无关。
    2026-10-12 校准: 开火帧 127:62 / 垂枪帧 54:38 / 书挡 100:40, 全朝左, 阈值稳。"""
    a = rgba[:, :, 3]
    ys, xs = np.where(a > 40)
    if len(xs) == 0:
        return False
    H = a.shape[0]
    y0 = int(ys.min())
    uy1 = y0 + int((ys.max() - y0) * upper_frac)
    mx = np.where(a[y0:uy1, :] > 40)[1]
    if len(mx) == 0:
        return False
    tx = np.where(a[int(H * torso_lo):int(H * torso_hi), :] > 40)[1]
    if len(tx) == 0:
        return False
    torso = tx.mean()
    left_reach, right_reach = torso - mx.min(), mx.max() - torso
    return right_reach > left_reach + 6

def grid4_flip_check(grid_rgb, alpha_full, labels, comps4):
    """逐格翻面检测。返回 (flipped_tags, msgs): 任一动作格翻面=废卷。"""
    msg = []
    flipped = []
    for i, (npx, bbox, cid) in enumerate(comps4):
        x0, y0, x1, y1 = bbox
        sub = np.dstack([np.asarray(grid_rgb)[y0:y1 + 1, x0:x1 + 1],
                         np.where(labels[y0:y1 + 1, x0:x1 + 1] == cid, 255, 0).astype(np.uint8)])
        if facing_flip(sub):
            flipped.append("f%d" % (i + 2))
            msg.append("f%d 翻面(朝右)" % (i + 2))
    return flipped, msg

def render_bookend(card, FS, FOOT_FRAC, target_h, tag):
    """书挡帧: 原卡图(透明底)按瞄准帧目标内容高缩放, 脚线对齐 foot_frac, 直接进 256 画布。"""
    rgba = np.asarray(card.convert("RGBA"))
    ys, xs = np.where(rgba[:, :, 3] > 20)
    x0, x1, y0, y1 = int(xs.min()), int(xs.max()), int(ys.min()), int(ys.max())
    pad = 2
    x0 = max(0, x0 - pad); y0 = max(0, y0 - pad)
    x1 = min(rgba.shape[1] - 1, x1 + pad); y1 = min(rgba.shape[0] - 1, y1 + pad)
    crop = Image.fromarray(rgba[y0:y1 + 1, x0:x1 + 1])
    ch = y1 - y0 + 1
    s = target_h / ch
    cw = max(1, int(round(crop.width * s)))
    ch2 = max(1, int(round(ch * s)))
    crop = crop.resize((cw, ch2), Image.LANCZOS)
    out = Image.new("RGBA", (FS, FS), (0, 0, 0, 0))
    sx = stance_x_of(np.asarray(crop))
    target = int(FS * 0.60)
    paste_x = (target - sx) if sx is not None else (FS - cw) // 2
    paste_x = max(0, min(paste_x, FS - cw))
    out.paste(crop, (paste_x, FS - ch2 - int(round(FOOT_FRAC * FS))), crop)
    out.save(os.path.join(OUT, "frames", tag + ".png"))
    print("  %s 书挡帧(原卡图, 目标高=%dpx→%dpx)" % (tag, ch, ch2))
    return out

def gen_ready_card(ref_rgba, keys, kidx, tag):
    """用一张干净的生成帧(ref_rgba, RGBA)做 i2i 参考, 产一张'准备姿态'单图卡图(512, 透明底, 脚线对齐)。
    与动作帧同风格/同色/同朝向→补齐首尾书挡, 消除原 512 卡图的色差/残留白底/方向错。
    参考端把生成帧人物贴到 1024 品红画布(放大到 ~620 高, 尽量多喂细节), 出图锁 1024², 再键控→512。"""
    ys, xs = np.where(ref_rgba[:, :, 3] > 20)
    crop = ref_rgba[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    cr = Image.fromarray(crop)
    sref = 620.0 / cr.height
    cr = cr.resize((max(1, int(cr.width * sref)), 620), Image.LANCZOS)
    canvas = Image.new("RGBA", (1024, 1024), (255, 0, 255, 255))
    canvas.paste(cr, ((1024 - cr.width) // 2, 1024 - cr.height - 44), cr)
    ref_png = io.BytesIO()
    canvas.convert("RGB").save(ref_png, format="PNG")
    ref_b64 = base64.b64encode(ref_png.getvalue()).decode()
    prompt = SKELETON.replace("{SUBJECT}", SUBJECT_BASE + CARD_READY_POSE +
                              " FACING LEFT in profile, " + "\n")
    url, kh = gen_i2i(prompt, ref_b64, keys, kidx, tag, image_size="1024x1024")
    pf = os.path.join(RAW, "card_%s.png" % tag)
    subprocess.run(["curl", "-sS", "-m", "120", "-o", pf, url], check=True)
    rgba = key_magenta(np.asarray(Image.open(pf).convert("RGB")))
    comp, _ = largest_component(rgba[:, :, 3])
    if comp is not None:
        rgba[:, :, 3] = comp
    ys, xs = np.where(rgba[:, :, 3] > 20)
    x0, x1, y0, y1 = int(xs.min()), int(xs.max()), int(ys.min()), int(ys.max())
    figi = Image.fromarray(rgba[y0:y1 + 1, x0:x1 + 1])
    target_h = int(512 * 0.85)
    sc = target_h / figi.height
    figi = figi.resize((max(1, int(figi.width * sc)), target_h), Image.LANCZOS)
    card512 = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    card512.paste(figi, ((512 - figi.width) // 2, 512 - target_h - 8), figi)
    card512.save(os.path.join(OUT, "new_card.png"))
    print("  新卡图(生成帧反向 i2i, 512 透明底) → new_card.png  url=%s" % url[:60])
    return card512

def grid_prompt():
    # 硬性不变量逐格重复（2026-10-12 二轮实测: 不重复时出现翻面/空手/带镜漂移）
    invariant = ("facing LEFT in profile, holding his M1 Garand rifle in his hands (never empty-handed), "
                 "simple iron sights only, NO scope")
    parts = []
    for i, pose in enumerate(POSES[:N]):
        parts.append("%s: the same soldier %s, %s;" % (GRID_POS[i], pose, invariant))
    flash = ("The star-shaped muzzle flash appears in ONLY ONE panel, the firing panel (top-right): small, "
             "orange-yellow with a white core, attached directly to the rifle muzzle, touching it. "
             "No other panel has any flash or smoke. ")
    return SKELETON.replace("{SUBJECT}", SUBJECT_BASE + (
        "shown in a regular grid of exactly 6 flat panels, 3 columns and 2 rows, "
        "all 6 panels showing THE SAME soldier with THE SAME rifle, helmet and gear, "
        "identical scale, identical colors and identical rendering in every panel, and NO shadow under any figure. "
        + " ".join(parts) + " " + flash +
        "Keep the exact 6-panel grid layout, panel positions and spacing of the reference image unchanged, "
        "changing only the soldier's pose in each panel as listed. "
        "One complete figure centered in each panel, generous empty magenta spacing between panels, "
        "no panel borders, no grid lines, no labels, no numbers.") + "\n")

def process_frame(rgb, tag, ledger_entry):
    im = Image.fromarray(rgb)
    pf = os.path.join(RAW, "%s.png" % tag)
    im.save(pf)
    px = im.load()
    corners = [px[2, 2], px[im.width - 3, 2], px[2, im.height - 3], px[im.width - 3, im.height - 3]]
    rgba = key_magenta(np.asarray(im))
    alpha_ratio = float((rgba[:, :, 3] == 0).mean())
    comp, comp_sz = largest_component(rgba[:, :, 3])
    if comp is not None:
        rgba[:, :, 3] = comp
    else:
        comp_sz = 0  # 全空格（切格越界/空面板），保留全透明
    ys_n, _ = np.nonzero(rgba[:, :, 3])
    h_bbox = int(ys_n.max() - ys_n.min() + 1) if len(ys_n) else 1
    frame = normalize_frame(rgba, FS, FOOT_FRAC, (ref_h_frac * FS) / h_bbox)
    fp = os.path.join(OUT, "frames", "%s.png" % tag)
    os.makedirs(os.path.dirname(fp), exist_ok=True)
    frame.save(fp)
    entry = {"tag": tag, "alpha_ratio": round(alpha_ratio, 4),
             "corners_ok": all(c[0] > 140 and c[2] > 140 for c in corners),
             "component_px": int(comp_sz)}
    ledger_entry.update(entry)
    print("  %s alpha=%.3f corners_ok=%s" % (tag, alpha_ratio, entry["corners_ok"]))

def process_comp(alpha_full, labels, comp_idx, bbox, grid_rgb, tag, ledger_entry, scale):
    """从整图键控结果中取一个连通域（labels 精确掩码）→ 裁 bbox → 全局统一缩放归一 → 存帧。"""
    x0, y0, x1, y1 = bbox
    pad = 2
    x0 = max(0, x0 - pad); y0 = max(0, y0 - pad)
    x1 = min(alpha_full.shape[1] - 1, x1 + pad); y1 = min(alpha_full.shape[0] - 1, y1 + pad)
    mask = (labels[y0:y1 + 1, x0:x1 + 1] == comp_idx)
    npx = int(mask.sum())
    a2 = np.where(mask, alpha_full[y0:y1 + 1, x0:x1 + 1], 0).astype(np.uint8)
    rgba = np.dstack([np.asarray(grid_rgb)[y0:y1 + 1, x0:x1 + 1], a2])
    frame = normalize_frame(rgba, FS, FOOT_FRAC, scale)
    fp = os.path.join(OUT, "frames", "%s.png" % tag)
    os.makedirs(os.path.dirname(fp), exist_ok=True)
    frame.save(fp)
    entry = {"tag": tag, "component_px": npx}
    ledger_entry.update(entry)
    print("  %s component=%dpx" % (tag, npx))

from identity_check import palette_sig, dist as palette_dist, ref_sig  # 主体一致性指纹(含 idle f0 基线)

def body_stats(rgb, alpha):
    """主体像素(α>60)逐通道均值/标准差。"""
    ys, xs = np.where(alpha > 60)
    px = np.asarray(rgb)[ys, xs, :3].astype(float)
    return px.mean(0), px.std(0)

def color_transfer(grid_rgb, alpha, ref_mean, ref_std):
    """整卷色彩迁移: 主体像素逐通道均值/方差对齐到参考（Reinhard 式）。
    只动全局色板, 帧间差异原样保留——救'卷内一致但整体偏色'的卷。"""
    m, s = body_stats(grid_rgb, alpha)
    s_safe = np.maximum(s, 1e-3)
    arr = np.asarray(grid_rgb).astype(float)
    for ch in range(3):
        arr[:, :, ch] = np.clip((arr[:, :, ch] - m[ch]) * (ref_std[ch] / s_safe[ch]) + ref_mean[ch], 0, 255)
    return Image.fromarray(arr.astype(np.uint8))

def transient_mask(rgb):
    """瞬时特效像素掩码（击发帧橙黄焰/白心、弹匣黄铜）——不属于主体身份。
    2026-10-12 门禁勘误: 指纹把焰一起算, 焰大的卷击发帧 pair 距离系统性放大, 好卷被 0.6 误杀
    （废卷4: 六格目检一致仍 0.68）。判据: 橙黄 r>190∧120<g<220∧b<130; 白心 r/g/b 全>205
    （棕靴 b≥130 / 浅灰衣不全>205 / 皮肤 b≥140, 均安全）。"""
    a = np.asarray(rgb).astype(int)
    r, g, b = a[:, :, 0], a[:, :, 1], a[:, :, 2]
    orange = (r > 190) & (g > 120) & (g < 220) & (b < 130)
    white = (r > 205) & (g > 205) & (b > 205)
    return orange | white

def identity_gate(grid, comps, ref_sig):
    """主体一致性门: 6 域指纹两两距离≤0.6 且对参考≤2.2。
    标定依据 2026-10-12 坏卷: 同卷内跨变体 0.83-1.00, 三簇结构与目检'三种主体'一致。
    返回 dict(pair_ok, ref_ok, fails, mx_pair)。ref 失败但 pair 通过的卷可色彩迁移后复检。"""
    a = key_magenta(np.asarray(grid.convert("RGB")))[:, :, 3]
    sigs = []
    for npx, bbox, cid in comps:
        x0, y0, x1, y1 = bbox
        sub_rgb = np.asarray(grid.convert("RGB"))[y0:y1 + 1, x0:x1 + 1]
        a2 = np.where(transient_mask(sub_rgb), 0, a[y0:y1 + 1, x0:x1 + 1])
        sub = np.dstack([sub_rgb, a2.astype(np.uint8)])
        sigs.append(palette_sig(sub))
    fails = []
    mx_pair = 0.0
    ref_dists = []
    for i in range(len(sigs)):
        d_ref = palette_dist(sigs[i], ref_sig)
        ref_dists.append(round(d_ref, 2))
        if d_ref > 2.6:
            fails.append("f%d 偏离参考 %.2f>2.6(软)" % (i + 1, d_ref))
        for j in range(i + 1, len(sigs)):
            d = palette_dist(sigs[i], sigs[j])
            mx_pair = max(mx_pair, d)
            if d > 0.6:
                fails.append("f%d~f%d 异体 %.2f>0.6" % (i + 1, j + 1, d))
    pair_ok = mx_pair <= 0.6
    return {"pair_ok": pair_ok, "fails": fails, "mx_pair": mx_pair, "ref_dists": ref_dists}

def main():
    keys = load_keys()
    REPROCESS = "--reprocess" in sys.argv
    REF_CARD = "--refcard" in sys.argv
    card_path = os.path.join(WS, "assets", "card_icons", "enemy", UNIT + ".png")
    if REF_CARD and not os.path.exists(card_path):
        print("card icon 不存在, 回落 idle f0 锚点:", card_path); REF_CARD = False
    ledger = {"unit": UNIT, "model": MODEL, "skeleton": "V3", "poses": "V7",
              "anchor": "card512" if REF_CARD else "idle_f0", "mode": MODE,
              "started": time.strftime("%F %T"), "frames": []}

    # i2i 参考图: idle f0 → 品红 1024 画布居中 512（与冒烟一致，冻结）
    idle = Image.open(os.path.join(ANIM_DIR, "sheet_idle.png")).convert("RGBA")
    f0 = idle.crop((0, 0, FS, FS))
    ref = Image.new("RGBA", (1024, 1024), (255, 0, 255, 255))
    big = f0.resize((512, 512), Image.LANCZOS)
    ref.paste(big, (256, 256), big)
    ref = ref.convert("RGB")
    ref.save(os.path.join(OUT, "reference_f0_on_magenta.png"))
    ref_b64 = base64.b64encode(open(os.path.join(OUT, "reference_f0_on_magenta.png"), "rb").read()).decode()

    # 现役 attack 内容高占比（归一目标）
    global ref_h_frac
    ref_h_frac = anim["subject"]["attack_h"]

    kidx = 0
    if MODE == "grid":
        if REPROCESS:
            print("[grid] 复处理现有 raw/grid6.png（不重掷）...")
            url, keyhead = "file://" + os.path.join(RAW, "grid6.png"), "reprocess"
        else:
            if REF_CARD:
                card = Image.open(card_path).convert("RGBA")
                print("[grid] 6帧底稿 i2i (1024x1024, 3x2, 锚点=512 卡图, 无描线版) ...")
                tpl = build_grid_template_card(card, FS)
                tpl.save(os.path.join(OUT, "grid_template_card.png"))
            else:
                print("[grid] 6帧底稿 i2i (1024x1024, 3x2, 底稿锁布局) ...")
                tpl, CW, CH = build_grid_template(idle, FS)
                tpl.save(os.path.join(OUT, "grid_template.png"))
            tpl_b64 = base64.b64encode(open(os.path.join(OUT, "grid_template.png"), "rb").read()).decode()
            url, keyhead = gen_i2i(grid_prompt(), tpl_b64, keys, kidx, "grid6", image_size="1024x1024")
        pf = os.path.join(RAW, "grid6.png")
        if not REPROCESS:
            subprocess.run(["curl", "-sS", "-m", "120", "-o", pf, url], check=True)
        grid = Image.open(pf).convert("RGB")
        GW, GH = grid.size
        # 输出恒为 1024²（实测）, 底稿同为 1024², 格尺寸按输出重算防缩放偏差
        cw, ch = GW / 3.0, GH / 2.0
        print("  grid %dx%d cell %.0fx%.0f" % (GW, GH, cw, ch))
        cells = []
        for i in range(N):
            col, row = i % 3, i // 3
            x0, x1 = int(round(col * cw)), int(round((col + 1) * cw))
            y0, y1 = int(round(row * ch)), int(round((row + 1) * ch))
            cells.append(grid.crop((x0, y0, x1, y1)))
        # 整图键控 → 连通域提取审计门（无固定切格, 枪口越伸不会被格线切断）
        alpha_full, labels, comps = grid_to_frames(grid)
        if alpha_full is None:
            ledger["audit"] = {"pass": False, "msgs": [comps]}
            json.dump(ledger, open(os.path.join(OUT, "ledger.json"), "w", encoding="utf-8"),
                      ensure_ascii=False, indent=1)
            print("  audit: FAIL —", comps, "｜废卷已记录, 重跑重掷")
            return
        # 主体一致性门（2026-10-12: 一卷内漂出三种主体, 目检实锤后标定）
        # pair(两两≤0.6)=硬门; ref 距离=软指标（风格差异与异体难以用绝对阈值区分,
        # 2.2/2.6 两档标定均误伤, 只记录+用于决定是否采用色彩迁移）
        idr = identity_gate(grid, comps, ref_sig)
        print("  identity: pair_ok=%s (max_pair=%.2f) mean_ref_dist=%.2f"
              % (idr["pair_ok"], idr["mx_pair"], sum(idr["ref_dists"]) / 6))
        if not idr["pair_ok"]:
            ledger["audit"] = {"pass": False, "msgs": idr["fails"]}
            json.dump(ledger, open(os.path.join(OUT, "ledger.json"), "w", encoding="utf-8"),
                      ensure_ascii=False, indent=1)
            print("  异体卷废, 重跑重掷")
            return
        # 色彩迁移: 仅当迁移后平均 ref 距离改善时采用
        a_all = key_magenta(np.asarray(grid.convert("RGB")))[:, :, 3]
        idle_img = Image.open(os.path.join(ANIM_DIR, "sheet_idle.png")).convert("RGBA")
        ia = np.asarray(idle_img.crop((0, 0, FS, FS)))
        r_mean, r_std = body_stats(idle_img.crop((0, 0, FS, FS)).convert("RGB"), ia[:, :, 3])
        grid_t = color_transfer(grid, a_all, r_mean, r_std)
        idr_t = identity_gate(grid_t, comps, ref_sig)
        d_before = sum(idr["ref_dists"]) / 6
        d_after = sum(idr_t["ref_dists"]) / 6
        if idr_t["pair_ok"] and d_after < d_before:
            grid = grid_t
            print("  color_transfer 采用: ref_dist %.2f → %.2f" % (d_before, d_after))
        else:
            print("  color_transfer 不采用: ref_dist %.2f → %.2f" % (d_before, d_after))
        ledger["audit"] = {"pass": True,
                           "identity_max_pair": round(idr["mx_pair"], 3),
                           "color_transferred": d_after < d_before,
                           "components": [{"px": c[0], "bbox": c[1]} for c in comps]}
        # 全局统一缩放: 用瞄准帧(f2, comps[1], 步枪水平 bbox≈身高)定标, 全帧共用
        h_aim = comps[1][1][3] - comps[1][1][1]
        scale = (ref_h_frac * FS) / h_aim
        print("  global scale=%.3f (aim h=%dpx → %dpx)" % (scale, h_aim, int(ref_h_frac * FS)))
        for i, (npx, bbox, cid) in enumerate(comps):
            ent = {"tag": "f%d" % (i + 1), "pose": POSES[i], "url": url, "key": keyhead}
            ledger["frames"].append(ent)
            process_comp(alpha_full, labels, cid, bbox, grid, "f%d" % (i + 1), ent, scale)
        # f6 = 网格第6格（瞄准变体, 与 f2 呼应=循环闭合; 弃用 idle f0——烘焙描边与生成帧不匹配
        #   且逐帧 bbox 归一会引入尺寸跳变, 见 2026-10-12 教训）
    elif MODE == "card4":
        # 锚点优先级: OUT/card_ref_good.png(除光晕/除溢色的好卡图) > card_path(原 512)
        good_anchor = os.path.join(OUT, "card_ref_good.png")
        src = good_anchor if os.path.exists(good_anchor) else card_path
        if not os.path.exists(src):
            print("card4 需要卡图锚点, 但 %s 不存在" % src); return
        card = Image.open(src).convert("RGBA")
        ledger["poses"] = "V9-card4"
        print("[card4] 4帧底稿 i2i (锚点=%s) ..." % os.path.basename(src))
        tpl = build_grid_template_4_card(card, FS)
        tpl.save(os.path.join(OUT, "grid_template_4.png"))
        tpl_b64 = base64.b64encode(open(os.path.join(OUT, "grid_template_4.png"), "rb").read()).decode()
        url, keyhead = gen_i2i(grid4_prompt(), tpl_b64, keys, kidx, "grid4", image_size="1024x1024")
        pf = os.path.join(RAW, "grid4.png")
        subprocess.run(["curl", "-sS", "-m", "120", "-o", pf, url], check=True)
        grid = Image.open(pf).convert("RGB")
        alpha_full, labels, comps4 = grid4_to_frames(grid)
        if alpha_full is None:
            ledger["audit"] = {"pass": False, "msgs": [comps4]}
            json.dump(ledger, open(os.path.join(OUT, "ledger.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
            print("  audit: FAIL —", comps4, "｜废卷已记录, 重跑重掷")
            return
        idr = identity_gate(grid, comps4, ref_sig)
        print("  identity: pair_ok=%s (max_pair=%.2f) mean_ref_dist=%.2f"
              % (idr["pair_ok"], idr["mx_pair"], sum(idr["ref_dists"]) / 4))
        if not idr["pair_ok"]:
            ledger["audit"] = {"pass": False, "msgs": idr["fails"]}
            json.dump(ledger, open(os.path.join(OUT, "ledger.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
            print("  异体卷废, 重跑重掷")
            return
        # 色彩迁移: 对齐到卡图色板（而非 idle f0）, 让 4 动作帧与书挡帧同色
        card_rgba = np.asarray(card)
        c_mean, c_std = body_stats(card_rgba[:, :, :3], card_rgba[:, :, 3])
        a_all = key_magenta(np.asarray(grid.convert("RGB")))[:, :, 3]
        grid_t = color_transfer(grid, a_all, c_mean, c_std)
        idr_t = identity_gate(grid_t, comps4, ref_sig)
        d_before = sum(idr["ref_dists"]) / 4
        d_after = sum(idr_t["ref_dists"]) / 4
        if idr_t["pair_ok"] and d_after < d_before:
            grid = grid_t
            print("  color_transfer 采用: ref_dist %.2f → %.2f" % (d_before, d_after))
        else:
            print("  color_transfer 不采用: ref_dist %.2f → %.2f" % (d_before, d_after))
        # 反帧门（2026-10-12）: 任一格翻面(朝右)即废卷重掷
        flip_tags, flip_msgs = grid4_flip_check(grid, alpha_full, labels, comps4)
        if flip_tags:
            ledger["audit"] = {"pass": False, "msgs": flip_msgs}
            json.dump(ledger, open(os.path.join(OUT, "ledger.json"), "w", encoding="utf-8"),
                      ensure_ascii=False, indent=1)
            print("  反帧废: %s, 重跑重掷" % " ".join(flip_msgs))
            return
        ledger["audit"] = {"pass": True, "identity_max_pair": round(idr["mx_pair"], 3),
                           "color_transferred": d_after < d_before,
                           "flip_ok": True,
                           "components": [{"px": c0[0], "bbox": c0[1]} for c0 in comps4]}
        # 全局统一缩放: 用瞄准帧(comps4[0] 上左)定标, 全帧共用
        h_aim = comps4[0][1][3] - comps4[0][1][1]
        scale = (ref_h_frac * FS) / h_aim
        print("  global scale=%.3f (aim h=%dpx → %dpx)" % (scale, h_aim, int(ref_h_frac * FS)))
        target_h = ref_h_frac * FS
        # 书挡帧 f1/f6 = 原卡图（稳定, 与卡面一致, 循环首尾无跳变）
        ledger["frames"].append({"tag": "f1", "pose": "bookend: 原卡图", "url": "card", "key": "card"})
        render_bookend(card, FS, FOOT_FRAC, target_h, "f1")
        ledger["frames"].append({"tag": "f6", "pose": "bookend: 原卡图", "url": "card", "key": "card"})
        render_bookend(card, FS, FOOT_FRAC, target_h, "f6")
        # 4 动作帧 f2-f5（瞄准/击发/后坐/垂枪）
        tags4 = ["f2", "f3", "f4", "f5"]
        for i, (npx, bbox, cid) in enumerate(comps4):
            ent = {"tag": tags4[i], "pose": POSES4[i], "url": url, "key": keyhead}
            ledger["frames"].append(ent)
            process_comp(alpha_full, labels, cid, bbox, grid, tags4[i], ent, scale)
    elif MODE == "cardgen":
        # 复用上一轮 card4 的 4 动作帧(f2~f5), 用它们反向 i2i 产一张干净卡图, 补首尾书挡
        f2p = os.path.join(OUT, "frames", "f2.png")
        if not os.path.exists(f2p):
            print("cardgen 需要 card4 的 frames/f2.png, 请先跑 --mode card4"); return
        ref_rgba = np.asarray(Image.open(f2p).convert("RGBA"))
        keys2 = load_keys()
        ledger["poses"] = "V9-cardgen"
        print("[cardgen] 用 f2(瞄准帧) 反向 i2i 生成准备姿态卡图 + 补首尾书挡 ...")
        newcard = gen_ready_card(ref_rgba, keys2, 0, "ready")
        # 重排 sheet = [newcard, f2, f3, f4, f5, newcard]
        target_h = ref_h_frac * FS
        ledger["frames"] = []
        ledger["frames"].append({"tag": "f1", "pose": "bookend: 新生成卡图", "url": "gen_ready", "key": "cardgen"})
        render_bookend(newcard, FS, FOOT_FRAC, target_h, "f1")
        ledger["frames"].append({"tag": "f6", "pose": "bookend: 新生成卡图", "url": "gen_ready", "key": "cardgen"})
        render_bookend(newcard, FS, FOOT_FRAC, target_h, "f6")
        for i in range(2, 6):
            ledger["frames"].append({"tag": "f%d" % i, "pose": "card4 动作帧(复用)", "url": "reuse", "key": "card4"})
        # 4 动作帧帧体已由 card4 写好, 只需补 f1/f6(新卡图书挡) → 直接合 sheet(下方共用尾)
    else:
        for i, pose in enumerate(POSES[:N], 1):
            tag = "f%d" % i
            prompt = SKELETON.replace("{SUBJECT}", SUBJECT_BASE + pose + "\n")
            print("[%d/%d] %s gen ..." % (i, N, tag))
            url, keyhead = gen_i2i(prompt, ref_b64, keys, kidx, tag)
            kidx += 1
            pf = os.path.join(RAW, "%s.png" % tag)
            subprocess.run(["curl", "-sS", "-m", "120", "-o", pf, url], check=True)
            ent = {"tag": tag, "pose": pose, "url": url, "key": keyhead}
            ledger["frames"].append(ent)
            process_frame(np.asarray(Image.open(pf).convert("RGB")), tag, ent)

    # 合 sheet（宽=N×FS）+ 预览对比页
    sheet = Image.new("RGBA", (FS * N, FS), (0, 0, 0, 0))
    for i in range(N):
        sheet.paste(Image.open(os.path.join(OUT, "frames", "f%d.png" % (i + 1))), (i * FS, 0))
    sheet.save(os.path.join(OUT, "sheet_attack_api.png"))

    cur = os.path.join(ANIM_DIR, "sheet_attack.png")
    cur_w, cur_h = Image.open(cur).size
    html = ["<html><head><meta charset='utf-8'><style>body{background:#222;color:#eee;font-family:monospace}",
            "img{image-rendering:auto}.row{margin:12px}h3{margin:4px}",
            ".chk{background:conic-gradient(#888 25%,#444 0 50%,#888 0 75%,#444 0);background-size:16px 16px;display:inline-block}</style></head><body>",
            "<h2>%s attack: API vs 现役 (放大2x, 棋盘底)</h2>" % UNIT,
            "<div class='row'><h3>API sheet_attack_api.png (%d帧)</h3><div class='chk'>" % N,
            "<img src='sheet_attack_api.png' style='width:%dpx'></div></div>" % (FS * N * 2),
            "<div class='row'><h3>现役 sheet_attack.png (%dpx 宽)</h3><div class='chk'>" % cur_w,
            "<img src='../../../assets/effects/unit_anims/%s/sheet_attack.png' style='width:%dpx'></div></div>" % (UNIT, min(cur_w * 2, 1536)),
            "<div class='row'><h3>参考 idle f0</h3><div class='chk'>",
            "<img src='../../../assets/effects/unit_anims/%s/sheet_idle.png' style='width:512px'></div></div>" % UNIT,
            "</body></html>"]
    open(os.path.join(OUT, "compare_api.html"), "w", encoding="utf-8").write("\n".join(html))

    ledger["finished"] = time.strftime("%F %T")
    json.dump(ledger, open(os.path.join(OUT, "ledger.json"), "w", encoding="utf-8"),
              ensure_ascii=False, indent=1)
    print("done →", OUT)

if __name__ == "__main__":
    main()
