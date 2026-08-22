extends RefCounted
class_name LeaderboardData
## 排行榜数据层 (Model)
##
## 负责所有排行榜数据的获取、计算和缓存。
## 与 UI 完全解耦，可独立测试。
##
## 对外接口：
##   - get_faction_leaderboard() -> Array  (公司势力排名)
##   - get_npc_leaderboard() -> Array      (玩家+挑战者排名，基于真实进度)
##   - get_active_phase_masters() -> Array (NPC战斗配置)
##   - get_phase_master_config(name) -> Dictionary
##   - refresh() -> void

# NPC相位师战斗配置 —— 单一真理源在 data/npc_phase_masters.gd（此处仅委托）
const NpcPhaseMasters = preload("res://data/npc_phase_masters.gd")

# 各公司势力领地范围（静态配置，仅用于 FSM 不可用时的 fallback）
const FACTION_RANGES: Array = [
	{"fid": "iron_wall_corp",    "start": 0,  "end": 0,   "name": "钢壁防务"},
	{"fid": "nova_arms",         "start": 21, "end": 40,  "name": "新星兵工"},
	{"fid": "aether_dynamics",   "start": 41, "end": 60,  "name": "以太动力"},
	{"fid": "quantum_logistics", "start": 61, "end": 80,  "name": "量子后勤"},
	{"fid": "helix_recon",       "start": 81, "end": 90,  "name": "螺旋侦察"},
	{"fid": "void_research",     "start": 91, "end": 100, "name": "虚空相位"},
	{"fid": "frontier_union",    "start": 0,  "end": 0,   "name": "边境联合"},
]

# 缓存数据
var _faction_data: Array = []
var _player_data: Array = []

## 获取当前活跃的相位师配置（用于遭遇战卡牌选择，非排行榜显示）
func get_active_phase_masters() -> Array:
	return NpcPhaseMasters.get_all()

## 根据相位师名字获取配置
func get_phase_master_config(p_name: String) -> Dictionary:
	return NpcPhaseMasters.get_by_name(p_name)

## 获取公司势力排名数据
func get_faction_leaderboard() -> Array:
	if _faction_data.is_empty():
		_initialize_faction_data()
	return _faction_data.duplicate(true)

## 获取玩家+挑战者排名数据（基于真实进度，非硬编码NPC）
func get_npc_leaderboard() -> Array:
	if _player_data.is_empty():
		_initialize_player_data()
	return _player_data.duplicate(true)

## 刷新所有数据（重新读取真实游戏状态）
func refresh() -> void:
	_initialize_faction_data()
	_initialize_player_data()

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
			var total: int = max(0, e - s + 1) if (e >= s and s > 0) else 0
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

## 初始化玩家+挑战者排名数据（基于真实进度，非硬编码NPC）
func _initialize_player_data() -> void:
	_player_data.clear()

	# 玩家真实进度
	var player_max_level: int = 1
	var player_stars: int = 0
	var lpm: Node = _get_autoload_node("LevelProgressManager")
	if lpm and lpm.has_method("get_max_unlocked_level"):
		player_max_level = int(lpm.get_max_unlocked_level())
	if lpm and "level_stars" in lpm:
		for lv in range(1, player_max_level + 1):
			player_stars += int(lpm.level_stars.get(lv, 0))

	# 玩家势力
	var player_faction_id: String = ""
	var player_faction_name: String = "自由相位师"
	var fsm: Node = _get_autoload_node("FactionSystemManager")
	if fsm and fsm.has_method("get_active_faction"):
		player_faction_id = String(fsm.get_active_faction())
	if player_faction_id != "" and fsm and fsm.has_method("get_faction_info"):
		var pfac: Dictionary = fsm.get_faction_info(player_faction_id)
		player_faction_name = String(pfac.get("name", player_faction_name))

	_player_data.append({
		"rank": 0,
		"name": "我（玩家）",
		"current_level": player_max_level,
		"wins": player_stars,
		"win_rate": 0.0,
		"preferred_faction": player_faction_id,
		"faction_name": player_faction_name,
		"is_player": true,
	})

	# 各势力挑战者（基于真实占领数）
	if fsm and fsm.has_method("get_all_factions_info"):
		var all_factions: Array = fsm.get_all_factions_info()
		for fi in all_factions:
			var fid: String = fi.get("id", "")
			if fid.is_empty() or fid == player_faction_id:
				continue
			var controlled: Array = fi.get("controlled_levels", [])
			var territory: int = controlled.size()
			var challenger_level: int = 1
			if not controlled.is_empty():
				challenger_level = int(controlled.max())
			_player_data.append({
				"rank": 0,
				"name": "%s·挑战者" % String(fi.get("name", fid)),
				"current_level": challenger_level,
				"wins": territory * 2,
				"win_rate": 0.0,
				"preferred_faction": fid,
				"faction_name": String(fi.get("name", fid)),
				"is_player": false,
			})

	_player_data.sort_custom(func(a, b) -> bool:
		if a.get("current_level", 0) != b.get("current_level", 0):
			return a.get("current_level", 0) > b.get("current_level", 0)
		return a.get("wins", 0) > b.get("wins", 0)
	)
	for i in range(_player_data.size()):
		_player_data[i]["rank"] = i + 1

func _get_autoload_node(name: String) -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		var tree: SceneTree = loop as SceneTree
		if tree.root != null:
			return tree.root.get_node_or_null(name)
	return null
