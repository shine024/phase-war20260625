extends RefCounted
class_name LeaderboardData
## 排行榜数据层 (Model)
##
## 负责所有排行榜数据的获取、计算和缓存。
## 与 UI 完全解耦，可独立测试。
##
## 对外接口：
##   - get_faction_leaderboard() -> Array  (公司势力排名)
##   - get_npc_leaderboard() -> Array      (NPC相位师排名)
##   - get_active_phase_masters() -> Array (NPC战斗配置)
##   - get_phase_master_config(name) -> Dictionary
##   - simulate_faction_battles() -> void

# NPC相位师战斗配置
const NPC_PHASE_MASTERS: Array = [
	{"name": "终焉之镰",   "faction": "void_research",     "era": "future",   "platform": "platform_future_heavy"},
	{"name": "炽焰星痕",   "faction": "nova_arms",         "era": "future",   "platform": "platform_future_medium"},
	{"name": "雷霆判官",   "faction": "aether_dynamics",   "era": "cold",     "platform": "platform_cold_medium"},
	{"name": "寒霜壁垒",   "faction": "iron_wall_corp",    "era": "ww2",      "platform": "platform_ww2_heavy"},
	{"name": "量子幽灵",   "faction": "quantum_logistics", "era": "modern",   "platform": "platform_modern_medium"},
	{"name": "虚空低语",   "faction": "helix_recon",       "era": "future",   "platform": "platform_future_light"},
	{"name": "边境开拓者", "faction": "frontier_union",    "era": "ww2",      "platform": "platform_ww2_light"},
]

# 各公司势力领地范围（静态配置）
const FACTION_RANGES: Array = [
	{"fid": "iron_wall_corp",    "start": 1,  "end": 20,  "name": "钢壁防务"},
	{"fid": "nova_arms",         "start": 21, "end": 40,  "name": "新星兵工"},
	{"fid": "aether_dynamics",   "start": 41, "end": 60,  "name": "以太动力"},
	{"fid": "quantum_logistics", "start": 61, "end": 80,  "name": "量子后勤"},
	{"fid": "helix_recon",       "start": 81, "end": 90,  "name": "螺旋侦察"},
	{"fid": "void_research",     "start": 91, "end": 100, "name": "虚空相位"},
	{"fid": "frontier_union",    "start": 1,  "end": 10,  "name": "边境联合"},
]

# NPC相位师预设（按排名顺序）
const NPC_PRESETS: Array = [
	{"name": "终焉之镰",   "style": "暗影猎手",   "wins": 342, "win_rate": 0.82},
	{"name": "炽焰星痕",   "style": "闪电术师",   "wins": 298, "win_rate": 0.78},
	{"name": "雷霆判官",   "style": "风暴使者",   "wins": 265, "win_rate": 0.75},
	{"name": "寒霜壁垒",   "style": "寒冰指挥官", "wins": 232, "win_rate": 0.71},
	{"name": "量子幽灵",   "style": "间谍",       "wins": 198, "win_rate": 0.68},
	{"name": "虚空低语",   "style": "相位法师",   "wins": 156, "win_rate": 0.65},
	{"name": "边境开拓者", "style": "先锋",       "wins": 98,  "win_rate": 0.60},
]

# NPC进度比例设计
const NPC_PROGRESS_RATIOS: Array = [1.0, 0.95, 0.80, 0.65, 0.50, 0.35, 0.20]

# 缓存数据
var _faction_data: Array = []
var _player_data: Array = []
var _faction_dynamic_state: Dictionary = {}
var _simulation_seed: int = 0
var _dynamic_initialized: bool = false

## 获取当前活跃的相位师配置（按排行榜前几名的NPC）
func get_active_phase_masters() -> Array:
	return NPC_PHASE_MASTERS.duplicate()

## 根据相位师名字获取配置
func get_phase_master_config(p_name: String) -> Dictionary:
	for config in NPC_PHASE_MASTERS:
		if config.get("name") == p_name:
			return config
	return {}

## 获取公司势力排名数据
func get_faction_leaderboard() -> Array:
	if _faction_data.is_empty():
		_initialize_faction_data()
	return _faction_data.duplicate(true)

## 获取NPC相位师排名数据
func get_npc_leaderboard() -> Array:
	if _player_data.is_empty():
		_initialize_player_data()
	return _player_data.duplicate(true)

## 刷新所有数据
func refresh() -> void:
	simulate_faction_battles()
	_initialize_faction_data()

## 模拟各势力之间的动态战斗
func simulate_faction_battles() -> void:
	_simulation_seed += 1
	var rng = RandomNumberGenerator.new()
	rng.seed = _simulation_seed * int(Time.get_ticks_msec())

	if not _dynamic_initialized:
		_init_faction_dynamic_state()

	var factions = _faction_dynamic_state.keys()
	for attacker_fid in factions:
		if rng.randf() > 0.4:
			continue

		var attacker_state = _faction_dynamic_state[attacker_fid]
		var success = rng.randf() < 0.5

		if success:
			var targets = []
			for fid in factions:
				if fid != attacker_fid and _faction_dynamic_state[fid].get("cleared", 0) > 0:
					targets.append(fid)
			if targets.is_empty():
				continue

			var target_fid = targets[rng.randi() % targets.size()]
			var target_state = _faction_dynamic_state[target_fid]
			if target_state["cleared"] > 0:
				target_state["cleared"] -= 1
				attacker_state["cleared"] += 1
		else:
			if attacker_state.get("cleared", 0) > 0:
				attacker_state["cleared"] -= 1

	_update_npc_progress_from_faction_state()

## 初始化公司势力数据
func _initialize_faction_data() -> void:
	_faction_data.clear()

	var current_level: int = 1
	var gm: Node = _get_autoload_node("GameManager")
	if gm and "current_level" in gm:
		current_level = int(gm.current_level)
	var cleared_max: int = max(0, current_level - 1)

	var fsm: Node = _get_autoload_node("FactionSystemManager")
	if fsm and fsm.has_method("get_all_factions_info"):
		var all_factions: Array = fsm.get_all_factions_info()
		for fi in all_factions:
			var fid: String = fi.get("id", "")
			if fid.is_empty():
				continue
			var controlled: Array = fi.get("controlled_levels", [])
			var total: int = controlled.size()
			var cleared: int = 0
			for lv in controlled:
				if int(lv) <= cleared_max:
					cleared += 1
			_faction_data.append({
				"name": fi.get("name", fid),
				"faction_id": fid,
				"score": cleared,
				"territories_total": total,
				"reputation": fi.get("reputation", 0),
			})
	else:
		for sd in FACTION_RANGES:
			var s: int = sd["start"]
			var e: int = sd["end"]
			var total: int = max(0, e - s + 1) if e >= s else 0
			var cleared: int = clampi(cleared_max - s + 1, 0, total) if s > 0 else 0
			_faction_data.append({
				"name": sd["name"],
				"faction_id": sd["fid"],
				"score": cleared,
				"territories_total": total,
				"reputation": 0,
			})

	_faction_data.sort_custom(func(a, b) -> bool:
		if a["score"] != b["score"]:
			return a["score"] > b["score"]
		return a["territories_total"] > b["territories_total"]
	)

## 初始化NPC相位师排名数据
func _initialize_player_data() -> void:
	_player_data.clear()

	for i in range(min(NPC_PRESETS.size(), FACTION_RANGES.size())):
		var npc = NPC_PRESETS[i]
		var faction = FACTION_RANGES[i]
		var f_start: int = faction["start"]
		var f_end: int = faction["end"]
		var total: int = max(0, f_end - f_start + 1)

		var ratio: float = NPC_PROGRESS_RATIOS[i] if i < NPC_PROGRESS_RATIOS.size() else 0.2
		var cleared: int = max(1, int(total * ratio))
		cleared = clampi(cleared, 1, total) if total > 0 else 0
		var current_level: int = (f_start + cleared - 1) if total > 0 else f_start

		_player_data.append({
			"rank": i + 1,
			"name": npc["name"],
			"current_level": current_level,
			"wins": npc["wins"],
			"win_rate": npc["win_rate"],
			"preferred_faction": faction["fid"],
			"faction_name": faction["name"],
		})

func _get_autoload_node(name: String) -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		var tree: SceneTree = loop as SceneTree
		if tree.root != null:
			return tree.root.get_node_or_null(name)
	return null

func _init_faction_dynamic_state() -> void:
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	for sd in FACTION_RANGES:
		var total = max(0, sd["end"] - sd["start"] + 1)
		var initial_cleared = int(total * rng.randf_range(0.2, 0.5))
		_faction_dynamic_state[sd["fid"]] = {
			"total": total,
			"cleared": initial_cleared,
		}
	_dynamic_initialized = true

## 根据势力动态状态更新NPC相位师进度
func _update_npc_progress_from_faction_state() -> void:
	for i in range(min(FACTION_RANGES.size(), _player_data.size())):
		var fid = FACTION_RANGES[i]["fid"]
		var faction_state = _faction_dynamic_state.get(fid, {"total": 0, "cleared": 0})
		var total = faction_state["total"]
		var cleared = faction_state["cleared"]

		var start_lv: int = FACTION_RANGES[i]["start"]
		var new_level = start_lv + cleared - 1
		if total > 0:
			new_level = clampi(new_level, start_lv, start_lv + total - 1)
		else:
			new_level = start_lv

		_player_data[i]["current_level"] = max(1, new_level)

	_player_data.sort_custom(func(a, b) -> bool:
		return a.get("current_level", 0) > b.get("current_level", 0)
	)
	for i in range(_player_data.size()):
		_player_data[i]["rank"] = i + 1
