#!/usr/bin/env python3
"""Generate 8 enemy sprites in 补充1/ using filenames from 可用/ and prompts from 精灵图nano_banana2_enemy_prompts_36.md"""

import os, sys, json, time, requests, base64

config_path = os.path.expanduser("~/.hermes/config.yaml")
api_key = ""
base_url = "https://apihub.agnes-ai.com/v1"
with open(config_path, "rb") as f:
    raw = f.read().decode("utf-8", errors="ignore")
    idx = raw.find("sk-thp")
    if idx >= 0:
        line = raw[idx:].split("\n")[0]
        api_key = line.split('"')[1] if '"' in line else line.strip()

headers = {
    "Authorization": f"Bearer {api_key}",
    "Content-Type": "application/json",
}

STRICT_PREFIX = (
    "STRICTLY a pure 2D side profile silhouette view, absolutely NO front view, "
    "NO three-quarter view, NO perspective depth, flat orthographic game sprite, "
    "single subject only centered, clean pure white background with NO ground, "
    "NO shadow, NO floor, NO reflection, NO watermark, NO signature, NO text, "
    "NO extra sketches, NO character faces visible, NO environment, "
    "studio isolated product shot style. "
)

# Mapping: 可用/ filename -> (target_filename in 补充1/, prompt_text from 36-prompts spec)
FILES = [
    # (target_filename, prompt_text)
    ("enemy_ww1_m76.png",
     "enemy_ww1_infantry_basic（【一战·基础】步兵班·MP18） 严格2D正侧视（true profile side view），正交投影（orthographic projection），游戏单位立绘/精灵图姿态，科幻硬表面机械步兵设定图（hard-surface mech infantry concept art），以\"【一战·基础】步兵班·MP18\"为主体，完整单位居中入镜，轻型装甲步兵外骨骼、短枪管冲锋枪轮廓清晰，肩甲/护膝/弹药包/机械关节细节丰富，金属磨损旧化（scratches, weathering），低饱和军绿与泥土灰主色，局部蓝色能量指示灯发光作为视觉焦点，干净棚拍纯白背景（white background），无地面无场景无杂物，高清。"),

    ("enemy_ww1_105mm.png",
     "enemy_ww1_mortar（【一战·支援】迫击炮组） 严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，科幻硬表面火力支援单位设定图，以\"【一战·支援】迫击炮组\"为主体，完整单位居中入镜，短管迫击炮、底板、弹药架和辅助机械臂轮廓清晰，装甲外壳与液压连接件丰富，金属磨损旧化，低饱和灰绿主色，局部蓝色能量点火单元发光，干净棚拍纯白背景，无地面无场景无杂物，高清。"),

    ("enemy_ww1_mg08.png",
     "enemy_ww1_mg_nest（【一战·阵地】机枪巢） 严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，科幻硬表面防御阵地设定图，以\"【一战·阵地】机枪巢\"为主体，完整单位居中入镜，固定机枪座与装甲挡板、弹链箱与散热护罩清晰，支撑架和防盾结构明确，磨损和泥尘旧化明显，低饱和军绿灰主色，局部蓝色能量冷却模块发光，干净棚拍纯白背景，无地面无场景无杂物，高清。"),

    ("enemy_cold_rpg.png",
     "enemy_cold_btr（【冷战·基础】BTR装甲车） 严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，科幻硬表面轮式装甲载具设定图，以\"【冷战·基础】BTR装甲车\"为主体，完整单位居中入镜，车体装甲、轮组与炮位侧视轮廓清晰，分件与舱门细节丰富，磨损旧化，低饱和灰绿主色，局部蓝色能量指示灯发光，干净棚拍纯白背景，无地面无场景无杂物，高清。"),

    ("enemy_cold_m14.png",
     "enemy_cold_ak（【冷战·基础】苏军步兵） 严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，科幻硬表面机械步兵设定图，以\"【冷战·基础】苏军步兵\"为主体，完整单位居中入镜，突击步枪与模块化护甲轮廓清晰，头盔与胸甲分件明确，磨损旧化，低饱和灰绿主色，局部蓝色能量指示灯发光，干净棚拍纯白背景，无地面无场景无杂物，高清。"),

    ("enemy_modern_javelin.png",
     "enemy_modern_marine（【现代·基础】海军陆战队） 严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，科幻硬表面现代步兵设定图，以\"【现代·基础】海军陆战队\"为主体，完整单位居中入镜，模块化护甲与步枪轮廓清晰，腰挂装备与通信模块细节丰富，磨损旧化，低饱和灰绿主色，局部蓝色能量指示灯发光，干净棚拍纯白背景，无地面无场景无杂物，高清。"),

    ("enemy_future_howitzer.png",
     "enemy_future_drone（【近未来·基础】无人机群个体） 严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，科幻硬表面无人机设定图，以\"【近未来·基础】无人机群个体\"为主体，完整单位居中入镜，机体、推进单元、传感器轮廓清晰，硬表面分件与机械细节丰富，轻度磨损旧化，低饱和银灰主色，局部蓝色能量推进器发光，干净棚拍纯白背景，无地面无场景无杂物，高清。"),

    ("enemy_ww2_mp40.png",
     "enemy_ww2_infantry（【二战·基础】步兵班·汤普森） 严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，科幻硬表面机械步兵设定图，以\"【二战·基础】步兵班·汤普森\"为主体，完整单位居中入镜，中轻型装甲、冲锋枪与弹鼓轮廓清晰，护甲分层与工具包细节丰富，磨损旧化，低饱和橄榄绿主色，局部蓝色能量模块发光，干净棚拍纯白背景，无地面无场景无杂物，高清。"),
]

OUTPUT_DIR = r"F:\godot fair duet\create\phase-war\assets\card_icons\补充1"
os.makedirs(OUTPUT_DIR, exist_ok=True)

FAILED = []
SUCCESS = []

for i, (filename, prompt_text) in enumerate(FILES, 1):
    full_prompt = STRICT_PREFIX + prompt_text
    
    payload = {
        "model": "agnes-image-2.0-flash",
        "prompt": full_prompt,
        "n": 1,
        "size": "1024x1024",
    }
    
    url = f"{base_url}/images/generations"
    max_retries = 5
    success = False
    
    print(f"\n--- [{i}/{len(FILES)}] {filename} ---")
    
    for attempt in range(1, max_retries + 1):
        try:
            resp = requests.post(url, headers=headers, json=payload, timeout=180)
            resp.raise_for_status()
            data = resp.json()
            
            img_data = None
            
            if "data" in data and len(data["data"]) > 0:
                item = data["data"][0]
                if "url" in item and item["url"]:
                    img_resp = requests.get(item["url"], timeout=60)
                    img_resp.raise_for_status()
                    img_data = img_resp.content
                elif "b64_json" in item and item["b64_json"]:
                    img_data = base64.b64decode(item["b64_json"])
            
            if img_data:
                out_path = os.path.join(OUTPUT_DIR, filename)
                with open(out_path, "wb") as fout:
                    fout.write(img_data)
                SUCCESS.append(filename)
                print(f"OK: {filename} ({len(img_data):,} bytes)")
                success = True
                break
            else:
                print(f"No image in response (attempt {attempt}): {json.dumps(data)[:300]}")
        except Exception as e:
            print(f"Error attempt {attempt}: {e}")
            if attempt < max_retries:
                time.sleep(8 * attempt)
    
    if not success:
        FAILED.append(filename)
        print(f"FAILED: {filename}")
    
    if i < len(FILES):
        time.sleep(5)

print(f"\n{'='*60}")
print(f"Summary: Success={len(SUCCESS)}, Failed={len(FAILED)}, Total={len(FILES)}")
if FAILED:
    print(f"\nFailed files:")
    for f in FAILED:
        print(f"  - {f}")
if SUCCESS:
    print(f"\nSuccess files:")
    for f in SUCCESS:
        print(f"  + {f}")
