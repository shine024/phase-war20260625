"""核爆蘑菇云精灵表生成（agnes-ai API）

生成一张 1024×1024 的 3×3 精灵表（9 帧），表现蘑菇云从地面闪光到完全消散的成长序列。
切割后供 AnimatedSprite2D 逐帧播放，比单 sprite + tween 缩放更流畅震撼。

prompt 关键设计（避免 AI 常见错误）：
  - 强调 "ONE mushroom cloud growing" 防 AI 画成 9 个独立爆炸
  - 强调 "3x3 grid" + "centered in each cell" 防 AI 乱布局
  - 强调 "consistent position across frames" 防蘑菇云帧间乱跳
  - 纯黑背景便于切割后阈值抠图

失败处理：单次失败重试 2 次，3 个 key 轮换。仍失败报告，可重跑。

用法：python tools/generate_nuke_spritesheet.py
输出：assets/effects/nuclear/nuke_mushroom_sheet.png
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
OUTPUT = os.path.join(ROOT, "assets", "effects", "nuclear", "nuke_mushroom_sheet.png")

# 精灵表 prompt（3×3 网格，9 帧蘑菇云成长序列）
PROMPT = (
    "sprite sheet of ONE nuclear mushroom cloud growing animation sequence, "
    "3x3 grid layout with 9 frames arranged left-to-right top-to-bottom, "
    "frame 1: small bright ground level flash ignition, "
    "frame 2: rising fireball stem forming, "
    "frame 3: stem rising with cap starting, "
    "frame 4: mushroom cap expanding, "
    "frame 5: full classic mushroom cloud shape, "
    "frame 6: cloud beginning to dissipate at edges, "
    "frame 7: cloud thinning and spreading, "
    "frame 8: mostly dispersed smoke, "
    "frame 9: faint lingering smoke trail, "
    "the SAME single mushroom cloud evolving across all 9 frames, NOT 9 separate explosions, "
    "consistent centered position within each grid cell across all frames, "
    "clear thin black grid lines separating each cell, "
    "solid pure black background #000000, high contrast bright white-gray smoke, "
    "top-down aerial game VFX sprite sheet, high detail, clean"
)

NEGATIVE_HINTS = "avoid: inconsistent positions, multiple different explosions, random layouts, text, watermark"


def load_keys():
    if not os.path.exists(KEY_FILE):
        print("ERROR: key 文件不存在: " + KEY_FILE)
        sys.exit(1)
    with open(KEY_FILE, encoding="utf-8") as f:
        keys = [ln.strip() for ln in f if ln.strip()]
    if not keys:
        print("ERROR: " + KEY_FILE + " 为空")
        sys.exit(1)
    return keys


def mask(k):
    return k[:6] + "..." + k[-4:] if len(k) > 12 else k


def call_api(prompt, key, size, tag, output_path):
    """单次 API 调用 + 下载。返回 (ok, msg)。"""
    payload = json.dumps({"model": MODEL, "prompt": prompt, "size": size, "n": 1})
    tmp = output_path + ".payload.json"
    with open(tmp, "w", encoding="utf-8") as f:
        f.write(payload)
    resp = output_path + ".resp.json"
    cmd = ["curl", "--http1.1", "-s", "-X", "POST", BASE_URL + "/images/generations",
           "-H", "Authorization: Bearer " + key, "-H", "Content-Type: application/json",
           "--data-binary", "@" + tmp, "-o", resp, "--max-time", "120"]
    try:
        subprocess.run(cmd, capture_output=True, text=True, timeout=150)
    finally:
        try: os.unlink(tmp)
        except OSError: pass
    if not os.path.exists(resp) or os.path.getsize(resp) < 10:
        return False, "[" + tag + "] 无响应"
    content = open(resp, encoding="utf-8", errors="replace").read()
    try: os.unlink(resp)
    except OSError: pass
    try:
        data = json.loads(content)
    except json.JSONDecodeError:
        return False, "[" + tag + "] 非 JSON: " + content[:150]
    if "data" not in data or not data["data"]:
        err = data.get("error", {})
        msg = err.get("message", str(data)[:150]) if isinstance(err, dict) else str(data)[:150]
        return False, "[" + tag + "] 无 data: " + msg
    url = data["data"][0].get("url", "")
    b64 = data["data"][0].get("b64_json", "")
    if url:
        subprocess.run(["curl", "--http1.1", "-s", "-L", "-o", output_path, url, "--max-time", "120"], timeout=150)
        if os.path.exists(output_path) and os.path.getsize(output_path) > 1000:
            return True, "[" + tag + "] OK(url, " + str(os.path.getsize(output_path)) + "B)"
        return False, "[" + tag + "] 下载失败"
    if b64:
        import base64
        with open(output_path, "wb") as f:
            f.write(base64.b64decode(b64))
        if os.path.getsize(output_path) > 1000:
            return True, "[" + tag + "] OK(b64, " + str(os.path.getsize(output_path)) + "B)"
    return False, "[" + tag + "] 无 url/b64"


def main():
    os.makedirs(os.path.dirname(OUTPUT), exist_ok=True)
    keys = load_keys()
    # 已存在则跳过（--force 参数可强制重生成）
    if os.path.exists(OUTPUT) and "--force" not in sys.argv and os.path.getsize(OUTPUT) > 1000:
        print("精灵表已存在，跳过（加 --force 强制重生成）: " + OUTPUT)
        return
    print("=" * 55)
    print("核爆蘑菇云精灵表生成（3x3 = 9帧）")
    print("输出: " + OUTPUT)
    print("可用 key: " + str(len(keys)) + " 个")
    print("=" * 55)
    # 最多重试 3 次（每次换 key）
    for attempt in range(3):
        key = keys[attempt % len(keys)]
        tag = "尝试" + str(attempt + 1) + " key" + mask(key)
        print(tag + " ...", end=" ", flush=True)
        ok, msg = call_api(PROMPT, key, "1024x1024", tag, OUTPUT)
        print("OK" if ok else "FAIL")
        print("  " + msg)
        if ok:
            print("=" * 55)
            print("成功！下一步：python tools/split_nuke_spritesheet.py 切割+验证")
            return
        time.sleep(3)
    print("=" * 55)
    print("3 次尝试均失败。可重跑本脚本，或手动调整 PROMPT 后重试。")


if __name__ == "__main__":
    main()
