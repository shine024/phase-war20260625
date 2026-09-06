#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""星冥 20 单位动画批量驱动：只跑 xeno keys（串行流水线 create → poll → build）。

实测 2026-09-04：视频 API free 限流≈同时 1 个在途任务（连续建第 2 个即 429），
故用单遍流水线——任何时刻只有 1 个在途任务；create 撞 429 自动等 60s 重试。
复用 generate_unit_animations.py 的 step 函数（keyframe 视频 → ffmpeg 抽帧 →
白转透 → 源帧 f*.png + sheet）。产出源帧后由 deploy_unit_anims.py 拼条部署。
幂等：已有 _task.json 跳过 create；已有 source.mp4 跳过 poll；已有 sheet 跳过 build。

跑法:
  python tools/generate_xeno_anims.py            # 全部 20 单位 × idle/attack
  python tools/generate_xeno_anims.py vis_xeno_zealot        # 指定单位
  python tools/generate_xeno_anims.py vis_xeno_zealot:attack # 指定单位:动画
"""
import os
import sys
import time
import importlib.util

sys.stdout.reconfigure(encoding="utf-8", errors="replace")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from xeno_assets_config import UNITS as XENO_UNITS

spec = importlib.util.spec_from_file_location(
    "gua", os.path.join(ROOT, "tools", "generate_unit_animations.py"))
gua = importlib.util.module_from_spec(spec)
sys.modules["gua"] = gua
spec.loader.exec_module(gua)

XENO_KEYS = [u["key"] for u in XENO_UNITS]
CREATE_RETRY = 8          # 429 重试次数上限
CREATE_RETRY_WAIT = 60    # 每次等待秒数


def apply_key_filter(arg: str) -> None:
    """--key N：只用 _api_key.txt 第 N 把 key（1-based，逗号分隔多把）。
    多条流水线并行时每线锁一把 key，避免互撞限流。"""
    sel = [int(x) - 1 for x in arg.split(",")]
    all_keys = gua.api_keys()
    bad = [i for i in sel if i < 0 or i >= len(all_keys)]
    if bad or not sel:
        raise SystemExit("--key 越界: %s（共 %d 把）" % (arg, len(all_keys)))
    chosen = [all_keys[i] for i in sel]
    gua.api_keys = lambda: chosen
    print("key 池限定为 #%s（%d 把）" % (arg, len(chosen)))


def create_with_retry(u, a):
    for attempt in range(CREATE_RETRY):
        try:
            gua.step_create(u, a)
            return True
        except Exception as e:
            msg = str(e)
            if "rate_limit" in msg or "429" in msg:
                print("  429 限流，等 %ds 后重试（%d/%d）" % (CREATE_RETRY_WAIT, attempt + 1, CREATE_RETRY))
                time.sleep(CREATE_RETRY_WAIT)
            else:
                print("  CREATE FAIL %s/%s: %s" % (u, a, msg[:200]))
                return False
    print("  CREATE RETRY EXHAUSTED %s/%s" % (u, a))
    return False


def main():
    key_arg = ""
    only = set()
    for a in sys.argv[1:]:
        if a.startswith("--key="):
            key_arg = a[len("--key="):]
        else:
            only.add(a)
    if key_arg:
        apply_key_filter(key_arg)
    jobs = []
    for key in XENO_KEYS:
        for anim in ("idle", "attack"):
            if only and key not in only and ("%s:%s" % (key, anim)) not in only:
                continue
            jobs.append((key, anim))
    print("星冥动画任务 %d 个（串行流水线）" % len(jobs))

    fails = []
    for i, (u, a) in enumerate(jobs):
        sheet = os.path.join(gua.anim_dir(u, a), "sheet_%s.png" % a)
        if os.path.exists(sheet):
            print("[%02d/%02d] skip %s/%s（已有 sheet）" % (i + 1, len(jobs), u, a))
            continue
        mp4 = os.path.join(gua.anim_dir(u, a), "source.mp4")
        try:
            if not os.path.exists(mp4):
                if not create_with_retry(u, a):
                    fails.append("%s/%s" % (u, a))
                    continue
            gua.step_poll(u, a)
            gua.step_build(u, a)
            print("[%02d/%02d] done %s/%s" % (i + 1, len(jobs), u, a))
        except Exception as e:
            print("  FAIL %s/%s: %s" % (u, a, str(e)[:300]))
            fails.append("%s/%s" % (u, a))

    if fails:
        print("\n失败 %d 个（重跑本脚本会自动续）：\n  %s" % (len(fails), "\n  ".join(fails)))
        sys.exit(1)
    print("\n全部完成")


if __name__ == "__main__":
    main()
