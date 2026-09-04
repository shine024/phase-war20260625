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
	# 平衡修复（2026-08-16 克制链审查）：无对空能力（attack_air=0）的直射单位跳过
	# 空中目标——伤害侧已禁止对空回退，索敌侧同步过滤，避免锁定飞机后干站。
	var stats = attacker.get("stats") as UnitStats
	var can_hit_air: bool = stats != null and stats.attack_air > 0.0
	# 单遍：找距离最近，同距（容差内）取最低 HP
	for e in enemies:
		if e == null or not is_instance_valid(e):
			continue
		if "hp" in e and float(e.hp) <= 0.0:
			continue
		# v20.15: 真隐身过滤（隐身且攻击方阵营无侦测源 → 不可选中）
		if not CardAbilityManager.is_unit_targetable(e, attacker):
			continue
		if not can_hit_air:
			var es = e.get("stats") as UnitStats
			if es != null and es.combat_kind == GameConstants.CombatKind.AIR:
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
## v8.x: 支持 SNIPER 优先锁定高价值目标（boss/master/command）
## P1 性能优化：单遍同时跟踪「高价值/克制类别/全体」三条候选线的最近者，
## 替代 filter 中间数组 + 二次 _nearest 遍历（每次索敌 2-3 次 Array/lambda 分配 → 0 分配）。
static func select_target_indirect(attacker: Node2D, enemies: Array) -> Node2D:
	if enemies.is_empty():
		return null
	var origin = attacker.global_position
	var valid = _filter_attackable(enemies, attacker)
	if valid.is_empty():
		return null
	var stats = attacker.get("stats") as UnitStats
	if stats == null:
		return _nearest(origin, valid)
	# v8: 支持行为 tag 覆盖（如 antitank 强制打装甲）
	var tags: Array = attacker.get("_behavior_tags_cached") if attacker.get("_behavior_tags_cached") != null else []
	var target_kind = _get_counter_priority(stats, tags)
	# v8.x: SNIPER_BOSS_PRIORITY（-2）优先高价值，普通克制 kind（>=0）优先克制类别
	var need_hv: bool = target_kind == CombatKindPriority.SNIPER_BOSS_PRIORITY
	var need_counter: bool = target_kind >= 0
	var best_all: Node2D = null
	var best_all_d2: float = INF
	var best_hv: Node2D = null
	var best_hv_d2: float = INF
	var best_counter: Node2D = null
	var best_counter_d2: float = INF
	for e in valid:
		var n2d := e as Node2D
		if n2d == null:
			continue
		var d2: float = origin.distance_squared_to(n2d.global_position)
		if d2 < best_all_d2:
			best_all_d2 = d2
			best_all = n2d
		if need_hv and _is_high_value_target(e) and d2 < best_hv_d2:
			best_hv_d2 = d2
			best_hv = n2d
		if need_counter:
			var s = e.get("stats") as UnitStats
			if s != null and s.combat_kind == target_kind and d2 < best_counter_d2:
				best_counter_d2 = d2
				best_counter = n2d
	if need_hv:
		return best_hv if best_hv != null else best_all
	if need_counter and best_counter != null:
		return best_counter
	return best_all

## 空射: 优先空中 → 无空中则克制目标 → 最近
## v8.x: 支持 SNIPER 优先锁定高价值目标
## P1 性能优化：单遍同时跟踪「SNIPER 高价值/空中/克制类别/全体」四条候选线的最近者，
## 替代 3 次 filter 中间数组 + 多次 _nearest 遍历（0 分配）。
## 行为等价：优先级 SNIPER 高价值 > 空中 > 克制类别 > 全体最近。
static func select_target_aerial(attacker: Node2D, enemies: Array) -> Node2D:
	if enemies.is_empty():
		return null
	var origin = attacker.global_position
	var valid = _filter_attackable(enemies, attacker)
	if valid.is_empty():
		return null
	# v8.x: SNIPER 标签优先锁定高价值目标（早于空中优先级，确保狙击手锁 Boss）
	var tags: Array = attacker.get("_behavior_tags_cached") if attacker.get("_behavior_tags_cached") != null else []
	var need_hv: bool = tags.has("sniper")
	var stats = attacker.get("stats") as UnitStats
	var target_kind: int = -1
	if stats != null:
		target_kind = _get_counter_priority(stats, tags)
	# sniper 的 SNIPER_BOSS_PRIORITY(-2) 不算克制类别（原版到此处 hv 恒空、countered 不执行）
	var need_counter: bool = stats != null and target_kind >= 0
	var best_all: Node2D = null
	var best_all_d2: float = INF
	var best_hv: Node2D = null
	var best_hv_d2: float = INF
	var best_air: Node2D = null
	var best_air_d2: float = INF
	var best_counter: Node2D = null
	var best_counter_d2: float = INF
	for e in valid:
		var n2d := e as Node2D
		if n2d == null:
			continue
		var d2: float = origin.distance_squared_to(n2d.global_position)
		if d2 < best_all_d2:
			best_all_d2 = d2
			best_all = n2d
		var s = e.get("stats") as UnitStats
		if need_hv and _is_high_value_target(e) and d2 < best_hv_d2:
			best_hv_d2 = d2
			best_hv = n2d
		if s != null:
			var kind: int = s.combat_kind
			if kind == GameConstants.CombatKind.AIR and d2 < best_air_d2:
				best_air_d2 = d2
				best_air = n2d
			if need_counter and kind == target_kind and d2 < best_counter_d2:
				best_counter_d2 = d2
				best_counter = n2d
	if need_hv and best_hv != null:
		return best_hv
	if best_air != null:
		return best_air
	if need_counter and best_counter != null:
		return best_counter
	return best_all

## 根据attacker的攻击维度确定克制优先目标类型
## v8: 支持 behavior tag 覆盖——antitank 强制锁定 ARMOR（让反坦克单位优先打装甲）
## v8.x: 扩展 sniper/stalker/engineer/ecm 等新兵种标签覆盖（优先级高于三维攻击值）
## （tags 参数可选，缺省时空数组，保持旧行为完全不变）
static func _get_counter_priority(stats: UnitStats, tags: Array = []) -> int:
	# v8.x: 新兵种标签覆盖（优先级最高，无视三维攻击值）
	# SNIPER 优先锁定高价值目标（Boss/master/command 标签单位在战斗中通常为 ARMOR/FORT 主类，
	# 此处返回 ARMOR 让狙击手优先打重甲/堡垒类，配合 TAG_COUNTER_RULES 的+50%伤害）
	if tags.has("sniper"):
		# 先尝试找 boss/master 标签目标——通过返回特殊值 -2 通知调用方走 boss 优先逻辑
		return CombatKindPriority.SNIPER_BOSS_PRIORITY
	# STALKER/STEALTH 优先攻击指挥/后勤（归入 LIGHT 主类的 support 子类）
	if tags.has("stalker") or tags.has("stealth"):
		return GameConstants.CombatKind.LIGHT
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

## v8.x: 兵种优先级特殊常量（负值区段，避免与 CombatKind 枚举 0-6 冲突）
const CombatKindPriority = {
	"SNIPER_BOSS_PRIORITY": -2,  # SNIPER 优先锁定 boss/master/command 标签
	"INVALID": -1,
}

## v8.x: 判断目标是否为高价值目标（boss/master/command 标签）
## 供 select_target_indirect/aerial 在 SNIPER_BOSS_PRIORITY 时调用
static func _is_high_value_target(e: Node) -> bool:
	if e == null or not is_instance_valid(e):
		return false
	# 检查 meta 标签（敌方 archetype 的 boss/elite 标记在 enemy_unit.gd 写入 meta）
	if e.has_meta("target_priority_tag"):
		var tag = String(e.get_meta("target_priority_tag", ""))
		if tag in ["boss", "master", "command"]:
			return true
	# 兼容：检查 stats.combat_kind 是否为高威胁类型（Boss 通常 ARMOR/FORT）
	var s = e.get("stats") as UnitStats
	if s != null:
		# 威胁值估算：HP > 500 视为高价值（Boss 普遍 HP 600+）
		if s.max_hp > 500.0:
			return true
	return false

## v26.13(D-2): 指令轮盘集火——attacker 带 _focus_target_ref（弱引用）且目标在候选中 → 必选。
## 候选已被上游按射程/可攻击过滤，集火目标不在其中（超射程/已死）时回退正常索敌，不会卡死。
static func _take_focus_target(attacker: Node2D, enemies: Array) -> Node2D:
	if attacker == null or not attacker.has_meta("_focus_target_ref"):
		return null
	var ref = attacker.get_meta("_focus_target_ref")
	if ref == null or not (ref is WeakRef):
		return null
	var t = ref.get_ref()
	if t == null or not is_instance_valid(t):
		return null
	for e in enemies:
		if e == t:
			return t
	return null

## 根据武器类型选目标
static func select_target(attacker: Node2D, enemies: Array, weapon_type: int) -> Node2D:
	# v26.13(D-2): 集火指令优先级最高（设计：索敌优先级 +∞）
	var _focus: Node2D = _take_focus_target(attacker, enemies)
	if _focus != null:
		return _focus
	# v8.x: 远程单位优先集火暴击标注目标（无标注或非远程则原样）
	enemies = _prioritize_crit_marked(attacker, enemies)
	match weapon_type:
		0: return select_target_direct(attacker, enemies)      # DIRECT
		1: return select_target_indirect(attacker, enemies)     # INDIRECT
		2: return select_target_aerial(attacker, enemies)      # AERIAL
		_: return select_target_direct(attacker, enemies)

## v20.15: attacker 参数用于真隐身过滤（隐身且攻击方阵营无侦测源 → 不可选中）；
## 传 null 时不过滤隐身（保持旧行为，供无攻击者上下文调用）。
static func _filter_attackable(enemies: Array, attacker: Node2D = null) -> Array:
	var result = []
	for e in enemies:
		if e == null or not is_instance_valid(e):
			continue
		if "hp" in e and float(e.hp) <= 0.0:
			continue
		if attacker != null and not CardAbilityManager.is_unit_targetable(e, attacker):
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

## v21 P1: gen_expansion_chamber 扩容弹舱——为本次攻击挑选"次级目标"（同时攻击目标数 +1）。
## 规则：除主目标外、在攻击者射程内、可选中（真隐身过滤）、存活，取最近者；
## 无候选返回 null（本次开火不追加）。与 select_target_direct 同套过滤口径。
static func select_expansion_target(attacker: Node2D, primary: Node2D, enemies: Array) -> Node2D:
	if enemies.is_empty() or attacker == null:
		return null
	var stats = attacker.get("stats") as UnitStats
	if stats == null:
		return null
	var origin: Vector2 = attacker.global_position
	var range_sq: float = 0.0
	if stats.attack_range > 0.0:
		range_sq = stats.attack_range * stats.attack_range
	var best: Node2D = null
	var best_d2: float = INF
	for e in enemies:
		if e == null or not is_instance_valid(e):
			continue
		if e == primary:
			continue
		if not CombatTargeting.is_attackable_combat_unit(e):
			continue
		if "hp" in e and float(e.hp) <= 0.0:
			continue
		# 真隐身过滤（与直射索敌同口径）
		if not CardAbilityManager.is_unit_targetable(e, attacker):
			continue
		var es = e.get("stats") as UnitStats
		# 无对空能力的单位不为次级目标锁飞机（与直射索敌同口径）
		if stats.attack_air <= 0.0 and es != null and es.combat_kind == GameConstants.CombatKind.AIR:
			continue
		var d2: float = origin.distance_squared_to((e as Node2D).global_position)
		if range_sq > 0.0 and d2 > range_sq:
			continue
		if d2 < best_d2:
			best_d2 = d2
			best = e as Node2D
	return best
