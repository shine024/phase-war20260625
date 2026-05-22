#!/usr/bin/env python3
"""逐行跟踪括号平衡，跳过字符串和注释中的括号。"""

import sys
import re

def strip_comments_and_strings(line: str) -> str:
    """移除GDScript中的注释和字符串字面量，返回仅含代码的部分。"""
    result = []
    i = 0
    while i < len(line):
        c = line[i]
        # 字符串字面量 (双引号)
        if c == '"':
            # 跳过整个字符串
            result.append(' ')  # 保留一个占位
            i += 1
            while i < len(line) and line[i] != '"':
                if line[i] == '\\':
                    i += 1  # 跳过转义字符
                i += 1
            if i < len(line):
                i += 1  # 跳过结束引号
            continue
        # 字符串字面量 (单引号) - GDScript 不常用但以防万一
        elif c == "'":
            result.append(' ')
            i += 1
            while i < len(line) and line[i] != "'":
                if line[i] == '\\':
                    i += 1
                i += 1
            if i < len(line):
                i += 1
            continue
        # 注释
        elif c == '#':
            break  # 注释到行尾，直接截断
        else:
            result.append(c)
            i += 1
    return ''.join(result)

def check_file(filepath: str):
    print(f"\n{'='*60}")
    print(f"Checking: {filepath}")
    print(f"{'='*60}")
    
    with open(filepath, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    # Track brackets: () [] {}
    round_bal = 0
    square_bal = 0
    curly_bal = 0
    
    # Track minimum balance (most negative point)
    round_min = 0
    square_min = 0
    curly_min = 0
    
    # First pass: find where balance goes negative
    print("\n--- Round brackets () ---")
    round_bal = 0
    for i, raw_line in enumerate(lines, 1):
        code = strip_comments_and_strings(raw_line)
        for c in code:
            if c == '(':
                round_bal += 1
            elif c == ')':
                round_bal -= 1
        if round_bal < round_min:
            round_min = round_bal
            print(f"  Line {i:4d}: balance={round_bal:+d}  | {raw_line.rstrip()}")
    print(f"  Final round bracket balance: {round_bal} (min was {round_min})")
    
    print("\n--- Square brackets [] ---")
    square_bal = 0
    for i, raw_line in enumerate(lines, 1):
        code = strip_comments_and_strings(raw_line)
        for c in code:
            if c == '[':
                square_bal += 1
            elif c == ']':
                square_bal -= 1
        if square_bal < square_min:
            square_min = square_bal
            print(f"  Line {i:4d}: balance={square_bal:+d}  | {raw_line.rstrip()}")
    print(f"  Final square bracket balance: {square_bal} (min was {square_min})")
    
    print("\n--- Curly brackets {{}} ---")
    curly_bal = 0
    for i, raw_line in enumerate(lines, 1):
        code = strip_comments_and_strings(raw_line)
        for c in code:
            if c == '{':
                curly_bal += 1
            elif c == '}':
                curly_bal -= 1
        if curly_bal < curly_min:
            curly_min = curly_bal
            print(f"  Line {i:4d}: balance={curly_bal:+d}  | {raw_line.rstrip()}")
    print(f"  Final curly bracket balance: {curly_bal} (min was {curly_min})")
    
    # Now detailed analysis: show lines where changes happen for problem brackets
    print("\n--- Detailed line-by-line for problem brackets ---")
    if round_bal != 0 or round_min < 0:
        print("  Round brackets () detailed:")
        bal = 0
        for i, raw_line in enumerate(lines, 1):
            code = strip_comments_and_strings(raw_line)
            open_count = code.count('(')
            close_count = code.count(')')
            old_bal = bal
            bal += open_count - close_count
            if open_count > 0 or close_count > 0:
                print(f"    L{i:4d}: {old_bal:+d} -> {bal:+d}  (+{open_count}/-{close_count})  {raw_line.rstrip()}")
    
    if curly_bal != 0 or curly_min < 0:
        print("  Curly brackets {} detailed:")
        bal = 0
        for i, raw_line in enumerate(lines, 1):
            code = strip_comments_and_strings(raw_line)
            open_count = code.count('{')
            close_count = code.count('}')
            old_bal = bal
            bal += open_count - close_count
            if open_count > 0 or close_count > 0:
                print(f"    L{i:4d}: {old_bal:+d} -> {bal:+d}  (+{open_count}/-{close_count})  {raw_line.rstrip()}")

if __name__ == '__main__':
    import os
    base = r'D:\godotplay\phase-war'
    check_file(os.path.join(base, 'scenes', 'tower', 'tower_main.gd'))
    check_file(os.path.join(base, 'tools', 'game_data_analyzer.gd'))
