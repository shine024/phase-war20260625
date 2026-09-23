# -*- coding: utf-8 -*-
"""_tmp_deploy_modicons.py —— v37.2 改造图标全量部署
①备份旧 mod_icons → ②249 胜者复制入位 → ③重映射 10 个数据文件的 icon 字段 → ④校验
旧图先整目录备份到 .godot/art_backup_modicons_v37_20260918/；旧文件本体保留原地
（部分旧文件名与新胜者同名会被覆盖——备份里有底）。
"""
import os
import re
import glob
import shutil

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WIN = os.path.join(ROOT, "docs", "待生成徽章_改造图标样张_20260917", "full_winners")
ICON_DIR = os.path.join(ROOT, "assets", "ui", "icons", "mod_icons")
BACKUP = os.path.join(ROOT, ".godot", "art_backup_modicons_v37_20260918")
SRC_GLOB = os.path.join(ROOT, "data", "modification_modules", "*_mods.gd")
RES_BASE = "res://assets/ui/icons/mod_icons/"


def main():
    winners = {fn[:-4] for fn in os.listdir(WIN) if fn.endswith(".png")}
    print("winners=%d" % len(winners))

    # ① 备份
    if not os.path.isdir(BACKUP):
        shutil.copytree(ICON_DIR, BACKUP,
                        ignore=shutil.ignore_patterns("*.import"))
        print("backup ->", BACKUP)

    # ② 胜者入位
    n = 0
    for fn in os.listdir(WIN):
        if fn.endswith(".png"):
            shutil.copyfile(os.path.join(WIN, fn), os.path.join(ICON_DIR, fn))
            n += 1
    print("copied=%d" % n)

    # ③ 重映射 icon 字段（只动 data/modification_modules 数据文件的 icon 行）
    replaced, missing = 0, []
    for f in sorted(glob.glob(SRC_GLOB)):
        src = open(f, "r", encoding="utf-8").read()
        starts = list(re.finditer(r'"([a-z0-9_]+)"\s*=\s*\{', src))
        out = src
        touched = 0
        for i in reversed(range(len(starts))):
            m = starts[i]
            end = starts[i + 1].start() if i + 1 < len(starts) else len(src)
            block = src[m.start():end]
            mid = m.group(1)
            if mid not in winners:
                missing.append(os.path.basename(f) + ":" + mid)
                continue
            new_block, hit = re.subn(
                r'icon\s*=\s*"res://assets/ui/icons/mod_icons/[^"]*"',
                'icon = "%s%s.png"' % (RES_BASE, mid), block, count=1)
            if hit:
                out = out[:m.start()] + new_block + out[end:]
                touched += hit
        if touched:
            open(f, "w", encoding="utf-8").write(out)
            replaced += touched
            print("  %s: %d icons" % (os.path.basename(f), touched))
    print("remapped=%d missing_winners=%d" % (replaced, len(missing)))
    for x in missing[:10]:
        print("  MISS", x)

    # ④ 校验：数据引用的每个新图标文件都在磁盘上
    bad = []
    for f in sorted(glob.glob(SRC_GLOB)):
        src = open(f, "r", encoding="utf-8").read()
        for m in re.finditer(r'"res://assets/ui/icons/mod_icons/([a-z0-9_]+)\.png"', src):
            if not os.path.exists(os.path.join(ICON_DIR, m.group(1) + ".png")):
                bad.append(m.group(1))
    print("dangling_refs=%d" % len(bad))
    print("DEPLOY OK" if not bad else "DEPLOY HAS DANGLING REFS")


if __name__ == "__main__":
    main()
