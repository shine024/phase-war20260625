#!/usr/bin/env python3
"""
精确修复 default_cards.gd 中 _unit 函数的武器槽位代码缩进
"""

from pathlib import Path

PROJECT_ROOT = Path(__file__).parent.parent

def fix_weapon_slots_indentation():
    """修复武器槽位代码的缩进"""
    file_path = PROJECT_ROOT / "data" / "default_cards.gd"

    with open(file_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    fixed_lines = []
    for i, line in enumerate(lines):
        # 武器槽位代码块（第 309-346 行）
        if 308 <= i <= 345:
            stripped = line.lstrip()
            if not stripped:  # 空行
                fixed_lines.append('\n')
                continue

            # 注释行：1 tab + 2 spaces
            if stripped.startswith('#'):
                fixed_lines.append('\t  ' + stripped + '\n')
            # 变量声明和语句：1 tab
            elif stripped.startswith('c.') or stripped.startswith('if ') or stripped.startswith('else:') or stripped.startswith('for ') or stripped.startswith('var ') or stripped.startswith('return '):
                fixed_lines.append('\t' + stripped + '\n')
            # 函数调用参数行：2 tabs（在 var 语句内）
            elif stripped.startswith('0, ') or stripped.startswith('1, ') or stripped.startswith('2, ') or stripped.startswith('c.weapon_type') or stripped.startswith('c.weapon_type') or stripped.startswith('w_light.') or stripped.startswith('w_armor.') or stripped.startswith('w_air.'):
                fixed_lines.append('\t\t' + stripped + '\n')
            else:
                fixed_lines.append(line)
        else:
            fixed_lines.append(line)

    with open(file_path, 'w', encoding='utf-8') as f:
        f.writelines(fixed_lines)

    print(f"已修复 {file_path}")

if __name__ == "__main__":
    fix_weapon_slots_indentation()
    print("完成！")
