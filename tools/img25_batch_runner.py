# -*- coding: utf-8 -*-
"""img25 全量批量 runner（2026-10-01，锚定帧先行路线 §十）

用法:
    python tools/img25_batch_runner.py [--limit N] [--anchors-only] [--keys k1,k2]

读 .godot/unit_review/img25_staging/_worklist.json：
  阶段A：缺 <key>_anchor_raw.png 的单位生成锚定帧（--chroma-out）
  阶段B：缺 <key>_R{1,2,3}_attack_sheet_832.png 的单位跑攻击表 3 掷
断点续跑：产物存在即跳过。日志：staging/_batch.log。状态：staging/_batch_state.json。
终版（无后缀 _attack_sheet_832.png）由人工终审后另出，本 runner 不做。
"""
import argparse
import json
import os
import subprocess
import sys
import time
from datetime import datetime

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ST = os.path.join(ROOT, ".godot", "unit_review", "img25_staging")
LOG = os.path.join(ST, "_batch.log")
STATE = os.path.join(ST, "_batch_state.json")
PIDF = os.path.join(ST, "_batch_runner.pid")

# 人型单位（用户 10-01 拍板：人型难控制，动作要小）——subject 命中即传 --small-motion
HUMANOID_RE = None


def is_humanoid(subject):
    global HUMANOID_RE
    if HUMANOID_RE is None:
        import re
        HUMANOID_RE = re.compile(r'士兵|机枪手|兵$|机甲|机器人|特种兵|喷火兵')
    return bool(HUMANOID_RE.search(subject))


def log(msg):
    line = "[%s] %s" % (datetime.now().strftime("%m-%d %H:%M:%S"), msg)
    print(line, flush=True)
    with open(LOG, "a", encoding="utf-8") as f:
        f.write(line + "\n")


def run_gen(args_list, tries=3):
    """跑子脚本，失败重试（限流退避）。超时/崩溃不炸批——记失败续跑下一个。返回 True/False。"""
    for t in range(tries):
        try:
            r = subprocess.run([sys.executable] + args_list, capture_output=True, text=True,
                               cwd=ROOT, timeout=600)
        except subprocess.TimeoutExpired:
            log("  超时(%d/%d): %s — 600s 强杀，重试" % (t + 1, tries, args_list[1]))
            time.sleep(30 * (t + 1))
            continue
        except OSError as e:
            log("  进程异常(%d/%d): %s" % (t + 1, tries, e))
            time.sleep(30 * (t + 1))
            continue
        if r.returncode == 0:
            if r.stdout.strip():
                log(r.stdout.strip().splitlines()[-1])
            return True
        log("  失败(%d/%d): %s | %s" % (t + 1, tries, args_list[1], (r.stderr or r.stdout or "")[:160]))
        time.sleep(30 * (t + 1))
    return False


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--limit", type=int, default=0, help="最多处理 N 个单位（0=不限）")
    ap.add_argument("--anchors-only", action="store_true")
    ap.add_argument("--keys", default="", help="逗号分隔的 key 白名单")
    args = ap.parse_args()

    with open(PIDF, "w") as f:
        f.write(str(os.getpid()))

    work = json.load(open(os.path.join(ST, "_worklist.json"), encoding="utf-8"))
    if args.keys:
        keep = set(args.keys.split(","))
        work = [w for w in work if w["key"] in keep]

    state = {"done_anchor": [], "done_attack": [], "failed": []}
    if os.path.exists(STATE):
        state = json.load(open(STATE, encoding="utf-8"))
    done_a, done_x, failed = set(state["done_anchor"]), set(state["done_attack"]), set(state["failed"])

    n = 0
    for item in work:
        key, card, subj, atk = item["key"], item["card"], item["subject"], item["attack"]
        if not atk:
            continue
        if args.limit and n >= args.limit:
            log("达到 --limit %d，收工" % args.limit)
            break
        anchor = os.path.join(ST, key + "_anchor_raw.png")
        if not os.path.exists(anchor):
            log("[%s] 锚定帧生成中…" % key)
            if run_gen(["tools/img25_anchor_gen.py", key, card, "--subject", subj, "--chroma-out"]):
                done_a.add(key)
            else:
                failed.add(key)
                continue
        else:
            done_a.add(key)
        json.dump({"done_anchor": sorted(done_a), "done_attack": sorted(done_x), "failed": sorted(failed)},
                  open(STATE, "w", encoding="utf-8"), indent=1)

        if args.anchors_only:
            continue
        missing_rolls = [r for r in (1, 2, 3)
                         if not os.path.exists(os.path.join(ST, "%s_R%d_attack_sheet_832.png" % (key, r)))]
        if missing_rolls:
            log("[%s] 攻击表生成中（缺掷 %s%s）…" % (key, missing_rolls, "，人型小动作" if is_humanoid(subj) else ""))
            extra = ["--small-motion"] if is_humanoid(subj) else []
            if run_gen(["tools/img25_attack_gen.py", key, "--subject", subj.split("（")[0],
                        "--rolls", "3", "--card-align", "--card", card] + extra):
                done_x.add(key)
            else:
                failed.add(key)
                continue
        else:
            done_x.add(key)
        json.dump({"done_anchor": sorted(done_a), "done_attack": sorted(done_x), "failed": sorted(failed)},
                  open(STATE, "w", encoding="utf-8"), indent=1)
        n += 1

    log("=== 批次结束：anchor %d / attack %d / failed %d ===" % (len(done_a), len(done_x), len(failed)))
    if failed:
        log("failed: %s" % sorted(failed))


if __name__ == "__main__":
    main()
