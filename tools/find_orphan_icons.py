"""孤儿卡图识别（修复路径分隔符问题）"""
import os

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# 1. 读 used，标准化为正斜杠相对路径
used = set()
with open(os.path.join(PROJECT_ROOT, "tools", "_used_icons.txt"), "r", encoding="utf-8") as f:
    for l in f:
        l = l.strip()
        if l.startswith("#") or not l:
            continue
        if l.startswith("res://"):
            l = l[6:]
        used.add(l.replace("\\", "/"))

# 2. walk，标准化为正斜杠
BACKUP_DIRS = {"_agent_source", "_uncut_backup", "enemy_backup_20260623", "work_全卡面加工", "_pre_flip_backup_2026-07-03"}
root = os.path.join(PROJECT_ROOT, "assets", "card_icons")
all_png = []
orphans = []
for dirpath, dirnames, filenames in os.walk(root):
    rel_dir = os.path.relpath(dirpath, root).replace("\\", "/")
    if any(p in BACKUP_DIRS for p in rel_dir.split("/") if p != "."):
        continue
    for fn in filenames:
        if not fn.endswith(".png"):
            continue
        full = os.path.join(dirpath, fn).replace("\\", "/")
        # 转成项目相对路径 assets/card_icons/...
        rel = os.path.relpath(full, PROJECT_ROOT).replace("\\", "/")
        all_png.append(rel)
        if rel not in used:
            orphans.append(rel)

hit = len(all_png) - len(orphans)
print("被引用:", len(used), "| 总png:", len(all_png), "| 命中:", hit, "| 孤儿:", len(orphans))

# 验证
test = "assets/card_icons/units/vis_player_001.png"
print("vis_player_001 命中?", test in used)

# 写出孤儿清单
out = os.path.join(PROJECT_ROOT, "tools", "_orphan_icons.txt")
with open(out, "w", encoding="utf-8") as f:
    f.write("# 孤儿卡图清单（未被引用）\n")
    f.write("# 总 %d | 命中 %d | 孤儿 %d\n" % (len(all_png), hit, len(orphans)))
    for p in sorted(orphans):
        f.write(p + "\n")
print("孤儿清单写入:", out)

# 分类统计
from collections import Counter
def cat(p):
    fn = os.path.basename(p)
    if "/units/" in p:
        if fn.startswith("vis_player"): return "units/vis_player"
        if fn.startswith("vis_enemy"): return "units/vis_enemy"
        if fn.startswith("vis_pool"): return "units/vis_pool"
        return "units/其他"
    if fn.startswith(("enemy_", "elite_", "boss_")): return "顶层 旧id单位图"
    if fn.startswith("fort_"): return "顶层 堡垒图(旧名)"
    if fn.startswith("energy"): return "顶层 energy"
    if fn.startswith("vis_"): return "顶层 vis_(重复)"
    return "顶层通用"
c = Counter(cat(p) for p in orphans)
print("\n=== 孤儿分类 ===")
for k, v in sorted(c.items()):
    print("  %-25s %d" % (k, v))
