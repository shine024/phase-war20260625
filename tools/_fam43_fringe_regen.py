# -*- coding: utf-8 -*-
"""fam43 品红边晕修复批·staged 重生成驱动（2026-10-06）。

背景：codeanim_gen.load_anchor 新增「品红 AA 边晕清除」（边圈品红签名像素 RGB 就近
回填实色非品红源），fam43 部署版紫晕病根修复。本脚本把判定「可以」已部署的 57 键
（mod_ranger/void_mage_expert 已单键先行重生成，跳过）分 4 片并行调
codeanim_gen.py 逐键重生成（内部自带双跑 md5 一致性检查）。
用法: python tools/_fam43_fringe_regen.py            # 全部
      python tools/_fam43_fringe_regen.py --worker 0/4  # 单片（内部并行用）
"""
import io
import json
import glob
import os
import re
import subprocess
import sys

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CFG = os.path.join(ROOT, ".godot", "unit_review", "codeanim_configs", "_configs_fam43.json")
DONE = {"mod_ranger", "void_mage_expert"}  # 已单键先行重生成并目检过


def load_ok():
    v = {}
    ps = glob.glob(os.path.join(ROOT, "tools", "fam43_review*.json"))
    ps.sort(key=lambda p: int(re.findall(r"\((\d+)\)", p)[-1])
            if re.search(r"\((\d+)\)", p) else -1)
    for p in ps:
        v.update(json.load(open(p, encoding="utf-8")))
    return sorted(k for k, d in v.items() if d.get("status") == "可以")


def main():
    if len(sys.argv) > 1 and sys.argv[1] == "--worker":
        i, n = int(sys.argv[2].split("/")[0]), int(sys.argv[2].split("/")[1])
        keys = [k for j, k in enumerate(load_ok()) if j % n == i and k not in DONE]
        bad = []
        for k in keys:
            r = subprocess.run(
                [sys.executable, os.path.join(ROOT, "tools", "codeanim_gen.py"),
                 k, "--configs", CFG],
                capture_output=True, text=True, encoding="utf-8", errors="replace")
            tail = (r.stdout or "").strip().splitlines()
            line = tail[-1] if tail else (r.stderr or "").strip().splitlines()[-1:]
            print("[w%d] %s" % (i, line if line else k), flush=True)
            if r.returncode != 0 or "MD5-DIFF" in (r.stdout or ""):
                bad.append(k)
        print("[w%d] done %d keys, bad=%s" % (i, len(keys), bad), flush=True)
        return
    n = 4
    ps = [subprocess.Popen([sys.executable, __file__, "--worker", "%d/%d" % (i, n)],
                           stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                           text=True, encoding="utf-8", errors="replace")
          for i in range(n)]
    for p in ps:
        for line in p.stdout:
            print(line, end="", flush=True)
    rc = [p.wait() for p in ps]
    print("[all] workers exit=%s" % rc)


if __name__ == "__main__":
    main()
