# -*- coding: utf-8 -*-
"""vis_player_051 (cold_inf_m60) 单张 6 帧攻击雪碧图试验——参考
chongdashu/ai-game-spritesheets 06-attack-spritesheet 结构化模板（用户 2026-09-29 指定，
弃现管线 A/B/C 中文条款 prompt，改英文 Intended-use/Inputs/Frame-sequence/Constraints 模板）。

双图输入：Image 1 = 用户指定卡图（镜像朝左白底身份锚）/ Image 2 = f0 铺 3x2 布局导图。
产物只落 img25_staging，raw 出来停——人工核对后才切格（流程纪律不变）。
"""
import base64
import io
import json
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import img25_sprite_trial as P  # 复用 gen_image(3key轮询)/make_layout_guide/OUT

SRC = os.path.join(ROOT, "docs", "img25_样张_20260929", "_对比_卡图_vis_player_051.png")
TAG = "vis051"

PROMPT = """Intended use:
Create a 6-frame 3x2 spritesheet for a side-view 2D game character attack animation.

Input images:
Image 1 is the identity anchor for this machine-gunner soldier. Preserve the exact character identity, face, camouflage uniform and helmet, ammo belt, machine gun, proportions, silhouette, palette, and left-facing direction.
Image 2 is the 3x2 spritesheet layout guide. Use it only as a layout guide for six equal cells; its repeated pose is not an action reference.

Primary request:
Generate the same soldier firing his machine gun from his standing pose, facing LEFT in exact side view for every frame. The muzzle flash is small and brief; the character remains on a stable foot baseline.

Canvas and layout:
- wide 16:9 PNG spritesheet
- 3 columns by 2 rows
- six equal cells
- frame order: left to right across the top row, then left to right across the bottom row
- character fully visible in each cell, including boots
- consistent character scale, camera, and ground baseline across all frames
- plain solid white background

Frame sequence:
Frame 1: neutral ready stance, gun held as in Image 1, no muzzle flash.
Frame 2: leans slightly into the gun, firmer grip, still no flash.
Frame 3: firing frame - a small orange-yellow muzzle flash at the muzzle tip only.
Frame 4: follow-through, slight recoil of shoulder and gun, flash gone, a thin smoke wisp near the muzzle.
Frame 5: recoil settling, body easing back, no flash, no smoke.
Frame 6: return to the calm ready stance, identical to Frame 1, no effects.

Style:
- 2D game sprite, clean volumetric color painting, no black outline, no contour line
- crisp edges, consistent lighting and palette, readable silhouette

Constraints:
- no direction change; the soldier faces LEFT in every frame, never right, never toward the camera
- no camera angle change; the exact same pure side view as Image 1 in every frame, never top-down, never 3/4
- no extra characters, no scenery, no ground, no shadow, no UI, no labels, no numbers, no text, no watermark, no visible grid lines or cell borders
- do not crop feet, helmet, gun barrel, or ammo belt
- do not merge cells or create comic panels
- do not recenter or rescale the character differently per frame
"""


def build_anchor():
    """用户原图 → 白底 → 裁 bbox → 镜像朝左 → 贴 512 方画布脚底。返回 PIL Image。"""
    im = Image.open(SRC).convert("RGBA")
    a = np.asarray(im)
    ys, xs = np.where(a[:, :, 3] > 8)
    im = im.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
    im = im.transpose(Image.FLIP_LEFT_RIGHT)  # 原图朝右 → sheet 真身朝左（游戏 flip_h 实机朝右）
    sc = min(500.0 / im.width, 500.0 / im.height)
    im = im.resize((max(1, int(im.width * sc)), max(1, int(im.height * sc))), Image.LANCZOS)
    canvas = Image.new("RGBA", (512, 512), (255, 255, 255, 255))
    canvas.alpha_composite(im, ((512 - im.width) // 2, 512 - im.height - 6))
    return canvas


def main():
    os.makedirs(P.OUT, exist_ok=True)
    anchor = build_anchor()
    refp = os.path.join(P.OUT, "%s_ref.png" % TAG)
    anchor.save(refp)
    print("身份锚(朝左):", refp, flush=True)

    guidep = P.make_layout_guide(anchor.convert("RGBA"), TAG)  # f0 铺 3x2 布局导图
    print("布局导图:", guidep, flush=True)

    def uri(img):
        buf = io.BytesIO()
        img.convert("RGB").save(buf, "PNG")
        return "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode()

    payload = os.path.join(P.OUT, "%s_attack_payload.json" % TAG)
    open(payload, "w", encoding="utf-8").write(json.dumps({
        "model": "agnes-image-2.5-flash", "prompt": PROMPT,
        "size": "2K", "ratio": "16:9",
        "extra_body": {"image": [uri(anchor), uri(Image.open(guidep))],
                       "response_format": "b64_json"}}, ensure_ascii=False))
    print("生图中（同步 30-60s）…", flush=True)
    raw = P.gen_image(payload, TAG)
    if not raw:
        print("生成失败")
        return 1
    rawp = os.path.join(P.OUT, "%s_attack_raw.png" % TAG)
    open(rawp, "wb").write(raw)
    print("raw 已落盘:", rawp)
    return 0


if __name__ == "__main__":
    sys.exit(main())
