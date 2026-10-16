# -*- coding: utf-8 -*-
"""ww2_inf_panzerschrek 单帧法（§7.6.2 mig_single 同路线）。
网格 4 格 i2i 六卷掷尽 f2/f4 仍变形(小差动作主体一致性做不出)→逐帧独立 i2i:
每帧 1024² 全幅单主体, 锚=镜像玩家卡图(朝左), 开火多帧连贯(蓄势→击发→后坐→归稳)。
键控 + 载具居中贴帧 + 书挡(镜像卡图) + 净高迭代归一。
用法: python tools/api_sprite_pipeline/pz_single.py
"""
import base64, io, json, os, subprocess, sys, time
import numpy as np
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__))
WS = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.argv = [sys.argv[0]]
sys.path.insert(0, HERE)
import generate_attack_api as P

FS = 256
UNIT = "ww2_inf_panzerschrek"
OUT = os.path.join(WS, ".godot", "unit_review", "api_" + UNIT)
RAW = os.path.join(OUT, "raw"); os.makedirs(RAW, exist_ok=True)
os.makedirs(os.path.join(OUT, "frames"), exist_ok=True)
REF_H = 0.55                            # 车内容高占比(现役 anim attack_h=0.5508)
FOOT = 8                                # 落地余量 px(现役 foot_frac 0.0332)

# 多帧开火循环(朝左, 单帧独立, 蓄势→击发→后坐→归稳 连续展开)
POSES = [
    ("pz_f2",
     "aiming: the same armored vehicle settling onto its suspension as the turret weapon "
     "finishes traversing to point straight LEFT, the crew bracing for the shot, "
     "flat exact side profile view, identical shape and proportions as the reference"),
    ("pz_f3",
     "firing: the same armored vehicle discharging the turret weapon, a compact star-shaped "
     "muzzle flash exactly at the weapon muzzle tip, orange-yellow with a white core, the hull "
     "rocking back on its suspension, flat exact side profile view, identical shape and "
     "proportions as the reference, the entire vehicle and flash well inside the frame"),
    ("pz_f4",
     "recoil: the same armored vehicle just after the shot, the turret weapon recoiled back, "
     "the hull pressed down onto its suspension recovering from the recoil, light exhaust haze "
     "drifting from the muzzle, flat exact side profile view, identical shape and proportions "
     "as the reference"),
    ("pz_f5",
     "recovering: the same armored vehicle settling back to rest, the turret weapon returning "
     "to point LEFT, the suspension leveling out, flat exact side profile view, identical "
     "shape and proportions as the reference"),
]
SUBJ = ("a modern six-wheeled armored vehicle, exactly the same vehicle as in the reference "
        "image, same turret, same wheels and same armor layout, small blue electric-glow "
        "accents only on its armor panels, the vehicle silhouette is single and clear, "
        "facing LEFT in profile, never mirrored, ")

GLOW_TAIL = ("small blue electric-glow accents only on its armor panels, the vehicle "
             "silhouette is single and clear, no second outline, nothing touches or "
             "crosses the image edges")


def ref_single():
    """镜像玩家卡图 → 1024² 品红底居中单主体参考"""
    card = Image.open(os.path.join(WS, "assets/card_icons/player/vis_player_010.png")).convert("RGBA")
    card = card.transpose(Image.FLIP_LEFT_RIGHT).crop(card.getbbox())
    cv = Image.new("RGBA", (1024, 1024), (255, 0, 255, 255))
    s = 640 / card.height
    c2 = card.resize((int(card.width * s), 640), Image.LANCZOS)
    cv.paste(c2, ((1024 - c2.width) // 2, 1024 - c2.height - 60), c2)
    return cv.convert("RGB")


def single_i2i(prompt, ref_img, keys, tag):
    buf = io.BytesIO(); ref_img.save(buf, format="PNG")
    b64 = base64.b64encode(buf.getvalue()).decode()
    body = {"model": P.MODEL, "prompt": prompt, "image_size": "1024x1024",
            "extra_body": {"image": ["data:image/png;base64," + b64], "response_format": "url"}}
    pf = os.path.join(RAW, "payload_%s.json" % tag)
    json.dump(body, open(pf, "w"))
    for att in range(6):
        key = keys[att % len(keys)]
        r = subprocess.run(["curl", "--http1.1", "-sS", "-m", "300", "-X", "POST",
                            "https://apihub.agnes-ai.com/v1/images/generations",
                            "-H", "Authorization: Bearer " + key, "-H", "Content-Type: application/json",
                            "-d", "@" + pf, "-w", "\nHTTP_CODE:%{http_code}"],
                           capture_output=True, text=True, encoding="utf-8", errors="replace")
        try:
            js = json.loads(r.stdout.rsplit("\nHTTP_CODE:", 1)[0])
        except Exception:
            time.sleep(5); continue
        if "data" in js and js["data"] and js["data"][0].get("url"):
            url = js["data"][0]["url"]
            if "/i2i/" in url:
                out = os.path.join(RAW, tag + ".png")
                subprocess.run(["curl", "-sS", "-m", "120", "-o", out, url], check=True)
                return out
            print("  %s 非 i2i, 重掷" % tag); time.sleep(5); continue
        time.sleep(6)
    raise RuntimeError("i2i failed: " + tag)


def key_to_frame(png_path):
    """品红键控 → 最大连通域 → 256 帧载具居中, 返回 (frame, 净高)"""
    im = Image.open(png_path).convert("RGB")
    rgba = P.key_magenta(np.asarray(im))
    comp, _ = P.largest_component(rgba[:, :, 3])
    if comp is not None: rgba[:, :, 3] = comp
    a = rgba[:, :, 3]; ys, xs = np.where(a > 20)
    if len(xs) == 0: return None, 0
    crop = Image.fromarray(rgba[ys.min():ys.max() + 1, xs.min():xs.max() + 1])
    th = int(FS * REF_H)
    s = th / crop.height
    max_w = int(FS * 0.94)
    if crop.width * s > max_w: s = max_w / crop.width
    crop = crop.resize((max(1, int(crop.width * s)), max(1, int(crop.height * s))), Image.LANCZOS)
    out = Image.new("RGBA", (FS, FS), (0, 0, 0, 0))
    out.paste(crop, ((FS - crop.width) // 2, FS - crop.height - FOOT), crop)
    return out, th


def body_h(fr):
    a = np.asarray(fr); rgb = a[:, :, :3].astype(int)
    FLASH = (rgb[:, :, 0] > 190) & (rgb[:, :, 1] > 120) & (rgb[:, :, 1] < 220) & (rgb[:, :, 2] < 130)
    WHITE = (rgb[:, :, 0] > 205) & (rgb[:, :, 1] > 205) & (rgb[:, :, 2] > 205)
    body = (a[:, :, 3] > 20) & ~FLASH & ~WHITE
    ys, xs = np.where(body)
    return ys.max() - ys.min() + 1, xs.min(), ys.min(), xs.max(), ys.max()


if __name__ == "__main__":
    keys = P.load_keys()
    ref = ref_single()
    ref.save(os.path.join(OUT, "ref_single_flip.png"))
    frames = {}
    for tag, pose in POSES:
        prompt = P.SKELETON.replace("{SUBJECT}", SUBJ + pose + ", " + GLOW_TAIL + "\n")
        for att in range(4):
            try:
                pf = single_i2i(prompt, ref, keys, tag)
            except RuntimeError as e:
                print("  %s × %s" % (tag, e)); time.sleep(15); continue
            fr, th = key_to_frame(pf)
            if fr is None:
                print("  %s 空, 重掷" % tag); time.sleep(8); continue
            frames[tag] = fr
            print("  %s 出帧" % tag, flush=True)
            break
    if len(frames) < 4:
        print("单帧不全(%d/4), 放弃" % len(frames)); sys.exit(1)
    # 净高迭代归一(至差<=2px)
    def normalize():
        hs = {k: body_h(im)[0] for k, im in frames.items()}
        base = min(hs.values())
        for rnd in range(4):
            if max(hs.values()) - min(hs.values()) <= 2: break
            for k, im in frames.items():
                h, x0, y0, x1, y1 = body_h(im)
                s = base / h
                if abs(s - 1) <= 0.003: continue
                im2 = im.resize((int(round(FS * s)),) * 2, Image.LANCZOS)
                _, x0, y0, x1, y1 = body_h(im2)
                o = Image.new("RGBA", (FS, FS), (0, 0, 0, 0))
                o.paste(im2, ((FS - (x1 - x0 + 1)) // 2 - x0, FS - FOOT - (y1 - y0 + 1) - y0), im2)
                frames[k] = o
            hs = {k: body_h(im)[0] for k, im in frames.items()}
            print("  归一轮%d: %s 差%d" % (rnd + 1, hs, max(hs.values()) - min(hs.values())))
    normalize()
    # 书挡 f1/f6 = 镜像卡图
    card = Image.open(os.path.join(WS, "assets/card_icons/player/vis_player_010.png")).convert("RGBA")
    card = card.transpose(Image.FLIP_LEFT_RIGHT).crop(card.getbbox())
    def book(c):
        s = int(FS * REF_H) / c.height
        c2 = c.resize((int(c.width * s), int(FS * REF_H)), Image.LANCZOS)
        o = Image.new("RGBA", (FS, FS), (0, 0, 0, 0))
        o.paste(c2, ((FS - c2.width) // 2, FS - int(FS * REF_H) - FOOT), c2)
        return o
    bk = book(card)
    order = [bk, frames["pz_f2"], frames["pz_f3"], frames["pz_f4"], frames["pz_f5"], bk]
    for i, fr in enumerate(order, 1):
        fr.save(os.path.join(OUT, "frames", "f%d.png" % i))
    sheet = Image.new("RGBA", (FS * 6, FS), (0, 0, 0, 0))
    for i in range(6):
        sheet.paste(Image.open(os.path.join(OUT, "frames", "f%d.png" % (i + 1))), (i * FS, 0))
    sheet.save(os.path.join(OUT, "sheet_attack_api.png"))
    old = Image.open(os.path.join(WS, "assets/effects/unit_anims/ww2_inf_panzerschrek/sheet_attack.png")).convert("RGBA")
    cv = Image.new("RGBA", (FS * 6, FS * 2 + 8), (16, 20, 24, 255))
    for i in range(6):
        cv.paste(old.crop((i * FS, 0, (i + 1) * FS, FS)), (i * FS, 0))
    cv.paste(sheet, (0, FS + 8))
    cv.save(os.path.join(OUT, "strip_new_vs_old.png"))
    hs = {i: body_h(Image.open(os.path.join(OUT, "frames", "f%d.png" % i)))[0] for i in range(1, 7)}
    print("终净高:", hs, "差:", max(hs.values()) - min(hs.values()))
    print("done")
