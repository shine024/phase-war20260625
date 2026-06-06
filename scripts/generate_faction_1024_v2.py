#!/usr/bin/env python3
"""Batch generate 14 E-segment faction cards at 1024x1024 with new matte-painting style."""
import os, json, urllib.request, time, sys

# API config
config_path = os.path.expanduser("~/.hermes/config.yaml")
with open(config_path, "r", encoding="utf-8") as f:
    import yaml
    config = yaml.safe_load(f)

api_key = config["model"]["api_key"]
base_url = config["model"]["base_url"]
url = f"{base_url}/images/generations"
headers = {
    "Authorization": f"Bearer {api_key}",
    "Content-Type": "application/json"
}

output_dir = r"F:\godot fair duet\create\phase-war\docs\美术资源预览_重做"
os.makedirs(output_dir, exist_ok=True)

# Common suffix for all cards
COMMON = (
    "STRICT true side profile, full body, centered composition, facing left, "
    "solid chroma key green #00FF00 background ONLY, "
    "NO realistic human faces, NO real-world military insignia, "
    "NO text, NO watermark, "
    "1024x1024"
)

CARDS = [
    {
        "id": "vis_player_036",
        "name": "不朽堡垒",
        "desc": (
            "Fictional military fortification 不朽堡垒, massive concrete and steel bunker on heavy tracked platform, "
            "thick armor plating with weathered textures, scorch marks, and battle damage, "
            "multiple weapon emplacements on top, hydraulic elevators visible, "
            "detailed mechanical joints and gear assemblies, "
            "weathered steel gray with rust streaks and oil stains, "
            "matte painting style, complex lighting, cinematic rim light from top-left"
        ) + ", " + COMMON
    },
    {
        "id": "vis_player_037",
        "name": "重装先驱",
        "desc": (
            "Fictional military soldier 重装先驱, heavy armored assault trooper with reinforced exoskeleton frame, "
            "thick segmented armor plates with visible bolt heads and weld seams, "
            "large shoulder-mounted cannon with glowing power coils, "
            "detailed armor seams and hydraulic piston actuators, "
            "steel gray armor with heavy scuff marks and welding sparks on edges, "
            "matte painting style, complex lighting, cinematic rim light from top-left"
        ) + ", " + COMMON
    },
    {
        "id": "vis_player_038",
        "name": "歼灭者自行火炮",
        "desc": (
            "Fictional military vehicle 歼灭者自行火炮, heavy self-propelled howitzer on multi-wheeled tracked chassis, "
            "massive artillery barrel with dual muzzle brake, visible recoil mechanism beneath, "
            "armored cab with weathered paint and faded identification numbers, "
            "detailed suspension springs, drive shafts, and fuel tank, "
            "dull gray-green camouflage with chipped paint revealing primer, "
            "matte painting style, complex lighting, cinematic rim light from top-left"
        ) + ", " + COMMON
    },
    {
        "id": "vis_player_039",
        "name": "幽灵狙击组",
        "desc": (
            "Fictional military unit 幽灵狙击组, tactical sniper in advanced multi-spectral camouflage, "
            "long-range precision rifle with large optical sight array and rangefinder, "
            "backpack with communication array and thermal drone cell, "
            "detailed tactical webbing, fabric weave, and equipment pouches, "
            "dark olive drab with subtle thermal-optic camouflage patterns, "
            "matte painting style, complex lighting, cinematic rim light from top-left"
        ) + ", " + COMMON
    },
    {
        "id": "vis_player_040",
        "name": "以太骑兵",
        "desc": (
            "Fictional military unit 以太骑兵, futuristic armored rider on anti-gravity hover-cycle, "
            "sleek chrome-white motorcycle with glowing blue energy exhaust vents, "
            "rider in full articulated exoskeleton armor suit, "
            "detailed energy conduit lines, thruster nozzles, and joint segments, "
            "white armor with blue energy glow accents and weathered battle scarring, "
            "matte painting style, complex lighting, cinematic rim light from top-left"
        ) + ", " + COMMON
    },
    {
        "id": "vis_player_041",
        "name": "蜂群母机",
        "desc": (
            "Fictional military aircraft 蜂群母机, large aerial drone carrier with swept-wing flying wing design, "
            "open top cargo bay revealing smaller reconnaissance drones inside, "
            "detailed panel lines, access hatches, and weapon hardpoints, "
            "twin rear-mounted propulsion units with heat exhaust grilles, "
            "weathered silver-white with blue squadron markings and fuel staining, "
            "matte painting style, complex lighting, cinematic rim light from top-left"
        ) + ", " + COMMON
    },
    {
        "id": "vis_player_042",
        "name": "移动堡垒基地",
        "desc": (
            "Fictional military platform 移动堡垒基地, enormous mobile fortress command vehicle on heavy crawler tracks, "
            "multi-level superstructure with satellite dishes and rotating sensor array, "
            "visible cargo cranes and open repair bay hangar doors, "
            "detailed track links, suspension bogies, and engine exhaust, "
            "industrial gray with yellow warning stripes and faded company logos, "
            "matte painting style, complex lighting, cinematic rim light from top-left"
        ) + ", " + COMMON
    },
    {
        "id": "vis_player_043",
        "name": "纳米修复蜂群",
        "desc": (
            "Fictional military unit 纳米修复蜂群, central command drone with swarm of hexagonal repair drones, "
            "larger drone has rotating sensor dish and multi-directional repair beams, "
            "dozens of tiny hexagonal drones with glowing cyan repair laser emitters, "
            "detailed mechanical hexagonal bodies with solar panel surfaces and antenna tips, "
            "white and cyan color scheme with weathered repair tool details, "
            "matte painting style, complex lighting, cinematic rim light from top-left"
        ) + ", " + COMMON
    },
    {
        "id": "vis_player_044",
        "name": "幻影特工",
        "desc": (
            "Fictional military operative 幻影特工, covert reconnaissance agent in adaptive optical cloaking suit, "
            "stealth gear with prismatic refraction elements and sensor-dampening panels, "
            "compact weapon rig with suppressed sidearm and compact thermal goggles, "
            "detailed cloaking projector backpack with antenna array and power cells, "
            "dark gray tactical gear with subtle optical shimmer and matte black hardware, "
            "matte painting style, complex lighting, cinematic rim light from top-left"
        ) + ", " + COMMON
    },
    {
        "id": "vis_player_045",
        "name": "轨道打击引导组",
        "desc": (
            "Fictional military unit 轨道打击引导组, forward observer soldier with orbital targeting laser designator, "
            "shoulder-mounted targeting console with holographic display panel, "
            "backpack with parabolic satellite dish antenna and compact power generator, "
            "detailed cable management and connection ports on tactical vest, "
            "tactical gray uniform with worn patches and visible weapon sling, "
            "matte painting style, complex lighting, cinematic rim light from top-left"
        ) + ", " + COMMON
    },
    {
        "id": "vis_player_046",
        "name": "相位炮台",
        "desc": (
            "Fictional military weapon 相位炮台, automated phase-cannon turret on reinforced emplacement, "
            "massive orbital cannon barrel with visible energy capacitor rings, "
            "detailed hydraulic elevation mechanism and ammo feeding system beneath, "
            "armored protective housing with sensor turret on top, "
            "deep purple-black armor with glowing violet energy conduits and cooling vents, "
            "matte painting style, complex lighting, cinematic rim light from top-left"
        ) + ", " + COMMON
    },
    {
        "id": "vis_player_047",
        "name": "次元行者",
        "desc": (
            "Fictional military operative 次元行者, phase-shift tactical agent with dimensional displacement armor, "
            "semi-cloaked exoskeleton with visible phase-field distortion at edges, "
            "compact phased-energy pistol and tactical blade in sheath, "
            "detailed phase-field generator on back with energy coil windings, "
            "dark armor with violet-purple energy shimmer and crackling phase effects, "
            "matte painting style, complex lighting, cinematic rim light from top-left"
        ) + ", " + COMMON
    },
    {
        "id": "vis_player_048",
        "name": "边境老兵",
        "desc": (
            "Fictional military veteran 边境老兵, weathered frontier soldier in patched mixed-faction gear, "
            "rugged bolt-action scoped rifle held at port arms, revolver in worn leather holster, "
            "ammunition bandolier, mix of old bolt-action and newer tactical equipment, "
            "detailed worn combat boots, patched uniform, and battle-scarred gear, "
            "earthly brown and olive drab heavy wear with dirt, grime, and corrosion, "
            "matte painting style, complex lighting, cinematic rim light from top-left"
        ) + ", " + COMMON
    },
    {
        "id": "vis_player_049",
        "name": "混编突击队",
        "desc": (
            "Fictional military unit 混编突击队, combined-arms assault trooper with modular weapon system, "
            "heavy armor plate carrier with interchangeable attachment points, "
            "advanced assault rifle with under-barrel launcher and tactical optics, "
            "detailed grenade pouches, radio equipment, and integrated medical kit, "
            "olive drab and desert tan two-tone with mixed faction patches and insignia, "
            "matte painting style, complex lighting, cinematic rim light from top-left"
        ) + ", " + COMMON
    },
]

def generate_image(prompt):
    payload = {
        "model": "agnes-image-2.0-flash",
        "prompt": prompt,
        "image_size": "1024x1024"
    }
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(url, data=data, headers=headers, method="POST")
    with urllib.request.urlopen(req, timeout=300) as resp:
        result = json.loads(resp.read().decode("utf-8"))
        if "data" not in result or len(result["data"]) == 0:
            return None
        img_data = result["data"][0]
        if "url" in img_data:
            with urllib.request.urlopen(img_data["url"], timeout=60) as img_resp:
                return img_resp.read()
    return None

results = []
for i, card in enumerate(CARDS, 1):
    print(f"\n[{i}/{len(CARDS)}] {card['id']} - {card['name']}")
    png_data = generate_image(card["desc"])
    if png_data:
        path = os.path.join(output_dir, f"{card['id']}_预览.png")
        with open(path, "wb") as f:
            f.write(png_data)
        size = os.path.getsize(path)
        print(f"  OK: {path} ({size/1024:.0f}KB)")
        results.append((card["id"], card["name"], "OK", size))
    else:
        print(f"  FAILED")
        results.append((card["id"], card["name"], "FAIL", 0))
    if i < len(CARDS):
        time.sleep(3)

print(f"\n{'='*60}")
print(f"Batch complete: {sum(1 for r in results if r[2]=='OK')}/{len(results)} succeeded")
print(f"Output: {output_dir}")
for r in results:
    status = "OK" if r[2]=="OK" else "FAIL"
    print(f"  [{status:4s}] {r[0]} ({r[1]})")
