# -*- coding: utf-8 -*-
"""10-01 想像力批重出：8 个挂起单位按逐格动作脚本（_special10/_actions/<key>.json）
从冻结新锚定重出攻击表 3 掷。动作设计依据用户 10-01 令"飞机可以投弹，攻击动作要有想像力"。

用法: python tools/img25_special10_regen.py [--keys k1,k2] [--rolls N]
旧产物改名 _pre101 后缀保留（掷废可回退），不删除。
"""
import argparse
import json
import os
import re
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ST = os.path.join(ROOT, ".godot", "unit_review", "img25_staging")
ACT = os.path.join(ST, "_special10", "_actions")
KEYS = ["cold_ak47", "cold_arty_brem1", "cold_mig21", "fut_stealth_bomber",
        "fut_sup_ps9", "mod_air_bomber", "mod_hummer_m2", "mod_stryker_mgs"]
HUMANOID_RE = re.compile(r'士兵|机枪手|兵$|机甲|机器人|特种兵|喷火兵')


def archive(key, rolls):
    """旧掷产物改名保留（防重出失败无回退）。注意 raw 真名=<key>_attack_raw_R<n>.png（后缀在后）。"""
    for r in range(1, rolls + 1):
        for pat in ("%s_attack_raw_R%d.png", "%s_R%d_attack_sheet_832.png"):
            p = os.path.join(ST, pat % (key, r))
            if os.path.exists(p):
                dst = p.replace(".png", "_pre101.png")
                if os.path.exists(dst):
                    dst = p.replace(".png", "_pre101b.png")
                os.rename(p, dst)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--keys", default="", help="逗号分隔子集（默认 8 全跑）")
    ap.add_argument("--rolls", type=int, default=3)
    a = ap.parse_args()
    keys = [k.strip() for k in a.keys.split(",") if k.strip()] or KEYS

    wl = json.load(open(os.path.join(ST, "_worklist.json"), encoding="utf-8"))
    items = wl if isinstance(wl, list) else wl.get("work", wl.get("items", []))
    by_key = {it["key"]: it for it in items}

    for k in keys:
        it = by_key[k]
        spec = os.path.join(ACT, k + ".json")
        if not os.path.exists(spec):
            print("[%s] 缺动作脚本 %s，跳过" % (k, spec), flush=True)
            continue
        anchor = os.path.join(ST, k + "_anchor_raw.png")
        if not os.path.exists(anchor):
            print("[%s] 缺锚定帧，跳过" % k, flush=True)
            continue
        archive(k, a.rolls)
        cmd = ["tools/img25_attack_gen.py", k,
               "--subject", it["subject"].split("（")[0],
               "--rolls", str(a.rolls), "--card-align", "--card", it["card"],
               "--cells-json", spec]
        if HUMANOID_RE.search(it["subject"]):
            cmd.append("--small-motion")
        print("[%s] 重出开始（%d 掷，动作=%s）" % (k, a.rolls, spec), flush=True)
        t0 = time.time()
        try:
            r = subprocess.run([sys.executable] + cmd, capture_output=True, text=True,
                               cwd=ROOT, timeout=600 * (a.rolls + 1))
        except subprocess.TimeoutExpired:
            print("[%s] 超时强杀" % k, flush=True)
            continue
        tail = (r.stdout.strip().splitlines() or [""])[-1][:140]
        print("[%s] rc=%d %.0fs | %s" % (k, r.returncode, time.time() - t0, tail), flush=True)
        if r.returncode != 0:
            print("  stderr:", (r.stderr or "")[-300:], flush=True)
    print("=== 想像力批重出结束 ===", flush=True)


if __name__ == "__main__":
    main()
