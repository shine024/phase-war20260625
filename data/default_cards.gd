extends RefCounted
## 默认战斗卡数据(v5.0:110单位 + 每目标攻击速度 + 堡垒类)

const GC = preload("res://resources/game_constants.gd")
const RealWorldUnitLabels = preload("res://data/real_world_unit_labels.gd")
const EnemyArchetypes = preload("res://data/enemy_archetypes.gd")
const EnemyBlueprints = preload("res://data/enemy_blueprints.gd")
const PhaseLaws = preload("res://data/phase_laws.gd")

## 静态缓存:避免每次 get_card_by_id 都重新创建
static var _all_cards_cache: Array = []
static var _id_lookup_cache: Dictionary = {}

static var _cache_building: bool = false

## 确保缓存已构建
static func _ensure_card_cache() -> void:
	if not _all_cards_cache.is_empty():
		return
	if _cache_building:
		push_warning("[DefaultCards] 缓存正在构建中,防止重入")
		return # 防重入:构建过程中被间接回调时直接返回,避免无限递归
	_cache_building = true
	_all_cards_cache = create_all()
	for c in _all_cards_cache:
		if c is CardResource:
			_id_lookup_cache[c.card_id] = c
		else:
			push_error("[DefaultCards] create_all() 返回了非 CardResource 对象: %s" % str(c))
	_cache_building = false
	print("[DefaultCards] 缓存构建完成,共 %d 张卡牌" % _all_cards_cache.size())

## 参数:id, name, era(0-4), combat_kind(0-4), power, deploy_speed, range, energy_cost, hp,
##      attack_light, attack_light_speed, attack_light_windup, attack_light_active,
##      attack_armor, attack_armor_speed, attack_armor_windup, attack_armor_active,
##      attack_air, attack_air_speed, attack_air_windup, attack_air_active,
##      defense_light, defense_armor, defense_air,
##      weapon_light_name, weapon_armor_name, weapon_air_name
static func _unit(
	id: String, name: String, era: int, combat_kind: int, power: int,
	deploy_speed: int, range_val: int, energy_cost: int, hp: int,
	atk_l: int, atk_l_speed: float, atk_l_windup: float, atk_l_active: float,
	atk_a: int, atk_a_speed: float, atk_a_windup: float, atk_a_active: float,
	atk_air: int, atk_air_speed: float, atk_air_windup: float, atk_air_active: float,
	def_l: int, def_a: int, def_air: int, w_light: String = "", w_armor: String = "", w_air: String = ""
) -> CardResource:
	var c = CardResource.new()

	c.card_id = id
	c.display_name = name
	c.card_type = GC.CardType.COMBAT_UNIT
	c.era = era
	c.combat_kind = combat_kind
	c.power = power
	c.deploy_speed = deploy_speed
	c.range_value = range_val
	c.energy_cost = energy_cost
	c.base_hp = float(hp)

	# 攻击属性
	c.attack_light = atk_l
	c.attack_light_speed = atk_l_speed
	c.attack_light_windup = atk_l_windup
	c.attack_light_active = atk_l_active

	c.attack_armor = atk_a
	c.attack_armor_speed = atk_a_speed
	c.attack_armor_windup = atk_a_windup
	c.attack_armor_active = atk_a_active

	c.attack_air = atk_air
	c.attack_air_speed = atk_air_speed
	c.attack_air_windup = atk_air_windup
	c.attack_air_active = atk_air_active

	# 防御属性
	c.defense_light = def_l
	c.defense_armor = def_a
	c.defense_air = def_air

	# 武器名称
	c.weapon_names[0] = w_light
	c.weapon_names[1] = w_armor
	c.weapon_names[2] = w_air

	# 派生属性
	c.attack_speed = _calculate_attack_speed(atk_l, atk_a, atk_air, atk_l_speed, atk_a_speed, atk_air_speed)
	c.weapon_type = _infer_weapon_type(combat_kind, range_val, atk_l, atk_a, atk_air)
	c.unit_subtype = _infer_unit_subtype(combat_kind, range_val, atk_l, atk_a, atk_air, w_light, w_armor, w_air)
	c.rarity = _infer_rarity(era, power)
	c.type_line = _format_type_line(era, combat_kind)
	c.summary_line = _format_summary(c)

	# 基础属性
	c.platform_type = combat_kind

	return c

## 计算综合攻击速度(取主要攻击类型的攻速)
static func _calculate_attack_speed(atk_l: int, atk_a: int, atk_air: int, speed_l: float, speed_a: float, speed_air: float) -> float:
	if atk_l >= atk_a and atk_l >= atk_air:
		return speed_l
	elif atk_a >= atk_l and atk_a >= atk_air:
		return speed_a
	else:
		return speed_air

## v6.2: 推断单位子类标记（用于战斗定位差异化修正）
## 规则：
##   - combat_kind=4 (FORT) → FORT 子类
##   - combat_kind=2 (SUPPORT) 中：
##       * range≥99 或 atk_a≥atk_l（重火力）→ ARTILLERY 火炮
##       * atk_air 为主要攻击（防空炮）→ ANTI_AIR 防空特化
##       * 其余（机枪巢/工兵）→ SUPPORT 辅助
##   - combat_kind=0/1/3 → NONE（普通轻装/装甲/空中）
##   注：combat_kind 值保持不变（仍为0-4），子类仅用于修正差异化。
static func _infer_unit_subtype(combat_kind: int, range_val: int, atk_l: int, atk_a: int, atk_air: int, w_light: String, w_armor: String, w_air: String) -> int:
	if combat_kind == GC.CombatKind.FORT:
		return GC.UnitSubType.FORT
	if combat_kind == GC.CombatKind.SUPPORT:
		# 防空特化：对空攻击是主要攻击维度
		if atk_air > atk_l and atk_air > atk_a and atk_air > 0:
			return GC.UnitSubType.ANTI_AIR
		# 火炮：远射程 或 对装甲为主攻击（重火力）
		if range_val >= 99 or atk_a >= atk_l and atk_a > 0:
			return GC.UnitSubType.ARTILLERY
		# 其余支援（机枪巢/工兵）
		return GC.UnitSubType.SUPPORT
	return GC.UnitSubType.NONE

static func create_all() -> Array:
	var list: Array = []

	# ==================== 一战单位(20个)====================
	list.append(_unit("ww1_mp18", "MP18突击班", 0, 0, 15, 4, 2, 10, 100, 35, 1.5, 0.15, 0.08, 0, 0, 0, 0, 0, 0, 0, 0, 8, 5, 3, "MP18冲锋枪", "", ""))
	list.append(_unit("ww1_mauser", "毛瑟步枪班", 0, 0, 15, 3, 3, 10, 95, 30, 0.67, 0.2, 0.1, 0, 0, 0, 0, 0, 0, 0, 0,8,5,3, "毛瑟G98步枪", "", ""))
	list.append(_unit("ww1_enfield", "李恩菲尔德班", 0, 0, 15, 3, 3, 10, 95, 30, 0.83, 0.18, 0.1, 0, 0, 0, 0, 0, 0, 0, 0,8,5,3, "李恩菲尔德步枪", "", ""))
	list.append(_unit("ww1_mg08", "MG08机枪巢", 0, 2, 23, 0, 4, 15, 90, 45, 2.0, 0.1, 0.05, 0, 0, 0, 0, 75, 6.0, 0.6, 0.32,12,8,10, "81mm/105mm火炮", "", "7.62mm/12.7mm高机枪"))
	list.append(_unit("ww1_vickers", "维克斯机枪巢", 0, 2, 23, 0, 4, 15, 85, 40, 1.8, 0.12, 0.06, 0, 0, 0, 0, 66, 6.0, 0.6, 0.32,12,8,10, "81mm/105mm火炮", "", "7.62mm/12.7mm高机枪"))
	list.append(_unit("ww1_m81", "81mm迫击炮组", 0, 2, 23, 1, 99, 12, 70, 120, 2.0, 1.2, 0.6, 60, 2.0, 1.2, 0.6, 0, 0, 0, 0,6,5,3, "81mm/105mm火炮", "迫击炮/野战炮", ""))
	list.append(_unit("ww1_m76", "76mm迫击炮组", 0, 2, 23, 1, 99, 12, 65, 114, 2.0, 1.2, 0.6, 54, 2.0, 1.2, 0.6, 0, 0, 0, 0,6,5,3, "81mm/105mm火炮", "迫击炮/野战炮", ""))
	list.append(_unit("ww1_storm", "暴风突击队", 0, 0, 20, 5, 2, 12, 110, 40, 1.5, 0.15, 0.08, 5, 0.67, 0.25, 0.12, 0, 0, 0, 0,10,6,4, "暴风冲锋枪", "73mm/90mm反坦克炮", ""))
	list.append(_unit("ww1_rolls", "罗尔斯装甲车", 0, 1, 45, 5, 3, 14, 180, 25, 1.0, 0.2, 0.1, 35, 0.83, 0.22, 0.12, 5, 0.67, 0.25, 0.12,18,22,10, "57mm/75mm坦克炮", "57mm/75mm坦克炮", "14.5mm车载机枪"))
	list.append(_unit("ww1_lanchest", "兰彻斯特装甲车", 0, 1, 45, 5, 3, 14, 170, 22, 1.0, 0.2, 0.1, 32, 0.83, 0.22, 0.12, 8, 0.67, 0.25, 0.12,18,22,10, "37mm/57mm坦克炮", "57mm/75mm坦克炮", "14.5mm车载机枪"))
	list.append(_unit("ww1_ft17", "FT-17轻型坦克", 0, 1, 45, 3, 3, 16, 200, 28, 0.83, 0.22, 0.12, 40, 0.67, 0.25, 0.12, 0, 0, 0, 0,20,25,8, "57mm/75mm坦克炮", "75mm/76mm坦克炮", ""))
	list.append(_unit("ww1_saint", "圣沙蒙坦克", 0, 1, 50, 2, 4, 20, 280, 20, 0.67, 0.25, 0.12, 50, 0.5, 0.3, 0.15, 0, 0, 0, 0,25,35,8, "37mm/57mm坦克炮", "85mm主炮", ""))
	list.append(_unit("ww1_a7v", "A7V重型坦克", 0, 1, 50, 2, 4, 20, 300, 18, 0.5, 0.3, 0.15, 48, 0.33, 0.4, 0.2, 0, 0, 0, 0,28,38,8, "37mm/57mm坦克炮", "85mm主炮", ""))
	list.append(_unit("ww1_mark4", "马克IV型坦克", 0, 1, 48, 2, 3, 18, 260, 22, 0.67, 0.25, 0.12, 45, 0.5, 0.3, 0.15, 0, 0, 0, 0,22,30,8, "37mm/57mm坦克炮", "75mm/76mm坦克炮", ""))
	list.append(_unit("ww1_77mm", "77mm野战炮", 0, 2, 23, 0, 99, 14, 60, 135, 1.32, 1.6, 0.8, 90, 1.32, 1.6, 0.8, 0, 0, 0, 0,6,8,4, "81mm/105mm火炮", "迫击炮/野战炮", ""))
	list.append(_unit("ww1_105mm", "105mm榴弹炮", 0, 2, 23, 0, 99, 16, 55, 150, 1.0, 2.0, 1.0, 105, 1.0, 2.0, 1.0, 0, 0, 0, 0,6,8,4, "81mm/105mm火炮", "迫击炮/野战炮", ""))
	list.append(_unit("ww1_37mm", "37mm高射炮", 0, 2, 23, 0, 5, 14, 70, 10, 1.5, 0.15, 0.08, 24, 4.0, 0.8, 0.4, 150, 8.0, 0.4, 0.2,8,8,18, "迫击炮/野战炮", "迫击炮/野战炮", "23mm/30mm高射炮"))
	list.append(_unit("ww1_cavalry", "骑兵斥候", 0, 0, 15, 6, 1, 8, 85, 20, 1.0, 0.2, 0.1, 0, 0, 0, 0, 0, 0, 0, 0,6,4,2, "骑兵卡宾枪/马刀", "", ""))
	list.append(_unit("ww1_flame", "火焰喷射兵", 0, 0, 18, 3, 1, 12, 100, 45, 1.0, 0.2, 0.1, 15, 0.5, 0.3, 0.15, 0, 0, 0, 0,8,5,3, "暴风冲锋枪", "73mm/90mm反坦克炮", ""))
	list.append(_unit("ww1_engineer", "工兵班", 0, 2, 20, 3, 2, 12, 90, 30, 1.0, 0.2, 0.1, 75, 2.0, 1.2, 0.6, 0, 0, 0, 0,10,8,5, "迫击炮/野战炮", "迫击炮/野战炮", ""))

	# ==================== 二战单位(20个)====================
	list.append(_unit("ww2_thompson", "汤普森班", 1, 0, 60, 4, 2, 10, 140, 55, 1.5, 0.15, 0.08, 0, 0, 0, 0, 0, 0, 0, 0,15,10,6, "冲锋枪/步枪", "", ""))
	list.append(_unit("ww2_garand", "加兰德班", 1, 0, 60, 3, 3, 10, 135, 50, 0.83, 0.18, 0.1, 0, 0, 0, 0, 0, 0, 0, 0,15,10,6, "冲锋枪/步枪", "", ""))
	list.append(_unit("ww2_mp40", "MP40班", 1, 0, 60, 4, 2, 10, 130, 52, 1.5, 0.15, 0.08, 0, 0, 0, 0, 0, 0, 0, 0,15,10,6, "冲锋枪/步枪", "", ""))
	list.append(_unit("ww2_ppsh", "波波沙班", 1, 0, 60, 4, 2, 10, 135, 54, 1.8, 0.12, 0.07, 0, 0, 0, 0, 0, 0, 0, 0,15,10,6, "冲锋枪/步枪", "", ""))
	list.append(_unit("ww2_mg42", "MG42机枪组", 1, 2, 90, 0, 4, 15, 120, 70, 2.5, 0.08, 0.05, 0, 0, 0, 0, 135, 8.0, 0.4, 0.2,20,15,18, "105mm/120mm榴弹炮", "", "20mm/25mm高炮"))
	list.append(_unit("ww2_browning", "勃朗宁机枪组", 1, 2, 90, 0, 4, 15, 130, 65, 2.0, 0.1, 0.05, 0, 0, 0, 0, 120, 7.2, 0.48, 0.24,20,15,18, "81mm/105mm火炮", "", "20mm/25mm高炮"))
	list.append(_unit("ww2_panzerschrek", "铁拳反坦克组", 1, 0, 65, 3, 2, 12, 120, 15, 1.0, 0.2, 0.1, 90, 0.33, 0.5, 0.25, 0, 0, 0, 0,12,10,5, "毛瑟G98步枪", "88mm/105mm反坦克炮", ""))
	list.append(_unit("ww2_bazooka", "巴祖卡组", 1, 0, 65, 3, 2, 12, 115, 12, 1.0, 0.2, 0.1, 85, 0.33, 0.5, 0.25, 0, 0, 0, 0,12,10,5, "加兰德M1步枪", "85mm/105mm反坦克炮", ""))
	list.append(_unit("ww2_m81", "81mm迫击炮", 1, 2, 90, 1, 99, 12, 85, 165, 2.0, 1.2, 0.6, 90, 2.0, 1.2, 0.6, 0, 0, 0, 0,12,10,6, "81mm/105mm火炮", "迫击炮/野战炮", ""))
	list.append(_unit("ww2_m120", "120mm重迫击炮", 1, 2, 90, 1, 99, 14, 80, 195, 1.32, 1.6, 0.8, 120, 1.32, 1.6, 0.8, 0, 0, 0, 0,12,10,6, "81mm/105mm火炮", "81mm/105mm火炮", ""))
	list.append(_unit("ww2_pz3", "三号坦克", 1, 1, 180, 3, 3, 16, 350, 40, 0.83, 0.22, 0.12, 80, 0.67, 0.25, 0.12, 0, 0, 0, 0,40,55,15, "75mm/76mm坦克炮", "105mm主炮", ""))
	list.append(_unit("ww2_pz4", "四号坦克", 1, 1, 180, 3, 3, 18, 380, 45, 0.83, 0.22, 0.12, 90, 0.67, 0.25, 0.12, 0, 0, 0, 0,42,60,15, "75mm/76mm坦克炮", "105mm/120mm主炮", ""))
	list.append(_unit("ww2_panther", "黑豹坦克", 1, 1, 180, 3, 4, 18, 420, 45, 0.83, 0.22, 0.12, 110, 0.67, 0.25, 0.12, 0, 0, 0, 0,45,70,15, "75mm/76mm坦克炮", "105mm/120mm主炮", ""))
	list.append(_unit("ww2_tiger", "虎式坦克", 1, 1, 180, 2, 4, 22, 480, 35, 0.67, 0.25, 0.12, 130, 0.5, 0.3, 0.15, 0, 0, 0, 0,55,80,18, "57mm/75mm坦克炮", "122mm主炮", ""))
	list.append(_unit("ww2_kingtiger", "虎王坦克", 1, 1, 180, 1, 4, 25, 550, 30, 0.5, 0.3, 0.15, 150, 0.33, 0.4, 0.2, 0, 0, 0, 0,60,85,18, "57mm/75mm坦克炮", "125mm滑膛炮", ""))
	list.append(_unit("ww2_t34_76", "T-34/76坦克", 1, 1, 180, 4, 3, 16, 360, 45, 0.83, 0.22, 0.12, 85, 0.67, 0.25, 0.12, 0, 0, 0, 0,40,60,15, "75mm/76mm坦克炮", "105mm/120mm主炮", ""))
	list.append(_unit("ww2_t34_85", "T-34/85坦克", 1, 1, 180, 4, 3, 18, 400, 45, 0.83, 0.22, 0.12, 100, 0.67, 0.25, 0.12, 0, 0, 0, 0,42,65,15, "75mm/76mm坦克炮", "105mm/120mm主炮", ""))
	list.append(_unit("ww2_is2", "IS-2重型坦克", 1, 1, 180, 2, 4, 22, 500, 35, 0.5, 0.3, 0.15, 135, 0.33, 0.4, 0.2, 0, 0, 0, 0,55,80,18, "57mm/75mm坦克炮", "122mm主炮", ""))
	list.append(_unit("ww2_sherman", "M4谢尔曼", 1, 1, 180, 4, 3, 16, 340, 45, 0.83, 0.22, 0.12, 80, 0.67, 0.25, 0.12, 0, 0, 0, 0,40,55,15, "75mm/76mm坦克炮", "105mm主炮", ""))
	list.append(_unit("ww2_hellcat", "M18地狱猫", 1, 1, 170, 5, 3, 16, 280, 30, 0.83, 0.22, 0.12, 95, 0.67, 0.25, 0.12, 0, 0, 0, 0,25,40,12, "57mm/75mm坦克炮", "105mm/120mm主炮", ""))

	# ==================== 冷战单位(20个)====================
	list.append(_unit("cold_rpg", "RPG火箭筒组", 2, 0, 170, 3, 2, 14, 180, 18, 0.9, 0.2, 0.1, 120, 0.4, 0.45, 0.2, 0, 0, 0, 0,15,5,5, "AK-47突击步枪", "RPG-7火箭筒", ""))
	list.append(_unit("cold_ak47", "AK-47步兵班", 2, 0, 160, 4, 2, 10, 200, 90, 1.5, 0.15, 0.08, 0, 0, 0, 0, 0, 0, 0, 0,30,20,12, "AK-47突击步枪", "", ""))
	list.append(_unit("cold_m14", "M14步兵班", 2, 0, 160, 4, 3, 10, 195, 85, 0.83, 0.18, 0.1, 0, 0, 0, 0, 0, 0, 0, 0,30,20,12, "M14步枪", "", ""))
	list.append(_unit("cold_m60", "M60机枪班", 2, 0, 170, 3, 4, 12, 210, 110, 2.0, 0.1, 0.05, 0, 0, 0, 0, 60, 1.5, 0.15, 0.08,32,22,15, "M14步枪", "", "12.7mm重机枪"))
	list.append(_unit("cold_rpk", "RPK机枪班", 2, 0, 170, 3, 3, 12, 205, 105, 1.8, 0.12, 0.06, 0, 0, 0, 0, 55, 1.5, 0.15, 0.08,32,22,15, "AK-74突击步枪", "", "12.7mm重机枪"))
	list.append(_unit("cold_btr60", "BTR-60装甲车", 2, 1, 480, 4, 3, 14, 550, 60, 1.0, 0.2, 0.1, 70, 0.83, 0.22, 0.12, 40, 1.0, 0.2, 0.1,50,60,35, "100mm主炮", "100mm主炮", "14.5mm车载机枪"))
	list.append(_unit("cold_m113", "M113装甲车", 2, 2, 240, 4, 2, 12, 300, 40, 0.83, 0.22, 0.12, 90, 2.68, 1.0, 0.48, 20, 0.83, 0.22, 0.12,35,45,25, "81mm/105mm火炮", "迫击炮/野战炮", "7.62mm/12.7mm高机枪"))
	list.append(_unit("cold_bmp1", "BMP-1步战车", 2, 1, 480, 4, 99, 16, 600, 70, 0.83, 0.22, 0.12, 120, 0.5, 0.3, 0.15, 30, 0.83, 0.22, 0.12,55,70,30, "100mm主炮", "122mm主炮", "14.5mm车载机枪"))
	list.append(_unit("cold_bradley", "M2布雷德利", 2, 1, 480, 4, 99, 18, 650, 75, 0.83, 0.22, 0.12, 130, 0.5, 0.3, 0.15, 35, 0.83, 0.22, 0.12,55,75,30, "105mm主炮", "122mm主炮", "14.5mm车载机枪"))
	list.append(_unit("cold_t55", "T-55坦克", 2, 1, 480, 3, 3, 16, 700, 60, 0.67, 0.25, 0.12, 140, 0.5, 0.3, 0.15, 0, 0, 0, 0,60,85,25, "100mm主炮", "125mm滑膛炮", ""))
	list.append(_unit("cold_t62", "T-62坦克", 2, 1, 480, 3, 4, 18, 750, 60, 0.67, 0.25, 0.12, 155, 0.5, 0.3, 0.15, 0, 0, 0, 0,60,90,25, "100mm主炮", "125mm滑膛炮", ""))
	list.append(_unit("cold_t72", "T-72坦克", 2, 1, 480, 3, 4, 20, 800, 55, 0.67, 0.25, 0.12, 180, 0.5, 0.3, 0.15, 0, 0, 0, 0,65,100,30, "85mm主炮", "125mm滑膛炮", ""))
	list.append(_unit("cold_m60t", "M60坦克", 2, 1, 480, 3, 3, 18, 720, 55, 0.67, 0.25, 0.12, 160, 0.5, 0.3, 0.15, 0, 0, 0, 0,60,95,30, "85mm主炮", "125mm滑膛炮", ""))
	list.append(_unit("cold_m1", "M1主战坦克", 2, 1, 480, 3, 4, 20, 850, 55, 0.67, 0.25, 0.12, 175, 0.5, 0.3, 0.15, 0, 0, 0, 0,65,100,30, "85mm主炮", "125mm滑膛炮", ""))
	list.append(_unit("cold_leo1", "豹1坦克", 2, 1, 480, 4, 3, 16, 650, 55, 0.83, 0.22, 0.12, 150, 0.67, 0.25, 0.12, 0, 0, 0, 0,50,80,25, "85mm主炮", "125mm滑膛炮", ""))
	list.append(_unit("cold_chieftain", "酋长坦克", 2, 1, 480, 2, 4, 20, 820, 50, 0.5, 0.3, 0.15, 165, 0.33, 0.4, 0.2, 0, 0, 0, 0,65,100,25, "85mm主炮", "125mm滑膛炮", ""))
	list.append(_unit("cold_zsu23", "ZSU-23-4自行高炮", 2, 2, 240, 3, 5, 16, 350, 30, 2.5, 0.08, 0.05, 60, 8.0, 0.4, 0.2, 450, 10.0, 0.32, 0.2,25,30,50, "迫击炮/野战炮", "迫击炮/野战炮", "23mm/30mm高射炮"))
	list.append(_unit("cold_sam7", "萨姆-7防空组", 2, 0, 165, 3, 99, 14, 150, 5, 0.5, 0.3, 0.15, 5, 0.5, 0.3, 0.15, 120, 0.33, 0.5, 0.25,15,12,20, "AK-47突击步枪", "RPG-7火箭筒", "萨姆-7防空导弹"))
	list.append(_unit("cold_mig21", "米格-21战机", 2, 3, 400, 6, 99, 18, 250, 60, 1.0, 0.2, 0.1, 50, 1.0, 0.2, 0.1, 160, 1.0, 0.2, 0.1,15,20,40, "空空导弹/20mm机炮", "空空导弹/20mm机炮", "地狱火导弹/127mm舰炮"))
	list.append(_unit("cold_f4", "F-4鬼怪战机", 2, 3, 400, 6, 99, 20, 280, 80, 1.0, 0.2, 0.1, 70, 1.0, 0.2, 0.1, 180, 1.0, 0.2, 0.1,15,20,40, "空空导弹/20mm机炮", "空空导弹/20mm机炮", "地狱火导弹/127mm舰炮"))
	list.append(_unit("cold_spetsnaz", "阿尔法特种部队", 2, 0, 180, 5, 2, 14, 220, 100, 1.5, 0.15, 0.08, 30, 0.67, 0.25, 0.12, 15, 1.0, 0.2, 0.1,35,25,15, "M16A4步枪", "85mm/105mm主炮", "便携式防空导弹"))

	# ==================== 现代单位(20个)====================
	list.append(_unit("mod_marine", "海军陆战队", 3, 0, 320, 4, 2, 10, 300, 140, 1.5, 0.15, 0.08, 0, 0, 0, 0, 0, 0, 0, 0,50,35,20, "M4卡宾枪/SCAR-H", "", ""))
	list.append(_unit("mod_ranger", "游骑兵", 3, 0, 340, 5, 2, 12, 320, 160, 1.5, 0.15, 0.08, 20, 0.83, 0.22, 0.12, 10, 1.0, 0.2, 0.1,55,38,22, "M4卡宾枪/SCAR-H", "火箭筒/轻型装甲武器", "便携式防空导弹"))
	list.append(_unit("mod_javelin", "标枪导弹兵", 3, 0, 330, 3, 99, 14, 220, 25, 0.33, 0.5, 0.25, 250, 0.25, 0.6, 0.3, 20, 0.33, 0.5, 0.25,30,25,15, "M4卡宾枪", "标枪反坦克导弹", "便携式防空导弹"))
	list.append(_unit("mod_stinger", "毒刺导弹兵", 3, 0, 320, 3, 99, 14, 200, 10, 0.5, 0.3, 0.15, 10, 0.5, 0.3, 0.15, 220, 0.33, 0.5, 0.25,25,20,25, "M4卡宾枪", "M4卡宾枪", "毒刺防空导弹"))
	list.append(_unit("mod_technical", "武装皮卡", 3, 0, 280, 5, 3, 8, 250, 80, 1.0, 0.2, 0.1, 40, 0.67, 0.25, 0.12, 15, 1.0, 0.2, 0.1,25,20,12, "AK-47突击步枪", "RPG-7火箭筒", "便携式防空导弹"))
	list.append(_unit("mod_stryker_mgs", "斯特赖克MGS", 3, 1, 900, 4, 4, 16, 900, 80, 0.67, 0.25, 0.12, 220, 0.5, 0.3, 0.15, 0, 0, 0, 0,70,90,30, "105mm主炮", "120mm/125mm主炮", ""))
	list.append(_unit("mod_stryker_m2", "斯特赖克M2", 3, 1, 880, 4, 3, 14, 850, 100, 1.0, 0.2, 0.1, 120, 0.83, 0.22, 0.12, 60, 1.5, 0.15, 0.08,65,80,40, "105mm/120mm主炮", "122mm主炮", "20mm机炮"))
	list.append(_unit("mod_hummer_tow", "悍马·陶式", 3, 0, 330, 5, 99, 14, 240, 20, 0.33, 0.5, 0.25, 260, 0.25, 0.6, 0.3, 10, 0.33, 0.5, 0.25,30,25,15, "M4卡宾枪", "陶式反坦克导弹", "便携式防空导弹"))
	list.append(_unit("mod_hummer_m2", "悍马·M2", 3, 0, 300, 5, 3, 10, 260, 90, 1.0, 0.2, 0.1, 20, 0.67, 0.25, 0.12, 40, 1.5, 0.15, 0.08,30,25,20, "M4卡宾枪", "M4卡宾枪", "12.7mm重机枪"))
	list.append(_unit("mod_m1a1", "M1A1坦克", 3, 1, 950, 3, 4, 20, 1100, 70, 0.67, 0.25, 0.12, 280, 0.5, 0.3, 0.15, 0, 0, 0, 0,90,140,35, "100mm主炮", "120mm主炮", ""))
	list.append(_unit("mod_m1a2", "M1A2艾布拉姆斯", 3, 1, 960, 3, 4, 22, 1200, 70, 0.67, 0.25, 0.12, 300, 0.5, 0.3, 0.15, 0, 0, 0, 0,95,150,35, "100mm主炮", "120mm L55主炮", ""))
	list.append(_unit("mod_m1a2sep", "M1A2 SEP", 3, 1, 960, 3, 4, 24, 1250, 75, 0.67, 0.25, 0.12, 320, 0.5, 0.3, 0.15, 0, 0, 0, 0,100,160,35, "105mm主炮", "双联装电磁炮", ""))
	list.append(_unit("mod_t90", "T-90坦克", 3, 1, 950, 3, 4, 20, 1150, 80, 0.67, 0.25, 0.12, 280, 0.5, 0.3, 0.15, 0, 0, 0, 0,85,135,35, "105mm主炮", "120mm主炮", ""))
	list.append(_unit("mod_leo2a6", "豹2A6坦克", 3, 1, 960, 3, 4, 22, 1180, 70, 0.67, 0.25, 0.12, 310, 0.5, 0.3, 0.15, 0, 0, 0, 0,90,145,35, "100mm主炮", "120mm L55主炮", ""))
	list.append(_unit("mod_challenger2", "挑战者2坦克", 3, 1, 950, 2, 4, 22, 1300, 65, 0.5, 0.3, 0.15, 290, 0.33, 0.4, 0.2, 0, 0, 0, 0,100,160,35, "100mm主炮", "120mm主炮", ""))
	list.append(_unit("mod_ah64", "AH-64阿帕奇", 3, 3, 800, 5, 99, 20, 350, 160, 0.67, 0.25, 0.12, 280, 0.67, 0.25, 0.12, 100, 0.67, 0.25, 0.12,25,35,30, "地狱火导弹/127mm舰炮", "地狱火导弹/127mm舰炮", "空空导弹/20mm机炮"))
	list.append(_unit("mod_ah1", "AH-1眼镜蛇", 3, 3, 780, 5, 99, 18, 320, 140, 0.67, 0.25, 0.12, 250, 0.67, 0.25, 0.12, 80, 0.67, 0.25, 0.12,25,35,30, "地狱火导弹/127mm舰炮", "地狱火导弹/127mm舰炮", "空空导弹/20mm机炮"))
	list.append(_unit("mod_uh60", "UH-60黑鹰", 3, 3, 700, 5, 99, 12, 300, 40, 0.5, 0.3, 0.15, 20, 0.5, 0.3, 0.15, 30, 0.5, 0.3, 0.15,20,25,20, "7.62mm舱门机枪/轻型机炮", "7.62mm舱门机枪/轻型机炮", "7.62mm舱门机枪/轻型机炮"))
	list.append(_unit("mod_m270", "M270火箭炮", 3, 2, 480, 1, 99, 20, 250, 540, 0.8, 2.4, 1.2, 360, 0.8, 2.4, 1.2, 0, 0, 0, 0,20,25,15, "227mm火箭炮", "105mm/120mm榴弹炮", ""))
	list.append(_unit("mod_m6", "自行高炮M6", 3, 2, 480, 3, 5, 18, 300, 40, 2.0, 0.1, 0.05, 90, 6.0, 0.6, 0.32, 840, 8.0, 0.4, 0.2,30,35,60, "81mm/105mm火炮", "迫击炮/野战炮", "25mm近防炮"))

	# ==================== 近未来单位(20个)====================
	list.append(_unit("fut_swarm", "蜂群无人机", 4, 3, 1200, 6, 99, 8, 200, 100, 2.0, 0.1, 0.05, 60, 2.0, 0.1, 0.05, 80, 2.0, 0.1, 0.05,15,15,25, "空空导弹/20mm机炮", "空空导弹/20mm机炮", "空空导弹/20mm机炮"))
	list.append(_unit("fut_scout_drone", "侦察无人机", 4, 3, 1100, 7, 99, 6, 150, 40, 0.5, 0.3, 0.15, 20, 0.5, 0.3, 0.15, 30, 0.5, 0.3, 0.15,12,12,20, "7.62mm舱门机枪/轻型机炮", "7.62mm舱门机枪/轻型机炮", "7.62mm舱门机枪/轻型机炮"))
	list.append(_unit("fut_attack_drone", "攻击无人机", 4, 3, 1300, 6, 99, 10, 280, 150, 1.0, 0.2, 0.1, 280, 1.0, 0.2, 0.1, 100, 1.0, 0.2, 0.1,20,25,30, "地狱火导弹/127mm舰炮", "地狱火导弹/127mm舰炮", "空空导弹/20mm机炮"))
	list.append(_unit("fut_cyborg", "机械步兵", 4, 0, 500, 4, 3, 12, 400, 200, 1.5, 0.15, 0.08, 0, 0, 0, 0, 0, 0, 0, 0,80,60,40, "植入式自动步枪/重型粒子炮", "", ""))
	list.append(_unit("fut_heavy_trooper", "重装机兵", 4, 0, 520, 3, 3, 15, 450, 220, 1.0, 0.2, 0.1, 30, 0.5, 0.3, 0.15, 15, 0.67, 0.25, 0.12,100,80,50, "植入式自动步枪/重型粒子炮", "电磁炮", "便携式防空导弹"))
	list.append(_unit("fut_scout_mech", "侦察机甲", 4, 0, 500, 5, 3, 12, 380, 150, 1.5, 0.15, 0.08, 80, 0.83, 0.22, 0.12, 40, 1.0, 0.2, 0.1,60,50,35, "粒子束步枪", "电磁炮", "点防御激光"))
	list.append(_unit("fut_assault_mech", "突击机甲", 4, 1, 1500, 4, 4, 18, 1400, 120, 0.83, 0.22, 0.12, 380, 0.67, 0.25, 0.12, 50, 0.83, 0.22, 0.12,100,160,60, "122mm主炮", "双联装电磁炮", "20mm机炮"))
	list.append(_unit("fut_heavy_mech", "重装机甲", 4, 1, 1580, 2, 4, 25, 1800, 80, 0.5, 0.3, 0.15, 500, 0.33, 0.4, 0.2, 60, 0.5, 0.3, 0.15,140,220,70, "105mm主炮", "重型等离子加农炮", "20mm机炮"))
	list.append(_unit("fut_hovertank", "悬浮坦克", 4, 1, 1500, 5, 4, 22, 1300, 100, 0.83, 0.22, 0.12, 420, 0.67, 0.25, 0.12, 50, 0.83, 0.22, 0.12,80,140,60, "105mm/120mm主炮", "重型等离子加农炮", "20mm机炮"))
	list.append(_unit("fut_howitzer", "悬浮自行火炮", 4, 2, 795, 4, 99, 20, 300, 840, 1.0, 2.0, 1.0, 600, 1.0, 2.0, 1.0, 0, 0, 0, 0,40,50,30, "电磁轨道炮", "电磁轨道炮", ""))
	list.append(_unit("fut_prism", "光棱坦克", 4, 1, 1550, 3, 5, 20, 1100, 180, 0.67, 0.25, 0.12, 350, 0.67, 0.25, 0.12, 100, 0.67, 0.25, 0.12,80,140,80, "125mm滑膛炮", "双联装电磁炮", "25mm M242大毒蛇"))
	list.append(_unit("fut_aa_hover", "防空悬浮车", 4, 2, 780, 5, 5, 16, 350, 30, 2.5, 0.08, 0.05, 60, 8.0, 0.4, 0.2, 1200, 10.0, 0.32, 0.2,30,40,100, "迫击炮/野战炮", "迫击炮/野战炮", "点防御激光"))
	list.append(_unit("fut_stealth_bomber", "隐形轰炸机", 4, 3, 1400, 6, 99, 24, 400, 300, 0.2, 0.6, 0.3, 350, 0.2, 0.6, 0.3, 30, 0.2, 0.6, 0.3,25,35,40, "轨道炮/激光", "轨道炮/激光", "7.62mm舱门机枪/轻型机炮"))
	list.append(_unit("fut_space_fighter", "空天战斗机", 4, 3, 1325, 7, 99, 22, 450, 120, 1.0, 0.2, 0.1, 100, 1.0, 0.2, 0.1, 350, 1.0, 0.2, 0.1,30,40,80, "地狱火导弹/127mm舰炮", "空空导弹/20mm机炮", "轨道炮/激光"))
	list.append(_unit("fut_spectre", "幽灵特工", 4, 0, 530, 5, 3, 16, 350, 220, 1.5, 0.15, 0.08, 80, 0.83, 0.22, 0.12, 50, 1.0, 0.2, 0.1,60,50,40, "植入式自动步枪/重型粒子炮", "85mm/105mm主炮", "12.7mm重机枪"))
	list.append(_unit("fut_nano_drone", "纳米修复机", 4, 3, 1000, 5, 99, 10, 180, 0, 0.5, 0.3, 0.15, 0, 0.5, 0.3, 0.15, 0, 0.5, 0.3, 0.15,20,30,30, "", "", ""))
	list.append(_unit("fut_shield", "力场发生器", 4, 2, 750, 0, 0, 15, 500, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,100,150,120, "", "", ""))
	list.append(_unit("fut_colossus", "巨神机甲", 4, 1, 1590, 1, 5, 30, 2000, 100, 0.33, 0.4, 0.2, 550, 0.25, 0.6, 0.3, 80, 0.33, 0.4, 0.2,150,250,80, "105mm/120mm主炮", "攻城电磁炮", "25mm M242大毒蛇"))
	list.append(_unit("fut_stormcore", "风暴核心原型", 4, 2, 800, 0, 99, 0, 600, 600, 0.8, 2.4, 1.2, 600, 0.8, 2.4, 1.2, 600, 0.8, 2.4, 1.2,80,100,100, "电磁轨道炮", "电磁轨道炮", "25mm近防炮"))
	list.append(_unit("fut_nexus", "虚空领主", 4, 1, 1590, 2, 99, 35, 2200, 150, 0.5, 0.3, 0.15, 480, 0.33, 0.4, 0.2, 120, 0.5, 0.3, 0.15,120,200,100, "125mm滑膛炮", "重型等离子加农炮", "40mm榴弹"))

	# omega_platform(全装型机动舱)— 与 fut_colossus 数据相同
	# 保留用于存档兼容:早期版本以此ID创建的蓝图不会失效
	list.append(_unit("omega_platform", "全装型机动舱", 4, 1, 1590, 1, 5, 30, 2000, 100, 0.33, 0.4, 0.2, 550, 0.25, 0.6, 0.3, 80, 0.33, 0.4, 0.2,150,250,80, "105mm/120mm主炮", "攻城电磁炮", "25mm M242大毒蛇"))

	# ==================== 堡垒单位(10个)====================
	list.append(_unit("fort_ww1_pillbox", "混凝土机枪碉堡", 0, 4, 80, 0, 5, 20, 600, 60, 2.0, 0.1, 0.05, 0, 0, 0, 0, 40, 1.5, 0.15, 0.08,50,60,40, "150mm要塞炮/88mm防空炮", "", "MG42/双联防空炮"))
	list.append(_unit("fort_ww1_artillery", "要塞炮台", 0, 4, 100, 0, 99, 25, 500, 80, 0.33, 0.4, 0.2, 60, 0.33, 0.4, 0.2, 0, 0, 0, 0,40,50,30, "150mm要塞炮/88mm防空炮", "150mm要塞炮/88mm防空炮", ""))
	list.append(_unit("fort_ww2_bunker", "混凝土碉堡", 1, 4, 200, 0, 5, 25, 1000, 80, 2.0, 0.1, 0.05, 0, 0, 0, 0, 60, 1.5, 0.15, 0.08,80,100,60, "150mm要塞炮/88mm防空炮", "", "150mm要塞炮/88mm防空炮"))
	list.append(_unit("fort_ww2_flak", "88mm防空塔", 1, 4, 220, 0, 6, 28, 800, 40, 1.5, 0.15, 0.08, 30, 1.0, 0.2, 0.1, 200, 2.0, 0.1, 0.05,60,80,100, "MG42/双联防空炮", "MG42/双联防空炮", "离子炮"))
	list.append(_unit("fort_cold_missile", "导弹发射井", 2, 4, 500, 0, 99, 35, 1200, 120, 0.2, 0.6, 0.3, 200, 0.2, 0.6, 0.3, 100, 0.2, 0.6, 0.3,80,100,80, "多管近防炮/88mm防空炮", "离子炮", "多管近防炮/88mm防空炮"))
	list.append(_unit("fort_cold_radar", "雷达站", 2, 4, 300, 0, 99, 20, 800, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,60,80,60, "", "", ""))
	list.append(_unit("fort_modern_citadel", "要塞核心", 3, 4, 800, 0, 6, 40, 2000, 120, 1.0, 0.2, 0.1, 150, 0.67, 0.25, 0.12, 80, 1.0, 0.2, 0.1,120,180,100, "多管近防炮/88mm防空炮", "多管近防炮/88mm防空炮", "150mm要塞炮/88mm防空炮"))
	list.append(_unit("fort_modern_phalanx", "近防炮系统", 3, 4, 600, 0, 5, 30, 1000, 50, 3.0, 0.05, 0.03, 30, 2.0, 0.1, 0.05, 300, 3.0, 0.05, 0.03,80,100,120, "150mm要塞炮/88mm防空炮", "MG42/双联防空炮", "离子炮阵列"))
	list.append(_unit("fort_future_ion", "离子炮台", 4, 4, 1200, 0, 7, 45, 2500, 200, 0.67, 0.25, 0.12, 300, 0.5, 0.3, 0.15, 150, 0.67, 0.25, 0.12,150,200,150, "离子炮", "离子炮阵列", "多管近防炮/88mm防空炮"))
	list.append(_unit("fort_future_shield", "能量护盾发生器", 4, 4, 1000, 0, 0, 30, 3000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,200,250,200, "", "", ""))

	# ==================== 能量卡(战前能量 1～7 级)====================
	list.append(_energy_start("energy_start_1", "战前能量 I", 5, 100.0, "common"))
	list.append(_energy_start("energy_start_2", "战前能量 II", 10, 150.0, "common"))
	list.append(_energy_start("energy_start_3", "战前能量 III", 15, 200.0, "common"))
	list.append(_energy_start("energy_start_4", "战前能量 IV", 20, 250.0, "uncommon"))
	list.append(_energy_start("energy_start_5", "战前能量 V", 25, 300.0, "uncommon"))
	list.append(_energy_start("energy_start_6", "战前能量 VI", 30, 350.0, "rare"))
	list.append(_energy_start("energy_start_7", "战前能量 VII", 35, 400.0, "rare"))

	# ─── 势力专属卡(14张)───
	var EC = preload("res://data/faction_exclusive_cards.gd")
	for cfg in EC.EXCLUSIVE_CARDS:
		list.append(EC.create_card(cfg))

	return list

## 返回所有蓝图 ID(战斗卡 + 能量卡 + 敌人蓝图)
static func get_all_blueprint_ids() -> Array:
	var ids: Array = []
	_ensure_card_cache()
	for c in _all_cards_cache:
		if c is CardResource:
			var card := c as CardResource
			if card.card_type == GC.CardType.COMBAT_UNIT or card.card_type == GC.CardType.ENERGY:
				ids.append(card.card_id)
	# 添加敌人掉落的高级蓝图ID
	for id in EnemyBlueprints.get_all_enemy_blueprint_ids():
		if id is String and not ids.has(id):
			ids.append(id)
	return ids

## 根据 PhaseLaws 定义生成法则卡模板(印制/发奖时用 clone())
static func create_law_card_resource(law_id: String) -> CardResource:
	var law: Dictionary = PhaseLaws.get_by_id(law_id)
	if law.is_empty():
		return null
	var kind: String = String(law.get("kind", ""))
	var c := CardResource.new()
	c.card_id = law_id
	c.linked_law_id = law_id
	var lname: String = String(law.get("name", ""))
	c.display_name = lname if not lname.is_empty() else law_id
	c.card_type = GC.CardType.LAW
	c.rarity = "rare" if kind == "passive" else "epic"
	var bc: Dictionary = law.get("battle_cost", {})
	var ac: Dictionary = law.get("activate_cost", {})
	if kind == "active":
		c.energy_cost = float(bc.get("energy", 0.0))
		c.type_line = "法则 — 主动"
		var nano_b: int = int(bc.get("nano", 0))
		if nano_b > 0:
			c.summary_line = "战中 %d⚡｜纳米 %d" % [int(c.energy_cost), nano_b]
		else:
			c.summary_line = "战中能耗 %d⚡" % int(c.energy_cost)
	else:
		c.energy_cost = float(ac.get("nano", 0))
		c.type_line = "法则 — 被动"
		c.summary_line = "激活纳米 %d" % int(ac.get("nano", 0))
	c.description = "自蓝图印制；装配至相位仪红/蓝槽后,在战前环境满足时可激活。"
	c.flavor_text = "\"法则需要载体。\""
	return c

## 根据 card_id 获取卡牌(兼容层)
static func get_card_by_id(card_id: String) -> CardResource:
	_ensure_card_cache()
	if _id_lookup_cache.has(card_id):
		return _id_lookup_cache[card_id] as CardResource
	return null

## 创建战斗单位辅助函数(v5.0:24参数,v6.0:含武器名参数)

## 推断武器类型
static func _infer_weapon_type(combat_kind: int, range: int, atk_light: int, atk_armor: int, atk_air: int) -> int:
	# 纯辅助/无攻击力单位 → 标记为 SUPPORT
	if atk_light == 0 and atk_armor == 0 and atk_air == 0:
		return GC.WeaponType.SUPPORT
	# 空中单位 → AERIAL
	if combat_kind == 3:  # AIR
		return GC.WeaponType.AERIAL
	# 支援单位（火炮/迫击炮等）→ INDIRECT（优先判定）
	if combat_kind == 2:  # SUPPORT
		return GC.WeaponType.INDIRECT
	# 曲射单位(range>=99)→ INDIRECT
	if range >= 99:
		return GC.WeaponType.INDIRECT
	# 默认直射(包括堡垒类 range<99)
	return GC.WeaponType.DIRECT

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
	var kind_names = ["轻装", "装甲", "支援", "空中", "堡垒"]
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

	# 显示主要攻击类型(使用主目标攻击速度)
	var main_atk = 0
	var main_type = ""
	var main_speed = c.attack_speed
	if c.attack_light >= c.attack_armor and c.attack_light >= c.attack_air:
		main_atk = c.attack_light
		main_type = "直射"
		main_speed = c.attack_light_speed
	elif c.attack_armor >= c.attack_light and c.attack_armor >= c.attack_air:
		main_atk = c.attack_armor
		main_type = "曲射"
		main_speed = c.attack_armor_speed
	else:
		main_atk = c.attack_air
		main_type = "空射"
		main_speed = c.attack_air_speed

	if main_atk > 0:
		parts.append("%s %d(%.1f)" % [main_type, main_atk, main_speed])

	return "｜".join(parts)

## 平台类型显示名(兼容旧 platform_type 引用)
static func get_platform_display_name(platform_type: int) -> String:
	return RealWorldUnitLabels.platform_chassis_long(platform_type)

## 武器类型显示名（v6.5：当前 WeaponType 为4值攻击方式枚举，返回战斗方式描述；
## 具体武器型号应由 card.weapon_names[] 提供）
static func get_weapon_display_name(weapon_type: int) -> String:
	return RealWorldUnitLabels.weapon_mode_name(weapon_type)

## 统一安全获取卡牌中文名:依次尝试 DefaultCards → EnemyPhaseEquipment → EnemyArchetypes → 返回 ID 本身
## 所有 UI 层的 ID 回退都应使用此函数,杜绝显示原始 card_id
static func get_safe_display_name(card_id: String) -> String:
	if card_id.is_empty():
		push_warning("[DefaultCards] get_safe_display_name: card_id 为空")
		return ""
	_ensure_card_cache()
	var c: CardResource = _id_lookup_cache.get(card_id) as CardResource
	if c != null and not c.display_name.is_empty() and not _looks_like_id(c.display_name):
		return c.display_name
	# 尝试敌方相位装备(platform 或 weapon)- 延迟加载避免循环依赖
	var eq_epe: GDScript = load("res://data/enemy_phase_equipment.gd")
	if eq_epe:
		var eq_data: Dictionary = eq_epe.get_war_platform(card_id)
		if not eq_data.is_empty():
			var eq_name: String = String(eq_data.get("name", ""))
			if not eq_name.is_empty():
				return eq_name
		eq_data = eq_epe.get_war_weapon(card_id)
		if not eq_data.is_empty():
			var eq_name: String = String(eq_data.get("name", ""))
			if not eq_name.is_empty():
				return eq_name
	# 尝试敌方原型表(enemy_* 格式)
	var arch_cfg: Dictionary = EnemyArchetypes.get_config(card_id)
	var arch_name: String = String(arch_cfg.get("display_name", "")) if not arch_cfg.is_empty() else ""
	if not arch_name.is_empty() and not _looks_like_id(arch_name):
		return arch_name
	# 尝试敌人掉落蓝图(bp_* 格式)
	var bp_card: CardResource = EnemyBlueprints.get_card_by_id(card_id)
	if bp_card != null and not bp_card.display_name.is_empty() and not _looks_like_id(bp_card.display_name):
		return bp_card.display_name
	# 所有回退都失败,记录警告并返回ID
	push_error("[DefaultCards] 无法找到卡牌名称: %s,将显示原始ID" % card_id)
	return card_id

## 从 CardResource 对象安全获取显示名称；display_name 为空或像 ID 时回退到 get_safe_display_name
static func safe_name(card: CardResource) -> String:
	if card == null:
		push_warning("[DefaultCards] safe_name: card 为 null")
		return ""
	if not card.display_name.is_empty() and not _looks_like_id(card.display_name):
		return card.display_name
	var fallback: String = get_safe_display_name(card.card_id)
	if fallback.is_empty():
		push_error("[DefaultCards] safe_name: 无法获取卡牌 %s 的名称" % card.card_id)
		return card.card_id  # 最后回退到ID,避免完全空白
	return fallback

## 判断一个字符串是否看起来像内部 ID 而非人类可读名称
static func _looks_like_id(s: String) -> bool:
	if s.is_empty():
		return false
	# 以常见 ID 前缀开头,或全是英文小写+下划线+数字且无中文
	if s.begins_with("bp_") or s.begins_with("enemy_") or s.begins_with("captured_") or s.begins_with("ww") or s.begins_with("cold_") or s.begins_with("modern_") or s.begins_with("future_"):
		return true
	# 纯 ASCII 小写+下划线+数字(无中文、无空格)= 大概率是 ID
	if s.to_utf8_buffer().size() == s.length() and s.find(" ") < 0:
		# 全 ASCII 且无空格:检查是否像 snake_case ID
		var has_underscore: bool = s.find("_") >= 0
		var has_digit: bool = false
		for ch in s:
			if ch >= '0' and ch <= '9':
				has_digit = true
				break
		if has_underscore and has_digit:
			return true
	return false

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
	c.description = "作为准备卡装入相位仪时,战斗开始时你的初始能量 +%d 点,可叠加多张。" % int(bonus)
	c.flavor_text = "把能量灌满电枢再出击。"
	return c
