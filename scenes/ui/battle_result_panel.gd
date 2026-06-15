extends Control

## 战斗结算面板

signal panel_closed
signal rewards_claimed

var victory: bool = false
var victory_stars: int = 0
var drop_results: Array = []

@onready var title_label = $Panel/VBoxContainer/TitleLabel
@onready var subtitle_label = $Panel/VBoxContainer/SubtitleLabel
@onready var stars_container = $Panel/VBoxContainer/StarsContainer
@onready var drops_scroll = $Panel/VBoxContainer/DropsContainer/DropsScroll
@onready var drops_list = $Panel/VBoxContainer/DropsContainer/DropsScroll/DropsList
@onready var claim_button = $Panel/VBoxContainer/ButtonsContainer/ClaimButton
@onready var close_button = $Panel/VBoxContainer/ButtonsContainer/CloseButton

func _ready():
	claim_button.pressed.connect(_on_claim_pressed)
	close_button.pressed.connect(_on_close_pressed)

## 设置战斗结果
func set_battle_result(is_victory: bool, stars: int = 0):
	victory = is_victory
	victory_stars = stars

	# 设置标题和副标题
	if victory:
		title_label.text = "⭐ 战斗胜利！ ⭐"
		title_label.modulate = Color(1.0, 0.9, 0.4)  # 金色

		match stars:
			3:
				subtitle_label.text = "完美表现！"
				subtitle_label.modulate = Color(1.0, 0.8, 0.0)
			2:
				subtitle_label.text = "表现出色！"
				subtitle_label.modulate = Color(0.8, 0.9, 1.0)
			1:
				subtitle_label.text = "艰难获胜"
				subtitle_label.modulate = Color(0.9, 0.9, 0.9)
			_:
				subtitle_label.text = "战斗胜利"
				subtitle_label.modulate = Color(0.9, 0.9, 0.9)
	else:
		title_label.text = "战斗失败"
		title_label.modulate = Color(0.8, 0.3, 0.3)  # 红色
		subtitle_label.text = "再接再厉..."
		subtitle_label.modulate = Color(0.7, 0.7, 0.7)

	# 显示星级
	_update_stars_display()

	# 获取掉落
	_fetch_drops()

## 更新星级显示（带动画）
func _update_stars_display():
	# 清空现有星级
	for child in stars_container.get_children():
		child.queue_free()

	if victory and victory_stars > 0:
		for i in range(3):
			var star_tex: Texture2D = UiAssetLoader.star_icon(5 if i < victory_stars else 1)
			var star_rect := TextureRect.new()
			star_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			star_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			star_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			star_rect.custom_minimum_size = Vector2(40, 40)
			star_rect.texture = star_tex
			if i >= victory_stars:
				star_rect.modulate = Color(0.45, 0.45, 0.5, 0.85)
			else:
				star_rect.modulate = Color(1.0, 0.95, 0.75, 1.0)
			stars_container.add_child(star_rect)

			# 星级弹入动画（延迟0.3秒逐个显示）
			var delay = i * 0.3
			var tween = create_tween()
			tween.tween_interval(delay)
			# 初始状态：缩小且透明
			star_rect.scale = Vector2(0.1, 0.1)
			star_rect.modulate.a = 0.0
			# 弹入效果：放大+淡入
			tween.set_parallel(true)
			tween.tween_property(star_rect, "scale", Vector2(1.2, 1.2), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.tween_property(star_rect, "modulate:a", 1.0, 0.2)
			tween.set_parallel(false)
			# 回弹到正常大小
			tween.tween_property(star_rect, "scale", Vector2(1.0, 1.0), 0.1).set_ease(Tween.EASE_IN)

## 获取掉落数据
func _fetch_drops():
	# 从DropManager单例获取掉落
	drop_results.clear()

	var dm = get_node_or_null("/root/DropManager")
	if dm and dm.has_method("get_pending_drops"):
		drop_results = dm.get_pending_drops()

	# 显示掉落
	_display_drops()

## 显示掉落列表
func _display_drops():
	# 清空列表
	for child in drops_list.get_children():
		child.queue_free()

	if drop_results.is_empty():
		var no_drops_label = Label.new()
		no_drops_label.text = "本次战斗无掉落"
		no_drops_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		no_drops_label.modulate = Color(0.6, 0.6, 0.6)
		drops_list.add_child(no_drops_label)
		return

	# 按类型分组显示
	var current_category = ""
	for drop in drop_results:
		var drop_info = _get_drop_info_from_manager(drop)

		# 创建掉落项
		var drop_item = _create_drop_item(drop_info)
		drops_list.add_child(drop_item)

## 从DropManager获取掉落信息
func _get_drop_info_from_manager(drop: DropTables.DropResult) -> Dictionary:
	var dm = get_node_or_null("/root/DropManager")
	if dm and dm.has_method("get_drop_info"):
		return dm.get_drop_info(drop)
	else:
		# 降级处理：直接使用DropTables
		var tables = DropTables.new()
		return {
			"name": tables.get_drop_display_name(drop.drop),
			"count": drop.count,
			"source": drop.source,
			"type": drop.drop.type,
			"color": tables.get_drop_rarity_color(drop.drop),
			"icon": tables.get_drop_icon_path(drop.drop)
		}

## 创建单个掉落项UI
func _create_drop_item(info: Dictionary) -> Control:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)

	# 图标（占位，使用文本）
	var icon_label = Label.new()
	var icon_text = _get_icon_for_type(info["type"])
	icon_label.text = icon_text
	icon_label.custom_minimum_size = Vector2(40, 40)
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_label.modulate = info["color"]
	hbox.add_child(icon_label)

	# 物品信息
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# 名称
	var name_label = Label.new()
	name_label.text = info["name"]
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.modulate = info["color"]
	vbox.add_child(name_label)

	# 数量和来源
	var detail_label = Label.new()
	detail_label.text = "x%d  |  %s" % [info["count"], info["source"]]
	detail_label.add_theme_font_size_override("font_size", 12)
	detail_label.modulate = Color(0.7, 0.7, 0.7)
	vbox.add_child(detail_label)

	hbox.add_child(vbox)

	# 分隔线
	var separator = HSeparator.new()
	separator.add_theme_constant_override("separation", 5)

	var container = VBoxContainer.new()
	container.add_child(hbox)
	container.add_child(separator)

	return container

## 根据类型获取图标文本
func _get_icon_for_type(type: int) -> String:
	match type:
		DropTables.DropType.MATERIAL:
			return "🔩"
		DropTables.DropType.CARD_DATA, DropTables.DropType.BLUEPRINT_FRAGMENT:
			return "📦"
		DropTables.DropType.LAW_DATA, DropTables.DropType.LAW_BLUEPRINT:
			return "📜"
		DropTables.DropType.ENERGY_DATA, DropTables.DropType.ENERGY_BLUEPRINT:
			return "⚡"
		DropTables.DropType.LORE_PAGE:
			return "📄"
		DropTables.DropType.CARD_REWARD:
			return "🃏"
		DropTables.DropType.ENERGY_CARD:
			return "⚡"
		DropTables.DropType.STAT_BOOST:
			return "📈"
		_:
			return "•"

## 领取奖励按钮
func _on_claim_pressed():
	var dm = get_node_or_null("/root/DropManager")
	if dm and dm.has_method("claim_drops"):
		dm.claim_drops()
	rewards_claimed.emit()
	_claim_animation()

## 领取动画效果
func _claim_animation():
	claim_button.disabled = true
	claim_button.text = "已领取！"

	# 禁用关闭按钮，延迟后允许
	close_button.disabled = true

	# 1秒后自动关闭
	await get_tree().create_timer(1.0).timeout
	if not is_inside_tree():
		return
	_on_close_pressed()

## 关闭面板
func _on_close_pressed():
	panel_closed.emit()
	queue_free()

## 设置为模态（需要处理背景点击）
func _input(event):
	if not is_inside_tree():
		return
	if not visible:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			# 检查是否点击在面板外
			var local_pos = get_global_transform().affine_inverse() * event.global_position
			if not get_rect().has_point(local_pos):
				if is_inside_tree():
					var vp: Viewport = get_viewport()
					if vp != null and is_instance_valid(vp) and vp.is_inside_tree():
						vp.set_input_as_handled()
				# 避免在输入分发过程中同步 queue_free，触发 Viewport is_inside_tree 断言
				call_deferred("_on_close_pressed")
