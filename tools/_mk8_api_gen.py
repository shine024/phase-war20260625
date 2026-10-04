# -*- coding: utf-8 -*-
"""MK8 API 生图批（2026-10-05）：marks 复审遗留 2 案，产物只落 staging（本批不写 assets/）。
A. fe_helix_phantom —— ind r=yes「要用生图」：无 unit_anims 可派生，纯 t2i 玩家卡图（朝右直出）。
   B4 R2 旧案（phase phantom trooper）复审仍暗糊，按 §6.1 十段英文重拼 + 人型正侧硬锁
   （6.1.3 全身可见）+ gain 收敛 + lit 门 + flood/fit 部署前处理。
B. mod_sup_m4_carbine —— fam r=yes「全是半身的」：现役卡图与动画都半身 → 品红锚定路线全身重建：
   img2img 全身补全锚定帧（anchor_gen + 全身硬性补丁）→ 全身校验（脚不触底/高宽比）→
   卡图 fit 落 mk8_staging；idle 8f 微呼吸复用 _b5_gen_batch.build_idle；
   attack 3×2 走 img25_attack_gen --cells-json（子进程）。
用法: python tools/_mk8_api_gen.py [a|b|ab]   缺省 ab
"""
import io
import json
import os
import subprocess
import sys
import types

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STG_A = os.path.join(ROOT, ".godot", "unit_review", "mk8_staging")
OUT_B = os.path.join(ROOT, ".godot", "unit_review", "img25_staging")
os.makedirs(STG_A, exist_ok=True)
os.makedirs(OUT_B, exist_ok=True)


def load(name, path):
    src = open(path, encoding="utf-8").read()
    lines = [ln for ln in src.splitlines() if "sys.stdout = io.TextIOWrapper" not in ln]
    mod = types.ModuleType(name)
    mod.__file__ = path
    exec(compile("\n".join(lines), path, "exec"), mod.__dict__)
    return mod


b4 = load("mk8_b4", os.path.join(ROOT, "tools", "_b4_card_gen.py"))
gl = load("mk8_gl", os.path.join(ROOT, "tools", "_b4_gain_loop.py"))
img25 = load("mk8_img25", os.path.join(ROOT, "tools", "img25_card_sideview_redo.py"))
ag = load("mk8_ag", os.path.join(ROOT, "tools", "img25_anchor_gen.py"))
agk = load("mk8_agk", os.path.join(ROOT, "tools", "img25_attack_gen.py"))  # depink/keep_main_bodies/alpha_bbox

from PIL import Image  # noqa: E402
import numpy as np  # noqa: E402


def gain_loop_img(im):
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


# ── A: fe_helix_phantom ──────────────────────────────────────────
A_SUBJECT = ("a near-future phase phantom trooper: skintight lightweight phase fabric suit and hood "
             "(soft cloth material), light armor plates on shoulders and chest, an energy blade "
             "sheathed at the waist, calm ready stance, arms relaxed at his sides")
A_PROMPT = (
    "Game card illustration of {subject}.\n"
    "Strictly flat side profile facing right: the camera is exactly at the subject's own side, "
    "level with its midline; the figure stands in strict profile, only one cheek and one shoulder "
    "visible, the far arm hidden behind the torso, entire body from hood to boots fully visible; "
    "no perspective foreshortening.\n"
    "Full body complete and centered, about 10% even white margin on all sides, nothing touching "
    "the canvas edges, feet fully inside the frame.\n"
    "One narrow cyan rim light along the back edge, faint glow limited to emissive parts. "
    "Muted cold palette of deep blue-grey steel and cold grey, the subject fully and evenly lit "
    "with plenty of light, distinct highlights and shadow layers, material detail clearly "
    "readable, a bright readable painted figure.\n"
    "Thick painterly illustration style: forms shaped by color masses and value transitions, "
    "smooth blended brushwork (rendered painterly color masses).\n"
    "Seamless pure white studio background: flat pure white, an empty photo-studio backdrop.\n"
    "[Single subject - hard rule] exactly ONE subject in the whole frame, the unit itself; the "
    "white studio backdrop contains nothing else.\n"
    "No text, watermark, frame, border, or flag-emblem lettering anywhere.\n"
    "text, perspective view, frame, ground, ceiling, foreshortening"
).format(subject=A_SUBJECT)


def case_a():
    print("== A: fe_helix_phantom (t2i player icon) ==", flush=True)
    payload = {"model": b4.MODEL, "prompt": A_PROMPT, "size": "1024x1024",
               "extra_body": {"response_format": "b64_json"}}
    raw = b4.gen(payload, "mk8-phantom")
    if not raw:
        print("[FAIL] A 生图无果", flush=True)
        return False
    im = Image.open(io.BytesIO(raw)).convert("RGB")
    im, ok, info = gain_loop_img(im)
    if not ok:  # 暗图 → 单句补强重掷一发（R2 实证补句有效）
        raw2 = b4.gen(dict(payload, prompt=A_PROMPT + "\nThe suit must be fully and evenly lit, "
                           "bright and clearly readable, never a dark silhouette."),
                      "mk8-phantom-r")
        if raw2:
            im2, ok2, info2 = gain_loop_img(Image.open(io.BytesIO(raw2)).convert("RGB"))
            if ok2:
                im, ok, info = im2, ok2, info2
    im.save(os.path.join(STG_A, "fe_helix_phantom_raw.png"))
    rgba = img25.flood_white_to_alpha(im, 238)
    icon = img25.fit_square(rgba, 512, 0.88)
    icon.save(os.path.join(STG_A, "fe_helix_phantom.png"))
    bg = Image.new("RGBA", (512, 512), (40, 44, 52, 255))
    bg.paste(icon, (0, 0), icon)
    bg.convert("RGB").save(os.path.join(STG_A, "fe_helix_phantom_preview.png"))
    print("[A] ok=%s %s → mk8_staging/fe_helix_phantom.png" % (ok, json.dumps(info)), flush=True)
    return True


# ── B: mod_sup_m4_carbine 全身锚定 ───────────────────────────────


def build_idle(key):
    """锚定帧 → 键控/depink/主体保留/bbox → 512 基 fit（底缘锚定）→ 8 帧微呼吸环。
    （B5 _b5_gen_batch.build_idle 同款内联版）"""
    raw = Image.open(os.path.join(OUT_B, key + "_anchor_raw.png")).convert("RGB")
    rgba = ag.chroma_key(raw)
    rgba = agk.depink(rgba)
    rgba = agk.keep_main_bodies(rgba, 0.35)
    box = agk.alpha_bbox(rgba)
    if box is None:
        print("[idle:%s] 键控后空图！" % key)
        return
    body = rgba.crop(box)
    FS2 = 512
    w, h = body.size
    sc = min((FS2 - 40) / w, (FS2 - 40) / h, 1.6)
    body = body.resize((max(1, int(w * sc)), max(1, int(h * sc))), Image.LANCZOS)
    base = Image.new("RGBA", (FS2, FS2), (0, 0, 0, 0))
    base.paste(body, ((FS2 - body.width) // 2, FS2 - 16 - body.height), body)
    a0 = np.asarray(base)
    up = np.roll(a0, -2, axis=0)
    up[-2:, :] = 0
    loop = [a0, a0, up, up, a0, a0, a0, a0]
    sheet = Image.new("RGBA", (8 * FS2, FS2), (0, 0, 0, 0))
    for i, f in enumerate(loop):
        sheet.paste(Image.fromarray(f), (i * FS2, 0))
    sheet.save(os.path.join(OUT_B, "%s_idle_sheet_512.png" % key))
    g = Image.new("RGBA", (4 * 256, 2 * 256), (40, 44, 52, 255))
    for i, f in enumerate(loop):
        fr = Image.fromarray(f).resize((256, 256), Image.LANCZOS)
        g.paste(fr, (i % 4 * 256, i // 4 * 256), fr)
    g.convert("RGB").save(os.path.join(OUT_B, "%s_idle_grid_preview.png" % key))
    print("[idle:%s] OK" % key, flush=True)


B_SUBJECT = ("现代美军M4卡宾枪兵，沙黄色作战服与模块化战术背心，戴战术头盔与风镜，"
             "双手持M4卡宾枪收于身前，枪口斜向下，中性站立待机")
B_SUPPLEMENT = ("\n【全身·硬性】参考卡图中的士兵只拍到上半身；这次必须补全下半身："
                "完整画出双腿、战术裤与军靴，从头盔到军靴的全身全部可见，"
                "双脚完整位于画面内、绝不触碰画布底边。")
B_KEY = "mod_sup_m4_carbine"
B_CELLS = dict(seq="卡宾枪点射",
               cells={"1": "枪托抵肩微微上抬，枪口泛起点点微光",
                      "2": "枪口爆出锐长橙红色火光，弹壳向右抛出",
                      "3": "火光衰减，枪口青烟拉出一缕",
                      "4": "枪身被后坐轻推，枪口余烟",
                      "5": "回到待机持枪"},
               fx="只要枪口火光与硝烟弹壳，无弹道无曳光")


def fullbody_check(keyed):
    """全身校验：半身的真判别特征 = 身体被画布底边裁切（脚不可见）。
    高宽比不可作门槛（宽持枪瞄准姿势全身也才 1.2-1.4，10-05 两掷实证）。"""
    a = np.asarray(keyed)
    ys, xs = np.where(a[:, :, 3] > 40)
    if not len(ys):
        return False, "empty"
    h = ys.max() - ys.min() + 1
    w = xs.max() - xs.min() + 1
    touches = ys.max() >= keyed.height - 6
    return not touches, "h=%d w=%d ratio=%.2f touches_bottom=%s" % (
        h, w, h / max(w, 1), touches)


def case_b():
    print("== B: %s (full-body anchor) ==" % B_KEY, flush=True)
    raw_p = os.path.join(OUT_B, B_KEY + "_anchor_raw.png")
    orig_build = ag.build_prompt
    for attempt in range(2):
        if not os.path.isfile(raw_p):  # 已有锚定帧（如中断续跑）直接校验，不重掷
            sup = B_SUPPLEMENT if attempt == 0 else (
                B_SUPPLEMENT + "这是最硬性的要求：上一版仍缺下半身；本版必须画完整的立正全身像，"
                               "头盔、躯干、双腿、军靴一个不缺，画面下沿必须留出地面空隙。")
            ag.build_prompt = lambda s, _o=orig_build, _s=sup: _o(s) + _s
            sys.argv = ["img25_anchor_gen.py", B_KEY,
                        os.path.join(ROOT, "assets", "card_icons", "enemy", B_KEY + ".png"),
                        "--chroma-out"]
            try:
                ag.main()
            except SystemExit:
                pass
            if not os.path.isfile(raw_p):
                print("[FAIL] B 锚定第 %d 掷无果" % (attempt + 1), flush=True)
                continue
        raw = Image.open(raw_p).convert("RGB")
        keyed = ag.chroma_key(raw)
        keyed = agk.depink(keyed)
        keyed = agk.keep_main_bodies(keyed, 0.35)
        ok, info = fullbody_check(keyed)
        print("  全身校验: ok=%s %s" % (ok, info), flush=True)
        if ok:
            break
        os.remove(raw_p)  # 不过校验 → 删掉强制重掷
    ag.build_prompt = orig_build
    if not os.path.isfile(raw_p):
        return False
    keyed.save(os.path.join(OUT_B, B_KEY + "_anchor_keyed.png"))
    # 卡图（敌朝左直出）落 mk8_staging
    icon = img25.fit_square(keyed, 512, 0.88)
    icon.save(os.path.join(STG_A, B_KEY + ".png"))
    # idle 8f 微呼吸（B5 build_idle 内联——其文件内嵌 loader 会被本脚本 loader 误删行）
    build_idle(B_KEY)
    # attack 3×2 cells 脚本（子进程走 img25_attack_gen）
    cj = os.path.join(OUT_B, "_mk8_cells_%s.json" % B_KEY)
    with open(cj, "w", encoding="utf-8") as f:
        json.dump(dict(B_CELLS, extra=("Strictly flat side profile facing left: the camera is exactly "
                                       "at the subject's own side, level with its midline; the "
                                       "subject's long axis stretches horizontally across the whole "
                                       "image, its upright parts stay vertical, no perspective "
                                       "foreshortening. Zoomed-out wide framing: the whole subject "
                                       "fully inside each cell with generous empty space on all four "
                                       "sides, far from the cell edges.")), f, ensure_ascii=False)
    rc = subprocess.call([sys.executable, os.path.join(ROOT, "tools", "img25_attack_gen.py"),
                          B_KEY, "--subject", B_SUBJECT, "--rolls", "2", "--cells-json", cj],
                         cwd=ROOT)
    print("[B] anchor+icon+idle 完成；attack rc=%d（2 掷落 img25_staging）" % rc, flush=True)
    return rc == 0


def main():
    which = (sys.argv[1] if len(sys.argv) > 1 else "ab").lower()
    if "a" in which:
        case_a()
    if "b" in which:
        case_b()
    print("MK8 生图批结束", flush=True)


if __name__ == "__main__":
    main()
