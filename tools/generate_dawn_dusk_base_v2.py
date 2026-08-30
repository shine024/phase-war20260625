#!/usr/bin/env python3
"""晨昏大陆底图 v2 重生成（方案11，用户对 v1 不满意：不精致/与游戏内容无关/比例失真）。
v2 定制要点（与 _layout_scheme11 五条时代战线一一对应）：
  - 五条南北向地貌带：一战堑壕 / 二战废土 / 冷战工业 / 现代都市废墟 / 近未来相位裂隙
  - 西暖东暗晨昏梯度 + 右上黑日（部署后 PIL 实测位置回写 GATE_POS_S11）
  - 山脉/河流/海岸提供大陆级尺度感
尺寸优先 2048x1152，API 不支持则逐级回退；生成 3 候选按指标打分（西暖东暗/黑日/细节量）。
胜者人工复核后转存 generated/dawn_dusk_continent.jpeg → deploy_world_map_assets.py（BASES 流程放大 2560×1440）。
"""
import json
import os
import shutil
import subprocess
import sys
import time

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KEY_FILE = os.path.join(ROOT, "tools", "_api_key.txt")
with open(KEY_FILE, "r") as f:
    API_KEY = f.read().strip()
BASE_URL = "https://apihub.agnes-ai.com/v1"
MODEL = "agnes-image-2.0-flash"
CAND_DIR = os.path.join(ROOT, "docs", "地图重设计", "generated", "base_v2_candidates")
FINAL_PATH = os.path.join(ROOT, "docs", "地图重设计", "generated", "dawn_dusk_continent.jpeg")

# 画布 2560×1440 = 16:9；优先大尺寸（原生细节多，部署脚本 LANCZOS 到 2560×1440）
SIZE_CANDIDATES = ["2048x1152", "1536x864", "1344x768", "1024x576"]

PROMPT = """Epic continental war map painting for a tactical strategy game,
hand-painted digital illustration with fine brush detail, seen from very high altitude,
the whole continent fills the frame edge to edge,
the land stretches across a twilight terminator: the WEST edge glows in warm golden
perpetual daylight, fading eastward through dusk into deep polar night on the EAST edge,
high in the eastern sky near the top-right corner hangs a small pitch-black eclipse sun
with a thin pale cyan corona,
five terrain belts cross the continent from north to south, each a different war era
frozen into the land, with clear visible boundaries of rivers and ridgelines:
the northern belt is World War One no-man's-land: zigzag trench lines, mud crater fields,
shattered woods, rusty barbed-wire posts;
the second belt is World War Two countryside: bombed farm towns, broken bridges,
abandoned tank hulls, a wrecked airfield;
the middle belt is a cold-war industrial region: concrete factories, cooling towers,
radar domes, missile silos;
the fourth belt is a modern ruined metropolis: a grid of avenues, collapsed skyscrapers,
burnt-out vehicles;
the southern belt is a near-future wasteland: glowing cyan phase rifts tearing the ground,
black obelisk structures, ash-grey deserts;
a snow-capped mountain spine rises along the west coast with one tiny fortified
mountain bunker carved into the peaks,
rivers run from the mountains to the southern delta, thin worn roads connect the belts,
a ragged coastline with small islands frames the continent,
immense continental scale of hundreds of kilometers, cities like grains of sand,
muted painterly palette, warm amber light in the west sinking into cold blue darkness
in the east,
no text, no letters, no labels, no compass, no map border, no grid, no UI"""


def generate_image(prompt: str, size: str, output_path: str) -> tuple:
    payload = json.dumps({"model": MODEL, "prompt": prompt, "size": size, "n": 1})
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
    if "error" in data:
        return False, "API error: " + str(data["error"])[:200]
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


def measure(path: str) -> dict:
    """底图指标：西暖东暗梯度 / 右上黑日 / 细节量（亮度标准差）。归一化坐标与
    画布布局对齐（黑日期望位置 = GATE_POS_S11 (2287,139)/2560×1440 ≈ (0.893, 0.097)）。"""
    im = Image.open(path).convert("RGB")
    w, h = im.size
    small = im.resize((256, 144))
    px = small.load()

    def region_mean(x0, y0, x1, y1):
        rs = gs = bs = n = 0
        for y in range(int(y0 * 144), int(y1 * 144)):
            for x in range(int(x0 * 256), int(x1 * 256)):
                r, g, b = px[x, y]
                rs += r
                gs += g
                bs += b
                n += 1
        return rs / n, gs / n, bs / n

    wr, wg, wb = region_mean(0.0, 0.2, 0.33, 0.8)   # 西三分之一
    er, eg, eb = region_mean(0.67, 0.2, 1.0, 0.8)   # 东三分之一
    lum_w = 0.299 * wr + 0.587 * wg + 0.114 * wb
    lum_e = 0.299 * er + 0.587 * eg + 0.114 * eb
    # 黑日：期望位置小盒 vs 同高度偏西参考盒
    sr, sg, sb = region_mean(0.875, 0.07, 0.915, 0.125)
    rr, rg, rb = region_mean(0.68, 0.07, 0.72, 0.125)
    lum_star = 0.299 * sr + 0.587 * sg + 0.114 * sb
    lum_ref = 0.299 * rr + 0.587 * rg + 0.114 * rb
    # 细节量：全图亮度标准差
    vals = []
    for y in range(144):
        for x in range(256):
            r, g, b = px[x, y]
            vals.append(0.299 * r + 0.587 * g + 0.114 * b)
    mean = sum(vals) / len(vals)
    std = (sum((v - mean) ** 2 for v in vals) / len(vals)) ** 0.5
    dark_grad = lum_w - lum_e       # 期望 > 15（西亮东暗）
    warm_west = wr - wb             # 期望 > 8（西暖）
    star_dark = lum_ref - lum_star  # 期望 > 25（黑日比周围天空暗）
    return {
        "size": f"{w}x{h}",
        "west_lum": round(lum_w, 1), "east_lum": round(lum_e, 1),
        "dark_grad": round(dark_grad, 1),
        "warm_west": round(warm_west, 1),
        "star_dark": round(star_dark, 1),
        "detail_std": round(std, 1),
        "pass": dark_grad > 15 and warm_west > 8 and star_dark > 25 and std > 30,
    }


def main() -> int:
    os.makedirs(CAND_DIR, exist_ok=True)
    results = []
    size_used = None
    for i in range(1, 4):
        png_path = os.path.join(CAND_DIR, f"base_candidate_{i}.png")
        jpg_path = os.path.join(CAND_DIR, f"base_candidate_{i}.jpeg")
        print(f"── 生成候选 {i}/3 ...", flush=True)
        ok, msg = False, ""
        for size in SIZE_CANDIDATES:
            ok, msg = generate_image(PROMPT, size, png_path)
            if ok:
                size_used = size
                break
            print(f"   size {size} 失败: {msg[:120]}", flush=True)
        if not ok:
            print(f"   ✗ 候选 {i} 全尺寸失败", flush=True)
            continue
        Image.open(png_path).convert("RGB").save(jpg_path, quality=95)
        m = measure(jpg_path)
        results.append((jpg_path, m))
        print(f"   {m['size']} 西亮{m['west_lum']}/东暗{m['east_lum']}(梯度{m['dark_grad']}) "
              f"西暖差{m['warm_west']} 黑日暗差{m['star_dark']} 细节σ{m['detail_std']} "
              f"→ {'✓ PASS' if m['pass'] else '✗ FAIL'}", flush=True)
        time.sleep(2)
    if not results:
        print("无候选，退出")
        return 1
    passing = [r for r in results if r[1]["pass"]]
    pool = passing if passing else results
    pool.sort(key=lambda r: (r[1]["detail_std"], r[1]["dark_grad"]), reverse=True)
    winner = pool[0]
    print(f"\n胜者: {winner[0]}\n指标: {winner[1]}")
    print(f"(通过验收 {len(passing)}/3；候选保留在 {CAND_DIR} 供人工比选)")
    print("人工复核通过后: copy 胜者 → generated/dawn_dusk_continent.jpeg → 部署脚本")
    return 0


if __name__ == "__main__":
    sys.exit(main())
