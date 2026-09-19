# -*- coding: utf-8 -*-
"""_tmp_gen_modicon_full.py —— 改造图标全量跑（用户 2026-09-17 下令）

249 模块 × 3 掷 → 六项审计选优 → 未过张修复重掷(≤3) → 胜者落盘 + 分族对比表。
断点可续跑：已存在的 raw 文件跳过（中断后原命令重跑即续）。
不改任何游戏数据/资产——胜者停在 docs/ 待用户过审。

输出：docs/待生成徽章_改造图标样张_20260917/
  full_raw/<id>_r{1,2,3}.png      全掷
  full_raw/<id>_fix{1..3}.png     修复掷
  full_winners/<id>.png           每模块 1 张
  full_report.json                全量审计报告
  全量对比表_<族>.png × 10
"""
import json
import os
import shutil
import sys
import time
import concurrent.futures

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from _tmp_modicon_audit import audit as icon_audit  # noqa: E402
from _tmp_gen_modicon_pilot import ANCHOR, call_api, KEYS  # noqa: E402

BASE = os.path.join(ROOT, "docs", "待生成徽章_改造图标样张_20260917")
RAW = os.path.join(BASE, "full_raw")
WIN = os.path.join(BASE, "full_winners")
MAP = os.path.join(BASE, "mapping_draft.json")
SYM_FIX = "，整体画面完全左右对称，主体严格位于正中轴线，两侧元素完全镜像一致"
MAX_FIX = 3


def valid(p):
    return os.path.exists(p) and os.path.getsize(p) > 5000


def gen_job(job):
    mid, tag, prompt = job
    out = os.path.join(RAW, "%s_%s.png" % (mid, tag))
    if valid(out):
        return True
    for attempt in range(2):
        if call_api(prompt, KEYS[(hash(mid) + attempt) % len(KEYS)], out):
            return True
        if os.path.exists(out):
            os.remove(out)
        time.sleep(3)
    return False


def phase1(entries):
    jobs = []
    for e in entries:
        prompt = ANCHOR.format(line=e["line"], subject=e["subject"])
        for roll in ("r1", "r2", "r3"):
            jobs.append((e["id"], roll, prompt))
    done = 0
    fails = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=min(3, len(KEYS))) as ex:
        for mid, ok in ((j[0], r) for j, r in zip(jobs, ex.map(gen_job, jobs))):
            done += 1
            if not ok:
                fails.append(mid)
            if done % 25 == 0:
                print("[gen] %d/%d fails=%d" % (done, len(jobs), len(fails)), flush=True)
    print("[gen] done %d/%d missing=%s" % (done, len(jobs), sorted(set(fails))), flush=True)


def select_best(mid, hue):
    rows = []
    for tag in ("r1", "r2", "r3"):
        p = os.path.join(RAW, "%s_%s.png" % (mid, tag))
        if valid(p):
            m = icon_audit(p, sym=True, hue=hue)
            m["tag"] = tag
            rows.append(m)
    rows.sort(key=lambda r: (not r["pass"], len(r["fails"]), -r["c26"], r["center_off"]))
    return rows


def main():
    entries = json.load(open(MAP, encoding="utf-8"))["entries"]
    print("[full] mods=%d" % len(entries), flush=True)
    os.makedirs(RAW, exist_ok=True)
    os.makedirs(WIN, exist_ok=True)

    t0 = time.time()
    phase1(entries)
    print("[full] phase1 %.0fmin" % ((time.time() - t0) / 60), flush=True)

    report, still = {}, []
    for i, e in enumerate(entries):
        mid, hue = e["id"], float(e["hue"])
        best = select_best(mid, hue)
        fix_rolls = []
        if best and not best[0]["pass"]:
            prompt = ANCHOR.format(line=e["line"], subject=e["subject"]) + SYM_FIX
            for k in range(1, MAX_FIX + 1):
                tag = "fix%d" % k
                if gen_job((mid, tag, prompt)):
                    m = icon_audit(os.path.join(RAW, "%s_%s.png" % (mid, tag)), sym=True, hue=hue)
                    m["tag"] = tag
                    fix_rolls.append(m)
                    if m["pass"]:
                        best = [m] + best
                        break
        if not best:
            still.append(mid + "（0 张可用）")
            report[mid] = {"error": "no image"}
            continue
        winner = best[0]
        shutil.copyfile(os.path.join(RAW, "%s_%s.png" % (mid, winner["tag"])),
                        os.path.join(WIN, mid + ".png"))
        repaired = winner["tag"].startswith("fix")
        report[mid] = {"name": e["name"], "family": e["family"], "rarity": e["rarity"],
                       "best_tag": winner["tag"], "best": winner, "repaired": repaired,
                       "fix_rolls": fix_rolls}
        if not winner["pass"]:
            still.append("%s（%s）" % (mid, ",".join(winner["fails"])))
        if (i + 1) % 25 == 0:
            print("[audit] %d/%d" % (i + 1, len(entries)), flush=True)

    with open(os.path.join(BASE, "full_report.json"), "w", encoding="utf-8") as f:
        json.dump(report, f, ensure_ascii=False, indent=1)
    n_pass = sum(1 for r in report.values() if r.get("best", {}).get("pass"))
    n_fix = sum(1 for r in report.values() if r.get("repaired"))
    print("[full] WINNERS=%d PASS=%d repaired=%d still_failing=%d %.0fmin" %
          (len(report), n_pass, n_fix, len(still), (time.time() - t0) / 60), flush=True)
    for s in still:
        print("  STILL:", s, flush=True)

    # 分族对比表
    from PIL import Image, ImageDraw, ImageFont
    font = ImageFont.truetype(r"C:\Windows\Fonts\msyh.ttc", 15)
    RAR = {"common": (107, 118, 145), "uncommon": (34, 197, 94), "rare": (56, 189, 248),
           "epic": (192, 132, 252), "legendary": (245, 158, 11), "mythic": (239, 68, 68)}
    fams = {}
    for mid, r in report.items():
        fams.setdefault(r.get("family", "?"), []).append((mid, r))
    for fam, items in fams.items():
        cols = 6
        rows = (len(items) + cols - 1) // cols
        sheet = Image.new("RGB", (cols * 220 + 30, rows * 200 + 40), (10, 18, 31))
        d = ImageDraw.Draw(sheet)
        d.text((15, 10), "全量对比表 · %s · %d 张" % (fam, len(items)), font=font,
               fill=(225, 230, 240))
        for i, (mid, r) in enumerate(items):
            p = os.path.join(WIN, mid + ".png")
            if not valid(p):
                continue
            x, y = 20 + (i % cols) * 220, 40 + (i // cols) * 200
            img = Image.open(p).convert("RGB").resize((128, 128), Image.LANCZOS)
            sheet.paste(img, (x, y))
            small = Image.open(p).convert("RGB").resize((26, 26), Image.LANCZOS)
            sheet.paste(small, (x + 140, y + 8))
            d.rectangle((x + 137, y + 5, x + 169, y + 37), outline=RAR.get(r["rarity"], (150, 150, 150)), width=2)
            d.text((x, y + 132), r["name"][:10] + " ·" + r["rarity"][:4], font=font, fill=(170, 178, 195))
            ok = r["best"].get("pass")
            d.text((x, y + 156), r["best_tag"] + (" PASS" if ok else " " + ",".join(r["best"]["fails"])),
                   font=font, fill=(110, 150, 110) if ok else (200, 120, 90))
        sheet.save(os.path.join(BASE, "全量对比表_%s.png" % fam))
    print("[full] sheets done", flush=True)


if __name__ == "__main__":
    main()
