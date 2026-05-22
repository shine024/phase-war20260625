extends Resource
class_name UnitStats
## 单位数值：战斗单位卡的属性。
## v3 目标：由 `card_id` + 养成状态派生（见 docs/BATTLE_CARD_V3_SCHEMA.md §3）；
## 当前仍保留 platform/weapon 字段以兼容拆分式卡与战斗逻辑。

@export var platform_type: int = 0     # 底盘类型（决定移动/生存特性）
@export var weapon_type: int = 0       # 攻击类型（决定弹道/伤害模式）
@export var max_hp: float = 100.0
@export var move_speed: float = 80.0
## 格子战术护甲：参与 CardGridDamage 百分比减伤 def/(def+50)
@export var defense: float = 0.0
## 格子战术闪避率（0~1，侦察/隐匿等平台固有）
@export var dodge_chance: float = 0.0
@export var attack_damage: float = 10.0
@export var attack_range: float = 120.0
@export var attack_interval: float = 1.0
@export var is_stationary: bool = false  # 堡垒不移动

## 多武器槽（每项 Dictionary：weapon_type, damage, range, interval, timer）；与 UnitStatsTable.build_multi_stats 一致
var weapons: Array = []

# ── 卡牌特殊能力识别 ─────────────────────────
## 当前战斗单位卡的 card_id（用于战斗中判断特殊能力）
var card_id: String = ""
## 相位仪绿槽平台卡 id（改装次数、军衔、星级强化文案、平台专属能力等）
var platform_card_id: String = ""
## 该平台槽位已装配的武器卡 id 列表（无武器模式时可为空）
var weapon_card_ids: Array[String] = []

# ── 词条特殊属性（默认值表示"未启用"）──────────────────────
## 伤害减免（0.0~1.0，来自 platform_armor 词条）
@export var damage_reduction: float = 0.0

## 暴击率（0.0~1.0，来自 crit_chance 词条）
@export var crit_chance: float = 0.0

## 吸血率（0.0~1.0，来自 lifesteal 词条）
@export var lifesteal: float = 0.0

## 溅射伤害比例（0.0~1.0，来自 splash_dmg 词条）
@export var splash_damage: float = 0.0

## 穿甲率（0.0~1.0，来自 armor_break 词条）
@export var armor_penetration: float = 0.0

## 连锁触发概率（0.0~1.0，来自 chain_lightning 词条）
@export var chain_chance: float = 0.0

## 击杀护盾（每次击杀获得的护盾量，基于 max_hp 百分比）
@export var shield_on_kill: float = 0.0

## 每秒回血（基于 max_hp 百分比，来自 nano_regen 词条）
@export var hp_regen: float = 0.0

# ── 变异词条标记 ──────────────────────────────
## 是否有武器伤害变异（双倍伤害概率）
var has_weapon_dmg_mutation: bool = false

## 是否有攻速变异（连续3次攻击加成）
var has_weapon_atkspd_mutation: bool = false

## 是否有暴击变异（暴击恢复生命）
var has_crit_mutation: bool = false

## 是否有吸血变异（低血量时吸血翻倍）
var has_lifesteal_mutation: bool = false

## 是否有回血变异（低血量时回复翻倍）
var has_hp_regen_mutation: bool = false

## 是否有平台HP变异（高血量时防御加成）
var has_platform_hp_mutation: bool = false
