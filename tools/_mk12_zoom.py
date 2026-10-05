# -*- coding: utf-8 -*-
"""MK12 部署稿存疑帧放大工具：从 sheet_attack.png 裁指定帧，768^2 放大后横向拼接。
用法: python tools/_mk12_zoom.py            # 跑下面 ZOOMS 全表
     python tools/_mk12_zoom.py key f1 f3   # 单位临时缩放
输出 .godot/unit_review/mk12_deploy_check/Z_<key>_<f...>.png
"""
import io
import os
import sys

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ANIM = os.path.join(ROOT, "assets", "effects", "unit_anims")
OUTD = os.path.join(ROOT, ".godot", "unit_review", "mk12_deploy_check")
FS = 256
Z = 768

# (key, [帧号 0-based])
ZOOMS = [
    ("ww2_inf_hellcat", [1, 2, 3, 4]),      # 沙黄 vs 橄榄绿：身份还是光洗
    ("ww2_inf_bazooka", [0, 2, 1, 3]),      # f1/f3 开火方向
    ("ww1_105mm", [3, 4, 1, 2]),            # f4 右侧杂 spark + f5 蓝管（对照 f2/f3）
    ("ww1_av7", [1, 2]),                    # f2 黑鸟+边线
    ("ww1_boss_av7", [1, 3, 4]),            # f2 黑鸟 + f4 贯身光束
    ("fe_aether_swarm_queen", [2, 4, 5]),   # 右缘条痕 f3/f6 + f5 橙爆 vs 青
    ("fe_aether_hover_cavalry", [0, 1, 5, 3]),  # f1/f6 炮塔朝向
    ("cold_spetsnaz", [3, 1]),              # f4 灰多边形
    ("cold_bradley", [4, 3]),               # f5 右向尾迹
    ("ww1_arty_77mm", [0, 1, 2]),           # f1/f2 黄绿曳光线
    ("ww1_arm_rolls", [2, 1]),              # f3 人脸确认
]


def zoom(key, frames):
    p = os.path.join(ANIM, key, "sheet_attack.png")
    im = Image.open(p).convert("RGBA")
    n = im.width // FS
    tiles = []
    for i in frames:
        assert 0 <= i < n, "%s f%d 越界 (n=%d)" % (key, i, n)
        f = im.crop((i * FS, 0, (i + 1) * FS, FS)).resize((Z, Z), Image.LANCZOS)
        tiles.append((i, f))
    W = Z * len(tiles)
    out = Image.new("RGBA", (W, Z + 28), (24, 24, 28, 255))
    d = ImageDraw.Draw(out)
    for k, (i, t) in enumerate(tiles):
        out.paste(t, (k * Z, 28))
        d.rectangle([k * Z, 0, k * Z + 64, 26], fill=(180, 30, 30, 255))
        d.text((k * Z + 8, 4), "f%d" % (i + 1), fill=(255, 255, 255, 255))
    name = "Z_%s_%s.png" % (key, "".join("f%d" % (i + 1) for i in frames))
    out.convert("RGB").save(os.path.join(OUTD, name))
    print("OK", name)


def main():
    os.makedirs(OUTD, exist_ok=True)
    if len(sys.argv) > 2:
        zoom(sys.argv[1], [int(x) - 1 for x in sys.argv[2:]])
        return
    for key, frames in ZOOMS:
        zoom(key, frames)


if __name__ == "__main__":
    main()
