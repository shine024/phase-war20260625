#!/usr/bin/env python3
"""余烬要塞（EMBER BUNKER）P1.5 美术资产生成脚本 v21。

生成 18 张基地贴图（This War of Mine 手绘阴郁风格）：
  - 14 张家具/设备精灵（白底 → 透明，缩到高 160px）
  - 2 张墙面纹理（512²，普通层/深层）
  - 1 张地板条（裁中带 512×32）
  - 1 张地表背景带（1280×128）

调用 agnes-image-2.0-flash（模板复用 generate_missing_card_icons_11.py），
白底转透明复用 deploy_card_icons_11.py 的平滑 alpha 方案。

用法：
  python tools/generate_bunker_assets.py            # 增量（已存在则跳过）
  python tools/generate_bunker_assets.py --force    # 全部重生成
生成后必须：
  1) godot --headless --import 生成 .import 元数据
  2) 按美术备份铁律打包 assets/bunker/ 到项目外 zip
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
RAW_DIR = os.path.join(ROOT, "assets", "bunker", "_raw")
OUT_DIR = os.path.join(ROOT, "assets", "bunker")

FORCE = "--force" in sys.argv

# ── 风格前缀（全组统一：This War of Mine 手绘阴郁末世风）──
SPRITE_PREFIX = (
    "This War of Mine inspired 2D game asset, hand-painted gritty somber style, "
    "muted desaturated earthy palette (dark grey-brown, dusty olive, rust), "
    "single object strictly side view, flat orthographic, centered, "
    "pure solid white background, NO shadow on ground, NO floor, NO reflection, "
    "NO text, NO watermark, NO human figures, NO extra objects. "
)
TEXTURE_PREFIX = (
    "Seamless tileable game texture, hand-painted gritty somber style, "
    "muted desaturated palette, even flat lighting, full-frame surface pattern only, "
    "NO objects, NO text, NO watermark, NO vignette. "
)
NEG = ("不要：文字、水印、人物、多余物件、地面投影、透视变形。")

# ── 18 张资产清单 ──
# kind: sprite(白底转透明) | texture(全幅纹理) | floor(裁横带) | scene(背景)
ASSETS = [
    # === 家具/设备精灵（14）===
    {"fname": "fur_bed", "kind": "sprite",
     "desc": "军用行军床侧视：简单金属折叠框架加帆布床面，一条旧军毯，轻微锈蚀"},
    {"fname": "fur_desk", "kind": "sprite",
     "desc": "破旧木书桌侧视：瘸腿、桌面摊开的笔记本与一盏小台灯（暖黄灯光）"},
    {"fname": "fur_table", "kind": "sprite",
     "desc": "食堂长桌侧视：金属长桌纵贯画面，桌上只有一把椅子朝向观众，远处两把倒扣的椅子"},
    {"fname": "fur_medbay", "kind": "sprite",
     "desc": "医疗舱侧视：蒙布的胶囊形治疗舱，舱旁立一面带雾的镜子，一盏手术灯"},
    {"fname": "fur_wartable", "kind": "sprite",
     "desc": "全息兵棋沙盘桌侧视：宽大金属桌面上方悬浮一片幽幽青色全息光网与光点，科技感"},
    {"fname": "fur_workbench", "kind": "sprite",
     "desc": "维修工作台侧视：台面散落扳手、零件、台钳，头顶一盏工作灯亮着暖橙光"},
    {"fname": "fur_archive", "kind": "sprite",
     "desc": "档案室屏柜列侧视：一排立式档案柜，数块屏幕亮着幽蓝微光映出浮尘，部分屏幕黑着"},
    {"fname": "fur_comms", "kind": "sprite",
     "desc": "通讯台侧视：老式通讯控制台，多排按钮与拨杆，一台待听指示灯亮着红点，旁边斜靠天线"},
    {"fname": "fur_reactor", "kind": "sprite",
     "desc": "反应堆核心侧视：粗壮圆柱形反应堆塔，中段一圈观察窗透出暖橙核心光，管线缠绕，厚重"},
    {"fname": "fur_memorial", "kind": "sprite",
     "desc": "纪念灯阵墙侧视：一面墙板上整齐排列三十个小灯座（全部未点亮，暗的），每盏灯下有一行空白名牌"},
    {"fname": "fur_observatory", "kind": "sprite",
     "desc": "观星台大门侧视：沉重的合金双开门，门缝透出一线冷青色星光，门上有星图刻纹"},
    {"fname": "fur_antenna", "kind": "sprite",
     "desc": "气象站天线阵列侧视：倾斜的桁架塔上的风速计与蝶形天线，半埋在碎石尘土中"},
    {"fname": "fur_depot", "kind": "sprite",
     "desc": "金属仓储货架侧视：四层重型货架，大部分格子空着落满灰，仅几只军绿色箱子"},
    {"fname": "fur_monument", "kind": "sprite",
     "desc": "风化石碑墙侧视：一面粗糙石墙，刻着数列姓名刻痕，有些刻痕深有些只起了一半，苔痕"},
    # === 纹理（2）+ 地板（1）+ 背景（1）===
    {"fname": "wall_tile", "kind": "texture",
     "desc": "地下掩体混凝土内墙纹理：灰褐色水泥墙面，细微裂纹、水渍痕迹、 patched 补丁，暗部"},
    {"fname": "wall_tile_deep", "kind": "texture",
     "desc": "地下深层掩体内墙纹理：更暗更冷的深灰蓝水泥墙面，粗粝、潮湿霉斑、深阴影"},
    {"fname": "floor_tile", "kind": "floor",
     "desc": "磨损金属地板纹理：暗铁灰防滑纹金属板，接缝铆钉、划痕与锈斑，正面平视"},
    {"fname": "bg_surface", "kind": "scene",
     "desc": ("2D游戏背景横带：小行星地表侧视全景。上三分之一是深空星空，远处悬着一弯蓝色地球；"
              "下三分之二是荒芜灰褐色陨石地表，散布岩石、残骸与旧建筑基础的剪影。"
              "阴郁手绘风，低饱和，无文字无水印无人物")},
]


def build_prompt(a):
    if a["kind"] == "sprite":
        return SPRITE_PREFIX + a["desc"] + "。" + NEG
    if a["kind"] == "scene":
        return ("This War of Mine inspired 2D game background, hand-painted gritty somber style, "
                "muted desaturated palette, " + a["desc"] + "。" + NEG)
    return TEXTURE_PREFIX + a["desc"] + "。" + NEG


def generate_image(prompt, output_path):
    payload = json.dumps({"model": MODEL, "prompt": prompt, "size": "1024x1024", "n": 1})
    tmpfile = output_path + ".payload.json"
    with open(tmpfile, "w", encoding="utf-8") as f:
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
    content = open(resp_file, encoding="utf-8").read()
    try:
        os.unlink(resp_file)
    except OSError:
        pass
    try:
        data = json.loads(content)
    except json.JSONDecodeError:
        return False, "Response not JSON: " + content[:200]
    if "data" not in data or len(data["data"]) == 0:
        err = data.get("error", {})
        msg = err.get("message", str(data)[:200]) if isinstance(err, dict) else str(err)[:200]
        return False, "No data: " + str(msg)
    url = data["data"][0].get("url", "")
    if not url:
        return False, "No URL in response"
    subprocess.run(["curl", "--http1.1", "-s", "-L", "-o", output_path, url, "--max-time", "120"],
                   capture_output=True, text=True, timeout=150)
    if os.path.exists(output_path) and os.path.getsize(output_path) > 1000:
        return True, "OK (" + str(os.path.getsize(output_path)) + " bytes)"
    return False, "Download failed/too small"


# ── 后处理 ──

def white_to_alpha(img):
    """白底转透明（平滑过渡，复用 deploy_card_icons_11.py 方案）。"""
    rgb = img.convert("RGB")
    try:
        import numpy as np
        arr = np.array(rgb, dtype=np.int16)
        brightness = (arr[:, :, 0] + arr[:, :, 1] + arr[:, :, 2]) / 3.0
        alpha = np.clip((240 - brightness) * 6.375, 0, 255).astype(np.uint8)
        out = np.dstack([arr[:, :, 0].astype(np.uint8), arr[:, :, 1].astype(np.uint8),
                         arr[:, :, 2].astype(np.uint8), alpha])
        from PIL import Image as _Image
        return _Image.fromarray(out, "RGBA")
    except ImportError:
        return rgb.convert("RGBA")  # numpy 缺失时退化：不抠白


def trim_and_resize_sprite(img, max_h=160, max_w=400):
    """按 alpha 裁边后等比缩到目标高度。"""
    bbox = img.getbbox()
    if bbox:
        img = img.crop(bbox)
    w, h = img.size
    if h == 0 or w == 0:
        return img
    scale = min(max_h / h, max_w / w, 1.0)
    return img.resize((max(1, int(w * scale)), max(1, int(h * scale))),
                      __import__("PIL.Image", fromlist=["Image"]).LANCZOS)


def post_process(a, raw_path, out_path):
    from PIL import Image
    img = Image.open(raw_path)
    if a["kind"] == "sprite":
        img = white_to_alpha(img)
        img = trim_and_resize_sprite(img)
    elif a["kind"] == "texture":
        img = img.convert("RGB").resize((512, 512), Image.LANCZOS)
    elif a["kind"] == "floor":
        # 裁中带（35%-65% 高度）→ 512×32 地板条
        w, h = img.size
        band = img.crop((0, int(h * 0.35), w, int(h * 0.65)))
        img = band.convert("RGB").resize((512, 32), Image.LANCZOS)
    elif a["kind"] == "scene":
        # 裁天空+地平线带（25%-55% 高度）→ 1280×72 地表背景条
        # （铺在 HUD 下方 44..116px，露出于地表房间的间隙，squash 后呈远景地平线）
        w, h = img.size
        band = img.crop((0, int(h * 0.25), w, int(h * 0.55)))
        img = band.convert("RGB").resize((1280, 72), Image.LANCZOS)
    img.save(out_path)
    return img.size


def main():
    os.makedirs(RAW_DIR, exist_ok=True)
    os.makedirs(OUT_DIR, exist_ok=True)
    print("Output dir: " + OUT_DIR)
    todo = [a for a in ASSETS if FORCE or not os.path.exists(os.path.join(OUT_DIR, a["fname"] + ".png"))]
    print("Assets: %d total, %d to generate\n" % (len(ASSETS), len(todo)))

    results = []
    for i, a in enumerate(ASSETS):
        out_path = os.path.join(OUT_DIR, a["fname"] + ".png")
        if a not in todo:
            print("[%2d/%d] %-18s SKIP (exists)" % (i + 1, len(ASSETS), a["fname"]))
            results.append((a["fname"], True, "skip"))
            continue
        raw_path = os.path.join(RAW_DIR, a["fname"] + "_raw.png")
        print("[%2d/%d] %-18s generating..." % (i + 1, len(ASSETS), a["fname"]))
        ok, msg = generate_image(build_prompt(a), raw_path)
        if not ok:
            print("  retry once... " + msg)
            time.sleep(3)
            ok, msg = generate_image(build_prompt(a), raw_path)
        if ok:
            try:
                size = post_process(a, raw_path, out_path)
                print("  OK -> %s %s" % (os.path.basename(out_path), size))
                results.append((a["fname"], True, str(size)))
            except Exception as e:
                print("  POST-PROCESS FAILED: %s" % e)
                results.append((a["fname"], False, str(e)))
        else:
            print("  FAILED: " + msg)
            results.append((a["fname"], False, msg))
        time.sleep(1)

    ok_n = sum(1 for _, ok, _ in results if ok)
    print("\n===== 汇总 %d/%d =====" % (ok_n, len(results)))
    for fname, ok, msg in results:
        print("  %s %-18s %s" % ("OK " if ok else "FAIL", fname, msg))
    print("\n后续步骤：")
    print("  1) godot --headless --import")
    print("  2) 打包 assets/bunker/ 到项目外 zip（PNG 不入 git 铁律）")
    return 0 if ok_n == len(results) else 1


if __name__ == "__main__":
    sys.exit(main())
