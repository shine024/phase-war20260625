extends RefCounted
class_name GameConstants
## 游戏常量：能量、刷新间隔、单位上限等

# 能量
const ENERGY_MAX: float = 100.0
const ENERGY_START: float = 100.0
const ENERGY_REGEN_PER_SEC: float = 1.0
const PHASE_BASE_DRAIN_PER_SEC: float = 0.5

# 单位
const PLAYER_SPAWN_INTERVAL: float = 10.0   # 秒
const PLAYER_MAX_UNITS: int = 5
const ENEMY_SPAWN_INTERVAL: float = 12.0
const ENEMY_WAVE_INTERVAL: float = 12.0
const ENEMY_MAX_UNITS: int = 5

## 战斗内：场上每名侦察/隐匿平台（SCOUT、STEALTH）提供的加成系数（相加后再与上限取 min）
## 与 design/gdd/battle-system.md 一致；战后装配加成见 GameManager 内单独常量
const RECON_FRAGMENT_BONUS_PER_UNIT: float = 0.10
const RECON_FRAGMENT_BONUS_CAP: float = 0.50

# 相位仪槽位
const PHASE_SLOT_COUNT: int = 4

## 格子战术：设计基准分辨率（立绘厘米换算）；竖向用 `y` 参与「18cm 屏 ↔ 1.5cm 士级」像素目标高
const CARD_GRID_REFERENCE_SCREEN_WIDTH_PX: int = 1280
const CARD_GRID_REFERENCE_SCREEN_HEIGHT_PX: int = 720
## 战斗 SubViewport 当前内部高度（`main.tscn`），可与设计分辨率不同；其它逻辑回退用
const CARD_GRID_BATTLE_VIEWPORT_HEIGHT_PX: float = 580.0
## 等效竖向 18cm 时，士级（以中士档为锚）立绘最大边约 1.5cm（像素按 `CARD_GRID_REFERENCE_SCREEN_HEIGHT_PX`）
const CARD_GRID_SCREEN_REF_HEIGHT_CM: float = 18.0
const CARD_GRID_ENLISTED_BASE_HEIGHT_CM: float = 1.5
## 卡面常为 1024 方图，按边长归一后屏上仍偏小，在目标像素上乘以此系数加大立绘（与 cm 比例叠乘，可调）
const CARD_GRID_BATTLEFIELD_DRAW_SCALE_MULTIPLIER: float = 2.35

## 新游戏时赠送法则碎片（用于蓝图库解析/升级；对应法则的 env_req 已放宽为全关卡可用）
const NEW_GAME_STARTER_LAW_SHARD_AMOUNT: int = 50
## 主动：烈焰·前线火力压制、雷霆·链式放电
const NEW_GAME_STARTER_ACTIVE_LAW_IDS: Array[String] = ["flame_front_bombard", "thunder_chain_discharge"]
## 被动：钢铁·固壁协议、烈焰·余烬加燃
const NEW_GAME_STARTER_PASSIVE_LAW_IDS: Array[String] = ["steel_fortify_protocol", "flame_afterburn"]

static func get_all_new_game_starter_law_ids() -> Array[String]:
	var out: Array[String] = []
	out.append_array(NEW_GAME_STARTER_ACTIVE_LAW_IDS)
	out.append_array(NEW_GAME_STARTER_PASSIVE_LAW_IDS)
	return out

# 平台类型（一战载具 + 高达风格，10 种 + 特殊 1 种）
enum PlatformType {
	HOUND,    # 威克斯装甲侦察车
	GUARD,    # 雷诺装甲护卫车
	TITAN,    # 马克V型重型坦克
	FORTRESS, # 要塞固定炮
	RADAR,    # 雷达指挥车
	SCOUT,    # 轻型侦察车
	RAIDER,   # 雷诺FT突击坦克
	SIEGE,    # 攻城重炮
	CARRIER,  # 载机母舰
	MEDIC,    # 野战维修车
	STEALTH,  # 渗透侦察型（隐匿机动）
	OMEGA_PLATFORM # 全装型机动舱（多槽重装，高达风）
}

# 武器类型（一战武器 + 高达风格，10 种 + 特殊 1 种）
enum WeaponType {
	SMG,      # MP18冲锋枪
	RIFLE,    # 李-恩菲尔德步枪
	MG,       # 马克沁机枪
	ROCKET,   # 斯托克斯迫击炮
	PISTOL,   # 鲁格P08
	SHOTGUN,  # 温彻斯特M1897堑壕枪
	SNIPER,   # 毛瑟G98狙击型
	FLAK,     # 76mm高射炮
	LASER,    # 光束步枪（高达）
	MISSILE,  # 制导火箭
	OMEGA_CANNON, # 米加粒子炮（高达）
	RAIL_CANNON, # 电磁轨道炮（高单发，低于米加满额）
}

# 卡片类型
# 显式数值：保持 COMBAT_UNIT/ENERGY/LAW 为 0~2，与既有蓝图/存档一致；3~5 为拆分式战斗卡（数据与 UI 仍大量使用）。
# v3：新内容优先 COMBAT_UNIT；PLATFORM/WEAPON/COMBINED 渐进弃用策略见 docs/BATTLE_CARD_V3_SCHEMA.md §2。
enum CardType {
	COMBAT_UNIT = 0, ## 战斗单位卡（蓝图等：底盘+武器合一）
	ENERGY = 1,
	LAW = 2, ## 法则卡
	PLATFORM = 3, ## 平台卡（独立平台资源）
	WEAPON = 4, ## 武器卡
	COMBINED = 5, ## 合成卡（多武器/来源追踪）
}

# 时代枚举（统一游戏中的时代定义）
enum Era {
	WW1,        # 一战  1-20
	WW2,        # 二战  21-40
	COLD_WAR,   # 冷战  41-60
	MODERN,     # 现代  61-80
	NEAR_FUTURE # 近未来 81-100
}

# ─────────────────────────────────────────────
#  显示名称映射（枚举值 -> 中文名称）
# ─────────────────────────────────────────────

## 平台类型中文名称映射
static func get_platform_type_name(platform_type: int) -> String:
	match platform_type:
		PlatformType.HOUND:       return "侦察型"
		PlatformType.GUARD:       return "护卫型"
		PlatformType.TITAN:       return "泰坦型"
		PlatformType.FORTRESS:    return "要塞型"
		PlatformType.RADAR:       return "雷达型"
		PlatformType.SCOUT:       return "轻侦察型"
		PlatformType.RAIDER:      return "突击型"
		PlatformType.SIEGE:       return "攻城型"
		PlatformType.CARRIER:     return "母舰型"
		PlatformType.MEDIC:       return "维修型"
		PlatformType.STEALTH:     return "隐匿型"
		PlatformType.OMEGA_PLATFORM: return "全装型"
		_: return "未知平台"

## 平台类型简短名称（用于UI空间有限时）
static func get_platform_type_short(platform_type: int) -> String:
	match platform_type:
		PlatformType.HOUND:       return "侦察"
		PlatformType.GUARD:       return "护卫"
		PlatformType.TITAN:       return "泰坦"
		PlatformType.FORTRESS:    return "要塞"
		PlatformType.RADAR:       return "雷达"
		PlatformType.SCOUT:       return "轻侦"
		PlatformType.RAIDER:      return "突击"
		PlatformType.SIEGE:       return "攻城"
		PlatformType.CARRIER:     return "母舰"
		PlatformType.MEDIC:       return "维修"
		PlatformType.STEALTH:     return "隐匿"
		PlatformType.OMEGA_PLATFORM: return "全装"
		_: return "未知"

const RealWorldUnitLabels = preload("res://data/real_world_unit_labels.gd")

## 武器类型中文名称映射（与单位信息面板一致的现实向长名）
static func get_weapon_type_name(weapon_type: int) -> String:
	return RealWorldUnitLabels.weapon_kind_long(weapon_type)

## 武器类型简短名称
static func get_weapon_type_short(weapon_type: int) -> String:
	return RealWorldUnitLabels.weapon_kind_short(weapon_type)

## 卡片类型中文名称映射
static func get_card_type_name(card_type: int) -> String:
	match card_type:
		CardType.COMBAT_UNIT:
			return "战斗单位卡"
		CardType.PLATFORM:
			return "平台卡"
		CardType.WEAPON:
			return "武器卡"
		CardType.COMBINED:
			return "合成卡"
		CardType.ENERGY:
			return "能量卡"
		CardType.LAW:
			return "法则卡"
		_:
			return "未知卡片"

## 稀有度中文名称映射
static func get_rarity_name(rarity: String) -> String:
	match rarity:
		"common":    return "普通"
		"uncommon":  return "优秀"
		"rare":      return "稀有"
		"epic":      return "史诗"
		"legendary": return "传说"
		_:           return "普通"

## 稀有度颜色
static func get_rarity_color(rarity: String) -> Color:
	match rarity:
		"common":    return Color(0.75, 0.75, 0.75, 1.0)  # 灰色
		"uncommon":  return Color(0.40, 0.90, 0.50, 1.0)  # 绿色
		"rare":      return Color(0.40, 0.65, 1.00, 1.0)  # 蓝色
		"epic":      return Color(0.75, 0.40, 1.00, 1.0)  # 紫色
		"legendary": return Color(1.00, 0.70, 0.30, 1.0)  # 金色
		_: return Color(0.75, 0.75, 0.75, 1.0)

## 时代中文名称映射
static func get_era_name(era: int) -> String:
	match era:
		Era.WW1: return "一战"
		Era.WW2: return "二战"
		Era.COLD_WAR: return "冷战"
		Era.MODERN: return "现代"
		Era.NEAR_FUTURE: return "近未来"
		_: return "未知时代"

## 时代简称映射
static func get_era_short(era: int) -> String:
	match era:
		Era.WW1: return "WW1"
		Era.WW2: return "WW2"
		Era.COLD_WAR: return "COLD"
		Era.MODERN: return "MODERN"
		Era.NEAR_FUTURE: return "FUTURE"
		_: return "???"

## ========== 统一时代划分逻辑 ==========

## 根据关卡获取时代（统一函数）
static func get_era_for_level(level: int) -> int:
	var lv: int = clampi(level, 1, 100)
	var era: int = 0
	if lv >= 81:
		era = Era.NEAR_FUTURE  # 近未来 81-100
	elif lv >= 61:
		era = Era.MODERN       # 现代 61-80
	elif lv >= 41:
		era = Era.COLD_WAR     # 冷战 41-60
	elif lv >= 21:
		era = Era.WW2          # 二战 21-40
	else:
		era = Era.WW1          # 一战 1-20
	return era

## 获取时代内关卡序号（1-20）
static func get_level_in_era(level: int) -> int:
	var lv: int = clampi(level, 1, 100)
	return ((lv - 1) % 20) + 1

## 获取时代前缀（用于敌人等）
static func get_era_prefix(era: int) -> String:
	match era:
		Era.WW1: return "ww1"
		Era.WW2: return "ww2"
		Era.COLD_WAR: return "cold"
		Era.MODERN: return "modern"
		Era.NEAR_FUTURE: return "near"
		_: return "ww1"

## 从时代前缀获取时代枚举
static func era_from_prefix(prefix: String) -> int:
	match prefix:
		"ww1": return Era.WW1
		"ww2": return Era.WW2
		"cold": return Era.COLD_WAR
		"modern": return Era.MODERN
		"near": return Era.NEAR_FUTURE
		_: return Era.WW1

## ========== 游戏平衡常量 ==========

## 相位师遭遇概率（0.0-1.0）
const PHASE_MASTER_ENCOUNTER_CHANCE: float = 0.15

## 经济系统常量
const NANO_MATERIAL_BASE_REWARD: int = 5
const NANO_MATERIAL_PER_LEVEL_EARLY: float = 1.5  # 前50关每关奖励系数
const NANO_MATERIAL_MAX_REWARD: int = 150         # 单次奖励上限

## 能量系统常量
const ENERGY_SLOT_MULTIPLIER_3_SLOT: float = 1.5  # 3槽相位仪回复倍率
const ENERGY_SLOT_MULTIPLIER_4_SLOT: float = 2.0  # 4槽相位仪回复倍率
