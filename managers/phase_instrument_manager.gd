extends Node
## 相位仪管理：按相位仪定义动态生成四色槽位

const GC = preload("res://resources/game_constants.gd")
const PhaseInstruments = preload("res://data/phase_instruments.gd")
const PhaseLaws = preload("res://data/phase_laws.gd")
const DefaultCards = preload("res://data/default_cards.gd")
const DEBUG_EQUIP_LOG := false
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

## 与 backpack 扁平索引一致：红→蓝→绿→黄（见 backpack_card_item._calculate_flat_index）
const SLOT_COLOR_ORDER: Array[String] = ["red", "blue", "green", "yellow"]
## 四色槽全量遍历（例如手动卸下全部并返还背包时；战后默认不再自动清空槽位）
const CARD_SLOTS: Array[String] = ["red", "blue", "green", "yellow"]
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
	"energy_output_pct": {"label": "能量输出", "per_point": 0.02, "display_unit": "%"},
}

var phase_field_xp: int = 0
var unspent_phase_field_points: int = 0
var phase_field_allocations: Dictionary = {}
var _loadouts_cache: Array = []
var _loadouts_dirty: bool = true
var _runtime_instrument_defs: Dictionary = {} # instrument_id -> Dictionary
var _drop_serial_counter: int = 0

#region agent log
func _agent_log(hypothesis_id: String, message: String, data: Dictionary) -> void:
	var f := FileAccess.open("F:/godot fair duel/phase-war/debug-585b52.log", FileAccess.WRITE_READ)
	if f == null:
		return
	f.seek_end()
	var payload := {
		"sessionId": "585b52",
		"runId": "equip_slow_v1",
		"hypothesisId": hypothesis_id,
		"location": "phase_instrument_manager.gd",
		"message": message,
		"data": data,
		"timestamp": Time.get_ticks_msec()
	}
	f.store_line(JSON.stringify(payload))
	f.close()
#endregion

func _mark_loadouts_dirty() -> void:
	_loadouts_dirty = true

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
	add_legacy.call("pi_drop", float(cfg.get("drop_bonus", 0.0)))
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
	_init_unlocked_instruments()
	_set_default_instrument_if_needed()
	_rebuild_slots()
	var cfg: Dictionary = get_current_instrument()
	var DebugLog = get_node_or_null("/root/DebugLog")
	if DebugLog:
		DebugLog.agent_log("phase_instrument_manager.gd", "_ready", {
			"selected_instrument_id": selected_instrument_id,
			"selected_name": String(cfg.get("name", "")),
			"selected_star": int(cfg.get("star", -1)),
			"unlocked_count": unlocked_instrument_ids.size(),
			"max_unlocked_star": _get_max_unlocked_star(),
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
	var bonus: Dictionary = get_phase_field_total_bonus()
	var hp_bonus: float = float(bonus.get("hp_pct", 0.0))
	var atk_bonus: float = float(bonus.get("atk_pct", 0.0))
	var def_bonus: float = float(bonus.get("def_pct", 0.0))

	if hp_bonus > 0.0:
		stats.max_hp = maxf(1.0, stats.max_hp * (1.0 + hp_bonus))

	if atk_bonus > 0.0:
		stats.attack_damage = maxf(0.1, stats.attack_damage * (1.0 + atk_bonus))
		for i in range(stats.weapons.size()):
			var w: Variant = stats.weapons[i]
			if not (w is Dictionary):
				continue
			var wd: Dictionary = w
			wd["damage"] = maxf(0.1, float(wd.get("damage", 0.0)) * (1.0 + atk_bonus))
			stats.weapons[i] = wd

	if def_bonus > 0.0:
		stats.damage_reduction = clampf(stats.damage_reduction + def_bonus, 0.0, 0.8)

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
	var DebugLog = get_node_or_null("/root/DebugLog")
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
		var arr: Array = []
		var old_arr: Array = old_slots.get(color, [])
		for i in range(cnt):
			arr.append(old_arr[i] if i < old_arr.size() else null)
		instrument_slots[color] = arr

func _law_id_from_card(card: CardResource) -> String:
	if card == null or card.card_type != GC.CardType.LAW:
		return ""
	var lid: String = card.linked_law_id if not String(card.linked_law_id).is_empty() else card.card_id
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
	if PhaseLawManager == null or not PhaseLawManager.has_method("set_equipped_laws"):
		return false
	# 退出阶段场景树销毁中时，plm 可能已不在树内，调用其内部绝对路径查询会报错
	if not PhaseLawManager.is_inside_tree():
		return false
	var pack: Dictionary = _compact_law_ids_from_current_slots()
	for pid in pack["passives"]:
		if PhaseLawManager.has_method("ensure_law_unlocked"):
			PhaseLawManager.ensure_law_unlocked(String(pid))
	for aid in pack["actives"]:
		if PhaseLawManager.has_method("ensure_law_unlocked"):
			PhaseLawManager.ensure_law_unlocked(String(aid))
	var budget: int = int(PhaseLawManager.battle_nano_budget) if "battle_nano_budget" in PhaseLawManager else 0
	var ok: bool = PhaseLawManager.set_equipped_laws(pack["passives"], pack["actives"], budget)
	if not ok and PhaseLawManager.has_method("force_sync_instrument_law_slots"):
		PhaseLawManager.force_sync_instrument_law_slots(pack["passives"], pack["actives"])
		return true
	return ok


## 开战前调用：以红/蓝槽内法则卡为准，刷新 PhaseLawManager 的装配（和 can_cast 列表一致）
func sync_law_cards_to_phase_law_manager() -> bool:
	return _apply_law_slots_to_plm()

## 旧存档：槽位无法则卡但 PhaseLawManager 仍有装配时，生成槽内卡并同步
func migrate_law_slots_from_phase_law_manager_if_empty() -> void:
	if _has_any_law_card_in_slots():
		return
	var actives: Array = PhaseLawManager.equipped_active_laws if "equipped_active_laws" in PhaseLawManager else []
	var passives: Array = PhaseLawManager.equipped_passive_laws if "equipped_passive_laws" in PhaseLawManager else []
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
		var tmpl: CardResource = DefaultCards.create_law_card_resource(lid)
		if tmpl != null:
			reds[i] = tmpl.clone()
			changed = true
	for i in range(blues.size()):
		if i >= passives.size():
			break
		var lid2: String = String(passives[i])
		if lid2.is_empty():
			continue
		var tmpl2: CardResource = DefaultCards.create_law_card_resource(lid2)
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
		var DebugLog = get_node_or_null("/root/DebugLog")
		if DebugLog:
			DebugLog.agent_log("phase_instrument_manager.gd", "equip_invalid", {
				"slot_index": slot_index,
				"color": color,
				"color_index": color_index,
				"card_null": card == null,
			}, "", "0ec8f5")
		return false
	#region agent log
	_agent_log("H2_equip_manager", "equip_card_entry", {
		"slot_index": slot_index,
		"color": color,
		"color_index": color_index,
		"card_id": card.card_id if card != null else "",
		"card_type": int(card.card_type) if card != null else -1,
		"depth": _recursion_depth,
	})
	#endregion
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
				var DebugLog = get_node_or_null("/root/DebugLog")
				if DebugLog:
					DebugLog.agent_log("phase_instrument_manager.gd", "equip_can_equip_fail", {
				"slot_index": slot_index,
				"color": color,
				"card_id": card.card_id,
				"card_type": int(card.card_type),
			}, "", "0ec8f5")
		return false

	if color == "red" or color == "blue":
		if PhaseLawManager == null or not PhaseLawManager.has_method("set_equipped_laws"):
			return false
		var hyp: Dictionary = _compact_law_ids_from_slots_hypothetical(color, color_index, card)
		for pid in hyp["passives"]:
			if PhaseLawManager.has_method("ensure_law_unlocked"):
				PhaseLawManager.ensure_law_unlocked(String(pid))
		for aid in hyp["actives"]:
			if PhaseLawManager.has_method("ensure_law_unlocked"):
				PhaseLawManager.ensure_law_unlocked(String(aid))
		var budget: int = int(PhaseLawManager.battle_nano_budget) if "battle_nano_budget" in PhaseLawManager else 0
		if not PhaseLawManager.set_equipped_laws(hyp["passives"], hyp["actives"], budget):
			# 相位仪槽位中的法则卡是玩家实体持有卡，优先保证槽位可装配；
			# 若战前规则校验失败，则回退为与槽位强同步（不做环境/纳米/解锁拦截）。
			if PhaseLawManager.has_method("force_sync_instrument_law_slots"):
				PhaseLawManager.force_sync_instrument_law_slots(hyp["passives"], hyp["actives"])
			else:
				print("[PhaseInstrumentManager] 法则槽装配未通过（环境/纳米/解锁）: ", card.display_name)
				return false

	# 装备卡牌到相位仪不消耗能量
	# 只有战斗中使用卡牌才消耗能量
	if DEBUG_EQUIP_LOG:
		print("[PhaseInstrumentManager] 装备卡牌 %s 到槽位 %s (颜色: %s)，不消耗能量" % [card.display_name, slot_index, color])

	var arr: Array = instrument_slots.get(color, [])
	var old_card: CardResource = arr[color_index]
	arr[color_index] = card
	instrument_slots[color] = arr

	if old_card != null:
		SignalBus.card_added_to_backpack.emit(old_card)
	_emit_slots_changed()
	SignalBus.card_equipped.emit(slot_index, card.card_id, _card_type_name(card))
	var DebugLog = get_node_or_null("/root/DebugLog")
	if DebugLog:
		DebugLog.agent_log("phase_instrument_manager.gd", "equip_ok", {
			"slot_index": slot_index,
			"color": color,
			"card_id": card.card_id,
			"energy_cost": int(card.energy_cost),
			"replaced_old_card": old_card != null,
		}, "", "0ec8f5")
	#region agent log
	_agent_log("H2_equip_manager", "equip_card_exit_ok", {
		"slot_index": slot_index,
		"card_id": card.card_id,
		"emit_done": true,
		"elapsed_ms": Time.get_ticks_msec() - _equip_t0,
	})
	#endregion
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
		SignalBus.card_added_to_backpack.emit(card)

## 战斗结束后：清空所有槽位并将卡片逐一放回背包的第一个空位
func unequip_all_and_return_to_backpack() -> void:
	var cards_to_return: Array[CardResource] = []
	for color in CARD_SLOTS:
		var arr: Array = instrument_slots.get(color, [])
		for i in range(arr.size()):
			var c: CardResource = arr[i]
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
			print("[PhaseInstrumentManager] 卡片 %s 已返还背包" % c2.card_id)

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
	for ld in get_loadouts():
		if not (ld is Dictionary):
			continue
		var plat: CardResource = ld.get("platform", null)
		if plat != null and plat.card_id == platform_card_id:
			return ld
	return {}

func get_slot_card_ids() -> Array:
	var ids: Array = []
	for color in SLOT_COLOR_ORDER:
		var arr: Array = instrument_slots.get(color, [])
		for c_raw in arr:
			var c: CardResource = c_raw
			if c == null:
				ids.append("")
				continue
			var cid: String = c.card_id
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
	var ptr: int = 0
	for color in SLOT_COLOR_ORDER:
		var arr: Array = instrument_slots.get(color, [])
		for i in range(arr.size()):
			var id_val: String = ""
			if ptr < card_ids.size() and card_ids[ptr] != null:
				id_val = str(card_ids[ptr])
			ptr += 1
			arr[i] = DefaultCards.get_card_by_id(id_val) if not id_val.is_empty() else null
		instrument_slots[color] = arr

	_emit_slots_changed()

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
## 绿色槽：放入初始平台卡；黄色槽：放入初始能量卡
func _equip_starter_cards_for_new_game() -> void:
	# 绿色槽：尝试填入初始平台卡（omega_platform 是默认解锁的高级蓝图）
	var green_arr: Array = instrument_slots.get("green", [])
	var starter_platform: CardResource = DefaultCards.get_card_by_id("omega_platform")
	if starter_platform != null:
		for i in range(green_arr.size()):
			if green_arr[i] == null:
				green_arr[i] = starter_platform.clone()
	instrument_slots["green"] = green_arr

	# 黄色槽：尝试填入初始能量卡（战前能量 IV 为默认演示档位）
	var yellow_arr: Array = instrument_slots.get("yellow", [])
	var starter_energy: CardResource = DefaultCards.get_card_by_id("energy_start_4")
	if starter_energy != null:
		for i in range(yellow_arr.size()):
			if yellow_arr[i] == null:
				yellow_arr[i] = starter_energy.clone()
	instrument_slots["yellow"] = yellow_arr

	print("[PhaseInstrumentManager] 新游戏初始卡牌已自动装备")

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
	var active_laws: Array = PhaseLawManager.equipped_active_laws if "equipped_active_laws" in PhaseLawManager else []
	var passive_laws: Array = PhaseLawManager.equipped_passive_laws if "equipped_passive_laws" in PhaseLawManager else []
	var active_idx: int = 0
	var passive_idx: int = 0
	for color in SLOT_COLOR_ORDER:
		var arr: Array = instrument_slots.get(color, [])
		for i in range(arr.size()):
			var slot_card: CardResource = arr[i]
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
			out.append(e)
	return out

func get_energy_output_rate() -> float:
	var cfg: Dictionary = get_current_instrument()
	var base_rate: float = float(cfg.get("energy_output_rate", 1.0))
	var phase_field_bonus: Dictionary = get_phase_field_total_bonus()
	var output_bonus: float = float(phase_field_bonus.get("energy_output_pct", 0.0))
	return base_rate * (1.0 + output_bonus) * 5.0  # 能量输出速度乘上5

func get_energy_recovery_rate() -> float:
	var cfg: Dictionary = get_current_instrument()
	var base_rate: float = float(cfg.get("energy_recovery_rate", 0.35))
	return base_rate * 3.0  # 能量获得速度乘上3

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
	if color == "yellow":
		return card.card_type == GC.CardType.ENERGY
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
	return DefaultCards.get_card_by_id(card_id)

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