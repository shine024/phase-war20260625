#!/usr/bin/env python3
"""
修复 default_cards.gd 和 card_resource.gd 中的缩进错误
"""

import os
import re
from pathlib import Path

PROJECT_ROOT = Path(__file__).parent.parent

def fix_default_cards():
    """修复 default_cards.gd 中的缩进问题"""
    file_path = PROJECT_ROOT / "data" / "default_cards.gd"

    with open(file_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    fixed_lines = []
    i = 0
    while i < len(lines):
        line = lines[i]

        # 删除 _law 函数末尾错误插入的武器槽位代码（第 224-259 行）
        if i == 223 and line.strip().startswith('# === 武器槽位系统'):
            # 跳过到 return c 之前
            while i < len(lines) and not lines[i].strip().startswith('return c'):
                i += 1
            # 现在找到了 return c 行，继续处理
            line = lines[i] if i < len(lines) else ''

        # 修复 _unit 函数中第 347-382 行的缩进（这些行缺少一个 tab）
        if 346 <= i <= 381:
            # 这些行应该有一个 tab 的缩进
            stripped = line.lstrip()
            if stripped and not line.startswith('\t'):
                # 如果行不以 tab 开头，添加一个 tab
                line = '\t' + stripped

        fixed_lines.append(line)
        i += 1

    with open(file_path, 'w', encoding='utf-8') as f:
        f.writelines(fixed_lines)

    print(f"已修复 {file_path}")


def fix_card_resource():
    """修复 card_resource.gd 中的缩进问题"""
    file_path = PROJECT_ROOT / "resources" / "card_resource.gd"

    with open(file_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    fixed_lines = []
    i = 0
    while i < len(lines):
        line = lines[i]

        # 修复第 375-395 行的缩进（这些行多了一个 tab）
        if 374 <= i <= 394:
            stripped = line.lstrip()
            if stripped:
                # 检查是否有两个 tab
                if line.startswith('\t\t'):
                    # 移除一个 tab
                    line = '\t' + stripped

        fixed_lines.append(line)
        i += 1

    with open(file_path, 'w', encoding='utf-8') as f:
        f.writelines(fixed_lines)

    print(f"已修复 {file_path}")


if __name__ == "__main__":
    print("修复缩进错误...")
    fix_default_cards()
    fix_card_resource()
    print("完成！")
