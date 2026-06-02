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

	# 注册步兵进化路径
	_register_path("infantry", InfantryEvolution.get_main_line(), InfantryEvolution.get_hidden_branches())

	# TODO: 其他兵种
	# _register_path("armor", ArmorEvolution.get_main_line(), ArmorEvolution.get_hidden_branches())
	# ...

	_initialized = true
	print("[EvolutionPathRegistry] Registered evolution paths")

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
	var current_power = MilitaryTitleRegistry.calculate_current_power(card)
	var target_power = target_node.get("power", 0)
	var min_power = int(target_power * power_ratio)
	if current_power < min_power:
		result.passed = false
		result.missing.append("战力不足，需要%d（当前%d）" % [min_power, current_power])

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
	# 简化：根据ID前缀识别
	if card_id.begins_with("ww1_mp18") or card_id.begins_with("ww2_thompson"):
		return 0  # LIGHT (步兵)
	# TODO: 其他兵种识别
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
	# TODO: 实现EOM识别
	return 0
