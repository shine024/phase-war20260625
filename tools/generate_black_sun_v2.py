#!/usr/bin/env python3
"""黑日 v2 重生成（方案11 唯一挂起项，见 docs/地图重设计/方案11_晨昏大陆_黑日战线.md §4.3）。
v1 失败：盘心灰绿 (23,28,29) 非纯黑；青裂纹 0.16%，240px 显示下不可辨。
本脚本调 agnes-image-2.0-flash 生成 3 个候选，PIL 按 v2 验收线自动打分择优：
  盘体平均亮度 < 25；盘内青色裂纹像素占比 ≥ 3%；裂纹线宽 p90 ≥ 4px；四角白底。
胜者转存 docs/地图重设计/generated/black_sun.jpeg（部署脚本输入约定），
随后手动跑 tools/deploy_world_map_assets.py（走 CIRCLE_MASKS 圆形蒙版）+ godot --import。
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
CAND_DIR = os.path.join(ROOT, "docs", "地图重设计", "generated", "black_sun_v2_candidates")
FINAL_PATH = os.path.join(ROOT, "docs", "地图重设计", "generated", "black_sun.jpeg")

PROMPT = """[P_SPR]
A single sun disc floating in empty sky, hand-painted,
a perfect circle of PURE MATTE BLACK (near absolute black, no grey),
crossed by THREE OR FOUR THICK bold glowing cyan #00e5ff fracture veins,
each vein clearly visible like bright electric cracks,
a soft pale cyan corona halo rim hugging tightly around the disc, bright enough to be seen,
ominous, quiet, wrong — a star that emits no light,
pure solid white background, no other objects"""

# 验收线（与需求清单 B3v2 一致）
BRIGHT_MAX = 25.0
CYAN_RATIO_MIN = 0.03
WIDTH_P90_MIN = 4.0


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
        "--data-binary", "@" + tmpfile, "-o", resp_file, "--max-time", "180",
    ]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=200)
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
    dl = ["curl", "--http1.1", "-s", "-L", "-o", output_path, url, "--max-time", "180"]
    d = subprocess.run(dl, capture_output=True, text=True, timeout=200)
    if d.returncode != 0 or not os.path.exists(output_path) or os.path.getsize(output_path) < 5000:
        return False, "download failed"
    return True, "ok"


def measure(path: str) -> dict:
    """按 v2 验收口径测量一张黑日候选图（JPEG 落盘后测，含压缩影响）。
    盘体范围用暗像素实测半径（与部署脚本 auto_dark 蒙版同口径），不用固定比例——
    生图盘体常不满幅，固定 0.44 圈会把盘外白底算进盘体。"""
    im = Image.open(path).convert("RGB")
    w, h = im.size
    px = im.load()
    gray = im.convert("L")
    b8 = gray.point(lambda v: 255 if v < 90 else 0)
    bbox = b8.getbbox()
    if bbox is None:
        return {"brightness": 255, "median_brightness": 255, "cyan_ratio": 0,
                "width_p50": 0, "width_p90": 0, "white_bg": False, "pass": False,
                "disc_r_ratio": 0}
    cx = (bbox[0] + bbox[2]) // 2
    cy = (bbox[1] + bbox[3]) // 2
    r = max(bbox[2] - bbox[0], bbox[3] - bbox[1]) // 2
    disc_r_ratio = round(r / float(min(w, h)), 3)
    # 盘心平均亮度（中心 20% 半径盒，与 v1 实测口径一致）
    rs = gs = bs = 0
    n = 0
    for y in range(cy - r // 5, cy + r // 5):
        for x in range(cx - r // 5, cx + r // 5):
            pr, pg, pb = px[x, y]
            rs += pr
            gs += pg
            bs += pb
            n += 1
    brightness = (rs + gs + bs) / (3.0 * n)
    # 盘内亮度中位数：判"盘体是否纯黑"的正确口径——均值会被盘心裂纹交叉点的
    # 高亮青色抬高（v2 候选实测均值 114 但盘体纯黑；v1 灰绿盘中位数即 26 不达标）
    disc_vals = []
    for y in range(cy - r, cy + r, 3):
        for x in range(cx - r, cx + r, 3):
            dx, dy = x - cx, y - cy
            if dx * dx + dy * dy <= r * r:
                pr, pg, pb = px[x, y]
                disc_vals.append((pr + pg + pb) / 3.0)
    disc_vals.sort()
    median_bright = disc_vals[len(disc_vals) // 2] if disc_vals else 255.0
    # 盘内青色像素占比 + 水平游程线宽（g+b-2r > 60 判青，与 v1 探针同阈值）
    cyan = 0
    tot = 0
    runs = []
    for y in range(cy - r, cy + r, 2):
        run = 0
        for x in range(cx - r, cx + r, 2):
            dx, dy = x - cx, y - cy
            if dx * dx + dy * dy > r * r:
                continue
            pr, pg, pb = px[x, y]
            tot += 1
            if pg + pb - 2 * pr > 60:
                cyan += 1
                run += 1
            elif run:
                runs.append(run)
                run = 0
        if run:
            runs.append(run)
    ratio = cyan / max(tot, 1)
    runs.sort()
    p90 = runs[int(len(runs) * 0.9)] * 2 if runs else 0.0  # 采样步长2，还原实寸
    p50 = runs[int(len(runs) * 0.5)] * 2 if runs else 0.0
    # 四角白底检查
    corners = [px[8, 8], px[w - 9, 8], px[8, h - 9], px[w - 9, h - 9]]
    white_bg = all(sum(c) / 3.0 > 240 for c in corners)
    return {
        "brightness": round(brightness, 1),
        "median_brightness": round(median_bright, 1),
        "cyan_ratio": round(ratio * 100, 2),
        "width_p50": p50,
        "width_p90": p90,
        "white_bg": white_bg,
        "disc_r_ratio": disc_r_ratio,
        "pass": median_bright < BRIGHT_MAX and ratio >= CYAN_RATIO_MIN and p90 >= WIDTH_P90_MIN and white_bg,
    }


def main() -> int:
    os.makedirs(CAND_DIR, exist_ok=True)
    results = []
    for i in range(1, 4):
        png_path = os.path.join(CAND_DIR, f"candidate_{i}.png")
        jpg_path = os.path.join(CAND_DIR, f"candidate_{i}.jpeg")
        print(f"── 生成候选 {i}/3 ...", flush=True)
        ok, msg = generate_image(PROMPT, png_path)
        if not ok:
            print(f"   ✗ 生成失败: {msg}", flush=True)
            continue
        Image.open(png_path).convert("RGB").save(jpg_path, quality=95)
        m = measure(jpg_path)
        results.append((jpg_path, m))
        print(f"   盘亮中位={m['median_brightness']} 青占比={m['cyan_ratio']}% "
              f"线宽p50/p90={m['width_p50']}/{m['width_p90']}px 白底={m['white_bg']} "
              f"→ {'✓ PASS' if m['pass'] else '✗ FAIL'}", flush=True)
        time.sleep(2)
    if not results:
        print("无候选，退出")
        return 1
    passing = [r for r in results if r[1]["pass"]]
    if passing:
        # 通过者中青裂纹占比最高者胜（裂纹可辨度优先）
        passing.sort(key=lambda r: r[1]["cyan_ratio"], reverse=True)
        winner = passing[0]
    else:
        # 全不过：按 (亮度达标, 青占比, 线宽p90) 择优，如实报告
        results.sort(key=lambda r: (r[1]["median_brightness"] < BRIGHT_MAX,
                                    r[1]["cyan_ratio"], r[1]["width_p90"]), reverse=True)
        winner = results[0]
        print("⚠ 无候选全项通过，取综合最优（部署前请人工复核）")
    shutil.copyfile(winner[0], FINAL_PATH)
    print(f"\n胜者: {winner[0]}\n指标: {winner[1]}\n已转存: {FINAL_PATH}")
    print("下一步: python tools/deploy_world_map_assets.py && godot --headless --import")
    return 0


if __name__ == "__main__":
    sys.exit(main())
