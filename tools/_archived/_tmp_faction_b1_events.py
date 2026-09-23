# -*- coding: utf-8 -*-
"""§4.6 faction_event_manager 死字段清理 + faction_panel 死显示块删除（势力批1）"""
import io

fails = []


def rep(path, old, new, tag):
    s = io.open(path, encoding='utf-8').read()
    if old not in s:
        fails.append(tag)
        return
    s = s.replace(old, new, 1)
    io.open(path, 'w', encoding='utf-8', newline='\n').write(s)


P = 'managers/faction/faction_event_manager.gd'
rep(P, 'signal bonus_event_active(faction_id: String, bonus: Dictionary)\n', '', 'signal')
rep(P, '''## 运行时状态
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
''', '''## 运行时状态（v6.22: loyalty/event_history/active_bonus_events 三死字段已删，
## save/load 对旧档同键静默忽略）
var active_event: Dictionary = {}
var battle_count_since_last: int = 0
''', 'vars_ready')

rep(P, '''	battle_count_since_last += 1
	_check_event_trigger()
	_tick_bonus_events()
''', '''	battle_count_since_last += 1
	_check_event_trigger()
''', 'tick_call')

rep(P, '''	var rewards: Dictionary = _calculate_rewards(choice)
	_apply_reputation_changes(choice)
	_apply_loyalty_changes(choice)
	# v26.11(A1.3): 结算补全——此前 rewards 里只有 reputation 真正入账，
	# skill_points / nano / exclusive_card / faction_bonus_duration 全部静默丢弃
	# （TODO_BACKLOG 高价值#3："事件结算不发 BONUS 奖励"）。声望走上方
	# _apply_reputation_changes（含对方势力 -15），其余字段在此发放。
	_grant_event_rewards(choice, rewards)
	event_history.append(active_event.duplicate(true))
''', '''	var rewards: Dictionary = _calculate_rewards(choice)
	_apply_reputation_changes(choice)
	# v26.11(A1.3): 结算补全——声望走 _apply_reputation_changes（含对方势力 -15），
	# 其余字段（nano/skill_points/exclusive_card）在此发放。
	# v6.22: faction_bonus_duration 临时加成链已随加成体系退役删除。
	_grant_event_rewards(choice, rewards)
''', 'resolve_calls')

rep(P, '''	# 势力临时加成：roll 一条限时加成挂到所选阵营（BONUS_EVENTS 池首次有了消费端）
	var bonus_dur: int = int(rewards.get("faction_bonus_duration", 0))
	if bonus_dur > 0:
		var bonus_fid: String = String(active_event.get("faction_a" if choice == "support_a" else "faction_b", ""))
		var bonus_name: String = _activate_random_timed_bonus(bonus_fid, bonus_dur)
		if not bonus_name.is_empty():
			granted.append("加成「%s」×%d场" % [bonus_name, bonus_dur])
	if not granted.is_empty():
''', '''	if not granted.is_empty():
''', 'bonus_branch')

rep(P, '''## roll 一条限时势力加成并激活（one_time 型跳过）；返回加成名
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


''', '', 'activate_bonus')

rep(P, '''## 应用忠诚度变化
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
''', '''## 保存状态（v6.22: loyalty/event_history/active_bonus_events 退役不再写；读档侧静默忽略旧键）
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
''', 'save_load_all')

Q = 'scenes/ui/faction_panel.gd'
rep(Q, '''func _append_active_faction_event(faction_mgr: Node) -> void:
	# —— 生效中的势力加成（事件奖励激活，按战斗场次递减）——
	var active_fid: String = String(faction_mgr.get("active_faction")) if "active_faction" in faction_mgr else ""
	if not active_fid.is_empty() and faction_mgr.has_method("get_active_faction_bonus_state"):
		var st: Dictionary = faction_mgr.get_active_faction_bonus_state(active_fid)
		if not st.is_empty():
			var bonus: Dictionary = st.get("bonus", {})
			var bonus_lbl := Label.new()
			bonus_lbl.text = "⚡ 生效加成：%s（剩 %d 场）" % [String(bonus.get("name", "?")), int(st.get("remaining", 0))]
			bonus_lbl.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
			bonus_lbl.add_theme_color_override("font_color", DT.COLOR_GOLD)
			faction_detail.add_child(bonus_lbl)
	# —— 待决策事件 ——
''', '''func _append_active_faction_event(faction_mgr: Node) -> void:
	# v6.22: 生效加成显示块已随势力临时加成体系退役删除。
	# —— 待决策事件 ——
''', 'panel_bonus_block')

rep(Q, '''	if rw.has("exclusive_card"):
		parts.append("专属卡")
	if rw.has("faction_bonus_duration"):
		parts.append("加成%d场" % int(rw["faction_bonus_duration"]))
	var summary: String = "，".join(parts) if not parts.is_empty() else "无直接奖励"
''', '''	if rw.has("exclusive_card"):
		parts.append("专属卡")
	var summary: String = "，".join(parts) if not parts.is_empty() else "无直接奖励"
''', 'panel_bonus_dur')

print("FAILS:", fails if fails else "none")
