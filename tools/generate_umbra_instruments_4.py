#!/usr/bin/env python3
"""生成影幕系列 4 张缺失相位仪图标（pi_umbra_01~04）。
对齐现有阵营族图风格（1024×1024 不透明徽章：深空底 + 霓虹发光主体，如 pi_eon/nova/iron/helix 系列）。
调用 agnes-image-2.0-flash，输出到 docs/待生成相位仪图标_影幕4张/ 供审核。
审核通过后直接复制到 assets/ui/instruments/（不透明底无需透明化处理）。
"""
import json
import os
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KEY_FILE = os.path.join(ROOT, "tools", "_api_key.txt")
with open(KEY_FILE, "r") as f:
    API_KEY = f.read().strip()
BASE_URL = "https://apihub.agnes-ai.com/v1"
MODEL = "agnes-image-2.0-flash"
OUTPUT_DIR = os.path.join(ROOT, "docs", "待生成相位仪图标_影幕4张")

STYLE = (
    "科幻策略游戏装备徽章图标，单一主体居中构图，深紫黑色径向渐变背景，"
    "虚空粉紫色霓虹发光轮廓与能量光晕，精致的暗色金属质感，"
    "游戏UI图标风格，正方形徽章构图，主体完整居中，无文字无水印无logo。"
)
NEGATIVE = "不要：文字、水印、logo、边框相框、多主体、场景环境、地面、人物、透视畸变。"

ICONS = [
    {
        "fname": "pi_umbra_01",
        "display": "影幕-薄刃",
        "prompt": STYLE + (
            "主体是一柄悬浮的虚空匕首/薄刃短剑，刃身细长锋利呈半透明虚空质感，"
            "刃尖微微下指，剑柄环绕粉色能量环，刃身泛出幽影微光，"
            "暗紫黑色空灵氛围，体现『一击薄刃』的隐秘锋锐感。" + NEGATIVE
        ),
    },
    {
        "fname": "pi_umbra_02",
        "display": "影幕-折光",
        "prompt": STYLE + (
            "主体是一枚悬浮的折光棱晶/隐形斗篷碎片，多面棱镜折射出粉紫色光谱分裂效果，"
            "周围有若隐若现的折光波纹与残影，半透明虚空质感，"
            "暗紫黑色空灵氛围，体现『折光隐匿』的光学迷彩感。" + NEGATIVE
        ),
    },
    {
        "fname": "pi_umbra_03",
        "display": "影幕-寂静域",
        "prompt": STYLE + (
            "主体是一个半球形寂静力场穹顶，穹顶表面流转粉色能量弧纹，"
            "穹顶内部悬浮虚空尘埃粒子被凝固静止，边缘泛出幽影光晕，"
            "暗紫黑色空灵氛围，体现『寂静杀场』的领域压制感。" + NEGATIVE
        ),
    },
    {
        "fname": "pi_umbra_04",
        "display": "影幕-虚空穿",
        "prompt": STYLE + (
            "主体是一道贯穿虚空的粉紫色能量贯穿光束，光束刺穿并撕裂前方悬浮的暗色晶体，"
            "贯穿点爆发强光与粒子飞溅，束身有多重穿透残影轨迹，"
            "暗紫黑色空灵氛围，体现『虚空贯穿』的终极穿透感。" + NEGATIVE
        ),
    },
]


def generate_image(prompt: str, output_path: str) -> tuple:
    payload = json.dumps({"model": MODEL, "prompt": prompt, "size": "1024x1024", "n": 1})
    tmpfile = output_path + ".payload.json"
    with open(tmpfile, "w") as f:
        f.write(payload)
    resp_file = output_path + ".resp.json"
    cmd = [
        "curl", "--http1.1", "-s", "-X", "POST", BASE_URL + "/images/generations",
        "-H", "Authorization: Bearer " + API_KEY,
        "-H", "Content-Type: application/json",
        "--data-binary", "@" + tmpfile, "-o", resp_file, "--max-time", "120",
    ]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=150)
    try:
        os.unlink(tmpfile)
    except OSError:
        pass
    if result.returncode != 0:
        return False, "curl exit " + str(result.returncode)
    if not os.path.exists(resp_file) or os.path.getsize(resp_file) < 10:
        return False, "No response file"
    content = open(resp_file).read()
    try:
        os.unlink(resp_file)
    except OSError:
        pass
    try:
        data = json.loads(content)
    except json.JSONDecodeError:
        return False, "Response not JSON: " + content[:200]
    url = None
    if isinstance(data.get("data"), list) and data["data"]:
        item = data["data"][0]
        url = item.get("url") or (item.get("b64_json") and "b64")
    if not url or url == "b64":
        return False, "No url in response: " + content[:200]
    dl = ["curl", "--http1.1", "-s", "-L", "-o", output_path, url, "--max-time", "120"]
    d = subprocess.run(dl, capture_output=True, text=True, timeout=150)
    if d.returncode != 0 or not os.path.exists(output_path) or os.path.getsize(output_path) < 5000:
        return False, "download failed"
    return True, "ok"


def main() -> int:
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    ok = 0
    for it in ICONS:
        out = os.path.join(OUTPUT_DIR, it["fname"] + ".png")
        print(f"── 生成 {it['fname']}（{it['display']}）...", flush=True)
        success, msg = generate_image(it["prompt"], out)
        if success:
            print(f"   ✓ {out} ({os.path.getsize(out)} bytes)", flush=True)
            ok += 1
        else:
            print(f"   ✗ 失败: {msg}", flush=True)
        time.sleep(2)
    print(f"\n完成 {ok}/{len(ICONS)}。输出目录: {OUTPUT_DIR}")
    print("审核通过后复制到 assets/ui/instruments/（不透明底直接可用）")
    return 0 if ok == len(ICONS) else 1


if __name__ == "__main__":
    sys.exit(main())
