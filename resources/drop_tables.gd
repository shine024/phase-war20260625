class_name DropTables extends Resource

## 预加载常用资源
const DefaultCards = preload("res://data/default_cards.gd")
const PhaseLaws = preload("res://data/phase_laws.gd")
const GC = preload("res://resources/game_constants.gd")

## 掉落物类型枚举
enum DropType {
	MATERIAL,           # 基础素材（纳米材料、合金等）
	CARD_DATA,          # 卡牌研究数据（研究点来源）
	DROPPED_CARD,       # 战斗掉落成品卡（带星级和强化）
	LORE_PAGE,          # 世界观情报
	CARD_REWARD,        # 完整卡牌
	ENERGY_CARD,        # 能量卡
	STAT_BOOST,         # 属性提升道具
	LAW_CARD,           # 法则卡
	LAW_DATA,           # 法则卡研究数据
	ENERGY_DATA,        # 能量卡研究数据
	BLUEPRINT_FRAGMENT, # 敌方蓝图碎片（与 CARD_DATA 语义相同，UI/领取用显式类型）
	LAW_BLUEPRINT,      # 法则侧蓝图/碎片条目（与 LAW_DATA 展示一致）
	ENERGY_BLUEPRINT,    # 能量蓝图条目（与 ENERGY_DATA 展示一致）
}

## 掉落物条目
class DropEntry:
	var item_id: String      # 物品ID
	var type: DropType       # 物品类型
	var weight: float = 1.0  # 权重（用于随机抽取）
	var min_count: int = 1   # 最小数量
	var max_count: int = 1   # 最大数量
	var metadata: Dictionary = {}  # 额外数据

	func _init(p_id: String, p_type: DropType, p_weight: float = 1.0, p_min: int = 1, p_max: int = 1):
		item_id = p_id
		type = p_type
		weight = p_weight
		min_count = p_min
		max_count = p_max

## 掉落表
class DropTable:
	var table_id: String
	var table_name: String
	var min_drops: int = 1      # 最少掉落数量
	var max_drops: int = 3      # 最多掉落数量
	var entries: Array[DropEntry] = []  # 掉落池
	var guarantee_drops: Array[DropEntry] = []  # 保底掉落（必定获得）

	func _init(p_id: String, p_name: String, p_min: int = 1, p_max: int = 3):
		table_id = p_id
		table_name = p_name
		min_drops = p_min
		max_drops = p_max

	func add_entry(entry: DropEntry) -> void:
		entries.append(entry)

	func add_guarantee(entry: DropEntry) -> void:
		guarantee_drops.append(entry)

## 掉落结果
class DropResult:
	var drop: DropEntry
	var count: int
	var source: String  # 来源描述

	func _init(p_drop: DropEntry, p_count: int, p_source: String = ""):
		drop = p_drop
		count = p_count
		source = p_source

## ========== 时代卡牌ID映射表（仅作兜底；主路径见 get_random_blueprint_for_era）==========

var era_blueprint_ids: Dictionary = {}

## 与击杀精英掉落、敌方原型表一致的「命名敌方蓝图」id（仅 PLATFORM 类型，WEAPON 系统已废弃）
const _NAMED_ELITE_ENEMY_BLUEPRINT_IDS: Array[String] = [
	"bulwark", "titan_mk2", "storm_rider", "heavy_carrier",
	"regen_frame", "abrams_mk2",
]


## 根据时代从敌方蓝图池随机一张 bp_{时代}_###（仅 PLATFORM 类型，WEAPON 已废弃）
func get_random_blueprint_for_era(era: int) -> String:
	return ""


func _pick_random_rare_enemy_drop_id(era: int) -> String:
	return ""


func sample_era_blueprint_display_names_for_preview(p_era: int, level_seed: int, max_names: int) -> PackedStringArray:
	return []


func resolve_blueprint_id(item_id: String, era: int) -> String:
	if item_id.begins_with("bp_"):
		return item_id
	if item_id.begins_with("era_"):
		return ""
	if item_id == "random_rare":
		return ""
	if item_id == "random_boss":
		return ""
	return item_id

## 根据关卡时代和难度生成掉落
func generate_drops(era: int, level: int, player_won: bool, victory_stars: int = 0) -> Array[DropResult]:
	var results: Array[DropResult] = []

	if not player_won:
		results.append(DropResult.new(
			DropEntry.new("nano_materials", DropType.MATERIAL, 1.0, 10, 20),
			20,
			"失败奖励"
		))
		return results

	var drop_pool: Array[DropEntry]
	var guarantee: Array[DropEntry] = []

	match era:
		0:
			drop_pool = ww1_common_drops
			guarantee = [
				DropEntry.new("nano_materials", DropType.MATERIAL, 1.0, 30, 50),
				DropEntry.new("", DropType.CARD_DATA, 0.0, 0, 0)
			]
		1:
			drop_pool = ww2_common_drops
			guarantee = [
				DropEntry.new("nano_materials", DropType.MATERIAL, 1.0, 50, 80),
				DropEntry.new("", DropType.CARD_DATA, 0.0, 0, 0)
			]
		2:
			drop_pool = cold_war_common_drops
			guarantee = [
				DropEntry.new("nano_materials", DropType.MATERIAL, 1.0, 70, 100),
				DropEntry.new("alloy", DropType.MATERIAL, 1.0, 15, 20),
				DropEntry.new("", DropType.CARD_DATA, 0.0, 0, 0)
			]
		3:
			drop_pool = modern_common_drops
			guarantee = [
				DropEntry.new("nano_materials", DropType.MATERIAL, 1.0, 90, 120),
				DropEntry.new("alloy", DropType.MATERIAL, 1.0, 20, 25),
				DropEntry.new("", DropType.CARD_DATA, 0.0, 0, 0)
			]
		4:
			drop_pool = near_future_common_drops
			guarantee = [
				DropEntry.new("nano_materials", DropType.MATERIAL, 1.0, 110, 150),
				DropEntry.new("alloy", DropType.MATERIAL, 1.0, 25, 30),
				DropEntry.new("crystal", DropType.MATERIAL, 1.0, 10, 15),
				DropEntry.new("era_4", DropType.CARD_DATA, 1.0, 1, 2)
			]
		_:
			drop_pool = material_drops
			guarantee = [
				DropEntry.new("nano_materials", DropType.MATERIAL, 1.0, 20, 40)
			]

	for g in guarantee:
		var count = randi_range(g.min_count, g.max_count)
		results.append(DropResult.new(g, count, "保底奖励"))

	if victory_stars >= 3:
		results.append(DropResult.new(
			DropEntry.new("era_%d" % era, DropType.CARD_DATA, 1.0, 1, 1),
			1,
			"三星奖励"
		))

	var random_drop_count = randi_range(1, 3)
	var total_weight = 0.0
	for entry in drop_pool:
		total_weight += entry.weight

	for i in range(random_drop_count):
		var roll = randf() * total_weight
		var current_weight = 0.0
		for entry in drop_pool:
			current_weight += entry.weight
			if roll <= current_weight:
				var count = randi_range(entry.min_count, entry.max_count)
				results.append(DropResult.new(entry, count, "随机掉落"))
				break

	_finalize_card_data_drops(results, era)
	return results

## 生成Boss战掉落
func generate_boss_drops(era: int, boss_id: String) -> Array[DropResult]:
	var results: Array[DropResult] = []

	results.append(DropResult.new(
		DropEntry.new("nano_materials", DropType.MATERIAL, 1.0, 300, 500),
		300,
		"Boss保底"
	))

	results.append(DropResult.new(
		DropEntry.new("random_boss", DropType.CARD_DATA, 1.0, 1, 1),
		1,
		"卡牌数据"
	))

	var specific_candidates: Array = era_boss_specific_permits.get(era, [])
	if boss_id.find("void") >= 0:
		specific_candidates.append("permit_card_void_time_ripple")
		specific_candidates.append("permit_card_omega_platform")
	elif boss_id.find("steel") >= 0:
		specific_candidates.append("permit_card_platform_ww2_heavy")
	elif boss_id.find("flame") >= 0:
		specific_candidates.append("permit_card_platform_cold_medium")
	elif boss_id.find("thunder") >= 0:
		specific_candidates.append("permit_card_thunder_emp_storm")
	if not specific_candidates.is_empty():
		var picked_id: String = String(specific_candidates[randi() % specific_candidates.size()])
		results.append(DropResult.new(
			DropEntry.new(picked_id, DropType.MATERIAL, 1.0, 1, 1),
			1,
			"Boss专属许可"
		))

	var total_weight = 0.0
	for entry in boss_drops:
		total_weight += entry.weight

	var roll_count = randi_range(2, 4)
	for i in range(roll_count):
		var roll = randf() * total_weight
		var current_weight = 0.0
		for entry in boss_drops:
			current_weight += entry.weight
			if roll <= current_weight:
				var count = randi_range(entry.min_count, entry.max_count)
				results.append(DropResult.new(entry, count, "Boss额外奖励"))
				break

	_finalize_card_data_drops(results, era)
	return results

## 将 era_N / random_* 等虚拟ID落成具体卡牌ID（与领取时一致，结算界面可显示卡名）
func _finalize_card_data_drops(results: Array, era: int) -> void:
	for i in range(results.size()):
		var r = results[i]
		if r == null or not r is DropResult:
			continue
		var res: DropResult = r as DropResult
		if res.drop.type != DropType.CARD_DATA and res.drop.type != DropType.BLUEPRINT_FRAGMENT:
			continue
		var resolved: String = resolve_blueprint_id(res.drop.item_id, era)
		if not resolved.is_empty():
			res.drop.item_id = resolved

## 格式化卡牌ID为可读名称
func _format_blueprint_id(blueprint_id: String) -> String:
	# 将 bp_ww1_001 转换为 "WW1-001"
	if blueprint_id.begins_with("bp_"):
		var parts = blueprint_id.split("_")
		if parts.size() >= 3:
			var era = parts[1].to_upper()
			var number = parts[2]
			return "%s-%s" % [era, number]
	return blueprint_id

## 获取掉落物显示名称
func get_drop_display_name(entry: DropEntry) -> String:
	match entry.type:
		DropType.MATERIAL:
			match entry.item_id:
				"nano_materials": return "纳米材料"
				"alloy": return "合金"
				"crystal": return "晶体"
				"permit_general": return "改造许可函·通用"
				"permit_type_assault": return "改造许可函·突击型"
				"permit_type_heavy": return "改造许可函·重装型"
				"permit_type_support": return "改造许可函·支援型"
				"permit_type_law": return "改造许可函·法则型"
				_ when entry.item_id.begins_with("permit_card_"):
					var target_id: String = entry.item_id.trim_prefix("permit_card_")
					var target_card = DefaultCards.get_card_by_id(target_id)
					var target_name: String = ""
					if target_card != null:
						target_name = target_card.display_name
					else:
						var law_cfg: Dictionary = PhaseLaws.get_by_id(target_id)
						target_name = String(law_cfg.get("name", target_id))
					return "改造许可函·%s专属" % target_name
				_: return entry.item_id
		DropType.CARD_DATA, DropType.BLUEPRINT_FRAGMENT:
			# era_N：未在生成阶段解析时（旧存档等）的占位文案
			if entry.item_id.begins_with("era_"):
				return "时代随机掉落卡"
			if entry.item_id.begins_with("bp_"):
				var card_bp = DefaultCards.get_card_by_id(entry.item_id)
				if card_bp:
					return "%s（敌方缴获）" % card_bp.display_name
				return "%s（敌方缴获）" % (_format_blueprint_id(entry.item_id))
			if entry.item_id == "random_rare" or entry.item_id == "random_boss":
				return "随机掉落卡"
			# 已解析或非 bp_ 的真实卡牌 ID
			var card_any = DefaultCards.get_card_by_id(entry.item_id)
			if card_any:
				return "%s（掉落）" % card_any.display_name
			if not entry.item_id.is_empty():
				return "%s（掉落）" % entry.item_id
			return "掉落卡"
		DropType.DROPPED_CARD:
			var card = DefaultCards.get_card_by_id(entry.item_id)
			if card:
				return "成品卡: " + card.display_name
			return "成品卡: " + entry.item_id
		DropType.LORE_PAGE:
			match entry.item_id:
				"lore_ww1_trench": return "堑壕战术手册"
				"lore_ww2_blitzkrieg": return "闪电战档案"
				"lore_cold_berlin": return "柏林墙日记"
				"lore_modern_drone": return "无人机作战手册"
				"lore_future_phase": return "相位技术纲要"
				_: return "情报资料"
		DropType.CARD_REWARD:
			var card = DefaultCards.get_card_by_id(entry.item_id)
			if card:
				return "卡牌: " + str(card.display_name)
			return "卡牌: " + entry.item_id
		DropType.ENERGY_CARD:
			match entry.item_id:
				"energy_basic": return "基础能量卡"
				"energy_advanced": return "高级能量卡"
				"energy_quantum": return "量子能量卡"
				_: return "能量卡"
		DropType.LAW_DATA, DropType.LAW_BLUEPRINT:
			# 法则数据：显示法则名称
			var law = PhaseLaws.get_by_id(entry.item_id)
			if not law.is_empty():
				return law.get("name", entry.item_id) + "（法则卡）"
			return "法则卡数据"
		DropType.ENERGY_DATA, DropType.ENERGY_BLUEPRINT:
			match entry.item_id:
				"energy_blueprint": return "能量卡数据"
				_: return "能量卡数据"
		DropType.LAW_CARD:
			# 完整法则卡
			if entry.item_id == "law_random_passive":
				return "随机被动法则卡"
			if entry.item_id == "law_random_active":
				return "随机主动法则卡"
			var law = PhaseLaws.get_by_id(entry.item_id)
			if not law.is_empty():
				return law.get("name", entry.item_id) + " 法则卡"
			return "法则卡"
		DropType.STAT_BOOST:
			match entry.item_id:
				"stat_boost_hp": return "生命强化"
				"stat_boost_damage": return "攻击强化"
				"stat_boost_speed": return "速度强化"
				"stat_boost_defense": return "防御强化"
				"stat_boost_attack_speed": return "攻速强化"
				"stat_boost_crit": return "暴击强化"
				"stat_boost_crit_damage": return "暴伤强化"
				_: return "属性提升"
		_: return entry.item_id

## 获取掉落物图标路径
func get_drop_icon_path(entry: DropEntry) -> String:
	match entry.type:
		DropType.MATERIAL:
			return "res://assets/icons/drops/material.png"
		DropType.CARD_DATA, DropType.BLUEPRINT_FRAGMENT:
			return "res://assets/icons/drops/blueprint.png"
		DropType.DROPPED_CARD:
			return "res://assets/icons/drops/card.png"
		DropType.LORE_PAGE:
			return "res://assets/icons/drops/lore.png"
		DropType.CARD_REWARD:
			return "res://assets/icons/drops/card.png"
		DropType.ENERGY_CARD:
			return "res://assets/icons/drops/energy.png"
		DropType.ENERGY_DATA, DropType.ENERGY_BLUEPRINT:
			return "res://assets/icons/drops/energy_blueprint.png"
		DropType.LAW_DATA, DropType.LAW_BLUEPRINT:
			return "res://assets/icons/drops/law_blueprint.png"
		DropType.LAW_CARD:
			return "res://assets/icons/drops/law_card.png"
		DropType.STAT_BOOST:
			return "res://assets/icons/drops/boost.png"
		_:
			return "res://assets/icons/drops/default.png"

## 获取掉落物稀有度颜色
func get_drop_rarity_color(entry: DropEntry) -> Color:
	match entry.type:
		DropType.MATERIAL:
			return Color(0.7, 0.7, 0.7)
		DropType.CARD_DATA, DropType.BLUEPRINT_FRAGMENT:
			return Color(0.3, 0.6, 1.0)
		DropType.DROPPED_CARD:
			return Color(0.5, 0.3, 0.8)
		DropType.LORE_PAGE:
			return Color(0.8, 0.6, 0.2)
		DropType.CARD_REWARD:
			return Color(0.5, 0.3, 0.8)
		DropType.ENERGY_CARD:
			return Color(0.3, 0.8, 0.3)
		DropType.ENERGY_DATA, DropType.ENERGY_BLUEPRINT:
			return Color(0.3, 0.9, 0.5)  # 绿色
		DropType.LAW_DATA, DropType.LAW_BLUEPRINT:
			return Color(0.8, 0.4, 0.8)  # 紫色，表示稀有
		DropType.LAW_CARD:
			return Color(0.9, 0.6, 0.2)  # 金色，表示史诗
		DropType.STAT_BOOST:
			return Color(1.0, 0.5, 0.0)
		_:
			return Color.WHITE