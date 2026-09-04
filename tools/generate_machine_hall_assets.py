# -*- coding: utf-8 -*-
"""generate_machine_hall_assets.py —— 机枢大厅（Machine Hall）资产批量生成（agnes-image-2.1-flash）

设计稿：docs/基地重设计/基地方案_机枢大厅.md（用户定调版：一间房 + 残破机器可修 + 面板三档皮肤）
输出：docs/基地重设计/generated_mh/  共 22 张
  mh_hall_bg.jpeg                大厅底图（整幅不透明）
  mh_<id>_wreck.jpeg / _active   9 台机器两态（白底精灵）
  mh_panel_t1_whiteboard / t2_crt / t3_holo   面板三档皮肤（白底精灵）

agnes 行为铁律（tools/_agnes_image_api.md 实测）：
  负面词只留结构性排除；正面意象锁死；风格词禁 gritty/somber/dusty；屏幕只画抽象图形。

用法：
  python tools/generate_machine_hall_assets.py              # 全部 22 张
  python tools/generate_machine_hall_assets.py generator radio  # 指定机器（自动含两态）
  python tools/generate_machine_hall_assets.py --list
"""
import json, os, re, subprocess, sys, time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KEY_MD = os.path.join(ROOT, "tools", "_agnes_image_api.md")
OUT_DIR = os.path.join(ROOT, "docs", "基地重设计", "generated_mh")
BASE_URL = "https://apihub.agnes-ai.cn/v1"
MODEL = "agnes-image-2.1-flash"
SIZE = "1152x768"

# ── 机器精灵通用前缀（白底单体道具；风格词按实测规避 dusty/gritty/somber）──
P_MACHINE = (
    "2D game asset, hand-painted stylized game art, "
    "muted palette of dark grey-brown and olive green, "
    "strictly side view, flat orthographic projection, "
    "ONE single machine as the whole subject, centered, "
    "the machine stands directly on an implied single ground line at the very bottom edge, "
    "the entire surroundings are pure solid white on all four sides, "
    "no text, no watermark, crisp sharp edges, high detail density. "
)
# 两态通用段（正面意象锁死；残破态禁用 dust 类词，破败感全靠锈/凹痕/断线/蒙布）
P_WRECK = (
    "STATE WRECKED: the machine is broken-down and long abandoned, every indicator light is dark, "
    "patches of orange rust and dents on the metal shell, one torn canvas tarp draped loosely over "
    "part of the machine, a few cut cables hanging limp, motionless and dead. "
)
P_ACTIVE = (
    "STATE RESTORED AND RUNNING: the machine is repaired and working, small indicator lights glowing "
    "warm amber and cold cyan, metal surfaces wiped clean, cables neatly tied, one small warm halo of "
    "light around each lamp, the machine feels quietly alive. "
)
# 结构性负面词（内容词一律走正面锁死，勿加）
P_NEGA = (
    "text, watermark, signature, frame, border, extra background scenery, "
    "perspective view, background room, floor texture"
)

# 机器表：id → (中文名, 构图提示, 残破态主体, 运转态主体)
MACHINES = {
    "generator": (
        "发电机", "bulky and boxy, roughly as wide as tall",
        "an old industrial diesel generator set: big riveted metal housing, cylinder block, exhaust pipe bent sideways, wheels and skid base",
        "the same generator set restored: exhaust pipe straightened, control panel with round gauges and toggle switches, three small amber lamps lit on the lid",
    ),
    "war_table": (
        "沙盘台", "wide and low",
        "a military command sand table: long flat table with a dark cracked sand-map surface with faded grid lines, four sturdy legs, one corner of the tabletop sagging",
        "the same command sand table restored: the dark sand-map surface now overlaid by a faint glowing cyan holographic grid of abstract flat tactical symbols hovering just above the table",
    ),
    "lab_bench": (
        "实验台", "wide and low",
        "an electronics laboratory bench: long workbench with a dead dark oscilloscope box, scattered bare circuit boards, a cold soldering iron on a stand",
        "the same laboratory bench restored: oscilloscope screen glowing with one simple abstract cyan waveform line, circuit boards stacked in neat trays, small lamp lit over the bench",
    ),
    "analyzer": (
        "分析仪", "tall and narrow",
        "a tall specimen analyzer cabinet: vertical metal cabinet with rows of empty dark rectangular slots like a card catalogue, one door hanging open showing empty racks inside",
        "the same analyzer cabinet restored: rows of dark card slots with four slots glowing soft cyan from within, a thin horizontal scanning light strip crossing the front, small readout panel with flat green symbols",
    ),
    "radio": (
        "电台", "tall and narrow",
        "a military radio rack: tall rack cabinet with dark dead dials, blank meter faces, a dangling handset cord, one side panel missing showing hollow frame inside",
        "the same radio rack restored: dial faces faintly backlit amber, five small indicator dots glowing amber and cyan in a column, handset resting on its hook, a thin antenna wire running up",
    ),
    "rest_pod": (
        "充能舱", "compact, slightly taller than wide",
        "a one-person sleeping pod: metal capsule bunk with a torn thin mattress hanging out, blanket crumpled on the floor line, small dead reading lamp arm",
        "the same sleeping pod restored: mattress neatly made with a folded grey blanket, small warm amber reading lamp glowing on the arm, a faint soft charge light strip along the pod rim",
    ),
    "workbench": (
        "工作台", "wide and low",
        "a mechanic workbench: heavy wooden-metal bench with a rusted vise locked shut, pegboard behind with empty hook outlines and one missing board corner, dark dead lamp overhead",
        "the same workbench restored: vise cleaned with faint tool outline painted on the pegboard around each hanging tool, warm lamp glowing over the bench, oil can and rag neatly placed",
    ),
    "galley": (
        "炊事机", "medium and boxy with one chimney pipe",
        "a field kitchen machine: boxy coal stove with a bent chimney pipe, cold black cooking pot on top, ash tray pulled out, fire door ajar showing cold dark interior",
        "the same field kitchen restored: chimney straightened, pot steaming gently with one curl of white steam, warm orange glow visible through the fire door grate, kettle beside the pot",
    ),
    "printer": (
        "打印机", "medium and boxy, roughly as wide as tall",
        "a card printer machine: boxy device with a glass-front forming chamber standing empty and dark, filament spool holders bare, output tray detached and leaning against the side",
        "the same card printer restored: the glass forming chamber glowing soft cyan with one plain blank card shape suspended mid-print inside (a simple flat rectangle, no picture on it), silver filament spool mounted, output tray reattached",
    ),
}

# 面板三档皮肤（白底单体道具）
PANELS = {
    "panel_t1_whiteboard": (
        "面板T1·白板",
        "a worn planning whiteboard standing on a wooden easel frame: white board surface with faint ghost marks of wiped-off abstract marker squiggles, six plain blank paper note sheets held by simple round magnets in a loose grid, one marker resting on the tray ledge, the notes are completely blank sheets of paper",
    ),
    "panel_t2_crt": (
        "面板T2·显示器",
        "a beige metal operations console: cabinet stand holding three boxy CRT monitors stacked in a row, each screen showing ONLY simple abstract glowing patterns (one plain green waveform line, one flat amber bar readout, one grid of dim dots), a wide keyboard shelf below, small status LEDs on the bezels",
    ),
    "panel_t3_holo": (
        "面板T3·投影",
        "a holographic projector pedestal: dark metal base column with a glowing projection lens on top, one translucent cyan hologram panel floating above it showing ONLY abstract flat diagrams (simple rectangles, thin connecting lines and small dots), faint light cone and drifting glowing particles around the panel, the hologram is translucent and slightly transparent",
    ),
}

# 大厅底图（整幅不透明；空房间=一切可移除物已搬走的正面锁死）
HALL_BG = (
    "2D game background art, hand-painted stylized game art, "
    "muted palette of dark grey-brown and olive green, "
    "a wide industrial workshop hall interior seen straight-on from the front, flat orthographic view. "
    "The hall is completely empty: every loose object has been carried away, only fixed structures remain — "
    "a back wall of riveted dark metal panels with horizontal wall pipes and cable trays running along it, "
    "one tall steel shelving rack standing empty on the left wall, "
    "a raised concrete loading platform along the back wall reached by two short steps, "
    "one sealed round blast door set into the back wall on the right side, "
    "the floor is one open continuous expanse of worn smooth concrete with a few dark cable channels "
    "running from the walls to six empty machine anchor points, the floor is completely clear and "
    "empty from wall to wall, "
    "dim cold ambient lighting with one faint warm pool of light from a single hanging work lamp in the center, "
    "no text, no watermark."
)

# 底图候选变体（2026-09-03 用户反馈"房间不好"——四取向并行出图，网页切换对比）
_HALL_CORE = (
    "2D game background art, hand-painted stylized game art, "
    "muted palette of dark grey-brown and olive green, "
    "a wide machine hall interior seen straight-on from the front, flat orthographic view. "
    "The hall is completely empty: every machine and every loose object has been carried away, "
    "only fixed structures remain. "
    "Back wall: riveted metal panels with horizontal wall pipes and cable trays, "
    "and one long horizontal strip of thirty small round brass lamps mounted on the wall, "
    "exactly five of the lamps warmly lit and the other twenty-five dark. "
    "One sealed round blast door set into the back wall on the right side. "
    "The concrete floor has six worn rectangular steel anchor plates with bolt holes "
    "where the machines used to stand, and dark cable channels running from the walls to the plates, "
    "the floor is otherwise completely clear from wall to wall. "
    "no text, no watermark. "
)
HALL_VARIANTS = {
    "bg_a": ("大厅A·亮版平层",
        _HALL_CORE + "Lighting: bright even warm daylight falling from three high industrial windows on the left wall, "
        "the whole hall is clearly lit and readable, warm ochre tones. Layout: one single flat ground level, no platform, no steps."),
    "bg_b": ("大厅B·高台版",
        _HALL_CORE + "Layout: a raised concrete platform along the back wall reached by two short steps. "
        "Lighting: dim cold ambient with one warm pool of light from a single hanging work lamp in the center."),
    "bg_c": ("大厅C·掩体拱厅",
        _HALL_CORE + "Layout: an underground bunker hall with a curved arched ceiling ribbed with steel supports, "
        "denser pipe clusters along the top of the walls, a lower and more compact room height. "
        "Lighting: two rows of small amber work lamps along both walls, warm dim overall."),
    "bg_d": ("大厅D·破顶月厂房",
        _HALL_CORE + "Layout: a tall factory hall whose roof is partly collapsed open, "
        "the broken roof opening shows a dark night sky with faint stars, "
        "one pale diagonal shaft of moonlight falling across the empty floor. "
        "Lighting: cool moonlight contrast with warm glow from the five lit wall lamps."),
}


def load_keys():
    src = open(KEY_MD, "r", encoding="utf-8").read()
    keys = re.findall(r"sk-[A-Za-z0-9]{20,}", src)
    if not keys:
        raise SystemExit("tools/_agnes_image_api.md 里找不到 key")
    return keys


def call_api(prompt, key, out):
    # 纯 urllib（HTTP/1.1）——规避 curl 子进程在中文/空格路径下的 ANSI 编码静默失败
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


def build_jobs():
    """[(文件名, prompt, 中文标签)]，顺序：底图 → 机器两态 → 面板皮肤"""
    jobs = [("mh_hall_bg.jpeg", HALL_BG, "大厅底图")]
    for mid, (zh, shape, wreck, active) in MACHINES.items():
        base = P_MACHINE + "Composition: %s. Subject: %s. " % (shape, wreck)
        jobs.append(("mh_%s_wreck.jpeg" % mid,
                     base + P_WRECK + "Avoid: " + P_NEGA, zh + "·残破"))
        base2 = P_MACHINE + "Composition: %s. Subject: %s. " % (shape, active)
        jobs.append(("mh_%s_active.jpeg" % mid,
                     base2 + P_ACTIVE + "Avoid: " + P_NEGA, zh + "·运转"))
    for pid, (zh, desc) in PANELS.items():
        jobs.append(("mh_%s.jpeg" % pid,
                     P_MACHINE + "Subject: " + desc + " Avoid: " + P_NEGA, zh))
    for vid, (zh, prompt) in HALL_VARIANTS.items():
        jobs.append(("mh_hall_%s.jpeg" % vid, prompt, zh))
    return jobs


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("-")]
    if "--list" in sys.argv:
        for mid, (zh, _, _, _) in MACHINES.items():
            print("%s  %s（两态）" % (mid, zh))
        for pid, (zh, _) in PANELS.items():
            print("%s  %s" % (pid, zh))
        print("hall_bg  大厅底图（原版）")
        for vid, (zh, _) in HALL_VARIANTS.items():
            print("%s  %s" % (vid, zh))
        return
    jobs = build_jobs()
    if args:
        want = set()
        for a in args:
            if a == "hall_bg":
                want.add("mh_hall_bg.jpeg")
            elif a in HALL_VARIANTS:
                want.add("mh_hall_%s.jpeg" % a)
            elif a in MACHINES:
                want.add("mh_%s_wreck.jpeg" % a)
                want.add("mh_%s_active.jpeg" % a)
            elif a in PANELS:
                want.add("mh_%s.jpeg" % a)
            else:
                raise SystemExit("未知目标: %s（--list 查看全部）" % a)
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
        print("[%d/%d] %s ..." % (i + 1, len(jobs), zh), end=" ", flush=True)
        ok = call_api(prompt, key, out)
        print("OK %dKB" % (os.path.getsize(out) // 1024) if ok and os.path.exists(out) else "FAIL")
        ok_n += 1 if ok else 0
        if i < len(jobs) - 1:
            time.sleep(3)
    print("完成 %d/%d" % (ok_n, len(jobs)))


if __name__ == "__main__":
    main()
