# -*- coding: utf-8 -*-
"""generate_truck_sprites.py —— 移动基地·五时代卡车精灵（白底生成→泛洪转透明→部署）

用途：世界地图卡车标记 + 移动基地外景停靠（用户 2026-09-04：卡车像卡图一样可在大地图上移动）。
管线先例：卡图两段式（generate_missing_card_icons_11.py 的 STRICT_PREFIX 白底锁 +
deploy_world_map_assets.py 的 flood_white_to_alpha 边缘泛洪转透明 + autocrop）。
注意：generated_truck_interior 的剖面图背景是画进去的战场场景，不能就地抠图——必须白底重生成。

用法：
  python tools/generate_truck_sprites.py               # 生成缺失 + 部署全部
  python tools/generate_truck_sprites.py era3          # 重roll 单张（先删 docs 源图）+ 部署
  python tools/generate_truck_sprites.py --deploy-only # 只跑部署（不调 API）
"""
import json, os, re, sys, time
from collections import deque

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KEY_MD = os.path.join(ROOT, "tools", "_agnes_image_api.md")
SRC_DIR = os.path.join(ROOT, "docs", "基地重设计", "generated_truck_sprite")
OUT_DIR = os.path.join(ROOT, "assets", "ui", "truck_base")
BASE_URL = "https://apihub.agnes-ai.cn/v1"
MODEL = "agnes-image-2.1-flash"
SIZE = "1152x768"

# ── 白底锁（卡图管线 STRICT_PREFIX 同款铁律）──
P_STRICT = (
    "2D game concept art, hand-painted stylized game art, "
    "single subject only centered, clean pure white background, NO ground, NO shadow, NO floor, NO scenery, "
    "studio product shot on white, "
    "strictly side view facing left, flat orthographic side elevation, "
    "the complete vehicle fits fully inside the frame with clear space above its roof, "
    "muted palette of dark grey-brown and olive green with small cyan accent lights, "
    "very high detail density on the vehicle, crisp shapes. "
    "Flat side view only, no perspective view, no text, no watermark. "
)
P_BASE = (
    "VEHICLE: a military command truck — a forward engine cab plus a tall rectangular "
    "armored command body built onto the rear frame, a small step ladder under the body side door, "
    "a fold-down ramp folded up at the rear tailgate. "
)

ERAS = {
    "era1": "ARMOR LANGUAGE: a World War One era military truck — simple steel rims with solid rubber tires, "
            "wooden plank cargo bed side panels with a canvas canopy stretched over hoops, "
            "crude riveted iron plates bolted onto the cab front, a tall thin wire antenna mast, "
            "two round kerosene-style headlamps, olive-green paint worn pale at the edges. ",
    "era2": "ARMOR LANGUAGE: a World War Two era armored command truck — fully enclosed welded steel armored "
            "box body with visible weld seams and bolt heads, angular armored cab with tiny protected vision slots, "
            "two thin rod antennas, jerry cans and a shovel strapped to the side panel, "
            "camouflage patches of olive and brown over grey-green paint. ",
    "era3": "ARMOR LANGUAGE: a Cold War era armored command truck — slab-sided armored body with one horizontal "
            "row of rectangular reactive armor blocks along the flank, a roof rack carrying a small rotating "
            "radar dish and a dense radio antenna array, one boxy infrared searchlight beside the cab, "
            "olive-drab body with large sand-colored camouflage shapes. ",
    "era4": "ARMOR LANGUAGE: a near-future armored command truck — smooth angled composite armor panels, "
            "one roof rail carrying two small boxy drones locked in launch cradles, "
            "thin cyan light strips running along the body edges, every side panel fully closed and flush, "
            "low-profile wide tires, digital camouflage of flat grey-green rectangles. ",
    "era5": "ARMOR LANGUAGE: a far-future phase-tech command land fortress on wheels — towering and very long, "
            "a forward armored cab plus a long semi-trailer command body roughly three times the cab length, "
            "connected by a visible fifth-wheel coupling gap, eight huge wheels on two rear axle groups, "
            "folded angular roof panels, thin glowing cyan phase-energy lines tracing the hull edges, "
            "one tall slender communications mast above the cab. ",
}

# ── v26.12d 移动基地等级线（基地与时代脱钩；车厢一次定型装下全部模块舱，升级只改外部）──
# 科技阶梯：现代（裸壳/焊接/反应装甲+现代无人机）→ 未来（能量炮塔/悬浮助力/科幻壳）→ 相位（顶点）。
P_TIER = (
    "2D game concept art, hand-painted stylized game art, "
    "single subject only centered, clean pure white background, NO ground, NO shadow, NO floor, NO scenery, "
    "studio product shot on white, "
    "strictly side view facing left, flat orthographic side elevation, "
    "the complete vehicle fits fully inside the frame, "
    "LAYOUT (identical in every tier): a very long land-train style military command vehicle — an "
    "integrated armored command hull roughly seven to eight times the cab length, always the same "
    "size, a forward command cab at the front, a fold-down ramp folded flat at the rear tailgate, "
    "a small step ladder under the body side door, "
    "very high detail density on the vehicle, crisp shapes. "
    "Flat side view only, no perspective view, no text, no watermark. "
)
TIERS = {
    "1": "STYLE: present-day bare starter — plain olive-green paint, canvas canopy strip over the roof "
         "vents, simple steel bumpers, twelve wheels on four axle groups, almost no outside equipment. ",
    "2": "STYLE: modern armored — welded steel armor plates with weld seams and bolt heads over the whole "
         "body, rod antennas, jerry cans and a shovel strapped on the flank, olive-and-brown camouflage, "
         "riding on heavy caterpillar tracks (no rubber wheels). ",
    "3": "STYLE: modern heavy — one full row of rectangular reactive armor blocks along the flank, a big "
         "roof radar dish and dense antenna masts, a stern drone rail carrying two modern reconnaissance "
         "drones, sand-and-olive camouflage, riding on heavy caterpillar tracks (no rubber wheels). ",
    "4": "STYLE: NEAR FUTURE — the vehicle is completely redesigned, no diesel parts left: NO wheels, the "
         "long hull rides on four hover thruster skids with soft cyan down-glow; sleek faceted stealth "
         "shell of gunmetal and arctic-white plating, NOT olive green, NO camouflage; a compact railgun "
         "energy turret on the roof; flat phased-array sensor panels instead of dish antennas; glowing "
         "reactor cell ports along the flank; cyan energy bands tracing the hull edges; NO step ladder "
         "anywhere — boarding is through a hover platform hatch. ",
    "5": "STYLE: PHASE ERA PINNACLE — every visible element is functional, nothing decorative: NO wheels, "
         "the long hull FLOATS above the ground on four antigrav phase pads with glowing cyan lift haze "
         "underneath (this is the propulsion); the shell is dark obsidian metal with thin phase-energy "
         "conduit lines carrying power along the flank and roof; roof equipment is strictly working gear — "
         "a rotating sensor mast, a laser point-defense array (a row of four glowing laser emitter "
         "barrels on a rotating mount), and two docking hatches with drone escorts floating beside the "
         "hull; a fold-down rear ramp; NO crystal, NO sail, NO crane arm, NO ornament; dark obsidian "
         "shell, olive only as a thin heritage stripe. ",
}

# ── v26.12d 五级剖面图（内部模块化舱室；白底可抠图，悬浮合成到关卡地图上）──
# 设备铁律（用户 2026-09-05）：每级必有 指挥台(电脑) + 买卡售货机 + 3D打印 + 恰好一张床；
# 模块化胶囊舱一字排开；长度一致（固定车长）；科技等级随车阶递进。
P_CUT = (
    "2D game concept art, hand-painted stylized game art, "
    "single subject only centered, clean pure white background, NO ground, NO shadow, NO floor, NO scenery, "
    "studio product shot on white, "
    "strictly side view facing left, flat orthographic side elevation, "
    "the complete vehicle fits fully inside the frame with clear space above its roof, "
    "a forward engine cab with a visible driver seat, plus a long rectangular command body whose outer "
    "side wall is cut away open like a dollhouse cross-section, fully revealing the furnished interior "
    "compartments in one long row from cab to tailgate, "
    "the interior is divided into modular capsule compartments separated by visible frame ribs, each "
    "capsule a distinct functional unit, "
    "very high detail density on the interior, a real lived-in working military home on wheels, "
    "crisp shapes. Flat side view only, no perspective corridor view, no open ceiling view, no text, no watermark. "
)
CUTS = {
    "1": "INTERIOR (tier 1 starter command post — simple but complete): rough steel and wood interior, "
         "a command desk with one boxy early computer terminal and a paper map on the wall, "
         "a simple card vending machine stocked with card packs, a basic desktop 3D printer on a "
         "workbench with a small robotic arm, "
         "a folding camp cot — exactly one bed, "
         "a small pot-belly stove, wooden and steel storage crates, hand tools hanging on a wall rack, "
         "warm lamplight. ",
    "2": "INTERIOR (tier 2 modern armored command post — complete and functional): riveted steel interior, "
         "the vehicle rides on heavy caterpillar tracks (no rubber wheels), "
         "a command console with computer monitors and a paper map wall, "
         "a card vending machine stocked with card packs, an industrial 3D printer with a robotic arm in "
         "its own work bay, "
         "a single metal bunk — exactly one bed, "
         "metal lockers and weapon racks, a compact galley unit, a diesel generator compartment with "
         "cable runs, fluorescent tube lights. ",
    "3": "INTERIOR (tier 3 modern heavy command center — dense and complete): "
         "the vehicle rides on heavy caterpillar tracks (no rubber wheels), "
         "a multi-monitor computer workstation with a big map board, "
         "a card vending machine, an industrial fabrication bay with a large 3D printer and tool arms, "
         "a laboratory bench with analysis equipment, "
         "exactly one single bed in its own nook, "
         "a drone maintenance rack, a diesel generator compartment with thick cable trays, "
         "fluorescent lights, dense equipment racks. ",
    "4": "INTERIOR (tier 4 near-future command bay — sleek and complete): "
         "NO wheels anywhere — the hull rides on four enclosed glowing turbine pads with soft cyan "
         "down-glow (hover propulsion), "
         "a command capsule with a wide curved flat screen and control consoles, "
         "a card vending wall, a clean fabrication bay with a large 3D printer and dual robotic arms, "
         "a laboratory capsule with analysis equipment, "
         "exactly one hover bunk in its own sleep capsule, "
         "a compact energy reactor core with glowing conduits, a drone bay, "
         "cyan strip lights, smooth composite panels. ",
    "5": "INTERIOR (tier 5 phase flagship bay — the richest and most advanced): "
         "the whole vehicle FLOATS HIGH in mid-air — a clear empty gap of pure empty white space beneath "
         "the hover pads, nothing below the vehicle at all, NO ground shadow; the hull hovers on "
         "articulated landing struts with soft blue-glowing hover pads, "
         "a command capsule with a large sand-table terrain model and many small flat screens showing "
         "simple abstract glowing symbols, "
         "phase-crystal energy conduits running along the ceiling branching into every compartment, "
         "a large fabrication bay with an additive manufacturing printer and dual robotic arms, "
         "a card vending wall, a laboratory capsule with sample racks and flat readout panels, "
         "exactly one capsule bunk — a single bed, "
         "walls of storage crates, dense cable trays and pipes, cyan strip lights. ",
}


def load_keys():
    src = open(KEY_MD, "r", encoding="utf-8").read()
    keys = re.findall(r"sk-[A-Za-z0-9]{20,}", src)
    if not keys:
        raise SystemExit("tools/_agnes_image_api.md 里找不到 key")
    return keys


def call_api(prompt, key, out):
    import urllib.request
    payload = json.dumps({"model": MODEL, "prompt": prompt, "size": SIZE, "n": 1}).encode("utf-8")
    req = urllib.request.Request(
        BASE_URL + "/images/generations", data=payload,
        headers={"Authorization": "Bearer " + key, "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=200) as r:
            data = json.loads(r.read().decode("utf-8", errors="replace"))
    except Exception as e:
        print("  请求失败: %s" % str(e)[:160])
        return False
    url = (data.get("data") or [{}])[0].get("url", "")
    if url:
        try:
            with urllib.request.urlopen(urllib.request.Request(url), timeout=200) as r, open(out, "wb") as f:
                f.write(r.read())
        except Exception as e:
            print("  下载失败: %s" % str(e)[:160])
            return False
    else:
        b64 = (data.get("data") or [{}])[0].get("b64_json", "")
        if not b64:
            print("  无图像数据")
            return False
        import base64
        with open(out, "wb") as f:
            f.write(base64.b64decode(b64))
    return os.path.exists(out) and os.path.getsize(out) > 5000


# ── 白底转透明（deploy_world_map_assets.py flood_white_to_alpha 同逻辑：边缘泛洪，保内部高光）──
def flood_white_to_alpha(im, thresh=238):
    im = im.convert("RGBA")
    w, h = im.size
    px = im.load()
    seen = bytearray(w * h)

    def near_white(x, y):
        r, g, b, _a = px[x, y]
        return r >= thresh and g >= thresh and b >= thresh

    q = deque()
    for x in range(w):
        for y in (0, h - 1):
            if near_white(x, y) and not seen[y * w + x]:
                seen[y * w + x] = 1
                q.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            if near_white(x, y) and not seen[y * w + x]:
                seen[y * w + x] = 1
                q.append((x, y))
    while q:
        x, y = q.popleft()
        px[x, y] = (255, 255, 255, 0)
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h and not seen[ny * w + nx] and near_white(nx, ny):
                seen[ny * w + nx] = 1
                q.append((nx, ny))
    return im


def remove_enclosed_white(im, min_pixels=400, thresh=238):
    """二遍处理：清除被车身/阴影环包住的封闭大白块（地面阴影残留）。
    小面积白色高光（车灯/反光 < min_pixels）保留。"""
    w, h = im.size
    px = im.load()
    seen = bytearray(w * h)

    def near_white(x, y):
        r, g, b, a = px[x, y]
        return a > 0 and r >= thresh and g >= thresh and b >= thresh

    comps = []
    for y0 in range(h):
        for x0 in range(w):
            if not seen[y0 * w + x0] and near_white(x0, y0):
                comp = []
                q = deque()
                q.append((x0, y0))
                seen[y0 * w + x0] = 1
                while q:
                    x, y = q.popleft()
                    comp.append((x, y))
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        nx, ny = x + dx, y + dy
                        if 0 <= nx < w and 0 <= ny < h and not seen[ny * w + nx] and near_white(nx, ny):
                            seen[ny * w + nx] = 1
                            q.append((nx, ny))
                comps.append(comp)
    for comp in comps:
        if len(comp) >= min_pixels:
            for x, y in comp:
                px[x, y] = (255, 255, 255, 0)
    return im


def autocrop(im, pad=4):
    bbox = im.getbbox()
    if not bbox:
        return im
    l, t, r, b = bbox
    l = max(0, l - pad)
    t = max(0, t - pad)
    r = min(im.width, r + pad)
    b = min(im.height, b + pad)
    return im.crop((l, t, r, b))


def deploy_all():
    from PIL import Image
    os.makedirs(OUT_DIR, exist_ok=True)
    ok = 0
    # (基础名, 是否做封闭白块清除)；剖面图内壁大面积浅色会被误删 → 只泛洪
    names = [(base, True) for base in ["truck_sprite_%s" % e for e in ERAS]
             + ["truck_tier%s" % t for t in TIERS]]
    names += [("truck_cut%s" % c, False) for c in CUTS]
    for base, strip_enclosed in names:
        src = os.path.join(SRC_DIR, base + ".jpeg")
        dst = os.path.join(OUT_DIR, base + ".png")
        if not os.path.exists(src):
            continue
        im = Image.open(src)
        out = flood_white_to_alpha(im)
        if strip_enclosed:
            out = remove_enclosed_white(out)
        out = autocrop(out)
        out.save(dst, "PNG")
        print("[deploy] %s -> %s %s" % (os.path.basename(src), os.path.basename(dst), out.size))
        ok += 1
    print("部署 %d" % ok)


def main():
    from PIL import Image  # noqa: 延迟导入
    args = [a for a in sys.argv[1:] if not a.startswith("-")]
    deploy_only = "--deploy-only" in sys.argv
    os.makedirs(SRC_DIR, exist_ok=True)
    if not deploy_only:
        keys = load_keys()
        jobs = [("truck_sprite_%s.jpeg" % eid, P_STRICT + P_BASE + desc, eid) for eid, desc in ERAS.items()]
        jobs += [("truck_tier%s.jpeg" % t, P_STRICT + P_TIER + desc, t) for t, desc in TIERS.items()]
        jobs += [("truck_cut%s.jpeg" % c, P_STRICT + P_CUT + desc, c) for c, desc in CUTS.items()]
        if args:
            want = {a for a in args}
            jobs = [j for j in jobs if any(w in j[0] for w in want)]
        for i, (fname, prompt, eid) in enumerate(jobs):
            out = os.path.join(SRC_DIR, fname)
            if os.path.exists(out) and os.path.getsize(out) > 5000:
                print("[%d/%d] %s 已存在，跳过" % (i + 1, len(jobs), fname))
                continue
            print("[%d/%d] %s ..." % (i + 1, len(jobs), fname), end="", flush=True)
            ok = call_api(prompt, keys[i % len(keys)], out)
            print(" OK %dKB" % (os.path.getsize(out) // 1024) if ok and os.path.exists(out) else " FAIL")
            if i < len(jobs) - 1:
                time.sleep(3)
    deploy_all()


if __name__ == "__main__":
    main()
