# -*- coding: utf-8 -*-
"""_tmp_gen_modicon_pilot.py —— 改造图标试点闭环（8 真实改造 × 3 掷 × 机器审计选优）

用户拍板（2026-09-17）：自动跑分选优，人不逐张看。
贴合来源 = 逐模块"名字→主体意象"映射表（下方 SUBJECTS，生产时由最终数据批量生成）。
不变形来源 = 六项审计指标（tools/_tmp_modicon_audit.py）+ 3 掷选优。
输出：docs/待生成徽章_改造图标样张_20260917/
  pilot_raw/<mod>_r{1,2,3}.png  全掷
  pilot_winners/<mod>.png       每模块选优 1 张
  pilot_report.json             审计指标与选优依据
  试点对比表.png
"""
import base64
import concurrent.futures
import json
import os
import re
import shutil
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from _tmp_modicon_audit import audit as icon_audit  # noqa: E402

KEY_MD = os.path.join(ROOT, "tools", "_agnes_image_api.md")
BASE = os.path.join(ROOT, "docs", "待生成徽章_改造图标样张_20260917")
RAW = os.path.join(BASE, "pilot_raw")
WIN = os.path.join(BASE, "pilot_winners")
URL_BASE = "https://apihub.agnes-ai.cn/v1"
MODEL = "agnes-image-2.1-flash"
SIZE = "1024x1024"
ROLLS = 3

ANCHOR = ("科幻策略游戏装备徽章图标，单一主体居中，对称纹章构图，"
          "深空黑到深灰蓝的深底径向渐变，{line}霓虹发光勾线与能量光晕，"
          "正方形徽章构图，主体完整居中，无文字无水印无logo，中心主体是{subject}")

# 8 真实改造：mod_key → (中文名, 族勾线色, 族色相hue, 稀有度, 主体意象[贴合映射])
PILOT = {
    "INF_02_ASSAULT_RIFLE": ("突击步枪化", "橄榄绿色", 80, "rare", "一支突击步枪的侧面剪影徽记"),
    "ARM_03_REACTIVE_ARMOR": ("爆反装甲", "钢青色", 187, "epic", "斜置的爆炸反应装甲块与起爆火光组成的徽记"),
    "ART_02_EXTENDED_RANGE": ("增程弹", "琥珀金色", 38, "rare", "一枚带尾部助推焰的增程炮弹与抛物弹道弧线组成的徽记"),
    "AA_06_LASER": ("激光近防系统", "钴蓝色", 220, "legendary", "一座近防炮塔向上射出一道弧形激光束的徽记"),
    "AIR_06_BVR_MISSILE": ("超视距导弹", "冰青色", 195, "epic", "一枚翼下挂架上的空对空导弹侧影徽记"),
    "FOR_03_AUTO_TURRET": ("自动炮塔", "珊瑚橙色", 15, "epic", "一座双管自动炮塔的正面徽记"),
    "REC_04_HIGH_POWER_SCOPE": ("高倍瞄准镜", "紫罗兰色", 275, "epic", "一枚高倍率圆形瞄准镜镜片与测距刻线组成的徽记"),
    "enh_dmg_up": ("火力训练", "品红色", 310, "uncommon", "一枚菱形能量晶体与交叉双炮管剪影组成的徽记"),
}


def load_keys():
    src = open(KEY_MD, "r", encoding="utf-8").read()
    return re.findall(r"sk-[A-Za-z0-9]{20,}", src)


KEYS = load_keys()


def call_api(prompt, key, out):
    payload = json.dumps({"model": MODEL, "prompt": prompt, "size": SIZE, "n": 1})
    r = subprocess.run(
        ["curl", "--http1.1", "-s", "-X", "POST", URL_BASE + "/images/generations",
         "-H", "Authorization: Bearer " + key, "-H", "Content-Type: application/json",
         "-d", payload, "--max-time", "180"], capture_output=True, text=True)
    try:
        data = json.loads(r.stdout)
    except Exception:
        return False
    item = (data.get("data") or [{}])[0]
    url = item.get("url", "")
    if url:
        subprocess.run(["curl", "--http1.1", "-s", "-L", "-o", out, url, "--max-time", "180"])
        return os.path.exists(out) and os.path.getsize(out) > 5000
    b64 = item.get("b64_json", "")
    if b64:
        with open(out, "wb") as f:
            f.write(base64.b64decode(b64))
        return os.path.getsize(out) > 5000
    return False


def gen_roll(job):
    mod, roll, prompt = job
    out = os.path.join(RAW, "%s_r%d.png" % (mod, roll))
    if os.path.exists(out) and os.path.getsize(out) > 5000:
        return mod, roll, True
    for attempt in range(2):
        if call_api(prompt, KEYS[(roll + attempt) % len(KEYS)], out):
            return mod, roll, True
        if os.path.exists(out):
            os.remove(out)
        time.sleep(4)
    return mod, roll, False


def main():
    os.makedirs(RAW, exist_ok=True)
    os.makedirs(WIN, exist_ok=True)
    jobs = []
    for mod, (_, line, _, _, subject) in PILOT.items():
        prompt = ANCHOR.format(line=line, subject=subject)
        for roll in range(1, ROLLS + 1):
            jobs.append((mod, roll, prompt))
    with concurrent.futures.ThreadPoolExecutor(max_workers=min(3, len(KEYS))) as ex:
        ok = list(ex.map(gen_roll, jobs))
    bad = [(m, r) for m, r, o in ok if not o]
    print("generated %d/%d" % (len(ok) - len(bad), len(ok)), flush=True)

    report = {}
    for mod, (name, line, hue, rarity, subject) in PILOT.items():
        rows = []
        for roll in range(1, ROLLS + 1):
            p = os.path.join(RAW, "%s_r%d.png" % (mod, roll))
            if not (os.path.exists(p) and os.path.getsize(p) > 5000):
                continue
            m = icon_audit(p, sym=True, hue=hue)
            m["roll"] = roll
            rows.append(m)
        if not rows:
            report[mod] = {"error": "no rolls"}
            continue
        rows.sort(key=lambda r: (not r["pass"], len(r["fails"]), -r["c26"], r["center_off"]))
        best = rows[0]
        shutil.copyfile(os.path.join(RAW, "%s_r%d.png" % (mod, best["roll"])),
                        os.path.join(WIN, mod + ".png"))
        report[mod] = {"name": name, "rarity": rarity, "line": line, "subject": subject,
                       "rolls": rows, "best_roll": best["roll"], "best": best}
        print("%-26s best=r%d pass=%s %s" % (mod, best["roll"], best["pass"],
              " ".join("%s=%s" % kv for kv in best.items() if kv[0] not in ("fails", "pass"))),
              flush=True)
    with open(os.path.join(BASE, "pilot_report.json"), "w", encoding="utf-8") as f:
        json.dump(report, f, ensure_ascii=False, indent=1)

    # ---- 试点对比表：8 胜者 128px + 26px + 名字/稀有度 ----
    from PIL import Image, ImageDraw, ImageFont
    FONT = r"C:\Windows\Fonts\msyh.ttc"
    RAR_COL = {"common": (107, 118, 145), "uncommon": (34, 197, 94), "rare": (56, 189, 248),
               "epic": (192, 132, 252), "legendary": (245, 158, 11), "mythic": (239, 68, 68)}
    sheet = Image.new("RGB", (4 * 260 + 40, 2 * 230 + 70), (10, 18, 31))
    d = ImageDraw.Draw(sheet)
    f_t, f_s = ImageFont.truetype(FONT, 20), ImageFont.truetype(FONT, 14)
    d.text((20, 18), "改造图标试点 8 选（每张 3 掷机器选优 · B 霓虹纹章 · 贴合逐模块定制）",
           font=f_t, fill=(225, 230, 240))
    for i, (mod, (name, _, _, rarity, _)) in enumerate(PILOT.items()):
        p = os.path.join(WIN, mod + ".png")
        if not os.path.exists(p):
            continue
        x, y = 20 + (i % 4) * 260, 70 + (i // 4) * 230
        img = Image.open(p).convert("RGB").resize((150, 150), Image.LANCZOS)
        sheet.paste(img, (x + 30, y))
        small = Image.open(p).convert("RGB").resize((26, 26), Image.LANCZOS)
        sheet.paste(small, (x + 195, y + 62))
        col = RAR_COL.get(rarity, (150, 150, 150))
        d.rectangle((x + 192, y + 58, x + 224, y + 92), outline=col, width=2)
        d.text((x + 30, y + 154), "%s · %s" % (name, rarity), font=f_s, fill=(170, 178, 195))
        d.text((x + 30, y + 176), "r%d %s" % (report[mod]["best_roll"],
               ",".join(report[mod]["best"]["fails"]) or "ALL PASS"),
               font=f_s, fill=(110, 150, 110) if report[mod]["best"]["pass"] else (200, 120, 90))
    sheet.save(os.path.join(BASE, "试点对比表.png"))
    print("sheet saved")


if __name__ == "__main__":
    main()
