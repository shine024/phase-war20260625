extends RefCounted
class_name CombatFeedback
## 战斗飘字：伤害 / MISS（格子战无 BattleHud 时由 BattleManager 信号驱动）

const _DmgNum = preload("res://scenes/effects/damage_number_display.gd")
# v32.0 B1-1: 极速推演旗标源（show_damage 读 ff_active 短路）
const BattleTimeState = preload("res://scripts/battle/battle_time_state.gd")

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
		# 节点已脱离场景树时（如即将销毁的敌人），get_tree() 会打印 C++ 警告并返回 null。
		# 用 is_inside_tree() 提前判定，避免无意义的警告刷屏。
		if not unit.is_inside_tree():
			return null
		var p: Node = unit.get_parent()
		while p != null:
			if p.name in ["Battlefield", "PlayerUnits", "EnemyUnits"]:
				return p
			p = p.get_parent()
		if unit.get_parent() != null:
			return unit.get_parent()
		# 动态获取 BattleManager 以避免循环依赖
		var tree := unit.get_tree()
		if tree != null:
			var bm = tree.root.get_node_or_null("BattleManager")
			if bm != null and bm.get("battlefield") != null:
				return bm.battlefield
	return null


static func show_damage(world_pos: Vector2, amount: float, unit: Node = null, is_critical: bool = false, dmg_type: String = "") -> void:
	if amount <= 0.0:
		return
	# v32.0 B1-1: 极速推演期间跳过伤害数字（8x 下不可读且刷屏）
	if BattleTimeState.ff_active:
		return
	# v6.15 打击感(P0)：重击（暴击）微顿帧——击杀顿帧同款时序重量给到暴击命中
	#（450ms 冷却/motion_reduce/慢动作守卫都在 BattleSpectacle 内；放节流前=
	# 合并窗口内的暴击也不丢拍）。
	if is_critical:
		BattleSpectacle.play_big_hit_hitstop()
	# v6.6: 节流——同一单位 80ms 内的伤害合并为一个数字。
	# 暴击/穿甲等高优先级类型不节流（视觉冲击感重要）。
	var crit_for_type: bool = is_critical
	var final_type_for_check: String = dmg_type
	if final_type_for_check.is_empty():
		crit_for_type = is_critical or amount >= 80.0
		final_type_for_check = "critical" if crit_for_type else "normal"
	# v27.12: 阵营双色（原 battle_hud.show_damage_popup 管线的 v13.1 语义迁入）——
	# 敌人掉血=我方输出(out/青)，我方掉血=敌方输出(in/红)。
	var side_for_check := _resolve_damage_side(unit)
	var is_priority: bool = crit_for_type or final_type_for_check in ["critical", "pierce", "heal", "shield", "salvage", "counter_break"]
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
			"side": side_for_check,
		}
		_do_show_damage(world_pos, amount, unit, is_critical, final_type_for_check, side_for_check)
		return
	# 无单位或高优先级类型：直接显示
	_do_show_damage(world_pos, amount, unit, is_critical, final_type_for_check, side_for_check)


## v27.12: 按受害方分组反推阵营色（与信号 is_player 语义一致，分组探测兜底）
static func _resolve_damage_side(unit: Node) -> String:
	if unit != null and is_instance_valid(unit):
		if unit.is_in_group("enemy_units"):
			return "out"
		elif unit.is_in_group("player_units"):
			return "in"
	return ""


## 实际创建伤害数字（原 show_damage 主体）
static func _do_show_damage(world_pos: Vector2, amount: float, unit: Node, is_critical: bool, final_type: String, side: String = "") -> void:
	var parent: Node = resolve_fx_parent(unit)
	if parent == null:
		return
	var dmg: int = int(roundf(amount))
	var crit: bool = is_critical or dmg >= 80
	# v6.4: 显式伤害类型优先；未指定时按暴击判定
	var type_str: String = final_type
	if type_str.is_empty():
		type_str = "critical" if crit else "normal"
	# v6.15 P1: 伤害数字相对分级——单次伤害 ≥15% 受害者 maxHP 即升 big_crit 重击样式
	#（DR 三级数字=相对量级；绝对 500 阈值在 era 后期数值膨胀下失效，保留为下限不动，
	# 见 damage_number_display.create_damage_number）。只升 normal/critical 两型，
	# 特殊语义类型(dot/heal/pierce/shield/salvage/counter_break)不动；big_crit 双侧
	# 金色不分阵营（与既有 >500 口径一致）。
	if (type_str == "normal" or type_str == "critical") and unit != null and is_instance_valid(unit):
		var st = unit.get("stats")
		var mv = st.get("max_hp") if st != null else null
		var mx: float = float(mv) if mv != null else 0.0
		if mx > 0.0 and amount >= mx * 0.15:
			type_str = "big_crit"
	_DmgNum.create_damage_number(parent, world_pos, dmg, crit, type_str, side)


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
	var side: String = String(entry.get("side", ""))
	_DmgNum.create_damage_number(parent, pos, dmg, is_critical, dmg_type, side)


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
	# v32.0 B1-1 对齐：极速推演期间弹字同样压制（与伤害数字同口径）
	if BattleTimeState.ff_active:
		return
	var parent: Node = resolve_fx_parent(unit)
	if parent == null:
		return
	# v6.15 P1: 机制弹出层——闪避从灰 MISS 升格为"闪避"银白大字（DR 招架弹字同语言）
	_DmgNum.create_callout(parent, world_pos, "闪避", "callout_dodge")


## v6.15 P1: 机制弹出层便捷口——按单位定位（自动解析战场父层+全局坐标）
static func show_callout_at(unit: Node, text: String, kind: String = "callout") -> void:
	if unit == null or not is_instance_valid(unit):
		return
	if BattleTimeState.ff_active:
		return
	var parent: Node = resolve_fx_parent(unit)
	if parent == null:
		return
	var pos: Vector2 = (unit as Node2D).global_position + Vector2(0, -34) if unit is Node2D else Vector2.ZERO
	_DmgNum.create_callout(parent, pos, text, kind)
