# -*- coding: utf-8 -*-
"""
组装脚本：将4个章节脚本的内容插入 AI_REVIEW_GAME_DESIGN_DOCUMENT.md
- 关卡详细参数 → 插入第二章末尾（2.3势力系统之后），重编号为2.4/2.5
- 我方相位仪目录 → 插入第五章末尾（5.5之后）
- 敌方装备系统 → 追加到文档末尾作为附录A
- 敌方相位师数据 → 追加到文档末尾作为附录B
"""

import os, re, sys

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DOC_PATH = os.path.join(BASE, "docs", "AI_REVIEW_GAME_DESIGN_DOCUMENT.md")

# --- Load section modules ---
def load_section(script_name):
    path = os.path.join(BASE, "scripts", script_name)
    with open(path, "r", encoding="utf-8") as f:
        code = f.read()
    ns = {}
    exec(code, ns)
    return ns.get("SECTION", "")

sec_level = load_section("doc_sec_level_details.py")
sec_player = load_section("doc_sec_player_instruments.py")
sec_enemy_eq = load_section("doc_sec_enemy_equipment.py")
sec_enemy_ms = load_section("doc_sec_enemy_masters.py")

# --- Read original document ---
with open(DOC_PATH, "r", encoding="utf-8") as f:
    lines = f.readlines()

# --- Renumber: 2.2 → 2.4, 2.3 → 2.5 in level section ---
sec_level = sec_level.replace("### 2.2 关卡参数详表", "### 2.4 关卡参数详表")
sec_level = sec_level.replace("#### 2.2.1", "#### 2.4.1")
sec_level = sec_level.replace("#### 2.2.2", "#### 2.4.2")
sec_level = sec_level.replace("#### 2.2.3", "#### 2.4.3")
sec_level = sec_level.replace("### 2.3 环境循环系统", "### 2.5 环境循环系统")

print(f"Level section: {len(sec_level)} chars")
print(f"Player instruments section: {len(sec_player)} chars")
print(f"Enemy equipment section: {len(sec_enemy_eq)} chars")
print(f"Enemy masters section: {len(sec_enemy_ms)} chars")

# --- Find insertion points ---
# 1. Insert point for chapter 2: after "### 2.3 势力系统" section ends (before "## 三" or "## 3")
insert_ch2_idx = None
insert_ch5_idx = None

for i, line in enumerate(lines):
    if line.startswith("## 三、") or line.startswith("## 3、"):
        insert_ch2_idx = i
        break

for i, line in enumerate(lines):
    if line.startswith("## 六、") or line.startswith("## 6、"):
        insert_ch5_idx = i
        break

if insert_ch2_idx is None:
    print("ERROR: Could not find chapter 3 start")
    sys.exit(1)
if insert_ch5_idx is None:
    print("ERROR: Could not find chapter 6 start")
    sys.exit(1)

print(f"Chapter 2 insert point: line {insert_ch2_idx + 1}")
print(f"Chapter 5 insert point: line {insert_ch5_idx + 1}")

# --- Assemble ---
result = []

# Part 1: Everything before chapter 3 (chapters 1-2)
result.extend(lines[:insert_ch2_idx])

# Part 2: Insert level details after chapter 2
result.append("\n" + sec_level.strip() + "\n\n")

# Part 3: Chapters 3-5 (from chapter 3 start to chapter 5 end)
result.extend(lines[insert_ch2_idx:insert_ch5_idx])

# Part 4: Insert player instruments at end of chapter 5
result.append("\n" + sec_player.strip() + "\n\n")

# Part 5: Chapters 6 onwards (chapter 6 to end)
result.extend(lines[insert_ch5_idx:])

# Part 6: Append appendices
result.append("\n---\n\n")
result.append(sec_enemy_eq.strip() + "\n\n")
result.append("---\n\n")
result.append(sec_enemy_ms.strip() + "\n")

# --- Write output ---
output = "".join(result)
with open(DOC_PATH, "w", encoding="utf-8") as f:
    f.write(output)

print(f"\nDone! Document written: {len(output)} chars, {len(lines)} -> {len(result)} lines")
