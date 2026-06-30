extends Node
## 相位仪管理：按相位仪定义动态生成四色槽位
##
## v6.2 新增：符文槽管理系统（与现有四色槽位并行运行）
## - 符文槽位：存放符文ID（String），替代废弃的法则系统
## - 战前装备，战斗中不可变更
## - 全局加成：所有己方单位共享符文之语激活效果

const GC = preload("res://resources/game_constants.gd")
const PhaseInstruments = preload("res://data/phase_instruments.gd")
const PhaseLaws = preload("res://data/phase_laws.gd")
const RunewordMatcher = preload("res://managers/runeword_matcher.gd")
const RuneDefs = preload("res://data/runes.gd")
const DEBUG_EQUIP_LOG := false
var _default_cards_instance: Variant = null

func _get_default_cards() -> Variant:
	if _default_cards_instance == null:
		_default_cards_instance = load("res://data/default_cards.gd")
	return _default_cards_instance
## ── 子系统：装备/卸下/同步 ──
const LoadoutSync = preload("res://managers/phase_instrument_loadout_sync.gd")
var _loadout_sync: PhaseInstrumentLoadoutSync = null

## 累计相位场经验阈值（Lv1..Lv16），与每关 victory 发放的 LevelEras.get_base_xp_for_level 对齐调参
const PHASE_FIELD_XP_THRESHOLDS: Array = [
	0,
	150,
	350,
	600,
	900,
	1250,
	1650,
	2100,
	2600,
	3150,
	3750,
	4400,
	5100,
	5850,
	6650,
	7500,
]

## 与 backpack 扁平索引一致：红→蓝→绿→黄→符文（v6.2 符文追加在末尾，不破坏旧索引）
const SLOT_COLOR_ORDER: Array[String] = ["red", "blue", "green", "yellow", "rune"]
## 四色槽全量遍历（例如手动卸下全部并返还背包时；战后默认不再自动清空槽位）
const CARD_SLOTS: Array[String] = ["red", "blue", "green", "yellow", "rune"]
## 法则卡跨色路由装配时的最大递归深度（防止无限递归）
const MAX_EQUIP_RECURSION: int = 2

var selected_instrument_id: String = ""
var instrument_slots: Dictionary = {} # color -> Array[CardResource | null]
var unlocked_instrument_ids: Array[String] = []
const PHASE_FIELD_POINTS_PER_LEVEL: int = 1
const PHASE_FIELD_GROWTH_RULES: Dictionary = {
	"atk_pct": {"label": "攻击", "per_point": 0.02, "display_unit": "%"},
	"def_pct": {"label": "防御", "per_point": 0.02, "display_unit": "%"},
	"hp_pct": {"label": "生命", "per_point": 0.03, "display_unit": "%"},
	# v7.x: key 保留 energy_output_pct（存档兼容），语义改为"能量恢复"
	"energy_output_pct": {"label": "能量恢复", "per_point": 0.02, "display_unit": "%"},
}

var phase_field_xp: int = 0
var unspent_phase_field_points: int = 0
var phase_field_allocations: Dictionary = {}
var _loadouts_cache: Array = []
var _loadouts_dirty: bool = true
var _runtime_instrument_defs: Dictionary = {} # instrument_id -> Dictionary

# ═══════════════════════════════════════════════════════════
# v6.7: 相位师排名差异化加成
# 战斗开始时算出玩家/敌方的相位师星级（1-7★），转排名系数乘到加成上。
# 3★=1.0 基准（向后兼容），低星略降，高星最多 +25%。
# ═══════════════════════════════════════════════════════════
const RANK_STAR_COEFFICIENTS: Dictionary = {
	1: 0.85,  # 新锐
	2: 0.92,  # 精英
	3: 1.00,  # 高手（基准）
	4: 1.08,  # 大师
	5: 1.15,  # 宗师
	6: 1.20,  # 传说
	7: 1.25,  # 神话
}

# ═══════════════════════════════════════════════════════════
# v7.2: 相位师镜像对称系数
# 敌方产兵加成镜像我方公式。这两个系数把敌方相位师的 attack_power/defense
# 换算成等量于我方"相位场属性点"的加成比例。校准依据：我方满相位场（约16点
# 分配到 atk/hp/def）在 PHASE_FIELD_GROWTH_RULES 下约贡献 atk+10%/hp+10%。
# 敌方满级相位师 attack_power~1000/defense~200，取系数使其贡献量级相当。
# ═══════════════════════════════════════════════════════════
const MIRROR_LEVEL_ATK_COEFF: float = 0.00010  # attack_power 1000 → +10% 攻击（等量我方满相位场）
const MIRROR_LEVEL_HP_COEFF: float = 0.00050   # defense 200 → +10% HP（等量我方满相位场）

## 当前战斗缓存的玩家相位师星级（start_battle 时算一次，整场不变）
var _cached_player_rank_stars: int = 3
## 当前战斗缓存的敌方 boss 相位师星级（仅 boss 对战时设置）
var _cached_enemy_rank_stars: int = 3

## 相位师星级 → 排名加成系数（0.85~1.25）
static func get_rank_coefficient(stars: int) -> float:
	return float(RANK_STAR_COEFFICIENTS.get(clampi(stars, 1, 7), 1.0))
var _drop_serial_counter: int = 0
var _plm: Node

# ── v6.2 符文系统状态 ──────────────────────────────────────────────
# 符文槽位：索引0..rune_slot_count-1，每个槽存放符文ID(String)或null(空槽)
# 与四色槽位完全独立，互不影响
var _rune_slots: Array = [] # Array[String | null]
# 玩家已拥有的符文ID集合（去重）
var _owned_runes: Array[String] = []
# 缓存：当前激活的符文之语加成（装备变更后刷新）
var _cached_rune_bonus: Dictionary = {}
# 缓存：当前激活的符文之语列表
var _cached_active_runewords: Array = []
# 缓存失效标记
var _rune_bonus_dirty: bool = true


func _mark_loadouts_dirty() -> void:
	_loadouts_dirty = true

## 显式使 loadout 缓存失效（外部修改 loadout 数据后调用）
func invalidate_loadout_cache() -> void:
	_loadouts_cache.clear()
	_loadouts_dirty = true

func _ensure_plm() -> Node:
	if _plm == null or not is_instance_valid(_plm):
		_plm = get_node_or_null("/root/PhaseLawManager")
	return _plm

func _resolve_instrument_cfg(instrument_id: String) -> Dictionary:
	if _runtime_instrument_defs.has(instrument_id):
		return _runtime_instrument_defs[instrument_id]
	return PhaseInstruments.get_by_id(instrument_id)

func _ensure_properties_with_legacy_fallback(cfg: Dictionary) -> Array:
	var out: Array = []
	if cfg.has("properties") and cfg["properties"] is Array:
		for p in cfg["properties"]:
			if p is Dictionary:
				out.append(p)
	if not out.is_empty():
		return out
	var legacy: Array[Dictionary] = []
	var star: int = int(cfg.get("star", 1))
	var add_legacy = func(pid: String, v: float) -> void:
		if v <= 0.0:
			return
		legacy.append({"id": pid, "value": v, "display": PhaseInstruments.build_property_display(pid, v)})
	add_legacy.call("pi_atk", float(cfg.get("card_damage_bonus", 0.0)))
	add_legacy.call("pi_def", float(cfg.get("defense_bonus", 0.0)))
	add_legacy.call("pi_xp", float(cfg.get("xp_bonus", 0.0)))
	var cost_reduce: int = int(cfg.get("energy_cost_reduction", 0))
	if cost_reduce <= 0:
		cost_reduce = int(PhaseInstruments.get_standard_property_value("pi_energy_cost", star, String(cfg.get("source", PhaseInstruments.SOURCE_SHOP))))
	if cost_reduce > 0:
		legacy.append({"id": "pi_energy_cost", "value": float(cost_reduce), "display": PhaseInstruments.build_property_display("pi_energy_cost", float(cost_reduce))})
	return legacy

func _get_property_value(cfg: Dictionary, property_id: String, fallback: float = 0.0) -> float:
	var props: Array = _ensure_properties_with_legacy_fallback(cfg)
	for p in props:
		if not (p is Dictionary):
			continue
		if String((p as Dictionary).get("id", "")) == property_id:
			return float((p as Dictionary).get("value", fallback))
	return fallback

func _get_max_unlocked_star() -> int:
	var max_star: int = 0
	for iid in unlocked_instrument_ids:
		var cfg: Dictionary = _resolve_instrument_cfg(String(iid))
		if cfg.is_empty():
			continue
		max_star = maxi(max_star, int(cfg.get("star", 0)))
	return max_star

func _ready() -> void:
	_loadout_sync = LoadoutSync.new()
	_loadout_sync.setup(self)
	_init_unlocked_instruments()
	_set_default_instrument_if_needed()
	_rebuild_slots()
	_rebuild_rune_slots()  # v6.2: 初始化符文槽位
	var cfg: Dictionary = get_current_instrument()
	var DebugLog = get_node_or_null("/root/DebugLogManager")
	if DebugLog:
		DebugLog.agent_log("phase_instrument_manager.gd", "_ready", {
			"selected_instrument_id": selected_instrument_id,
			"selected_name": String(cfg.get("name", "")),
			"selected_star": int(cfg.get("star", -1)),
			"unlocked_count": unlocked_instrument_ids.size(),
			"max_unlocked_star": _get_max_unlocked_star(),
			"rune_slot_count": get_rune_slot_count(),  # v6.2
		}, "", "0ec8f5")

func _init_unlocked_instruments() -> void:
	if not unlocked_instrument_ids.is_empty():
		return
	for d in PhaseInstruments.get_all():
		if not (d is Dictionary):
			continue
		if bool(d.get("is_generic", false)):
			unlocked_instrument_ids.append(String(d.get("id", "")))
	var default_id: String = PhaseInstruments.get_default_id()
	if not unlocked_instrument_ids.has(default_id):
		unlocked_instrument_ids.append(default_id)

func grant_phase_field_xp(source: String, amount: int) -> void:
	if amount <= 0:
		return
	var old_level: int = get_phase_field_level()
	phase_field_xp = max(0, phase_field_xp + amount)
	if SignalBus and SignalBus.has_signal("phase_field_xp_changed"):
		SignalBus.phase_field_xp_changed.emit(source, amount, phase_field_xp)
	var new_level: int = get_phase_field_level()
	if new_level > old_level:
		var level_gain: int = new_level - old_level
		unspent_phase_field_points += level_gain * PHASE_FIELD_POINTS_PER_LEVEL
		if SignalBus and SignalBus.has_signal("phase_field_level_up"):
			SignalBus.phase_field_level_up.emit(old_level, new_level, unspent_phase_field_points)

func add_phase_xp(amount: int) -> void:
	grant_phase_field_xp("legacy", amount)

func get_phase_xp() -> int:
	return phase_field_xp

func get_phase_field_level() -> int:
	var level: int = 1
	for i in range(PHASE_FIELD_XP_THRESHOLDS.size()):
		if phase_field_xp >= int(PHASE_FIELD_XP_THRESHOLDS[i]):
			level = i + 1
	return level

func get_phase_level() -> int:
	return get_phase_field_level()

func get_phase_field_xp_progress() -> Dictionary:
	var level: int = get_phase_field_level()
	var idx: int = clampi(level - 1, 0, PHASE_FIELD_XP_THRESHOLDS.size() - 1)
	var cur_threshold: int = int(PHASE_FIELD_XP_THRESHOLDS[idx])
	var next_threshold: int = int(PHASE_FIELD_XP_THRESHOLDS[min(idx + 1, PHASE_FIELD_XP_THRESHOLDS.size() - 1)])
	var next_xp: int = max(0, next_threshold - cur_threshold)
	return {
		"level": level,
		"xp": phase_field_xp,
		"cur_xp": max(0, phase_field_xp - cur_threshold),
		"next_xp": next_xp,
	}

func get_phase_xp_progress() -> Dictionary:
	return get_phase_field_xp_progress()

func get_unspent_phase_field_points() -> int:
	return max(0, unspent_phase_field_points)

func get_phase_field_allocations() -> Dictionary:
	return phase_field_allocations.duplicate(true)

func get_phase_field_growth_rules() -> Dictionary:
	return PHASE_FIELD_GROWTH_RULES.duplicate(true)

func get_phase_field_growth_detail_lines() -> Array[String]:
	var lines: Array[String] = []
	lines.append("每提升1级获得 %d 点相位场属性点" % PHASE_FIELD_POINTS_PER_LEVEL)
	for key in PHASE_FIELD_GROWTH_RULES.keys():
		var rule: Dictionary = PHASE_FIELD_GROWTH_RULES[key]
		var label: String = String(rule.get("label", key))
		var per_point: float = float(rule.get("per_point", 0.0))
		var unit: String = String(rule.get("display_unit", ""))
		var value_text: String = ""
		if unit == "%":
			value_text = "+%.0f%%/点" % (per_point * 100.0)
		else:
			value_text = "+%.2f/点" % per_point
		lines.append("%s: %s" % [label, value_text])
	return lines

func get_phase_field_total_bonus() -> Dictionary:
	var bonus: Dictionary = {}
	for key in PHASE_FIELD_GROWTH_RULES.keys():
		var points: int = int(phase_field_allocations.get(key, 0))
		if points <= 0:
			continue
		var rule: Dictionary = PHASE_FIELD_GROWTH_RULES[key]
		var per_point: float = float(rule.get("per_point", 0.0))
		bonus[key] = points * per_point
	return bonus

func apply_phase_field_bonus_to_unit_stats(stats: UnitStats) -> void:
	if stats == null:
		return
	var cfg: Dictionary = get_current_instrument()
	var bonus: Dictionary = get_phase_field_total_bonus()
	# 相位场属性点加成
	var hp_bonus: float = float(bonus.get("hp_pct", 0.0))
	var atk_bonus: float = float(bonus.get("atk_pct", 0.0))
	var def_bonus: float = float(bonus.get("def_pct", 0.0))
	# 相位仪固有属性加成
	var pi_atk: float = _get_property_value(cfg, "pi_atk")
	var pi_def: float = _get_property_value(cfg, "pi_def")
	var pi_hp: float = _get_property_value(cfg, "pi_hp")
	# 合计
	var total_hp_mult: float = hp_bonus + pi_hp * 0.05  # pi_hp 每点+5% HP
	var total_atk_mult: float = atk_bonus + pi_atk * 0.05  # pi_atk 每点+5% 攻击
	var total_def_mult: float = def_bonus + pi_def * 0.05  # pi_def 每点+5% 防御

	# v6.7: 乘上玩家相位师排名系数（星级越高，加成越强）
	# 3★=1.0 基准（等于改动前），低星略降，高星最多 +25%
	var rank_coeff: float = get_rank_coefficient(_cached_player_rank_stars)
	total_hp_mult *= rank_coeff
	total_atk_mult *= rank_coeff
	total_def_mult *= rank_coeff

	if total_hp_mult > 0.0:
		stats.max_hp = maxf(1.0, stats.max_hp * (1.0 + total_hp_mult))

	if total_atk_mult > 0.0:
		stats.attack_damage = maxf(0.1, stats.attack_damage * (1.0 + total_atk_mult))
		# v5.0: 三维攻击全加成
		stats.attack_light = maxf(0.1, stats.attack_light * (1.0 + total_atk_mult))
		stats.attack_armor = maxf(0.1, stats.attack_armor * (1.0 + total_atk_mult))
		stats.attack_air = maxf(0.1, stats.attack_air * (1.0 + total_atk_mult))
		for i in range(stats.weapons.size()):
			var w: Variant = stats.weapons[i]
			if not (w is Dictionary):
				continue
			var wd: Dictionary = w
			wd["damage"] = maxf(0.1, float(wd.get("damage", 0.0)) * (1.0 + total_atk_mult))
			stats.weapons[i] = wd
		# v7.x 修复: 同步 weapon_slots[].damage（战斗 AI 读的是这里）
		if stats.has_method("_sync_weapon_slots_damage"):
			stats._sync_weapon_slots_damage(1.0 + total_atk_mult)

	if total_def_mult > 0.0:
		stats.damage_reduction = clampf(stats.damage_reduction + total_def_mult, 0.0, 0.8)

# ═══════════════════════════════════════════════════════════
# v6.7: 相位师排名加成 —— 敌方 boss 镜像 + 星级缓存管理
# ═══════════════════════════════════════════════════════════

## v6.7: 敌方 boss 单位加成（与玩家方对称）
## 仅在 _is_phase_master_battle 时由 battle_spawn_system 调用。
## 用敌方 boss 星级算排名系数，乘到敌方单位 stats 上。
## 注：敌方单位不走 apply_phase_field_bonus_to_unit_stats（那条路径读玩家相位仪），
##     此处独立应用一个量级相当的乘算，保持"敌我双方对称"。
func apply_enemy_phase_master_bonus_to_unit_stats(stats: UnitStats, enemy_stars: int) -> void:
	if stats == null:
		return
	# v7.2: 等级维度加成 —— 读相位师 master_stats.attack_power/defense，镜像我方相位场属性点。
	# 注意：符文/相位仪/改造维度由 enemy_phase_field_driver 的 v6.14 函数处理
	# （_apply_master_rune_bonus / _apply_enemy_phase_instrument_bonus / _apply_sequence_entry_bonus），
	# 此处只负责等级维度，避免双重叠加。无 master_config 时回退旧标量（向后兼容）。
	var master_cfg: Dictionary = _get_current_enemy_master_config()
	if master_cfg.is_empty():
		_apply_enemy_bonus_legacy_scalar(stats, enemy_stars)
		return
	var rank_coeff: float = get_rank_coefficient(enemy_stars)
	var master_stats: Dictionary = master_cfg.get("stats", {})
	var atk_from_level: float = float(master_stats.get("attack_power", 0.0)) * MIRROR_LEVEL_ATK_COEFF * rank_coeff
	var hp_from_level: float = float(master_stats.get("defense", 0.0)) * MIRROR_LEVEL_HP_COEFF * rank_coeff
	# 应用等级加成（atk/hp，与我方相位场属性点对称）
	if hp_from_level > 0.0:
		stats.max_hp = maxf(1.0, stats.max_hp * (1.0 + hp_from_level))
	if atk_from_level > 0.0:
		stats.attack_damage = maxf(0.1, stats.attack_damage * (1.0 + atk_from_level))
		stats.attack_light = maxf(0.1, stats.attack_light * (1.0 + atk_from_level))
		stats.attack_armor = maxf(0.1, stats.attack_armor * (1.0 + atk_from_level))
		stats.attack_air = maxf(0.1, stats.attack_air * (1.0 + atk_from_level))
		if stats.has_method("_sync_weapon_slots_damage"):
			stats._sync_weapon_slots_damage(1.0 + atk_from_level)
		for i in range(stats.weapons.size()):
			var w: Variant = stats.weapons[i]
			if w is Dictionary:
				var wd: Dictionary = w
				wd["damage"] = maxf(0.1, float(wd.get("damage", 0.0)) * (1.0 + atk_from_level))
				stats.weapons[i] = wd

## v7.2: 旧单一标量加成（master_config 不可用时的回退路径，保持向后兼容）
func _apply_enemy_bonus_legacy_scalar(stats: UnitStats, enemy_stars: int) -> void:
	var coeff: float = get_rank_coefficient(enemy_stars)
	var base_mult: float = 0.17 * coeff
	stats.max_hp = maxf(1.0, stats.max_hp * (1.0 + base_mult))
	stats.attack_damage = maxf(0.1, stats.attack_damage * (1.0 + base_mult))
	stats.attack_light = maxf(0.1, stats.attack_light * (1.0 + base_mult))
	stats.attack_armor = maxf(0.1, stats.attack_armor * (1.0 + base_mult))
	stats.attack_air = maxf(0.1, stats.attack_air * (1.0 + base_mult))
	if stats.has_method("_sync_weapon_slots_damage"):
		stats._sync_weapon_slots_damage(1.0 + base_mult)
	for i in range(stats.weapons.size()):
		var w: Variant = stats.weapons[i]
		if w is Dictionary:
			var wd: Dictionary = w
			wd["damage"] = maxf(0.1, float(wd.get("damage", 0.0)) * (1.0 + base_mult))
			stats.weapons[i] = wd
	stats.damage_reduction = clampf(stats.damage_reduction + base_mult, 0.0, 0.8)

## v7.2: 从 BattleManager 取当前敌方相位师配置
func _get_current_enemy_master_config() -> Dictionary:
	var tree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return {}
	var bm: Node = tree.root.get_node_or_null("BattleManager")
	if bm == null or not ("_phase_master_config" in bm):
		return {}
	var cfg: Dictionary = bm.get("_phase_master_config")
	return cfg if not cfg.is_empty() else {}

## v6.7: 战斗开始时缓存玩家相位师星级（整场战斗不变）
func set_player_rank_stars(stars: int) -> void:
	_cached_player_rank_stars = clampi(stars, 1, 7)

## v6.7: 战斗开始时缓存敌方 boss 相位师星级
func set_enemy_rank_stars(stars: int) -> void:
	_cached_enemy_rank_stars = clampi(stars, 1, 7)

## v6.7: 战斗结束时清空缓存（恢复 3★ 基准，避免影响非战斗场景）
func clear_rank_cache() -> void:
	_cached_player_rank_stars = 3
	_cached_enemy_rank_stars = 3

func _set_default_instrument_if_needed() -> void:
	# 仅在「未选择」或「当前 ID 已非法/未解锁」时重选；否则每次 get_current_instrument 会把选择覆盖成默认 ID，导致无法切换相位仪
	if not selected_instrument_id.is_empty() and has_unlocked_instrument(selected_instrument_id):
		return
	var best_id: String = PhaseInstruments.get_default_id()
	var best_star: int = -1
	for iid in unlocked_instrument_ids:
		var cfg: Dictionary = _resolve_instrument_cfg(String(iid))
		if cfg.is_empty():
			continue
		var s: int = int(cfg.get("star", 0))
		if s > best_star:
			best_star = s
			best_id = String(cfg.get("id", best_id))
	selected_instrument_id = best_id
	var DebugLog = get_node_or_null("/root/DebugLogManager")
	if DebugLog:
		DebugLog.agent_log("phase_instrument_manager.gd", "_set_default_instrument", {
				"default_id": selected_instrument_id,
				"default_star": best_star,
			}, "", "0ec8f5")

func _rebuild_slots() -> void:
	var old_slots: Dictionary = instrument_slots.duplicate(true)
	instrument_slots.clear()
	var cfg: Dictionary = get_current_instrument()
	var counts: Dictionary = cfg.get("slot_counts", {})
	for color in SLOT_COLOR_ORDER:
		var cnt: int = int(counts.get(color, 0))
		if color == "rune":
			# v6.2: rune 槽位从 _rune_slots 同步（rune存的是String不是CardResource）
			_rebuild_rune_slots()
			var rune_arr: Array = []
			for i in range(cnt):
				rune_arr.append(_rune_slots[i] if i < _rune_slots.size() else null)
			instrument_slots["rune"] = rune_arr
			continue
		var arr: Array = []
		var old_arr: Array = old_slots.get(color, [])
		for i in range(cnt):
			arr.append(old_arr[i] if i < old_arr.size() else null)
		instrument_slots[color] = arr
	# v6.2: 同步刷新符文槽位数量（保留已装备的符文）
	_rebuild_rune_slots()

func _law_id_from_card(card: Variant) -> String:
	# v6.2: rune 槽存的是 String，防御非 CardResource 传入（red/blue 槽正常只存 CardResource）
	if card == null or not (card is CardResource):
		return ""
	var cr: CardResource = card
	if cr.card_type != GC.CardType.LAW:
		return ""
	var lid: String = cr.linked_law_id if not String(cr.linked_law_id).is_empty() else cr.card_id
	# 法则蓝图在部分链路里会携带 law: 前缀；PhaseLaws 的 key 统一是无前缀 law_id。
	if lid.begins_with("law:"):
		lid = lid.substr(4)
	if PhaseLaws.get_by_id(lid).is_empty():
		return ""
	return lid

func _has_any_law_card_in_slots() -> bool:
	for color in ["red", "blue"]:
		for c_raw in instrument_slots.get(color, []):
			var c: CardResource = c_raw
			if c != null and c.card_type == GC.CardType.LAW:
				return true
	return false

func _compact_law_ids_from_slots_hypothetical(color: String, color_index: int, new_card: CardResource) -> Dictionary:
	var reds: Array = (instrument_slots.get("red", []) as Array).duplicate()
	var blues: Array = (instrument_slots.get("blue", []) as Array).duplicate()
	if color == "red" and color_index >= 0 and color_index < reds.size():
		reds[color_index] = new_card
	elif color == "blue" and color_index >= 0 and color_index < blues.size():
		blues[color_index] = new_card
	return {
		"actives": _compact_law_ids_for_kind(reds, "active"),
		"passives": _compact_law_ids_for_kind(blues, "passive"),
	}

func _compact_law_ids_for_kind(slot_arr: Array, expected_kind: String) -> Array:
	var out: Array = []
	for c_raw in slot_arr:
		var c: CardResource = c_raw
		if c == null:
			continue
		var lid: String = _law_id_from_card(c)
		if lid.is_empty():
			continue
		var law: Dictionary = PhaseLaws.get_by_id(lid)
		if law.is_empty() or String(law.get("kind", "")) != expected_kind:
			continue
		if not out.has(lid):
			out.append(lid)
	return out

func _compact_law_ids_from_current_slots() -> Dictionary:
	return {
		"actives": _compact_law_ids_for_kind(instrument_slots.get("red", []), "active"),
		"passives": _compact_law_ids_for_kind(instrument_slots.get("blue", []), "passive"),
	}

func _apply_law_slots_to_plm() -> bool:
	_ensure_plm()
	if not _plm or not _plm.has_method("set_equipped_laws"):
		return false
	# 退出阶段场景树销毁中时，plm 可能已不在树内，调用其内部绝对路径查询会报错
	if not _plm.is_inside_tree():
		return false
	var pack: Dictionary = _compact_law_ids_from_current_slots()
	for pid in pack["passives"]:
		if _plm.has_method("ensure_law_unlocked"):
			_plm.ensure_law_unlocked(String(pid))
	for aid in pack["actives"]:
		if _plm.has_method("ensure_law_unlocked"):
			_plm.ensure_law_unlocked(String(aid))
	var budget: int = int(_plm.battle_nano_budget) if "battle_nano_budget" in _plm else 0
	var ok: bool = _plm.set_equipped_laws(pack["passives"], pack["actives"], budget)
	if not ok and _plm.has_method("force_sync_instrument_law_slots"):
		_plm.force_sync_instrument_law_slots(pack["passives"], pack["actives"])
		return true
	return ok


## 开战前调用：以红/蓝槽内法则卡为准，刷新 PhaseLawManager 的装配（和 can_cast 列表一致）
func sync_law_cards_to_phase_law_manager() -> bool:
	return _apply_law_slots_to_plm()

## 旧存档：槽位无法则卡但 PhaseLawManager 仍有装配时，生成槽内卡并同步
func migrate_law_slots_from_phase_law_manager_if_empty() -> void:
	if _has_any_law_card_in_slots():
		return
	var actives: Array = []
	var passives: Array = []
	_ensure_plm()
	if _plm and "equipped_active_laws" in _plm:
		actives = _plm.equipped_active_laws
	if _plm and "equipped_passive_laws" in _plm:
		passives = _plm.equipped_passive_laws
	if actives.is_empty() and passives.is_empty():
		return
	var reds: Array = instrument_slots.get("red", [])
	var blues: Array = instrument_slots.get("blue", [])
	var changed: bool = false
	for i in range(reds.size()):
		if i >= actives.size():
			break
		var lid: String = String(actives[i])
		if lid.is_empty():
			continue
		var tmpl: CardResource = _get_default_cards().create_law_card_resource(lid)
		if tmpl != null:
			reds[i] = tmpl.clone()
			changed = true
	for i in range(blues.size()):
		if i >= passives.size():
			break
		var lid2: String = String(passives[i])
		if lid2.is_empty():
			continue
		var tmpl2: CardResource = _get_default_cards().create_law_card_resource(lid2)
		if tmpl2 != null:
			blues[i] = tmpl2.clone()
			changed = true
	if changed:
		instrument_slots["red"] = reds
		instrument_slots["blue"] = blues
		_emit_slots_changed()
		_apply_law_slots_to_plm()

## 读档后：若槽内已有法则卡，用槽位覆盖 PhaseLawManager 装配列表
func sync_law_slots_to_plm_if_has_law_cards() -> void:
	if _has_any_law_card_in_slots():
		_apply_law_slots_to_plm()

func equip_card(slot_index: int, card: CardResource, _energy_manager: Node = null, _recursion_depth: int = 0) -> bool:
	var _equip_t0: int = Time.get_ticks_msec()
	var loc: Dictionary = _flat_index_to_slot(slot_index)
	var color: String = String(loc.get("color", ""))
	var color_index: int = int(loc.get("index", -1))
	if color.is_empty() or color_index < 0 or card == null:
		var DebugLog = get_node_or_null("/root/DebugLogManager")
		if DebugLog:
			DebugLog.agent_log("phase_instrument_manager.gd", "equip_invalid", {
				"slot_index": slot_index,
				"color": color,
				"color_index": color_index,
				"card_null": card == null,
			}, "", "0ec8f5")
		return false
	if not _can_equip_card_to_color(card, color):
		# 法则卡自动路由：拖到红/蓝任一槽时，自动找到正确颜色的第一个空位
		if card.card_type == GC.CardType.LAW and (color == "red" or color == "blue"):
			var alt_color: String = "red" if color == "blue" else "blue"
			if _can_equip_card_to_color(card, alt_color):
				var alt_arr: Array = instrument_slots.get(alt_color, [])
				for ai in range(alt_arr.size()):
					if alt_arr[ai] == null:
						# 重新计算 flat_index 并递归调用
						var alt_flat: int = _slot_to_flat_index(alt_color, ai)
						if alt_flat >= 0 and _recursion_depth < MAX_EQUIP_RECURSION:
							return equip_card(alt_flat, card, _energy_manager, _recursion_depth + 1)
						break
				var DebugLog = get_node_or_null("/root/DebugLogManager")
				if DebugLog:
					DebugLog.agent_log("phase_instrument_manager.gd", "equip_can_equip_fail", {
				"slot_index": slot_index,
				"color": color,
				"card_id": card.card_id,
				"card_type": int(card.card_type),
			}, "", "0ec8f5")
		return false

	if color == "red" or color == "blue":
		_ensure_plm()
		if not _plm or not _plm.has_method("set_equipped_laws"):
			return false
		var hyp: Dictionary = _compact_law_ids_from_slots_hypothetical(color, color_index, card)
		for pid in hyp["passives"]:
			if _plm.has_method("ensure_law_unlocked"):
				_plm.ensure_law_unlocked(String(pid))
		for aid in hyp["actives"]:
			if _plm.has_method("ensure_law_unlocked"):
				_plm.ensure_law_unlocked(String(aid))
		var budget: int = int(_plm.battle_nano_budget) if "battle_nano_budget" in _plm else 0
		if not _plm.set_equipped_laws(hyp["passives"], hyp["actives"], budget):
			# 相位仪槽位中的法则卡是玩家实体持有卡，优先保证槽位可装配；
			# 若战前规则校验失败，则回退为与槽位强同步（不做环境/纳米/解锁拦截）。
			if _plm.has_method("force_sync_instrument_law_slots"):
				_plm.force_sync_instrument_law_slots(hyp["passives"], hyp["actives"])
			else:
				# [LOG-v5.1] print("[PhaseInstrumentManager] 法则槽装配未通过（环境/纳米/解锁）: ", card.display_name)
				return false

	# 装备卡牌到相位仪不消耗能量
	# 只有战斗中使用卡牌才消耗能量
	# [LOG-v5.1] if DEBUG_EQUIP_LOG: print("[PhaseInstrumentManager] 装备卡牌 %s 到槽位 %s (颜色: %s)，不消耗能量" % [card.display_name, slot_index, color])

	var arr: Array = instrument_slots.get(color, [])
	var old_card: CardResource = arr[color_index]
	arr[color_index] = card
	instrument_slots[color] = arr

	if old_card != null:
		SignalBus.card_added_to_backpack.emit(old_card)
	_emit_slots_changed()
	# v7.0: card_equipped 第2参数改传 instance_id（实例化养成身份）；无 instance_id 回退 card_id
	var equip_id: String = card.instance_id if not card.instance_id.is_empty() else card.card_id
	SignalBus.card_equipped.emit(slot_index, equip_id, _card_type_name(card))
	var DebugLog = get_node_or_null("/root/DebugLogManager")
	if DebugLog:
		DebugLog.agent_log("phase_instrument_manager.gd", "equip_ok", {
			"slot_index": slot_index,
			"color": color,
			"card_id": card.card_id,
			"energy_cost": int(card.energy_cost),
			"replaced_old_card": old_card != null,
		}, "", "0ec8f5")
	return true

func unequip_card(slot_index: int) -> void:
	var loc: Dictionary = _flat_index_to_slot(slot_index)
	var color: String = String(loc.get("color", ""))
	var color_index: int = int(loc.get("index", -1))
	if color.is_empty() or color_index < 0:
		return
	var arr: Array = instrument_slots.get(color, [])
	var card: CardResource = arr[color_index]
	arr[color_index] = null
	instrument_slots[color] = arr
	if color == "red" or color == "blue":
		_apply_law_slots_to_plm()
	_emit_slots_changed()
	SignalBus.card_unequipped.emit(slot_index)
	# 将卡归还到背包
	if card != null:
		# [LOG-v5.1] print("[PhaseInstrumentManager] unequip_card: Emitting card_added_to_backpack for card_id=%s" % card.card_id)
		SignalBus.card_added_to_backpack.emit(card)
		# [LOG-v5.1] print("[PhaseInstrumentManager] unequip_card: Signal emitted successfully")

## 战斗结束后：清空所有槽位并将卡片逐一放回背包的第一个空位
func unequip_all_and_return_to_backpack() -> void:
	var cards_to_return: Array[CardResource] = []
	for color in CARD_SLOTS:
		var arr: Array = instrument_slots.get(color, [])
		for i in range(arr.size()):
			# v6.2: rune 槽存的是 rune_id (String)，不是卡牌；
			# 切换相位仪时符文由 _rebuild_rune_slots 保留/回收，不参与"返还背包"。
			var c_raw = arr[i]
			if c_raw != null and not (c_raw is CardResource):
				continue
			var c: CardResource = c_raw
			if c != null:
				cards_to_return.append(c)
				arr[i] = null
		instrument_slots[color] = arr

	_apply_law_slots_to_plm()

	_emit_slots_changed()

	# 通过信号将卡片逐一放回背包的第一个空位
	if SignalBus and not cards_to_return.is_empty():
		for c2 in cards_to_return:
			SignalBus.card_added_to_backpack.emit(c2)
			# [LOG-v5.1] print("[PhaseInstrumentManager] 卡片 %s 已返还背包" % c2.card_id)

func get_slots() -> Array:
	var out: Array = []

	for color in SLOT_COLOR_ORDER:
		var arr: Array = instrument_slots.get(color, [])
		for s in arr:
			out.append(s)
	return out

# 新主逻辑：绿色槽中的每张战斗卡都是一个独立部署单位
func get_loadouts() -> Array:
	if not _loadouts_dirty:
		return _loadouts_cache
	_loadouts_dirty = true
	var loadouts: Array = []
	var green_slots: Array = instrument_slots.get("green", [])
	for c_raw in green_slots:
		var c: CardResource = c_raw
		if c == null:
			continue
		# 仅平台卡可部署（战斗卡）
		if c.card_type != GC.CardType.COMBAT_UNIT:
			continue
		loadouts.append({"platform": c, "weapons": []})

	_loadouts_cache = loadouts
	_loadouts_dirty = false
	return loadouts

## 按平台卡 id（含合成卡 id）查找完整 loadout；找不到返回空字典
func get_loadout_by_platform_card_id(platform_card_id: String) -> Dictionary:
	if platform_card_id.is_empty():
		return {}
	# v7.0: 优先按 instance_id 精确匹配（实例化后两张同名卡可区分）
	# 回退按 card_id 匹配（兼容旧路径，返回第一个匹配）
	var fallback: Dictionary = {}
	for ld in get_loadouts():
		if not (ld is Dictionary):
			continue
		var plat: CardResource = ld.get("platform", null)
		if plat == null:
			continue
		if not plat.instance_id.is_empty() and plat.instance_id == platform_card_id:
			return ld
		if plat.card_id == platform_card_id and fallback.is_empty():
			fallback = ld
	return fallback

func get_slot_card_ids() -> Array:
	var ids: Array = []
	for color in SLOT_COLOR_ORDER:
		var arr: Array = instrument_slots.get(color, [])
		for c_raw in arr:
			# v6.2: rune 槽存的是 rune_id (String)，不是 CardResource；
			# rune 槽的持久化由独立的 save_rune_state/load_rune_state 处理，
			# 此处对 rune 槽返回空字符串占位，避免 String 强转 CardResource 崩溃，
			# 也避免读档时 get_card_by_id(rune_id) 误把 rune_id 当卡牌 ID 还原。
			if c_raw != null and not (c_raw is CardResource):
				ids.append("")
				continue
			var c: CardResource = c_raw
			if c == null:
				ids.append("")
				continue
			# v7.0: 优先存 instance_id（实例化养成身份）；无 instance_id 时回退 card_id（兼容旧卡）
			var cid: String = c.instance_id
			if cid.is_empty():
				cid = c.card_id
			# 与 PhaseLaws/DefaultCards 一致：槽位存档用无前缀 law_id，读档时也可用 law: 兼容
			if c.card_type == GC.CardType.LAW and cid.begins_with("law:"):
				cid = cid.substr(4)
			ids.append(cid)
	return ids

## 旧版存档：槽位序列按 绿→红→蓝→黄 写入，需转为 红→蓝→绿→黄
func remap_legacy_green_first_slots(card_ids: Array) -> Array:
	var cfg: Dictionary = get_current_instrument()
	var counts: Dictionary = cfg.get("slot_counts", {})
	var r: int = int(counts.get("red", 0))
	var b: int = int(counts.get("blue", 0))
	var g: int = int(counts.get("green", 0))
	var y: int = int(counts.get("yellow", 0))
	var expected: int = r + b + g + y
	if card_ids.size() != expected:
		return card_ids
	var greens: Array = []
	var reds: Array = []
	var blues: Array = []
	var yellows: Array = []
	var ptr: int = 0
	for _i in range(g):
		greens.append(card_ids[ptr] if ptr < card_ids.size() else "")
		ptr += 1
	for _i2 in range(r):
		reds.append(card_ids[ptr] if ptr < card_ids.size() else "")
		ptr += 1
	for _i3 in range(b):
		blues.append(card_ids[ptr] if ptr < card_ids.size() else "")
		ptr += 1
	for _i4 in range(y):
		yellows.append(card_ids[ptr] if ptr < card_ids.size() else "")
		ptr += 1
	var out: Array = []
	for x in reds:
		out.append(x)
	for x2 in blues:
		out.append(x2)
	for x3 in greens:
		out.append(x3)
	for x4 in yellows:
		out.append(x4)
	return out

func set_slots_from_card_ids(card_ids: Array) -> void:
	# 先计算期望的槽位总数
	var expected_total = 0
	for color in SLOT_COLOR_ORDER:
		expected_total += instrument_slots.get(color, []).size()

	# 如果保存的槽数据量与期望不符，打印警告但不清空，尽力恢复
	if card_ids.size() != expected_total:
		push_warning("[PhaseInstrumentManager] 槽位数量不匹配（存档 %d vs 当前 %d），尽力恢复..." % [card_ids.size(), expected_total])

	# 尽力逐个恢复：按当前槽位数遍历，存档中多余的忽略，不足的留空
	var ir: Node = get_node_or_null("/root/InstanceRegistry")
	var ptr: int = 0
	for color in SLOT_COLOR_ORDER:
		var arr: Array = instrument_slots.get(color, [])
		for i in range(arr.size()):
			var id_val: String = ""
			if ptr < card_ids.size() and card_ids[ptr] != null:
				id_val = str(card_ids[ptr])
			ptr += 1
			if id_val.is_empty():
				arr[i] = null
				continue
			# v7.x: 能量卡系统移除——旧存档槽位里的 energy_start_* 不再装备，留空并记录待补偿。
			# 解析出 base_card_id（energy_start_1#3 → energy_start_1）判断。
			var _id_base: String = id_val
			if ir != null and ir.has_method("get_card_id_of"):
				_id_base = ir.get_card_id_of(id_val)
			if _id_base.begins_with("energy_start_"):
				arr[i] = null
				_compensate_removed_energy_card(_id_base)
				continue
			# v7.0: 优先用 instance_id 取实例（含养成数据），取不到回退 card_id 取模板
			# v7.3: 回退链路修复——裸 card_id 查 get_instance 必返回 null（key 是 card_id#序号），
			#   旧存档槽位若存了裸 card_id（迁移/边界），原逻辑静默回退到无养成的模板，
			#   导致"装备后强化/改造消失"。改为：先尝试同名实例回退查找，仍找不到才用模板并告警。
			var restored: CardResource = null
			if ir != null and ir.has_method("get_instance"):
				restored = ir.get_instance(id_val)
			if restored == null and ir != null and ir.has_method("get_instances_by_card_id"):
				# 裸 card_id 回退：查该卡的所有实例，取第一个（旧存档无序号信息时尽力恢复）
				var _candidates: Array = ir.get_instances_by_card_id(id_val)
				if not _candidates.is_empty():
					restored = ir.get_instance(String(_candidates[0]))
					if restored != null:
						push_warning("[PhaseInstrumentManager] 槽位存档 ID '%s' 是裸 card_id，已回退到首个同名实例 '%s'" % [id_val, restored.instance_id])
			# v7.x 修复（Bug1）：实例查不到时，重建并注册新实例（而非对带 #序号 的 instance_id 查 get_card_by_id 必失败，
			# 导致槽位回退无养成模板或留空）。根因：势力卡裸 card_id / 旧档迁移 / load_state 模板查不到静默跳过 等场景 Registry 缺失该实例。
			# v7.x 重复修复：原逻辑无脑 create_instance 新建实例（如 omega_platform#2），导致 Registry 多出同名实例，
			# 成长面板显示重复。改为：先用 _base_id 查同名实例复用，只有该 card_id 一个实例都没有时才新建。
			if restored == null and ir != null and ir.has_method("get_card_id_of"):
				var _base_id: String = ir.get_card_id_of(id_val)  # cold_t72#1 → cold_t72（无序号返回原值）
				if not _base_id.is_empty():
					# 优先复用已有的同名实例（避免多建，如槽位存 omega_platform#1 但 Registry 只剩 omega_platform#2）
					if ir.has_method("get_instances_by_card_id"):
						var _existing: Array = ir.get_instances_by_card_id(_base_id)
						if not _existing.is_empty():
							restored = ir.get_instance(String(_existing[0]))
							if restored != null:
								push_warning("[PhaseInstrumentManager] 槽位存档 ID '%s' 的实例缺失，已复用同名实例 '%s'" % [id_val, restored.instance_id])
					# 该 card_id 一个实例都没有 → 才新建（首次获得该卡/旧档完全无此实例）
					if restored == null and ir.has_method("create_instance"):
						restored = ir.create_instance(_base_id)
						if restored != null:
							push_warning("[PhaseInstrumentManager] 槽位存档 ID '%s' 找不到任何同名实例，已新建实例 '%s'（养成从0开始）" % [id_val, restored.instance_id])
			if restored == null:
				restored = _get_default_cards().get_card_by_id(id_val)
				if restored != null:
					# 明确告警：槽位持有的是无养成的模板（非实例），便于发现真实断裂点
					push_warning("[PhaseInstrumentManager] 槽位存档 ID '%s' 找不到实例，回退到模板（无强化/改造数据）" % id_val)
			arr[i] = restored
		instrument_slots[color] = arr

	_emit_slots_changed()

## v7.x: 旧存档能量卡清理补偿
## 能量卡系统移除后，旧存档槽位/背包里的 energy_start_* 卡被清理，按星级补偿纳米材料。
## 补偿规则：nano_materials += 100 + star × 50（1星=150，7星=450）
## 每张卡只补偿一次（用 _compensated_energy_cards 集合去重，防多槽位同卡重复补偿）
var _compensated_energy_cards: Dictionary = {}  # card_id(instance级) → true
func _compensate_removed_energy_card(base_card_id: String) -> void:
	if _compensated_energy_cards.has(base_card_id):
		return
	_compensated_energy_cards[base_card_id] = true
	# 从卡ID解析星级（energy_start_1~7 → 1~7）
	var star: int = 1
	var suffix := base_card_id.substr("energy_start_".length())
	if suffix.is_valid_int():
		star = clampi(int(suffix), 1, 7)
	var comp: int = 100 + star * 50
	if BasicResourceManager and BasicResourceManager.has_method("add_resource"):
		BasicResourceManager.add_resource("nano_materials", comp)
	if SignalBus and SignalBus.has_signal("show_toast"):
		SignalBus.show_toast.emit("能量卡系统已移除，%s 补偿 %d 纳米材料" % [base_card_id, comp])

## v7.x: 遍历 InstanceRegistry，清理所有 energy_start_* 实例（背包残留）并逐个补偿。
## 用 _compensated_energy_cards 去重（槽位守卫可能已补偿过同卡），避免重复发奖。
func _cleanup_removed_energy_card_instances() -> void:
	var ir: Node = get_node_or_null("/root/InstanceRegistry")
	if ir == null or not ir.has_method("get_all_instance_ids"):
		return
	if not ir.has_method("dispose_instance") or not ir.has_method("get_card_id_of"):
		return
	var all_ids: Array = ir.get_all_instance_ids()
	var to_remove: Array = []
	for iid in all_ids:
		var base_id: String = ir.get_card_id_of(String(iid))
		if base_id.begins_with("energy_start_"):
			to_remove.append(String(iid))
	for iid in to_remove:
		ir.dispose_instance(iid)
		# 补偿（去重：_compensated_energy_cards 按卡种记录，同种只补一次
		# —— 但背包里可能有多张同名卡实例，应每张都补偿，所以用 instance_id 作 key）
		if not _compensated_energy_cards.has(iid):
			_compensated_energy_cards[iid] = true
			var base_id: String = ir.get_card_id_of(iid)
			var star: int = 1
			var suffix := base_id.substr("energy_start_".length())
			if suffix.is_valid_int():
				star = clampi(int(suffix), 1, 7)
			var comp: int = 100 + star * 50
			if BasicResourceManager and BasicResourceManager.has_method("add_resource"):
				BasicResourceManager.add_resource("nano_materials", comp)
	# 通知背包刷新（能量卡实例被移除）
	if not to_remove.is_empty() and SignalBus and SignalBus.has_signal("backpack_changed"):
		SignalBus.backpack_changed.emit()

func clear_slots_for_new_game() -> void:
	unlocked_instrument_ids.clear()
	_init_unlocked_instruments()
	_set_default_instrument_if_needed()
	_rebuild_slots()
	phase_field_xp = 0
	unspent_phase_field_points = 0
	phase_field_allocations.clear()
	# 新游戏自动装备初始卡牌，避免进入战斗后所有槽位为空无法部署
	_equip_starter_cards_for_new_game()
	_emit_slots_changed()

## 新游戏自动装备一套初始卡牌到空槽位
## 绿色槽：放入初始平台卡（一战时代 FT-17，与第1关主题匹配）；黄色槽：放入初始能量卡
## 注：原配置用 omega_platform（近未来终极单位）+ energy_start_4（20星 +2100能量上限），
## 是开发期演示残留——新手开局拿到后期最强单位+海量能量，第1关毫无难度且与一战关卡主题错配。
## 改为 FT-17（一战坦克）+ energy_start_1（5星 +500能量上限），让新手体验正常的养成曲线。
func _equip_starter_cards_for_new_game() -> void:
	# v7.0: 初始卡也实例化（独立 instance_id + 养成数据），不污染 DefaultCards 模板
	var ir: Node = get_node_or_null("/root/InstanceRegistry")
	# 绿色槽：填入一战初始平台卡（FT-17 轻型坦克，era=0 一战）
	var green_arr: Array = instrument_slots.get("green", [])
	if not green_arr.is_empty():
		for i in range(green_arr.size()):
			if green_arr[i] == null:
				var starter_platform: CardResource = null
				if ir != null and ir.has_method("create_instance"):
					starter_platform = ir.create_instance("ww1_ft17")
				else:
					var tpl: CardResource = _get_default_cards().get_card_by_id("ww1_ft17")
					starter_platform = tpl.clone() if tpl != null else null
				if starter_platform != null:
					green_arr[i] = starter_platform
	instrument_slots["green"] = green_arr

	# v7.x: 黄色能量槽已移除（能量卡系统移除），不再装备初始能量卡。
	# 能量上限改由相位仪星级决定（见 EnergyManager._apply_instrument_energy）。

	# [LOG-v5.1] print("[PhaseInstrumentManager] 新游戏初始卡牌已自动装备")

func save_state() -> Dictionary:
	var runtime_defs: Dictionary = {}
	for iid in _runtime_instrument_defs.keys():
		runtime_defs[String(iid)] = (_runtime_instrument_defs[iid] as Dictionary).duplicate(true)
	return {
		"phase_field_xp": phase_field_xp,
		"phase_xp": phase_field_xp, # 旧键兼容
		"unspent_phase_field_points": unspent_phase_field_points,
		"phase_field_allocations": phase_field_allocations.duplicate(true),
		"selected_instrument_id": selected_instrument_id,
		"unlocked_instrument_ids": unlocked_instrument_ids.duplicate(),
		"slot_card_ids": get_slot_card_ids(),
		"runtime_instrument_defs": runtime_defs,
		"drop_serial_counter": _drop_serial_counter,
		# v6.2: 符文系统状态
		"rune_state": save_rune_state(),
	}

func load_state(data: Dictionary) -> void:
	phase_field_xp = int(data.get("phase_field_xp", data.get("phase_xp", 0)))
	unspent_phase_field_points = int(data.get("unspent_phase_field_points", 0))
	phase_field_allocations = data.get("phase_field_allocations", {})
	if not (phase_field_allocations is Dictionary):
		phase_field_allocations = {}
	_runtime_instrument_defs.clear()
	var runtime_defs_raw: Dictionary = data.get("runtime_instrument_defs", {})
	if runtime_defs_raw is Dictionary:
		for iid in runtime_defs_raw.keys():
			var cfg: Variant = runtime_defs_raw[iid]
			if cfg is Dictionary:
				register_runtime_instrument(cfg as Dictionary, false)
	_drop_serial_counter = int(data.get("drop_serial_counter", 0))
	unlocked_instrument_ids.clear()
	for id_raw in data.get("unlocked_instrument_ids", []):
		var iid: String = String(id_raw)
		if not iid.is_empty() and not unlocked_instrument_ids.has(iid):
			unlocked_instrument_ids.append(iid)
	_init_unlocked_instruments()
	var new_id: String = String(data.get("selected_instrument_id", PhaseInstruments.get_default_id()))
	if not has_unlocked_instrument(new_id):
		new_id = PhaseInstruments.get_default_id()
	var changed: bool = (new_id != selected_instrument_id)
	selected_instrument_id = new_id
	if changed or instrument_slots.is_empty():
		_rebuild_slots()
	# 在 load_state 内部恢复槽位卡牌，消除两步加载时序依赖
	if data.has("slot_card_ids") and data["slot_card_ids"] is Array:
		set_slots_from_card_ids(data["slot_card_ids"])
	else:
		# 新游戏（空数据）或旧存档缺少 slot_card_ids：自动装备初始卡牌
		_equip_starter_cards_for_new_game()
	# v6.2: 恢复符文系统状态（旧存档无此字段时为空，新游戏从0开始）
	var rune_state: Variant = data.get("rune_state", {})
	if rune_state is Dictionary:
		load_rune_state(rune_state)
	# v7.x: 能量卡系统移除——清理 Registry 里所有 energy_start_* 实例（背包残留）并补偿纳米材料。
	# 槽位里的能量卡已由 set_slots_from_card_ids 守卫处理；此处清理背包里的实例。
	_cleanup_removed_energy_card_instances()

func _emit_slots_changed() -> void:
	_mark_loadouts_dirty()
	SignalBus.phase_slots_changed.emit(get_slots())

func _card_type_name(card: CardResource) -> String:
	match card.card_type:
		GC.CardType.COMBAT_UNIT: return "platform"
		GC.CardType.ENERGY: return "energy"
		GC.CardType.LAW: return "law"
	return "unknown"

func get_current_instrument() -> Dictionary:
	_set_default_instrument_if_needed()
	var cfg: Dictionary = _resolve_instrument_cfg(selected_instrument_id)
	if cfg.is_empty():
		return cfg
	var copy_cfg: Dictionary = cfg.duplicate(true)
	copy_cfg["properties"] = _ensure_properties_with_legacy_fallback(copy_cfg)
	return copy_cfg

## v6.6: 获取当前相位仪的主动特殊能力（active_ability）
## 返回 {} 表示无主动能力。供 PhaseInstrumentAbilities 和 passive 消费方查询。
func get_active_ability() -> Dictionary:
	var cfg: Dictionary = get_current_instrument()
	return cfg.get("active_ability", {})

func get_all_instruments() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for d in PhaseInstruments.get_all():
		if d is Dictionary:
			var c: Dictionary = (d as Dictionary).duplicate(true)
			c["properties"] = _ensure_properties_with_legacy_fallback(c)
			out.append(c)
	for rid in _runtime_instrument_defs.keys():
		var rcfg: Dictionary = (_runtime_instrument_defs[rid] as Dictionary).duplicate(true)
		rcfg["properties"] = _ensure_properties_with_legacy_fallback(rcfg)
		out.append(rcfg)
	return out

func equip_instrument(instrument_id: String) -> bool:
	var cfg: Dictionary = _resolve_instrument_cfg(instrument_id)
	if cfg.is_empty():
		return false
	if not has_unlocked_instrument(instrument_id):
		return false
	# 切换前先归还所有已装备卡到背包，防止槽位减少时卡被静默丢弃
	unequip_all_and_return_to_backpack()
	selected_instrument_id = instrument_id
	_rebuild_slots()
	_emit_slots_changed()
	return true

func has_unlocked_instrument(instrument_id: String) -> bool:
	if instrument_id.is_empty():
		return false
	var cfg: Dictionary = _resolve_instrument_cfg(instrument_id)
	if cfg.is_empty():
		return false
	if bool(cfg.get("is_generic", false)):
		return true
	return unlocked_instrument_ids.has(instrument_id)

func unlock_instrument(instrument_id: String) -> bool:
	var cfg: Dictionary = _resolve_instrument_cfg(instrument_id)
	if cfg.is_empty():
		return false
	if has_unlocked_instrument(instrument_id):
		return true
	unlocked_instrument_ids.append(instrument_id)
	return true

func get_unlocked_instrument_ids() -> Array[String]:
	return unlocked_instrument_ids.duplicate()

func get_highest_unlocked_instrument() -> Dictionary:
	var best: Dictionary = {}
	var best_star: int = -1
	for iid in unlocked_instrument_ids:
		var cfg: Dictionary = _resolve_instrument_cfg(String(iid))
		if cfg.is_empty():
			continue
		var s: int = int(cfg.get("star", 0))
		if s > best_star:
			best_star = s
			best = cfg
	return best

func get_slot_layout() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var active_laws: Array = []
	var passive_laws: Array = []
	_ensure_plm()
	if _plm and "equipped_active_laws" in _plm:
		active_laws = _plm.equipped_active_laws
	if _plm and "equipped_passive_laws" in _plm:
		passive_laws = _plm.equipped_passive_laws
	var active_idx: int = 0
	var passive_idx: int = 0
	for color in SLOT_COLOR_ORDER:
		var arr: Array = instrument_slots.get(color, [])
		for i in range(arr.size()):
			# v6.2: rune 槽位存的是 rune_id (String)，四色槽存的是 CardResource，
			# 因此 slot_card 不能用 CardResource 类型注解，否则 rune 槽赋值时会抛
			# "Trying to assign a non-object value to a variable of type 'card_resource.gd'"。
			var slot_card: Variant = arr[i]
			var e := {"color": color, "index": i, "card": slot_card, "law_id": "", "law_kind": ""}
			if color == "red":
				var from_card: String = _law_id_from_card(slot_card)
				if not from_card.is_empty():
					e["law_id"] = from_card
					e["law_kind"] = "active"
				elif active_idx < active_laws.size():
					e["law_id"] = String(active_laws[active_idx])
					e["law_kind"] = "active"
				active_idx += 1
			elif color == "blue":
				var from_card_b: String = _law_id_from_card(slot_card)
				if not from_card_b.is_empty():
					e["law_id"] = from_card_b
					e["law_kind"] = "passive"
				elif passive_idx < passive_laws.size():
					e["law_id"] = String(passive_laws[passive_idx])
					e["law_kind"] = "passive"
				passive_idx += 1
			elif color == "rune":
				# v6.2: rune 槽位存的是 rune_id (String)，不是 CardResource
				e["rune_id"] = str(slot_card) if slot_card != null else ""
			out.append(e)
	return out

## v7.x: 移除 get_energy_output_rate()（半失效死代码，battle_spawn 的 deploy_time 从未被使用）
## 能量恢复速率：base（按star派生）× 3，再叠加 phase_field 的"能量恢复"点数加成
func get_energy_recovery_rate() -> float:
	var cfg: Dictionary = get_current_instrument()
	var base_rate: float = float(cfg.get("energy_recovery_rate", 0.35))
	var phase_field_bonus: Dictionary = get_phase_field_total_bonus()
	# phase_field 的 energy_output_pct 点数（存档兼容 key）现在提升能量恢复
	var recovery_bonus: float = float(phase_field_bonus.get("energy_output_pct", 0.0))
	return base_rate * (1.0 + recovery_bonus) * 3.0  # 能量获得速度乘上3

func get_spawn_range_ratio() -> float:
	var cfg: Dictionary = get_current_instrument()
	return maxf(0.1, float(cfg.get("spawn_range_ratio", 0.3)) + _get_property_value(cfg, "pi_deploy_range", 0.0))

func get_instrument_property_entries() -> Array:
	var cfg: Dictionary = get_current_instrument()
	return _ensure_properties_with_legacy_fallback(cfg)

func register_runtime_instrument(cfg: Dictionary, auto_unlock: bool = true) -> String:
	var iid: String = String(cfg.get("id", ""))
	if iid.is_empty():
		return ""
	var normalized: Dictionary = cfg.duplicate(true)
	normalized["properties"] = _ensure_properties_with_legacy_fallback(normalized)
	_runtime_instrument_defs[iid] = normalized
	if auto_unlock and not unlocked_instrument_ids.has(iid):
		unlocked_instrument_ids.append(iid)
	return iid

func _pick_random_from_pool(pool: Array, used_ids: Dictionary, min_star: int = 1) -> Dictionary:
	var candidates: Array[Dictionary] = []
	for d in pool:
		if not (d is Dictionary):
			continue
		var dd: Dictionary = d
		var pid: String = String(dd.get("id", ""))
		if pid.is_empty() or used_ids.has(pid):
			continue
		if int(dd.get("min_star", 1)) > min_star:
			continue
		candidates.append(dd)
	if candidates.is_empty():
		return {}
	return candidates[randi() % candidates.size()]

func _roll_rare_count(star: int) -> int:
	if star <= 2:
		return 0
	if star <= 4:
		return 1
	if star <= 6:
		return 1 if randf() < 0.6 else 2
	return 2 if randf() < 0.65 else 3

func _roll_rare_rarity(star: int) -> String:
	var roll: float = randf()
	if star <= 4:
		return "Rare" if roll < 0.5 else "Epic"
	if star <= 6:
		if roll < 0.4:
			return "Rare"
		if roll < 0.8:
			return "Epic"
		return "Legendary"
	if roll < 0.3:
		return "Rare"
	if roll < 0.7:
		return "Epic"
	return "Legendary"

func _pick_rare_property(star: int, used_ids: Dictionary, rarity: String) -> Dictionary:
	var candidates: Array[Dictionary] = []
	for d in PhaseInstruments.RARE_PROPERTY_POOL:
		if not (d is Dictionary):
			continue
		var dd: Dictionary = d
		var pid: String = String(dd.get("id", ""))
		if pid.is_empty() or used_ids.has(pid):
			continue
		if int(dd.get("min_star", 1)) > star:
			continue
		if String(dd.get("rarity", "")) != rarity:
			continue
		candidates.append(dd)
	if candidates.is_empty():
		return _pick_random_from_pool(PhaseInstruments.RARE_PROPERTY_POOL, used_ids, star)
	return candidates[randi() % candidates.size()]

func _roll_drop_star_by_progress() -> int:
	var gm: Node = get_node_or_null("/root/GameManager")
	var level: int = 1
	if gm != null and "current_level" in gm:
		level = maxi(1, int(gm.current_level))
	var center: int = clampi(1 + int(level / 3), 1, 7)
	var weighted: Array[int] = []
	for s in range(1, 8):
		var dist: int = absi(s - center)
		var weight: int = maxi(1, 6 - dist * 2)
		for _i in range(weight):
			weighted.append(s)
	if weighted.is_empty():
		return clampi(center, 1, 7)
	return weighted[randi() % weighted.size()]

func create_drop_instrument(base_id: String, star: int = -1, serial: int = 0) -> Dictionary:
	var base_cfg: Dictionary = PhaseInstruments.get_by_id(base_id)
	if base_cfg.is_empty():
		return {}
	var s: int = star
	if s < 1:
		s = _roll_drop_star_by_progress()
	s = clampi(s, 1, 7)
	var out: Dictionary = base_cfg.duplicate(true)
	out["star"] = s
	out["source"] = PhaseInstruments.SOURCE_DROP
	out["base_id"] = base_id
	var sid: String = "%03d" % maxi(1, serial)
	out["id"] = "pi_drop_%s_%d_%s" % [base_id, s, sid]
	out["name"] = "%s (掉落)" % String(base_cfg.get("name", "相位仪"))
	var used_ids: Dictionary = {}
	var props: Array[Dictionary] = []
	var rare_count: int = mini(_roll_rare_count(s), s)
	for _i in range(rare_count):
		var rare_rarity: String = _roll_rare_rarity(s)
		var rp: Dictionary = _pick_rare_property(s, used_ids, rare_rarity)
		if rp.is_empty():
			continue
		var rpid: String = String(rp.get("id", ""))
		used_ids[rpid] = true
		props.append({"id": rpid, "value": 1.0, "display": PhaseInstruments.build_property_display(rpid, 1.0), "rarity": String(rp.get("rarity", "Rare"))})
	while props.size() < s:
		var sp: Dictionary = _pick_random_from_pool(PhaseInstruments.STANDARD_PROPERTY_POOL, used_ids, s)
		if sp.is_empty():
			break
		var pid: String = String(sp.get("id", ""))
		used_ids[pid] = true
		var val: float = PhaseInstruments.get_standard_property_value(pid, s, PhaseInstruments.SOURCE_DROP)
		props.append({"id": pid, "value": val, "display": PhaseInstruments.build_property_display(pid, val), "rarity": String(sp.get("rarity", "Common"))})
	out["properties"] = props
	return out

func try_roll_battle_drop_instrument(base_drop_rate: float = 0.4, enemy_star_bonus: int = 0, preferred_base_id: String = "") -> Dictionary:
	var chance: float = clampf(base_drop_rate + float(maxi(enemy_star_bonus, 0)) * 0.1, 0.0, 1.0)
	if randf() > chance:
		return {}
	var all_defs: Array[Dictionary] = PhaseInstruments.get_all()
	if all_defs.is_empty():
		return {}
	var base_id: String = preferred_base_id
	if base_id.is_empty():
		var chosen: Dictionary = all_defs[randi() % all_defs.size()]
		base_id = String(chosen.get("id", ""))
	_drop_serial_counter += 1
	var drop_cfg: Dictionary = create_drop_instrument(base_id, -1, _drop_serial_counter)
	if drop_cfg.is_empty():
		return {}
	register_runtime_instrument(drop_cfg, true)
	return drop_cfg

func _flat_index_to_slot(slot_index: int) -> Dictionary:
	var ptr: int = 0
	for color in SLOT_COLOR_ORDER:
		var arr: Array = instrument_slots.get(color, [])
		for i in range(arr.size()):
			if ptr == slot_index:
				return {"color": color, "index": i}
			ptr += 1
	return {}

## 根据 color + color_index 反算扁平索引，失败返回 -1
func _slot_to_flat_index(color: String, color_index: int) -> int:
	var ptr: int = 0
	for c in SLOT_COLOR_ORDER:
		var arr: Array = instrument_slots.get(c, [])
		for i in range(arr.size()):
			if c == color and i == color_index:
				return ptr
			ptr += 1
	return -1

func _can_equip_card_to_color(card: CardResource, color: String) -> bool:
	if color == "green":
		return card.card_type == GC.CardType.COMBAT_UNIT
	# v7.x: yellow 能量槽已移除（能量卡系统移除），不再接受任何卡
	if color == "yellow":
		return false
	if color == "red" or color == "blue":
		if card.card_type != GC.CardType.LAW:
			return false
		var lid: String = _law_id_from_card(card)
		if lid.is_empty():
			return false
		var law: Dictionary = PhaseLaws.get_by_id(lid)
		if law.is_empty():
			return false
		var kind: String = String(law.get("kind", ""))
		if color == "red":
			return kind == "active"
		return kind == "passive"
	return false

func get_card_by_id(card_id: String) -> CardResource:
	return _get_default_cards().get_card_by_id(card_id)

## 获取当前相位仪的最大单位上场数量（基于绿色槽位数量）
## 绿色槽位数量直接决定可上场的平台卡数量
func get_max_deployable_units() -> int:
	var cfg: Dictionary = get_current_instrument()
	var slot_counts: Dictionary = cfg.get("slot_counts", {})
	var green_slots: int = int(slot_counts.get("green", 1))
	# 绿色槽位数量 = 可上场的平台卡数量
	return clampi(green_slots, 1, GC.PLAYER_MAX_UNITS)

## 获取当前相位仪的绿色槽位数量
func get_green_slot_count() -> int:
	var cfg: Dictionary = get_current_instrument()
	var slot_counts: Dictionary = cfg.get("slot_counts", {})
	return int(slot_counts.get("green", 1))


# ═══════════════════════════════════════════════════════════════════
# v6.2 符文槽位管理系统
# ═══════════════════════════════════════════════════════════════════
# 符文槽位与四色槽位完全独立：
#   - 战斗卡槽位(green)：仅放战斗单位卡
#   - 能量卡槽位(yellow)：仅放能量卡
#   - 符文槽位(rune)：仅放符文（rune_id 字符串）
# 三类槽位严格隔离，不可混装。

## 获取当前相位仪的符文槽位数量
func get_rune_slot_count() -> int:
	var cfg: Dictionary = get_current_instrument()
	# 优先使用 rune_slot_count 字段，回退到 slot_counts.rune
	if cfg.has("rune_slot_count"):
		return int(cfg["rune_slot_count"])
	var slot_counts: Dictionary = cfg.get("slot_counts", {})
	return int(slot_counts.get("rune", 1))

## 获取当前符文槽位内容（Array[String | null]）
func get_rune_slots() -> Array:
	return _rune_slots.duplicate()

## 获取指定索引符文槽位的符文ID（空槽返回""）
func get_rune_at(slot_index: int) -> String:
	if slot_index < 0 or slot_index >= _rune_slots.size():
		return ""
	var v = _rune_slots[slot_index]
	if v == null:
		return ""
	return str(v)

## 初始化符文槽位（按当前相位仪的 rune_slot_count 重建空槽）
## 在 _rebuild_slots() 或切换相位仪时调用
func _rebuild_rune_slots() -> void:
	var count := get_rune_slot_count()
	# 保留已装备的符文，超出的回收，不足的补空
	var new_slots: Array = []
	for i in range(count):
		if i < _rune_slots.size() and _rune_slots[i] != null and _rune_slots[i] != "":
			new_slots.append(_rune_slots[i])
		else:
			new_slots.append(null)
	_rune_slots = new_slots
	_sync_rune_to_instrument_slots()
	_mark_rune_bonus_dirty()

## v6.2: 把 _rune_slots 同步到 instrument_slots["rune"]，供 get_slot_layout 统一输出
func _sync_rune_to_instrument_slots() -> void:
	var rune_arr: Array = []
	for v in _rune_slots:
		rune_arr.append(v)
	# 确保数组长度等于 rune_slot_count
	var target_count: int = get_rune_slot_count()
	while rune_arr.size() < target_count:
		rune_arr.append(null)
	instrument_slots["rune"] = rune_arr

## 装备符文到指定槽位
## 返回 true 表示成功，false 表示槽位越界或符文ID无效
func equip_rune(slot_index: int, rune_id: String) -> bool:
	if slot_index < 0 or slot_index >= get_rune_slot_count():
		push_warning("[PhaseInstrumentManager] 符文槽位越界: %d" % slot_index)
		return false
	if not _owned_runes.has(rune_id):
		push_warning("[PhaseInstrumentManager] 未拥有的符文: %s" % rune_id)
		return false
	# 如果符文已在其他槽位，先从原槽位移除（同一符文不能重复装备）
	for i in range(_rune_slots.size()):
		if _rune_slots[i] == rune_id and i != slot_index:
			_rune_slots[i] = null
	# 写入新槽位
	while _rune_slots.size() <= slot_index:
		_rune_slots.append(null)
	_rune_slots[slot_index] = rune_id
	# v6.2: 同步到 instrument_slots["rune"] 供 get_slot_layout 使用
	_sync_rune_to_instrument_slots()
	_mark_rune_bonus_dirty()
	# 注意：phase_slots_changed 信号声明为 (slots: Array)，emit 必须传参，
	# 否则 Godot 4.5 运行时会抛 "emit failed: expected 1 argument" 错误，
	# 导致 equip_rune 在写入数据后异常中断、UI 不刷新（表现为符文装备不上）。
	SignalBus.phase_slots_changed.emit(get_slots())
	return true

## 卸下指定槽位的符文（符文保留在已拥有列表中，只是从槽位移除）
func unequip_rune(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= _rune_slots.size():
		return
	_rune_slots[slot_index] = null
	_sync_rune_to_instrument_slots()
	_mark_rune_bonus_dirty()
	SignalBus.phase_slots_changed.emit(get_slots())

## 卸下所有符文（保留所有权）
func unequip_all_runes() -> void:
	for i in range(_rune_slots.size()):
		_rune_slots[i] = null
	_sync_rune_to_instrument_slots()
	_mark_rune_bonus_dirty()
	SignalBus.phase_slots_changed.emit(get_slots())

## 添加符文到玩家持有列表（去重）
## 返回 true 表示新获得，false 表示已拥有
func add_owned_rune(rune_id: String) -> bool:
	if not _owned_runes.has(rune_id):
		_owned_runes.append(rune_id)
		SignalBus.rune_acquired.emit(rune_id, "acquired")
		return true
	return false

## 移除玩家持有的符文（同时从槽位卸下）
func remove_owned_rune(rune_id: String) -> void:
	_owned_runes.erase(rune_id)
	for i in range(_rune_slots.size()):
		if _rune_slots[i] == rune_id:
			_rune_slots[i] = null
	_mark_rune_bonus_dirty()
	SignalBus.phase_slots_changed.emit(get_slots())

## 玩家是否拥有某符文
func has_rune(rune_id: String) -> bool:
	return _owned_runes.has(rune_id)

## 获取玩家持有的所有符文ID
func get_owned_runes() -> Array[String]:
	return _owned_runes.duplicate()

# ── 符文之语加成（缓存机制） ──────────────────────────────────────

func _mark_rune_bonus_dirty() -> void:
	_rune_bonus_dirty = true

## 刷新缓存的符文加成
## v6.2: 同时累加每个已装备符文的基础加成（primary_effect/secondary_effect），
## 这样即使没凑齐符文之语组合，单个符文也有加成显示。
## v6.2b: 分开存储单符文加成和符文之语加成，符文之语附带名称
func _refresh_rune_bonus() -> void:
	var slot_count := get_rune_slot_count()
	var matched := RunewordMatcher.check_active_runewords(_rune_slots, slot_count)
	_cached_active_runewords = matched
	# ── 单符文加成 ──
	var rune_stats: Dictionary = {}
	var rune_specials: Array = []
	for slot_v in _rune_slots:
		if slot_v == null:
			continue
		var rune_id: String = str(slot_v)
		if rune_id.is_empty():
			continue
		var rune_def: Dictionary = RuneDefs.get_rune(rune_id)
		if rune_def.is_empty():
			continue
		_merge_rune_effect(rune_def.get("primary_effect", {}), rune_stats, rune_specials)
		_merge_rune_effect(rune_def.get("secondary_effect", null), rune_stats, rune_specials)
	# ── 符文之语加成（每个符文之语独立存储，含名称） ──
	var runeword_bonuses: Array = []
	var rw_stats: Dictionary = {}
	var rw_specials: Array = []
	for rw in matched:
		var rw_id: String = String(rw.get("id", ""))
		var rw_name: String = String(RunewordDefinitions.RUNEWORD_NAMES.get(rw_id, rw_id))
		var rw_eff_stats: Dictionary = {}
		var rw_eff_specials: Array = []
		for eff in rw.get("effects", []):
			_merge_rune_effect(eff, rw_eff_stats, rw_eff_specials)
			_merge_rune_effect(eff, rw_stats, rw_specials)
		runeword_bonuses.append({
			"id": rw_id,
			"name": rw_name,
			"stats": rw_eff_stats,
			"specials": rw_eff_specials,
		})
	# ── 合并总数（向后兼容 get_rune_bonus） ──
	var merged_stats: Dictionary = {}
	var merged_specials: Array = []
	_merge_dict_into(rune_stats, merged_stats)
	_merge_dict_into(rw_stats, merged_stats)
	for sp in rune_specials:
		merged_specials.append(sp)
	for sp in rw_specials:
		merged_specials.append(sp)
	_cached_rune_bonus = {
		"stats": merged_stats,
		"specials": merged_specials,
		"rune_stats": rune_stats,
		"rune_specials": rune_specials,
		"runeword_bonuses": runeword_bonuses,
	}
	_rune_bonus_dirty = false

## 把 src 字典的数值累加到 dst
func _merge_dict_into(src: Dictionary, dst: Dictionary) -> void:
	for key in src.keys():
		dst[key] = float(dst.get(key, 0.0)) + float(src[key])

## 把单个符文的 effect 累加到 stats/specials
## effect 结构：{"stat": "attack", "value": 0.15}（数值类）
##           或 {"stat": "on_kill_regen_energy", "chance": 0.3, "value": 50}（特殊类）
func _merge_rune_effect(effect: Variant, stats: Dictionary, specials: Array) -> void:
	if effect == null or not (effect is Dictionary):
		return
	var eff: Dictionary = effect
	var stat_key: String = String(eff.get("stat", ""))
	if stat_key.is_empty():
		return
	# 特殊类：stat 以 on_ 开头（如 on_kill_regen_energy）
	if stat_key.begins_with("on_"):
		specials.append({
			"special": stat_key,
			"chance": float(eff.get("chance", 1.0)),
			"value": eff.get("value", 0),
		})
	else:
		# 数值类：累加 value
		var val: float = float(eff.get("value", 0.0))
		if val != 0.0:
			stats[stat_key] = float(stats.get(stat_key, 0.0)) + val

## 获取当前激活的符文之语加成
## 返回：{"stats": {attack: 0.5, hp: 0.3, ...}, "specials": [...]}
func get_rune_bonus() -> Dictionary:
	if _rune_bonus_dirty:
		_refresh_rune_bonus()
	return _cached_rune_bonus

## 获取当前激活的符文之语列表
## 返回：Array[Dictionary] 每项为符文之语定义
func get_active_runewords() -> Array:
	if _rune_bonus_dirty:
		_refresh_rune_bonus()
	return _cached_active_runewords

## v6.2: 汇总所有加成来源，供 UI（tooltip/统计行/HUD）统一显示
## 返回结构：
##   {
##     "instrument_props": ["卡牌伤害 +6%", ...],        # 相位仪固有属性（已格式化字符串）
##     "phase_field": {"atk_pct": 0.10, ...},            # 相位场属性点加成（原始小数，key 同 PHASE_FIELD_GROWTH_RULES）
##     "phase_field_labels": {"atk_pct": "攻击", ...},   # 相位场 key→中文 label
##     "rune_stats": {"attack": 0.15, ...},              # 符文之语数值加成（原始小数）
##     "rune_specials": [{"special":"on_kill_regen_energy","chance":0.3,"value":50}, ...],  # 符文特殊效果
##     "has_any": bool,                                   # 是否有任何加成（用于决定是否显示面板）
##   }
func get_all_bonus_summary() -> Dictionary:
	var summary: Dictionary = {}
	# 1. 相位仪固有属性（复用 get_instrument_property_entries，已是格式化字符串）
	var prop_entries: Array = get_instrument_property_entries()
	var inst_props: Array[String] = []
	for pe in prop_entries:
		if not (pe is Dictionary):
			continue
		var display: String = String((pe as Dictionary).get("display", ""))
		if not display.is_empty():
			inst_props.append(display)
	summary["instrument_props"] = inst_props
	# 2. 相位场属性点加成
	var pf_bonus: Dictionary = get_phase_field_total_bonus()
	summary["phase_field"] = pf_bonus
	var pf_labels: Dictionary = {}
	for key in pf_bonus.keys():
		var rule: Dictionary = PHASE_FIELD_GROWTH_RULES.get(key, {})
		pf_labels[key] = String(rule.get("label", key))
	summary["phase_field_labels"] = pf_labels
	# 3. 符文加成（v6.2b: 单符文与符文之语分开）
	var rune_bonus: Dictionary = get_rune_bonus()
	# 单符文加成
	summary["rune_stats"] = rune_bonus.get("rune_stats", {})
	summary["rune_specials"] = rune_bonus.get("rune_specials", [])
	# 符文之语加成（含名称，每个独立）
	summary["runeword_bonuses"] = rune_bonus.get("runeword_bonuses", [])
	# 合并总数（向后兼容，部分 UI 仍用合并值）
	summary["rune_total_stats"] = rune_bonus.get("stats", {})
	summary["rune_total_specials"] = rune_bonus.get("specials", [])
	# 4. 是否有任何加成（v6.2c: 补上 runeword_bonuses 判断，避免只激活符文之语时面板被隐藏）
	var rs: Dictionary = rune_bonus.get("rune_stats", {})
	var rws: Dictionary = rune_bonus.get("stats", {})
	var rw_count: int = rune_bonus.get("runeword_bonuses", []).size()
	var has_any: bool = (not inst_props.is_empty()) or (not pf_bonus.is_empty()) or (not rs.is_empty()) or (not rws.is_empty()) or (rw_count > 0)
	summary["has_any"] = has_any
	return summary

# ── 存档支持 ──────────────────────────────────────────────────────

## 序列化符文槽位状态
func save_rune_state() -> Dictionary:
	var slots_serialized: Array = []
	for v in _rune_slots:
		slots_serialized.append(v if v != null else "")
	return {
		"rune_slots": slots_serialized,
		"owned_runes": _owned_runes.duplicate(),
	}

## 从存档恢复符文槽位状态
func load_rune_state(data: Dictionary) -> void:
	var saved_slots: Array = data.get("rune_slots", [])
	_owned_runes = []
	for r in data.get("owned_runes", []):
		_owned_runes.append(str(r))
	# 按 rune_slot_count 重建槽位，载入存档内容
	_rebuild_rune_slots()
	for i in range(mini(saved_slots.size(), _rune_slots.size())):
		var rs: String = str(saved_slots[i])
		if not rs.is_empty():
			_rune_slots[i] = rs
	# 重新同步到 instrument_slots["rune"]（_rebuild_rune_slots 在重建时同步的是空槽）
	_sync_rune_to_instrument_slots()
	_mark_rune_bonus_dirty()
	# 通知 UI 刷新（存档恢复后需要触发 phase_slots_changed 信号）
	_emit_slots_changed()
