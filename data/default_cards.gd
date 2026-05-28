extends RefCounted
## 默认战斗卡数据（v3：100单位完整时代系统）

const GC = preload("res://resources/game_constants.gd")
const RealWorldUnitLabels = preload("res://data/real_world_unit_labels.gd")
const EnemyBlueprints = preload("res://data/enemy_blueprints.gd")
const PhaseLaws = preload("res://data/phase_laws.gd")

## 静态缓存：避免每次 get_card_by_id 都重新创建
static var _all_cards_cache: Array = []
static var _id_lookup_cache: Dictionary = {}

## 确保缓存已构建
static func _ensure_card_cache() -> void:
	if not _all_cards_cache.is_empty():
		return
	_all_cards_cache = create_all()
	for c in _all_cards_cache:
		if c is CardResource:
			_id_lookup_cache[c.card_id] = c

static func create_all() -> Array:
	var list: Array = []
	
	# ==================== 一战单位（20个）====================
	list.append(_unit("ww1_mp18", "MP18突击班", 0, 0, 15, 1.5, 4, 2, 10, 35, 0, 0, 8, 5, 3))
	list.append(_unit("ww1_mauser", "毛瑟步枪班", 0, 0, 15, 0.67, 3, 3, 10, 30, 0, 0, 8, 5, 3))
	list.append(_unit("ww1_enfield", "李恩菲尔德班", 0, 0, 15, 0.83, 3, 3, 10, 30, 0, 0, 8, 5, 3))
	list.append(_unit("ww1_mg08", "MG08机枪巢", 0, 2, 23, 2.0, 0, 4, 15, 45, 0, 25, 12, 8, 10))
	list.append(_unit("ww1_vickers", "维克斯机枪巢", 0, 2, 23, 1.8, 0, 4, 15, 40, 0, 22, 12, 8, 10))
	list.append(_unit("ww1_m81", "81mm迫击炮组", 0, 2, 23, 0.5, 1, 99, 12, 40, 20, 0, 6, 5, 3))
	list.append(_unit("ww1_m76", "76mm迫击炮组", 0, 2, 23, 0.5, 1, 99, 12, 38, 18, 0, 6, 5, 3))
	list.append(_unit("ww1_storm", "暴风突击队", 0, 0, 20, 1.5, 5, 2, 12, 40, 5, 0, 10, 6, 4))
	list.append(_unit("ww1_rolls", "罗尔斯装甲车", 0, 1, 45, 1.0, 5, 3, 14, 25, 35, 5, 18, 22, 10))
	list.append(_unit("ww1_lanchest", "兰彻斯特装甲车", 0, 1, 45, 1.0, 5, 3, 14, 22, 32, 8, 18, 22, 10))
	list.append(_unit("ww1_ft17", "FT-17轻型坦克", 0, 1, 45, 0.83, 3, 3, 16, 28, 40, 0, 20, 25, 8))
	list.append(_unit("ww1_saint", "圣沙蒙坦克", 0, 1, 50, 0.67, 2, 4, 20, 20, 50, 0, 25, 35, 8))
	list.append(_unit("ww1_a7v", "A7V重型坦克", 0, 1, 50, 0.5, 2, 4, 20, 18, 48, 0, 28, 38, 8))
	list.append(_unit("ww1_mark4", "马克IV型坦克", 0, 1, 48, 0.67, 2, 3, 18, 22, 45, 0, 22, 30, 8))
	list.append(_unit("ww1_77mm", "77mm野战炮", 0, 2, 23, 0.33, 0, 99, 14, 45, 30, 0, 6, 8, 4))
	list.append(_unit("ww1_105mm", "105mm榴弹炮", 0, 2, 23, 0.25, 0, 99, 16, 50, 35, 0, 6, 8, 4))
	list.append(_unit("ww1_37mm", "37mm高射炮", 0, 2, 23, 1.5, 0, 5, 14, 10, 8, 50, 8, 8, 18))
	list.append(_unit("ww1_cavalry", "骑兵斥候", 0, 0, 15, 1.0, 6, 1, 8, 20, 0, 0, 6, 4, 2))
	list.append(_unit("ww1_flame", "火焰喷射兵", 0, 0, 18, 1.0, 3, 1, 12, 45, 15, 0, 8, 5, 3))
	list.append(_unit("ww1_engineer", "工兵班", 0, 2, 20, 1.0, 3, 2, 12, 30, 25, 0, 10, 8, 5))
	
	# ==================== 二战单位（20个）====================
	list.append(_unit("ww2_thompson", "汤普森班", 1, 0, 60, 1.5, 4, 2, 10, 55, 0, 0, 15, 10, 6))
	list.append(_unit("ww2_garand", "加兰德班", 1, 0, 60, 0.83, 3, 3, 10, 50, 0, 0, 15, 10, 6))
	list.append(_unit("ww2_mp40", "MP40班", 1, 0, 60, 1.5, 4, 2, 10, 52, 0, 0, 15, 10, 6))
	list.append(_unit("ww2_ppsh", "波波沙班", 1, 0, 60, 1.8, 4, 2, 10, 54, 0, 0, 15, 10, 6))
	list.append(_unit("ww2_mg42", "MG42机枪组", 1, 2, 90, 2.5, 0, 4, 15, 70, 0, 45, 20, 15, 18))
	list.append(_unit("ww2_browning", "勃朗宁机枪组", 1, 2, 90, 2.0, 0, 4, 15, 65, 0, 40, 20, 15, 18))
	list.append(_unit("ww2_panzerschrek", "铁拳反坦克组", 1, 0, 65, 0.33, 3, 2, 12, 15, 90, 0, 12, 10, 5))
	list.append(_unit("ww2_bazooka", "巴祖卡组", 1, 0, 65, 0.33, 3, 2, 12, 12, 85, 0, 12, 10, 5))
	list.append(_unit("ww2_m81 mortar", "81mm迫击炮", 1, 2, 90, 0.5, 1, 99, 12, 55, 30, 0, 12, 10, 6))
	list.append(_unit("ww2_m120 mortar", "120mm重迫击炮", 1, 2, 90, 0.33, 1, 99, 14, 65, 40, 0, 12, 10, 6))
	list.append(_unit("ww2_pz3", "三号坦克", 1, 1, 180, 0.83, 3, 3, 16, 40, 80, 0, 40, 55, 15))
	list.append(_unit("ww2_pz4", "四号坦克", 1, 1, 180, 0.83, 3, 3, 18, 45, 90, 0, 42, 60, 15))
	list.append(_unit("ww2_panther", "黑豹坦克", 1, 1, 180, 0.83, 3, 4, 18, 45, 110, 0, 45, 70, 15))
	list.append(_unit("ww2_tiger", "虎式坦克", 1, 1, 180, 0.67, 2, 4, 22, 35, 130, 0, 55, 80, 18))
	list.append(_unit("ww2_kingtiger", "虎王坦克", 1, 1, 180, 0.5, 1, 4, 25, 30, 150, 0, 60, 85, 18))
	list.append(_unit("ww2_t34_76", "T-34/76坦克", 1, 1, 180, 0.83, 4, 3, 16, 45, 85, 0, 40, 60, 15))
	list.append(_unit("ww2_t34_85", "T-34/85坦克", 1, 1, 180, 0.83, 4, 3, 18, 45, 100, 0, 42, 65, 15))
	list.append(_unit("ww2_is2", "IS-2重型坦克", 1, 1, 180, 0.5, 2, 4, 22, 35, 135, 0, 55, 80, 18))
	list.append(_unit("ww2_sherman", "M4谢尔曼", 1, 1, 180, 0.83, 4, 3, 16, 45, 80, 0, 40, 55, 15))
	list.append(_unit("ww2_hellcat", "M18地狱猫", 1, 1, 170, 0.83, 5, 3, 16, 30, 95, 0, 25, 40, 12))
	
	# ==================== 冷战单位（20个）====================
	list.append(_unit("cold_ak47", "AK-47步兵班", 2, 0, 160, 1.5, 4, 2, 10, 90, 0, 0, 30, 20, 12))
	list.append(_unit("cold_m14", "M14步兵班", 2, 0, 160, 0.83, 4, 3, 10, 85, 0, 0, 30, 20, 12))
	list.append(_unit("cold_m60 mg", "M60机枪班", 2, 0, 170, 2.0, 3, 4, 12, 110, 0, 60, 32, 22, 15))
	list.append(_unit("cold_rpk", "RPK机枪班", 2, 0, 170, 1.8, 3, 3, 12, 105, 0, 55, 32, 22, 15))
	list.append(_unit("cold_btr60", "BTR-60装甲车", 2, 1, 480, 1.0, 4, 3, 14, 60, 70, 40, 50, 60, 35))
	list.append(_unit("cold_m113", "M113装甲车", 2, 2, 240, 0.83, 4, 2, 12, 40, 30, 20, 35, 45, 25))
	list.append(_unit("cold_bmp1", "BMP-1步战车", 2, 1, 480, 0.83, 4, 99, 16, 70, 120, 30, 55, 70, 30))
	list.append(_unit("cold_bradley", "M2布雷德利", 2, 1, 480, 0.83, 4, 99, 18, 75, 130, 35, 55, 75, 30))
	list.append(_unit("cold_t55", "T-55坦克", 2, 1, 480, 0.67, 3, 3, 16, 60, 140, 0, 60, 85, 25))
	list.append(_unit("cold_t62", "T-62坦克", 2, 1, 480, 0.67, 3, 4, 18, 60, 155, 0, 60, 90, 25))
	list.append(_unit("cold_t72", "T-72坦克", 2, 1, 480, 0.67, 3, 4, 20, 55, 180, 0, 65, 100, 30))
	list.append(_unit("cold_m60t", "M60坦克", 2, 1, 480, 0.67, 3, 3, 18, 55, 160, 0, 60, 95, 30))
	list.append(_unit("cold_m1", "M1主战坦克", 2, 1, 480, 0.67, 3, 4, 20, 55, 175, 0, 65, 100, 30))
	list.append(_unit("cold_leo1", "豹1坦克", 2, 1, 480, 0.83, 4, 3, 16, 55, 150, 0, 50, 80, 25))
	list.append(_unit("cold_chieftain", "酋长坦克", 2, 1, 480, 0.5, 2, 4, 20, 50, 165, 0, 65, 100, 25))
	list.append(_unit("cold_zsu23", "ZSU-23-4自行高炮", 2, 2, 240, 2.5, 3, 5, 16, 30, 20, 150, 25, 30, 50))
	list.append(_unit("cold_sam7", "萨姆-7防空组", 2, 0, 165, 0.33, 3, 99, 14, 5, 5, 120, 15, 12, 20))
	list.append(_unit("cold_mig21", "米格-21战机", 2, 3, 400, 1.0, 6, 99, 18, 60, 50, 160, 15, 20, 40))
	list.append(_unit("cold_f4", "F-4鬼怪战机", 2, 3, 400, 1.0, 6, 99, 20, 80, 70, 180, 15, 20, 40))
	list.append(_unit("cold_spetsnaz", "阿尔法特种部队", 2, 0, 180, 1.5, 5, 2, 14, 100, 30, 15, 35, 25, 15))
	
	# ==================== 现代单位（20个）====================
	list.append(_unit("mod_marine", "海军陆战队", 3, 0, 320, 1.5, 4, 2, 10, 140, 0, 0, 50, 35, 20))
	list.append(_unit("mod_ranger", "游骑兵", 3, 0, 340, 1.5, 5, 2, 12, 160, 20, 10, 55, 38, 22))
	list.append(_unit("mod_javelin", "标枪导弹兵", 3, 0, 330, 0.25, 3, 99, 14, 25, 250, 20, 30, 25, 15))
	list.append(_unit("mod_stinger", "毒刺导弹兵", 3, 0, 320, 0.33, 3, 99, 14, 10, 10, 220, 25, 20, 25))
	list.append(_unit("mod_technical", "武装皮卡", 3, 0, 280, 1.0, 5, 3, 8, 80, 40, 15, 25, 20, 12))
	list.append(_unit("mod_stryker_mgs", "斯特赖克MGS", 3, 1, 900, 0.67, 4, 4, 16, 80, 220, 0, 70, 90, 30))
	list.append(_unit("mod_stryker_m2", "斯特赖克M2", 3, 1, 880, 1.0, 4, 3, 14, 100, 120, 60, 65, 80, 40))
	list.append(_unit("mod_hummer_tow", "悍马·陶式", 3, 0, 330, 0.25, 5, 99, 14, 20, 260, 10, 30, 25, 15))
	list.append(_unit("mod_hummer_m2", "悍马·M2", 3, 0, 300, 1.0, 5, 3, 10, 90, 20, 40, 30, 25, 20))
	list.append(_unit("mod_m1a1", "M1A1坦克", 3, 1, 950, 0.67, 3, 4, 20, 70, 280, 0, 90, 140, 35))
	list.append(_unit("mod_m1a2", "M1A2艾布拉姆斯", 3, 1, 960, 0.67, 3, 4, 22, 70, 300, 0, 95, 150, 35))
	list.append(_unit("mod_m1a2sep", "M1A2 SEP", 3, 1, 960, 0.67, 3, 4, 24, 75, 320, 0, 100, 160, 35))
	list.append(_unit("mod_t90", "T-90坦克", 3, 1, 950, 0.67, 3, 4, 20, 80, 280, 0, 85, 135, 35))
	list.append(_unit("mod_leo2a6", "豹2A6坦克", 3, 1, 960, 0.67, 3, 4, 22, 70, 310, 0, 90, 145, 35))
	list.append(_unit("mod_challenger2", "挑战者2坦克", 3, 1, 950, 0.5, 2, 4, 22, 65, 290, 0, 100, 160, 35))
	list.append(_unit("mod_ah64", "AH-64阿帕奇", 3, 3, 800, 0.67, 5, 99, 20, 160, 280, 100, 25, 35, 30))
	list.append(_unit("mod_ah1", "AH-1眼镜蛇", 3, 3, 780, 0.67, 5, 99, 18, 140, 250, 80, 25, 35, 30))
	list.append(_unit("mod_uh60", "UH-60黑鹰", 3, 3, 700, 0.5, 5, 99, 12, 40, 20, 30, 20, 25, 20))
	list.append(_unit("mod_m270", "M270火箭炮", 3, 2, 480, 0.2, 1, 99, 20, 180, 120, 0, 20, 25, 15))
	list.append(_unit("mod_m6", "自行高炮M6", 3, 2, 480, 2.0, 3, 5, 18, 40, 30, 280, 30, 35, 60))
	
	# ==================== 近未来单位（20个）====================
	list.append(_unit("fut_swarm", "蜂群无人机", 4, 3, 1200, 2.0, 6, 99, 8, 100, 60, 80, 15, 15, 25))
	list.append(_unit("fut_scout_drone", "侦察无人机", 4, 3, 1100, 0.5, 7, 99, 6, 40, 20, 30, 12, 12, 20))
	list.append(_unit("fut_attack_drone", "攻击无人机", 4, 3, 1300, 1.0, 6, 99, 10, 150, 280, 100, 20, 25, 30))
	list.append(_unit("fut_cyborg", "机械步兵", 4, 0, 500, 1.5, 4, 3, 12, 200, 0, 0, 80, 60, 40))
	list.append(_unit("fut_heavy_trooper", "重装机兵", 4, 0, 520, 1.0, 3, 3, 15, 220, 30, 15, 100, 80, 50))
	list.append(_unit("fut_scout_mech", "侦察机甲", 4, 0, 500, 1.5, 5, 3, 12, 150, 80, 40, 60, 50, 35))
	list.append(_unit("fut_assault_mech", "突击机甲", 4, 1, 1500, 0.83, 4, 4, 18, 120, 380, 50, 100, 160, 60))
	list.append(_unit("fut_heavy_mech", "重装机甲", 4, 1, 1580, 0.5, 2, 4, 25, 80, 500, 60, 140, 220, 70))
	list.append(_unit("fut_hovertank", "悬浮坦克", 4, 1, 1500, 0.83, 5, 4, 22, 100, 420, 50, 80, 140, 60))
	list.append(_unit("fut_howitzer", "悬浮自行火炮", 4, 2, 795, 0.25, 4, 99, 20, 280, 200, 0, 40, 50, 30))
	list.append(_unit("fut_prism", "光棱坦克", 4, 1, 1550, 0.67, 3, 5, 20, 180, 350, 100, 80, 140, 80))
	list.append(_unit("fut_aa_hover", "防空悬浮车", 4, 2, 780, 2.5, 5, 5, 16, 30, 20, 400, 30, 40, 100))
	list.append(_unit("fut_stealth_bomber", "隐形轰炸机", 4, 3, 1400, 0.2, 6, 99, 24, 300, 350, 30, 25, 35, 40))
	list.append(_unit("fut_space_fighter", "空天战斗机", 4, 3, 1325, 1.0, 7, 99, 22, 120, 100, 350, 30, 40, 80))
	list.append(_unit("fut_spectre", "幽灵特工", 4, 0, 530, 1.5, 5, 3, 16, 220, 80, 50, 60, 50, 40))
	list.append(_unit("fut_nano_drone", "纳米修复机", 4, 3, 1000, 0.5, 5, 99, 10, 0, 0, 0, 20, 30, 30))
	list.append(_unit("fut_shield", "力场发生器", 4, 2, 750, 0.0, 0, 0, 15, 0, 0, 0, 100, 150, 120))
	list.append(_unit("fut_colossus", "巨神机甲", 4, 1, 1590, 0.33, 1, 5, 30, 100, 550, 80, 150, 250, 80))
	list.append(_unit("fut_stormcore", "风暴核心原型", 4, 2, 800, 0.2, 0, 99, 0, 200, 200, 200, 80, 100, 100))
	list.append(_unit("fut_nexus", "虚空领主", 4, 1, 1590, 0.5, 2, 99, 35, 150, 480, 120, 120, 200, 100))

	# ==================== 终极单位 ====================
	var omega := _unit("omega_platform", "全装型机动舱", 4, 1, 9999, 0.45, 7, 3, 9, 55, 80, 0, 8, 18, 0)
	omega.rarity = "legendary"
	omega.type_line = "终极 — 多槽重装"
	omega.summary_line = "移速 0.30｜耐久 240｜防御 13"
	omega.description = "可以同时装备3张武器卡，作为整条战线的核心输出。终极单位。"
	omega.flavor_text = "当它开火时，战场会短暂安静。"
	omega.base_hp = 240.0
	omega.power = 9999
	list.append(omega)

	# ==================== 能量卡（战前能量 1～7 级）====================
	list.append(_energy_start("energy_start_1", "战前能量 I", 5, 100.0, "common"))
	list.append(_energy_start("energy_start_2", "战前能量 II", 10, 150.0, "common"))
	list.append(_energy_start("energy_start_3", "战前能量 III", 15, 200.0, "common"))
	list.append(_energy_start("energy_start_4", "战前能量 IV", 20, 250.0, "uncommon"))
	list.append(_energy_start("energy_start_5", "战前能量 V", 25, 300.0, "uncommon"))
	list.append(_energy_start("energy_start_6", "战前能量 VI", 30, 350.0, "rare"))
	list.append(_energy_start("energy_start_7", "战前能量 VII", 35, 400.0, "rare"))

	return list

## 返回所有蓝图 ID（战斗卡 + 能量卡 + 敌人蓝图）
static func get_all_blueprint_ids() -> Array:
	var ids: Array = []
	_ensure_card_cache()
	for c in _all_cards_cache:
		if c is CardResource:
			var card := c as CardResource
			if card.card_type == GC.CardType.COMBAT_UNIT or card.card_type == GC.CardType.ENERGY:
				ids.append(card.card_id)
	# 添加敌人掉落的高级蓝图ID
	var enemy_blueprint_ids = EnemyBlueprints.get_all_enemy_blueprint_ids()
	for id in enemy_blueprint_ids:
		if id is String and not ids.has(id):
			ids.append(id)
	return ids

## 根据 PhaseLaws 定义生成法则卡模板（印制/发奖时用 clone()）
static func create_law_card_resource(law_id: String) -> CardResource:
	var law: Dictionary = PhaseLaws.get_by_id(law_id)
	if law.is_empty():
		return null
	var kind: String = String(law.get("kind", ""))
	var c := CardResource.new()
	c.card_id = law_id
	c.linked_law_id = law_id
	c.display_name = String(law.get("name", law_id))
	c.card_type = GC.CardType.LAW
	c.rarity = "rare" if kind == "passive" else "epic"
	var bc: Dictionary = law.get("battle_cost", {})
	var ac: Dictionary = law.get("activate_cost", {})
	if kind == "active":
		c.energy_cost = float(bc.get("energy", 0.0))
		c.type_line = "法则 — 主动"
		var nano_b: int = int(bc.get("nano", 0))
		if nano_b > 0:
			c.summary_line = "战中 %.0f⚡｜纳米 %d" % [c.energy_cost, nano_b]
		else:
			c.summary_line = "战中能耗 %.0f⚡" % c.energy_cost
	else:
		c.energy_cost = float(ac.get("nano", 0))
		c.type_line = "法则 — 被动"
		c.summary_line = "激活纳米 %d" % int(ac.get("nano", 0))
	c.description = "自蓝图印制；装配至相位仪红/蓝槽后，在战前环境满足时可激活。"
	c.flavor_text = "\"法则需要载体。\""
	return c

## 根据 card_id 获取卡牌（兼容层）
static func get_card_by_id(card_id: String) -> CardResource:
	_ensure_card_cache()
	if _id_lookup_cache.has(card_id):
		return _id_lookup_cache[card_id] as CardResource
	return null

## 创建战斗单位辅助函数
## 参数：id, name, era(0-4), combat_kind(0-3), power, attack_speed, deploy_speed, range, energy_cost, 
##      attack_light, attack_armor, attack_air, defense_light, defense_armor, defense_air
static func _unit(
	id: String, name: String, era: int, combat_kind: int, power: int,
	attack_speed: float, deploy_speed: int, range: int, energy_cost: int,
	atk_light: int, atk_armor: int, atk_air: int,
	def_light: int, def_armor: int, def_air: int
) -> CardResource:
	var c = CardResource.new()
	c.card_id = id
	c.display_name = name
	c.card_type = GC.CardType.COMBAT_UNIT
	
	# === 新字段（v3）===
	c.era = era
	c.power = power
	c.weapon_type = _infer_weapon_type(combat_kind, range, atk_light, atk_armor, atk_air)
	c.combat_kind = combat_kind
	c.attack_speed = attack_speed
	c.deploy_speed = deploy_speed
	c.range_value = range
	c.energy_cost = float(energy_cost)
	
	# === 多维攻击 ===
	c.attack_light = atk_light
	c.attack_armor = atk_armor
	c.attack_air = atk_air
	
	# === 多维防御 ===
	c.defense_light = def_light
	c.defense_armor = def_armor
	c.defense_air = def_air
	
	# === 推断其他属性 ===
	c.base_hp = _infer_hp(power, combat_kind)
	c.rarity = _infer_rarity(era, power)
	c.type_line = _format_type_line(era, combat_kind)
	c.summary_line = _format_summary(c)
	c.description = ""
	c.flavor_text = ""
	
	return c

## 推断武器类型
static func _infer_weapon_type(combat_kind: int, range: int, atk_light: int, atk_armor: int, atk_air: int) -> int:
	# 空中单位 → AERIAL
	if combat_kind == 3:  # AIR
		return GC.WeaponType.AERIAL
	
	# 曲射单位（range=99 且对地对空都有攻击）→ INDIRECT
	if range >= 99:
		return GC.WeaponType.INDIRECT
	
	# 默认直射
	return GC.WeaponType.DIRECT

## 推断HP
static func _infer_hp(power: int, combat_kind: int) -> int:
	var base = power * 2
	match combat_kind:
		0:  # LIGHT
			base = power * 1.5
		1:  # ARMOR
			base = power * 3.0
		2:  # SUPPORT
			base = power * 2.0
		3:  # AIR
			base = power * 1.2
	return int(base)

## 推断稀有度
static func _infer_rarity(era: int, power: int) -> String:
	if era <= 1:
		return "common"
	elif era == 2:
		return "rare" if power > 400 else "uncommon"
	elif era == 3:
		return "epic" if power > 800 else "rare"
	else:  # era 4
		return "mythic" if power > 1500 else "legendary"

## 格式化类型行
static func _format_type_line(era: int, combat_kind: int) -> String:
	var era_names = ["一战", "二战", "冷战", "现代", "近未来"]
	var kind_names = ["轻装", "装甲", "支援", "空中"]
	return "%s — %s" % [era_names[era], kind_names[combat_kind]]

## 格式化摘要
static func _format_summary(c: CardResource) -> String:
	var parts = []
	parts.append("战力 %d" % c.power)
	
	if c.attack_speed > 0:
		parts.append("攻速 %.1f/s" % c.attack_speed)
	
	parts.append("部署 %d" % c.deploy_speed)
	
	if c.range_value < 99:
		parts.append("射程 %d" % c.range_value)
	else:
		parts.append("全图")
	
	# 显示主要攻击类型
	var main_atk = 0
	var main_type = ""
	if c.attack_light >= c.attack_armor and c.attack_light >= c.attack_air:
		main_atk = c.attack_light
		main_type = "对轻"
	elif c.attack_armor >= c.attack_light and c.attack_armor >= c.attack_air:
		main_atk = c.attack_armor
		main_type = "对甲"
	else:
		main_atk = c.attack_air
		main_type = "对空"
	
	if main_atk > 0:
		parts.append("%s %d" % [main_type, main_atk])
	
	return "｜".join(parts)


## 平台类型显示名（兼容旧 platform_type 引用）
static func get_platform_display_name(platform_type: int) -> String:
	return RealWorldUnitLabels.platform_chassis_long(platform_type)


## 武器类型显示名（兼容旧 weapon_type 引用）
static func get_weapon_display_name(weapon_type: int) -> String:
	return RealWorldUnitLabels.weapon_kind_long(weapon_type)

## 生成战前能量卡
static func _energy_start(id: String, name: String, cost: float, bonus: float, rarity: String = "common") -> CardResource:
	var c = CardResource.new()
	c.card_id = id
	c.display_name = name
	c.card_type = GC.CardType.ENERGY
	c.energy_cost = cost
	c.energy_grant = bonus
	c.rarity = rarity
	c.type_line = "战前 — 能量储备"
	c.summary_line = "开局额外 +%d⚡" % int(bonus)
	c.description = "作为准备卡装入相位仪时，战斗开始时你的初始能量 +%d 点，可叠加多张。" % int(bonus)
	c.flavor_text = "把能量灌满电枢再出击。"
	return c
