# -*- coding: utf-8 -*-
"""_tmp_gen_modicon_samples.py —— 改造图标重设计四方向样张（agnes-image-2.1-flash）

v37.2 图标重选型样张：A 军械剪影×2 / B 霓虹纹章×3 / C 双色扁平×2 / D 厚涂特写×1。
prompt 骨架照 STYLE_BIBLE 6.4 徽章锚段（B）与 agnes 行为实测约束（正面意象锁死、
负面词只留结构性、屏幕内容限定）。样张仅供选型审美裁决，非最终资产。

输出：docs/待生成徽章_改造图标样张_20260917/raw/<id>.png + manifest.json
用法：python tools/_tmp_gen_modicon_samples.py [id ...]   # 无参=全部
"""
import base64
import concurrent.futures
import json
import os
import re
import subprocess
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KEY_MD = os.path.join(ROOT, "tools", "_agnes_image_api.md")
OUT_DIR = os.path.join(ROOT, "docs", "待生成徽章_改造图标样张_20260917", "raw")
BASE_URL = "https://apihub.agnes-ai.cn/v1"
MODEL = "agnes-image-2.1-flash"
SIZE = "1024x1024"

# ---- 四方向 prompt（中文锚段；负面只留结构性，正面意象锁死） ----

# B 霓虹纹章：STYLE_BIBLE 6.4 徽章锚段原文 + 族变体句（勾线主色=模块族，主体=功能意象）
B_ANCHOR = (
    "科幻策略游戏装备徽章图标，单一主体居中，对称纹章构图，"
    "深空黑到深灰蓝的深底径向渐变，{line}霓虹发光勾线与能量光晕，"
    "正方形徽章构图，主体完整居中，无文字无水印无logo"
)
SAMPLES = {
    # ---- B 霓虹纹章·族徽（3 族 3 色示范） ----
    "b_badge_armor_cyan": B_ANCHOR.format(line="青蓝色") +
        "，中心主体是多层复合装甲板拼接而成的对称盾形徽记，盾面中央镶嵌履带纹样",
    "b_badge_arty_amber": B_ANCHOR.format(line="琥珀金色") +
        "，中心主体是一枚竖置曲射榴弹与两道对称抛物线弹道弧光组成的徽记",
    "b_badge_recon_violet": B_ANCHOR.format(line="紫罗兰色") +
        "，中心主体是一枚圆形光学侦察镜片与十字准星组成的对称徽记，镜片内有微光刻线",
    # ---- A 军械剪影·近白剪影（Tarkov/WoT 路数） ----
    "a_silhouette_scope": (
        "军事装备游戏图标，单一主体居中，一具军用光学瞄准镜的侧面剪影，"
        "近白色高对比剪影带深灰蓝暗部层次，扁平矢量风格，纯深灰蓝色平坦背景，"
        "边缘干净利落，正方形图标构图，主体占画面六成，无文字无水印无logo"
    ),
    "a_silhouette_apshell": (
        "军事装备游戏图标，单一主体居中，一枚穿甲弹弹体的侧面剪影，"
        "近白色高对比剪影带深灰蓝暗部层次，扁平矢量风格，纯深灰蓝色平坦背景，"
        "边缘干净利落，正方形图标构图，主体占画面六成，无文字无水印无logo"
    ),
    # ---- C 双色扁平·功能符号（game-icons/Destiny 路数） ----
    "c_flat_wrench": (
        "极简扁平游戏图标，单一符号居中，一把扳手与齿轮组合的符号，"
        "浅灰白色符号主体配一处钢绿色高亮细节，双色扁平矢量风格，"
        "粗壮几何化线条，纯深色平坦背景，符号占画面中心六成，无文字无水印无logo"
    ),
    "c_flat_helmet": (
        "极简扁平游戏图标，单一符号居中，一顶军用钢盔的正面符号，"
        "浅灰白色符号主体配一处电蓝色高亮细节，双色扁平矢量风格，"
        "粗壮几何化线条，纯深色平坦背景，符号占画面中心六成，无文字无水印无logo"
    ),
    # ---- D 厚涂特写（卡面同源，英雄图标路线） ----
    "d_painted_apfsds": (
        "游戏物品图标，一枚尾翼稳定脱壳穿甲弹弹体的艺术特写，"
        "厚涂插画风格，金属质感，单一主体斜置居中，"
        "冷色环境光与一处暖色边缘光形成冷暖对撞，深色简洁背景，"
        "正方形构图，无文字无水印无logo"
    ),
}

DIRECTION = {
    "b": "B 霓虹纹章·族徽", "a": "A 军械剪影", "c": "C 双色扁平", "d": "D 厚涂特写",
}


def load_keys():
    src = open(KEY_MD, "r", encoding="utf-8").read()
    keys = re.findall(r"sk-[A-Za-z0-9]{20,}", src)
    if not keys:
        raise SystemExit("tools/_agnes_image_api.md 里找不到 key")
    return keys


KEYS = load_keys()


def call_api(prompt, key, out):
    payload = json.dumps({"model": MODEL, "prompt": prompt, "size": SIZE, "n": 1})
    r = subprocess.run(
        ["curl", "--http1.1", "-s", "-X", "POST", BASE_URL + "/images/generations",
         "-H", "Authorization: Bearer " + key, "-H", "Content-Type: application/json",
         "-d", payload, "--max-time", "180"],
        capture_output=True, text=True)
    try:
        data = json.loads(r.stdout)
    except Exception:
        return False, "bad json: " + r.stdout[:120]
    item = (data.get("data") or [{}])[0]
    url = item.get("url", "")
    if url:
        subprocess.run(["curl", "--http1.1", "-s", "-L", "-o", out, url, "--max-time", "180"])
        return os.path.exists(out) and os.path.getsize(out) > 5000, "url"
    b64 = item.get("b64_json", "")
    if b64:
        with open(out, "wb") as f:
            f.write(base64.b64decode(b64))
        return os.path.getsize(out) > 5000, "b64"
    return False, str(data)[:160]


def gen_one(sid):
    prompt = SAMPLES[sid]
    out = os.path.join(OUT_DIR, sid + ".png")
    if os.path.exists(out) and os.path.getsize(out) > 5000:
        return sid, True, "cached"
    for attempt in range(3):
        key = KEYS[(attempt + hash(sid)) % len(KEYS)]
        t0 = time.time()
        ok, how = call_api(prompt, key, out)
        if ok:
            return sid, True, "%.0fs %s" % (time.time() - t0, how)
        if os.path.exists(out):
            os.remove(out)
        time.sleep(5)
    return sid, False, "3 attempts failed"


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    ids = sys.argv[1:] if len(sys.argv) > 1 else list(SAMPLES)
    results = {}
    with concurrent.futures.ThreadPoolExecutor(max_workers=min(3, len(KEYS))) as ex:
        for sid, ok, note in ex.map(gen_one, ids):
            results[sid] = {"ok": ok, "note": note,
                            "direction": DIRECTION.get(sid[0], "?")}
            print(("OK  " if ok else "FAIL") + " " + sid + "  " + note, flush=True)
    mf = os.path.join(OUT_DIR, "manifest.json")
    with open(mf, "w", encoding="utf-8") as f:
        json.dump(results, f, ensure_ascii=False, indent=1)
    print("manifest ->", mf)


import sys
if __name__ == "__main__":
    main()
