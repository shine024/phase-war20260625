#!/usr/bin/env python3
"""
自动修复 .tscn 文件中的 load_steps 不匹配问题
统计每个文件的实际资源数量（ext_resource + sub_resource），然后更新 load_steps
"""

import os
import re
from pathlib import Path

# 项目根目录
PROJECT_ROOT = Path(__file__).parent.parent
SCENES_DIR = PROJECT_ROOT / "scenes"


def count_resources(file_path: Path) -> int:
    """统计文件中的资源数量（ext_resource + sub_resource）"""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()

        # 计数 [ext_resource] 和 [sub_resource] 开头的行
        ext_count = len(re.findall(r'^\[ext_resource\s', content, re.MULTILINE))
        sub_count = len(re.findall(r'^\[sub_resource\s', content, re.MULTILINE))
        return ext_count + sub_count
    except Exception as e:
        print(f"错误读取 {file_path}: {e}")
        return -1


def get_current_load_steps(file_path: Path) -> int:
    """获取当前声明的 load_steps"""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        match = re.search(r'load_steps=(\d+)', content)
        if match:
            return int(match.group(1))
        return 0
    except Exception as e:
        print(f"错误读取 {file_path}: {e}")
        return -1


def fix_load_steps(file_path: Path, expected_steps: int) -> bool:
    """修复文件的 load_steps"""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()

        # 替换 load_steps
        new_content = re.sub(
            r'load_steps=\d+',
            f'load_steps={expected_steps}',
            content
        )

        if content != new_content:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(new_content)
            return True
        return False
    except Exception as e:
        print(f"错误写入 {file_path}: {e}")
        return False


def main():
    print("扫描 scenes/ui 目录中的 .tscn 文件...")

    mismatches = []
    fixed_count = 0

    # 扫描所有 .tscn 文件
    for tscn_file in SCENES_DIR.rglob("*.tscn"):
        current = get_current_load_steps(tscn_file)
        actual = count_resources(tscn_file)

        if current >= 0 and actual >= 0 and current != actual:
            mismatches.append((tscn_file, current, actual))

    if not mismatches:
        print("没有发现不匹配的文件！")
        return

    print(f"\n发现 {len(mismatches)} 个不匹配的文件：\n")

    # 显示并修复
    for file_path, current, actual in mismatches:
        rel_path = file_path.relative_to(PROJECT_ROOT)
        print(f"  {rel_path}: 声明={current}, 实际={actual}")

        if fix_load_steps(file_path, actual):
            print(f"    [OK] 已修复为 load_steps={actual}")
            fixed_count += 1
        else:
            print(f"    [FAIL] 修复失败")

    print(f"\n修复完成！共修复 {fixed_count} 个文件")


if __name__ == "__main__":
    main()
