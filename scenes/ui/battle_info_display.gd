extends Control
## 增强版战斗信息显示面板：显示战斗状态、统计信息等

const DT = preload("res://resources/design_tokens.gd")

var _battle_active: bool = false
var _battle_time: float = 0.0
var _time_display_acc: float = 0.0
var _player_kills: int = 0
var _enemy_kills: int = 0
var _damage_dealt: int = 0
var _damage_taken: int = 0

# UI节点引用
@onready var _battle_time_label: Label = $VBoxContainer/BattleStats/TimeLabel
@onready var _units_label: Label = $VBoxContainer/BattleStats/UnitsLabel
@onready var _kills_label: Label = $VBoxContainer/BattleStats/KillsLabel
@onready var _damage_label: Label = $VBoxContainer/BattleStats/DamageLabel

const UNIT_COUNT_REFRESH_SEC: float = 0.2
var _unit_count_refresh_accum: float = 0.0
@onready var _status_indicator: ColorRect = $VBoxContainer/StatusPanel/StatusIndicator
@onready var _status_text: Label = $VBoxContainer/StatusPanel/StatusLabel

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_design_tokens()
	_update_display()

	if SignalBus:
		SignalBus.battle_started.connect(_on_battle_started)
		SignalBus.battle_ended.connect(_on_battle_ended)
		SignalBus.unit_damaged.connect(_on_unit_damaged)
		SignalBus.unit_died.connect(_on_unit_died)

	if BattleManager != null and BattleManager.battle_active:
		_on_battle_started()
	else:
		set_process(false)

func _process(delta: float) -> void:
	if _battle_active:
		_battle_time += delta
		_time_display_acc += delta
		if _time_display_acc >= 1.0:
			_time_display_acc -= 1.0
			_update_time_display()
		_unit_count_refresh_accum += delta
		if _unit_count_refresh_accum >= UNIT_COUNT_REFRESH_SEC:
			_unit_count_refresh_accum = 0.0
			_update_unit_count_display()

func _apply_design_tokens() -> void:
	# 应用设计令牌样式
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = DT.get_panel_color(true)
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = DT.COLOR_ENERGY

	add_theme_stylebox_override("panel", panel_style)

	# 设置标签字体
	for child in $VBoxContainer/BattleStats.get_children():
		if child is Label:
			child.add_theme_font_size_override("font_size", DT.get_font_size(DT.FONT_SIZE_SMALL))
			child.add_theme_color_override("font_color", DT.get_text_color(true))

func _on_battle_started() -> void:
	_battle_active = true
	_battle_time = 0.0
	_player_kills = 0
	_enemy_kills = 0
	_damage_dealt = 0
	_damage_taken = 0
	_unit_count_refresh_accum = UNIT_COUNT_REFRESH_SEC
	set_process(true)
	_update_status("战斗中", Color(0.2, 0.8, 0.3, 1.0))
	_update_unit_count_display()
	_update_display()

func _on_battle_ended(player_won: bool) -> void:
	_battle_active = false
	_update_unit_count_display()
	_update_display()
	set_process(false)
	if player_won:
		_update_status("胜利！", Color(0.2, 0.9, 0.4, 1.0))
	else:
		_update_status("失败...", Color(0.9, 0.2, 0.2, 1.0))

func _on_unit_damaged(_unit: Node, is_player: bool, amount: float, _at_position: Vector2) -> void:
	if not _battle_active:
		return
	var dmg: int = ceili(amount) if amount > 0.001 else 0
	if is_player:
		_damage_taken += dmg
	else:
		_damage_dealt += dmg
	_update_display()

func _on_unit_died(_unit: Node, is_player: bool) -> void:
	if not _battle_active:
		return
	if is_player:
		_enemy_kills += 1
	else:
		_player_kills += 1
	_update_display()

func _update_time_display() -> void:
	if _battle_time_label:
		var minutes = int(_battle_time / 60)
		var seconds = int(fmod(_battle_time, 60.0))
		_battle_time_label.text = "时间: %02d:%02d" % [minutes, seconds]

func _update_unit_count_display() -> void:
	if _units_label == null:
		return
	var player_n: int = 0
	var enemy_n: int = 0
	if _battle_active and BattleManager != null:
		if BattleManager.has_method("get_player_unit_count"):
			player_n = int(BattleManager.get_player_unit_count())
		if BattleManager.has_method("get_enemy_unit_count"):
			enemy_n = int(BattleManager.get_enemy_unit_count())
	_units_label.text = "单位 我方:%d 敌方:%d" % [player_n, enemy_n]


func _update_display() -> void:
	if _kills_label:
		# 我方击毁数 / 敌方击毁数（敌方击毁 = 我方单位阵亡次数）
		_kills_label.text = "击毁 我方:%d 敌方:%d" % [_player_kills, _enemy_kills]
	if _damage_label:
		# 我方造成伤害 / 敌方造成伤害（敌方 = 我方承受）
		_damage_label.text = "伤害 我方:%d 敌方:%d" % [_damage_dealt, _damage_taken]

func _update_status(status_text: String, status_color: Color) -> void:
	if _status_text:
		_status_text.text = status_text
		_status_text.add_theme_color_override("font_color", status_color)
	if _status_indicator:
		_status_indicator.color = status_color

## 重置战斗统计
func reset_stats() -> void:
	_battle_time = 0.0
	_player_kills = 0
	_enemy_kills = 0
	_damage_dealt = 0
	_damage_taken = 0
	_unit_count_refresh_accum = UNIT_COUNT_REFRESH_SEC
	_update_display()
	_update_time_display()
	_update_unit_count_display()
	_update_status("准备中", Color(0.6, 0.6, 0.6, 1.0))

## 获取战斗统计数据
func get_battle_stats() -> Dictionary:
	return {
		"battle_time": _battle_time,
		"player_kills": _player_kills,
		"enemy_kills": _enemy_kills,
		"damage_dealt": _damage_dealt,
		"damage_taken": _damage_taken,
		"battle_active": _battle_active
	}
