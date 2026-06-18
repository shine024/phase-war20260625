extends RefCounted
class_name CityLocations
## v6.4 城市地点定义 — 365天循环剧情模式的城市地图
##
## 每个地点是一个按钮，玩家在不同时段/天数点击会触发不同事件。
## 地点按"全天开放"/"白天开放"/"夜间开放"区分时段可用性。

# ── 时段常量（与DayClock一致） ──────────────────────────────────────

const PHASE_ALL: Array[int] = [0, 1, 2, 3, 4]           ## 全天开放
const PHASE_DAYTIME: Array[int] = [0, 1]                 ## 仅白天（上午/下午）
const PHASE_NIGHT: Array[int] = [2, 3]                   ## 仅夜间（晚上/午夜）
const PHASE_EVENING_DAWN: Array[int] = [2, 3, 4]         ## 晚上/午夜/早晨

# ── 8个城市地点 ───────────────────────────────────────────────────

const LOCATIONS: Array[Dictionary] = [
	{
		"id": "command_center",
		"name": "指挥部",
		"icon": "⚑",
		"button_pos": Vector2(0.5, 0.45),      # 相对位置（0-1，用于响应式布局）
		"available_phases": PHASE_ALL,
		"available_from_day": 1,
		"description": "战略指挥中心，接受主线任务、查看全局态势",
		"actions": ["main_story", "quest_board"],
		"color": Color(0.0, 0.94, 1.0, 1.0),   # 青色
	},
	{
		"id": "market",
		"name": "中央市场",
		"icon": "⚖",
		"button_pos": Vector2(0.25, 0.3),
		"available_phases": PHASE_DAYTIME,
		"available_from_day": 1,
		"description": "交易资源，购买补给和卡牌",
		"actions": ["shop", "quest_board"],
		"color": Color(0.95, 0.85, 0.2, 1.0),  # 金色
	},
	{
		"id": "training_ground",
		"name": "训练场",
		"icon": "⚔",
		"button_pos": Vector2(0.75, 0.3),
		"available_phases": PHASE_ALL,
		"available_from_day": 1,
		"description": "进行实战训练，提升卡牌和符文",
		"actions": ["battle", "enhance"],
		"color": Color(0.9, 0.3, 0.3, 1.0),    # 红色
	},
	{
		"id": "intel_agency",
		"name": "情报局",
		"icon": "◈",
		"button_pos": Vector2(0.15, 0.55),
		"available_phases": PHASE_ALL,
		"available_from_day": 7,
		"description": "收集情报，解锁隐藏任务和相位线索",
		"actions": ["quest_board", "intel"],
		"color": Color(0.55, 0.36, 0.96, 1.0), # 紫色
	},
	{
		"id": "border_zone",
		"name": "边境哨所",
		"icon": "ǂ",
		"button_pos": Vector2(0.85, 0.55),
		"available_phases": PHASE_ALL,
		"available_from_day": 7,
		"description": "前线哨所，接取战斗任务和防御作战",
		"actions": ["battle", "quest_board"],
		"color": Color(0.2, 0.9, 0.4, 1.0),    # 绿色
	},
	{
		"id": "aether_tower",
		"name": "以太塔",
		"icon": "▲",
		"button_pos": Vector2(0.35, 0.7),
		"available_phases": PHASE_EVENING_DAWN,
		"available_from_day": 30,
		"description": "相位研究塔，深度符文研究（需势力声望）",
		"actions": ["rune_shop", "quest_board"],
		"color": Color(0.3, 0.6, 1.0, 1.0),    # 蓝色
	},
	{
		"id": "void_rift",
		"name": "虚空裂隙",
		"icon": "◉",
		"button_pos": Vector2(0.65, 0.7),
		"available_phases": PHASE_NIGHT,
		"available_from_day": 60,
		"description": "不稳定的空间裂隙，高风险高回报的挑战",
		"actions": ["boss_battle", "rune_drop"],
		"color": Color(0.7, 0.2, 0.9, 1.0),    # 深紫
	},
	{
		"id": "rest_area",
		"name": "休息区",
		"icon": "☾",
		"button_pos": Vector2(0.5, 0.85),
		"available_phases": PHASE_ALL,
		"available_from_day": 1,
		"description": "休息恢复，直接跳到第二天早晨",
		"actions": ["rest"],
		"color": Color(0.6, 0.6, 0.65, 1.0),   # 灰色
	},
]

# ── 查询接口 ───────────────────────────────────────────────────────

## 获取所有地点
static func get_all_locations() -> Array[Dictionary]:
	return LOCATIONS

## 按ID获取地点
static func get_location(location_id: String) -> Dictionary:
	for loc in LOCATIONS:
		if loc["id"] == location_id:
			return loc
	return {}

## 获取指定天数解锁的地点
static func get_available_locations(current_day: int, current_phase: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for loc in LOCATIONS:
		if current_day < int(loc.get("available_from_day", 1)):
			continue
		var phases: Array = loc.get("available_phases", PHASE_ALL)
		if not phases.has(current_phase):
			continue
		result.append(loc)
	return result

## 地点是否当前可用
static func is_location_available(location_id: String, current_day: int, current_phase: int) -> bool:
	var loc := get_location(location_id)
	if loc.is_empty():
		return false
	if current_day < int(loc.get("available_from_day", 1)):
		return false
	var phases: Array = loc.get("available_phases", PHASE_ALL)
	return phases.has(current_phase)

## 获取地点数量
static func get_location_count() -> int:
	return LOCATIONS.size()
