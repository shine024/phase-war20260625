# -*- coding: utf-8 -*-
"""img25 换卡图·侧视重做（10-01 深夜，视角违规修正批）。

背景：Agent C/主会话首批 11 张重生成卡未写视角约束，出图正面/3-4 视角，
违反 STYLE_BIBLE §四（平视全身侧面、facing right、白底无地面）。
本工具按 docs/统一化/STYLE_BIBLE.md §6.1 十段拼装重出 10 张
（ww2_air_dive_bomber 已合格侧视，跳过）。

管线对齐 tools/_tmp_b4_card_regen_b2.py（统一化 B2 批宪法样板）：
1152x768 白底 → flood_white_to_alpha(238) → fit_square(512, x0.88) → player 直出朝右。
API 走 img25 现役 .cn 端点（tools/img25_anchor_gen.py 密钥轮换复用）。

用法：python tools/img25_card_sideview_redo.py gen|deploy|review
"""
import json
import os
import sys
import time

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from img25_anchor_gen import IMG_API, KEYS, gen_image  # noqa: E402  现役端点+轮换

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, ".godot", "unit_review", "img25_staging", "_card_regen")
PDIR = os.path.join(ROOT, "assets", "card_icons", "player")
T256 = os.path.join(PDIR, "..", "_thumb256", "player")
T384 = os.path.join(PDIR, "..", "_thumb384", "player")
FRONT_BAK = os.path.join(ROOT, ".godot", "art_backup_card_front_20261001")

# STYLE_BIBLE §6.1 十段拼装（B2 宪法样板）
COMP_REAL = ("{era} single military unit or vehicle, full body, eye-level side view, facing "
             "right, historically accurate equipment detail, unit fills about three "
             "quarters of the frame with even white margins")
COMP_SCIFI = ("{era} single hard-surface sci-fi unit or vehicle, full body, eye-level "
              "side view, facing right, sleek angular panel lines, unit fills about three "
              "quarters of the frame with even white margins")
RIM_REAL = "one narrow cool sky-blue rim light along the back edge"
RIM_SCIFI = "one narrow cyan rim light along the back edge, faint glow limited to emissive parts"
ANCHOR = ("overcast diffused lighting, {rim}, muted cold palette of deep blue-grey steel "
          "and cold grey, thick painterly illustration, clean painterly silhouettes defined "
          "by value contrast and a narrow rim light, smooth blended brushwork, hard-edge "
          "steel surfaces, clean pure white background with NO ground")
NEGATIVE = ("text, perspective view, three-quarter view, front view, angled view, "
            "frame, ground, ceiling, foreshortening")
# 二掷修正（5-5 定案后）：占比句压不住生成器→改"完整入框"；灰天幕→明写无缝纯白影棚底
COMP_SAFE = ("{era} single military unit or vehicle, full body, eye-level side view, facing "
             "right, historically accurate equipment detail, entire unit fully inside the "
             "frame with generous even white margins on all sides, nothing cropped at the "
             "frame edges, isolated on a seamless pure white studio background")
COMP_SAFE_SCIFI = ("{era} single hard-surface sci-fi unit, full body, eye-level side view, "
                   "facing right, sleek angular panel lines, entire unit fully inside the "
                   "frame with generous even white margins on all sides, nothing cropped at "
                   "the frame edges, isolated on a seamless pure white studio background")

# (key, 部署文件名, prompt)
# 10-02 三批：用户复验抓 5 张仍非 90° 正侧（3/4 视角）——a7v/mark4/105mm/stealth 二批 + dive_bomber
# 首批漏网；无人机另批"不好看"。prompt 改 orthographic 正侧硬锁：主轴水平横贯画面 +
# 两侧重叠成单线（履带/轮）+ 翼面 edge-on 细线 + 明写 no front/rear face visible。
JOBS = [
    ("mod_ranger", "vis_player_061",
     COMP_SAFE.format(era="modern") + ", a single elite ranger rifleman in full dark combat gear "
     "with assault rifle, helmet and field pack, standing in strict profile, rifle raised to his "
     "shoulder aiming forward through the sights, ready to fire, entire body from helmet to "
     "boots fully visible, "
     + ANCHOR.format(rim=RIM_REAL) + ". " + NEGATIVE),
    ("mod_sup_m4_carbine", "mod_sup_m4_carbine",
     COMP_SAFE.format(era="modern") + ", a single modern rifleman with M4 carbine raised to his "
     "shoulder aiming forward through the sights, ready to fire, tan combat uniform and plate "
     "carrier, helmet, standing in strict profile, entire body from helmet to boots fully "
     "visible, "
     + ANCHOR.format(rim=RIM_REAL) + ". " + NEGATIVE),
    ("mod_stinger", "mod_stinger",
     COMP_SAFE.format(era="modern") + ", a single modern air-defense soldier standing upright on "
     "both feet in strict profile, a shoulder-fired surface-to-air missile launcher raised to "
     "his shoulder and aimed forward, the whole launcher tube fully visible inside the frame, "
     "helmet and field gear, legs fully visible from hips to boots, "
     + ANCHOR.format(rim=RIM_REAL) + ". " + NEGATIVE),
    ("mod_stryker_m2", "mod_stryker_m2",
     COMP_SAFE.format(era="modern") + ", a single modern eight-wheeled armored personnel carrier "
     "shown in flat side profile with both the front and the rear of the vehicle fully visible, "
     "remote weapon station and spaced armor, plain camouflage, white void behind the "
     "vehicle, no horizon line, "
     + ANCHOR.format(rim=RIM_REAL) + ". " + NEGATIVE),
    ("platform_modern_stealth", "platform_modern_stealth",
     COMP_SAFE_SCIFI.format(era="near-future") + ", a single compact military quadcopter drone "
     "seen exactly from directly beside it in flat orthographic side view, a flat angular dark "
     "stealth fuselage shaped like a small stealth bomber wing, two propellers visible from "
     "the side as thin horizontal translucent ellipses, one above the nose and one above the "
     "tail, small landing skids tucked beneath the flat body, hovering level, no pilot, no "
     "person, no tail boom, no perspective foreshortening, entire drone fully inside the frame "
     "with generous even white margins on all sides, nothing cropped, isolated on a seamless "
     "pure white studio background, "
     + ANCHOR.format(rim=RIM_SCIFI) + ". " + NEGATIVE
     + ", helicopter, top view, robot, humanoid, mech, person, soldier"),
    ("ww1_105mm", "ww1_105mm",
     COMP_REAL.format(era="WWI") + ", a single WWI heavy field howitzer seen exactly from "
     "directly beside it in flat orthographic side view, its long barrel horizontal and "
     "pointing to the right, tall curved gun shield, the two large spoked wheels overlapping "
     "into one single wheel seen in profile, split carriage trail extending down to the lower "
     "left, no perspective foreshortening, entire unit fully inside the frame with generous "
     "even white margins on all sides, nothing cropped, isolated on a seamless pure white "
     "studio background, "
     + ANCHOR.format(rim=RIM_REAL) + ". " + NEGATIVE),
    ("ww2_air_dive_bomber", "ww2_air_dive_bomber",
     COMP_REAL.format(era="WWII") + ", a single WWII German Ju 87 Stuka dive bomber seen exactly "
     "from directly beside it in flat orthographic side view in level flight, inverted gull "
     "wings seen edge-on as a thin dark line crossing the fuselage, fixed landing gear with "
     "wheel spats, propeller spinner at the nose pointing to the right, tail fin and rudder at "
     "the rear left, no perspective foreshortening, entire aircraft fully inside the frame with "
     "generous even white margins on all sides, nothing cropped, isolated on a seamless pure "
     "white studio background, "
     + ANCHOR.format(rim=RIM_REAL) + ". " + NEGATIVE),
    ("ww1_a7v", "ww1_a7v",
     COMP_REAL.format(era="WWI") + ", a single German A7V heavy tank seen exactly from directly "
     "beside it in flat orthographic side view, the huge boxy riveted hull stretching "
     "horizontally across the whole image, commander cupola on top, a row of side machine-gun "
     "ports along the hull flank, both track runs overlapping into one single continuous track "
     "line along the bottom of the hull, no front or rear face visible, entire unit fully "
     "inside the frame with generous even white margins on all sides, nothing cropped, isolated "
     "on a seamless pure white studio background with no sky and no horizon, "
     + ANCHOR.format(rim=RIM_REAL) + ". " + NEGATIVE),
    ("ww1_mark4", "ww1_mark4",
     COMP_REAL.format(era="WWI") + ", a single British Mark IV rhomboid tank seen exactly from "
     "directly beside it in flat orthographic side view, the complete rhomboid track outline "
     "running over and under the boxy hull like a flat silhouette, one side sponson with its "
     "gun port visible on the near flank, both track runs overlapping into one single "
     "continuous track line, no front or rear face visible, entire unit fully inside the frame "
     "with generous even white margins on all sides, nothing cropped, isolated on a seamless "
     "pure white studio background, "
     + ANCHOR.format(rim=RIM_REAL) + ". " + NEGATIVE),
    ("ww1_lanchest", "ww1_lanchest",
     COMP_REAL.format(era="WWI") + ", a single WWI armoured car with vertical riveted armored body, "
     "small dome turret and spoked wheels, "
     + ANCHOR.format(rim=RIM_REAL) + ". " + NEGATIVE),
    ("platform_future_radar", "vis_player_087",
     COMP_SCIFI.format(era="near-future") + ", a single near-future radar station with dome scanner "
     "array on angular armored base, thin antenna masts, "
     + ANCHOR.format(rim=RIM_SCIFI) + ". " + NEGATIVE),
]


def flood_white_to_alpha(img, thresh=238):
    """边界泛洪白转透明（B2 宪法实现，主体内部浅色/高光不动）。"""
    rgb = img.convert("RGB")
    w, h = rgb.size
    px = rgb.load()
    from collections import deque

    def near_white(x, y):
        r, g, b = px[x, y]
        return r >= thresh and g >= thresh and b >= thresh

    visited = bytearray(w * h)
    q = deque()
    for x in range(w):
        for y in (0, h - 1):
            if near_white(x, y) and not visited[y * w + x]:
                visited[y * w + x] = 1
                q.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            if near_white(x, y) and not visited[y * w + x]:
                visited[y * w + x] = 1
                q.append((x, y))
    while q:
        x, y = q.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h and not visited[ny * w + nx] and near_white(nx, ny):
                visited[ny * w + nx] = 1
                q.append((nx, ny))
    out = rgb.convert("RGBA")
    opx = out.load()
    for y in range(h):
        for x in range(w):
            if visited[y * w + x]:
                r, g, b, _ = opx[x, y]
                opx[x, y] = (r, g, b, 0)
    return out


def fit_square(img, size=512, fill=0.88):
    img = img.convert("RGBA")
    bbox = img.getbbox()
    if bbox:
        img = img.crop(bbox)
    w, h = img.size
    scale = min(size / w, size / h) * fill
    nw, nh = max(1, int(w * scale)), max(1, int(h * scale))
    img = img.resize((nw, nh), Image.LANCZOS)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.paste(img, ((size - nw) // 2, (size - nh) // 2), img)
    return canvas


def raw_path(key):
    return os.path.join(OUT, f"{key}_side_raw.png")


# 键控配置（10-02 救图实验定案）：(flood 阈值, 是否 grow 扩张)。
# grow = 与透明区相邻的浅色像素迭代转透明，治地影/灰带残边；@238 纯 flood 不够的户在此登记。
# 未登记户 238/False（flood2 实测干净：m4_carbine/stinger/stryker_m2/105mm/lanchest/a7v 重掷后）。
KEY_CFG = {
    "mod_ranger": (222, True),            # 底色浅灰，@222 才吃得住（fix3 实验）
    "mod_stryker_m2": (238, True),        # 三掷 raw 轮下地影（grow 除净）
    "ww1_mark4": (238, True),             # 顶缘浅灰渍 grow 除净
    "platform_future_radar": (238, True),  # 底部地影白边
    "platform_modern_stealth": (238, True),  # 起落架下白地影成片
}
# 出图朝左的翻正表（卡图宪法朝右；菱形坦克无文字/对称件镜像无损，士兵无字符镜像无损）
# 10-02 三批目检回填：a7v（尖削车头朝左）、mark4（低车头朝左、指挥舱在右尾端）、
# stealth（尖削机头朝左）；105mm 炮口自然朝右、stuka 机头自然朝右不翻
FLIP = {"ww1_a7v", "ww1_mark4", "platform_modern_stealth"}
# 尾工序近白清零（限深色本体户：本体无合法 ≥235 白，grow 够不到的封闭白斑兜底）
# 10-02 三批：105mm 轮辐间封闭白楔（辐条镂空处白底未透，nearwhite=3356）入列
WIPE_WHITE = {"mod_stryker_m2", "ww1_105mm"}


def grow_alpha(img, thresh=215, max_iter=60):
    """边界泛洪后的补充扩张：透明区邻接的浅色像素继续转透明，迭代到收敛。"""
    im = img.copy()
    w, h = im.size
    px = im.load()
    for _ in range(max_iter):
        frontier = []
        for y in range(h):
            for x in range(w):
                if px[x, y][3] == 0:
                    continue
                r, g, b, _a = px[x, y]
                if not (r >= thresh and g >= thresh and b >= thresh):
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h and px[nx, ny][3] == 0:
                        frontier.append((x, y))
                        break
        if not frontier:
            break
        for x, y in frontier:
            r, g, b, _a = px[x, y]
            px[x, y] = (r, g, b, 0)
    return im


def gen():
    os.makedirs(OUT, exist_ok=True)
    failed = []
    for i, (key, _dep, prompt) in enumerate(JOBS):
        rp = raw_path(key)
        if os.path.exists(rp) and os.path.getsize(rp) > 50000:
            print("skip", key, flush=True)
            continue
        payload = os.path.join(OUT, f"{key}_side.payload.json")
        with open(payload, "w", encoding="utf-8") as f:
            json.dump({"model": "agnes-image-2.1-flash", "prompt": prompt,
                       "size": "1152x768", "n": 1, "response_format": "b64_json"}, f)
        print("-- generate", key, flush=True)
        data = gen_image(payload, key_idx=i)
        if not data:
            print("   FAIL", key, flush=True)
            failed.append(key)
            continue
        if os.path.exists(rp):
            prev = rp.replace("_raw.png", "_raw_prev.png")
            os.replace(rp, prev)  # 重掷先留档，二进制删=永久
            print("   prev archived", os.path.basename(prev), flush=True)
        with open(rp, "wb") as f:
            f.write(data)
        print("   ok", len(data) // 1024, "KB", flush=True)
        time.sleep(2)
    print("[SUMMARY] failed:", failed or "none")
    return 1 if failed else 0


def deploy(*only):
    """部署；可传单位 key 只部署子集（10-02 三批增量）。"""
    os.makedirs(FRONT_BAK, exist_ok=True)
    for key, dep, _p in JOBS:
        if only and key not in only:
            continue
        rp = raw_path(key)
        im = Image.open(rp)
        if key in FLIP:
            im = im.transpose(Image.FLIP_LEFT_RIGHT)
        th, do_grow = KEY_CFG.get(key, (238, False))
        cut = flood_white_to_alpha(im, th)
        if do_grow:
            cut = grow_alpha(cut)
        if key in WIPE_WHITE:
            px = cut.load()
            for y in range(cut.height):
                for x in range(cut.width):
                    r, g, b, a = px[x, y]
                    if a > 0 and min(r, g, b) >= 235:
                        px[x, y] = (r, g, b, 0)
        sq = fit_square(cut, 512)
        dst = os.path.join(PDIR, f"{dep}.png")
        bak = os.path.join(FRONT_BAK, f"{dep}.png")
        if os.path.exists(dst) and not os.path.exists(bak):
            os.replace(dst, bak)  # 首次覆盖：正面违规版入备份
        sq.save(dst)
        for t, size in ((T256, 256), (T384, 384)):
            os.makedirs(t, exist_ok=True)
            sq.resize((size, size), Image.LANCZOS).save(os.path.join(t, f"{dep}.png"))
        print("deployed", key, "->", dep, f"(th={th} grow={do_grow} flip={key in FLIP})")
    print("[SUMMARY] deployed", len(JOBS))


def review():
    S = 240
    from PIL import ImageDraw
    sheet = Image.new("RGB", (S * 5 + 12, (S + 22) * 2 + 8), (30, 30, 34))
    d = ImageDraw.Draw(sheet)
    for i, (key, dep, _p) in enumerate(JOBS):
        rp = raw_path(key)
        if not os.path.exists(rp):
            continue
        im = Image.open(rp).convert("RGB")
        w, h = im.size
        s = min(w, h)
        im = im.crop(((w - s) // 2, (h - s) // 2, (w + s) // 2, (h + s) // 2)).resize((S, S))
        x, y = (i % 5) * (S + 2), (i // 5) * (S + 26)
        sheet.paste(im, (4 + x, 22 + y))
        d.text((6 + x, 6 + y), key, fill=(255, 220, 120))
    outp = os.path.join(ROOT, ".godot", "unit_review", "codeanim", "_card_side_raws.png")
    sheet.save(outp)
    print("saved", outp)


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "gen"
    os.chdir(ROOT)
    sys.exit({"gen": gen, "deploy": deploy, "review": review}[cmd](*sys.argv[2:]))
