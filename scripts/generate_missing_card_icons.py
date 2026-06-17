"""
Generate missing player card icons using agnes-image model.

For each card that lacks an icon:
  - Generate a 1024x1024 card icon with white background
  - Style: military unit illustration, strict 2D side/front view, isolated on white
  - Output: assets/card_icons/<card_id>.png

Usage:
  python scripts/generate_missing_card_icons.py

API Key: read from ~/.hermes/config.yaml or use SKIPPABLE_API_KEY env var.
"""
import os, json, base64, urllib.request, time

# ── API config ──────────────────────────────────────────────
BASE_URL = "https://apihub.agnes-ai.com/v1/images/generations"
OUTPUT_DIR = r"F:\godot fair duet\create\phase-war\assets\card_icons"

# Read API key from config
api_key = ""
config_path = os.path.expanduser("~/.hermes/config.yaml")
try:
    with open(config_path, "r", encoding="utf-8") as f:
        for line in f:
            if "api_key:" in line and not line.strip().startswith("#"):
                api_key = line.strip().split("api_key:", 1)[1].strip()
                break
except Exception:
    pass

# Override with env var if set
api_key = os.environ.get("SKIPPABLE_API_KEY", api_key) or api_key

# ── Card definitions: (card_id, prompt) ─────────────────────
# Prompts are designed for 1024x1024 card icons with white background
# Style: military unit illustration, clean side/front view, isolated on white

CARDS = [
    # ═══════════ WW1 (15 cards) ═══════════
    ("ww1_mp18", "WW1 MP18 assault infantry squad, soldier holding submachine gun, khaki uniform with leather belt, WW1 era German military style, realistic military illustration, isolated on white background, 1024x1024"),
    ("ww1_mauser", "WW1 Mauser rifle infantry squad, soldier with bolt-action rifle, khaki field uniform, WW1 era military, realistic military illustration, isolated on white background, 1024x1024"),
    ("ww1_enfield", "WW1 Lee-Enfield rifle infantry squad, soldier with magazine-fed rifle, British khaki uniform, WW1 era military, realistic military illustration, isolated on white background, 1024x1024"),
    ("ww1_mg08", "WW1 MG08 machine gun nest, heavy machine gun on tripod with sandbag cover, two-gun crew, WW1 era, realistic military illustration, isolated on white background, 1024x1024"),
    ("ww1_vickers", "WW1 Vickers machine gun position, heavy machine gun on pedestal mount with armored shield, WW1 era British military, realistic military illustration, isolated on white background, 1024x1024"),
    ("ww1_m81", "WW1 81mm mortar team, portable light mortar with ammunition boxes, infantry support weapon, WW1 era, realistic military illustration, isolated on white background, 1024x1024"),
    ("ww1_m76", "WW1 76mm mortar crew, medium mortar with round base plates, infantry fire support, WW1 era, realistic military illustration, isolated on white background, 1024x1024"),
    ("ww1_storm", "WW1 Stormtrooper assault squad, elite infantry with reinforced helmet and submachine guns, aggressive stance, WW1 era German storm troops, realistic military illustration, isolated on white background, 1024x1024"),
    ("ww1_lanchest", "WW1 Lanchester armored car, early armored vehicle with turret and machine gun mounts, riveted steel armor, WW1 era, realistic military illustration, isolated on white background, 1024x1024"),
    ("ww1_ft17", "WW1 FT-17 light tank, early tank with rotating turret, tracked chassis, French military design, WW1 era, realistic military illustration, isolated on white background, 1024x1024"),
    ("ww1_saint", "WW1 Saint-Chamond tank, heavy WW1 tank with long hull and front-mounted gun, riveted armor plates, French military, realistic military illustration, isolated on white background, 1024x1024"),
    ("ww1_a7v", "WW1 A7V heavy tank, German WW1 super-heavy tank with boxy hull, multiple machine gun ports, imposing military vehicle, realistic military illustration, isolated on white background, 1024x1024"),
    ("ww1_mark4", "WW1 Mark IV tank, British WW1 tank with male armament (cannons and machine guns), rhomboid tracked hull, trench-crossing design, realistic military illustration, isolated on white background, 1024x1024"),
    ("ww1_77mm", "WW1 77mm field gun, horse-drawn artillery piece with wooden spoked wheels, crew with field glasses, WW1 era British artillery, realistic military illustration, isolated on white background, 1024x1024"),
    ("ww1_105mm", "WW1 105mm howitzer, medium field artillery with curved barrel, ammunition limber, WW1 era siege artillery, realistic military illustration, isolated on white background, 1024x1024"),
    ("ww1_37mm", "WW1 37mm anti-aircraft gun, small caliber AA gun on elevated platform, flak position, WW1 era early air defense, realistic military illustration, isolated on white background, 1024x1024"),
    ("ww1_cavalry", "WW1 cavalry scout, mounted soldier with carbine and sword, reconnaissance uniform, WW1 era cavalry, realistic military illustration, isolated on white background, 1024x1024"),
    ("ww1_flame", "WW1 flame thrower operator, soldier with backpack flame thrower apparatus, protective gear, WW1 era assault infantry, realistic military illustration, isolated on white background, 1024x1024"),
    ("ww1_engineer", "WW1 engineer squad, soldiers with shovels, welding equipment, and construction tools, field engineering gear, WW1 era, realistic military illustration, isolated on white background, 1024x1024"),

    # ═══════════ WW2 (16 cards) ═══════════
    ("ww2_thompson", "WW2 Thompson submachine gun squad, American GI with Tommy gun, M1 helmet, WWII era US infantry, realistic military illustration, isolated on white background, 1024x1024"),
    ("ww2_garand", "WW2 M1 Garand rifle squad, American infantry with semi-automatic rifle, M1 helmet, WWII era US army, realistic military illustration, isolated on white background, 1024x1024"),
    ("ww2_mp40", "WW2 MP40 squad, German infantry with submachine gun, Stahlhelm helmet, WWII era Wehrmacht, realistic military illustration, isolated on white background, 1024x1024"),
    ("ww2_ppsh", "WW2 PPSh-41 squad, Soviet infantry with submachine gun, ushanka hat, WWII era Red Army, realistic military illustration, isolated on white background, 1024x1024"),
    ("ww2_mg42", "WW2 MG42 machine gun nest, German heavy machine gun position with shield and ammunition belt, WWII era, realistic military illustration, isolated on white background, 1024x1024"),
    ("ww2_browning", "WW2 Browning M2 machine gun position, American heavy machine gun on tripod, WWII era, realistic military illustration, isolated on white background, 1024x1024"),
    ("ww2_panzerschrek", "WW2 Panzerfaust/Panzerschreck anti-tank team, German infantry with rocket launcher, WWII era, realistic military illustration, isolated on white background, 1024x1024"),
    ("ww2_bazooka", "WW2 Bazooka anti-tank team, American infantry with rocket launcher, WWII era, realistic military illustration, isolated on white background, 1024x1024"),
    ("ww2_m81", "WW2 81mm mortar team, American mortar squad with M2 mortar and ammunition, WWII era, realistic military illustration, isolated on white background, 1024x1024"),
    ("ww2_m120", "WW2 120mm heavy mortar, American heavy mortar position with large caliber tube, WWII era siege support, realistic military illustration, isolated on white background, 1024x1024"),
    ("ww2_pz3", "WW2 Panzer III tank, German medium tank with medium-length cannon, WWII era Wehrmacht armored, realistic military illustration, isolated on white background, 1024x1024"),
    ("ww2_pz4", "WW2 Panzer IV tank, German medium/heavy tank with short-barreled howitzer, WWII era, realistic military illustration, isolated on white background, 1024x1024"),
    ("ww2_panther", "WW2 Panther medium tank, German Panther with sloped armor and long cannon, WWII era, realistic military illustration, isolated on white background, 1024x1024"),
    ("ww2_tiger", "WW2 Tiger I heavy tank, German Tiger with thick vertical armor and long 88mm gun, WWII era, realistic military illustration, isolated on white background, 1024x1024"),
    ("ww2_kingtiger", "WW2 King Tiger super-heavy tank, German Tiger II with extreme frontal armor and long cannon, WWII era boss tank, realistic military illustration, isolated on white background, 1024x1024"),
    ("ww2_t34_76", "WW2 T-34/76 tank, Soviet medium tank with sloped armor and 76mm gun, WWII era Red Army, realistic military illustration, isolated on white background, 1024x1024"),
    ("ww2_t34_85", "WW2 T-34/85 tank, improved Soviet medium tank with larger turret and 85mm gun, WWII era, realistic military illustration, isolated on white background, 1024x1024"),
    ("ww2_is2", "WW2 IS-2 heavy tank, Soviet heavy tank with massive 122mm gun, thick armor, WWII era, realistic military illustration, isolated on white background, 1024x1024"),
    ("ww2_sherman", "WW2 M4 Sherman tank, American medium tank with 75mm gun, WWII era, realistic military illustration, isolated on white background, 1024x1024"),
    ("ww2_hellcat", "WW2 M18 Hellcat tank destroyer, American lightweight tank destroyer with open turret, low silhouette, WWII era, realistic military illustration, isolated on white background, 1024x1024"),

    # ═══════════ Cold War (16 cards) ═══════════
    ("cold_rpg", "Cold War RPG-7 anti-tank team, soldier with rocket-propelled grenade launcher, Eastern Bloc military style, 1960s-80s era, realistic military illustration, isolated on white background, 1024x1024"),
    ("cold_ak47", "Cold War AK-47 infantry squad, Soviet/Russian soldier with assault rifle, olive drab uniform, Kalashnikov design, Cold War era, realistic military illustration, isolated on white background, 1024x1024"),
    ("cold_m14", "Cold War M14 infantry squad, American soldier with M14 rifle, 1960s US military uniform, Cold War era, realistic military illustration, isolated on white background, 1024x1024"),
    ("cold_m60", "Cold War M60 machine gun team, American squad automatic weapon with bipod and ammo box, 1960s US military, realistic military illustration, isolated on white background, 1024x1024"),
    ("cold_rpk", "Cold War RPK light machine gun team, Soviet portable machine gun with curved magazine, Cold War era Eastern Bloc, realistic military illustration, isolated on white background, 1024x1024"),
    ("cold_btr60", "Cold War BTR-60 armored personnel carrier, Soviet wheeled APC with turret, 8-wheel drive, Cold War era, realistic military illustration, isolated on white background, 1024x1024"),
    ("cold_m113", "Cold War M113 armored personnel carrier, American tracked APC with open top, 1960s US military, realistic military illustration, isolated on white background, 1024x1024"),
    ("cold_bmp1", "Cold War BMP-1 infantry fighting vehicle, Soviet tracked IFV with 73mm gun, Cold War era, realistic military illustration, isolated on white background, 1024x1024"),
    ("cold_bradley", "Cold War M2 Bradley fighting vehicle, American tracked IFV with TOW missile launcher, 1980s US military, realistic military illustration, isolated on white background, 1024x1024"),
    ("cold_t55", "Cold War T-55 main battle tank, Soviet medium tank with 100mm gun, sloped armor, Cold War era, realistic military illustration, isolated on white background, 1024x1024"),
    ("cold_t62", "Cold War T-62 main battle tank, Soviet tank with 115mm smoothbore gun, improved T-55, Cold War era, realistic military illustration, isolated on white background, 1024x1024"),
    ("cold_t72", "Cold War T-72 main battle tank, Soviet heavy MBT with autoloader, distinctive cast turret, Cold War era, realistic military illustration, isolated on white background, 1024x1024"),
    ("cold_m60t", "Cold War M60 main battle tank, American MBT with 105mm gun, 1960s-80s US armored forces, realistic military illustration, isolated on white background, 1024x1024"),
    ("cold_m1", "Cold War M1 Abrams main battle tank, American MBT with gas turbine engine, low silhouette, 1980s US army, realistic military illustration, isolated on white background, 1024x1024"),
    ("cold_leo1", "Cold War Leopard 1 tank, German MBT with low profile and 105mm gun, 1960s West German army, realistic military illustration, isolated on white background, 1024x1024"),
    ("cold_chieftain", "Cold War Chieftain tank, British heavy MBT with long 120mm gun, heavily armored, 1960s British army, realistic military illustration, isolated on white background, 1024x1024"),
    ("cold_zsu23", "Cold War ZSU-23-4 self-propelled AA, Soviet quad-23mm anti-aircraft vehicle, 1960s era, realistic military illustration, isolated on white background, 1024x1024"),
    ("cold_sam7", "Cold War SA-7 surface-to-air missile team, portable Soviet SAM launcher, shoulder-fired anti-air, Cold War era, realistic military illustration, isolated on white background, 1024x1024"),
    ("cold_mig21", "Cold War MiG-21 fighter jet, Soviet delta-wing interceptor, pointy nose, Cold War era air force, realistic military illustration, isolated on white background, 1024x1024"),
    ("cold_f4", "Cold War F-4 Phantom II fighter jet, American twin-engine multirole fighter, 1960s USAF/US Navy, realistic military illustration, isolated on white background, 1024x1024"),
    ("cold_spetsnaz", "Cold War Spetsnaz special forces, Soviet elite special operations soldier, black tactical gear, Cold War era, realistic military illustration, isolated on white background, 1024x1024"),

    # ═══════════ Modern (12 cards) ═══════════
    ("mod_marine", "Modern US Marine infantry squad, soldier with M4 carbine, digital camouflage, 2000s era, realistic military illustration, isolated on white background, 1024x1024"),
    ("mod_ranger", "Modern Army Ranger squad, elite US infantry with advanced tactical gear, M4 rifle with optics, 2000s era, realistic military illustration, isolated on white background, 1024x1024"),
    ("mod_javelin", "Modern Javelin anti-tank missile team, soldier firing disposable Javelin launcher, 2000s era, realistic military illustration, isolated on white background, 1024x1024"),
    ("mod_stinger", "Modern Stinger portable air defense team, soldier with FIM-92 Stinger missile, 2000s era anti-air, realistic military illustration, isolated on white background, 1024x1024"),
    ("mod_hummer_tow", "Modern HMMWV with TOW missile, American Humvee mounted anti-tank platform, 2000s era, realistic military illustration, isolated on white background, 1024x1024"),
    ("mod_hummer_m2", "Modern HMMWV with M2 heavy machine gun, American Humvee mounted gun truck, 2000s era, realistic military illustration, isolated on white background, 1024x1024"),
    ("mod_m1a1", "Modern M1A1 Abrams tank, American main battle tank with depleted uranium armor, 1990s era, realistic military illustration, isolated on white background, 1024x1024"),
    ("mod_m1a2", "Modern M1A2 Abrams SEP tank, upgraded American MBT with thermal sights and glass cockpit, 2000s era, realistic military illustration, isolated on white background, 1024x1024"),
    ("mod_t90", "Modern T-90 main battle tank, Russian MBT with Kontakt-5 explosive armor, 1990s era, realistic military illustration, isolated on white background, 1024x1024"),
    ("mod_leo2a6", "Modern Leopard 2A6 tank, German MBT with long 120mm L/55 gun, NATO forces, 2000s era, realistic military illustration, isolated on white background, 1024x1024"),
    ("mod_challenger2", "Modern Challenger 2 tank, British MBT with Chobham armor, 120mm gun, 1990s British army, realistic military illustration, isolated on white background, 1024x1024"),
    ("mod_ah64", "Modern AH-64 Apache attack helicopter, American twin-engine armed helicopter, stub wings with missiles, 2000s era, realistic military illustration, isolated on white background, 1024x1024"),
    ("mod_ah1", "Modern AH-1 Cobra attack helicopter, American single rotor armed helicopter, tandem cockpit, 1990s era, realistic military illustration, isolated on white background, 1024x1024"),
    ("mod_uh60", "Modern UH-60 Black Hawk transport helicopter, American utility helicopter with four-blade rotor, 2000s era, realistic military illustration, isolated on white background, 1024x1024"),
    ("mod_stryker_mgs", "Modern Stryker MGS tank destroyer, American 8x8 wheeled armored vehicle with 105mm gun, 2000s era, realistic military illustration, isolated on white background, 1024x1024"),
    ("mod_stryker_m2", "Modern Stryker M2 infantry carrier, American 8x8 wheeled APC with turret, 2000s era, realistic military illustration, isolated on white background, 1024x1024"),

    # ═══════════ Future (14 cards) ═══════════
    ("fut_swarm", "Future swarm drone unit, cluster of small autonomous drones with propellers, futuristic military technology, 2050s era, realistic military illustration, isolated on white background, 1024x1024"),
    ("fut_scout_drone", "Future reconnaissance drone, sleek unmanned aerial vehicle with camera pod, modern stealth design, 2040s era, realistic military illustration, isolated on white background, 1024x1024"),
    ("fut_attack_drone", "Future attack drone, armed unmanned combat aerial vehicle with missile payload, stealth geometry, 2040s era, realistic military illustration, isolated on white background, 1024x1024"),
    ("fut_cyborg", "Future cyborg infantry, enhanced soldier with cybernetic implants and powered armor, 2060s era, realistic military illustration, isolated on white background, 1024x1024"),
    ("fut_heavy_trooper", "Future heavy trooper, heavily augmented soldier with exoskeleton and energy weapon, 2060s era, realistic military illustration, isolated on white background, 1024x1024"),
    ("fut_scout_mech", "Future scout mech, lightweight bipedal reconnaissance mech with sensor array, 2060s era, realistic military illustration, isolated on white background, 1024x1024"),
    ("fut_assault_mech", "Future assault mech, medium bipedal combat mech with integrated cannon and armor, 2060s era, realistic military illustration, isolated on white background, 1024x1024"),
    ("fut_heavy_mech", "Future heavy mech, large bipedal war mech with heavy armor and multiple weapon systems, 2060s era, realistic military illustration, isolated on white background, 1024x1024"),
    ("fut_hovertank", "Future hover tank, anti-gravity armored vehicle with energy weapon, no tracks, 2050s era, realistic military illustration, isolated on white background, 1024x1024"),
    ("fut_howitzer", "Future悬浮 self-propelled howitzer, anti-gravity artillery with electromagnetic rail gun, 2050s era, realistic military illustration, isolated on white background, 1024x1024"),
    ("fut_prism", "Future Prism tank, armored vehicle with crystalline energy weapon system, glowing refractive optics, 2050s era, realistic military illustration, isolated on white background, 1024x1024"),
    ("fut_aa_hover", "Future anti-air hover platform, floating armored vehicle with point-defense laser array, 2050s era, realistic military illustration, isolated on white background, 1024x1024"),
    ("fut_stealth_bomber", "Future stealth bomber, flying wing design with internal weapon bay, low observable signature, 2050s era, realistic military illustration, isolated on white background, 1024x1024"),
    ("fut_space_fighter", "Future space fighter jet, atmospheric-and-space capable craft with vectoring thrusters, 2050s era, realistic military illustration, isolated on white background, 1024x1024"),
    ("fut_spectre", "Future spectre operative, cloaked special operations soldier with adaptive camouflage, 2060s era, realistic military illustration, isolated on white background, 1024x1024"),
    ("fut_nano_drone", "Future nano repair drone, small autonomous maintenance drone with healing beam emitter, 2050s era, realistic military illustration, isolated on white background, 1024x1024"),
    ("fut_shield", "Future energy shield generator, portable barrier projector emitting hexagonal energy field, 2050s era, realistic military illustration, isolated on white background, 1024x1024"),
    ("fut_colossus", "Future colossus mech, massive quadrupedal combat walker with heavy weaponry, 2060s era boss unit, realistic military illustration, isolated on white background, 1024x1024"),
    ("fut_stormcore", "Future storm core prototype, experimental energy weapon platform with swirling plasma core, 2060s era, realistic military illustration, isolated on white background, 1024x1024"),
]

# Deduplicate and filter
seen = set()
unique_cards = []
for card in CARDS:
    if card[0] not in seen:
        seen.add(card[0])
        unique_cards.append(card)
CARDS = unique_cards

print(f"Total cards to generate: {len(CARDS)}")
print(f"Output directory: {OUTPUT_DIR}")
print(f"API key loaded: {'Yes' if api_key else 'No (will read from env)'}")
print()

def generate_image(card_id, prompt, output_dir, model="agnes-image-2.0-flash"):
    """Generate a single image via agnes-image API."""
    data = {
        "model": model,
        "prompt": prompt,
        "image_size": "1024x1024",
    }

    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json"
    }

    req = urllib.request.Request(BASE_URL,
        data=json.dumps(data).encode("utf-8"),
        headers=headers)

    try:
        with urllib.request.urlopen(req, timeout=300) as response:
            result = json.loads(response.read().decode("utf-8"))

            if "data" in result and len(result["data"]) > 0:
                item = result["data"][0]
                img_url = item.get("url")
                if img_url and "http" in str(img_url):
                    img_req = urllib.request.Request(img_url, headers={"User-Agent": "Mozilla/5.0"})
                    with urllib.request.urlopen(img_req, timeout=60) as img_resp:
                        img_data = img_resp.read()

                    output_path = os.path.join(output_dir, f"{card_id}.png")
                    with open(output_path, "wb") as f:
                        f.write(img_data)
                    return True, len(img_data)

            return False, "No URL in response"

    except Exception as e:
        return False, str(e)


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    # Check which cards already have icons
    existing = []
    to_generate = []
    for card_id, _ in CARDS:
        path = os.path.join(OUTPUT_DIR, f"{card_id}.png")
        if os.path.exists(path):
            existing.append(card_id)
        else:
            to_generate.append(card_id)

    print(f"Already exist: {len(existing)}")
    print(f"To generate: {len(to_generate)}")
    print()

    if existing:
        print("Existing cards:")
        for c in sorted(existing):
            print(f"  {c}")
        print()

    success_count = 0
    fail_count = 0
    skipped_count = len(existing)

    for i, (card_id, prompt) in enumerate(CARDS):
        if card_id in existing:
            print(f"[{i+1}/{len(CARDS)}] SKIP: {card_id} (already exists)")
            continue

        print(f"[{i+1}/{len(CARDS)}] Generating: {card_id}...")
        ok, detail = generate_image(card_id, prompt, OUTPUT_DIR)
        if ok:
            success_count += 1
            print(f"  OK: {detail:,} bytes")
        else:
            fail_count += 1
            print(f"  FAIL: {detail}")

        # Rate limit: wait between requests
        if i < len(CARDS) - 1:
            time.sleep(3)

    print()
    print("=" * 50)
    print(f"Results: {success_count} generated, {fail_count} failed, {skipped_count} skipped (existing)")
    print(f"Total: {len(CARDS)}")


if __name__ == "__main__":
    main()
