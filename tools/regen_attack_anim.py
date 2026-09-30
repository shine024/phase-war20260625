# -*- coding: utf-8 -*-
"""攻击动画重生成管线 v1（记录4·八轮，视频队列满 → image-2.5 img2img 关键姿态路线）。

对指定单位：以 idle f0 为 img2img 基准，生成 4 类关键姿态（点火/峰值/后坐/烟散），
抠底+注册（履带底线对齐+车体中心对齐）+ 质检（朝向/完整/调色板相似度），
按 12 帧时间结构拼新 sheet_attack.png。原文件自动备份。

用法：
  python tools/regen_attack_anim.py gen  <anim_key> <火器名词> [base_era_prompt]
      例: python tools/regen_attack_anim.py gen guardian_ww1_ironclad 主炮
  python tools/regen_attack_anim.py apply <anim_key>
生成物：.godot/anim_regen/<key>/（raw 候选 + frame_*.png + preview.png）
"""
import base64
import io
import json
import os
import re
import subprocess
import sys
from collections import deque

import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KEYS = re.findall(r'sk-[A-Za-z0-9]{20,}', open(os.path.join(ROOT, 'tools', '_agnes_image_api.md'), encoding='utf-8').read())
API = "https://apihub.agnes-ai.cn/v1/images/generations"
MODEL = "agnes-image-2.5-flash"
WORK = os.path.join(ROOT, ".godot", "anim_regen")
BAK = os.path.join(ROOT, ".godot", "art_backup_anim_regen_20260927")

BASE_STYLE = ("严格保持首帧图像中该单位的外观、比例、涂装、全部细节与花纹完全一致，不改变设计，"
              "不增删任何部件。平面正交正侧视，2D游戏精灵风格，武器指向画面左侧。"
              "背景为纯净无缝纯白色，无地面无阴影无文字无水印。镜头完全锁定，单位完整在画面内不被裁切。")


def call_img2img(prompt, image_b64_uri, key):
    payload = {
        "model": MODEL,
        "prompt": prompt + " " + BASE_STYLE,
        "size": "1K", "ratio": "1:1",
        "extra_body": {"image": [image_b64_uri], "response_format": "b64_json"},
    }
    tmp = os.path.join(WORK, "_payload.json")
    open(tmp, "w").write(json.dumps(payload))
    r = subprocess.run(["curl", "--http1.1", "-s", "-X", "POST", API,
                        "-H", "Authorization: Bearer " + key, "-H", "Content-Type: application/json",
                        "--data-binary", "@" + tmp, "--max-time", "360"],
                       capture_output=True, text=True, timeout=380)
    try:
        d = json.loads(r.stdout)
    except Exception:
        return None, r.stdout[:150]
    err = (d.get("error") or {}).get("message", "")
    b64 = (d.get("data") or [{}])[0].get("b64_json")
    if b64:
        return base64.b64decode(b64), None
    return None, err or json.dumps(d, ensure_ascii=False)[:150]


def flood_white(im, white_t=238):
    a = np.array(im)
    h, w = a.shape[:2]
    white = (a[:, :, 0] >= white_t) & (a[:, :, 1] >= white_t) & (a[:, :, 2] >= white_t) & (a[:, :, 3] > 0)
    seen = np.zeros((h, w), bool)
    dq = deque()
    for x in range(w):
        for y in (0, h - 1):
            if white[y, x] and not seen[y, x]:
                seen[y, x] = True; dq.append((y, x))
    for y in range(h):
        for x in (0, w - 1):
            if white[y, x] and not seen[y, x]:
                seen[y, x] = True; dq.append((y, x))
    while dq:
        y, x = dq.popleft()
        a[y, x, 3] = 0
        for ny, nx in ((y-1, x), (y+1, x), (y, x-1), (y, x+1)):
            if 0 <= ny < h and 0 <= nx < w and white[ny, nx] and not seen[ny, nx]:
                seen[ny, nx] = True; dq.append((ny, nx))
    return Image.fromarray(a)


def tighten_alpha(im):
    a = np.asarray(im).astype(np.int16).copy()
    al = a[:, :, 3]
    m = (al >= 25) & (al <= 210)
    al[m] = np.clip(25 + (al[m] - 25) * (210 - 25) / (210 - 25), 0, 245)
    return Image.fromarray(a.astype(np.uint8))


def content(im):
    a = np.asarray(im)[:, :, 3]
    ys, xs = np.where(a > 12)
    if len(xs) == 0:
        return None
    return im.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))


def hull_ux(im):
    """车体（去左侧 18% 炮管区）内容质心 x 与底缘 y。"""
    a = np.asarray(im)[:, :, 3]
    m = a > 12
    ys, xs = np.where(m)
    if len(xs) == 0:
        return None
    x0, x1, y1 = xs.min(), xs.max(), ys.max()
    cut = x0 + (x1 - x0) * 0.18
    sel = xs >= cut
    cx = xs[sel].mean()
    return float(cx), float(y1), float(x0), float(x1)


def register_to_base(gen_im, base_frame, fs):
    """把生成帧注册到 fs×fs 画布：底缘对齐 f0 底缘，车体质心 x 对齐 f0 车体质心 x，
    缩放按车体宽度比。返回 (registered, qa)。"""
    bf = content(base_frame)
    bg = hull_ux(bf)
    gg = hull_ux(content(gen_im))
    if not bg or not gg:
        return None, "no content"
    b_cx, b_y1, _, _ = bg
    g_cx, g_y1, gx0, gx1 = gg
    b_w = bg[3] - bg[2]
    g_w = gx1 - gx0
    scale = (b_w * 1.0) / max(1.0, g_w)
    scale = max(0.5, min(scale, 1.6))
    nw, nh = max(1, int(gen_im.width * scale)), max(1, int(gen_im.height * scale))
    g2 = gen_im.resize((nw, nh), Image.LANCZOS)
    a2 = np.asarray(g2)[:, :, 3]
    ys, xs = np.where(a2 > 12)
    if len(xs) == 0:
        return None, "empty after scale"
    g2c = hull_ux(g2)
    gcx, gy1 = g2c[0], g2c[1]
    px = int(round(b_cx - gcx))
    py = int(round(b_y1 - gy1))
    canvas = Image.new("RGBA", (fs, fs), (0, 0, 0, 0))
    canvas.alpha_composite(g2, (px, py))
    qa = {"scale": round(scale, 3), "dx": px, "dy": py}
    return canvas, qa


def hsv_sim(im1, im2):
    def hist(im):
        a = np.asarray(im)
        m = a[:, :, 3] > 60
        if m.sum() < 100:
            return None
        rgb = a[:, :, :3][m] / 255.0
        mx = rgb.max(axis=1); mn = rgb.min(axis=1)
        s = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
        r, g, b = rgb[:, 0], rgb[:, 1], rgb[:, 2]
        d = np.maximum(mx - mn, 1e-6)
        h = np.zeros(len(rgb))
        h = np.where(mx == r, ((g - b) / d) % 6, h)
        h = np.where(mx == g, (b - r) / d + 2, h)
        h = np.where(mx == b, (r - g) / d + 4, h)
        H = np.clip((h / 6.0 * 16).astype(int), 0, 15)
        S = np.clip((s * 4).astype(int), 0, 3)
        V = np.clip((mx * 4).astype(int), 0, 3)
        hh = np.zeros(256)
        np.add.at(hh, H * 16 + S * 4 + V, 1)
        return hh / max(hh.sum(), 1)
    hi, hj = hist(im1), hist(im2)
    if hi is None or hj is None:
        return 0.0
    return float(np.dot(hi, hj) / (np.linalg.norm(hi) * np.linalg.norm(hj) + 1e-9))


POSES = {
    "antic":  "开火前一瞬：车体极轻微前倾蓄力，炮管保持原位，无火光无烟。",
    "fire_a": "此刻主炮向画面左侧开火：炮口爆发明亮的白热火光与橙色焰缘（火光紧凑完整、完全在画面内不接触任何边缘），炮管明显后坐后缩，车体轻微后震。",
    "fire_b": "开火峰值：炮口火光最大最亮（白热核心+橙黄焰缘，紧凑完整在画面内），炮口冒出少量烟尘，炮管后坐至最后位，车体后震。",
    "fire_c": "火光衰减：炮口红橙色余焰变小，烟尘略散，炮管保持后坐位。",
    "recoil": "开火完毕：无火光，炮管保持后坐后缩位，炮口飘少量青烟，车体仍轻微后移。",
    "smoke":  "开火后余烟：仅炮口一缕淡青烟缓慢飘散，炮管正缓缓复位，车体接近首帧位置。",
    "settle": "完全回到首帧待机姿态，仅炮口残留最后一丝淡烟。",
}
# 12 帧时间结构
SEQUENCE = [None, "antic", "fire_a", "fire_b", "fire_b", "fire_c", "recoil", "recoil", "smoke", "smoke", "settle", None]


def main_gen(key, weapon):
    os.makedirs(os.path.join(WORK, key), exist_ok=True)
    d = os.path.join(ROOT, "assets", "effects", "unit_anims", key)
    idle = Image.open(os.path.join(d, "sheet_idle.png")).convert("RGBA")
    f0 = idle.crop((0, 0, 256, 256))
    f0.save(os.path.join(WORK, key, "_f0_256.png"))
    f0_512 = f0.convert("RGB").resize((512, 512), Image.LANCZOS)
    buf = io.BytesIO(); f0_512.save(buf, "PNG")
    uri = "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode()
    gen_dir = os.path.join(WORK, key)
    for pose in ["fire_a", "fire_b", "fire_c", "recoil", "smoke", "settle", "antic"]:
        for cand in range(2):
            out = os.path.join(gen_dir, "%s_%d.png" % (pose, cand))
            if os.path.exists(out):
                print("skip exists", out); continue
            raw, err = call_img2img("该单位的主武器为%s。" % weapon + POSES[pose], uri, KEYS[0])
            if raw is None:
                print("%s_%d FAIL: %s" % (pose, cand, err))
                continue
            open(out + ".raw.png", "wb").write(raw)
            im = Image.open(io.BytesIO(raw)).convert("RGBA")
            im = flood_white(im)
            im = tighten_alpha(im)
            im.save(out)
            print("%s_%d ok" % (pose, cand))
    print("GEN_DONE", key)


def main_apply(key):
    d = os.path.join(ROOT, "assets", "effects", "unit_anims", key)
    gen_dir = os.path.join(WORK, key)
    f0 = Image.open(os.path.join(gen_dir, "_f0_256.png")).convert("RGBA")
    frames = []
    qa_all = []
    for i, pose in enumerate(SEQUENCE):
        if pose is None:
            frames.append(f0.copy()); qa_all.append((i, "f0", 1.0)); continue
        cands = []
        for cand in (0, 1):
            p = os.path.join(gen_dir, "%s_%d.png" % (pose, cand))
            if os.path.exists(p):
                gen = Image.open(p).convert("RGBA")
                reg, qa = register_to_base(gen, f0, 256)
                if reg is not None:
                    cands.append((reg, qa, hsv_sim(f0, reg)))
        if not cands:
            print("帧 %d (%s) 无可用候选，回退 f0" % (i, pose))
            frames.append(f0.copy()); qa_all.append((i, pose + "(回退f0)", 1.0)); continue
        cands.sort(key=lambda t: -t[2])
        best, qa, sim = cands[0]
        frames.append(best); qa_all.append((i, pose + " cand" + str(cands.index((best, qa, sim)) + 1), round(sim, 3)))
    sheet = Image.new("RGBA", (256 * 12, 256), (0, 0, 0, 0))
    for i, fr in enumerate(frames):
        sheet.alpha_composite(fr, (i * 256, 0))
    os.makedirs(BAK, exist_ok=True)
    import shutil
    bakp = os.path.join(BAK, "sheet_attack_" + key + ".png")
    if not os.path.exists(bakp):  # 幂等保护：重跑 apply 不得覆盖原件备份
        shutil.copy2(os.path.join(d, "sheet_attack.png"), bakp)
    sheet.save(os.path.join(d, "sheet_attack.png"))
    # 对比图：上排旧 12 帧 / 下排新 12 帧
    old = Image.open(os.path.join(BAK, "sheet_attack_" + key + ".png")).convert("RGBA")
    W = Image.new("RGB", (128 * 12, 128 * 2 + 26), (70, 70, 78))
    dr = ImageDraw.Draw(W)
    for i in range(12):
        for row, src in ((0, old), (1, sheet)):
            fr = src.crop((i * 256, 0, (i + 1) * 256, 256)).convert("RGBA")
            bg = Image.new("RGBA", (128, 128), (70, 70, 78, 255))
            bg.alpha_composite(fr.resize((128, 128)))
            W.paste(bg.convert("RGB"), (i * 128, row * 128 + 18))
            dr.text((i * 128 + 4, row * 128 + 2), "%02d" % i, fill=(255, 220, 120))
    W.save(os.path.join(WORK, key, "before_after.png"))
    print("APPLY_DONE", key)
    for t in qa_all:
        print("  frame", t)


if __name__ == "__main__":
    cmd = sys.argv[1]
    key = sys.argv[2]
    weapon = sys.argv[3] if len(sys.argv) > 3 else "主炮"
    os.makedirs(WORK, exist_ok=True)
    if cmd == "gen":
        main_gen(key, weapon)
    elif cmd == "apply":
        main_apply(key)
