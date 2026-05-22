extends HBoxContainer
## 新功能按钮栏：添加新系统的按钮

func _ready() -> void:
	add_theme_constant_override("separation", 8)

	# 创建新系统的按钮
	_create_daily_task_button()
	_create_challenge_button()
	_create_collection_button()
	_create_achievement_button()

func _create_daily_task_button() -> void:
	var button = Button.new()
	button.text = "日常"
	button.custom_minimum_size = Vector2(80, 35)
	button.tooltip_text = "查看日常任务"
	button.pressed.connect(_on_daily_task_pressed)
	add_child(button)

func _create_challenge_button() -> void:
	var button = Button.new()
	button.text = "挑战"
	button.custom_minimum_size = Vector2(80, 35)
	button.tooltip_text = "查看挑战模式"
	button.pressed.connect(_on_challenge_pressed)
	add_child(button)

func _create_collection_button() -> void:
	var button = Button.new()
	button.text = "图鉴"
	button.custom_minimum_size = Vector2(80, 35)
	button.tooltip_text = "查看卡牌图鉴"
	button.pressed.connect(_on_collection_pressed)
	add_child(button)

func _create_achievement_button() -> void:
	var button = Button.new()
	button.text = "成就"
	button.custom_minimum_size = Vector2(80, 35)
	button.tooltip_text = "查看成就"
	button.pressed.connect(_on_achievement_pressed)
	add_child(button)

func _on_daily_task_pressed() -> void:
	_open_panel("DailyTaskPanel", "日常任务")

func _on_challenge_pressed() -> void:
	_open_panel("ChallengeModePanel", "挑战模式")

func _on_collection_pressed() -> void:
	_open_panel("CardCollectionPanel", "卡牌图鉴")

func _on_achievement_pressed() -> void:
	_open_panel("AchievementPanel", "成就")

func _open_panel(panel_name: String, panel_title: String) -> void:
	# 尝试加载面板场景
	var panel_scene = load("res://scenes/ui/" + panel_name.to_lower() + ".tscn")
	if panel_scene:
		var panel = panel_scene.instantiate()
		if panel:
			# 添加到主场景的弹出层
			var main_scene = get_tree().current_scene
			if main_scene:
				var popup_layer = main_scene.get_node_or_null("PopupLayer")
				if popup_layer:
					popup_layer.add_child(panel)
					panel.popup_centered()
				else:
					# 如果没有PopupLayer，直接添加到根节点
					get_tree().root.add_child(panel)
					panel.popup_centered()
	else:
		# 如果场景不存在，显示提示
		push_error("面板 " + panel_name + " 尚未实现，请先创建UI场景文件")
