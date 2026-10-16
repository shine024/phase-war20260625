# -*- coding: utf-8 -*-
"""2x2 载具攻击帧生成——锚点=原卡图(无描线), 一单 2x2 = 4 动作帧 + 原卡图书挡首尾 = 6 帧卷。
2026-10-13 沉淀: 载具全程"在轮子上"不动轮、只做主炮微动; 禁 silhouette 词; 品红底+无地面无投影强化;
焰仅一格; 无否定句无预兆词。
用法: python tools/api_sprite_pipeline/grid2x2_vehicle.py <anim_key>
产物: .godot/unit_review/api_<anim_key>/{raw/grid2x2.png, frames/f1..f6.png, sheet_attack_api.png}
"""
import base64, io, json, os, subprocess, sys, time
from PIL import Image
import numpy as np
HERE = os.path.dirname(os.path.abspath(__file__))
WS = os.path.abspath(os.path.join(HERE, "..", ".."))
UNIT = sys.argv[1] if len(sys.argv) > 1 else "ww2_inf_panzerschrek"
ANIM = os.path.join(WS, "assets", "effects", "unit_anims", UNIT)
anim = json.load(open(os.path.join(ANIM, "anim.json"), encoding="utf-8"))
FS = 256
FOOT_FRAC = anim.get("foot_frac", 0.03)
OUT = os.path.join(WS, ".godot", "unit_review", "api_" + UNIT)
RAW = os.path.join(OUT, "raw"); os.makedirs(RAW, exist_ok=True)

sys.argv = [sys.argv[0]]
sys.path.insert(0, HERE)
import generate_attack_api as P
import batch_regen as B

# 载具 4 动作帧文案(小动作、主炮微动、焰只上右)
DESC = ("the same modern 8x8 wheeled armored vehicle as in the reference image: angular matte-olive hull, "
        "glowing blue light accents along the side panels, a roof-mounted main gun on the front, antenna masts, 8 wheels")
POSES = [
    "ready: the vehicle in a stable stance on all 8 wheels, the roof main gun barrel pointing level to the left",
    "firing: the roof main gun discharging with a compact star-shaped muzzle flash attached directly at the barrel tip, orange-yellow with a white core, the vehicle body braced and settled on its wheels",
    "recoil: the roof main gun recoiling slightly back, the barrel eased back just a little, the vehicle settled on its wheels",
    "settling: the roof main gun easing back into the ready position, barrel pointing level to the left, a calm stance",
]
INV = ("facing LEFT in profile, the main gun barrel pointing to the left, the vehicle NEVER mirrored, "
       "the same glowing blue light accents and hull details in every panel, all 8 wheels present and identical")

SKELETON_V = ("STRICTLY a pure 2D SIDE VIEW side-on game sprite (never a front view, never a three-quarter view), "
              "flat orthographic game sprite, single vehicle only, centered,\n"
              + DESC + ",\n"
              "matte painting style, detailed weathering, "
              "every panel is FULLY COLORED with exactly the same colors as the reference image, "
              "NEVER a black silhouette, NEVER a flat dark shadow shape, "
              "FLAT EVEN MATTE LIGHTING with uniform brightness, the lighting is identical in every panel,\n"
              "the entire background is one perfectly flat uniform bright pure magenta #FF00FF color fill "
              "covering the canvas edge to edge: NO ground, NO floor line, NO tan strip, NO shadow under the vehicle in any panel, "
              "nothing but the vehicle on flat magenta in every panel,\n"
              "the complete vehicle in each panel, generous empty margin, "
              "NO text, NO watermark, NO scene background\n")

def prompt2x2():
    parts = ["%s: the same vehicle %s, %s;" % (p, pose, INV)
             for p, pose in zip(["top-left", "top-right", "bottom-left", "bottom-right"], POSES)]
    flash = ("The star-shaped muzzle flash appears in ONLY ONE panel, the top-right panel: small, "
             "orange-yellow with a white core, attached directly to the gun barrel tip. "
             "The other three panels have NO flash, NO spark, NO smoke. ")
    return SKELETON_V + (
        "shown in a regular grid of exactly 4 flat panels, 2 columns and 2 rows, "
        "all 4 panels showing THE SAME vehicle, identical scale, identical colors and identical rendering in every panel. "
        + " ".join(parts) + " " + flash +
        "Keep the exact 4-panel grid layout, panel positions and spacing of the reference image unchanged, "
        "changing only the main gun pose in each panel as listed. "
        "One complete vehicle centered in each panel, generous empty magenta spacing between panels, "
        "no panel borders, no grid lines, no labels, no numbers.")

def b64(im):
    buf = io.BytesIO(); im.save(buf, "PNG")
    return base64.b64encode(buf.getvalue()).decode()

def call_i2i_multi(ref_b64_list, prompt, tag):
    keys = P.load_keys()
    body = {"model": P.MODEL, "prompt": prompt, "image_size": "1024x1024",
            "extra_body": {"image": ["data:image/png;base64," + b for b in ref_b64_list],
                           "response_format": "url"}}
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
            print("  [%s] att%d unparseable, retry" % (tag, att), flush=True); time.sleep(5); continue
        if "data" in js and js["data"] and js["data"][0].get("url"):
            url = js["data"][0]["url"]
            if "/i2i/" in url:
                fp = os.path.join(RAW, tag + ".png")
                for datt in range(5):
                    subprocess.run(["curl", "--http1.1", "-sS", "-m", "180", "-o", fp, url],
                                   capture_output=True, text=True)
                    try:
                        im = Image.open(fp); im.load()
                        if im.size == (1024, 1024):
                            print("  → %s ok key=%s" % (tag, key[:12]), flush=True)
                            return
                    except Exception:
                        pass
                    if os.path.exists(fp):
                        os.remove(fp)
                    print("  [%s] 下载截断(datt%d), 3s 后重下" % (tag, datt), flush=True)
                    time.sleep(3)
                raise RuntimeError("download failed: " + url)
            print("  [%s] i2i 标志缺失, retry" % tag, flush=True); time.sleep(5); continue
        print("  [%s] att%d fail: %s" % (tag, att, str(js.get("error", {}).get("message"))[:120]), flush=True)
        time.sleep(6)
    raise RuntimeError("i2i failed: " + tag)

def main():
    # 锚点 = 原卡图(干净无描线)——工作流 §7.2 卡图解析纪律:
    # 命名卡图不存在时解析 vis_enemy 编号(vis_player_0NN 索引+1 → enemy/vis_enemy_0NN.png),
    # 禁止退回 idle f0 帧图当锚(粗描线会被 i2i 复现→成品发闷, 2026-10-13 panzerschrek 实例)。
    card = B.make_transparent(Image.open(os.path.join(WS, "assets", "card_icons", "enemy", "vis_enemy_010.png")))
    card = card.crop(card.getbbox())
    card.save(os.path.join(OUT, "anchor_card.png"))
    # 2x2 版式底稿: 车按原生尺寸落 4 格(不上降采样)
    tpl = P.build_grid_template_4_card(card, FS)
    tpl.save(os.path.join(OUT, "grid_template_2x2.png"))
    print("[%s] 2x2 生成中 ..." % UNIT, flush=True)
    call_i2i_multi([b64(tpl), b64(card)], prompt2x2(), "grid2x2")
    grid = Image.open(os.path.join(RAW, "grid2x2.png")).convert("RGB")
    # 键控 4 格
    alpha_full, labels, comps = P.grid4_to_frames(grid)
    if alpha_full is None:
        print("  4 格键控失败: %s (原图保留在 raw/grid2x2.png, 先看原图)" % comps, flush=True)
        return
    flipped, fmsgs = P.grid4_flip_check(grid, alpha_full, labels, comps)
    print("  反帧检查: %s" % (" ".join(fmsgs) if fmsgs else "全朝左 ok"), flush=True)
    # 4 动作帧 → 256 画布(载具居中 + 限宽 0.88 + foot_frac 脚线)
    gpx = np.asarray(grid)
    h_aim = comps[0][1][3] - comps[0][1][1]
    scale = (0.80 * FS) / h_aim
    for i, (npx, bbox, cid) in enumerate(comps):
        x0, y0, x1, y1 = bbox
        pad = 2
        x0, y0 = max(0, x0 - pad), max(0, y0 - pad)
        x1, y1 = min(alpha_full.shape[1] - 1, x1 + pad), min(alpha_full.shape[0] - 1, y1 + pad)
        mask = labels[y0:y1 + 1, x0:x1 + 1] == cid
        a2 = np.where(mask, alpha_full[y0:y1 + 1, x0:x1 + 1], 0).astype(np.uint8)
        rgba = np.dstack([gpx[y0:y1 + 1, x0:x1 + 1], a2])
        comp, _ = P.largest_component(rgba[:, :, 3])
        if comp is not None:
            rgba[:, :, 3] = comp
        fr = Image.fromarray(rgba)
        fa = np.asarray(fr)[:, :, 3]
        fyy, fxx = np.where(fa > 20)
        crop = fr.crop((fxx.min(), fyy.min(), fxx.max() + 1, fyy.max() + 1))
        ch_want = int(crop.height * scale)
        max_ch = int(FS * (1 - FOOT_FRAC)) - 4
        s = scale if ch_want <= max_ch else max_ch / crop.height
        if crop.width * s > int(FS * 0.88):
            s = int(FS * 0.88) / crop.width
        crop = crop.resize((max(1, int(crop.width * s)), max(1, int(crop.height * s))), Image.LANCZOS)
        frame = Image.new("RGBA", (FS, FS), (0, 0, 0, 0))
        px = (FS - crop.width) // 2
        frame.paste(crop, (px, FS - int(crop.height) - int(round(FOOT_FRAC * FS))), crop)
        frame.save(os.path.join(OUT, "frames", "f%d.png" % (i + 2)))
    # 书挡 f1/f6 = 原卡图居中(对齐 card4 路线)
    for tag in ("f1", "f6"):
        crop = card
        s = min(0.80 * FS / crop.height, int(FS * 0.88) / crop.width)
        crop2 = crop.resize((max(1, int(crop.width * s)), max(1, int(crop.height * s))), Image.LANCZOS)
        frame = Image.new("RGBA", (FS, FS), (0, 0, 0, 0))
        frame.paste(crop2, ((FS - crop2.width) // 2, FS - crop2.height - int(round(FOOT_FRAC * FS))), crop2)
        frame.save(os.path.join(OUT, "frames", tag + ".png"))
    # 合 6 帧 sheet
    sheet = Image.new("RGBA", (FS * 6, FS), (0, 0, 0, 0))
    for i in range(6):
        sheet.paste(Image.open(os.path.join(OUT, "frames", "f%d.png" % (i + 1))), (i * FS, 0))
    sheet.save(os.path.join(OUT, "sheet_attack_api.png"))
    # 贴边检查
    clip = 0
    for i in range(6):
        fa = np.asarray(Image.open(os.path.join(OUT, "frames", "f%d.png" % (i + 1))))[:, :, 3]
        if fa[:3, :].any() or fa[-3:, :].any() or fa[:, :3].any() or fa[:, -3:].any():
            clip += 1
    print("  6 帧卷完成, 贴边 %d 帧" % clip, flush=True)

if __name__ == "__main__":
    main()
