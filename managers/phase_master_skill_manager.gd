extends Node
## ═══════════════════════════════════════════════════════════
##  相位师技能树管理器（v8.x 新增）
##  全局 autoload singleton，管理玩家在 4 分支技能树的解锁状态。
##
##  技能点来源：相位场 XP 升级（PhaseInstrumentManager 通知本 manager）
##  解锁时根据节点 unlocks 字段驱动子系统：
##    - phase_instrument → PhaseInstrumentManager.unlock_instrument
##    - unit_ability / unit_mechanism → 记录解锁状态供 UnitStatsTable 查询
##    - concept_weapon → 记录解锁状态供战斗系统查询
##    - special_card → 标记可获取（InstanceRegistry/BlueprintManager）
##    - evolution → 记录已解锁的进化 era 供 CardEvolutionManager 查询
##    - affix → 通知 AffixManager 赋予对应 affix 池
## ═══════════════════════════════════════════════════════════

signal node_unlocked(node_id: String)
signal points_changed(available: int)

const SkillTree = preload("res://data/phase_master_skill_tree.gd")

## 已解锁节点 ID 列表
var _unlocked_nodes: Array = []
## 已花费技能点
var _spent_points: int = 0
## 额外技能点（任务/事件奖励）
var _bonus_points: int = 0
## 当前相位场等级（驱动技能点上限，由 PhaseInstrumentManager 通知）
var _phase_field_level: int = 1


func _ready() -> void:
	# 监听相位场升级信号（技能点来源）
	# phase_field_level_up(old_level, new_level, unspent_points)
	if SignalBus.has_signal("phase_field_level_up"):
		SignalBus.phase_field_level_up.connect(_on_phase_field_leveled_up)


# ─────────────────────────────────────────────
#  查询接口
# ─────────────────────────────────────────────

## 节点是否已解锁
func is_unlocked(node_id: String) -> bool:
	return node_id in _unlocked_nodes


## 是否解锁了某类型的某内容（供战斗系统查询）
## 例：is_content_unlocked("unit_ability", "light_crit")
func is_content_unlocked(unlock_type: String, content_id: String) -> bool:
	for nid in _unlocked_nodes:
		var node: Dictionary = SkillTree.get_skill(nid)
		var unlocks: Array = node.get("unlocks", [])
		for u in unlocks:
			if u is Dictionary and u.get("type", "") == unlock_type and str(u.get("id", "")) == str(content_id):
				return true
	return false


## 是否解锁了某 era 的进化（era=-1 表示全时代）
func is_evolution_era_unlocked(era: int) -> bool:
	for nid in _unlocked_nodes:
		var node: Dictionary = SkillTree.get_skill(nid)
		var unlocks: Array = node.get("unlocks", [])
		for u in unlocks:
			if u is Dictionary and u.get("type", "") == "evolution":
				var node_era: int = int(u.get("era", -99))
				if node_era == -1 or node_era == era:
					return true
	return false


## 可用技能点
func get_available_points() -> int:
	var max_pts: int = SkillTree.max_skill_points_at_phase_field_level(_phase_field_level) + _bonus_points
	return maxi(0, max_pts - _spent_points)


## 获取已花费点数
func get_spent_points() -> int:
	return _spent_points


## 能否解锁节点
func can_unlock_node(node_id: String) -> Dictionary:
	var node: Dictionary = SkillTree.get_skill(node_id)
	if node.is_empty():
		return {"ok": false, "reason": "node_not_found"}
	if node_id in _unlocked_nodes:
		return {"ok": false, "reason": "already_unlocked"}
	# 前置节点检查
	var requires: Array = node.get("requires", [])
	for req in requires:
		if not (req in _unlocked_nodes):
			return {"ok": false, "reason": "requires_not_met", "missing": req}
	# 技能点检查
	var cost: int = int(node.get("cost", 1))
	if _spent_points + cost > SkillTree.max_skill_points_at_phase_field_level(_phase_field_level) + _bonus_points:
		return {"ok": false, "reason": "not_enough_points"}
	return {"ok": true, "cost": cost}


## 解锁节点（返回是否成功）
func unlock_node(node_id: String) -> bool:
	var can: Dictionary = can_unlock_node(node_id)
	if not bool(can.get("ok", false)):
		return false
	var cost: int = int(can.get("cost", 1))
	_unlocked_nodes.append(node_id)
	_spent_points += cost
	# 根据 unlocks 字段驱动子系统（延迟调用避免 autoload 顺序问题）
	call_deferred("_apply_unlocks", node_id)
	node_unlocked.emit(node_id)
	points_changed.emit(get_available_points())
	return true


## 应用节点的解锁内容到各子系统
func _apply_unlocks(node_id: String) -> void:
	var node: Dictionary = SkillTree.get_skill(node_id)
	var unlocks: Array = node.get("unlocks", [])
	for u in unlocks:
		if not (u is Dictionary):
			continue
		var u_type: String = u.get("type", "")
		match u_type:
			"phase_instrument":
				_unlock_phase_instrument(str(u.get("id", "")))
			"affix":
				_grant_affix_pool(u.get("pool", []))
			# unit_ability / unit_mechanism / concept_weapon / evolution / special_card
			# 仅记录解锁状态（is_content_unlocked / is_evolution_era_unlocked 查询），
			# 战斗系统/进化面板/卡牌系统各自查询，无需主动推送
			_:
				pass


## 解锁相位仪（复用 PhaseInstrumentManager.unlock_instrument 入口）
func _unlock_phase_instrument(instrument_id: String) -> void:
	var pim: Node = get_node_or_null("/root/PhaseInstrumentManager")
	if pim != null and pim.has_method("unlock_instrument"):
		pim.unlock_instrument(instrument_id)


## 赋予 affix 词条池（通知 AffixManager）
func _grant_affix_pool(pool: Array) -> void:
	var am: Node = get_node_or_null("/root/AffixManager")
	if am != null and am.has_method("grant_skill_tree_affix_pool"):
		am.grant_skill_tree_affix_pool(pool)


# ─────────────────────────────────────────────
#  战斗效果查询（供 UnitStatsTable / battle_spawn_system 调用）
# ─────────────────────────────────────────────

## 获取所有已解锁节点的合并战斗效果（stat_bonus 累加，special 收集）
func get_active_effects() -> Dictionary:
	var merged: Dictionary = {"stat_bonus": {}, "special": [], "experience_bonus": 0.0}
	for nid in _unlocked_nodes:
		var node: Dictionary = SkillTree.get_skill(nid)
		var fx: Dictionary = node.get("effects", {})
		# 合并 stat_bonus
		if fx.has("stat_bonus"):
			for k in fx["stat_bonus"]:
				var v: float = float(fx["stat_bonus"][k])
				if not merged["stat_bonus"].has(k):
					merged["stat_bonus"][k] = 0.0
				merged["stat_bonus"][k] += v
		# 经验加成
		if fx.has("experience_bonus"):
			merged["experience_bonus"] += float(fx["experience_bonus"])
		# 收集 special（conditional/aura 等）
		if fx.has("conditional") or fx.has("aura"):
			merged["special"].append(fx)
	return merged


# ─────────────────────────────────────────────
#  技能点管理
# ─────────────────────────────────────────────

## 相位场等级变化时更新技能点上限
func set_phase_field_level(level: int) -> void:
	_phase_field_level = level
	points_changed.emit(get_available_points())


## 相位场升级信号回调
## phase_field_level_up(old_level, new_level, unspent_points)
func _on_phase_field_leveled_up(_old_level: int, new_level: int, _unspent: int) -> void:
	set_phase_field_level(new_level)


## 添加额外技能点（任务/事件奖励）
func add_bonus_points(amount: int) -> void:
	_bonus_points += amount
	points_changed.emit(get_available_points())


## 重置整个技能树（返还所有点数）
func reset_all() -> int:
	var total: int = _spent_points
	_unlocked_nodes.clear()
	_spent_points = 0
	points_changed.emit(get_available_points())
	return total


# ─────────────────────────────────────────────
#  存档
# ─────────────────────────────────────────────

func save_state() -> Dictionary:
	return {
		"unlocked_nodes": _unlocked_nodes.duplicate(),
		"spent_points": _spent_points,
		"bonus_points": _bonus_points,
		"phase_field_level": _phase_field_level,
	}


func load_state(data: Dictionary) -> void:
	var un = data.get("unlocked_nodes", [])
	_unlocked_nodes = un.duplicate() if un is Array else []
	_spent_points = int(data.get("spent_points", 0))
	_bonus_points = int(data.get("bonus_points", 0))
	_phase_field_level = int(data.get("phase_field_level", 1))
	# 注意：load_state 时不重新 _apply_unlocks（避免重复解锁相位仪/重复赋予 affix）
	# 已解锁状态直接恢复，子系统状态由各自存档负责


func reset_to_defaults() -> void:
	_unlocked_nodes.clear()
	_spent_points = 0
	_bonus_points = 0
	_phase_field_level = 1
