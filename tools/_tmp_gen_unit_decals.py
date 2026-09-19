# -*- coding: utf-8 -*-
"""_tmp_gen_unit_decals.py —— 战法件单位贴花素材（11 种，白底生成 → 泛洪抠透明 → 384px 落盘）

v37.3 贴花批：形象类/keystone 战法件在战场单位身上的外挂贴片。
抠底复用 generate_ground_decals.flood_white_to_alpha；agnes 行为约束按 tools/_agnes_image_api.md。
输出：docs/待生成徽章_改造贴花_20260917/<id>.png（透明底 384px）+ 贴花总览.png
"""
import base64
import concurrent.futures
import json
import os
import re
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from generate_ground_decals import flood_white_to_alpha  # noqa: E402

from PIL import Image

KEY_MD = os.path.join(ROOT, "tools", "_agnes_image_api.md")
OUT = os.path.join(ROOT, "docs", "待生成徽章_改造贴花_20260917")
URL_BASE = "https://apihub.agnes-ai.cn/v1"
MODEL = "agnes-image-2.1-flash"
SIZE = "1024x1024"

ANCHOR = ("军事游戏单位外挂装备贴片素材，单一物体，侧视图，扁平风格化厚涂，"
          "配色克制（军绿/钢灰/暗橙点缀），纯白背景，物体完整居中占画面六成，"
          "边缘干净锐利，无文字无水印无logo")

DECALS = {
    "camo_net": "一张覆盖载具的伪装网，网面自然下垂带褶皱，网眼纹理半透明感",
    "sandbags": "一段弧形沙袋街垒，三层沙袋堆叠，宽扁造型",
    "smoke_pods": "一组四联装烟幕弹发射器，斜置发射管簇带支架",
    "emp_mast": "一根车载电子干扰天线杆，顶部环形天线与线圈",
    "mine_plow": "车首扫雷犁，宽铲体与向下铲齿，带安装支架",
    "spaced_plates": "两块铰接的附加间隙装甲钢板，斜置叠放",
    "aps_turret": "一座小型主动拦截转塔，方形相控阵面板朝前",
    "reactive_blocks": "一组斜置爆炸反应装甲块，六边形块阵列带螺栓",
    "cb_radar": "一台车载反炮兵雷达，平板相控阵天线与升降支架",
    "laser_lens": "一座近防激光透镜转塔，球形炮塔顶发光晶体",
    "exo_frame": "一副单兵外骨骼背部支架，液压杆与绑带",
}


def load_keys():
    src = open(KEY_MD, "r", encoding="utf-8").read()
    return re.findall(r"sk-[A-Za-z0-9]{20,}", src)


KEYS = load_keys()


def call_api(prompt, key, out):
    payload = json.dumps({"model": MODEL, "prompt": prompt, "size": SIZE, "n": 1})
    r = subprocess.run(
        ["curl", "--http1.1", "-s", "-X", "POST", URL_BASE + "/images/generations",
         "-H", "Authorization: Bearer " + key, "-H", "Content-Type: application/json",
         "-d", payload, "--max-time", "180"], capture_output=True, text=True)
    try:
        data = json.loads(r.stdout)
    except Exception:
        return False
    item = (data.get("data") or [{}])[0]
    url = item.get("url", "")
    if url:
        raw = os.path.join(OUT, "_raw_" + os.path.basename(out))
        subprocess.run(["curl", "--http1.1", "-s", "-L", "-o", raw, url, "--max-time", "180"])
        return os.path.exists(raw) and os.path.getsize(raw) > 5000
    b64 = item.get("b64_json", "")
    if b64:
        raw = os.path.join(OUT, "_raw_" + os.path.basename(out))
        with open(raw, "wb") as f:
            f.write(base64.b64decode(b64))
        return os.path.getsize(raw) > 5000
    return False


def gen_one(sid):
    prompt = ANCHOR + "，主体是" + DECALS[sid]
    raw = os.path.join(OUT, "_raw_%s.png" % sid)
    out = os.path.join(OUT, "%s.png" % sid)
    if os.path.exists(out) and os.path.getsize(out) > 3000:
        return sid, True
    for attempt in range(3):
        if call_api(prompt, KEYS[(attempt + hash(sid) % 3) % len(KEYS)], out):
            try:
                im = Image.open(raw).convert("RGB")
                alpha = flood_white_to_alpha(im)
                alpha.thumbnail((384, 384), Image.LANCZOS)
                alpha.save(out)
                os.remove(raw)
                return sid, True
            except Exception as exc:
                print("process fail %s: %s" % (sid, exc), flush=True)
        time.sleep(4)
    return sid, False


def main():
    os.makedirs(OUT, exist_ok=True)
    results = {}
    with concurrent.futures.ThreadPoolExecutor(max_workers=min(3, len(KEYS))) as ex:
        for sid, ok in ex.map(gen_one, DECALS):
            results[sid] = ok
            print(("OK  " if ok else "FAIL ") + sid, flush=True)
    # 总览
    tiles = [(s, Image.open(os.path.join(OUT, s + ".png"))) for s in DECALS
             if os.path.exists(os.path.join(OUT, s + ".png"))]
    sheet = Image.new("RGB", (4 * 210 + 20, ((len(tiles) + 3) // 4) * 230 + 20), (24, 32, 46))
    for i, (s, im) in enumerate(tiles):
        im.thumbnail((190, 190), Image.LANCZOS)
        sheet.paste(im, (15 + (i % 4) * 210, 10 + (i // 4) * 230), im)
    sheet.save(os.path.join(OUT, "贴花总览.png"))
    print("done %d/%d" % (sum(results.values()), len(results)), flush=True)


if __name__ == "__main__":
    main()
