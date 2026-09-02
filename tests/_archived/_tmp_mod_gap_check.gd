extends SceneTree
## 一次性预检脚本：验证改造 attack_* 百分比/固定值是否真正进入主战斗路径
## （weapon_slots[].damage）——决定 set/flat 攻击通道的落点设计。
## Usage: godot --headless --path . --script tests/_tmp_mod_gap_check.gd

const UnitStatsTable = preload("res://resources/unit_stats_table.gd")
const DefaultCards = preload("res://data/default_cards.gd")

func _initialize() -> void:
	var code := 0
	var card = DefaultCards.get_card_by_id("ww1_arm_ft17").clone()

	# 基线
	var base = UnitStatsTable.build_stats_from_card(card, 0)
	var base_atk_a: float = base.attack_armor
	var base_w1: float = _w_dmg(base, 1)

	# 装 15% 火力训练（enh_dmg_up Lv1: attack_* 三维 +15%）
	card.mods = [{"id": "enh_dmg_up", "level": 1, "enabled": true}]
	var modded = UnitStatsTable.build_stats_from_card(card, 0)
	var mod_atk_a: float = modded.attack_armor
	var mod_w1: float = _w_dmg(modded, 1)

	print("base: attack_armor=%.1f weapon1.damage=%.1f" % [base_atk_a, base_w1])
	print("mod : attack_armor=%.1f weapon1.damage=%.1f" % [mod_atk_a, mod_w1])
	# registry 乘区 int() 截断：272×1.15=312.8 → 312（±1 容差判定）
	if absf(mod_atk_a - base_atk_a * 1.15) > 1.0:
		print("UNEXPECTED: stats.attack_armor 未按 +15% 放大")
		code = 1
	if absf(mod_w1 - base_w1) < 0.01:
		print("GAP-CONFIRMED: 改造 attack 百分比未进入 weapon_slots[].damage（主战斗路径读这里）")
		code = 2
	else:
		print("NO-GAP: weapon damage 已同步（=%.1f → %.1f）" % [base_w1, mod_w1])
	quit(code)

func _w_dmg(stats, idx: int) -> float:
	if stats.weapon_slots.size() <= idx:
		return -1.0
	var w = stats.weapon_slots[idx]
	if w == null:
		return -2.0
	return float(w.damage)
