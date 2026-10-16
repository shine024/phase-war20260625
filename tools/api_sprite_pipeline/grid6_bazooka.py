# -*- coding: utf-8 -*-
"""6 格(i2i 一次出 6 帧)尝试——巴祖卡 ww2_inf_bazooka。
复用 batch_regen 的调用/锚点机制 + generate_attack_api 的 6 格底稿构造。
只产出原图给人看(不做键控/裁格/拼 sheet), 落 .godot/unit_review/api_ww2_inf_bazooka/raw/grid6_tN.png。
用法: python tools/api_sprite_pipeline/grid6_bazooka.py [rolls]   (默认 1 发)
"""
import base64, os, sys
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__))
WS = os.path.abspath(os.path.join(HERE, "..", ".."))
_BATCH_ARGS = sys.argv[1:]
sys.argv = [sys.argv[0]]
sys.path.insert(0, HERE)
import generate_attack_api as P
import batch_regen as B
sys.argv = [sys.argv[0]] + _BATCH_ARGS

UNIT = "ww2_inf_bazooka"
ROLLS = int(sys.argv[1]) if len(sys.argv) > 1 else 1
out = os.path.join(WS, ".godot", "unit_review", "api_" + UNIT)
raw = os.path.join(out, "raw"); os.makedirs(raw, exist_ok=True)

# 6 格开火循环(人形, 动作做小减跳变, 焰仅 f3, 全程朝左不变面)
POSES6 = [
    "holding the bazooka horizontally in front of his chest with both hands, muzzle pointing left, a calm ready stance, feet planted",
    "raising the bazooka: both hands easing it up toward his shoulder, muzzle rising slightly to the left, one small step into the aim",
    "firing: the bazooka braced at his shoulder, discharging with a compact star-shaped muzzle flash attached directly at the front of the tube, orange-yellow with a white core, body braced against the shot",
    "recoil: the muzzle held just above the horizontal line, the whole upper body leaning slightly back against the shot, both hands still gripping the tube, feet planted",
    "lowering the bazooka: both hands easing it back down toward his chest, muzzle pointing down-left, one small step out of the aim",
    "the bazooka held level in front of his chest with both hands, muzzle pointing left, a calm settled stance, feet planted",
]
GRID6_POS = P.GRID_POS  # top-left/top-middle/top-right/bottom-left/bottom-middle/bottom-right

def build_prompt():
    inv = ("facing LEFT in profile, holding the bazooka rocket launcher in his hands (never empty-handed), "
           "the rocket is still loaded in the tube, NO scope")
    parts = ["%s: the same soldier %s, %s;" % (GRID6_POS[i], p, inv) for i, p in enumerate(POSES6)]
    flash = ("The star-shaped muzzle flash appears in ONLY ONE panel, the firing panel (top-right): small, "
             "orange-yellow with a white core, attached directly to the front of the tube, touching it. "
             "No other panel has any flash or smoke. ")
    # 本地骨架: 去掉共享 SKELETON 里会诱发"黑色剪影"的 silhouette 字样,
    # 换成"平视 2D 游戏精灵 + 每格完整上色"的表述, 并显式禁止黑色剪影/单色黑影。
    skeleton = ("STRICTLY a pure 2D SIDE VIEW side-on game sprite (never a front view, never a three-quarter view), "
                "flat orthographic game sprite, single subject only centered,\n"
                "{SUBJECT}\n"
                "matte painting style, detailed weathering and surface texture, "
                "every panel is FULLY COLORED with exactly the same olive-drab uniform and brown weapon colors "
                "as the reference image, NEVER a black silhouette, NEVER a flat dark shadow shape, "
                "FLAT EVEN MATTE LIGHTING with uniform brightness across the figure, "
                "the lighting is identical in every panel, clean flat game-sprite colors,\n"
                "the entire background is one perfectly flat uniform bright pure magenta #FF00FF color fill "
                "covering the canvas edge to edge, exactly like a solid color fill in an image editor: "
                "no vignette, no gradient, no lighting falloff, no texture anywhere,\n"
                "centered composition, full body fitting in frame with generous empty margin, "
                "NO text, NO watermark, NO ground, NO scene background\n")
    return skeleton.replace("{SUBJECT}",
        "the same WWII US infantryman as in the reference image, with the bazooka anti-tank rocket, "
        "shown in a regular grid of exactly 6 flat panels, 3 columns and 2 rows, "
        "all 6 panels showing THE SAME soldier with THE SAME bazooka, helmet and gear, "
        "identical scale, identical colors and identical rendering in every panel, and NO shadow under any figure. "
        + " ".join(parts) + " " + flash +
        "Keep the exact 6-panel grid layout, panel positions and spacing of the reference image unchanged, "
        "changing only the soldier's pose in each panel as listed. "
        "One complete FULLY COLORED figure centered in each panel, generous empty magenta spacing between panels, "
        "no panel borders, no grid lines, no labels, no numbers.")

def main():
    keys = P.load_keys()
    card = B.make_transparent(Image.open(os.path.join(WS, "assets", "card_icons", "enemy", "ww2_inf_bazooka.png")))
    card = card.crop(card.getbbox())
    card.save(os.path.join(out, "anchor_card.png"))
    tpl = P.build_grid_template_card(card, 256)
    tpl.save(os.path.join(out, "grid_template_6.png"))
    tpl_b64 = base64.b64encode(open(os.path.join(out, "grid_template_6.png"), "rb").read()).decode()
    prompt = build_prompt()
    for n in range(1, ROLLS + 1):
        tag = "grid6_t%d" % n
        print("[grid6] %s 生成中 ..." % tag, flush=True)
        url, kh = B.i2i(prompt, tpl_b64, keys, tag, out_raw=raw)
        pf = os.path.join(raw, tag + ".png")
        import subprocess
        subprocess.run(["curl", "-sS", "-m", "120", "-o", pf, url], check=True)
        im = Image.open(pf)
        print("  → %s (%s) key=%s" % (pf, im.size, kh), flush=True)
    print("done")

if __name__ == "__main__":
    main()
