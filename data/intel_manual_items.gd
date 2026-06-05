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
static func roll_random_evolution_blueprint(rank: String) -> Dictionary:
	# 进化蓝图只从精英和Boss掉落
	if rank == "normal":
		return {}

	# TODO: 从进化路径注册表中获取所有可掉落的进化路径
	# 目前返回空，待进化路径表完善后实现
	return {}

## ── 内部工具 ─────────────────────────────────────────────

static func _enemy_type_to_unit_type(enemy_type: String) -> int:
	# 将敌人类型转换为unit_type（CombatKind）
	# 注意：某些兵种共享相同的 unit_type
	match enemy_type:
		"infantry", "recon": return 0  # LIGHT
		"armor", "heavy_armor": return 1  # ARMOR
		"artillery", "engineer": return 2  # SUPPORT
		"air": return 3  # AIR
		"fort": return 4  # FORT
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
		print("[IntelManualItems] 无效蓝图ID: %s" % blueprint_id)
		return {}

	if is_mod_blueprint(blueprint_id):
		var mod_id = BlueprintDefinitions.extract_mod_id(blueprint_id)
		var mod_data = ModificationRegistry.get_data(mod_id)
		if mod_data.is_empty():
			print("[IntelManualItems] 改造模块不存在: %s" % mod_id)
			return {}
		var rarity = mod_data.get("rarity", "common")
		return {
			"name": BlueprintDefinitions.get_mod_blueprint_name(mod_id),
			"desc": _get_mod_blueprint_desc(mod_id, rarity),
			"rarity": rarity,
			"type": "mod",
			"mod_id": mod_id,
			"icon": mod_data.get("icon", "res://textures/icons/mods/default_mod.png"),
		}
	elif is_evolution_blueprint(blueprint_id):
		## 进化蓝图定义
		var info = BlueprintDefinitions.extract_evolution_info(blueprint_id)
		var from_card = info.get("from", "")
		var to_card = info.get("to", "")
		if from_card.is_empty() or to_card.is_empty():
			print("[IntelManualItems] 进化蓝图解析失败: %s, from=%s, to=%s" % [blueprint_id, from_card, to_card])
			return {}
		return {
			"name": "进化图纸：%s → %s" % [from_card, to_card],
			"desc": "允许将%s进化为%s" % [from_card, to_card],
			"rarity": "epic",
			"type": "evolution",
			"from": from_card,
			"icon": "res://textures/icons/evolution_blueprint.png",
			"to": to_card,
		}
	print("[IntelManualItems] 未知的蓝图类型: %s" % blueprint_id)
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

