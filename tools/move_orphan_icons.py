"""孤儿卡图最终分类与移动决策
保守原则：只移动"100% 确认无用"的图，任何可能被回退链命中的保留。

分类：
- MOVE（移动到 _unused）：顶层旧 id 单位图（enemy_*/elite_*/boss_*）、顶层重复 vis_*、顶层通用词图
- KEEP（保留）：units/ 下所有（含 vis_enemy_001-035 预备资产、fort_旧名回退图）
- 已确认备份目录：整体归档
"""
import os
import shutil

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CARD_ICONS = os.path.join(PROJECT_ROOT, "assets", "card_icons")
UNUSED_DIR = os.path.join(CARD_ICONS, "_unused_icons")

# 备份目录（整体保留，不参与分析）
BACKUP_DIRS = {"_agent_source", "_uncut_backup", "enemy_backup_20260623",
               "work_全卡面加工", "_pre_flip_backup_2026-07-03", "_unused_icons"}


def is_backup(rel_dir):
	parts = rel_dir.replace("\\", "/").split("/")
	return any(p in BACKUP_DIRS for p in parts if p != ".")


def main():
	dry = "--dry-run" in __import__("sys").argv
	# 读已用清单
	used = set()
	with open(os.path.join(PROJECT_ROOT, "tools", "_used_icons.txt"), "r", encoding="utf-8") as f:
		for l in f:
			l = l.strip()
			if l.startswith("#") or not l:
				continue
			if l.startswith("res://"):
				l = l[6:]
			used.add(l.replace("\\", "/"))

	# 额外硬编码引用（探测遗漏的）
	EXTRA_USED = {
		"assets/card_icons/units/vis_player_029.png",  # omega OMEGA_SPRITE_PATH
		"assets/card_icons/units/vis_player_072.png",  # 堡垒我方图（for_player=true）
		"assets/card_icons/units/vis_player_073.png",
		"assets/card_icons/units/vis_player_074.png",
		"assets/card_icons/units/vis_player_075.png",
		"assets/card_icons/units/vis_player_076.png",
		"assets/card_icons/units/vis_player_077.png",
		"assets/card_icons/units/vis_player_078.png",
		"assets/card_icons/units/vis_player_079.png",
		"assets/card_icons/units/vis_player_080.png",
		"assets/card_icons/units/vis_player_081.png",
		"assets/card_icons/units/vis_enemy_001.png",  # A/B段敌方原图（预备资产，保留）
	}
	used |= EXTRA_USED

	move_list = []
	keep_list = []
	for dirpath, dirnames, filenames in os.walk(CARD_ICONS):
		rel_dir = os.path.relpath(dirpath, CARD_ICONS)
		if is_backup(rel_dir):
			continue
		for fn in filenames:
			if not fn.endswith(".png"):
				continue
			full = os.path.join(dirpath, fn).replace("\\", "/")
			rel = os.path.relpath(full, PROJECT_ROOT).replace("\\", "/")
			if rel in used:
				continue  # 已用
			# 决策：units/ 下保留（预备资产/回退图），顶层旧id图移动
			if "/units/" in rel:
				keep_list.append(rel)  # units 下保守保留
			else:
				# 顶层：旧 id 单位图 / 重复 vis_ / 通用词图 → 移动
				move_list.append(rel)

	print("=== 移动决策 ===")
	print("移动到 _unused_icons: %d 张" % len(move_list))
	print("保留（units/下预备/回退）: %d 张" % len(keep_list))
	print()

	# 子分类移动清单
	from collections import Counter
	def cat(p):
		fn = os.path.basename(p)
		if fn.startswith(("enemy_", "elite_", "boss_")): return "旧id单位图"
		if fn.startswith("fort_"): return "堡垒图(旧名)"
		if fn.startswith("energy"): return "energy_*"
		if fn.startswith("vis_"): return "vis_*(重复)"
		return "通用词图"
	c = Counter(cat(p) for p in move_list)
	print("=== 移动清单分类 ===")
	for k, v in sorted(c.items()):
		print("  %-20s %d" % (k, v))

	if dry:
		print("\n(DRY-RUN：未移动)")
		return

	# 实际移动
	os.makedirs(UNUSED_DIR, exist_ok=True)
	moved = 0
	for rel in move_list:
		src = os.path.join(PROJECT_ROOT, rel.replace("/", os.sep))
		dst = os.path.join(UNUSED_DIR, os.path.basename(rel))
		# 避免重名覆盖
		if os.path.exists(dst):
			base, ext = os.path.splitext(dst)
			dst = base + "_dup" + str(moved) + ext
		shutil.move(src, dst)
		moved += 1
	print("\n已移动 %d 张到: assets/card_icons/_unused_icons/" % moved)


if __name__ == "__main__":
	main()
