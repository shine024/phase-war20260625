extends Resource
class_name UnitStats
## 单位数值：战斗单位卡的属性。
##
## v3 重构：由 CardResource 的战斗卡字段直接派生（era + combat_kind + base_*）。
## 保留旧 platform_type/weapon_type 字段以兼容过渡期，新代码不应写入。

# ─────────────────────────────────────────────
#  核心属性（由 CardResource 战斗卡字段派生）
# ─────────────────────────────────────────────

@export var max_hp: float = 100.0
@export var move_speed: float = 80.0
## 格子战术护甲：参与 CardGridDamage 百分比减伤 def/(def+50)
@export var defense: float = 0.0
## 格子战术闪避率（0~1，轻装型固有）
@export var dodge_chance: float = 0.0
@export var attack_range: float = 120.0
@export var attack_interval: float = 1.0
@export var is_stationary: bool = false  # 炮台不移动

## @compat 兼容属性：attack_damage 读写映射到 attack_light
## 旧代码仍然读写 stats.attack_damage，内部等价于 attack_light
var attack_damage: float = 0.0:
	set(v):
		attack_light = v
	get:
		return attack_light

## 武器类型（GameConstants.WeaponType：DIRECT/INDIRECT/AERIAL）
var weapon_type: int = 0

## 部署速度（0-7，越大越快进入战场）
var deploy_speed: int = 3

## 攻击维度（对不同类型单位的伤害）
@export var attack_light: float = 0.0   # 对轻装
@export var attack_armor: float = 0.0   # 对装甲
@export var attack_air: float = 0.0     # 对空中

## v5.0: 每种攻击目标独立的攻速参数
## 对轻装攻击参数
var attack_light_speed: float = 1.0   # 次/秒
var attack_light_windup: float = 0.2    # 前摇（秒）
var attack_light_active: float = 0.1    # 动作（秒）

## 对装甲攻击参数
var attack_armor_speed: float = 1.0   # 次/秒
var attack_armor_windup: float = 0.2  # 前摇（秒）
var attack_armor_active: float = 0.1   # 动作（秒）

## 对空中攻击参数
var attack_air_speed: float = 1.0   # 次/秒
var attack_air_windup: float = 0.2   # 前摇（秒）
var attack_air_active: float = 0.1    # 动作（秒）

## 防御维度（对不同类型单位攻击的防御）- 三攻三防系统（v6.2 对齐）
## v6.2: 防御维度与攻击维度对齐——按"攻击者的单位类型"选取防御值
## defense_light = 防轻装单位(LIGHT/SUPPORT)攻击
## defense_armor = 防装甲单位(ARMOR/FORT)攻击
## defense_air   = 防空中单位(AIR)攻击
@export var defense_light: float = 0.0  # 防轻装单位攻击
@export var defense_armor: float = 0.0  # 防装甲单位攻击
@export var defense_air: float = 0.0    # 防空中单位攻击

## 多武器槽（每项 Dictionary：damage, range, interval, timer）
var weapons: Array = []

## 武器槽位数组（3个槽位：轻装/装甲/对空）
## 从 CardResource 同步而来，用于战斗中选择对应武器
var weapon_slots: Array = []

# ─────────────────────────────────────────────
#  身份字段
# ─────────────────────────────────────────────

## 当前战斗单位卡的 card_id（用于战斗中判断特殊能力）
var card_id: String = ""

## 时代（GameConstants.Era）
var era: int = 0

## 战斗定位（0=轻装/1=装甲/2=支援/3=空中/4=堡垒）
var combat_kind: int = 0

## 单位子类（v6.2: GameConstants.UnitSubType，用于战斗定位差异化修正）
## NONE=普通单位, ARTILLERY=火炮, SUPPORT=辅助, FORT=堡垒, ANTI_AIR=防空特化
var unit_subtype: int = 0

## 战力（进化门槛用，v5.0新增）
var power: int = 0

## 强化等级 0-10（v5.0）
var enhance_level: int = 0

## 武器外观标签（纯显示）
var weapon_label: String = ""

# ─────────────────────────────────────────────
#  旧字段（deprecated，保留兼容）
# ─────────────────────────────────────────────

## @deprecated 旧底盘类型，新代码用 combat_kind
@export var platform_type: int = 0

## @deprecated 旧攻击类型（已废弃，保留用于兼容）
## 新代码使用新的 weapon_type 变量存储 WeaponTypeNew 枚举值
@export var legacy_weapon_type: int = 0

## @deprecated 旧平台卡 id，新代码用 card_id
var platform_card_id: String = ""

## @deprecated 旧武器卡 id 列表
var weapon_card_ids: Array[String] = []

# ─────────────────────────────────────────────
#  词条特殊属性（默认值表示"未启用"）
# ─────────────────────────────────────────────

## 伤害减免（0.0~1.0，来自 platform_armor 词条）
@export var damage_reduction: float = 0.0

## 暴击率（0.0~1.0，来自 crit_chance 词条）
@export var crit_chance: float = 0.0

## 暴击伤害加成（来自 crit_dmg_up 词条；基础暴击1.5x，每级+0.2x）
@export var crit_damage_bonus: float = 0.0

## 吸血率（0.0~1.0，来自 lifesteal 词条）
@export var lifesteal: float = 0.0

## 溅射伤害比例（0.0~1.0，来自 splash_dmg 词条）
@export var splash_damage: float = 0.0

## 穿甲率（0.0~1.0，来自 armor_break 词条）
@export var armor_penetration: float = 0.0

## v6.2: 条件型穿甲（相克 MOD 用）—— 仅对特定单位类型生效
## armor_pen_vs_light: 仅对 LIGHT/SUPPORT 目标的防御生效
## armor_pen_vs_armor: 仅对 ARMOR/FORT 目标的防御生效
## armor_pen_vs_air:   仅对 AIR 目标的防御生效
## 在 take_damage 中按自身 combat_kind 选取并叠加到基础 armor_penetration
var armor_pen_vs_light: float = 0.0
var armor_pen_vs_armor: float = 0.0
var armor_pen_vs_air: float = 0.0

## v6.6: 条件型对堡垒伤害加成（来自 attack_fort 改造，如温压弹/爆破装置）
## FORT 目标在 get_attack_vs() 被归入 ARMOR 维度吃 attack_armor，
## 此字段为额外的对堡垒特攻乘数：实际伤害 = attack_armor × (1 + attack_fort_bonus)
var attack_fort_bonus: float = 0.0

## v6.6: 溅射半径加成（来自 splash_radius 改造，如子母弹/近炸引信）
## _apply_splash 的半径 = 80 × (1 + splash_radius_bonus)，默认 0 时与原硬编码行为一致
var splash_radius_bonus: float = 0.0

## v6.6: 主目标伤害惩罚（来自 single_target_penalty 改造，值是负小数）
## 子母弹等范围武器的单目标伤害平衡项：主目标伤害 × (1 + single_target_penalty)
var single_target_penalty: float = 0.0

## 连锁触发概率（0.0~1.0，来自 chain_lightning 词条）
@export var chain_chance: float = 0.0

## 击杀护盾（每次击杀获得的护盾量，基于 max_hp 百分比）
@export var shield_on_kill: float = 0.0

## 每秒回血（基于 max_hp 百分比，来自 nano_regen 词条）
@export var hp_regen: float = 0.0

# ─────────────────────────────────────────────
#  变异词条标记
# ─────────────────────────────────────────────

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

# ─────────────────────────────────────────────
#  势力变体特殊属性（由 FactionCardGenerator 注入）
# ─────────────────────────────────────────────

## 势力命中精度加成（0.0~0.50，降低敌方闪避效果）
var faction_accuracy_bonus: float = 0.0

## 势力法则效果加成（倍率，1.0=无加成）
var faction_effect_bonus: float = 0.0

## 技能树特殊效果标记列表（由战斗系统按需读取）
var skill_tree_specials: Array = []

## v6.2: 根据目标单位类型获取有效穿甲率（基础 + 条件型）
## attacker_combat_kind 是攻击者自身类型（用于将来按攻击者类型限制）；
## target_combat_kind 决定激活哪个条件穿甲。
func get_effective_armor_penetration(target_combat_kind: int) -> float:
	var pen: float = armor_penetration  # 基础穿甲（对所有目标生效）
	# 条件型穿甲：按目标单位类型激活
	var is_light: bool = (target_combat_kind == 0 or target_combat_kind == 2)  # LIGHT/SUPPORT
	var is_armor: bool = (target_combat_kind == 1 or target_combat_kind == 4)  # ARMOR/FORT
	var is_air: bool = (target_combat_kind == 3)  # AIR
	if is_light:
		pen += armor_pen_vs_light
	if is_armor:
		pen += armor_pen_vs_armor
	if is_air:
		pen += armor_pen_vs_air
	return clampf(pen, 0.0, 1.0)

## 根据目标类型获取对应武器
## v6.2: SUPPORT 归入 LIGHT 槽、FORT 归入 ARMOR 槽（攻防维度对齐）
func get_weapon_for_target(target_combat_kind: int) -> WeaponResource:
	if weapon_slots.is_empty():
		return null

	const GC = preload("res://resources/game_constants.gd")
	match target_combat_kind:
		GC.CombatKind.LIGHT, GC.CombatKind.SUPPORT:
			return weapon_slots[0] if weapon_slots.size() > 0 else null
		GC.CombatKind.ARMOR, GC.CombatKind.FORT:
			return weapon_slots[1] if weapon_slots.size() > 1 else null
		GC.CombatKind.AIR:
			return weapon_slots[2] if weapon_slots.size() > 2 else null
		_:
			return weapon_slots[0] if weapon_slots.size() > 0 else null
