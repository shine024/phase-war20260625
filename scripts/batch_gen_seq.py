# -*- coding: utf-8 -*-
"""
Batch image generation - runs SEQUENTIALLY to respect API rate limit.
All logging goes to stdout (not stderr, so batch process can see output).
Usage: python batch_gen_seq.py
"""
import subprocess
import sys
import os
import time
import json
import re
import urllib.request
import urllib.error

SCRIPT = os.path.join(os.path.dirname(__file__), "gen_image.py")
TOKEN = "tk_0WnDqe2sNuuQvwYg78Lfu6vePXADe2r6"

# All generation tasks
TASKS = [
    # === A. Card Icons ===
    ("guard",   "assets/card_icons/guard.png",
     "Top-down view of a medium armored guard unit for a card game. Low-profile tank with thick frontal armor plates, dual side shields, heavy barrel turret, dark olive green and gunmetal. Dark space bg, transparent, unit centered, 10%% margin. No text. High detail, sharp edges, sci-fi military style."),
    ("titan",   "assets/card_icons/titan.png",
     "Top-down view of a massive heavy titan unit for a card game. Hulking bipedal war machine, heavy armor plating, dual shoulder cannons, glowing orange reactor core on chest, dark gunmetal with orange heat vents. Dark space bg, transparent, unit centered, 10%% margin. No text. High detail, sharp edges, sci-fi war machine style."),
    ("fortress","assets/card_icons/fortress.png",
     "Top-down view of a fortress defense platform for a card game. Large hexagonal stationary base with turret emplacements at each corner, radar dish on top, reinforced thick walls, dark steel gray with amber warning lights. Dark space bg, transparent, unit centered, 10%% margin. No text. High detail, sharp edges, sci-fi fortification style."),
    ("radar",   "assets/card_icons/radar.png",
     "Top-down view of a radar and support unit for a card game. Compact hovering sensor platform with large rotating radar antenna, multiple receiver dishes, scanning energy beam sweeping, dark gunmetal with bright green holographic elements. Dark space bg, transparent, unit centered, 10%% margin. No text. High detail, sharp edges, sci-fi electronics style."),
    ("scout",   "assets/card_icons/scout.png",
     "Top-down view of a light reconnaissance scout unit for a card game. Ultra-lightweight fast-moving hovercraft, minimal armor, twin forward sensor pods, glowing yellow lights, silver and dark gray. Dark space bg, transparent, unit centered, 10%% margin. No text. High detail, sharp edges, sci-fi scout style."),
    ("raider",  "assets/card_icons/raider.png",
     "Top-down view of a raider assault unit for a card game. Fast attack hovercraft with sharp angular nose, dual forward cannons, swept-back wings, red accent stripes, dark crimson and black. Dark space bg, transparent, unit centered, 10%% margin. No text. High detail, sharp edges, sci-fi assault style."),
    ("siege",   "assets/card_icons/siege.png",
     "Top-down view of a siege artillery unit for a card game. Massive long-range artillery tank with very long cannon barrel, heavy recoil systems, fortified chassis, dark olive drab with yellow hazard markings. Dark space bg, transparent, unit centered, 10%% margin. No text. High detail, sharp edges, sci-fi artillery style."),
    ("carrier", "assets/card_icons/carrier.png",
     "Top-down view of a carrier mothership unit for a card game. Very large aircraft carrier with wide flight deck, multiple hangar bays, command tower, deep navy blue and white. Dark space bg, transparent, unit centered, 10%% margin. No text. High detail, sharp edges, sci-fi carrier style."),
    ("medic",   "assets/card_icons/medic.png",
     "Top-down view of a medic repair support unit for a card game. Compact medical support vehicle with repair arms, healing energy aura, green medical cross, white and light teal with green accents. Dark space bg, transparent, unit centered, 10%% margin. No text. High detail, sharp edges, sci-fi medical style."),
    ("stealth", "assets/card_icons/stealth.png",
     "Top-down view of a stealth infiltration unit for a card game. Sleek angular fighter, faceted body that bends light, faint purple engine glow, black with subtle purple shimmer. Dark space bg, transparent, unit centered, 10%% margin. No text. High detail, sharp edges, sci-fi stealth style."),
    ("omega",   "assets/card_icons/omega_platform.png",
     "Top-down view of an omega all-equipment elite ace unit for a card game. Ultimate tier war machine, most heavily armored, golden trim on black body, multiple weapon systems, energy wings, glowing golden-white reactor. Dark space bg, transparent, unit centered, 10%% margin. No text. High detail, sharp edges, sci-fi elite style."),

    # === B. Card Frames ===
    ("frame_common",     "assets/cards/frames/common.png",
     "A card game card frame border, transparent background. ONLY a decorative border frame with empty center, no card art. Clean geometric border, subtle dark gray metallic frame, corner accents. No text."),
    ("frame_uncommon",   "assets/cards/frames/uncommon.png",
     "A card game card frame border, transparent background. ONLY a decorative border frame with empty center, no card art. Sleek silver border with subtle blue glow, geometric corner pieces, slightly more ornate than common. No text."),
    ("frame_rare",       "assets/cards/frames/rare.png",
     "A card game card frame border, transparent background. ONLY a decorative border frame with empty center, no card art. Gold and amber border with bright golden glow, star decorations at corners. No text."),
    ("frame_epic",       "assets/cards/frames/epic.png",
     "A card game card frame border, transparent background. ONLY a decorative border frame with empty center, no card art. Deep purple gradient border with vivid purple energy glow, diamond corner ornaments. No text."),
    ("frame_legendary",  "assets/cards/frames/legendary.png",
     "A card game card frame border, transparent background. ONLY a decorative border frame with empty center, no card art. Majestic golden border with intense golden fire and particle effects, legendary aura. No text."),

    # === C. UI Icons ===
    ("icon_shop",        "assets/ui/icons/icon_shop.png",
     "A flat game UI icon of a shopping store, single color icon on transparent background. Simple bold shopping bag or storefront symbol, high contrast, works on dark backgrounds. Clean modern flat style."),
    ("icon_quest",       "assets/ui/icons/icon_quest.png",
     "A flat game UI icon of a quest or mission, single color icon on transparent background. Scroll or document with exclamation mark, high contrast, works on dark backgrounds. Clean modern flat style."),
    ("icon_leaderboard", "assets/ui/icons/icon_leaderboard.png",
     "A flat game UI icon of a leaderboard or ranking list, single color icon on transparent background. Trophy or numbered list symbol, high contrast, works on dark backgrounds. Clean modern flat style."),
    ("icon_settings",    "assets/ui/icons/icon_settings.png",
     "A flat game UI icon of settings or gear, single color icon on transparent background. Cog wheel or gear symbol, high contrast, works on dark backgrounds. Clean modern flat style."),
    ("icon_help",        "assets/ui/icons/icon_help.png",
     "A flat game UI icon of help or information, single color icon on transparent background. Question mark in circle, high contrast, works on dark backgrounds. Clean modern flat style."),
    ("icon_close",       "assets/ui/icons/icon_close.png",
     "A flat game UI icon of close or dismiss, single color icon on transparent background. X cross or close button, high contrast, works on dark backgrounds. Clean modern flat style."),
    ("icon_arrow_left",  "assets/ui/icons/icon_arrow_left.png",
     "A flat game UI icon of a left arrow, single color icon on transparent background. Simple chevron or triangle pointing left, high contrast, works on dark backgrounds. Clean modern flat style."),
    ("icon_arrow_right", "assets/ui/icons/icon_arrow_right.png",
     "A flat game UI icon of a right arrow, single color icon on transparent background. Simple chevron or triangle pointing right, high contrast, works on dark backgrounds. Clean modern flat style."),
    ("icon_filter",      "assets/ui/icons/icon_filter.png",
     "A flat game UI icon of a filter or funnel, single color icon on transparent background. Funnel or filter symbol with lines, high contrast, works on dark backgrounds. Clean modern flat style."),
    ("icon_sort",        "assets/ui/icons/icon_sort.png",
     "A flat game UI icon of a sort or list order, single color icon on transparent background. Vertical bars of ascending height or sort arrows, high contrast, works on dark backgrounds. Clean modern flat style."),

    # === D. Faction Logos ===
    ("iron_wall_32",  "assets/ui/factions/iron_wall_corp_32.png",
     "Faction logo for Iron Wall Corporation - defense-oriented faction. A strong fortress wall or shield emblem, iron gray and dark blue, imposing and defensive. Simple bold emblem, clean lines, works at small size. Transparent background, no text."),
    ("iron_wall_128","assets/ui/factions/iron_wall_corp_128.png",
     "Faction logo for Iron Wall Corporation - defense-oriented faction. A strong fortress wall or shield emblem, iron gray and dark blue, imposing and defensive. More detailed emblem with metallic texture, works at larger size. Transparent background, no text."),
    ("nova_arms_32",  "assets/ui/factions/nova_arms_32.png",
     "Faction logo for Nova Arms Manufacturing - firepower-oriented faction. A stylized explosion or star-burst weapon emblem, orange and black, aggressive and powerful. Simple bold emblem, clean lines, works at small size. Transparent background, no text."),
    ("nova_arms_128", "assets/ui/factions/nova_arms_128.png",
     "Faction logo for Nova Arms Manufacturing - firepower-oriented faction. A stylized explosion or star-burst weapon emblem, orange and black, aggressive and powerful. More detailed with flame effects, works at larger size. Transparent background, no text."),
    ("aether_dyn_32", "assets/ui/factions/aether_dynamics_32.png",
     "Faction logo for Aether Dynamics Heavy Industry - propulsion and engine faction. A turbine or engine core emblem, teal and silver, technological and dynamic. Simple bold emblem, clean lines, works at small size. Transparent background, no text."),
    ("aether_dyn_128","assets/ui/factions/aether_dynamics_128.png",
     "Faction logo for Aether Dynamics Heavy Industry - propulsion and engine faction. A turbine or engine core with energy rings, teal and silver, technological and dynamic. More detailed with energy effects, works at larger size. Transparent background, no text."),
    ("quantum_log_32","assets/ui/factions/quantum_logistics_32.png",
     "Faction logo for Quantum Logistics Group - supply and transport faction. A hexagon with supply chain nodes, purple and white, organized and connected. Simple bold emblem, clean lines, works at small size. Transparent background, no text."),
    ("quantum_log_128","assets/ui/factions/quantum_logistics_128.png",
     "Faction logo for Quantum Logistics Group - supply and transport faction. A hexagon with interconnected supply chain network, purple and white, organized and high-tech. More detailed with network lines, works at larger size. Transparent background, no text."),
    ("helix_recon_32","assets/ui/factions/helix_recon_32.png",
     "Faction logo for Helix Recon Systems - reconnaissance and tracking faction. An eye or radar sweep emblem, yellow and dark green, vigilant and scanning. Simple bold emblem, clean lines, works at small size. Transparent background, no text."),
    ("helix_recon_128","assets/ui/factions/helix_recon_128.png",
     "Faction logo for Helix Recon Systems - reconnaissance and tracking faction. An eye with radar wave rings, yellow and dark green, vigilant and high-tech. More detailed with wave effects, works at larger size. Transparent background, no text."),
    ("void_research_32","assets/ui/factions/void_research_32.png",
     "Faction logo for Void Phase Research Institute - experimental phase technology faction. A mysterious portal or phase rift emblem, deep purple and void black, mysterious and unknown. Simple bold emblem, clean lines, works at small size. Transparent background, no text."),
    ("void_research_128","assets/ui/factions/void_research_128.png",
     "Faction logo for Void Phase Research Institute - experimental phase technology faction. A mysterious portal with swirling phase energy, deep purple and void black, mysterious and awe-inspiring. More detailed with swirling effects, works at larger size. Transparent background, no text."),
    ("frontier_32","assets/ui/factions/frontier_union_32.png",
     "Faction logo for Frontier Union Corporation - alliance and expansion faction. A star or union star emblem, silver and bronze, collaborative and expansive. Simple bold emblem, clean lines, works at small size. Transparent background, no text."),
    ("frontier_128","assets/ui/factions/frontier_union_128.png",
     "Faction logo for Frontier Union Corporation - alliance and expansion faction. A star with radiating lines of expansion, silver and bronze, collaborative and ambitious. More detailed with ray effects, works at larger size. Transparent background, no text."),

    # === E. Star Icons ===
    ("star_1",  "assets/ui/stars/star_1.png",
     "A glowing game UI star icon, single star symbol. Bright golden yellow star with subtle glow effect on transparent background. Clean flat style, works on any dark UI."),
    ("star_2",  "assets/ui/stars/star_2.png",
     "Two glowing game UI star icons side by side, stars symbol. Bright golden yellow stars with subtle glow effects on transparent background. Clean flat style, works on any dark UI."),
    ("star_3",  "assets/ui/stars/star_3.png",
     "Three glowing game UI star icons in a row, stars symbol. Bright golden yellow stars with subtle glow effects on transparent background. Clean flat style, works on any dark UI."),
    ("star_4",  "assets/ui/stars/star_4.png",
     "Four glowing game UI star icons in a row, stars symbol. Bright golden yellow stars with subtle glow effects on transparent background. Clean flat style, works on any dark UI."),
    ("star_5",  "assets/ui/stars/star_5.png",
     "Five glowing game UI star icons in a row, stars symbol. Bright golden yellow stars with subtle glow effects on transparent background. Clean flat style, works on any dark UI."),
    ("star_6",  "assets/ui/stars/star_6.png",
     "Six glowing game UI star icons in two rows of three, stars symbol. Bright golden yellow stars with subtle glow effects on transparent background. Clean flat style, works on any dark UI."),
    ("star_7",  "assets/ui/stars/star_7.png",
     "Seven glowing game UI star icons in two rows, stars symbol. Bright golden yellow stars with subtle glow effects on transparent background. Clean flat style, works on any dark UI."),
]

def win_path(p: str) -> str:
    r"""Convert /f/... to F:\..."""
    m = re.match(r"/([a-z])/(.*)", p)
    if m:
        p = f"{m.group(1).upper()}:\\{m.group(2)}"
    return p.replace("/", "\\")

def download(url: str, dest: str, retries: int = 3) -> bool:
    dest_win = win_path(dest)
    os.makedirs(os.path.dirname(dest_win), exist_ok=True)
    for attempt in range(retries):
        try:
            urllib.request.urlretrieve(url, dest_win)
            size = os.path.getsize(dest_win)
            print(f"  [OK] {os.path.basename(dest_win)} {size:,} B")
            return True
        except Exception as e:
            print(f"  [WARN] DL attempt {attempt+1} failed: {e}")
            if attempt < retries - 1:
                time.sleep(3)
    return False

def run_and_get_url(prompt: str) -> str:
    """Run gen_image.py, parse JSON from stdout for result_url."""
    cmd = [sys.executable, SCRIPT, prompt, "placeholder_output.png",
           "--token", TOKEN, "--poll-interval", "8", "--max-poll-time", "600"]
    proc = subprocess.run(cmd, capture_output=True, encoding="utf-8", errors="replace", timeout=660)

    # Print stderr lines so user sees progress
    if proc.stderr:
        for line in proc.stderr.splitlines():
            line = line.strip()
            if line:
                print(f"    {line}")

    # Parse stdout for JSON result
    for line in proc.stdout.splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            data = json.loads(line)
            if "result_url" in data:
                return data["result_url"]
        except json.JSONDecodeError:
            pass
    return None

def generate_one(key: str, output: str, prompt: str) -> bool:
    output_abs = win_path(output)
    if os.path.exists(output_abs) and os.path.getsize(output_abs) > 5000:
        print(f"  [SKIP] {key} (exists)")
        return True

    print(f"[GEN] {key} ...", flush=True)
    url = None
    for attempt in range(5):
        url = run_and_get_url(prompt)
        if url:
            break
        wait = (attempt + 1) * 15
        print(f"  [RETRY] {key}, waiting {wait}s...")
        time.sleep(wait)

    if not url:
        print(f"  [FAIL] {key} - no result URL after 5 attempts")
        return False

    if isinstance(url, list):
        url = url[0]
    return download(url, output)

def main():
    print(f"Batch generating {len(TASKS)} assets sequentially...")
    print()
    success = 0
    fail = 0
    for i, (key, output, prompt) in enumerate(TASKS):
        print(f"[{i+1}/{len(TASKS)}] ", end="", flush=True)
        if generate_one(key, output, prompt):
            success += 1
        else:
            fail += 1
        print()

    print(f"\n=== Done: {success} ok, {fail} failed ===")

if __name__ == "__main__":
    main()