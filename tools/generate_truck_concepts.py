# -*- coding: utf-8 -*-
"""generate_truck_concepts.py —— 装甲卡车基地·五时代概念定调图（agnes-image-2.1-flash）

设计稿：docs/基地重设计/基地方案_空间概念选型.md §六（装甲卡车底盘，用户定调方向）
输出：docs/基地重设计/generated_truck/truck_era1..era5.jpeg  共 5 张
构图契约：五张同一机位——严格侧视、车头朝左、整车入画、停在战线边缘土路上；
只换装甲语言与背景，验证"同一车系逐代换甲 + 战场背景当车背景"。

agnes 行为铁律（tools/_agnes_image_api.md 实测）：
  负面词只留结构性排除；正面意象锁死；风格词禁 gritty/somber/dusty；
  屏幕/全息只画抽象图形；徽记只画"simple flat geometric shapes (never letters)"。

用法：
  python tools/generate_truck_concepts.py          # 全部 5 张（已存在跳过）
  python tools/generate_truck_concepts.py era3     # 单独重生成某时代
  python tools/generate_truck_concepts.py --list
"""
import json, os, re, sys, time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KEY_MD = os.path.join(ROOT, "tools", "_agnes_image_api.md")
OUT_DIR = os.path.join(ROOT, "docs", "基地重设计", "generated_truck")
BASE_URL = "https://apihub.agnes-ai.cn/v1"
MODEL = "agnes-image-2.1-flash"
SIZE = "1152x768"

# ── 共享骨架：构图契约 + 车系锚（五张一致的部分）──
P_SCENE = (
    "2D game concept art, hand-painted stylized game art, "
    "muted palette of dark grey-brown and olive green with small cyan accent lights, "
    "strictly side view of the whole vehicle facing left, flat orthographic view, "
    "the complete vehicle fits fully inside the frame with clear space above its roof, "
    "the truck is parked on a straight dirt road at the forward edge of a battlefield, "
    "the battlefield scenery behind it stays low, simple and quiet so the truck is clearly the hero, "
    "soft dusk light, no text, no watermark, crisp shapes, high detail density on the vehicle. "
)
P_TRUCK = (
    "VEHICLE: a six-wheel military command truck, a forward engine cab plus a tall rectangular "
    "command body built onto the rear frame, a small step ladder under a side door, "
    "a fold-down ramp at the rear tailgate, small cyan indicator lights along the body edge. "
)

# ── 五时代：装甲语言 + 战场背景（正面意象锁死）──
ERAS = {
    "era1": ("era1·一战老爷军卡",
        "ARMOR LANGUAGE: a World War One era military truck — simple steel rims with solid rubber tires, "
        "wooden plank cargo bed side panels, one canvas canopy stretched over hoops above the rear body, "
        "crude riveted iron plates bolted onto the cab front, a tall thin wire antenna mast, "
        "two round kerosene-style headlamps, olive-green paint worn pale at the edges, "
        "the improvised armor makes it read as a civilian truck pressed into war service. "
        "BATTLEFIELD: distant trench lines with wooden stakes and barbed wire posts, bare leafless trees, "
        "pale hazy morning sky, low rolling empty ground."),
    "era2": ("era2·二战焊接装甲厢",
        "ARMOR LANGUAGE: a World War Two era armored command truck — fully enclosed welded steel armored "
        "box body with visible weld seams and bolt heads, angular armored cab with tiny protected vision slots, "
        "a small round roof hatch, two thin rod antennas, jerry cans and a shovel strapped to the side panel, "
        "camouflage patches of olive and brown over grey-green paint. "
        "BATTLEFIELD: silhouettes of a ruined brick town far away, two thin smoke columns rising, "
        "overcast heavy grey sky, empty churned field rows."),
    "era3": ("era3·冷战反应装甲",
        "ARMOR LANGUAGE: a Cold War era armored command truck — slab-sided armored body with one horizontal "
        "row of rectangular reactive armor blocks along the flank, a roof rack carrying a small rotating "
        "radar dish and a dense radio antenna array, one boxy infrared searchlight beside the cab, "
        "olive-drab body with large sand-colored camouflage shapes, a small hitched trailer behind "
        "carrying a compact generator set under a tarpaulin. "
        "BATTLEFIELD: a desert outpost with low sandbag positions and one concrete bunker, "
        "clear hot pale-blue sky, flat sandy ground with tire track rows."),
    "era4": ("era4·近未来复合装甲",
        "ARMOR LANGUAGE: a near-future armored command truck — smooth angled composite armor panels, "
        "one roof rail carrying two small boxy drones locked in launch cradles, "
        "thin cyan light strips running along the body edges, "
        "every side panel fully closed and flush with clean panel seams, "
        "low-profile wide tires, digital camouflage of flat grey-green rectangles. "
        "BATTLEFIELD: a ruined concrete megacity skyline with broken window grids, "
        "hazy dust-free pale sky, an empty cracked plaza road."),
    "era5": ("era5·相位要塞半挂",
        "ARMOR LANGUAGE: a far-future phase-tech command land fortress on wheels — the vehicle is "
        "towering and very long, clearly much bigger than any ordinary truck: a forward armored cab "
        "plus a separate long semi-trailer command body roughly three times the cab length, "
        "connected by a visible fifth-wheel coupling gap, eight huge wheels on two rear axle groups. "
        "The huge armored body has folded angular roof panels that clearly hint they can unfold "
        "into a much larger structure, thin glowing cyan phase-energy lines tracing the hull edges, "
        "one tall slender communications mast above the cab, "
        "faint cyan glow leaking from vents along the lower hull. "
        "BATTLEFIELD: a quiet otherworldly wasteland with a few large floating rock shards in the distance "
        "and a pale fractured sky with a faint aurora band."),
    "era2_giant": ("era2变体·决战兵器超重卡车",
        "ARMOR LANGUAGE: a 1940s super-heavy 'wonder weapon' command truck — a giant boxy hull much "
        "larger than any standard truck of its time, clad in vertical faceted armor plates with heavy "
        "bolt heads, oversized road wheels with deep lug treads, twin stacks of spare wheels strapped "
        "to the hull sides, a small anti-aircraft ring mount with one slim gun barrel on the roof, "
        "a long whip antenna and a frame antenna over the cab, two-tone dark grey and "
        "sand paint. The whole vehicle reads as an experimental giant built to win the war in one blow. "
        "BATTLEFIELD: a vast armored proving ground with earth berms and a few wooden observation "
        "towers far away, overcast heavy sky."),
    "era3_giant": ("era3变体·冷战巨型陆地列车",
        "ARMOR LANGUAGE: a 1960s experimental giant overland command land train — a huge high-mounted "
        "command cab pulling two long separate multi-wheel trailer bodies, many small road wheels per "
        "axle group, the whole road train is extremely long and rides high above the ground on a "
        "ladder frame, one lattice antenna mast and a small round radar dome on the first trailer, "
        "olive-grey military paint with orange-black hazard stripes on the body corners. "
        "COMPOSITION EXCEPTION: the land train is far too long to fit in the frame — its rearmost "
        "trailer section runs out of the right edge of the image, only the front cab and first trailer "
        "are fully visible, which makes the length read even bigger. "
        "BATTLEFIELD: a vast snow-covered test range, low pale sun, distant sparse fence posts and one "
        "small radar station, clear freezing sky."),
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
        return os.path.exists(out) and os.path.getsize(out) > 5000
    b64 = (data.get("data") or [{}])[0].get("b64_json", "")
    if b64:
        import base64
        with open(out, "wb") as f:
            f.write(base64.b64decode(b64))
        return os.path.getsize(out) > 5000
    print("  无图像数据: %s" % json.dumps(data)[:160])
    return False


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("-")]
    if "--list" in sys.argv:
        for eid, (zh, _) in ERAS.items():
            print("%s  %s" % (eid, zh))
        return
    jobs = [("truck_%s.jpeg" % eid, P_SCENE + P_TRUCK + desc, zh) for eid, (zh, desc) in ERAS.items()]
    if args:
        want = {"truck_%s.jpeg" % a for a in args}
        jobs = [j for j in jobs if j[0] in want]
    keys = load_keys()
    os.makedirs(OUT_DIR, exist_ok=True)
    ok_n = 0
    for i, (fname, prompt, zh) in enumerate(jobs):
        out = os.path.join(OUT_DIR, fname)
        if os.path.exists(out) and os.path.getsize(out) > 5000 and not args:
            print("[%d/%d] %s 已存在，跳过" % (i + 1, len(jobs), zh))
            ok_n += 1
            continue
        key = keys[i % len(keys)]
        print("[%d/%d] %s ..." % (i + 1, len(jobs), zh), end="", flush=True)
        ok = call_api(prompt, key, out)
        print(" OK %dKB" % (os.path.getsize(out) // 1024) if ok and os.path.exists(out) else " FAIL")
        ok_n += 1 if ok else 0
        if i < len(jobs) - 1:
            time.sleep(3)
    print("完成 %d/%d" % (ok_n, len(jobs)))


if __name__ == "__main__":
    main()
