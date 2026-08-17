extends PanelContainer
## 右上角：敌方刷新进度（从上到下）
## v10 解题式玩法：新增下波构成预警行（PreviewLabel）——显示下一波敌方类型倾向，
## 让玩家在波次到来前有针对部署的窗口。情报精度联动：情报完成度低只显示"敌方来袭"，
## 中级显示类型，高级显示类型+数量（情报价值落地：高情报=战场透明）。

const GC = preload("res://resources/game_constants.gd")
const REFRESH_INTERVAL_SEC := 0.25
## 预警数据刷新间隔（秒）——构成不像倒计时那样每帧变，低频查询即可
const PREVIEW_REFRESH_SEC := 1.0

var _wave_total_logged: bool = false
var _next_label: Label
var _wave_label: Label
var _count_label: Label
var _preview_label: Label
var _bar: ProgressBar
var _refresh_accum: float = 0.0
var _preview_accum: float = 0.0
var _preview_text: String = ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 10
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)
	visible = false
	_next_label = get_node_or_null("Margin/VBox/NextLabel") as Label
	_wave_label = get_node_or_null("Margin/VBox/WaveLabel") as Label
	_count_label = get_node_or_null("Margin/VBox/CountLabel") as Label
	_preview_label = get_node_or_null("Margin/VBox/PreviewLabel") as Label
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
			# 波次进度可视化 ●●◉○○（已完成/当前/未完成三态）+ 文字
			var dots := ""
			for i in range(wave_total):
				if i < wave_idx - 1:
					dots += "●"   # 已完成波次（实心）
				elif i == wave_idx - 1:
					dots += "◉"   # 当前波次（实心带圈，视觉突出）
				else:
					dots += "○"   # 未完成波次（空心）
			_wave_label.text = "%s  波次 %d/%d" % [dots, wave_idx, wave_total]
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
	# v10：下波构成预警（低频刷新，1s 一次）
	if _preview_label:
		_preview_accum += delta
		if _preview_accum >= PREVIEW_REFRESH_SEC:
			_preview_accum = 0.0
			_refresh_wave_preview()
		_preview_label.text = _preview_text


## v10：刷新下波构成预警文本（情报精度分级：0=只显示来袭 / 1=类型 / 2=类型+数量）
func _refresh_wave_preview() -> void:
	if BattleManager == null or not BattleManager.has_method("get_next_wave_preview"):
		_preview_text = ""
		return
	var preview: Dictionary = BattleManager.get_next_wave_preview()
	if not bool(preview.get("valid", false)):
		_preview_text = ""
		return
	var precision: int = _intel_preview_precision()
	var bias: String = String(preview.get("bias_display", "混合"))
	var to_spawn: int = int(preview.get("to_spawn", 0))
	var is_boss: bool = bool(preview.get("is_boss_wave", false))
	if precision <= 0:
		_preview_text = "⚠ 敌方来袭"
	elif precision == 1:
		if is_boss:
			_preview_text = "☠ 下波: BOSS 波次"
		else:
			_preview_text = "⚠ 下波: %s单位为主" % bias
	else:
		if is_boss:
			_preview_text = "☠ 下波: BOSS 波次 ×%d" % to_spawn
		else:
			_preview_text = "⚠ 下波: %s ×%d" % [bias, to_spawn]


## v10：情报精度分级（0/1/2）。
## 全局情报水平近似：IntelManual 条目完成度——完成 0 条=无预警细节，1-7 条=类型级，
## 8+ 条=完整构成。阈值宽松（预警是体验增益，不该让早期玩家完全瞎打）。
func _intel_preview_precision() -> int:
	var im: Node = get_node_or_null("/root/IntelManual")
	if im == null or not im.has_method("get_total_completed"):
		return 2  # 无情报系统（异常兜底）→ 给最高精度，惩罚不应由系统缺失造成
	var completed: int = int(im.get_total_completed())
	if completed >= 8:
		return 2
	if completed >= 1:
		return 1
	return 0
