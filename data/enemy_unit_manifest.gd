extends RefCounted
class_name EnemyUnitManifest
## 100 基本敌人 + 缴获卡绑定（与 docs/card_icon_manifest_100_zh.md 对齐）
##
## v3 重构：100张敌人卡自带完整属性，不再从旧平台卡克隆。
## captured_* 由 CapturedUnitCards 注册，不经 DropManager 对 platform_* 的拦截。

const GC = preload("res://resources/game_constants.gd")
const BattleCardV3 = preload("res://data/battle_card_v3.gd")

const MANIFEST_VERSION: int = 2
const CAPTURED_PREFIX: String = "captured_"

## A 段：新时代单位 → 敌人 archetype 前缀 foe_（28张，v3更新）
const FOE_PLATFORM_CARD_IDS: Array[String] = [
	# 一战（5个）
	"ww1_rolls", "ww1_ft17", "ww1_77mm", "ww1_cavalry", "ww1_engineer",
	# 二战（7个）
	"ww2_hellcat", "ww2_sherman", "ww2_tiger", "ww2_bazooka", "ww2_panzerschrek",
	"ww2_m81", "ww1_m81",
	# 冷战（5个）
	"cold_btr60", "cold_t55", "cold_bmp1", "cold_m113", "cold_zsu23",
	# 现代系统（6个）
	"mod_technical", "mod_m1a1", "mod_m6", "mod_m270", "fut_scout_drone",
	"mod_m1a2sep",
	# 近未来（4个）
	"fut_scout_mech", "fut_hovertank", "fut_prism", "fut_heavy_mech",
	# 终极单位
	"fut_nexus",
]

## B 段：原精英掉落平台（6张）
const FOE_SPECIAL_CARD_IDS: Array[String] = [
	"bulwark", "titan_mk2", "storm_rider", "heavy_carrier", "regen_frame", "abrams_mk2",
]

## C 段：固定敌人（与 enemy_archetypes.json 一致，36张）
const FIXED_ENEMY_IDS: Array[String] = [
	"enemy_ww1_infantry_basic", "enemy_ww1_infantry_rifle", "enemy_ww1_mg_nest", "enemy_ww1_mortar",
	"elite_ww1_storm", "elite_ww1_armored", "boss_ww1_av7",
	"enemy_ww2_infantry", "enemy_ww2_rifleman", "enemy_ww2_mg42", "enemy_ww2_panzerschreck",
	"elite_ww2_paratrooper", "elite_ww2_panther", "boss_ww2_kingtiger",
	"enemy_cold_ak", "enemy_cold_m60", "enemy_cold_btr", "enemy_cold_m113",
	"elite_cold_spetsnaz", "elite_cold_t72", "boss_cold_mig",
	"enemy_modern_marine", "enemy_modern_technical", "enemy_modern_stryker", "enemy_modern_mlrs",
	"elite_modern_delta", "elite_modern_abrams", "elite_modern_apache", "boss_modern_command",
	"enemy_future_drone", "enemy_future_cyborg", "enemy_future_mech", "enemy_future_hovertank",
	"elite_future_spectre", "elite_future_colossus", "boss_future_nexus",
]

## D 段：补充敌人（29张）
const POOL_ENEMY_IDS: Array[String] = [
	"foe_pool_001", "foe_pool_002", "foe_pool_003", "foe_pool_004", "foe_pool_005",
	"foe_pool_006", "foe_pool_007", "foe_pool_008", "foe_pool_009", "foe_pool_010",
	"foe_pool_011", "foe_pool_012", "foe_pool_013", "foe_pool_014", "foe_pool_015",
	"foe_pool_016", "foe_pool_017", "foe_pool_018", "foe_pool_019", "foe_pool_020",
	"foe_pool_021", "foe_pool_022", "foe_pool_023", "foe_pool_024", "foe_pool_025",
	"foe_pool_026", "foe_pool_027", "foe_pool_028", "foe_pool_029",
]

## D段显示名
const POOL_DISPLAY_NAMES: Array[String] = [
	"李-恩菲尔德志愿兵排", "劳斯莱斯 Mk.II 装甲车", "维克斯 .303 机枪阵地", "福特 T 型战地救护车", "MP18 突击队",
	"M1 加兰德伞兵班", "黄蜂 Hummel 自行火炮", "PaK 40 反坦克炮组", "GMC 2.5t 补给卡车", "毛瑟 Kar98k 狙击组",
	"BMD-1 空降战车", "BMP-1 步兵战车", "9K111 法特导弹组", "P-18 雷达警戒车", "BREM-1 装甲抢修车",
	"M4 卡宾特遣班", "爱国者 PAC-3 发射车", "HIMARS 火箭炮组", "RQ-7 影子无人机班", "EA-18G 电子战小组",
	"神经接口突击兵", "HK-07 量产机兵", "HEL-30 激光炮阵列", "N-Repair 纳米工程车", "X-9 猎杀者渗透组",
	"毛瑟 C96 征召兵排", "Sd.Kfz.251/1 半履带车", "SS-C-1 岸防导弹组", "PS-9 相位中继站",
]

static var _entries_cache: Array = []
static var _unit_icon_by_archetype: Dictionary = {}

const UNITS_ICON_DIR := "res://assets/card_icons/units/"

# ─────────────────────────────────────────────
#  A/B段敌人卡属性表（直接定义，不从旧平台卡克隆）
#  新格式: { "kind": combat_kind, "hp": base_hp,
#            "weapon_type": WeaponTypeNew, "deploy_speed": 0-7,
#            "attack_light/armor/air": 多维攻击,
#            "defense_light/armor/air": 多维防御,
#            "rng": base_range, "ivl": base_interval,
#            "spd": base_speed, "weapon": weapon_label }
# ─────────────────────────────────────────────

## FOE_PLATFORM_CARD_IDS 直接 ID → 已有 platform_* 属性键映射
const _FOE_ID_TO_PLATFORM: Dictionary = {
	"ww1_rolls": "platform_ww1_medium",
	"ww1_ft17": "platform_ww1_medium",
	"ww1_77mm": "platform_ww1_fort",
	"ww1_cavalry": "platform_ww1_light",
	"ww1_engineer": "platform_ww1_medic",
	"ww2_hellcat": "platform_ww2_raider",
	"ww2_sherman": "platform_ww2_medium",
	"ww2_tiger": "platform_ww2_heavy",
	"ww2_bazooka": "platform_ww2_light",
	"ww2_panzerschrek": "platform_ww2_light",
	"ww2_m81": "platform_ww2_fortress",
	"ww1_m81": "platform_ww1_fort",
	"cold_btr60": "platform_cold_ifv",
	"cold_t55": "platform_cold_medium",
	"cold_bmp1": "platform_cold_ifv",
	"cold_m113": "platform_cold_carrier",
	"cold_zsu23": "platform_cold_radar",
	"fut_scout_mech": "platform_future_light",
	"fut_hovertank": "platform_future_medium",
	"fut_prism": "platform_future_heavy",
	"fut_heavy_mech": "platform_future_heavy",
	"fut_nexus": "omega_platform",
		# 现代时代（FOE_PLATFORM_CARD_IDS 现代段）
		"mod_technical": "platform_modern_light",
		"mod_m1a1": "platform_modern_medium",
		"mod_m6": "platform_modern_radar",
		"mod_m270": "platform_modern_spg",
		"fut_scout_drone": "platform_modern_stealth",
		"mod_m1a2sep": "platform_modern_guard_heavy",
	}

static func _get_foe_stats(card_id: String) -> Dictionary:
	var key: String = String(_FOE_ID_TO_PLATFORM.get(card_id, card_id))
	match key:
		# 一战 A段
		"platform_ww1_light":
			return {"kind": 0, "hp": 65.0, "weapon_type": 0, "deploy_speed": 4,
			        "attack_light": 35.0, "attack_armor": 0.0, "attack_air": 0.0,
			        "defense_light": 8.0, "defense_armor": 5.0, "defense_air": 3.0,
			        "rng": 95.0, "ivl": 0.67, "spd": 115.0, "weapon": "冲锋枪"}
		"platform_ww1_medium":
			return {"kind": 1, "hp": 200.0, "weapon_type": 0, "deploy_speed": 3,
			        "attack_light": 25.0, "attack_armor": 40.0, "attack_air": 0.0,
			        "defense_light": 18.0, "defense_armor": 22.0, "defense_air": 10.0,
			        "rng": 160.0, "ivl": 0.8, "spd": 40.0, "weapon": "机枪"}
		"platform_ww1_fort":
			return {"kind": 2, "hp": 260.0, "weapon_type": 0, "deploy_speed": 0,
			        "attack_light": 45.0, "attack_armor": 0.0, "attack_air": 25.0,
			        "defense_light": 12.0, "defense_armor": 8.0, "defense_air": 10.0,
			        "rng": 160.0, "ivl": 0.5, "spd": 0.0, "weapon": "机枪"}
		"platform_ww1_radar":
			return {"kind": 2, "hp": 180.0, "weapon_type": 0, "deploy_speed": 0,
			        "attack_light": 40.0, "attack_armor": 0.0, "attack_air": 22.0,
			        "defense_light": 12.0, "defense_armor": 8.0, "defense_air": 10.0,
			        "rng": 155.0, "ivl": 0.56, "spd": 0.0, "weapon": "机枪"}
		"platform_ww1_medic":
			return {"kind": 2, "hp": 80.0, "weapon_type": 0, "deploy_speed": 4,
			        "attack_light": 30.0, "attack_armor": 25.0, "attack_air": 0.0,
			        "defense_light": 10.0, "defense_armor": 8.0, "defense_air": 5.0,
			        "rng": 85.0, "ivl": 1.0, "spd": 75.0, "weapon": "步枪"}
		# 二战 A段
		"platform_ww2_light":
			return {"kind": 0, "hp": 50.0, "weapon_type": 0, "deploy_speed": 5,
			        "attack_light": 8.0, "attack_armor": 4.0, "attack_air": 4.0,
			        "defense_light": 4.0, "defense_armor": 3.0, "defense_air": 3.0,
			        "rng": 95.0, "ivl": 0.38, "spd": 135.0, "weapon": "冲锋枪"}
		"platform_ww2_medium":
			return {"kind": 1, "hp": 110.0, "weapon_type": 0, "deploy_speed": 3,
			        "attack_light": 14.0, "attack_armor": 8.0, "attack_air": 7.0,
			        "defense_light": 9.0, "defense_armor": 7.0, "defense_air": 7.0,
			        "rng": 155.0, "ivl": 0.95, "spd": 75.0, "weapon": "步枪"}
		"platform_ww2_heavy":
			return {"kind": 1, "hp": 200.0, "weapon_type": 1, "deploy_speed": 1,
			        "attack_light": 30.0, "attack_armor": 18.0, "attack_air": 15.0,
			        "defense_light": 13.0, "defense_armor": 10.0, "defense_air": 10.0,
			        "rng": 195.0, "ivl": 1.70, "spd": 40.0, "weapon": "迫击炮"}
		"platform_ww2_raider":
			return {"kind": 0, "hp": 90.0, "weapon_type": 0, "deploy_speed": 4,
			        "attack_light": 7.0, "attack_armor": 3.0, "attack_air": 3.0,
			        "defense_light": 7.0, "defense_armor": 5.0, "defense_air": 5.0,
			        "rng": 160.0, "ivl": 0.25, "spd": 100.0, "weapon": "机枪"}
		"platform_ww2_radar":
			return {"kind": 2, "hp": 180.0, "weapon_type": 0, "deploy_speed": 0,
			        "attack_light": 14.0, "attack_armor": 8.0, "attack_air": 7.0,
			        "defense_light": 11.0, "defense_armor": 9.0, "defense_air": 9.0,
			        "rng": 155.0, "ivl": 0.95, "spd": 0.0, "weapon": "步枪"}
		"platform_ww2_siege":
			return {"kind": 2, "hp": 300.0, "weapon_type": 1, "deploy_speed": 0,
			        "attack_light": 30.0, "attack_armor": 18.0, "attack_air": 15.0,
			        "defense_light": 14.0, "defense_armor": 11.0, "defense_air": 11.0,
			        "rng": 195.0, "ivl": 1.70, "spd": 0.0, "weapon": "迫击炮"}
		"platform_ww2_fortress":
			return {"kind": 2, "hp": 260.0, "weapon_type": 0, "deploy_speed": 0,
			        "attack_light": 7.0, "attack_armor": 3.0, "attack_air": 3.0,
			        "defense_light": 20.0, "defense_armor": 16.0, "defense_air": 16.0,
			        "rng": 160.0, "ivl": 0.25, "spd": 0.0, "weapon": "机枪"}
		# 冷战 A段
		"platform_cold_light":
			return {"kind": 0, "hp": 65.0, "weapon_type": 0, "deploy_speed": 5,
			        "attack_light": 8.0, "attack_armor": 5.0, "attack_air": 4.0,
			        "defense_light": 5.0, "defense_armor": 4.0, "defense_air": 4.0,
			        "rng": 95.0, "ivl": 0.38, "spd": 115.0, "weapon": "冲锋枪"}
		"platform_cold_medium":
			return {"kind": 1, "hp": 200.0, "weapon_type": 1, "deploy_speed": 2,
			        "attack_light": 30.0, "attack_armor": 20.0, "attack_air": 16.0,
			        "defense_light": 13.0, "defense_armor": 11.0, "defense_air": 10.0,
			        "rng": 195.0, "ivl": 1.70, "spd": 40.0, "weapon": "迫击炮"}
		"platform_cold_ifv":
			return {"kind": 3, "hp": 140.0, "weapon_type": 0, "deploy_speed": 3,
			        "attack_light": 7.0, "attack_armor": 4.0, "attack_air": 4.0,
			        "defense_light": 8.0, "defense_armor": 6.0, "defense_air": 6.0,
			        "rng": 160.0, "ivl": 0.25, "spd": 50.0, "weapon": "机枪"}
		"platform_cold_scout":
			return {"kind": 0, "hp": 50.0, "weapon_type": 0, "deploy_speed": 6,
			        "attack_light": 8.0, "attack_armor": 4.0, "attack_air": 4.0,
			        "defense_light": 4.0, "defense_armor": 3.0, "defense_air": 3.0,
			        "rng": 95.0, "ivl": 0.38, "spd": 135.0, "weapon": "冲锋枪"}
		"platform_cold_radar":
			return {"kind": 2, "hp": 180.0, "weapon_type": 0, "deploy_speed": 0,
			        "attack_light": 14.0, "attack_armor": 10.0, "attack_air": 9.0,
			        "defense_light": 11.0, "defense_armor": 9.0, "defense_air": 9.0,
			        "rng": 155.0, "ivl": 0.95, "spd": 0.0, "weapon": "步枪"}
		"platform_cold_carrier":
			return {"kind": 3, "hp": 140.0, "weapon_type": 2, "deploy_speed": 2,
			        "attack_light": 7.0, "attack_armor": 4.0, "attack_air": 5.0,
			        "defense_light": 8.0, "defense_armor": 6.0, "defense_air": 6.0,
			        "rng": 160.0, "ivl": 0.25, "spd": 50.0, "weapon": "机枪"}
		# 现代 A段
		"platform_modern_light":
			return {"kind": 0, "hp": 65.0, "weapon_type": 0, "deploy_speed": 5,
			        "attack_light": 8.0, "attack_armor": 5.0, "attack_air": 5.0,
			        "defense_light": 5.0, "defense_armor": 4.0, "defense_air": 4.0,
			        "rng": 95.0, "ivl": 0.38, "spd": 115.0, "weapon": "冲锋枪"}
		"platform_modern_medium":
			return {"kind": 1, "hp": 110.0, "weapon_type": 1, "deploy_speed": 3,
			        "attack_light": 30.0, "attack_armor": 20.0, "attack_air": 18.0,
			        "defense_light": 9.0, "defense_armor": 7.0, "defense_air": 7.0,
			        "rng": 195.0, "ivl": 1.70, "spd": 75.0, "weapon": "迫击炮"}
		"platform_modern_radar":
			return {"kind": 2, "hp": 180.0, "weapon_type": 0, "deploy_speed": 0,
			        "attack_light": 14.0, "attack_armor": 10.0, "attack_air": 9.0,
			        "defense_light": 11.0, "defense_armor": 9.0, "defense_air": 9.0,
			        "rng": 155.0, "ivl": 0.95, "spd": 0.0, "weapon": "步枪"}
		"platform_modern_spg":
			return {"kind": 2, "hp": 300.0, "weapon_type": 1, "deploy_speed": 0,
			        "attack_light": 30.0, "attack_armor": 20.0, "attack_air": 18.0,
			        "defense_light": 14.0, "defense_armor": 11.0, "defense_air": 11.0,
			        "rng": 195.0, "ivl": 1.70, "spd": 0.0, "weapon": "迫击炮"}
		"platform_modern_stealth":
			return {"kind": 0, "hp": 50.0, "weapon_type": 0, "deploy_speed": 6,
			        "attack_light": 8.0, "attack_armor": 5.0, "attack_air": 5.0,
			        "defense_light": 5.0, "defense_armor": 4.0, "defense_air": 4.0,
			        "rng": 95.0, "ivl": 0.38, "spd": 115.0, "weapon": "冲锋枪"}
		"platform_modern_guard_heavy":
			return {"kind": 1, "hp": 110.0, "weapon_type": 1, "deploy_speed": 2,
			        "attack_light": 140.0, "attack_armor": 100.0, "attack_air": 90.0,
			        "defense_light": 9.0, "defense_armor": 7.0, "defense_air": 7.0,
			        "rng": 240.0, "ivl": 1.65, "spd": 75.0, "weapon": "轨道炮"}
		# 现代 A段 - 直接使用的 ID
		"mod_technical":
			return {"kind": 0, "hp": 90.0, "weapon_type": 0, "deploy_speed": 4,
			        "attack_light": 18.0, "attack_armor": 5.0, "attack_air": 5.0,
			        "defense_light": 7.0, "defense_armor": 5.0, "defense_air": 5.0,
			        "rng": 130.0, "ivl": 0.30, "spd": 120.0, "weapon": "机枪"}
		"mod_m1a1":
			return {"kind": 1, "hp": 220.0, "weapon_type": 1, "deploy_speed": 2,
			        "attack_light": 50.0, "attack_armor": 40.0, "attack_air": 35.0,
			        "defense_light": 15.0, "defense_armor": 12.0, "defense_air": 12.0,
			        "rng": 240.0, "ivl": 1.80, "spd": 60.0, "weapon": "火炮"}
		"mod_m6":
			return {"kind": 2, "hp": 160.0, "weapon_type": 0, "deploy_speed": 0,
			        "attack_light": 25.0, "attack_armor": 15.0, "attack_air": 35.0,
			        "defense_light": 12.0, "defense_armor": 10.0, "defense_air": 12.0,
			        "rng": 280.0, "ivl": 0.15, "spd": 0.0, "weapon": "机枪"}
		"mod_m270":
			return {"kind": 2, "hp": 200.0, "weapon_type": 1, "deploy_speed": 0,
			        "attack_light": 40.0, "attack_armor": 30.0, "attack_air": 20.0,
			        "defense_light": 10.0, "defense_armor": 8.0, "defense_air": 8.0,
			        "rng": 400.0, "ivl": 2.50, "spd": 0.0, "weapon": "火箭炮"}
		"fut_scout_drone":
			return {"kind": 3, "hp": 50.0, "weapon_type": 0, "deploy_speed": 6,
			        "attack_light": 8.0, "attack_armor": 8.0, "attack_air": 8.0,
			        "defense_light": 3.0, "defense_armor": 3.0, "defense_air": 3.0,
			        "rng": 150.0, "ivl": 0.35, "spd": 135.0, "weapon": "机枪"}
		"mod_m1a2sep":
			return {"kind": 1, "hp": 240.0, "weapon_type": 1, "deploy_speed": 2,
			        "attack_light": 55.0, "attack_armor": 45.0, "attack_air": 40.0,
			        "defense_light": 16.0, "defense_armor": 13.0, "defense_air": 13.0,
			        "rng": 250.0, "ivl": 1.70, "spd": 65.0, "weapon": "火炮"}
		# 近未来 A段
		"platform_future_light":
			return {"kind": 0, "hp": 50.0, "weapon_type": 0, "deploy_speed": 5,
			        "attack_light": 13.0, "attack_armor": 9.0, "attack_air": 9.0,
			        "defense_light": 5.0, "defense_armor": 4.0, "defense_air": 4.0,
			        "rng": 185.0, "ivl": 0.50, "spd": 115.0, "weapon": "光束步枪"}
		"platform_future_medium":
			return {"kind": 1, "hp": 90.0, "weapon_type": 0, "deploy_speed": 4,
			        "attack_light": 13.0, "attack_armor": 9.0, "attack_air": 9.0,
			        "defense_light": 7.0, "defense_armor": 6.0, "defense_air": 6.0,
			        "rng": 185.0, "ivl": 0.50, "spd": 100.0, "weapon": "光束步枪"}
		"platform_future_radar":
			return {"kind": 2, "hp": 180.0, "weapon_type": 0, "deploy_speed": 0,
			        "attack_light": 13.0, "attack_armor": 9.0, "attack_air": 9.0,
			        "defense_light": 11.0, "defense_armor": 9.0, "defense_air": 9.0,
			        "rng": 185.0, "ivl": 0.50, "spd": 0.0, "weapon": "光束步枪"}
		"platform_future_heavy":
			return {"kind": 1, "hp": 200.0, "weapon_type": 1, "deploy_speed": 1,
			        "attack_light": 220.0, "attack_armor": 180.0, "attack_air": 160.0,
			        "defense_light": 13.0, "defense_armor": 11.0, "defense_air": 10.0,
			        "rng": 250.0, "ivl": 2.2, "spd": 40.0, "weapon": "米加粒子炮"}
		"omega_platform":
			return {"kind": 1, "hp": 240.0, "weapon_type": 1, "deploy_speed": 1,
			        "attack_light": 220.0, "attack_armor": 180.0, "attack_air": 160.0,
			        "defense_light": 15.0, "defense_armor": 12.0, "defense_air": 11.0,
			        "rng": 250.0, "ivl": 2.2, "spd": 30.0, "weapon": "米加粒子炮"}
		# B段 特殊卡
		"bulwark":
			return {"kind": 2, "hp": 300.0, "weapon_type": 0, "deploy_speed": 0,
			        "attack_light": 22.0, "attack_armor": 15.0, "attack_air": 13.0,
			        "defense_light": 20.0, "defense_armor": 16.0, "defense_air": 16.0,
			        "rng": 60.0, "ivl": 0.85, "spd": 0.0, "weapon": "霰弹枪"}
		"titan_mk2":
			return {"kind": 1, "hp": 250.0, "weapon_type": 1, "deploy_speed": 2,
			        "attack_light": 38.0, "attack_armor": 26.0, "attack_air": 23.0,
			        "defense_light": 15.0, "defense_armor": 12.0, "defense_air": 11.0,
			        "rng": 215.0, "ivl": 2.00, "spd": 35.0, "weapon": "导弹"}
		"storm_rider":
			return {"kind": 0, "hp": 60.0, "weapon_type": 2, "deploy_speed": 5,
			        "attack_light": 28.0, "attack_armor": 19.0, "attack_air": 17.0,
			        "defense_light": 5.0, "defense_armor": 4.0, "defense_air": 4.0,
			        "rng": 240.0, "ivl": 1.60, "spd": 120.0, "weapon": "狙击枪"}
		"heavy_carrier":
			return {"kind": 3, "hp": 160.0, "weapon_type": 2, "deploy_speed": 2,
			        "attack_light": 7.0, "attack_armor": 5.0, "attack_air": 5.0,
			        "defense_light": 9.0, "defense_armor": 7.0, "defense_air": 7.0,
			        "rng": 160.0, "ivl": 0.25, "spd": 50.0, "weapon": "机枪"}
		"regen_frame":
			return {"kind": 3, "hp": 100.0, "weapon_type": 0, "deploy_speed": 3,
			        "attack_light": 7.0, "attack_armor": 5.0, "attack_air": 4.0,
			        "defense_light": 6.0, "defense_armor": 5.0, "defense_air": 5.0,
			        "rng": 85.0, "ivl": 0.45, "spd": 75.0, "weapon": "手枪"}
		"abrams_mk2":
			return {"kind": 1, "hp": 220.0, "weapon_type": 1, "deploy_speed": 2,
			        "attack_light": 140.0, "attack_armor": 100.0, "attack_air": 90.0,
			        "defense_light": 12.0, "defense_armor": 10.0, "defense_air": 9.0,
			        "rng": 240.0, "ivl": 1.65, "spd": 65.0, "weapon": "轨道炮"}
		# D段 池子卡默认（按 kind 0-3 循环）
		"_pool_default":
			return {"kind": 1, "hp": 100.0, "weapon_type": 0, "deploy_speed": 4,
			        "attack_light": 14.0, "attack_armor": 10.0, "attack_air": 9.0,
			        "defense_light": 8.0, "defense_armor": 6.0, "defense_air": 6.0,
			        "rng": 155.0, "ivl": 0.95, "spd": 75.0, "weapon": "步枪"}
		_:
			return {"kind": 1, "hp": 100.0, "weapon_type": 0, "deploy_speed": 4,
			        "attack_light": 14.0, "attack_armor": 10.0, "attack_air": 9.0,
			        "defense_light": 8.0, "defense_armor": 6.0, "defense_air": 6.0,
			        "rng": 155.0, "ivl": 0.95, "spd": 75.0, "weapon": "步枪"}


## D段池子卡按 kind 的属性修正
static func _pool_stats_for_kind(kind: int) -> Dictionary:
	match kind:
		0: return {"hp": 55.0, "weapon_type": 0, "deploy_speed": 5,
		          "attack_light": 10.0, "attack_armor": 7.0, "attack_air": 6.0,
		          "defense_light": 4.0, "defense_armor": 3.0, "defense_air": 3.0,
		          "rng": 110.0, "ivl": 0.50, "spd": 120.0, "weapon": "冲锋枪"}
		1: return {"hp": 120.0, "weapon_type": 0, "deploy_speed": 3,
		          "attack_light": 16.0, "attack_armor": 11.0, "attack_air": 10.0,
		          "defense_light": 10.0, "defense_armor": 8.0, "defense_air": 8.0,
		          "rng": 155.0, "ivl": 0.90, "spd": 60.0, "weapon": "步枪"}
		2: return {"hp": 200.0, "weapon_type": 1, "deploy_speed": 0,
		          "attack_light": 25.0, "attack_armor": 18.0, "attack_air": 16.0,
		          "defense_light": 14.0, "defense_armor": 11.0, "defense_air": 11.0,
		          "rng": 180.0, "ivl": 1.50, "spd": 0.0, "weapon": "迫击炮"}
		3: return {"hp": 90.0, "weapon_type": 2, "deploy_speed": 3,
		          "attack_light": 8.0, "attack_armor": 6.0, "attack_air": 5.0,
		          "defense_light": 6.0, "defense_armor": 5.0, "defense_air": 5.0,
		          "rng": 130.0, "ivl": 0.40, "spd": 70.0, "weapon": "手枪"}
		_: return {"hp": 100.0, "weapon_type": 0, "deploy_speed": 4,
		          "attack_light": 14.0, "attack_armor": 10.0, "attack_air": 9.0,
		          "defense_light": 8.0, "defense_armor": 6.0, "defense_air": 6.0,
		          "rng": 155.0, "ivl": 0.95, "spd": 75.0, "weapon": "步枪"}


# ─────────────────────────────────────────────
#  公开接口
# ─────────────────────────────────────────────

static func get_unit_icon_path_for_archetype(archetype_id: String) -> String:
	var aid := String(archetype_id).strip_edges()
	if aid.is_empty():
		return ""
	_ensure_unit_icon_map()
	var rel: String = String(_unit_icon_by_archetype.get(aid, ""))
	if rel.is_empty():
		return ""
	var full := "%s%s.png" % [UNITS_ICON_DIR, rel]
	return full if ResourceLoader.exists(full) else ""


static func _ensure_unit_icon_map() -> void:
	if not _unit_icon_by_archetype.is_empty():
		return
	for row in get_entries():
		if row is not Dictionary:
			continue
		var aid: String = String(row.get("archetype_id", ""))
		var vid: String = String(row.get("visual_id", ""))
		if aid.is_empty() or vid.is_empty():
			continue
		_unit_icon_by_archetype[aid] = vid


static func get_entry_count() -> int:
	return 28 + 6 + 36 + 29


static func captured_card_id_for(archetype_id: String) -> String:
	return "%s%s" % [CAPTURED_PREFIX, String(archetype_id).strip_edges()]


static func is_captured_card_id(card_id: String) -> bool:
	return String(card_id).begins_with(CAPTURED_PREFIX)


static func archetype_id_for_platform_card(platform_card_id: String) -> String:
	return "foe_%s" % String(platform_card_id).strip_edges()


## 获取全部100张敌人条目
static func get_entries() -> Array:
	if not _entries_cache.is_empty():
		return _entries_cache
	var rows: Array = []
	for pid in FOE_PLATFORM_CARD_IDS:
		rows.append(_make_foe_row(pid))
	for sid in FOE_SPECIAL_CARD_IDS:
		rows.append(_make_foe_row(sid))
	for eid in FIXED_ENEMY_IDS:
		rows.append(_make_fixed_row(eid))
	for i in range(POOL_ENEMY_IDS.size()):
		rows.append(_make_pool_row(i))
	_entries_cache = rows
	return _entries_cache


static func build_archetype_dictionary(base_archetypes: Dictionary) -> Dictionary:
	var out: Dictionary = base_archetypes.duplicate(true)
	for row in get_entries():
		if row is not Dictionary:
			continue
		var aid: String = String(row.get("archetype_id", ""))
		var cfg: Dictionary = row.get("archetype_config", {})
		if aid.is_empty() or cfg.is_empty():
			continue
		out[aid] = cfg
	return out


static func get_drop_card_id(archetype_id: String) -> String:
	return captured_card_id_for(archetype_id)


# ─────────────────────────────────────────────
#  行构建（新模型：不再从 default_cards 克隆）
# ─────────────────────────────────────────────

## A/B段：直接从属性表生成
static func _make_foe_row(card_id: String) -> Dictionary:
	var era: int = _era_from_platform_id(card_id)
	var aid: String = archetype_id_for_platform_card(card_id)
	var s: Dictionary = _get_foe_stats(card_id)
	var display_name: String = _get_foe_display_name(card_id)
	var speed: float = 0.0
	if s.spd > 0.0:
		speed = -maxf(40.0, float(s.spd) * 0.65)
	return {
		"archetype_id": aid,
		"display_name": display_name,
		"era": era,
		"visual_id": _visual_id_for_source_id(card_id),
		"drop_card_id": captured_card_id_for(aid),
		"template_card_id": "",  # 不再需要旧模板
		"drop_trigger": "on_kill",
		"drop_chance": _default_drop_chance("frontline"),
		"archetype_config": {
			"era": era,
			"display_name": display_name,
			"hp": s.hp,
			"speed": speed,
			"attack_damage": s.attack_light,
			"attack_range": s.rng,
			"attack_interval": s.ivl,
			"combat_kind": s.kind,
			"weapon_label": s.weapon,
			"defense": s.defense_light,
			"tags": _tags_for_kind(s.kind),
			"swarm_unit": (s.kind == 0),
			"drops": [{"card_id": captured_card_id_for(aid), "chance": 0.08}],
		},
	}


## C段：固定敌人（基础配置来自 enemy_archetypes，此处只建掉落与 id）
static func _make_fixed_row(enemy_id: String) -> Dictionary:
	var era: int = _era_from_enemy_id(enemy_id)
	return {
		"archetype_id": enemy_id,
		"display_name": "",
		"era": era,
		"visual_id": _visual_id_for_source_id(enemy_id),
		"drop_card_id": captured_card_id_for(enemy_id),
		"template_card_id": "",
		"drop_trigger": "on_kill",
		"drop_chance": _default_drop_chance(_tag_tier_from_id(enemy_id)),
		"archetype_config": {},
	}


## D段：池子卡
static func _make_pool_row(index: int) -> Dictionary:
	var aid: String = POOL_ENEMY_IDS[index]
	var era: int = clampi(index / 5, 0, 4)
	var kind: int = index % 4
	var display_name: String = POOL_DISPLAY_NAMES[index] if index < POOL_DISPLAY_NAMES.size() else aid
	var s: Dictionary = _pool_stats_for_kind(kind)
	var speed: float = 0.0
	if s.spd > 0.0:
		speed = -maxf(40.0, float(s.spd) * 0.65)
	return {
		"archetype_id": aid,
		"display_name": display_name,
		"era": era,
		"visual_id": "vis_pool_%03d" % (index + 1),
		"drop_card_id": captured_card_id_for(aid),
		"template_card_id": "",
		"drop_trigger": "on_kill",
		"drop_chance": 0.08,
		"archetype_config": {
			"era": era,
			"display_name": display_name,
			"hp": s.hp,
			"speed": speed,
			"attack_damage": s.attack_light,
			"attack_range": s.rng,
			"attack_interval": s.ivl,
			"combat_kind": kind,
			"weapon_label": s.weapon,
			"defense": s.defense_light,
			"tags": _tags_for_kind(kind),
			"swarm_unit": (kind == 0),
			"drops": [{"card_id": captured_card_id_for(aid), "chance": 0.08}],
		},
	}


# ─────────────────────────────────────────────
#  辅助函数
# ─────────────────────────────────────────────

static func _tags_for_kind(kind: int) -> Array:
	match kind:
		2: return ["turret", "sustained"]
		3: return ["support"]
		4: return ["fortress", "immobile"]  # v5.0 堡垒
		1: return ["vehicle", "armored"]
		_: return ["frontline"]


static func _get_foe_display_name(card_id: String) -> String:
	match card_id:
		"platform_ww1_light": return "威克斯侦察车"
		"platform_ww1_medium": return "马克V型坦克"
		"platform_ww1_fort": return "要塞固定炮"
		"platform_ww1_radar": return "野战观测站"
		"platform_ww1_medic": return "野战救护车"
		"platform_ww2_light": return "M8灰狗装甲车"
		"platform_ww2_medium": return "谢尔曼坦克"
		"platform_ww2_heavy": return "虎式坦克"
		"platform_ww2_raider": return "BA-64轻型突击车"
		"platform_ww2_radar": return "雷达指挥车"
		"platform_ww2_siege": return "203毫米迫击炮"
		"platform_ww2_fortress": return "混凝土碉堡"
		"platform_cold_light": return "悍马侦察车"
		"platform_cold_medium": return "T-72主战坦克"
		"platform_cold_ifv": return "布雷德利步战车"
		"platform_cold_scout": return "BRDM-2侦察车"
		"platform_cold_radar": return "电子对抗站"
		"platform_cold_carrier": return "BMP步战车"
		"mod_technical": return "皮卡武装"
		"mod_m1a1": return "M1A1主战坦克"
		"mod_m6": return "自行高炮M6"
		"mod_m270": return "M270火箭炮"
		"fut_scout_drone": return "侦察无人机"
		"mod_m1a2sep": return "M1A2 SEP主战坦克"
		# 直接 ID 显示名（与 default_cards 对齐）
		"ww1_rolls": return "罗尔斯装甲车"
		"ww1_ft17": return "FT-17轻型坦克"
		"ww1_77mm": return "77mm野战炮"
		"ww1_cavalry": return "骑兵斥候"
		"ww1_engineer": return "工兵班"
		"ww2_hellcat": return "M18地狱猫"
		"ww2_sherman": return "M4谢尔曼"
		"ww2_tiger": return "虎式坦克"
		"ww2_bazooka": return "巴祖卡组"
		"ww2_panzerschrek": return "铁拳反坦克组"
		"ww2_m81": return "81mm迫击炮"
		"ww1_m81": return "81mm迫击炮组"
		"cold_btr60": return "BTR-60装甲车"
		"cold_t55": return "T-55坦克"
		"cold_bmp1": return "BMP-1步战车"
		"cold_m113": return "M113装甲车"
		"cold_zsu23": return "ZSU-23-4自行高炮"
		"fut_scout_mech": return "侦察机甲"
		"fut_hovertank": return "悬浮坦克"
		"fut_prism": return "光棱坦克"
		"fut_heavy_mech": return "重装机甲"
		"fut_nexus": return "虚空领主"
		"platform_modern_light": return "北极星全地形车"
		"platform_modern_medium": return "艾布拉姆斯坦克"
		"platform_modern_radar": return "相控阵雷达车"
		"platform_modern_spg": return "帕拉丁自行火炮"
		"platform_modern_stealth": return "光学隐匿侦察车"
		"platform_modern_guard_heavy": return "豹2A7主战坦克"
		"platform_future_light": return "光学侦察车"
		"platform_future_medium": return "悬浮坦克"
		"platform_future_radar": return "量子感知平台"
		"platform_future_heavy": return "机甲步行者"
		"omega_platform": return "全装型机动舱"
		"bulwark": return "壁垒"
		"titan_mk2": return "泰坦Mk.II"
		"storm_rider": return "暴风骑士"
		"heavy_carrier": return "重装母舰"
		"regen_frame": return "再生骨架"
		"abrams_mk2": return "艾布拉姆斯Mk.II"
		_: return card_id


static func _merge_fixed_config(row: Dictionary, base_cfg: Dictionary) -> Dictionary:
	var cfg: Dictionary = base_cfg.duplicate(true)
	var aid: String = String(row.get("archetype_id", ""))
	var chance: float = float(row.get("drop_chance", 0.08))
	var drop_id: String = String(row.get("drop_card_id", ""))
	if not drop_id.is_empty():
		cfg["drops"] = [{"card_id": drop_id, "chance": chance}]
	return cfg


## 供 EnemyArchetypes 调用：在固定 JSON 配置上强制写入缴获掉落
static func apply_capture_drops_to_archetypes(archetypes: Dictionary) -> Dictionary:
	var out: Dictionary = archetypes.duplicate(true)
	for row in get_entries():
		if row is not Dictionary:
			continue
		var aid: String = String(row.get("archetype_id", ""))
		if aid.is_empty():
			continue
		var drop_id: String = String(row.get("drop_card_id", ""))
		var chance: float = float(row.get("drop_chance", 0.08))
		var sub: Dictionary = row.get("archetype_config", {})
		if not out.has(aid):
			if sub is Dictionary and not sub.is_empty():
				out[aid] = sub.duplicate(true)
			else:
				continue
		var cfg: Dictionary = out[aid]
		if cfg is Dictionary:
			cfg["drops"] = [{"card_id": drop_id, "chance": chance}]
			if not String(row.get("display_name", "")).is_empty():
				cfg["display_name"] = String(row.get("display_name", ""))
			out[aid] = cfg
	return out


static func _era_from_platform_id(card_id: String) -> int:
	if card_id.contains("ww1"):
		return 0
	if card_id.contains("ww2"):
		return 1
	if card_id.contains("cold"):
		return 2
	if card_id.contains("modern") or card_id.begins_with("mod_"):
		return 3
	if card_id.contains("future") or card_id.begins_with("fut_") or card_id == "omega_platform":
		return 4
	return 0


static func _era_from_enemy_id(enemy_id: String) -> int:
	if enemy_id.contains("ww1"):
		return 0
	if enemy_id.contains("ww2"):
		return 1
	if enemy_id.contains("cold"):
		return 2
	if enemy_id.contains("modern"):
		return 3
	if enemy_id.contains("future") or enemy_id.contains("near"):
		return 4
	return 0


static func _tag_tier_from_id(enemy_id: String) -> String:
	if enemy_id.begins_with("boss_"):
		return "boss"
	if enemy_id.begins_with("elite_"):
		return "elite"
	return "frontline"


static func _default_drop_chance(tier: String) -> float:
	match tier:
		"boss":
			return 0.55
		"elite":
			return 0.22
		_:
			return 0.08


## 与 docs/card_icon_manifest_100_agent_prompts.md 编号一致
static func _visual_id_for_source_id(source_id: String) -> String:
	var sid: String = source_id.strip_edges()
	var special_idx: int = FOE_SPECIAL_CARD_IDS.find(sid)
	if special_idx >= 0:
		return "vis_player_%03d" % (30 + special_idx)
	var platform_idx: int = FOE_PLATFORM_CARD_IDS.find(sid)
	if platform_idx >= 0:
		return "vis_player_%03d" % (platform_idx + 1)
	var fixed_idx: int = FIXED_ENEMY_IDS.find(sid)
	if fixed_idx >= 0:
		return "vis_enemy_%03d" % (36 + fixed_idx)
	var pool_idx: int = POOL_ENEMY_IDS.find(sid)
	if pool_idx >= 0:
		return "vis_pool_%03d" % (pool_idx + 1)
	return sid
