extends Control
## 增强版战斗信息显示面板：显示战斗状态、统计信息等

const DT = preload("res://resources/design_tokens.gd")

var _battle_active: bool = false
var _battle_time: float = 0.0
var _time_display_acc: float = 0.0
# P1 性能优化：统计脏标记，受击/死亡只设标记，_process 合并刷新（原每次受击同步 _update_display）
var _stats_dirty: bool = false
var _player_kills: int = 0
var _enemy_kills: int = 0
var _damage_dealt: int = 0
var _damage_taken: int = 0

# UI节点引用
@onready var _battle_time_label: Label = $VBoxContainer/BattleStats/TimeLabel
@onready var _units_label: Label = $VBoxContainer/BattleStats/UnitsLabel
@onready var _kills_label: Label = $VBoxContainer/BattleStats/KillsLabel
@onready var _damage_label: Label = $VBoxContainer/BattleStats/DamageLabel
# v6.2: 加成总览标签（符文/相位场/相位仪综合加成）
@onready var _bonus_label: Label = $VBoxContainer/BattleStats/BonusLabel
@onready var _bonus_separator: HSeparator = $VBoxContainer/BattleStats/BonusSeparator

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
		# v6.2: 监听相位仪槽位变化（符文装备/卸下），即时刷新加成显示
		if SignalBus.has_signal("phase_slots_changed"):
			SignalBus.phase_slots_changed.connect(_on_bonus_slots_changed)

	if BattleManager != null and BattleManager.battle_active:
		_on_battle_started()
	else:
		set_process(false)
	# v6.2: 战前立即刷新一次加成（不依赖战斗状态）
	call_deferred("_refresh_bonus_display")

func _exit_tree() -> void:
	if SignalBus:
		if SignalBus.battle_started.is_connected(_on_battle_started):
			SignalBus.battle_started.disconnect(_on_battle_started)
		if SignalBus.battle_ended.is_connected(_on_battle_ended):
			SignalBus.battle_ended.disconnect(_on_battle_ended)
		if SignalBus.unit_damaged.is_connected(_on_unit_damaged):
			SignalBus.unit_damaged.disconnect(_on_unit_damaged)
		if SignalBus.unit_died.is_connected(_on_unit_died):
			SignalBus.unit_died.disconnect(_on_unit_died)
		# v6.2: 断开加成刷新信号
		if SignalBus.has_signal("phase_slots_changed") and SignalBus.phase_slots_changed.is_connected(_on_bonus_slots_changed):
			SignalBus.phase_slots_changed.disconnect(_on_bonus_slots_changed)

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
		# P1 性能优化：合并本帧所有受击/死亡的脏标记，最多每帧刷新一次
		if _stats_dirty:
			_stats_dirty = false
			_update_display()

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
	# v6.2: 战斗开始时刷新加成显示（可能战前刚分配了相位场点数或换了符文）
	_refresh_bonus_display()

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
	# P1 性能优化：设脏标记而非同步刷新（受击密集时每秒数十次 Label 赋值）
	_stats_dirty = true

func _on_unit_died(_unit: Node, is_player: bool) -> void:
	if not _battle_active:
		return
	if is_player:
		_enemy_kills += 1
	else:
		_player_kills += 1
	_stats_dirty = true

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

# ── v6.2 加成总览显示 ──────────────────────────────────────────

## phase_slots_changed 回调：符文装备/卸下时即时刷新加成
func _on_bonus_slots_changed(_slots: Variant = null) -> void:
	_refresh_bonus_display()

## 刷新加成显示：从 PhaseInstrumentManager.get_all_bonus_summary() 取数据
## 无加成时隐藏标签和分隔线，有加成才显示
func _refresh_bonus_display() -> void:
	if _bonus_label == null or not is_instance_valid(_bonus_label):
		return
	var pim: Node = get_node_or_null("/root/PhaseInstrumentManager")
	if pim == null or not pim.has_method("get_all_bonus_summary"):
		_bonus_label.visible = false
		return
	var summary: Dictionary = pim.get_all_bonus_summary()
	if not bool(summary.get("has_any", false)):
		_bonus_label.visible = false
		return
	var rune_block: String = ""      # 符文块（单符文加成）
	var instrument_block: String = "" # 相位仪块（相位仪固有属性 + 相位场属性点）
	# v6.2c: 单符文加成（精简：攻+15% 生+20%）
	var rune_stats: Dictionary = summary.get("rune_stats", {})
	if not rune_stats.is_empty():
		var stat_parts: Array[String] = []
		for key in rune_stats.keys():
			var s: String = RuneDefinitions.format_stat_bonus(String(key), float(rune_stats[key]))
			if not s.is_empty():
				stat_parts.append(s)
		if not stat_parts.is_empty():
			rune_block = "符文: " + " ".join(stat_parts)
	# v6.2b: 符文之语加成（每个带名称：[锐利]攻+25%）
	# 符文之语单独成行显示（不并入主行 parts），突出已激活的符文之语
	var runeword_lines: Array[String] = []
	var runeword_bonuses: Array = summary.get("runeword_bonuses", [])
	for rw in runeword_bonuses:
		if not (rw is Dictionary):
			continue
		var rw_name: String = String((rw as Dictionary).get("name", ""))
		var rw_stats: Dictionary = (rw as Dictionary).get("stats", {})
		var rw_parts: Array[String] = []
		for key in rw_stats.keys():
			var s: String = RuneDefinitions.format_stat_bonus(String(key), float(rw_stats[key]))
			if not s.is_empty():
				rw_parts.append(s)
		for sp in (rw as Dictionary).get("specials", []):
			if not (sp is Dictionary):
				continue
			var sp_name: String = RuneDefinitions.special_display_name(String((sp as Dictionary).get("special", "")))
			var chance := int(round(float((sp as Dictionary).get("chance", 1.0)) * 100.0))
			rw_parts.append("%s%d%%" % [sp_name, chance])
		if not rw_parts.is_empty():
			runeword_lines.append("✦ [%s] %s" % [rw_name, " ".join(rw_parts)])
	# 相位仪块：相位场属性点 + 相位仪固有属性（同属相位系统，合并一块）
	var inst_parts: Array[String] = []
	var pf_bonus: Dictionary = summary.get("phase_field", {})
	var pf_labels: Dictionary = summary.get("phase_field_labels", {})
	if not pf_bonus.is_empty():
		var pf_parts: Array[String] = []
		for key in pf_bonus.keys():
			var pct := int(round(float(pf_bonus[key]) * 100.0))
			if pct == 0:
				continue
			pf_parts.append("%s+%d%%" % [String(pf_labels.get(key, key)), pct])
		if not pf_parts.is_empty():
			inst_parts.append("相位场:" + " ".join(pf_parts))
	var inst_props: Array = summary.get("instrument_props", [])
	if not inst_props.is_empty():
		var prop_parts: Array[String] = []
		var shown := 0
		for p in inst_props:
			if shown >= 3:
				prop_parts.append("…")
				break
			prop_parts.append(String(p))
			shown += 1
		if not prop_parts.is_empty():
			inst_parts.append("相位仪:" + " ".join(prop_parts))
	if not inst_parts.is_empty():
		instrument_block = " | ".join(inst_parts)
	# v6.2c: 各类加成分块换行显示（相位仪 / 符文 / 符文之语 各一块）
	var blocks: Array[String] = []
	if not instrument_block.is_empty():
		blocks.append("✦ " + instrument_block)
	if not rune_block.is_empty():
		blocks.append("✦ " + rune_block)
	for rw_line in runeword_lines:
		blocks.append("  " + rw_line)
	if blocks.is_empty():
		_bonus_label.visible = false
		return
	_bonus_label.text = "\n".join(blocks)
	_bonus_label.visible = true


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
