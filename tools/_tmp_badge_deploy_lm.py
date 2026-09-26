#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""记录4：传说/神话改造图标徽章化部署（用户拍板"可以"采纳样张方向）。

流程：每 mod 2 掷（反写实硬词版 prompt）→ _tmp_modicon_audit 六项择优 →
128 备份原图标（F:\\godot fair duet\\_art_backup\\modicon_badge_20260924\\）→ 部署
assets/ui/icons/mod_icons/<id>.png。引擎导入由调用方跑 --headless --editor --quit。
"""
import json
import os
import shutil
import subprocess
import sys
import time

from PIL import Image

sys.stdout.reconfigure(encoding="utf-8", errors="replace")
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import _tmp_modicon_audit as AUD  # noqa: E402

KEY_FILE = os.path.join(ROOT, "tools", "_api_key.txt")
with open(KEY_FILE, "r", encoding="utf-8") as f:
    KEYS = [k.strip() for k in f.read().splitlines() if k.strip()]
BASE_URL = "https://apihub.agnes-ai.com/v1"
MODEL = "agnes-image-2.0-flash"
ICON_DIR = os.path.join(ROOT, "assets", "ui", "icons", "mod_icons")
BAK_DIR = r"F:\godot fair duet\_art_backup\modicon_badge_20260924"
ROLL_DIR = os.path.join(ROOT, "docs", "徽章管线样张_传说神话_20260924", "rolls")
os.makedirs(ROLL_DIR, exist_ok=True)
os.makedirs(BAK_DIR, exist_ok=True)

ANCHOR = ("科幻策略游戏装备徽章图标，扁平化矢量游戏技能图标风格，平涂色块与霓虹发光勾线，"
          "深空黑到深灰蓝的深底径向渐变，对称纹章构图，"
          "完整徽章整体居中构图，绝不特写局部，绝无景深虚化，绝无照片写实渲染，"
          "无文字无水印无logo")
LEG_TIER = "徽章整体以琥珀金为主色调，金色能量勾线与琥珀色光晕，传说级华贵质感"
MYTH_TIER = ("徽章整体以猩红为主色调，红色能量勾线与绯红光晕，"
             "外围再套一圈红色环形徽章框形成双层徽章，神话级顶端威压感")

JOBS = [
    ("aa_06_laser", "legendary", "主体是一座激光近防阵列徽章：中央旋转 emitter 透镜，"
     "数道金色激光束呈扇形交汇于镜前焦点", 39.0),
    ("arm_04_aps", "legendary", "主体是主动防护系统徽章：相控阵盒向侧前弹出拦截弹，"
     "拦截弹拖出金色弧线拦截轨迹", 39.0),
    ("art_13_apfsds_sabot", "legendary", "主体是尾翼稳定脱壳穿甲弹徽章：细长弹杆水平向左飞行，"
     "弹托瓣分离飞散在弹体后侧，金色速度线", 39.0),
    ("gen_21_vanguard_repair", "mythic", "主体是先锋维修矩阵徽章：环形阵列臂展开，"
     "中心修复光束向下洒落重构机械碎块", 3.0),
    ("gen_22_aegis_protocol", "mythic", "主体是神盾协议力场徽章：六边形蜂窝能量盾面展开，"
     "盾面中心一枚纹章核心发光", 3.0),
    ("gen_23_singularity_core", "mythic", "主体是奇点核心徽章：黑洞式吸积环旋转，"
     "光粒沿环面呈螺旋坠入白炽核心", 3.0),
]


def gen_one(api_key, prompt, out1024):
    payload = json.dumps({"model": MODEL, "prompt": prompt, "size": "1024x1024", "n": 1})
    tmpfile = out1024 + ".payload.json"
    with open(tmpfile, "w", encoding="utf-8") as f:
        f.write(payload)
    resp_file = out1024 + ".resp.json"
    cmd = ["curl", "--http1.1", "-s", "-X", "POST", BASE_URL + "/images/generations",
           "-H", "Authorization: Bearer " + api_key,
           "-H", "Content-Type: application/json",
           "--data-binary", "@" + tmpfile, "-o", resp_file, "--max-time", "180"]
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=200, encoding="utf-8")
    for p in (tmpfile, resp_file):
        if os.path.exists(resp_file):
            break
    if r.returncode != 0 or not os.path.exists(resp_file) or os.path.getsize(resp_file) < 10:
        return None
    content = open(resp_file, encoding="utf-8").read()
    try:
        os.unlink(resp_file)
    except OSError:
        pass
    try:
        data = json.loads(content)
        url = data.get("data")[0].get("url")
    except Exception:
        return None
    if not url:
        return None
    img_file = out1024 + ".img.bin"
    subprocess.run(["curl", "-s", "-L", url, "-o", img_file, "--max-time", "120"],
                   capture_output=True, text=True)
    if not os.path.exists(img_file) or os.path.getsize(img_file) < 1000:
        return None
    try:
        im = Image.open(img_file)
        im.load()
    except Exception:
        return None
    im.convert("RGB").save(out1024)
    try:
        os.unlink(img_file)
    except OSError:
        pass
    return out1024


def audit_score(path, hue):
    try:
        res, fails = AUD.audit(path, sym=False, hue=hue)
    except Exception as e:
        return 999, ["exception:" + str(e)[:40]], {}
    score = len(fails) * 100 - int(res.get("c26", 0)) // 10
    return score, fails, res


def main():
    ki = 0
    deployed, failed = [], []
    for mod_id, tier, subject, hue in JOBS:
        tier_txt = LEG_TIER if tier == "legendary" else MYTH_TIER
        prompt = ANCHOR + "。" + subject + "，" + tier_txt + "。text, frame"
        cands = []
        for roll in range(2):
            out1024 = os.path.join(ROLL_DIR, "%s_r%d_1024.png" % (mod_id, roll))
            if os.path.exists(out1024):
                cands.append(out1024)
                continue
            ok = None
            for attempt in range(5):
                key = KEYS[ki % len(KEYS)]
                ki += 1
                ok = gen_one(key, prompt, out1024)
                if ok:
                    break
                print("ROLL retry", mod_id, roll, attempt + 1)
                time.sleep(31)
            if ok:
                cands.append(out1024)
            time.sleep(20)
        if not cands:
            print("DEPLOY FAIL(no-candidate)", mod_id)
            failed.append(mod_id)
            continue
        scored = []
        for c in cands:
            small = os.path.join(ROLL_DIR, "%s_r%d_128.png" % (mod_id, roll_flag(c, cands)))
            Image.open(c).convert("RGB").resize((128, 128), Image.LANCZOS).save(small)
            score, fails, res = audit_score(small, hue)
            scored.append((score, fails, res, small))
            print("CAND", os.path.basename(small), "score=", score, "fails=", fails, res)
        scored.sort(key=lambda t: t[0])
        best_small = scored[0][3]
        dst = os.path.join(ICON_DIR, mod_id + ".png")
        if os.path.exists(dst):
            shutil.copy2(dst, os.path.join(BAK_DIR, mod_id + ".png"))
        Image.open(best_small).convert("RGBA").save(dst)
        deployed.append(mod_id)
        print("DEPLOY ok", mod_id, "<-", os.path.basename(best_small))
        time.sleep(15)
    print("BADGE_DEPLOY done=%d failed=%d %s" % (len(deployed), len(failed), failed))


def roll_flag(c, cands):
    base = os.path.basename(c)
    return 0 if "_r0_" in base else 1


if __name__ == "__main__":
    main()
