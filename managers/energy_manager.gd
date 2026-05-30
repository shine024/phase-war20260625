extends Node
## 能量管理：总量由黄色槽决定；战内不可自然回复（仅战后补能）

const GC = preload("res://resources/game_constants.gd")
const BasicResources = preload("res://data/basic_resources.gd")

var current: float = 0.0
var _max: float = GC.ENERGY_MAX
var _base_start: float = GC.ENERGY_START
var _regen_per_sec: float = 0.0
var _in_battle: bool = false

## @deprecated agent log 已迁移到 DebugLogger
func _agent_log(_hypothesis_id: String, _message: String, _data: Dictionary) -> void:
	pass

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	set_process(false)
	_reset_to_start()
	#region agent log
	_agent_log("H2_start_battle_not_called", "_ready", {"current": current, "max": _max, "base_start": _base_start, "regen": _regen_per_sec})
	#endregion

func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not _in_battle:
		return
	# 能量回复：每秒自然回复 = 基础回复 + 能量卡加成 - 相位仪消耗
	var net_regen: float = GC.ENERGY_REGEN_PER_SEC + _regen_per_sec - GC.PHASE_BASE_DRAIN_PER_SEC
	if net_regen > 0.0:
		_add_energy(net_regen * delta)

func start_battle() -> void:
	_apply_equipped_energy_cards()
	_in_battle = true
	set_process(true)
	# 未装黄色能量卡时 _base_start 为 0，会导致主动法则的 battle_cost.energy 永远无法支付
	if _base_start <= 0.0:
		_base_start = GC.ENERGY_START
	# 能量上限由能量卡蓝图星级决定（1级=100, 2级=200, ...7级=700）
	# 未装能量卡时上限为 GC.ENERGY_MAX (100)
	current = clampf(_base_start, 0.0, _max)
	if SignalBus:
		SignalBus.energy_changed.emit(current, _max)
	#region agent log
	_agent_log("H2_start_battle_not_called", "start_battle_emit", {"current": current, "max": _max, "base_start": _base_start, "regen": _regen_per_sec, "in_battle": _in_battle})
	#endregion

func end_battle() -> void:
	_in_battle = false
	set_process(false)
	_auto_recharge_from_energy_blocks()

func _auto_recharge_from_energy_blocks() -> void:
	var missing: int = int(ceil(maxf(0.0, _max - current)))
	if missing <= 0:
		return
	if not BasicResourceManager.has_method("get_total") or not BasicResourceManager.has_method("add_resource"):
		return
	var available: int = int(BasicResourceManager.get_total(BasicResources.ID_ENERGY_BLOCK))
	var spend_blocks: int = mini(available, missing)
	if spend_blocks <= 0:
		return
	BasicResourceManager.add_resource(BasicResources.ID_ENERGY_BLOCK, -spend_blocks)
	current = clampf(current + float(spend_blocks), 0.0, _max)
	if SignalBus:
		SignalBus.energy_changed.emit(current, _max)
	#region agent log
	_agent_log("H4_wrong_energy_source", "auto_recharge_emit", {"spend_blocks": spend_blocks, "current": current, "max": _max})
	#endregion

func _reset_to_start() -> void:
	current = GC.ENERGY_START
	_max = GC.ENERGY_MAX
	_base_start = GC.ENERGY_START

func _apply_equipped_energy_cards() -> void:
	_base_start = 0.0
	_regen_per_sec = 0.0
	_max = GC.ENERGY_MAX  # 默认无卡时上限100
	var slot_count = 0
	var total_energy_star: int = 0
	var energy_card_count: int = 0
	if PhaseInstrumentManager.has_method("get_slots"):
		for c_raw in PhaseInstrumentManager.get_slots():
			if c_raw is CardResource:
				slot_count += 1
				var card: CardResource = c_raw
				if card.card_type != GC.CardType.ENERGY:
					continue
				energy_card_count += 1
				# 读取能量卡蓝图星级，累计叠加决定能量上限
				if BlueprintManager and BlueprintManager.has_method("get_blueprint_star"):
					total_energy_star += BlueprintManager.get_blueprint_star(card.card_id)
				# energy_start_*: 开局能量（唯一能量卡类型）
				if card.card_id.begins_with("energy_start_"):
					_base_start += maxf(0.0, card.energy_grant)
	# 能量上限 = 基础100 + 所有能量卡星级各自×100 求和
	# 例：2级卡(200) + 7级卡(700) + 基础100 = 1000
	if total_energy_star > 0:
		_max = GC.ENERGY_MAX + float(total_energy_star) * 100.0
	# 顶级相位仪（4个以上能量槽）能量回复乘5
	if slot_count >= 4:
		_regen_per_sec *= 5.0
	#region agent log
	_agent_log("H3_apply_equipped_logic_wrong", "_apply_equipped_energy_cards_done", {"slot_count_total": slot_count, "energy_card_count": energy_card_count, "total_energy_star": total_energy_star, "base_start": _base_start, "regen": _regen_per_sec, "max": _max})
	#endregion

func _add_energy(amount: float) -> void:
	current = clampf(current + amount, 0.0, _max)
	if SignalBus:
		SignalBus.energy_changed.emit(current, _max)
	#region agent log
	_agent_log("H1_ui_not_connected", "energy_changed_emit", {"delta": amount, "current": current, "max": _max})
	#endregion

func can_afford(cost: float) -> bool:
	return current >= cost

func spend(cost: float) -> bool:
	if not can_afford(cost):
		if SignalBus:
			SignalBus.energy_insufficient.emit(cost)
		return false
	current -= cost
	current = maxf(0.0, current)
	if SignalBus:
		SignalBus.energy_changed.emit(current, _max)
	return true

func add_energy(amount: float) -> void:
	_add_energy(amount)

func get_current() -> float:
	return current

func get_max() -> float:
	return _max
