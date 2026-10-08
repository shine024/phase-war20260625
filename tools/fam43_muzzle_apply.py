# -*- coding: utf-8 -*-
"""fam43 枪口校准一键应用（2026-10-06 校准页导出 JSON 的下游）。

流程: fam43_calib.json → 回填 _configs_fam43.json（muzzle/flash_angle）
      → codeanim_gen 逐家重生（内置 md5 复跑）→ fam43_deploy_v2 部署指定家
      → Godot 导入 → 刷新审查页。
用法: python tools/fam43_muzzle_apply.py [calib.json 路径]（缺省 .godot/unit_review/fam43_calib.json）
"""
import io
import json
import os
import subprocess
import sys

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CALIB = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
    ROOT, ".godot", "unit_review", "fam43_calib.json")
CFG = os.path.join(ROOT, ".godot", "unit_review", "codeanim_configs", "_configs_fam43.json")
GODOT = r"D:\Downloads\Godot\Godot_v4.5.1-stable_win64.exe"
PY = sys.executable


def sh(cmd):
    print("$", " ".join(cmd), flush=True)
    r = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True,
                       encoding="utf-8", errors="replace")
    tail = (r.stdout or "").strip().split("\n")[-6:]
    print("\n".join("  " + t for t in tail if t), flush=True)
    if r.returncode != 0:
        print("  !! exit=%d %s" % (r.returncode, (r.stderr or "")[-400:]), flush=True)
    return r.returncode == 0


def main():
    calib = json.load(open(CALIB, encoding="utf-8"))
    if not calib:
        sys.exit("calib 为空")
    cfgs = json.load(open(CFG, encoding="utf-8"))
    for k, v in calib.items():
        if k not in cfgs:
            print("[skip] %s 不在配置" % k)
            continue
        cfgs[k]["muzzle"] = v["muzzle"]
        cfgs[k]["flash_angle"] = v.get("flash_angle", cfgs[k].get("flash_angle", 0))
        print("[cfg] %-22s muzzle=%s angle=%s" % (k, v["muzzle"], v.get("flash_angle")))
    json.dump(cfgs, open(CFG, "w", encoding="utf-8"), ensure_ascii=False, indent=1)

    keys = [k for k in calib if k in cfgs]
    for k in keys:
        sh([PY, os.path.join("tools", "codeanim_gen.py"), k, "--configs", CFG])
    sh([PY, os.path.join("tools", "fam43_deploy_v2.py")] + keys)
    sh([GODOT, "--headless", "--editor", "--quit", "--path", "."])
    sh([PY, os.path.join("tools", "fam43_review_page.py")])
    print("DONE 应用 %d 家" % len(keys))


if __name__ == "__main__":
    main()
