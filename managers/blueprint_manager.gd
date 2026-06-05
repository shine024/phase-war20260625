extends Node
## BlueprintManager — 卡牌账号进度管理器
## 当前职责：蓝图解锁、卡牌星级管理、研究点升级、纳米材料管理
## @todo 待重命名为 CardDataManager（ADR-001），因引用范围广暂保留原名

## 信号名保留 fragments_changed 以兼容外部（30+ 引用）
## 实际含义已变为「蓝图数据变更」（副本/星级/研究点/改装等）
signal fragments_changed
signal blueprint_star_upgraded(card_id: String, new_star: int)
signal blueprint_obtained(card_id: String, count: int)
signal card_manufactured(card_id: String, star: int)

var DEBUG_BLUEPRINT_LOG := false

## 蓝图管理器（研究点升星系统）
## - 记录已解锁蓝图
## - 记录蓝图副本数（card_id → 副本数，≥1 即可制造）
## - 研究点手动升星（1~9★）
## - 法则蓝图统一在此管理（law:xxx 前缀）

const GC = preload("res://resources/game_constants.gd")
const BasicResources = preload("res://data/basic_resources.gd")
const StarConfig = preload("res://data/blueprint_star_config.gd")
const ModEffects = preload("res://data/mod_effects.gd")
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

const MAX_BLUEPRINT_LEVEL: int = 9
const LAW_BLUEPRINT_PREFIX: String = "law:"

## XP 类型常量（兼容旧升级系统）
const XP_TYPE_DEFAULT: int = -1
const XP_TYPE_PLATFORM: int = 0

const EXCLUDED_WAR_PLATFORM_TYPES: Array = ["striker", "sniper", "stealth", "mage"]

## ── PhaseLawManager 安全引用缓存 ──
var _plm: Node = null
func _ensure_plm() -> Node:
	if _plm == null:
		_plm = get_node_or_null("/root/PhaseLawManager")
	return _plm

## 默认解锁的基础能量蓝图（新存档与一次性迁移会补足）
const DEFAULT_ENERGY_BLUEPRINT_IDS: Array[String] = [
	"energy_start_1", "energy_start_2", "energy_start_3", "energy_start_4",
	"energy_start_5", "energy_start_6", "energy_start_7",
]

## ─────────── 核心数据 ───────────

var unlocked_blueprint_ids: Array = []

## card_id -> 副本数量（≥1 表示可制造）
var blueprint_copies: Dictionary = {}

## blueprint_stars 已在 v5 迁移中彻底废弃，不再保留字段

## card_id -> 已选改装分支（最多9项，同 conflict_group 冲突自动替换）
var blueprint_mods: Dictionary = {}

## card_id -> 进化继承属性倍率（累计），如 0.30 表示 +30%
var blueprint_inherit_bonus: Dictionary = {}

## card_id -> 进化后 era0 有效 HP 下限（含养成乘区，战斗时按时代缩放）
var blueprint_evolution_hp_floor: Dictionary = {}

## card_id -> 最近一次军衔缓存 {rank_id, rank_name, power_score}
var blueprint_rank_cache: Dictionary = {}
## card_id -> 敌源MOD ID
var blueprint_enemy_origin_mod: Dictionary = {}

## 纳米材料已迁移到 BasicResourceManager（autoload）

var _suppress_auto_save: bool = false
var _auto_save_deferred_scheduled: bool = false
var _auto_save_pending_reason: String = ""

## 旧存档是否已做过「默认能量蓝图首份副本」迁移
var _legacy_default_energy_copies_migrated: bool = false

## 战斗中解锁仅写入数据；battle_ended 前由 BattleManager 调用 flush 再发信号（音效/结算列表）
var _deferred_unlock_notify_ids: Array = []



## ─────────── 内部辅助 ───────────

func _get_card_for_permit(card_id: String) -> CardResource:
	var card: CardResource = DefaultCards.get_card_by_id(card_id)
	if card != null:
		return card
	if card_id.begins_with("law:"):
		var lid: String = card_id.substr(4)
		return DefaultCards.create_law_card_resource(lid)
	return null

func _get_mod_category_permit_id(card_id: String) -> String:
	var card: CardResource = _get_card_for_permit(card_id)
	if card == null:
		return BasicResources.ID_PERMIT_TYPE_ASSAULT
	if card.card_type == GC.CardType.LAW:
		return BasicResources.ID_PERMIT_TYPE_LAW
	if card.card_type == GC.CardType.ENERGY:
		return BasicResources.ID_PERMIT_TYPE_SUPPORT
	if card.card_type == GC.CardType.COMBAT_UNIT:
		## v3兼容：旧platform_type已废弃，改用combat_kind
		var ckind: int = card.combat_kind if card.combat_kind >= 0 else 0
		if ckind == GC.CombatKind.ARMOR or ckind == GC.CombatKind.SUPPORT:
			return BasicResources.ID_PERMIT_TYPE_HEAVY
		# 默认轻装单位为突击类型
		return BasicResources.ID_PERMIT_TYPE_ASSAULT
	return BasicResources.ID_PERMIT_TYPE_ASSAULT

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
	_suppress_auto_save = true
	_unlock_default_blueprints()
	_suppress_auto_save = false
	if SignalBus:
		if SignalBus.has_signal("battle_started") and not SignalBus.battle_started.is_connected(_on_battle_started_clear_deferred_unlocks):
			SignalBus.battle_started.connect(_on_battle_started_clear_deferred_unlocks)

func _sync_debug_log_flag() -> void:
	var debug_mgr: Node = get_node_or_null("/root/DebugLogManager")
	if debug_mgr != null and debug_mgr.has_method("is_channel_enabled"):
		DEBUG_BLUEPRINT_LOG = bool(debug_mgr.is_channel_enabled("blueprint_manager", DEBUG_BLUEPRINT_LOG))

func _unlock_default_blueprints() -> void:
	var plm := _ensure_plm()
	var all_ids: Array = DefaultCards.get_all_blueprint_ids()
	var high_tier_blueprints = [
		"omega_platform", "titan_mk2", "abrams_mk2",
		"storm_rider"
	]
	for id in all_ids:
		if id is String and not unlocked_blueprint_ids.has(id):
			if id in high_tier_blueprints or id in DEFAULT_ENERGY_BLUEPRINT_IDS:
				unlocked_blueprint_ids.append(id)
				if DEBUG_BLUEPRINT_LOG:
					pass  # LOG: Initial unlock

	var default_law_blueprints = [
		"steel_quick_repair",
		"steel_bastion_wall",
		"flame_heat_overload",
		"thunder_ion_net",
	]
	for law_id in default_law_blueprints:
		var bp_id: String = LAW_BLUEPRINT_PREFIX + law_id
		if not unlocked_blueprint_ids.has(bp_id):
			unlocked_blueprint_ids.append(bp_id)
		if blueprint_copies.get(bp_id, 0) < 1:
			blueprint_copies[bp_id] = 1
			if DEBUG_BLUEPRINT_LOG:
				pass  # LOG: Initial law unlock
			if plm and plm.has_method("ensure_law_unlocked"):
				plm.ensure_law_unlocked(law_id)

	_ensure_starter_copies_for_default_energy_blueprints()

func _ensure_starter_copies_for_default_energy_blueprints() -> void:
	for eid in DEFAULT_ENERGY_BLUEPRINT_IDS:
		if not unlocked_blueprint_ids.has(eid):
			continue
		if get_blueprint_copies(eid) < 1:
			add_blueprint_copy(eid, 1)
	# 全装型初始1份副本（新存档背包直接给，此处确保蓝图面板也可见）
	if is_blueprint_unlocked("omega_platform") and get_blueprint_copies("omega_platform") < 1:
		add_blueprint_copy("omega_platform", 1)
	# 初始能量卡设为2★
	# [DEPRECATED] 初始能量卡设星级逻辑已禁用
	#for eid in ["energy_start_1", "energy_start_2"]:

## 旧存档：已解锁的默认能量蓝图若 0 副本则补到 1（每个存档只执行一次）
func _migrate_legacy_default_energy_starter_copies() -> void:
	var changed := false
	for eid in DEFAULT_ENERGY_BLUEPRINT_IDS:
		if not is_blueprint_unlocked(eid):
			continue
		if int(blueprint_copies.get(eid, 0)) >= 1:
			continue
		blueprint_copies[eid] = 1
		# var rarity: String = get_card_rarity(eid)
		changed = true
	if changed:
		if DEBUG_BLUEPRINT_LOG:
			pass  # LOG: 旧存档迁移：已为默认能量蓝图补足首份副本
		emit_signal("fragments_changed")

## ─────────── 蓝图解锁 ───────────

func _is_battle_active() -> bool:
	return BattleManager != null and BattleManager.battle_active


func _on_battle_started_clear_deferred_unlocks() -> void:
	# 异常退出战斗时可能未 flush；新局开始前补发通知，避免丢失结算/统计
	if not _deferred_unlock_notify_ids.is_empty():
		flush_deferred_unlock_notifications()


func flush_deferred_unlock_notifications() -> void:
	if _deferred_unlock_notify_ids.is_empty():
		return
	var pending: Array = _deferred_unlock_notify_ids.duplicate()
	_deferred_unlock_notify_ids.clear()
	if SignalBus == null:
		return
	for id in pending:
		SignalBus.blueprint_unlocked.emit(String(id))


func is_blueprint_unlocked(card_id: String) -> bool:
	return unlocked_blueprint_ids.has(card_id)

func unlock_blueprint(card_id: String) -> void:
	if card_id.is_empty():
		return
	if not unlocked_blueprint_ids.has(card_id):
		unlocked_blueprint_ids.append(card_id)
		if _is_battle_active():
			if not _deferred_unlock_notify_ids.has(card_id):
				_deferred_unlock_notify_ids.append(card_id)
		elif SignalBus:
			SignalBus.blueprint_unlocked.emit(card_id)
		_auto_save("蓝图解锁: " + card_id)

func get_unlocked_blueprint_ids() -> Array:
	return unlocked_blueprint_ids.duplicate()

## ─────────── 核心方法：蓝图副本 ───────────

## 添加蓝图副本（保证≥1可制造，多余副本转化为研究点奖励）
func add_blueprint_copy(card_id: String, count: int = 1) -> void:
	if card_id.is_empty() or count <= 0:
		return
	if _is_excluded_war_platform_id(card_id):
		return
	if not is_blueprint_unlocked(card_id):
		unlock_blueprint(card_id)
	blueprint_copies[card_id] = max(1, int(blueprint_copies.get(card_id, 0)))
	# 多余副本 → 研究点奖励
	var rarity: String = get_card_rarity(card_id)
	var grant_per_copy: int = int(StarConfig.get_research_cost_for_next_star(1, rarity) * 0.35)
	add_research_points(max(1, grant_per_copy) * count)
	emit_signal("fragments_changed")
	emit_signal("blueprint_obtained", card_id, count)

## 获取蓝图副本总数
func get_blueprint_copies(card_id: String) -> int:
	return int(blueprint_copies.get(card_id, 0))

## 首次从「掉卡」获得某张卡：解锁蓝图并保证至少 1 副本
func apply_card_drop_first_copy(card_id: String) -> void:
	var plm := _ensure_plm()
	var id: String = _normalize_blueprint_id(card_id)
	if id.is_empty() or _is_excluded_war_platform_id(id):
		return
	if not is_blueprint_unlocked(id):
		unlock_blueprint(id)
	blueprint_copies[id] = maxi(1, int(blueprint_copies.get(id, 0)))
	if is_law_blueprint_id(id) and plm and plm.has_method("ensure_law_unlocked"):
		plm.ensure_law_unlocked(law_id_from_blueprint_id(id))
	emit_signal("fragments_changed")

## ─────────── 蓝图等级系统（研究点升星，影响进化门槛） ───────────
## 星级是蓝图的整体成长度，影响进化资格检查（E1≥4★，E2≥7★）
## 注意：与 enhance_level（强化等级，0-10）是不同概念

## 获取蓝图当前星级
func get_blueprint_star(card_id: String) -> int:
	# [DEPRECATED] 星级系统已废弃，固定返回1
	return 1

## 获取法则蓝图星级（别名）
func get_law_blueprint_level(law_id: String) -> int:
	return get_blueprint_star(law_blueprint_id(law_id))

## 获取升星进度（基于当前研究点）
func get_star_progress(card_id: String) -> Dictionary:
	var star: int = get_blueprint_star(card_id)
	var rarity: String = get_card_rarity(card_id)
	var need: int = StarConfig.get_research_cost_for_next_star(star, rarity)
	var cur: int = get_research_points()
	var progress: float = 1.0 if need <= 0 else clampf(float(cur) / float(need), 0.0, 1.0)
	return {
		"current_star": star,
		"current_research": cur,
		"next_star_research": need,
		"progress_0_to_1": progress,
	}

## 检查蓝图是否可以升星
## [DEPRECATED] 升星功能已废弃，始终返回 false
func can_upgrade_blueprint(card_id: String, _xp_type: int = 0) -> bool:
	return false

## 蓝图升星：消耗研究点
## [DEPRECATED] 升星功能已废弃，始终返回 false
func upgrade_blueprint_level(card_id: String, _xp_type: int = 0) -> bool:
	return false

## 蓝图升星通知已制造卡片
func _on_blueprint_star_up(card_id: String, old_star: int, new_star: int) -> void:
	ManagerLazyLoader.ensure_loaded("affix")
	var am: Node = null
	if ManagerLazyLoader and ManagerLazyLoader.has_method("get_manager"):
		am = ManagerLazyLoader.get_manager("affix")
	if am == null:
		am = get_node_or_null("/root/AffixManager")
	if am and am.has_method("on_blueprint_star_up"):
		am.on_blueprint_star_up(card_id, old_star, new_star)
	_auto_save("蓝图升星: %s %d★ → %d★" % [card_id, old_star, new_star])

## 获取所有有副本的蓝图ID列表
func get_all_blueprint_ids() -> Array:
	var result: Array = []
	for card_id in blueprint_copies:
		if blueprint_copies[card_id] > 0:
			result.append(card_id)
	return result

## 获取所有有副本的蓝图ID及副本数
func get_all_blueprint_ids_with_copies() -> Dictionary:
	return blueprint_copies.duplicate()

## ─────────── 卡片等级兼容 ───────────

func get_card_level(card_id: String, _xp_type: int = -1) -> int:
	return get_blueprint_star(card_id)

func get_blueprint_level(card_id: String) -> int:
	return get_blueprint_star(card_id)

## 获取卡片XP进度（兼容旧升级系统）
func get_card_xp_progress(card_id: String, _xp_type: int = XP_TYPE_DEFAULT) -> Dictionary:
	var current_star: int = get_blueprint_star(card_id)
	var rarity: String = get_card_rarity(card_id)
	var need: int = StarConfig.get_research_cost_for_next_star(current_star, rarity)
	var cur: int = get_research_points()
	if current_star >= MAX_BLUEPRINT_LEVEL:
		return {
			"level": current_star,
			"cur_xp": cur,
			"next_xp": 0,
		}
	return {
		"level": current_star,
		"cur_xp": cur,
		"next_xp": need,
	}

## 获取卡片突破次数（兼容旧系统，当前返回0）
func get_card_breakthroughs(_card_id: String) -> int:
	return 0

## ─────────── 默认强化列表 ───────────

## 获取某星级对应的默认强化列表
func get_default_enhancements(card_id: String, star: int) -> Array:
	var enhancements: Array = []
	if star <= 0:
		return enhancements
	var card: CardResource = DefaultCards.get_card_by_id(card_id)
	if card == null:
		return enhancements
	var pool: Array = StarConfig.get_pool_for_card_type(card.card_type)
	if pool.is_empty():
		return enhancements
	var is_mythic: bool = card.rarity == "mythic"
	for i in range(star):
		var stable_key: int = int(hash(String(card_id) + "|" + str(star) + "|" + str(i)))
		var entry: Dictionary = StarConfig.roll_affix_at(pool, is_mythic, stable_key)
		if not entry.is_empty():
			enhancements.append(entry)
	return enhancements

## 获取指定卡牌在当前星级已生效的强化文案
func get_star_enhancement_lines(card_id: String, star: int = -1) -> Array[String]:
	var lines: Array[String] = []
	if card_id.is_empty():
		return lines
	var applied_star: int = star if star > 0 else get_blueprint_star(card_id)
	if applied_star <= 0:
		return lines
	var enhancements: Array = get_default_enhancements(card_id, applied_star)
	if enhancements.is_empty():
		var c0: CardResource = DefaultCards.get_card_by_id(card_id)
		if c0 != null:
			var pool_fb: Array = StarConfig.get_pool_for_card_type(c0.card_type)
			if not pool_fb.is_empty():
				var e0: Dictionary = StarConfig.roll_affix_at(
					pool_fb,
					str(c0.rarity).to_lower() == "mythic",
					int(hash(String(card_id) + "|fb|" + str(applied_star)))
				)
				if not e0.is_empty():
					enhancements.append(e0)
	for e_raw in enhancements:
		if not (e_raw is Dictionary):
			continue
		var e: Dictionary = e_raw
		var name_text: String = String(e.get("name", e.get("id", "强化")))
		var base_v: float = float(e.get("value_base", 0.0))
		var per_star_v: float = float(e.get("value_per_star", 0.0))
		var final_v: float = base_v + maxf(0.0, float(applied_star - 1)) * per_star_v
		lines.append("%s +%s" % [name_text, _format_enhancement_value(final_v)])
	return lines

func _format_enhancement_value(v: float) -> String:
	if absf(v - round(v)) < 0.001:
		return str(int(round(v)))
	return ("%.1f" % v)

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

func get_research_points() -> int:
	var brm: Node = _get_basic_resource_manager()
	if brm != null and brm.has_method("get_total"):
		return int(brm.get_total(BasicResources.ID_RESEARCH_POINTS))
	return 0

func add_research_points(amount: int) -> void:
	if amount == 0:
		return
	var brm: Node = _get_basic_resource_manager()
	if brm != null and brm.has_method("add_basic_resource"):
		brm.add_basic_resource(BasicResources.ID_RESEARCH_POINTS, amount)
	emit_signal("fragments_changed")

## ─────────── 制造 ───────────

## 制造卡牌（副本≥1即可制造，不消耗副本数）
## 返回：成功返回制造的卡牌资源，失败返回null
func manufacture_card(card_id: String) -> CardResource:
	var lookup_id: String = _normalize_blueprint_id(card_id)
	if not is_blueprint_unlocked(lookup_id):
		push_error("[BlueprintManager] 无法制造未解锁的蓝图: " + lookup_id)
		return null
	var card: CardResource = DefaultCards.get_card_by_id(lookup_id)
	if card == null:
		var law_lookup_id: String = lookup_id
		if law_lookup_id.begins_with(LAW_BLUEPRINT_PREFIX):
			law_lookup_id = law_lookup_id.substr(LAW_BLUEPRINT_PREFIX.length())
		if not PhaseLaws.get_by_id(law_lookup_id).is_empty():
			card = DefaultCards.create_law_card_resource(law_lookup_id)

	if card == null:
		push_error("[BlueprintManager] 无法制造卡牌，找不到资源: " + lookup_id)
		return null

	var star: int = get_blueprint_star(lookup_id)

	if card.card_type == GC.CardType.LAW or card.card_type == GC.CardType.ENERGY:
		var out_card: CardResource = card.clone()
		# out_card.star_level = star  # [DEPRECATED] star_level 赋值已废弃
		# [DEPRECATED] out_card.star_level 赋值已废弃
		if DEBUG_BLUEPRINT_LOG:
			pass  # LOG: 制造成功（法则/能量卡）
		emit_signal("card_manufactured", lookup_id, star)
		_auto_save("制造卡牌: %s ★%d" % [lookup_id, star])
		return out_card

	if DEBUG_BLUEPRINT_LOG:
		pass  # LOG: 制造成功
	emit_signal("card_manufactured", lookup_id, star)
	_auto_save("制造卡牌: %s ★%d" % [lookup_id, star])
	return card

func can_manufacture(card_id: String) -> bool:
	var lookup_id: String = _normalize_blueprint_id(card_id)
	if not is_blueprint_unlocked(lookup_id):
		return false
	# 非专属卡：蓝图已解锁即可制造
	if not _is_exclusive_card(lookup_id):
		return true
	# 专属卡：需检查势力条件
	return _is_exclusive_card_available(lookup_id)

## 检查是否为势力专属卡
func _is_exclusive_card(card_id: String) -> bool:
	var EC = preload("res://data/faction_exclusive_cards.gd")
	return EC.is_exclusive_card(card_id)

## 获取蓝图的势力分支（供合成系统使用）
## 势力变体卡的 card_id 格式为 faction:{faction_id}:{base_card_id}
func get_blueprint_faction_branch(card_id: String) -> String:
	if card_id.begins_with("faction:"):
		var parts: PackedStringArray = card_id.split(":")
		if parts.size() >= 2:
			return parts[1]
	return ""

## 检查势力专属卡是否可用
func _is_exclusive_card_available(card_id: String) -> bool:
	var EC = preload("res://data/faction_exclusive_cards.gd")
	if not EC.is_exclusive_card(card_id):
		return true  # 非专属卡始终可用
	var faction_id: String = EC.get_exclusive_faction(card_id)
	var min_lv: int = EC.get_min_faction_level(card_id)
	var fsm: Node = get_node_or_null("/root/FactionSystemManager")
	if fsm == null:
		return false
	if fsm.get_active_faction() != faction_id:
		return false
	return fsm.get_faction_level(faction_id) >= min_lv

func get_manufacture_info(card_id: String) -> Dictionary:
	var lookup_id: String = _normalize_blueprint_id(card_id)
	if not is_blueprint_unlocked(lookup_id):
		return {"can_manufacture": false, "reason": "蓝图未解锁"}
	var copies: int = get_blueprint_copies(lookup_id)
	var star: int = get_blueprint_star(lookup_id)
	var card: CardResource = DefaultCards.get_card_by_id(lookup_id)
	if card == null:
		var law_lookup_id: String = lookup_id
		if law_lookup_id.begins_with(LAW_BLUEPRINT_PREFIX):
			law_lookup_id = law_lookup_id.substr(LAW_BLUEPRINT_PREFIX.length())
		if not PhaseLaws.get_by_id(law_lookup_id).is_empty():
			card = DefaultCards.create_law_card_resource(law_lookup_id)
	return {
		"can_manufacture": true,
		"card_id": lookup_id,
		"card_name": card.display_name if card else lookup_id,
		"card_type": card.card_type if card else -1,
		"star": star,
		"copies": copies,
		"cost_copies": 1
	}

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

## 获取第 mod_index 个改造槽位的消耗需求（研究点 + 许可证）
func get_modification_requirements(card_id: String, mod_index: int) -> Dictionary:
	return ModManager.get_modification_requirements(card_id, mod_index, self)

## 获取当前已装改造数量
func get_modification_count(card_id: String) -> int:
	return ModManager.get_modification_count(card_id, blueprint_mods)

## 获取最大改造次数
func get_max_mod_slots() -> int:
	return ModManager.get_max_mod_slots()

## 获取可选 MOD 列表（从 ModEffects 获取具体 MOD_XX 定义）
func get_mod_options(card_id: String, _mod_index: int) -> Array[Dictionary]:
	return ModManager.get_mod_options(card_id)

## 检查是否可以执行第 mod_index 次改造
func can_apply_modification(card_id: String, mod_index: int) -> bool:
	return ModManager.can_apply_modification(card_id, mod_index, self)

## 执行改造：安装 MOD
func apply_modification(card_id: String, option_id: String) -> bool:
	return ModManager.apply_modification(card_id, option_id, self)

## ─────────── 进化系统 ───────────
## Facade 委托 → CardEvolutionManager（managers/evolution/card_evolution_manager.gd）

func get_evolution_options(card_id: String) -> Dictionary:
	return CardEvolutionManager.get_evolution_options(card_id)

func can_evolve_blueprint(card_id: String, target_card_id: String) -> Dictionary:
	return CardEvolutionManager.can_evolve_blueprint(card_id, target_card_id, self)

func evolve_blueprint(card_id: String, target_card_id: String) -> bool:
	return CardEvolutionManager.evolve_blueprint(card_id, target_card_id, self)

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


func _apply_evolution_hp_floor(stats: UnitStats, platform_card_id: String, era: int) -> void:
	EvolutionHelpers._apply_evolution_hp_floor(stats, platform_card_id, era, self)

## ─────────── 存档 ───────────

func save_state() -> Dictionary:
	var copies_dict: Dictionary = {}
	for k in blueprint_copies:
		copies_dict[k] = blueprint_copies[k]
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
	var eom_dict: Dictionary = {}
	for k in blueprint_enemy_origin_mod:
		eom_dict[k] = String(blueprint_enemy_origin_mod[k])
	return {
		"unlocked": unlocked_blueprint_ids.duplicate(),
		"blueprint_copies": copies_dict,
		"blueprint_mods": mods_dict,
		"blueprint_inherit_bonus": inherit_dict,
		"blueprint_evolution_hp_floor": hp_floor_dict,
		"blueprint_rank_cache": rank_dict,
		"blueprint_enemy_origin_mod": eom_dict,
		"legacy_default_energy_copies_migrated": _legacy_default_energy_copies_migrated,
	}

func load_state(data: Dictionary) -> void:
	emit_signal("fragments_changed")
	_legacy_default_energy_copies_migrated = bool(data.get("legacy_default_energy_copies_migrated", false))
	if data.has("unlocked") and data["unlocked"] is Array:
		unlocked_blueprint_ids = (data["unlocked"] as Array).duplicate()
		var filtered: Array = []
		for id in unlocked_blueprint_ids:
			if not _is_excluded_war_platform_id(String(id)):
				filtered.append(id)
		unlocked_blueprint_ids = filtered
	if unlocked_blueprint_ids.is_empty():
		_unlock_default_blueprints()
	if data.has("blueprint_copies") and data["blueprint_copies"] is Dictionary:
		blueprint_copies.clear()
		for k in data["blueprint_copies"]:
			var cid: String = String(k)
			if not _is_excluded_war_platform_id(cid):
				blueprint_copies[cid] = int(data["blueprint_copies"][k])
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
	if data.has("blueprint_enemy_origin_mod") and data["blueprint_enemy_origin_mod"] is Dictionary:
		blueprint_enemy_origin_mod.clear()
		for k in data["blueprint_enemy_origin_mod"]:
			blueprint_enemy_origin_mod[String(k)] = String(data["blueprint_enemy_origin_mod"][k])
	# 兼容旧存档的 fragments → blueprint_copies 迁移
	if not data.has("blueprint_copies") and data.has("fragments") and data["fragments"] is Dictionary:
		blueprint_copies.clear()
		for k in data["fragments"]:
			var cid: String = String(k)
			if not _is_excluded_war_platform_id(cid):
				blueprint_copies[cid] = int(data["fragments"][k])
	if not _legacy_default_energy_copies_migrated:
		_migrate_legacy_default_energy_starter_copies()
		_legacy_default_energy_copies_migrated = true
	_migrate_v3_law_copies_to_knowledge()
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
	print("[BlueprintManager] 已同步 %d 张卡的改造数据到模板" % blueprint_mods.size())

func _migrate_v3_law_copies_to_knowledge() -> void:
	var plm := _ensure_plm()
	if plm == null or not plm.has_method("add_knowledge"):
		return
	var to_erase: Array[String] = []
	for k in blueprint_copies.keys():
		var key: String = String(k)
		if not key.begins_with(LAW_BLUEPRINT_PREFIX):
			continue
		var law_id: String = key.substr(LAW_BLUEPRINT_PREFIX.length())
		var copies: int = int(blueprint_copies[key])
		if copies > 0:
			var kind: String = plm.knowledge_key_for_law_id(law_id)
			plm.add_knowledge(kind, copies * 5)
		to_erase.append(key)
	for key in to_erase:
		blueprint_copies.erase(key)

func reset_to_defaults() -> void:
	unlocked_blueprint_ids.clear()
	blueprint_copies.clear()
	blueprint_mods.clear()
	blueprint_inherit_bonus.clear()
	blueprint_rank_cache.clear()
	blueprint_enemy_origin_mod.clear()
	_legacy_default_energy_copies_migrated = false
	_unlock_default_blueprints()

## ─────────── 自动存档 ───────────

func _auto_save(reason: String = "") -> void:
	return

func _flush_deferred_auto_save() -> void:
	_auto_save_deferred_scheduled = false
	_auto_save_pending_reason = ""

# ─────────────────────────────────────────────
#  新扩展方法：强化改造与进化系统
# ─────────────────────────────────────────────

## 强化卡牌到指定等级（新接口）
func apply_reinforcement(card: CardResource, target_level: int) -> Dictionary:
	var result = {success = false, cost = 0, message = ""}

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

	return result

## 备用：获取等级消耗倍率
func _get_rank_cost_multiplier(level: int) -> float:
	match level:
		1: return 0.0
		2: return 0.5
		3: return 1.0
		4: return 1.5
		5: return 2.0
		6: return 2.5
		7: return 3.0
		8: return 3.5
		9: return 4.5
		10: return 6.0
		_: return 1.0

## 安装改造（新接口）
## 改造需要：纳米材料 + 改造指南（根据稀有度）
func install_modification(card: CardResource, mod_id: String, slot: int = -1) -> Dictionary:
	var result = {success = false, cost = 0, message = ""}

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
	var skip_blueprint_check = (IntelItemBag == null)
	if not skip_blueprint_check:
		if not IntelItemBag.has_item(blueprint_id):
			result.message = "缺少图纸：%s" % blueprint_name
			return result

	# 计算纳米材料消耗
	var base_power = get_base_power_for_mod_cost(card.card_id)
	var nano_cost = int(base_power * 0.5)  # 改造消耗卡牌战力50%的纳米材料

	# 检查纳米材料
	if not BasicResourceManager.can_afford("nano", nano_cost):
		result.message = "纳米材料不足（需要%d）" % nano_cost
		return result

	# 应用改造
	var mod_entry = {
		id = mod_id,
		installed_at = Time.get_unix_time_from_system(),
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
	_update_blueprint_mods_cache(card.card_id)

	# 通知外部
	emit_signal("fragments_changed")

	# 自动保存
	_auto_save("modification")

	return result

## 替换改造（新接口）
func replace_modification(card: CardResource, old_mod_id: String, new_mod_id: String) -> Dictionary:
	var result = {success = false, refund = 0, cost = 0, message = ""}

	# 查找旧改造位置
	var old_index = -1
	for i in range(card.mods.size()):
		var mod_entry = card.mods[i]
		var entry_id = mod_entry.get("id", "") if mod_entry is Dictionary else ""
		if entry_id == old_mod_id:
			old_index = i
			break

	if old_index < 0:
		result.message = "找不到要替换的改造：%s" % old_mod_id
		return result

	# 移除旧改造
	card.mods.remove_at(old_index)

	# 安装新改造
	var install_result = install_modification(card, new_mod_id, old_index)

	if install_result.success:
		# 计算返还
		var old_mod_data = _get_mod_data_from_registry(old_mod_id)
		var refund = int(old_mod_data.get("cost_install", 0) * 0.5)
		_add_research(refund)

		result.success = true
		result.refund = refund
		result.cost = install_result.cost
		result.message = "改造替换成功"
	else:
		# 失败，恢复旧改造
		card.mods.insert(old_index, {id = old_mod_id, installed_at = 0})
		result.message = install_result.message

	return result

## 进化卡牌（改造保留到新卡牌）
## 进化需要：纳米材料 + 进化图纸
func evolve_card(card: CardResource, target_card_id: String) -> Dictionary:
	var result = {success = false, new_card = null, message = ""}

	# 检查进化条件
	var check_result = card.check_evolution_requirements(target_card_id)
	if not check_result.passed:
		result.message = "进化条件未满足：" + ", ".join(check_result.missing)
		return result

	# 计算特定进化蓝图ID
	var evo_blueprint_id = BlueprintDefinitions.get_evolution_blueprint_id(card.card_id, target_card_id)

	# 检查进化图纸
	if IntelItemBag == null or not IntelItemBag.has_item(evo_blueprint_id):
		result.message = "缺少进化图纸：%s → %s" % [card.display_name, target_card_id]
		return result

	# 计算纳米材料消耗（基于目标卡牌战力）
	var target_card = _get_card_from_library(target_card_id)
	if target_card == null:
		result.message = "找不到目标卡牌：%s" % target_card_id
		return result

	var nano_cost = int(target_card.power * 2.0)  # 进化消耗目标战力2倍的纳米材料

	## v7.1: 直接调用 BasicResourceManager 而非 has_method(self) 检查
	if not BasicResourceManager.can_afford("nano", nano_cost):
		result.message = "纳米材料不足（需要%d）" % nano_cost
		return result

	# 记录旧改造
	var preserved_mods = card.mods.duplicate(true)

	# 记录进化历史
	card.record_evolution(card.card_id, target_card_id, preserved_mods)

	# 创建新卡牌（通过DefaultCards）
	var new_card = target_card  # 使用已获取的卡牌

	# 转移改造到新卡牌
	new_card.mods = preserved_mods

	# 继承强化等级
	new_card.enhance_level = card.enhance_level

	# 消耗资源
	BasicResourceManager.consume("nano", nano_cost)
	# 进化图纸不消耗，获得一次后永久可用

	# 更新blueprint数据
	_remove_blueprint(card.card_id)
	_add_blueprint(target_card_id, new_card.enhance_level, new_card.mods)

	result.success = true
	result.new_card = new_card
	result.message = "进化成功：%s → %s" % [card.display_name, new_card.display_name]

	# 自动保存
	_auto_save("evolution")

	return result

## 获取卡牌的当前军衔称号（新接口）
func get_card_military_title(card: CardResource) -> Dictionary:
	return card.get_military_rank()

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

## 消耗研究点
func _consume_research(amount: int) -> void:
	# BasicResourceManager是autoload，直接访问
	BasicResourceManager.consume("research", amount)

## 添加研究点
func _add_research(amount: int) -> void:
	BasicResourceManager.add_resource(BasicResources.ID_RESEARCH_POINTS, amount)

## 移除蓝图（进化时调用）
func _remove_blueprint(card_id: String) -> void:
	if blueprint_copies.has(card_id):
		blueprint_copies[card_id] = 0
	if blueprint_mods.has(card_id):
		blueprint_mods.erase(card_id)

## 添加蓝图（进化时调用）
func _add_blueprint(card_id: String, enhance_level: int, mods: Array) -> void:
	if not blueprint_copies.has(card_id):
		blueprint_copies[card_id] = 0
	blueprint_copies[card_id] = max(1, blueprint_copies[card_id])
	if not mods.is_empty():
		blueprint_mods[card_id] = mods.duplicate(true)

## 从库中获取卡牌
func _get_card_from_library(card_id: String) -> CardResource:
	# DefaultCards是const preload，始终可用
	return DefaultCards.get_card_by_id(card_id)

## 更新blueprint_mods缓存（始终同步 card.mods → blueprint_mods）
func _update_blueprint_mods_cache(card_id: String) -> void:
	var card = _get_card_from_library(card_id)
	if card and not card.mods.is_empty():
		blueprint_mods[card_id] = card.mods.duplicate(true)
	elif card and card.mods.is_empty():
		blueprint_mods.erase(card_id)
