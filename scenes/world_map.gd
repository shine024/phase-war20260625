extends Control
## 大地图：选择 1~100 关（一战 / 二战 / 冷战 / 现代 / 近未来）
## 按时代分组显示，当前关卡高亮

var _map_built: bool = false  # 地图是否已构建（缓存）
static var _cached_level_map_template: Control = null  # 跨场景复用模板，避免每次重建100按钮
static var _cached_star_layers: Dictionary = {}  # 按视口尺寸缓存静态星空点位

func _input(event: InputEvent) -> void:
	# ESC键返回主场景
	if event.is_action("ui_cancel"):
		_on_back_to_title()
		_safe_set_input_handled()
	# 检查是否是键盘事件
	elif event is InputEventKey:
		var key_event = event as InputEventKey
		if key_event.keycode == KEY_ESCAPE:
			_on_back_to_title()
			_safe_set_input_handled()

func _safe_set_input_handled() -> void:
	if not is_inside_tree():
		return
	var vp: Viewport = get_viewport()
	if vp != null and is_instance_valid(vp) and vp.is_inside_tree():
		vp.set_input_as_handled()

const LevelEras = preload("res://data/level_eras.gd")
const LevelInformation = preload("res://data/level_information.gd")
const BasicResourcesData = preload("res://data/basic_resources.gd")
const EnemyArchetypesData = preload("res://data/enemy_archetypes.gd")
const DefaultCardsData = preload("res://data/default_cards.gd")
const PhaseLawsData = preload("res://data/phase_laws.gd")
const DropTablesPreview = preload("res://resources/drop_tables.gd")
const LEVEL_COUNT: int = LevelEras.LEVEL_COUNT
const LEVELS_PER_ROW: int = 10
const ERA_SIZE: int = 20  # 每时代 20 关
const DEFAULT_BG_PATH: String = "res://assets/backgrounds/bg_default.png"
# 时代配色方案
const ERA_COLORS: Array = [
	{
		"name": "一战", "icon": "⚔",
		"bg":     Color(0.12, 0.08, 0.05, 0.95),
		"border": Color(0.85, 0.65, 0.3, 0.5),
		"title":  Color(0.95, 0.78, 0.45, 1.0),
		"btn_bg": Color(0.14, 0.09, 0.05, 0.85),
		"btn_active": Color(0.9, 0.65, 0.2, 1.0),
	},
	{
		"name": "二战", "icon": "✈",
		"bg":     Color(0.05, 0.09, 0.05, 0.95),
		"border": Color(0.45, 0.8, 0.35, 0.5),
		"title":  Color(0.55, 0.95, 0.45, 1.0),
		"btn_bg": Color(0.06, 0.11, 0.06, 0.85),
		"btn_active": Color(0.4, 0.95, 0.35, 1.0),
	},
	{
		"name": "冷战", "icon": "☢",
		"bg":     Color(0.05, 0.05, 0.13, 0.95),
		"border": Color(0.35, 0.55, 0.95, 0.5),
		"title":  Color(0.45, 0.7, 1.0, 1.0),
		"btn_bg": Color(0.05, 0.06, 0.15, 0.85),
		"btn_active": Color(0.4, 0.65, 1.0, 1.0),
	},
	{
		"name": "现代", "icon": "🚀",
		"bg":     Color(0.04, 0.10, 0.12, 0.95),
		"border": Color(0.0, 0.85, 0.95, 0.5),
		"title":  Color(0.2, 0.95, 1.0, 1.0),
		"btn_bg": Color(0.04, 0.12, 0.14, 0.85),
		"btn_active": Color(0.0, 0.94, 1.0, 1.0),
	},
	{
		"name": "近未来", "icon": "⚡",
		"bg":     Color(0.10, 0.04, 0.14, 0.95),
		"border": Color(0.75, 0.35, 1.0, 0.5),
		"title":  Color(0.85, 0.5, 1.0, 1.0),
		"btn_bg": Color(0.12, 0.05, 0.17, 0.85),
		"btn_active": Color(0.8, 0.45, 1.0, 1.0),
	},
]

var _stars: Array = []
var _level_info_popup: Window = null
var _runtime_active: bool = false

## 信号：当用户点击返回主界面时发出
signal back_to_main()


func _enter_tree() -> void:
	pass

func _ready() -> void:
	_generate_stars()
	# 延迟一帧再生成地图，避免启动时卡顿
	call_deferred("_build_level_map")
	visibility_changed.connect(_on_visibility_changed)
	_on_visibility_changed()

	# 多种方式尝试找到返回按钮
	var back_btn: Button = get_node_or_null("Margin/VBox/BackToTitleButton")
	if back_btn == null:
		# 尝试相对路径
		back_btn = $Margin/VBox/BackToTitleButton
	if back_btn == null:
		# 尝试直接查找
		back_btn = find_child("BackToTitleButton", true, false)

	if back_btn:
		back_btn.pressed.connect(_on_back_to_title)
		# 美化返回按钮
		_style_back_button(back_btn)
	else:
		push_warning("[WorldMap] ⚠️ 返回按钮未找到！")

	# 美化标题
	_style_title()

func _on_visibility_changed() -> void:
	_runtime_active = is_visible_in_tree()
	set_process(false)
	if _runtime_active:
		queue_redraw()

func _generate_stars() -> void:
	var vp_size = get_viewport_rect().size
	var w = max(vp_size.x, 1280.0)
	var h = max(vp_size.y, 720.0)
	var cache_key: String = "%dx%d" % [int(w), int(h)]
	if _cached_star_layers.has(cache_key):
		_stars = (_cached_star_layers[cache_key] as Array).duplicate(true)
		return
	_stars.clear()
	var rng = RandomNumberGenerator.new()
	# 固定种子：保持背景静态一致，不再每次随机变化
	rng.seed = int(w) * 73856093 + int(h) * 19349663
	for i in range(80):
		_stars.append({
			"x": rng.randf_range(0, w),
			"y": rng.randf_range(0, h),
			"size": rng.randf_range(0.5, 2.0),
			"alpha": rng.randf_range(0.25, 0.65),
		})
	_cached_star_layers[cache_key] = _stars.duplicate(true)

func _style_title() -> void:
	var title_l: Label = get_node_or_null("Margin/VBox/TitleLabel")
	if title_l:
		title_l.add_theme_font_size_override("font_size", 26)
		title_l.add_theme_color_override("font_color", Color(0, 0.941, 1, 1))
		title_l.text = "— 战区地图 · 100 关 —"

func _style_back_button(btn: Button) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.06, 0.1, 0.17, 0.9)
	s.border_width_left = 1; s.border_width_top = 1
	s.border_width_right = 1; s.border_width_bottom = 1
	s.border_color = Color(0, 0.75, 0.85, 0.6)
	s.corner_radius_top_left = 5; s.corner_radius_top_right = 5
	s.corner_radius_bottom_right = 5; s.corner_radius_bottom_left = 5
	btn.add_theme_stylebox_override("normal", s)
	btn.add_theme_color_override("font_color", Color(0, 0.94, 1, 1))
	btn.add_theme_font_size_override("font_size", 14)

func _build_level_map() -> void:
	# 缓存检查：如果地图已构建，跳过
	if _map_built:
		print("[WorldMap] 地图已构建，跳过重复生成")
		return

	var container: GridContainer = get_node_or_null("Margin/VBox/ScrollContainer/LevelGrid") as GridContainer
	# 使用 ScrollContainer/LevelGrid 节点，但我们把 GridContainer 替换为 VBoxContainer 布局
	var scroll: ScrollContainer = get_node_or_null("Margin/VBox/ScrollContainer")
	if scroll == null:
		return
	# 清空旧内容
	for c in scroll.get_children():
		c.queue_free()

	# 跨实例缓存命中：直接复用模板副本，跳过按钮重建与样式计算
	if _cached_level_map_template != null and is_instance_valid(_cached_level_map_template):
		var reused := _cached_level_map_template.duplicate(Node.DUPLICATE_USE_INSTANTIATION) as Control
		if reused != null:
			scroll.add_child(reused)
			_map_built = true
			print("[WorldMap] 使用缓存地图模板，跳过100按钮重建")
			return

	# 创建新的内容 VBox
	var content_vbox := VBoxContainer.new()
	content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_vbox.add_theme_constant_override("separation", 12)
	scroll.add_child(content_vbox)

	var current_level: int = GameManager.current_level if GameManager else 1
	var _btn_count: int = 0

	for era_idx in range(5):
		var era_info: Dictionary = ERA_COLORS[era_idx]
		var era_start: int = era_idx * ERA_SIZE + 1
		var era_end: int = era_start + ERA_SIZE - 1

		# 时代区块容器
		var era_panel := PanelContainer.new()
		var era_style := StyleBoxFlat.new()
		era_style.bg_color = era_info["bg"]
		era_style.border_width_left = 2
		era_style.border_width_top = 2
		era_style.border_width_right = 2
		era_style.border_width_bottom = 2
		era_style.border_color = era_info["border"]
		era_style.corner_radius_top_left = 8
		era_style.corner_radius_top_right = 8
		era_style.corner_radius_bottom_right = 8
		era_style.corner_radius_bottom_left = 8
		era_panel.add_theme_stylebox_override("panel", era_style)

		var era_margin := MarginContainer.new()
		era_margin.add_theme_constant_override("margin_left", 12)
		era_margin.add_theme_constant_override("margin_right", 12)
		era_margin.add_theme_constant_override("margin_top", 10)
		era_margin.add_theme_constant_override("margin_bottom", 10)

		var era_vbox := VBoxContainer.new()
		era_vbox.add_theme_constant_override("separation", 8)

		# 时代标题
		var header_hbox := HBoxContainer.new()
		header_hbox.add_theme_constant_override("separation", 8)

		var icon_lbl := Label.new()
		icon_lbl.text = era_info["icon"]
		icon_lbl.add_theme_font_size_override("font_size", 18)
		icon_lbl.add_theme_color_override("font_color", era_info["title"])
		header_hbox.add_child(icon_lbl)

		var title_lbl := Label.new()
		title_lbl.text = "%s  第 %d–%d 关" % [era_info["name"], era_start, era_end]
		title_lbl.add_theme_font_size_override("font_size", 16)
		title_lbl.add_theme_color_override("font_color", era_info["title"])
		title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header_hbox.add_child(title_lbl)

		era_vbox.add_child(header_hbox)

		# 分割线
		var sep := HSeparator.new()
		sep.add_theme_color_override("color", era_info["border"])
		era_vbox.add_child(sep)

		# 关卡按钮网格
		var grid := GridContainer.new()
		grid.columns = LEVELS_PER_ROW
		grid.add_theme_constant_override("h_separation", 5)
		grid.add_theme_constant_override("v_separation", 5)

		for j in range(ERA_SIZE):
			var level_index: int = era_start + j
			var btn := _make_level_button(level_index, era_idx, era_info, current_level)
			_btn_count += 1
			grid.add_child(btn)

		era_vbox.add_child(grid)
		era_margin.add_child(era_vbox)
		era_panel.add_child(era_margin)
		content_vbox.add_child(era_panel)
		# 拆帧构建：降低一次性创建100按钮造成的主线程尖峰
		await get_tree().process_frame

	# 标记地图已构建
	_cached_level_map_template = content_vbox.duplicate(Node.DUPLICATE_USE_INSTANTIATION) as Control
	_map_built = true
	print("[WorldMap] 地图构建完成，共创建 ", _btn_count, " 个关卡按钮")

## 刷新地图（清除缓存，强制重新生成）
func refresh_levels() -> void:
	_map_built = false
	# 当前关卡高亮依赖构建时的 current_level；刷新时禁用静态模板复用，避免高亮停留在旧关卡
	_cached_level_map_template = null
	_build_level_map()

func _make_level_button(level_index: int, _era_idx: int, era_info: Dictionary, current_level: int) -> Button:
	var btn := Button.new()
	btn.text = "%d" % level_index
	btn.name = "LevelButton%d" % level_index
	btn.custom_minimum_size = Vector2(52, 36)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", 12)
	btn.alignment = HORIZONTAL_ALIGNMENT_CENTER

	var is_current: bool = (level_index == current_level)
	var btn_style := StyleBoxFlat.new()

	if is_current:
		# 当前关卡：亮青/时代色高亮
		btn_style.bg_color = Color(era_info["btn_active"].r * 0.2,
			era_info["btn_active"].g * 0.2,
			era_info["btn_active"].b * 0.2, 0.9)
		btn_style.border_width_left = 2; btn_style.border_width_top = 2
		btn_style.border_width_right = 2; btn_style.border_width_bottom = 2
		btn_style.border_color = era_info["btn_active"]
		btn_style.shadow_color = Color(era_info["btn_active"].r, era_info["btn_active"].g,
			era_info["btn_active"].b, 0.5)
		btn_style.shadow_size = 4
		btn.add_theme_color_override("font_color", era_info["btn_active"])
		btn.add_theme_font_size_override("font_size", 13)
	else:
		btn_style.bg_color = era_info["btn_bg"]
		btn_style.border_width_left = 1; btn_style.border_width_top = 1
		btn_style.border_width_right = 1; btn_style.border_width_bottom = 1
		btn_style.border_color = Color(era_info["border"].r, era_info["border"].g,
			era_info["border"].b, 0.35)
		btn.add_theme_color_override("font_color", Color(
			era_info["title"].r, era_info["title"].g, era_info["title"].b, 0.75))

	btn_style.corner_radius_top_left = 4
	btn_style.corner_radius_top_right = 4
	btn_style.corner_radius_bottom_right = 4
	btn_style.corner_radius_bottom_left = 4
	btn.add_theme_stylebox_override("normal", btn_style)

	# hover 样式
	var hover_style := btn_style.duplicate() as StyleBoxFlat
	hover_style.bg_color = Color(
		era_info["btn_active"].r * 0.15 + 0.04,
		era_info["btn_active"].g * 0.15 + 0.04,
		era_info["btn_active"].b * 0.15 + 0.04, 0.95)
	hover_style.border_color = Color(
		era_info["btn_active"].r, era_info["btn_active"].g,
		era_info["btn_active"].b, 0.7)
	btn.add_theme_stylebox_override("hover", hover_style)
	btn.add_theme_color_override("font_hover_color", era_info["btn_active"])

	btn.pressed.connect(func() -> void: _on_level_selected(level_index))
	return btn

func _process(_delta: float) -> void:
	pass

func _draw() -> void:
	if not _runtime_active:
		return
	var vp_size = get_viewport_rect().size

	# 星星
	for s in _stars:
		draw_circle(Vector2(s["x"], s["y"]), s["size"], Color(0.7, 0.9, 1.0, s["alpha"]))

	# 静态扫描线（不再动态滚动）
	var scan_color := Color(0, 0.941, 1, 0.025)
	var scan_step := 36.0
	var y := 0.0
	while y < vp_size.y:
		draw_line(Vector2(0, y), Vector2(vp_size.x, y), scan_color, 1.0)
		y += scan_step

	# 底部装饰线
	draw_line(Vector2(0, vp_size.y - 2), Vector2(vp_size.x, vp_size.y - 2),
		Color(0, 0.941, 1, 0.25), 2.0)

func _on_back_to_title() -> void:
	# 嵌入到 Main 的 MapOverlay 时，不切场景，改为通知父层关闭。
	if has_meta("embedded_mode") and bool(get_meta("embedded_mode")):
		back_to_main.emit()
		return
	# 独立场景模式：直接切换回主场景
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_level_selected(level_index: int) -> void:
	_show_level_info_popup(level_index)

func _show_level_info_popup(level_index: int) -> void:
	if _level_info_popup and is_instance_valid(_level_info_popup):
		_level_info_popup.queue_free()
	var popup := Window.new()
	popup.title = "关卡情报"
	popup.size = Vector2i(620, 540)
	popup.unresizable = false
	# 同步 queue_free 可能在输入分发中途拆掉 Window 视口，触发 Viewport::_push_unhandled_input_internal 断言
	popup.close_requested.connect(_close_popup_safe.bind(popup))
	add_child(popup)
	_level_info_popup = popup

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	popup.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var info: Dictionary = _collect_level_info(level_index)
	var title := Label.new()
	title.text = "Lv.%d  %s" % [level_index, String(info.get("display_name", ""))]
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0, 0.94, 1, 1))
	vbox.add_child(title)

	var desc := Label.new()
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.text = String(info.get("description", ""))
	desc.add_theme_font_size_override("font_size", 13)
	desc.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95, 0.95))
	vbox.add_child(desc)

	var env := Label.new()
	env.text = "环境: %s / %s / %s / %s" % [
		String(info.get("weather", "?")),
		String(info.get("terrain", "?")),
		String(info.get("energy_field", "?")),
		String(info.get("time_of_day", "?"))
	]
	env.add_theme_font_size_override("font_size", 12)
	env.add_theme_color_override("font_color", Color(0.75, 0.85, 1, 0.95))
	vbox.add_child(env)

	var bg := Label.new()
	bg.text = "关卡背景: %s (%s)" % [
		String(info.get("background_path", "")),
		"已找到" if bool(info.get("background_exists", false)) else "未找到"
	]
	bg.add_theme_font_size_override("font_size", 12)
	bg.add_theme_color_override("font_color", Color(0.8, 0.9, 0.9, 0.95))
	vbox.add_child(bg)

	var reward := Label.new()
	var recon_bonus: float = 0.0
	if GameManager and GameManager.has_method("_get_recon_fragment_bonus_multiplier"):
		recon_bonus = float(GameManager._get_recon_fragment_bonus_multiplier())
	var base_fragment_chance_percent: float = float(info.get("fragment_chance_percent", 0.0))
	var preview_fragment_chance_percent: float = base_fragment_chance_percent * (1.0 + recon_bonus)
	reward.text = "掉落预览: 能量块 +%d, 纳米材料 +%d, 合金 +%d, 晶体 +%d, 蓝图概率 %.1f%% → %.1f%%（侦查加成 %+d%%）" % [
		int(info.get("energy_block_drop", 0)),
		int(info.get("nano_materials_drop", 0)),
		int(info.get("alloy_drop", 0)),
		int(info.get("crystal_drop", 0)),
		base_fragment_chance_percent,
		preview_fragment_chance_percent,
		int(round(recon_bonus * 100.0))
	]
	reward.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reward.add_theme_font_size_override("font_size", 12)
	reward.add_theme_color_override("font_color", Color(0.9, 0.95, 0.8, 0.95))
	vbox.add_child(reward)

	var enemies := Label.new()
	enemies.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	enemies.text = "敌人预览: %s" % String(info.get("enemy_preview", "未知"))
	enemies.add_theme_font_size_override("font_size", 12)
	enemies.add_theme_color_override("font_color", Color(1, 0.85, 0.7, 0.95))
	vbox.add_child(enemies)

	var drops := Label.new()
	drops.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	drops.text = "敌方可能掉落: %s" % String(info.get("enemy_drop_preview", "无"))
	drops.add_theme_font_size_override("font_size", 12)
	drops.add_theme_color_override("font_color", Color(0.9, 0.82, 1, 0.95))
	vbox.add_child(drops)

	var laws := Label.new()
	laws.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	laws.text = "法则限制: %s" % String(info.get("law_preview", "全部可用"))
	laws.add_theme_font_size_override("font_size", 12)
	laws.add_theme_color_override("font_color", Color(0.75, 0.9, 1, 0.95))
	vbox.add_child(laws)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	btn_row.add_theme_constant_override("separation", 10)
	var close_btn := Button.new()
	close_btn.text = "关闭"
	close_btn.pressed.connect(_close_popup_safe.bind(popup))
	btn_row.add_child(close_btn)
	var enter_btn := Button.new()
	enter_btn.text = "进入该关"
	enter_btn.pressed.connect(_enter_level_from_popup.bind(level_index, popup))
	btn_row.add_child(enter_btn)
	vbox.add_child(btn_row)
	popup.popup_centered()

func _close_popup_safe(popup: Window) -> void:
	if is_instance_valid(popup):
		popup.call_deferred("queue_free")

func _enter_level_from_popup(level_index: int, popup: Window) -> void:
	if GameManager and GameManager.has_method("set_current_level"):
		GameManager.set_current_level(level_index)
	_close_popup_safe(popup)
	if has_meta("embedded_mode") and bool(get_meta("embedded_mode")):
		back_to_main.emit()
		return
	# 独立场景模式：切回主场景
	# 同步切场景会在按键输入分发中途释放本 Window 视口，易触发 Viewport::_push_unhandled_input_internal
	get_tree().call_deferred("change_scene_to_file", "res://scenes/main.tscn")

func _collect_level_info(level_index: int) -> Dictionary:
	var info_db = LevelInformation.new()
	var li: Dictionary = info_db.get_level_info(level_index)
	var env: Dictionary = li.get("environment", {})
	var drops: Dictionary = BasicResourcesData.get_drops_for_level(level_index)
	var era: int = LevelEras.get_era(level_index)
	var enemy_ids: Array = EnemyArchetypesData.get_ids_for_era(era)
	enemy_ids.sort()
	var level_enemy_ids: Array = _pick_level_enemy_ids(level_index, enemy_ids)
	var enemy_names: Array = []
	var drop_names: Array = []
	var drop_ids_all: Array = []
	for i in range(mini(level_enemy_ids.size(), 5)):
		var eid: String = String(level_enemy_ids[i])
		var cfg: Dictionary = EnemyArchetypesData.get_config(eid)
		var ename: String = String(cfg.get("display_name", eid))
		enemy_names.append(ename)
		var ds: Array = EnemyArchetypesData.get_drop_definitions(eid)
		for d in ds:
			if d is Dictionary:
				var cid: String = String(d.get("card_id", ""))
				if cid.is_empty():
					continue
				var c = null
				var n: String = c.display_name if c else DefaultCardsData.get_safe_display_name(cid)
				if not drop_names.has(n):
					drop_names.append(n)
	# 统计该关敌人池的可能掉落（关卡专属口径）
	for eid_val in level_enemy_ids:
		var eid_all: String = String(eid_val)
		var all_drops: Array = EnemyArchetypesData.get_drop_definitions(eid_all)
		for d_all in all_drops:
			if d_all is Dictionary:
				var cid_all: String = String(d_all.get("card_id", ""))
				if cid_all.is_empty():
					continue
				if not drop_ids_all.has(cid_all):
					drop_ids_all.append(cid_all)
	var allowed_laws: Array = info_db.get_available_laws_for_level(level_index)
	var law_preview: String = "全部可用"
	if not allowed_laws.is_empty():
		var law_names: Array = []
		for law_id in allowed_laws:
			var cfg_law: Dictionary = PhaseLawsData.get_by_id(String(law_id))
			law_names.append(String(cfg_law.get("name", String(law_id))))
		law_preview = ", ".join(law_names)
	var bg_idx: int = ((level_index - 1) % 10) + 1
	var bg_path: String = "res://assets/backgrounds/bg_%02d.png" % bg_idx
	var bg_exists: bool = ResourceLoader.exists(bg_path)
	var fallback_exists: bool = ResourceLoader.exists(DEFAULT_BG_PATH)
	var selected_bg_path: String = bg_path if bg_exists else (DEFAULT_BG_PATH if fallback_exists else "")
	
	# 根据关卡号生成掉落预览，使用不同的掉落组合
	var rng = RandomNumberGenerator.new()
	rng.seed = level_index * 7919  # 使用大质数作为种子，让不同关卡差异更大
	
	# 优先显示与该关卡敌人相关的掉落
	var drop_preview_text: String = "无"
	var display_drops: Array = []
	
	# 从该时代所有可掉落中，根据关卡号选择不同的掉落
	if not drop_ids_all.is_empty():
		# 按稀有度分组
		var common_drops: Array = []
		var rare_drops: Array = []
		var epic_drops: Array = []
		var mythic_drops: Array = []
		
		for cid in drop_ids_all:
			var c = null
			if c:
				match c.rarity:
					"common":
						common_drops.append(c.display_name)
					"uncommon":
						rare_drops.append(c.display_name)
					"rare":
						epic_drops.append(c.display_name)
					"epic", "mythic":
						mythic_drops.append(c.display_name)
		
		# 根据关卡难度决定掉落组合
		var era_level = (level_index - 1) % 20 + 1  # 时代内关卡号 1-20
		var difficulty_tier = era_level / 5  # 1-4 (整数除法，故意为之)
		
		# 高难度关卡有更高概率显示稀有掉落
		var show_mythic = era_level >= 18 and difficulty_tier >= 3
		var show_epic = era_level >= 12 or difficulty_tier >= 2
		var show_rare = era_level >= 6
		
		# 构建掉落列表
		if mythic_drops.size() > 0 and show_mythic:
			var mythic_idx = rng.randi() % mythic_drops.size()
			display_drops.append(mythic_drops[mythic_idx])
		
		if show_epic and epic_drops.size() > 0:
			var count = mini(2 if difficulty_tier >= 3 else 1, epic_drops.size())
			for k in range(count):
				if epic_drops.size() > 0:
					var idx = rng.randi() % epic_drops.size()
					display_drops.append(epic_drops[idx])
					epic_drops.remove_at(idx)
		
		if show_rare and rare_drops.size() > 0:
			var count = mini(2 if difficulty_tier >= 2 else 1, rare_drops.size())
			for k in range(count):
				if rare_drops.size() > 0:
					var idx = rng.randi() % rare_drops.size()
					display_drops.append(rare_drops[idx])
					rare_drops.remove_at(idx)
		
		# 填充普通掉落直到有3-5个
		while display_drops.size() < 4 and not common_drops.is_empty():
			if common_drops.size() > 0:
				var idx = rng.randi() % common_drops.size()
				display_drops.append(common_drops[idx])
				common_drops.remove_at(idx)
			else:
				break
		
		# 打乱最终顺序
		for i in range(display_drops.size()):
			var j = rng.randi() % display_drops.size()
			var temp = display_drops[i]
			display_drops[i] = display_drops[j]
			display_drops[j] = temp
		
		# 限制显示数量
		display_drops.resize(mini(display_drops.size(), 5))
		drop_preview_text = ", ".join(display_drops)
		
		if drop_ids_all.size() > display_drops.size():
			drop_preview_text += " 等%d种" % drop_ids_all.size()
	elif not drop_names.is_empty():
		drop_preview_text = ", ".join(drop_names.slice(0, 3))
	# 与战后 DropTables CARD_DATA 池对齐的示例（敌方原型表常为空或与结算不一致）
	var dt_preview = DropTablesPreview.new()
	if dt_preview != null and dt_preview.has_method("sample_era_blueprint_display_names_for_preview"):
		var bp_line: PackedStringArray = dt_preview.sample_era_blueprint_display_names_for_preview(era, level_index, 4)
		if not bp_line.is_empty():
			var sample_txt: String = ", ".join(bp_line)
			if drop_preview_text == "无":
				drop_preview_text = "%s（每场战功卡随机）" % sample_txt
			else:
				drop_preview_text = "%s · 战功卡池示例: %s" % [drop_preview_text, sample_txt]
	var out: Dictionary = {
		"display_name": String(li.get("display_name", "第%d关" % level_index)),
		"description": String(li.get("description", "")),
		"weather": String(env.get("weather", "")),
		"terrain": String(env.get("terrain", "")),
		"energy_field": String(env.get("energy_field", "")),
		"time_of_day": String(env.get("time_of_day", "")),
		"background_path": selected_bg_path,
		"background_exists": bg_exists,
		"background_fallback_used": (not bg_exists and fallback_exists),
		"nano_materials_drop": int(drops.get("basic_nano", 0)),
		"energy_block_drop": int(drops.get("energy_block", 0)),
		"nano_material_drop": 5 + level_index * 2,
		"fragment_chance_percent": (0.25 + level_index * 0.002) * 100.0,
		"enemy_preview": ", ".join(enemy_names),
		"enemy_drop_preview": drop_preview_text,
		"law_preview": law_preview,
	}
	return out

func _pick_level_enemy_ids(level_index: int, era_enemy_ids: Array) -> Array:
	if era_enemy_ids.is_empty():
		return []
	var in_era: int = ((level_index - 1) % ERA_SIZE) + 1
	# 关卡越后，敌人池越大：早期更聚焦，后期更丰富
	var target_count: int = clampi(4 + int((in_era - 1) / 4), 4, 10)
	target_count = mini(target_count, era_enemy_ids.size())
	var rng := RandomNumberGenerator.new()
	rng.seed = int(level_index) * 2654435761
	var shuffled: Array = era_enemy_ids.duplicate()
	for i in range(shuffled.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var t = shuffled[i]
		shuffled[i] = shuffled[j]
		shuffled[j] = t
	var picked: Array = []
	for i in range(target_count):
		picked.append(shuffled[i])
	return picked

## 仅在地图打开时执行的轻量刷新（避免每次重建100个按钮）
func refresh_for_open() -> void:
	_on_visibility_changed()
	if not _map_built:
		_build_level_map()
