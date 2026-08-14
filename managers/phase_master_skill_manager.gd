extends Node
## ═══════════════════════════════════════════════════════════
##  相位师技能树管理器（v8.x 新增）
##  全局 autoload singleton，管理玩家在 4 分支技能树的解锁状态。
##
##  技能点来源：相位场 XP 升级（PhaseInstrumentManager 通知本 manager）
##  解锁时根据节点 unlocks 字段驱动子系统：
##    - phase_instrument → PhaseInstrumentManager.unlock_instrument
##    - unit_ability / unit_mechanism → 记录解锁状态供 UnitStatsTable 查询
##      （v8.5 unit_mechanism：定向爆破/瞄准狙击/闪电穿插/电子屏蔽/战术核武/护盾投射/定时标记）
##    - evolution → 记录已解锁的进化 era 供 CardEvolutionManager 查询
##    - affix → 通知 AffixManager 赋予对应 affix 池
##    - card_skill → 记录供 CardPeriodicSkillEngine 查询
##    - tactic → 记录供 TacticDetector 查询
##  v8.5 废弃：concept_weapon / special_card（旧存档兼容读取，无新节点）
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
## v7.x perf: get_active_effects() 合并结果缓存。
## 原实现每次部署单位都遍历所有已解锁节点 × SkillTree.get_skill() 的 2 次全树扫描
## （~30-40 节点 × 60 遍历 = ~2400 hash 查找/次部署）。缓存后仅在节点变化时重算。
var _effects_cache: Dictionary = {}
var _effects_cache_signature: String = ""


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


## 已解锁节点签名（供 UnitStats 缓存 key 使用）。
## 任何 unit_mechanism/unit_ability 节点解锁、或 reset_all，都会改变签名 →
## stats 缓存（battle_spawn_system._stats_cache / card_info_panel._cached_display_stats）
## 自动失效。避免"解锁前缓存的无机制 stats 在解锁后仍命中旧缓存"导致机制空转
## （典型症状：战术核武技能树已点开，但导弹发射井战斗不发射、情报也不显示）。
func get_unlocked_signature() -> String:
	return ":".join(_unlocked_nodes)


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
			# 以下类型仅记录解锁状态，由 is_content_unlocked(type, id) 查询，
			# 各子系统（战斗/进化/卡片技能引擎/战法检测器）自行读取：
			#   unit_ability    → 兵种特殊能力（暴击/吸血/穿甲等）
			#   unit_mechanism  → v8.5 兵种机制技能（定向爆破/瞄准狙击/闪电穿插/电子屏蔽/战术核武/护盾投射/定时标记）
			#   evolution       → 进化形态解锁
			#   card_skill      → v8.x 卡片定时技能（CardPeriodicSkillEngine 查询）
			#   tactic          → v8.x 战法（TacticDetector 查询）
			# 注：concept_weapon / special_card 类型在 v8.5 已废弃（原节点改为机制技能/数值），
			#     仅保留于旧存档兼容读取，不再有新节点使用。
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
##
## v7.x perf: 缓存结果。原实现每次部署单位都遍历所有已解锁节点 ×
## SkillTree.get_skill() 的 2 次全树扫描（~2400 hash 查找/次）。
## 现在按 unlocked_nodes 签名缓存，仅在节点变化（unlock_node/reset_all/load_state）时重算。
func get_active_effects() -> Dictionary:
	var sig: String = get_unlocked_signature()
	if sig == _effects_cache_signature and not _effects_cache.is_empty():
		return _effects_cache
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
	_effects_cache = merged
	_effects_cache_signature = sig
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
	# v7.x perf: 节点变化，失效效果缓存
	_effects_cache.clear()
	_effects_cache_signature = ""
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
	# v7.x perf: 节点变化，失效效果缓存
	_effects_cache.clear()
	_effects_cache_signature = ""
	# 注意：load_state 时不重新 _apply_unlocks（避免重复解锁相位仪/重复赋予 affix）
	# 已解锁状态直接恢复，子系统状态由各自存档负责


func reset_to_defaults() -> void:
	_unlocked_nodes.clear()
	_spent_points = 0
	_bonus_points = 0
	_phase_field_level = 1
	# v7.x perf: 节点变化，失效效果缓存
	_effects_cache.clear()
	_effects_cache_signature = ""
