extends RefCounted
class_name DefaultCards
## 默认背包卡片数据（用于演示） - v3 架构修复版

const GC = preload("res://resources/game_constants.gd")
const PhaseLaws = preload("res://data/phase_laws.gd")
const EnemyBlueprints = preload("res://data/enemy_blueprints.gd")
const CapturedUnitCards = preload("res://data/captured_unit_cards.gd")
const EnemyPhaseEquipment = preload("res://data/enemy_phase_equipment.gd")
const RealWorldUnitLabels = preload("res://data/real_world_unit_labels.gd")
const UnitStatsTable = preload("res://resources/unit_stats_table.gd")
const CardResource = preload("res://resources/card_resource.gd")

## 旧版法则卡 id → PhaseLaws.id（存档/商店兼容）
const LEGACY_LAW_CARD_ID_MAP: Dictionary = {
	"law_steel_passive_1": "steel_phase_armor",
	"law_steel_passive_2": "steel_quick_repair",
	"law_steel_active": "steel_bastion_wall",
	"law_flame_passive_1": "flame_heat_overload",
	"law_flame_passive_2": "flame_afterburn",
	"law_flame_active": "flame_front_bombard",
	"law_thunder_passive_1": "thunder_arc_beacon",
	"law_thunder_passive_2": "thunder_emp_storm",
	"law_thunder_active": "thunder_emp_storm",
	"law_void_passive_1": "void_entropy_lens",
	"law_void_passive_2": "void_time_ripple",
	"law_void_active": "void_time_ripple",
}

## 静态缓存：避免每次 get_card_by_id 都重新 create_all() 68 张卡
static var _all_cards_cache: Array = []
static var _id_lookup_cache: Dictionary = {}

## 确保 create_all 缓存已构建（整个游戏会话只构建一次）
static func _ensure_card_cache() -> void:
	if not _all_cards_cache.is_empty():
		return
	_all_cards_cache = create_all()
	for c in _all_cards_cache:
		if c is CardResource:
			_id_lookup_cache[c.card_id] = c
	CapturedUnitCards.register_into_default_cards_cache()

static func create_all() -> Array:
	var list: Array = []

	# ==================== 载具卡（29种，按时代分类） ====================

	# 一战载具（5种）
	list.append(_platform("platform_ww1_light", "威克斯侦察车", 3, 0))
	list.append(_platform("platform_ww1_medium", "马克V型坦克", 5, 2))
	list.append(_platform("platform_ww1_fort", "要塞固定炮", 5, 3))
	list.append(_platform("platform_ww1_radar", "野战观测站", 5, 4))
	list.append(_platform("platform_ww1_medic", "野战救护车", 4, 9))

	# 二战载具（7种）
	list.append(_platform("platform_ww2_light", "M8灰狗装甲车", 4, 5))
	list.append(_platform("platform_ww2_medium", "谢尔曼坦克", 5, 1))
	list.append(_platform("platform_ww2_heavy", "虎式坦克", 6, 2))
	list.append(_platform("platform_ww2_raider", "BA-64轻型突击车", 4, 6))
	list.append(_platform("platform_ww2_radar", "雷达指挥车", 5, 4))
	list.append(_platform("platform_ww2_siege", "203毫米迫击炮", 5, 7))
	list.append(_platform("platform_ww2_fortress", "混凝土碉堡", 5, 3))

	# 冷战载具（6种）
	list.append(_platform("platform_cold_light", "悍马侦察车", 4, 0))
	list.append(_platform("platform_cold_medium", "T-72主战坦克", 5, 2))
	list.append(_platform("platform_cold_ifv", "布雷德利步战车", 5, 8))
	list.append(_platform("platform_cold_scout", "BRDM-2侦察车", 4, 5))
	list.append(_platform("platform_cold_radar", "电子对抗站", 5, 4))
	list.append(_platform("platform_cold_carrier", "BMP步战车", 5, 8))

	# 现代载具（6种）
	list.append(_platform("platform_modern_light", "北极星全地形车", 3, 0))
	list.append(_platform("platform_modern_medium", "艾布拉姆斯坦克", 6, 1))
	list.append(_platform("platform_modern_radar", "相控阵雷达车", 5, 4))
	list.append(_platform("platform_modern_spg", "帕拉丁自行火炮", 5, 7))
	list.append(_platform("platform_modern_stealth", "光学隐匿侦察车", 5, 10))
	list.append(_platform("platform_modern_guard_heavy", "豹2A7主战坦克", 7, 1))

	# 近未来载具（4种）
	list.append(_platform("platform_future_light", "光学侦察车", 4, 10))
	list.append(_platform("platform_future_medium", "悬浮坦克", 5, 6))
	list.append(_platform("platform_future_radar", "量子感知平台", 5, 4))
	list.append(_platform("platform_future_heavy", "机甲步行者", 6, 2))

	# 终极载具
	list.append(_platform("omega_platform", "全装型机动舱", 9, 11))

	# ==================== 能量卡（仅战前能量 1～7 级） ====================

	list.append(_energy_start("energy_start_1", "战前能量 I", 5, 100.0, "common"))
	list.append(_energy_start("energy_start_2", "战前能量 II", 10, 150.0, "common"))
	list.append(_energy_start("energy_start_3", "战前能量 III", 15, 200.0, "common"))
	list.append(_energy_start("energy_start_4", "战前能量 IV", 20, 250.0, "uncommon"))
	list.append(_energy_start("energy_start_5", "战前能量 V", 25, 300.0, "uncommon"))
	list.append(_energy_start("energy_start_6", "战前能量 VI", 30, 350.0, "rare"))
	list.append(_energy_start("energy_start_7", "战前能量 VII", 35, 400.0, "rare"))

	# ==================== 法则卡（与 PhaseLaws 一一对应） ====================
	_append_all_law_cards(list)

	return list

## v3 重构：为平台卡片设置完整的战斗属性
static func _apply_platform_v3_stats(
	c: CardResource,
	era: int,
	pt: int,  # 旧 PlatformType，用于映射
	hp: float,
	speed: float,
	weapon_label: String,
	weapon_type_new: int,  # 新 WeaponTypeNew
	damage: float,
	range_val: float,
	interval: float,
	deploy_speed: int,
	attack_light: float,
	attack_armor: float,
	attack_air: float,
	defense_light: float,
	defense_armor: float,
	defense_air: float
) -> void:
	c.era = era
	c.combat_kind = int(UnitStatsTable.PLATFORM_TO_COMBAT_KIND.get(pt, 0))
	c.base_hp = hp
	c.base_speed = speed
	c.weapon_label = weapon_label
	c.weapon_type = weapon_type_new
	c.deploy_speed = deploy_speed

	# 单武器模式：使用 base_* 字段
	c.base_range = range_val
	c.base_interval = interval

	# 多维攻防
	c.attack_light = attack_light
	c.attack_armor = attack_armor
	c.attack_air = attack_air
	c.defense_light = defense_light
	c.defense_armor = defense_armor
	c.defense_air = defense_air

	# base_defense 用于防御百分比计算（取平均防御值）
	c.base_defense = (defense_light + defense_armor + defense_air) / 3.0

static func _platform(id: String, name: String, cost: float, pt: int) -> CardResource:
	var c = CardResource.new()
	c.card_id = id
	c.display_name = name
	c.card_type = GC.CardType.COMBAT_UNIT
	c.energy_cost = cost

	# v3 重构：使用新字段
	c.combat_kind = int(UnitStatsTable.PLATFORM_TO_COMBAT_KIND.get(pt, 0))

	# 根据卡牌ID设置详细属性
	match id:
		# 一战平台
		"platform_ww1_light":
			c.rarity = "common"
			c.type_line = "一战 — 轻型侦察车"
			c.summary_line = "移速 1.15｜耐久 65｜防御 2"
			c.description = "轻型装甲车，快速侦察用途。"
			c.flavor_text = ""总要有第一辆冲进火线的装甲车。""
			_apply_platform_v3_stats(c, 0, 0, 65.0, 115.0, "冲锋枪", 0, 14.0, 120.0, 0.8, 4, 14.0, 7.0, 0.0, 2.0, 3.0, 0.0)
		"platform_ww1_medium":
			c.rarity = "common"
			c.type_line = "一战 — 中型坦克"
			c.summary_line = "移速 0.40｜耐久 200｜防御 6"
			c.description = "菱形车身，跨越战壕的重型坦克。"
			c.flavor_text = "“当它开始加速，战线的形状就被重新焊接。”"
			_apply_platform_v3_stats(c, 0, 2, 200.0, 40.0, "机枪", 0, 28.0, 140.0, 1.2, 2, 28.0, 35.0, 0.0, 4.0, 8.0, 0.0)
		"platform_ww1_fort":
			c.rarity = "uncommon"
			c.type_line = "一战 — 固定阵地"
			c.summary_line = "移速 0｜耐久 260｜防御 8"
			c.description = "固定防御工事，不可移动。"
			c.flavor_text = ""炮位一旦落下，战场就多了一座新堡。""
			_apply_platform_v3_stats(c, 0, 3, 260.0, 0.0, "机枪", 0, 25.0, 180.0, 1.5, 1, 25.0, 30.0, 0.0, 6.0, 10.0, 0.0)
		"platform_ww1_medic":
			c.rarity = "common"
			c.type_line = "一战 — 野战救护"
			c.summary_line = "移速 0.75｜耐久 80｜防御 2"
			c.description = "轻型野战救护车，脱战缓慢回复附近友军。"
			c.flavor_text = ""把伤员从死神手里抢回来。""
			_apply_platform_v3_stats(c, 0, 9, 80.0, 75.0, "手枪", 0, 8.0, 80.0, 1.0, 3, 8.0, 4.0, 0.0, 2.0, 2.0, 0.0)
		"platform_ww1_radar":
			c.rarity = "common"
			c.type_line = "一战 — 野战观测站"
			c.summary_line = "移速 0｜耐久 180｜防御 4"
			c.description = "固定观测站，可侦测敌方位置。"
			c.flavor_text = ""看得见，才打得着。""
			_apply_platform_v3_stats(c, 0, 4, 180.0, 0.0, "步枪", 0, 12.0, 300.0, 2.0, 1, 12.0, 8.0, 0.0, 3.0, 4.0, 0.0)
		# 二战平台
		"platform_ww2_light":
			c.rarity = "common"
			c.type_line = "二战 — 轮式侦察车"
			c.summary_line = "移速 1.35｜耐久 50｜防御 2"
			c.description = "轮式侦察车，公路机动性强。"
			c.flavor_text = ""先看到，先开火。""
			_apply_platform_v3_stats(c, 1, 5, 50.0, 135.0, "冲锋枪", 0, 16.0, 120.0, 0.7, 4, 16.0, 8.0, 0.0, 2.0, 3.0, 0.0)
		"platform_ww2_medium":
			c.rarity = "common"
			c.type_line = "二战 — 中型坦克"
			c.summary_line = "移速 0.75｜耐久 110｜防御 5"
			c.description = "均衡型中型坦克。"
			c.flavor_text = ""不是墙，而是会向前推进的装甲墙。""
			_apply_platform_v3_stats(c, 1, 1, 110.0, 75.0, "步枪", 0, 20.0, 150.0, 1.0, 3, 20.0, 25.0, 0.0, 3.0, 6.0, 0.0)
		"platform_ww2_heavy":
			c.rarity = "rare"
			c.type_line = "二战 — 重型坦克"
			c.summary_line = "移速 0.40｜耐久 200｜防御 8"
			c.description = "重型坦克，装甲厚但速度慢。"
			c.flavor_text = ""装甲就是最好的防御。""
			_apply_platform_v3_stats(c, 1, 2, 200.0, 40.0, "火箭炮", 1, 35.0, 200.0, 2.5, 2, 25.0, 45.0, 0.0, 5.0, 10.0, 0.0)
		"platform_ww2_raider":
			c.rarity = "common"
			c.type_line = "二战 — 轻型突击车"
			c.summary_line = "移速 1.0｜耐久 90｜防御 3"
			c.description = "轻型四轮突击车，速度极快但装甲薄弱。"
			c.flavor_text = ""快到子弹追不上。""
			_apply_platform_v3_stats(c, 1, 6, 90.0, 100.0, "机枪", 0, 22.0, 130.0, 0.9, 4, 22.0, 15.0, 0.0, 3.0, 4.0, 0.0)
		"platform_ww2_radar":
			c.rarity = "common"
			c.type_line = "二战 — 雷达指挥车"
			c.summary_line = "移速 0｜耐久 180｜防御 4"
			c.description = "搭载早期雷达，可远距离侦测敌军动向。"
			c.flavor_text = "天线转动，战场透明。"
			_apply_platform_v3_stats(c, 1, 4, 180.0, 0.0, "步枪", 0, 14.0, 320.0, 1.8, 1, 14.0, 10.0, 0.0, 3.0, 5.0, 0.0)
		"platform_ww2_siege":
			c.rarity = "common"
			c.type_line = "二战 — 迫击炮"
			c.summary_line = "移速 0｜耐久 300｜防御 8"
			c.description = "重型迫击炮，曲射越过障碍攻击后方。"
			c.flavor_text = ""绕过去"只是弹道的选择。"
			_apply_platform_v3_stats(c, 1, 7, 300.0, 0.0, "火箭炮", 1, 40.0, 250.0, 3.0, 1, 20.0, 50.0, 0.0, 4.0, 12.0, 0.0)
		"platform_ww2_fortress":
			c.rarity = "common"
			c.type_line = "二战 — 固定碉堡"
			c.summary_line = "移速 0｜耐久 260｜防御 8"
			c.description = "钢筋混凝土碉堡,固定阵地防御。"
			c.flavor_text = ""混凝土浇筑的勇气。""
			_apply_platform_v3_stats(c, 1, 3, 260.0, 0.0, "机枪", 0, 24.0, 160.0, 1.3, 1, 24.0, 28.0, 0.0, 6.0, 10.0, 0.0)
		# 冷战平台
		"platform_cold_light":
			c.rarity = "common"
			c.type_line = "冷战 — 轻型多用途车"
			c.summary_line = "移速 1.15｜耐久 65｜防御 3"

static func test():
	print("Half1 OK")
