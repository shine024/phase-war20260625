extends RefCounted
class_name CombatFeedback
## 战斗飘字：伤害 / MISS（格子战无 BattleHud 时由 BattleManager 信号驱动）

const _DmgNum = preload("res://scenes/effects/damage_number_display.gd")


static func resolve_fx_parent(unit: Node) -> Node:
	if unit != null and is_instance_valid(unit):
		var p: Node = unit.get_parent()
		while p != null:
			if p.name in ["Battlefield", "PlayerUnits", "EnemyUnits"]:
				return p
			p = p.get_parent()
		if unit.get_parent() != null:
			return unit.get_parent()
		# 动态获取 BattleManager 以避免循环依赖
		if unit != null and is_instance_valid(unit):
			var tree := unit.get_tree()
			if tree != null:
				var bm = tree.root.get_node_or_null("BattleManager")
				if bm != null and bm.get("battlefield") != null:
					return bm.battlefield
	return null


static func show_damage(world_pos: Vector2, amount: float, unit: Node = null, is_critical: bool = false, dmg_type: String = "") -> void:
	if amount <= 0.0:
		return
	var parent: Node = resolve_fx_parent(unit)
	if parent == null:
		return
	var dmg: int = int(roundf(amount))
	var crit: bool = is_critical or dmg >= 80
	# v6.4: 显式伤害类型优先；未指定时按暴击判定
	var final_type: String = dmg_type
	if final_type.is_empty():
		final_type = "critical" if crit else "normal"
	_DmgNum.create_damage_number(parent, world_pos, dmg, crit, final_type)


static func show_miss(world_pos: Vector2, unit: Node = null) -> void:
	var parent: Node = resolve_fx_parent(unit)
	if parent == null:
		return
	_DmgNum.create_miss(parent, world_pos)
