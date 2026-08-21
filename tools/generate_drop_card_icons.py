#!/usr/bin/env python3
"""4 张缴获卡（drop_*）敌方原图生成+部署。

背景：drop_smg_mk2/drop_phase_lance/drop_thunder_field/drop_railgun 无独立敌方原图
（攻击帧管线因此跳过它们）。本脚本 text2img 生成白底卡图 → 白转透明 → 512 方形
→ 三处部署（对齐查找链）：
  assets/card_icons/enemy/<id>.png   敌方原图（朝左，惯例归档）
  assets/card_icons/<id>.png         主目录——resolve_card_icon_texture_path 的兜底命中点
  assets/card_icons/player/<id>.png  玩家翻转版（配合 ui_asset_loader.PLAYER_ICON_OVERRIDE）

用法: python tools/generate_drop_card_icons.py [--force]
"""
import base64
import io
import json
import os
import ssl
import sys
import time
import urllib.request

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KEY_FILE = os.path.join(ROOT, "tools", "_api_key.txt")
IMG = "https://apihub.agnes-ai.cn/v1/images/generations"
MODEL = "agnes-image-2.1-flash"

STRICT_PREFIX = (
    "STRICTLY a pure 2D side profile silhouette view, absolutely NO front view, "
    "NO three-quarter view, NO perspective depth, flat orthographic game sprite, "
    "single subject only centered, clean pure white background with NO ground, "
    "NO shadow, NO floor, NO reflection, NO watermark, NO signature, NO text, "
    "NO extra sketches, NO character faces visible, NO environment, "
    "studio isolated product shot style. "
)
NEGATIVE = (
    "不要：三分之四视角、斜侧视、透视 perspective、广角、仰视、俯视、等距 isometric、"
    "鸟瞰 top-down、看到顶部、背景场景、地面、投影底板、文字、水印、logo。"
)

TARGETS = [
    {
        "id": "drop_smg_mk2",
        "prompt": STRICT_PREFIX + (
            "一战德军 MP18-II 冲锋枪突击班组，严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，"
            "科幻硬表面军事单位设定图，四名士兵持伯格曼 MP18-II 冲锋枪呈战斗队形全部朝向画面左侧，"
            "煤灰色野战军装配尖顶钢盔与弹药挎包轮廓清晰，金属磨损旧化，"
            "低饱和军灰主色，局部蓝色能量指示微光，干净棚拍纯白背景，无地面无场景无杂物，高清。" + NEGATIVE
        ),
    },
    {
        "id": "drop_phase_lance",
        "prompt": STRICT_PREFIX + (
            "二战实验性相位刺刀突击班组，严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，"
            "科幻硬表面军事单位设定图，四名士兵持加装相位刺刀的突击步枪呈战斗队形全部朝向画面左侧，"
            "枪口下方伸出细长发光蓝色相位能量刃，灰绿野战服与钢盔轮廓清晰，"
            "低饱和灰绿主色，相位刃青蓝能量发光，干净棚拍纯白背景，无地面无场景无杂物，高清。" + NEGATIVE
        ),
    },
    {
        "id": "drop_thunder_field",
        "prompt": STRICT_PREFIX + (
            "现代雷霆特种突击班组，严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，"
            "科幻硬表面军事单位设定图，四名特种兵持粗壮雷霆突击步枪（顶部导轨+枪身电容组）"
            "呈战斗队形全部朝向画面左侧，深色作战服战术背心与头盔轮廓清晰，"
            "低饱和深灰主色，枪身电容组蓝色电弧微光，干净棚拍纯白背景，无地面无场景无杂物，高清。" + NEGATIVE
        ),
    },
    {
        "id": "drop_railgun",
        "prompt": STRICT_PREFIX + (
            "近未来动力装甲电磁步枪班组，严格2D正侧视，正交投影，游戏单位立绘/精灵图姿态，"
            "科幻硬表面军事单位设定图，三名动力装甲步兵持电磁轨道步枪（双导轨+管状储能环）"
            "呈战斗队形全部朝向画面左侧，白色与浅灰装甲板轮廓清晰，外露液压关节，"
            "低饱和白灰主色，双导轨之间蓝色电磁光弧发光，干净棚拍纯白背景，无地面无场景无杂物，高清。" + NEGATIVE
        ),
    },
]


def load_keys():
    with open(KEY_FILE, encoding="utf-8") as f:
        return [ln.strip() for ln in f if ln.strip()]


def white_to_alpha(img):
    """白底转透明（与 deploy_card_icons_11.py 同法：240→0 / 200→255 平滑过渡）。"""
    try:
        import numpy as np
        arr = np.array(img.convert("RGB"), dtype=np.int16)
        brightness = arr.sum(axis=2) / 3.0
        alpha = np.clip((240 - brightness) * 6.375, 0, 255).astype(np.uint8)
        out = np.dstack([arr[:, :, 0].astype(np.uint8), arr[:, :, 1].astype(np.uint8),
                         arr[:, :, 2].astype(np.uint8), alpha])
        return Image.fromarray(out, "RGBA")
    except ImportError:
        rgb = img.convert("RGB")
        px = rgb.load()
        out = Image.new("RGBA", rgb.size)
        opx = out.load()
        for y in range(rgb.size[1]):
            for x in range(rgb.size[0]):
                r, g, b = px[x, y]
                br = (r + g + b) / 3.0
                a = max(0, min(255, int((240 - br) * 6.375)))
                opx[x, y] = (r, g, b, a)
        return out


def fit_square(img, size=512):
    """内容等比缩放进 size 方形画布（留 4% 边距），居中。"""
    w, h = img.size
    scale = min(size / w, size / h) * 0.96
    nw, nh = max(1, int(w * scale)), max(1, int(h * scale))
    content = img.resize((nw, nh), Image.LANCZOS)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.alpha_composite(content, ((size - nw) // 2, (size - nh) // 2))
    return canvas


def call_text2img(prompt, key, size="1024x1024"):
    body = {"model": MODEL, "prompt": prompt, "size": size}
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    req = urllib.request.Request(
        IMG, data=json.dumps(body).encode(),
        headers={"Authorization": "Bearer " + key, "Content-Type": "application/json"})
    r = urllib.request.urlopen(req, timeout=300, context=ctx)
    d = json.loads(r.read().decode())
    data = d.get("data", [])
    if not data or not data[0].get("url"):
        raise RuntimeError("empty data (rate-limit?): " + json.dumps(d)[:150])
    with urllib.request.urlopen(data[0]["url"], timeout=120, context=ctx) as resp:
        return resp.read()


def main():
    force = "--force" in sys.argv
    keys = load_keys()
    key_idx = 0
    ok = 0
    for t in TARGETS:
        enemy_p = os.path.join(ROOT, "assets", "card_icons", "enemy", t["id"] + ".png")
        if os.path.exists(enemy_p) and not force:
            print("[%s] SKIP (exists)" % t["id"])
            continue
        for attempt in range(4):
            key = keys[key_idx % len(keys)]
            try:
                raw = call_text2img(t["prompt"], key)
                img = fit_square(white_to_alpha(Image.open(io.BytesIO(raw))))
                os.makedirs(os.path.dirname(enemy_p), exist_ok=True)
                img.save(enemy_p)
                img.save(os.path.join(ROOT, "assets", "card_icons", t["id"] + ".png"))
                img.transpose(Image.Transpose.FLIP_LEFT_RIGHT).save(
                    os.path.join(ROOT, "assets", "card_icons", "player", t["id"] + ".png"))
                print("[%s] OK (key%d) -> enemy/ + 根目录 + player/ 各一份" % (t["id"], key_idx % len(keys)))
                ok += 1
                break
            except Exception as e:
                print("[%s] key%d attempt %d failed: %s" % (t["id"], key_idx % len(keys), attempt + 1, e))
                key_idx += 1
                time.sleep(30)
        time.sleep(15)
    print("done: %d/%d" % (ok, len(TARGETS)))
    sys.exit(0 if ok == len(TARGETS) else 1)


if __name__ == "__main__":
    main()
