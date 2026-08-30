#!/usr/bin/env python3
"""底图 v3 探索轮：自然大陆 10 张单图候选（用户 2026-08-28 新方向）。
要求：不要横带/时代带/晨昏设定；地貌自然过渡；自然海岸轮廓；东端一个黑色传送门。
5 种地貌风味 × 2 = 10 张，PNG 落盘 + 拼接触图（docs/地图重设计/base_v3_review.png）供挑选。
选中后进入精致轮：两屏拼合 2560×1440 宽图。
"""
import json
import os
import subprocess
import time

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KEY_FILE = os.path.join(ROOT, "tools", "_api_key.txt")
with open(KEY_FILE, "r") as f:
    API_KEY = f.read().strip()
BASE_URL = "https://apihub.agnes-ai.com/v1"
MODEL = "agnes-image-2.0-flash"
OUT_DIR = os.path.join(ROOT, "docs", "地图重设计", "generated", "base_v3e_candidates")
REVIEW_SHEET = os.path.join(ROOT, "docs", "地图重设计", "base_v3e_review.png")

COMMON = (
    "Hand-painted top-down map of ONE island continent whose silhouette is clearly "
    "shaped like the island of GREENLAND, but rotated 90 degrees to lie on its side: "
    "the long axis runs WEST-EAST across the frame, the broad rounded end facing WEST, "
    "the pointed tapering tip pointing EAST, "
    "the coastline deeply cut with fjords exactly like Greenland's real coast, "
    "mountain ranges arranged like Greenland's real geography: "
    "high mountain rims fringing the outer coast, "
    "a vast high snowy interior plateau in the middle, lowlands along the shores, "
    "seen at true continental scale from so high above that individual buildings, roads, "
    "fields and trenches are INVISIBLE — only terrain colors, ridgelines, river lines, "
    "forest masses, ice fields and huge ruin zones are visible, "
    "sea fills the top and bottom margins and the space beyond the pointed eastern tip, "
    "terrain blends organically with soft gradual transitions, "
    "absolutely NO horizontal stripes, NO parallel terrain bands, no grid, "
    "scattered across the lowlands are the ruins of five war eras, every ruin vast enough "
    "to span tens of kilometers and readable only as large color blotches, smudges and "
    "textured zones, never as single buildings or thin lines: "
    "near the far WEST the oldest era — broad pale chalk-scarred wasteland patches and "
    "grey burnt-out forest masses; further east the WWII era — mid-grey charred zones and "
    "razed town footprints; then the cold-war era — wide dull industrial grey zones and "
    "dead factory districts; then the modern era — huge dark ruined megacity blotch clusters; "
    "and crowding around the eastern pointed tip the future era — shattered geometric "
    "megastructure fields with faint cyan glowing fracture webs, "
    "older ruins toward the west, newer toward the east, mixed and scattered organically "
    "like real war-torn history, NOT arranged in bands, "
    "muted painterly palette, fine brush detail, soft natural light, "
    "standing at the pointed EASTERN TIP of the land, one huge pitch-black circular "
    "portal gate with a faint pale glow, dark and ominous, the final destination, "
    "no text, no letters, no labels, no compass, no map border, no frame"
)

FLAVORS = [
    ("icy_core", "a huge pale snow-and-ice interior plateau dominating the middle, "
     "only a narrow green coastal band around the rim"),
    ("tundra_lakes", "the interior is drier tundra highland threaded with chains of "
     "long thin lakes and braided rivers"),
    ("green_rim", "wide green forested lowland belts along both the north and south "
     "coasts, snowy highland only in the center"),
    ("fjord_south", "the southern coastline shredded with extremely deep long fjords "
     "and steep walls, the north coast smoother"),
    ("warm_west", "the broad western end mild, green and inviting, growing colder, "
     "paler and more hostile toward the eastern tip"),
]


def generate_image(prompt: str, output_path: str) -> tuple:
    payload = json.dumps({"model": MODEL, "prompt": prompt, "size": "1024x576", "n": 1})
    tmpfile = output_path + ".payload.json"
    with open(tmpfile, "w") as f:
        f.write(payload)
    resp_file = output_path + ".resp.json"
    cmd = [
        "curl", "--http1.1", "-s", "-X", "POST", BASE_URL + "/images/generations",
        "-H", "Authorization: Bearer " + API_KEY,
        "-H", "Content-Type: application/json",
        "--data-binary", "@" + tmpfile, "-o", resp_file, "--max-time", "240",
    ]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=260)
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
    dl = ["curl", "--http1.1", "-s", "-L", "-o", output_path, url, "--max-time", "240"]
    d = subprocess.run(dl, capture_output=True, text=True, timeout=260)
    if d.returncode != 0 or not os.path.exists(output_path) or os.path.getsize(output_path) < 20000:
        return False, "download failed"
    return True, "ok"


def contact_sheet(paths_labels):
    """5×2 缩略格 + 编号标签 → 单张总览图。"""
    cols, rows = 5, 2
    tw, th = 512, 288
    pad = 10
    sheet = Image.new("RGB", (cols * tw + (cols + 1) * pad,
                              rows * (th + 26) + (rows + 1) * pad), (18, 18, 24))
    d = ImageDraw.Draw(sheet)
    for i, (p, label) in enumerate(paths_labels):
        r, c = divmod(i, cols)
        x = pad + c * (tw + pad)
        y = pad + r * (th + 26 + pad)
        try:
            im = Image.open(p).convert("RGB")
            im.thumbnail((tw, th))
            ox = x + (tw - im.width) // 2
            oy = y + (th - im.height) // 2
            sheet.paste(im, (ox, oy))
        except Exception as e:
            print("thumb fail", p, e)
        d.text((x + 4, y + th + 5), label, fill=(255, 220, 120))
    sheet.save(REVIEW_SHEET)
    print("contact sheet →", REVIEW_SHEET)


def main() -> int:
    os.makedirs(OUT_DIR, exist_ok=True)
    ok_list = []
    idx = 0
    for flv_name, flv_text in FLAVORS:
        for rep in range(2):
            idx += 1
            out = os.path.join(OUT_DIR, f"v3e_{idx:02d}_{flv_name}.png")
            print(f"── [{idx}/10] {flv_name} #{rep+1} ...", flush=True)
            ok, msg = generate_image(COMMON + " ; " + flv_text, out)
            if ok:
                print(f"   ✓ {os.path.basename(out)} ({os.path.getsize(out)} bytes)", flush=True)
                ok_list.append((out, f"{idx}: {flv_name}#{rep+1}"))
            else:
                print(f"   ✗ {msg}", flush=True)
            time.sleep(2)
    if ok_list:
        contact_sheet(ok_list)
    print(f"\n完成 {len(ok_list)}/10。单图在 {OUT_DIR}")
    json.dump(ok_list, open(os.path.join(OUT_DIR, "_manifest.json"), "w"), ensure_ascii=False, indent=1)
    return 0


if __name__ == "__main__":
    import sys
    sys.exit(main())
