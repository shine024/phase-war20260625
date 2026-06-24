#!/usr/bin/env python3
"""补充1 19张敌人精灵图重新生成 (512x512)"""
import os
import time
import requests

# 读API key
config_path = os.path.expanduser("~/.hermes/config.yaml")
with open(config_path, "rb") as f:
    raw = f.read()
idx = raw.find(b"sk-thp")
end = raw.find(b"\n", idx)
key_line = raw[idx:end].decode("utf-8", errors="replace").strip()
API_KEY = key_line.split(":")[-1].strip().strip("'\"")

BASE_URL = "https://apihub.agnes-ai.com/v1"

STRICT_PREFIX = (
    "STRICTLY a pure 2D side profile silhouette view, absolutely NO front view, "
    "NO three-quarter view, NO perspective depth, flat orthographic game sprite, "
    "single subject only centered, clean pure white background with NO ground, "
    "NO shadow, NO floor, NO reflection, NO watermark, NO signature, NO text, "
    "NO extra sketches, NO character faces visible, NO environment, "
    "studio isolated product shot style. "
)

TARGET_DIR = r"F:\godot fair duet\create\phase-war\assets\card_icons\补充1"
TARGET_SIZE = (512, 512)

# 19张图的名字 -> 描述 (参照精灵图风格：科幻硬表面、低饱和、蓝色能量发光)
PROMPTS = {
    "enemy_ww1_enfield.png": (
        "enemy_ww1_enfield (【一战·基础】恩菲尔德步枪兵) "
        "sci-fi hard-surface mechanical infantry, carrying an Enfield rifle with mechanical modifications, "
        "moderate armor plating on shoulders and chest, weathered metal texture, "
        "low-saturation khaki gray main color, blue energy glow on weapon sight, "
        "clean white background, no ground, no shadow, 1024x1024"
    ),
    "enemy_ww1_mauser.png": (
        "enemy_ww1_mauser (【一战·基础】毛瑟步枪兵) "
        "sci-fi hard-surface mechanical infantry, carrying a Mauser rifle with bolt-action mechanical upgrade, "
        "light armor with leather straps and ammo pouches, riveted joints visible, "
        "low-saturation earth brown main color, blue energy glow on rifle barrel tip, "
        "clean white background, no ground, no shadow, 1024x1024"
    ),
    "enemy_ww1_m76.png": (
        "enemy_ww1_m76 (【一战·基础】M76掷弹兵) "
        "sci-fi hard-surface grenadier infantry, shoulder-mounted grenade launcher with mechanical targeting arm, "
        "heavy shoulder pads, reinforced leg braces, ammunition belt across chest, "
        "low-saturation olive drab main color, blue energy glow on launcher muzzle, "
        "clean white background, no ground, no shadow, 1024x1024"
    ),
    "enemy_ww1_m81.png": (
        "enemy_ww1_m81 (【一战·支援】M81火焰兵) "
        "sci-fi hard-surface flamethrower infantry, backpack-mounted fuel tank with articulated nozzle arm, "
        "heat-resistant armor plating, thick gloves and boots, pressure gauge on chest, "
        "low-saturation rust gray main color, blue energy glow on fuel ignition point, "
        "clean white background, no ground, no shadow, 1024x1024"
    ),
    "enemy_ww1_vickers.png": (
        "enemy_ww1_vickers (【一战·阵地】维克斯机枪组) "
        "sci-fi hard-surface Vickers machine gun emplacement, tripod-mounted heavy machine gun with armored shield, "
        "ammo box on side, cooling jacket with vent fins, reinforced base plate, "
        "low-saturation steel gray main color, blue energy glow on cooling vents, "
        "clean white background, no ground, no shadow, 1024x1024"
    ),
    "enemy_ww2_bazooka.png": (
        "enemy_ww2_bazooka (【二战·支援】巴祖卡反坦克组) "
        "sci-fi hard-surface bazooka anti-tank infantry, shoulder-fired rocket launcher with mechanical aiming bracket, "
        "light combat vest, rocket pods on back, reinforced arm guard, "
        "low-saturation olive green main color, blue energy glow on rocket warhead, "
        "clean white background, no ground, no shadow, 1024x1024"
    ),
    "enemy_ww2_garand.png": (
        "enemy_ww2_garand (【二战·基础】加兰德半自动步枪兵) "
        "sci-fi hard-surface mechanical infantry, carrying a Garand semi-automatic rifle with gas-tube mechanism, "
        "M1 helmet with mechanical neck support, field vest with en-bloc clip holder, "
        "low-saturation olive drab main color, blue energy glow on rifle action, "
        "clean white background, no ground, no shadow, 1024x1024"
    ),
    "enemy_ww2_kingtiger.png": (
        "enemy_ww2_kingtiger (【二战·Boss】虎王坦克) "
        "sci-fi hard-surface super-heavy tank platform, thick sloped frontal armor, long-barrel main gun, "
        "wide tracks with road wheels, overlapping armor plates, hydraulic suspension visible, "
        "low-saturation steel gray-green main color, blue energy glow on engine exhaust and turret ring, "
        "clean white background, no ground, no shadow, 1024x1024"
    ),
    "enemy_ww2_m81.png": (
        "enemy_ww2_m81 (【二战·基础】M81装甲掷弹兵) "
        "sci-fi hard-surface armored infantry, modular composite armor with integrated rifle mount, "
        "radio pack on shoulder, tactical bayonet attachment, reinforced knee pads, "
        "low-saturation desert tan main color, blue energy glow on radio antenna, "
        "clean white background, no ground, no shadow, 1024x1024"
    ),
    "enemy_ww2_mp40.png": (
        "enemy_ww2_mp40 (【二战·基础】MP40冲锋枪手) "
        "sci-fi hard-surface submachine gunner, MP40 with mechanical folding stock upgrade, "
        "compact armor vest, drum magazine on hip, tactical goggles on helmet, "
        "low-saturation dark gray main color, blue energy glow on magazine feed, "
        "clean white background, no ground, no shadow, 1024x1024"
    ),
    "enemy_ww2_ppsh.png": (
        "enemy_ww2_ppsh (【二战·基础】PPSh-41冲锋枪手) "
        "sci-fi hard-surface submachine gunner, Soviet PPSh-41 with enhanced barrel cooling shroud, "
        "heavy winter combat gear with mechanical heating elements, drum mag, field pack, "
        "low-saturation military green-gray main color, blue energy glow on heating coils, "
        "clean white background, no ground, no shadow, 1024x1024"
    ),
    "enemy_ww2_thompson.png": (
        "enemy_ww2_thompson (【二战·基础】汤普森冲锋枪手) "
        "sci-fi hard-surface Thompson submachine gunner, top-feed magazine with mechanical spring assist, "
        "leather combat harness upgraded with polymer plates, forearm guard, "
        "low-saturation blued steel gray main color, blue energy glow on magazine base, "
        "clean white background, no ground, no shadow, 1024x1024"
    ),
    "enemy_cold_rpg.png": (
        "enemy_cold_rpg (【冷战·支援】RPG-7反坦克组) "
        "sci-fi hard-surface RPG-7 anti-tank infantry, shoulder-mounted rocket launcher with optical sight arm, "
        "moderate body armor, rocket rounds on back rack, reinforced boot soles, "
        "low-saturation sand gray main color, blue energy glow on rocket fuse, "
        "clean white background, no ground, no shadow, 1024x1024"
    ),
    "enemy_cold_sam7.png": (
        "enemy_cold_sam7 (【冷战·阵地】SA-7防空组) "
        "sci-fi hard-surface SA-7 surface-to-air missile launcher, shoulder-fired SAM with tracking dish array, "
        "missile pod on back, radar warning receiver on chest, field communications pack, "
        "low-saturation woodland green main color, blue energy glow on tracking dish, "
        "clean white background, no ground, no shadow, 1024x1024"
    ),
    "enemy_cold_spetsnaz.png": (
        "enemy_cold_spetsnaz (【冷战·精英】特种部队) "
        "sci-fi hard-surface elite Spetsnaz operator, lightweight tactical armor with integrated comms, "
        "suppressed assault rifle with modular attachments, night vision mount, compact utility harness, "
        "low-saturation deep charcoal main color, blue energy glow on NVG sensor, "
        "clean white background, no ground, no shadow, 1024x1024"
    ),
    "enemy_modern_javelin.png": (
        "enemy_modern_javelin (【现代·支援】标枪反坦克组) "
        "sci-fi hard-surface Javelin ATGM team, shoulder-launched guided missile with thermal imager sight, "
        "modular plate carrier, missile canister on back, laser rangefinder on arm, "
        "low-saturation coyote brown main color, blue energy glow on thermal scope, "
        "clean white background, no ground, no shadow, 1024x1024"
    ),
    "enemy_modern_ranger.png": (
        "enemy_modern_ranger (【现代·基础】游骑兵) "
        "sci-fi hard-surface modern Ranger infantry, modular exoskeleton armor with rifle sling mount, "
        "advanced comms headset, multi-tool harness, ballistic thigh protector, "
        "low-saturation ranger green main color, blue energy glow on exo-joint actuators, "
        "clean white background, no ground, no shadow, 1024x1024"
    ),
    "enemy_modern_stinger.png": (
        "enemy_modern_stinger (【现代·阵地】毒刺防空组) "
        "sci-fi hard-surface FIM-92 Stinger SAM operator, shoulder-fired infrared-seeking missile launcher, "
        "guided missile with seeker head dome, tactical vest with flare countermeasures, "
        "low-saturation woodland OD main color, blue energy glow on seeker dome, "
        "clean white background, no ground, no shadow, 1024x1024"
    ),
    "enemy_future_spectre.png": (
        "enemy_future_spectre (【近未来·精英】幽灵特工) "
        "sci-fi hard-surface cloaked special ops operative, adaptive camouflage paneling with light-bending surface, "
        "compact plasma rifle with phase-shifting barrel, holographic sight overlay, "
        "low-saturation deep gunmetal main color, blue energy glow on cloak nodes, "
        "clean white background, no ground, no shadow, 1024x1024"
    ),
}


def generate_single(prompt_text, output_name):
    """生成单张图片"""
    full_prompt = STRICT_PREFIX + prompt_text
    headers = {
        "Authorization": f"Bearer {API_KEY}",
        "Content-Type": "application/json",
    }
    payload = {
        "model": "agnes-image-2.0-flash",
        "prompt": full_prompt,
        "n": 1,
        "size": "1024x1024",
    }
    resp = requests.post(f"{BASE_URL}/images/generations", json=payload, headers=headers, timeout=120)
    if resp.status_code != 200:
        return False, f"HTTP {resp.status_code}: {resp.text[:200]}"
    data = resp.json()
    item = data.get("data", [{}])[0]
    img_url = item.get("url", "")
    if not img_url:
        b64 = item.get("b64_json", "")
        if b64:
            from PIL import Image
            from io import BytesIO
            img_data = bytes.fromhex(b64)
            img = Image.open(BytesIO(img_data)).convert('RGB')
            w, h = img.size
            arr = img.load()
            bg = arr[w//2, 0]
            alpha = Image.new('L', (w, h), 255)
            al = alpha.load()
            for y in range(h):
                for x in range(w):
                    r, g, b = arr[x, y]
                    if max(abs(r-bg[0]), abs(g-bg[1]), abs(b-bg[2])) <= 25:
                        al[x, y] = 0
            rgba = img.convert('RGBA')
            rgba.putalpha(alpha)
            rgba = rgba.resize((512, 512), Image.LANCZOS)
            out_path = os.path.join(TARGET_DIR, output_name)
            rgba.save(out_path, 'PNG')
            return True, output_name
        return False, f"No URL/b64 in response: {str(data)[:200]}"
    # 下载图片
    img_resp = requests.get(img_url, timeout=120)
    if img_resp.status_code != 200:
        return False, f"Download HTTP {img_resp.status_code}"
    # 后处理：抠图+缩放到512
    from PIL import Image
    from io import BytesIO
    img = Image.open(BytesIO(img_resp.content)).convert('RGB')
    # 白底抠图
    arr = img.load()
    w, h = img.size
    bg = arr[w//2, 0]  # 顶中取样背景色
    alpha = Image.new('L', (w, h), 255)
    al = alpha.load()
    for y in range(h):
        for x in range(w):
            r, g, b = arr[x, y]
            if max(abs(r-bg[0]), abs(g-bg[1]), abs(b-bg[2])) <= 25:
                al[x, y] = 0
    rgba = img.convert('RGBA')
    rgba.putalpha(alpha)
    rgba = rgba.resize((512, 512), Image.LANCZOS)
    out_path = os.path.join(TARGET_DIR, output_name)
    rgba.save(out_path, 'PNG')
    return True, output_name


def main():
    # 先清空补充1目录
    existing = [f for f in os.listdir(TARGET_DIR) if f.lower().endswith(('.png', '.jpg', '.jpeg', '.bmp'))]
    for f in existing:
        p = os.path.join(TARGET_DIR, f)
        os.remove(p)
        imp = p + '.import'
        if os.path.exists(imp):
            os.remove(imp)
    print(f"已清空 {len(existing)} 个旧文件")

    success = 0
    fail = 0
    names = list(PROMPTS.keys())
    for i, (name, prompt) in enumerate(PROMPTS.items()):
        print(f"[{i+1}/{len(names)}] 生成 {name}...")
        ok, msg = generate_single(prompt, name)
        if ok:
            print(f"  OK: {msg}")
            success += 1
        else:
            print(f"  FAIL: {msg}")
            fail += 1
        time.sleep(3)  # 间隔3秒

    print(f"\n完成: 成功={success}, 失败={fail}")


if __name__ == '__main__':
    main()
