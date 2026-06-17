extends RefCounted
## v7.0: 蓝图道具系统
## 蓝图是战斗掉落和商店可购买的一次性消耗品。
## 每个改造模块和进化路径都有对应的蓝图。
##
## 蓝图类型：
##   - 改造蓝图：blueprint_<mod_id> — 允许安装对应改造模块
##   - 进化蓝图：blueprint_evol_<from>_<to> — 允许对应进化操作
##
## 获取方式：
##   - 战斗掉落（基于敌人类型）
##   - 商店购买

const BlueprintDefinitions = preload("res://data/blueprint_definitions.gd")
const ModificationRegistry = preload("res://scripts/systems/modification_registry.gd")

## ── 商店可售卖的蓝图列表 ────────────────────────────────────

## 所有可在商店购买的蓝图ID
## 随着游戏进程解锁，这里列出初始可用的蓝图
const ALL_TYPES: Array[String] = [
	## 步兵改造蓝图 (LIGHT unit_type = 0)
	"blueprint_inf_01_submachine_gun",
	"blueprint_inf_02_assault_rifle",
	"blueprint_inf_05_ap_ammo",
	"blueprint_inf_11_armor_insert",
	## 装甲改造蓝图 (ARMOR unit_type = 1)
	"blueprint_arm_01_sloped_armor",
	"blueprint_arm_06_apfsds",
	"blueprint_arm_11_fire_control",
	## 更多蓝图将在游戏进程中解锁
]

## ── 蓝图类型前缀 ──────────────────────────────────────────

const PREFIX_MOD := "blueprint_"           ## 改造蓝图前缀
const PREFIX_EVOL := "blueprint_evol_"      ## 进化蓝图前缀

## ── 静态方法 ─────────────────────────────────────────────

## 判断蓝图ID是否有效
static func is_valid_blueprint(blueprint_id: String) -> bool:
	if blueprint_id.begins_with(PREFIX_MOD):
		return true
	if blueprint_id.begins_with(PREFIX_EVOL):
		return true
	return false

## 判断是否为改造蓝图
static func is_mod_blueprint(blueprint_id: String) -> bool:
	return BlueprintDefinitions.is_mod_blueprint(blueprint_id)

## 判断是否为进化蓝图
static func is_evolution_blueprint(blueprint_id: String) -> bool:
	return BlueprintDefinitions.is_evolution_blueprint(blueprint_id)

## 获取蓝图显示名称
static func get_blueprint_name(blueprint_id: String) -> String:
	if is_mod_blueprint(blueprint_id):
		var mod_id = BlueprintDefinitions.extract_mod_id(blueprint_id)
		return BlueprintDefinitions.get_mod_blueprint_name(mod_id)
	elif is_evolution_blueprint(blueprint_id):
		# 进化蓝图名称由调用者提供
		return "进化图纸"
	return "未知图纸"

## 获取蓝图稀有度
static func get_blueprint_rarity(blueprint_id: String) -> String:
	if is_mod_blueprint(blueprint_id):
		var mod_id = BlueprintDefinitions.extract_mod_id(blueprint_id)
		return BlueprintDefinitions.get_mod_blueprint_rarity(mod_id)
	elif is_evolution_blueprint(blueprint_id):
		return "epic"  # 进化图纸默认史诗
	return "common"

## 获取稀有度颜色
static func get_rarity_color(rarity: String) -> Color:
	match rarity:
		"common": return Color(0.7, 0.8, 0.7, 1.0)
		"uncommon": return Color(0.3, 0.75, 0.3, 1.0)
		"rare": return Color(0.3, 0.5, 1.0, 1.0)
		"epic": return Color(0.7, 0.3, 0.9, 1.0)
		"legendary": return Color(1.0, 0.6, 0.2, 1.0)
		_: return Color.WHITE

## 获取稀有度名称
static func get_rarity_name(rarity: String) -> String:
	match rarity:
		"common": return "普通"
		"uncommon": return "精良"
		"rare": return "稀有"
		"epic": return "史诗"
		"legendary": return "传说"
		_: return "未知"

## 随机掉落一个改造蓝图（基于敌人类型）
## enemy_type: "infantry", "armor", "artillery", "air", "recon", etc.
## rank: "normal" / "elite" / "boss"
static func roll_random_mod_blueprint(enemy_type: String, rank: String) -> Dictionary:
	# ModificationRegistry 已在类顶部 const 声明，无需重复声明

	# 获取该敌人类型可掉落的改造列表
	var unit_type = _enemy_type_to_unit_type(enemy_type)
	var available_mods = ModificationRegistry.get_for_unit_type(unit_type)

	if available_mods.is_empty():
		return {}

	# 根据稀有度权重随机选择
	var weighted_pool = []
	for mod_id in available_mods:
		var mod_data = ModificationRegistry.get_data(mod_id)
		var rarity = mod_data.get("rarity", "common")
		var weight = _get_rarity_drop_weight(rarity, rank)
		if weight > 0:
			weighted_pool.append({"mod_id": mod_id, "weight": weight})

	var total_weight = 0
	for entry in weighted_pool:
		total_weight += entry.weight

	if total_weight == 0:
		return {}

	var roll = randi() % total_weight
	var cumulative = 0
	for entry in weighted_pool:
		cumulative += entry.weight
		if roll < cumulative:
			var blueprint_id = BlueprintDefinitions.get_mod_blueprint_id(entry.mod_id)
			return {
				"item_type": blueprint_id,
				"name": get_blueprint_name(blueprint_id),
				"rarity": get_blueprint_rarity(blueprint_id),
				"mod_id": entry.mod_id,
			}

	return {}

## 随机掉落一个进化蓝图
## rank: "normal" / "elite" / "boss"
## v7.1: 实现——从 8 类进化路径的所有"进化跳"中按稀有度加权随机
## （允许掉重复：不查背包，已拥有的蓝图数量+1但不影响解锁状态）
static func roll_random_evolution_blueprint(rank: String) -> Dictionary:
	# 进化蓝图只从精英和Boss掉落
	if rank == "normal":
		return {}

	# 收集所有进化路径的"进化跳"（from_card → to_card）
	var all_evo_steps = _collect_all_evolution_steps()

	if all_evo_steps.is_empty():
		return {}

	# 按稀有度加权随机选择
	var weighted_pool = []
	for step in all_evo_steps:
		var rarity = _era_to_rarity(step.get("to_era", "WW1"))
		var weight = _get_rarity_drop_weight(rarity, rank)
		if weight > 0:
			weighted_pool.append({
				"from": step["from"],
				"to": step["to"],
				"rarity": rarity,
				"weight": weight,
			})

	if weighted_pool.is_empty():
		return {}

	# 加权随机
	var total_weight = 0
	for entry in weighted_pool:
		total_weight += entry.weight
	var roll = randi() % total_weight
	var cumulative = 0
	for entry in weighted_pool:
		cumulative += entry.weight
		if roll < cumulative:
			var blueprint_id = BlueprintDefinitions.get_evolution_blueprint_id(entry.from, entry.to)
			return {
				"item_type": blueprint_id,
				"name": get_blueprint_name(blueprint_id),
				"rarity": entry.rarity,
				"from": entry.from,
				"to": entry.to,
			}
	return {}

## ── 内部工具 ─────────────────────────────────────────────

## v7.1: 收集所有进化路径的进化跳（每条路径的相邻节点配对）
## 返回: [{from, to, to_era}, ...]
static func _collect_all_evolution_steps() -> Array:
	var steps: Array = []
	# 8 类进化路径
	var path_classes: Array = [
		preload("res://data/evolution_paths/infantry_evolution.gd"),
		preload("res://data/evolution_paths/armor_evolution.gd"),
		preload("res://data/evolution_paths/artillery_evolution.gd"),
		preload("res://data/evolution_paths/anti_air_evolution.gd"),
		preload("res://data/evolution_paths/air_evolution.gd"),
		preload("res://data/evolution_paths/recon_evolution.gd"),
		preload("res://data/evolution_paths/engineer_evolution.gd"),
		preload("res://data/evolution_paths/fort_evolution.gd"),
	]
	for path_class in path_classes:
		# 主线
		if path_class.has_method("get_main_line"):
			_append_steps_from_path(steps, path_class.get_main_line())
		# 副线（装甲/空军/堡垒有）
		if path_class.has_method("get_secondary_line"):
			_append_steps_from_path(steps, path_class.get_secondary_line())
		# 隐藏分支
		if path_class.has_method("get_hidden_branches"):
			var hidden = path_class.get_hidden_branches()
			for branch_name in hidden:
				_append_steps_from_path(steps, hidden[branch_name])
	return steps

## v7.1: 从单条进化路径（Dictionary，按stage排序）中提取相邻卡配对
static func _append_steps_from_path(steps: Array, path: Dictionary) -> void:
	if path.is_empty():
		return
	# 按stage排序
	var sorted: Array = []
	for key in path.keys():
		var node: Dictionary = path[key]
		sorted.append({"stage": int(node.get("stage", 0)), "node": node})
	sorted.sort_custom(func(a, b): return a.stage < b.stage)
	# 相邻配对
	var prev_card := ""
	for entry in sorted:
		var card_id: String = entry.node.get("card_id", "")
		if card_id.is_empty():
			continue
		if not prev_card.is_empty():
			steps.append({
				"from": prev_card,
				"to": card_id,
				"to_era": entry.node.get("era", "WW1"),
			})
		prev_card = card_id

## v7.1: 进化目标卡 era → 稀有度映射（影响掉落权重）
static func _era_to_rarity(era: String) -> String:
	match era:
		"WW1", "WW2": return "common"
		"Cold": return "uncommon"
		"Modern": return "rare"
		"Future", "Ultimate": return "epic"
		_: return "common"

static func _enemy_type_to_unit_type(enemy_type: String) -> int:
	# 将敌人类型转换为unit_type（CombatKind）
	# v6.4: 补全 flame/stealth/anti_air/boss/medic/command 等映射，避免只掉步兵蓝图
	match enemy_type:
		"infantry", "recon", "flame", "medic", "scout": return 0  # LIGHT（步兵系）
		"armor", "heavy_armor", "command": return 1  # ARMOR（装甲系，指挥官归装甲）
		"artillery", "engineer", "anti_air": return 2  # SUPPORT（炮兵/工兵/防空）
		"air", "stealth": return 3  # AIR（空军/隐身单位归空军）
		"fort", "boss_nano", "boss_phase": return 4  # FORT（堡垒/Boss 归堡垒）
		_: return 0  # 默认 LIGHT

static func _get_rarity_drop_weight(rarity: String, rank: String) -> int:
	# 根据稀有度和敌人等级返回掉落权重
	var base = 0
	match rarity:
		"common": base = 40
		"uncommon": base = 25
		"rare": base = 12
		"epic": base = 5
		"legendary": base = 2
		_: base = 0

	match rank:
		"boss": return base * 3
		"elite": return base * 2
		_: return base

## ── 蓝图定义查询 ───────────────────────────────────────────

## 获取蓝图定义信息
## Returns: {name, desc, rarity, type}
static func get_def(blueprint_id: String) -> Dictionary:
	if not is_valid_blueprint(blueprint_id):
		push_warning("[IntelManualItems] 无效蓝图ID: %s" % blueprint_id)
		return {}

	if is_mod_blueprint(blueprint_id):
		var mod_id = BlueprintDefinitions.extract_mod_id(blueprint_id)
		var mod_data = ModificationRegistry.get_data(mod_id)
		if mod_data.is_empty():
			push_warning("[IntelManualItems] 改造模块不存在: %s" % mod_id)
			return {}
		var rarity = mod_data.get("rarity", "common")
		return {
			"name": BlueprintDefinitions.get_mod_blueprint_name(mod_id),
			"desc": _get_mod_blueprint_desc(mod_id, rarity),
			"rarity": rarity,
			"type": "mod",
			"mod_id": mod_id,
			"icon": "res://assets/ui/icons/icon_modification.svg",
		}
	elif is_evolution_blueprint(blueprint_id):
		## 进化蓝图定义
		var info = BlueprintDefinitions.extract_evolution_info(blueprint_id)
		var from_card = info.get("from", "")
		var to_card = info.get("to", "")
		if from_card.is_empty() or to_card.is_empty():
			push_warning("[IntelManualItems] 进化蓝图解析失败: %s, from=%s, to=%s" % [blueprint_id, from_card, to_card])
			return {}
		return {
			"name": "进化图纸：%s → %s" % [from_card, to_card],
			"desc": "允许将%s进化为%s" % [from_card, to_card],
			"rarity": "epic",
			"type": "evolution",
			"from": from_card,
			"icon": "res://assets/ui/icons/icon_blueprint.svg",
			"to": to_card,
		}
	push_warning("[IntelManualItems] 未知的蓝图类型: %s" % blueprint_id)
	return {}

## 获取改造蓝图描述
static func _get_mod_blueprint_desc(mod_id: String, rarity: String) -> String:
	var rarity_name = get_rarity_name(rarity)
	return "允许安装【%s】改造模块（%s）" % [mod_id, rarity_name]

## 获取商店价格（基于稀有度）
static func get_shop_price(blueprint_id: String) -> int:
	var def = get_def(blueprint_id)
	if def.is_empty():
		return 0
	var rarity = def.get("rarity", "common")
	match rarity:
		"common": return 100
		"uncommon": return 250
		"rare": return 600
		"epic": return 1500
		"legendary": return 3500
		_: return 100

## 动态获取所有可购买蓝图（包括游戏进程中解锁的）
## current_reputation: 当前声望值
static func get_available_blueprints(current_reputation: int = 0) -> Array[String]:
	var available: Array[String] = []
	## 基础蓝图始终可用
	for bp_id in ALL_TYPES:
		available.append(bp_id)
	## 随着声望解锁更多蓝图（TODO: 实现解锁逻辑）
	return available

