#!/usr/bin/env python3
"""人形战斗卡攻击姿态帧生成(agnes-image img2img + 黑底抠图)

用法:
  python tools/generate_attack_frames.py            # 试点 5 张人形卡
  python tools/generate_attack_frames.py --all      # 全量人形卡(见 TARGETS_ALL 扩充)

流程(复用 generate_boss_idle_frames.py 的成熟管线):
  1. 取卡图(512 RGBA 透明) → 合成纯黑底 → base64
  2. img2img: "同角色攻击姿态:前排士兵举枪水平指向左侧" → 黑底输出
  3. 黑底反抠 + 颜色增益匹配 + bbox 归一化回原构图
  4. 存 assets/effects/unit_anims/<archetype_id>/attack_f0.png
     AttackPoseAnim 检测到帧自动在开火时换贴图展示 ~0.16s

注意: 帧不带枪口火/烟(游戏内另有 MuzzleAnchors 炮口特效,重复画会打架)。
"""
import base64
import io
import json
import os
import ssl
import sys
import time
import urllib.request

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KEY_FILE = os.path.join(ROOT, "tools", "_api_key.txt")
IMG = "https://apihub.agnes-ai.cn/v1/images/generations"
MODEL = "agnes-image-2.1-flash"

BASE_MOTION = (
    "ATTACK FIRING STANCE animation frame: the frontmost soldier raises his firearm to a "
    "horizontal AIMING position with the muzzle pointing LEFT, body leaning slightly forward, "
    "as if about to fire. All other soldiers and equipment stay in EXACTLY the same positions "
    "and poses as the input image. CRITICAL: keep the SAME framing, SAME camera distance and "
    "SAME scale as the input image — the soldiers' bodies must remain the SAME SIZE, filling "
    "the frame exactly like the input; do NOT zoom out, do NOT shrink the subjects, do NOT "
    "add empty space around them. Same squad, same number of soldiers, same uniforms, "
    "same colors, same weapons. NO muzzle flash, NO smoke, "
    "NO explosion, NO new objects, NO text, NO watermark."
)

VEHICLE_MOTION = (
    "ATTACK FIRING STANCE animation frame of the weapon system: the launcher or turret "
    "elevates into a firing angle pointing LEFT, crew (if any) brace for launch recoil. "
    "CRITICAL: keep the SAME framing, SAME camera distance and SAME scale as the input image; "
    "do NOT zoom out, do NOT shrink, do NOT add empty space. Same vehicle, same colors, "
    "same equipment. NO muzzle flash, NO smoke, NO explosion, NO new objects, NO text."
)

TARGETS = [
    # 一战
    {"id": "ww1_inf_rifle", "base": "assets/card_icons/enemy/vis_enemy_037.png"},
    {"id": "ww1_sup_mg_nest", "base": "assets/card_icons/enemy/vis_enemy_038.png",
     "extra": "The machine gunner crouches low behind the gun, gripping the firing handles, barrel aimed LEFT."},
    {"id": "ww1_arty_mortar", "base": "assets/card_icons/enemy/vis_enemy_039.png",
     "extra": "A crewman drops a shell into the mortar tube, others brace; the tube elevates to firing angle."},
    {"id": "ww1_inf_storm_e", "base": "assets/card_icons/enemy/vis_enemy_040.png"},
    {"id": "ww1_inf_enfield", "base": "assets/card_icons/enemy/ww1_inf_enfield.png"},
    {"id": "ww1_sup_vickers", "base": "assets/card_icons/enemy/ww1_sup_vickers.png",
     "extra": "The gunner crouches low behind the Vickers gun, ready to fire LEFT."},
    {"id": "ww1_inf_mp18_x", "base": "assets/card_icons/enemy/ww1_inf_mp18_x.png"},
    # 二战
    {"id": "ww2_inf_thompson", "base": "assets/card_icons/enemy/vis_enemy_043.png"},
    {"id": "ww2_inf_garand", "base": "assets/card_icons/enemy/vis_enemy_044.png"},
    {"id": "ww2_inf_para_e", "base": "assets/card_icons/enemy/vis_enemy_047.png"},
    {"id": "ww2_arm_garand_para", "base": "assets/card_icons/enemy/ww2_arm_garand_para.png"},
    {"id": "ww2_inf_kar98k", "base": "assets/card_icons/enemy/ww2_inf_kar98k.png",
     "extra": "The sniper settles his cheek on the rifle stock, scope aimed LEFT."},
    # 冷战
    {"id": "cold_inf_m60", "base": "assets/card_icons/enemy/vis_enemy_051.png",
     "extra": "The machine gunner braces the GPMG on its bipod, aimed LEFT."},
    {"id": "cold_inf_spetsnaz_e", "base": "assets/card_icons/enemy/vis_enemy_054.png"},
    {"id": "cold_inf_metis", "base": "assets/card_icons/enemy/cold_inf_metis.png",
     "extra": "The missile team launcher tube aims LEFT, gunner sights the target."},
    # 现代
    {"id": "mod_inf_marine", "base": "assets/card_icons/enemy/vis_enemy_057.png"},
    {"id": "mod_sup_m4_carbine", "base": "assets/card_icons/enemy/mod_sup_m4_carbine.png"},
    {"id": "mod_arm_himars", "base": "assets/card_icons/enemy/mod_arm_himars.png", "vehicle": True,
     "extra": "The launcher pods elevate to a firing angle pointing LEFT."},
    {"id": "mod_sup_growler", "base": "assets/card_icons/enemy/mod_sup_growler.png", "vehicle": True,
     "extra": "The aircraft pitches slightly forward with underwing missiles angled LEFT, ready to launch."},
    # 近未来
    {"id": "fut_inf_spectre_e", "base": "assets/card_icons/enemy/vis_enemy_069.png"},
    {"id": "fut_inf_neural", "base": "assets/card_icons/enemy/fut_inf_neural.png"},
    {"id": "fut_arm_hk07", "base": "assets/card_icons/enemy/fut_arm_hk07.png",
     "extra": "The lead combat robot raises its arm cannons to horizontal aiming LEFT."},
    {"id": "fut_inf_x9", "base": "assets/card_icons/enemy/fut_inf_x9.png"},
    {"id": "fut_inf_c96", "base": "assets/card_icons/enemy/fut_inf_c96.png"},
    {"id": "fut_arty_ssc1", "base": "assets/card_icons/enemy/fut_arty_ssc1.png", "vehicle": True,
     "extra": "The coastal missile launcher elevates its canisters to firing angle pointing LEFT."},
    # 缴获卡（2026-08-18 补齐敌方原图后追加）
    {"id": "drop_smg_mk2", "base": "assets/card_icons/enemy/drop_smg_mk2.png"},
    {"id": "drop_phase_lance", "base": "assets/card_icons/enemy/drop_phase_lance.png",
     "extra": "The front soldier levels his rifle with the glowing phase bayonet aimed LEFT."},
    {"id": "drop_thunder_field", "base": "assets/card_icons/enemy/drop_thunder_field.png"},
    {"id": "drop_railgun", "base": "assets/card_icons/enemy/drop_railgun.png",
     "extra": "The front trooper levels the dual-rail gauss rifle, rails energized, aimed LEFT."},
]


def load_keys():
    with open(KEY_FILE, encoding="utf-8") as f:
        return [ln.strip() for ln in f if ln.strip()]


def flatten_black(png_path):
    im = Image.open(png_path).convert("RGBA")
    if im.size != (512, 512):
        im = im.resize((512, 512), Image.LANCZOS)
    bg = Image.new("RGBA", (512, 512), (0, 0, 0, 255))
    bg.alpha_composite(im)
    buf = io.BytesIO()
    bg.convert("RGB").save(buf, format="PNG")
    return buf.getvalue()


def key_black(im):
    im = im.convert("RGB")
    px = im.load()
    out = Image.new("RGBA", im.size)
    po = out.load()
    for y in range(im.size[1]):
        for x in range(im.size[0]):
            r, g, b = px[x, y]
            m = max(r, g, b)
            if m <= 18:
                po[x, y] = (0, 0, 0, 0)
            elif m >= 48:
                po[x, y] = (r, g, b, 255)
            else:
                a = (m - 18) * 255 // 30
                po[x, y] = (r, g, b, a)
    return out


def content_bbox(im):
    px = im.load()
    minx, miny, maxx, maxy = im.size[0], im.size[1], -1, -1
    for y in range(0, im.size[1], 2):
        for x in range(0, im.size[0], 2):
            if px[x, y][3] > 32:
                if x < minx: minx = x
                if x > maxx: maxx = x
                if y < miny: miny = y
                if y > maxy: maxy = y
    if maxx < 0:
        return None
    return (minx, miny, maxx, maxy)


def color_match(src, ref):
    sp, rp = src.load(), ref.load()
    sums = [0, 0, 0]; sumr = [0, 0, 0]; n = 0
    for y in range(0, src.size[1], 4):
        for x in range(0, src.size[0], 4):
            if sp[x, y][3] > 64 and rp[x, y][3] > 64:
                n += 1
                for c in range(3):
                    sums[c] += sp[x, y][c]; sumr[c] += rp[x, y][c]
    if n < 50:
        return src
    gains = []
    for c in range(3):
        ms = sums[c] / n; mr = sumr[c] / n
        gains.append(min(1.8, max(0.5, mr / max(ms, 1))))
    for y in range(src.size[1]):
        for x in range(src.size[0]):
            r, g, b, a = sp[x, y]
            if a > 0:
                sp[x, y] = (min(255, int(r * gains[0])), min(255, int(g * gains[1])),
                            min(255, int(b * gains[2])), a)
    return src


def normalize_to_base(frame, base):
    """构图矫正 v3（攻击帧专用：双轴拉伸 + 底部锚定）。
    攻击帧仅展示 ~0.16s，且战场显示尺寸 60-120px——微畸变不可感知；
    双轴独立拉伸到与原图 bbox 完全一致可确定性消灭换帧跳尺寸/悬空
    （v2 等比 fit + 高度下限会被宽度封顶压制，实测高度仍差 33-55%）。"""
    fb = content_bbox(frame)
    bb = content_bbox(base)
    if fb is None or bb is None:
        return frame
    content = frame.crop(fb)
    bw = bb[2] - bb[0]; bh = bb[3] - bb[1]
    fw = fb[2] - fb[0]; fh = fb[3] - fb[1]
    if fw < 4 or fh < 4:
        return frame
    content = content.resize((bw, bh), Image.LANCZOS)
    canvas = Image.new("RGBA", base.size, (0, 0, 0, 0))
    cx = (bb[0] + bb[2]) // 2
    canvas.alpha_composite(content, (cx - bw // 2, bb[1]))
    return canvas


def call_img2img(prompt, image_png_bytes, key, size="1024x1024"):
    b64 = base64.b64encode(image_png_bytes).decode()
    body = {
        "model": MODEL,
        "prompt": prompt,
        "size": size,
        "extra_body": {"image": ["data:image/png;base64," + b64], "response_format": "url"},
    }
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    req = urllib.request.Request(
        IMG, data=json.dumps(body).encode(),
        headers={"Authorization": "Bearer " + key, "Content-Type": "application/json"})
    r = urllib.request.urlopen(req, timeout=300, context=ctx)
    d = json.loads(r.read().decode())
    data = d.get("data", [])
    if not data or not data[0].get("url"):
        # 空 data 多为限流——带响应摘要抛出，调用方退避重试
        raise RuntimeError("empty data (rate-limit?): " + json.dumps(d)[:150])
    url = data[0]["url"]
    with urllib.request.urlopen(url, timeout=120, context=ctx) as resp:
        return resp.read()


def main():
    keys = load_keys()
    key_idx = 0  # 记住最后成功的 key（备用 key 可能失效，不做盲目轮换）
    ok = 0
    for t in TARGETS:
        out_dir = os.path.join(ROOT, "assets", "effects", "unit_anims", t["id"])
        os.makedirs(out_dir, exist_ok=True)
        out_path = os.path.join(out_dir, "attack_f0.png")
        base_path = os.path.join(ROOT, t["base"])
        if os.path.exists(out_path) and "--force" not in sys.argv:
            print("[%s] SKIP (exists)" % t["id"])
            continue
        if not os.path.exists(base_path):
            print("[%s] BASE MISSING: %s" % (t["id"], t["base"]))
            continue
        base = Image.open(base_path).convert("RGBA")
        if base.size != (512, 512):
            base = base.resize((512, 512), Image.LANCZOS)
        if t.get("vehicle"):
            prompt = VEHICLE_MOTION + " " + t.get("extra", "")
        else:
            prompt = BASE_MOTION + " " + t.get("extra", "")
        # 实测该 API 连发易触发限流(空 data)：单目标最多 4 次，失败退避 45s，成功后间隔 20s
        for attempt in range(4):
            key = keys[key_idx % len(keys)]
            try:
                raw = call_img2img(prompt, flatten_black(base_path), key)
                frame = key_black(Image.open(io.BytesIO(raw)))
                # 生成图是 1024×1024——color_match 按 frame 尺寸循环索引 base，必须先缩到 base 尺寸
                if frame.size != base.size:
                    frame = frame.resize(base.size, Image.LANCZOS)
                frame = color_match(frame, base)
                frame = normalize_to_base(frame, base)
                frame.save(out_path)
                print("[%s] OK (key%d) -> %s (%d bytes)" % (t["id"], key_idx % len(keys), out_path, len(raw)))
                ok += 1
                break
            except Exception as e:
                import traceback
                print("[%s] key%d attempt %d failed: %s" % (t["id"], key_idx % len(keys), attempt + 1, e))
                traceback.print_exc()
                key_idx += 1
                time.sleep(45)
        time.sleep(20)
    print("done: %d/%d" % (ok, len(TARGETS)))
    sys.exit(0 if ok == len(TARGETS) else 1)


if __name__ == "__main__":
    main()
