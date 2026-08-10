"""大招专属 VFX 纹理生成（agnes-ai API）

为敌我双方"大招级"技能生成 10 张专属战场纹理，每张精准对应一类大招语义。
遵循 docs/VFX特效纹理生成工作流.md（核爆 VFX 实战总结）：
  - 强制纯黑背景 #000000（agnes-ai 不可靠输出透明，黑底最易抠图）
  - top-down view / centered / symmetrical / game VFX sprite
  - 生成后用 remove_spell_burst_background.py（flood fill）抠图转透明

敌我双方贴图清单（语义专属，不套用核爆图）：
  敌方 boss 大招（6类）：
    - apocalypse_void.png    虚空天降（紫黑能量坍缩柱，apocalypse/void 类）
    - apocalypse_meteor.png  陨石雨（橙红火球群坠落，meteor 类）
    - inferno_hell.png       地狱火焰（暗红黑烈焰漩涡，inferno/napalm 类）
    - chain_lightning.png    连锁闪电（蓝白分叉电弧，chain/tesla 类）
    - summon_portal.png      召唤传送门（紫绿螺旋漩涡，summon/deploy 类）
    - debuff_dark.png        黑暗debuff（深紫黑雾笼罩，darkness 类）
  我方相位仪能力（4种）：
    - player_barrage.png     火炮连发（青白炮弹落地爆炸群，artillery_barrage）
    - player_shield.png      巨型护盾（蓝青六边形能量穹顶，mega_shield）
    - player_rage.png        狂暴激涌（金红能量光环脉冲，rage_buff）
    - player_fortress.png    壁垒要塞（钢蓝厚重金属壁垒，fortress_bulwark）

复用 generate_nuclear_vfx_textures.py 的 agnes-ai API 调用结构。
用法：
  cd tools && python generate_spell_burst_vfx.py
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
OUTPUT_DIR = os.path.join(ROOT, "assets", "effects", "spell_burst")

# 10 张专属贴图的 prompt + 尺寸配置
# prompt 强制「纯黑背景」——agnes-ai 不可靠输出透明，但纯黑底用阈值/flood fill 易抠图
# 每张语义精准对应一类大招，配色与代码侧 spawn_spell_burst 的染色一致
TEXTURES = [
    # ── 敌方 boss 大招（6类）──
    {
        "id": "apocalypse_void",
        "size": "1024x1024",
        "prompt": (
            "void apocalypse collapse, dark purple-black energy implosion column, "
            "swirling vortex of dark matter tearing inward, magenta-violet lightning cracks, "
            "ominous dimensional rift, top-down view, perfectly centered, symmetrical, "
            "solid pure black background #000000, high contrast, "
            "game VFX sprite texture, dark energy, no fire no explosion"
        ),
    },
    {
        "id": "apocalypse_meteor",
        "size": "1024x1024",
        "prompt": (
            "fiery meteor shower, bright glowing orange fireballs falling from sky, "
            "cluster of flaming energy spheres with light trails, cosmic bombardment, "
            "top-down view, centered spread, "
            "solid pure black background #000000, high contrast, "
            "game VFX sprite texture, energy fireballs"
        ),
    },
    {
        "id": "inferno_hell",
        "size": "1024x1024",
        "prompt": (
            "hellfire inferno vortex, dark crimson and black swirling flame tornado, "
            "evil dark red-orange fire cyclone with black smoke, demonic hell flames, "
            "top-down view, perfectly centered, symmetrical spiral, "
            "solid pure black background #000000, high contrast, "
            "game VFX sprite texture, hellish dark fire, not bright nuclear"
        ),
    },
    {
        "id": "chain_lightning",
        "size": "1024x1024",
        "prompt": (
            "chain lightning storm, bright blue-white forking electric arcs radiating outward, "
            "multiple branching lightning bolts from center, crackling Tesla energy discharge, "
            "top-down view, perfectly centered, radial spread, "
            "solid pure black background #000000, high contrast, "
            "game VFX sprite texture, electric arc, no fire no smoke"
        ),
    },
    {
        "id": "summon_portal",
        "size": "1024x1024",
        "prompt": (
            "summoning portal, glowing purple-green spiral vortex gateway, "
            "swirling magical rift with rune rings, dimensional summon gate, "
            "top-down view, perfectly centered, circular spiral, "
            "solid pure black background #000000, high contrast, "
            "game VFX sprite texture, magic portal, no creatures"
        ),
    },
    {
        "id": "debuff_dark",
        "size": "1024x1024",
        "prompt": (
            "darkness curse cloud, deep purple-black smothering shadow mist spreading, "
            "ominous dark fog blanket with faint violet glow edges, suffocating darkness hex, "
            "top-down view, centered wide spread, "
            "solid pure black background #000000, high contrast, "
            "game VFX sprite texture, dark curse aura, no bright light"
        ),
    },
    # ── 我方相位仪能力（4种）──
    {
        "id": "player_barrage",
        "size": "1024x1024",
        "prompt": (
            "artillery barrage impact zone, multiple cyan-white shell explosions cluster, "
            "scattered artillery shell blast craters with blue-white energy flashes, "
            "precision bombardment pattern, top-down view, spread centered, "
            "solid pure black background #000000, high contrast, "
            "game VFX sprite texture, military shells, blue energy tint"
        ),
    },
    {
        "id": "player_shield",
        "size": "1024x1024",
        "prompt": (
            "energy shield dome, bright cyan-blue hexagonal force field barrier, "
            "protective energy canopy with glowing tech patterns, defensive bubble, "
            "top-down view, perfectly centered, dome shape, "
            "solid pure black background #000000, high contrast, "
            "game VFX sprite texture, protective shield, blue tech"
        ),
    },
    {
        "id": "player_rage",
        "size": "1024x1024",
        "prompt": (
            "rage berserk aura, intense golden-red energy ring pulse outward, "
            "furious power surge with flame-like energy waves, aggressive buff glow, "
            "top-down view, perfectly centered, symmetrical ring, "
            "solid pure black background #000000, high contrast, "
            "game VFX sprite texture, power aura, gold-red"
        ),
    },
    {
        "id": "player_fortress",
        "size": "1024x1024",
        "prompt": (
            "fortress bulwark barrier, steel-blue heavy metal armor plates formation, "
            "thick reinforced defensive wall with rivets and plates, impenetrable bulwark, "
            "top-down view, perfectly centered, circular formation, "
            "solid pure black background #000000, high contrast, "
            "game VFX sprite texture, heavy armor, steel-blue"
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
    """单次 API 调用 + 下载。返回 (ok, msg)。复用 nuclear 脚本的响应解析逻辑。"""
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
    return False, "[" + tag + "] 下载失败/过小"


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    keys = load_keys()
    print("=== 大招专属 VFX 纹理生成 ===")
    print("输出目录: " + OUTPUT_DIR)
    print("贴图数量: " + str(len(TEXTURES)))
    print("API key 数: " + str(len(keys)) + " (" + ", ".join(mask(k) for k in keys) + ")")
    print("")
    success = 0
    failed = []
    for i, tex in enumerate(TEXTURES):
        tid = tex["id"]
        output_path = os.path.join(OUTPUT_DIR, tid + ".png")
        # 已存在则跳过（除非 --force）
        if os.path.exists(output_path) and "--force" not in sys.argv:
            print("[" + str(i + 1) + "/" + str(len(TEXTURES)) + "] " + tid + " 已存在，跳过（--force 重生成）")
            success += 1
            continue
        key = keys[i % len(keys)]  # 轮换 key
        print("[" + str(i + 1) + "/" + str(len(TEXTURES)) + "] " + tid + " 生成中... (key " + mask(key) + ")")
        ok, msg = call_api(tex["prompt"], key, tex["size"], tid, output_path)
        print("  " + msg)
        if ok:
            success += 1
        else:
            failed.append(tid)
        time.sleep(2)  # 防 rate limit
    print("")
    print("=== 结果: " + str(success) + "/" + str(len(TEXTURES)) + " 成功 ===")
    if failed:
        print("失败: " + ", ".join(failed))
        print("可重跑脚本（已成功的会跳过）")
    print("")
    print("下一步：python tools/remove_spell_burst_background.py  （flood fill 抠图转透明）")


if __name__ == "__main__":
    main()
