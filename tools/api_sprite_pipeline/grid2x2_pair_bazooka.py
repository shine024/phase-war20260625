# -*- coding: utf-8 -*-
"""双 2x2 有联系生成——巴祖卡 ww2_inf_bazooka（用户 2026-10-13 口径:
"二张参考图 + 提示语控制, 生成 2 张 2x2, 前后有联系"）。
管线既有: 4 格=2x2 高分辨率动作帧(每格 512, 细节预算高), 单图 i2i。本脚本把"一张 2x2"扩成"两张 2x2",
两张参考图 = 卡图 + 2x2 版式底稿; 提示语控制动作; 前后联系 = 后段以"前段结果图"当参考续画。
落原图(不键控不裁格不拼 sheet), 给侧边浏览器看原图。
用法: python tools/api_sprite_pipeline/grid2x2_pair_bazooka.py
产物: .godot/unit_review/api_ww2_inf_bazooka/raw/{front2x2, rear2x2}.png
"""
import base64, io, json, os, subprocess, sys, time
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__))
WS = os.path.abspath(os.path.join(HERE, "..", ".."))
REAR_ONLY = "--rear-only" in sys.argv   # ⚠️ 必须在下一行截断 argv 前取参(2026-10-13 实踩: 截断后参数恒丢)
sys.argv = [sys.argv[0]]
sys.path.insert(0, HERE)
import generate_attack_api as P
import batch_regen as B

UNIT = "ww2_inf_bazooka"
out = os.path.join(WS, ".godot", "unit_review", "api_" + UNIT)
raw = os.path.join(out, "raw"); os.makedirs(raw, exist_ok=True)

POS4 = ["top-left", "top-right", "bottom-left", "bottom-right"]
# 卡图实际姿态(2026-10-13 用户纠错): 右膝跪地, 火箭筒【已经扛在肩上】, 筒口朝左, 背挎 M1 步枪。
# 动作文案必须从卡图真实姿态出发——全程跪姿、筒不离肩, 只做瞄准/击发/后坐/回稳微差;
# 禁用 "raising toward his shoulder / one small step" 类诱导离肩+站起的措辞。
# 前段(开火相位): 瞄准 → 绷紧 → 击发(唯一焰, 下左格) → 后坐
# ⚠️ 非击发格禁提 shot/fire 类预兆词(2026-10-13 两轮实证: "tensing for the shot" 诱发双焰)——
#   否定句同理(工作流文档 §6.2: "NO flash" 类在 pose 里会反噬), 焰只允许出现在 flash_note 一处。
POSES_FRONT = [
    "aiming: kneeling exactly as in the reference image, the bazooka resting on his shoulder, muzzle level pointing left, both hands gripping the tube, cheek at the breech",
    "bracing: kneeling, the bazooka on his shoulder, muzzle tilting very slightly upward as he settles his grip, chin pressing at the breech, shoulders squared",
    "firing: kneeling, the bazooka on his shoulder discharging, a compact star-shaped muzzle flash attached directly at the front of the tube, orange-yellow with a white core, body braced against the shot",
    "recoil: kneeling, the bazooka still on his shoulder, the muzzle kicked slightly upward, helmet tipped back, shoulders rocked backward, both hands still on the tube, feet planted",
]
# 后段(回收相位): 回稳 → 松瞄准 → 再贴腮 → 平端定住(循环闭合, 无焰格——文案零火器词)
POSES_REAR = [
    "recovering: kneeling, the bazooka on his shoulder, the muzzle easing back down to level after the shot, upper body straightening up",
    "relaxing the aim: kneeling, the bazooka resting on his shoulder, his cheek off the breech, muzzle level pointing left, a calm held pose",
    "re-aiming: kneeling, the bazooka on his shoulder, his cheek settling back at the breech, muzzle level pointing left",
    "holding the aim: kneeling, the bazooka on his shoulder, muzzle perfectly level to the left, both hands gripping the tube, a calm steady held pose",
]

INV = ("kneeling on one knee EXACTLY as in the reference image in every panel, he NEVER stands up, "
       "the bazooka RESTING ON HIS SHOULDER in every panel (it never leaves his shoulder), "
       "facing LEFT in profile, the rocket still loaded in the tube, NO scope")
# 去 silhouette 诱发压黑的骨架(2026-10-13 六格压黑实证, 见 §7.8)
SKELETON2 = ("STRICTLY a pure 2D SIDE VIEW side-on game sprite (never a front view, never a three-quarter view), "
             "flat orthographic game sprite,\n"
             "{SUBJECT}\n"
             "matte painting style, detailed weathering and surface texture, "
             "every panel is FULLY COLORED with exactly the same olive-drab uniform and brown weapon colors "
             "as the reference image, NEVER a black silhouette, NEVER a flat dark shadow shape, "
             "FLAT EVEN MATTE LIGHTING with uniform brightness, the lighting is identical in every panel, "
             "clean flat game-sprite colors,\n"
             "the entire background is one perfectly flat uniform bright pure magenta #FF00FF color fill "
             "covering the canvas edge to edge: no vignette, no gradient, no texture anywhere, "
             "ALL FOUR panels share the SAME pure magenta background, "
             "NO ground, NO floor, NO floor line, NO tan strip, NO shadow under any figure, "
             "nothing but the kneeling soldier on flat magenta in every panel,\n"
             "full body fitting in each panel with generous empty margin, "
             "NO text, NO watermark, NO ground, NO scene background\n")

def prompt2x2(poses, flash_note, extra_note=""):
    parts = ["%s: the same soldier %s, %s;" % (POS4[i], p, INV) for i, p in enumerate(poses)]
    return SKELETON2.replace("{SUBJECT}",
        "the same WWII US infantryman as in the reference image, with the bazooka anti-tank rocket, "
        "shown in a regular grid of exactly 4 flat panels, 2 columns and 2 rows, "
        "all 4 panels showing THE SAME soldier with THE SAME bazooka, helmet and gear, "
        "identical scale, identical colors and identical rendering in every panel, and NO shadow under any figure. "
        + " ".join(parts) + " " + flash_note +
        "Keep the exact 4-panel grid layout, panel positions and spacing of the reference image unchanged, "
        "changing only the soldier's pose in each panel as listed. "
        "One complete FULLY COLORED figure centered in each panel, generous empty magenta spacing between panels, "
        "no panel borders, no grid lines, no labels, no numbers. " + extra_note)

def b64(im):
    buf = io.BytesIO(); im.save(buf, "PNG")
    return base64.b64encode(buf.getvalue()).decode()

def call_i2i_multi(ref_b64_list, prompt, tag):
    """多参考图 i2i: extra_body.image 传多张(data-URI), 401 轮换, 输出 1024²。"""
    keys = P.load_keys()
    body = {"model": P.MODEL, "prompt": prompt, "image_size": "1024x1024",
            "extra_body": {"image": ["data:image/png;base64," + b for b in ref_b64_list],
                           "response_format": "url"}}
    pf = os.path.join(raw, "payload_%s.json" % tag)
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
            print("  [%s] att%d unparseable, retry" % (tag, att), flush=True); time.sleep(5); continue
        if "data" in js and js["data"] and js["data"][0].get("url"):
            url = js["data"][0]["url"]
            if "/i2i/" in url:
                # 下载域(platform-outputs)不稳: 2026-10-13 三连败(curl 35/28 截断), 必须重试+完整性校验
                fp = os.path.join(raw, tag + ".png")
                for datt in range(5):
                    subprocess.run(["curl", "--http1.1", "-sS", "-m", "180", "-o", fp, url],
                                   capture_output=True, text=True)
                    ok = False
                    try:
                        im = Image.open(fp); im.load()
                        ok = im.size == (1024, 1024)
                    except Exception:
                        ok = False
                    if ok:
                        print("  → %s ok key=%s" % (tag, key[:12]), flush=True)
                        return
                    if os.path.exists(fp):
                        os.remove(fp)  # 截断 PNG 不可续, 删了从头下
                    print("  [%s] 下载截断(datt%d), 3s 后重下" % (tag, datt), flush=True)
                    time.sleep(3)
                raise RuntimeError("download failed after 5 tries: " + url)
            print("  [%s] i2i 标志缺失, retry" % tag, flush=True); time.sleep(5); continue
        print("  [%s] att%d fail: %s" % (tag, att, str(js.get("error", {}).get("message"))[:120]), flush=True)
        time.sleep(6)
    raise RuntimeError("i2i failed: " + tag)

def main(rear_only=False):
    card = B.make_transparent(Image.open(os.path.join(WS, "assets", "card_icons", "enemy", "ww2_inf_bazooka.png")))
    card = card.crop(card.getbbox())
    card.save(os.path.join(out, "anchor_card.png"))
    # 2x2 版式底稿(管线既有): 卡图人物落 4 格, 品红底, 每格 512
    tpl = P.build_grid_template_4_card(card, 256)
    tpl.save(os.path.join(out, "grid_template_2x2.png"))

    # ── 前段 2x2 (开火相位): 参考图 = 版式底稿 + 卡图; 焰只在下左格 ──
    if not rear_only:
        print("[pair2x2] 前段 front2x2 生成中 ...", flush=True)
        call_i2i_multi([b64(tpl), b64(card.convert("RGBA"))],
                       prompt2x2(POSES_FRONT,
                                  "EXACTLY ONE panel in the entire image has a muzzle flash — the bottom-left panel: "
                                  "small, orange-yellow with a white core, attached directly to the front of the tube. "
                                  "The other three panels have NO flash, NO spark, NO smoke. "),
                       "front2x2")
    front = Image.open(os.path.join(raw, "front2x2.png")).convert("RGB")

    # ── 后段 2x2 (回收相位): 参考图 = 前段结果并排卡图(外观锚) + 版式底稿; 无前段末格"后坐"接续, 全程无焰 ──
    combo = Image.new("RGBA", (1024 * 2, 1024), (255, 0, 255, 255))
    combo.paste(front, (0, 0))
    c2 = card.convert("RGBA").resize((512, 512), Image.LANCZOS)
    combo.paste(c2, (1024, 256), c2)
    combo.convert("RGB").save(os.path.join(raw, "ref_rear_combo.png"))
    rear_note = ("Reference image 1 is a combined strip: its LEFT half is the previous sequence of 4 panels "
                 "(read top-left, top-right, bottom-left, bottom-right = aiming, bracing, firing, recoil), "
                 "its RIGHT half is the same soldier shown alone, kept ONLY as an appearance reference. "
                 "Regenerate the 4-panel grid with EXACTLY the same soldier, the SAME scale, colors, weapon, "
                 "pose style and 2x2 panel layout as that left half, but continuing with the 4 NEW poses listed above: "
                 "the FIRST panel of your grid starts from the soldier's pose in the previous bottom-right panel "
                 "(recoil, leaning back), so the two grids connect as one continuous shooting-and-recovering cycle. "
                 "No panel in this grid has any flash or smoke — the muzzle flash was already shown in the previous grid. ")
    print("[pair2x2] 后段 rear2x2 生成中 ...", flush=True)
    call_i2i_multi([b64(combo.convert("RGB")), b64(tpl)],
                   prompt2x2(POSES_REAR, "", rear_note), "rear2x2")
    print("done: raw/front2x2.png + raw/rear2x2.png (原图, 未后处理)", flush=True)

if __name__ == "__main__":
    main(rear_only=REAR_ONLY)
