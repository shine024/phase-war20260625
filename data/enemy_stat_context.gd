extends RefCounted
class_name EnemyStatContext
## 敌人统一数值上下文：关卡、波次、相位师属性、可选我方全局修正（与玩家 UnitStats 管线隔离）。

var level: int = 1
var wave_index: int = 0
## 敌方相位师 stats 字典（如 attack_power / defense），无则留空
var master_stats: Dictionary = {}
## 可选：我方对敌难度修正 { "hp_mul": 1.0, "attack_mul": 1.0, "speed_mul": 1.0 }，缺省键视为 1.0
var player_pressure: Dictionary = {}


func _init(p_level: int = 1, p_wave: int = 0) -> void:
	level = maxi(1, p_level)
	wave_index = maxi(0, p_wave)
