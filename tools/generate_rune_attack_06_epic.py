"""
生成精准符文 (attack_06) 的正确图标 - 替换 epic 文件夹中的错误风格版本。

精准符文信息：
  - id: attack_06
  - 名称: 精准
  - 类别: attack
  - 稀有度: epic
  - 效果: 命中率 +25%, 攻击力 +12%
  - 颜色: crimson red (#ff2244)
  - 形状: 向上三角形 + 中心竖线
  - 环数: 3 (epic = 3 rings)

现有 epic/rune_attack_06.png 是带金色画框的方形卡牌风格，与整体圆形石质魔法封印风格不符。
本脚本生成符合规范的圆形符文图标，并部署到 assets/runes/epic/ 目录。
"""

import requests, json, os, sys, time

API_KEY = os.environ.get("AGNES_API_KEY", "")
if not API_KEY:
    # 尝试从 tools/_api_key.txt 读取
    try:
        with open("tools/_api_key.txt", "r") as f:
            API_KEY = f.read().strip()
    except:
        raise SystemExit("AGNES_API_KEY 未设置，且 tools/_api_key.txt 不存在。")

BASE_URL = "https://apihub.agnes-ai.com/v1"

# 精准符文配置
RUNE = {
    "id": "attack_06",
    "name": "精准",
    "category": "attack",
    "color": "crimson red",
    "color_hex": "#ff2244",
    "shape_desc": "a bold triangle pointing upward with a vertical line cutting through the center",
}

RARITY = {
    "name": "epic",
    "glow": "strong",
    "bg": "dark purple #1a0a2e",
}

OUTPUT_DIR = r"F:\godot fair duet\create\phase-war\assets\runes\epic"
OUTPUT_FILE = os.path.join(OUTPUT_DIR, "rune_attack_06.png")
DRAFT_DIR = r"F:\godot fair duet\create\phase-war\docs\rune_attack_06_draft"
os.makedirs(DRAFT_DIR, exist_ok=True)
DRAFT_FILE = os.path.join(DRAFT_DIR, "rune_attack_06_epic.png")


def generate_prompt(rune, rarity):
    """生成与 generate_rune_icons.py 完全一致的 prompt（Plan2 Magic Seal 风格）"""
    plan_prefix = "Plan2_Magic_Seal_Rune,"
    return f"""{plan_prefix}
A single RPG rune icon for "{rune['name']}" ({rune['id']}),
{rune['shape_desc']},
monochromatic {rune['color']} color scheme ({rune['color_hex']}),
dark circular background ({rarity['bg']}),
{rarity['glow']} neon glow on edges,
magic seal style with concentric circular bands, wedge-shaped notches on rings,
dot markers and short dash lines distributed on the rings,
central core symbol ({rune['shape_desc']}),
stone or metal texture on the rings,
glowing magical energy emanating from center,
tiered ring design: 3 rings for epic,
high contrast, sharp edges, flat vector style,
no borders, no frames, no watermarks, no text,
centered composition, 1024x1024px square canvas"""


def call_api(prompt):
    """调用 agnes-image-2.0-flash API 生成图片"""
    payload = {
        "model": "agnes-image-2.0-flash",
        "prompt": prompt,
        "image_size": "1024x1024"
    }
    headers = {
        "Authorization": f"Bearer {API_KEY}",
        "Content-Type": "application/json"
    }
    
    print(f"正在生成 {RUNE['name']} ({RUNE['id']}) epic 符文图标...")
    resp = requests.post(f"{BASE_URL}/images/generations", json=payload, headers=headers, timeout=120)
    data = resp.json()
    
    if resp.status_code == 200 and data.get("data") and data["data"][0].get("url"):
        img_url = data["data"][0]["url"]
        print(f"API 返回图片 URL，正在下载...")
        img_resp = requests.get(img_url)
        if img_resp.status_code == 200:
            return img_resp.content
        else:
            raise SystemExit(f"下载失败: HTTP {img_resp.status_code}")
    else:
        raise SystemExit(f"API 调用失败: HTTP {resp.status_code}, 响应: {str(data)[:500]}")


def resize_to_995(raw_data, output_path):
    """
    将 1024x1024 缩放到 995x995（与项目其他符文图标一致）。
    需要 PIL。如果没有 PIL，保持 1024x1024 原尺寸。
    """
    try:
        from PIL import Image
        from io import BytesIO
        img = Image.open(BytesIO(raw_data))
        if img.size == (1024, 1024):
            img = img.resize((995, 995), Image.LANCZOS)
            img.save(output_path, "PNG")
            print(f"已缩放至 995x995: {output_path}")
        else:
            # 如果不是 1024，直接保存
            with open(output_path, "wb") as f:
                f.write(raw_data)
            print(f"原始尺寸 {img.size}，直接保存: {output_path}")
    except ImportError:
        print("PIL 未安装，保持 1024x1024 原尺寸")
        with open(output_path, "wb") as f:
            f.write(raw_data)


def main():
    prompt = generate_prompt(RUNE, RARITY)
    print(f"Prompt:\n{prompt}\n")
    
    try:
        raw_data = call_api(prompt)
        
        # 保存草稿到 docs/ 供审核
        with open(DRAFT_FILE, "wb") as f:
            f.write(raw_data)
        print(f"草稿已保存: {DRAFT_FILE}")
        
        # 部署到 assets/runes/epic/（缩放到 995x995）
        resize_to_995(raw_data, OUTPUT_FILE)
        print(f"\n部署完成: {OUTPUT_FILE}")
        
        # 验证文件大小
        size = os.path.getsize(OUTPUT_FILE)
        print(f"文件大小: {size / 1024:.1f} KB")
        
    except Exception as e:
        print(f"\n错误: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
