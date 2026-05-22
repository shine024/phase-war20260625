extends PanelContainer
## 数据统计界面：显示玩家的游戏统计数据

signal closed

const StatisticsManager = preload("res://managers/statistics_manager.gd")

# UI组件引用
@onready var close_button: Button = $Margin/VBox/Header/CloseButton
@onready var stats_container: VBoxContainer = $Margin/VBox/Body/Scroll/StatsContainer
@onready var playtime_label: Label = $Margin/VBox/Footer/PlaytimeLabel

var _statistics_data: Dictionary = {}

func _ready() -> void:
	if close_button:
		close_button.pressed.connect(_on_close)

	_refresh_statistics()

	# 连接统计变化信号
	var stats_mgr = get_node_or_null("/root/StatisticsManager")
	if stats_mgr and stats_mgr.has_signal("statistic_changed"):
		stats_mgr.statistic_changed.connect(_on_statistic_changed)

func refresh() -> void:
	_refresh_statistics()

## 刷新统计数据
func _refresh_statistics() -> void:
	var stats_mgr = get_node_or_null("/root/StatisticsManager")
	if not stats_mgr:
		return

	_statistics_data = stats_mgr.get_statistics_summary()
	_update_ui()

## 更新UI显示
func _update_ui() -> void:
	if not stats_container:
		return

	# 清空现有内容
	for child in stats_container.get_children():
		child.queue_free()

	# 添加统计类别
	_add_battle_statistics()
	_add_collection_statistics()
	_add_performance_statistics()
	_add_resource_statistics()

	# 更新游戏时长
	if playtime_label and _statistics_data.has("游戏时长"):
		playtime_label.text = "📊 总游戏时长：%s" % _statistics_data["游戏时长"]

## 添加战斗统计
func _add_battle_statistics() -> void:
	var category = _create_stat_category("⚔️ 战斗统计")

	var stats = [
		"总战斗场次",
		"胜利场次",
		"胜率",
		"总击杀",
		"平均击杀/场"
	]

	for stat_name in stats:
		if _statistics_data.has(stat_name):
			var stat_item = _create_stat_item(stat_name, _statistics_data[stat_name])
			category.add_child(stat_item)

	stats_container.add_child(category)

## 添加收集统计
func _add_collection_statistics() -> void:
	var category = _create_stat_category("📚 收集进度")

	var stats = [
		"收集卡片",
		"解锁蓝图",
		"解锁成就",
		"通关关卡",
		"击败Boss"
	]

	for stat_name in stats:
		if _statistics_data.has(stat_name):
			var stat_item = _create_stat_item(stat_name, _statistics_data[stat_name])
			category.add_child(stat_item)

	stats_container.add_child(category)

## 添加表现统计
func _add_performance_statistics() -> void:
	var category = _create_stat_category("🎯 表现记录")

	var stats = [
		"完美战斗",
		"最快胜利"
	]

	for stat_name in stats:
		if _statistics_data.has(stat_name):
			var stat_item = _create_stat_item(stat_name, _statistics_data[stat_name])
			category.add_child(stat_item)

	stats_container.add_child(category)

## 添加资源统计
func _add_resource_statistics() -> void:
	var category = _create_stat_category("💰 资源统计")

	var stat_item = _create_stat_item("纳米材料总获得", _format_number(_statistics_data.get("总获得", 0)))
	category.add_child(stat_item)

	stat_item = _create_stat_item("纳米材料总花费", _format_number(_statistics_data.get("总花费", 0)))
	category.add_child(stat_item)

	stats_container.add_child(category)

## 创建统计类别
func _create_stat_category(title: String) -> VBoxContainer:
	var container = VBoxContainer.new()
	container.custom_minimum_size = Vector2(0, 120)
	container.add_theme_constant_override("separation", 4)

	# 类别标题
	var title_label = Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 13)
	title_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0, 1))
	container.add_child(title_label)

	# 分隔线
	var separator = HSeparator.new()
	container.add_child(separator)

	return container

## 创建统计项目
func _create_stat_item(label_text: String, value_text: String) -> HBoxContainer:
	var container = HBoxContainer.new()
	container.add_theme_constant_override("separation", 8)

	# 标签
	var label = Label.new()
	label.text = label_text + "："
	label.custom_minimum_size = Vector2(100, 0)
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85, 1))
	container.add_child(label)

	# 值
	var value = Label.new()
	value.text = value_text
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.add_theme_font_size_override("font_size", 11)
	value.add_theme_color_override("font_color", Color(0.3, 0.9, 0.5, 1))
	container.add_child(value)

	return container

## 格式化数字
func _format_number(number: int) -> String:
	if number >= 1000000:
		return "%.1fM" % (number / 1000000.0)
	elif number >= 1000:
		return "%.1fK" % (number / 1000.0)
	else:
		return str(number)

## 统计数据变化回调
func _on_statistic_changed(stat_id: String, new_value: int) -> void:
	_refresh_statistics()

## 关闭按钮
func _on_close() -> void:
	closed.emit()
	queue_free()
