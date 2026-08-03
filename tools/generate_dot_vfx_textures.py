"""DOT 持续特效贴图生成（agnes-ai API + 黑底抠图）

生成 4 张单位身上挂的 DOT 持续视觉贴图：
  - dot_burn.png  火焰（橙红，单位脚下持续燃烧）
  - dot_chem.png  毒雾（绿色，单位周围毒气缭绕）
  - dot_emp.png   电弧（紫色，单位身上电流闪烁）
  - dot_nano.png  纳米（青色，单位周围纳米光点）

复用核爆 VFX 的黑底流程（强制纯黑背景 → 生成 → 亮度阈值抠图）：
  黑底主体高对比，亮度<20 透明，简单可靠。

用法：
  python tools/generate_dot_vfx_textures.py
输出：assets/effects/dot/dot_burn.png ~ dot_nano.png（透明背景，512x512）
后续：用 Agent Tools editor.reload_filesystem 导入 Godot
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
OUTPUT_DIR = os.path.join(ROOT, "assets", "effects", "dot")

# 4 张 DOT 贴图配置：黑底 prompt（持续视觉，要适合长时间显示，环形/围绕型）
TEXTURES = [
    {
        "id": "dot_burn",
        "prompt": (
            "ring of small burning flames circling upward, orange-red fire particles, "
            "glowing embers and small flames arranged in a circle, "
            "top-down view, perfectly centered ring shape, "
            "solid pure black background #000000, high contrast, "
            "game VFX sprite texture, clean, no ground no character"
        ),
    },
    {
        "id": "dot_chem",
        "prompt": (
            "toxic green poison gas cloud swirling in a ring, bright green poisonous vapor, "
            "chemical smoke wisps arranged in a circular cloud, "
            "top-down view, perfectly centered ring shape, "
            "solid pure black background #000000, high contrast, "
            "game VFX sprite texture, clean, no ground no character"
        ),
    },
    {
        "id": "dot_emp",
        "prompt": (
            "purple electric arcs crackling in a ring, bright violet lightning bolts, "
            "electromagnetic pulse energy discharge circular pattern, "
            "top-down view, perfectly centered ring shape, "
            "solid pure black background #000000, high contrast, "
            "game VFX sprite texture, clean, no ground no character"
        ),
    },
    {
        "id": "dot_nano",
        "prompt": (
            "cyan nanite particles swirling in a ring, bright teal nano-machine dots, "
            "small glowing cyan light points arranged in a circular orbit, "
            "top-down view, perfectly centered ring shape, "
            "solid pure black background #000000, high contrast, "
            "game VFX sprite texture, clean, no ground no character"
        ),
    },
]


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
            return True, "[" + tag + "] OK(b64)"
    return False, "[" + tag + "] 无 url/b64"


def cutout_black_bg(path):
    """黑底阈值抠图：亮度<20 透明，20-50 羽化。返回去背景像素占比。"""
    from PIL import Image
    img = Image.open(path).convert("RGBA")
    w, h = img.size
    px = img.load()
    removed = 0
    for y in range(h):
        for x in range(w):
            p = px[x, y]
            b = (p[0] + p[1] + p[2]) // 3
            if b < 20:
                px[x, y] = (p[0], p[1], p[2], 0)
                removed += 1
            elif b < 50:
                px[x, y] = (p[0], p[1], p[2], int(255 * (b - 20) / 30))
    img.save(path)
    return removed * 100 // (w * h)


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    keys = load_keys()
    force = "--force" in sys.argv
    print("=" * 55)
    print("DOT 持续特效贴图生成（4 张：火焰/毒雾/电弧/纳米）")
    print("输出: " + OUTPUT_DIR)
    print("=" * 55)
    success = 0
    for i, tex in enumerate(TEXTURES):
        tex_id = tex["id"]
        out_path = os.path.join(OUTPUT_DIR, tex_id + ".png")
        # 已存在且非 force 则跳过
        if not force and os.path.exists(out_path) and os.path.getsize(out_path) > 1000:
            print("[" + str(i + 1) + "/4] " + tex_id + " 已存在，跳过")
            success += 1
            continue
        key = keys[i % len(keys)]
        print("[" + str(i + 1) + "/4] " + tex_id + " key" + mask(key) + " ...", end=" ", flush=True)
        ok, msg = call_api(tex["prompt"], key, "1024x1024", tex_id, out_path)
        print("OK" if ok else "FAIL")
        print("  " + msg)
        if ok:
            # 黑底抠图
            pct = cutout_black_bg(out_path)
            print("  抠图去背景 " + str(pct) + "%")
            success += 1
        if i < len(TEXTURES) - 1:
            time.sleep(3)
    print("=" * 55)
    print("完成: " + str(success) + "/4 张成功")
    print("下一步：用 Agent Tools editor.reload_filesystem 导入 Godot")
    print("  （python -c 调 call('editor.reload_filesystem', {})）")


if __name__ == "__main__":
    main()
