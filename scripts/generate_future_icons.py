"""
Last batch: Generate remaining Future card icons (11 cards).
"""
import os, json, urllib.request, time

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

CARDS = [
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
