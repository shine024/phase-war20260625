extends RefCounted
class_name EnemyStatContext
## 敌人统一数值上下文：关卡、波次、档位、势力、可选难度。
##
## v8.2 简化：公式收敛为 档位 × 波数 [× 难度]。
## - base 属性表已烤进时代递进（一战→近未来 hp 5-7×），公式不加时代系数/关卡线性乘数。
## - 砍掉 master_stats / player_pressure（经典敌兵不再吃相位师属性 / 死乘区恒1.0）。
## - master_stats 字段保留供 apply_phase_master_to_unit_stats 兼容签名，但 resolve 链不再读。
## - v6.22: 占领势力加成乘区（faction_buff）随占领状态机退役删除。

var level: int = 1
var wave_index: int = 0
## v8.2: 档位（EnemyLoadoutTiers 四档常量），决定档位系数（1.20/1.30/1.46/1.66）。
## 由 make_default_context 按 level 算时代内进度 → get_tier_for_level_progress 填充。
var tier: int = 1
## [兼容保留，不再参与 resolve 链] 敌方相位师 stats 字典。产兵侧 apply_phase_master_to_unit_stats 仍可读。
var master_stats: Dictionary = {}
## [废弃·恒空] 预留的"我方养成反向影响敌难度"乘区，从未接通，恒返回空字典 → 乘子恒1.0。
var player_pressure: Dictionary = {}
## v6.22: faction_buff 字段已随占领状态机退役删除（旧档兼容无涉——该字段不入存档）。
## v7.x(A4): 全局玩家难度系数（easy 0.85 / normal 1.0 / hard 1.15），仅缩放敌方 HP+攻击。
## 由 make_default_context 从 settings.cfg 读取并填充；resolve_classic_enemy 在乘区链末尾乘上。
## 默认 1.0 → 单元测试用 EnemyStatContext.new() 不传难度时行为与历史版本完全一致（纯函数）。
var difficulty_multiplier: float = 1.0

## v7.x(敌方加成来源明细): 以下字段仅用于构建情报面板"加成来源"的可读标签，
## 不参与任何战斗数值计算。由 make_default_context 填充，单元测试构造的 ctx 这些字段保持默认。
var difficulty_name: String = "普通"        # 难度档名（普通/简单/困难）
# v6.22: faction_id/faction_level 标签字段已随占领状态机退役删除。
var is_phase_master_battle: bool = false     # 是否相位师遭遇战（仅标签用，resolve 链不再因它变化）


func _init(p_level: int = 1, p_wave: int = 0) -> void:
	level = maxi(1, p_level)
	wave_index = maxi(0, p_wave)
