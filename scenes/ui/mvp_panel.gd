extends Control
## v7.x 战后 MVP 战绩面板（克制版）
##
## 战斗结束瞬间先于 BattleResultDialog 弹出，展示团队战绩概览。
## 玩家点击"查看奖励 →"后切换到 BattleResultDialog 看具体掉落。
##
## 内容（团队 MVP，不做 per-unit——普通单位伤害走 CombatFeedback 直调不经过 SignalBus，无法准确采集）：
##   - 战绩横幅（胜利/失败 + 时长）
##   - 核心数据（击毁 X · 损失 Y · 伤害 Z）
##   - 击杀类型（前 3 类敌人，来自 BattleManager._defeated_enemies）
##   - 星级评定（★1~3，基于击杀比/损失比/时长）
##   - 关闭按钮 → 切换到 BattleResultDialog
##
## 数据来源：BattleInfoDisplay.get_battle_stats() + BattleManager._defeated_enemies
## 挂机模式跳过（_is_afk_running）

const DT = preload("res://resources/design_tokens.gd")
const BattleResultDialog = preload("res://scenes/ui/battle_result_dialog.gd")

signal mvp_confirmed()


static func create(parent: Node, player_won: bool, blueprints: Array, \
		phase_field_xp_before: int, phase_field_level_before: int, \
		reward_summary: Dictionary) -> Control:
	var panel: Control = load("res://scenes/ui/mvp_panel.tscn").instantiate()
	panel.player_won = player_won
	panel._blueprints = blueprints
	panel._xp_before = phase_field_xp_before
	panel._level_before = phase_field_level_before
	panel._reward_summary = reward_summary
	parent.add_child(panel)
	panel._build()
	return panel


var player_won: bool = true
var _blueprints: Array = []
var _xp_before: int = 0
var _level_before: int = 0
var _reward_summary: Dictionary = {}


func _ready() -> void:
	anchors_preset = Control.PRESET_FULL_RECT
	mouse_filter = Control.MOUSE_FILTER_STOP


func _build() -> void:
	# 背景遮罩
	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.65)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)
	# 中央容器
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	# 主面板
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(480, 360)
	var style := StyleBoxFlat.new()
	style.bg_color = DT.COLOR_PANEL
	style.corner_radius_top_left = DT.CORNER_RADIUS
	style.corner_radius_top_right = DT.CORNER_RADIUS
	style.corner_radius_bottom_right = DT.CORNER_RADIUS
	style.corner_radius_bottom_left = DT.CORNER_RADIUS
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = DT.COLOR_GOLD if player_won else DT.COLOR_TEXT_DIM
	style.content_margin_left = 24.0
	style.content_margin_right = 24.0
	style.content_margin_top = 20.0
	style.content_margin_bottom = 20.0
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	# 内容列
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)
	# === 战绩横幅 ===
	var title := Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title_ls := LabelSettings.new()
	if player_won:
		title.text = "胜  利"
		title_ls.font_color = DT.COLOR_GOLD
		title_ls.font_size = DT.FONT_SIZE_HUGE
	else:
		title.text = "失  败"
		title_ls.font_color = DT.COLOR_TEXT_DIM
		title_ls.font_size = DT.FONT_SIZE_TITLE
	title_ls.outline_color = Color(0, 0, 0, 0.85)
	title_ls.outline_size = 4
	title.label_settings = title_ls
	vbox.add_child(title)
	# === 战斗时长 ===
	var stats: Dictionary = _collect_stats()
	var time_lbl := Label.new()
	time_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_lbl.text = "战斗时长  %s" % _format_time(stats.get("battle_time", 0.0))
	time_lbl.add_theme_font_size_override("font_size", DT.FONT_SIZE_MEDIUM)
	time_lbl.add_theme_color_override("font_color", DT.COLOR_TEXT_BRIGHT)
	vbox.add_child(time_lbl)
	# === 星级评定 ===
	var stars: int = _compute_stars(stats)
	var star_lbl := Label.new()
	star_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	star_lbl.text = _star_text(stars)
	star_lbl.add_theme_font_size_override("font_size", DT.FONT_SIZE_TITLE)
	star_lbl.add_theme_color_override("font_color", DT.COLOR_GOLD if stars >= 2 else DT.COLOR_TEXT_DIM)
	vbox.add_child(star_lbl)
	# === 核心数据 ===
	vbox.add_child(_make_separator())
	var data_grid := GridContainer.new()
	data_grid.columns = 2
	data_grid.add_theme_constant_override("h_separation", 32)
	data_grid.add_theme_constant_override("v_separation", 6)
	vbox.add_child(data_grid)
	_add_data_row(data_grid, "击毁敌方", str(stats.get("enemy_kills", 0)), DT.COLOR_GREEN_BRIGHT)
	_add_data_row(data_grid, "我方损失", str(stats.get("player_kills", 0)), DT.COLOR_DANGER)
	_add_data_row(data_grid, "造成伤害", str(int(stats.get("damage_dealt", 0))), DT.COLOR_ACCENT_CYAN)
	_add_data_row(data_grid, "承受伤害", str(int(stats.get("damage_taken", 0))), DT.COLOR_ENERGY)
	# === 击杀类型分布 ===
	var kill_breakdown := _kill_type_breakdown()
	if not kill_breakdown.is_empty():
		vbox.add_child(_make_separator())
		var kb_lbl := Label.new()
		kb_lbl.text = "击破分布"
		kb_lbl.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
		kb_lbl.add_theme_color_override("font_color", DT.COLOR_TEXT_DIM)
		vbox.add_child(kb_lbl)
		var kb_text := ", ".join(kill_breakdown)
		var kb_val := Label.new()
		kb_val.text = kb_text
		kb_val.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
		kb_val.add_theme_color_override("font_color", DT.COLOR_TEXT_BRIGHT)
		kb_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(kb_val)
	# === 关闭按钮 ===
	vbox.add_child(_make_separator())
	var btn := Button.new()
	btn.text = "查看奖励 →" if player_won else "继续"
	btn.custom_minimum_size = Vector2(0, 40)
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = DT.COLOR_GOLD if player_won else DT.COLOR_BORDER
	btn_style.corner_radius_top_left = 4
	btn_style.corner_radius_top_right = 4
	btn_style.corner_radius_bottom_right = 4
	btn_style.corner_radius_bottom_left = 4
	btn.add_theme_stylebox_override("normal", btn_style)
	btn.add_theme_color_override("font_color", Color(0.05, 0.05, 0.08, 1.0))
	btn.add_theme_font_size_override("font_size", DT.FONT_SIZE_MEDIUM)
	btn.pressed.connect(_on_continue_pressed)
	vbox.add_child(btn)
	# 淡入
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.2)


func _on_continue_pressed() -> void:
	mvp_confirmed.emit()
	# 淡出后切换到 BattleResultDialog
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.18)
	tw.tween_callback(func():
		var main: Node = get_parent()
		BattleResultDialog.create(main, player_won, _blueprints, _xp_before, _level_before, _reward_summary)
		queue_free()
	)


# =========================================================================
#  数据采集
# =========================================================================

func _collect_stats() -> Dictionary:
	# 优先从 BattleInfoDisplay.get_battle_stats() 取（实时统计）
	var bid: Node = get_node_or_null("/root/Main/HudLayer/BattleTopStatusBar/BattleInfoDisplay")
	if bid == null:
		# fallback：尝试全局查找
		var tree := get_tree()
		if tree != null:
			bid = _find_node_by_name(tree.root, "BattleInfoDisplay")
	if bid != null and bid.has_method("get_battle_stats"):
		return bid.get_battle_stats()
	return {}


func _find_node_by_name(root: Node, name: String) -> Node:
	if root.name == name:
		return root
	for c in root.get_children():
		var found := _find_node_by_name(c, name)
		if found != null:
			return found
	return null


## 击杀类型分布（前 3 类），来自 BattleManager._defeated_enemies
func _kill_type_breakdown() -> Array:
	var bm: Node = get_node_or_null("/root/BattleManager")
	if bm == null:
		return []
	var defeated: Array = []
	if "_defeated_enemies" in bm:
		defeated = bm.get("_defeated_enemies")
	if defeated.is_empty():
		return []
	# 按 enemy_type 聚合
	var counts: Dictionary = {}
	for e in defeated:
		var et: String = e.get("enemy_type", "infantry") if e is Dictionary else "infantry"
		counts[et] = int(counts.get(et, 0)) + 1
	# 排序取前 3
	var sorted: Array = counts.keys()
	sorted.sort_custom(func(a, b): return counts[a] > counts[b])
	var out: Array = []
	for i in range(mini(3, sorted.size())):
		out.append("%s ×%d" % [_type_display_name(sorted[i]), counts[sorted[i]]])
	return out


func _type_display_name(t: String) -> String:
	match t:
		"infantry": return "步兵"
		"armor", "tank": return "装甲"
		"artillery": return "火炮"
		"anti_air": return "防空"
		"air": return "空军"
		"recon": return "侦察"
		"engineer": return "工兵"
		"fort": return "堡垒"
		_: return t


## 星级评定：基于击杀比/损失比/时长（1~3 星）
func _compute_stars(stats: Dictionary) -> int:
	if not player_won:
		return 1
	var kills: int = int(stats.get("enemy_kills", 0))
	var losses: int = int(stats.get("player_kills", 0))
	var time_s: float = float(stats.get("battle_time", 0.0))
	var stars: int = 1
	# 击杀数门槛
	if kills >= 8:
		stars += 1
	if kills >= 20:
		stars += 1
	# 损失扣星
	if losses > kills * 0.8 and kills > 0:
		stars = max(1, stars - 1)
	# 时长奖励（速胜）
	if time_s > 0 and time_s < 60 and kills >= 5:
		stars = min(3, stars + 1)
	return clampi(stars, 1, 3)


func _star_text(stars: int) -> String:
	var s := ""
	for i in range(3):
		s += "★" if i < stars else "☆"
	return s


# =========================================================================
#  辅助 UI
# =========================================================================

func _make_separator() -> HSeparator:
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	return sep


func _add_data_row(grid: GridContainer, label: String, value: String, color: Color) -> void:
	var l := Label.new()
	l.text = label
	l.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	l.add_theme_color_override("font_color", DT.COLOR_TEXT_DIM)
	grid.add_child(l)
	var v := Label.new()
	v.text = value
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_theme_font_size_override("font_size", DT.FONT_SIZE_MEDIUM)
	v.add_theme_color_override("font_color", color)
	grid.add_child(v)


func _format_time(sec: float) -> String:
	var m: int = int(sec) / 60
	var s: int = int(sec) % 60
	return "%d:%02d" % [m, s]
