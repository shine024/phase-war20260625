extends Node
## 委托任务：自由接取，推进目标后完成得奖励
##
## 支持的 objective_type:
##   win_battles      — 胜利N场（内部追踪）
##   kill_enemies     — 击毁N个敌人（内部追踪）
##   clear_level      — 通过第N关（内部追踪）
##   collect_fragments — 已废弃，等同 collect_cards（兼容旧存档任务）
##   attack_faction   — 击败指定相位师（内部追踪）
##   defend_faction   — 在指定势力关卡击败相位师（内部追踪）
##   enhance           — 完成N次强化（内部追踪）
##   collect_cards     — 拥有N张卡片（实时查询背包）
##   research_law      — 研究N个法则（内部追踪）
##   reach_reputation  — 声望达到N（实时查询 FactionSystemManager）
##   buy_items         — 购买N次物品（内部追踪）
##   quick_win         — N秒内胜利（内部追踪最快记录）
##   perfect_battle    — 获得N次三星胜利（内部追踪）
##   survive_waves     — 存活N个波次（内部追踪最高波次）

const QuestDefs = preload("res://data/quest_definitions.gd")
const LevelInfoClass = preload("res://data/level_information.gd")
const CardDropGrantsScript = preload("res://scripts/card_drop_grants.gd")

signal quest_accepted(quest_id: String)
signal quest_progress_changed(quest_id: String)
signal quest_completed(quest_id: String, rewards: Dictionary)
signal quest_phase_master_defeated(quest_id: String, master_name: String)

# 已接任务：quest_id -> { "progress": {...}, "cleared_levels": [...], "defeated_masters": [...] }
var _accepted: Dictionary = {}
# 已完成过的任务 id
var _completed_ids: Array = []

const MAX_ACCEPTED: int = 5

## 需要外部通知的事件方法：合成、强化、研究法则、购买物品、战斗时间/星级

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if SignalBus:
		if not SignalBus.battle_ended.is_connected(_on_battle_ended):
			SignalBus.battle_ended.connect(_on_battle_ended)
		if SignalBus.has_signal("unit_died"):
			if not SignalBus.unit_died.is_connected(_on_unit_died):
				SignalBus.unit_died.connect(_on_unit_died)

# ──────────────── 信号处理器 ────────────────

func _on_battle_ended(player_won: bool) -> void:
	if player_won:
		var gm = get_node_or_null("/root/GameManager")
		var level: int = gm.current_level if gm and gm.get("current_level") != null else 1
		_notify_battle_won(level)

func _on_unit_died(_unit: Node, is_player: bool) -> void:
	if is_player:
		return
	_notify_enemy_killed()


func _on_enhancement_completed(success: bool, _card_id: String, _stats: Dictionary, _message: String) -> void:
	if not success:
		return
	for qid in _accepted.keys():
		var def: Dictionary = QuestDefs.get_by_id(qid)
		if def.get("objective_type", "") == "enhance":
			_inc_progress(qid, "enhance_count")
			_try_complete(qid)

# ──────────────── 外部通知接口 ────────────────

## 研究法则后调用
func notify_law_researched(_law_id: String) -> void:
	for qid in _accepted.keys():
		var def: Dictionary = QuestDefs.get_by_id(qid)
		if def.get("objective_type", "") == "research_law":
			_inc_progress(qid, "research_count")
			_try_complete(qid)

## 商店购买后调用
func notify_item_bought() -> void:
	for qid in _accepted.keys():
		var def: Dictionary = QuestDefs.get_by_id(qid)
		if def.get("objective_type", "") == "buy_items":
			_inc_progress(qid, "buy_count")
			_try_complete(qid)

## 战斗结束时由 battle_manager 调用，传入战斗时长和星级
func notify_battle_result(battle_time_sec: float, victory_stars: int, survived_waves: int) -> void:
	for qid in _accepted.keys():
		var def: Dictionary = QuestDefs.get_by_id(qid)
		var otype: String = def.get("objective_type", "")
		var target: Variant = def.get("target", 0)
		if otype == "quick_win":
			# 记录最快通关时间
			var best: float = float(_get_progress(qid, "best_time"))
			if best <= 0.0 or battle_time_sec < best:
				_set_progress(qid, "best_time", battle_time_sec)
			quest_progress_changed.emit(qid)
			_try_complete(qid)
		elif otype == "perfect_battle" and victory_stars >= 3:
			_inc_progress(qid, "perfect_count")
			_try_complete(qid)
		elif otype == "survive_waves":
			var best_waves: int = _get_progress(qid, "max_waves")
			if survived_waves > best_waves:
				_set_progress(qid, "max_waves", survived_waves)
			quest_progress_changed.emit(qid)
			_try_complete(qid)

## 碎片增加时调用
func notify_fragments_changed() -> void:
	for qid in _accepted.keys():
		_try_complete(qid)
		if not _accepted.has(qid):
			quest_progress_changed.emit(qid)

## 通知任务系统：击败了相位师
func notify_phase_master_defeated(master_name: String) -> void:
	for qid in _accepted.keys():
		var data: Dictionary = _accepted[qid]
		var def: Dictionary = QuestDefs.get_by_id(qid)
		if def.is_empty():
			continue
		var otype: String = def.get("objective_type", "")

		if otype == "attack_faction":
			var target_attack: Dictionary = def.get("target", {})
			var target_master: String = target_attack.get("target_master", "")
			if target_master == master_name:
				if not data.has("defeated_masters"):
					data["defeated_masters"] = []
				if master_name not in data["defeated_masters"]:
					data["defeated_masters"].append(master_name)
				quest_progress_changed.emit(qid)
				_try_complete(qid)
				quest_phase_master_defeated.emit(qid, master_name)

		elif otype == "defend_faction":
			var target_defend: Dictionary = def.get("target", {})
			var defend_faction: String = target_defend.get("defend_faction", "")

			var LevelInfo = LevelInfoClass.new()
			var gm = get_node_or_null("/root/GameManager")
			var current_level: int = gm.get("current_level") if gm else 1
			var current_faction: String = LevelInfo.get_level_faction(current_level)

			if current_faction == defend_faction:
				if not data.has("defeated_masters"):
					data["defeated_masters"] = []
				if master_name not in data["defeated_masters"]:
					data["defeated_masters"].append(master_name)
				quest_progress_changed.emit(qid)
				_try_complete(qid)
				quest_phase_master_defeated.emit(qid, master_name)

# ──────────────── 内部进度追踪 ────────────────

func _notify_battle_won(level: int) -> void:
	for qid in _accepted.keys():
		var data: Dictionary = _accepted[qid]
		_ensure_progress(data)
		if not data.has("cleared_levels"):
			data["cleared_levels"] = []
		_inc_progress(qid, "win_battles")
		if level not in data["cleared_levels"]:
			data["cleared_levels"].append(level)
		quest_progress_changed.emit(qid)
		_try_complete(qid)

func _notify_enemy_killed() -> void:
	for qid in _accepted.keys():
		_inc_progress(qid, "kill_enemies")
		_try_complete(qid)

func _ensure_progress(data: Dictionary) -> void:
	if not data.has("progress"):
		data["progress"] = {}

func _get_progress(qid: String, key: String) -> int:
	var data: Dictionary = _accepted.get(qid, {})
	return int(data.get("progress", {}).get(key, 0))

func _set_progress(qid: String, key: String, value: Variant) -> void:
	var data: Dictionary = _accepted.get(qid, {})
	if not data.has("progress"):
		data["progress"] = {}
	data["progress"][key] = value

func _inc_progress(qid: String, key: String, amount: int = 1) -> void:
	var val: int = _get_progress(qid, key) + amount
	_set_progress(qid, key, val)

# ──────────────── 公共API ────────────────

func accept_quest(quest_id: String) -> bool:
	if quest_id.is_empty():
		return false
	if _accepted.size() >= MAX_ACCEPTED:
		return false
	if _accepted.has(quest_id):
		return true
	var def: Dictionary = QuestDefs.get_by_id(quest_id)
	if def.is_empty():
		return false
	_accepted[quest_id] = {"progress": {}, "cleared_levels": []}
	quest_accepted.emit(quest_id)
	quest_progress_changed.emit(quest_id)
	return true

func abandon_quest(quest_id: String) -> void:
	_accepted.erase(quest_id)
	quest_progress_changed.emit(quest_id)

func get_accepted_quest_ids() -> Array:
	return _accepted.keys()

func get_quest_progress(quest_id: String) -> Dictionary:
	return _accepted.get(quest_id, {}).duplicate(true)

func is_accepted(quest_id: String) -> bool:
	return _accepted.has(quest_id)

func is_completed_ever(quest_id: String) -> bool:
	return quest_id in _completed_ids

func get_target_value_for_quest(quest_id: String) -> Variant:
	var def: Dictionary = QuestDefs.get_by_id(quest_id)
	return def.get("target", 0)

# ──────────────── 进度查询（UI 用） ────────────────

func get_current_progress_for_quest(quest_id: String) -> int:
	var def: Dictionary = QuestDefs.get_by_id(quest_id)
	if def.is_empty():
		return 0
	var data: Dictionary = _accepted.get(quest_id, {})
	var progress: Dictionary = data.get("progress", {})
	var otype: String = def.get("objective_type", "")
	var target_val: Variant = def.get("target", 0)

	if otype == "win_battles":
		return int(progress.get("win_battles", 0))
	if otype == "kill_enemies":
		return int(progress.get("kill_enemies", 0))
	if otype == "clear_level":
		var level: int = int(target_val)
		var cleared: Array = data.get("cleared_levels", [])
		return 1 if level in cleared else 0
	if otype == "collect_fragments":
		return mini(_count_player_cards(), 100)
	if otype == "enhance":
		return int(progress.get("enhance_count", 0))
	if otype == "collect_cards":
		return _count_player_cards()
	if otype == "research_law":
		return int(progress.get("research_count", 0))
	if otype == "reach_reputation":
		return _get_max_reputation()
	if otype == "buy_items":
		return int(progress.get("buy_count", 0))
	if otype == "quick_win":
		var best: float = float(progress.get("best_time", 0.0))
		if best <= 0.0:
			return 0
		return 1  # 已记录过时间，用 is_quest_done 判断是否达标
	if otype == "perfect_battle":
		return int(progress.get("perfect_count", 0))
	if otype == "survive_waves":
		return int(progress.get("max_waves", 0))
	if otype in ["attack_faction", "defend_faction"]:
		return get_quest_progress_for_mission(quest_id)
	return 0

## 获取目标值（用于UI显示）
func get_target_for_display(quest_id: String) -> int:
	var def: Dictionary = QuestDefs.get_by_id(quest_id)
	if def.is_empty():
		return 0
	var otype: String = def.get("objective_type", "")
	var target: Variant = def.get("target", 0)

	if otype == "collect_cards" or otype == "reach_reputation" \
		or otype == "quick_win" or otype == "survive_waves":
		return int(target)
	# win_battles, kill_enemies, enhance, buy_items, perfect_battle
	if target is int:
		return int(target)
	return 0

# ──────────────── 完成判定 ────────────────

func is_quest_done(quest_id: String) -> bool:
	var def: Dictionary = QuestDefs.get_by_id(quest_id)
	if def.is_empty():
		return false
	var otype: String = def.get("objective_type", "")
	var target_val: Variant = def.get("target", 0)
	var data: Dictionary = _accepted.get(quest_id, {})
	var progress: Dictionary = data.get("progress", {})

	if otype == "win_battles":
		return int(progress.get("win_battles", 0)) >= int(target_val)
	if otype == "kill_enemies":
		return int(progress.get("kill_enemies", 0)) >= int(target_val)
	if otype == "clear_level":
		return int(target_val) in data.get("cleared_levels", [])
	if otype == "attack_faction":
		var t: Dictionary = def.get("target", {})
		return t.get("target_master", "") in data.get("defeated_masters", [])
	if otype == "defend_faction":
		var t: Dictionary = def.get("target", {})
		var defend_faction: String = t.get("defend_faction", "")
		var LevelInfo = LevelInfoClass.new()
		var gm = get_node_or_null("/root/GameManager")
		var current_level: int = gm.get("current_level") if gm else 1
		var current_faction: String = LevelInfo.get_level_faction(current_level)
		if current_faction != defend_faction:
			return false
		return data.get("defeated_masters", []).size() > 0
	if otype == "collect_fragments":
		var need: int = int(target_val) if target_val is int else 1
		return _count_player_cards() >= need
	if otype == "enhance":
		return int(progress.get("enhance_count", 0)) >= int(target_val)
	if otype == "collect_cards":
		return _count_player_cards() >= int(target_val)
	if otype == "research_law":
		return int(progress.get("research_count", 0)) >= int(target_val)
	if otype == "reach_reputation":
		return _get_max_reputation() >= int(target_val)
	if otype == "buy_items":
		return int(progress.get("buy_count", 0)) >= int(target_val)
	if otype == "quick_win":
		var best: float = float(progress.get("best_time", 0.0))
		return best > 0.0 and best <= float(target_val)
	if otype == "perfect_battle":
		return int(progress.get("perfect_count", 0)) >= int(target_val)
	if otype == "survive_waves":
		return int(progress.get("max_waves", 0)) >= int(target_val)
	return false

# ──────────────── 实时查询辅助 ────────────────

func _count_player_cards() -> int:
	var bm = get_node_or_null("/root/BlueprintManager")
	if bm and bm.has_method("get_unlocked_blueprint_ids"):
		return bm.get_unlocked_blueprint_ids().size()
	if bm and bm.has_method("get_all_blueprint_ids"):
		return bm.get_all_blueprint_ids().size()
	return 0

func _get_max_reputation() -> int:
	var fsm = get_node_or_null("/root/FactionSystemManager")
	if fsm and fsm.has_method("get_all_factions_info"):
		var all_info: Array = fsm.get_all_factions_info()
		var max_rep: int = 0
		for info in all_info:
			if info is Dictionary:
				max_rep = maxi(max_rep, int(info.get("reputation", 0)))
		return max_rep
	return 0

# ──────────────── 任务完成与奖励 ────────────────

func _try_complete(quest_id: String) -> void:
	if not is_quest_done(quest_id):
		return
	var def: Dictionary = QuestDefs.get_by_id(quest_id)
	var rewards: Dictionary = def.get("rewards", {})
	_grant_rewards(rewards)
	_accepted.erase(quest_id)
	if quest_id not in _completed_ids:
		_completed_ids.append(quest_id)
	quest_completed.emit(quest_id, rewards)
	quest_progress_changed.emit(quest_id)

func _grant_rewards(rewards: Dictionary) -> void:
	var bm = get_node_or_null("/root/BlueprintManager")
	if rewards.has("blueprint_fragments") and rewards["blueprint_fragments"] is Dictionary and bm != null:
		for card_id in rewards["blueprint_fragments"]:
			var n: int = int(rewards["blueprint_fragments"][card_id])
			CardDropGrantsScript.grant_enemy_style_card(bm, String(card_id), 0, maxi(1, n))
	if bm != null:
		if rewards.has("nano_materials") and bm.has_method("add_nano_materials"):
			bm.add_nano_materials(int(rewards["nano_materials"]))
		if rewards.has("unlock_blueprint") and bm.has_method("unlock_blueprint"):
			bm.unlock_blueprint(str(rewards["unlock_blueprint"]))
	var fsm = get_node_or_null("/root/FactionSystemManager")
	if rewards.has("company_rep") and rewards["company_rep"] is Dictionary:
		for company_id in rewards["company_rep"]:
			var delta: int = int(rewards["company_rep"][company_id])
			var cid: String = String(company_id)
			if fsm != null and fsm.has_method("add_faction_reputation"):
				fsm.add_faction_reputation(cid, delta)
	if fsm != null:
		var faction_reward: Dictionary = {}
		if rewards.has("faction_reputation") and rewards["faction_reputation"] is Dictionary:
			faction_reward = rewards["faction_reputation"]
		elif rewards.has("faction_rep") and rewards["faction_rep"] is Dictionary:
			faction_reward = rewards["faction_rep"]
		for faction_id in faction_reward:
			var delta: int = int(faction_reward[faction_id])
			fsm.add_faction_reputation(String(faction_id), delta)

# ──────────────── 存档 ────────────────

func save_state() -> Dictionary:
	return {
		"accepted": _accepted.duplicate(true),
		"completed_ids": _completed_ids.duplicate(),
	}

func load_state(data: Dictionary) -> void:
	if data.has("accepted") and data["accepted"] is Dictionary:
		_accepted = (data["accepted"] as Dictionary).duplicate(true)
	if data.has("completed_ids") and data["completed_ids"] is Array:
		_completed_ids = (data["completed_ids"] as Array).duplicate()

# ──────────────── 进攻/防守任务辅助 ────────────────

func get_quest_progress_for_mission(quest_id: String) -> int:
	var def: Dictionary = QuestDefs.get_by_id(quest_id)
	if def.is_empty():
		return 0
	var data: Dictionary = _accepted.get(quest_id, {})
	var otype: String = def.get("objective_type", "")

	if otype == "attack_faction":
		var t: Dictionary = def.get("target", {})
		var target_master: String = t.get("target_master", "")
		var defeated: Array = data.get("defeated_masters", [])
		return 1 if target_master in defeated else 0

	if otype == "defend_faction":
		var t: Dictionary = def.get("target", {})
		var defend_faction: String = t.get("defend_faction", "")
		var LevelInfo = LevelInfoClass.new()
		var gm = get_node_or_null("/root/GameManager")
		var current_level: int = gm.get("current_level") if gm else 1
		var current_faction: String = LevelInfo.get_level_faction(current_level)
		if current_faction != defend_faction:
			return false
		var defeated: Array = data.get("defeated_masters", [])
		return defeated.size() > 0

	return 0

func is_mission_quest(quest_id: String) -> bool:
	var def: Dictionary = QuestDefs.get_by_id(quest_id)
	if def.is_empty():
		return false
	var otype: String = def.get("objective_type", "")
	return otype == "attack_faction" or otype == "defend_faction"

func get_quest_target_faction(quest_id: String) -> String:
	var def: Dictionary = QuestDefs.get_by_id(quest_id)
	if def.is_empty():
		return ""
	var otype: String = def.get("objective_type", "")
	var target: Dictionary = def.get("target", {})
	if otype == "attack_faction":
		return target.get("target_faction", "")
	if otype == "defend_faction":
		return target.get("defend_faction", "")
	return ""

func is_mission_quest_done(quest_id: String) -> bool:
	return get_quest_progress_for_mission(quest_id) >= 1
