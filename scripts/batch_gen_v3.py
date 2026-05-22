# -*- coding: utf-8 -*-
"""
Phase War 资产批量生成脚本 v3
- 遇到 concurrency limit 时自动等待重试
- 支持 Ctrl+C 中断，下次运行自动跳过已存在文件
- 顺序执行，避免占用多个并发槽
"""
import subprocess, json, os, re, time, urllib.request, signal, sys

SCRIPT = r"F:\Program Files (x86)\WorkBuddy\resources\app\extensions\genie\out\extension\builtin\buddy-multimodal-generation\scripts\buddy-cloud.py"
TOKEN = "tk_0WnDqe2sNuuQvwYg78Lfu6vePXADe2r6"
BASE = r"F:\godot fair duel\phase-war"

INTERRUPTED = False

def signal_handler(sig, frame):
    global INTERRUPTED
    print("\n[USER] Interrupted! Will resume from last position on next run.", flush=True)
    INTERRUPTED = True

signal.signal(signal.SIGINT, signal_handler)

def win_path(p):
    m = re.match(r"/([a-z])/(.*)", p)
    if m:
        p = f"{m.group(1).upper()}:\\{m.group(2)}"
    return p.replace("/", "\\")

def run_buddy(prompt):
    cmd = [sys.executable, SCRIPT, "image", prompt,
           "--token", TOKEN, "--poll-interval", "8", "--max-poll-time", "600"]
    proc = subprocess.run(cmd, capture_output=True, encoding="utf-8", errors="replace")
    try:
        return json.loads(proc.stdout) if proc.stdout.strip() else {}
    except json.JSONDecodeError:
        return {"error": "PARSE_FAILED", "raw": proc.stdout[:500]}

def download(url, dest):
    dest_win = win_path(dest)
    os.makedirs(os.path.dirname(dest_win), exist_ok=True)
    for attempt in range(3):
        try:
            urllib.request.urlretrieve(url, dest_win)
            size = os.path.getsize(dest_win)
            print(f"  [OK] {os.path.basename(dest_win)} {size:,} B", flush=True)
            return True
        except Exception as e:
            print(f"  [WARN] DL attempt {attempt+1} failed: {e}", flush=True)
            if attempt < 2:
                time.sleep(3)
    return False

def gen_and_download(prompt, output_path, idx, total):
    basename = os.path.basename(win_path(output_path))
    win_out = win_path(output_path)
    if os.path.exists(win_out) and os.path.getsize(win_out) > 5000:
        print(f"[{idx}/{total}] [SKIP] {basename} (exists)", flush=True)
        return True

    print(f"[{idx}/{total}] [GEN] {basename} ...", flush=True)
    for attempt in range(1, 8):
        result = run_buddy(prompt)
        if "result_url" in result:
            url = result["result_url"]
            if isinstance(url, list):
                url = url[0]
            ok = download(url, output_path)
            if ok:
                return True
        # Check error type
        raw = result.get("raw_result", {})
        err = raw.get("error", "") if isinstance(raw, dict) else str(result)
        if "concurrent" in err.lower() or "limit" in err.lower():
            wait = attempt * 25
            print(f"  [RATE] Slot busy, waiting {wait}s (attempt {attempt}/7)...", flush=True)
            time.sleep(wait)
            continue
        if "上限" in str(result):
            wait = attempt * 20
            print(f"  [RATE] Limit hit, waiting {wait}s...", flush=True)
            time.sleep(wait)
            continue
        print(f"  [ERR] {json.dumps(result)[:200]}", flush=True)
        if attempt < 7:
            time.sleep(5)
    print(f"  [FAIL] {basename} - giving up after 7 attempts", flush=True)
    return False

TASKS = [
    # B. 卡牌边框
    ("common.png",    "f:/godot fair duel/phase-war/assets/cards/frames/common.png",
     "Flat design card frame border template, no fill, transparent background, subtle inner border line, color grey #BFBFBF, sharp clean edges, center empty for card art, 512x512 PNG"),
    ("uncommon.png",  "f:/godot fair duel/phase-war/assets/cards/frames/uncommon.png",
     "Flat design card frame border template, no fill, transparent background, subtle inner border line, color green #66E680, sharp clean edges, center empty for card art, 512x512 PNG"),
    ("rare.png",      "f:/godot fair duel/phase-war/assets/cards/frames/rare.png",
     "Flat design card frame border template, no fill, transparent background, subtle inner border line, color blue #66A6FF, sharp clean edges, center empty for card art, 512x512 PNG"),
    ("epic.png",      "f:/godot fair duel/phase-war/assets/cards/frames/epic.png",
     "Flat design card frame border template, no fill, transparent background, subtle glow effect, decorative corner accents, color purple #BF66FF, sharp clean edges, center empty for card art, 512x512 PNG"),
    ("legendary.png", "f:/godot fair duel/phase-war/assets/cards/frames/legendary.png",
     "Flat design card frame border template, no fill, transparent background, strong outer glow effect, ornate corner decorations, color gold #FFB34D, sharp clean edges, center empty for card art, 512x512 PNG"),
    # A. 卡牌图标
    ("guard.png",        "f:/godot fair duel/phase-war/assets/card_icons/guard.png",
     "Isometric side-view card icon, transparent PNG, sci-fi armored reconnaissance vehicle, steel grey color scheme, mechanical details, compact armored car design, centered with 10% safe margin, 512x512"),
    ("titan.png",        "f:/godot fair duel/phase-war/assets/card_icons/titan.png",
     "Isometric side-view card icon, transparent PNG, heavy main battle unit, giant tank silhouette, dark gunmetal color scheme, imposing high-health armored vehicle, centered with 10% safe margin, 512x512"),
    ("fortress.png",     "f:/godot fair duel/phase-war/assets/card_icons/fortress.png",
     "Isometric side-view card icon, transparent PNG, defensive fortress unit, static fortification with multiple turrets, fortified bunker design, steel grey and concrete colors, centered with 10% safe margin, 512x512"),
    ("radar.png",        "f:/godot fair duel/phase-war/assets/card_icons/radar.png",
     "Isometric side-view card icon, transparent PNG, detection and buff support unit, radar dish on vehicle chassis, scanner and antenna equipment, blue-tinted tech aesthetic, centered with 10% safe margin, 512x512"),
    ("scout.png",        "f:/godot fair duel/phase-war/assets/card_icons/scout.png",
     "Isometric side-view card icon, transparent PNG, light reconnaissance unit, fast scouting vehicle, aerodynamic streamlined body, olive drab and tan color, centered with 10% safe margin, 512x512"),
    ("raider.png",       "f:/godot fair duel/phase-war/assets/card_icons/raider.png",
     "Isometric side-view card icon, transparent PNG, fast assault unit, rapid breakthrough tank, wedge-shaped aggressive profile, dark olive and rust color, centered with 10% safe margin, 512x512"),
    ("siege.png",        "f:/godot fair duel/phase-war/assets/card_icons/siege.png",
     "Isometric side-view card icon, transparent PNG, long-range heavy fire siege unit, massive artillery gun platform, heavy tracked chassis, olive drab and gunmetal grey, centered with 10% safe margin, 512x512"),
    ("carrier.png",      "f:/godot fair duel/phase-war/assets/card_icons/carrier.png",
     "Isometric side-view card icon, transparent PNG, high-cost core carrier unit, large aircraft carrier style platform, multiple deck levels, steel grey with accent markings, centered with 10% safe margin, 512x512"),
    ("medic.png",        "f:/godot fair duel/phase-war/assets/card_icons/medic.png",
     "Isometric side-view card icon, transparent PNG, repair support unit, field maintenance vehicle, medical cross markings, green and white color scheme, centered with 10% safe margin, 512x512"),
    ("stealth.png",      "f:/godot fair duel/phase-war/assets/card_icons/stealth.png",
     "Isometric side-view card icon, transparent PNG, stealth infiltration unit, angular stealth vehicle silhouette, dark matte black with subtle purple highlights, low profile design, centered with 10% safe margin, 512x512"),
    ("omega_platform.png","f:/godot fair duel/phase-war/assets/card_icons/omega_platform.png",
     "Isometric side-view card icon, transparent PNG, ultimate ace unit, heavy multi-slot gundam-style humanoid mech, gold and dark grey color scheme, imposing powerful presence, centered with 10% safe margin, 512x512"),
    # C. 功能UI图标
    ("icon_shop.png",       "f:/godot fair duel/phase-war/assets/ui/icons/icon_shop.png",
     "UI icon for shop button, single color flat design, store building with awning icon, white on transparent background, 256x256 PNG"),
    ("icon_quest.png",      "f:/godot fair duel/phase-war/assets/ui/icons/icon_quest.png",
     "UI icon for quest button, single color flat design, scroll or scroll with exclamation mark, white on transparent background, 256x256 PNG"),
    ("icon_leaderboard.png","f:/godot fair duel/phase-war/assets/ui/icons/icon_leaderboard.png",
     "UI icon for leaderboard button, single color flat design, podium with ranks 1-2-3 icon, white on transparent background, 256x256 PNG"),
    ("icon_settings.png",  "f:/godot fair duel/phase-war/assets/ui/icons/icon_settings.png",
     "UI icon for settings button, single color flat design, gear cog wheel icon, white on transparent background, 256x256 PNG"),
    ("icon_help.png",       "f:/godot fair duel/phase-war/assets/ui/icons/icon_help.png",
     "UI icon for help button, single color flat design, question mark inside circle icon, white on transparent background, 256x256 PNG"),
    ("icon_close.png",      "f:/godot fair duel/phase-war/assets/ui/icons/icon_close.png",
     "UI icon for close button, single color flat design, bold X cross mark icon, white on transparent background, 256x256 PNG"),
    ("icon_arrow_right.png","f:/godot fair duel/phase-war/assets/ui/icons/icon_arrow_right.png",
     "UI icon for right arrow, single color flat design, right-pointing chevron arrow icon, white on transparent background, 256x256 PNG"),
    ("icon_filter.png",     "f:/godot fair duel/phase-war/assets/ui/icons/icon_filter.png",
     "UI icon for filter button, single color flat design, funnel or filter icon, white on transparent background, 256x256 PNG"),
    ("icon_sort.png",       "f:/godot fair duel/phase-war/assets/ui/icons/icon_sort.png",
     "UI icon for sort button, single color flat design, three horizontal lines with up-down arrows or sort indicator icon, white on transparent background, 256x256 PNG"),
    # D. 势力Logo 32px
    ("iron_wall_corp_32.png",    "f:/godot fair duel/phase-war/assets/ui/factions/iron_wall_corp_32.png",
     "Minimal faction logo, shield with brick wall pattern, steel grey and dark blue, clean icon design, 32x32 PNG"),
    ("nova_arms_32.png",         "f:/godot fair duel/phase-war/assets/ui/factions/nova_arms_32.png",
     "Minimal faction logo, crossed guns with flame burst, orange and dark red, clean icon design, 32x32 PNG"),
    ("aether_dynamics_32.png",   "f:/godot fair duel/phase-war/assets/ui/factions/aether_dynamics_32.png",
     "Minimal faction logo, rocket engine with phase trail, cyan and purple, clean icon design, 32x32 PNG"),
    ("quantum_logistics_32.png",  "f:/godot fair duel/phase-war/assets/ui/factions/quantum_logistics_32.png",
     "Minimal faction logo, box package with data stream, green and teal, clean icon design, 32x32 PNG"),
    ("helix_recon_32.png",       "f:/godot fair duel/phase-war/assets/ui/factions/helix_recon_32.png",
     "Minimal faction logo, double helix spiral with radar sweep, purple and blue, clean icon design, 32x32 PNG"),
    ("void_research_32.png",     "f:/godot fair duel/phase-war/assets/ui/factions/void_research_32.png",
     "Minimal faction logo, eye with void crack portal, dark purple and black, clean icon design, 32x32 PNG"),
    ("frontier_union_32.png",    "f:/godot fair duel/phase-war/assets/ui/factions/frontier_union_32.png",
     "Minimal faction logo, multiple arrows converging with star, gold and bronze, clean icon design, 32x32 PNG"),
    # D. 势力Logo 128px
    ("iron_wall_corp_128.png",   "f:/godot fair duel/phase-war/assets/ui/factions/iron_wall_corp_128.png",
     "Detailed faction logo, shield with brick wall pattern and steel texture, steel grey and dark blue with metallic sheen, 128x128 PNG"),
    ("nova_arms_128.png",        "f:/godot fair duel/phase-war/assets/ui/factions/nova_arms_128.png",
     "Detailed faction logo, crossed guns with flame burst and sparks, orange and dark red with fire glow, 128x128 PNG"),
    ("aether_dynamics_128.png",  "f:/godot fair duel/phase-war/assets/ui/factions/aether_dynamics_128.png",
     "Detailed faction logo, rocket engine with phase distortion trail and speed lines, cyan and purple with glow, 128x128 PNG"),
    ("quantum_logistics_128.png","f:/godot fair duel/phase-war/assets/ui/factions/quantum_logistics_128.png",
     "Detailed faction logo, holographic package box with data stream particles, green and teal with digital effect, 128x128 PNG"),
    ("helix_recon_128.png",      "f:/godot fair duel/phase-war/assets/ui/factions/helix_recon_128.png",
     "Detailed faction logo, double helix DNA spiral with radar pulse rings, purple and electric blue, 128x128 PNG"),
    ("void_research_128.png",    "f:/godot fair duel/phase-war/assets/ui/factions/void_research_128.png",
     "Detailed faction logo, all-seeing eye with void rift portal and crack tendrils, dark purple and black with cosmic effect, 128x128 PNG"),
    ("frontier_union_128.png",   "f:/godot fair duel/phase-war/assets/ui/factions/frontier_union_128.png",
     "Detailed faction logo, multiple directional arrows converging at center star, gold and copper with metallic sheen, 128x128 PNG"),
    # E. 星级图标
    ("star_1.png", "f:/godot fair duel/phase-war/assets/ui/stars/star_1.png",
     "Single star icon, one filled star, golden yellow #FFD700, clean flat design, white background, 128x128 PNG"),
    ("star_2.png", "f:/godot fair duel/phase-war/assets/ui/stars/star_2.png",
     "Star rating icon, two filled stars side by side, golden yellow #FFD700, clean flat design, white background, 128x128 PNG"),
    ("star_3.png", "f:/godot fair duel/phase-war/assets/ui/stars/star_3.png",
     "Star rating icon, three filled stars in a row, golden yellow #FFD700, clean flat design, white background, 128x128 PNG"),
    ("star_4.png", "f:/godot fair duel/phase-war/assets/ui/stars/star_4.png",
     "Star rating icon, four filled stars in a row, golden yellow #FFD700, clean flat design, white background, 128x128 PNG"),
    ("star_5.png", "f:/godot fair duel/phase-war/assets/ui/stars/star_5.png",
     "Star rating icon, five filled stars in a row, golden yellow #FFD700, clean flat design, white background, 128x128 PNG"),
    ("star_6.png", "f:/godot fair duel/phase-war/assets/ui/stars/star_6.png",
     "Star rating icon, six filled stars in a row, golden yellow #FFD700, clean flat design, white background, 128x128 PNG"),
    ("star_7.png", "f:/godot fair duel/phase-war/assets/ui/stars/star_7.png",
     "Star rating icon, seven filled stars in a row, golden yellow #FFD700, clean flat design, white background, 128x128 PNG"),
]

print(f"Total tasks: {len(TASKS)}", flush=True)
success = 0
failed = []
for i, (fname, out_path, prompt) in enumerate(TASKS, 1):
    if INTERRUPTED:
        print(f"\n[STOP] Interrupted at task {i}. Run again to resume.", flush=True)
        break
    ok = gen_and_download(prompt, out_path, i, len(TASKS))
    if ok:
        success += 1
    else:
        failed.append((fname, out_path, prompt))

print(f"\n=== DONE: {success}/{len(TASKS)} successful ===", flush=True)
if failed:
    print("FAILED TASKS:", flush=True)
    for f, p, _ in failed:
        print(f"  - {f}", flush=True)
