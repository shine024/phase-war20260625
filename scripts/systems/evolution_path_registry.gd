extends Node
## 进化路径注册表
## 管理所有73个进化节点的查询和验证

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

static func register_all() -> void:
	if _initialized:
		return

	_cache.clear()

	# 注册所有兵种进化路径
	_register_path("infantry", InfantryEvolution.get_main_line(), InfantryEvolution.get_hidden_branches())
	_register_path("armor", ArmorEvolution.get_main_line(), ArmorEvolution.get_hidden_branches())
	_register_path("air", AirEvolution.get_main_line(), AirEvolution.get_hidden_branches())
	_register_path("artillery", ArtilleryEvolution.get_main_line(), ArtilleryEvolution.get_hidden_branches())
	_register_path("fort", FortEvolution.get_main_line(), FortEvolution.get_hidden_branches())
	_register_path("recon", ReconEvolution.get_main_line(), ReconEvolution.get_hidden_branches())
	_register_path("engineer", EngineerEvolution.get_main_line(), EngineerEvolution.get_hidden_branches())
	_register_path("anti_air", AntiAirEvolution.get_main_line(), AntiAirEvolution.get_hidden_branches())

	_initialized = true
	# [LOG-v5.1] print("[EvolutionPathRegistry] Registered evolution paths for all 8 unit types")

static func _register_path(type_key: String, main_line: Dictionary, hidden_branches: Dictionary) -> void:
	_cache[type_key] = {
		main_line = main_line.duplicate(true),
		hidden_branches = hidden_branches.duplicate(true),
	}

## ─────────────────────────────────────────────
##  查询接口
## ─────────────────────────────────────────────

## 获取卡牌的进化路径
static func get_evolution_path(card_id: String) -> Dictionary:
	_ensure_initialized()

	# 识别兵种类型
	var unit_type = _identify_unit_type(card_id)
	var type_key = _unit_type_to_key(unit_type)

	return _cache.get(type_key, {})

## 获取可进化到的目标列表
static func get_evolution_targets(card: Dictionary) -> Array:
	_ensure_initialized()

	var card_id = card.get("id", "")
	var path = get_evolution_path(card_id)
	var result = []

	# 主线目标
	var main_line = path.get("main_line", {})
	for stage_key in main_line.keys():
		var stage_data = main_line[stage_key]
		var target_id = stage_data.get("card_id", "")

		# 跳过当前卡牌
		if target_id == card_id:
			continue

		# 检查进化条件
		var requirements = stage_data.get("requirements", {})
		if _check_requirements(card, requirements):
			result.append({
				target_id = target_id,
				name = stage_data.get("name", ""),
				stage = stage_data.get("stage", 0),
				path_type = "main",
			})

	# 隐藏分支目标
	var hidden_branches = path.get("hidden_branches", {})
	for branch_key in hidden_branches.keys():
		var branch = hidden_branches[branch_key]
		for stage_key in branch.keys():
			var stage_data = branch[stage_key]
			var target_id = stage_data.get("card_id", "")

			if target_id == card_id:
				continue

			var requirements = stage_data.get("requirements", {})
			if _check_requirements(card, requirements):
				result.append({
					target_id = target_id,
					name = stage_data.get("name", ""),
					stage = stage_data.get("stage", 0),
					path_type = branch_key,
				})

	return result

## 检查进化条件
static func check_evolution_requirements(card: Dictionary, target_card_id: String) -> Dictionary:
	_ensure_initialized()

	var result = {
		passed = true,
		missing = [],
		warnings = [],
	}

	var path = get_evolution_path(card.get("id", ""))

	# 查找目标节点
	var target_node = _find_target_node(path, target_card_id)
	if target_node.is_empty():
		result.passed = false
		result.missing.append("找不到目标进化节点")
		return result

	# 检查条件
	var requirements = target_node.get("requirements", {})

	# 强化等级
	var required_level = requirements.get("level", 1)
	var current_level = card.get("level", 1)
	if current_level < required_level:
		result.passed = false
		result.missing.append("强化等级需要达到Lv%d" % required_level)

	# 改造数量
	var required_mods = requirements.get("mods_count", 0)
	var current_mods = card.get("installed_modifications", []).size()
	if current_mods < required_mods:
		result.passed = false
		result.missing.append("需要安装%d个改造" % required_mods)

	# EOM数量
	var required_eom = requirements.get("eom_count", 0)
	if required_eom > 0:
		var current_eom = _count_eom_modifications(card.get("installed_modifications", []))
		if current_eom < required_eom:
			result.passed = false
			result.missing.append("需要%d个进化专属改造" % required_eom)

	# 战力门槛
	var power_ratio = requirements.get("power_ratio", 1.0)
	var card_id = card.get("id", "")
	var base_power = card.get("power", 0)
	var current_power = card.get("level", 1)
	var target_power = target_node.get("power", 0)
	var min_power = int(target_power * power_ratio)

	# 计算实际战力（包含强化和改造加成）
	var actual_power = MilitaryTitleRegistry.calculate_current_power(base_power, current_power, _identify_unit_type(card_id))

	if actual_power < min_power:
		result.passed = false
		result.missing.append("战力不足，需要%d（当前%d）" % [min_power, actual_power])

	# 情报需求
	var intel_requirements = {}
	for key in requirements.keys():
		if key.begins_with("intel_"):
			intel_requirements[key] = requirements[key]

	if not intel_requirements.is_empty():
		# 检查情报系统
		if IntelManual and IntelManual.has_method("get_intel_progress"):
			for intel_key in intel_requirements.keys():
				var required_progress = intel_requirements[intel_key]
				# 从key中提取卡牌ID，如 "intel_ww1_mp18" -> "ww1_mp18"
				var intel_card_id = intel_key.trim_prefix("intel_")
				var current_progress = IntelManual.get_intel_progress(intel_card_id)

				if current_progress < required_progress:
					result.passed = false
					result.missing.append("%s情报不足（需要%.0f%%，当前%.0f%%）" % [
						intel_card_id, required_progress * 100, current_progress * 100
					])

	return result

## 计算进化后属性
static func calculate_evolved_stats(old_card: Dictionary, target_card_id: String) -> Dictionary:
	var path = get_evolution_path(old_card.get("id", ""))
	var target_node = _find_target_node(path, target_card_id)

	if target_node.is_empty():
		return {}

	var inherit_mult = target_node.get("inherit_multiplier", 0.30)

	# 基础属性
	var base_stats = {
		max_hp = target_node.get("max_hp", 0),
		attack_light = target_node.get("attack_light", 0),
		attack_armor = target_node.get("attack_armor", 0),
		attack_air = target_node.get("attack_air", 0),
		defense_light = target_node.get("defense_light", 0),
		defense_armor = target_node.get("defense_armor", 0),
		defense_air = target_node.get("defense_air", 0),
	}

	# 继承旧改造加成
	var old_mods = old_card.get("installed_modifications", [])
	var mod_bonus = ModificationRegistry.apply_effects({}, old_mods)

	# 应用继承比例
	for key in mod_bonus.keys():
		if base_stats.has(key):
			if mod_bonus[key] is int or mod_bonus[key] is float:
				base_stats[key] += int(mod_bonus[key] * inherit_mult)

	return base_stats

## ─────────────────────────────────────────────
##  内部工具
## ─────────────────────────────────────────────

static func _ensure_initialized() -> void:
	if not _initialized:
		register_all()

static func _identify_unit_type(card_id: String) -> int:
	# 根据卡牌ID前缀识别兵种类型
	# 步兵 (LIGHT)
	if card_id.begins_with("ww1_mp18") or card_id.begins_with("ww2_thompson"):
		return 0

	# 装甲 (MEDIUM)
	if card_id.begins_with("ww1_ft17") or card_id.begins_with("ww1_saint"):
		return 1
	if card_id.begins_with("ww2_pz3") or card_id.begins_with("ww2_tiger"):
		return 1
	if card_id.begins_with("cold_t55") or card_id.begins_with("cold_t72") or card_id.begins_with("cold_leo1"):
		return 1
	if card_id.begins_with("mod_m1a1") or card_id.begins_with("mod_m1a2sep") or card_id.begins_with("mod_leo2a6"):
		return 1
	if card_id.begins_with("fut_hovertank") or card_id.begins_with("fut_heavy_mech") or card_id.begins_with("fut_prism"):
		return 1

	# 空中 (HEAVY)
	if card_id.begins_with("cold_mig21") or card_id.begins_with("mod_f16"):
		return 2
	if card_id.begins_with("mod_ah1") or card_id.begins_with("mod_ah64"):
		return 2
	if card_id.begins_with("fut_f22") or card_id.begins_with("fut_space_fighter") or card_id.begins_with("fut_attack_drone") or card_id.begins_with("fut_swarm"):
		return 2
	if card_id.begins_with("fut_b2") or card_id.begins_with("fut_stealth_bomber"):
		return 2

	# 火炮 (HEAVY)
	if card_id.begins_with("mod_katyusha") or card_id.begins_with("mod_self_propelled"):
		return 3
	if card_id.begins_with("fort_cold_missile"):
		return 3
	if card_id.begins_with("fort_modern_cannon") or card_id.begins_with("fort_future_cannon"):
		return 3

	# 要塞 (HEAVY)
	if card_id.begins_with("fort_ww1_pillbox") or card_id.begins_with("fort_ww2_bunker"):
		return 4
	if card_id.begins_with("fort_ww2_flak"):
		return 4
	if card_id.begins_with("fort_cold_missile") or card_id.begins_with("fort_cold_radar"):
		return 4
	if card_id.begins_with("fort_modern_citadel") or card_id.begins_with("fort_modern_phalanx"):
		return 4
	if card_id.begins_with("fort_future_ion") or card_id.begins_with("fort_future_shield"):
		return 4

	# 侦察 (SUPPORT)
	if card_id.begins_with("ww1_cavalry") or card_id.begins_with("ww2_motorcycle"):
		return 5
	if card_id.begins_with("cold_spetsnaz"):
		return 5
	if card_id.begins_with("mod_ranger") or card_id.begins_with("mod_m24"):
		return 5
	if card_id.begins_with("cold_sniper"):
		return 5
	if card_id.begins_with("fut_spectre") or card_id.begins_with("fut_nexus_archer"):
		return 5

	# 工兵 (SUPPORT)
	if card_id.begins_with("mod_pioneer") or card_id.begins_with("mod_sapper") or card_id.begins_with("mod_engineer"):
		return 6
	if card_id.begins_with("mod_captain") or card_id.begins_with("mod_commissar"):
		return 6

	# 反空 (HEAVY)
	if card_id.begins_with("mod_flak") or card_id.begins_with("fort_ww2_flak"):
		return 7

	# 默认返回步兵
	return 0

static func _unit_type_to_key(unit_type: int) -> String:
	match unit_type:
		0: return "infantry"
		1: return "armor"
		2: return "artillery"
		3: return "air"
		4: return "fort"
		_: return ""

static func _find_target_node(path: Dictionary, target_card_id: String) -> Dictionary:
	# 搜索主线
	var main_line = path.get("main_line", {})
	for stage_key in main_line.keys():
		if main_line[stage_key].get("card_id", "") == target_card_id:
			return main_line[stage_key]

	# 搜索隐藏分支
	var hidden_branches = path.get("hidden_branches", {})
	for branch_key in hidden_branches.keys():
		var branch = hidden_branches[branch_key]
		for stage_key in branch.keys():
			if branch[stage_key].get("card_id", "") == target_card_id:
				return branch[stage_key]

	return {}

static func _check_requirements(card: Dictionary, requirements: Dictionary) -> bool:
	# 简化检查
	var level = requirements.get("level", 1)
	var mods_count = requirements.get("mods_count", 0)

	return card.get("level", 1) >= level and card.get("installed_modifications", []).size() >= mods_count

static func _count_eom_modifications(modifications: Array) -> int:
	var count = 0
	for mod_entry in modifications:
		var mod_id = mod_entry.get("id", "") if mod_entry is Dictionary else String(mod_entry)
		if mod_id.begins_with("EOM_"):
			count += 1
	return count

## ─── 武器槽位系统支持 ───

## 进化时继承/替换武器槽位
## source_card: CardResource - 源卡牌
## target_card_id: String - 目标卡牌ID
## preserve_mods: bool - 是否保留改造加成（默认true）
## 返回：进化后的武器槽位数组
static func evolve_weapon_slots(source_card: CardResource, target_card_id: String, preserve_mods: bool = true) -> Array:
	_ensure_initialized()
	
	# 获取目标卡牌（延迟加载避免循环依赖）
	var target_dc: GDScript = load("res://data/default_cards.gd")
	var target_card = target_dc.get_card_by_id(target_card_id) if target_dc else null
	if target_card == null:
		# 如果找不到目标卡牌，返回源卡槽位
		var result = []
		for w in source_card.weapon_slots:
			if w is WeaponResource:
				result.append(w.clone())
		return result
	
	# 确保目标卡槽位已初始化
	if target_card.has_method("_ensure_weapon_slots_initialized"):
		target_card._ensure_weapon_slots_initialized()
	
	# 确保源卡槽位已初始化
	if source_card.has_method("_ensure_weapon_slots_initialized"):
		source_card._ensure_weapon_slots_initialized()
	
	var evolved_slots = []
	
	# 遍历三个槽位
	for i in range(min(3, target_card.weapon_slots.size())):
		var target_weapon = target_card.weapon_slots[i]
		var source_weapon = null
		
		# 获取源卡对应槽位
		if i < source_card.weapon_slots.size():
			source_weapon = source_card.weapon_slots[i]
		
		if target_weapon is WeaponResource and target_weapon.enabled:
			# 目标槽位有武器，使用目标武器
			var evolved = target_weapon.clone()
			
			# 如果源卡有对应槽位且启用了改造保留
			if preserve_mods and source_weapon is WeaponResource and source_weapon.enabled:
				# 继承改造加成比例
				var base_damage = target_weapon.damage
				var source_damage = source_weapon.damage
				var mod_ratio = 1.0
				
				# 检查源武器是否有改造效果
				if source_weapon.has("_mod_effects"):
					var mod_effects = source_weapon.get("_mod_effects", {})
					var damage_mult = mod_effects.get("slot_damage_mult", 1.0)
					var damage_add = mod_effects.get("slot_damage_add", 0.0)
					mod_ratio = damage_mult + (damage_add / max(1.0, base_damage))
				
				# 应用改造加成到新武器
				if mod_ratio != 1.0:
					evolved.damage = int(evolved.damage * mod_ratio)
				
				# 继承其他改造效果
				if source_weapon.has("_mod_effects"):
					evolved._mod_effects = source_weapon._mod_effects.duplicate()
			
			# 设置新武器ID
			evolved.weapon_id = target_card_id + "_slot_" + ["light", "armor", "air"][i]
			evolved_slots.append(evolved)
			
		elif source_weapon is WeaponResource and source_weapon.enabled:
			# 目标槽位为空但源卡有武器，继承源武器
			var inherited = source_weapon.clone()
			inherited.weapon_id = target_card_id + "_slot_" + ["light", "armor", "air"][i]
			evolved_slots.append(inherited)
		else:
			# 都为空，添加空槽位
			evolved_slots.append(WeaponResource.create_empty_slot(i))
	
	return evolved_slots

## 获取进化后的武器配置对比（用于UI显示）
## 返回：描述进化前后的武器变化文本
static func get_weapon_evolution_summary(source_slots: Array, target_slots: Array) -> String:
	var summary_parts = []
	
	for i in range(min(3, source_slots.size(), target_slots.size())):
		var slot_names = ["轻装", "装甲", "对空"]
		var source_w = source_slots[i] if i < source_slots.size() else null
		var target_w = target_slots[i] if i < target_slots.size() else null
		
		var source_name = source_w.display_name if source_w is WeaponResource and source_w.enabled else "空槽位"
		var target_name = target_w.display_name if target_w is WeaponResource and target_w.enabled else "空槽位"
		
		if source_name != target_name:
			var source_dmg = int(source_w.damage) if source_w is WeaponResource else 0
			var target_dmg = int(target_w.damage) if target_w is WeaponResource else 0
			summary_parts.append("%s: %s(%d) → %s(%d)" % [slot_names[i], source_name, source_dmg, target_name, target_dmg])
	
	if summary_parts.is_empty():
		return "武器配置无变化"
	else:
		return "武器变化：" + " | ".join(summary_parts)
