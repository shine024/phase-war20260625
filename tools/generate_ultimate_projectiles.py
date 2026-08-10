"""大招飞行弹体贴图生成（agnes-ai API, agnes-image-2.1-flash）

为"有天降弹道"的大招生成专属飞行体贴图。区别于 spell_burst（圆形爆炸光团），
飞行体必须是「细长的、有朝向的、pointing downward」的物体（像 nuke_missile），
这样才能在贝塞尔飞行时旋转方向、看起来像"真的飞过来"。

生成目录：assets/effects/ultimate_projectiles/
抠图：复用 remove_spell_burst_background.py 的 flood fill（黑底→透明）

飞行体贴图清单（语义专属，对应 spawn_ultimate_projectile 的 texture 参数）：
  - ult_meteor.png        陨石弹体（燃烧岩石+火焰拖尾，橙红，apocalypse_meteor 用）
  - ult_orbital.png       轨道制导炸弹（流线金属弹体+蓝色尾焰，青白，orbital_bombard 用）
  - ult_void_orb.png      虚空能量球（紫黑坍缩球体+紫色电弧，紫，void_apocalypse 用）
  - ult_inferno_bomb.png  燃烧弹（铁壳炸弹+火焰包裹，橙红，inferno/napalm 用）
  - ult_divine_spear.png  神罚光矛（发光长矛/光柱体，金白，god_weapon_single 用）
  - ult_nuke_player.png   我方核导弹（已有 nuke_missile.png，此为敌方目标用，橙白）

用法：
  cd tools && python generate_ultimate_projectiles.py
"""
import json
import os
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KEY_FILE = os.path.join(ROOT, "tools", "_api_key.txt")
BASE_URL = "https://apihub.agnes-ai.cn/v1"
MODEL = "agnes-image-2.1-flash"  # 用户文档最新模型
OUTPUT_DIR = os.path.join(ROOT, "assets", "effects", "ultimate_projectiles")

# 飞行体贴图：强制「纵向长条形、指向下方、纯黑背景」
# 关键 prompt 元素：vertical elongated shape, pointing downward, projectile/missile/meteor
# 这样 AI 输出的才是"飞过来的东西"而非"爆炸光团"
TEXTURES = [
    {
        "id": "ult_meteor",
        "size": "1024x1024",
        "prompt": (
            "a single burning meteor projectile falling downward, glowing molten rock sphere with "
            "long fiery orange-red flame trail behind it, smoking cratered asteroid, "
            "vertical elongated composition pointing downward, detailed game VFX sprite, "
            "top-down view showing the meteor head at bottom and flame trail extending upward, "
            "solid pure black background #000000, high contrast, "
            "centered, no explosion no impact, just the flying meteor body with trail"
        ),
    },
    {
        "id": "ult_orbital",
        "size": "1024x1024",
        "prompt": (
            "a futuristic orbital guided bomb descending from space, sleek aerodynamic metal bomb body, "
            "blue-cyan plasma thruster trail at top, GPS guided munition, sci-fi precision weapon, "
            "vertical elongated composition pointing downward, detailed game VFX sprite, "
            "top-down view showing bomb head at bottom and plasma trail extending upward, "
            "solid pure black background #000000, high contrast, "
            "centered, no explosion, just the flying bomb body with trail, blue-white tones"
        ),
    },
    {
        "id": "ult_void_orb",
        "size": "1024x1024",
        "prompt": (
            "a dark void energy orb descending, sphere of collapsing dark purple-black matter, "
            "swirling violet-magenta energy tendrils trailing behind, ominous dimensional rift projectile, "
            "vertical elongated composition pointing downward, detailed game VFX sprite, "
            "top-down view showing orb at bottom and dark energy trail extending upward, "
            "solid pure black background #000000, high contrast, "
            "centered, no explosion no fire, purple-magenta void energy tones"
        ),
    },
    {
        "id": "ult_inferno_bomb",
        "size": "1024x1024",
        "prompt": (
            "an incendiary napalm bomb falling downward, dark iron bomb shell body wrapped in flames, "
            "long dark orange-red fire trail with black smoke behind, WW2 style burning munition, "
            "vertical elongated composition pointing downward, detailed game VFX sprite, "
            "top-down view showing bomb head at bottom and fire-smoke trail extending upward, "
            "solid pure black background #000000, high contrast, "
            "centered, no explosion no impact, just the flying incendiary bomb with trail"
        ),
    },
    {
        "id": "ult_divine_spear",
        "size": "1024x1024",
        "prompt": (
            "a divine punishment light spear descending from heaven, glowing golden-white energy javelin, "
            "holy radiant beam weapon with light particles trailing, celestial divine lance, "
            "vertical elongated composition pointing downward, detailed game VFX sprite, "
            "top-down view showing spear tip at bottom and light trail extending upward, "
            "solid pure black background #000000, high contrast, "
            "centered, no explosion, just the flying holy spear body, golden-white tones"
        ),
    },
    {
        "id": "ult_nuke_player",
        "size": "1024x1024",
        "prompt": (
            "a tactical nuclear missile flying upward then arcing, sleek military ballistic missile, "
            "white-orange rocket body with fiery exhaust trail, strategic warhead munition, "
            "vertical elongated composition pointing downward, detailed game VFX sprite, "
            "top-down view showing missile nose at bottom and exhaust trail extending upward, "
            "solid pure black background #000000, high contrast, "
            "centered, no explosion no mushroom cloud, just the flying missile body with trail, orange-white"
        ),
    },
]


def load_keys():
    if not os.path.exists(KEY_FILE):
        print("ERROR: key 文件不存在: " + KEY_FILE)
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
    payload = json.dumps({"model": MODEL, "prompt": prompt, "size": size, "n": 1})
    tmpfile = output_path + ".payload.json"
    with open(tmpfile, "w", encoding="utf-8") as f:
        f.write(payload)
    resp_file = output_path + ".resp.json"
    cmd = [
        "curl", "--http1.1", "-s", "--ssl-no-revoke",
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
    dl_cmd = ["curl", "--http1.1", "-s", "-L", "--ssl-no-revoke", "-o", output_path, url, "--max-time", "120"]
    subprocess.run(dl_cmd, capture_output=True, text=True, timeout=150)
    if os.path.exists(output_path) and os.path.getsize(output_path) > 1000:
        return True, "[" + tag + "] OK(url, " + str(os.path.getsize(output_path)) + "B)"
    return False, "[" + tag + "] 下载失败"


def main():
    print("=" * 60)
    print("大招飞行弹体贴图生成 (agnes-image-2.1-flash)")
    print("输出目录: " + OUTPUT_DIR)
    print("=" * 60)
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    keys = load_keys()
    print("加载 %d 个 key: %s" % (len(keys), ", ".join(mask(k) for k in keys)))
    key_idx = 0
    ok_count = 0
    skip_count = 0
    fail_count = 0
    for tex in TEXTURES:
        out_path = os.path.join(OUTPUT_DIR, tex["id"] + ".png")
        # 已存在则跳过（不覆盖，避免重跑覆盖好的）
        if os.path.exists(out_path) and os.path.getsize(out_path) > 5000:
            print("[SKIP] %s 已存在 (%dB)" % (tex["id"], os.path.getsize(out_path)))
            skip_count += 1
            continue
        # 轮换 key
        key = keys[key_idx % len(keys)]
        key_idx += 1
        print("[GEN]  %s  key=%s  size=%s ..." % (tex["id"], mask(key), tex["size"]), end=" ", flush=True)
        ok, msg = call_api(tex["prompt"], key, tex["size"], tex["id"], out_path)
        print(msg)
        if ok:
            ok_count += 1
        else:
            fail_count += 1
            # 失败后换下一个 key 重试一次
            if len(keys) > 1:
                key = keys[key_idx % len(keys)]
                key_idx += 1
                print("[RETRY] %s  key=%s ..." % (tex["id"], mask(key)), end=" ", flush=True)
                ok2, msg2 = call_api(tex["prompt"], key, tex["size"], tex["id"], out_path)
                print(msg2)
                if ok2:
                    ok_count += 1
                    fail_count -= 1
        time.sleep(1)  # 请求间隔，避免限流
    print("=" * 60)
    print("完成: %d 成功 / %d 跳过 / %d 失败 (共 %d)" % (ok_count, skip_count, fail_count, len(TEXTURES)))
    if fail_count > 0:
        print("⚠ 失败的贴图，代码侧有 null 守卫会回退到激光线段，不会崩")


if __name__ == "__main__":
    main()
