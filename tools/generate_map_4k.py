#!/usr/bin/env python3
"""4K 底图候选生成（用户定稿图《大地图.jpeg》的构图提炼 → API 4K 文生图）。
背景：API 无图生图（edits 上游 503，generations 忽略 image 字段），4K 只能按提示词
重新生成，构图与定稿图相似但不完全一致。4K 档限流 1 张/分钟，出 3 候选。
输出 docs/地图重设计/generated/map4k_candidates/map4k_c{1,2,3}.png
"""
import json
import os
import subprocess
import time

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KEY = open(os.path.join(ROOT, "tools", "_api_key.txt")).read().strip()
BASE = "https://apihub.agnes-ai.com/v1"
MODEL = "agnes-image-2.1-flash"
OUT_DIR = os.path.join(ROOT, "docs", "地图重设计", "generated", "map4k_candidates")

PROMPT = (
    "Hand-drawn watercolor fantasy world map, delicate ink linework, top-down cartographic view, "
    "a single island continent shaped like GREENLAND rotated horizontal: broad rugged end west, "
    "tapering tip pointing east, deep fjord coastline with small offshore islets, "
    "black-ink hatched mountain ranges ringing the entire coast, "
    "a vast white ice-dome plateau in the center with soft blue shadow crevasses, "
    "pale green tundra lowlands along the western and southern shores, thin winding rivers, "
    "parchment-cream background with pale blue-grey watercolor sea washes, "
    "scattered hand-drawn war ruins as tiny ink clusters: weathered stone ruins and broken "
    "round towers in the west and center, dark ruined cities and shattered cyan-glowing "
    "crystal megastructures crowding the eastern third, "
    "at the eastern tip a huge pitch-black circular portal with a soft pale cyan glowing ring, "
    "fine watercolor paper grain, muted warm palette, extremely detailed brushwork, "
    "no text, no labels, no compass, no border, no frame"
)


def gen(prompt: str, out: str) -> str:
    payload = json.dumps({"model": MODEL, "prompt": prompt, "size": "3840x2160", "n": 1})
    open(out + ".p.json", "w").write(payload)
    r = subprocess.run([
        "curl", "--http1.1", "-s", "-X", "POST", BASE + "/images/generations",
        "-H", "Authorization: Bearer " + KEY,
        "-H", "Content-Type: application/json",
        "--data-binary", "@" + out + ".p.json", "--max-time", "280",
    ], capture_output=True, text=True, timeout=300)
    os.unlink(out + ".p.json")
    d = json.loads(r.stdout)
    if "error" in d:
        return "ERR: " + str(d["error"])[:120]
    url = (d.get("data") or [{}])[0].get("url")
    if not url:
        return "ERR no url: " + r.stdout[:120]
    subprocess.run(["curl", "-sL", "--max-time", "280", "-o", out, url], timeout=300)
    return "%s (%.1f MB)" % (Image.open(out).size, os.path.getsize(out) / 1048576)


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    for i in (1, 2, 3):
        out = os.path.join(OUT_DIR, f"map4k_c{i}.png")
        print(f"── 4K 候选 {i}/3 ...", flush=True)
        print("  ", gen(PROMPT, out), flush=True)
        if i < 3:
            time.sleep(66)  # 4K 档限流 1 张/分钟
    print("完成 →", OUT_DIR)


if __name__ == "__main__":
    main()
