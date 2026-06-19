extends RefCounted
class_name CombatFeedback
## 战斗飘字：伤害 / MISS（格子战无 BattleHud 时由 BattleManager 信号驱动）

const _DmgNum = preload("res://scenes/effects/damage_number_display.gd")

## v6.6: 伤害数字节流——同一单位 80ms 内的伤害合并显示一次（累加伤害值）。
## 避免密集交火（弹道批量命中）时同一单位瞬间迸溅大量伤害数字节点和 Tween。
const THROTTLE_WINDOW_MS: int = 80
const THROTTLE_MERGE_MAX: int = 99999  ## 合并上限（避免极高频时数字过大不直观）

## 节流表：unit_instance_id -> {"expire_ms": int, "amount": float, "is_critical": bool, "dmg_type": String, "pos": Vector2}
static var _throttle_map: Dictionary = {}


## 清空节流表（战斗结束时调用，避免跨战斗残留）
static func reset_throttle() -> void:
	_throttle_map.clear()


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
	# v6.6: 节流——同一单位 80ms 内的伤害合并为一个数字。
	# 暴击/穿甲等高优先级类型不节流（视觉冲击感重要）。
	var crit_for_type: bool = is_critical
	var final_type_for_check: String = dmg_type
	if final_type_for_check.is_empty():
		crit_for_type = is_critical or amount >= 80.0
		final_type_for_check = "critical" if crit_for_type else "normal"
	var is_priority: bool = crit_for_type or final_type_for_check in ["critical", "pierce", "heal", "shield"]
	if not is_priority and unit != null and is_instance_valid(unit):
		var uid: int = unit.get_instance_id()
		var now_ms: int = Time.get_ticks_msec()
		if _throttle_map.has(uid):
			var entry: Dictionary = _throttle_map[uid]
			var expire_ms: int = int(entry.get("expire_ms", 0))
			if now_ms < expire_ms:
				# 窗口内：累加伤害，刷新到期时间（滑动窗口），不立即显示
				var new_amount: float = float(entry.get("amount", 0.0)) + amount
				if new_amount > THROTTLE_MERGE_MAX:
					new_amount = THROTTLE_MERGE_MAX
				entry["amount"] = new_amount
				entry["expire_ms"] = now_ms + THROTTLE_WINDOW_MS
				# 取最新位置，确保合并数字出现在当前受击位置
				entry["pos"] = world_pos
				# 升级为暴击样式（若任一击暴击）
				if is_critical and not bool(entry.get("is_critical", false)):
					entry["is_critical"] = true
					entry["dmg_type"] = "critical"
				return
			else:
				# 窗口已过期：先 flush 上一轮的合并伤害
				_flush_throttle_entry(uid, entry)
		# 新窗口：登记并立即显示
		_throttle_map[uid] = {
			"expire_ms": now_ms + THROTTLE_WINDOW_MS,
			"amount": amount,
			"is_critical": is_critical,
			"dmg_type": final_type_for_check,
			"pos": world_pos,
		}
		_do_show_damage(world_pos, amount, unit, is_critical, final_type_for_check)
		return
	# 无单位或高优先级类型：直接显示
	_do_show_damage(world_pos, amount, unit, is_critical, final_type_for_check)


## 实际创建伤害数字（原 show_damage 主体）
static func _do_show_damage(world_pos: Vector2, amount: float, unit: Node, is_critical: bool, final_type: String) -> void:
	var parent: Node = resolve_fx_parent(unit)
	if parent == null:
		return
	var dmg: int = int(roundf(amount))
	var crit: bool = is_critical or dmg >= 80
	# v6.4: 显式伤害类型优先；未指定时按暴击判定
	var type_str: String = final_type
	if type_str.is_empty():
		type_str = "critical" if crit else "normal"
	_DmgNum.create_damage_number(parent, world_pos, dmg, crit, type_str)


## flush 一个节流表项：把累积的伤害作为合并数字显示出来
static func _flush_throttle_entry(uid: int, entry: Dictionary) -> void:
	_throttle_map.erase(uid)
	var amount: float = float(entry.get("amount", 0.0))
	if amount <= 0.0:
		return
	var pos: Vector2 = entry.get("pos", Vector2.ZERO) as Vector2
	var is_critical: bool = bool(entry.get("is_critical", false))
	var dmg_type: String = String(entry.get("dmg_type", "normal"))
	# 合并数字无具体 unit（已擦除），用一个兜底父节点
	# 优先尝试用 pos 附近的战场节点；fallback 到 /root/Main/BattleContainer/Battlefield
	var parent: Node = null
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		parent = tree.root.get_node_or_null("/root/Main/BattleContainer/Battlefield")
		if parent == null:
			parent = tree.root.get_node_or_null("/root/BattleManager")
	if parent == null:
		return
	var dmg: int = int(roundf(amount))
	_DmgNum.create_damage_number(parent, pos, dmg, is_critical, dmg_type)


## 定期清理过期但未被 flush 的节流表项（由 BattleManager 在战斗中周期性调用）
static func flush_expired_throttle() -> void:
	var now_ms: int = Time.get_ticks_msec()
	var expired: Array = []
	for uid in _throttle_map.keys():
		var entry: Dictionary = _throttle_map[uid]
		if now_ms >= int(entry.get("expire_ms", 0)):
			expired.append(uid)
	for uid in expired:
		var entry: Dictionary = _throttle_map[uid]
		_flush_throttle_entry(int(uid), entry)


static func show_miss(world_pos: Vector2, unit: Node = null) -> void:
	var parent: Node = resolve_fx_parent(unit)
	if parent == null:
		return
	_DmgNum.create_miss(parent, world_pos)
