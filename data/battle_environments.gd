extends RefCounted
class_name BattleEnvironments
## 战场环境定义：按关卡编号描述天气/地形/能量场/时间等
##
## 若某关未在 ENV_BY_LEVEL 中显式配置，将按时代给一个默认环境。

const LevelEras = preload("res://data/level_eras.gd")

const ENV_BY_LEVEL: Dictionary = {
	10: {
		"level": 10,
		"era": "WW1",
		"weather": "rain",
		"terrain": "city",
		"energy_field": "normal",
		"time_of_day": "dusk",
	},
	25: {
		"level": 25,
		"era": "WW2",
		"weather": "clear",
		"terrain": "plain",
		"energy_field": "low_field",
		"time_of_day": "day",
	},
	45: {
		"level": 45,
		"era": "COLD",
		"weather": "snow",
		"terrain": "city",
		"energy_field": "normal",
		"time_of_day": "day",
	},
	68: {
		"level": 68,
		"era": "MODERN",
		"weather": "storm",
		"terrain": "city",
		"energy_field": "high_field",
		"time_of_day": "night",
	},
	90: {
		"level": 90,
		"era": "NEAR_FUTURE",
		"weather": "sandstorm",
		"terrain": "plain",
		"energy_field": "nano_fog",
		"time_of_day": "dusk",
	},
}

static func get_for_level(level: int) -> Dictionary:
	var lv: int = clampi(level, 1, LevelEras.LEVEL_COUNT)
	if ENV_BY_LEVEL.has(lv):
		return (ENV_BY_LEVEL[lv] as Dictionary).duplicate(true)

	var era_enum: int = LevelEras.get_era(lv)
	var era_name: String = _era_to_string(era_enum)
	var env: Dictionary = _default_env_for_era(era_enum)
	env["level"] = lv
	env["era"] = era_name
	return env

static func _era_to_string(era_enum: int) -> String:
	match era_enum:
		LevelEras.Era.WW1:
			return "WW1"
		LevelEras.Era.WW2:
			return "WW2"
		LevelEras.Era.COLD_WAR:
			return "COLD"
		LevelEras.Era.MODERN:
			return "MODERN"
		LevelEras.Era.NEAR_FUTURE:
			return "NEAR_FUTURE"
	return "WW1"

static func _default_env_for_era(era_enum: int) -> Dictionary:
	match era_enum:
		LevelEras.Era.WW1:
			return {
				"weather": "clear",
				"terrain": "plain",
				"energy_field": "normal",
				"time_of_day": "day",
			}
		LevelEras.Era.WW2:
			return {
				"weather": "rain",
				"terrain": "plain",
				"energy_field": "normal",
				"time_of_day": "dusk",
			}
		LevelEras.Era.COLD_WAR:
			return {
				"weather": "snow",
				"terrain": "city",
				"energy_field": "normal",
				"time_of_day": "day",
			}
		LevelEras.Era.MODERN:
			return {
				"weather": "storm",
				"terrain": "city",
				"energy_field": "high_field",
				"time_of_day": "night",
			}
		LevelEras.Era.NEAR_FUTURE:
			return {
				"weather": "sandstorm",
				"terrain": "plain",
				"energy_field": "nano_fog",
				"time_of_day": "dusk",
			}
	# 默认兜底
	return {
		"weather": "clear",
		"terrain": "plain",
		"energy_field": "normal",
		"time_of_day": "day",
	}

