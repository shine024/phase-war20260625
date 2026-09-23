# -*- coding: utf-8 -*-
"""W5 CP-2 重生成 Wave3（2026-09-15，用户拍板"重新生成"）：照片/渲染感 20 张。

对策预置（Wave1/2 沉淀）：厚涂风格前置（现代/二战题材照片引力强）、隔离句前置
（士兵/载具易进走廊）、单主体锁（quantum 教训）、禁"battle-worn"类破败词（禁则5）。
023 身份修正 = M1A2 SEP（ui_asset_loader 实证）。5 张动画联动单位：
mod_sup_m4_carbine / ww2_air_bomber / ww2_air_dive_bomber / ww2_arty_pak40 / ww2_sup_gmc_truck。
用法：gen / deploy。备份 preCP2D。
"""
import json
import os
import sys
import time
import urllib.request

import numpy as np
from PIL import Image
from collections import deque

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _netfix as netfix

netfix.install()

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KEY = open(os.path.join(ROOT, "tools", "_api_key.txt")).readline().strip()
BASE_URL = "https://apihub.agnes-ai.com/v1"
MODEL = "agnes-image-2.0-flash"
OUT = os.path.join(ROOT, "docs", "待生成卡图_W5_CP2_2026-09-14")

TAIL_ICE = (" overcast diffused lighting, one narrow cool sky-blue rim light along the back edge, "
            "muted cold palette of deep blue-grey steel and cold grey, thick painterly "
            "illustration, clean painterly silhouettes defined by value contrast and a narrow rim "
            "light, smooth blended brushwork, hard-edge steel surfaces, clean pure white "
            "background with NO ground")
TAIL_NEON = TAIL_ICE.replace(
    "one narrow cool sky-blue rim light along the back edge",
    "one narrow cyan rim light along the back edge, faint glow limited to emissive parts")
NEG = " text, perspective view, frame, ground, ceiling"

V = "unit fills about three quarters of the frame with even white margins"
SOLDIER_HEAD = "thick painterly digital illustration, isolated on a plain empty pure white background, "
VEH_HEAD = "thick painterly digital illustration, "

UNITS = [
    {"id": "mod_sup_m4_carbine", "tail": TAIL_ICE, "prompt":
     SOLDIER_HEAD + "one lone modern soldier in tan combat gear and helmet aiming an M4 "
     "carbine with both hands muzzle pointing right, eye-level full body side view, facing "
     "right, " + V + ", only one soldier in empty white space"},
    {"id": "vis_player_016", "tail": TAIL_ICE, "prompt":
     VEH_HEAD + "modern single military vehicle, full body, eye-level side view, facing "
     "right, historically accurate equipment detail, " + V + ", one single olive green "
     "wheeled armored personnel carrier with six wheels and a small turret, the vehicle "
     "stands alone"},
    {"id": "vis_player_018", "tail": TAIL_ICE, "prompt":
     VEH_HEAD + "modern single military vehicle, full body, eye-level side view, facing "
     "right, historically accurate equipment detail, " + V + ", one single tracked infantry "
     "fighting vehicle in grey green digital camouflage paint with a compact autocannon "
     "turret, the vehicle stands alone"},
    {"id": "vis_player_023", "tail": TAIL_ICE, "prompt":
     VEH_HEAD + "modern single military vehicle, full body, eye-level side view, facing "
     "right, historically accurate equipment detail, " + V + ", one single M1A2 main battle "
     "tank in side profile, low sloped composite turret with a 120mm smoothbore main gun "
     "and a commander machine gun mount, side skirt armor covering the track runs, the "
     "tank stands alone with no second vehicle"},
    {"id": "vis_player_026", "tail": TAIL_NEON, "prompt":
     VEH_HEAD + "near-future single hard-surface sci-fi unit, full body, eye-level side "
     "view, facing right, sleek angular panel lines, " + V + ", one single white robotic "
     "carrier vehicle with a broad hull and two articulated mechanical lifting arms on its "
     "back, small blue sensor lights, exactly one vehicle standing alone"},
    {"id": "vis_player_029", "tail": TAIL_NEON, "prompt":
     VEH_HEAD + "near-future single hard-surface sci-fi unit, full body, eye-level side "
     "view, facing right, sleek angular panel lines, " + V + ", one single super heavy "
     "sci-fi tank with layered angular armor plates, two forward gun barrels and wide "
     "dual track runs, the tank stands alone"},
    {"id": "vis_player_035", "tail": TAIL_ICE, "prompt":
     VEH_HEAD + "cold war era single military vehicle, full body, eye-level side view, "
     "facing right, historically accurate equipment detail, " + V + ", one single main "
     "battle tank in olive green paint with a rounded cast turret and a long main gun, "
     "the tank stands alone"},
    {"id": "vis_player_057", "tail": TAIL_ICE, "prompt":
     SOLDIER_HEAD + "one lone modern soldier in desert camouflage uniform and helmet "
     "holding a rifle across the chest muzzle pointing right, eye-level full body side "
     "view, facing right, " + V + ", only one soldier in empty white space"},
    {"id": "vis_player_058", "tail": TAIL_ICE, "prompt":
     VEH_HEAD + "modern single military vehicle, full body, eye-level side view, facing "
     "right, historically accurate equipment detail, " + V + ", one single armed pickup "
     "truck with a mounted heavy machine gun in the cargo bed, spare wheel and jerry cans "
     "on the tailgate, the truck stands alone"},
    {"id": "vis_player_059", "tail": TAIL_ICE, "prompt":
     VEH_HEAD + "modern single military vehicle, full body, eye-level side view, facing "
     "right, historically accurate equipment detail, " + V + ", one single eight wheeled "
     "armored personnel carrier with a low turret and angled hull, the vehicle stands alone"},
    {"id": "vis_player_060", "tail": TAIL_ICE, "prompt":
     VEH_HEAD + "modern single military vehicle, full body, eye-level side view, facing "
     "right, historically accurate equipment detail, " + V + ", one single tracked multiple "
     "rocket launcher vehicle with a box launcher module raised at the rear, the vehicle "
     "stands alone"},
    {"id": "vis_player_061", "tail": TAIL_ICE, "prompt":
     SOLDIER_HEAD + "one lone modern special forces operator in dark grey tactical gear "
     "and balaclava holding a suppressed carbine muzzle pointing right, eye-level full "
     "body side view, facing right, " + V + ", only one soldier in empty white space"},
    {"id": "vis_player_062", "tail": TAIL_ICE, "prompt":
     VEH_HEAD + "modern single military vehicle, full body, eye-level side view, facing "
     "right, historically accurate equipment detail, " + V + ", one single grey green main "
     "battle tank with a wedge shaped turret and smoke grenade launchers, the tank stands "
     "alone"},
    {"id": "vis_player_068", "tail": TAIL_NEON, "prompt":
     VEH_HEAD + "near-future single hard-surface sci-fi unit, full body, eye-level side "
     "view, facing right, sleek angular panel lines, " + V + ", one single hovering hover "
     "tank with a smooth wedge hull above a skirt skirt of air cushion thrusters and a "
     "long plasma barrel turret, the tank hovers alone"},
    {"id": "vis_player_069", "tail": TAIL_NEON, "prompt":
     SOLDIER_HEAD + "one lone near-future soldier in a sleek refractive optical camouflage "
     "suit holding a compact rifle muzzle pointing right, faint cyan light seams on the "
     "suit, eye-level full body side view, facing right, " + V + ", only one soldier in "
     "empty white space"},
    {"id": "vis_player_070", "tail": TAIL_NEON, "prompt":
     VEH_HEAD + "near-future single hard-surface sci-fi unit, full body, eye-level side "
     "view, facing right, sleek angular panel lines, " + V + ", one single bipedal combat "
     "mech with layered armor plating and exposed inner frame details on one shoulder, a "
     "gatling gun arm, the mech stands alone"},
    {"id": "ww2_air_bomber", "tail": TAIL_ICE, "prompt":
     VEH_HEAD + "WWII single military aircraft, full body, eye-level side view, facing "
     "right, historically accurate equipment detail, " + V + ", one single twin engine "
     "medium bomber with a glazed nose cockpit, dorsal gun turret and tail fin, the "
     "aircraft floats alone in level flight attitude"},
    {"id": "ww2_air_dive_bomber", "tail": TAIL_ICE, "prompt":
     VEH_HEAD + "WWII single military aircraft, full body, eye-level side view, facing "
     "right, historically accurate equipment detail, " + V + ", one single dive bomber "
     "with inverted gull wings, a large propeller spinner and fixed landing gear, the "
     "aircraft floats alone in level flight attitude"},
    {"id": "ww2_arty_pak40", "tail": TAIL_ICE, "prompt":
     "thick painterly digital illustration, isolated on a plain empty pure white background, "
     "one single WWII towed anti-tank gun emplaced for firing, a split trail carriage with "
     "two road wheels, a thin long barrel level with the ground behind a small gunner "
     "shield, dunkelgelb yellow-ochre paint, eye-level side view, facing right, the gun "
     "stands completely alone with no crew, " + V},
    {"id": "ww2_sup_gmc_truck", "tail": TAIL_ICE, "prompt":
     VEH_HEAD + "WWII single military vehicle, full body, eye-level side view, facing "
     "right, historically accurate equipment detail, " + V + ", one single six wheeled "
     "recovery truck with an open cab, a canvas covered cargo bed and a rear mounted "
     "crane boom, the truck stands alone"},
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


def keep_largest(img):
    arr = np.asarray(img.convert("RGBA")).copy()
    m = arr[..., 3] >= 16
    h, w = m.shape
    lab = np.zeros((h, w), np.int32)
    cur = 0
    sizes = {}
    for y in range(h):
        for x in range(w):
            if m[y, x] and lab[y, x] == 0:
                cur += 1
                q = deque([(y, x)])
                lab[y, x] = cur
                n = 0
                while q:
                    cy, cx = q.popleft()
                    n += 1
                    for dy in (-1, 0, 1):
                        for dx in (-1, 0, 1):
                            ny, nx = cy + dy, cx + dx
                            if 0 <= ny < h and 0 <= nx < w and m[ny, nx] and lab[ny, nx] == 0:
                                lab[ny, nx] = cur
                                q.append((ny, nx))
                sizes[cur] = n
    if not sizes:
        return img, 0
    main = max(sizes, key=sizes.get)
    kill = m & (lab != main)
    arr[kill] = 0
    return Image.fromarray(arr, "RGBA"), int(kill.sum())


def grounding_clear(img, bright_cap=248):
    arr = np.asarray(img.convert("RGBA")).astype(np.int16)
    h, w = arr.shape[:2]
    y0 = int(h * 0.70)
    a = arr[..., 3]
    bright = arr[..., :3].mean(-1)
    fl = (a < 200) & (bright < bright_cap)
    vis = np.zeros((h, w), bool)
    q = deque()
    for x in range(w):
        for y in (h - 1, h - 2):
            if fl[y, x]:
                vis[y, x] = True
                q.append((x, y))
    while q:
        x, y = q.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if y0 <= ny < h and 0 <= nx < w and not vis[ny, nx] and fl[ny, nx]:
                vis[ny, nx] = True
                q.append((nx, ny))
    arr[vis] = 0
    return Image.fromarray(arr.astype(np.uint8), "RGBA"), int(vis.sum())


def eid_of(tid):
    return "vis_enemy_" + tid[11:] if tid.startswith("vis_player_") else tid


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "gen"
    only = sys.argv[2] if len(sys.argv) > 2 else ""
    os.makedirs(OUT, exist_ok=True)
    units = [u for u in UNITS if not only or u["id"] == only]
    if mode == "gen":
        for i, u in enumerate(units):
            fp = os.path.join(OUT, u["id"] + "_white.png")
            if os.path.exists(fp) and os.path.getsize(fp) > 1000:
                print("[%d] %s 已有" % (i, u["id"]))
                continue
            print("[%d/%d] gen %s" % (i + 1, len(units), u["id"]), flush=True)
            ok, msg = generate(u["prompt"], fp)
            if not ok:
                time.sleep(4)
                ok, msg = generate(u["prompt"], fp)
            print("   ", "OK" if ok else "FAIL " + msg, flush=True)
            time.sleep(2)
        sheets = []
        chunk = []
        for idx, u in enumerate(units):
            fp = os.path.join(OUT, u["id"] + "_white.png")
            if not os.path.exists(fp):
                continue
            t = fit_square(white_to_alpha(Image.open(fp)))
            t, _ = keep_largest(t)
            t, _ = grounding_clear(t)
            a = np.asarray(t)
            m = a[..., 3] >= 16
            ys, xs = np.where(m)
            occ = max(xs.max() - xs.min() + 1, ys.max() - ys.min() + 1) * 100.0 / 512
            rgb = a[..., :3][m].astype(np.int16)
            warm = (rgb[:, 0] > rgb[:, 2] + 30).sum() * 100.0 / max(1, len(rgb))
            print("%-24s occ=%.1f warm=%.1f" % (u["id"], occ, warm))
            t.thumbnail((256, 256))
            chunk.append((u["id"], t))
            if len(chunk) == 8:
                sheets.append(chunk)
                chunk = []
        if chunk:
            sheets.append(chunk)
        for si, ch in enumerate(sheets, 1):
            sh = Image.new("RGB", (256 * 4, 256 * 2), (50, 50, 50))
            for i, (uid, t) in enumerate(ch):
                bg = Image.new("RGBA", (256, 256), (60, 60, 60, 255))
                bg.paste(t, ((256 - t.width) // 2, (256 - t.height) // 2), t)
                sh.paste(bg.convert("RGB"), ((i % 4) * 256, (i // 4) * 256))
            sh.save(os.path.join(ROOT, ".godot", "agent_tools", "w5_vision_audit",
                                 "regen_w3_preview_%d.png" % si))
        print("previews -> regen_w3_preview_*.png")
    elif mode == "deploy":
        for u in units:
            tid = u["id"]
            fp = os.path.join(OUT, tid + "_white.png")
            assert os.path.exists(fp), fp
            eid = eid_of(tid)
            for p in (os.path.join(ROOT, "assets", "card_icons", "player", tid + ".png"),
                      os.path.join(ROOT, "assets", "card_icons", "enemy", eid + ".png")):
                bak = os.path.join(ROOT, "_art_backup",
                                   os.path.splitext(os.path.basename(p))[0] + "-preCP2D-2026-09-15.png")
                if not os.path.exists(bak):
                    Image.open(p).convert("RGBA").save(bak)
            t = fit_square(white_to_alpha(Image.open(fp)))
            t, nk = keep_largest(t)
            t, ng = grounding_clear(t)
            t.save(os.path.join(ROOT, "assets", "card_icons", "player", tid + ".png"), "PNG")
            arr = np.asarray(Image.open(os.path.join(ROOT, "assets", "card_icons", "player", tid + ".png")).convert("RGBA"))
            Image.fromarray(arr[:, ::-1]).save(os.path.join(ROOT, "assets", "card_icons", "enemy", eid + ".png"), "PNG")
            for size, d in ((256, "_thumb256"), (384, "_thumb384")):
                for side, src, nid in (("player", "player/" + tid, tid), ("enemy", "enemy/" + eid, eid)):
                    im = Image.open(os.path.join(ROOT, "assets", "card_icons", src + ".png")).convert("RGBA")
                    if max(im.size) > size:
                        im.thumbnail((size, size), Image.Resampling.LANCZOS)
                    out = os.path.join(ROOT, "assets", "card_icons", d, side, nid + ".png")
                    os.makedirs(os.path.dirname(out), exist_ok=True)
                    im.save(out)
            print("deployed %s (残渣%d 底影%d)" % (tid, nk, ng))
        print("done — anchors + verify + reimport + 动画联动(5)待跑")


if __name__ == "__main__":
    main()
