extends Control

## 关卡选择面板

signal level_selected(level: int)
signal panel_closed

var current_era: int = 1
var era_data: Array = []

@onready var era_tabs = $Panel/VBoxContainer/EraTabs
@onready var era_name_label = $Panel/VBoxContainer/Header/EraNameLabel
@onready var era_progress_label = $Panel/VBoxContainer/Header/EraProgressLabel
@onready var levels_grid = $Panel/VBoxContainer/Body/LevelsScroll/LevelsGrid
@onready var close_button = $Panel/VBoxContainer/Footer/CloseButton

const LevelEras = preload("res://data/level_eras.gd")

func _ready():
	_setup_era_tabs()
	close_button.pressed.connect(_on_close_pressed)

	# 默认选择一战时代
	_select_era(1)

## 设置时代标签页
func _setup_era_tabs():
	era_tabs.clear_tabs()

	var eras = [
		{1: "一战 (1-20)"},
		{2: "二战 (21-40)"},
		{3: "冷战 (41-60)"},
		{4: "现代 (61-80)"},
		{5: "未来 (81-100)"}
	]

	for era_info in eras:
		for era_id in era_info.keys():
			var era_name = era_info[era_id]
			era_tabs.add_tab(era_name)

	era_tabs.tab_changed.connect(_on_era_tab_changed)

## 选择时代
func _select_era(era: int):
	current_era = era
	_update_header()
	_load_levels()

## 更新头部信息
func _update_header():
	var era_names = {
		1: "一战时代 (1914-1918)",
		2: "二战时代 (1939-1945)",
		3: "冷战时代 (1947-1991)",
		4: "现代时代 (1991-2025)",
		5: "未来时代 (2025-2050)"
	}

	era_name_label.text = era_names.get(current_era, "未知时代")

	# 获取时代进度
	var lpm = get_node_or_null("/root/LevelProgressManager")
	if lpm and lpm.has_method("get_era_progress"):
		var progress = lpm.get_era_progress(current_era)
		var completion_rate = (progress["completed"] as float / progress["total"] * 100)
		era_progress_label.text = "进度: %d/%d (%.0f%%) | ⭐ %d/%d 星" % [
			progress["completed"],
			progress["total"],
			completion_rate,
			progress["total_stars"],
			progress["max_stars"]
		]

		# 添加时代特色描述
		var era_desc = _get_era_description(current_era)
		if era_progress_label.has_method("set_tooltip_text"):
			era_progress_label.tooltip_text = era_desc

## 加载关卡列表
func _load_levels():
	# 清空网格
	for child in levels_grid.get_children():
		child.queue_free()

	var start_level = (current_era - 1) * 20 + 1
	var end_level = current_era * 20

	var lpm = get_node_or_null("/root/LevelProgressManager")
	if not lpm:
		return

	for level in range(start_level, end_level + 1):
		var level_ui = _create_level_button(level, lpm)
		levels_grid.add_child(level_ui)

## 创建关卡按钮
func _create_level_button(level: int, lpm: Node) -> Control:
	var is_unlocked = lpm.is_level_unlocked(level) if lpm.has_method("is_level_unlocked") else false
	var stars = lpm.get_level_stars(level) if lpm.has_method("get_level_stars") else 0
	var is_boss = (level % 20 == 0)

	var button = Button.new()
	button.custom_minimum_size = Vector2(100, 100)
	button.disabled = not is_unlocked

	# 设置按钮文本
	if is_unlocked:
		var level_name = "第%d关" % ((level - 1) % 20 + 1)
		if is_boss:
			level_name = "Boss\n%ds" % ((level - 1) % 20 + 1)
		var level_in_era = ((level - 1) % 20) + 1
		var difficulty = _get_difficulty_text(level)
		button.text = "%s\n%s\n%s" % [level_name, difficulty, _get_stars_text(stars)]

		# 添加关卡信息提示
		var tooltip = _get_level_tooltip(level, level_in_era, is_boss)
		button.tooltip_text = tooltip
	else:
		button.text = "🔒"
		var level_in_era = ((level - 1) % 20) + 1
		button.tooltip_text = "第 %d 关 - 未解锁\n完成前一关以解锁" % level_in_era

	# 设置按钮颜色
	if is_boss and is_unlocked:
		button.modulate = Color(1.0, 0.6, 0.2)  # Boss用橙色
	elif not is_unlocked:
		button.modulate = Color(0.5, 0.5, 0.5)  # 锁定用灰色
	else:
		# 根据关卡在时代中的位置调整颜色
		var level_in_era = ((level - 1) % 20) + 1
		var color_intensity = 0.6 + (level_in_era / 20.0) * 0.4
		button.modulate = Color(color_intensity, color_intensity, 1.0)

	# 连接信号
	if is_unlocked:
		button.pressed.connect(_on_level_pressed.bind(level))

	return button

## 获取难度文本
func _get_difficulty_text(level: int) -> String:
	var level_in_era = ((level - 1) % 20) + 1
	if level_in_era <= 5:
		return "简单"
	elif level_in_era <= 10:
		return "普通"
	elif level_in_era <= 15:
		return "困难"
	else:
		return "极难"

## 获取关卡提示信息
func _get_level_tooltip(level: int, level_in_era: int, is_boss: bool) -> String:
	var era_name = LevelEras.get_era_name(LevelEras.get_era(level))
	var tooltip = "%s - 第 %d 关\n" % [era_name, level_in_era]
	tooltip += "难度：%s\n" % _get_difficulty_text(level)

	# 添加推荐等级
	var rec_level = level_in_era + (current_era - 1) * 20
	tooltip += "推荐等级：%d\n" % rec_level

	# 添加时代信息
	if is_boss:
		tooltip += "\n⚠️ Boss关卡\n该时代的最终挑战\n建议充分准备后再挑战"
	else:
		# 添加关卡特色提示
		if level_in_era == 1:
			tooltip += "\n该时代的起点关卡\n适合新手玩家"
		elif level_in_era % 5 == 0:
			tooltip += "\n重要关卡\n完成后解锁新内容"

	return tooltip

## 获取星级文本
func _get_stars_text(stars: int) -> String:
	match stars:
		3:
			return "⭐⭐⭐"
		2:
			return "⭐⭐☆"
		1:
			return "⭐☆☆"
		_:
			return "☆☆☆"

## 时代标签页变化
func _on_era_tab_changed(tab_index: int):
	var era = tab_index + 1
	_select_era(era)

## 关卡按钮按下
func _on_level_pressed(level: int):
	level_selected.emit(level)

## 获取时代特色描述
func _get_era_description(era: int) -> String:
	match era:
		1:
			return "一战时代：堑壕战、毒气战、早期坦克\n特点：低技术、高伤亡、阵地战"
		2:
			return "二战时代：闪电战、航母战、原子弹\n特点：机械化战争、全球冲突"
		3:
			return "冷战时代：核威慑、太空竞赛、代理战争\n特点：高科技、意识形态对抗"
		4:
			return "现代时代：精确打击、网络战、无人机\n特点：信息化战争、反恐作战"
		5:
			return "未来时代：AI觉醒、量子武器、太空战争\n特点：未来科技、多维战场"
		_:
			return "未知时代"

## 关闭面板
func _on_close_pressed():
	panel_closed.emit()
	queue_free()
