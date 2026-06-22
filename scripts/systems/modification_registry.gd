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
const EnhancementModifications = preload("res://data/modification_modules/enhancement_mods.gd")  # v6.4 强化词条统一

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
	_register_modifications("enhancement", EnhancementModifications)  # v6.4 强化词条统一

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
	# v6.4: 强化词条适用于所有兵种
	result.append_array(EnhancementModifications.get_for_unit_type(unit_type))
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
	# v6.4: 强化词条适用所有卡
	result.append_array(EnhancementModifications.get_for_card(card_id))
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
		# v6.5: 跳过已禁用的改造
		if mod_entry is Dictionary:
			if mod_entry.has("enabled") and not bool(mod_entry.get("enabled", true)):
				continue
		var mod_id = mod_entry.get("id", "") if mod_entry is Dictionary else String(mod_entry)
		var mod_data = get_data(mod_id)
		var effects = mod_data.get("effects", {})
		if effects.is_empty():
			continue
		# v6.4: 复用统一的单条应用逻辑
		result = _apply_single_mod_effects(result, effects)

	return result


## v6.4: 按等级应用改造效果（统一5套系统的等级概念）
## modifications: Array of {id, level} 或 {id}（默认level=1）或纯String（默认level=1）
## 支持改造条目里的 level_effects（每级不同效果）或 effects（无等级差异时用，所有等级相同）
static func apply_with_level(base_stats: Dictionary, modifications: Array) -> Dictionary:
	_ensure_initialized()

	var result = base_stats.duplicate(true)

	for mod_entry in modifications:
		var mod_id: String = ""
		var mod_level: int = 1
		if mod_entry is Dictionary:
			mod_id = String(mod_entry.get("id", ""))
			mod_level = int(mod_entry.get("level", 1))
			# v6.5: 跳过已禁用的改造（仅武器类改造可禁用，但这里统一检查）
			# 旧存档无 enabled 字段时默认视为启用（true）
			if mod_entry.has("enabled") and not bool(mod_entry.get("enabled", true)):
				continue
		else:
			mod_id = String(mod_entry)
		if mod_id.is_empty():
			continue
		mod_level = clampi(mod_level, 1, 3)  # 等级统一1-3

		var mod_data: Dictionary = get_data(mod_id)
		if mod_data.is_empty():
			continue

		# 优先使用 level_effects（每级不同），否则用 effects（所有等级相同）
		var effects: Dictionary = {}
		var level_effects: Dictionary = mod_data.get("level_effects", {})
		if not level_effects.is_empty() and level_effects.has(mod_level):
			effects = level_effects[mod_level]
		else:
			effects = mod_data.get("effects", {})

		# 应用效果（复用 apply_effects 的单条逻辑）
		result = _apply_single_mod_effects(result, effects)

	return result


## v6.4: 内部辅助——对单个 effects 字典应用到一个 stats 字典（apply_effects 的单条逻辑抽取）
static func _apply_single_mod_effects(result: Dictionary, effects: Dictionary) -> Dictionary:
	for effect_key in effects.keys():
		var effect_value = effects[effect_key]
		match effect_key:
			"attack_light", "attack_armor", "attack_air", \
			"defense_light", "defense_armor", "defense_air", "max_hp":
				if not result.has(effect_key):
					result[effect_key] = 0
				if effect_value is float:
					result[effect_key] = int(float(result[effect_key]) * (1.0 + effect_value))
				elif effect_value is int:
					result[effect_key] += effect_value
			"move_speed", "attack_range":
				if not result.has(effect_key):
					result[effect_key] = 0
				result[effect_key] += effect_value
			"attack_interval":
				if not result.has(effect_key):
					result[effect_key] = 1.0
				result[effect_key] = max(0.1, float(result[effect_key]) * (1.0 + effect_value))
			"deploy_speed":
				if not result.has(effect_key):
					result[effect_key] = 0
				result[effect_key] = max(0, int(result[effect_key]) + int(effect_value))
			"crit_chance", "dodge_chance", "crit_resist", "armor_penetration", \
			"armor_pen_vs_light", "armor_pen_vs_armor", "armor_pen_vs_air":
				if not result.has(effect_key):
					result[effect_key] = 0.0
				result[effect_key] = min(1.0, float(result[effect_key]) + float(effect_value))
			# v6.6: attack_fort → 条件型对堡垒伤害加成（温压弹/爆破装置）
			# 加法叠加（值是正小数），仅在 get_attack_vs() 对 FORT 目标时生效
			"attack_fort":
				if not result.has("attack_fort_bonus"):
					result["attack_fort_bonus"] = 0.0
				result["attack_fort_bonus"] += float(effect_value)
			# v6.6: splash_radius → 溅射半径乘数加成（子母弹/近炸引信）
			"splash_radius":
				if not result.has("splash_radius_bonus"):
					result["splash_radius_bonus"] = 0.0
				result["splash_radius_bonus"] += float(effect_value)
			# v6.6: single_target_penalty → 主目标伤害乘数（负值，子母弹平衡项）
			"single_target_penalty":
				if not result.has("single_target_penalty"):
					result["single_target_penalty"] = 0.0
				result["single_target_penalty"] += float(effect_value)
			# v6.6: 补全高频失效的软特性 key（映射到已有 stat）
			# accuracy_bonus：命中提升 → 映射为暴击率（命中系统简化，6个炮兵/防空/空战核心改造用它）
			"accuracy_bonus":
				if not result.has("crit_chance"):
					result["crit_chance"] = 0.0
				result["crit_chance"] = min(1.0, float(result["crit_chance"]) + float(effect_value))
			# ifak_heal：急救包 → 映射为持续回血
			"ifak_heal":
				if not result.has("hp_regen"):
					result["hp_regen"] = 0.0
				result["hp_regen"] += float(effect_value)
			# mine_immunity / nbq_immunity：免疫类 → 映射为减伤
			"mine_immunity", "nbq_immunity":
				if not result.has("damage_reduction"):
					result["damage_reduction"] = 0.0
				result["damage_reduction"] = min(0.75, float(result["damage_reduction"]) + float(effect_value))
			# sustained_fire：持续射击 → 映射为攻速提升（负 attack_interval）
			"sustained_fire":
				if not result.has("attack_interval"):
					result["attack_interval"] = 1.0
				result["attack_interval"] = max(0.1, float(result["attack_interval"]) * (1.0 - float(effect_value)))
			# v6.6: missile_dodge → 映射为通用闪避（反导主题改造：gen_09/aa_09/air_08）
			# 当前弹道无"导弹 vs 其他"区分维度，干净映射为 dodge_chance
			"missile_dodge":
				if not result.has("dodge_chance"):
					result["dodge_chance"] = 0.0
				result["dodge_chance"] = min(1.0, float(result["dodge_chance"]) + float(effect_value))
			# v6.6: counter_bonus → 映射为暴击率（反炮兵雷达 art_05，"精确还击"语义）
			"counter_bonus":
				if not result.has("crit_chance"):
					result["crit_chance"] = 0.0
				result["crit_chance"] = min(1.0, float(result["crit_chance"]) + float(effect_value))
			"damage_reduction":
				if not result.has(effect_key):
					result[effect_key] = 0.0
				result[effect_key] = min(0.75, float(result[effect_key]) + float(effect_value))
			"crit_damage_bonus", "shield_on_kill", "hp_regen":
				if not result.has(effect_key):
					result[effect_key] = 0.0
				result[effect_key] += float(effect_value)
			"lifesteal":
				if not result.has(effect_key):
					result[effect_key] = 0.0
				result[effect_key] = min(0.6, float(result[effect_key]) + float(effect_value))
			"splash_damage":
				if not result.has(effect_key):
					result[effect_key] = 0.0
				result[effect_key] = min(0.8, float(result[effect_key]) + float(effect_value))
			"chain_chance":
				if not result.has(effect_key):
					result[effect_key] = 0.0
				result[effect_key] = min(0.6, float(result[effect_key]) + float(effect_value))
			# v6.5→v6.6: 武器类改造改变武器型号（SHOTGUN/SNIPER/MISSILE 等 legacy 型号）
			# 修复前：直接写入 weapon_type，污染了弹道类型字段（WeaponType 4值枚举），
			# 导致 MISSILE(9) 被 AI 误判为非曲射。现写入独立的 legacy_weapon_type 字段
			# （UnitStats/WeaponResource 均有此字段，bullet 的 VFX/弹道 match 读它）
			"weapon_type", "legacy_weapon_type":
				result["legacy_weapon_type"] = int(effect_value)
			# ── v6.8: 第一批软特性 key 激活（语义同源映射，零新字段，复活 18 个改造）──
			# 视野/侦察类 → 攻击射程延伸（视野≈索敌范围≈射程）
			# gen_01_comms / gen_06_laser_designator / rec_05_uav / for_06_radar
			"vision", "vision_bonus", "stealth_detect", "detection_range":
				if not result.has("attack_range"):
					result["attack_range"] = 0
				result["attack_range"] += int(float(effect_value) * 120.0)
			# 夜视/烟雾穿透类 → 暴击率（精确射击语义）
			# inf_20_night_vision / rec_08_nvg / arm_12_thermal_sight / inf_21_thermal
			"night_bonus", "smoke_ignore":
				if not result.has("crit_chance"):
					result["crit_chance"] = 0.0
				result["crit_chance"] = min(1.0, float(result["crit_chance"]) + float(effect_value))
			# 热防护/三防类 → 减伤（防护语义同源）
			# rec_02_ir_suppression / arm_02_composite_armor / arm_03_reactive_armor / gen_07_mine_resistant
			"thermal_immunity", "heat_resist", "heat_immunity_once", "mine_damage_reduction":
				if not result.has("damage_reduction"):
					result["damage_reduction"] = 0.0
				result["damage_reduction"] = min(0.75, float(result["damage_reduction"]) + float(effect_value))
			# 隐蔽/低可探测类 → 闪避（难被发现=难被命中）
			# rec_01_optical_camouflage / gen_03_camouflage / for_07_camouflage
			"detection_reduce":
				if not result.has("dodge_chance"):
					result["dodge_chance"] = 0.0
				# detection_reduce 是负值（-0.20），取绝对值映射为闪避增益
				result["dodge_chance"] = min(1.0, float(result["dodge_chance"]) + absf(float(effect_value)))
			# 巷战加成类 → 对轻装伤害（巷战主要打击步兵/轻装）
			# inf_22_breaching / rec_09_breaching
			"urban_attack_bonus":
				if not result.has("attack_light"):
					result["attack_light"] = 0
				if effect_value is float:
					result["attack_light"] = int(float(result["attack_light"]) * (1.0 + effect_value))
				elif effect_value is int:
					result["attack_light"] += effect_value
			# ── v6.8: 第二批软特性 key 激活（语义同源映射，复活约 18 个改造）──
			# 射程/作战半径类 → 攻击射程
			# air_10_drop_tank(combat_range) / air_07_dogfight_missile(close_accuracy→暴击)
			"combat_range":
				if not result.has("attack_range"):
					result["attack_range"] = 0
				result["attack_range"] += int(float(effect_value) * 120.0)
			"close_accuracy", "enemy_confusion", "intel_speed":
				# 近战精确/敌方混乱/情报优势 → 暴击率（精确打击语义）
				if not result.has("crit_chance"):
					result["crit_chance"] = 0.0
				result["crit_chance"] = min(1.0, float(result["crit_chance"]) + float(effect_value))
			# 弹药/持续作战类 → 攻速提升（弹药充足=持续射速，负 attack_interval）
			# air_11_weapon_rack(ammo_capacity) / air_09_air_refuel(sustained_combat)
			# aa_06_laser(infinite_ammo) / aa_12_fire_on_move(mobile_fire)
			"ammo_capacity", "sustained_combat":
				if not result.has("attack_interval"):
					result["attack_interval"] = 1.0
				result["attack_interval"] = max(0.1, float(result["attack_interval"]) * (1.0 - float(effect_value)))
			"infinite_ammo", "mobile_fire":
				# 布尔型：无限弹药/行进间射击 → 攻速小幅提升（true 时减 10% 间隔）
				if not result.has("attack_interval"):
					result["attack_interval"] = 1.0
				if bool(effect_value):
					result["attack_interval"] = max(0.1, float(result["attack_interval"]) * 0.9)
			"accuracy_penalty":
				# 精度惩罚（负值）→ 暴击率降低（aa_12 行进间射击的平衡项）
				if not result.has("crit_chance"):
					result["crit_chance"] = 0.0
				result["crit_chance"] = max(0.0, float(result["crit_chance"]) + float(effect_value))
			# 反装甲/反轻装类 → 对应维度伤害加成
			# for_08_trench(enemy_armor_slow -0.50) → 对装甲；for_09_minefield(approach_damage) → 对轻装
			"enemy_armor_slow":
				if not result.has("attack_armor"):
					result["attack_armor"] = 0
				result["attack_armor"] = int(float(result["attack_armor"]) * (1.0 + absf(float(effect_value))))
			"approach_damage":
				if not result.has("attack_light"):
					result["attack_light"] = 0
				if effect_value is float:
					result["attack_light"] = int(float(result["attack_light"]) * (1.0 + float(effect_value)))
			# 隐蔽/反锁定类 → 闪避（负值取绝对值转为闪避增益）
			# air_03_stealth_coating(lock_reduction -0.40) / rec_03_suppressor(fire_exposure -0.80)
			# aa_10_camouflage(aggro_reduce -0.30)
			"lock_reduction", "fire_exposure", "aggro_reduce":
				if not result.has("dodge_chance"):
					result["dodge_chance"] = 0.0
				result["dodge_chance"] = min(1.0, float(result["dodge_chance"]) + absf(float(effect_value)))
			# 拦截/防护类 → 减伤
			# aa_06_laser / arm_04_aps(missile_intercept 0.30)
			"missile_intercept":
				if not result.has("damage_reduction"):
					result["damage_reduction"] = 0.0
				result["damage_reduction"] = min(0.75, float(result["damage_reduction"]) + float(effect_value))
			# 巷战机动类 → 移动速度（inf_22/rec_09 urban_move_bonus 10/20）
			"urban_move_bonus":
				if not result.has("move_speed"):
					result["move_speed"] = 0
				result["move_speed"] += int(effect_value)
			_:
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

## ─── 武器槽位系统支持 ───

## 应用改造效果到武器槽位
## weapon: WeaponResource - 基础武器
## modifications: Array - 改造ID列表
## slot_idx: int - 槽位索引（0=轻装, 1=装甲, 2=对空）
## 返回：修改后的 WeaponResource
static func apply_to_weapon_slot(weapon: WeaponResource, modifications: Array, slot_idx: int = -1) -> WeaponResource:
	_ensure_initialized()
	if weapon == null or not weapon.enabled:
		return weapon

	var result = weapon.clone()
	
	for mod_entry in modifications:
		# v6.5: 跳过已禁用的改造
		if mod_entry is Dictionary:
			if mod_entry.has("enabled") and not bool(mod_entry.get("enabled", true)):
				continue
		var mod_id = mod_entry.get("id", "") if mod_entry is Dictionary else String(mod_entry)
		var mod_data = get_data(mod_id)
		if mod_data.is_empty():
			continue

		var effects = mod_data.get("effects", {})

		# 检查改造是否适用于特定槽位
		var condition_slot = int(mod_data.get("condition_slot", -1))
		if condition_slot >= 0 and condition_slot != slot_idx:
			continue

		# 应用效果到武器属性
		for effect_key in effects.keys():
			var effect_value = effects[effect_key]

			match effect_key:
				"slot_damage_mult":
					if effect_value is float or effect_value is int:
						result.damage *= float(effect_value)
				"slot_damage_add":
					if effect_value is float or effect_value is int:
						result.damage += float(effect_value)
				"slot_attack_speed_mult":
					if effect_value is float or effect_value is int:
						result.attack_speed *= float(effect_value)
				"slot_range_bonus":
					if effect_value is int:
						result.range_value += effect_value
				"slot_windup_reduce":
					if effect_value is float or effect_value is int:
						result.windup = maxf(0.05, result.windup - float(effect_value))
				"slot_active_reduce":
					if effect_value is float or effect_value is int:
						result.active = maxf(0.05, result.active - float(effect_value))
				# v6.5: 武器类改造改变该槽位的武器类型（影响弹道和命中效果）
				"slot_weapon_type":
					result.weapon_type = int(effect_value)
				_:
					# 其他特殊效果存储到武器 _mod_effects（已在 WeaponResource 声明，clone 时复制）
					result._mod_effects[effect_key] = effect_value
	
	return result

## 批量应用改造到所有武器槽位
## weapon_slots: Array[WeaponResource] - 武器槽位数组
## modifications: Array - 改造ID列表
## 返回：修改后的槽位数组（Array[WeaponResource]，与 unit_stats_table.tmp_slots 类型匹配，
##   避免普通 Array 赋给 typed Array[WeaponResource] 报错）
static func apply_to_weapon_slots(weapon_slots: Array, modifications: Array) -> Array:
	_ensure_initialized()
	var result: Array[WeaponResource] = []

	for i in range(weapon_slots.size()):
		var weapon = weapon_slots[i]
		if weapon is WeaponResource and weapon.enabled:
			result.append(apply_to_weapon_slot(weapon, modifications, i))
		elif weapon is WeaponResource:
			# 未启用槽位：原样保留（仍是 WeaponResource，类型安全）
			result.append(weapon)
		else:
			# 非 WeaponResource 占位：用空槽位补齐，保证 typed Array[WeaponResource] 不报错
			result.append(WeaponResource.create_empty_slot(i))

	return result
