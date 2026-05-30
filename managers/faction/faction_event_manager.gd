extends Node
class_name FactionEventManager

signal event_generated(event: Dictionary)
signal event_resolved(event_id: String, choice: String, rewards: Dictionary)
signal bonus_event_active(faction_id: String, bonus: Dictionary)

const FactionWarEvents = preload("res://data/faction_war_events.gd")
const CompanyDefinitions = preload("res://data/company_definitions.gd")

## 运行时状态
var active_event: Dictionary = {}
var active_bonus_events: Dictionary = {}
var event_history: Array = []
var battle_count_since_last: int = 0
var loyalty: Dictionary = {}

## 初始化忠诚度
func _ready() -> void:
	_init_loyalty()

func _init_loyalty() -> void:
	for c in CompanyDefinitions.get_all():
		loyalty[c.get("id", "")] = 50.0

## 每场战斗结束后检查
func on_battle_ended() -> void:
	battle_count_since_last += 1
	_check_event_trigger()
	_tick_bonus_events()

## 检查是否触发新事件
func _check_event_trigger() -> void:
	if not active_event.is_empty():
		return
	if battle_count_since_last < 5:
		return
	battle_count_since_last = 0
	_generate_event()

## 检查事件模板条件
func _check_conditions(template: Dictionary) -> bool:
	var conditions: Dictionary = template.get("conditions", {})
	var fsm: Node = get_node_or_null("/root/FactionSystemManager")
	if fsm == null:
		return false
	if conditions.has("min_level"):
		# 通过 LevelProgressManager 检查已通关关卡数
		var lpm: Node = get_node_or_null("/root/LevelProgressManager")
		if lpm == null:
			return false
		# level_stars 字典中星级 > 0 的关卡即为已通关
		var cleared_count: int = 0
		for lvl_key in lpm.level_stars:
			if int(lpm.level_stars[lvl_key]) > 0:
				cleared_count += 1
		if cleared_count < int(conditions["min_level"]):
			return false
	if conditions.has("min_faction_level"):
		var active_fid: String = fsm.get_active_faction()
		if active_fid.is_empty():
			return false
		if fsm.get_faction_level(active_fid) < int(conditions["min_faction_level"]):
			return false
	if conditions.has("min_reputation"):
		var active_fid: String = fsm.get_active_faction()
		if active_fid.is_empty():
			return false
		if fsm.get_faction_reputation(active_fid) < int(conditions["min_reputation"]):
			return false
	return true

## 生成新事件
func _generate_event() -> void:
	var pool: Array = []
	var total_weight: int = 0
	for tmpl in FactionWarEvents.get_event_templates():
		if _check_conditions(tmpl):
			pool.append(tmpl)
			total_weight += int(tmpl.get("weight", 10))
	if pool.is_empty():
		return
	# 加权随机
	var roll: int = randi() % total_weight
	var cumul: int = 0
	for tmpl in pool:
		cumul += int(tmpl.get("weight", 10))
		if roll < cumul:
			_instantiate_event(tmpl)
			return

## 实例化事件（填充势力A/B）
func _instantiate_event(template: Dictionary) -> void:
	var factions: Array = CompanyDefinitions.get_all()
	var idx_a: int = randi() % factions.size()
	var fid_a: String = factions[idx_a].get("id", "")
	# 选择不同势力B
	var candidates: Array = []
	for i in range(factions.size()):
		if i != idx_a:
			candidates.append(factions[i].get("id", ""))
	var fid_b: String = ""
	if not candidates.is_empty():
		fid_b = candidates[randi() % candidates.size()]
	# 获取当前关卡数
	var level_num: int = 1
	var lpm: Node = get_node_or_null("/root/LevelProgressManager")
	if lpm != null:
		level_num = lpm.get_max_unlocked_level()
	# 替换模板占位符
	var name_str: String = template.get("name", "")
	var desc_str: String = template.get("desc", "")
	var fsm: Node = get_node_or_null("/root/FactionSystemManager")
	if fsm != null:
		name_str = name_str.replace("{faction_a}", fsm.get_faction_display_name(fid_a))
		name_str = name_str.replace("{faction_b}", fsm.get_faction_display_name(fid_b))
		desc_str = desc_str.replace("{faction_a}", fsm.get_faction_display_name(fid_a))
		desc_str = desc_str.replace("{faction_b}", fsm.get_faction_display_name(fid_b))
	name_str = name_str.replace("{level}", str(level_num))
	desc_str = desc_str.replace("{level}", str(level_num))
	active_event = {
		"id": "evt_%d_%d" % [Time.get_unix_time_from_system(), randi() % 10000],
		"template": template,
		"faction_a": fid_a,
		"faction_b": fid_b,
		"name": name_str,
		"desc": desc_str,
		"generated_at": Time.get_unix_time_from_system(),
		"resolved": false,
	}
	event_generated.emit(active_event.duplicate(true))

## 玩家做出选择
func resolve_event(choice: String) -> Dictionary:
	if active_event.is_empty():
		return {}
	var rewards: Dictionary = _calculate_rewards(choice)
	_apply_reputation_changes(choice)
	_apply_loyalty_changes(choice)
	event_history.append(active_event.duplicate(true))
	var result := {"event_id": active_event.get("id", ""), "choice": choice, "rewards": rewards}
	event_resolved.emit(active_event.get("id", ""), choice, rewards)
	active_event = {}
	return result

## 计算奖励
func _calculate_rewards(choice: String) -> Dictionary:
	var tmpl_rewards: Dictionary = active_event.get("template", {}).get("rewards", {})
	return tmpl_rewards.get(choice, {}).duplicate(true)

## 应用声望变化
func _apply_reputation_changes(choice: String) -> void:
	var fsm: Node = get_node_or_null("/root/FactionSystemManager")
	if fsm == null:
		return
	var rewards: Dictionary = _calculate_rewards(choice)
	var fid_a: String = active_event.get("faction_a", "")
	var fid_b: String = active_event.get("faction_b", "")
	var rep_amount: int = int(rewards.get("reputation", 20))
	if choice == "support_a":
		if fsm.has_method("add_faction_reputation"):
			fsm.add_faction_reputation(fid_a, rep_amount)
			fsm.add_faction_reputation(fid_b, -15)
	elif choice == "support_b":
		if fsm.has_method("add_faction_reputation"):
			fsm.add_faction_reputation(fid_b, rep_amount)
			fsm.add_faction_reputation(fid_a, -15)
	else:
		# neutral
		if fsm.has_method("add_faction_reputation"):
			fsm.add_faction_reputation(fid_a, -5)
			fsm.add_faction_reputation(fid_b, -5)

## 应用忠诚度变化
func _apply_loyalty_changes(choice: String) -> void:
	var fid_a: String = active_event.get("faction_a", "")
	var fid_b: String = active_event.get("faction_b", "")
	if choice == "support_a":
		loyalty[fid_a] = clampf(loyalty.get(fid_a, 50.0) + 10.0, 0.0, 100.0)
		loyalty[fid_b] = clampf(loyalty.get(fid_b, 50.0) - 5.0, 0.0, 100.0)
	elif choice == "support_b":
		loyalty[fid_b] = clampf(loyalty.get(fid_b, 50.0) + 10.0, 0.0, 100.0)
		loyalty[fid_a] = clampf(loyalty.get(fid_a, 50.0) - 5.0, 0.0, 100.0)

## 递减加成事件
func _tick_bonus_events() -> void:
	var to_remove: Array = []
	for fid in active_bonus_events:
		var data: Dictionary = active_bonus_events[fid]
		data["remaining"] = int(data.get("remaining", 0)) - 1
		if data.get("remaining", 0) <= 0:
			to_remove.append(fid)
	for fid in to_remove:
		active_bonus_events.erase(fid)

## 获取忠诚度
func get_loyalty(faction_id: String) -> float:
	return loyalty.get(faction_id, 50.0)

## 获取事件历史
func get_event_history() -> Array:
	return event_history.duplicate(true)

## 保存状态
func save_state() -> Dictionary:
	return {
		"battle_count_since_last": battle_count_since_last,
		"loyalty": loyalty.duplicate(),
		"event_history": event_history.duplicate(true),
		"active_bonus_events": active_bonus_events.duplicate(true),
	}

## 加载状态
func load_state(data: Dictionary) -> void:
	battle_count_since_last = int(data.get("battle_count_since_last", 0))
	if data.has("loyalty") and data["loyalty"] is Dictionary:
		loyalty = data["loyalty"].duplicate()
	else:
		_init_loyalty()
	if data.has("event_history") and data["event_history"] is Array:
		event_history = data["event_history"].duplicate()
	else:
		event_history = []
	if data.has("active_bonus_events") and data["active_bonus_events"] is Dictionary:
		active_bonus_events = data["active_bonus_events"].duplicate(true)
	else:
		active_bonus_events = {}
	active_event = {}

## 激活加成事件
func apply_bonus_event(faction_id: String, bonus: Dictionary) -> void:
	var duration: int = int(bonus.get("duration_battles", 3))
	active_bonus_events[faction_id] = {
		"bonus": bonus.duplicate(true),
		"remaining": duration,
	}
	bonus_event_active.emit(faction_id, bonus)

## 获取势力活跃加成
func get_active_bonus_for_faction(faction_id: String) -> Dictionary:
	if active_bonus_events.has(faction_id):
		return active_bonus_events[faction_id].get("bonus", {})
	return {}
