#!/usr/bin/env python
"""
Phase War - 批量生成 UI 图标
从 stdin 读取 token，批量提交任务，轮询完成后下载并保存图片
"""
import subprocess
import json
import sys
import os
import time
import urllib.request
import shutil

SKILL_SCRIPT = "C:/Users/jianchang.tan/AppData/Local/Programs/WorkBuddy/resources/app.asar.unpacked/resources/builtin-skills/buddy-multimodal-generation/scripts/buddy-cloud.py"
PYTHON_EXE = "C:/Python314/python.exe"
ASSETS_BASE = "F:/godot fair duet/create/phase-war/assets/ui"

TOKEN = sys.stdin.read().strip()

# ─── 图标列表 ────────────────────────────────────────────────────────────────
# (output_path, prompt)
TASKS = [
    # ── 势力 Logo（8 势力，每个相同 prompt，128 和 32 共用一张源图）──
    ("factions/neutral_512.png",
     "flat 2D faction logo icon, a balanced neutral compass rose combined with three interlocking hollow circles representing no single faction allegiance, soft silver-white and muted grey-blue palette, faint hyperspace void backdrop with dim flowing light streaks, symmetrical emblem for generic unaligned phase operators, flat clean vector style, centered on dark background, game UI faction icon, 512x512"),
    ("factions/iron_wall_corp_512.png",
     "flat 2D faction logo icon, a bold shield emblem as the central motif, shield surface covered with steel cross texture and rivet details along the edge, metallic silver and dark gunmetal gray color palette, behind the shield a subtle faint hyperspace backdrop of deep grey-blue void with dim flowing light streaks, sharp clean vector outlines, symmetrical composition, military defense corporation symbol representing the belief we are the wall, former soldiers whose will becomes an impenetrable phase barrier, flat design with subtle inner gradient for depth, centered on dark background, game UI faction icon, 512x512"),
    ("factions/nova_arms_512.png",
     "flat 2D faction logo icon, two crossed sci-fi rifles forming an X shape behind a rising flame burst, flame depicted as sharp angular tongues pointing upward representing phase will materialized as destructive power, orange and deep dark steel color palette, behind the emblem a faint hyperspace backdrop of deep grey-blue void with dim flowing light streaks, bold clean vector lines, symmetrical emblem composition, aggressive arms faction representing the belief we do not defend we erase threats, firepower fanatics whose phase technology manifests as flames of destruction, flat design style, centered on dark background, game UI faction icon, 512x512"),
    ("factions/aether_dynamics_512.png",
     "flat 2D faction logo icon, a central engine turbine with five curved blade vanes, surrounded by an outer energy ring with small glowing node dots evenly spaced representing the eternal cycle of knowledge into phase power, cyan-blue and dark charcoal gray color palette, behind the emblem a faint hyperspace backdrop of deep grey-blue void with dim flowing light streaks, sleek technical vector design, symmetrical circular emblem, scholar faction representing the belief power fades only knowledge endures, flat design style, centered on dark background, game UI faction icon, 512x512"),
    ("factions/quantum_logistics_512.png",
     "flat 2D faction logo icon, a central rectangular cargo box with glowing circuit edges, connected by four flowing data stream lines radiating outward from each corner with small node dots along the streams representing hyperspace island logistics network, teal cyan and deep navy blue color palette, behind the emblem a faint hyperspace backdrop of deep grey-blue void with dim flowing light streaks, clean technical vector design, merchant faction representing the belief war is won by logistics, phase technology used for spatial fold transport, flat design style, centered on dark background, game UI faction icon, 512x512"),
    ("factions/helix_recon_512.png",
     "flat 2D faction logo icon, a double helix spiral forming the central spine overlaid with a radar sweep arc and concentric scanning rings emanating outward, at the core a sharp information eye symbol representing phase perception extended across hyperspace, vibrant green and dark slate gray color palette, behind the emblem a faint hyperspace backdrop of deep grey-blue void with dim flowing light streaks, sharp clean vector lines, reconnaissance faction representing the belief the unseen enemy cannot be defeated, flat design style, centered on dark background, game UI faction icon, 512x512"),
    ("factions/void_research_512.png",
     "flat 2D faction logo icon, a central vertical slit eye with an elliptical iris, surrounded by jagged void cracks radiating outward like broken space-time fractures representing dimensional tears in hyperspace, dark violet and deep black color palette with faint purple glow at crack edges suggesting forbidden phase energy leaking through, behind the emblem a faint hyperspace backdrop of deep grey-blue void with dim flowing light streaks, mysterious research faction representing the belief gaze into the abyss and the abyss gazes back, flat design style, centered on dark background, game UI faction icon, 512x512"),
    ("factions/frontier_union_512.png",
     "flat 2D faction logo icon, a multi-pointed cross star formed by overlapping diverse geometric shapes representing different phase beliefs uniting, with a small flowing banner flag draped below the star, gold and olive drab green color palette, behind the emblem a faint hyperspace backdrop of deep grey-blue void with dim flowing light streaks, strong clean vector outlines, symmetrical balanced composition, idealist faction representing the belief we do not need to be the same to stand together, flat design style, centered on dark background, game UI faction icon, 512x512"),

    # ── 星级图标 ──
    ("stars/star_1.png",
     "flat 2D single star rating icon, one classic five-pointed star with clean outlined shape, solid fill in bronze-copper color #CD7F32 with very faint dim glow suggesting the first spark of phase awareness awakening in hyperspace, simple and minimal design, centered composition on dark grey-blue background, game UI rarity rating icon, 512x512"),
    ("stars/star_2.png",
     "flat 2D two-star rating icon, two classic five-pointed stars side by side with equal size, solid fill in bronze-copper color #CD7F32 with faint warm glow between stars suggesting growing phase perception of hyperspace light streams, uniform spacing, simple clean design, centered composition on dark grey-blue background, game UI rarity rating icon, 512x512"),
    ("stars/star_3.png",
     "flat 2D three-star rating icon, three classic five-pointed stars arranged in a horizontal row, solid fill in polished silver color #C0C0C0 with subtle metallic sheen and faint phase shimmer connecting the stars suggesting mature phase perception and navigation between hyperspace floating islands, uniform spacing, simple clean design, centered composition on dark grey-blue background, game UI rarity rating icon, 512x512"),
    ("stars/star_4.png",
     "flat 2D four-star rating icon, four classic five-pointed stars arranged in a horizontal row, solid fill in rich gold color #FFD700 with warm golden glow suggesting the phase shifter's will beginning to materialize as reality-interference power leaving phase traces in hyperspace, uniform spacing, clean design, centered composition on dark grey-blue background, game UI rarity rating icon, 512x512"),
    ("stars/star_5.png",
     "flat 2D five-star rating icon, five classic five-pointed stars arranged in a horizontal row, solid fill in bright gold color #FFD700 with a subtle soft glow outline around each star and faint resonance ripples between stars suggesting the phase shifter's will resonating with hyperspace reality, uniform spacing, premium clean design, centered composition on dark grey-blue background, game UI rarity rating icon, 512x512"),
    ("stars/star_6.png",
     "flat 2D six-star rating icon, six classic five-pointed stars arranged in a 2 rows by 3 columns grid, solid fill in elegant platinum-gold color #E5E4E2 with a distinct outer glow halo around each star and subtle hyperspace void distortion patterns between stars suggesting the phase shifter can rewrite local hyperspace reality through sheer will, uniform spacing, premium high-tier design, centered composition on dark grey-blue background, game UI rarity rating icon, 512x512"),
    ("stars/star_7.png",
     "flat 2D seven-star rating icon, seven classic five-pointed stars arranged in a diamond constellation pattern with one large central star and six smaller stars orbiting, solid fill in brilliant diamond-gold with radiant light rays emanating outward from the central star and flowing hyperspace light bands weaving through the constellation suggesting ultimate phase mastery where will rewrites hyperspace laws themselves, legendary tier design, centered composition on dark grey-blue background, game UI rarity rating icon, 512x512"),
    ("stars/star_8.png",
     "flat 2D eight-star rating icon, eight classic five-pointed stars in a gentle arc or double-row layout, brilliant platinum-silver fill with subtle prismatic edge highlights suggesting beyond-seven-star extension tier, faint hyperspace light band behind the row, centered on dark grey-blue background, game UI rarity rating icon, 512x512"),

    # ── 相位仪型号图标 ──
    ("instruments/pi_aegis_01.png",
     "flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, dial on small shield outpost mount, aether dynamics silver-blue, sentry turret silhouette on bezel, soft luminous outer ring, holographic tick marks, sci-fi Phase War game UI, centered on dark grey-blue background, 512x512"),
    ("instruments/pi_aegis_02.png",
     "flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, square phalanx shield array framing dial, formation grid lines, defensive corporation emblem hint, soft luminous outer ring, holographic tick marks, sci-fi Phase War game UI, centered on dark grey-blue background, 512x512"),
    ("instruments/pi_aegis_03.png",
     "flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, domed shield canopy over dial, layered energy panels, fortress dome silhouette, soft luminous outer ring, holographic tick marks, sci-fi Phase War game UI, centered on dark grey-blue background, 512x512"),
    ("instruments/pi_aegis_04.png",
     "flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, massive citadel core shield with radiant barrier nodes, ultimate aether dynamics fortress instrument, legendary tier gold-purple rim glow, soft luminous outer ring, holographic tick marks, sci-fi Phase War game UI, centered on dark grey-blue background, 512x512"),
    ("instruments/pi_atlas_01.png",
     "flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, quantum logistics cargo drone silhouette, worker bee logistics glyph, teal supply lines, soft luminous outer ring, holographic tick marks, sci-fi Phase War game UI, centered on dark grey-blue background, 512x512"),
    ("instruments/pi_atlas_02.png",
     "flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, structural support beam frame, bridge pillar icons, logistics backbone dial, soft luminous outer ring, holographic tick marks, sci-fi Phase War game UI, centered on dark grey-blue background, 512x512"),
    ("instruments/pi_atlas_03.png",
     "flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, bridge core hub with radiating supply routes, heavy teal energy trunk lines, epic tier purple-blue rim glow, soft luminous outer ring, holographic tick marks, sci-fi Phase War game UI, centered on dark grey-blue background, 512x512"),
    ("instruments/pi_eon_01.png",
     "flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, frontier union gold clock hand second needle, minimal time dial ticks, soft luminous outer ring, holographic tick marks, sci-fi Phase War game UI, centered on dark grey-blue background, 512x512"),
    ("instruments/pi_eon_02.png",
     "flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, layered time-step rings, olive and gold chronometer stages, rare tier blue rim glow, soft luminous outer ring, holographic tick marks, sci-fi Phase War game UI, centered on dark grey-blue background, 512x512"),
    ("instruments/pi_eon_03.png",
     "flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, ultimate chronology crown, multi-hand temporal dial, frontier union flagship time instrument, legendary tier gold-purple rim glow, soft luminous outer ring, holographic tick marks, sci-fi Phase War game UI, centered on dark grey-blue background, 512x512"),
    ("instruments/pi_generic_01.png",
     "flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, compact entry phase instrument dial, bronze trim, one slow star point on deep space blue face, rookie pilot starter kit aesthetic, soft luminous outer ring, holographic tick marks, sci-fi Phase War game UI, centered on dark grey-blue background, 512x512"),
    ("instruments/pi_generic_02.png",
     "flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, slightly larger dial with dual faint star orbits and soft cyan recovery glow ring suggesting energy recycle, soft luminous outer ring, holographic tick marks, sci-fi Phase War game UI, centered on dark grey-blue background, 512x512"),
    ("instruments/pi_generic_03.png",
     "flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, dial with expanded outer deployment range tick marks and three star points, agile scout styling, soft luminous outer ring, holographic tick marks, sci-fi Phase War game UI, centered on dark grey-blue background, 512x512"),
    ("instruments/pi_generic_04.png",
     "flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, dial with forward-pointing phase blade motif on bezel, warm amber accent for attack tuning, soft luminous outer ring, holographic tick marks, sci-fi Phase War game UI, centered on dark grey-blue background, 512x512"),
    ("instruments/pi_generic_05.png",
     "flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, dual-layer dial rings, crossed phase strike glyphs, balanced assault module look, rare tier blue rim glow, soft luminous outer ring, holographic tick marks, sci-fi Phase War game UI, centered on dark grey-blue background, 512x512"),
    ("instruments/pi_generic_06.png",
     "flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, heavy shield-shaped bezel around dial, reinforced rivet frame, defensive steel gray accents, rare tier blue rim glow, soft luminous outer ring, holographic tick marks, sci-fi Phase War game UI, centered on dark grey-blue background, 512x512"),
    ("instruments/pi_generic_07.png",
     "flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, fortified dial with thick armored collar and steady gold stability glow, rare tier blue rim glow, soft luminous outer ring, holographic tick marks, sci-fi Phase War game UI, centered on dark grey-blue background, 512x512"),
    ("instruments/pi_generic_08.png",
     "flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, dial surrounded by pulsing lightning arcs, high energy output capacitor nodes, rare tier blue rim glow, soft luminous outer ring, holographic tick marks, sci-fi Phase War game UI, centered on dark grey-blue background, 512x512"),
    ("instruments/pi_generic_09.png",
     "flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, overcharged dial with red overload sector and crackling phase sparks at rim, epic tier purple-blue rim glow, soft luminous outer ring, holographic tick marks, sci-fi Phase War game UI, centered on dark grey-blue background, 512x512"),
    ("instruments/pi_generic_10.png",
     "flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, constellation-linked dial with six tiny node stars chained by light threads, resource focus, epic tier purple-blue rim glow, soft luminous outer ring, holographic tick marks, sci-fi Phase War game UI, centered on dark grey-blue background, 512x512"),
    ("instruments/pi_generic_11.png",
     "flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, seven-node star chain halo, balanced multi-stat enhancement look, silver-gold trim, legendary tier gold-purple rim glow, soft luminous outer ring, holographic tick marks, sci-fi Phase War game UI, centered on dark grey-blue background, 512x512"),
    ("instruments/pi_generic_12.png",
     "flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, celestial crown bezel above dial, radiant sky-gold aura, ultimate generic flagship instrument, legendary tier gold-purple rim glow, soft luminous outer ring, holographic tick marks, sci-fi Phase War game UI, centered on dark grey-blue background, 512x512"),
    ("instruments/pi_helix_01.png",
     "flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, helix recon green spiral spine across dial, hunter sight reticle, recon line motif, soft luminous outer ring, holographic tick marks, sci-fi Phase War game UI, centered on dark grey-blue background, 512x512"),
    ("instruments/pi_helix_02.png",
     "flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, interwoven helix mesh net around dial, data web nodes, scout network aesthetic, soft luminous outer ring, holographic tick marks, sci-fi Phase War game UI, centered on dark grey-blue background, 512x512"),
    ("instruments/pi_helix_03.png",
     "flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, dense neural helix bundle core, bright synapse flashes, advanced recon instrument, soft luminous outer ring, holographic tick marks, sci-fi Phase War game UI, centered on dark grey-blue background, 512x512"),
    ("instruments/pi_iron_01.png",
     "flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, iron wall corp anchor bolt frame, heavy steel chains, anchored tanker dial, soft luminous outer ring, holographic tick marks, sci-fi Phase War game UI, centered on dark grey-blue background, 512x512"),
    ("instruments/pi_iron_02.png",
     "flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, forged chain links encircling dial, molten steel seam highlights, soft luminous outer ring, holographic tick marks, sci-fi Phase War game UI, centered on dark grey-blue background, 512x512"),
    ("instruments/pi_iron_03.png",
     "flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, throne-backplate iron fortress mount, regal gunmetal and gold rivets, ultimate iron wall instrument, legendary tier gold-purple rim glow, soft luminous outer ring, holographic tick marks, sci-fi Phase War game UI, centered on dark grey-blue background, 512x512"),
    ("instruments/pi_nova_01.png",
     "flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, nova arms orange circuit loop around dial, weapon circuit board traces, soft luminous outer ring, holographic tick marks, sci-fi Phase War game UI, centered on dark grey-blue background, 512x512"),
    ("instruments/pi_nova_02.png",
     "flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, flame-wreathed dial bezel, heat distortion waves, assault firepower styling, rare tier blue rim glow, soft luminous outer ring, holographic tick marks, sci-fi Phase War game UI, centered on dark grey-blue background, 512x512"),
    ("instruments/pi_nova_03.png",
     "flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, hyperstring vibration lines and intense flame crown, legendary nova arms superweapon dial, legendary tier gold-purple rim glow, soft luminous outer ring, holographic tick marks, sci-fi Phase War game UI, centered on dark grey-blue background, 512x512"),
    ("instruments/pi_nova_04.png",
     "flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, fission chamber ring with particle burst spokes, kill-energy feedback glow, soft luminous outer ring, holographic tick marks, sci-fi Phase War game UI, centered on dark grey-blue background, 512x512"),
    ("instruments/pi_r_free_deploy.png",
     "flat 2D stat ability icon, a nano-printed combat unit materializing from thin air with phase energy particles converging into solid form, blueprints ghost pattern visible around the forming unit as if being extracted from hyperspace database, a large zero symbol 0 overlaid suggesting zero deployment cost, faint hyperspace void with floating island nodes in background, golden legendary glow aura surrounding the composition, the materializing unit shows nano-assembly seam lines, game UI attribute icon, centered on dark grey-blue background, 512x512"),
    ("instruments/pi_umbra_01.png",
     "flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, void research violet thin blade slash across dial, stealth edge highlight, soft luminous outer ring, holographic tick marks, sci-fi Phase War game UI, centered on dark grey-blue background, 512x512"),
    ("instruments/pi_umbra_02.png",
     "flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, refracted light prism shards, crit eye slit motif, shadow recon styling, soft luminous outer ring, holographic tick marks, sci-fi Phase War game UI, centered on dark grey-blue background, 512x512"),
    ("instruments/pi_umbra_03.png",
     "flat 2D phase instrument equipment shop icon, circular deep space blue dial face with flowing star points, silent void dome suppressing light, dark purple haze, assassination field instrument, epic tier purple-blue rim glow, soft luminous outer ring, holographic tick marks, sci-fi Phase War game UI, centered on dark grey-blue background, 512x512"),
]

# ─── 辅助函数 ────────────────────────────────────────────────────────────────

def run_cmd(cmd_args, input_data=None):
    result = subprocess.run(
        cmd_args,
        input=input_data,
        capture_output=True, text=True
    )
    return result.stdout.strip(), result.stderr.strip(), result.returncode

def submit_job(token, prompt):
    cmd = [PYTHON_EXE, SKILL_SCRIPT, "image", prompt, "--no-poll", "--token-stdin"]
    stdout, stderr, code = run_cmd(cmd, input_data=token)
    if code != 0:
        return None, f"submit failed: {stderr}"
    try:
        data = json.loads(stdout)
        return data.get("job_id"), None
    except Exception as e:
        return None, f"parse error: {e}, stdout={stdout}"

def check_status(token, job_id):
    cmd = [PYTHON_EXE, SKILL_SCRIPT, "status", job_id, "--type", "image", "--token-stdin"]
    stdout, stderr, code = run_cmd(cmd, input_data=token)
    if code != 0:
        return None, f"status failed: {stderr}"
    try:
        data = json.loads(stdout)
        return data, None
    except Exception as e:
        return None, f"parse error: {e}, stdout={stdout}"

def download_file(url, dest_path):
    os.makedirs(os.path.dirname(dest_path), exist_ok=True)
    try:
        with urllib.request.urlopen(url) as resp, open(dest_path, 'wb') as f:
            shutil.copyfileobj(resp, f)
        return True
    except Exception as e:
        print(f"  [WARN] download failed: {e}")
        return False

def resize_image(src, dst, size):
    """用 Pillow 缩放图片；如果没有 Pillow 直接复制"""
    try:
        from PIL import Image
        img = Image.open(src)
        img = img.resize((size, size), Image.LANCZOS)
        img.save(dst)
    except ImportError:
        shutil.copy(src, dst)
        print(f"  [INFO] PIL not available, copied original to {dst}")

# ─── 主流程 ──────────────────────────────────────────────────────────────────

# 阶段一：批量提交
print("=" * 60)
print(f"Phase 1: Submitting {len(TASKS)} image generation jobs...")
print("=" * 60)

jobs = []  # [(output_path, job_id)]
failed_submit = []

# 为避免 API 限流，每提交 5 个暂停 2 秒
for i, (out_path, prompt) in enumerate(TASKS):
    full_out = os.path.join(ASSETS_BASE, out_path)
    if os.path.exists(full_out) and out_path not in [
        "factions/neutral_512.png", "factions/iron_wall_corp_512.png",
        "factions/nova_arms_512.png", "factions/aether_dynamics_512.png",
        "factions/quantum_logistics_512.png", "factions/helix_recon_512.png",
        "factions/void_research_512.png", "factions/frontier_union_512.png",
    ]:
        print(f"  [{i+1}/{len(TASKS)}] SKIP (exists): {out_path}")
        continue

    job_id, err = submit_job(TOKEN, prompt)
    if job_id:
        jobs.append((out_path, job_id))
        print(f"  [{i+1}/{len(TASKS)}] SUBMITTED: {out_path} -> {job_id}")
    else:
        failed_submit.append((out_path, err))
        print(f"  [{i+1}/{len(TASKS)}] FAILED submit: {out_path}: {err}")

    if (i + 1) % 5 == 0:
        time.sleep(2)

print(f"\nSubmitted: {len(jobs)}, Failed: {len(failed_submit)}")
if failed_submit:
    print("Failed submissions:")
    for p, e in failed_submit:
        print(f"  {p}: {e}")

# 阶段二：等待并下载
print("\n" + "=" * 60)
print(f"Phase 2: Polling {len(jobs)} jobs (may take 1-3 min each)...")
print("=" * 60)

# 首次等待 40 秒
if jobs:
    print("Waiting 60s for jobs to start processing...")
    time.sleep(60)

completed = []
pending = list(jobs)
max_retries = 15  # 最多 15 * 30s = 7.5 分钟

for attempt in range(max_retries):
    if not pending:
        break
    still_pending = []
    for out_path, job_id in pending:
        data, err = check_status(TOKEN, job_id)
        if err:
            print(f"  [WARN] status error for {out_path}: {err}")
            still_pending.append((out_path, job_id))
            continue
        status = data.get("status", "")
        if status == "DONE":
            result_url = data.get("result_url")
            if isinstance(result_url, list):
                result_url = result_url[0]
            if result_url:
                full_out = os.path.join(ASSETS_BASE, out_path)
                os.makedirs(os.path.dirname(full_out), exist_ok=True)
                ok = download_file(result_url, full_out)
                if ok:
                    completed.append(out_path)
                    print(f"  [DONE] Downloaded: {out_path}")
                else:
                    print(f"  [FAIL] Download failed: {out_path}")
            else:
                print(f"  [WARN] No result_url for {out_path}: {data}")
        elif status in ("FAILED", "ERROR"):
            print(f"  [FAIL] Job failed: {out_path} -> {data}")
        else:
            still_pending.append((out_path, job_id))

    pending = still_pending
    if pending:
        print(f"  Still pending: {len(pending)}, waiting 30s... (attempt {attempt+1}/{max_retries})")
        time.sleep(30)

if pending:
    print(f"\n[WARN] {len(pending)} jobs still pending after max retries:")
    for p, j in pending:
        print(f"  {p}: job_id={j}")

# 阶段三：势力 Logo 尺寸变体
print("\n" + "=" * 60)
print("Phase 3: Resizing faction logos...")
print("=" * 60)

faction_map = {
    "neutral": "factions/neutral_512.png",
    "iron_wall_corp": "factions/iron_wall_corp_512.png",
    "nova_arms": "factions/nova_arms_512.png",
    "aether_dynamics": "factions/aether_dynamics_512.png",
    "quantum_logistics": "factions/quantum_logistics_512.png",
    "helix_recon": "factions/helix_recon_512.png",
    "void_research": "factions/void_research_512.png",
    "frontier_union": "factions/frontier_union_512.png",
}

for faction, src_rel in faction_map.items():
    src = os.path.join(ASSETS_BASE, src_rel)
    if not os.path.exists(src):
        print(f"  [SKIP] Source not found: {src}")
        continue
    for size, suffix in [(128, "128"), (32, "32")]:
        dst = os.path.join(ASSETS_BASE, f"factions/{faction}_{suffix}.png")
        resize_image(src, dst, size)
        print(f"  [RESIZE] {faction}_{suffix}.png ({size}x{size})")

print("\n" + "=" * 60)
print(f"All done! Completed: {len(completed)}, Pending timeout: {len(pending)}, Submit failed: {len(failed_submit)}")
print("=" * 60)
