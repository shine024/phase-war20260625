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

## ── 进化/改装子模块（class_name 全局引用） ──
## @note Godot 4.5 --check-only 模式下部分 class_name 加载顺序不确定，preload 保证可用
const ModManager = preload("res://managers/evolution/mod_manager.gd")
const CardEvolutionManager = preload("res://managers/evolution/card_evolution_manager.gd")
const EvolutionHelpers = preload("res://managers/evolution/evolution_helpers.gd")

const MAX_BLUEPRINT_LEVEL: int = 9
const LAW_BLUEPRINT_PREFIX: String = "law:"

## XP 类型常量（兼容旧升级系统）
## TODO: 确认 affix_panel 等引用方迁移后删除
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

## card_id -> 当前星级(1~9)
var blueprint_stars: Dictionary = {}

## card_id -> 已选改装分支（最多9项，同 conflict_group 冲突自动替换）
var blueprint_mods: Dictionary = {}

## card_id -> 进化继承属性倍率（累计），如 0.30 表示 +30%
var blueprint_inherit_bonus: Dictionary = {}

## card_id -> 进化后 era0 有效 HP 下限（含养成乘区，战斗时按时代缩放）
var blueprint_evolution_hp_floor: Dictionary = {}

## card_id -> 最近一次军衔缓存 {rank_id, rank_name, power_score}
var blueprint_rank_cache: Dictionary = {}

## 纳米材料兜底（已迁移到 BasicResourceManager，此字段仅作后备）
var nano_materials: int = 0
var _legacy_nano_pending: int = 0

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
					print("[BlueprintManager] Initial unlock: ", id)

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
			blueprint_stars[bp_id] = 1
			if DEBUG_BLUEPRINT_LOG:
				print("[BlueprintManager] Initial law unlock: ", law_id, " (1 copy)")
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
	for eid in ["energy_start_1", "energy_start_2"]:
		if int(blueprint_stars.get(eid, 1)) < 2:
			blueprint_stars[eid] = 2

## 旧存档：已解锁的默认能量蓝图若 0 副本则补到 1（每个存档只执行一次）
func _migrate_legacy_default_energy_starter_copies() -> void:
	var changed := false
	for eid in DEFAULT_ENERGY_BLUEPRINT_IDS:
		if not is_blueprint_unlocked(eid):
			continue
		if int(blueprint_copies.get(eid, 0)) >= 1:
			continue
		blueprint_copies[eid] = 1
		var rarity: String = get_card_rarity(eid)
		blueprint_stars[eid] = StarConfig.calculate_star(1, rarity)
		changed = true
	if changed:
		if DEBUG_BLUEPRINT_LOG:
			print("[BlueprintManager] 旧存档迁移：已为默认能量蓝图补足首份副本")
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
	blueprint_stars[card_id] = max(1, int(blueprint_stars.get(card_id, 1)))
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
	if int(blueprint_stars.get(id, 0)) < 1:
		blueprint_stars[id] = 1
	if is_law_blueprint_id(id) and plm and plm.has_method("ensure_law_unlocked"):
		plm.ensure_law_unlocked(law_id_from_blueprint_id(id))
	emit_signal("fragments_changed")

## ─────────── 蓝图等级系统（研究点升星，影响进化门槛） ───────────
## 星级是蓝图的整体成长度，影响进化资格检查（E1≥4★，E2≥7★）
## 注意：与 enhance_level（强化等级，0-10）是不同概念

## 获取蓝图当前星级
func get_blueprint_star(card_id: String) -> int:
	return int(blueprint_stars.get(card_id, 1))

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
func can_upgrade_blueprint(card_id: String, _xp_type: int = 0) -> bool:
	if card_id.is_empty():
		return false
	var star: int = get_blueprint_star(card_id)
	if star >= MAX_BLUEPRINT_LEVEL:
		return false
	if not is_blueprint_unlocked(card_id):
		return false
	var rarity: String = get_card_rarity(card_id)
	var needed: int = StarConfig.get_research_cost_for_next_star(star, rarity)
	return get_research_points() >= needed

## 蓝图升星：消耗研究点
func upgrade_blueprint_level(card_id: String, _xp_type: int = 0) -> bool:
	if not can_upgrade_blueprint(card_id, _xp_type):
		return false
	var old_star: int = get_blueprint_star(card_id)
	var rarity: String = get_card_rarity(card_id)
	var cost: int = StarConfig.get_research_cost_for_next_star(old_star, rarity)
	add_research_points(-cost)
	var new_star: int = min(MAX_BLUEPRINT_LEVEL, old_star + 1)
	blueprint_stars[card_id] = new_star
	emit_signal("fragments_changed")
	emit_signal("blueprint_star_upgraded", card_id, new_star)
	_on_blueprint_star_up(card_id, old_star, new_star)
	return true

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
	return nano_materials

func add_nano_materials(amount: int) -> void:
	if amount == 0:
		return
	var brm: Node = _get_basic_resource_manager()
	if brm != null and brm.has_method("add_basic_resource"):
		brm.add_basic_resource(BasicResources.ID_NANO_MATERIALS, amount)
	elif brm != null and brm.has_method("add_resource"):
		brm.add_basic_resource(BasicResources.ID_NANO_MATERIALS, amount)
	else:
		nano_materials = max(0, nano_materials + amount)
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
	elif brm != null and brm.has_method("add_resource"):
		brm.add_resource(BasicResources.ID_RESEARCH_POINTS, amount)
	emit_signal("fragments_changed")

func merge_legacy_nano_into_basic_resources() -> void:
	if _legacy_nano_pending <= 0:
		_legacy_nano_pending = 0
		nano_materials = 0
		return
	var brm: Node = _get_basic_resource_manager()
	if brm != null and brm.has_method("add_basic_resource"):
		brm.add_basic_resource(BasicResources.ID_NANO_MATERIALS, _legacy_nano_pending)
	elif brm != null and brm.has_method("add_resource"):
		brm.add_basic_resource(BasicResources.ID_NANO_MATERIALS, _legacy_nano_pending)
	else:
		nano_materials = max(0, nano_materials + _legacy_nano_pending)
	_legacy_nano_pending = 0
	nano_materials = 0
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
		out_card.star_level = star
		if DEBUG_BLUEPRINT_LOG:
			print("[BlueprintManager] 制造成功: ", out_card.display_name, " ★", star)
		emit_signal("card_manufactured", lookup_id, star)
		_auto_save("制造卡牌: %s ★%d" % [lookup_id, star])
		return out_card

	if DEBUG_BLUEPRINT_LOG:
		print("[BlueprintManager] 制造成功: ", card.display_name, " ★", star)
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


func _apply_platform_star_growth_bias(stats: UnitStats, platform_card_id: String) -> void:
	EvolutionHelpers._apply_platform_star_growth_bias(stats, platform_card_id, self)


func _apply_evolution_hp_floor(stats: UnitStats, platform_card_id: String, era: int) -> void:
	EvolutionHelpers._apply_evolution_hp_floor(stats, platform_card_id, era, self)

## ─────────── 存档 ───────────

func save_state() -> Dictionary:
	var copies_dict: Dictionary = {}
	for k in blueprint_copies:
		copies_dict[k] = blueprint_copies[k]
	var stars_dict: Dictionary = {}
	for k in blueprint_stars:
		stars_dict[k] = blueprint_stars[k]
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
	return {
		"unlocked": unlocked_blueprint_ids.duplicate(),
		"blueprint_copies": copies_dict,
		"blueprint_stars": stars_dict,
		"blueprint_mods": mods_dict,
		"blueprint_inherit_bonus": inherit_dict,
		"blueprint_evolution_hp_floor": hp_floor_dict,
		"blueprint_rank_cache": rank_dict,
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
	if data.has("blueprint_stars") and data["blueprint_stars"] is Dictionary:
		blueprint_stars.clear()
		for k in data["blueprint_stars"]:
			var cid: String = String(k)
			if not _is_excluded_war_platform_id(cid):
				blueprint_stars[cid] = max(1, int(data["blueprint_stars"][k]))
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
	# 兼容旧存档的 fragments → blueprint_copies 迁移
	if not data.has("blueprint_copies") and data.has("fragments") and data["fragments"] is Dictionary:
		blueprint_copies.clear()
		for k in data["fragments"]:
			var cid: String = String(k)
			if not _is_excluded_war_platform_id(cid):
				blueprint_copies[cid] = int(data["fragments"][k])
		if data.has("blueprint_levels") and data["blueprint_levels"] is Dictionary:
			blueprint_stars.clear()
			for k in data["blueprint_levels"]:
				var cid: String = String(k)
				if not _is_excluded_war_platform_id(cid):
					blueprint_stars[cid] = max(1, mini(int(data["blueprint_levels"][k]), MAX_BLUEPRINT_LEVEL))
		else:
			blueprint_stars.clear()
			for cid in blueprint_copies:
				var rarity: String = get_card_rarity(cid)
				blueprint_stars[cid] = StarConfig.calculate_star(blueprint_copies[cid], rarity)
	_legacy_nano_pending = 0
	nano_materials = 0
	if not _legacy_default_energy_copies_migrated:
		_migrate_legacy_default_energy_starter_copies()
		_legacy_default_energy_copies_migrated = true
	_migrate_v3_law_copies_to_knowledge()

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
	blueprint_stars.clear()
	blueprint_mods.clear()
	blueprint_inherit_bonus.clear()
	blueprint_rank_cache.clear()
	nano_materials = 0
	_legacy_nano_pending = 0
	_legacy_default_energy_copies_migrated = false
	_unlock_default_blueprints()

## ─────────── 自动存档 ───────────

func _auto_save(reason: String = "") -> void:
	return

func _flush_deferred_auto_save() -> void:
	_auto_save_deferred_scheduled = false
	_auto_save_pending_reason = ""
