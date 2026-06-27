extends Node
## 能量管理：总量由黄色槽决定；战内不可自然回复（仅战后补能）

const GC = preload("res://resources/game_constants.gd")
const BasicResources = preload("res://data/basic_resources.gd")

var current: float = 0.0
var _max: float = GC.ENERGY_MAX
var _base_start: float = GC.ENERGY_START
var _regen_per_sec: float = 0.0
var _in_battle: bool = false
# v7.3 修复 B2: 战后能量块补能的跨战斗结转加成。
# 原 bug：补能写 current，但 start_battle 每次重置 current = clampf(_base_start) → 补能被丢弃，纯损失能量块。
# 改为写入 _carryover_bonus，start_battle 时累加到 current，让补能跨战斗生效。
var _carryover_bonus: float = 0.0
# P0 性能优化：缓存上次 emit 的整数能量值，避免每帧 emit energy_changed
var _last_emitted_int: int = -1
var _last_emitted_max: int = -1


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	set_process(false)
	_reset_to_start()

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
	current = clampf(_base_start + _carryover_bonus, 0.0, _max)
	# v7.3: 结转加成用完即清零（只影响下场开局一次，避免无限累加）
	_carryover_bonus = 0.0
	if SignalBus:
		SignalBus.energy_changed.emit(current, _max)

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
	# v7.3 修复 B2: 补能结果写入 _carryover_bonus（下场战斗开局额外能量），而非 current 或 _base_start。
	# current 被 start_battle 重置；_base_start 被能量卡重算覆盖。_carryover_bonus 在 start_battle 累加到 current 后清零，
	# 让补能的跨战斗价值真正生效（下场开局能量更高），玩家消耗能量块不再纯损失。
	var recharged: float = float(spend_blocks)
	_carryover_bonus += recharged
	current = clampf(current + recharged, 0.0, _max)
	if SignalBus:
		SignalBus.energy_changed.emit(current, _max)

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
				# v7.1: 从卡ID解析等级（替代已废弃的 BlueprintManager.get_blueprint_star，原API固定返回1）
				total_energy_star += _parse_energy_card_star(card.card_id)
				# energy_start_*: 开局能量（唯一能量卡类型）
				if card.card_id.begins_with("energy_start_"):
					_base_start += maxf(0.0, card.energy_grant)
	# 能量上限 = 基础100 + 所有能量卡等级各自×100 求和
	# 例：2级卡(200) + 7级卡(700) + 基础100 = 1000
	if total_energy_star > 0:
		_max = GC.ENERGY_MAX + float(total_energy_star) * 100.0
	# v7.1: 接入相位仪"回复能量"属性（get_energy_recovery_rate 原为死代码，从未被调用）
	if PhaseInstrumentManager.has_method("get_energy_recovery_rate"):
		_regen_per_sec += PhaseInstrumentManager.get_energy_recovery_rate()
	# 顶级相位仪（4个以上能量槽）能量回复乘5
	if slot_count >= 4:
		_regen_per_sec *= 5.0
	if _base_start <= 0.0:
		_base_start = GC.ENERGY_START

## v7.1: 从能量卡ID解析星级（energy_start_1~7 → 1~7）
## 静态方法，供 UI 和本类共用同一份公式（避免前后端逻辑脱节）
static func parse_energy_card_star(card_id: String) -> int:
	if card_id.begins_with("energy_start_"):
		var suffix := card_id.substr("energy_start_".length())
		if suffix.is_valid_int():
			return clampi(int(suffix), 1, 7)
	return 1

## 实例包装器（兼容内部调用）
func _parse_energy_card_star(card_id: String) -> int:
	return parse_energy_card_star(card_id)

func _add_energy(amount: float) -> void:
	current = clampf(current + amount, 0.0, _max)
	# P0 性能优化：仅在整数部分变化时 emit（能量条每帧回复，但显示只需整数精度）
	# 原每帧 emit 导致 HUD 每帧格式化字符串，60FPS 下每秒 60 次信号+字符串分配
	if SignalBus:
		var cur_int: int = int(current)
		var max_int: int = int(_max)
		if cur_int != _last_emitted_int or max_int != _last_emitted_max:
			_last_emitted_int = cur_int
			_last_emitted_max = max_int
			SignalBus.energy_changed.emit(current, _max)

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
