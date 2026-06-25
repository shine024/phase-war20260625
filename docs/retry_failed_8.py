#!/usr/bin/env python3
"""Retry script for 8 failed enemy sprites."""

import os, sys, json, time, requests, base64

# --- Read API key from config ---
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

# The 8 failed files with their prompts
FAILED_PROMPTS = [
    ("enemy_ww1_mortar.png",
     "enemy_ww1_mortar（【一战·支援】迫击炮组） 严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，科幻硬表面火力支援单位设定图，以\"【一战·支援】迫击炮组\"为主体，完整单位居中入镜，短管迫击炮、底板、弹药架和辅助机械臂轮廓清晰，装甲外壳与液压连接件丰富，金属磨损旧化，低饱和灰绿主色，局部蓝色能量点火单元发光，干净棚拍纯白背景，无地面无场景无杂物，高清。"),
    
    ("elite_ww1_armored.png",
     "elite_ww1_armored（【一战·精英】装甲车） 严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，科幻硬表面装甲载具设定图，以\"【一战·精英】装甲车\"为主体，完整单位居中入镜，厚重车体、履带与负重轮侧视轮廓清晰，前装甲斜面与机枪塔明确，分件和焊缝细节丰富，磨损旧化，低饱和冷灰主色，局部蓝色能量指示灯发光，干净棚拍纯白背景，无地面无场景无杂物，高清。"),
    
    ("boss_ww1_av7.png",
     "boss_ww1_av7（【一战·Boss】圣沙蒙坦克平台） 严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，科幻硬表面重型坦克设定图，以\"【一战·Boss】圣沙蒙坦克平台\"为主体，完整单位居中入镜，超厚装甲、长履带、炮塔与副武器位清晰，机械关节/装甲分件/铆钉/液压细节丰富，重度磨损旧化，低饱和冷灰主色，局部蓝色能量核心发光作为视觉焦点，干净棚拍纯白背景，无地面无场景无杂物，高清。"),
    
    ("enemy_ww2_panzerschreck.png",
     "enemy_ww2_panzerschreck（【二战·支援】反坦克组） 严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，科幻硬表面反装甲火力单位设定图，以\"【二战·支援】反坦克组\"为主体，完整单位居中入镜，肩扛反坦克发射器与弹药筒轮廓清晰，护甲与固定支撑结构明确，磨损旧化，低饱和军绿灰主色，局部蓝色能量点火指示灯发光，干净棚拍纯白背景，无地面无场景无杂物，高清。"),
    
    ("elite_ww2_paratrooper.png",
     "elite_ww2_paratrooper（【二战·精英】伞兵精英） 严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，科幻硬表面精英步兵设定图，以\"【二战·精英】伞兵精英\"为主体，完整单位居中入镜，轻量化装甲与伞兵背负组件、突击武器轮廓清晰，结构分件明确，磨损旧化，低饱和军绿主色，局部蓝色能量信标发光，干净棚拍纯白背景，无地面无场景无杂物，高清。"),
    
    ("boss_ww2_kingtiger.png",
     "boss_ww2_kingtiger（【二战·Boss】虎王坦克平台） 严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，科幻硬表面超重型坦克设定图，以\"【二战·Boss】虎王坦克平台\"为主体，完整单位居中入镜，超厚前装甲、长炮塔、履带侧视轮廓严格清晰，重型机械分件与铆钉液压细节密集，重度磨损旧化，低饱和钢灰与军绿主色，局部蓝色能量核心发光，干净棚拍纯白背景，无地面无场景无杂物，高清。"),
    
    ("enemy_modern_mlrs.png",
     "enemy_modern_mlrs（【现代·阵地】火箭炮车） 严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，科幻硬表面远程火力平台设定图，以\"【现代·阵地】火箭炮车\"为主体，完整单位居中入镜，火箭发射箱、承载底盘与稳定结构侧视轮廓清晰，机械分件细节丰富，磨损旧化，低饱和军灰主色，局部蓝色能量瞄准模块发光，干净棚拍纯白背景，无地面无场景无杂物，高清。"),
    
    ("elite_future_colossus.png",
     "elite_future_colossus（【近未来·精英】巨神机甲） 严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，科幻硬表面重型机甲设定图，以\"【近未来·精英】巨神机甲\"为主体，完整单位居中入镜，厚重机甲躯干、重装甲四肢与主炮轮廓清晰，机械关节/装甲分件/液压细节丰富，重度磨损旧化，低饱和钛灰主色，局部蓝色能量核心发光，干净棚拍纯白背景，无地面无场景无杂物，高清。"),
]

OUTPUT_DIR = r"F:\godot fair duet\create\phase-war\assets\card_icons\补充1"
os.makedirs(OUTPUT_DIR, exist_ok=True)

SUCCESS = []
FAILED = []

for i, (filename, prompt_text) in enumerate(FAILED_PROMPTS, 1):
    full_prompt = STRICT_PREFIX + prompt_text
    
    payload = {
        "model": "agnes-image-2.0-flash",
        "prompt": full_prompt,
        "n": 1,
        "size": "1024x1024",
    }
    
    url = f"{base_url}/images/generations"
    max_retries = 5  # More retries for retry script
    success = False
    
    print(f"\n--- Retry [{i}/{len(FAILED_PROMPTS)}] {filename} ---")
    
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
    
    if i < len(FAILED_PROMPTS):
        time.sleep(5)

print(f"\n{'='*60}")
print(f"Retry Summary: Success={len(SUCCESS)}, Failed={len(FAILED)}")
if FAILED:
    print(f"\nStill failed:")
    for f in FAILED:
        print(f"  - {f}")
