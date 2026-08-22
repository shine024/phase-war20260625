class_name CardEvolutionManager
## 进化系统 — 从 BlueprintManager 拆分的子模块
## 所有函数为 static，通过 bpm_ref（BlueprintManager 实例）访问核心数据

const DefaultCards = preload("res://data/default_cards.gd")
const PhaseLaws = preload("res://data/phase_laws.gd")
const UnitLineageConfig = preload("res://data/unit_lineage_config.gd")
const BlueprintDefinitions = preload("res://data/blueprint_definitions.gd")
## v9.x 条件指引：技能树节点名/势力中文名查询（detail 字段用）
const SkillTreeData = preload("res://data/phase_master_skill_tree.gd")
const CompanyDefinitions = preload("res://data/company_definitions.gd")

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

## 拒绝结果构建（结构性错误早退：invalid/card_locked/invalid_target/target_not_in_path/cross_class）
## conditions 恒为数组，UI 可安全遍历
static func _evolve_check_denied(reason: String) -> Dictionary:
	return {
		"ok": false,
		"reason": reason,
		"reason_zh": UnitLineageConfig.localize_evolve_reason(reason),
		"conditions": [],
	}

## v9.x: conditions 快照的 key → 旧拒绝码映射（保持 reason/EVOLVE_REASON_ZH 语义不变）
static func _condition_key_to_reason(key: String) -> String:
	match key:
		"power": return "power_not_enough"
		"evo_blueprint": return "evo_blueprint_missing"
		"skill_tree_era": return "evolution_not_unlocked_in_skill_tree"
		"enhance": return "enhance_not_enough"
		"mods": return "mod_not_enough"
		"enemy_mod": return "enemy_mod_not_enough"
		"faction_level": return "faction_level_not_enough"
		_: return "invalid"

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

	# 2026-08-22：蓝图解锁守卫已随蓝图体系移除（进化本就要求持有实例，所有权即资格）
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

	## v9.x: 玩法条件改为非早退式全量评估——收集进 conditions 数组供 UI 逐条渲染达成/未达成。
	## ok = 全部满足；reason = 首个未满足项（拒绝码语义与旧早退版一致）。
	## 失败路径同样填充 enhance/mod 数字字段（旧版只有成功路径填，未达标时 UI 反而看不到进度）。
	var conditions: Array = []

	## v5.0 Phase 4: 战力达标检查（v9.x 重设：门槛 = 目标白板战斗战力×0.70，与判定左侧同标尺）
	var target_base_power: int = EvolutionHelpers.get_target_power_bar(target_card_id)
	if target_base_power > 0:
		# v7.0: 战力估算传 instance_id（让估算读到实例的养成数据）
		var current_power: float = EvolutionHelpers.estimate_power_score(card_id_or_instance, bpm_ref)
		conditions.append({
			"key": "power",
			"met": current_power >= float(target_base_power),
			"current_text": str(int(current_power)),
			"required_text": str(target_base_power),
		})

	## 进化蓝图检查：持有目标卡进化蓝图即可解锁进化（蓝图不消耗）
	var evo_blueprint_id: String = BlueprintDefinitions.get_evolution_blueprint_id(card_id, target_card_id)
	var iib: Node = _get_autoload_node("IntelItemBag")
	var has_evo_bp: bool = iib != null and not evo_blueprint_id.is_empty() and iib.has_item(evo_blueprint_id)
	conditions.append({
		"key": "evo_blueprint",
		"met": has_evo_bp,
		"current_text": "持有" if has_evo_bp else "缺失",
		"required_text": "持有",
		## v9.x：指明获取渠道（战后掉落规则见 intel_discovery_manager 掉落表）
		"detail": "击败精英/Boss 敌人，战后结算几率掉落进化图纸",
	})

	var stage: String = UnitLineageConfig.get_stage(card_id, target_card_id)

	## v8.x: 进化能力需先在相位师技能树解锁。
	## 技能树指挥系的 evolution 节点按 era 解锁进化能力（era=-1 表示全时代）。
	## （v9：原 concept_weapon 分支已解散，形态进化/护盾投射两节点归位指挥系深层）
	var card_era: int = _get_card_era(card_id, is_instance, card_id_or_instance)
	var pmsm: Node = _get_autoload_node("PhaseMasterSkillManager")
	if pmsm != null and pmsm.has_method("is_evolution_era_unlocked"):
		var era_ok: bool = pmsm.is_evolution_era_unlocked(card_era)
		conditions.append({
			"key": "skill_tree_era",
			"met": era_ok,
			"current_text": "已解锁" if era_ok else "未解锁",
			"required_text": "已解锁",
			## v9.x：点名可解锁该时代进化的技能树节点及分支（与技能面板前置提示同风格，
			## 避免玩家看到"未解锁"却不知去哪点）
			"detail": _skill_tree_era_hint(card_era),
		})
	# 注：若 PhaseMasterSkillManager 不可用（旧环境），跳过该项（向后兼容）

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

	var enh_req: int = UnitLineageConfig.get_enhance_requirement(stage)
	var mod_req: int = UnitLineageConfig.get_mod_requirement(stage)
	conditions.append({
		"key": "enhance",
		"met": enhance_lvl >= enh_req,
		"current_text": str(enhance_lvl),
		"required_text": str(enh_req),
	})
	conditions.append({
		"key": "mods",
		"met": mod_count >= mod_req,
		"current_text": str(mod_count),
		"required_text": str(mod_req),
	})

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
			var faction_lv: int = 0
			if fsm != null and fsm.has_method("get_faction_level"):
				faction_lv = fsm.get_faction_level(target_faction_id)
			## v9.x：点名目标势力中文名（多势力分支并存时玩家需知道提升哪家声望）
			var faction_name: String = String(CompanyDefinitions.get_by_id(target_faction_id).get("name", target_faction_id))
			conditions.append({
				"key": "faction_level",
				"met": faction_lv >= required_faction_lv,
				"current_text": str(faction_lv),
				"required_text": str(required_faction_lv),
				"detail": "提升「%s」声望等级（做该势力委托/击败其占领关卡敌人）" % faction_name,
			})

	## 汇总：首个未满足项决定 reason（评估顺序与旧早退版一致）
	var first_fail_key: String = ""
	for c in conditions:
		if not bool(c.get("met", false)):
			first_fail_key = String(c.get("key", ""))
			break
	var out: Dictionary = {
		"ok": first_fail_key.is_empty(),
		"reason": "ok" if first_fail_key.is_empty() else _condition_key_to_reason(first_fail_key),
		"stage": stage,
		"conditions": conditions,
		"enhance_requirement": enh_req,
		"mod_requirement": mod_req,
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
	bpm_ref.blueprint_inherit_bonus[target_card_id] = merged_bonus
	var old_hp: float = EvolutionHelpers.compute_platform_preview_hp(card_id, 0, bpm_ref)
	if old_hp > 0.0:
		var floor_hp: float = old_hp * 1.10
		var prev_floor: float = float(bpm_ref.blueprint_evolution_hp_floor.get(target_card_id, 0.0))
		bpm_ref.blueprint_evolution_hp_floor[target_card_id] = maxf(prev_floor, floor_hp)

	var source_mods: Array = bpm_ref.blueprint_mods.get(card_id, [])
	bpm_ref.blueprint_mods[target_card_id] = source_mods.duplicate()
	bpm_ref.blueprint_mods[card_id] = []
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

	# 情报分支奖励迁移
	if not source_intel_bonus.is_empty():
		ir.set_intel_branch_bonus(target_inst.instance_id, source_intel_bonus.duplicate(true))

	# 4. 蓝图解锁记账已移除（2026-08-22）
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

## v8.x: 获取卡的 era（用于技能树进化解锁检查）
static func _get_card_era(card_id: String, is_instance: bool, instance_or_id: String) -> int:
	# 优先从实例/模板卡读 era 字段
	if is_instance:
		var ir: Node = _get_autoload_node("InstanceRegistry")
		if ir != null and ir.has_method("get_instance"):
			var inst: CardResource = ir.get_instance(instance_or_id)
			if inst != null:
				return int(inst.era)
	# 回退：从 DefaultCards 模板读
	var DefaultCards = load("res://data/default_cards.gd")
	if DefaultCards != null and DefaultCards.has_method("get_card_by_id"):
		var tpl: CardResource = DefaultCards.get_card_by_id(card_id)
		if tpl != null:
			return int(tpl.era)
	return 0

## v9.x: 技能树进化解锁条件的具体指引——按卡时代列出可解锁该时代进化的技能树节点。
## 数据驱动：扫描技能树 unlocks 含 evolution 且 era 匹配（-1=全时代）的节点，
## 技能树重排/加节点后文案自动跟随，无需手工同步。
static func _skill_tree_era_hint(card_era: int) -> String:
	var node_names: Array = []
	for branch in SkillTreeData.get_all_branches():
		for s in SkillTreeData.get_skills_for_branch(branch):
			for u in s.get("unlocks", []):
				if not (u is Dictionary) or u.get("type", "") != "evolution":
					continue
				var u_era: int = int(u.get("era", -99))
				if u_era == -1 or u_era == card_era:
					node_names.append("「%s」（%s分支·第%d层）" % [
						String(s.get("name", String(s.get("id", "")))),
						SkillTreeData.get_branch_display_name(String(branch)),
						int(s.get("tier", 0))])
	if node_names.is_empty():
		return "需在相位师技能树解锁该时代的进化能力"
	return "在技能树点亮：%s" % " 或 ".join(PackedStringArray(node_names))
