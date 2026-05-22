extends PanelContainer
## 右上角：敌方刷新进度（从上到下）

const GC = preload("res://resources/game_constants.gd")
const REFRESH_INTERVAL_SEC := 0.25

var _wave_total_logged: bool = false
var _next_label: Label
var _wave_label: Label
var _count_label: Label
var _bar: ProgressBar
var _refresh_accum: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 10
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)
	visible = false
	_next_label = get_node_or_null("Margin/VBox/NextLabel") as Label
	_wave_label = get_node_or_null("Margin/VBox/WaveLabel") as Label
	_count_label = get_node_or_null("Margin/VBox/CountLabel") as Label
	_bar = get_node_or_null("Margin/VBox/ProgressBar") as ProgressBar
	if SignalBus:
		if not SignalBus.battle_started.is_connected(_on_battle_started):
			SignalBus.battle_started.connect(_on_battle_started)
		if not SignalBus.battle_ended.is_connected(_on_battle_ended):
			SignalBus.battle_ended.connect(_on_battle_ended)
	if BattleManager != null and BattleManager.battle_active:
		_on_battle_started()

func _on_battle_started() -> void:
	_refresh_accum = REFRESH_INTERVAL_SEC
	set_process(true)

func _on_battle_ended(_player_won: bool) -> void:
	set_process(false)
	visible = false

func _process(delta: float) -> void:
	if BattleManager == null or not BattleManager.battle_active:
		visible = false
		return
	if GameManager and GameManager.has_method("is_phase_master_battle") and GameManager.is_phase_master_battle():
		visible = false
		return
	visible = true
	# 格子战仍显示敌方波次与场上数量（中央 BattleInfoDisplay 也同步单位数）
	_refresh_accum += delta
	if _refresh_accum < REFRESH_INTERVAL_SEC:
		return
	_refresh_accum = 0.0
	var remaining = BattleManager.get_enemy_wave_time_remaining()
	var interval = BattleManager.get_enemy_wave_interval()
	var wave_idx = int(BattleManager.get_enemy_wave_index())
	var wave_total: int = 0
	if BattleManager.has_method("get_enemy_wave_total"):
		wave_total = int(BattleManager.get_enemy_wave_total())
	var count = int(BattleManager.get_enemy_unit_count())
	if _next_label:
		if remaining >= 0:
			_next_label.text = "下次波次: %.1fs" % remaining
		else:
			_next_label.text = "下次波次: --"
	if _wave_label:
		if wave_total > 0:
			_wave_label.text = "波次: %d / %d" % [wave_idx, wave_total]
		else:
			_wave_label.text = "波次: %d" % wave_idx
	if _count_label:
		var cap: int = GC.ENEMY_MAX_UNITS
		if GameManager and GameManager.has_method("is_card_grid_battle") and GameManager.is_card_grid_battle():
			cap = BattleSlotGrid.SLOT_COUNT
		_count_label.text = "当前 敌方: %d / %d" % [count, cap]
	if _bar and interval > 0 and remaining >= 0:
		_bar.value = (interval - remaining) / interval * 100.0
	if not _wave_total_logged and wave_total > 0:
		_wave_total_logged = true
