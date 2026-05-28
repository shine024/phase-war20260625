extends RefCounted
class_name EnemyBlueprints
## 敌人掉落的新蓝图：仅通过击败对应敌人解锁。
## 当前总量 143（平台54 + 武器89；含特殊蓝图13 + 生成蓝图130）

const GC = preload("res://resources/game_constants.gd")

const ERA_PREFIX: Array[String] = ["ww1", "ww2", "cold", "modern", "near"]
const ERA_LABEL: Array[String] = ["一战", "二战", "冷战", "现代", "近未来"]
const GENERATED_PLATFORM_COUNTS: Array[int] = [10, 10, 9, 9, 10]
const NAME_PREFIX_PLATFORM: Array[String] = ["铁壁", "霜脊", "风痕", "玄甲", "苍穹", "赤曜", "夜巡", "雷铸"]
const NAME_SUFFIX_PLATFORM: Array[String] = ["战车", "机动架", "突击底盘", "防卫舱", "侦察座", "载具框架"]

## 精确的蓝图ID到名称映射表（去除时代前缀，使用具体型号）
const BLUEPRINT_NAME_MAP: Dictionary = {
	# 一战时期 - 平台
	"bp_ww1_001": "铁壁 Mk.I 机动装甲",
	"bp_ww1_002": "霜脊式固定碉堡",
	"bp_ww1_003": "风痕型侦察车体",
	"bp_ww1_004": "A7V 玄甲突击装甲",
	"bp_ww1_005": "苍穹型防空塔",
	"bp_ww1_006": "赤曜式突击底盘",
	"bp_ww1_007": "夜巡者轻型装甲",
	"bp_ww1_008": "雷铸机动堡垒",
	"bp_ww1_009": "铁壁 Mk.II 车体",
	"bp_ww1_010": "霜脊·改机动装甲",

	# 一战时期 - 武器
	"bp_ww1_011": "裂空式重机枪",
	"bp_ww1_012": "震锋步兵炮",
	"bp_ww1_013": "霆火反器材步枪",
	"bp_ww1_014": "霜矛迫击炮",
	"bp_ww1_015": "影刃轻机枪",
	"bp_ww1_016": "炽线加农炮",
	"bp_ww1_017": "寒星信号枪",
	"bp_ww1_018": "鸣雷野战炮",
	"bp_ww1_019": "曙光重机枪",
	"bp_ww1_020": "流焰榴弹炮",
	"bp_ww1_021": "裂空卡宾枪",
	"bp_ww1_022": "震锋速射炮",
	"bp_ww1_023": "霆火中型机枪",
	"bp_ww1_024": "霜矛臼炮",
	"bp_ww1_025": "影刃狙击步枪",
	"bp_ww1_026": "炽线反装甲炮",

	# 二战时期 - 平台
	"bp_ww2_001": "雷铸式突击车",
	"bp_ww2_002": "铁壁突击炮底盘",
	"bp_ww2_003": "霜脊轮式侦察车",
	"bp_ww2_004": "风痕装甲车",
	"bp_ww2_005": "玄甲重型底盘",
	"bp_ww2_006": "苍穹空降侦察车",
	"bp_ww2_007": "赤曜步兵坦克",
	"bp_ww2_008": "夜巡歼击车底盘",
	"bp_ww2_009": "雷铸轻型侦察车",
	"bp_ww2_010": "铁壁步兵战车",

	# 二战时期 - 武器
	"bp_ww2_011": "M5 鸣雷高速穿甲炮",
	"bp_ww2_012": "曙光半自动步枪",
	"bp_ww2_013": "M2 流焰榴弹炮",
	"bp_ww2_014": "裂空冲锋枪",
	"bp_ww2_015": "震锋反坦克炮",
	"bp_ww2_016": "霆火战斗步枪",
	"bp_ww2_017": "霜矛迫击炮",
	"bp_ww2_018": "影刃冲锋枪",
	"bp_ww2_019": "炽线火箭筒",
	"bp_ww2_020": "寒星栓动步枪",
	"bp_ww2_021": "鸣雷步兵炮",
	"bp_ww2_022": "曙光卡宾枪",
	"bp_ww2_023": "流焰无后坐力炮",
	"bp_ww2_024": "裂空精确步枪",
	"bp_ww2_025": "震锋重迫击炮",
	"bp_ww2_026": "霆火自动步枪",

	# 冷战时期 - 平台
	"bp_cold_001": "BTR-夜巡装甲运兵车",
	"bp_cold_002": "雷铸式步兵战车",
	"bp_cold_003": "铁壁式警戒塔",
	"bp_cold_004": "M113 霜脊装甲车",
	"bp_cold_005": "风痕空降战车",
	"bp_cold_006": "玄甲防御工事",
	"bp_cold_007": "苍穹防空导弹车",
	"bp_cold_008": "赤曜主战坦克",
	"bp_cold_009": "夜巡哨戒炮台",

	# 冷战时期 - 武器
	"bp_cold_010": "影刃线导反坦克导弹",
	"bp_cold_011": "炽线激光指示器",
	"bp_cold_012": "寒星自动榴弹发射器",
	"bp_cold_013": "M60 鸣雷通用机枪",
	"bp_cold_014": "曙光反坦克导弹",
	"bp_cold_015": "流焰火箭筒",
	"bp_cold_016": "裂空空对地导弹",
	"bp_cold_017": "震锋重机枪",
	"bp_cold_018": "霆火无后坐力炮",
	"bp_cold_019": "霜矛狙击步枪",
	"bp_cold_020": "影刃迫击炮",
	"bp_cold_021": "炽线轻机枪",
	"bp_cold_022": "寒星肩射防空导弹",
	"bp_cold_023": "鸣雷突击步枪",
	"bp_cold_024": "曙光加农炮",
	"bp_cold_025": "流焰班用机枪",
	"bp_cold_026": "裂空反辐射导弹",

	# 现代时期 - 平台
	"bp_modern_001": "赤曜轮式侦察车",
	"bp_modern_002": "夜巡城市作战车",
	"bp_modern_003": "雷铸模块化底盘",
	"bp_modern_004": "铁壁防地雷反伏击车",
	"bp_modern_005": "霜脊轻型坦克",
	"bp_modern_006": "风痕高机动底盘",
	"bp_modern_007": "玄甲无人侦察车",
	"bp_modern_008": "苍穹防空系统载车",
	"bp_modern_009": "赤曜重型突击底盘",

	# 现代时期 - 武器
	"bp_modern_010": "SCAR-震锋突击步枪",
	"bp_modern_011": "XM25 霆火空爆榴弹发射器",
	"bp_modern_012": "霜矛冲锋枪",
	"bp_modern_013": "M829 影刃尾翼稳定脱壳穿甲弹",
	"bp_modern_014": "炽线精确射手步枪",
	"bp_modern_015": "寒星自动榴弹发射器",
	"bp_modern_016": "鸣雷短管步枪",
	"bp_modern_017": "曙光反器材狙击步枪",
	"bp_modern_018": "流焰模块化突击步枪",
	"bp_modern_019": "裂空多用途榴弹发射器",
	"bp_modern_020": "震锋战斗卡宾枪",
	"bp_modern_021": "霆火反坦克火箭筒",
	"bp_modern_022": "霜矛狙击系统",
	"bp_modern_023": "影刃轻型迫击炮",
	"bp_modern_024": "炽线个人防卫武器",
	"bp_modern_025": "寒星空爆榴弹",
	"bp_modern_026": "鸣雷制式步枪",

	# 近未来时期 - 平台
	"bp_near_001": "苍穹型主动防御系统",
	"bp_near_002": "赤曜无人战斗车体",
	"bp_near_003": "夜巡外骨骼装甲",
	"bp_near_004": "雷铸遥控武器站",
	"bp_near_005": "铁壁重型装甲套件",
	"bp_near_006": "霜脊机动外骨骼",
	"bp_near_007": "风痕无人哨戒系统",
	"bp_near_008": "玄甲模块化装甲车体",
	"bp_near_009": "苍穹无人机控制站",
	"bp_near_010": "赤曜近防武器站",

	# 近未来时期 - 武器
	"bp_near_011": "定向能武器-曙光",
	"bp_near_012": "电热化学炮-流焰",
	"bp_near_013": "金属风暴-裂空",
	"bp_near_014": "电磁轨道炮-震锋",
	"bp_near_015": "高能激光枪-霆火",
	"bp_near_016": "电热化学炮-霜矛",
	"bp_near_017": "微型导弹舱-影刃",
	"bp_near_018": "电磁轨道炮-炽线",
	"bp_near_019": "高能激光枪-寒星",
	"bp_near_020": "声波共振器-鸣雷",
	"bp_near_021": "定向能武器-曙光·改",
	"bp_near_022": "电热化学炮-流焰·改",
	"bp_near_023": "高能激光枪-裂空",
	"bp_near_024": "电磁轨道炮-震锋·改",
	"bp_near_025": "微型导弹舱-霆火",
	"bp_near_026": "电热化学炮-霜矛·改"
}

static func get_all_enemy_blueprint_ids() -> Array:
	var ids: Array = []
	for c in _create_all():
		if c is CardResource:
			ids.append((c as CardResource).card_id)
	return ids

static func get_card_by_id(card_id: String) -> CardResource:
	for c in _create_all():
		if c is CardResource:
			var card := c as CardResource
			if card.card_id == card_id:
				return card
	return null

static func _create_generated_blueprints() -> Array:
	var list: Array = []
	for era in range(5):
		var prefix: String = ERA_PREFIX[era]
		var label: String = ERA_LABEL[era]
		var p_count: int = GENERATED_PLATFORM_COUNTS[era]
		var bp_idx: int = 1
		for i in range(p_count):
			var id_key_p: String = "bp_%s_%03d" % [prefix, bp_idx]
			bp_idx += 1
			var pt: int = (era * 3 + i) % 11
			var cost_p: float = 3.0 + float((i + era) % 5) + era * 0.4
			var name_p: String = _generated_display_name(label, era, i)
			list.append(_p(id_key_p, name_p, cost_p, pt, "common",
				"平台 — %s／战场缴获" % label,
				"移速 %d｜耐久 %d" % [55 + (i % 6) * 6, 90 + (i % 7) * 10],
				"由%s时代敌军装备逆向解析而来的平台蓝图。" % label,
				"“改造后可直接投入战区。”"))
	return list

static func _generated_display_name(label: String, era: int, idx: int) -> String:
	# 构建蓝图 ID
	var prefix: String = ERA_PREFIX[era]
	var bp_idx: int = idx + 1
	var card_id: String = "bp_%s_%03d" % [prefix, bp_idx]

	# 首先尝试从映射表中获取精确名称
	if BLUEPRINT_NAME_MAP.has(card_id):
		return BLUEPRINT_NAME_MAP[card_id]

	# 如果映射表中没有，使用备用生成算法
	var prefix_pool: Array[String] = NAME_PREFIX_PLATFORM
	var suffix_pool: Array[String] = NAME_SUFFIX_PLATFORM
	var p: String = prefix_pool[(era * 7 + idx) % prefix_pool.size()]
	var s: String = suffix_pool[(era * 5 + idx * 2 + 1) % suffix_pool.size()]
	return "%s·%s%s" % [label, p, s]

static func _create_all() -> Array:
	var list: Array = []

	# ==================== 精英/头目掉落的特殊蓝图 ====================

	# 一战掉落
	# [已废弃] 武器系统已移除，保留代码供存档兼容
	#	"武器 — MP18冲锋枪／近距强化",
	#	"伤害 10｜射程 短｜攻速 极快",
	#	"近距伤害更高，攻击间隔 0.35 秒。目标距离小于一半射程时伤害 +4。",
	#	"从战场上缴获的改进型。"))
	list.append(_p("bulwark", "盾卫装甲车", 7, 1, "uncommon",
		"平台 — 盾卫装甲车／正面减伤",
		"移速 0.5｜耐久 140",
		"正面受击减伤 40%，背后正常。不可移动时正面减伤提升至 55%。",
		"“盾在人在。”"))
	list.append(_p("titan_mk2", "马克V型·改", 10, 2, "rare",
		"平台 — 马克V型·改／超重装",
		"移速 0.4｜耐久 220",
		"受到伤害 -3（最低 1）。存续 12 秒后输出 +25%。",
		"“超重型突击坦克的装甲技术。”"))

	# 二战掉落
	# [已废弃] 武器系统已移除，保留代码供存档兼容
	#	"武器 — 突击冲锋枪／首次爆发",
	#	"伤害 14｜射程 中｜攻速 快",
	#	"首次攻击伤害 +80%，之后恢复正常。每 15 秒重置。",
	#	"第一击决定胜负。"))
	list.append(_p("storm_rider", "突击坦克·风暴型", 8, 6, "rare",
		"平台 — 突击坦克·风暴型／风暴增益",
		"移速 0.8｜耐久 95",
		"处于风暴/危险区域内时移速 +30%、伤害 +20%。",
		"“在风暴里才活着。”"))
	list.append(_p("heavy_carrier", "重型载机母舰", 9, 8, "rare",
		"平台 — 重型载机母舰／僚机强化",
		"移速 0.5｜耐久 150",
		"可搭载 2 台僚机。僚机被击毁后 12 秒可再次部署。",
		"“一舰变三机。”"))

	# 冷战掉落
	# [已废弃] 武器系统已移除，保留代码供存档兼容
	#	"武器 — 长程反坦克步枪／极远穿透",
	#	"伤害 40｜射程 极远｜攻速 慢",
	#	"射程 +100。无视目标 15% 护甲。",
	#	"直线上的东西都不安全。"))
	list.append(_p("regen_frame", "野战维修车·改", 6, 9, "uncommon",
		"平台 — 野战维修车·改／脱战回复",
		"移速 0.6｜耐久 85",
		"脱战 3 秒后每秒回复 8 耐久。低护甲。",
		"“打不死就满血。”"))

	# 现代掉落
	# [已废弃] 武器系统已移除，保留代码供存档兼容
	#	"武器 — 高爆榴霰弹／范围减速",
	#	"伤害 8｜射程 中｜攻速 慢",
	#	"短 CD 小范围 AOE，命中单位 2 秒内移速 -30%。",
	#	"跑不动就挨打。"))
	list.append(_p("abrams_mk2", "艾布拉姆斯坦克·改", 10, 1, "rare",
		"平台 — 艾布拉姆斯坦克·改／野战修复",
		"移速 0.6｜耐久 320",
		"脱战后每秒回复 5% 血量。装甲厚度 +20%。",
		"“现代坦克的巅峰。”"))
	# [已废弃] 武器系统已移除，保留代码供存档兼容
	#	"模块 — 超频模块／一次性增益",
	#	"使用后 10 秒内该单位攻速 +25%、移速 +20%。仅生效一次。",
	#	"装备后使用一次，为该单位提供短时超频。",
	#	"试作指挥中枢的馈赠。"))

	# 近未来掉落
	# [已废弃] 武器系统已移除，保留代码供存档兼容
	#	"武器 — 米加光束炮／穿盾",
	#	"伤害 35｜射程 远｜攻速 中",
	#	"持续锁定单体，高穿盾。对护盾伤害 +40%。",
	#	"从虚空借来的光。"))
	#	"武器 — 米加粒子炮／终极火力",
	#	"伤害 65｜射程 极远｜攻速 慢",
	#	"极高伤害的终极武器，少量单位即可扭转战局。",
	#	"当它开火时，战场会短暂安静。"))

	list.append_array(_create_generated_blueprints())
	return list

## 根据 platform_type 返回合理的默认武器类型（与 default_cards.gd 一致）
## PlatformType → 默认武器类型（旧 WeaponType 枚举值）
const _PLATFORM_DEFAULT_WEAPON: Dictionary = {
	0: 0,   # HOUND → SMG
	1: 1,   # GUARD → RIFLE
	2: 3,   # TITAN → ROCKET
	3: 2,   # FORTRESS → MG
	4: 1,   # RADAR → RIFLE
	5: 0,   # SCOUT → SMG
	6: 2,   # RAIDER → MG
	7: 3,   # SIEGE → ROCKET
	8: 2,   # CARRIER → MG
	9: 4,   # MEDIC → PISTOL
	10: 0,  # STEALTH → SMG
	11: 10, # OMEGA_PLATFORM → OMEGA_CANNON
}

## PlatformType → 默认武器中文名
const _PLATFORM_DEFAULT_WEAPON_LABEL: Dictionary = {
	0: "冲锋枪",
	1: "步枪",
	2: "火箭炮",
	3: "机枪",
	4: "步枪",
	5: "冲锋枪",
	6: "机枪",
	7: "火箭炮",
	8: "机枪",
	9: "手枪",
	10: "冲锋枪",
	11: "米加粒子炮",
}

static func _default_weapon_for_platform(pt: int) -> int:
	return int(_PLATFORM_DEFAULT_WEAPON.get(pt, 1))  # 默认 RIFLE

static func _p(id: String, name: String, cost: float, pt: int, rarity: String, type_line: String, summary: String, desc: String, flavor: String) -> CardResource:
	var c = CardResource.new()
	c.card_id = id
	c.display_name = name
	c.card_type = GC.CardType.COMBAT_UNIT
	c.energy_cost = cost
	c.combat_kind = int(UnitStatsTable.PLATFORM_TO_COMBAT_KIND.get(pt, 1))
	c.weapon_label = str(_PLATFORM_DEFAULT_WEAPON_LABEL.get(pt, "步枪"))
	c.era = 1
	c.base_hp = 100.0
	c.range_value = 3
	c.attack_speed = 1.0
	c.base_speed = 80.0
	c.rarity = rarity
	c.type_line = type_line
	c.summary_line = summary
	c.description = desc
	c.flavor_text = flavor
	return c
