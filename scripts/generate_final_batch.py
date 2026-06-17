"""
Final batch: Generate remaining Modern and Future card icons.

Remaining: 16 Modern + 14 Future = 30 cards
"""
import os, json, urllib.request, urllib.error, time

BASE_URL = "https://apihub.agnes-ai.com/v1/images/generations"
OUTPUT_DIR = r"F:\godot fair duet\create\phase-war\assets\card_icons"

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
    print("ERROR: No API key!")
    exit(1)

CARDS = [
    # Modern remaining (16)
    ("mod_stinger", "Modern FIM-92 Stinger portable air defense, soldier with shoulder-fired anti-air missile launcher, 2000s era, realistic military illustration, isolated on white background, 1024x1024"),
    ("mod_hummer_tow", "Modern HMMWV with TOW anti-tank missile launcher, American Humvee mounted platform, 2000s era, realistic military illustration, isolated on white background, 1024x1024"),
    ("mod_hummer_m2", "Modern HMMWV with M2HB heavy machine gun, American 4x4 tactical vehicle gun truck, 2000s era, realistic military illustration, isolated on white background, 1024x1024"),
    ("mod_m1a1", "Modern M1A1 Abrams main battle tank, American MBT with composite armor and 120mm gun, 1990s era, realistic military illustration, isolated on white background, 1024x1024"),
    ("mod_m1a2", "Modern M1A2 Abrams SEP main battle tank, upgraded US MBT with thermal viewer and digital systems, 2000s era, realistic military illustration, isolated on white background, 1024x1024"),
    ("mod_t90", "Modern T-90 main battle tank, Russian MBT with Kontakt-5 explosive armor and 125mm gun, 1990s era, realistic military illustration, isolated on white background, 1024x1024"),
    ("mod_leo2a6", "Modern Leopard 2A6 main battle tank, German MBT with long 120mm L/55 gun, NATO forces, realistic military illustration, isolated on white background, 1024x1024"),
    ("mod_challenger2", "Modern Challenger 2 main battle tank, British MBT with Dorchester Tier 2 armor and 120mm L30 gun, realistic military illustration, isolated on white background, 1024x1024"),
    ("mod_ah64", "Modern AH-64 Apache attack helicopter, American twin-turboshaft armed helicopter with stub wings and missiles, realistic military illustration, isolated on white background, 1024x1024"),
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
    for attempt in range(3):
        try:
            data = json.dumps({"model": "agnes-image-2.0-flash", "prompt": prompt, "image_size": "1024x1024"}).encode("utf-8")
            headers = {"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"}
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
        except Exception as e:
            if attempt < 2:
                time.sleep(15 * (attempt + 1))
            else:
                return False, str(e)

def main():
    total = len(CARDS)
    success = failed = skipped = 0

    for i, (card_id, prompt) in enumerate(CARDS):
        path = os.path.join(OUTPUT_DIR, f"{card_id}.png")
        if os.path.exists(path):
            print(f"[{i+1}/{total}] SKIP: {card_id}")
            skipped += 1
            continue

        print(f"[{i+1}/{total}] {card_id}...", end=" ", flush=True)
        ok, detail = generate_one(card_id, prompt)
        if ok:
            success += 1
            print(f"OK ({int(detail/1024)}KB)")
        else:
            failed += 1
            print(f"FAIL: {detail}")
        time.sleep(5)

    print(f"\n{'='*50}")
    print(f"Generated: {success}, Failed: {failed}, Skipped: {skipped}")

if __name__ == "__main__":
    main()
