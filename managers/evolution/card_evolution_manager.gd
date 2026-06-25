class_name CardEvolutionManager
## 进化系统 — 从 BlueprintManager 拆分的子模块
## 所有函数为 static，通过 bpm_ref（BlueprintManager 实例）访问核心数据

const DefaultCards = preload("res://data/default_cards.gd")
const PhaseLaws = preload("res://data/phase_laws.gd")
const UnitLineageConfig = preload("res://data/unit_lineage_config.gd")
const BlueprintDefinitions = preload("res://data/blueprint_definitions.gd")

## 通过 Autoload 名称获取节点
static func _get_autoload_node(autoload_name: String) -> Node:
	var tree = Engine.get_main_loop()
	if tree and tree.root:
		return tree.root.get_node_or_null(autoload_name)
	return null

## 获取进化选项
static func get_evolution_options(card_id: String) -> Dictionary:
	if card_id.is_empty():
		return {}
	var evo_1: String = UnitLineageConfig.get_evolution_1_target(card_id)
	var branches: Dictionary = UnitLineageConfig.get_all_faction_targets(card_id)

	## v6.0: 查询情报进化分支
	var intel_branches: Array = []
	var iem: Node = _get_autoload_node("IntelEvolutionManager")
	if iem != null and iem.has_method("get_evolution_options_for_card"):
		var bpm: Node = _get_autoload_node("BlueprintManager")
		intel_branches = iem.get_evolution_options_for_card(card_id, bpm)

	return {
		"base_card_id": card_id,
		"evolution_1": evo_1,
		"faction_branches": branches,
		"intel_branches": intel_branches,  ## v6.0: 情报进化分支
	}

## 获取卡片情报进度
static func get_card_intel_progress(card_id: String) -> float:
	var tree = Engine.get_main_loop()
	if tree and tree.root:
		var im = tree.root.get_node_or_null("IntelManual")
		if im and im.has_method("get_intel_progress"):
			return im.get_intel_progress(card_id)
	return 0.0

## 拒绝结果构建
static func _evolve_check_denied(reason: String) -> Dictionary:
	return {
		"ok": false,
		"reason": reason,
		"reason_zh": UnitLineageConfig.localize_evolve_reason(reason),
	}

## v7.0: 从参数中解析出 card_id（支持 instance_id 和裸 card_id）
## "cold_t72#1" → "cold_t72"，"cold_t72" → "cold_t72"
static func _resolve_card_id(id_str: String) -> String:
	if id_str.is_empty():
		return ""
	var ir: Node = _get_autoload_node("InstanceRegistry")
	if ir != null and ir.has_method("get_card_id_of"):
		var base: String = ir.get_card_id_of(id_str)
		if not base.is_empty():
			return base
	return id_str

## v7.0: 获取实例的 ID（优先 instance_id，回退 card_id）
## 用于区分传进来的是实例 id 还是裸 card_id
static func _is_instance_id(id_str: String) -> bool:
	return id_str.contains("#")

## v7.0: 获取源卡的增强等级——优先实例对象，回退 CardEnhancementManager
static func _get_source_enhance_level(card_id_or_instance: String) -> int:
	var ir: Node = _get_autoload_node("InstanceRegistry")
	if ir != null and ir.has_method("get_instance"):
		var inst: CardResource = ir.get_instance(card_id_or_instance)
		if inst != null:
			return maxi(inst.enhance_level, 0)
	# 回退：按 card_id 查模板
	var tree = Engine.get_main_loop()
	if tree and tree.root:
		var cem: Node = tree.root.get_node_or_null("CardEnhancementManager")
		if cem != null and cem.has_method("get_card_enhancement_level"):
			return maxi(cem.get_card_enhancement_level(card_id_or_instance), 0)
	return 0

## 进化条件检查
## v7.0: card_id 参数支持 instance_id（实例化养成身份）
static func can_evolve_blueprint(card_id_or_instance: String, target_card_id: String, bpm_ref: Node) -> Dictionary:
	if card_id_or_instance.is_empty() or target_card_id.is_empty():
		return _evolve_check_denied("invalid")
	# v7.0: 支持 instance_id，解析出 card_id 用于模板查表
	var card_id: String = _resolve_card_id(card_id_or_instance)
	var is_instance: bool = _is_instance_id(card_id_or_instance)

	if not bpm_ref.is_blueprint_unlocked(card_id):
		return _evolve_check_denied("card_locked")
	if DefaultCards.get_card_by_id(target_card_id) == null and PhaseLaws.get_by_id(target_card_id).is_empty():
		return _evolve_check_denied("invalid_target")
	var opts: Dictionary = get_evolution_options(card_id)
	var evo_1: String = String(opts.get("evolution_1", ""))
	var branches: Dictionary = opts.get("faction_branches", {})
	var intel_branches: Array = opts.get("intel_branches", [])  ## v6.0
	var valid_target: bool = (target_card_id == evo_1)
	if not valid_target:
		for k in branches.keys():
			if String(branches[k]) == target_card_id:
				valid_target = true
				break
	## v6.0: 检查情报进化分支目标
	if not valid_target:
		for ib in intel_branches:
			if ib is Dictionary and String(ib.get("target_card_id", "")) == target_card_id:
				valid_target = true
				break
	if not valid_target:
		return _evolve_check_denied("target_not_in_path")

	## v5.0 Phase 4: 不跨类型检查（combat_kind 一致）
	## v6.0: 情报进化分支可能允许跨类型（cross_class标记）
	var _is_intel_branch: bool = false
	var _intel_branch_data: Dictionary = {}
	for ib in intel_branches:
		if ib is Dictionary and String(ib.get("target_card_id", "")) == target_card_id:
			_is_intel_branch = true
			_intel_branch_data = ib
			break
	var from_card: CardResource = DefaultCards.get_card_by_id(card_id)
	var to_card: CardResource = DefaultCards.get_card_by_id(target_card_id)
	if from_card != null and to_card != null:
		if from_card.combat_kind >= 0 and to_card.combat_kind >= 0:
			if from_card.combat_kind != to_card.combat_kind:
				## v6.0: 跨类型检查——情报分支如果标记cross_class则允许
				if not (_is_intel_branch and _intel_branch_data.get("unique_bonus", {}).get("cross_class", false)):
					return _evolve_check_denied("cross_class")

	## v5.0 Phase 4: 战力达标检查（培养后战力 >= 目标基础战力）
	var target_base_power: int = UnitLineageConfig.get_target_base_power(target_card_id)
	if target_base_power > 0:
		# v7.0: 战力估算传 instance_id（让估算读到实例的养成数据）
		var current_power: float = EvolutionHelpers.estimate_power_score(card_id_or_instance, bpm_ref)
		if current_power < float(target_base_power):
			return _evolve_check_denied("power_not_enough")

	## 进化蓝图检查：持有目标卡进化蓝图即可解锁进化（蓝图不消耗）
	var evo_blueprint_id: String = BlueprintDefinitions.get_evolution_blueprint_id(card_id, target_card_id)
	var iib: Node = _get_autoload_node("IntelItemBag")
	if iib == null or not iib.has_item(evo_blueprint_id):
		return _evolve_check_denied("evo_blueprint_missing")

	var stage: String = UnitLineageConfig.get_stage(card_id, target_card_id)

	## v6.0: 新门槛 — 强化等级 + MOD数量 + 敌源MOD
	# v7.0: 优先从实例对象读 enhance_level 和 mods；实例不存在回退 blueprint_mods 字典
	var enhance_lvl: int = 0
	var mod_count: int = 0
	if is_instance:
		var ir: Node = _get_autoload_node("InstanceRegistry")
		if ir != null and ir.has_method("get_instance"):
			var inst: CardResource = ir.get_instance(card_id_or_instance)
			if inst != null:
				enhance_lvl = maxi(inst.enhance_level, 0)
				mod_count = inst.mods.size()
	else:
		enhance_lvl = _get_card_enhance_level(card_id, bpm_ref)
		mod_count = ModManager.get_modification_count(card_id, bpm_ref.blueprint_mods)
	
	if enhance_lvl < UnitLineageConfig.get_enhance_requirement(stage):
		return _evolve_check_denied("enhance_not_enough")
	if mod_count < UnitLineageConfig.get_mod_requirement(stage):
		return _evolve_check_denied("mod_not_enough")
	if UnitLineageConfig.get_enemy_mod_required(stage):
		if not ModManager.has_enemy_origin_mod(card_id, bpm_ref.blueprint_mods):
			return _evolve_check_denied("enemy_mod_not_enough")

	## 势力贡献度检查：E2（势力分支）需要目标势力达到指定等级
	var required_faction_lv: int = UnitLineageConfig.get_faction_level_required(stage)
	if required_faction_lv > 0:
		var target_faction_id: String = ""
		var all_branches: Dictionary = UnitLineageConfig.get_all_faction_targets(card_id)
		for f_id in all_branches.keys():
			if String(all_branches[f_id]) == target_card_id:
				target_faction_id = String(f_id)
				break
		if target_faction_id.is_empty():
			push_warning("[CardEvolutionManager] E2进化目标 %s 不在 %s 的势力分支中，跳过势力等级检查" % [target_card_id, card_id])
		else:
			var fsm: Node = _get_autoload_node("FactionSystemManager")
			if fsm == null or not fsm.has_method("get_faction_level") or fsm.get_faction_level(target_faction_id) < required_faction_lv:
				return _evolve_check_denied("faction_level_not_enough")
	var out: Dictionary = {
		"ok": true,
		"reason": "ok",
		"stage": stage,
		"enhance_requirement": UnitLineageConfig.get_enhance_requirement(stage),
		"mod_requirement": UnitLineageConfig.get_mod_requirement(stage),
		"current_enhance": enhance_lvl,
		"current_mod_count": mod_count,
	}
	out["inherit_ratio"] = UnitLineageConfig.get_inherit_ratio(card_id, target_card_id)
	out["reason_zh"] = UnitLineageConfig.localize_evolve_reason(String(out.get("reason", "invalid")))
	## v6.6: 情报进化分支奖励 — 覆盖 inherit_ratio，附加 extra_mod_slot / special_ability
	if _is_intel_branch and not _intel_branch_data.is_empty():
		var bonus: Dictionary = _intel_branch_data.get("unique_bonus", {})
		if bonus.has("inherit_ratio"):
			out["inherit_ratio"] = float(bonus["inherit_ratio"])
		if bonus.get("extra_mod_slot", false):
			out["extra_mod_slot"] = true
		var ability: String = String(bonus.get("special_ability", ""))
		if not ability.is_empty():
			out["special_ability"] = ability
		out["intel_branch_id"] = String(_intel_branch_data.get("_branch_id", ""))
	return out

## 进化执行
## v7.0: card_id_or_instance 支持 instance_id（实例化养成身份）
## 实例化语义：源实例 dispose → 创建目标新实例 → 养成迁移到目标实例
## 非实例（旧路径）：按 card_id 索引 blueprint_* 字典（保持兼容）
static func evolve_blueprint(card_id_or_instance: String, target_card_id: String, bpm_ref: Node) -> bool:
	var can_info: Dictionary = can_evolve_blueprint(card_id_or_instance, target_card_id, bpm_ref)
	if not bool(can_info.get("ok", false)):
		return false

	var card_id: String = _resolve_card_id(card_id_or_instance)
	var is_instance: bool = _is_instance_id(card_id_or_instance)

	# v7.0: 实例化路径——源实例 dispose + 目标实例创建 + 养成迁移
	var ir: Node = _get_autoload_node("InstanceRegistry")
	if is_instance and ir != null:
		return _evolve_instance(card_id_or_instance, target_card_id, card_id, can_info, bpm_ref, ir)

	# ── 旧路径兼容（按 card_id 操作 blueprint_* 字典）──
	var inherit_ratio: float = float(can_info.get("inherit_ratio", 0.30))
	var old_bonus: float = float(bpm_ref.blueprint_inherit_bonus.get(card_id, 0.0))
	var merged_bonus: float = clampf(old_bonus + inherit_ratio, 0.0, 0.9)
	if not bpm_ref.is_blueprint_unlocked(target_card_id):
		bpm_ref.unlock_blueprint(target_card_id)
	bpm_ref.blueprint_copies[target_card_id] = max(1, int(bpm_ref.blueprint_copies.get(target_card_id, 0)))
	bpm_ref.blueprint_inherit_bonus[target_card_id] = merged_bonus
	var old_hp: float = EvolutionHelpers.compute_platform_preview_hp(card_id, 0, bpm_ref)
	if old_hp > 0.0:
		var floor_hp: float = old_hp * 1.10
		var prev_floor: float = float(bpm_ref.blueprint_evolution_hp_floor.get(target_card_id, 0.0))
		bpm_ref.blueprint_evolution_hp_floor[target_card_id] = maxf(prev_floor, floor_hp)

	var source_mods: Array = bpm_ref.blueprint_mods.get(card_id, [])
	bpm_ref.blueprint_mods[target_card_id] = source_mods.duplicate()
	bpm_ref.blueprint_mods[card_id] = []
	bpm_ref.blueprint_copies[card_id] = 0
	var cem: Node = _get_autoload_node("CardEnhancementManager")
	if cem and cem.has_method("clear_card_enhancement"):
		cem.clear_card_enhancement(card_id)

	_apply_intel_branch_bonus(card_id, target_card_id, can_info, bpm_ref)

	bpm_ref.emit_signal("fragments_changed")
	return true


## v7.0: 实例化进化——源实例 dispose + 目标实例创建 + 养成迁移
static func _evolve_instance(source_instance_id: String, target_card_id: String, source_card_id: String, can_info: Dictionary, bpm_ref: Node, ir: Node) -> bool:
	if ir == null:
		return false

	# 1. 读取源实例的养成数据
	var source_inst: CardResource = ir.get_instance(source_instance_id)
	if source_inst == null:
		return false

	var source_mods: Array = source_inst.mods.duplicate(true)
	var source_enhance_lvl: int = source_inst.enhance_level
	var source_module_slots: Array = source_inst.module_slots.duplicate(true)
	var source_eom: String = ir.get_enemy_origin_mod(source_instance_id)
	var source_intel_bonus: Dictionary = ir.get_intel_branch_bonus(source_instance_id)

	var inherit_ratio: float = float(can_info.get("inherit_ratio", 0.30))
	var old_bonus: float = ir.get_inherit_bonus(source_instance_id)
	var merged_bonus: float = clampf(old_bonus + inherit_ratio, 0.0, 0.9)
	var old_hp: float = EvolutionHelpers.compute_platform_preview_hp(source_card_id, 0, bpm_ref)
	var floor_hp: float = 0.0
	if old_hp > 0.0:
		floor_hp = old_hp * 1.10

	# 2. 创建目标实例
	var target_inst: CardResource = ir.create_instance(target_card_id)
	if target_inst == null:
		return false

	# 3. 迁移养成数据到目标实例
	target_inst.enhance_level = source_enhance_lvl        # 强化等级继承
	target_inst.mods = source_mods                         # 改造完全继承
	target_inst.module_slots = source_module_slots          # 词条槽继承

	ir.set_inherit_bonus(target_inst.instance_id, merged_bonus)
	if floor_hp > 0.0:
		var prev_floor: float = ir.get_evolution_hp_floor(target_inst.instance_id)
		ir.set_evolution_hp_floor(target_inst.instance_id, maxf(prev_floor, floor_hp))

	# 敌源MOD + 情报分支奖励迁移
	if not source_eom.is_empty():
		ir.set_enemy_origin_mod(target_inst.instance_id, source_eom)
	if not source_intel_bonus.is_empty():
		ir.set_intel_branch_bonus(target_inst.instance_id, source_intel_bonus.duplicate(true))

	# 4. 解锁目标卡蓝图（如果尚未解锁）
	if not bpm_ref.is_blueprint_unlocked(target_card_id):
		bpm_ref.unlock_blueprint(target_card_id)

	# 5. dispose 源实例
	ir.dispose_instance(source_instance_id)

	# 6. 情报分支奖励应用
	_apply_intel_branch_bonus(source_card_id, target_card_id, can_info, bpm_ref)

	bpm_ref.emit_signal("fragments_changed")
	return true


## v6.6/v7.0: 应用情报进化分支奖励（提取自原 evolve_blueprint）
static func _apply_intel_branch_bonus(card_id: String, target_card_id: String, can_info: Dictionary, bpm_ref: Node) -> void:
	var intel_branch_id: String = String(can_info.get("intel_branch_id", ""))
	if not intel_branch_id.is_empty():
		var iem: Node = _get_autoload_node("IntelEvolutionManager")
		if iem and iem.has_method("claim_branch"):
			iem.claim_branch(card_id, intel_branch_id)
		if can_info.get("extra_mod_slot", false):
			if not bpm_ref.blueprint_intel_branch_bonus.has(target_card_id):
				bpm_ref.blueprint_intel_branch_bonus[target_card_id] = {}
			bpm_ref.blueprint_intel_branch_bonus[target_card_id]["extra_mod_slot"] = true
		var ability: String = String(can_info.get("special_ability", ""))
		if not ability.is_empty():
			if not bpm_ref.blueprint_intel_branch_bonus.has(target_card_id):
				bpm_ref.blueprint_intel_branch_bonus[target_card_id] = {}
			bpm_ref.blueprint_intel_branch_bonus[target_card_id]["special_ability"] = ability

## 获取卡片强化等级（通过 CardEnhancementManager Autoload）
static func _get_card_enhance_level(card_id: String, bpm_ref: Node) -> int:
	var tree = Engine.get_main_loop()
	if tree and tree.root:
		var cem: Node = tree.root.get_node_or_null("CardEnhancementManager")
		if cem != null and cem.has_method("get_card_enhancement_level"):
			return cem.get_card_enhancement_level(card_id)
	return 1
