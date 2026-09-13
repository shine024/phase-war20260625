#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""美术全量基线打包（AGENTS.md 美术打包铁律的脚本化，v30.6）。

两树 walk（assets/card_icons/ + assets/ui/instruments/，png/svg/txt）→
zipfile ZIP_STORED → 按日期命名落盘。

落盘位置（按可用性自动选择，--out 可覆盖）：
  1. 权威目录 F:\\godot fair duet\\_art_backup\\（发行机；本机常无 F 盘）
  2. 本机镜像 D:\\godotplay\\_art_backup\\（默认兜底）

用法：
    python tools/pack_art_backup.py            # 打包今日基线（已存在则覆盖）
    python tools/pack_art_backup.py --dry      # 只统计不落盘
输出：文件数 / 体积 / sha16（记入 CHANGELOG 与提交说明）。
"""
import argparse
import hashlib
import zipfile
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TREES = ["assets/card_icons", "assets/ui/instruments"]
EXTS = {".png", ".svg", ".txt"}
AUTHORITY_DIR = Path(r"F:\godot fair duet\_art_backup")
MIRROR_DIR = Path(r"D:\godotplay\_art_backup")


def collect() -> list:
    files = []
    for tree in TREES:
        base = ROOT / tree
        for p in sorted(base.rglob("*")):
            if p.suffix.lower() in EXTS and p.is_file():
                files.append(p)
    return files


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry", action="store_true", help="只统计不落盘")
    ap.add_argument("--out", type=Path, default=None, help="指定 zip 输出路径")
    args = ap.parse_args()

    files = collect()
    total = sum(p.stat().st_size for p in files)
    print(f"trees={TREES}")
    print(f"files={len(files)}  raw={total / 1048576:.1f}MB")
    if args.dry:
        return

    out: Path = args.out or (AUTHORITY_DIR if AUTHORITY_DIR.parent.exists() else MIRROR_DIR)
    out.mkdir(parents=True, exist_ok=True)
    zip_path = out / f"phase-war-art-backup-{date.today().isoformat()}.zip"
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_STORED) as z:
        for p in files:
            z.write(p, p.as_posix())
    sha16 = hashlib.sha256(zip_path.read_bytes()).hexdigest()[:16]
    print(f"zip={zip_path}")
    print(f"size_mb={zip_path.stat().st_size / 1048576:.1f}  sha16={sha16}")
    if out == MIRROR_DIR and AUTHORITY_DIR != MIRROR_DIR:
        print(f"⚠️ 权威目录 {AUTHORITY_DIR} 不可用，已落本机镜像——发行机侧记得同步")


if __name__ == "__main__":
    main()
