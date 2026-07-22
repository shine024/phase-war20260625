## 游戏常量：能量、刷新间隔、单位上限等
extends RefCounted
class_name GameConstants

# 能量
const ENERGY_MAX: float = 100.0
const ENERGY_START: float = 100.0
const ENERGY_REGEN_PER_SEC: float = 1.0
const PHASE_BASE_DRAIN_PER_SEC: float = 0.5

# 单位
const PLAYER_SPAWN_INTERVAL: float = 10.0
const PLAYER_MAX_UNITS: int = 6
const ENEMY_SPAWN_INTERVAL: float = 12.0
const ENEMY_WAVE_INTERVAL: float = 12.0
const ENEMY_MAX_UNITS: int = 6

## 战斗内：场上每名侦察/隐匿平台（SCOUT、STEALTH）提供的加成系数
const RECON_FRAGMENT_BONUS_PER_UNIT: float = 0.10
const RECON_FRAGMENT_BONUS_CAP: float = 0.50

# 相位仪槽位
const PHASE_SLOT_COUNT: int = 4

## 格子战术：设计基准分辨率
const CARD_GRID_REFERENCE_SCREEN_WIDTH_PX: int = 1280
const CARD_GRID_REFERENCE_SCREEN_HEIGHT_PX: int = 720
const CARD_GRID_BATTLE_VIEWPORT_HEIGHT_PX: float = 580.0
const CARD_GRID_SCREEN_REF_HEIGHT_CM: float = 18.0
const CARD_GRID_ENLISTED_BASE_HEIGHT_CM: float = 1.5
const CARD_GRID_BATTLEFIELD_DRAW_SCALE_MULTIPLIER: float = 2.35

## 初始知识值倍率
const NEW_GAME_STARTER_LAW_SHARD_AMOUNT: int = 50
const NEW_GAME_STARTER_ACTIVE_LAW_IDS: Array[String] = ["flame_front_bombard", "thunder_chain_discharge"]
const NEW_GAME_STARTER_PASSIVE_LAW_IDS: Array[String] = ["steel_fortify_protocol", "flame_afterburn"]

static func get_all_new_game_starter_law_ids() -> Array[String]:
	var out: Array[String] = []
	out.append_array(NEW_GAME_STARTER_ACTIVE_LAW_IDS)
	out.append_array(NEW_GAME_STARTER_PASSIVE_LAW_IDS)
	return out

# @deprecated 旧平台类型枚举
enum PlatformType {
	HOUND,
	GUARD,
	TITAN,
	FORTRESS,
	RADAR,
	SCOUT,
	RAIDER,
	SIEGE,
	CARRIER,
	MEDIC,
	STEALTH,
	OMEGA_PLATFORM,
	COMMAND
}

# 武器类型枚举（基于攻击方式）
enum WeaponType {
	DIRECT = 0,
	INDIRECT = 1,
	AERIAL = 2,
	SUPPORT = 3
}

# v6.6: 统一曲射武器判定 —— 与 bullet.gd _configure_behavior 的 _is_indirect 分支对齐
# 含新枚举 INDIRECT(1)/AERIAL(2)，以及改造可能写入的 legacy 曲射值
# ROCKET(3)/FLAK(7)/MISSILE(9)（见 WeaponTypeLegacy）
# 修复前 AI 侧仅判 [INDIRECT, AERIAL]，导致 MISSILE(9) 等改造武器被误判为直射，
# 与其曲射弹道行为(_is_indirect=true)矛盾
static func is_indirect_weapon_type(wt: int) -> bool:
	return wt == WeaponType.INDIRECT or wt == WeaponType.AERIAL or wt in [3, 7, 9]

# v7.x: legacy 12 值武器类型（WeaponTypeLegacy）→ 新 4 值 WeaponType 映射。
# 敌方 archetype 配的是 legacy 值（0/1/2/3/7/9…），而 TargetSelection.select_target
# 用新枚举（0=DIRECT/1=INDIRECT/2=AERIAL）分派。这里集中映射，避免敌兵(enemy_unit.gd)
# 与相位师产兵(enemy_phase_field_driver.gd)各维护一份漂移。
# 规则：空中平台(is_aircraft=true)→AERIAL；曲射类(ROCKET=3/FLAK=7/MISSILE=9/RAIL=11)→INDIRECT；其余→DIRECT
# 与 is_indirect_weapon_type 的曲射判定保持一致（RAIL=11 仅在此处算 INDIRECT，因索敌需要差异化）。
static func legacy_weapon_to_new_weapon_type(legacy_wt: int, is_aircraft: bool = false) -> int:
	if is_aircraft:
		return int(WeaponType.AERIAL)
	if legacy_wt == 3 or legacy_wt == 7 or legacy_wt == 9 or legacy_wt == 11:
		return int(WeaponType.INDIRECT)
	return int(WeaponType.DIRECT)

# 战斗定位枚举（单位类型）
# v6.2: 攻防维度对齐后，攻防计算上 SUPPORT 归入 LIGHT、FORT 归入 ARMOR
#       （参见 AttackCalculator.get_attack_vs / get_defense_vs 的 match 分组）
#       CombatKind 保留 5 值用于显示/索敌差异化；主类归属由 UnitSubType 标记区分。
enum CombatKind {
	LIGHT = 0,
	ARMOR = 1,
	SUPPORT = 2,
	AIR = 3,
	FORT = 4
}

# 单位子类标记（v6.2: 配合"3主类+子类"设计）
# 主类归属：LIGHT 主类含 ARTILLERY/SUPPORT/ANTI_AIR 子类；ARMOR 主类含 FORT 子类
# 用于战斗定位差异化修正（如火炮不享闪避、堡垒额外HP加成）
enum UnitSubType {
	NONE = 0,       # 默认（纯轻装步兵 / 纯装甲坦克 / 纯空中）
	ARTILLERY = 1,  # 火炮（轻装主类）：远射程，无闪避
	SUPPORT = 2,    # 辅助/支援（轻装主类）：机枪巢、工兵等
	FORT = 3,       # 堡垒（装甲主类）：超高HP+防御
	ANTI_AIR = 4,   # 防空特化（轻装主类）：专防空，高 def_air
}

# 索敌方式枚举
enum TargetingMode {
	NEAREST_FIRST = 0,
	FARTHEST_FIRST = 1
}

## 战斗类型到索敌方式的映射
static func get_targeting_mode_for_combat_kind(combat_kind: int) -> int:
	match combat_kind:
		CombatKind.SUPPORT:
			return TargetingMode.FARTHEST_FIRST
		CombatKind.AIR:
			return TargetingMode.FARTHEST_FIRST
		CombatKind.FORT:
			return TargetingMode.FARTHEST_FIRST
		_:
			return TargetingMode.NEAREST_FIRST

# 旧武器类型枚举
enum WeaponTypeLegacy {
	SMG,
	RIFLE,
	MG,
	ROCKET,
	PISTOL,
	SHOTGUN,
	SNIPER,
	FLAK,
	LASER,
	MISSILE,
	OMEGA_CANNON,
	RAIL_CANNON
}

# 卡片类型
enum CardType {
	COMBAT_UNIT = 0,
	ENERGY = 1,
	LAW = 2,
	PLATFORM = 3,
	WEAPON = 4,
	COMBINED = 5
}

# 时代枚举
enum Era {
	WW1,
	WW2,
	COLD_WAR,
	MODERN,
	NEAR_FUTURE
}

const RealWorldUnitLabels = preload("res://data/real_world_unit_labels.gd")

static func get_weapon_type_name(weapon_type: int) -> String:
	return RealWorldUnitLabels.weapon_kind_long(weapon_type)

static func get_weapon_type_short(weapon_type: int) -> String:
	return RealWorldUnitLabels.weapon_kind_short(weapon_type)

static func get_card_type_name(card_type: int) -> String:
	match card_type:
		CardType.COMBAT_UNIT: return "战斗卡"
		CardType.ENERGY: return "能量卡"
		CardType.LAW: return "法则卡"
		CardType.PLATFORM: return "战斗卡"
		CardType.WEAPON: return "战斗卡"
		CardType.COMBINED: return "战斗卡"
		_: return "未知卡片"

static func get_rarity_name(rarity: String) -> String:
	match rarity:
		"common": return "普通"
		"uncommon": return "优秀"
		"rare": return "稀有"
		"epic": return "史诗"
		"legendary": return "传说"
		"mythic": return "神话"
		_: return "普通"

# 稀有度配色（全项目唯一权威源，与 DesignTokens.COLOR_RARITY_* 数值一致）
# common 枪铁灰 / uncommon 钢绿 / rare 电蓝 / epic 紫 / legendary 琥珀 / mythic 红
# 所有其他处的稀有度色必须透传本函数，禁止再定义本地副本。
static func get_rarity_color(rarity: String) -> Color:
	match rarity:
		"common": return Color(0.420, 0.463, 0.569, 1.0)    # #6b7691 枪铁灰
		"uncommon": return Color(0.133, 0.773, 0.369, 1.0)  # #22c55e 钢绿
		"rare": return Color(0.220, 0.741, 0.973, 1.0)      # #38bdf8 电蓝
		"epic": return Color(0.753, 0.518, 0.988, 1.0)      # #c084fc 紫
		"legendary": return Color(0.961, 0.620, 0.043, 1.0) # #f59e0b 琥珀
		"mythic": return Color(0.937, 0.267, 0.267, 1.0)    # #ef4444 红
		_: return Color(0.420, 0.463, 0.569, 1.0)

static func get_era_name(era: int) -> String:
	match era:
		Era.WW1: return "一战"
		Era.WW2: return "二战"
		Era.COLD_WAR: return "冷战"
		Era.MODERN: return "现代"
		Era.NEAR_FUTURE: return "近未来"
		_: return "未知时代"

static func get_era_short(era: int) -> String:
	match era:
		Era.WW1: return "WW1"
		Era.WW2: return "WW2"
		Era.COLD_WAR: return "COLD"
		Era.MODERN: return "MODERN"
		Era.NEAR_FUTURE: return "FUTURE"
		_: return "???"

static func get_era_for_level(level: int) -> int:
	var lv: int = clampi(level, 1, 100)
	if lv >= 81: return Era.NEAR_FUTURE
	elif lv >= 61: return Era.MODERN
	elif lv >= 41: return Era.COLD_WAR
	elif lv >= 21: return Era.WW2
	else: return Era.WW1

static func get_level_in_era(level: int) -> int:
	var lv: int = clampi(level, 1, 100)
	return ((lv - 1) % 20) + 1

static func get_era_prefix(era: int) -> String:
	match era:
		Era.WW1: return "ww1"
		Era.WW2: return "ww2"
		Era.COLD_WAR: return "cold"
		Era.MODERN: return "modern"
		Era.NEAR_FUTURE: return "near"
		_: return "ww1"

static func era_from_prefix(prefix: String) -> int:
	match prefix:
		"ww1": return Era.WW1
		"ww2": return Era.WW2
		"cold": return Era.COLD_WAR
		"modern": return Era.MODERN
		"near": return Era.NEAR_FUTURE
		_: return Era.WW1

## 游戏平衡常量
const PHASE_MASTER_ENCOUNTER_CHANCE: float = 0.15
const NANO_MATERIAL_BASE_REWARD: int = 5
const NANO_MATERIAL_PER_LEVEL_EARLY: float = 1.5
const NANO_MATERIAL_MAX_REWARD: int = 150

## v6.0: 情报驱动系统常量
const ENABLE_INTEL_DIMENSIONS: bool = true
const ENABLE_ENEMY_ORIGIN_MODS: bool = true
const ENABLE_INTEL_EVOLUTION: bool = true

const ENEMY_ORIGIN_MOD_SLOT_NAME: String = "D"
const ENEMY_ORIGIN_MOD_SLOT_UNLOCK_INTEL: float = 0.30
const ENEMY_ORIGIN_MOD_MAX_TIER: int = 3
const EOM_FRAGMENT_DROP_CHANCE: float = 0.25
const EOM_FRAGMENT_PER_DROP: int = 1

const INTEL_DIMENSION_WEIGHTS: Dictionary = {
	"basic": 0.30,
	"tactical": 0.30,
	"material": 0.25,
	"secret": 0.15,
}

const PERFECT_VICTORY_INTEL_BONUS: float = 0.10

# v7.x(A4): 全局玩家难度选择器单一真理源。enemy_stat_resolver 在乘区链末尾乘上对应值。
# 仅缩放敌方 HP 与攻击（不动 wave 数/掉落/经验），最小侵入平衡。默认 normal=1.0 行为零变化。
const DIFFICULTY_MULTIPLIERS: Dictionary = {
	"easy": 0.85,
	"normal": 1.0,
	"hard": 1.15,
}
