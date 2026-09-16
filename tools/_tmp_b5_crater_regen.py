#!/usr/bin/env python3
"""B5（2026-09-14）：ground_decal_crater 重生成——v28 版中心带了未爆弹。
根因：旧 prompt "artillery shell crater" 的 shell 被模型画成真炮弹。
按 tools/_agnes_image_api.md 行为铁律改写：通篇不提 shell/munition，正面意象锁死
"空坑、坑底只有暗土与碎小石"。复用 generate_ground_decals.py 的生成/后处理管线。
原图备份 _art_backup/ground_decal_crater-preB5-2026-09-14.png。
"""
import os
import shutil
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import generate_ground_decals as G  # noqa: E402
from PIL import Image  # noqa: E402

OUT = os.path.join(ROOT, "assets", "battle", "decals", "ground_decal_crater.png")
BAK = os.path.join(ROOT, "_art_backup", "ground_decal_crater-preB5-2026-09-14.png")

# 正面意象锁死（不写任何"炮弹/军械"概念词；负面词仅结构性）
PROMPT = (
    "a single empty blast crater in bare earth seen from directly above, "
    "a round hollow bowl of packed dark soil with a raised irregular splash rim "
    "of lighter dirt, the hollow is completely empty, its floor is smooth bare "
    "dark earth with a few tiny loose stones, a few small pebbles scattered near "
    "the outer rim, " + G.STYLE
)


def warm_ratio(im):
    """暖区占比近似（宪法口径的粗估，仅作 sanity——终验收以目视+审计工具为准）"""
    px = im.convert("RGBA").getdata()
    warm = opaque = 0
    for r, g, b, a in px:
        if a < 40:
            continue
        opaque += 1
        if r > b + 28 and r > 110 and g > b:
            warm += 1
    return 100.0 * warm / max(1, opaque)


def main():
    os.makedirs(os.path.dirname(BAK), exist_ok=True)
    if os.path.exists(OUT) and not os.path.exists(BAK):
        shutil.copy2(OUT, BAK)
        print("[bak ]", BAK)
    raw = OUT + ".raw.png"
    ok, msg = False, "not attempted"
    for attempt in range(3):
        ok, msg = G.generate_image(PROMPT, raw, attempt)
        print("[gen ] attempt %d %s %s" % (attempt, ok, msg))
        if ok:
            break
    if not ok:
        print("GENERATION FAILED")
        sys.exit(1)
    im = Image.open(raw)
    im = G.flood_white_to_alpha(im)
    im = G.autocrop(im)
    w, h = im.size
    scale = 512.0 / max(w, h)
    im = im.resize((max(1, int(w * scale)), max(1, int(h * scale))), Image.LANCZOS)
    im.save(OUT)
    os.remove(raw)
    print("[out ]", OUT, im.size)
    print("[warm] 暖区占比近似 %.1f%%（红线 15%%）" % warm_ratio(im))


if __name__ == "__main__":
    main()
