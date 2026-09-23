#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""garand 视频管线产物 → 部署（512 master 留审查区，256 写 unit_anims）。

前置：generate_unit_animations.py build 已产出
  资料/单位分帧动画/NNN_ww2_arm_garand_para_空降步兵加兰德/{idle,attack}/sheet_*.png (512 master)
本脚本：备份旧部署表 preW3C → 目视条带 → 用户通过后手动跑 deploy 段。
用法：python _tmp_w5_garand_deploy.py check   （只出条带+质检）
      python _tmp_w5_garand_deploy.py deploy  （备份+部署 256）
"""
import glob
import os
import shutil
import sys

from PIL import Image

sys.stdout.reconfigure(encoding="utf-8", errors="replace")
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WORK = os.path.join(ROOT, "资料", "单位分帧动画")
DEPLOY = os.path.join(ROOT, "assets", "effects", "unit_anims", "ww2_arm_garand_para")
REV = os.path.join(ROOT, "docs", "flow重生成_审查", "动画雪碧图")


def masters():
    out = {}
    for d in glob.glob(os.path.join(WORK, "*_ww2_arm_garand_para_*")):
        for anim in ("idle", "attack"):
            p = os.path.join(d, anim, "sheet_%s.png" % anim)
            if os.path.exists(p):
                out[anim] = p
    return out


def check():
    ms = masters()
    if len(ms) < 2:
        print("master 缺失:", ms)
        return 1
    for anim, p in sorted(ms.items()):
        im = Image.open(p).convert("RGBA")
        n = im.size[0] // 512
        strip = im.resize((im.size[0] // 2, 256), Image.LANCZOS)
        strip.save(os.path.join(REV, "ww2_arm_garand_para_%s_sheet_v6_strip.png" % anim))
        print("%s: %d 帧 %s" % (anim, n, im.size))
    return 0


def deploy():
    ms = masters()
    os.makedirs(REV, exist_ok=True)
    for anim, src in sorted(ms.items()):
        cur = os.path.join(DEPLOY, "sheet_%s.png" % anim)
        if os.path.exists(cur):
            bak = os.path.join(REV, "ww2_arm_garand_para_%s_sheet_preW3C.png" % anim)
            if not os.path.exists(bak):
                shutil.copy2(cur, bak)
                print("备份旧表 ->", os.path.basename(bak))
        im = Image.open(src).convert("RGBA")
        out = im.resize((im.size[0] // 2, 256), Image.LANCZOS)
        out.save(cur)
        shutil.copy2(cur, os.path.join(REV, "ww2_arm_garand_para_%s_sheet.png" % anim))
        print("deploy", anim, out.size)
    return 0


if __name__ == "__main__":
    sys.exit(check() if (len(sys.argv) < 2 or sys.argv[1] == "check") else deploy())
