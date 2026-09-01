extends Node
## 进化路径注册表
## 管理所有73个进化节点的查询和验证
## v9.x：兵种识别委托 data/evolution_paths/__init__.gd（112卡前缀测试覆盖）。
## 原 _identify_unit_type/_unit_type_to_key 第二套映射已删——其 2/3（空中↔火炮）对调、
## 5/6/7（侦察/工兵/反空）返回空、火炮/防空前缀缺失默认落步兵，是进化属性预览空白的断裂源。

const EvolutionPathsIndex = preload("res://data/evolution_paths/__init__.gd")

## ─────────────────────────────────────────────
##  查询接口
## ─────────────────────────────────────────────

## 获取卡牌的进化路径
static func get_evolution_path(card_id: String) -> Dictionary:
	return EvolutionPathsIndex.get_evolution_path(card_id)

## 获取可进化到的目标列表
static func get_evolution_targets(card: Dictionary) -> Array:
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

	# v25.3 战力/EOM/情报门槛已删：本函数是遗留数据层（无运行时调用方，权威判定在
	# CardEvolutionManager.can_evolve_blueprint），战力门随"战力→军衔→战力"循环
	# 拆除一并退役；情报门与 EOM（2026-08-21 已退役）同样不再保留。

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

	# 继承旧改造加成（普通改造 + 强化词条都继承，与 card_evolution_manager.evolve_blueprint 的全量复制一致）
	# v6.10: 改用 apply_with_level（支持 level_effects，强化词条加成才能在预览里正确反映）
	# v22: 传宿主 era（可得时）——继承的攻击/HP flat 按时代缩放，预览与战场同口径
	var old_mods = old_card.get("installed_modifications", [])
	var mod_bonus = ModificationRegistry.apply_with_level({}, old_mods, {"era": int(old_card.get("era", -1))})

	# 应用继承比例
	for key in mod_bonus.keys():
		if base_stats.has(key):
			if mod_bonus[key] is int or mod_bonus[key] is float:
				base_stats[key] += int(mod_bonus[key] * inherit_mult)

	return base_stats

## ─────────────────────────────────────────────
##  内部工具
## ─────────────────────────────────────────────

static func _find_target_node(path: Dictionary, target_card_id: String) -> Dictionary:
	# 搜索主线
	var main_line = path.get("main_line", {})
	for stage_key in main_line.keys():
		if main_line[stage_key].get("card_id", "") == target_card_id:
			return main_line[stage_key]

	# 搜索副线（装甲/空中的 secondary_line，v9.x 委托后可用）
	var secondary_line = path.get("secondary_line", {})
	for stage_key in secondary_line.keys():
		if secondary_line[stage_key].get("card_id", "") == target_card_id:
			return secondary_line[stage_key]

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

## ─── 武器槽位系统支持 ───

## 进化时继承/替换武器槽位
## source_card: CardResource - 源卡牌
## target_card_id: String - 目标卡牌ID
## preserve_mods: bool - 是否保留改造加成（默认true）
## 返回：进化后的武器槽位数组
static func evolve_weapon_slots(source_card: CardResource, target_card_id: String, preserve_mods: bool = true) -> Array:
	
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
				
				# 检查源武器是否有改造效果（_mod_effects 已在 WeaponResource 声明，检查是否非空）
				if not source_weapon._mod_effects.is_empty():
					var mod_effects = source_weapon._mod_effects
					var damage_mult = mod_effects.get("slot_damage_mult", 1.0)
					var damage_add = mod_effects.get("slot_damage_add", 0.0)
					mod_ratio = damage_mult + (damage_add / max(1.0, base_damage))

				# 应用改造加成到新武器
				if mod_ratio != 1.0:
					evolved.damage = int(evolved.damage * mod_ratio)

				# 继承其他改造效果
				if not source_weapon._mod_effects.is_empty():
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
