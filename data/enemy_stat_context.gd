extends RefCounted
class_name EnemyStatContext
## 敌人统一数值上下文：关卡、波次、相位师属性、可选我方全局修正（与玩家 UnitStats 管线隔离）。

var level: int = 1
var wave_index: int = 0
## 敌方相位师 stats 字典（如 attack_power / defense），无则留空
var master_stats: Dictionary = {}
## 可选：我方对敌难度修正 { "hp_mul": 1.0, "attack_mul": 1.0, "speed_mul": 1.0 }，缺省键视为 1.0
var player_pressure: Dictionary = {}
## v6.9: 占领势力对敌人的加成 { "hp_mul": 1.0, "attack_mul": 1.0, "speed_mul": 1.0 }
## 由 make_default_context 按 LevelInformation.get_level_faction() + FactionSystemManager.get_faction_level() 填充
## 无主之地（1-20关）或未知势力留空，resolve_classic_enemy 视为全 1.0（无加成）
var faction_buff: Dictionary = {}
## v7.x(A4): 全局玩家难度系数（easy 0.85 / normal 1.0 / hard 1.15），仅缩放敌方 HP+攻击。
## 由 make_default_context 从 settings.cfg 读取并填充；resolve_classic_enemy 在乘区链末尾乘上。
## 默认 1.0 → 单元测试用 EnemyStatContext.new() 不传难度时行为与历史版本完全一致（纯函数）。
var difficulty_multiplier: float = 1.0

## v7.x(敌方加成来源明细): 以下字段仅用于构建情报面板"加成来源"的可读标签，
## 不参与任何战斗数值计算。由 make_default_context 填充，单元测试构造的 ctx 这些字段保持默认。
var difficulty_name: String = "普通"        # 难度档名（普通/简单/困难）
var faction_id: String = ""                  # 占领势力ID（空=无主之地）
var faction_level: int = 0                   # 占领势力等级
var is_phase_master_battle: bool = false     # 是否相位师遭遇战（决定 master_stats 来源标签）


func _init(p_level: int = 1, p_wave: int = 0) -> void:
	level = maxi(1, p_level)
	wave_index = maxi(0, p_wave)
