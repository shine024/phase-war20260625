"""
Generate remaining missing player card icons - FINAL BATCH

Only generates cards that DON'T already exist.
Processes all remaining cards in sequence with 3s delay.

Remaining cards to generate (58 total):
  WW2: 4 missing
  Cold War: 21
  Modern: 19
  Future: 14
"""
import os, json, urllib.request, time

BASE_URL = "https://apihub.agnes-ai.com/v1/images/generations"
OUTPUT_DIR = r"F:\godot fair duet\create\phase-war\assets\card_icons"

# Read API key
api_key = os.environ.get("SKIPPABLE_API_KEY", "")
if not api_key:
    config_path = os.path.expanduser("~/.hermes/config.yaml")
    try:
        with open(config_path, "r", encoding="utf-8") as f:
            for line in f:
                if "api_key:" in line and not line.strip().startswith("#"):
                    api_key = line.strip().split("api_key:", 1)[1].strip()
                    break
    except Exception:
        pass

if not api_key:
    print("ERROR: No API key found!")
    exit(1)

print(f"API key loaded: {api_key[:10]}...")
print(f"Output dir: {OUTPUT_DIR}")
print()

# All remaining cards that need generation
CARDS = [
    # WW2 missing (4)
    ("ww2_mg42", "WW2 MG42 machine gun nest, German heavy machine gun on shield mount with ammunition belt feed, WWII era German army, realistic military illustration, isolated on white background, 1024x1024"),
    ("ww2_m81", "WW2 81mm mortar team, American infantry mortar squad with M2 mortar tube and ammunition crates, WWII era, realistic military illustration, isolated on white background, 1024x1024"),
    ("ww2_sherman", "WW2 M4 Sherman medium tank, American tank with 75mm gun, riveted hull, WWII era US army, realistic military illustration, isolated on white background, 1024x1024"),
    ("ww2_hellcat", "WW2 M18 Tank Destroyer, American lightweight fast tank destroyer with open turret and 76mm gun, low silhouette, WWII era, realistic military illustration, isolated on white background, 1024x1024"),

    # Cold War (21)
    ("cold_ak47", "Cold War AK-47 infantry squad, Soviet soldier with iconic assault rifle, olive drab uniform and peaked cap, 1960s era, realistic military illustration, isolated on white background, 1024x1024"),
    ("cold_m14", "Cold War M14 infantry squad, American soldier with M14 rifle, 1960s US military uniform, realistic military illustration, isolated on white background, 1024x1024"),
    ("cold_m60", "Cold War M60 machine gun team, American squad automatic weapon with bipod and ammunition belt, 1960s US military, realistic military illustration, isolated on white background, 1024x1024"),
    ("cold_rpg", "Cold War RPG-7 anti-tank team, Soviet soldier with rocket-propelled grenade launcher, Eastern Bloc military, 1960s era, realistic military illustration, isolated on white background, 1024x1024"),
    ("cold_rpk", "Cold War RPK light machine gun team, Soviet portable machine gun with curved magazine, Eastern Bloc military, realistic military illustration, isolated on white background, 1024x1024"),
    ("cold_btr60", "Cold War BTR-60 armored personnel carrier, Soviet wheeled APC with turret and 8-wheel drive, realistic military illustration, isolated on white background, 1024x1024"),
    ("cold_m113", "Cold War M113 armored personnel carrier, American tracked APC with open top hatch, 1960s US military, realistic military illustration, isolated on white background, 1024x1024"),
    ("cold_bmp1", "Cold War BMP-1 infantry fighting vehicle, Soviet tracked IFV with 73mm gun and infantry door, realistic military illustration, isolated on white background, 1024x1024"),
    ("cold_bradley", "Cold War M2 Bradley fighting vehicle, American tracked IFV with TOW missile launcher on turret, 1980s US military, realistic military illustration, isolated on white background, 1024x1024"),
    ("cold_t55", "Cold War T-55 main battle tank, Soviet medium tank with 100mm D-10T gun and sloped armor, realistic military illustration, isolated on white background, 1024x1024"),
    ("cold_t62", "Cold War T-62 main battle tank, Soviet tank with 115mm U-5TS smoothbore gun, improved turret, realistic military illustration, isolated on white background, 1024x1024"),
    ("cold_t72", "Cold War T-72 main battle tank, Soviet heavy MBT with autoloader and distinctive cast turret, realistic military illustration, isolated on white background, 1024x1024"),
    ("cold_m60t", "Cold War M60 main battle tank, American MBT with 105mm M68 gun, 1960s-80s US armored forces, realistic military illustration, isolated on white background, 1024x1024"),
    ("cold_m1", "Cold War M1 Abrams main battle tank, American MBT with gas turbine engine and low silhouette, 1980s US army, realistic military illustration, isolated on white background, 1024x1024"),
    ("cold_leo1", "Cold War Leopard 1 tank, German MBT with low profile and 105mm L7 gun, 1960s West German army, realistic military illustration, isolated on white background, 1024x1024"),
    ("cold_chieftain", "Cold War Chieftain tank, British heavy MBT with long 120mm gun and heavily sloped frontal armor, realistic military illustration, isolated on white background, 1024x1024"),
    ("cold_zsu23", "Cold War ZSU-23-4 self-propelled AA, Soviet quad-23mm anti-aircraft vehicle on tracked chassis, realistic military illustration, isolated on white background, 1024x1024"),
    ("cold_sam7", "Cold War SA-7 Grail surface-to-air missile, Soviet soldier with shoulder-fired SAM launcher, realistic military illustration, isolated on white background, 1024x1024"),
    ("cold_mig21", "Cold War MiG-21 fighter jet, Soviet delta-wing interceptor with pointed nose cone, realistic military illustration, isolated on white background, 1024x1024"),
    ("cold_f4", "Cold War F-4 Phantom II fighter jet, American twin-engine multirole fighter with variable geometry intakes, realistic military illustration, isolated on white background, 1024x1024"),
    ("cold_spetsnaz", "Cold War Spetsnaz special forces operator, Soviet elite soldier with suppressed pistol and night vision goggle, realistic military illustration, isolated on white background, 1024x1024"),

    # Modern (19)
    ("mod_marine", "Modern US Marine Corps infantry squad, soldier with M4 carbine and AIM camo pattern, 2000s era, realistic military illustration, isolated on white background, 1024x1024"),
    ("mod_ranger", "Modern US Army Ranger elite infantry, advanced tactical gear with M4 rifle and optic sight, 2000s era, realistic military illustration, isolated on white background, 1024x1024"),
    ("mod_javelin", "Modern FGM-148 Javelin anti-tank missile team, soldier operating disposable launcher, 2000s era, realistic military illustration, isolated on white background, 1024x1024"),
    ("mod_stinger", "Modern FIM-92 Stinger portable air defense, soldier with shoulder-fired anti-air missile, 2000s era, realistic military illustration, isolated on white background, 1024x1024"),
    ("mod_hummer_tow", "Modern HMMWV with TOW anti-tank missile launcher, American Humvee mounted platform, 2000s era, realistic military illustration, isolated on white background, 1024x1024"),
    ("mod_hummer_m2", "Modern HMMWV with M2HB heavy machine gun, American 4x4 tactical vehicle gun truck, 2000s era, realistic military illustration, isolated on white background, 1024x1024"),
    ("mod_m1a1", "Modern M1A1 Abrams main battle tank, American MBT with composite armor and 120mm gun, 1990s era, realistic military illustration, isolated on white background, 1024x1024"),
    ("mod_m1a2", "Modern M1A2 Abrams SEP main battle tank, upgraded US MBT with thermal viewer and digital systems, 2000s era, realistic military illustration, isolated on white background, 1024x1024"),
    ("mod_t90", "Modern T-90 main battle tank, Russian MBT with Kontakt-5 ERA and 125mm gun, 1990s era, realistic military illustration, isolated on white background, 1024x1024"),
    ("mod_leo2a6", "Modern Leopard 2A6 main battle tank, German MBT with long 120mm L/55 gun, NATO forces, realistic military illustration, isolated on white background, 1024x1024"),
    ("mod_challenger2", "Modern Challenger 2 main battle tank, British MBT with Dorchester Tier 2 armor and 120mm L30 gun, realistic military illustration, isolated on white background, 1024x1024"),
    ("mod_ah64", "Modern AH-64 Apache attack helicopter, American twin-turboshaft armed helicopter with coaxial twin rotors and TADS/PNVS, realistic military illustration, isolated on white background, 1024x1024"),
    ("mod_ah1", "Modern AH-1 Cobra attack helicopter, American single-engine attack helicopter with tandem cockpit, realistic military illustration, isolated on white background, 1024x1024"),
    ("mod_uh60", "Modern UH-60 Black Hawk utility helicopter, American four-blade rotor tactical airlift aircraft, realistic military illustration, isolated on white background, 1024x1024"),
    ("mod_stryker_mgs", "Modern Stryker M10 Gun System, American 8x8 wheeled armored vehicle with 105mm gun turret, realistic military illustration, isolated on white background, 1024x1024"),
    ("mod_stryker_m2", "Modern Stryker M2 Infantry Carrier Vehicle, American 8x8 wheeled APC with remote weapon station, realistic military illustration, isolated on white background, 1024x1024"),
    ("mod_m270", "Modern M270 MLRS rocket launcher, American multiple launch rocket system on tracked chassis, 1980s era, realistic military illustration, isolated on white background, 1024x1024"),
    ("mod_m6", "Modern M6 Linebacker self-propelled AA, American radar-guided quad 40mm Bofors on M48 chassis, realistic military illustration, isolated on white background, 1024x1024"),

    # Future (14)
    ("fut_swarm", "Future autonomous drone swarm unit, compact quadcopter combat drone with micro-missiles, 2050s military tech, realistic military illustration, isolated on white background, 1024x1024"),
    ("fut_scout_drone", "Future tactical reconnaissance UAV, sleek fixed-wing drone with gimbal camera pod, 2040s military, realistic military illustration, isolated on white background, 1024x1024"),
    ("fut_attack_drone", "Future armed combat UAV, stealthy loitering munition with wing-mounted precision missiles, 2040s military, realistic military illustration, isolated on white background, 1024x1024"),
    ("fut_cyborg", "Future cybernetically enhanced infantry soldier, powered exoskeleton suit with neural interface helmet, 2060s military, realistic military illustration, isolated on white background, 1024x1024"),
    ("fut_heavy_trooper", "Future heavy powered armor trooper, massively augmented soldier with shoulder-mounted cannon, 2060s military, realistic military illustration, isolated on white background, 1024x1024"),
    ("fut_scout_mech", "Future light reconnaissance bipedal mech, agile two-legged combat walker with sensor mast, 2060s military, realistic military illustration, isolated on white background, 1024x1024"),
    ("fut_assault_mech", "Future medium assault bipedal mech, two-legged combat platform with integrated autocannon, 2060s military, realistic military illustration, isolated on white background, 1024x1024"),
    ("fut_heavy_mech", "Future heavy bipedal combat mech, towering two-legged war machine with layered armor and missile pods, 2060s military, realistic military illustration, isolated on white background, 1024x1024"),
    ("fut_hovertank", "Future anti-gravity hover tank, trackless armored vehicle with magnetic levitation and plasma cannon, 2050s military, realistic military illustration, isolated on white background, 1024x1024"),
    ("fut_howitzer", "Future electromagnetic rail howitzer, floating artillery platform with glowing accelerator barrel, 2050s military, realistic military illustration, isolated on white background, 1024x1024"),
    ("fut_prism", "Future Prism energy tank, armored vehicle with crystalline focusing array and refractive beam weapon, 2050s military, realistic military illustration, isolated on white background, 1024x1024"),
    ("fut_aa_hover", "Future point-defense anti-air platform, floating turret with phased-array laser emitters, 2050s military, realistic military illustration, isolated on white background, 1024x1024"),
    ("fut_stealth_bomber", "Future stealth strategic bomber, flying-wing design with internal bay and plasma exhaust, 2050s military, realistic military illustration, isolated on white background, 1024x1024"),
    ("fut_space_fighter", "Future space superiority fighter, dual-mode atmospheric/orbital craft with vectoring nozzles, 2050s military, realistic military illustration, isolated on white background, 1024x1024"),
    ("fut_spectre", "Future adaptive camouflage operative, stealth-special forces soldier with active camo field generator, 2060s military, realistic military illustration, isolated on white background, 1024x1024"),
    ("fut_nano_drone", "Future nano-repair drone, small autonomous maintenance platform with directed energy healer beam, 2050s military, realistic military illustration, isolated on white background, 1024x1024"),
    ("fut_shield", "Future portable energy shield generator, hexagonal force field projector with power cell backpack, 2050s military, realistic military illustration, isolated on white background, 1024x1024"),
    ("fut_colossus", "Future colossus heavy siege mech, massive quadrupedal walking fortress with siege cannon, 2060s boss unit, realistic military illustration, isolated on white background, 1024x1024"),
    ("fut_stormcore", "Future storm core experimental platform, unstable energy weapon prototype with swirling plasma containment, 2060s military, realistic military illustration, isolated on white background, 1024x1024"),
]

def generate_one(card_id, prompt):
    """Generate single image and save to disk."""
    data = json.dumps({
        "model": "agnes-image-2.0-flash",
        "prompt": prompt,
        "image_size": "1024x1024",
    }).encode("utf-8")

    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json"
    }

    req = urllib.request.Request(BASE_URL, data=data, headers=headers)
    with urllib.request.urlopen(req, timeout=300) as resp:
        result = json.loads(resp.read().decode("utf-8"))

    if "data" in result and len(result["data"]) > 0:
        item = result["data"][0]
        img_url = item.get("url")
        if img_url and "http" in str(img_url):
            img_req = urllib.request.Request(img_url, headers={"User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(img_req, timeout=60) as img_resp:
                img_data = img_resp.read()
            output_path = os.path.join(OUTPUT_DIR, f"{card_id}.png")
            with open(output_path, "wb") as f:
                f.write(img_data)
            return True, len(img_data)
    return False, "No URL"


def main():
    total = len(CARDS)
    success = 0
    failed = 0
    skipped = 0

    for i, (card_id, prompt) in enumerate(CARDS):
        path = os.path.join(OUTPUT_DIR, f"{card_id}.png")
        if os.path.exists(path):
            print(f"[{i+1}/{total}] SKIP: {card_id} (exists)")
            skipped += 1
            continue

        print(f"[{i+1}/{total}] Generating: {card_id}...", end=" ", flush=True)
        ok, detail = generate_one(card_id, prompt)
        if ok:
            success += 1
            print(f"OK ({int(detail/1024)}KB)")
        else:
            failed += 1
            print(f"FAIL: {detail}")

        if i < total - 1:
            time.sleep(3)

    print()
    print("=" * 50)
    print(f"Generated: {success}")
    print(f"Failed: {failed}")
    print(f"Skipped (existing): {skipped}")
    print(f"Total processed: {total}")


if __name__ == "__main__":
    main()
