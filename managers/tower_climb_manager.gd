extends Node
## 爬塔模式核心管理器（Autoload）
## 职责：状态机、层间流程、奖励生成、元进度、存档
## 合并了原设计中的 TowerClimbManager + TowerRewardManager + TowerMetaManager

const TowerDefinitions = preload("res://data/tower_definitions.gd")
const TowerRelics = preload("res://data/tower_relics.gd")
const TowerEvents = preload("res://data/tower_events.gd")

## 性能优化：预加载常用资源
const DefaultCards = preload("res://data/default_cards.gd")
const GameConstants = preload("res://resources/game_constants.gd")
const PhaseLaws = preload("res://data/phase_laws.gd")

# ── 状态机 ────────────────────────────────────────────────
enum TowerState {
	IDLE,           # 未开始
	SELECT_START,   # 选择起始相位仪
	PRE_BATTLE,     # 层间准备
	BATTLE,         # 战斗中
	POST_BATTLE,    # 战斗结算
	REWARD_SELECT,  # 三选一奖励
	EVENT,          # 层间事件
	REST,           # 休息层
	SHOP,           # 商店层
	GAME_OVER,      # 爬塔结束（失败）
	VICTORY,        # 通关最终层
}

enum RewardType {
	NEW_CARD,
	UPGRADE_CARD,
	NEW_LAW,
	RELIC,
	HEAL,
	MAX_HP_UP,
	GOLD_BONUS,
	REMOVE_CARD,
}

# ── 核心运行数据（仅内存，不持久化）─────────────────────
var current_state: TowerState = TowerState.IDLE
var current_run: Dictionary = {}
var _saved_law_state: Dictionary = {}  # 进入爬塔前保存的法则状态
var _enemy_boost_multiplier: float = 1.0  # 传送门事件加成

# ── 元进度（跨局持久化）─────────────────────────────────
var meta_progress: Dictionary = {
	"total_runs": 0,
	"best_floor": 0,
	"best_score": 0,
	"total_victories": 0,
	"total_score": 0,
	"unlocked_starters": ["default", "scout", "heavy"],
	"unlocked_relics": [],
	"permanent_upgrades": {
		"starting_hp_bonus": 0,
		"starting_energy_bonus": 0,
		"starting_gold_bonus": 0,
	},
}

# ── 排行榜 ───────────────────────────────────────────────
var leaderboard: Array = []  # [{run_id, floor, score, date, starter, relics}]

# ── 存档路径 ─────────────────────────────────────────────
const TOWER_SAVE_FILE := "user://tower_save.json"
const TOWER_SCHEMA_VERSION := 1

const REWARD_WEIGHTS_EARLY := {  # 1-10 层
	RewardType.NEW_CARD: 40,
	RewardType.UPGRADE_CARD: 15,
	RewardType.NEW_LAW: 10,
	RewardType.RELIC: 5,
	RewardType.HEAL: 20,
	RewardType.MAX_HP_UP: 5,
	RewardType.GOLD_BONUS: 5,
}
const REWARD_WEIGHTS_MID := {  # 11-20 层
	RewardType.NEW_CARD: 30,
	RewardType.UPGRADE_CARD: 25,
	RewardType.NEW_LAW: 15,
	RewardType.RELIC: 15,
	RewardType.HEAL: 5,
	RewardType.MAX_HP_UP: 5,
	RewardType.GOLD_BONUS: 5,
}
const REWARD_WEIGHTS_LATE := {  # 21-30 层
	RewardType.NEW_CARD: 20,
	RewardType.UPGRADE_CARD: 20,
	RewardType.NEW_LAW: 15,
	RewardType.RELIC: 25,
	RewardType.HEAL: 5,
	RewardType.MAX_HP_UP: 5,
	RewardType.GOLD_BONUS: 10,
}

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	load_meta_progress()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_meta_progress()

# ═══════════════════════════════════════════════════════════
#  运行流程
# ═══════════════════════════════════════════════════════════

## 是否在爬塔模式中
func is_active() -> bool:
	return current_run.get("active", false)

## 获取当前层数
func get_current_floor() -> int:
	return int(current_run.get("floor", 1))

## 获取最大层数
func get_max_floor() -> int:
	return TowerDefinitions.MAX_FLOOR

## 开始新的爬塔运行
func start_new_run(starting_loadout_id: String) -> void:
	var loadout: Dictionary = TowerDefinitions.STARTING_LOADOUTS.get(starting_loadout_id, TowerDefinitions.STARTING_LOADOUTS["default"])

	# 保存自由模式法则状态
	_save_free_mode_law_state()

	# 初始化运行数据
	var permanent_hp := int(meta_progress["permanent_upgrades"].get("starting_hp_bonus", 0))
	var permanent_energy := int(meta_progress["permanent_upgrades"].get("starting_energy_bonus", 0))
	var permanent_gold := int(meta_progress["permanent_upgrades"].get("starting_gold_bonus", 0))

	current_run = {
		"active": true,
		"floor": 1,
		"max_floor": TowerDefinitions.MAX_FLOOR,
		"hp": int(loadout.get("starting_hp", 100)) + permanent_hp,
		"max_hp": int(loadout.get("starting_hp", 100)) + permanent_hp,
		"gold": int(loadout.get("starting_gold", 0)) + permanent_gold,
		"score": 0,
		"start_time": Time.get_unix_time_from_system(),
		"starter_id": starting_loadout_id,
		"deck": _create_initial_deck(starting_loadout_id),
		"law_cards": [],
		"relics": [],
		"relic_effects": {},  # 累计遗物效果
		"upgraded_cards": [],  # 已升级的卡ID
		"run_stats": {
			"total_kills": 0,
			"total_damage_dealt": 0,
			"floors_cleared": 0,
			"bosses_defeated": 0,
			"perfect_floors": 0,
		},
	}
	_enemy_boost_multiplier = 1.0
	_set_state(TowerState.PRE_BATTLE)

	if SignalBus:
		SignalBus.tower_run_started.emit()
	print("[TowerClimbManager] 新爬塔开始: 起始套件=%s, HP=%d/%d" % [
		starting_loadout_id, current_run["hp"], current_run["max_hp"]])

## 推进到下一层
func advance_to_next_floor() -> void:
	if not is_active():
		return
	var next_floor := TowerDefinitions.get_next_floor(get_current_floor())
	current_run["floor"] = next_floor

	var floor_type := TowerDefinitions.get_floor_type(next_floor)
	match floor_type:
		"rest":
			_set_state(TowerState.REST)
		"shop":
			_set_state(TowerState.SHOP)
		"event":
			_set_state(TowerState.EVENT)
		_:
			_set_state(TowerState.PRE_BATTLE)

	if SignalBus:
		SignalBus.tower_floor_changed.emit(next_floor)
	print("[TowerClimbManager] 推进到第 %d 层 (类型: %s)" % [next_floor, floor_type])

## 获取当前层的战斗配置（供 BattleManager 使用）
func get_battle_config_for_floor(floor_num: int) -> Dictionary:
	var config := TowerDefinitions.get_floor_config(floor_num)

	# 应用遗物效果
	var energy_bonus := int(_get_cumulative_effect("energy_start_bonus"))
	config["energy_start_bonus"] = energy_bonus

	# 应用传送门加成
	if _enemy_boost_multiplier > 1.0:
		config["enemy_multiplier"] *= _enemy_boost_multiplier

	# 应用商店折扣
	if _has_effect("shop_discount"):
		config["shop_discount"] = _get_cumulative_effect("shop_discount")

	return config

## 层通关回调
func on_floor_cleared(battle_stats: Dictionary) -> void:
	if not is_active():
		return

	var floor_num := get_current_floor()
	var floor_config := TowerDefinitions.get_floor_config(floor_num)
	var floor_type: String = str(floor_config.get("floor_type", "normal"))
	print("[TowerClimbManager] 层通关: %s" % [floor_num, floor_type])

	# 更新统计
	var stats: Dictionary = current_run["run_stats"]
	stats["floors_cleared"] = int(stats.get("floors_cleared", 0)) + 1
	stats["total_kills"] = int(stats.get("total_kills", 0)) + int(battle_stats.get("total_kills", 0))
	if floor_type == "boss":
		stats["bosses_defeated"] = int(stats.get("bosses_defeated", 0)) + 1

	# 计算分数
	var kill_score: int = int(battle_stats.get("total_kills", 0)) * int(floor_config.get("score_per_kill", 10))
	var kill_bonus := _get_cumulative_effect("kill_score_bonus")
	var kill_multiplier := _get_cumulative_effect("kill_score_multiplier", 1.0)
	kill_score = int(float(kill_score + kill_bonus) * kill_multiplier)
	var floor_clear_bonus := int(_get_cumulative_effect("floor_clear_score_bonus"))
	var floor_score := kill_score + floor_clear_bonus + floor_num * 5
	current_run["score"] = int(current_run.get("score", 0)) + floor_score

	# 通关奖励金币
	var gold_reward := 10 + floor_num * 2
	current_run["gold"] = int(current_run.get("gold", 0)) + gold_reward

	# 判断是否通关最终层
	if floor_num >= TowerDefinitions.MAX_FLOOR:
		end_run(true)
		return

	# 进入战后流程
	_set_state(TowerState.POST_BATTLE)

## 层失败回调
func on_floor_failed() -> void:
	if not is_active():
		return
	# 基地被摧毁，本局结束
	current_run["hp"] = 0
	end_run(false)

## 结束运行
func end_run(victory: bool) -> void:
	if not is_active():
		return

	var final_floor := get_current_floor()
	var final_score := int(current_run.get("score", 0))
	var elapsed := Time.get_unix_time_from_system() - float(current_run.get("start_time", 0))

	# 更新元进度
	meta_progress["total_runs"] = int(meta_progress.get("total_runs", 0)) + 1
	meta_progress["total_score"] = int(meta_progress.get("total_score", 0)) + final_score
	if final_floor > int(meta_progress.get("best_floor", 0)):
		meta_progress["best_floor"] = final_floor
	if final_score > int(meta_progress.get("best_score", 0)):
		meta_progress["best_score"] = final_score
	if victory:
		meta_progress["total_victories"] = int(meta_progress.get("total_victories", 0)) + 1

	# 检查解锁条件
	_check_meta_unlocks(final_floor, final_score)

	# 更新排行榜（无上限）
	leaderboard.append({
		"run_id": meta_progress["total_runs"],
		"floor": final_floor,
		"score": final_score,
		"date": Time.get_datetime_string_from_system().substr(0, 10),
		"starter": current_run.get("starter_id", "default"),
		"relics": current_run.get("relics", []).duplicate(),
		"victory": victory,
		"elapsed": int(elapsed),
		"stats": current_run.get("run_stats", {}).duplicate(),
	})
	leaderboard.sort_custom(func(a, b): return int(a.get("score", 0)) > int(b.get("score", 0)))

	# 保存元进度并清除运行存档
	save_meta_progress()
	clear_saved_run()

	# 标记运行结束
	current_run["active"] = false
	_set_state(TowerState.VICTORY if victory else TowerState.GAME_OVER)

	# 恢复自由模式法则状态
	_restore_free_mode_law_state()

	if SignalBus:
		SignalBus.tower_run_ended.emit(victory, final_floor, final_score)
	print("[TowerClimbManager] 爬塔结束: %s, 层数=%d, 分数=%d, 用时=%ds" % [
		"通关" if victory else "失败", final_floor, final_score, int(elapsed)])

## 中途放弃
func abandon_run() -> void:
	if not is_active():
		return
	current_run["active"] = false
	_restore_free_mode_law_state()
	save_meta_progress()
	_set_state(TowerState.IDLE)
	if SignalBus:
		SignalBus.tower_run_ended.emit(false, get_current_floor(), int(current_run.get("score", 0)))

# ═══════════════════════════════════════════════════════════
#  奖励系统
# ═══════════════════════════════════════════════════════════

## 生成三个奖励选项
func generate_reward_choices() -> Array:
	var floor_num := get_current_floor()
	var floor_config := TowerDefinitions.get_floor_config(floor_num)
	var is_boss: bool = floor_config.get("floor_type") == "boss"
	var is_elite: bool = floor_config.get("floor_type") == "elite"

	var choices: Array = []

	# Boss 关保证至少 1 个遗物
	if is_boss:
		choices.append(_generate_reward(RewardType.RELIC, floor_num, true))
	elif is_elite:
		choices.append(_generate_reward(RewardType.RELIC, floor_num, false))

	# 填充剩余选项
	var weights: Dictionary = _get_reward_weights_for_floor(floor_num)
	while choices.size() < 3:
		var reward := _generate_weighted_reward(weights, floor_num)
		# 避免重复类型
		var is_duplicate := false
		for existing in choices:
			if existing.get("type", -1) == reward.get("type", -2):
				is_duplicate = true
				break
		if not is_duplicate:
			choices.append(reward)

	if SignalBus:
		SignalBus.tower_reward_offered.emit(choices)
	return choices

## 应用选中的奖励
func apply_reward(reward: Dictionary) -> void:
	var reward_type: int = reward.get("type", -1)
	match reward_type:
		RewardType.NEW_CARD:
			var card_id: String = reward.get("card_id", "")
			if not card_id.is_empty():
				current_run["deck"].append(card_id)
				print("[TowerClimbManager] 获得卡牌: %s" % card_id)
		RewardType.UPGRADE_CARD:
			var card_id: String = reward.get("card_id", "")
			if not card_id.is_empty() and not current_run["upgraded_cards"].has(card_id):
				current_run["upgraded_cards"].append(card_id)
				print("[TowerClimbManager] 升级卡牌: %s" % card_id)
		RewardType.NEW_LAW:
			var law_id: String = reward.get("law_id", "")
			if not law_id.is_empty():
				current_run["law_cards"].append(law_id)
				print("[TowerClimbManager] 获得法则: %s" % law_id)
		RewardType.RELIC:
			var relic_id: String = reward.get("relic_id", "")
			if not relic_id.is_empty():
				current_run["relics"].append(relic_id)
				_apply_relic_effect(relic_id)
				print("[TowerClimbManager] 获得遗物: %s" % relic_id)
		RewardType.HEAL:
			var amount: int = int(reward.get("heal_amount", 20))
			_heal(amount)
		RewardType.MAX_HP_UP:
			var amount: int = int(reward.get("hp_amount", 10))
			current_run["max_hp"] = int(current_run["max_hp"]) + amount
			current_run["hp"] = mini(int(current_run["hp"]) + amount, int(current_run["max_hp"]))
			if SignalBus:
				SignalBus.tower_hp_changed.emit(int(current_run["hp"]), int(current_run["max_hp"]))
		RewardType.GOLD_BONUS:
			var amount: int = int(reward.get("gold_amount", 20))
			current_run["gold"] = int(current_run["gold"]) + amount
			if SignalBus:
				SignalBus.tower_gold_changed.emit(int(current_run["gold"]))
		RewardType.REMOVE_CARD:
			# 移除最弱的卡（简化逻辑）
			if current_run["deck"].size() > 2:
				current_run["deck"].pop_front()
				print("[TowerClimbManager] 移除一张卡牌")

	if SignalBus:
		SignalBus.tower_reward_selected.emit(reward)

## 跳过奖励
func skip_reward() -> void:
	print("[TowerClimbManager] 跳过奖励")
	advance_to_next_floor()

# ═══════════════════════════════════════════════════════════
#  休息层
# ═══════════════════════════════════════════════════════════

## 休息层回复
func rest_heal() -> void:
	var heal_amount := 25
	heal_amount += int(_get_cumulative_effect("rest_heal_bonus"))
	_heal(heal_amount)
	print("[TowerClimbManager] 休息回复: %d HP" % heal_amount)

## 休息层最大生命提升
func rest_max_hp_up() -> void:
	var amount := 10
	current_run["max_hp"] = int(current_run["max_hp"]) + amount
	_heal(amount)
	if SignalBus:
		SignalBus.tower_hp_changed.emit(int(current_run["hp"]), int(current_run["max_hp"]))
	print("[TowerClimbManager] 休息提升最大生命: +%d" % amount)

# ═══════════════════════════════════════════════════════════
#  事件系统
# ═══════════════════════════════════════════════════════════

## 获取当前层的事件
func get_current_event() -> Dictionary:
	return TowerEvents.get_random_event(get_current_floor())

## 应用事件效果
func apply_event_effect(effect: Dictionary) -> void:
	var effect_type: String = effect.get("type", "none")
	match effect_type:
		"heal":
			_heal(int(effect.get("amount", 0)))
		"gold":
			current_run["gold"] = int(current_run["gold"]) + int(effect.get("amount", 0))
			if SignalBus:
				SignalBus.tower_gold_changed.emit(int(current_run["gold"]))
		"max_hp_up":
			var amount: int = int(effect.get("amount", 0))
			current_run["max_hp"] = int(current_run["max_hp"]) + amount
			_heal(amount)
		"add_random_relic":
			var max_rarity: String = effect.get("max_rarity", "uncommon")
			var relic := TowerRelics.get_random_relic(
				current_run["relics"] as Array, max_rarity
			)
			if not relic.is_empty():
				current_run["relics"].append(relic["id"])
				_apply_relic_effect(relic["id"])
				if SignalBus:
					SignalBus.tower_relic_obtained.emit(relic["id"])
		"add_random_card":
			var card := _get_random_card_for_floor(get_current_floor())
			if not card.is_empty():
				current_run["deck"].append(card)
		"skip_floor":
			_enemy_boost_multiplier += float(effect.get("enemy_boost", 0.15))
			advance_to_next_floor()  # 跳过当前层
			return  # 跳过后不执行 advance_to_next_floor
		"stat_boost":
			var stat: String = effect.get("stat", "")
			var value: float = float(effect.get("value", 0))
			if not stat.is_empty():
				var effects: Dictionary = current_run.get("relic_effects", {})
				effects[stat] = float(effects.get(stat, 0)) + value
				current_run["relic_effects"] = effects
		"sacrifice_card_for_relic":
			if current_run["deck"].size() > 2:
				current_run["deck"].pop_front()
				var relic := TowerRelics.get_random_relic(
					current_run["relics"] as Array, "rare"
				)
				if not relic.is_empty():
					current_run["relics"].append(relic["id"])
					_apply_relic_effect(relic["id"])
					if SignalBus:
						SignalBus.tower_relic_obtained.emit(relic["id"])
		"upgrade_random_card":
			var multiplier: float = float(effect.get("multiplier", 1.2))
			if not current_run["deck"].is_empty():
				var deck_cards: Array = current_run["deck"] as Array
				var idx: int = int(randi() % deck_cards.size())
			var card_id: String = str(deck_cards[idx])
			print("[TowerClimbManager] 随机升级卡牌: %s (x%.1f)" % [card_id, multiplier])
			if not current_run["upgraded_cards"].has(card_id):
					current_run["upgraded_cards"].append(card_id)
		"remove_card_for_gold":
			if current_run["deck"].size() > 2:
				current_run["deck"].pop_front()
				var gold_amt: int = int(effect.get("gold_amount", 15))
				current_run["gold"] = int(current_run["gold"]) + gold_amt
				if SignalBus:
					SignalBus.tower_gold_changed.emit(int(current_run["gold"]))
		"random_reward":
			# 宝箱：随机获得一个奖励
			var roll := randi() % 3
			match roll:
				0:
					_heal(15)
				1:
					current_run["gold"] = int(current_run["gold"]) + 20
					if SignalBus:
						SignalBus.tower_gold_changed.emit(int(current_run["gold"]))
				2:
					var relic := TowerRelics.get_random_relic(
						current_run["relics"] as Array, "uncommon"
					)
					if not relic.is_empty():
						current_run["relics"].append(relic["id"])
						_apply_relic_effect(relic["id"])
						if SignalBus:
							SignalBus.tower_relic_obtained.emit(relic["id"])

	advance_to_next_floor()

# ═══════════════════════════════════════════════════════════
#  存档系统
# ═══════════════════════════════════════════════════════════

## 保存元进度 + 当前运行状态
func save_meta_progress() -> bool:
	var data := {
		"__schema_version": TOWER_SCHEMA_VERSION,
		"meta_progress": meta_progress.duplicate(true),
		"leaderboard": leaderboard.duplicate(true),
	}
	# 如果有进行中的爬塔运行，也保存（支持断点续玩）
	if is_active():
		data["current_run"] = current_run.duplicate(true)
		data["saved_law_state"] = _saved_law_state.duplicate(true)
		data["enemy_boost"] = _enemy_boost_multiplier
		data["current_state"] = int(current_state)

	var json_str := JSON.stringify(data)
	if json_str.is_empty():
		push_error("[TowerClimbManager] JSON 序列化失败")
		return false

	var f := FileAccess.open(TOWER_SAVE_FILE, FileAccess.WRITE)
	if f == null:
		push_error("[TowerClimbManager] 无法写入爬塔存档: %s" % TOWER_SAVE_FILE)
		return false
	f.store_string(json_str)
	f.close()
	print("[TowerClimbManager] 元进度已保存" + ("（含进行中运行）" if is_active() else ""))
	return true

## 加载元进度
func load_meta_progress() -> bool:
	if not FileAccess.file_exists(TOWER_SAVE_FILE):
		print("[TowerClimbManager] 无爬塔存档，使用默认值")
		return false

	var f := FileAccess.open(TOWER_SAVE_FILE, FileAccess.READ)
	if f == null:
		return false
	var json_str := f.get_as_text()
	f.close()

	var json := JSON.new()
	if json.parse(json_str) != OK:
		push_error("[TowerClimbManager] 爬塔存档 JSON 解析失败")
		return false

	var data = json.get_data()
	if not data is Dictionary:
		return false

	if data.has("meta_progress"):
		meta_progress = data["meta_progress"]
	if data.has("leaderboard"):
		leaderboard = data["leaderboard"]

	# 恢复进行中的运行（断点续玩）
	if data.has("current_run"):
		var saved_run: Dictionary = data.get("current_run", {})
		if saved_run.get("active", false):
			current_run = saved_run
			if data.has("saved_law_state"):
				_saved_law_state = data.get("saved_law_state", {})
			if data.has("enemy_boost"):
				_enemy_boost_multiplier = float(data.get("enemy_boost", 1.0))
			if data.has("current_state"):
				current_state = int(data.get("current_state", TowerState.PRE_BATTLE))
			if SignalBus:
				SignalBus.tower_run_started.emit()
				SignalBus.tower_state_changed.emit(int(current_state))
				SignalBus.tower_floor_changed.emit(get_current_floor())
				SignalBus.tower_hp_changed.emit(int(current_run.get("hp", 100)), int(current_run.get("max_hp", 100)))
				SignalBus.tower_gold_changed.emit(int(current_run.get("gold", 0)))
			print("[TowerClimbManager] 已恢复进行中的运行: 第 %d 层" % get_current_floor())

	print("[TowerClimbManager] 元进度已加载: %d 次运行, 最高 %d 层" % [
		meta_progress.get("total_runs", 0), meta_progress.get("best_floor", 0)])
	return true

## 是否有进行中的运行可以恢复
func has_saved_run() -> bool:
	return is_active()

## 清除已保存的运行状态（运行正常结束时调用）
func clear_saved_run() -> void:
	var data := {
		"__schema_version": TOWER_SCHEMA_VERSION,
		"meta_progress": meta_progress.duplicate(true),
		"leaderboard": leaderboard.duplicate(true),
	}
	var json_str := JSON.stringify(data)
	var f := FileAccess.open(TOWER_SAVE_FILE, FileAccess.WRITE)
	if f:
		f.store_string(json_str)
		f.close()
		print("[TowerClimbManager] 已清除运行存档")

## 重置元进度（开发用）
func reset_meta_progress() -> void:
	meta_progress = {
		"total_runs": 0,
		"best_floor": 0,
		"best_score": 0,
		"total_victories": 0,
		"total_score": 0,
		"unlocked_starters": ["default", "scout", "heavy"],
		"unlocked_relics": [],
		"permanent_upgrades": {
			"starting_hp_bonus": 0,
			"starting_energy_bonus": 0,
			"starting_gold_bonus": 0,
		},
	}
	leaderboard.clear()
	save_meta_progress()

# ═══════════════════════════════════════════════════════════
#  内部方法
# ═══════════════════════════════════════════════════════════

func _set_state(new_state: TowerState) -> void:
	current_state = new_state
	if SignalBus:
		SignalBus.tower_state_changed.emit(int(new_state))
	print("[TowerClimbManager] 状态: %s" % TowerState.keys()[new_state])

func _heal(amount: int) -> void:
	current_run["hp"] = mini(
		int(current_run["hp"]) + amount,
		int(current_run["max_hp"])
	)
	if SignalBus:
		SignalBus.tower_hp_changed.emit(int(current_run["hp"]), int(current_run["max_hp"]))

func _apply_relic_effect(relic_id: String) -> void:
	var relic: Dictionary = TowerRelics.get_relic(relic_id)
	if relic.is_empty():
		return
	var effect: Dictionary = relic.get("effect", {})
	var effects: Dictionary = current_run.get("relic_effects", {})
	for key in effect:
		var existing: float = float(effects.get(key, 0))
		effects[key] = existing + float(effect[key])
	current_run["relic_effects"] = effects

	# 最大生命加成立即生效
	var hp_bonus := _get_cumulative_effect("max_hp_bonus")
	if hp_bonus > 0:
		var base_hp := int(TowerDefinitions.STARTING_LOADOUTS.get(
			current_run.get("starter_id", "default"), {}
		).get("starting_hp", 100))
		base_hp += int(meta_progress["permanent_upgrades"].get("starting_hp_bonus", 0))
		current_run["max_hp"] = base_hp + int(hp_bonus)
		if SignalBus:
			SignalBus.tower_hp_changed.emit(int(current_run["hp"]), int(current_run["max_hp"]))

	if SignalBus:
		SignalBus.tower_relic_obtained.emit(relic_id)

func _get_cumulative_effect(key: String, default_val: float = 0.0) -> float:
	var effects: Dictionary = current_run.get("relic_effects", {})
	return float(effects.get(key, default_val))

func _has_effect(key: String) -> bool:
	var effects: Dictionary = current_run.get("relic_effects", {})
	return effects.has(key) and float(effects[key]) != 0.0

func _create_initial_deck(loadout_id: String) -> Array:
	var loadout: Dictionary = TowerDefinitions.STARTING_LOADOUTS.get(loadout_id, {})
	var deck: Array = []
	var platforms: Array = loadout.get("platforms", [])
	var weapons: Array = loadout.get("weapons", [])
	for p in platforms:
		deck.append(String(p))
	for w in weapons:
		deck.append(String(w))
	return deck

func _get_reward_weights_for_floor(floor_num: int) -> Dictionary:
	if floor_num <= 10:
		return REWARD_WEIGHTS_EARLY
	elif floor_num <= 20:
		return REWARD_WEIGHTS_MID
	else:
		return REWARD_WEIGHTS_LATE

func _generate_weighted_reward(weights: Dictionary, floor_num: int) -> Dictionary:
	var types: Array = []
	var weight_vals: Array = []
	for type_key in weights:
		types.append(int(type_key))
		weight_vals.append(float(weights[type_key]))

	var total: float = 0.0
	for w in weight_vals:
		total += w
	var roll := randf() * total
	var cumulative := 0.0
	var selected_type: int = RewardType.NEW_CARD
	for i in range(types.size()):
		cumulative += weight_vals[i]
		if roll <= cumulative:
			selected_type = types[i]
			break
	return _generate_reward(selected_type, floor_num, false)

func _generate_reward(type: int, floor_num: int, force_good: bool) -> Dictionary:
	var result := {"type": type}
	match type:
		RewardType.NEW_CARD:
			var card_id := _get_random_card_for_floor(floor_num)
			result["card_id"] = card_id
			if DefaultCards and DefaultCards.has_method("get_card_by_id"):
			var card: Variant = DefaultCards.get_card_by_id(card_id)
			print("[TowerClimbManager] 新卡牌奖励: id=%s, type=%d, is_null=%s" % [card_id, typeof(card), card == null])
			if card:
					result["name"] = "新卡牌: %s" % card.display_name
				else:
					result["name"] = "新卡牌: %s" % card_id
			else:
				result["name"] = "新卡牌"
			result["description"] = "添加一张新卡牌到你的卡组"
		RewardType.UPGRADE_CARD:
			var deck: Array = current_run.get("deck", [])
			if not deck.is_empty():
				var unupgraded: Array = []
				for cid in deck:
					if not current_run["upgraded_cards"].has(cid):
						unupgraded.append(cid)
				if not unupgraded.is_empty():
					var card_id: String = unupgraded[randi() % unupgraded.size()]
					result["card_id"] = card_id
					result["name"] = "升级卡牌"
					result["description"] = "%s 属性 +20%%" % card_id
				else:
					# 所有卡都已升级，回退为新卡
					result["type"] = RewardType.NEW_CARD
					return _generate_reward(RewardType.NEW_CARD, floor_num, false)
			else:
				result["type"] = RewardType.NEW_CARD
				return _generate_reward(RewardType.NEW_CARD, floor_num, false)
		RewardType.NEW_LAW:
			var law_id := _get_random_law_for_floor(floor_num)
			result["law_id"] = law_id
			result["name"] = "新法则卡"
			result["description"] = "获得一张法则卡用于战斗"
		RewardType.RELIC:
			var max_rarity := "uncommon" if force_good else "uncommon"
			if floor_num > 15:
				max_rarity = "rare"
			var relic := TowerRelics.get_random_relic(
				current_run.get("relics", []) as Array, max_rarity
			)
			if relic.is_empty():
				result["type"] = RewardType.GOLD_BONUS
				return _generate_reward(RewardType.GOLD_BONUS, floor_num, false)
			result["relic_id"] = relic["id"]
			result["name"] = relic["name"]
			result["description"] = relic["description"]
			result["rarity"] = relic["rarity"]
		RewardType.HEAL:
			var amount := 15 + floori(floor_num * 0.5)
			result["heal_amount"] = amount
			result["name"] = "生命回复"
			result["description"] = "恢复 %d 点基地生命" % amount
		RewardType.MAX_HP_UP:
			var amount := 8 + floori(floor_num * 0.3)
			result["hp_amount"] = amount
			result["name"] = "生命上限提升"
			result["description"] = "基地最大生命 + %d" % amount
		RewardType.GOLD_BONUS:
			var amount := 15 + floor_num * 2
			result["gold_amount"] = amount
			result["name"] = "金币奖励"
			result["description"] = "获得 %d 金币" % amount
		RewardType.REMOVE_CARD:
			result["name"] = "精简卡组"
			result["description"] = "移除卡组中的一张卡牌"
	return result

func _get_random_card_for_floor(floor_num: int) -> String:
	var era := TowerDefinitions.floor_to_era(floor_num)
	if not DefaultCards:
		return ""

	var prefix := ""
	if GC and GC.has_method("get_era_prefix"):
		prefix = GC.get_era_prefix(era)

	# 优先选择当前时代的卡牌，20% 概率选其他时代
	var era_cards: Array = []
	var other_cards: Array = []
	var all_ids: Array = DefaultCards.get_all_blueprint_ids() if DefaultCards.has_method("get_all_blueprint_ids") else []

	for card_id_val in all_ids:
		var card_id: String = str(card_id_val)
		# 跳过法则和能量卡
		if card_id.begins_with("law:") or card_id.begins_with("energy_"):
			continue
		if card_id.begins_with("bp_%s_" % prefix):
			era_cards.append(card_id)
		else:
			other_cards.append(card_id)

	var pool: Array = era_cards if (not era_cards.is_empty() and randf() > 0.2) else other_cards
	if pool.is_empty():
		pool = era_cards + other_cards
	if pool.is_empty():
		return ""

	return pool[randi() % pool.size()] as String

func _get_random_law_for_floor(floor_num: int) -> String:
	if not PhaseLaws or not PhaseLaws.has_method("get_all_ids"):
		return ""
	var all_ids: Array = PhaseLaws.get_all_ids()
	if all_ids.is_empty():
		return ""
	# 避免重复
	var available: Array = []
	for lid in all_ids:
		if not current_run["law_cards"].has(String(lid)):
			available.append(String(lid))
	if available.is_empty():
		available = all_ids.map(func(x): return str(x))
	return available[randi() % available.size()] as String

func _save_free_mode_law_state() -> void:
	var plm = get_node_or_null("/root/PhaseLawManager")
	if plm:
		_saved_law_state = {}
		if "equipped_active_laws" in plm:
			_saved_law_state["equipped_active_laws"] = Array(plm.equipped_active_laws)
		if "equipped_passive_laws" in plm:
			_saved_law_state["equipped_passive_laws"] = Array(plm.equipped_passive_laws)
		if "active_law_states" in plm:
			_saved_law_state["active_law_states"] = Dictionary(plm.active_law_states)
		print("[TowerClimbManager] 已保存自由模式法则状态")

func _restore_free_mode_law_state() -> void:
	if _saved_law_state.is_empty():
		return
	var plm = get_node_or_null("/root/PhaseLawManager")
	if plm:
		if _saved_law_state.has("equipped_active_laws"):
			plm.equipped_active_laws = _saved_law_state["equipped_active_laws"]
		if _saved_law_state.has("equipped_passive_laws"):
			plm.equipped_passive_laws = _saved_law_state["equipped_passive_laws"]
		if _saved_law_state.has("active_law_states"):
			plm.active_law_states = _saved_law_state["active_law_states"]
		print("[TowerClimbManager] 已恢复自由模式法则状态")
	_saved_law_state.clear()

func _check_meta_unlocks(best_floor: int, _total_score: int) -> void:
	# 首次通关第10层
	if best_floor >= 10 and not meta_progress["unlocked_relics"].has("relic_war_drums"):
		meta_progress["unlocked_relics"].append("relic_war_drums")
		print("[TowerClimbManager] 元进度解锁: 遗物池 - 战鼓")
	# 首次通关第20层
	if best_floor >= 20 and not meta_progress["unlocked_relics"].has("relic_phase_accelerator"):
		meta_progress["unlocked_relics"].append("relic_phase_accelerator")
		print("[TowerClimbManager] 元进度解锁: 遗物池 - 相位加速器")
	# 累计10次
	if meta_progress["total_runs"] >= 10:
		var upgrades: Dictionary = meta_progress["permanent_upgrades"]
		if upgrades.get("starting_hp_bonus", 0) < 10:
			upgrades["starting_hp_bonus"] = 10
			print("[TowerClimbManager] 元进度解锁: 永久 +10 起始HP")
	# 累计通关3次
	if meta_progress["total_victories"] >= 3:
		if not meta_progress["unlocked_relics"].has("relic_berserker_mark"):
			meta_progress["unlocked_relics"].append("relic_berserker_mark")
			print("[TowerClimbManager] 元进度解锁: 遗物池 - 狂战印记")
