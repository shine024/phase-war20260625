# -*- coding: utf-8 -*-
"""W5 CP-2 重生成 Wave1（2026-09-14）：cel/多主体/重复图修复，6 张无动画目标。

管线 = W3-C 同款：agnes-image-2.0-flash 1152x768 白底 → §6.1 十段拼装 prompt →
white_to_alpha → fit_square 512×88% → player 直出 / enemy FLIP → thumbs 256/384。
用法：
  python tools/_tmp_w5_cp2_regen_w1.py gen      # 生成白底原图 + 透明预览拼图（不动 assets）
  python tools/_tmp_w5_cp2_regen_w1.py deploy   # 目检通过后部署（备份 preCP2B）
身份依据 ui_asset_loader.gd：019=M1A1（mod_m1a1）/ 024=侦察机甲外骨骼 / 067=突击机甲 /
078=科幻要塞 / quantum=修理母机（锁单主体）/ nano_drone=球形纳米炮手无人机。
"""
import json
import os
import sys
import time
import urllib.request

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _netfix as netfix

netfix.install()

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KEY = open(os.path.join(ROOT, "tools", "_api_key.txt")).readline().strip()
BASE_URL = "https://apihub.agnes-ai.com/v1"
MODEL = "agnes-image-2.0-flash"
OUT = os.path.join(ROOT, "docs", "待生成卡图_W5_CP2_2026-09-14")

TAIL_NEON = (" overcast diffused lighting, one narrow cyan rim light along the back edge, "
             "faint glow limited to emissive parts, muted cold palette of deep blue-grey steel "
             "and cold grey, thick painterly illustration, clean painterly silhouettes defined "
             "by value contrast and a narrow rim light, smooth blended brushwork, hard-edge "
             "steel surfaces, clean pure white background with NO ground")
TAIL_ICE = TAIL_NEON.replace(
    "one narrow cyan rim light along the back edge, faint glow limited to emissive parts",
    "one narrow cool sky-blue rim light along the back edge")
NEG = " text, perspective view, frame, ground, ceiling"

UNITS = [
    {"id": "fut_nano_drone", "tail": TAIL_NEON, "prompt":
     "near-future single hard-surface sci-fi unit, full body, eye-level side view, facing "
     "right, sleek angular panel lines, unit fills about three quarters of the frame with "
     "even white margins, a single floating spherical drone machine, its whole body is one "
     "armored ball shell with a small round sensor lens and one underslung compact energy "
     "cannon, small thruster vanes on the sides, one single machine floating alone"},
    {"id": "vis_player_024", "tail": TAIL_NEON, "prompt":
     "near-future single hard-surface sci-fi unit, full body, eye-level side view, facing "
     "right, sleek angular panel lines, unit fills about three quarters of the frame with "
     "even white margins, one lone near-future soldier wearing a light powered exoskeleton "
     "scout armor suit, holding a compact rifle with both hands muzzle pointing right, slim "
     "servo limbs and a small backpack power unit, only one soldier in the whole image with "
     "no second figure, isolated subject on plain white"},
    {"id": "vis_player_067", "tail": TAIL_NEON, "prompt":
     "near-future single hard-surface sci-fi unit, full body, eye-level side view, facing "
     "right, sleek angular panel lines, unit fills about three quarters of the frame with "
     "even white margins, one single bipedal assault mech walker shown in strict side "
     "profile, heavy sloped armor plates on torso and legs, a single autocannon mounted on "
     "the shoulder rig, two thick reverse-jointed legs, the mech stands alone in strict side "
     "profile"},
    {"id": "vis_player_078", "tail": TAIL_NEON, "prompt":
     "near-future single hard-surface sci-fi structure, full body, eye-level view, unit "
     "fills about three quarters of the frame with even white margins, one single fortified "
     "bunker structure with layered crenellated armor walls, a central glowing energy core, "
     "two small side gun turrets, one antenna mast, the building stands alone"},
    {"id": "vis_player_019", "tail": TAIL_ICE, "prompt":
     "thick painterly digital illustration, modern single military vehicle, full body, eye-level side view, facing right, "
     "historically accurate equipment detail, unit fills about three quarters of the frame "
     "with even white margins, one single M1A1 main battle tank in side profile, low sloped "
     "composite turret with a 120mm smoothbore main gun, side skirt armor covering the track "
     "runs, the tank stands alone with no second vehicle"},
    {"id": "fe_quantum_repair_drone", "tail": TAIL_NEON, "prompt":
     "thick painterly digital illustration, isolated on a plain empty pure white background, "
     "a single near-future armored repair drone vehicle, a broad rounded armored hull with "
     "layered panel plates and a glazed blue sensor canopy at the front, four small "
     "clustered thruster vents under the hull, two sturdy articulated repair crane arms "
     "folded against the flanks with tool hands, a green status light strip, eye-level side "
     "view, facing right, unit fills about three quarters of the frame, one single uncrewed "
     "machine alone in empty white space"},
]


def generate(prompt, out_path):
    payload = json.dumps({"model": MODEL, "prompt": prompt, "size": "1152x768", "n": 1}).encode()
    req = urllib.request.Request(BASE_URL + "/images/generations", data=payload, headers={
        "Authorization": "Bearer " + KEY, "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=150) as resp:
            data = json.loads(resp.read().decode())
        url = data["data"][0]["url"]
        urllib.request.urlretrieve(url, out_path)
        return os.path.getsize(out_path) > 1000, "ok"
    except Exception as e:
        return False, str(e)[:160]


def white_to_alpha(img):
    arr = np.array(img.convert("RGB"), dtype=np.int16)
    bright = arr.mean(-1)
    alpha = np.clip((240 - bright) * 6.375, 0, 255).astype(np.uint8)
    out = np.dstack([arr[:, :, 0].astype(np.uint8), arr[:, :, 1].astype(np.uint8),
                     arr[:, :, 2].astype(np.uint8), alpha])
    return Image.fromarray(out, "RGBA")


def fit_square(img, size=512):
    img = img.convert("RGBA")
    bbox = img.getbbox()
    if bbox:
        img = img.crop(bbox)
    w, h = img.size
    scale = min(size / w, size / h) * 0.88
    nw, nh = max(1, int(w * scale)), max(1, int(h * scale))
    img = img.resize((nw, nh), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.paste(img, ((size - nw) // 2, (size - nh) // 2), img)
    return canvas


def gate(img):
    """透明稿质检：占比 / 暖区。"""
    a = np.asarray(img)
    m = a[..., 3] >= 16
    ys, xs = np.where(m)
    occ = max(xs.max() - xs.min() + 1, ys.max() - ys.min() + 1) * 100.0 / img.size[0]
    rgb = a[..., :3][m].astype(np.int16)
    warm = (rgb[:, 0] > rgb[:, 2] + 30).sum() * 100.0 / max(1, len(rgb))
    return round(occ, 1), round(warm, 1)


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "gen"
    os.makedirs(OUT, exist_ok=True)
    if mode == "gen":
        for i, u in enumerate(UNITS):
            fp = os.path.join(OUT, u["id"] + "_white.png")
            if os.path.exists(fp) and os.path.getsize(fp) > 1000:
                print("[%d] %s 已有原图，跳过" % (i, u["id"]))
                continue
            print("[%d/%d] gen %s" % (i + 1, len(UNITS), u["id"]), flush=True)
            ok, msg = generate(u["prompt"], fp)
            if not ok:
                time.sleep(4)
                ok, msg = generate(u["prompt"], fp)
            print("   ", "OK" if ok else "FAIL " + msg, flush=True)
            time.sleep(2)
        # 预览拼图（透明稿质检）
        sheet = Image.new("RGB", (256 * 3, 256 * 2), (50, 50, 50))
        for i, u in enumerate(UNITS):
            fp = os.path.join(OUT, u["id"] + "_white.png")
            if not os.path.exists(fp):
                continue
            t = fit_square(white_to_alpha(Image.open(fp)))
            occ, warm = gate(t)
            print("%-26s occ=%s warm=%s" % (u["id"], occ, warm))
            t.thumbnail((256, 256))
            bg = Image.new("RGBA", (256, 256), (60, 60, 60, 255))
            bg.paste(t, ((256 - t.width) // 2, (256 - t.height) // 2), t)
            sheet.paste(bg.convert("RGB"), ((i % 3) * 256, (i // 3) * 256))
        sheet.save(os.path.join(ROOT, ".godot", "agent_tools", "w5_vision_audit", "regen_w1_preview.png"))
        print("preview -> .godot/agent_tools/w5_vision_audit/regen_w1_preview.png")
    elif mode == "deploy":
        PDIR = os.path.join(ROOT, "assets", "card_icons", "player")
        EDIR = os.path.join(ROOT, "assets", "card_icons", "enemy")
        BK = os.path.join(ROOT, "_art_backup")
        for u in UNITS:
            fp = os.path.join(OUT, u["id"] + "_white.png")
            assert os.path.exists(fp), fp
            tid = u["id"]
            eid = "vis_enemy_" + tid[11:] if tid.startswith("vis_player_") else tid
            for p in (os.path.join(PDIR, tid + ".png"), os.path.join(EDIR, eid + ".png")):
                bak = os.path.join(BK, os.path.splitext(os.path.basename(p))[0] + "-preCP2B-2026-09-14.png")
                if not os.path.exists(bak):
                    Image.open(p).convert("RGBA").save(bak)
            t = fit_square(white_to_alpha(Image.open(fp)))
            t.save(os.path.join(PDIR, tid + ".png"), "PNG")
            arr = np.asarray(Image.open(os.path.join(PDIR, tid + ".png")).convert("RGBA"))
            Image.fromarray(arr[:, ::-1]).save(os.path.join(EDIR, eid + ".png"), "PNG")
            for size, d in ((256, "_thumb256"), (384, "_thumb384")):
                for side, base, nid in (("player", os.path.join(PDIR, tid + ".png"), tid),
                                        ("enemy", os.path.join(EDIR, eid + ".png"), eid)):
                    img = Image.open(base).convert("RGBA")
                    if max(img.size) > size:
                        img.thumbnail((size, size), Image.Resampling.LANCZOS)
                    out = os.path.join(ROOT, "assets", "card_icons", d, side, nid + ".png")
                    os.makedirs(os.path.dirname(out), exist_ok=True)
                    img.save(out)
            print("deployed", tid, "/", eid)
        print("deploy done — 记得跑 anchors + verify + reimport")


if __name__ == "__main__":
    main()
