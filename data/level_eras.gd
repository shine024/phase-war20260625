extends RefCounted
class_name LevelEras
## 100 关 × 5 时代：一战 / 二战 / 冷战 / 现代 / 近未来
## 每关：波次数、每波刷新敌人数、波次间隔、掉落率倍数

const GC = preload("res://resources/game_constants.gd")

const LEVEL_COUNT: int = 100

# 使用 GameConstants 中的统一时代枚举
const ERA := GC.Era
# 向后兼容别名
const Era := ERA

## 每时代关数
const ERA_LEVELS: int = 20

## 时代内波次范围 [最小波, 最大波] - 调整波次数控制战斗时长
const ERA_WAVES: Dictionary = {
	Era.WW1: [3, 5],
	Era.WW2: [4, 7],     # 二战降低上限
	Era.COLD_WAR: [5, 8], # 冷战适度控制
	Era.MODERN: [6, 9],   # 现代避免过长
	Era.NEAR_FUTURE: [7, 10], # 近未来集中但不过度
}

## 时代内每波敌人数范围 [最小, 最大] - 调整以匹配玩家5单位上限
const ERA_SPAWN_COUNT: Dictionary = {
	Era.WW1: [1, 2],
	Era.WW2: [2, 3],
	Era.COLD_WAR: [2, 3],  # 冷战降低上限
	Era.MODERN: [2, 4],    # 现代降低上限
	Era.NEAR_FUTURE: [3, 4], # 近未来控制上限
}

## 波次间隔（秒）- 调整后期节奏，避免过快
const ERA_WAVE_INTERVAL: Dictionary = {
	Era.WW1: 14.0,
	Era.WW2: 13.0,
	Era.COLD_WAR: 12.0,
	Era.MODERN: 12.0,  # 维持现代节奏
	Era.NEAR_FUTURE: 11.0,  # 近未来略微加快但不过度
}

## 掉落率倍数（时代越靠后掉落越高）
const ERA_DROP_MULTIPLIER: Dictionary = {
	Era.WW1: 0.85,
	Era.WW2: 1.0,
	Era.COLD_WAR: 1.15,
	Era.MODERN: 1.25,
	Era.NEAR_FUTURE: 1.4,
}

## 每关「相位仪经验」插值锚点（时代内第 1 / 10 / 20 关），约 +10% 让成长反馈更明显
const ERA_XP_FIRST: Dictionary = {
	Era.WW1: 132,
	Era.WW2: 198,
	Era.COLD_WAR: 264,
	Era.MODERN: 330,
	Era.NEAR_FUTURE: 396,
}

const ERA_XP_MID: Dictionary = {
	Era.WW1: 330,
	Era.WW2: 495,
	Era.COLD_WAR: 660,
	Era.MODERN: 825,
	Era.NEAR_FUTURE: 990,
}

const ERA_XP_LAST: Dictionary = {
	Era.WW1: 550,
	Era.WW2: 825,
	Era.COLD_WAR: 1100,
	Era.MODERN: 1375,
	Era.NEAR_FUTURE: 1650,
}

static func get_era(level: int) -> int:
	var lv: int = clampi(level, 1, LEVEL_COUNT)
	var idx: int = int((lv - 1) / float(ERA_LEVELS))
	return clampi(idx, 0, Era.NEAR_FUTURE)

static func get_wave_total_for_level(level: int) -> int:
	var era: int = get_era(level)
	var lv: int = clampi(level, 1, LEVEL_COUNT)
	var in_era: int = ((lv - 1) % ERA_LEVELS) + 1  # 1..20
	var r: Array = ERA_WAVES.get(era, [3, 5])
	var min_w: int = int(r[0])
	var max_w: int = int(r[1])
	# 时代内线性：第1关=min，第20关=max
	var t: float = (in_era - 1) / float(ERA_LEVELS - 1) if ERA_LEVELS > 1 else 0.0
	return clampi(min_w + int((max_w - min_w) * t), min_w, max_w)

static func get_wave_interval_for_level(level: int) -> float:
	var era: int = get_era(level)
	return float(ERA_WAVE_INTERVAL.get(era, 12.0))

static func get_spawn_count_for_wave(level: int, wave_index: int) -> int:
	var era: int = get_era(level)
	var r: Array = ERA_SPAWN_COUNT.get(era, [1, 2])
	var min_c: int = int(r[0])
	var max_c: int = int(r[1])
	# 波次增长更温和，避免后期过度增长
	var wave_bonus: int = mini(int(wave_index / 4.0), 1)  # 每4波多1个，而非每3波
	var base: int = randi_range(min_c, max_c)
	return clampi(base + wave_bonus, 1, 5)  # 限制上限为5，匹配玩家单位上限


## 格子战术：单侧部署格上限与 BattleSlotGrid.SLOT_COUNT 同步
static func get_spawn_count_for_wave_card_grid(level: int, wave_index: int) -> int:
	const SLOT_CAP: int = BattleSlotGrid.SLOT_COUNT
	var era: int = get_era(level)
	var r: Array = ERA_SPAWN_COUNT.get(era, [1, 2])
	var min_c: int = maxi(2, int(r[0]))
	var max_c: int = mini(SLOT_CAP, maxi(min_c + 1, int(r[1]) + 1))
	var w: int = maxi(1, wave_index)
	var wave_bonus: int = mini(int((w - 1) / 2.0), 3)
	var base: int = randi_range(min_c, max_c)
	return clampi(base + wave_bonus, 2, SLOT_CAP)

static func get_drop_rate_multiplier(level: int) -> float:
	var era: int = get_era(level)
	return float(ERA_DROP_MULTIPLIER.get(era, 1.0))

static func get_era_name(era: int) -> String:
	match era:
		Era.WW1: return "一战"
		Era.WW2: return "二战"
		Era.COLD_WAR: return "冷战"
		Era.MODERN: return "现代"
		Era.NEAR_FUTURE: return "近未来"
	return ""

## 根据关卡返回本关基础相位仪经验（胜利后直接注入 PhaseInstrumentManager）
static func get_base_xp_for_level(level: int) -> int:
	var lv: int = clampi(level, 1, LEVEL_COUNT)
	var era: int = get_era(lv)
	var in_era: int = ((lv - 1) % ERA_LEVELS) + 1 # 1..20
	var xp1: float = float(ERA_XP_FIRST.get(era, 100))
	var xp10: float = float(ERA_XP_MID.get(era, xp1 * 2.0))
	var xp20: float = float(ERA_XP_LAST.get(era, xp10 * 1.5))
	if in_era <= 10:
		var t1: float = float(in_era - 1) / 9.0
		return int(round(lerpf(xp1, xp10, t1)))
	else:
		var t2: float = float(in_era - 11) / 9.0
		return int(round(lerpf(xp10, xp20, t2)))
