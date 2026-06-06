extends Node
## 改造模块注册表
## 管理所有140+个改造模块的注册、查询和验证

const InfantryModifications = preload("res://data/modification_modules/infantry_mods.gd")
const ArmorModifications = preload("res://data/modification_modules/armor_mods.gd")
const ArtilleryModifications = preload("res://data/modification_modules/artillery_mods.gd")
const AntiAirModifications = preload("res://data/modification_modules/anti_air_mods.gd")
const AirModifications = preload("res://data/modification_modules/air_mods.gd")
const ReconModifications = preload("res://data/modification_modules/recon_mods.gd")
const EngineerModifications = preload("res://data/modification_modules/engineer_mods.gd")
const FortModifications = preload("res://data/modification_modules/fort_mods.gd")
const UniversalModifications = preload("res://data/modification_modules/universal_mods.gd")

## ─────────────────────────────────────────────
##  缓存
## ─────────────────────────────────────────────

static var _cache: Dictionary = {}
static var _initialized: bool = false

## ─────────────────────────────────────────────
##  初始化
## ─────────────────────────────────────────────

func _ready() -> void:
	## 作为autoload时自动初始化
	register_all()

## ─────────────────────────────────────────────
##  注册
## ─────────────────────────────────────────────

## 注册所有改造模块
static func register_all() -> void:
	if _initialized:
		return

	_cache.clear()
	_register_modifications("infantry", InfantryModifications)
	_register_modifications("armor", ArmorModifications)
	_register_modifications("artillery", ArtilleryModifications)
	_register_modifications("anti_air", AntiAirModifications)
	_register_modifications("air", AirModifications)
	_register_modifications("recon", ReconModifications)
	_register_modifications("engineer", EngineerModifications)
	_register_modifications("fort", FortModifications)
	_register_modifications("universal", UniversalModifications)

	_initialized = true
	# [LOG-v5.1] print("[ModificationRegistry] Registered %d modification modules" % _count_total())

static func _register_modifications(type_key: String, class_ref: RefCounted) -> void:
	var mod_ids = class_ref.get_all_mod_ids()
	var type_cache = {}

	for mod_id in mod_ids:
		type_cache[mod_id] = class_ref.get_mod_data(mod_id)

	_cache[type_key] = type_cache

static func _count_total() -> int:
	var count = 0
	for type_key in _cache.keys():
		count += _cache[type_key].size()
	return count

## ─────────────────────────────────────────────
##  查询接口
## ─────────────────────────────────────────────

## 获取改造数据
static func get_data(mod_id: String) -> Dictionary:
	_ensure_initialized()

	# 优先通过各模块直接查找（避免前缀解析问题）
	for type_key in _cache.keys():
		if _cache[type_key].has(mod_id):
			return _cache[type_key][mod_id].duplicate(true)

	# 回退：解析ID前缀获取类型
	var prefix = mod_id.split("_")[0]  # "inf", "arm", "art"...
	var type_key = _prefix_to_type(prefix)

	if type_key.is_empty():
		return {}

	return _cache.get(type_key, {}).get(mod_id, {}).duplicate(true)

## 获取特定兵种的所有改造
static func get_for_unit_type(unit_type: int) -> Array:
	_ensure_initialized()

	var result = []
	result.append_array(InfantryModifications.get_for_unit_type(unit_type))
	result.append_array(ArmorModifications.get_for_unit_type(unit_type))
	result.append_array(ArtilleryModifications.get_for_unit_type(unit_type))
	result.append_array(AntiAirModifications.get_for_unit_type(unit_type))
	result.append_array(AirModifications.get_for_unit_type(unit_type))
	result.append_array(ReconModifications.get_for_unit_type(unit_type))
	result.append_array(EngineerModifications.get_for_unit_type(unit_type))
	result.append_array(FortModifications.get_for_unit_type(unit_type))
	result.append_array(UniversalModifications.get_for_unit_type(unit_type))
	return result

## 按 card_id 精筛改造（比 get_for_unit_type 更精确）
static func get_mods_for_card(card_id: String) -> Array:
	_ensure_initialized()
	var result = []
	result.append_array(InfantryModifications.get_for_card(card_id))
	result.append_array(ArmorModifications.get_for_card(card_id))
	result.append_array(ArtilleryModifications.get_for_card(card_id))
	result.append_array(AntiAirModifications.get_for_card(card_id))
	result.append_array(AirModifications.get_for_card(card_id))
	result.append_array(ReconModifications.get_for_card(card_id))
	result.append_array(EngineerModifications.get_for_card(card_id))
	result.append_array(FortModifications.get_for_card(card_id))
	result.append_array(UniversalModifications.get_for_card(card_id))
	return result

## 检查改造冲突
static func check_conflict(card: Dictionary, mod_id: String) -> bool:
	_ensure_initialized()

	var mod_data = get_data(mod_id)
	var conflict_group = mod_data.get("conflict_group", "")

	if conflict_group.is_empty():
		return false  # 无冲突

	var installed = card.get("installed_modifications", [])
	for installed_mod in installed:
		var installed_id = installed_mod.get("id", "") if installed_mod is Dictionary else String(installed_mod)
		var installed_data = get_data(installed_id)
		var installed_group = installed_data.get("conflict_group", "")
		if installed_group == conflict_group:
			return true  # 冲突

	return false

## 验证槽位类型
static func validate_slot_type(mod_id: String, slot_type: String) -> bool:
	_ensure_initialized()

	var mod_data = get_data(mod_id)
	var mod_slot_type = mod_data.get("slot_type", "")
	return mod_slot_type == slot_type or mod_slot_type == "universal"

## 计算改造效果（应用到属性）
static func apply_effects(base_stats: Dictionary, modifications: Array) -> Dictionary:
	_ensure_initialized()

	var result = base_stats.duplicate(true)

	for mod_entry in modifications:
		var mod_id = mod_entry.get("id", "") if mod_entry is Dictionary else String(mod_entry)
		var mod_data = get_data(mod_id)
		var effects = mod_data.get("effects", {})

		# 应用效果
		for effect_key in effects.keys():
			var effect_value = effects[effect_key]

			match effect_key:
				"attack_light", "attack_armor", "attack_air":
					if result.has(effect_key):
						if effect_value is float:
							result[effect_key] = int(result[effect_key] * (1.0 + effect_value))
						elif effect_value is int:
							result[effect_key] += effect_value
				"defense_light", "defense_armor", "defense_air":
					if result.has(effect_key):
						if effect_value is float:
							result[effect_key] = int(result[effect_key] * (1.0 + effect_value))
						elif effect_value is int:
							result[effect_key] += effect_value
				"max_hp":
					if result.has(effect_key):
						if effect_value is float:
							result[effect_key] = int(result[effect_key] * (1.0 + effect_value))
						elif effect_value is int:
							result[effect_key] += effect_value
				"move_speed", "attack_range":
					if result.has(effect_key):
						result[effect_key] += effect_value
				"attack_interval":
					if result.has(effect_key):
						result[effect_key] = max(0.1, result[effect_key] * (1.0 + effect_value))
				"deploy_speed":
					if result.has(effect_key):
						result[effect_key] = max(0, result[effect_key] + effect_value)
				"crit_chance", "dodge_chance", "crit_resist":
					if not result.has(effect_key):
						result[effect_key] = 0.0
					result[effect_key] = min(1.0, result[effect_key] + effect_value)
				_:
					# 特殊效果（如hp_regen, smoke_ignore等）
					if not result.has("_special"):
						result["_special"] = {}
					result["_special"][effect_key] = effect_value

	return result

## ─────────────────────────────────────────────
##  内部工具
## ─────────────────────────────────────────────

static func _ensure_initialized() -> void:
	if not _initialized:
		register_all()

static func _prefix_to_type(prefix: String) -> String:
	match prefix:
		"inf": return "infantry"
		"arm": return "armor"
		"art": return "artillery"
		"aa": return "anti_air"
		"air": return "air"
		"rec": return "recon"
		"eng": return "engineer"
		"for": return "fort"
		"gen": return "universal"
		_: return ""

## 获取所有改造ID（用于调试）
static func get_all_ids() -> Array:
	_ensure_initialized()

	var result = []
	for type_key in _cache.keys():
		result.append_array(_cache[type_key].keys())
	return result
