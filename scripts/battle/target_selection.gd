extends RefCounted
class_name TargetSelection
## v5.0: 三种选敌逻辑

enum TargetMode { DIRECT, INDIRECT, AERIAL }

## v8.x: 远程单位阈值——attack_range >= 此值视为远程，参与暴击标注集火优先
const REMOTE_RANGE_THRESHOLD: float = 250.0

## 直射: 距离最近 → 同距最低HP → 同距同HP最早部署
## 超出射程时向敌方基地方向移动（由调用方处理，此处只选目标）
## P1 性能优化：单遍手写循环找最优，避免 sort/filter/lambda 分配
static func select_target_direct(attacker: Node2D, enemies: Array) -> Node2D:
	if enemies.is_empty():
		return null
	var origin = attacker.global_position
	var best: Node2D = null
	var best_dist_sq: float = INF
	var best_hp: float = INF
	const SAME_DIST_TOL_SQ: float = 100.0  # 10^2
	# 单遍：找距离最近，同距（容差内）取最低 HP
	for e in enemies:
		if e == null or not is_instance_valid(e):
			continue
		if "hp" in e and float(e.hp) <= 0.0:
			continue
		var d_sq: float = origin.distance_squared_to(e.global_position)
		if d_sq < best_dist_sq - SAME_DIST_TOL_SQ:
			# 明显更近，直接选
			best = e
			best_dist_sq = d_sq
			best_hp = float(e.hp) if "hp" in e else INF
		elif absf(d_sq - best_dist_sq) <= SAME_DIST_TOL_SQ:
			# 同距（容差内），取最低 HP
			var e_hp: float = float(e.hp) if "hp" in e else INF
			if e_hp < best_hp:
				best = e
				best_hp = e_hp
				if d_sq < best_dist_sq:
					best_dist_sq = d_sq
	return best

## 曲射: 优先被克制类型 → 无克制则最近 → 同距最低HP
## 不移动
static func select_target_indirect(attacker: Node2D, enemies: Array) -> Node2D:
	if enemies.is_empty():
		return null
	var origin = attacker.global_position
	var valid = _filter_attackable(enemies)
	if valid.is_empty():
		return null
	var stats = attacker.get("stats") as UnitStats
	if stats == null:
		return _nearest(origin, valid)
	# v8: 支持行为 tag 覆盖（如 antitank 强制打装甲）
	var tags: Array = attacker.get("_behavior_tags_cached") if attacker.get("_behavior_tags_cached") != null else []
	var target_kind = _get_counter_priority(stats, tags)
	if target_kind >= 0:
		var countered = valid.filter(func(e):
			var s = e.get("stats") as UnitStats
			return s != null and s.combat_kind == target_kind
		)
		if not countered.is_empty():
			return _nearest(origin, countered)
	return _nearest(origin, valid)

## 空射: 优先空中 → 无空中则克制目标 → 最近
static func select_target_aerial(attacker: Node2D, enemies: Array) -> Node2D:
	if enemies.is_empty():
		return null
	var origin = attacker.global_position
	var valid = _filter_attackable(enemies)
	if valid.is_empty():
		return null
	# 优先空中
	var air_targets = valid.filter(func(e):
		var s = e.get("stats") as UnitStats
		return s != null and s.combat_kind == GameConstants.CombatKind.AIR
	)
	if not air_targets.is_empty():
		return _nearest(origin, air_targets)
	# 无空中则用克制优先
	var stats = attacker.get("stats") as UnitStats
	if stats != null:
		var tags: Array = attacker.get("_behavior_tags_cached") if attacker.get("_behavior_tags_cached") != null else []
		var target_kind = _get_counter_priority(stats, tags)
		if target_kind >= 0:
			var countered = valid.filter(func(e):
				var s = e.get("stats") as UnitStats
				return s != null and s.combat_kind == target_kind
			)
			if not countered.is_empty():
				return _nearest(origin, countered)
	return _nearest(origin, valid)

## 根据attacker的攻击维度确定克制优先目标类型
## v8: 支持 behavior tag 覆盖——antitank 强制锁定 ARMOR（让反坦克单位优先打装甲）
## （tags 参数可选，缺省时空数组，保持旧行为完全不变）
static func _get_counter_priority(stats: UnitStats, tags: Array = []) -> int:
	# v8: 行为 tag 覆盖（优先级最高，无视三维攻击值）
	if tags.has("antitank"):
		return GameConstants.CombatKind.ARMOR
	if stats.attack_light > stats.attack_armor and stats.attack_light > stats.attack_air:
		return GameConstants.CombatKind.LIGHT
	elif stats.attack_armor > stats.attack_light and stats.attack_armor > stats.attack_air:
		return GameConstants.CombatKind.ARMOR
	elif stats.attack_air > stats.attack_light and stats.attack_air > stats.attack_armor:
		return GameConstants.CombatKind.AIR
	return -1

## 根据武器类型选目标
static func select_target(attacker: Node2D, enemies: Array, weapon_type: int) -> Node2D:
	# v8.x: 远程单位优先集火暴击标注目标（无标注或非远程则原样）
	enemies = _prioritize_crit_marked(attacker, enemies)
	match weapon_type:
		0: return select_target_direct(attacker, enemies)      # DIRECT
		1: return select_target_indirect(attacker, enemies)     # INDIRECT
		2: return select_target_aerial(attacker, enemies)      # AERIAL
		_: return select_target_direct(attacker, enemies)

static func _filter_attackable(enemies: Array) -> Array:
	var result = []
	for e in enemies:
		if e == null or not is_instance_valid(e):
			continue
		if "hp" in e and float(e.hp) <= 0.0:
			continue
		result.append(e)
	return result

static func _nearest(origin: Vector2, targets: Array) -> Node2D:
	if targets.is_empty():
		return null
	var best = targets[0] as Node2D
	var best_d2 = origin.distance_squared_to(best.global_position)
	for i in range(1, targets.size()):
		var t = targets[i] as Node2D
		if t == null:
			continue
		var d2 = origin.distance_squared_to(t.global_position)
		if d2 < best_d2:
			best_d2 = d2
			best = t
	return best

## v8.x: 远程单位（attack_range >= REMOTE_RANGE_THRESHOLD）优先选暴击标注目标
## 候选中存在未过期 _crit_marked_until 的目标时，仅返回这些目标；否则原样返回
## 非远程单位不参与集火优先，原样返回
static func _prioritize_crit_marked(attacker: Node2D, enemies: Array) -> Array:
	var stats = attacker.get("stats") as UnitStats
	if stats == null or stats.attack_range < REMOTE_RANGE_THRESHOLD:
		return enemies
	var now: float = Time.get_ticks_msec() / 1000.0
	var marked: Array = []
	for e in enemies:
		if e == null or not is_instance_valid(e):
			continue
		if e.has_meta("_crit_marked_until") and now < float(e.get_meta("_crit_marked_until", 0.0)):
			marked.append(e)
	return marked if not marked.is_empty() else enemies
