# -*- coding: utf-8 -*-
"""米格-29 (cold_boss_mig) 单帧法: 4 动作帧逐帧独立 i2i (idle f0 锚) + 指纹一致 + 色迁移 + 书挡卡图。
用于 4 格同帧 i2i 主体漂移做不出的单位(小差动作/飞机)。
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
UNIT = "cold_boss_mig"
AK = "cold_mig21"                       # anim_key
OUT = os.path.join(WS, ".godot", "unit_review", "api_" + UNIT)
RAW = os.path.join(OUT, "raw"); os.makedirs(RAW, exist_ok=True)
os.makedirs(os.path.join(OUT, "frames"), exist_ok=True)
REF_H = 0.60                            # 飞机内容高占比(低, 宽机身)

# 4 动作帧(朝左, 单帧独立): 预备/开火(唯一焰)/后坐余烟/归稳
POSES = [
    "ready: the same MiG-29 fighter jet in stable level flight, cannon primed, engine running, NO flash",
    "firing: the same MiG-29 fighter jet firing its cannon, a compact star-shaped muzzle flash at the cannon muzzle, orange-yellow with a white core",
    "recoil: the same MiG-29 fighter jet just after firing, light smoke wisping from the cannon muzzle, cannon recoiled",
    "settled: the same MiG-29 fighter jet back to stable level flight, cannon at rest, engine running",
]
SUBJ = ("a MiG-29 fighter jet, exactly the same jet as in the reference image, twin-engine twin-tail, "
        "pointing to the LEFT in profile, ")

def ref_single():
    ims = Image.open(os.path.join(WS, "assets/effects/unit_anims", AK, "sheet_idle.png")).convert("RGBA")
    f0 = ims.crop((0, 0, FS, FS))
    cv = Image.new("RGBA", (1024, 1024), (255, 0, 255, 255))
    bb = f0.getbbox(); f0c = f0.crop(bb)
    s = 640 / f0c.height if f0c.height else 1
    f0c = f0c.resize((max(1, int(f0c.width * s)), int(f0c.height * s)), Image.LANCZOS)
    cv.paste(f0c, ((1024 - f0c.width) // 2, 1024 - f0c.height - 60), f0c)
    return cv.convert("RGB")

def single_i2i(prompt, ref_img, keys, tag):
    b64 = base64.b64encode(open_io(ref_img)).decode()
    url, kh = P.gen_i2i(prompt, b64, keys, 0, tag, image_size="1024x1024")
    pf = os.path.join(RAW, tag + ".png")
    subprocess.run(["curl", "-sS", "-m", "120", "-o", pf, url], check=True)
    return pf

def open_io(im):
    buf = io.BytesIO(); im.save(buf, format="PNG"); return buf.getvalue()

def key_to_frame(png_path, foot_frac=0.045):
    im = Image.open(png_path).convert("RGB")
    rgba = P.key_magenta(np.asarray(im))
    comp, _ = P.largest_component(rgba[:, :, 3])
    if comp is not None: rgba[:, :, 3] = comp
    a = rgba[:, :, 3]; ys, xs = np.where(a > 20)
    if len(xs) == 0: return None
    crop = Image.fromarray(rgba[ys.min():ys.max() + 1, xs.min():xs.max() + 1])
    th = int(FS * REF_H)
    s = th / crop.height
    max_w = int(FS * 0.92)
    if crop.width * s > max_w: s = max_w / crop.width
    crop = crop.resize((max(1, int(crop.width * s)), int(crop.height * s)), Image.LANCZOS)
    out = Image.new("RGBA", (FS, FS), (0, 0, 0, 0))
    px = (FS - crop.width) // 2                       # 飞机居中
    out.paste(crop, (px, FS - int(crop.height) - int(round(foot_frac * FS))), crop)
    return out

def sig(im):
    a = np.asarray(im); return P.palette_sig(a) if hasattr(P, "palette_sig") else None

if __name__ == "__main__":
    keys = P.load_keys()
    ref = ref_single()
    ref.save(os.path.join(OUT, "ref_single.png"))
    frames = []
    for i, pose in enumerate(POSES, start=2):
        for att in range(4):
            prompt = P.SKELETON.replace("{SUBJECT}", SUBJ + pose + "\n")
            pf = single_i2i(prompt, ref, keys, "mig_f%d" % i)
            fr = key_to_frame(pf)
            if fr is None:
                print("  f%d 空, 重掷" % i); time.sleep(8); continue
            frames.append(fr)
            print("  f%d 出帧" % i); break
    if len(frames) < 4:
        print("单帧不全, 放弃"); sys.exit(1)
    # 书挡 f1/f6 = 卡图
    card = Image.open(os.path.join(WS, "assets/card_icons/enemy/vis_enemy_056.png")).convert("RGBA")
    card = card.crop(card.getbbox())
    def book(c):
        th = int(FS * REF_H); s = th / c.height
        c2 = c.resize((int(c.width * s), th), Image.LANCZOS)
        out = Image.new("RGBA", (FS, FS), (0, 0, 0, 0)); out.paste(c2, ((FS - c2.width)//2, FS - th - int(round(0.05*FS))), c2); return out
    bookend = book(card)
    order = [bookend, frames[0], frames[1], frames[2], frames[3], bookend]
    for i, fr in enumerate(order, 1):
        fr.save(os.path.join(OUT, "frames", "f%d.png" % i))
    sheet = Image.new("RGBA", (FS * 6, FS), (0, 0, 0, 0))
    for i, fr in enumerate(order):
        sheet.paste(fr, (i * FS, 0))
    sheet.save(os.path.join(OUT, "sheet_attack_api.png"))
    json.dump({"unit": UNIT, "method": "single-frame", "note": "米格单帧法, 4 帧逐帧 i2i + 卡图书挡"},
              open(os.path.join(OUT, "batch_result.json"), "w"), ensure_ascii=False, indent=1)
    print("done →", OUT)
