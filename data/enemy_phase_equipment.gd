extends RefCounted
class_name EnemyPhaseEquipment

## 数据子模块预加载
const _EquipmentSpecials = preload("res://data/enemy_equipment_specials.gd")
const _EquipmentArmorModules = preload("res://data/enemy_equipment_armor_modules.gd")
const _EquipmentWeapons = preload("res://data/enemy_equipment_weapons.gd")

const _INSTRUMENTS_JSON_PATH := "res://data/json/enemy_phase_instruments.json"
const _PLATFORMS_JSON_PATH := "res://data/json/enemy_phase_platforms.json"
const _WEAPONS_JSON_PATH := "res://data/json/enemy_phase_weapons.json"
const _ENERGY_JSON_PATH := "res://data/json/enemy_phase_energy_cards.json"

static var PHASE_INSTRUMENTS: Dictionary = _load_json_dict(_INSTRUMENTS_JSON_PATH, _EquipmentSpecials.LEGACY_PHASE_INSTRUMENTS)
static var WAR_PLATFORMS: Dictionary = _load_json_dict(_PLATFORMS_JSON_PATH, _EquipmentArmorModules.LEGACY_WAR_PLATFORMS)
static var WAR_WEAPONS: Dictionary = _load_json_dict(_WEAPONS_JSON_PATH, _EquipmentWeapons.LEGACY_WAR_WEAPONS)
static var ENERGY_CARDS: Dictionary = _load_json_dict(_ENERGY_JSON_PATH, _EquipmentSpecials.LEGACY_ENERGY_CARDS)

## 向后兼容：const 别名指向子模块同名 const
const LEGACY_PHASE_INSTRUMENTS: Dictionary = _EquipmentSpecials.LEGACY_PHASE_INSTRUMENTS
const LEGACY_WAR_PLATFORMS: Dictionary = _EquipmentArmorModules.LEGACY_WAR_PLATFORMS
const LEGACY_WAR_WEAPONS: Dictionary = _EquipmentWeapons.LEGACY_WAR_WEAPONS
const LEGACY_ENERGY_CARDS: Dictionary = _EquipmentSpecials.LEGACY_ENERGY_CARDS

static func _load_json_dict(path: String, fallback: Dictionary) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("[EnemyPhaseEquipment] JSON missing: %s" % path)
		return fallback
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY or int(parsed.get("schema_version", 0)) != 1:
		return fallback
	var data = parsed.get("data", fallback)
	return data if typeof(data) == TYPE_DICTIONARY else fallback

## 敌方相位师装备数据：相位仪、平台、武器、能量卡

const GC = preload("res://resources/game_constants.gd")

const CardResource = preload("res://resources/card_resource.gd")

const DefaultCards = preload("res://data/default_cards.gd")

## 战争平台 type 字符串 -> GameConstants.PlatformType（用于蓝图库 CardResource）
const _WAR_PLATFORM_TYPE_MAP: Dictionary = {
	"fortress": 3,
	"titan": 2,
	"raider": 6,
	"siege": 7,
	"striker": 6,
	"sniper": 5,
	"stealth": 10,
	"mage": 11,
}

## PlatformType -> combat_kind 正确映射（0=轻装, 1=装甲, 2=支援, 3=空中）
const _PLATFORM_TO_COMBAT_KIND: Dictionary = {
	0: 0,          # 轻装
	1: 1,          # 装甲
	2: 1,          # 装甲
	3: 2,       # 支援
	4: 2,          # 支援
	5: 0,          # 轻装
	6: 0,         # 轻装
	7: 2,          # 支援
	8: 3,        # 空中
	9: 2,          # 支援
	10: 0,        # 轻装
	11: 1, # 装甲
	12: 2,        # 支援
}

## 战争武器 type 字符串 -> GameConstants.WeaponType
const _WAR_WEAPON_TYPE_MAP: Dictionary = {
	"machinegun": 2,
	"cannon": 3,
	"railcannon": 11,
	"flamethrower": 7,
	"mortar": 3,
	"tesla": 8,
	"railgun": 11,
	"lance": 8,
	"gravity": 9,
}

## 将敌方相位师装备 ID 转为蓝图库/解析 UI 用的 CardResource（仅展示）
static func get_equipment_blueprint(equipment_id: String) -> CardResource:
	if equipment_id.is_empty():
		return null
	var pdata: Dictionary = get_war_platform(equipment_id)
	if not pdata.is_empty():
		return _card_resource_from_war_platform(pdata, equipment_id)
	var wdata: Dictionary = get_war_weapon(equipment_id)
	if not wdata.is_empty():
		return _card_resource_from_war_weapon(wdata, equipment_id)
	var edata: Dictionary = get_energy_card(equipment_id)
	if not edata.is_empty():
		return _card_resource_from_energy_card(edata, equipment_id)
	var idata: Dictionary = get_phase_instrument(equipment_id)
	if not idata.is_empty():
		return _card_resource_from_phase_instrument(idata, equipment_id)
	return null

static func _card_resource_from_war_platform(d: Dictionary, equipment_id: String) -> CardResource:
	var c := CardResource.new()
	c.card_id = equipment_id
	var ename: String = String(d.get("name", ""))
	c.display_name = ename if not ename.is_empty() else DefaultCards.get_safe_display_name(equipment_id)
	c.rarity = String(d.get("rarity", "common"))
	var ptype: String = String(d.get("type", "titan"))
	c.card_type = GC.CardType.COMBAT_UNIT
	var platform_type_val: int = int(_WAR_PLATFORM_TYPE_MAP.get(ptype, 2))
	c.combat_kind = int(_PLATFORM_TO_COMBAT_KIND.get(platform_type_val, 1))
	c.energy_cost = 5.0 + float(d.get("level", 5)) * 0.3
	c.type_line = "平台 — %s／敌方相位师" % String(d.get("faction", ""))
	var stats: Dictionary = d.get("stats", {}) as Dictionary
	c.summary_line = "耐久 %d｜攻击 %d｜移速 %d" % [
		int(stats.get("hp", 0)), int(stats.get("attack", 0)), int(stats.get("move_speed", 0))]
	c.description = "由敌方相位师装备数据生成的平台蓝图（展示用）。"
	c.flavor_text = ""
	#c.max_weapons = 2
	#c.weight_capacity = 0
	c.era = 0
	c.base_hp = float(stats.get("hp", 100.0))
	c.range_value = 120  # 射程（格）
	c.attack_speed = 1.0  # 攻速（次/秒）
	c.base_speed = float(stats.get("move_speed", 80.0))
	return c

static func _card_resource_from_war_weapon(d: Dictionary, equipment_id: String) -> CardResource:
	var c := CardResource.new()
	c.card_id = equipment_id
	var ename: String = String(d.get("name", ""))
	c.display_name = ename if not ename.is_empty() else DefaultCards.get_safe_display_name(equipment_id)
	c.rarity = String(d.get("rarity", "common"))
	var wtype: String = String(d.get("type", "machinegun"))
	c.card_type = GC.CardType.COMBAT_UNIT
	c.weapon_label = wtype
	c.energy_cost = 4.0 + float(d.get("level", 5)) * 0.25
	c.type_line = "武器 — %s／敌方相位师" % String(d.get("faction", ""))
	c.summary_line = "伤害 %d｜攻速 %.2f｜射程 %d" % [
		int(d.get("damage", 0)), float(d.get("attack_speed", 0.0)), int(d.get("range", 0))]
	c.description = "由敌方相位师装备数据生成的武器蓝图（展示用）。"
	#c.weight = 1
	c.era = 0
	c.combat_kind = 0
	c.base_hp = 100.0
	c.range_value = int(float(d.get("range", 120.0)))  # 射程（格）
	c.attack_speed = float(d.get("attack_speed", 1.0)) if float(d.get("attack_speed", 0.0)) > 0.0 else 1.0  # 攻速（次/秒）
	c.base_speed = 0.0
	return c

static func _card_resource_from_energy_card(d: Dictionary, equipment_id: String) -> CardResource:
	var c := CardResource.new()
	c.card_id = equipment_id
	var ename: String = String(d.get("name", ""))
	c.display_name = ename if not ename.is_empty() else DefaultCards.get_safe_display_name(equipment_id)
	c.rarity = String(d.get("rarity", "common"))
	c.card_type = GC.CardType.ENERGY
	c.energy_cost = 0.0
	c.energy_grant = float(d.get("energy_amount", 15))
	c.type_line = "能量 — %s／敌方相位师" % String(d.get("faction", ""))
	c.summary_line = "能量 +%.0f｜回充 +%.1f" % [
		float(d.get("energy_amount", 0.0)), float(d.get("energy_regen_boost", 0.0))]
	c.description = "由敌方相位师装备数据生成的能量卡蓝图（展示用）。"
	return c

static func _card_resource_from_phase_instrument(d: Dictionary, equipment_id: String) -> CardResource:
	var c := CardResource.new()
	c.card_id = equipment_id
	var ename: String = String(d.get("name", ""))
	c.display_name = ename if not ename.is_empty() else DefaultCards.get_safe_display_name(equipment_id)
	c.rarity = String(d.get("rarity", "common"))
	c.card_type = GC.CardType.COMBAT_UNIT
	c.combat_kind = int(_PLATFORM_TO_COMBAT_KIND.get(11, 1))
	c.energy_cost = 6.0 + float(d.get("level", 5)) * 0.35
	c.type_line = "相位仪 — %s" % String(d.get("faction", ""))
	var bs: Dictionary = d.get("base_stats", {}) as Dictionary
	c.summary_line = "Lv.%d｜耐久 %d｜能量 %d" % [
		int(d.get("level", 0)), int(bs.get("max_hp", 0)), int(bs.get("energy_capacity", 0))]
	c.description = "由敌方相位师装备数据生成的相位仪蓝图（展示用）。"
	#c.max_weapons = 0
	c.era = 0
	c.base_hp = float(bs.get("max_hp", 100.0))
	c.base_range = 120.0
	c.base_interval = 1.0
	c.base_speed = 0.0
	return c

## 获取相位仪数据
static func get_phase_instrument(instrument_id: String) -> Dictionary:
	if PHASE_INSTRUMENTS.has(instrument_id):
		return PHASE_INSTRUMENTS[instrument_id]
	return {}

## 获取平台数据
static func get_war_platform(platform_id: String) -> Dictionary:
	if WAR_PLATFORMS.has(platform_id):
		return WAR_PLATFORMS[platform_id]
	return {}


## 敌方平台卡绑定的默认武器 id（`enemy_phase_platforms.json` 字段 `default_weapon`）
static func get_default_weapon_id_for_platform(platform_id: String) -> String:
	var d: Dictionary = get_war_platform(platform_id)
	if d.is_empty():
		return ""
	return String(d.get("default_weapon", "")).strip_edges()


## 获取武器数据
static func get_war_weapon(weapon_id: String) -> Dictionary:
	if WAR_WEAPONS.has(weapon_id):
		return WAR_WEAPONS[weapon_id]
	return {}

## 获取能量卡数据
static func get_energy_card(card_id: String) -> Dictionary:
	if ENERGY_CARDS.has(card_id):
		return ENERGY_CARDS[card_id]
	return {}

## 根据等级获取可用装备
static func get_equipment_by_level(level: int) -> Dictionary:
	var result = {
		"phase_instruments": [],
		"platforms": [],
		"weapons": [],
		"energy_cards": []
	}

	for instrument_id in PHASE_INSTRUMENTS:
		var instrument = PHASE_INSTRUMENTS[instrument_id]
		if instrument.level <= level + 5:  # 允许使用稍高等级的装备
			result.phase_instruments.append(instrument_id)

	for platform_id in WAR_PLATFORMS:
		var platform = WAR_PLATFORMS[platform_id]
		if platform.level <= level + 3:
			result.platforms.append(platform_id)

	for weapon_id in WAR_WEAPONS:
		var weapon = WAR_WEAPONS[weapon_id]
		if weapon.level <= level + 3:
			result.weapons.append(weapon_id)

	for card_id in ENERGY_CARDS:
		var card = ENERGY_CARDS[card_id]
		if card.level <= level + 2:
			result.energy_cards.append(card_id)

	return result

## 根据势力获取装备
static func get_equipment_by_faction(faction: String) -> Dictionary:
	var result = {
		"phase_instruments": [],
		"platforms": [],
		"weapons": [],
		"energy_cards": []
	}

	var faction_prefix = faction.split("_")[0]

	for instrument_id in PHASE_INSTRUMENTS:
		if instrument_id.contains(faction_prefix):
			result.phase_instruments.append(instrument_id)

	for platform_id in WAR_PLATFORMS:
		if platform_id.contains(faction_prefix):
			result.platforms.append(platform_id)

	for weapon_id in WAR_WEAPONS:
		if weapon_id.contains(faction_prefix):
			result.weapons.append(weapon_id)

	for card_id in ENERGY_CARDS:
		if card_id.contains(faction_prefix):
			result.energy_cards.append(card_id)

	return result
