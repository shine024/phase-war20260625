class_name TowerDefinitions
## 爬塔模式数据定义：层数配置、难度曲线、起始套件

const MAX_FLOOR := 30
const ERAS_PER_TOWER := 5
const FLOORS_PER_ERA := 6

# ── 起始套件 ──────────────────────────────────────────────
const STARTING_LOADOUTS := {
	"default": {
		"id": "default",
		"name": "标准相位仪",
		"description": "均衡配置，适合新手",
		"platforms": ["platform_ww1_light", "platform_ww1_medium"],
		"weapons": ["weapon_ww1_rifle", "weapon_ww1_mg"],
		"starting_hp": 100,
		"starting_gold": 0,
		"energy_bonus": 0,
	},
	"scout": {
		"id": "scout",
		"name": "侦察相位仪",
		"description": "快速部署，低消耗",
		"platforms": ["platform_ww1_light", "platform_ww1_light"],
		"weapons": ["weapon_ww1_rifle", "weapon_ww1_rifle"],
		"starting_hp": 80,
		"starting_gold": 0,
		"energy_bonus": 15,
	},
	"heavy": {
		"id": "heavy",
		"name": "重装相位仪",
		"description": "高生命，强力单位",
		"platforms": ["platform_ww1_heavy"],
		"weapons": ["weapon_ww1_mg", "weapon_ww1_mg"],
		"starting_hp": 130,
		"starting_gold": 0,
		"energy_bonus": -10,
	},
}

# ── Boss 层定义 ────────────────────────────────────────────
const BOSS_FLOORS := [10, 20, 30]
const ELITE_FLOORS := [5, 15, 25]
const REST_FLOORS := [7, 14, 21, 28]
const SHOP_FLOORS := [8, 16, 24]

# ── 时代映射 ──────────────────────────────────────────────
const ERA_NAMES := ["ww1", "ww2", "cold", "modern", "future"]


## 获取层数对应的时代索引 (0-4)
static func floor_to_era(floor_num: int) -> int:
	return clampi(floori((floor_num - 1) / float(FLOORS_PER_ERA)), 0, ERAS_PER_TOWER - 1)


## 获取层数对应的虚拟关卡（用于敌人类型选取）
static func floor_to_virtual_level(floor_num: int) -> int:
	var era := floor_to_era(floor_num)
	var floor_in_era := (floor_num - 1) % FLOORS_PER_ERA
	return era * 20 + 8 + floor_in_era * 2


## 获取层数类型
static func get_floor_type(floor_num: int) -> String:
	if floor_num in BOSS_FLOORS:
		return "boss"
	if floor_num in ELITE_FLOORS:
		return "elite"
	if floor_num in REST_FLOORS:
		return "rest"
	if floor_num in SHOP_FLOORS:
		return "shop"
	if floor_num >= 3 and floor_num % 4 == 3:
		return "event"
	return "normal"


## 获取完整层配置
static func get_floor_config(floor_num: int) -> Dictionary:
	var floor_type := get_floor_type(floor_num)
	var era := floor_to_era(floor_num)
	return {
		"floor": floor_num,
		"era": era,
		"floor_type": floor_type,
		"wave_total": _calc_wave_total(floor_num, floor_type),
		"wave_interval": _calc_wave_interval(floor_num, floor_type),
		"enemy_multiplier": _calc_enemy_multiplier(floor_num, floor_type),
		"enemy_count_per_wave": _calc_enemy_count(floor_num, floor_type),
		"virtual_level": floor_to_virtual_level(floor_num),
		"score_per_kill": 10 + floor_num * 2,
	}


## 获取下一层编号（考虑特殊层类型）
static func get_next_floor(current_floor: int) -> int:
	return mini(current_floor + 1, MAX_FLOOR)


## 是否是最后一层
static func is_final_floor(floor_num: int) -> bool:
	return floor_num >= MAX_FLOOR


## ── 内部计算 ──────────────────────────────────────────────

static func _calc_wave_total(floor_num: int, floor_type: String) -> int:
	match floor_type:
		"boss":
			return 1
		"elite":
			return 3 + floori(floor_num / 8)
		"rest", "shop", "event":
			return 0  # 非战斗层
		_:
			return 3 + floori(floor_num / 5)


static func _calc_wave_interval(floor_num: int, floor_type: String) -> float:
	match floor_type:
		"boss":
			return 30.0  # Boss 不刷新波次
		"elite":
			return maxf(8.0, 13.0 - floor_num * 0.12)
		_:
			return maxf(7.0, 13.0 - floor_num * 0.15)


static func _calc_enemy_multiplier(floor_num: int, floor_type: String) -> float:
	var base := 1.0 + floor_num * 0.035
	match floor_type:
		"boss":
			return base * 2.0
		"elite":
			return base * 1.5
		_:
			return base


static func _calc_enemy_count(floor_num: int, floor_type: String) -> int:
	match floor_type:
		"boss":
			return 1  # Boss 只刷一个
		"elite":
			return 2 + floori(floor_num / 12)
		_:
			return 1 + floori(floor_num / 7)
