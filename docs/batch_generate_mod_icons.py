#!/usr/bin/env python3
"""
批量生成改造模块图标 (512x512 PNG)
- 从 config.yaml 读取 agnes API key
- 使用 SVG 风格描述生成图标
- 输出到 assets/ui/icons/mod_icons/
"""

import json
import os
import sys
import yaml
import urllib.request
import ssl

# === 配置 ===
PROJECT_DIR = "F:/godot fair duet/create/phase-war"
CONFIG_PATH = "C:/Users/jianchang.tan/.hermes/config.yaml"
PROMPTS_PATH = os.path.join(PROJECT_DIR, "docs", "mod_icon_prompts.json")
OUTPUT_DIR = os.path.join(PROJECT_DIR, "assets", "ui", "icons", "mod_icons")

# 批量参数
BATCH_SIZE = 4  # 每批 4 个（避免超时）
DELAY = 3  # 每个请求间隔秒数

# SSL 忽略（如果需要）
ssl_ctx = ssl.create_default_context()
ssl_ctx.check_hostname = False
ssl_ctx.verify_mode = ssl.CERT_NONE


def load_config():
    """从 config.yaml 读取 API key"""
    with open(CONFIG_PATH, "r") as f:
        config = yaml.safe_load(f)
    return config.get("model", {}).get("api_key", ""), config.get("model", {}).get("base_url", "")


def load_prompts():
    """加载槽位类型描述"""
    with open(PROMPTS_PATH, "r", encoding="utf-8") as f:
        return json.load(f)


def generate_icon(api_key, base_url, slot_name, prompt):
    """生成单个图标"""
    full_url = base_url.rstrip("/") + "/images/generations"
    
    payload = json.dumps({
        "model": "agnes-image-2.0-flash",
        "prompt": prompt,
        "size": "512x512",
        "n": 1
    }).encode()
    
    req = urllib.request.Request(
        full_url,
        data=payload,
        headers={
            "Content-Type": "application/json",
            "Authorization": "Bearer " + api_key
        }
    )
    
    try:
        resp = urllib.request.urlopen(req, context=ssl_ctx, timeout=120)
        data = json.loads(resp.read())
        
        if "data" in data and len(data["data"]) > 0:
            return data["data"][0]["url"]
        else:
            print(f"  ERROR: No data in response: {json.dumps(data)[:200]}")
            return None
    except Exception as e:
        print(f"  ERROR: {e}")
        return None


def download_icon(url, output_path):
    """从 URL 下载图标到本地"""
    req = urllib.request.Request(url)
    resp = urllib.request.urlopen(req, context=ssl_ctx, timeout=120)
    img_data = resp.read()
    
    with open(output_path, "wb") as f:
        f.write(img_data)
    
    size_kb = len(img_data) / 1024
    return size_kb


def main():
    print("=" * 60)
    print("改造模块图标批量生成器")
    print("=" * 60)
    
    # 1. 加载 API key
    print("\n[1/4] 加载 API key...")
    api_key, base_url = load_config()
    print(f"  Key 长度: {len(api_key)}")
    print(f"  Base URL: {base_url}")
    
    # 2. 加载描述
    print("\n[2/4] 加载槽位描述...")
    prompts = load_prompts()
    print(f"  槽位数: {len(prompts)}")
    
    # 3. 创建输出目录
    print("\n[3/4] 创建输出目录...")
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    
    # 检查已有的图标
    existing = set()
    if os.path.exists(OUTPUT_DIR):
        for f in os.listdir(OUTPUT_DIR):
            if f.endswith(".png"):
                existing.add(f.replace(".png", ""))
    print(f"  已有: {len(existing)}")
    print(f"  待生成: {len(prompts) - len(existing & set(prompts.keys()))}")
    
    # 4. 批量生成
    print("\n[4/4] 批量生成中...\n")
    success = 0
    failed = 0
    skipped = 0
    
    for i, (slot_name, prompt) in enumerate(prompts.items()):
        icon_filename = f"mod_{slot_name}.png"
        output_path = os.path.join(OUTPUT_DIR, icon_filename)
        
        # 检查是否已存在
        if slot_name in existing:
            print(f"  [{i+1}/{len(prompts)}] 跳过 {slot_name} (已存在)")
            skipped += 1
            continue
        
        print(f"  [{i+1}/{len(prompts)}] 生成 {slot_name} ...")
        print(f"    Prompt: {prompt[:50]}...")
        
        # 生成
        img_url = generate_icon(api_key, base_url, slot_name, prompt)
        if img_url is None:
            print(f"    ✗ 生成失败")
            failed += 1
            continue
        
        # 下载
        try:
            size_kb = download_icon(img_url, output_path)
            print(f"    ✓ 保存 {icon_filename} ({size_kb:.0f}KB)")
            success += 1
        except Exception as e:
            print(f"    ✗ 下载失败: {e}")
            failed += 1
        
        # 延迟（避免请求过快）
        import time
        time.sleep(DELAY)
    
    # 5. 总结
    print("\n" + "=" * 60)
    print("生成完成!")
    print(f"  成功: {success}")
    print(f"  跳过: {skipped}")
    print(f"  失败: {failed}")
    print(f"  输出目录: {OUTPUT_DIR}")
    print("=" * 60)
    
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
