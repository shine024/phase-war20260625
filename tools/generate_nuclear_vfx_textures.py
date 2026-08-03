"""战术核武 VFX 纹理生成（agnes-ai API）

为「导弹发射井」的战术核武机制生成 5 张战场核爆专用纹理：
  - nuke_fireball.png   核爆火球（512×512 透明底，中心亮白→边缘橙红）
  - nuke_shockwave.png  冲击波环（512×512 透明底，白蓝能量环）
  - nuke_mushroom.png   蘑菇云（512×512 透明底，灰白云柱向上扩散）
  - nuke_burn.png       地面焦痕（256×256 透明底，深棕黑烧焦土）
  - nuke_missile.png    ICBM 导弹（128×128 透明底，俯视军事火箭）

复用 generate_level1_bg_candidates.py 的 agnes-ai API 调用结构：
  端点：https://apihub.agnes-ai.cn/v1
  模型：agnes-image-2.0-flash
  Key：tools/_api_key.txt（轮换）

设计要点：
  - 全部要求「transparent background」「top-down view」「centered」「game VFX sprite」
  - 配合 Godot ADD 混合材质（火球/冲击波/蘑菇云叠加发光感）
  - 失败不阻塞：单张失败仅警告，代码侧有 ResourceLoader.exists() 守卫 + 程序化回退

用法：
  cd tools && python generate_nuclear_vfx_textures.py
  生成后图片自动落 assets/effects/nuclear/，Godot 导入后 battle_spectacle._load_nuclear_texture 自动加载。

注意：生成的图是 AI 直出（非透明背景/非精确俯视很常见），可能需要手动用
      tools/deploy_card_icons_11.py 的白底转透明 + 缩放流程后处理。
"""
import json
import os
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KEY_FILE = os.path.join(ROOT, "tools", "_api_key.txt")
BASE_URL = "https://apihub.agnes-ai.cn/v1"
MODEL = "agnes-image-2.0-flash"
OUTPUT_DIR = os.path.join(ROOT, "assets", "effects", "nuclear")

# 5 张纹理的 prompt + 尺寸配置
# 尺寸用 agnes-ai 支持的方阵（VFX 贴图多为方形）
# prompt 强制「纯黑背景」——agnes-ai 不可靠输出透明，但能输出纯黑底，
# 纯黑底用简单阈值即可抠图（主体几乎不会是纯黑），比灰底/白底可靠得多
TEXTURES = [
    {
        "id": "nuke_fireball",
        "size": "1024x1024",
        "prompt": (
            "nuclear explosion fireball, bright white-yellow glowing core, "
            "orange-red outer glow radiating outward, intense hot plasma sphere, "
            "top-down view, perfectly centered, symmetrical, "
            "solid pure black background #000000, high contrast, "
            "game VFX sprite texture, high detail, no ground no horizon"
        ),
    },
    {
        "id": "nuke_shockwave",
        "size": "1024x1024",
        "prompt": (
            "expanding shockwave ring, single bright white-blue energy ring, "
            "hollow center, circular wave front, glowing rim, "
            "top-down view, perfectly centered, symmetrical, "
            "solid pure black background #000000, high contrast, "
            "game VFX sprite texture, clean single ring, no explosion no fire"
        ),
    },
    {
        "id": "nuke_mushroom",
        "size": "1024x1024",
        "prompt": (
            "nuclear mushroom cloud seen from above, bright white-gray glowing smoke "
            "column expanding upward into a wide cap, billowing turbulent cloud, "
            "top-down aerial view, centered, "
            "solid pure black background #000000, high contrast, "
            "game VFX sprite texture, no ground, smoke only"
        ),
    },
    {
        "id": "nuke_burn",
        "size": "1024x1024",
        "prompt": (
            "scorched earth burn mark, bright glowing orange-red charred circle "
            "with ash texture, slightly irregular burnt edges, "
            "top-down flat view, centered, "
            "solid pure black background #000000, high contrast, "
            "game texture, flat decal, no 3d height"
        ),
    },
    {
        "id": "nuke_missile",
        "size": "1024x1024",
        "prompt": (
            "ICBM ballistic military missile rocket, bright glowing white-orange "
            "metallic body with pointed nose, bright flame trail at tail, "
            "single missile centered, vertical orientation, "
            "solid pure black background #000000, high contrast, "
            "game sprite, detailed"
        ),
    },
]


def load_keys():
    if not os.path.exists(KEY_FILE):
        print("ERROR: key 文件不存在: " + KEY_FILE)
        print("  请把 agnes-ai key 写入该文件（每行一个，支持轮换）")
        sys.exit(1)
    with open(KEY_FILE, "r", encoding="utf-8") as f:
        keys = [ln.strip() for ln in f if ln.strip()]
    if not keys:
        print("ERROR: " + KEY_FILE + " 为空")
        sys.exit(1)
    return keys


def mask(key):
    if len(key) <= 12:
        return key[:3] + "..." + key[-3:]
    return key[:6] + "..." + key[-4:]


def call_api(prompt, key, size, tag, output_path):
    """单次 API 调用 + 下载。返回 (ok, msg)。复用 level1 脚本的响应解析逻辑。"""
    payload = json.dumps({"model": MODEL, "prompt": prompt, "size": size, "n": 1})
    tmpfile = output_path + ".payload.json"
    with open(tmpfile, "w", encoding="utf-8") as f:
        f.write(payload)
    resp_file = output_path + ".resp.json"
    cmd = [
        "curl", "--http1.1", "-s",
        "-X", "POST", BASE_URL + "/images/generations",
        "-H", "Authorization: Bearer " + key,
        "-H", "Content-Type: application/json",
        "--data-binary", "@" + tmpfile,
        "-o", resp_file,
        "--max-time", "120",
    ]
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=150)
    finally:
        try:
            os.unlink(tmpfile)
        except OSError:
            pass
    if result.returncode != 0:
        return False, "[" + tag + "] curl exit " + str(result.returncode) + ": " + (result.stderr or "")[:160]
    if not os.path.exists(resp_file) or os.path.getsize(resp_file) < 10:
        return False, "[" + tag + "] 无响应文件"
    content = open(resp_file, "r", encoding="utf-8", errors="replace").read()
    try:
        os.unlink(resp_file)
    except OSError:
        pass
    try:
        data = json.loads(content)
    except json.JSONDecodeError:
        return False, "[" + tag + "] 响应非 JSON: " + content[:200]
    if "data" not in data or len(data["data"]) == 0:
        err = data.get("error", {})
        msg = err.get("message", str(data)[:200]) if isinstance(err, dict) else str(data)[:200]
        return False, "[" + tag + "] 无 data: " + msg
    url = data["data"][0].get("url", "")
    if not url:
        b64 = data["data"][0].get("b64_json", "")
        if b64:
            import base64
            with open(output_path, "wb") as f:
                f.write(base64.b64decode(b64))
            if os.path.getsize(output_path) > 1000:
                return True, "[" + tag + "] OK(b64, " + str(os.path.getsize(output_path)) + "B)"
        return False, "[" + tag + "] 响应无 URL"
    dl_cmd = ["curl", "--http1.1", "-s", "-L", "-o", output_path, url, "--max-time", "120"]
    subprocess.run(dl_cmd, capture_output=True, text=True, timeout=150)
    if os.path.exists(output_path) and os.path.getsize(output_path) > 1000:
        return True, "[" + tag + "] OK(url, " + str(os.path.getsize(output_path)) + "B)"
    return False, "[" + tag + "] 下载失败/过小"


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    keys = load_keys()
    print("=" * 60)
    print("战术核武 VFX 纹理生成")
    print("输出目录: " + OUTPUT_DIR)
    print("纹理数: " + str(len(TEXTURES)) + " 张")
    print("可用 key: " + str(len(keys)) + " 个（" + ", ".join(mask(k) for k in keys) + "）")
    print("=" * 60)

    success = 0
    failed = []
    for i, tex in enumerate(TEXTURES):
        tex_id = tex["id"]
        out_path = os.path.join(OUTPUT_DIR, tex_id + ".png")
        # 已存在则跳过（避免重复消耗 quota）
        if os.path.exists(out_path) and os.path.getsize(out_path) > 1000:
            print("[" + str(i + 1) + "/" + str(len(TEXTURES)) + "] " + tex_id + " 已存在，跳过")
            success += 1
            continue
        # key 轮换：第 i 张用第 (i % len) 个 key
        key = keys[i % len(keys)]
        print("[" + str(i + 1) + "/" + str(len(TEXTURES)) + "] " + tex_id + " (" + tex["size"] + ") key " + mask(key) + " ...", end=" ", flush=True)
        ok, msg = call_api(tex["prompt"], key, tex["size"], tex_id, out_path)
        print("OK" if ok else "FAIL")
        print("    " + msg)
        if ok:
            success += 1
        else:
            failed.append(tex_id)
        # API 限速：每张间隔 3s
        if i < len(TEXTURES) - 1:
            time.sleep(3)

    print("=" * 60)
    print("完成: " + str(success) + "/" + str(len(TEXTURES)) + " 张成功")
    if failed:
        print("失败纹理: " + ", ".join(failed))
        print("  代码侧已有 ResourceLoader.exists() 守卫 + 程序化回退，失败纹理不影响核爆运行")
        print("  可重跑本脚本（已成功的会跳过）或手动找素材替换")
    print("=" * 60)
    print("后续步骤:")
    print("  1. 检查生成图质量，必要时用图像工具白底转透明 + 缩放到目标尺寸")
    print("     (参考 tools/deploy_card_icons_11.py 的处理流程)")
    print("  2. Godot 会自动导入 .png，battle_spectacle._load_nuclear_texture() 自动加载")
    print("  3. 进游戏看核爆演出效果，不达标可删除对应纹理回退程序化")


if __name__ == "__main__":
    main()
