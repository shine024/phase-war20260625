extends RefCounted
class_name TruckTravel
## v26.19 移动基地行军数值真身：地形消耗 / 行程天数 / 引擎升级
## （BunkerManager 结算、世界地图行军规划弹窗、基地燃料卡三处共读；改数值只动本文件）
##
## 模型（停哪打哪；v26.25 起燃料定期自动回复 + 能量块 1:1 充能）：
##   燃料消耗 = clamp(ceil(距离px/48), 4, 60) × 目的地地形系数 ×（回程走熟路 ×0.5）
##   行程天数 = ceil(距离px / 速度)，速度 = 300 + 90 ×(引擎Lv-1)，至少 1 天
##   自动回复 = REGEN_BASE + REGEN_PER_LV ×(引擎Lv-1) /分钟（实时，离线/挂机都计时）
##   充能 = 能量块 → 燃料 1:1（基地发电机工位/行军弹窗，补满为止）
##   安全储备：燃料 - 本次消耗 < RESERVE_FLOOR 不予出车；睡觉快充 SLEEP_REFUEL/晚
##   引擎 Lv1-5：速度/罐容/回复速率随级提升；纳米+合金付费升级

const TANK_BASE := 100
const TANK_PER_LV := 25
const SLEEP_REFUEL := 45
const RESERVE_FLOOR := 10
const SPEED_BASE := 300.0
const SPEED_PER_LV := 90.0
const ENGINE_MAX_LV := 5
## v26.25 燃料自动回复速率（每分钟；引擎每级再 +1）
const REGEN_BASE_PER_MIN := 3.0
const REGEN_PER_LV_PER_MIN := 1.0
## v26.21 实时行军换算：1 天行程 = 12 秒真实时间（出发即走，离线/切场景也计时；
## v26.29 由 60 秒提速 5 倍——用户实测原速过慢）
const SECONDS_PER_DAY := 12.0

## 升级到下一级的资源价（索引=当前等级 1..4）；短名对齐 BunkerRoomDefs.RES
const ENGINE_UPGRADES := [
	{"nano": 150, "alloy": 80},
	{"nano": 300, "alloy": 160},
	{"nano": 550, "alloy": 300},
	{"nano": 900, "alloy": 500},
]

## 目的地地形系数（era1-5；名称对齐 truck_base.ERAS 驻防地域）
const TERRAINS := [
	{"name": "索姆战壕", "mult": 1.0},
	{"name": "东部砖镇", "mult": 1.1},
	{"name": "沙漠前哨", "mult": 1.3},
	{"name": "浮岩荒原", "mult": 1.2},
	{"name": "相位极光带", "mult": 1.5},
]

const LayoutS11 = preload("res://data/world_map_layout_s11.gd")

static func era_of(level: int) -> int:
	return clampi((clampi(level, 1, 100) - 1) / 20 + 1, 1, 5)

static func terrain_of(level: int) -> Dictionary:
	return TERRAINS[era_of(level) - 1]

static func point_for_level(level: int) -> Vector2:
	var pts: Array = LayoutS11.POINTS
	var idx := clampi(level, 1, 100) - 1
	if idx < 0 or idx >= pts.size():
		return Vector2.ZERO
	return pts[idx]

static func dist_between(a: int, b: int) -> float:
	return point_for_level(a).distance_to(point_for_level(b))

static func speed_for(engine_level: int) -> float:
	return SPEED_BASE + SPEED_PER_LV * float(clampi(engine_level, 1, ENGINE_MAX_LV) - 1)

## v26.25 燃料自动回复速率（每分钟；引擎升级同时提速）
static func regen_per_minute(engine_level: int) -> float:
	return REGEN_BASE_PER_MIN + REGEN_PER_LV_PER_MIN * float(clampi(engine_level, 1, ENGINE_MAX_LV) - 1)

## 补满油罐还差多少（能量块 1:1 充能的"补满"语义用）
static func fuel_needed_to_fill(cur: float, cap: int) -> int:
	return maxi(0, ceili(float(cap) - cur))

## 燃料不够出车时，自动回复到够用还需多少分钟（拒绝提示 ETA 用）
static func regen_minutes_until(cur: float, needed: int, engine_level: int) -> int:
	var deficit: float = float(needed) - cur
	if deficit <= 0.0:
		return 0
	return maxi(1, ceili(deficit / regen_per_minute(engine_level)))

## 单段行军燃料消耗（回程走熟路半价）
static func fuel_cost(from_level: int, to_level: int) -> int:
	var base := int(ceil(dist_between(from_level, to_level) / 48.0))
	base = clampi(base, 4, 60)
	var mult: float = float(terrain_of(to_level).get("mult", 1.0))
	if to_level < from_level:
		mult *= 0.5
	return int(ceil(float(base) * mult))

## 行程天数（引擎等级提速），至少 1 天
static func travel_days(from_level: int, to_level: int, engine_level: int) -> int:
	var days := int(ceil(dist_between(from_level, to_level) / speed_for(engine_level)))
	return maxi(days, 1)

## 升级到 engine_level+1 的价目；满级/非法返回 {}
static func upgrade_cost(engine_level: int) -> Dictionary:
	var idx := clampi(engine_level, 1, ENGINE_MAX_LV) - 1
	if engine_level >= ENGINE_MAX_LV or idx < 0 or idx >= ENGINE_UPGRADES.size():
		return {}
	return ENGINE_UPGRADES[idx]
