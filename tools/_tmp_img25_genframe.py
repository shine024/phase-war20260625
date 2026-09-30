# -*- coding: utf-8 -*-
"""img25 生成动作帧链路验证（2026-09-30）——跑通流程用，非批量。

完整链：卡图锚 → 单帧生成开火动作（英文 SUBJECT 锁身份）→ matte v2 →
火光判向 → 对齐 f0 → 序列（s_fire=生成帧整帧身体+焰；衰减帧=f0+焰贴片）。

用法：python tools/_tmp_img25_genframe.py key1 key2 ...
产物：.godot/unit_review/img25_staging/genframe/<key>/
      raw → matte → aligned → sheet_idle/attack → _check.png（全尺寸逐帧目检拼图）
"""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import _tmp_img25_redo_88 as R
import _tmp_img25_hybrid_sample as H

OUT = os.path.join(ROOT, ".godot", "unit_review", "img25_staging", "genframe")
FS = 256

# 英文 SUBJECT 锁身份（视觉反推自动化前的手写样本；批量时走 agnes 反推缓存）
SUBJECTS = {
    "cold_ak47": ("the standing infantry rifleman shown in Image 1: a soldier in a long "
                  "olive winter greatcoat and steel helmet holding an assault rifle at "
                  "hip level — a single human foot soldier, NOT a vehicle, NOT a robot, no armor"),
    "ww2_arm_tiger": ("the exact same German WWII Tiger tank as in Image 1, identical size and "
                      "proportions: a boxy tank with "
                      "vertical frontal armor, interleaved overlapping road wheels, and a "
                      "long-barreled turret gun — strictly a tank, no wings, no legs"),
    "mod_challenger2": ("the modern main battle tank shown in Image 1: an angular hull with "
                        "sloped composite turret, side skirts and a long smoothbore gun — "
                        "strictly a tank, no wings"),
    "cold_rpg": ("the tripod-mounted recoilless gun shown in Image 1: a long olive tube on "
                 "a low tripod with a square shield plate and a rocket in the muzzle — "
                 "strictly the weapon on its mount alone, NO people, NO soldier"),
    "mod_ah64": ("the attack helicopter shown in Image 1: a tandem-cockpit gunship with "
                 "stub wings carrying rocket pods, a chin gun turret and a tail rotor — "
                 "strictly a helicopter, no wheels touching ground"),
    "cold_f4": ("the jet fighter shown in Image 1: a Cold-War era jet with swept wings, "
                "a pointed nose and twin engines — strictly a jet aircraft in flight"),
    "guardian_future_omega": ("the heavy future mech shown in Image 1: a bipedal robot with "
                              "broad shoulder armor, glowing blue energy cores and heavy "
                              "limbs — strictly a walking mech, no wings, no wheels"),
    "ww1_flame": ("the German WWII infantryman shown in Image 1: a soldier in field-grey "
                  "uniform, long boots and steel helmet firing a stamped assault rifle — "
                  "a single human soldier, NOT a vehicle"),
}

# 开火姿态描述（按武器类型；此表先手写两样本）
FIRE_POSE = {
    "cold_ak47": "the rifle raised to the shoulder firing position, a bright muzzle flash "
                 "at the barrel tip, head slightly leaning into the stock, subtle recoil "
                 "lean-back",
    "ww2_arm_tiger": "a huge muzzle blast at the gun barrel tip, the barrel in visible "
                     "recoil, dust kicked up beside the muzzle",
    "mod_challenger2": "a bright muzzle flash at the gun tip, the barrel in full recoil",
    "cold_rpg": "the tube stays on its tripod exactly as in Image 1, a bright muzzle flash "
                "at the tube tip and dust kicked up behind the mount",
    "mod_ah64": "rocket pods firing with small bright flashes, the chin gun blazing tracers",
    "cold_f4": "the nose cannon firing a bright flash, a brief missile trail from the wing",
    "guardian_future_omega": "its arm cannon discharging a bright blue-white energy burst",
    "ww1_flame": "the rifle at the shoulder firing a bright muzzle flash, slight recoil lean",
}

FIRE_PROMPT = """Intended use:
Edit a 2D game sprite image to create a single attack frame.

Input images:
Image 1 is a game sprite of %s, facing LEFT in exact side view.

Primary request:
Edit Image 1: the subject is FIRING its weapon right now — %s.
Everything that is not the weapon or the pose stays exactly the same: same body shape, same colors, same panel lines, same details, same scale, same left-facing side view, same pure white background. The weapon flash and the firing pose are the only new things.

Background: the same pure flat white as Image 1, edge to edge; no ground, no shadow, no label, no border.

Style:
- identical art style to Image 1, crisp edges, consistent lighting and palette

Constraints:
- the ENTIRE subject stays visible in frame at the SAME scale as Image 1 — do NOT zoom in, do NOT show the weapon alone, do NOT draw any close-up
- the weapon stays held/mounted on the subject exactly as in Image 1
- same identity: do NOT redesign, do NOT change colors or proportions
- a small, brief flash at the weapon only; no fire anywhere else
- exactly one subject, the same individual as Image 1; no extra soldiers, no extra vehicles
- do not crop any part of the subject
"""  # noqa: E501


def run(key, rel, weapon, energy, defensive):
    d = os.path.join(OUT, key)
    os.makedirs(d, exist_ok=True)
    H.KEY, H.REL, H.OUT = key, rel, d

    f0, ref = R.load_card(rel)
    if rel.startswith("player/") and key == "fut_nano_drone":
        f0 = f0.transpose(Image.FLIP_LEFT_RIGHT)
    f0.save(os.path.join(d, "f0.png"))

    subj = SUBJECTS.get(key)
    if subj is None:
        print("%s: 无 SUBJECT，跳过（批量前需视觉反推）" % key)
        return
    prompt = FIRE_PROMPT % (subj, FIRE_POSE[key])

    # 1 生成开火动作帧（带缓存）
    rawp = os.path.join(d, "fire_raw.png")
    if not os.path.exists(rawp):
        pf = os.path.join(d, "fire_payload.json")
        open(pf, "w", encoding="utf-8").write(json.dumps({
            "model": "agnes-image-2.5-flash", "prompt": prompt,
            "size": "2K", "ratio": "16:9",
            "extra_body": {"image": [H.uri(ref)], "response_format": "b64_json"}},
            ensure_ascii=False))
        raw = R.gen_payload(pf)
        if not raw:
            print("%s: 生成失败" % key)
            return
        open(rawp, "wb").write(raw)

    # 2 matte v2 + 3 火光判向（matte 内置）
    fm = H.matte_centered(open(rawp, "rb").read())
    if fm is None:
        print("%s: matte 失败" % key)
        return
    fm.save(os.path.join(d, "fire_matte.png"))

    # 4 对齐 f0
    fire_al = H.align_to_f0(fm, f0)
    fire_al.save(os.path.join(d, "fire_al.png"))

    # 5 序列：s_fire=生成帧整帧；衰减=f0+生成焰抠取（兜底程序焰）
    fl = H.extract_flash(fire_al)
    flash_src = "生成焰抠取"
    if fl is None:
        fl = H.prog_flash()
        flash_src = "程序焰兜底"
    a = np.asarray(f0)
    ys, xs = np.where(a[:, :, 3] > 8)
    if key in H.MUZZLE_OVERRIDE:
        mx, my = H.MUZZLE_OVERRIDE[key]
    else:
        x0 = int(xs.min())
        band = ys[xs <= x0 + 3]
        mx, my = x0, int(band.mean())
    fl_half = fl.point(lambda v: int(v * 0.55))
    s_fire = fire_al                                   # 生成帧整帧（身体动作+焰）
    s_decay = H.overlay(f0, fl_half, mx + 1, my)       # 身体回 f0，焰衰减
    idle_srcs = [f0, H.shift(f0, 0, -1), H.shift(f0, 0, -2), H.shift(f0, 0, -1),
                 f0, H.shift(f0, 0, 1), H.shift(f0, 0, 2), H.shift(f0, 0, 1)]
    atk_srcs = [f0, f0, s_fire, H.shift(s_decay, 2, 1), H.shift(f0, 2, 1), f0]
    order = [0, 1, 2, 3, 4, 5, 5, 4, 3, 2, 1, 0]
    atk_frames = [atk_srcs[i] for i in order]
    for name, frames in (("idle", idle_srcs), ("attack", atk_frames)):
        sheet = Image.new("RGBA", (FS * len(frames), FS), (0, 0, 0, 0))
        for i, fr in enumerate(frames):
            sheet.alpha_composite(fr, (i * FS, 0))
        sheet.save(os.path.join(d, "sheet_%s.png" % name))

    # 6 全尺寸目检拼图：f0 | fire_al | idle x8 | attack x12（原尺寸 128）
    def strip(im, h=128):
        return im.resize((im.width * h // FS, h), Image.LANCZOS)
    w_id = FS * 8 * 128 // FS
    w_at = FS * 12 * 128 // FS
    W = max(300, w_id + 12) + 12
    img = Image.new("RGB", (W, 128 + 160 + 150 + 40), (16, 16, 20))
    dr = ImageDraw.Draw(img)
    f0t = f0.resize((128, 128), Image.LANCZOS)
    ft = fire_al.resize((128, 128), Image.LANCZOS)
    dr.text((6, 4), "%s f0 | fire_al | flash=%s" % (key, flash_src), fill=(255, 210, 120))
    img.paste(f0t, (6, 24), f0t)
    img.paste(ft, (140, 24), ft)
    si = strip(Image.open(os.path.join(d, "sheet_idle.png")).convert("RGBA"))
    sa = strip(Image.open(os.path.join(d, "sheet_attack.png")).convert("RGBA"))
    dr.text((6, 160), "idle x8", fill=(255, 210, 120))
    img.paste(si, (6, 178), si)
    dr.text((6, 312), "attack x12", fill=(255, 210, 120))
    img.paste(sa, (6, 330), sa)
    img.save(os.path.join(d, "_check.png"))
    print("%s: 完成（flash=%s, muzzle=%s）→ _check.png" % (key, flash_src, (mx, my)))


def main():
    keys = sys.argv[1:]
    for (key, rel, weapon, energy, defensive) in R.U:
        if not keys or key in keys:
            run(key, rel, weapon, energy, defensive)


if __name__ == "__main__":
    main()
