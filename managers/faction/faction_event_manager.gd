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
	# v26.6: 断链补链——事件此前只发 SignalBus.faction_event_generated（全项目零监听），玩家永远看不到。
	# 按 manufacture/daily_task 先例在生成处直接播 toast（事件名 + 支持方核心奖励）
	var _rewards: Dictionary = template.get("rewards", {}).get("support_a", {})
	var _parts: Array[String] = []
	if _rewards.has("reputation"):
		_parts.append("声望+%d" % int(_rewards["reputation"]))
	if _rewards.has("skill_points"):
		_parts.append("技能点+%d" % int(_rewards["skill_points"]))
	if _rewards.has("nano") or _rewards.has("nanomaterial"):
		_parts.append("纳米+%d" % int(_rewards.get("nano", _rewards.get("nanomaterial", 0))))
	if _rewards.has("exclusive_card"):
		_parts.append("专属卡")
	var _summary: String = "，".join(_parts) if not _parts.is_empty() else "做出选择获取声望"
	SignalBus.show_toast.emit("⚔ 势力事件：%s（%s）" % [name_str, _summary])

## 玩家做出选择
func resolve_event(choice: String) -> Dictionary:
	if active_event.is_empty():
		return {}
	var rewards: Dictionary = _calculate_rewards(choice)
	_apply_reputation_changes(choice)
	_apply_loyalty_changes(choice)
	# v26.11(A1.3): 结算补全——此前 rewards 里只有 reputation 真正入账，
	# skill_points / nano / exclusive_card / faction_bonus_duration 全部静默丢弃
	# （TODO_BACKLOG 高价值#3："事件结算不发 BONUS 奖励"）。声望走上方
	# _apply_reputation_changes（含对方势力 -15），其余字段在此发放。
	_grant_event_rewards(choice, rewards)
	event_history.append(active_event.duplicate(true))
	var result := {"event_id": active_event.get("id", ""), "choice": choice, "rewards": rewards}
	event_resolved.emit(active_event.get("id", ""), choice, rewards)
	active_event = {}
	return result

## v26.11(A1.3): 发放事件奖励（声望已在主链应用，此处发其余字段并 toast 汇总）
func _grant_event_rewards(choice: String, rewards: Dictionary) -> void:
	var granted: Array[String] = []
	# 纳米材料（模板字段 nano / nanomaterial 两种拼写并存）
	var nano: int = int(rewards.get("nano", rewards.get("nanomaterial", 0)))
	if nano > 0:
		var brm: Node = get_node_or_null("/root/BasicResourceManager")
		if brm and brm.has_method("add_resource"):
			brm.add_resource("nano_materials", nano)
			granted.append("纳米+%d" % nano)
	# 技能点 → 相位师技能树（全局技能点唯一在册货币，starter 发放同路径）
	var sp: int = int(rewards.get("skill_points", 0))
	if sp > 0:
		var pmsm: Node = get_node_or_null("/root/PhaseMasterSkillManager")
		if pmsm and pmsm.has_method("add_bonus_points"):
			pmsm.add_bonus_points(sp)
			granted.append("技能点+%d" % sp)
	# 专属卡：所选阵营的专属卡池随机一张，实例化入背包
	if rewards.has("exclusive_card"):
		var chosen_fid: String = String(active_event.get("faction_a" if choice == "support_a" else "faction_b", ""))
		var card_name: String = _grant_exclusive_card(chosen_fid)
		if not card_name.is_empty():
			granted.append("专属卡「%s」" % card_name)
	# 势力临时加成：roll 一条限时加成挂到所选阵营（BONUS_EVENTS 池首次有了消费端）
	var bonus_dur: int = int(rewards.get("faction_bonus_duration", 0))
	if bonus_dur > 0:
		var bonus_fid: String = String(active_event.get("faction_a" if choice == "support_a" else "faction_b", ""))
		var bonus_name: String = _activate_random_timed_bonus(bonus_fid, bonus_dur)
		if not bonus_name.is_empty():
			granted.append("加成「%s」×%d场" % [bonus_name, bonus_dur])
	if not granted.is_empty():
		SignalBus.show_toast.emit("⚔ 事件结算：%s" % "，".join(granted))

## 随机发放一张势力专属卡（返回卡名；池空/失败返回空串）
func _grant_exclusive_card(faction_id: String) -> String:
	const FactionExclusiveCards = preload("res://data/faction_exclusive_cards.gd")
	var pool: Array = FactionExclusiveCards.get_exclusives_for_faction(faction_id)
	if pool.is_empty():
		return ""
	var cfg: Dictionary = pool[randi() % pool.size()]
	var card: CardResource = FactionExclusiveCards.create_card(cfg)
	if card == null:
		return ""
	var ir: Node = get_node_or_null("/root/InstanceRegistry")
	var inst: CardResource = card
	if ir != null and ir.has_method("create_instance_from_template"):
		inst = ir.create_instance_from_template(card)
	SignalBus.card_added_to_backpack.emit(inst)
	return String(cfg.get("name", cfg.get("id", "")))

## roll 一条限时势力加成并激活（one_time 型跳过）；返回加成名
func _activate_random_timed_bonus(faction_id: String, duration: int) -> String:
	var timed: Array = []
	for b in FactionWarEvents.get_bonus_events():
		if b.has("duration_battles"):
			timed.append(b)
	if timed.is_empty() or faction_id.is_empty():
		return ""
	var bonus: Dictionary = timed[randi() % timed.size()].duplicate(true)
	bonus["duration_battles"] = duration
	apply_bonus_event(faction_id, bonus)
	return String(bonus.get("name", ""))

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
		"loyalty": loyalty.duplicate(true),
		"event_history": event_history.duplicate(true),
		"active_bonus_events": active_bonus_events.duplicate(true),
		# v26.11(A1.5a): 补存未决事件——此前 active_event 不入档，读档即丢
		# （TODO_BACKLOG 观察项："读档丢未决事件"）。玩家在事件面板看到的
		# 待抉择事件自此跨会话保留；旧档无该 key = 空事件，行为不变。
		"active_event": active_event.duplicate(true),
	}

## 加载状态
func load_state(data: Dictionary) -> void:
	battle_count_since_last = int(data.get("battle_count_since_last", 0))
	if data.has("loyalty") and data["loyalty"] is Dictionary:
		# v7.x 修复: 与 save_state 对齐用深拷贝，防止读档后多个键共享内部引用互相污染
		loyalty = data["loyalty"].duplicate(true)
	else:
		_init_loyalty()
	if data.has("event_history") and data["event_history"] is Array:
		# v7.x 修复: event_history 元素是字典，浅拷贝会共享内部引用，改深拷贝对齐 save_state
		event_history = data["event_history"].duplicate(true)
	else:
		event_history = []
	if data.has("active_bonus_events") and data["active_bonus_events"] is Dictionary:
		active_bonus_events = data["active_bonus_events"].duplicate(true)
	else:
		active_bonus_events = {}
	# v26.11(A1.5a): 恢复未决事件（旧档无 key = 空事件；缺 template 的事件体视为损坏丢弃）
	active_event = {}
	if data.has("active_event") and data["active_event"] is Dictionary:
		var restored: Dictionary = data["active_event"]
		if not restored.is_empty() and restored.has("template") and restored.has("name"):
			active_event = restored.duplicate(true)

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

## v26.11(A1.3): 势力生效加成的完整状态 {bonus, remaining}（供 UI 展示剩余场次）
func get_bonus_state_for_faction(faction_id: String) -> Dictionary:
	if active_bonus_events.has(faction_id):
		return active_bonus_events[faction_id].duplicate(true)
	return {}
