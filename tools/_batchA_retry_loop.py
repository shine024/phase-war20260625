# -*- coding: utf-8 -*-
"""批A 视频任务重试循环（队列满/限流退避）：每 25 分钟一轮，最多 10 轮，全部完成即停。

单位：ww1_arty_77mm / mod_arm_m1a2sep / ww1_mark4 / ww1_105mm
完成判据：资料/单位分帧动画/*<key>*/attack/ 下 f*.png >= 4
只产 f 帧（staging 语义），绝不写 assets/。日志: .godot/unit_review/_batchA_retry.log
"""
import glob
import os
import re
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LOG = os.path.join(ROOT, ".godot", "unit_review", "_batchA_retry.log")
UNITS = ["ww1_arty_77mm", "mod_arm_m1a2sep", "ww1_mark4", "ww1_105mm"]


def done(key):
    for d in glob.glob(os.path.join(ROOT, "资料", "单位分帧动画", "*")):
        if re.sub(r"^\d{3}_", "", os.path.basename(d)).split("_")[0] == "" :
            continue
        stripped = re.sub(r"^\d{3}_", "", os.path.basename(d))
        if (stripped == key or stripped.startswith(key + "_")) and \
           len(glob.glob(os.path.join(d, "attack", "f*.png"))) >= 4:
            return True
    return False


def log(msg):
    line = "[%s] %s" % (time.strftime("%m-%d %H:%M:%S"), msg)
    print(line, flush=True)
    with open(LOG, "a", encoding="utf-8") as f:
        f.write(line + "\n")


for round_i in range(1, 11):
    todo = [k for k in UNITS if not done(k)]
    if not todo:
        log("全部完成，退出")
        break
    log("第%d轮 待处理: %s" % (round_i, ",".join(todo)))
    for k in todo:
        if done(k):
            continue
        r = subprocess.run([sys.executable, "tools/_batchA_video_driver.py", k],
                           cwd=ROOT, capture_output=True, text=True)
        tail = (r.stdout or "").strip().split("\n")
        tail = [t for t in tail if t.strip()][-3:]
        ok = done(k)
        log("  %-16s %s | %s" % (k, "OK" if ok else "未成", " || ".join(tail)[:200]))
        time.sleep(20)
    if round_i < 10:
        time.sleep(25 * 60)
log("循环结束")
