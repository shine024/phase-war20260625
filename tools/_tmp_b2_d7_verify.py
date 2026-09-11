#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""批次② Task 7 字段零动断言——git HEAD vs 工作区逐条解析。

断言（任一失败退出码 1）：
1. 十文件 name/name_en/prototype 及其余一切非 description 内容逐字节一致
   （实现：把两侧所有 description 字符串内容屏蔽为占位后整体比较）；
2. 逐条解析 name/name_en/prototype 字段值零变化（显式报告口径）；
3. 条目数 27/31/25/23/18/17/16/16/15/14，合计 202；
4. description 变更数 == 182（与重写脚本口径一致）。
"""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

ROOT = Path(__file__).resolve().parents[1]
EXPECTED = {
    "infantry": 27, "universal": 31, "air": 25, "artillery": 23, "armor": 18,
    "anti_air": 17, "engineer": 16, "enhancement": 16, "recon": 15, "fort": 14,
}
ENTRY_KEY = re.compile(r'(?m)^\t*"([a-z0-9_]+)"\s*=\s*\{')
DESC = re.compile(r'(?<![A-Za-z_])description = "([^"]*)"')
NAME = re.compile(r'(?<![A-Za-z_])name = "([^"]*)"')          # 排除 slot_name 等；不匹配 name_en（后随 _）
NAME_EN = re.compile(r'(?<![A-Za-z_])name_en = "([^"]*)"')
PROTO = re.compile(r'(?<![A-Za-z_])prototype = "([^"]*)"')


def mask(t: str) -> str:
    return re.sub(r'(description\s*=\s*)"[^"]*"', r'\1<D>', t)


def entries(text: str) -> dict[str, dict[str, str]]:
    spans = [(m.start(), m.group(1)) for m in ENTRY_KEY.finditer(text)]
    out = {}
    for i, (pos, key) in enumerate(spans):
        end = spans[i + 1][0] if i + 1 < len(spans) else len(text)
        b = text[pos:end]
        def one(rx, label):
            f = rx.findall(b)
            assert len(f) == 1, f"{key}:{label} 命中 {len(f)} 次"
            return f[0]
        out[key] = {"name": one(NAME, "name"), "name_en": one(NAME_EN, "name_en"),
                    "prototype": one(PROTO, "prototype"),
                    "description": one(DESC, "description")}
    return out


def main() -> int:
    total = desc_changed = 0
    for stem, expect in EXPECTED.items():
        rel = f"data/modification_modules/{stem}_mods.gd"
        head = subprocess.run(["git", "show", f"HEAD:{rel}"], cwd=ROOT,
                              capture_output=True).stdout.decode("utf-8")
        work = (ROOT / rel).read_text(encoding="utf-8")
        if mask(head) != mask(work):
            print(f"[FAIL] {rel}: 屏蔽 description 后内容仍有差异（非 description 域被改动）")
            return 1
        he, we = entries(head), entries(work)
        if set(he) != set(we):
            print(f"[FAIL] {rel}: 条目键集变化 {set(he) ^ set(we)}")
            return 1
        if len(we) != expect:
            print(f"[FAIL] {rel}: 条目数 {len(we)} != {expect}")
            return 1
        for k in we:
            for f in ("name", "name_en", "prototype"):
                if he[k][f] != we[k][f]:
                    print(f"[FAIL] {rel}:{k}: {f} 变化 «{he[k][f]}» → «{we[k][f]}»")
                    return 1
        changed = sum(1 for k in we if he[k]["description"] != we[k]["description"])
        desc_changed += changed
        total += len(we)
        print(f"[OK] {rel}: {len(we)} 条｜name/name_en/prototype 零动｜description 变更 {changed}")
    if desc_changed != 182:
        print(f"[FAIL] description 变更数 {desc_changed} != 182")
        return 1
    print(f"[PASS] 合计 {total} 条：名域零动断言通过，description 变更 {desc_changed} 条")
    return 0


if __name__ == "__main__":
    sys.exit(main())
