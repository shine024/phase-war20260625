extends Node
class_name FactionEventManager

signal event_generated(event: Dictionary)
signal event_resolved(event_id: String, choice: String, rewards: Dictionary)

const FactionWarEvents = preload("res://data/faction_war_events.gd")
const CompanyDefinitions = preload("res://data/company_definitions.gd")

## 运行时状态（v6.22: loyalty/event_history/active_bonus_events 三死字段已删，
## save/load 对旧档同键静默忽略）
var active_event: Dictionary = {}
var battle_count_since_last: int = 0

## 每场战斗结束后检查
func on_battle_ended() -> void:
	battle_count_since_last += 1
	_check_event_trigger()

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
	# v26.11(A1.3): 结算补全——声望走 _apply_reputation_changes（含对方势力 -15），
	# 其余字段（nano/skill_points/exclusive_card）在此发放。
	# v6.22: faction_bonus_duration 临时加成链已随加成体系退役删除。
	_grant_event_rewards(choice, rewards)
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

## 保存状态（v6.22: loyalty/event_history/active_bonus_events 退役不再写；读档侧静默忽略旧键）
func save_state() -> Dictionary:
	return {
		"battle_count_since_last": battle_count_since_last,
		# v26.11(A1.5a): 补存未决事件——玩家在事件面板看到的待抉择事件跨会话保留；
		# 旧档无该 key = 空事件，行为不变。
		"active_event": active_event.duplicate(true),
	}

## 加载状态
func load_state(data: Dictionary) -> void:
	battle_count_since_last = int(data.get("battle_count_since_last", 0))
	# v6.22: 旧档 loyalty/event_history/active_bonus_events 键静默忽略（字段已退役）。
	# v26.11(A1.5a): 恢复未决事件（旧档无 key = 空事件；缺 template 的事件体视为损坏丢弃）
	active_event = {}
	if data.has("active_event") and data["active_event"] is Dictionary:
		var restored: Dictionary = data["active_event"]
		if not restored.is_empty() and restored.has("template") and restored.has("name"):
			active_event = restored.duplicate(true)
