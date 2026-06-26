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
const FactionQuestGenerator = preload("res://data/faction_quest_generator.gd")  # v6.9: 势力动态任务生成

signal quest_accepted(quest_id: String)
signal quest_progress_changed(quest_id: String)
signal quest_completed(quest_id: String, rewards: Dictionary)
signal quest_phase_master_defeated(quest_id: String, master_name: String)

# 已接任务：quest_id -> { "progress": {...}, "cleared_levels": [...], "defeated_masters": [...] }
var _accepted: Dictionary = {}
# 已完成过的任务 id
var _completed_ids: Array = []
# v6.6(剧情): 已揭示的隐藏任务 id 集合（补剧情.txt 第四幕真实者支线）
# hidden=true 的任务初始不可见，由 NPC 对话/剧情节点 reveal_quest 后才出现在任务板
var _revealed_quest_ids: Array[String] = []

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
	# v6.6 修复: enhancement_completed 原 emit 无 connect，强化类教学任务永远不推进。
	# CardEnhancementManager 是 lazy-load，deferred 到下一帧再查找连接，避免时序竞争。
	call_deferred("_connect_enhancement_signal")

## v6.6: 延迟连接 CardEnhancementManager.enhancement_completed（lazy-load 安全）
func _connect_enhancement_signal() -> void:
	var cem = get_node_or_null("/root/CardEnhancementManager")
	if cem == null:
		return
	if not cem.enhancement_completed.is_connected(_on_enhancement_completed):
		cem.enhancement_completed.connect(_on_enhancement_completed)

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


func _on_enhancement_completed(success: bool, _card_id: String, _action: String, _message: String) -> void:
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
	# v6.6(剧情): hidden 任务必须先 reveal 才能接（补剧情.txt 真实者支线）
	if not is_quest_available(quest_id):
		return false
	_accepted[quest_id] = {"progress": {}, "cleared_levels": []}
	quest_accepted.emit(quest_id)
	quest_progress_changed.emit(quest_id)
	return true

func abandon_quest(quest_id: String) -> void:
	_accepted.erase(quest_id)
	quest_progress_changed.emit(quest_id)

# ──────────────── v6.6(剧情): 隐藏/分支任务系统（补剧情.txt 第四幕真实者的阴影）────────────────

## 任务是否当前可接（可见且未完成）
## hidden=true 的任务需先 reveal_quest 揭示；prereq 任务需先完成
## v6.7(剧情任务): category=="story" 的任务，前置 prereq 一旦完成即自动 reveal（不依赖 NPC）
func is_quest_available(quest_id: String) -> bool:
	var def: Dictionary = QuestDefs.get_by_id(quest_id)
	if def.is_empty():
		return false
	# prereq 任务未完成 → 不可接
	var prereq: String = String(def.get("prereq", ""))
	if not prereq.is_empty() and not is_completed_ever(prereq):
		return false
	# story 任务前置完成后自动揭示（自由模式无 city_map / NPC，剧情任务不应卡 reveal）
	if def.get("category", "commission") == "story" and not _revealed_quest_ids.has(quest_id):
		_revealed_quest_ids.append(quest_id)
	# hidden 且未揭示 → 不可接（其他 hidden 任务仍走 NPC reveal 路径）
	if bool(def.get("hidden", false)) and not _revealed_quest_ids.has(quest_id):
		return false
	return true

## 揭示一个隐藏任务（由 NPC 对话/剧情节点调用，补剧情.txt 真实者邀请）
func reveal_quest(quest_id: String) -> bool:
	if not _revealed_quest_ids.has(quest_id):
		_revealed_quest_ids.append(quest_id)
		if SignalBus.has_signal("show_toast"):
			SignalBus.show_toast.emit("新任务已揭示")
		return true
	return false

## 任务是否已被揭示（隐藏任务可见性查询）
func is_quest_revealed(quest_id: String) -> bool:
	return _revealed_quest_ids.has(quest_id)

## 设置任务分支结果（补剧情.txt 第四幕"加入/拒绝/拖延真实者"选择）
## branch_key 存入 StoryManager story_flags，供后续剧情节点判定
func set_quest_branch(quest_id: String, branch_key: String, branch_value: Variant = true) -> void:
	var sm: Node = get_node_or_null("/root/StoryManager")
	if sm and sm.has_method("set_story_flag"):
		# 分支标记命名：quest_<quest_id>_<branch_key>
		sm.set_story_flag("quest_%s_%s" % [quest_id, branch_key], branch_value)
	# 揭示分支后续任务（如有）
	var def: Dictionary = QuestDefs.get_by_id(quest_id)
	var branches: Dictionary = def.get("branches", {})
	if branches.has(branch_key):
		var next_quest: String = String(branches[branch_key].get("next_quest", ""))
		if not next_quest.is_empty():
			reveal_quest(next_quest)

## 获取任务分支结果（供剧情节点查询玩家选择）
func get_quest_branch(quest_id: String, branch_key: String) -> Variant:
	var sm: Node = get_node_or_null("/root/StoryManager")
	if sm and sm.has_method("get_story_flag"):
		return sm.get_story_flag("quest_%s_%s" % [quest_id, branch_key], null)
	return null

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
	# v6.9: 任务随机结果——若定义了 outcome_table，按权重抽取一个结果变体
	var rewards: Dictionary = def.get("rewards", {})
	var outcome_label: String = ""
	var outcome_table: Array = def.get("outcome_table", [])
	if not outcome_table.is_empty():
		var picked: Dictionary = _roll_outcome(outcome_table)
		if not picked.is_empty():
			rewards = picked.get("rewards", rewards)
			outcome_label = String(picked.get("label", ""))
	_grant_rewards(rewards)
	_accepted.erase(quest_id)
	if quest_id not in _completed_ids:
		_completed_ids.append(quest_id)
	quest_completed.emit(quest_id, rewards)
	quest_progress_changed.emit(quest_id)
	# v6.6: 同步镜像到 SignalBus（audio/全局监听者订阅的是 SignalBus 版本）
	SignalBus.quest_completed.emit(quest_id, rewards)
	# v6.9: 随机结果提示（让玩家知道抽到了什么结果）
	if not outcome_label.is_empty() and SignalBus.has_signal("show_toast"):
		var qtitle: String = String(def.get("title", quest_id))
		SignalBus.show_toast.emit("%s：%s" % [qtitle, outcome_label])
	# v6.9: 动态任务完成后从注册表移除（避免 get_available_ids 堆积已完成任务）
	if bool(def.get("is_dynamic", false)):
		QuestDefs.unregister_dynamic_quest(quest_id)

## v6.9: 按 weight 权重抽取一个结果变体
## [param outcome_table] [{weight, label, rewards}, ...]
## [return] 抽中的变体 Dictionary；输入空或异常返回空字典
static func _roll_outcome(outcome_table: Array) -> Dictionary:
	if outcome_table.is_empty():
		return {}
	var total_weight: int = 0
	for o in outcome_table:
		if o is Dictionary:
			total_weight += maxi(1, int(o.get("weight", 1)))
	if total_weight <= 0:
		return {}
	var roll: int = randi() % total_weight
	for o in outcome_table:
		if not (o is Dictionary):
			continue
		roll -= maxi(1, int(o.get("weight", 1)))
		if roll < 0:
			return o
	return outcome_table[outcome_table.size() - 1] if outcome_table[outcome_table.size() - 1] is Dictionary else {}

func _grant_rewards(rewards: Dictionary) -> void:
	var bm = get_node_or_null("/root/BlueprintManager")
	# DEPRECATED (P0-3c): blueprint_fragments reward logic disabled — reward schema migrated away from fragment-based model
	#if rewards.has("blueprint_fragments") and rewards["blueprint_fragments"] is Dictionary and bm != null:
	#	for card_id in rewards["blueprint_fragments"]:
	#		var n: int = int(rewards["blueprint_fragments"][card_id])
	#		CardDropGrantsScript.grant_enemy_style_card(bm, String(card_id), 0, maxi(1, n))
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
		# v6.6(剧情): 持久化已揭示的隐藏任务（补剧情.txt 真实者支线）
		"revealed_quest_ids": _revealed_quest_ids.duplicate(),
		# v6.9: 持久化动态任务定义（未完成的动态任务读档后恢复）
		"dynamic_quests": QuestDefs.get_all_dynamic_quest_defs(),
	}

func load_state(data: Dictionary) -> void:
	if data.has("accepted") and data["accepted"] is Dictionary:
		_accepted = (data["accepted"] as Dictionary).duplicate(true)
	if data.has("completed_ids") and data["completed_ids"] is Array:
		_completed_ids = (data["completed_ids"] as Array).duplicate()
	# v6.6(剧情): 恢复已揭示的隐藏任务（旧存档无此字段时为空，需重新触发剧情揭示）
	_revealed_quest_ids.clear()
	for qid in data.get("revealed_quest_ids", []):
		_revealed_quest_ids.append(String(qid))
	# v6.9: 恢复动态任务定义（读档前清空，避免重复；旧存档无此字段时为空数组）
	QuestDefs.clear_dynamic_quests()
	for def in data.get("dynamic_quests", []):
		if def is Dictionary:
			# 直接回填（已含 is_dynamic 标记），跳过 register 的冲突检查
			var qid: String = String(def.get("id", ""))
			if not qid.is_empty():
				QuestDefs.register_dynamic_quest(def)
	# 清理已完成但仍在注册表的动态任务（防御性：存档时刚好完成的边界情况）
	var stale_dynamic: Array = []
	for qid in QuestDefs.get_dynamic_quest_ids():
		if is_completed_ever(String(qid)):
			stale_dynamic.append(String(qid))
	for sid in stale_dynamic:
		QuestDefs.unregister_dynamic_quest(sid)

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

# ──────────────── v6.7(剧情任务): 自由模式剧情任务查询接口 ────────────────

## 返回指定 category 的全部任务定义（委托/剧情/日常）
func get_quests_by_category(category: String) -> Array:
	var out: Array = []
	for qid in QuestDefs.get_available_ids():
		var def: Dictionary = QuestDefs.get_by_id(qid)
		if def.is_empty():
			continue
		if def.get("category", "commission") == category:
			out.append(def)
	return out

## 返回某剧情任务的触发关卡号（category=="story"）；非剧情任务返回 0
func trigger_level_for_quest(quest_id: String) -> int:
	var def: Dictionary = QuestDefs.get_by_id(quest_id)
	if def.is_empty() or def.get("category", "commission") != "story":
		return 0
	return int(def.get("trigger_level", 0))

## 查询当前关卡是否有已接取、未完成的剧情任务（供 GameManager 进关触发战前对话）
## 返回 quest_id，无则空字符串
func get_active_story_quest_at_level(level: int) -> String:
	for qid in _accepted.keys():
		if trigger_level_for_quest(qid) == level and not is_quest_done(qid):
			return qid
	return ""

# ──────────────── v6.9: 势力动态任务系统 ────────────────

## 刷新某势力的动态任务（进入势力领地/声望升级时由 GameManager 调用）
## 生成1个新动态任务并注册到 QuestDefs，同时揭示让玩家可见可接
## [param faction_id] 势力ID（空或未知则不生成）
## [param max_active_per_faction] 同势力同时存在的动态任务上限，避免堆积
func refresh_faction_quests(faction_id: String, max_active_per_faction: int = 2) -> String:
	if faction_id.is_empty():
		return ""
	var fsm = get_node_or_null("/root/FactionSystemManager")
	var flevel: int = 1
	if fsm and fsm.has_method("get_faction_level"):
		flevel = int(fsm.get_faction_level(faction_id))
	# 清理该势力已完成的动态任务（unregister，避免堆积）
	_cleanup_completed_dynamic_quests_for_faction(faction_id)
	# 控制同势力动态任务数量
	var existing: int = _count_active_dynamic_quests_for_faction(faction_id)
	if existing >= max_active_per_faction:
		return ""
	# 生成新任务
	var def: Dictionary = FactionQuestGenerator.generate_quest(faction_id, flevel)
	if def.is_empty():
		return ""
	var qid: String = QuestDefs.register_dynamic_quest(def)
	if qid.is_empty():
		return ""
	# 动态任务自动揭示（不依赖 NPC，进领地即可见）
	reveal_quest(qid)
	if SignalBus.has_signal("show_toast"):
		var fsm2 = get_node_or_null("/root/FactionSystemManager")
		var fname: String = faction_id
		if fsm2 and fsm2.has_method("get_faction_info"):
			fname = String(fsm2.get_faction_info(faction_id).get("name", faction_id))
		SignalBus.show_toast.emit("%s发布了新委托" % fname)
	quest_progress_changed.emit(qid)
	return qid

## 统计某势力当前已注册且未完成的动态任务数
func _count_active_dynamic_quests_for_faction(faction_id: String) -> int:
	var count: int = 0
	for qid in QuestDefs.get_dynamic_quest_ids():
		if is_completed_ever(String(qid)):
			continue
		var def: Dictionary = QuestDefs.get_by_id(String(qid))
		if String(def.get("company_id", "")) == faction_id:
			count += 1
	return count

## 清理某势力已完成的动态任务（从注册表移除，保持集合精简）
func _cleanup_completed_dynamic_quests_for_faction(faction_id: String) -> void:
	var to_remove: Array = []
	for qid in QuestDefs.get_dynamic_quest_ids():
		var sid = String(qid)
		if not is_completed_ever(sid):
			continue
		var def: Dictionary = QuestDefs.get_by_id(sid)
		if String(def.get("company_id", "")) == faction_id:
			to_remove.append(sid)
	for sid in to_remove:
		QuestDefs.unregister_dynamic_quest(sid)

## 判断任务是否为动态生成（供 UI 区分展示）
func is_dynamic_quest(quest_id: String) -> bool:
	var def: Dictionary = QuestDefs.get_by_id(quest_id)
	return bool(def.get("is_dynamic", false))
