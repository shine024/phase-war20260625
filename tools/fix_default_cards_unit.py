#!/usr/bin/env python3
"""
修复 default_cards.gd 中 _unit 函数的武器槽位代码缩进
"""

from pathlib import Path

PROJECT_ROOT = Path(__file__).parent.parent

def fix_unit_function():
    """修复 _unit 函数中的武器槽位代码缩进"""
    file_path = PROJECT_ROOT / "data" / "default_cards.gd"

    with open(file_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    fixed_lines = []
    for i, line in enumerate(lines):
        # 第 310-344 行（约）的武器槽位代码需要减少一个 tab 的缩进
        if 309 <= i <= 343:
            stripped = line.lstrip()
            if stripped and not stripped.startswith('#'):
                # 如果这行不是注释，减少一个 tab 的缩进
                if line.startswith('\t\t'):
                    line = '\t' + stripped
        fixed_lines.append(line)

    with open(file_path, 'w', encoding='utf-8') as f:
        f.writelines(fixed_lines)

    print(f"已修复 {file_path}")

if __name__ == "__main__":
    fix_unit_function()
    print("完成！")
