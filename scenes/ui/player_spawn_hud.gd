extends PanelContainer
## 左上角：我方刷新进度（从上到下）

const GC = preload("res://resources/game_constants.gd")
const REFRESH_INTERVAL_SEC := 0.25

var _next_label: Label
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
	_count_label = get_node_or_null("Margin/VBox/CountLabel") as Label
	_bar = get_node_or_null("Margin/VBox/ProgressBar") as ProgressBar
	if SignalBus:
		if not SignalBus.battle_started.is_connected(_on_battle_started):
			SignalBus.battle_started.connect(_on_battle_started)
		if not SignalBus.battle_ended.is_connected(_on_battle_ended):
			SignalBus.battle_ended.connect(_on_battle_ended)
	if BattleManager != null and BattleManager.battle_active:
		_on_battle_started()

func _exit_tree() -> void:
	if SignalBus:
		if SignalBus.battle_started.is_connected(_on_battle_started):
			SignalBus.battle_started.disconnect(_on_battle_started)
		if SignalBus.battle_ended.is_connected(_on_battle_ended):
			SignalBus.battle_ended.disconnect(_on_battle_ended)

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
	visible = true
	_refresh_accum += delta
	if _refresh_accum < REFRESH_INTERVAL_SEC:
		return
	_refresh_accum = 0.0
	var remaining = BattleManager.get_player_spawn_time_remaining()
	var interval = BattleManager.get_player_spawn_interval()
	var count = int(BattleManager.get_player_unit_count())
	if _next_label:
		if interval <= 0.0:
			_next_label.text = "部署: 点绿槽再点战场"
		elif remaining >= 0:
			_next_label.text = "下次: %.1fs" % remaining
		else:
			_next_label.text = "下次: --"
	if _count_label:
		var cap: int = GC.PLAYER_MAX_UNITS
		if GameManager and GameManager.has_method("is_card_grid_battle") and GameManager.is_card_grid_battle():
			cap = BattleSlotGrid.SLOT_COUNT
		_count_label.text = "当前 我方: %d / %d" % [count, cap]
	if _bar:
		if interval > 0 and remaining >= 0:
			_bar.value = (interval - remaining) / interval * 100.0
		else:
			_bar.value = 0.0
