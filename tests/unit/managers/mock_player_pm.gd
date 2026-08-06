class_name MockPlayerPm
extends Node
## 测试用 PhaseInstrumentManager 替身（duck-typing，assembler/compute_player_card_power 只调 has_method）
## 提供最小可用的 loadouts/instrument/rune/phase_field 接口，供玩家侧战力链路测试。
## extends Node 而非 RefCounted：MasterPlayerAssembler.evaluate_player_stars(pm: Node)
## 类型标注要求 Node，且 build_player_master_dict 内部会调 is_instance_valid(pm)。

var _loadouts: Array = []
var _instrument: Dictionary = {"id": "pi_test", "star": 5, "name": "测试相位仪"}
var _rune_slots: Array = []
var _active_rw: Array = []
var _phase_bonus: Dictionary = {"hp_pct": 0.20, "atk_pct": 0.15, "def_pct": 0.10}

func set_loadouts(cards: Array) -> void:
	_loadouts.clear()
	for c in cards:
		_loadouts.append({"platform": c, "weapons": []})

func set_instrument_star(star: int) -> void:
	_instrument["star"] = star

func get_loadouts() -> Array:
	return _loadouts

func get_current_instrument() -> Dictionary:
	return _instrument

func get_rune_slots() -> Array:
	return _rune_slots

func get_rune_slot_count() -> int:
	return _rune_slots.size()

func get_active_runewords() -> Array:
	return _active_rw

func get_active_ability() -> Dictionary:
	return {}

func get_phase_field_total_bonus() -> Dictionary:
	return _phase_bonus

## 简化版：按 _phase_bonus 给 stats 加成（真实 pm 逻辑更复杂，此处验证链路通即可）
func apply_phase_field_bonus_to_unit_stats(stats) -> void:
	if stats == null:
		return
	var hp_pct: float = float(_phase_bonus.get("hp_pct", 0.0))
	var atk_pct: float = float(_phase_bonus.get("atk_pct", 0.0))
	var def_pct: float = float(_phase_bonus.get("def_pct", 0.0))
	if hp_pct > 0.0:
		stats.max_hp *= (1.0 + hp_pct)
	if atk_pct > 0.0:
		var m: float = 1.0 + atk_pct
		stats.attack_light *= m
		stats.attack_armor *= m
		stats.attack_air *= m
		stats.attack_damage *= m
	if def_pct > 0.0:
		var dm: float = 1.0 + def_pct
		stats.defense *= dm
		stats.defense_light *= dm
		stats.defense_armor *= dm
		stats.defense_air *= dm

func get_rune_bonus() -> Dictionary:
	return {}
