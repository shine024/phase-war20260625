#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""W3 步骤 1 增量盘点——diff 2026-09-09 基线 zip vs assets/ 全树（2026-09-14 收尾计划 W3）。

以 `_art_backup/phase-war-art-backup-2026-09-09.zip`（2299 文件）为对照，
列出 assets/ 全树 png 的 新增 / 变更 / 删除 三清单（变更判定=CRC32 或 size 不一致）。
输出：stdout 报告 + `docs/统一化/plans/w3_increment_manifest.json`（供步骤 2 分档消费）。
"""
import os
import sys
import json
import zipfile
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "assets")
ZIP = r"F:\godot fair duet\_art_backup\phase-war-art-backup-2026-09-09.zip"
OUT = os.path.join(ROOT, "docs", "统一化", "plans", "w3_increment_manifest.json")


def main() -> int:
    znames = {}
    with zipfile.ZipFile(ZIP) as z:
        for zi in z.infolist():
            if zi.is_dir():
                continue
            znames[zi.filename.replace("\\", "/")] = (zi.file_size, zi.CRC)

    local = {}
    for dirpath, _dirnames, filenames in os.walk(ASSETS):
        for fn in filenames:
            if not fn.lower().endswith(".png"):
                continue
            p = os.path.join(dirpath, fn)
            rel = "assets/" + os.path.relpath(p, ASSETS).replace("\\", "/")
            local[rel] = p

    added, changed, same, missing = [], [], 0, []
    for rel, p in sorted(local.items()):
        with open(p, "rb") as f:
            data = f.read()
        crc = zlib.crc32(data) & 0xFFFFFFFF
        if rel not in znames:
            added.append(rel)
        elif znames[rel] != (len(data), crc):
            changed.append(rel)
        else:
            same += 1
    for rel in sorted(znames):
        if rel.endswith(".png") and rel not in local:
            missing.append(rel)

    print("[BASE] zip 条目 %d（png %d）｜本地 assets png %d"
          % (len(znames), sum(1 for k in znames if k.endswith(".png")), len(local)))
    print("[ADDED] %d" % len(added))
    for r in added:
        print("  +", r)
    print("[CHANGED] %d" % len(changed))
    for r in changed:
        print("  ~", r)
    print("[MISSING] %d" % len(missing))
    for r in missing:
        print("  -", r)
    print("[SAME] %d" % same)

    with open(OUT, "w", encoding="utf-8") as f:
        json.dump({"added": added, "changed": changed, "missing": missing,
                   "same_count": same}, f, ensure_ascii=False, indent=1)
    print("[JSON]", OUT)
    return 0


if __name__ == "__main__":
    sys.exit(main())
