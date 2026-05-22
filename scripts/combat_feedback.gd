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
	if BattleManager != null and BattleManager.battlefield != null:
		return BattleManager.battlefield
	return null


static func show_damage(world_pos: Vector2, amount: float, unit: Node = null, is_critical: bool = false) -> void:
	if amount <= 0.0:
		return
	var parent: Node = resolve_fx_parent(unit)
	if parent == null:
		return
	var dmg: int = int(roundf(amount))
	var crit: bool = is_critical or dmg >= 80
	var dmg_type: String = "critical" if crit else "normal"
	_DmgNum.create_damage_number(parent, world_pos, dmg, crit, dmg_type)


static func show_miss(world_pos: Vector2, unit: Node = null) -> void:
	var parent: Node = resolve_fx_parent(unit)
	if parent == null:
		return
	_DmgNum.create_miss(parent, world_pos)
