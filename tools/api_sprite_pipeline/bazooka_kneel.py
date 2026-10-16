# -*- coding: utf-8 -*-
"""ww2_inf_bazooka 蹲姿专用重掷（API 精灵图工作流 v1 + 2026-10-13 用户反馈修正）。

用户反馈三问题: 动作太夸张 / 大小脚位对不齐 / 部分抠错。
根因: batch_regen 的通用 humanoid pose(站姿举枪→垂枪)套在 bazooka 上——
与蹲姿书挡(f1/f6=idle)首尾断裂, 跳变大。

玩家视角动作设计(本脚本定案):
  游戏屏上单位 ~100px, 玩家读剪影节奏。bazooka 辨识核心=蹲姿+筒扛肩+背负步枪;
  攻击反馈=管口星焰+管尾喷烟(backblast, bazooka 独有, 旧卷有/新卷丢)。
  旧卷(现役)骨架正确(全蹲姿筒不离肩), 毛病=尾烟占半格过大 + f5 二次焰(误读两枪)。
  新循环 6 帧:
    f1 书挡=idle f0 蹲姿扛筒
    f2 蓄势: 蹲姿不变, 贴腮压肩(微动作)
    f3 击发: 管口(左端)星焰 + 管尾(右端)适度灰白喷烟——唯一焰帧
    f4 后坐: 上身微仰, 管口微抬, 两端残烟丝
    f5 回位: 回到瞄准, 最后一缕烟消散
    f6 书挡=f1
  大小/脚位: aim 帧定标全局统一缩放 + foot_frac 脚线 + 躯干靠右 0.60(沿 §7.3/§7.6)。
  抠图: key_magenta + 强除溢色(§7.6: b>g+15 ∧ r>g+10 边缘5px切环) + 灰渣清理(§7.7)。

用法: python tools/api_sprite_pipeline/bazooka_kneel.py   (最多 5 掷, 自动门+落盘)
"""
import base64, json, os, shutil, sys, time
from collections import deque
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
WS = os.path.abspath(os.path.join(HERE, "..", ".."))
_ARGS = sys.argv[1:]              # 先取本脚本参数(sys.argv[1] 会被 P 当 UNIT)
sys.argv = [sys.argv[0]]          # 复位: 让 generate_attack_api 走默认 UNIT
sys.path.insert(0, HERE)
import generate_attack_api as P
sys.argv = [sys.argv[0]] + _ARGS  # 恢复

FS = 256
FOOT = 0.0449            # batch_regen_config.json / anim 口径
TARGET_H = int(FS * 0.89)
STANCE_FRAC = 0.60
UID = "ww2_inf_bazooka"
# 2026-10-13 用户拍板: f2(蓄势)/f5(回位)去掉——4 帧循环 扛筒→击发→后坐→扛筒。
# 落盘 f1..f4(重编号), 部署时 anim.json counts.attack 须同步改 4。
KEEP_FRAMES = [1, 3, 4, 6]
OUT = os.path.join(WS, ".godot", "unit_review", "api_" + UID)
RAW = os.path.join(OUT, "raw")
FRAMES = os.path.join(OUT, "frames")
ROLLS = os.path.join(OUT, "rolls")

IDLE_SHEET = os.path.join(WS, "assets", "effects", "unit_anims", "ww2_inf_bazooka", "sheet_idle.png")

SUBJECT = ("the same World War Two US infantryman as in the reference image, in the exact same kneeling "
           "pose as the reference: M1 steel helmet, olive drab field jacket and trousers, brown leather "
           "boots, a rifle slung diagonally on his back. He operates the exact same bazooka as in the "
           "reference: a long slim dark-green rocket launcher tube braced over his shoulder and pointing "
           "to the left, both hands gripping the tube. The kneeling pose and the braced tube are "
           "IDENTICAL in every panel, ")

POSES = [
    ("top-left", "taking aim: the tube braced on his shoulder exactly as in the reference, cheek pressed "
                 "against the tube, his shoulders tightening slightly before the shot, tube level and pointing left"),
    ("top-right", "firing: a compact star-shaped flash attached at the LEFT front end of the tube, "
                  "orange-yellow with a white core, and a modest compact burst of pale grey backblast smoke "
                  "puffing from the RIGHT rear end of the tube, his body braced against the shot"),
    ("bottom-left", "just after the shot: the tube still braced on his shoulder with its front end tilted "
                    "only slightly upward, his upper body leaning gently back, thin wisps of pale smoke "
                    "drifting from both ends of the tube"),
    ("bottom-right", "settling back into the aiming pose: the tube level on his shoulder pointing left "
                     "again, the last small wisp of pale smoke fading away behind him, calm and steady"),
]


def build_prompt():
    inv = ("facing LEFT in profile, never mirrored, holding the bazooka tube in both hands "
           "(never empty-handed), NO scope")
    parts = "; ".join("%s: the same kneeling soldier %s, %s" % (pos, p, inv) for pos, p in POSES)
    dual = ("You are given TWO reference images. Reference image 1 is the SAME soldier in the highest "
            "available detail and resolution: copy his exact face, gear, equipment, colors and rendering "
            "style from it. Reference image 2 defines the 4-panel grid layout and the kneeling pose: keep "
            "its exact grid layout, panel positions, figure size and kneeling pose, and fill each of its 4 "
            "panels with the highly detailed soldier from reference image 1 performing the listed action. "
            "The soldier is ")
    return P.SKELETON.replace("{SUBJECT}", dual + SUBJECT + (
        "shown in a regular grid of exactly 4 flat panels, 2 columns and 2 rows, "
        "all 4 panels showing THE SAME unit in THE SAME kneeling pose, identical scale, identical colors "
        "and identical rendering in every panel, the launcher tube stays braced on his shoulder in every "
        "panel, NO shadow under any figure, NO dark outline or border stroke around the figures. "
        "The background is ONE flat solid magenta color everywhere: no floor, no ground plane, "
        "no horizontal shading bands, no gradient, no vignette. "
        + parts + "; "
        + "The star-shaped flash appears in ONLY ONE panel, the firing panel (top-right). Smoke appears "
        "only in the firing and the after-shot panels. "
        "All four figures rendered at identical scale, matching the figure size of reference image 2, "
        "changing only the soldier's action in each panel as listed. "
        "Each figure stays COMPLETELY inside its own panel: the bazooka tube, the rifle and the flash "
        "must never cross the vertical or horizontal midlines of the sheet; wide empty magenta gutters "
        "separate the four panels. The flash is small and stays well inside the firing panel. "
        "One complete figure centered in each panel, generous empty magenta spacing between panels, "
        "no panel borders, no grid lines, no labels, no numbers.\n"))


def i2i(prompt, refs_b64, keys, tag):
    """refs_b64: 参考图 base64 列表(多图 i2i)。双参考=高分辨卡图(身份) + 4 格底稿(布局)。"""
    body = {"model": P.MODEL, "prompt": prompt, "image_size": "1024x1024",
            "extra_body": {"image": ["data:image/png;base64," + b for b in refs_b64],
                           "response_format": "url"}}
    pf = os.path.join(RAW, "payload_%s.json" % tag)
    json.dump(body, open(pf, "w"))
    for att in range(8):
        key = keys[att % len(keys)]
        r = subprocess_run_curl(pf, key)
        try:
            js = json.loads(r.rsplit("\nHTTP_CODE:", 1)[0])
        except Exception:
            time.sleep(5); continue
        if "data" in js and js["data"] and js["data"][0].get("url"):
            url = js["data"][0]["url"]
            if "/i2i/" in url:
                return url, key[:12]
            print("  [%s] att%d i2i 标志缺失" % (tag, att)); time.sleep(5); continue
        print("  [%s] att%d fail: %s" % (tag, att, str(js.get("error", {}).get("message", ""))[:100]))
        time.sleep(6)
    raise RuntimeError("i2i failed: " + tag)


def subprocess_run_curl(pf, key):
    """POST /v1/images/generations。2026-XX 起本机 curl(schannel) 在 Python
    subprocess 内报 (35) SEC_E_NO_CREDENTIALS（pwsh 直跑正常，加 --cacert/--ssl-no-revoke
    均无效），urllib 默认证书束又报 certificate has expired → 用 certifi CA 走 urllib。"""
    import urllib.request, ssl
    try:
        import certifi
        ca = certifi.where()
    except ImportError:
        ca = None
    req = urllib.request.Request(
        "https://apihub.agnes-ai.com/v1/images/generations",
        data=open(pf, "rb").read(),
        headers={"Authorization": "Bearer " + key, "Content-Type": "application/json"})
    ctx = ssl.create_default_context(cafile=ca) if ca else None
    with urllib.request.urlopen(req, timeout=300, context=ctx) as resp:
        return resp.read().decode("utf-8", "replace") + "\nHTTP_CODE:%d" % resp.status


def download_url(url, path, timeout=120):
    """下载到本地。与 subprocess_run_curl 同因：本机 curl(schannel) 在 Python
    subprocess 内 SEC_E_NO_CREDENTIALS，urllib 默认束证书过期 → certifi。"""
    import urllib.request, ssl
    try:
        import certifi
        ca = certifi.where()
    except ImportError:
        ca = None
    ctx = ssl.create_default_context(cafile=ca) if ca else None
    with urllib.request.urlopen(url, timeout=timeout, context=ctx) as resp:
        data = resp.read()
    open(path, "wb").write(data)
    return len(data)


def smoke_mask_smart(rgb, a2):
    """成品路径剔烟 v3(2026-10-13 定案): smoke 命中按 4 邻接连通块分块——
    与背景接触(块膨胀 2px 触及 a2==0)的块 = 挂在人外的烟团/烟丝 → 整块剔;
    完全被实体包围的块 = 装备/制服亮面高光 → 保留。
    实证: 双参考卷(grid4_t3)击发格几乎无尾烟, v1 全剔命中 1258px 全是
    盔顶/右臂/肩袢/背带/背包高光(p50 亮度149 sat0.06) → 成品肩背成片洞
    (洞在白底渲染下目检呈"肩部白斑", pixel 取证全帧不透明白仅 15 碎点)。
    面积阈值版(v1.5, ≥600px 才剔)救不了: 双参考高光成片 >600px。
    门禁路径(pair/flip 度量)仍用 v1 全剔——度量保守无妨, 不影响成品像素。"""
    sm = smoke_mask(rgb) & (a2 > 0)
    if not sm.any():
        return sm
    bgd = ~(a2 > 0)
    for _ in range(2):
        d = bgd.copy()
        d[1:, :] |= bgd[:-1, :]; d[:-1, :] |= bgd[1:, :]
        d[:, 1:] |= bgd[:, :-1]; d[:, :-1] |= bgd[:, 1:]
        bgd = d
    keep = sm.copy()
    h, w = sm.shape
    seen = np.zeros_like(sm, bool)
    for yy in range(h):
        for xx in range(w):
            if sm[yy, xx] and not seen[yy, xx]:
                stack = [(yy, xx)]; seen[yy, xx] = True; comp = []
                while stack:
                    y, x = stack.pop(); comp.append((y, x))
                    for ny, nx in ((y+1, x), (y-1, x), (y, x+1), (y, x-1)):
                        if 0 <= ny < h and 0 <= nx < w and sm[ny, nx] and not seen[ny, nx]:
                            seen[ny, nx] = True; stack.append((ny, nx))
                if any(bgd[y, x] for y, x in comp):
                    for y, x in comp:
                        keep[y, x] = False
    return keep


def smoke_mask(rgb):
    """管尾喷烟像素(backblast): 中性浅灰白、近零饱和。2026-10-13 勘误——transient_mask
    只剔焰不剔烟, 烟量帧间不同 → pair 指纹被烟撑爆误判异体; flip 门烟在右端 → 误判翻面。
    v2: 加饱和约束 (mx-mn)/mx<0.15——v1(min>135) 误伤制服受光面料(f2/f4/f5 白斑实证)。
    灰白烟饱和≈0; 橄榄绿面料高光饱和 0.15~0.25 存活。"""
    a = np.asarray(rgb).astype(float)
    r, g, b = a[:, :, 0], a[:, :, 1], a[:, :, 2]
    mx = np.maximum(np.maximum(r, g), b)
    mn = np.minimum(np.minimum(r, g), b)
    sat = (mx - mn) / np.maximum(mx, 1e-6)
    return (np.abs(r - g) < 22) & (np.abs(g - b) < 22) & (mn > 135) & (sat < 0.15)


def strong_despill(rgba):
    """§7.6 强除溢色: 暗紫环判据 b>g+15 ∧ r>g+10 → 边缘 5px 内 alpha 置 0 切环。
    v2(2026-10-13): 只清半透明层(a<250)——品红 antialias 渗色住在键控半透明边里,
    实心实体(a=255)不中清。v1 全清把管缘/肩线实心好边一起啃出成片洞
    (t1 击发格管区洞 1140/483/421@y76 + 洞总量 39917→70599 实证)。"""
    arr = rgba.copy()
    r, g, b = arr[:, :, 0].astype(int), arr[:, :, 1].astype(int), arr[:, :, 2].astype(int)
    a = arr[:, :, 3]
    violet = (b > g + 15) & (r > g + 10) & (a > 0)
    # 边缘 5px 带 = alpha>0 像素的 5px 膨胀边缘
    band = a > 0
    er = band.copy()
    for _ in range(5):
        er = er & np.roll(er, 1, 0) & np.roll(er, -1, 0) & np.roll(er, 1, 1) & np.roll(er, -1, 1)
    edge = band & ~er
    kill = violet & edge & (a < 250)
    arr[:, :, 3][kill] = 0
    return arr


def ground_shadow_cut(rgba):
    """脚下品红地面投影切除(2026-10-13): 生成卷脚下常有暗化品红地面影
    (b>g+15 ∧ r>g+10 判据命中), 随主体进 bbox → bbox 底被投影垫低 →
    统一脚线后人物被抬高(脚不齐主诉) + 键控后投影碎渣(抠坏主诉)。
    处理: violet 连通块中, 底缘触及裁剪底 10px 内的块 → 整块 alpha=0。
    实体装备不会命中 violet 判据, 无误杀面。"""
    arr = rgba.copy()
    r, g, b = arr[:, :, 0].astype(int), arr[:, :, 1].astype(int), arr[:, :, 2].astype(int)
    a = arr[:, :, 3]
    violet = (b > g + 15) & (r > g + 10) & (a > 0)
    h = a.shape[0]
    if not violet.any():
        return arr
    seen = np.zeros_like(violet, bool)
    ys_all, xs_all = np.where(a > 20)
    if len(xs_all) == 0:
        return arr
    bottom = ys_all.max()
    for yy, xx in zip(*np.where(violet)):
        if seen[yy, xx]:
            continue
        stack = [(yy, xx)]; seen[yy, xx] = True; comp = []
        while stack:
            y, x = stack.pop(); comp.append((y, x))
            for ny, nx in ((y+1, x), (y-1, x), (y, x+1), (y, x-1)):
                if 0 <= ny < a.shape[0] and 0 <= nx < a.shape[1] and violet[ny, nx] and not seen[ny, nx]:
                    seen[ny, nx] = True; stack.append((ny, nx))
        cb = max(c[0] for c in comp)
        if cb >= bottom - 10:
            arr[:, :, 3][[c[0] for c in comp], [c[1] for c in comp]] = 0
    return arr


def decontaminate_edges(rgba):
    """边缘+体内去污(2026-10-13): ①键控留下的暗化品红/深色 antialias 边——
    strong_despill v2 只清半透明, 实心暗边(a=255)存活 → 成品人物一圈深色描边。
    ②原始卷地面阴影带压在人物身上 → 键控后躯干留成片暗品红半透明渗色
    (f2/f3 背包横纹实证)。处理: violet_loose=(b>g+8∧r>g+6) 宽判据(橄榄布 g 主导、
    棕木 b<g、皮肤 b<g 均不命中), 边缘带全清+体内 loose 像素用内核色传播重上色
    (不切 alpha, 不啃形)。"""
    arr = rgba.copy()
    r, g, b = arr[:, :, 0].astype(int), arr[:, :, 1].astype(int), arr[:, :, 2].astype(int)
    a = arr[:, :, 3]
    violet = (b > g + 15) & (r > g + 10) & (a > 0)
    violet_loose = (b > g + 8) & (r > g + 6) & (a > 0)
    interior = (a == 255) & ~violet_loose
    core = interior.copy()
    for _ in range(2):
        core = core & np.roll(core, 1, 0) & np.roll(core, -1, 0) & np.roll(core, 1, 1) & np.roll(core, -1, 1)
    band = a > 0
    edge_band = band & ~core
    dirty = (edge_band & (violet | (a < 255))) | (violet_loose & band)
    for _ in range(3):
        if not dirty.any():
            break
        src = (core | ~dirty) & band
        acc = np.zeros(arr[:, :, :3].shape, float)
        cnt = np.zeros(a.shape, float)
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                if dy == 0 and dx == 0:
                    continue
                s = np.roll(np.roll(src, dy, 0), dx, 1)
                c = np.roll(np.roll(arr[:, :, :3].astype(float), dy, 0), dx, 1)
                w = s.astype(float)
                acc += c * w[:, :, None]
                cnt += w
        ok = dirty & (cnt > 0)
        arr[:, :, :3][ok] = (acc[ok] / cnt[ok][:, None]).astype(np.uint8)
        core = core | ok
        dirty = dirty & ~ok & (np.roll(core, 1, 0) | np.roll(core, -1, 0) | np.roll(core, 1, 1) | np.roll(core, -1, 1) | core)
    return arr


def clean_scraps(rgba):
    """§7.7 残渣清理: 贴边6px ∧ 中性浅灰(min>160) ∧ 连通块<500px → 删。"""
    arr = rgba.copy()
    a = arr[:, :, 3]
    h, w = a.shape
    solid = a > 0
    seen = np.zeros_like(solid, bool)
    for yy in range(h):
        for xx in range(w):
            if solid[yy, xx] and not seen[yy, xx]:
                stack = [(yy, xx)]; seen[yy, xx] = True; comp = []
                while stack:
                    y, x = stack.pop(); comp.append((y, x))
                    for ny, nx in ((y+1, x), (y-1, x), (y, x+1), (y, x-1)):
                        if 0 <= ny < h and 0 <= nx < w and solid[ny, nx] and not seen[ny, nx]:
                            seen[ny, nx] = True; stack.append((ny, nx))
                if len(comp) >= 500:
                    continue
                near_edge = any(y < 6 or y >= h - 6 or x < 6 or x >= w - 6 for y, x in comp)
                if not near_edge:
                    continue
                px = arr[[c[0] for c in comp], [c[1] for c in comp]]
                mn = px[:, :3].min(axis=1)
                r, g, b = px[:, 0], px[:, 1], px[:, 2]
                neutral = (np.abs(r - g) < 25) & (np.abs(g - b) < 25)
                hit = (mn > 160) & neutral
                if hit.mean() > 0.6:
                    arr[:, :, 3][[c[0] for c in comp], [c[1] for c in comp]] = 0
    return arr


def clean_magenta_residue(rgba):
    """§7.10 最小清理: 只删模型画进图里的品红残留(脚下地面阴影+焰尾品红碎片),
    按 4 邻接连通块整块判: 块内多数像素呈品红色相(r-g>25 ∧ b-g>15 ∧ b>120)→整块 a=0。
    不碰制服/木托/皮肤(棕木 r>g 但 b 压 g 不到阈值; 橄榄布 b<g)。"""
    arr = rgba.copy()
    a = arr[:, :, 3]
    r = arr[:, :, 0].astype(int); g = arr[:, :, 1].astype(int); b = arr[:, :, 2].astype(int)
    mag = (a > 0) & (r - g > 25) & (b - g > 15) & (b > 120)
    seen = np.zeros_like(mag, bool)
    h, w = mag.shape
    for yy in range(h):
        for xx in range(w):
            if mag[yy, xx] and not seen[yy, xx]:
                stack = [(yy, xx)]; seen[yy, xx] = True; comp = []
                while stack:
                    y, x = stack.pop(); comp.append((y, x))
                    for ny, nx in ((y+1, x), (y-1, x), (y, x+1), (y, x-1)):
                        if 0 <= ny < h and 0 <= nx < w and mag[ny, nx] and not seen[ny, nx]:
                            seen[ny, nx] = True; stack.append((ny, nx))
                idx = ([c[0] for c in comp], [c[1] for c in comp])
                if mag[idx].mean() > 0.6:
                    arr[:, :, 3][idx] = 0
    return arr


def fill_holes(frame):
    """成品帧洞修补兜底(2026-10-13): 内部洞(40~2000px, 4px 环实体率>0.6)→洞缘线性
    inpaint(每行取左右缘实体色插值, 无左右缘的行取上下缘)。中值平铺补丁色差明显
    (f3 肩洞 963px 实证), 线性过渡融入周围明暗纹理。
    附带: 品红残渣清道(键控漏网 b>g+20 ∧ r>g+20 → a=0, f3 脚底品红渣实证)。
    合法大空隙(焰与人之间)与外缘不碰。"""
    arr = np.asarray(frame.convert("RGBA")).copy()
    a = arr[:, :, 3]
    r, g, b = arr[:, :, 0].astype(int), arr[:, :, 1].astype(int), arr[:, :, 2].astype(int)
    a[(b > g + 20) & (r > g + 20) & (a > 0)] = 0        # 品红残渣清道
    H, W = a.shape
    holes = a < 10
    seen = np.zeros_like(holes, bool)
    for yy in range(H):
        for xx in range(W):
            if holes[yy, xx] and not seen[yy, xx]:
                stack = [(yy, xx)]; seen[yy, xx] = True; pts = []
                while stack:
                    y, x = stack.pop(); pts.append((y, x))
                    for ny, nx in ((y+1, x), (y-1, x), (y, x+1), (y, x-1)):
                        if 0 <= ny < H and 0 <= nx < W and holes[ny, nx] and not seen[ny, nx]:
                            seen[ny, nx] = True; stack.append((ny, nx))
                if not (40 <= len(pts) <= 2000):
                    continue
                # 紧凑度门: 渗色洞团块状(≥0.15); 人物与管/背带间的合法狭长空隙格
                # (<0.05)不填——填之产网格状伪影(实证)
                ys2 = [p[0] for p in pts]; xs2 = [p[1] for p in pts]
                compact = len(pts) / max((max(ys2) - min(ys2) + 1) * (max(xs2) - min(xs2) + 1), 1)
                if compact < 0.15:
                    continue
                m = np.zeros_like(holes)
                for py, px in pts:
                    m[py, px] = True
                ring = m.copy()
                for _ in range(4):
                    d = ring.copy()
                    d[1:, :] |= ring[:-1, :]; d[:-1, :] |= ring[1:, :]
                    d[:, 1:] |= ring[:, :-1]; d[:, :-1] |= ring[:, 1:]
                    ring = d
                ring = ring & ~m
                nbr = ring & (a > 200)
                ringpx = int(ring.sum())
                if nbr.sum() / max(ringpx, 1) <= 0.6:
                    continue
                # 洞缘双向线性 inpaint: 水平(行左右缘)插值 + 垂直(列上下缘)插值取均值。
                # 单向行插值在左右缘色差大时产生横纹(f2 肩/f3 胸实证), 双向消除。
                rows = {}
                cols = {}
                for py, px in pts:
                    rows.setdefault(py, []).append(px)
                    cols.setdefault(px, []).append(py)
                hval = {}
                for py, xs2 in rows.items():
                    xl, xr = min(xs2), max(xs2)
                    cl = arr[py, xl - 1, :3].astype(float) if xl > 0 and a[py, xl - 1] > 200 else None
                    cr = arr[py, xr + 1, :3].astype(float) if xr < W - 1 and a[py, xr + 1] > 200 else None
                    for px in xs2:
                        t = (px - xl) / max(xr - xl, 1)
                        if cl is not None and cr is not None:
                            hval[(py, px)] = cl * (1 - t) + cr * t
                        elif cl is not None or cr is not None:
                            hval[(py, px)] = cl if cl is not None else cr
                vval = {}
                for px, ys2 in cols.items():
                    yt, yb = min(ys2), max(ys2)
                    ct = arr[yt - 1, px, :3].astype(float) if yt > 0 and a[yt - 1, px] > 200 else None
                    cb = arr[yb + 1, px, :3].astype(float) if yb < H - 1 and a[yb + 1, px] > 200 else None
                    for py in ys2:
                        s = (py - yt) / max(yb - yt, 1)
                        if ct is not None and cb is not None:
                            vval[(py, px)] = ct * (1 - s) + cb * s
                        elif ct is not None or cb is not None:
                            vval[(py, px)] = ct if ct is not None else cb
                for py, px in pts:
                    hv = hval.get((py, px))
                    vv = vval.get((py, px))
                    if hv is not None and vv is not None:
                        col = (hv + vv) / 2
                    else:
                        col = hv if hv is not None else vv
                    if col is None:
                        continue
                    arr[py, px, :3] = np.clip(col, 0, 255).astype(np.uint8)
                    arr[py, px, 3] = 255
    return Image.fromarray(arr)


def place_frame(rgba_arr, scale, stance_x=None):
    """内容裁剪→缩放→256 帧: 躯干靠右 0.60 + 脚线 foot_frac。"""
    a = rgba_arr[:, :, 3]
    ys, xs = np.where(a > 20)
    if len(xs) == 0:
        return Image.new("RGBA", (FS, FS), (0, 0, 0, 0))
    crop = Image.fromarray(rgba_arr[ys.min():ys.max() + 1, xs.min():xs.max() + 1])
    s = scale
    max_w = int(FS * 0.94)
    if crop.width * s > max_w:
        s = max_w / crop.width
    max_ch = int(FS * (1 - FOOT)) - 4
    if crop.height * s > max_ch:
        s = max_ch / crop.height
    crop = crop.resize((max(1, int(crop.width * s)), max(1, int(crop.height * s))), Image.LANCZOS)
    out = Image.new("RGBA", (FS, FS), (0, 0, 0, 0))
    sx = P.stance_x_of(np.asarray(crop))
    px = (int(FS * STANCE_FRAC) - sx) if sx is not None else (FS - crop.width) // 2
    px = max(0, min(px, FS - crop.width))
    out.paste(crop, (px, FS - int(crop.height) - int(round(FOOT * FS))), crop)
    return out


def grid4_to_frames_nosmoke(grid_rgb):
    """键控后额外剔烟(α置0)——供 flip/pair 门用, 帧提取仍用含烟原 alpha。"""
    a = P.key_magenta(np.asarray(grid_rgb.convert("RGB")))
    rgb = np.asarray(grid_rgb.convert("RGB"))
    a[:, :, 3][smoke_mask(rgb)] = 0
    alpha = a[:, :, 3]
    comps, labels = P.label_components(alpha, want_labels=True)
    comps = [c for c in comps if c[0] > 3000]
    if len(comps) != 4:
        return None, None, "主连通域数=%d (期望4, 剔烟后)" % len(comps)
    return a[:, :, 3], labels, comps


def identity_gate_smoke(grid, comps, ref_sig):
    """identity_gate 本地版: 指纹剔除 焰+烟(P.identity_gate 内部 alpha 只剔焰,
    烟留在主体像素里 → 烟量帧间差把 pair 撑爆, t2/t5 误杀实证)。
    另: 击发帧被焰光染暖是合理表现(输出保留), 但调色板指纹会把它误读成异体
    (t5: f2/f4/f5 两两 0.2 一致, f3 对全部 1.1+ 实证)——指纹计算前各格 color_transfer
    对齐 f2(无烟无焰基线)色板, 只影响门禁度量, 输出帧原色不动。只回 pair 判定。"""
    rgb_full = np.asarray(grid.convert("RGB"))
    a = P.key_magenta(rgb_full)[:, :, 3]
    keep_a = []
    for npx, bbox, cid in comps:
        x0, y0, x1, y1 = bbox
        sub_rgb = rgb_full[y0:y1 + 1, x0:x1 + 1]
        keep = ~(P.transient_mask(sub_rgb) | smoke_mask(sub_rgb))
        a2 = np.where(keep, a[y0:y1 + 1, x0:x1 + 1], 0)
        # 紧凑重裁: 剔焰烟后重求 bbox(f3 原bbox被焰烟撑宽 → 指纹空间分域错位)
        ys, xs = np.where(a2 > 0)
        if len(xs) > 0:
            a2 = a2[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
            sub_rgb = sub_rgb[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
        keep_a.append((sub_rgb, a2))
    m0, s0 = P.body_stats(keep_a[0][0], keep_a[0][1])
    sigs = []
    for sub_rgb, a2 in keep_a:
        moved = np.asarray(P.color_transfer(Image.fromarray(np.ascontiguousarray(sub_rgb)), a2, m0, s0))
        sigs.append(P.palette_sig(np.dstack([moved, a2.astype(np.uint8)])))
    # pair 门: 排除击发帧(index 1)——焰光色相偏移是 palette 直方图门拉不回的
    # (transient_mask 勘误 §7.1 的极端版; 三轮度量修实证 1.17→0.97 收敛极限)。
    # 击发帧身份改形状门: 剔焰烟 alpha 归一 IoU vs f2, 形状同族=身份成立, 抗光照污染。
    mx_pair = 0.0
    for i in range(len(sigs)):
        for j in range(i + 1, len(sigs)):
            if 1 in (i, j):
                continue
            mx_pair = max(mx_pair, P.palette_dist(sigs[i], sigs[j]))
    iou = shape_iou(keep_a[0][1], keep_a[1][1])
    # 阈值 0.55→0.50(2026-10-13): t1 净卷(全4格目检同体同风格)击发格剔烟后
    # 轮廓与 aim 差 0.524 被误杀; 异体卷实测 <0.4, 0.50 仍有区分度。
    return {"mx_pair": round(mx_pair, 3), "firing_iou": round(iou, 3),
            "ok": mx_pair <= 0.6 and iou >= 0.50}


def shape_iou(a_a, a_b):
    """两块 alpha (>60) 归一到同尺寸后的 IoU——击发帧身份形状门。"""
    from PIL import Image as _I
    m_a = a_a > 60
    m_b = a_b > 60
    if m_a.sum() == 0 or m_b.sum() == 0:
        return 0.0
    h, w = m_a.shape
    m_b_r = np.asarray(_I.fromarray((m_b * 255).astype(np.uint8)).resize((w, h), _I.NEAREST)) > 127
    inter = (m_a & m_b_r).sum()
    union = (m_a | m_b_r).sum()
    return inter / max(1, union)


def place_firing_frame(rgba, scale):
    """击发帧摆位: 人体按统一 scale(净人高定标)+躯干靠右; 焰层(transient_mask)按原始
    相对偏移落位, 超出左缘则右移压贴管口。击发格焰横伸 80~118px, 256 画布按整宽钳位
    会把人缩小 20%+(t1~t5 实测机制); 焰压贴后包裹管口, 与旧 sheet 同表现。"""
    a = rgba[:, :, 3]
    ys, xs = np.where(a > 20)
    if len(xs) == 0:
        return Image.new("RGBA", (FS, FS), (0, 0, 0, 0))
    crop = Image.fromarray(rgba[ys.min():ys.max() + 1, xs.min():xs.max() + 1])
    s = scale
    max_ch = int(FS * (1 - FOOT)) - 4
    if crop.height * s > max_ch:
        s = max_ch / crop.height
    crop = crop.resize((max(1, int(crop.width * s)), max(1, int(crop.height * s))), Image.LANCZOS)
    arr = np.asarray(crop).copy()
    fire = P.transient_mask(arr[:, :, :3]) & (arr[:, :, 3] > 0)
    body = (arr[:, :, 3] > 0) & ~fire

    body_img = arr.copy()          # 保留全部像素(含焰): 焰层右移后原位置由 body 兜底,
                                   # 否则 body 清 fire → 焰移走露出洞(成品焰心黑洞实证)
    fire_img = arr.copy()
    fire_img[:, :, 3][~fire] = 0

    bys, bxs = np.where(body_img[:, :, 3] > 0)
    if len(bxs) == 0:
        return place_frame(rgba, scale)
    bx0, by0 = int(bxs.min()), int(bys.min())
    sub_body = body_img[by0:bys.max() + 1, bx0:int(bxs.max()) + 1]
    sb = Image.fromarray(sub_body)
    out = Image.new("RGBA", (FS, FS), (0, 0, 0, 0))
    sx = P.stance_x_of(np.asarray(sb))
    px = (int(FS * STANCE_FRAC) - sx) if sx is not None else (FS - sb.width) // 2
    px = max(0, min(px, FS - sb.width))
    py = FS - sb.height - int(round(FOOT * FS))
    out.paste(sb, (px, py), sb)

    fys, fxs = np.where(fire_img[:, :, 3] > 0)
    if len(fxs):
        fx0, fy0 = int(fxs.min()), int(fys.min())
        sub_fire = fire_img[fy0:fys.max() + 1, fx0:int(fxs.max()) + 1]
        px_f = px + (fx0 - bx0)      # 原始相对偏移落位
        py_f = py + (fy0 - by0)
        if px_f < 6:                 # 压贴: 超左缘 → 右移贴管口
            px_f = 6
        if px_f + sub_fire.shape[1] > FS - 3:
            px_f = FS - 3 - sub_fire.shape[1]
        sf = Image.fromarray(sub_fire)
        out.alpha_composite(sf, (max(0, px_f), max(0, py_f)))
    return out


def extract_comp(grid_path, idx):
    """从备用卷取指定格(阅读序): 键控+剔烟+despill+紧凑裁剪。
    选卷依据: t1/t3 烟亮白命中 smoke_mask; t5 烟暗棕[93,81,77]漏剔(实证)。"""
    g = Image.open(grid_path).convert("RGB")
    alpha_full, labels, comps = P.grid4_to_frames(g)
    if alpha_full is None:
        return None
    npx, bbox, cid = comps[idx]
    x0, y0, x1, y1 = bbox
    sub_rgb = np.asarray(g)[y0:y1 + 1, x0:x1 + 1]
    a2 = np.where(labels[y0:y1 + 1, x0:x1 + 1] == cid, alpha_full[y0:y1 + 1, x0:x1 + 1], 0).astype(np.uint8)
    # 烟剔除避开焰邻域(3px): 白色焰心饱和度≈0 会被 smoke_mask 当烟剔 → 焰心黑洞(实证)
    fire = P.transient_mask(sub_rgb)
    fd = fire.copy()
    for _ in range(3):
        fd = fd | np.roll(fd, 1, 0) | np.roll(fd, -1, 0) | np.roll(fd, 1, 1) | np.roll(fd, -1, 1)
    a2[smoke_mask_smart(sub_rgb, a2) & ~fd] = 0
    ys, xs = np.where(a2 > 0)
    if len(xs) == 0:
        return None
    rgba = np.ascontiguousarray(np.dstack([sub_rgb, a2])[ys.min():ys.max() + 1, xs.min():xs.max() + 1])
    return strong_despill(rgba)


def _png_bytes(im):
    import io
    buf = io.BytesIO()
    im.save(buf, "PNG")
    return buf.getvalue()


def main():
    keys = P.load_keys()
    os.makedirs(RAW, exist_ok=True); os.makedirs(FRAMES, exist_ok=True); os.makedirs(ROLLS, exist_ok=True)
    from_raw = None
    f3_from = None
    borrows = {}   # 格号(idx) -> 备用卷文件名; --borrow=idx:file 可多个
    for arg in _ARGS:
        if arg.startswith("--from-raw="):
            from_raw = arg.split("=", 1)[1]
        if arg.startswith("--f3-from="):
            f3_from = arg.split("=", 1)[1]
            borrows[1] = f3_from
        if arg.startswith("--borrow="):
            k, v = arg.split("=", 1)[1].split(":", 1)
            borrows[int(k)] = v

    # 锚 = idle f0 (蹲姿扛筒)
    idle = Image.open(IDLE_SHEET).convert("RGBA")
    anchor = idle.crop((0, 0, FS, FS))
    anchor = anchor.crop(anchor.getbbox())
    anchor.save(os.path.join(OUT, "anchor_idle.png"))

    tpl = P.build_grid_template_4_card(anchor, FS)
    tpl.save(os.path.join(OUT, "grid_template_4.png"))
    tpl_b64 = base64.b64encode(open(os.path.join(OUT, "grid_template_4.png"), "rb").read()).decode()
    # 单参考(2026-10-13 用户指示): 只用原最高分辨率卡图, 不再传精灵底稿——
    # 底稿(idle f0 放大 1024)把描边风格/偏小尺寸/白格线残留带进生成卷。
    # 用 player 变体(亮灰绿, 与现役卷风格一致; enemy 变体偏黑被用户否)——
    # 原图朝右, 水平翻转成朝左再传, 避免与 facing LEFT 冲突诱发翻面帧。
    card_hi = Image.open(os.path.join(WS, "assets", "card_icons", "player", "ww2_inf_bazooka.png")).convert("RGBA")
    card_hi = card_hi.transpose(Image.FLIP_LEFT_RIGHT)
    card_hi = card_hi.crop(card_hi.getbbox())
    # 大卡图: ~942px 贴 1024² 白底画布当参考 1
    big = int(1024 * 0.92)
    sc = big / max(card_hi.size)
    card_hi2 = card_hi.resize((max(1, int(card_hi.width * sc)), max(1, int(card_hi.height * sc))), Image.LANCZOS)
    canvas = Image.new("RGBA", (1024, 1024), (255, 255, 255, 255))
    canvas.paste(card_hi2, ((1024 - card_hi2.width) // 2, 1024 - int(card_hi2.height * 0.96)), card_hi2)
    canvas.save(os.path.join(OUT, "anchor_card.png"))
    card_b64 = base64.b64encode(_png_bytes(canvas)).decode()
    # 4 格底稿当参考 2: 人物缩小(cap 0.72)留宽品红沟——给火光/筒口留余量, 防越中线熔连
    tpl = P.build_grid_template_4_card(card_hi, 1024, scale_cap=0.60)
    tpl.save(os.path.join(OUT, "grid_template_4.png"))
    tpl_b64 = base64.b64encode(_png_bytes(tpl)).decode()
    refs = [card_b64, tpl_b64]

    rec = {"unit": UID, "mode": "kneel-v1"}
    ok = False
    attempts = [(0, from_raw)] if from_raw else [(i, None) for i in range(1, 6)]
    for attempt, pre in attempts:
        print("[kneel] 试 %d ..." % attempt, flush=True)
        try:
            if pre:
                grid_path = os.path.join(RAW, pre)
                url, kh = "(from-raw %s)" % pre, "reuse"
            else:
                url, kh = i2i(build_prompt(), refs, keys, "grid4_t%d" % attempt)
                grid_path = os.path.join(RAW, "grid4_t%d.png" % attempt)
                download_url(url, grid_path)
            grid = Image.open(grid_path).convert("RGB")
        except RuntimeError as e:
            print("  ×", e); time.sleep(15); continue

        alpha_full, labels, comps = P.grid4_to_frames(grid)
        if alpha_full is None:
            print("  × 门禁:", comps); time.sleep(8); continue
        # 剔烟后过门(烟不属主体身份, 三卷误杀实证——见 smoke_mask 注)
        a_ns, labels_ns, comps_ns = grid4_to_frames_nosmoke(grid)
        if a_ns is not None:
            flipped, fmsgs = P.grid4_flip_check(grid, a_ns, labels_ns, comps_ns)
        else:
            flipped, fmsgs = P.grid4_flip_check(grid, alpha_full, labels, comps)
        if flipped:
            print("  × 反帧:", " ".join(fmsgs)); time.sleep(8); continue
        idr = identity_gate_smoke(grid, comps, P.ref_sig)
        print("  pair=%.3f 击发IoU=%s" % (idr["mx_pair"], idr.get("firing_iou")))
        # --from-raw = 复跑人工已认可的卷: 身份/形状门是掷新卷的自动判废器, 此处跳过
        if not from_raw and not idr.get("ok", idr["mx_pair"] <= 0.6):
            print("  × 异体卷"); time.sleep(8); continue

        # aim 帧(阅读序第 0 = top-left)定标
        h_aim = comps[0][1][3] - comps[0][1][1]
        scale = (0.89 * FS) / h_aim

        frames = {}
        raw_crops = {}
        for i, (npx, bbox, cid) in enumerate(comps):
            x0, y0, x1, y1 = bbox
            pad = 2
            x0, y0 = max(0, x0 - pad), max(0, y0 - pad)
            x1, y1 = min(alpha_full.shape[1] - 1, x1 + pad), min(alpha_full.shape[0] - 1, y1 + pad)
            mask = labels[y0:y1 + 1, x0:x1 + 1] == cid
            a2 = np.where(mask, alpha_full[y0:y1 + 1, x0:x1 + 1], 0).astype(np.uint8)
            sub_rgb = np.asarray(grid)[y0:y1 + 1, x0:x1 + 1]
            # §7.10 定案: 默认只去背景+最小清理(品红残影), 全链伤图(胸口网纹实证)。
            # BAZOOKA_LEGACY=1 回旧全链(剔烟/despill/去污/残渣) 仅排障对照用。
            if os.environ.get("BAZOOKA_LEGACY") == "1":
                fire = P.transient_mask(sub_rgb)
                fd = fire.copy()
                for _ in range(3):
                    fd = fd | np.roll(fd, 1, 0) | np.roll(fd, -1, 0) | np.roll(fd, 1, 1) | np.roll(fd, -1, 1)
                a2[smoke_mask_smart(sub_rgb, a2) & ~fd] = 0
            ys, xs = np.where(a2 > 0)
            if len(xs) == 0:
                continue
            cy0, cy1, cx0, cx1 = ys.min(), ys.max(), xs.min(), xs.max()
            rgba = np.ascontiguousarray(np.dstack([sub_rgb, a2])[cy0:cy1 + 1, cx0:cx1 + 1])
            # 边缘 antialias 渗色带仍要除(§7.9 v2 口径: 只清 a<250 半透明边)
            rgba = strong_despill(rgba)
            if os.environ.get("BAZOOKA_LEGACY") == "1":
                rgba = ground_shadow_cut(rgba)
                rgba = decontaminate_edges(rgba)
                rgba = clean_scraps(rgba)
            else:
                rgba = clean_magenta_residue(rgba)
            raw_crops[i] = rgba
            if i == 1:  # 击发格: 焰压贴摆位(整宽钳位会缩人 20%, t1~t5 实测)
                frames["f3"] = place_firing_frame(rgba, scale)
            else:
                frames["f%d" % (i + 2)] = place_frame(rgba, scale)
        # 单帧法借格(--borrow=格号:卷 / --f3-from=卷 等价 borrow 1): 本卷该格有缺陷
        # (人小/暗烟撑宽/烟团)而后处理救不回。借备用卷同序格: 净人高对齐 f2 +
        # 色板迁移对齐本卷(击发格再加焰压贴摆位)。
        for bidx, bfile in sorted(borrows.items()):
            if 0 not in raw_crops:
                break
            fr = extract_comp(os.path.join(RAW, bfile), bidx)
            if fr is None:
                print("  borrow %d:%s 提取失败" % (bidx, bfile)); continue
            m2, s2 = P.body_stats(raw_crops[0][:, :, :3].astype(float), raw_crops[0][:, :, 3])
            moved = np.asarray(P.color_transfer(Image.fromarray(fr[:, :, :3]), fr[:, :, 3], m2, s2))
            if bidx == 1:
                # 二次校正: 一次 Reinhard 拉不平焰光帧的分布形状(残差实测仍偏亮)
                m3, s3 = P.body_stats(moved.astype(float), fr[:, :, 3])
                if np.abs(m3 - m2).mean() > 6:
                    moved = np.clip(moved.astype(float) + (m2 - m3), 0, 255).astype(np.uint8)
                frames["f3"] = place_firing_frame(np.dstack([moved, fr[:, :, 3]]),
                                                  raw_crops[0].shape[0] / moved.shape[0])
            else:
                frames["f%d" % (bidx + 2)] = place_frame(np.dstack([moved, fr[:, :, 3]]),
                                                         raw_crops[0].shape[0] / moved.shape[0])
            print("  f%d 借自 %s" % (bidx + 2, bfile))

        book = place_frame(np.asarray(anchor), TARGET_H / anchor.height)
        frames["f1"] = book; frames["f6"] = book
        for old in os.listdir(FRAMES):
            if old.endswith(".png"):
                os.remove(os.path.join(FRAMES, old))

        sheet = Image.new("RGBA", (FS * len(KEEP_FRAMES), FS), (0, 0, 0, 0))
        # §7.10: fill_holes 降级为排障开关(默认不跑, 伤图实证); BAZOOKA_FILLHOLES=1 才启用
        no_fill = os.environ.get("BAZOOKA_FILLHOLES") != "1"
        for i, src in enumerate(KEEP_FRAMES):
            fr = frames["f%d" % src] if no_fill else fill_holes(frames["f%d" % src])
            fr.save(os.path.join(FRAMES, "f%d.png" % (i + 1)))
            sheet.paste(fr, (i * FS, 0))
        sheet.save(os.path.join(OUT, "sheet_attack_api.png"))

        # GIF 预览 (128px, 8fps)
        gif_frames = [f.resize((128, 128), Image.LANCZOS) for f in
                      [Image.open(os.path.join(FRAMES, "f%d.png" % (i + 1))) for i in range(len(KEEP_FRAMES))]]
        gif_frames[0].save(os.path.join(OUT, "preview_kneel.gif"), save_all=True,
                           append_images=gif_frames[1:] + [gif_frames[0]], duration=130, loop=0, disposal=2)

        # 新旧对照条
        old = Image.open(os.path.join(WS, "assets", "effects", "unit_anims", "ww2_inf_bazooka", "sheet_attack.png")).convert("RGBA")
        strip = Image.new("RGBA", (max(old.width, sheet.width), old.height + sheet.height + 8), (24, 24, 28, 255))
        strip.paste(old, (0, 0), old)
        strip.paste(sheet, (0, old.height + 8), sheet)
        strip.save(os.path.join(OUT, "strip_kneel_vs_old.png"))

        rec.update(roll=attempt, key=kh, pair=idr["mx_pair"], url=url[:80], audit="pass")
        ok = True
        print("  [OK] 卷 %d 通过" % attempt)
        break

    json.dump(rec, open(os.path.join(OUT, "batch_result.json"), "w"), ensure_ascii=False, indent=1)
    print("done" if ok else "FAIL: 5 掷全废")


if __name__ == "__main__":
    main()
