# -*- coding: utf-8 -*-
"""W5 CP-2 重生成 Wave2（2026-09-15）：5 张有动画目录的 C 档卡图。
卡图先行重建（身份/档位）：drop_phase_lance=未来空降兵·相位骑枪(neon) /
drop_thunder_field=风暴兵·电弧线圈(neon) / mod_arty_rq7=现代侦察无人机(ice) /
ww1_inf_mp18_x=WWIMP18步兵(ice) / vis_xeno_tripod=异形三足机(violet)。
⚠️ 这 5 个单位有 assets/effects/unit_anims/ 目录——卡图部署后动画集即设计漂移，
须随后用程序化直出管线重建动画（rolls v5/v6 先例）。
用法：gen / deploy
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

HEAD_ICE = (" overcast diffused lighting, one narrow cool sky-blue rim light along the back edge, "
            "muted cold palette of deep blue-grey steel and cold grey, thick painterly "
            "illustration, clean painterly silhouettes defined by value contrast and a narrow rim "
            "light, smooth blended brushwork, hard-edge steel surfaces, clean pure white "
            "background with NO ground")
HEAD_NEON = HEAD_ICE.replace(
    "one narrow cool sky-blue rim light along the back edge",
    "one narrow cyan rim light along the back edge, faint glow limited to emissive parts")
HEAD_VIOLET = HEAD_ICE.replace(
    "one narrow cool sky-blue rim light along the back edge",
    "one narrow faint violet rim light along the back edge")
NEG = " text, perspective view, frame, ground, ceiling"

UNITS = [
    {"id": "drop_phase_lance", "tail": HEAD_NEON, "prompt":
     "near-future single hard-surface sci-fi unit, full body, eye-level side view, facing "
     "right, sleek angular panel lines, unit fills about three quarters of the frame with "
     "even white margins, one lone future drop-troop soldier in grey-green field gear and "
     "helmet aiming a compact carbine fitted with a long glowing cyan phase-lance energy "
     "blade under the barrel, only one soldier in the whole image"},
    {"id": "drop_thunder_field", "tail": HEAD_NEON, "prompt":
     "thick painterly digital illustration, isolated on a plain empty pure white background, "
     "one lone future storm trooper in dark tactical gear and helmet standing in profile, "
     "holding a compact rifle fitted with a glowing electric arc coil emitter at the muzzle, "
     "small cyan lightning arcs around the coil, eye-level full body side view, facing "
     "right, unit fills about three quarters of the frame, only one soldier in empty white space"},
    {"id": "mod_arty_rq7", "tail": HEAD_ICE, "prompt":
     "thick painterly digital illustration, isolated on a plain empty pure white background, "
     "a single unmanned reconnaissance airplane drone in flight, twin tail booms on a straight "
     "wing, a pusher propeller at the rear, a small spherical sensor turret under the nose, "
     "military green grey paint, eye-level side view, facing right, the aircraft floats alone "
     "with no wheels and no ground vehicle and no pilot"},
    {"id": "ww1_inf_mp18_x", "tail": HEAD_ICE, "prompt":
     "WWI single military unit, full body, eye-level side view, facing right, historically "
     "accurate equipment detail, unit fills about three quarters of the frame with even "
     "white margins, one lone WWI infantryman in field cap and greatcoat advancing with an "
     "MP18 submachine gun gripped in both hands muzzle pointing right, only one soldier in "
     "the whole image"},
    {"id": "vis_xeno_tripod", "tail": HEAD_VIOLET, "prompt":
     "single alien war machine, full body, eye-level side view, facing right, unit fills "
     "about three quarters of the frame with even white margins, one single tripod alien "
     "war machine with a crystal-studded dome body, three long segmented insect-like legs "
     "and a forward beam cannon pod, faint bioluminescent crystal lights, the machine "
     "stands alone"},
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
    os.makedirs(OUT, exist_ok=True)
    if mode == "gen":
        for i, u in enumerate(UNITS):
            fp = os.path.join(OUT, u["id"] + "_white.png")
            if os.path.exists(fp) and os.path.getsize(fp) > 1000:
                print("[%d] %s 已有" % (i, u["id"]))
                continue
            print("[%d/%d] gen %s" % (i + 1, len(UNITS), u["id"]), flush=True)
            ok, msg = generate(u["prompt"], fp)
            if not ok:
                time.sleep(4)
                ok, msg = generate(u["prompt"], fp)
            print("   ", "OK" if ok else "FAIL " + msg, flush=True)
            time.sleep(2)
        sheet = Image.new("RGB", (256 * 3, 256 * 2), (50, 50, 50))
        for i, u in enumerate(UNITS):
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
            bg = Image.new("RGBA", (256, 256), (60, 60, 60, 255))
            bg.paste(t, ((256 - t.width) // 2, (256 - t.height) // 2), t)
            sheet.paste(bg.convert("RGB"), ((i % 3) * 256, (i // 3) * 256))
        sheet.save(os.path.join(ROOT, ".godot", "agent_tools", "w5_vision_audit", "regen_w2_preview.png"))
        print("preview -> regen_w2_preview.png")
    elif mode == "deploy":
        for u in UNITS:
            tid = u["id"]
            fp = os.path.join(OUT, tid + "_white.png")
            assert os.path.exists(fp), fp
            eid = eid_of(tid)
            for p in (os.path.join(ROOT, "assets", "card_icons", "player", tid + ".png"),
                      os.path.join(ROOT, "assets", "card_icons", "enemy", eid + ".png")):
                bak = os.path.join(ROOT, "_art_backup",
                                   os.path.splitext(os.path.basename(p))[0] + "-preCP2C-2026-09-15.png")
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
        print("done — anchors + verify + reimport + 动画重建待办")


if __name__ == "__main__":
    main()
