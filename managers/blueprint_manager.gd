extends Node
## BlueprintManager — 卡牌账号数据代管器
## 当前职责：账号级养成数据代管（改造/继承/HP下限/军衔缓存/情报分支/武器槽）、
## 纳米/研究点资源代管、法则蓝图 ID 助手。蓝图解锁/副本/制造/星级已移除（2026-08-22）。
## @todo 待重命名为 CardDataManager（ADR-001），因引用范围广暂保留原名

## 信号名保留 fragments_changed 以兼容外部（30+ 引用）
## 实际含义已变为「蓝图数据变更」（副本/星级/研究点/改装等）
signal fragments_changed

var DEBUG_BLUEPRINT_LOG := false

## 蓝图管理器（研究点升星系统）
## - 记录已解锁蓝图
## - 记录蓝图副本数（card_id → 副本数，≥1 即可制造）
## - 研究点手动升星（1~9★）
## - 法则蓝图统一在此管理（law:xxx 前缀）

const GC = preload("res://resources/game_constants.gd")
const BasicResources = preload("res://data/basic_resources.gd")
const DefaultCards = preload("res://data/default_cards.gd")
const EnemyPhaseEquipment = preload("res://data/enemy_phase_equipment.gd")
const PhaseLaws = preload("res://data/phase_laws.gd")
const UnitLineageConfig = preload("res://data/unit_lineage_config.gd")
const RankRules = preload("res://data/rank_rules.gd")
const UnitStatsTable = preload("res://resources/unit_stats_table.gd")
const IntelManualItems = preload("res://data/intel_manual_items.gd")
const BlueprintDefinitions = preload("res://data/blueprint_definitions.gd")

## ── 进化/改装子模块（class_name 全局引用） ──
## @note Godot 4.5 --check-only 模式下部分 class_name 加载顺序不确定，preload 保证可用
const ModManager = preload("res://managers/evolution/mod_manager.gd")
const CardEvolutionManager = preload("res://managers/evolution/card_evolution_manager.gd")
const EvolutionHelpers = preload("res://managers/evolution/evolution_helpers.gd")
const PowerTiers = preload("res://data/power_tiers.gd")

const MAX_BLUEPRINT_LEVEL: int = 9
const LAW_BLUEPRINT_PREFIX: String = "law:"

## XP 类型常量（兼容旧升级系统）
const XP_TYPE_DEFAULT: int = -1
const XP_TYPE_PLATFORM: int = 0

const EXCLUDED_WAR_PLATFORM_TYPES: Array = ["striker", "sniper", "stealth", "mage"]

# v9.x（P2-7范围B）：PhaseLawManager 安全引用缓存已随法则系统退役移除

## v7.x: 能量卡系统移除，能量蓝图列表清空（保留常量名避免多处引用报错，遍历天然跳过）

## ─────────── 核心数据 ───────────


## card_id -> 副本数量（≥1 表示可制造）

## {card_id: 变动前的副本数}。结算面板的"卡牌副本 +N"据此增量计算，免去全量遍历 ~133 蓝图。

## blueprint_stars 已在 v5 迁移中彻底废弃，不再保留字段

## card_id -> 已选改装分支（最多9项，同 conflict_group 冲突自动替换）
var blueprint_mods: Dictionary = {}

## card_id -> 进化继承属性倍率（累计），如 0.30 表示 +30%
var blueprint_inherit_bonus: Dictionary = {}

## card_id -> 进化后 era0 有效 HP 下限（含养成乘区；v6.8 起战斗不再按时代缩放，下限直接用此值）
var blueprint_evolution_hp_floor: Dictionary = {}

## card_id -> 最近一次军衔缓存 {rank_id, rank_name, power_score}
var blueprint_rank_cache: Dictionary = {}
## card_id -> 敌源MOD ID
## v6.6: card_id -> 情报进化分支奖励 {extra_mod_slot: bool, special_ability: str}
var blueprint_intel_branch_bonus: Dictionary = {}
## card_id -> 自定义武器槽位配置（用于进化/改造后的武器）
var blueprint_weapon_slots: Dictionary = {}

## v6.11: card_battle_stars 字段已移除（战力星级系统②已合并到强化等级①）

## 纳米材料已迁移到 BasicResourceManager（autoload）

var _suppress_auto_save: bool = false
var _auto_save_deferred_scheduled: bool = false
var _auto_save_pending_reason: String = ""

## 旧存档是否已做过「默认能量蓝图首份副本」迁移

## 战斗中解锁仅写入数据；battle_ended 前由 BattleManager 调用 flush 再发信号（音效/结算列表）



## ─────────── 内部辅助 ───────────

func _is_excluded_war_platform_id(card_id: String) -> bool:
	if card_id.is_empty():
		return false
	var pdata: Dictionary = EnemyPhaseEquipment.get_war_platform(card_id)
	if pdata.is_empty():
		return false
	var ptype: String = String(pdata.get("type", ""))
	return EXCLUDED_WAR_PLATFORM_TYPES.has(ptype)

func _get_basic_resource_manager() -> Node:
	return BasicResourceManager

func _get_card_type(card_id: String) -> int:
	var card: CardResource = DefaultCards.get_card_by_id(card_id)
	if card == null:
		return GC.CardType.COMBAT_UNIT
	return card.card_type

## ─────────── 蓝图ID规范化 ───────────

func is_law_blueprint_id(card_id: String) -> bool:
	return not card_id.is_empty() and card_id.begins_with(LAW_BLUEPRINT_PREFIX)

func law_blueprint_id(law_id: String) -> String:
	return LAW_BLUEPRINT_PREFIX + law_id

func law_id_from_blueprint_id(card_id: String) -> String:
	if not is_law_blueprint_id(card_id):
		return ""
	return card_id.substr(LAW_BLUEPRINT_PREFIX.length())

func _normalize_blueprint_id(card_id: String) -> String:
	var sid: String = String(card_id).strip_edges()
	if sid.is_empty():
		return ""
	if is_law_blueprint_id(sid):
		return sid
	if not PhaseLaws.get_by_id(sid).is_empty():
		return law_blueprint_id(sid)
	return sid

## 供掉落/发卡逻辑使用的规范化存储键
func normalize_storage_id(card_id: String) -> String:
	return _normalize_blueprint_id(card_id)

## 平台类敌人掉落等：跳过不应作为奖励的作战平台 id
func should_skip_drop_grant(card_id: String) -> bool:
	return _is_excluded_war_platform_id(_normalize_blueprint_id(card_id))

## ─────────── 初始化 ───────────

func _ready() -> void:
	_sync_debug_log_flag()
	# v9.x（P2-7范围B）：新档默认法则解锁已随法则系统退役移除

func _sync_debug_log_flag() -> void:
	var debug_mgr: Node = get_node_or_null("/root/DebugLogManager")
	if debug_mgr != null and debug_mgr.has_method("is_channel_enabled"):
		DEBUG_BLUEPRINT_LOG = bool(debug_mgr.is_channel_enabled("blueprint_manager", DEBUG_BLUEPRINT_LOG))

# v9.x（P2-7范围B）：_ensure_default_laws_unlocked 已随法则系统退役移除（另两处 load_state/
# reset_to_defaults 内的调用点同步删除）

## ─────────── 蓝图等级系统（研究点升星，影响进化门槛） ───────────
## 星级是蓝图的整体成长度，影响进化资格检查（E1≥4★，E2≥7★）
## 注意：与 enhance_level（强化等级，0-10）是不同概念

## 获取蓝图当前星级
# ── v6.11: 战力星级系统②已移除（合并到强化等级①），get_battle_star/get_battle_star_power/
#           add_battle_star_power/sync_battle_stars_to_cards 已删 ──

# v9.x（P2-7范围B）：get_law_blueprint_level（恒 1，唯一调用方 phase_law_manager 已删）随之移除

## 获取所有有副本的蓝图ID列表

## ─────────── 默认强化列表 ───────────

## v6.11: 以下星级强化函数已移除（废弃的星级系统，强化改走 enhance_level + module_slots）：
##   - get_default_enhancements（基于已移除的 StarConfig 星级池）
##   - get_star_enhancement_lines（基于已移除的星级系统，无外部调用）
##   - _format_enhancement_value（仅被上述两函数内部调用）

## ─────────── 资源管理（纳米材料 / 研究点） ───────────

func get_nano_materials() -> int:
	var brm: Node = _get_basic_resource_manager()
	if brm != null and brm.has_method("get_total"):
		return int(brm.get_total(BasicResources.ID_NANO_MATERIALS))
	return 0

func add_nano_materials(amount: int) -> void:
	if amount == 0:
		return
	var brm: Node = _get_basic_resource_manager()
	if brm != null and brm.has_method("add_basic_resource"):
		brm.add_basic_resource(BasicResources.ID_NANO_MATERIALS, amount)
	emit_signal("fragments_changed")

# v9.x（P2-7范围C）：get_research_points/add_research_points 已随科研点退役移除

## ─────────── 势力专属卡 ───────────

## 获取蓝图的势力分支（供合成/卡背使用）
## 势力变体卡的 card_id 格式为 faction:{faction_id}:{base_card_id}
func get_blueprint_faction_branch(card_id: String) -> String:
	if card_id.begins_with("faction:"):
		var parts: PackedStringArray = card_id.split(":")
		if parts.size() >= 2:
			return parts[1]
	return ""

## ─────────── 卡牌改装（Phase 3.3 重构：MOD_XX 列表 + 冲突替换） ───────────
## Facade 委托 → ModManager（managers/evolution/mod_manager.gd）

## 获取卡牌基础战力（不含改造加成），用于改造消耗公式
func get_base_power_for_mod_cost(card_id: String) -> float:
	return ModManager.get_base_power_for_mod_cost(card_id, self)

## 获取改造槽位消耗（新系统：按槽位次数递增）
func get_mod_slot_cost(slot_index: int) -> int:
	## 槽位消耗：第1槽50，第2槽100，...第9槽450
	var base_cost = 50
	return base_cost * slot_index

## 获取当前已装改造数量
func get_modification_count(card_id: String) -> int:
	return ModManager.get_modification_count(card_id, blueprint_mods)

## 获取最大改造次数
func get_max_mod_slots() -> int:
	return ModManager.get_max_mod_slots()

# v6.6: 以下旧改造系统方法已移除（死代码，无活跃调用方）：
#   - get_modification_requirements（仅被 card_enhancement_panel 的 _format_mod_requirements 调用，后者已删除）
#   - get_mod_options（返回 ModEffects 的 MOD_01~20，与新 140+ 模块系统不兼容）
#   - can_apply_modification（基于 ModEffects 的资源校验，新系统用 install_modification + card.can_install_modification）
#   - apply_modification（option_id "offense/defense/utility" 在 ModEffects 查不到，永远失败）
# 改造安装统一走 install_modification(card, mod_id)（modification_panel 使用）。

## ─────────── 进化系统 ───────────
## Facade 委托 → CardEvolutionManager（managers/evolution/card_evolution_manager.gd）

func get_evolution_options(card_id: String) -> Dictionary:
	return CardEvolutionManager.get_evolution_options(card_id)

func can_evolve_blueprint(card_id: String, target_card_id: String) -> Dictionary:
	return CardEvolutionManager.can_evolve_blueprint(card_id, target_card_id, self)

func evolve_blueprint(card_id: String, target_card_id: String) -> bool:
	var ok: bool = CardEvolutionManager.evolve_blueprint(card_id, target_card_id, self)
	if ok:
		# v7.x: 进化改变第 2 层加成（进化 HP 下限 + 新卡基础值），刷新玩家相位师战力缓存避免面板陈旧
		_refresh_player_master_eval_safe()
	return ok

## ─────────── 军衔系统 ───────────
## Facade 委托 → EvolutionHelpers（managers/evolution/evolution_helpers.gd）

func get_rank_info(card_id: String) -> Dictionary:
	return EvolutionHelpers.get_rank_info(card_id, self)

## 战力估算（委托 → EvolutionHelpers）
func _estimate_power_score(card_id: String) -> float:
	return EvolutionHelpers.estimate_power_score(card_id, self)

func _estimate_power_score_meta_only(card_id: String) -> float:
	return EvolutionHelpers.estimate_power_score_meta_only(card_id, self)

func _preview_battle_era_internal() -> int:
	return EvolutionHelpers._preview_battle_era()

func _build_unit_stats_for_power_preview(card: CardResource) -> UnitStats:
	return EvolutionHelpers.build_unit_stats_for_power_preview(card, self)

func _combat_power_from_unit_stats(stats: UnitStats) -> float:
	return EvolutionHelpers.combat_power_from_unit_stats(stats)


## ─────────── 稀有度 ──
## Facade 委托 → EvolutionHelpers（统一入口见 RarityHelpers）

func get_card_base_rarity(card_id: String) -> String:
	return EvolutionHelpers.get_card_base_rarity(card_id)

func get_card_rarity(card_id: String) -> String:
	return EvolutionHelpers.get_card_rarity(card_id)

func get_rarity_multiplier(card_id: String) -> float:
	return EvolutionHelpers.get_rarity_multiplier(card_id)

func get_effective_power_multiplier(card_id: String) -> float:
	return EvolutionHelpers.get_effective_power_multiplier(card_id, self)

func _sync_single_weapon_damage_from_attack(stats: UnitStats) -> void:
	EvolutionHelpers._sync_single_weapon_damage_from_attack(stats)


func _multiply_attack_damage_and_weapon_slots(stats: UnitStats, factor: float) -> void:
	EvolutionHelpers._multiply_attack_damage_and_weapon_slots(stats, factor)


func apply_growth_to_stats(stats: UnitStats, platform_card: CardResource, weapon_cards: Array, apply_rank_bonus: bool = true) -> void:
	## 统一入口见 AttributeGrowth（scripts/systems/attribute_growth.gd）
	EvolutionHelpers.apply_growth_to_stats(stats, platform_card, weapon_cards, self, apply_rank_bonus)


func _compute_platform_preview_hp(card_id: String, era: int) -> float:
	return EvolutionHelpers.compute_platform_preview_hp(card_id, era, self)


func _apply_platform_enhance_growth_bias(stats: UnitStats, platform_card_id: String) -> void:
	EvolutionHelpers._apply_platform_enhance_growth_bias(stats, platform_card_id, self)


func _apply_evolution_hp_floor(stats: UnitStats, platform_card: CardResource, era: int) -> void:
	EvolutionHelpers._apply_evolution_hp_floor(stats, platform_card, era, self)

## ─────────── 存档 ───────────

func save_state() -> Dictionary:
	var mods_dict: Dictionary = {}
	for k in blueprint_mods:
		mods_dict[k] = (blueprint_mods[k] as Array).duplicate()
	var inherit_dict: Dictionary = {}
	for k in blueprint_inherit_bonus:
		inherit_dict[k] = float(blueprint_inherit_bonus[k])
	var hp_floor_dict: Dictionary = {}
	for k in blueprint_evolution_hp_floor:
		hp_floor_dict[k] = float(blueprint_evolution_hp_floor[k])
	var rank_dict: Dictionary = {}
	for k in blueprint_rank_cache:
		rank_dict[k] = (blueprint_rank_cache[k] as Dictionary).duplicate(true)
	var intel_bonus_dict: Dictionary = {}
	for k3 in blueprint_intel_branch_bonus:
		intel_bonus_dict[k3] = (blueprint_intel_branch_bonus[k3] as Dictionary).duplicate(true)
	var weapon_slots_dict: Dictionary = {}
	for k2 in blueprint_weapon_slots:
			var slots_array = []
			for w in blueprint_weapon_slots[k2]:
				if w is WeaponResource:
					# 只保存必要数据
					slots_array.append({
						"weapon_id": w.weapon_id,
						"slot_type": w.slot_type,
						"display_name": w.display_name,
						"enabled": w.enabled,
						"damage": w.damage,
						"attack_speed": w.attack_speed,
						"windup": w.windup,
						"active": w.active,
						"weapon_type": w.weapon_type,
						"range_value": w.range_value,
						"projectile_scene": w.projectile_scene,
						"hit_effect_scene": w.hit_effect_scene,
						"sound_id": w.sound_id,
					})
			weapon_slots_dict[k2] = slots_array

	# v6.11: 战力星级数据 card_battle_stars 已移除（不再存档）

	return {
		"blueprint_mods": mods_dict,
		"blueprint_inherit_bonus": inherit_dict,
		"blueprint_evolution_hp_floor": hp_floor_dict,
		"blueprint_rank_cache": rank_dict,
		"blueprint_intel_branch_bonus": intel_bonus_dict,
		"blueprint_weapon_slots": weapon_slots_dict,
	}

func load_state(data: Dictionary) -> void:
	emit_signal("fragments_changed")
	# 旧档的 unlocked/blueprint_copies/legacy_default_energy_copies_migrated 键随蓝图体系移除而忽略
	# v9.x（P2-7范围B）：默认法则解锁调用已随法则系统退役移除
	if data.has("blueprint_mods") and data["blueprint_mods"] is Dictionary:
		blueprint_mods.clear()
		for k in data["blueprint_mods"]:
			var cid_m: String = String(k)
			if data["blueprint_mods"][k] is Array:
				blueprint_mods[cid_m] = (data["blueprint_mods"][k] as Array).duplicate()
	if data.has("blueprint_inherit_bonus") and data["blueprint_inherit_bonus"] is Dictionary:
		blueprint_inherit_bonus.clear()
		for k in data["blueprint_inherit_bonus"]:
			blueprint_inherit_bonus[String(k)] = float(data["blueprint_inherit_bonus"][k])
	if data.has("blueprint_evolution_hp_floor") and data["blueprint_evolution_hp_floor"] is Dictionary:
		blueprint_evolution_hp_floor.clear()
		for k in data["blueprint_evolution_hp_floor"]:
			blueprint_evolution_hp_floor[String(k)] = float(data["blueprint_evolution_hp_floor"][k])
	if data.has("blueprint_rank_cache") and data["blueprint_rank_cache"] is Dictionary:
		blueprint_rank_cache.clear()
		for k in data["blueprint_rank_cache"]:
			if data["blueprint_rank_cache"][k] is Dictionary:
				blueprint_rank_cache[String(k)] = (data["blueprint_rank_cache"][k] as Dictionary).duplicate(true)

	# v6.6: 情报进化分支奖励加载
	if data.has("blueprint_intel_branch_bonus") and data["blueprint_intel_branch_bonus"] is Dictionary:
		blueprint_intel_branch_bonus.clear()
		for k in data["blueprint_intel_branch_bonus"]:
			if data["blueprint_intel_branch_bonus"][k] is Dictionary:
				blueprint_intel_branch_bonus[String(k)] = (data["blueprint_intel_branch_bonus"][k] as Dictionary).duplicate(true)

	# v6.6 修复: 武器槽位配置加载（原错误嵌套在 intel_branch_bonus 条件内，
	# 导致无该字段的存档加载时武器槽被静默丢弃。此处退回顶层 load_state 级别独立加载）
	if data.has("blueprint_weapon_slots") and data["blueprint_weapon_slots"] is Dictionary:
		blueprint_weapon_slots.clear()
		for k in data["blueprint_weapon_slots"]:
			var cid_w: String = String(k)
			if data["blueprint_weapon_slots"][k] is Array:
				var slots_array: Array[WeaponResource] = []
				for w_data in data["blueprint_weapon_slots"][k]:
					if w_data is Dictionary:
						var w = WeaponResource.new()
						w.weapon_id = w_data.get("weapon_id", "")
						w.slot_type = w_data.get("slot_type", 0)
						w.display_name = w_data.get("display_name", "")
						w.enabled = w_data.get("enabled", true)
						w.damage = w_data.get("damage", 0.0)
						w.attack_speed = w_data.get("attack_speed", 1.0)
						w.windup = w_data.get("windup", 0.2)
						w.active = w_data.get("active", 0.1)
						w.weapon_type = w_data.get("weapon_type", 0)
						w.range_value = w_data.get("range_value", 3)
						w.projectile_scene = w_data.get("projectile_scene", "")
						w.hit_effect_scene = w_data.get("hit_effect_scene", "")
						w.sound_id = w_data.get("sound_id", "")
						slots_array.append(w)
				blueprint_weapon_slots[cid_w] = slots_array

	# v6.11: 战力星级数据加载已移除（card_battle_stars 不再存档，旧字段被忽略）

	# 旧档 fragments（v2 蓝图碎片）与法则副本→知识迁移随蓝图体系移除而废弃
	# 将 blueprint_mods 反向同步到 CardResource 模板，确保 UI 和冲突检测正常
	_sync_blueprint_mods_to_templates()

## 将 blueprint_mods（持久存储）同步回 CardResource 模板的 mods 数组
func _sync_blueprint_mods_to_templates() -> void:
	for card_id in blueprint_mods:
		var mods_array = blueprint_mods[card_id]
		if not mods_array is Array:
			continue
		var card = _get_card_from_library(card_id)
		if card:
			card.mods.clear()
			for entry in mods_array:
				if entry is Dictionary:
					card.mods.append(entry.duplicate(true))
	if blueprint_mods.is_empty():
		return
	# [LOG-v5.1] print("[BlueprintManager] 已同步 %d 张卡的改造数据到模板" % blueprint_mods.size())


func reset_to_defaults() -> void:
	blueprint_mods.clear()
	blueprint_inherit_bonus.clear()
	blueprint_evolution_hp_floor.clear()
	blueprint_rank_cache.clear()
	blueprint_intel_branch_bonus.clear()
	blueprint_weapon_slots.clear()
	# v9.x（P2-7范围B）：默认法则解锁调用已随法则系统退役移除

## ─────────── 自动存档 ───────────

## v6.6: 蓝图变更后触发自动存档。
## 使用 deferred + 标记位实现节流：同一帧内的多次变更只保存一次，
## 避免高频率操作（如批量改造）导致 I/O 风暴。
func _auto_save(reason: String = "") -> void:
	if _suppress_auto_save:
		return
	if _auto_save_deferred_scheduled:
		# 已有挂起的保存，仅追加 reason（用于调试）
		if not reason.is_empty():
			_auto_save_pending_reason = reason
		return
	_auto_save_deferred_scheduled = true
	_auto_save_pending_reason = reason
	call_deferred("_flush_deferred_auto_save")

func _flush_deferred_auto_save() -> void:
	_auto_save_deferred_scheduled = false
	var reason: String = _auto_save_pending_reason
	_auto_save_pending_reason = ""
	var sm: Node = get_node_or_null("/root/SaveManager")
	if sm and sm.has_method("save_game"):
		sm.save_game()
	elif sm and sm.has_method("save_state"):
		# 兜底：SaveManager 可能未初始化完整，触发状态保存
		sm.save_state()

# v7.x: 安全刷新玩家相位师战力缓存（强化/改造/进化操作后调用，避免面板显示陈旧缓存）
# 守卫：PhaseInstrumentManager 未就绪或缺方法时静默跳过（非战斗场景或启动早期）
func _refresh_player_master_eval_safe() -> void:
	var pm: Node = get_node_or_null("/root/PhaseInstrumentManager")
	if pm != null and pm.has_method("refresh_player_master_eval"):
		pm.refresh_player_master_eval()

# ─────────────────────────────────────────────
#  新扩展方法：强化改造与进化系统
# ─────────────────────────────────────────────

## 强化卡牌到指定等级（新接口）
func apply_reinforcement(card: CardResource, target_level: int) -> Dictionary:
	var result = {success = false, cost = 0, message = ""}

	# v9.5: 养成隔离守卫——严禁直接改 DefaultCards 共享模板（会污染所有同名卡）
	if card == null or card.instance_id.is_empty():
		result.message = "卡牌未实例化，无法强化（拒绝操作共享模板）"
		push_warning("[BlueprintManager] apply_reinforcement 拒绝模板: instance_id 为空")
		return result

	# 验证等级范围
	if target_level < 1 or target_level > 10:
		result.message = "强化等级超出范围（1-10）"
		return result

	var current_level = card.enhance_level
	if target_level <= current_level:
		result.message = "目标等级不高于当前等级"
		return result

	# 计算消耗
	var base_power = card.power
	var cost_multiplier_sum = 0.0

	# 使用UnifiedRankSystem的cost_multiplier
	for level in range(current_level + 1, target_level + 1):
		var mult = _get_rank_cost_multiplier(level)
		cost_multiplier_sum += mult

	var nano_cost = int(base_power * cost_multiplier_sum)

	# 检查资源（直接调用BasicResourceManager）
	if not BasicResourceManager.can_afford("nano", nano_cost):
		result.message = "纳米材料不足（需要%d）" % nano_cost
		return result

	# 应用强化
	card.enhance_level = target_level
	BasicResourceManager.consume("nano", nano_cost)

	result.success = true
	result.cost = nano_cost
	result.message = "强化成功：%s → Lv%d" % [card.display_name, target_level]

	# 自动保存
	_auto_save("reinforcement")

	# v7.x: 强化改变第 1/2 层加成，刷新玩家相位师战力缓存避免面板陈旧
	_refresh_player_master_eval_safe()

	return result

## 备用：获取等级消耗倍率（reinforcement_panel 旧路径用）
## v7.x 修复 W4：原 Lv1=0.0 导致首强化完全免费（白嫖），与 CardEnhancementManager.get_enhance_nano_cost
## 的 Lv1=0.5 倍率不一致。统一为 0.5，与实例化强化路径口径对齐。
func _get_rank_cost_multiplier(level: int) -> float:
	match level:
		1: return 0.5
		2: return 1.0
		3: return 1.5
		4: return 2.0
		5: return 2.5
		6: return 3.0
		7: return 3.5
		8: return 4.0
		9: return 5.0
		10: return 6.0
		_: return 1.0

## 安装改造（新接口）
## 改造需要：纳米材料 + 改造指南（根据稀有度）
func install_modification(card: CardResource, mod_id: String, slot: int = -1) -> Dictionary:
	var result = {success = false, cost = 0, message = ""}

	# v9.5: 养成隔离守卫——严禁直接改 DefaultCards 共享模板
	if card == null or card.instance_id.is_empty():
		result.message = "卡牌未实例化，无法改造（拒绝操作共享模板）"
		push_warning("[BlueprintManager] install_modification 拒绝模板: instance_id 为空")
		return result

	# 检查槽位
	if card.mods.size() >= 9:
		result.message = "改造槽位已满（最多9个）"
		return result

	# 检查冲突
	var check_result = card.can_install_modification(mod_id)
	if not check_result.can_install:
		result.message = check_result.reason
		return result

	# 获取改造数据
	var mod_data = _get_mod_data_from_registry(mod_id)
	if mod_data.is_empty():
		result.message = "找不到改造数据：%s" % mod_id
		return result

	# 计算特定蓝图ID
	var blueprint_id = BlueprintDefinitions.get_mod_blueprint_id(mod_id)
	var blueprint_name = BlueprintDefinitions.get_mod_blueprint_name(mod_id)

	# 检查改造蓝图（图纸）
	## v7.1: 兼容 - 如果IntelItemBag不存在或未初始化，跳过蓝图检查
	## 开发/测试时可手动给予纳米即可操作
	var bag = get_node_or_null("/root/IntelItemBag")
	var skip_blueprint_check = (bag == null)
	if not skip_blueprint_check:
		if not bag.has_item(blueprint_id):
			result.message = "缺少图纸：%s" % blueprint_name
			return result

	# 计算纳米材料消耗
	# 平衡修复（2026-08-16 经济审查）：原公式 (80+28)×rarity×0.5 与卡牌本身无关——
	# 虚空领主与一战步枪班同价（~54 纳米），后期单关收入 ~2000 纳米下改造形同免费
	# （水槽压力跨时代通缩 ~25×）。改按卡牌战力定价，且每已装一个改造 +20% 递增，
	# 恢复"满改一张时代顶级卡 ≈ 数关收入"的 sink 压力。
	var card_power: float = maxf(60.0, float(card.power))
	var installed_count: int = card.mods.size()
	var nano_cost = int(card_power * 0.5 * (1.0 + 0.2 * installed_count))

	# 检查纳米材料
	if not BasicResourceManager.can_afford("nano", nano_cost):
		result.message = "纳米材料不足（需要%d）" % nano_cost
		return result

	# v6.14: 检查卡牌战力档位是否满足改造门槛（不同战力装不同改造）
	# 按 rarity 派生门槛：common→无门槛, rare→需ELITE档, legendary→需OVERLORD档
	# v7.3 修复 B1: 传 instance_id（实例存在时）而非 card_id。
	# 原代码传 card.card_id（模板），estimate_power_score 用模板 build stats（enhance_level=0/mods=[]），
	# 导致高稀有改造永远被误拒（白板战力达不到 ELITE/CHAMPION/OVERLORD 档）。
	var _power_key: String = String(card.instance_id) if (not String(card.instance_id).is_empty()) else card.card_id
	var _card_power: float = _estimate_power_score(_power_key)
	var _card_tier: int = PowerTiers.get_tier_by_power(_card_power)
	var _mod_min_tier: int = ModManager.get_min_power_tier_for_mod(mod_id)
	if not PowerTiers.meets_requirement(_card_tier, _mod_min_tier):
		result.message = "卡牌战力不足（需%s档，当前%s档）" % [
			PowerTiers.get_tier_name(_mod_min_tier), PowerTiers.get_tier_name(_card_tier)]
		return result

	# 应用改造
	var mod_entry = {
		id = mod_id,
		installed_at = Time.get_unix_time_from_system(),
		enabled = true,  # v6.5: 武器类改造可启用/禁用
		paid_cost = nano_cost,  # 2026-08-16: 记录实付，供替换/卸下时 50% 返还
	}

	if slot >= 0 and slot < card.mods.size():
		card.mods.insert(slot, mod_entry)
	else:
		card.mods.append(mod_entry)

	# 消耗资源
	BasicResourceManager.consume("nano", nano_cost)
	# 图纸不消耗，获得一次后永久可用

	result.success = true
	result.cost = nano_cost
	result.message = "改造安装成功：%s" % mod_data.get("name", mod_id)

	# 更新blueprint_mods缓存
	# v7.0: 用 instance_id 做 key（实例化养成），直接存实例的 mods（不再查模板）
	_update_blueprint_mods_cache_for_card(card)

	# 通知外部
	emit_signal("fragments_changed")

	# 自动保存
	_auto_save("modification")

	# v7.x: 改造改变第 1/2 层加成，刷新玩家相位师战力缓存避免面板陈旧
	_refresh_player_master_eval_safe()

	return result

## v6.5: 切换武器类改造的启用/禁用状态
## 仅对武器类改造（slot_type 为 "weapon" 或 "gun"）有效，禁用后跳过效果但仍占用槽位
## v7.0: 参数 card_id 实际是 instance_id；优先取实例对象
func set_mod_enabled(card_id: String, mod_index: int, enabled: bool) -> bool:
	var card: CardResource = _get_card_for_mods(card_id)
	if card == null:
		return false
	# v9.5: 养成隔离守卫——_get_card_for_mods 回退到模板时拒绝操作（避免污染共享模板）
	if card.instance_id.is_empty():
		push_warning("[BlueprintManager] set_mod_enabled 拒绝模板: %s 未实例化" % card_id)
		return false
	if mod_index < 0 or mod_index >= card.mods.size():
		return false
	var mod_entry = card.mods[mod_index]
	if not (mod_entry is Dictionary):
		return false
	# 检查是否武器类改造
	var mod_id: String = String(mod_entry.get("id", ""))
	var ModReg = preload("res://scripts/systems/modification_registry.gd")
	var mod_data: Dictionary = ModReg.get_data(mod_id)
	var slot_type: String = String(mod_data.get("slot_type", ""))
	if slot_type != "weapon" and slot_type != "gun":
		return false  # 仅武器类改造可启用/禁用
	mod_entry["enabled"] = enabled
	card.mods[mod_index] = mod_entry
	_update_blueprint_mods_cache_for_card(card)
	emit_signal("fragments_changed")
	_auto_save("modification_toggle")
	return true

## v6.5: 获取改造的启用状态（无 enabled 字段时默认 true）
## v7.0: 参数 card_id 实际是 instance_id；优先取实例对象
func is_mod_enabled(card_id: String, mod_index: int) -> bool:
	var card: CardResource = _get_card_for_mods(card_id)
	if card == null:
		return true
	if mod_index < 0 or mod_index >= card.mods.size():
		return true
	var mod_entry = card.mods[mod_index]
	if not (mod_entry is Dictionary):
		return true
	if mod_entry.has("enabled"):
		return bool(mod_entry["enabled"])
	return true

## v7.0: 按 instance_id 取实例对象（找实例）；无实例回退 _get_card_from_library（模板）
## 供改造读写使用
func _get_card_for_mods(id_str: String) -> CardResource:
	if id_str.is_empty():
		return null
	var ir: Node = get_node_or_null("/root/InstanceRegistry")
	if ir != null and ir.has_method("get_instance"):
		var inst: CardResource = ir.get_instance(id_str)
		if inst != null:
			return inst
	return _get_card_from_library(id_str)

## 替换改造（新接口）
func replace_modification(card: CardResource, old_mod_id: String, new_mod_id: String) -> Dictionary:
	var result = {success = false, refund = 0, cost = 0, message = ""}

	# v9.5: 养成隔离守卫——严禁直接改 DefaultCards 共享模板
	if card == null or card.instance_id.is_empty():
		result.message = "卡牌未实例化，无法替换改造（拒绝操作共享模板）"
		push_warning("[BlueprintManager] replace_modification 拒绝模板: instance_id 为空")
		return result

	# 查找旧改造位置
	var old_index = -1
	var old_paid: int = 0
	for i in range(card.mods.size()):
		var mod_entry = card.mods[i]
		var entry_id = mod_entry.get("id", "") if mod_entry is Dictionary else ""
		if entry_id == old_mod_id:
			old_index = i
			if mod_entry is Dictionary:
				old_paid = int(mod_entry.get("paid_cost", 0))
			break

	if old_index < 0:
		result.message = "找不到要替换的改造：%s" % old_mod_id
		return result

	# 移除旧改造
	card.mods.remove_at(old_index)

	# 安装新改造
	var install_result = install_modification(card, new_mod_id, old_index)

	if install_result.success:
		# 计算返还（2026-08-16 经济审查修复：返还与扣费同币种——原扣纳米返研究点属货币错配；
		# 按实付 paid_cost 50% 返纳米，旧存档条目无 paid_cost 时回退模块表 cost_install 口径）
		var refund: int = 0
		if old_paid > 0:
			refund = int(old_paid * 0.5)
		else:
			var old_mod_data = _get_mod_data_from_registry(old_mod_id)
			refund = int(old_mod_data.get("cost_install", 0) * 0.5)
		BasicResourceManager.add_resource("nano", refund)

		result.success = true
		result.refund = refund
		result.cost = install_result.cost
		result.message = "改造替换成功"
	else:
		# 失败，恢复旧改造
		card.mods.insert(old_index, {id = old_mod_id, installed_at = 0})
		result.message = install_result.message

	return result

# v6.7：死代码 evolve_card 已删除。
# 该函数（原 1230-1301 行）全项目无调用方，且其"进化消耗纳米 = 目标战力×2"
# 公式被 evolution_panel.gd 误抄，导致面板显示与实际零消耗的 evolve_blueprint 不符。
# 进化统一走 evolve_blueprint（→ CardEvolutionManager.evolve_blueprint）。

## 获取可用的改造列表（按卡牌ID精筛）
func get_available_modifications(card: CardResource) -> Array:
	# ModificationRegistry是autoload，直接访问
	var card_id = card.card_id if card else ""
	if not card_id.is_empty() and ModificationRegistry.has_method("get_mods_for_card"):
		return ModificationRegistry.get_mods_for_card(card_id)
	return ModificationRegistry.get_for_unit_type(card.combat_kind if card else 0)

## 获取进化路径预览
func get_evolution_preview(card: CardResource, target_card_id: String) -> Dictionary:
	var check_result = card.check_evolution_requirements(target_card_id)
	var stats = card.calculate_evolved_stats(target_card_id)

	return {
		can_evolve = check_result.passed,
		missing = check_result.missing,
		new_stats = stats,
		preserved_mods = card.mods.size(),
	}

## ─────────────────────────────────────────────
##  内部辅助方法
## ─────────────────────────────────────────────

## 从注册表获取改造数据
func _get_mod_data_from_registry(mod_id: String) -> Dictionary:
	# ModificationRegistry是autoload，直接访问
	return ModificationRegistry.get_data(mod_id)

## 检查纳米材料是否足够
func _can_afford_nano(amount: int) -> bool:
	return BasicResourceManager.can_afford("nano", amount)

## 消耗纳米材料
func _consume_nano(amount: int) -> void:
	BasicResourceManager.consume("nano", amount)

## 检查研究点是否足够
func _can_afford_research(amount: int) -> bool:
	# BasicResourceManager是autoload，直接访问
	return BasicResourceManager.can_afford("research", amount)

# v9.x（P2-7范围C）：_consume_research/_add_research（零调用方）已随科研点退役移除

## 移除蓝图养成数据（进化时调用；副本记账已随蓝图体系移除）
func _remove_blueprint(card_id: String) -> void:
	blueprint_mods.erase(card_id)

## 添加蓝图养成数据（进化时调用）
func _add_blueprint(card_id: String, _enhance_level: int, mods: Array) -> void:
	if not mods.is_empty():
		blueprint_mods[card_id] = mods.duplicate(true)

## 从库中获取卡牌
func _get_card_from_library(card_id: String) -> CardResource:
	# DefaultCards是const preload，始终可用
	return DefaultCards.get_card_by_id(card_id)

## 更新blueprint_mods缓存（始终同步 card.mods → blueprint_mods）
## v7.0: 兼容旧接口（按 card_id 查模板），新代码应优先用 _update_blueprint_mods_cache_for_card
func _update_blueprint_mods_cache(card_id: String) -> void:
	var card = _get_card_from_library(card_id)
	if card and not card.mods.is_empty():
		blueprint_mods[card_id] = card.mods.duplicate(true)
	elif card and card.mods.is_empty():
		blueprint_mods.erase(card_id)

## v7.0: 用实例对象更新 blueprint_mods 缓存
## key 优先用 instance_id（实例化养成），无 instance_id 回退 card_id
## 直接存实例的 mods，不查模板（模板的 mods 始终为空）
func _update_blueprint_mods_cache_for_card(card: CardResource) -> void:
	if card == null:
		return
	var key: String = card.instance_id if not card.instance_id.is_empty() else card.card_id
	if not card.mods.is_empty():
		blueprint_mods[key] = card.mods.duplicate(true)
	else:
		blueprint_mods.erase(key)

## ─── 武器槽位管理 ───

## 获取卡牌的自定义武器槽位配置
## card_id: String - 卡牌ID
## 返回：Array[WeaponResource] 或 null（如果无自定义配置）
func get_custom_weapon_slots(card_id: String) -> Array:
	if not blueprint_weapon_slots.has(card_id):
		return []
	return blueprint_weapon_slots.get(card_id, []) as Array

## 设置卡牌的自定义武器槽位配置
## card_id: String - 卡牌ID
## slots: Array[WeaponResource] - 武器槽位数组
## auto_save: bool - 是否自动保存（默认true）
func set_custom_weapon_slots(card_id: String, slots: Array, auto_save: bool = true) -> void:
	blueprint_weapon_slots[card_id] = slots.duplicate(true)
	if auto_save:
		_auto_save("武器槽位修改")

## 应用自定义武器槽位到卡牌
## card: CardResource - 卡牌资源
## 返回：是否应用了自定义配置
func apply_custom_weapon_slots(card: CardResource) -> bool:
	if card == null:
		return false
	
	var custom_slots = get_custom_weapon_slots(card.card_id)
	if custom_slots.is_empty():
		# 无自定义配置，确保使用默认槽位
		if card.has_method("_ensure_weapon_slots_initialized"):
			card._ensure_weapon_slots_initialized()
		return false
	
	# 应用自定义槽位
	card.weapon_slots.clear()
	for w in custom_slots:
		if w is WeaponResource:
			card.weapon_slots.append(w.clone())
	
	return true

## 保存当前卡牌的武器槽位配置（用于进化/改造后保存）
## card: CardResource - 卡牌资源
func save_card_weapon_slots(card: CardResource) -> void:
	if card == null:
		return
	
	blueprint_weapon_slots[card.card_id] = []
	for w in card.weapon_slots:
		if w is WeaponResource:
			blueprint_weapon_slots[card.card_id].append(w.clone())
	
	_auto_save("保存武器槽位配置")
