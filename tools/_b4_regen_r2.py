# -*- coding: utf-8 -*-
"""B4 重掷轮 R2：用户审阅页导出 b4_regen_list.json 的 24 案（2026-10-04 02:45）。
提示词全英文（用户实测：英文提示反馈更好、生成更准确；结构 1:1 镜像已验证的中文 STRICT 串）。
- 22 案：旧 raw 备份为 _raw_prev.png（并清同代 dark1/dark2/left 备份）→ 重掷 → gain 收敛（无注入）→
  门；仍不过门走单图 relight 兜底。
- vis_player_061/vis_enemy_061（描线+半身）：放弃 sheet f0 派生，改真生图（游骑兵/三角洲全身厚涂立绘）；
  朝向约定 player 朝右 / enemy 朝左（vis_enemy_021 实拍证实）。
星战风修法=正向装具时代锚（modern tactical gear / chitin exoskeleton）；agnes 负词反噬定律全程遵守。
用法: python tools/_b4_regen_r2.py [id子串过滤]
"""
import io, json, os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STAGE = os.path.join(ROOT, ".godot", "b4_card_staging")
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
from PIL import Image
import numpy as np


def load(name, path):
    """加载工具模块但剔除其顶层的 stdout 重包行（连环重包会互相关掉共享缓冲）。"""
    import types
    src = open(path, encoding="utf-8").read()
    lines = [ln for ln in src.splitlines() if "sys.stdout = io.TextIOWrapper" not in ln]
    mod = types.ModuleType(name)
    mod.__file__ = path
    exec(compile("\n".join(lines), path, "exec"), mod.__dict__)
    return mod


b4 = load("b4r_gen", os.path.join(ROOT, "tools", "_b4_card_gen.py"))
gl = load("b4r_gain", os.path.join(ROOT, "tools", "_b4_gain_loop.py"))

REROLL = ["flame_raider_advanced", "flame_raider_expert", "flame_siege_basic", "flame_siege_advanced",
          "flame_siege_expert", "steel_fortress_expert", "steel_titan_basic", "steel_titan_advanced",
          "steel_titan_expert", "thunter_striker_basic", "thunter_striker_advanced",
          "thunter_striker_expert", "thunter_sniper_basic", "thunter_sniper_expert",
          "void_stealth_basic", "void_stealth_advanced", "mod_arm_stryker_e", "fut_arm_prism",
          "ww1_arm_rolls", "ww1_inf_mp18_x", "mod_inf_scout_drone", "fe_helix_phantom"]

# ---------- 英文提示词（镜像中文 STRICT 结构） ----------
PLAT_EN = ("Game card illustration of {subject}, {tier}.\n"
           "Strictly flat side profile, facing right: the camera is exactly at the subject's own side, "
           "level with its midline; the subject's long axis stretches horizontally across the whole "
           "image, its upright parts stay vertical, and the front and rear faces are not visible; "
           "no perspective foreshortening.\n"
           "{axis}{pose}"
           "Full body complete and centered, about 10% even white margin on all sides, nothing touching "
           "the canvas edges, feet fully inside the frame.\n"
           "{accent}Muted cold palette of deep blue-grey steel and cold grey, the subject fully and evenly "
           "lit with plenty of light, distinct highlights and shadow layers, material detail clearly "
           "readable, a bright readable painted figure.\n"
           "Thick painterly illustration style: forms shaped by color masses and value transitions, "
           "smooth blended brushwork (rendered painterly color masses).\n"
           "Seamless pure white studio background: flat pure white, an empty photo-studio backdrop.\n"
           "[Single subject - hard rule] exactly ONE subject in the whole frame, the unit itself; "
           "the white studio backdrop contains nothing else.\n"
           "No text, watermark, frame, border, or flag-emblem lettering anywhere.\n"
           "text, perspective view, frame, ground, ceiling, foreshortening")

FAM_EN = {
    "flame_raider": "a flame-raider assault trooper in modern fire-proximity gear: one-piece heat-resistant "
                    "suit, full-coverage fire mask, backpack fuel-cylinder group, holding a compact "
                    "flamethrower two-handed, a tiny ember-orange pilot glow at the nozzle",
    "flame_siege": "a heavy flame-throwing siege piece on a fixed emplacement: massive projector cannon on a "
                   "baseplate with mount and gun shield, barrel at medium elevation, a tiny ember-orange glow "
                   "at the emitter; a fixed emplacement, not a tank, not a vehicle, no tracks, no wheels",
    "steel_fortress": "a giant fortress: a massive fixed defensive fortification building with recessed "
                      "turret mounts and layered armor plating, standing on its foundation; a building, "
                      "not a tank, no tracks, no wheels, cannot move",
    "steel_titan": "a heavy battle tank: rotating turret with a long main gun, layered armor and wide "
                   "track runs",
    "thunter_striker": "a tesla strike trooper in modern modular infantry gear: tactical vest with external "
                       "battery packs and insulated armor pads, full-coverage tactical helmet with goggles, "
                       "holding a tesla carbine with arcing electricity and exposed cables",
    "thunter_sniper": "a tesla sniper in modern marksman gear: tactical helmet, optics stack, camo wrap, "
                      "insulated cape, holding a long-range precision rifle with a high-magnification scope",
    "void_stealth": "a void stalker: an alien creature in an angular dark matte chitin exoskeleton like "
                    "insect plating, faint glow in the shell seams, holding a curved blade, light half-cape, "
                    "agile silhouette",
}
TIER_EN = {"basic": "standard-issue equipment with a clean functional look",
           "advanced": "upgraded variant: additional armor plating, reinforced joints, a second weapon mount",
           "expert": "elite refit: glowing energy core, ornate trim lines, master-crafted finish"}
AXIS_EN = {
    "steel_titan": "the hull stretches horizontally across the whole image: both track runs overlap into "
                   "one single continuous track line, only one row of road wheels visible; the front and "
                   "rear faces are not visible at all, no perspective foreshortening;",
    "flame_siege": "the barrel and mount stretch horizontally across the whole image: the gun shield seen "
                   "exactly in side profile, the muzzle never points at the camera; no perspective "
                   "foreshortening;",
    "steel_fortress": "the fortress facade stretches horizontally across the whole image, turrets facing "
                      "right; no front or rear face visible, no perspective foreshortening;",
    "flame_raider": "only one cheek and one shoulder visible, the far arm hidden behind the torso, nozzle "
                    "and nose both pointing right; no perspective foreshortening;",
    "thunter_striker": "only one cheek and one shoulder visible, the far arm hidden behind the torso, "
                       "carbine muzzle and nose both pointing right; no perspective foreshortening;",
    "thunter_sniper": "only one cheek and one shoulder visible, the far arm hidden behind the torso, rifle "
                      "muzzle and nose both pointing right; no perspective foreshortening;",
    "void_stealth": "only one cheek profile visible, the far arm hidden behind the torso, curved blade and "
                    "nose both pointing right; no perspective foreshortening;",
}
POSE_EN = {
    "flame_raider": "holding the flamethrower two-handed raised to the shoulder, nozzle pointing right, "
                    "ready to unleash the flame;",
    "thunter_striker": "holding the tesla carbine raised to the shoulder, stock at the cheek, aiming;",
    "thunter_sniper": "holding the long rifle raised to the shoulder, stock at the cheek, aiming through "
                      "the scope;",
    "void_stealth": "curved blade pointed forward, lunging-ready stance;",
}
ACCENT_EN = "one small warm ember-orange accent glow on this flame unit; "

CONVERT_EN = ("The first image is the reference card artwork. Repaint it as a new game card "
              "illustration: {subject}.\n"
              "[Viewpoint - hard rule] strictly flat side profile facing right: the camera is exactly at "
              "the subject's own side, level with its midline; the subject's long axis stretches "
              "horizontally across the whole image, its upright parts stay vertical; never a top-down, "
              "oblique or three-quarter view.\n"
              "[Composition - hard rule] single subject centered, full body complete, about 10% even white "
              "margin on all sides, nothing touching the canvas edges, feet fully inside the frame, "
              "no cropping.\n"
              "[Parts - hard rule] the parts and equipment stay exactly the same as the reference; add "
              "nothing, remove nothing, simplify nothing.\n"
              "[Axis - hard rule] the subject's long axis stretches horizontally across the whole image: "
              "only one side is visible (a trooper shows one cheek and one shoulder, the far arm hidden "
              "behind the torso); the front and rear faces are not visible, no perspective foreshortening; "
              "wheels or tracks overlap into one single continuous row in side view.\n"
              "[Single subject - hard rule] exactly this one subject in the frame; the background is a "
              "seamless pure white studio backdrop, flat pure white, an empty photo-studio backdrop, "
              "nothing else in the frame.\n"
              "[Palette - hard rule] muted cold palette of deep blue-grey steel and cold grey, the subject "
              "fully and evenly lit with plenty of light, distinct highlights and shadow layers, material "
              "detail clearly readable; {accent}\n"
              "[Style - hard rule] thick painterly illustration: forms shaped by color masses and value "
              "transitions, smooth blended brushwork, hard-edge steel surfaces; seamless pure white studio "
              "background, no ground, no scene, no cast shadow.\n"
              "No text, watermark, frame, border, or flag-emblem lettering anywhere.\n"
              "text, perspective view, frame, ground, ceiling, foreshortening")

REGEN_EN = {
    "mod_arm_stryker_e": ("assets/card_icons/player/vis_player_059.png",
                          "a modern eight-wheeled armored personnel carrier (Stryker-type), boxy hull seen "
                          "in full side profile, roof weapon station"),
    "fut_arm_prism": ("assets/card_icons/player/vis_player_026.png",
                      "a near-future prism main battle tank: faceted angular armor, long gun barrel and "
                      "mirrored optics turret"),
    "ww1_arm_rolls": (None,
                      "a WW1 Rolls-Royce armoured car: long rectangular bonnet with vertical radiator "
                      "slats, four spoked pneumatic wheels (a wheeled vehicle, absolutely no tracks), rear "
                      "hull with a spherical rotating turret and a slim gun barrel; WW1 British army green "
                      "desaturated to a cold grey-green"),
    "ww1_inf_mp18_x": ("assets/card_icons/player/ww1_inf_enfield.png",
                       "a WW1 stormtrooper in the same style and era as the reference: steel helmet, "
                       "greatcoat, puttee boots, holding an MP18 submachine gun raised to the shoulder "
                       "aiming; swap the reference rifle for an MP18, keep the rest of the identity"),
    "fe_helix_phantom": ("assets/card_icons/player/fe_helix_phantom.png",
                         "a near-future phase phantom trooper: skintight lightweight phase fabric suit and "
                         "hood (soft cloth material), light armor plates on shoulders and chest, energy "
                         "blade sheathed at the waist"),
    "mod_inf_scout_drone": ("assets/card_icons/player/vis_player_022.png",
                            "a modern quadcopter scout drone: slim fuselage, gimbal camera and antennas, "
                            "level side-view flight attitude"),
}
REGEN_T2I_EXTRA_EN = {
    "ww1_arm_rolls": "the four spoked wheels overlap into one single row of wheels seen in profile; the "
                     "front and rear faces are not visible at all, no perspective foreshortening;",
}

# 构图违约补强后缀（贴边/裁切案专用，二次重掷时加）
EXTRA_SUFFIX = {
    "thunter_striker_basic":
        "Zoomed-out wide framing: the complete figure visible from helmet to boots, generous white "
        "space on all four sides, the entire carbine fully inside the frame with the muzzle far from "
        "the canvas edges.",
    "flame_siege_advanced":
        "Zoomed-out wide framing: the entire emplacement including its full baseplate and mount legs "
        "fully inside the frame, generous white space on all four sides, the whole barrel visible with "
        "the muzzle far from the canvas edges.",
}

DELTA_SUBJECT = ("an elite modern special-forces rifleman (army ranger): deep blue-grey combat uniform, "
                 "sand-colored modular magazine rig and tactical belt, balaclava, holding a carbine rifle "
                 "raised to the shoulder aiming, full tactical gear detail")
DELTA_AXIS = AXIS_EN["thunter_striker"].replace("carbine muzzle", "rifle muzzle")
DELTA_POSE = "holding the carbine raised to the shoulder, stock at the cheek, aiming;"

SINGLE_RELIGHT = ("The first image is a game card illustration with correct composition, but painted far "
                  "too dark. Output a new image:\n"
                  "[Keep] exactly the same viewpoint, composition, every part, pose and size as the first "
                  "image, part-for-part overlap; keep the background flat pure white.\n"
                  "[Fix light only] the subject fully and evenly lit, distinct highlights, midtones and "
                  "shadow layers, material detail clearly readable; keep the first image's paint-scheme "
                  "identity.\n"
                  "[Style] thick painterly illustration, forms shaped by color masses. "
                  "No text, watermark, or frame.")


def gain_loop_img(im):
    """对单张图跑 gain 收敛循环，返回 (图, ok, info)。"""
    a = np.asarray(im.convert("RGB")).astype(float)
    ok, info = gl.gate(a.astype(int))
    for tgt in gl.TARGETS:
        if ok:
            break
        _, body = gl.body_mask(a)
        m = float(a[body].mean())
        gain = max(1.0, min(tgt / max(m, 1.0), 1.35))
        if gain <= 1.01:
            break
        a = np.clip(a * gain, 0, 255)
        a[a.min(axis=2) >= gl.WHITE_SNAP] = 255.0
        ok, info = gl.gate(a.astype(int))
    return Image.fromarray(a.astype(np.uint8)), ok, info


def single_relight(p):
    payload = {"model": b4.MODEL, "prompt": SINGLE_RELIGHT, "size": "1024x1024",
               "extra_body": {"image": [b4.uri_of(p)], "response_format": "b64_json"}}
    raw = b4.gen(payload, "srelight")
    if not raw:
        return None
    return Image.open(io.BytesIO(raw)).convert("RGB")


def clear_old_backups(cid):
    for suf in ("_raw_dark1.png", "_raw_dark2.png", "_raw_left.png"):
        f = os.path.join(STAGE, cid + suf)
        if os.path.isfile(f):
            os.remove(f)


def case_prompt(cid):
    if cid in REGEN_EN:
        ref, subject = REGEN_EN[cid]
        prompt = CONVERT_EN.format(subject=subject, accent="")
        if not ref:
            prompt = PLAT_EN.format(subject=subject, tier=TIER_EN["basic"], accent="",
                                    axis=REGEN_T2I_EXTRA_EN.get(cid, ""), pose="")
        return prompt, ref
    fam, _, tier = cid.rpartition("_")
    prompt = PLAT_EN.format(subject=FAM_EN[fam], tier=TIER_EN[tier],
                            accent=ACCENT_EN if fam in ("flame_raider", "flame_siege") else "",
                            axis=AXIS_EN.get(fam, ""), pose=POSE_EN.get(fam, ""))
    return prompt, None


def main():
    only = sys.argv[1] if len(sys.argv) > 1 else None
    marks = {}
    jl = os.path.join(STAGE, "b4_regen_list.json")
    if os.path.isfile(jl):
        try:
            marks = {m["id"]: m.get("tags", []) for m in
                     json.load(open(jl, encoding="utf-8")).get("regen", [])}
        except Exception as e:
            print("清单读取失败（继续，不带标签）:", e)
    for cid in REROLL:
        if only and only not in cid:
            continue
        p = os.path.join(STAGE, cid + "_raw.png")
        done = p + ".r2done"
        if os.path.isfile(p) and os.path.isfile(done):
            print("[skip] %s 已完成（r2done）" % cid, flush=True)
            continue
        if os.path.isfile(done):
            os.remove(done)
        if os.path.isfile(p):
            prev = os.path.join(STAGE, cid + "_raw_prev.png")
            if os.path.isfile(prev):
                os.remove(prev)
            os.rename(p, prev)
        clear_old_backups(cid)
        prompt, ref = case_prompt(cid)
        if cid in EXTRA_SUFFIX:
            prompt = prompt + "\n" + EXTRA_SUFFIX[cid]
        b4.run_case(cid, prompt, ref)
        if not os.path.isfile(p):
            print("[FAIL] %s 重掷无果" % cid, flush=True)
            continue
        im, ok, info = gain_loop_img(Image.open(p))
        if not ok:
            im2 = single_relight(p)
            if im2 is not None:
                im, ok, info = gain_loop_img(im2)
        im.save(p)
        open(done, "w").write("ok")
        print("[%s] %s tags=%s %s" % ("OK" if ok else "MISS", cid, marks.get(cid, []),
                                      json.dumps(info, ensure_ascii=False)), flush=True)
    # ── delta 对：真生图替换 sheet f0 派生 ──
    if not only or "delta" in only or "061" in only:
        dpdone = os.path.join(STAGE, "_delta_raw.png.r2done")
        if os.path.isfile(dpdone) and os.path.isfile(os.path.join(STAGE, "vis_player_061.png")):
            print("[skip] delta_pair 已完成（r2done）", flush=True)
        else:
            dp = os.path.join(STAGE, "_delta_raw.png")
        for f in ("vis_player_061.png", "vis_enemy_061.png"):
            fp = os.path.join(STAGE, f)
            if os.path.isfile(fp):
                prev = os.path.join(STAGE, f.replace(".png", "_prev.png"))
                if os.path.isfile(prev):
                    os.remove(prev)
                os.rename(fp, prev)
        if os.path.isfile(dp):
            os.remove(dp)
        prompt = PLAT_EN.format(subject=DELTA_SUBJECT, tier="elite field gear with a clean combat-ready "
                                                            "look", accent="",
                                axis=DELTA_AXIS, pose=DELTA_POSE)
        payload = {"model": b4.MODEL, "prompt": prompt, "size": "1024x1024",
                   "extra_body": {"response_format": "b64_json"}}
        raw = b4.gen(payload, "delta")
        if raw:
            im = Image.open(io.BytesIO(raw)).convert("RGB")
            im, ok, info = gain_loop_img(im)
            if not ok:
                im.save(dp)
                im2 = single_relight(dp)
                if im2 is not None:
                    im, ok, info = gain_loop_img(im2)
            im512 = im.resize((512, 512), Image.LANCZOS)
            im512.save(os.path.join(STAGE, "vis_player_061.png"))                       # player 朝右
            im512.transpose(Image.FLIP_LEFT_RIGHT).save(os.path.join(STAGE, "vis_enemy_061.png"))  # 敌朝左
            open(dpdone, "w").write("ok")
            print("[%s] delta_pair(游骑兵/三角洲) %s" % ("OK" if ok else "MISS",
                                                          json.dumps(info, ensure_ascii=False)), flush=True)
        else:
            print("[FAIL] delta 生图无果", flush=True)
    print("R2 重掷轮完成", flush=True)


if __name__ == "__main__":
    main()
