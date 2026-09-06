# -*- coding: utf-8 -*-
"""generate_truck_img2img.py —— 移动基地·图生图轮（用户 2026-09-05：越生成越差，要传原图给 API 按原图生成）

与 generate_truck_sprites.py（纯文生图）的区别：请求体带 extra_body.image = [Data URI base64 母本图]，
prompt 只写编辑指令。官方推荐结构：[改变要求] + [添加/移除元素] + [要保留的元素]；
API 无 strength 参数，保留度全靠提示词。经验（_agnes_image_api.md）：不写"不要 X"负面清单，
用"该画什么"正面替代（如"车顶只留一根杆状天线"替代"不要激光炮"）。

母本（两张都是用户亲手给的图，不再漂移）：
  外观 = generated_truck_sprite/library_hero_3840x1240.png_2K_202609051213.jpeg（tier5 悬浮装甲列车，白底）
         → T1-T4 全部从它降档改出：车体/比例/侧视角度完全不变，只降外设科技。
         T5 就是母本本体（已部署 truck_tier5.png），不重生成。
  剖面 = 单独图/Gravity_well_sprite_animation_202609041734.jpeg（用户最初认可的卡车剖面：
         电脑桌+墙上地图 / 卡贩卖机 / 3D打印 / 柜子 / 右上角一张床）
         → cut1-5 从它升档改出：构图/物件位置不动，背景改纯白（供抠图），按档升设备与行走机构。

产物落 generated_truck_sprite/_i2i/，审核通过后再 --deploy 覆盖 assets/ui/truck_base/。

用法：
  python tools/generate_truck_img2img.py              # 生成全部缺失
  python tools/generate_truck_img2img.py tier1 cut5   # 只跑指定任务（已存在也重跑）
  python tools/generate_truck_img2img.py --sheet      # 只拼审核图 _i2i_review.png
"""
import base64, io, json, os, sys

from PIL import Image, ImageDraw

from collections import deque

from generate_truck_sprites import (
    MODEL, SRC_DIR, OUT_DIR, load_keys,
    remove_enclosed_white, autocrop,
)

I2I_DIR = os.path.join(SRC_DIR, "_i2i")
REF_EXT = os.path.join(SRC_DIR, "library_hero_3840x1240.png_2K_202609051213.jpeg")
REF_CUT = os.path.join(os.path.dirname(SRC_DIR), "单独图",
                       "Gravity_well_sprite_animation_202609041734.jpeg")
SIZE = "1152x768"

# 外观降档链：车体/比例/角度/画风全保留（车箱固定长度，升级只换外设）。
# tier5 = 母本本体，不在任务表里。
# v2 教训：第一轮 T1-T3 车体跑偏缩短——"conventional/present-day truck" 这类主体改名会让
# 模型整辆重画。v2 逐条列死母本特征锚死车体（超长 7-8 倍车头/列车式斜鼻/上排小窗），
# 换轮写"在悬浮垫原位换普通橡胶轮"，并显式要白底无影。
_EXT_ANCHOR = (
    "Edit this image. This is the SAME vehicle, only refitted. Keep the exact same very long "
    "armored land-train hull: the hull length stays about seven to eight times the cab length, "
    "with the same sleek locomotive-style sloped nose, the same row of small rectangular windows "
    "along the upper hull flank, the same rear tailgate. Keep the same hand-painted stylized "
    "game art style and the same plain pure white background. "
)
_EXT_TIERS = {
    "tier1": _EXT_ANCHOR +
        "Only change: the hover pads become ordinary large rubber-tired road wheels at the same "
        "positions and the vehicle rests on the ground, the thruster flames are gone; the roof is "
        "stripped to flat armor hatches plus one single thin rod antenna; the red cannon, the sensor "
        "pod and the radar dome are gone, leaving clean flat hull plates; plain worn olive-green paint. "
        "No text, no watermark, no ground shadow.",
    "tier2": _EXT_ANCHOR +
        "Only change: the hover pads become ordinary large rubber-tired road wheels at the same "
        "positions and the vehicle rests on the ground, the thruster flames are gone; the big red "
        "cannon, the sensor pod and the round radar dome are all removed, leaving a clean flat roof "
        "with only two thin rod antennas; the hull is covered in welded steel armor plates with "
        "visible weld seams and bolt heads; jerry cans strapped along the lower hull; camouflage "
        "patches of olive and brown. No text, no watermark, no ground shadow.",
    "tier3": _EXT_ANCHOR +
        "Only change: the hover pads become ordinary large rubber-tired road wheels at the same "
        "positions and the vehicle rests on the ground, the thruster flames are gone; one horizontal "
        "row of rectangular reactive armor blocks runs along the hull flank; a roof rack carries a "
        "small rotating radar dish and a dense radio antenna array; a boxy infrared searchlight sits "
        "beside the cab; sand-and-olive camouflage. No text, no watermark, no ground shadow.",
    "tier4": _EXT_ANCHOR +
        "Only change: keep it hovering just above the ground, but the orange flames become soft "
        "glowing cyan anti-gravity pads; the hull is smooth angled composite armor; one roof rail "
        "carries two small boxy drones; thin cyan light strips run along the hull edges; the top "
        "cannon becomes a long blue-white electromagnetic railgun. No text, no watermark, "
        "no ground shadow.",
}

# 剖面升档链 v2（用户纠正后）：先 cut_base 仅做背景白化锁构图（实测 .cn 端点更保真：
# 3D打印橙件/单床都保留；.com 会换掉打印件且多画一张床），五档全部从 cut_base 星形派生，
# 每张只做"加本档设备"的增量编辑，禁改车体——保证五张都是原图那辆车。
CUT_BASE = os.path.join(I2I_DIR, "cut_base_cn.jpeg")
PROMPT_CUT_BASE = (
    "Edit this image. Task: replace only the background. Keep the truck and its cut-open interior "
    "EXACTLY as in the input image — same cab design, same chassis, same wheels, same step ladders, "
    "same every piece of interior equipment in the same positions (computer desk, world map, vending "
    "machine, 3D printer, cabinets, bed), same colors, same painting style, same composition and camera. "
    "Only change: the desert background (rocks, sky, ground) becomes plain pure white, and the ground "
    "shadow under the truck is removed. Do not redraw the vehicle. No text, no watermark.")
_CUT_ANCHOR = ("Edit this image. Keep the truck, its cut-open cargo box and every piece of interior "
               "equipment EXACTLY at the same position as in the input image — same cab design, same "
               "chassis and wheels, same computer desk with the world map, same vending machine, same "
               "3D printer, same cabinets, same single bed, same colors and painting style. "
               "Do not redraw the vehicle, do not move anything. Only change this: ")
_CUTS = {
    "cut2": _CUT_ANCHOR +
        "add welded steel armor plating with visible bolt heads on the box exterior, a few more "
        "supply crates beside the cabinets, and one more thin radio antenna on the cab roof. "
        "No text, no watermark.",
    "cut3": _CUT_ANCHOR +
        "add a row of rectangular reactive armor blocks on the box exterior, a small radar dish on "
        "a roof rack above the box, and a radar console with a round screen beside the computer desk. "
        "No text, no watermark.",
    "cut4": _CUT_ANCHOR +
        "the computer screens now glow with cyan holographic readouts, a small robotic arm is mounted "
        "above the 3D printer, and thin cyan light strips run along the interior ceiling. "
        "No text, no watermark.",
    "cut5": _CUT_ANCHOR +
        "add far-future phase technology: cyan holographic displays around the desk, glowing energy "
        "conduits along the interior walls, the whole interior bathed in soft cyan light, and thin "
        "cyan energy lines tracing the box exterior panels. No text, no watermark.",
}

JOBS = {}
for _k, _p in _EXT_TIERS.items():
    JOBS[_k] = {"prompt": _p, "ref": REF_EXT}
for _k, _p in _CUTS.items():
    JOBS[_k] = {"prompt": _p, "ref": CUT_BASE}

def _data_uri(path, max_w=1408):
    im = Image.open(path).convert("RGB")
    if im.width > max_w:
        im.thumbnail((max_w, max_w))
    buf = io.BytesIO()
    im.save(buf, "JPEG", quality=90)
    return "data:image/jpeg;base64," + base64.b64encode(buf.getvalue()).decode()


def call_img2img(prompt, key, out, ref_path, base_urls):
    import urllib.request
    payload = json.dumps({
        "model": MODEL, "prompt": prompt, "size": SIZE, "n": 1,
        "extra_body": {"image": [_data_uri(ref_path)], "response_format": "url"},
    }).encode("utf-8")
    for base in base_urls:
        req = urllib.request.Request(
            base + "/images/generations", data=payload,
            headers={"Authorization": "Bearer " + key, "Content-Type": "application/json"})
        try:
            with urllib.request.urlopen(req, timeout=240) as r:
                data = json.loads(r.read().decode("utf-8", errors="replace"))
        except Exception as e:
            print("  [%s] 请求失败(%s): %s" % (base, "", str(e)[:140]))
            continue
        url = (data.get("data") or [{}])[0].get("url", "")
        try:
            if url:
                with urllib.request.urlopen(urllib.request.Request(url), timeout=240) as r, open(out, "wb") as f:
                    f.write(r.read())
            else:
                b64 = (data.get("data") or [{}])[0].get("b64_json", "")
                if not b64:
                    continue
                with open(out, "wb") as f:
                    f.write(base64.b64decode(b64))
        except Exception as e:
            print("  下载失败: %s" % str(e)[:140])
            continue
        if os.path.exists(out) and os.path.getsize(out) > 5000:
            return True
    return False


def run(only=None, force=False):
    os.makedirs(I2I_DIR, exist_ok=True)
    keys = load_keys()
    # .cn 实测比 .com 保真（打印件/单床保留），.com 仅作 .cn 失败兜底
    base_urls = ["https://apihub.agnes-ai.cn/v1", "https://apihub.agnes-ai.com/v1"]
    names = only if only else list(JOBS)
    for i, name in enumerate(names):
        job = JOBS.get(name)
        if job is None:
            print("未知任务: %s（可选: %s）" % (name, ", ".join(JOBS)))
            return 1
        out = os.path.join(I2I_DIR, name + ".jpeg")
        if name == "cut1":
            import shutil
            shutil.copyfile(CUT_BASE, out)
            print("[copy] cut1 = cut_base（原图即现代档，零漂移）")
            continue
        if os.path.exists(out) and not force and only is None:
            print("[skip] %s 已存在" % name)
            continue
        print("[%d/%d] %s ← 母本 %s" % (i + 1, len(names), name, os.path.basename(job["ref"])))
        ok = False
        for attempt in range(len(keys)):
            ok = call_img2img(job["prompt"], keys[(i + attempt) % len(keys)], out, job["ref"], base_urls)
            if ok:
                break
            print("  换 key 重试 %d" % (attempt + 1))
        print("  => %s" % ("OK %dKB" % (os.path.getsize(out) // 1024) if ok else "FAILED"))
    return 0


def sheet():
    """审核图：上排外观 tier1-5（tier5=母本），下排剖面 cut1-5，每格标名。"""
    cell = (360, 240)
    cols = 5
    canvas = Image.new("RGB", (cell[0] * cols, cell[1] * 2 + 60), (24, 26, 30))
    d = ImageDraw.Draw(canvas)
    tops = [("tier1", os.path.join(I2I_DIR, "tier1.jpeg")),
            ("tier2", os.path.join(I2I_DIR, "tier2.jpeg")),
            ("tier3", os.path.join(I2I_DIR, "tier3.jpeg")),
            ("tier4", os.path.join(I2I_DIR, "tier4.jpeg")),
            ("tier5=母本", REF_EXT)]
    bots = [("cut" + str(n), os.path.join(I2I_DIR, "cut%d.jpeg" % n)) for n in range(1, 6)]
    for row, items, y0 in ((0, tops, 0), (1, bots, cell[1] + 60)):
        for col, (label, path) in enumerate(items):
            x = col * cell[0]
            d.rectangle([x, y0, x + cell[0], y0 + 30], fill=(60, 64, 72))
            d.text((x + 8, y0 + 8), label, fill=(255, 255, 255))
            try:
                im = Image.open(path).convert("RGB")
                im.thumbnail((cell[0] - 8, cell[1] - 8))
                canvas.paste(im, (x + 4, y0 + 34 + (cell[1] - 8 - im.height) // 2))
            except Exception as e:
                d.text((x + 8, y0 + 60), "缺失: %s" % str(e)[:40], fill=(255, 120, 120))
    out = os.path.join(SRC_DIR, "_i2i_review.png")
    canvas.save(out)
    print("审核图: %s" % out)


def _kill_ground_band(im, y_frac=0.70, mx_lo=110, spread_max=28):
    """清外观图底部地面阴影：底带内中性灰(mx≥110、max-min 小)全删。
    实测（PIL 扫线）：阴影悬在 y≈0.74-0.85h、像素 (105..230) 中性灰且不接边缘；
    轮胎 mx≈34、迷彩/车体高饱和——均不受影响。tier4 的青色悬浮辉光 spread≈68 保留。"""
    im = im.convert("RGBA")
    w, h = im.size
    px = im.load()
    y0 = int(h * y_frac)
    for y in range(y0, h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            mx, mn = max(r, g, b), min(r, g, b)
            if mx >= mx_lo and mx - mn <= spread_max:
                px[x, y] = (0, 0, 0, 0)
    return im


def _flood_bg(im, thresh=235):
    """颜色感知背景泛洪（flood_white_to_alpha 的超集）：从边缘吃掉
    ①近白(≥thresh) ②浅中性光晕(mx≥180 且 max-min≤45，JPEG 阴影/辉光桥)
    ③浅青辉光(b,g≥200 且 r≤g-20，反重力光池桥)。深色轮廓/彩色车体即停。"""
    im = im.convert("RGBA")
    w, h = im.size
    px = im.load()
    seen = bytearray(w * h)

    def bg(x, y):
        r, g, b, _ = px[x, y]
        mx, mn = max(r, g, b), min(r, g, b)
        if mx >= thresh:
            return True
        if mx >= 180 and mx - mn <= 45:
            return True
        if b >= 200 and g >= 200 and r <= g - 20:
            return True
        return False

    q = deque()
    for x in range(w):
        for y in (0, h - 1):
            if bg(x, y) and not seen[y * w + x]:
                seen[y * w + x] = 1
                q.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            if bg(x, y) and not seen[y * w + x]:
                seen[y * w + x] = 1
                q.append((x, y))
    while q:
        x, y = q.popleft()
        px[x, y] = (255, 255, 255, 0)
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h and not seen[ny * w + nx] and bg(nx, ny):
                seen[ny * w + nx] = 1
                q.append((nx, ny))
    return im


def _remove_detached_ground_blobs(im, y_frac=0.5, area_frac=0.5):
    """删与车体分离、整体位于下半部的悬浮块（tier4/cut4/cut5 的青色反重力光池：
    饱和度高不被 _kill_ground_band 命中，且与车体之间有白隙——按连通域分离）。"""
    im = im.convert("RGBA")
    w, h = im.size
    px = im.load()
    seen = bytearray(w * h)
    comps = []
    for sy in range(h):
        for sx in range(w):
            if seen[sy * w + sx] or px[sx, sy][3] == 0:
                continue
            label = len(comps)
            q = [(sx, sy)]
            seen[sy * w + sx] = 1
            x0 = x1 = sx
            y0 = y1 = sy
            n = 0
            while q:
                x, y = q.pop()
                n += 1
                x0, x1 = min(x0, x), max(x1, x)
                y0, y1 = min(y0, y), max(y1, y)
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h and not seen[ny * w + nx] and px[nx, ny][3] != 0:
                        seen[ny * w + nx] = 1
                        q.append((nx, ny))
            comps.append((n, x0, y0, x1, y1))
    if len(comps) < 2:
        return im
    comps.sort(reverse=True)
    main_area, mx0, my0, mx1, my1 = comps[0]
    main_h = my1 - my0
    cut_y = my0 + int(main_h * y_frac)
    for area, x0, y0, x1, y1 in comps[1:]:
        if y0 > cut_y and area < main_area * area_frac:
            for y in range(y0, y1 + 1):
                for x in range(x0, x1 + 1):
                    if px[x, y][3] != 0:
                        px[x, y] = (0, 0, 0, 0)
    return im


def _kill_neutral_rect(im, x0, y0, x1, y1, mx_lo=110, spread_max=30):
    """定点清中性灰残留（驾驶室/厢体夹角处的背景袋，同母本构图五图同位）。
    只删矩形内的中性浅灰， outline/彩色车体不受影响。"""
    im = im.convert("RGBA")
    w, h = im.size
    px = im.load()
    for y in range(int(h * y0), int(h * y1)):
        for x in range(int(w * x0), int(w * x1)):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            mx, mn = max(r, g, b), min(r, g, b)
            if mx >= mx_lo and mx - mn <= spread_max:
                px[x, y] = (0, 0, 0, 0)
    return im


def deploy():
    """审核通过后覆盖 assets：外观 flood+封白+底带阴影清理+脱落光池；剖面 flood-only+脱落光池。"""
    plans = []
    for n in range(1, 5):
        plans.append(("tier%d" % n, "truck_tier%d.png" % n, True))
    for n in range(1, 6):
        plans.append(("cut%d" % n, "truck_cut%d.png" % n, False))
    for src_name, dst_name, is_tier in plans:
        src = os.path.join(I2I_DIR, src_name + ".jpeg")
        if not os.path.exists(src):
            print("缺源图，跳过 %s" % src_name)
            continue
        im = Image.open(src)
        im = _flood_bg(im, thresh=235)
        if is_tier:
            im = remove_enclosed_white(im, min_pixels=1500)
            im = _kill_ground_band(im)
        else:
            # 剖面：阴影(中性灰)挡住泛洪路径，在轮间/尾板下兜出残留底色袋——
            # y>0.80h 底带内中性灰全清（该带只有轮/跳板/阴影，内景墙在上方不受影响）
            im = _kill_ground_band(im, y_frac=0.80, mx_lo=100, spread_max=30)
            # 驾驶室/厢体夹角的浅色底袋（五图同位，只删中性灰不动车体描边）
            im = _kill_neutral_rect(im, 0.23, 0.62, 0.37, 0.76)
        im = _remove_detached_ground_blobs(im)
        im = autocrop(im, pad=4)
        dst = os.path.join(OUT_DIR, dst_name)
        im.save(dst)
        print("部署 %s (%dx%d)" % (dst_name, im.width, im.height))
    print("记得触发 Godot 导入。")


# ── tier5 新母本（用户 2026-09-05 下午给定：带地面场景版）专用抠图 ──
TIER5_MASTER = os.path.join(SRC_DIR, "library_hero_3840x1240.png_2K_202609051421.jpeg")


def deploy_tier5_master(dst_names=("truck_tier5.png", "truck_sprite_era5.png")):
    """新 tier5 抠图：上半白底泛洪 + 地面带清除 + 焰羽羽化保留。
    实测（_grid_tier5_new.png）：车体 y0.12-0.73h（喷口底缘~0.735h，滑橇~0.71h），
    焰羽 0.68-0.90h，地面线~0.755h、0.78h 以下满幅。
    0.73h 以下只留橙色焰羽（喷口橙光环属焰色保留），并随深度羽化到 0.80h 归零——
    地面/火花溅地全去，火焰在半空淡出，读作悬浮尾焰。"""
    from generate_truck_sprites import flood_white_to_alpha
    im = Image.open(TIER5_MASTER).convert("RGBA")
    w, h = im.size
    px = im.load()

    def is_flame(r, g, b):
        return (r > 150 and r - b > 60) or (r > 230 and g > 170 and b < 160)

    # 先泛洪（天空白区含喷口间气袋与外部连通，一次吃净；地面非白挡住泛洪），
    # 再清带——若反过来，清带留下的黑色透明像素会挡住近白 BFS，兜出白色残块
    im = flood_white_to_alpha(im, thresh=238)
    px = im.load()  # flood 内部 convert("RGBA") 返回副本，必须重新 load 指向新缓冲
    y_band0, y_band1 = int(h * 0.73), int(h * 0.80)
    for y in range(y_band1, h):
        for x in range(w):
            px[x, y] = (0, 0, 0, 0)
    for y in range(y_band0, y_band1):
        keep_frac = (y_band1 - y) / float(y_band1 - y_band0)
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            if not is_flame(r, g, b):
                px[x, y] = (0, 0, 0, 0)
            else:
                px[x, y] = (r, g, b, int(255 * keep_frac))
    # 火焰+车底+地面线围出的封闭白袋泛洪不可达，二遍封白清除（车身高光 <min_pixels 保留）
    from generate_truck_sprites import remove_enclosed_white
    im = remove_enclosed_white(im, min_pixels=1500)
    im = _remove_detached_ground_blobs(im)
    im = autocrop(im, pad=4)
    for dst_name in dst_names:
        dst = os.path.join(OUT_DIR, dst_name)
        im.save(dst)
        print("部署 %s (%dx%d)" % (dst_name, im.width, im.height))


# ── 五张用户定稿外观（2026-09-05 晚最终确认）→ 项目资产 ──
# 文件名注意：tier4 定稿是 tier4.jpeg（无 truck_ 前缀），其余带前缀
FINAL_SOURCES = {
    1: os.path.join(SRC_DIR, "truck_tier1.jpeg"),
    2: os.path.join(SRC_DIR, "truck_tier2.jpeg"),
    3: os.path.join(SRC_DIR, "truck_tier3.jpeg"),
    4: os.path.join(SRC_DIR, "tier4.jpeg"),
    5: os.path.join(SRC_DIR, "truck_tier5.jpeg"),
}


def deploy_finals():
    """用户定稿五张 → 抠图 → assets/ui/truck_base/truck_tierN.png（标准外观管线）。"""
    from generate_truck_sprites import flood_white_to_alpha, remove_enclosed_white
    for n, src in FINAL_SOURCES.items():
        if not os.path.exists(src):
            print("缺定稿图:", src)
            continue
        im = Image.open(src)
        im = flood_white_to_alpha(im, thresh=238)
        im = remove_enclosed_white(im, min_pixels=1500)
        im = _kill_ground_band(im)
        im = _remove_detached_ground_blobs(im)
        im = autocrop(im, pad=4)
        dst = os.path.join(OUT_DIR, "truck_tier%d.png" % n)
        im.save(dst)
        print("定稿部署 truck_tier%d.png (%dx%d)" % (n, im.width, im.height))


if __name__ == "__main__":
    args = [a for a in sys.argv[1:]]
    if "--sheet" in args:
        sheet()
    elif "--deploy" in args:
        deploy()
    elif "--tier5" in args:
        deploy_tier5_master()
    elif "--finals" in args:
        deploy_finals()
    else:
        only = [a for a in args if not a.startswith("-")] or None
        force = "--force" in args
        sys.exit(run(only, force))
