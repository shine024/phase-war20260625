extends RefCounted
class_name TacticDetector
## ═══════════════════════════════════════════════════════════
##  v8.x 战法检测系统
##
##  每 1s 检测场上友军兵种组合，匹配 tactics.gd 中 18 个战法的激活条件。
##  满足条件即激活全局 stat_bonus，应用到全体友军。
##
##  接入点：battle_manager._process(delta) 中调用 update(delta)
##  依赖：
##    - Tactics（战法定义）
##    - PhaseMasterSkillManager（查询已解锁的 tactic 节点）
##    - CardPeriodicSkillEngine（查询已激活的卡片技能 family，用于战法条件）
##
##  差异更新：每次检测后比较新旧激活集，只对变化的单位应用/移除 buff
## ═══════════════════════════════════════════════════════════

const GC = preload("res://resources/game_constants.gd")
const TacticsDef = preload("res://data/tactics.gd")

const DETECT_INTERVAL: float = 1.0  # 检测间隔（秒）

var _timer: float = 0.0
var _player_units_node: Node = null
var _skill_manager: Node = null  # PhaseMasterSkillManager autoload
var _card_skill_engine: RefCounted = null  # CardPeriodicSkillEngine（RefCounted，非 Node）
## 当前已激活的战法 ID 集合（用于差异更新）
var _active_tactics: Dictionary = {}  # tactic_id → true
## 已应用的 stat_bonus 缓存（用于差异移除）
var _applied_bonus: Dictionary = {}  # tactic_id → stat_bonus dict

func setup(deps: Dictionary) -> void:
	_player_units_node = deps.get("player_units_node", null)
	_skill_manager = deps.get("skill_manager", null)
	_card_skill_engine = deps.get("card_skill_engine", null)

## 每帧调用（由 battle_manager._process 调用）
func update(delta: float) -> void:
	_timer += delta
	if _timer < DETECT_INTERVAL:
		return
	_timer = 0.0
	_detect_and_apply()

## 重置状态（战斗结束时调用）
func reset() -> void:
	_timer = 0.0
	_active_tactics.clear()
	_applied_bonus.clear()

## 获取当前已激活的战法列表（供 UI/调试）
func get_active_tactics() -> Array:
	return _active_tactics.keys()

# ─────────────────────────────────────────────
#  内部：检测与 Buff 应用
# ─────────────────────────────────────────────

func _detect_and_apply() -> void:
	if _player_units_node == null:
		return
	var allies: Array = _collect_player_units()
	if allies.is_empty():
		_clear_all_tactics()
		return
	# 收集场上统计
	var counts_by_kind: Dictionary = {}  # CombatKind → 数量
	var counts_by_tag: Dictionary = {}   # 标签 → 数量
	var distinct_kinds: int = 0
	var card_skill_families: Dictionary = {}  # family → 数量（P1 接入后填充）
	var ultimate_count: int = 0
	_analyze_allies(allies, counts_by_kind, counts_by_tag, distinct_kinds, card_skill_families, ultimate_count)

	# 检测每个战法
	var new_active: Dictionary = {}
	for tactic_id in TacticsDef.get_all_tactics():
		var def: Dictionary = TacticsDef.get_tactic(tactic_id)
		# 高级战法需技能树解锁
		if def.get("require_unlock", false) and not _is_tactic_unlocked(tactic_id):
			continue
		# 检测条件
		if _check_conditions(def.get("conditions", {}), counts_by_kind, counts_by_tag,
							 distinct_kinds, card_skill_families, ultimate_count, allies):
			new_active[tactic_id] = true

	# 差异更新：移除失效的，添加新激活的
	_apply_diff(new_active)

## 收集场上所有友军单位
func _collect_player_units() -> Array:
	var result: Array = []
	if _player_units_node == null:
		return result
	for u in _player_units_node.get_children():
		if u != null and is_instance_valid(u) and u.has_method("get"):
			if "hp" in u and float(u.hp) > 0.0:
				result.append(u)
	return result

## 分析友军阵容统计
func _analyze_allies(allies: Array, counts_by_kind: Dictionary, counts_by_tag: Dictionary,
					 distinct_kinds: int, card_skill_families: Dictionary, ultimate_count: int) -> void:
	var seen_kinds: Dictionary = {}
	for u in allies:
		# 按 CombatKind 计数
		var s = u.get("stats") as UnitStats
		if s != null:
			var ck: int = int(s.combat_kind)
			counts_by_kind[ck] = int(counts_by_kind.get(ck, 0)) + 1
			seen_kinds[ck] = true
		# 按标签计数：优先 _behavior_tags_cached，回退单位自身的 tags 属性
		# 注意：Node.get(property) 只接受 1 个参数，需用 in 操作符先检查属性存在性
		var tags_raw = null
		if "_behavior_tags_cached" in u:
			tags_raw = u.get("_behavior_tags_cached")
		if tags_raw == null and "tags" in u:
			tags_raw = u.get("tags")
		var tags: Array = tags_raw if tags_raw is Array else []
		for tag in tags:
			counts_by_tag[tag] = int(counts_by_tag.get(tag, 0)) + 1
	# distinct_kinds 是出参，Godot 无出参，用返回值替代（此处直接写入 dict）
	counts_by_kind["__distinct__"] = seen_kinds.size()
	# 卡片技能 family 由 _card_skill_engine 提供（P1 接入）
	if _card_skill_engine != null and _card_skill_engine.has_method("get_active_families"):
		var fams = _card_skill_engine.get_active_families()
		for fam in fams:
			card_skill_families[fam] = int(card_skill_families.get(fam, 0)) + 1
	# 终极技能数
	if _card_skill_engine != null and _card_skill_engine.has_method("get_ultimate_count"):
		# 用 dict 包装返回值（GDScript 无出参）
		ultimate_count = _card_skill_engine.get_ultimate_count()

## 检测战法条件是否满足
func _check_conditions(conditions: Dictionary, counts_by_kind: Dictionary, counts_by_tag: Dictionary,
					   distinct_kinds: int, card_skill_families: Dictionary, ultimate_count: int,
					   allies: Array) -> bool:
	# min_count_by_kind
	var min_kind: Dictionary = conditions.get("min_count_by_kind", {})
	for ck in min_kind:
		var need: int = int(min_kind[ck])
		var have: int = int(counts_by_kind.get(ck, 0))
		if have < need:
			return false
	# min_count_by_tag
	var min_tag: Dictionary = conditions.get("min_count_by_tag", {})
	for tag in min_tag:
		var need: int = int(min_tag[tag])
		var have: int = int(counts_by_tag.get(tag, 0))
		if have < need:
			return false
	# require_distinct_kinds
	var need_distinct: int = int(conditions.get("require_distinct_kinds", 0))
	if need_distinct > 0:
		var actual_distinct: int = int(counts_by_kind.get("__distinct__", 0))
		if actual_distinct < need_distinct:
			return false
	# min_card_skill_family
	var min_fam: Dictionary = conditions.get("min_card_skill_family", {})
	for fam in min_fam:
		var need: int = int(min_fam[fam])
		var have: int = int(card_skill_families.get(fam, 0))
		if have < need:
			return false
	# min_ultimate_skill_count
	var need_ult: int = int(conditions.get("min_ultimate_skill_count", 0))
	if need_ult > 0 and ultimate_count < need_ult:
		return false
	# min_backline_count（后排单位数：slot 索引靠玩家方）
	var need_backline: int = int(conditions.get("min_backline_count", 0))
	if need_backline > 0:
		var backline_count: int = 0
		for u in allies:
			var slot_idx: int = int(u.get_meta("card_grid_slot", -1))
			# 玩家方 slot 0-6，slot 0-2 视为后排（远离敌方）
			if slot_idx >= 0 and slot_idx <= 2:
				backline_count += 1
		if backline_count < need_backline:
			return false
	return true

## 是否已在技能树解锁某战法
func _is_tactic_unlocked(tactic_id: String) -> bool:
	if _skill_manager == null:
		return false
	if not _skill_manager.has_method("is_content_unlocked"):
		return false
	return _skill_manager.is_content_unlocked("tactic", tactic_id)

## 差异更新：应用新激活的战法，移除失效的
func _apply_diff(new_active: Dictionary) -> void:
	# 移除失效的战法
	var to_remove: Array = []
	for old_id in _active_tactics:
		if not new_active.has(old_id):
			to_remove.append(old_id)
	for tid in to_remove:
		_remove_tactic_buff(tid)
		_active_tactics.erase(tid)
	# 添加新激活的战法
	for new_id in new_active:
		if not _active_tactics.has(new_id):
			_apply_tactic_buff(new_id)
			_active_tactics[new_id] = true

## 应用单个战法的 Buff 到全体友军
func _apply_tactic_buff(tactic_id: String) -> void:
	var def: Dictionary = TacticsDef.get_tactic(tactic_id)
	var stat_bonus: Dictionary = def.get("effects", {}).get("stat_bonus", {})
	if stat_bonus.is_empty():
		return
	_applied_bonus[tactic_id] = stat_bonus.duplicate(true)

## 移除单个战法的 Buff
func _remove_tactic_buff(tactic_id: String) -> void:
	_applied_bonus.erase(tactic_id)

## 获取所有已激活战法的合并 stat_bonus（供 battle_spawn_system 应用到单位 stats）
func get_merged_stat_bonus() -> Dictionary:
	var merged: Dictionary = {}
	for tid in _applied_bonus:
		var bonus: Dictionary = _applied_bonus[tid]
		for k in bonus:
			var v: float = float(bonus[k])
			if not merged.has(k):
				merged[k] = 0.0
			merged[k] += v
	return merged

## 获取所有已激活战法的 special 标记（供 construct_unit 写入 meta）
func get_active_specials() -> Array:
	var specials: Array = []
	for tid in _active_tactics:
		var def: Dictionary = TacticsDef.get_tactic(tid)
		var sp: Array = def.get("effects", {}).get("special", [])
		for s in sp:
			if not specials.has(s):
				specials.append(s)
	return specials

## 清除所有战法（战斗结束）
func _clear_all_tactics() -> void:
	_active_tactics.clear()
	_applied_bonus.clear()
