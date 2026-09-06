# -*- coding: utf-8 -*-
"""generate_truck_interiors.py —— 装甲卡车基地·五时代货厢剖面（内景定调图系列）

设计稿：docs/基地重设计/基地方案_空间概念选型.md §六 + 会话记录 2026-09-04
用户分编（2026-09-04 口径）：
  单独图/Gravity_well_..._1734.jpeg（现代军卡内景剖面）→ 降编为 era4「现代」档（还好，够用）；
  era5「未来」需重新生成且内景复杂度全面加码；现代设计水准 → 冷战张；冷战设计水准 → 二战张。
输出：docs/基地重设计/generated_truck_interior/interior_era{1,2,3,5}.jpeg（era4=1734 本体，脚本外 cp）
构图契约：与五时代外景同语法——严格侧视、车头朝左、整车入画、停在战线边缘土路；
  本系列叠加：货厢侧板剖开如模型剖面，一条长内景从驾驶舱到尾门。

agnes 行为铁律（tools/_agnes_image_api.md 实测）：
  负面词只留结构性排除（text/perspective/ceiling）；正面意象锁死（复杂度=枚举物件清单）；
  风格词禁 gritty/somber/dusty；屏幕只画抽象图形（era5 无全息地图为用户既定口径）。

用法：
  python tools/generate_truck_interiors.py            # 全部 4 张（已存在跳过）
  python tools/generate_truck_interiors.py era5       # 单独重roll（先删对应 jpeg）
  python tools/generate_truck_interiors.py --size 1152x768
"""
import json, os, re, sys, time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KEY_MD = os.path.join(ROOT, "tools", "_agnes_image_api.md")
OUT_DIR = os.path.join(ROOT, "docs", "基地重设计", "generated_truck_interior")
BASE_URL = "https://apihub.agnes-ai.cn/v1"
MODEL = "agnes-image-2.1-flash"
SIZE = "1376x768"  # 与 1734 主图同规格；API 不认则降 1152x768（--size 覆盖）

# ── 共享骨架：构图契约 + 内景复杂度总纲（四张一致）──
P_SCENE = (
    "2D game concept art, hand-painted stylized game art, "
    "muted palette of dark grey-brown and olive green with small cyan accent lights, "
    "strictly side view of the whole vehicle facing left, flat orthographic side elevation, "
    "the complete vehicle fits fully inside the frame with clear space above its roof, "
    "the outer wall of the tall rectangular command body is cut away open like a dollhouse cross-section, "
    "fully revealing the furnished interior compartments in one long row from driver cab to tailgate, "
    "the interior is unusually rich and densely packed with believable working equipment — "
    "every compartment is full: desks, instrument racks, wall-mounted tools, cable runs, storage crates and beds, "
    "a real lived-in working military home on wheels, very high detail density on the vehicle and interior, "
    "the truck is parked on a straight dirt road at the forward edge of a battlefield, "
    "the battlefield scenery behind stays low, simple and quiet so the truck is clearly the hero, "
    "soft dusk light, crisp shapes. "
    "Flat side view only, no perspective corridor view, no open ceiling view, no text, no watermark. "
)
P_CAB = (
    "VEHICLE: a military command truck — a forward engine cab with a visible driver seat inside, "
    "plus a tall rectangular command body built onto the rear frame, "
    "a small step ladder under the body side door, a fold-down ramp at the rear tailgate. "
)

# ── 四时代：装甲语言 + 内景物件清单（复杂度阶梯：era1 最朴 < era2 < era3 < era5 最密）──
ERAS = {
    "era5": ("era5·相位要塞半挂（重生成·最复杂）",
        "ARMOR LANGUAGE: a far-future phase-tech command land fortress on wheels — towering and very long, "
        "a forward armored cab plus a separate long semi-trailer command body roughly three times the cab length, "
        "connected by a visible fifth-wheel coupling gap, eight huge wheels on two rear axle groups, "
        "both cab and semi-trailer cut away dollhouse-style to show interiors, "
        "thin glowing cyan phase-energy lines tracing the hull edges, one tall slender communications mast above the cab. "
        "INTERIOR (the richest of this series, far denser than any ordinary command truck): five or six distinct "
        "compartments in a row — "
        "a command bay with a large sand-table terrain model and many small screens showing only simple abstract "
        "glowing symbols and flat color readouts, "
        "a phase-crystal power core chamber with glowing cyan crystal conduits running along the ceiling "
        "branching into every compartment, "
        "a fabrication bay with a large additive manufacturing printer and robotic tool arms, "
        "a laboratory bench with sample racks and flat abstract readout panels, "
        "a galley bay with a food converter machine and a tall stocked vending wall, "
        "a sleep corner with exactly one single capsule bunk — only one bed in the whole vehicle, "
        "the commander's private berth, "
        "walls of storage crates, dense cable trays and pipes running everywhere, cyan strip lights. "
        "BATTLEFIELD: a quiet otherworldly wasteland with a few large floating rock shards in the distance "
        "and a pale fractured sky with a faint aurora band."),
    "era3": ("era3·冷战移动指挥中心",
        "ARMOR LANGUAGE: a Cold War era armored command truck — slab-sided armored body with one horizontal row of "
        "rectangular reactive armor blocks along the flank, a roof rack with a small rotating radar dish and a dense "
        "radio antenna array, olive-drab body with large sand-colored camouflage shapes. "
        "INTERIOR (a 1960s mobile command center, dense and functional): "
        "a console wall of CRT monitors glowing with simple abstract green readouts and plain flat graphic symbols, "
        "reel-to-reel tape recorders and analog dial instrument panels with toggle switches and warning lamps, "
        "a big horizontal map board with magnetic markers and a rotary telephone switchboard, "
        "a vintage vending machine stocked with boxed rations, a compact galley unit with a kettle and food warmer, "
        "one single metal bunk frame with a folded wool blanket — only one bed in the vehicle, "
        "a diesel generator compartment with thick cable trays, "
        "a wall-mounted oscilloscope showing one simple green waveform, fluorescent tube lights, "
        "dense cable runs along the ceiling. "
        "BATTLEFIELD: a desert outpost with low sandbag positions and one concrete bunker, "
        "clear hot pale-blue sky, flat sandy ground with tire track rows."),
    "era2": ("era2·二战装甲指挥厢",
        "ARMOR LANGUAGE: a World War Two era armored command truck — fully enclosed welded steel armored box body "
        "with visible weld seams and bolt heads, angular armored cab with tiny protected vision slots, "
        "two thin rod antennas, jerry cans and a shovel strapped to the side panel, "
        "camouflage patches of olive and brown over grey-green paint. "
        "INTERIOR (a 1940s mobile command post, packed and busy): "
        "a bank of glowing vacuum-tube radio transmitters with round frequency dials and needle gauges, "
        "a mechanical code machine with a keyboard and rotors, a wooden map table with rulers, dividers and a green "
        "banker's lamp, a large paper situation map pinned with wooden markers on a cork board, "
        "a wall of metal lockers and stenciled supply crates, one single folding canvas cot — "
        "only one bed in the vehicle, "
        "a compact field stove with mess tins, a wall-mounted toolbox with wrenches, coiled black cables everywhere, "
        "a brass periscope through the roof, warm tungsten bulbs in cage lamps. "
        "BATTLEFIELD: silhouettes of a ruined brick town far away, two thin smoke columns rising, "
        "overcast heavy grey sky, empty churned field rows."),
    "era1": ("era1·一战野战指挥 wagon",
        "ARMOR LANGUAGE: a World War One era military truck — simple steel rims with solid rubber tires, "
        "wooden plank cargo bed with the canvas canopy rolled up on the visible side exposing the wooden interior, "
        "crude riveted iron plates bolted onto the cab front, a tall thin wire antenna mast, "
        "two round kerosene-style headlamps, olive-green paint worn pale at the edges. "
        "INTERIOR (a 1910s field command wagon, dense but primitive): "
        "rough wooden plank walls and floor, a wooden map table with paper maps pinned to the wall, "
        "a candle lantern and an oil lamp, a wooden field telephone switchboard box with fabric-wrapped cables, "
        "a brass Morse telegraph key on a small writing desk with a wooden stool, "
        "a folding canvas camp cot with a rolled blanket, a small pot-belly iron stove with a chimney pipe "
        "through the roof, wooden ammunition crates used as shelves with tinned food and jerry cans, "
        "a rifle rack, hand tools hanging on nails, a hanging greatcoat, everything lit warm by lamplight. "
        "BATTLEFIELD: distant trench lines with wooden stakes and barbed wire posts, bare leafless trees, "
        "pale hazy morning sky, low rolling empty ground."),
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
            print("  无图像数据: %s" % json.dumps(data)[:160])
            return False
        import base64
        with open(out, "wb") as f:
            f.write(base64.b64decode(b64))
    try:
        from PIL import Image
        w, h = Image.open(out).size
        print(" [%dx%d]" % (w, h), end="")
        if SIZE and (w, h) != tuple(int(x) for x in SIZE.split("x")):
            print("(与请求不符!)", end="")
    except Exception:
        pass
    return os.path.exists(out) and os.path.getsize(out) > 5000


def main():
    global SIZE
    argv = sys.argv[1:]
    if "--size" in argv:
        i = argv.index("--size")
        SIZE = argv[i + 1]
        argv = argv[:i] + argv[i + 2:]
    if "--list" in argv:
        for eid, (zh, _) in ERAS.items():
            print("%s  %s" % (eid, zh))
        return
    jobs = [("interior_%s.jpeg" % eid, P_SCENE + P_CAB + desc, zh) for eid, (zh, desc) in ERAS.items()]
    if argv:
        want = {"interior_%s.jpeg" % a for a in argv}
        jobs = [j for j in jobs if j[0] in want]
    keys = load_keys()
    os.makedirs(OUT_DIR, exist_ok=True)
    ok_n = 0
    for i, (fname, prompt, zh) in enumerate(jobs):
        out = os.path.join(OUT_DIR, fname)
        if os.path.exists(out) and os.path.getsize(out) > 5000:
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
