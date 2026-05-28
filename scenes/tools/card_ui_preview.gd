extends Control
## 战斗卡 UI 排版实时调节工具
## 拖动滑块即时更新所有预览卡片，找到满意数值后复制到 backpack_card_item.gd
##
## 用法：编辑器 F6 运行此场景，或从游戏内切换场景
## 命令行（默认展示 DefaultCards 全卡池）：见项目说明或关「单卡调试 → single_card_mode」

const GC = preload("res://resources/game_constants.gd")
const StarConfig = preload("res://data/blueprint_star_config.gd")
const DefaultCards = preload("res://data/default_cards.gd")
const CardItemScene = preload("res://scenes/ui/backpack_card_item.tscn")
const SlotScene = preload("res://scenes/ui/phase_slot.tscn")
## 二次元竖卡常用比例 5:7（例 350×490）
const CARD_REFERENCE_5X7 := Vector2i(350, 490)

## ── 所有可调参数（默认值 = 当前代码中的值）──
@export_group("卡片尺寸 (5:7 参考 350×490)")
@export var slot_width: int = 350:
	set(v): slot_width = v; _on_param_changed()
@export var slot_height: int = 490:
	set(v): slot_height = v; _on_param_changed()

@export_group("Minimal 模式")
@export var minimal_mode: bool = true:
	set(v): minimal_mode = v; _on_param_changed()
@export var icon_min_size: int = 72:
	set(v): icon_min_size = v; _on_param_changed()
@export var name_font_size: int = 14:
	set(v): name_font_size = v; _on_param_changed()
@export var name_min_height: int = 96:
	set(v): name_min_height = v; _on_param_changed()
@export var name_max_lines: int = 10:
	set(v): name_max_lines = v; _on_param_changed()

@export_group("MTG 预览排版 (仅 Minimal)")
@export var use_mtg_preview_layout: bool = true:
	set(v): use_mtg_preview_layout = v; _on_param_changed()
## 原画区高度占槽高比例；宽度随内区横向铺满
@export var mtg_art_height_pct: int = 55:
	set(v): mtg_art_height_pct = v; _on_param_changed()

@export_group("Full 模式")
@export var show_type_bar: bool = true:
	set(v): show_type_bar = v; _on_param_changed()
@export var type_bar_height: int = 4:
	set(v): type_bar_height = v; _on_param_changed()
@export var show_stats_row: bool = true:
	set(v): show_stats_row = v; _on_param_changed()
@export var show_level_row: bool = true:
	set(v): show_level_row = v; _on_param_changed()
@export var full_name_font_size: int = 11:
	set(v): full_name_font_size = v; _on_param_changed()
@export var margin_h: int = 3:
	set(v): margin_h = v; _on_param_changed()
@export var margin_top: int = 2:
	set(v): margin_top = v; _on_param_changed()
@export var margin_bottom: int = 3:
	set(v): margin_bottom = v; _on_param_changed()

@export_group("边框与圆角")
@export var corner_radius: int = 8:
	set(v): corner_radius = v; _on_param_changed()
@export var border_width_common: int = 1:
	set(v): border_width_common = v; _on_param_changed()
@export var border_width_rare: int = 2:
	set(v): border_width_rare = v; _on_param_changed()

@export_group("间距")
@export var card_spacing: int = 8:
	set(v): card_spacing = v; _rebuild_layout()
@export var grid_columns: int = 0:
	set(v): grid_columns = v; _rebuild_layout()

@export_group("单卡调试")
## 开启后只显示一张居中卡；关闭则展示 DefaultCards 全卡池与其它测试区（命令行预览全卡请关此项）。
@export var single_card_mode: bool = false
## 使用 DefaultCards 真数据（军衔/星级可走 BlueprintManager）；关则用假卡
@export var single_card_use_real_blueprint: bool = true
## 单卡预览用的蓝图 id（如 omega_platform、platform_cold_medium）；改后调任意滑块或 F5 刷新
@export var single_card_blueprint_id: String = "omega_platform"

## ── 内部状态 ──
var _preview_cards: Array[Control] = []
var _is_building := false
var _dirty := false

func _ready() -> void:
	_is_building = true
	_build_ui()
	_is_building = false
	_refresh_all_cards()

func _build_ui() -> void:
	# 背景
	var bg := ColorRect.new()
	bg.name = "Bg"
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.07, 0.12, 1.0)
	add_child(bg)

	# 根布局：左右分栏，锚满屏
	var root_hbox := HBoxContainer.new()
	root_hbox.name = "RootHBox"
	root_hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_hbox.add_theme_constant_override("separation", 0)
	root_hbox.add_theme_constant_override("theme_override_constants/separation", 16)
	add_child(root_hbox)

	# ── 左栏：控制面板（固定宽度滚动）──
	var ctrl_scroll := ScrollContainer.new()
	ctrl_scroll.name = "CtrlScroll"
	ctrl_scroll.custom_minimum_size.x = 280
	ctrl_scroll.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	root_hbox.add_child(ctrl_scroll)

	var ctrl_vbox := VBoxContainer.new()
	ctrl_vbox.name = "CtrlVBox"
	ctrl_vbox.add_theme_constant_override("separation", 8)
	ctrl_scroll.add_child(ctrl_vbox)

	_add_ctrl_title(ctrl_vbox, "卡片尺寸 (5:7)")
	_add_slider(ctrl_vbox, "宽度", "slot_width", 40, 480, 1)
	_add_slider(ctrl_vbox, "高度", "slot_height", 56, 700, 1)

	_add_ctrl_title(ctrl_vbox, "Minimal 模式")
	_add_toggle(ctrl_vbox, "启用 Minimal", "minimal_mode")
	_add_slider(ctrl_vbox, "图标最小尺寸", "icon_min_size", 16, 256, 1)
	_add_slider(ctrl_vbox, "顶栏/情报字号", "name_font_size", 8, 28, 1)
	_add_slider(ctrl_vbox, "情报区最小高度", "name_min_height", 20, 320, 1)
	_add_slider(ctrl_vbox, "情报最大行数", "name_max_lines", 1, 16, 1)

	_add_ctrl_title(ctrl_vbox, "MTG 预览 (Minimal)")
	_add_toggle(ctrl_vbox, "启用 MTG 卡面排版", "use_mtg_preview_layout")
	_add_slider(ctrl_vbox, "原画区高度(%槽高)", "mtg_art_height_pct", 20, 80, 1)

	_add_ctrl_title(ctrl_vbox, "Full 模式元素")
	_add_toggle(ctrl_vbox, "显示类型色条", "show_type_bar")
	_add_slider(ctrl_vbox, "色条高度", "type_bar_height", 2, 12, 1)
	_add_toggle(ctrl_vbox, "显示费用/重量行", "show_stats_row")
	_add_toggle(ctrl_vbox, "显示等级/经验行", "show_level_row")
	_add_slider(ctrl_vbox, "Full名字号", "full_name_font_size", 8, 16, 1)
	_add_slider(ctrl_vbox, "内边距-左右", "margin_h", 0, 10, 1)
	_add_slider(ctrl_vbox, "内边距-上", "margin_top", 0, 10, 1)
	_add_slider(ctrl_vbox, "内边距-下", "margin_bottom", 0, 10, 1)

	_add_ctrl_title(ctrl_vbox, "边框与圆角")
	_add_slider(ctrl_vbox, "圆角", "corner_radius", 0, 16, 1)
	_add_slider(ctrl_vbox, "普通边框宽", "border_width_common", 0, 4, 1)
	_add_slider(ctrl_vbox, "稀有边框宽", "border_width_rare", 0, 4, 1)

	_add_ctrl_title(ctrl_vbox, "单卡蓝图")
	_add_toggle(ctrl_vbox, "仅单卡预览", "single_card_mode")
	_add_toggle(ctrl_vbox, "单卡用 DefaultCards", "single_card_use_real_blueprint")

	_add_ctrl_title(ctrl_vbox, "预览布局")
	_add_slider(ctrl_vbox, "卡片间距", "card_spacing", 2, 24, 1)
	_add_slider(ctrl_vbox, "每行列数(0=自动)", "grid_columns", 0, 12, 1)

	# 分隔线
	var sep2 := VSeparator.new()
	sep2.name = "Sep"
	root_hbox.add_child(sep2)

	# ── 右栏：预览区 ──
	var preview_scroll := ScrollContainer.new()
	preview_scroll.name = "PreviewScroll"
	preview_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_hbox.add_child(preview_scroll)

	var preview_vbox := VBoxContainer.new()
	preview_vbox.name = "PreviewVBox"
	preview_vbox.add_theme_constant_override("separation", 16)
	preview_scroll.add_child(preview_vbox)

	# 标题
	var title := Label.new()
	title.text = "实时卡片排版预览"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.8, 0.85, 1.0))
	preview_vbox.add_child(title)

	if not single_card_mode:
		preview_vbox.add_child(_section("全卡池 DefaultCards（create_all，与游戏默认卡表一致）"))
		var grid_all := _make_grid_container()
		grid_all.name = "Grid_AllDefaultCards"
		if grid_columns < 1:
			grid_all.columns = 5
		preview_vbox.add_child(grid_all)
		var all_list: Array = DefaultCards.create_all()
		for entry in all_list:
			if entry is CardResource:
				var tmpl: CardResource = entry as CardResource
				var pc: CardResource = _clone_card_for_preview(tmpl)
				if pc:
					_add_card(grid_all, pc, pc.display_name)

	if single_card_mode:
		preview_vbox.add_child(_section("单卡预览（左侧勾选「仅单卡预览」可关）"))
		var wrap := CenterContainer.new()
		wrap.name = "SingleCardWrap"
		wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
		wrap.custom_minimum_size = Vector2(0, 420)
		preview_vbox.add_child(wrap)
		var grid_s := _make_grid_container()
		grid_s.name = "Grid_Single"
		grid_s.columns = 1
		grid_s.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		wrap.add_child(grid_s)
		var lone: CardResource = _make_single_preview_card()
		_add_card(grid_s, lone, lone.display_name)
		_add_parameter_output_section(preview_vbox)
		return

	# ── 类型 x 稀有度 ──
	preview_vbox.add_child(_section("卡片类型 x 稀有度"))
	var grid1 := _make_grid_container()
	grid1.name = "Grid_TypeRarity"
	preview_vbox.add_child(grid1)

	var card_types := [
		[GC.CardType.COMBAT_UNIT, "平台"],
		[GC.CardType.COMBAT_UNIT,   "武器"],
		[GC.CardType.COMBAT_UNIT, "合成"],
		[GC.CardType.ENERGY,   "能量"],
		[GC.CardType.LAW,      "法则"],
	]
	for ct_entry in card_types:
		for rarity in ["common", "uncommon", "rare", "legendary"]:
			var card := _fake_card(ct_entry[0], rarity, 0, ct_entry[1])
			var item := _add_card(grid1, card, "%s/%s" % [ct_entry[1], _r_cn(rarity)])

	# ── 星级 ──
	preview_vbox.add_child(_section("星级显示 (rare/PLATFORM)"))
	var grid2 := _make_grid_container()
	grid2.name = "Grid_Stars"
	preview_vbox.add_child(grid2)

	for star in range(0, 8):
		var card := _fake_card(GC.CardType.COMBAT_UNIT, "rare", star, "★%d" % star)
		_add_card(grid2, card, "★%d" % star)

	# ── 长名称测试 ──
	preview_vbox.add_child(_section("长名称截断测试"))
	var grid3 := _make_grid_container()
	grid3.name = "Grid_LongName"
	preview_vbox.add_child(grid3)

	var long_names := [
		["platform", "legendary", 5, "全装型机动舱"],
		["platform", "rare", 0, "量子感知平台"],
		["platform", "uncommon", 3, "203毫米迫击炮"],
		["platform", "common", 0, "威克斯侦察车"],
		["energy",   "common", 0, "能量"],
	]
	for ln in long_names:
		var ct := GC.CardType.COMBAT_UNIT if ln[0] == "platform" else GC.CardType.ENERGY
		var card := _fake_card(ct, ln[1], ln[2], ln[3])
		_add_card(grid3, card, ln[3])

	# ── 槽位对比 ──
	preview_vbox.add_child(_section("PhaseSlot 槽位"))
	var hbox_slots := HBoxContainer.new()
	hbox_slots.name = "SlotHBox"
	hbox_slots.add_theme_constant_override("separation", 12)
	preview_vbox.add_child(hbox_slots)

	var empty_slot := SlotScene.instantiate()
	empty_slot.set_meta("slot_color", "red")
	empty_slot.set_meta("slot_index", 0)
	hbox_slots.add_child(empty_slot)
	hbox_slots.add_child(_small_label("空槽"))

	var filled_slot := SlotScene.instantiate()
	filled_slot.set_meta("slot_color", "red")
	filled_slot.set_meta("slot_index", 1)
	var slot_card: CardResource = _preview_card_from_blueprint_id("platform_modern_guard_heavy")
	if slot_card == null:
		slot_card = _fake_card(GC.CardType.COMBAT_UNIT, "rare", 3, "豹2A7")
	filled_slot.set_card(slot_card)
	filled_slot.add_theme_stylebox_override("panel", _filled_slot_sb())
	hbox_slots.add_child(filled_slot)
	hbox_slots.add_child(_small_label("已填充"))

	_add_parameter_output_section(preview_vbox)


func _add_parameter_output_section(preview_vbox: VBoxContainer) -> void:
	preview_vbox.add_child(_section(""))
	var output_box := VBoxContainer.new()
	output_box.name = "OutputBox"
	output_box.add_theme_constant_override("separation", 4)
	preview_vbox.add_child(output_box)

	var output_title := Label.new()
	output_title.text = "当前参数（复制到 backpack_card_item.gd）"
	output_title.add_theme_font_size_override("font_size", 14)
	output_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	output_box.add_child(output_title)

	var output_code := Label.new()
	output_code.name = "OutputCode"
	output_code.add_theme_font_size_override("font_size", 11)
	output_code.add_theme_color_override("font_color", Color(0.6, 0.85, 0.6))
	output_box.add_child(output_code)


# ── 刷新逻辑 ──

func _on_param_changed() -> void:
	if _is_building or not is_inside_tree():
		return
	_dirty = true
	# 合并同帧多次变更，避免卡顿
	if not is_connected("draw", _apply_deferred):
		call_deferred("_apply_deferred")

func _apply_deferred() -> void:
	if is_connected("draw", _apply_deferred):
		disconnect("draw", _apply_deferred)
	if not _dirty:
		return
	_dirty = false
	_refresh_all_cards()

func _apply_preview_metas_to_item(item: Control) -> void:
	var slot_size := Vector2(slot_width, slot_height)
	item.SLOT_SIZE = slot_size
	item.CARD_LIST_ICON_DISPLAY_MIN = Vector2(icon_min_size, icon_min_size)
	item.ENABLE_MINIMAL_CARD_RENDER = minimal_mode
	item.custom_minimum_size = slot_size
	item.set_meta("_pv_mtg_layout", use_mtg_preview_layout and minimal_mode)
	item.set_meta("_pv_mtg_art_pct", mtg_art_height_pct)
	item.set_meta("_pv_type_bar", show_type_bar)
	item.set_meta("_pv_type_bar_h", type_bar_height)
	item.set_meta("_pv_stats_row", show_stats_row)
	item.set_meta("_pv_level_row", show_level_row)
	item.set_meta("_pv_full_name_fs", full_name_font_size)
	item.set_meta("_pv_margin_h", margin_h)
	item.set_meta("_pv_margin_top", margin_top)
	item.set_meta("_pv_margin_bottom", margin_bottom)
	item.set_meta("_pv_corner", corner_radius)
	item.set_meta("_pv_bw_common", border_width_common)
	item.set_meta("_pv_bw_rare", border_width_rare)
	item.set_meta("_pv_name_fs", name_font_size)
	item.set_meta("_pv_name_mh", name_min_height)
	item.set_meta("_pv_name_ml", name_max_lines)


func _refresh_all_cards() -> void:
	for item in _preview_cards:
		if not is_instance_valid(item) or not item.card:
			continue
		var card_to_show: CardResource = item.card
		if item.get_meta("_pv_single_slot", false):
			var fresh: CardResource = _make_single_preview_card()
			if fresh:
				card_to_show = fresh
		_apply_preview_metas_to_item(item)
		item.set_card(card_to_show)
		_post_set_card_tweak(item)
	# 更新代码输出
	_update_output()

func _post_set_card_tweak(item: Control) -> void:
	"""set_card 执行完毕后，根据预览参数微调节点"""
	if not item.has_meta("_pv_corner"):
		return
	var cr: int = item.get_meta("_pv_corner")
	# 调整圆角：修改 panel 样式
	var sb := item.get_theme_stylebox("panel")
	if sb is StyleBoxFlat:
		var fsb := sb as StyleBoxFlat
		fsb.set_corner_radius_all(cr)
		fsb.border_width_left = item.get_meta("_pv_bw_common")
		fsb.border_width_top = item.get_meta("_pv_bw_common")
		fsb.border_width_right = item.get_meta("_pv_bw_common")
		fsb.border_width_bottom = item.get_meta("_pv_bw_common")
		if item.card and item.card.rarity in ["rare", "legendary"]:
			var bw_r: int = item.get_meta("_pv_bw_rare")
			fsb.border_width_left = bw_r
			fsb.border_width_top = bw_r
			fsb.border_width_right = bw_r
			fsb.border_width_bottom = bw_r
		item.queue_redraw()

	# Full 模式调整
	if not item.ENABLE_MINIMAL_CARD_RENDER:
		# 内边距
		var margin_node: Control = item.get_node_or_null("VBox/ContentMargin") as MarginContainer
		if margin_node:
			margin_node.add_theme_constant_override("margin_left", item.get_meta("_pv_margin_h"))
			margin_node.add_theme_constant_override("margin_right", item.get_meta("_pv_margin_h"))
			margin_node.add_theme_constant_override("margin_top", item.get_meta("_pv_margin_top"))
			margin_node.add_theme_constant_override("margin_bottom", item.get_meta("_pv_margin_bottom"))
		# 类型色条高度
		var type_bar: Panel = item.get_node_or_null("VBox/TypeBar") as Panel
		if type_bar:
			type_bar.visible = item.get_meta("_pv_type_bar")
			type_bar.custom_minimum_size = Vector2(0, item.get_meta("_pv_type_bar_h"))
		# Stats / Level 行可见性
		var stats_row: Control = item.get_node_or_null("VBox/ContentMargin/InnerVBox/StatsRow") as Control
		if stats_row:
			stats_row.visible = item.get_meta("_pv_stats_row")
		var level_row: Control = item.get_node_or_null("VBox/ContentMargin/InnerVBox/LevelRow") as Control
		if level_row:
			level_row.visible = item.get_meta("_pv_level_row")
		# Full 名字号
		var full_name: Label = item.get_node_or_null("VBox/ContentMargin/InnerVBox/IconRow/NameLabel") as Label
		if full_name:
			full_name.add_theme_font_size_override("font_size", item.get_meta("_pv_full_name_fs"))

	# Minimal 模式调整：覆盖硬编码的字号/行数
	else:
		var name_lbl: Label = item.get_node_or_null("VBox/ContentMargin/InnerVBox/IconRow/NameLabel") as Label
		if item.get_meta("_pv_mtg_layout", false):
			var fs: int = int(item.get_meta("_pv_name_fs"))
			var name_hdr: Label = item.get_node_or_null("VBox/ContentMargin/InnerVBox/IconRow/MtgHeader/MtgNameLabel") as Label
			if name_hdr:
				name_hdr.add_theme_font_size_override("font_size", fs)
			var rank_hdr: Label = item.get_node_or_null("VBox/ContentMargin/InnerVBox/IconRow/MtgHeader/MtgRankLabel") as Label
			if rank_hdr:
				rank_hdr.add_theme_font_size_override("font_size", clampi(fs - 1, 7, 26))
			var cost_hdr2: Label = item.get_node_or_null("VBox/ContentMargin/InnerVBox/IconRow/MtgHeader/MtgCostLabel") as Label
			if cost_hdr2:
				cost_hdr2.add_theme_font_size_override("font_size", fs)
			if name_lbl:
				var tl_fs: int = clampi(fs - 1, 8, 24)
				name_lbl.add_theme_font_size_override("font_size", tl_fs)
				name_lbl.custom_minimum_size = Vector2(0, clampi(int(item.get_meta("_pv_name_mh")), 20, 420))
				name_lbl.max_lines_visible = clampi(int(item.get_meta("_pv_name_ml")), 1, 16)
		elif name_lbl:
			name_lbl.add_theme_font_size_override("font_size", item.get_meta("_pv_name_fs"))
			name_lbl.custom_minimum_size = Vector2(0, item.get_meta("_pv_name_mh"))
			name_lbl.max_lines_visible = item.get_meta("_pv_name_ml")

	if item.has_method("mtg_preview_refresh_art_layout"):
		item.mtg_preview_refresh_art_layout()

func _update_output() -> void:
	var out_label: Label = get_node_or_null("RootHBox/PreviewScroll/PreviewVBox/OutputBox/OutputCode")
	if out_label == null:
		return
	var mode_str := "true" if minimal_mode else "false"
	var mtg_str := "true" if (use_mtg_preview_layout and minimal_mode) else "false"
	var lines := [
		"const SLOT_SIZE: Vector2 = Vector2(%d, %d)" % [slot_width, slot_height],
		"const CARD_LIST_ICON_DISPLAY_MIN := Vector2(%d, %d)" % [icon_min_size, icon_min_size],
		"const ENABLE_MINIMAL_CARD_RENDER := %s" % mode_str,
		"",
		"# MTG 预览 (card_ui_preview 专用 meta，非背包常量):",
		"  _pv_mtg_layout=%s  _pv_mtg_art_pct=%d" % [mtg_str, mtg_art_height_pct],
		"# 单卡真实蓝图: use_real=%s  id=%s" % [str(single_card_use_real_blueprint).to_lower(), single_card_blueprint_id],
		"",
		"# Minimal 名字参数:",
		"  font_size=%d  min_height=%d  max_lines=%d" % [name_font_size, name_min_height, name_max_lines],
		"",
		"# Full 模式参数:",
		"  name_font_size=%d  type_bar=%d  margin=(%d,%d,%d)" % [full_name_font_size, type_bar_height, margin_h, margin_top, margin_bottom],
		"",
		"# 边框:",
		"  corner_radius=%d  common=%dpx  rare=%dpx" % [corner_radius, border_width_common, border_width_rare],
	]
	out_label.text = "\n".join(lines)


func _rebuild_layout() -> void:
	if not is_inside_tree():
		return
	# 更新所有 grid 的 separation
	for grid in get_tree().get_nodes_in_group("_card_grid"):
		if grid is GridContainer:
			grid.add_theme_constant_override("h_separation", card_spacing)
			grid.add_theme_constant_override("v_separation", card_spacing)
			if grid_columns > 0:
				grid.columns = grid_columns

func _add_card(grid: GridContainer, card: CardResource, label_text: String) -> Control:
	var wrapper := VBoxContainer.new()
	wrapper.add_theme_constant_override("separation", 2)
	wrapper.alignment = BoxContainer.ALIGNMENT_CENTER

	var item := CardItemScene.instantiate() as Control
	if single_card_mode and _preview_cards.is_empty():
		item.set_meta("_pv_single_slot", true)
	_apply_preview_metas_to_item(item)
	item.set_card(card)
	_post_set_card_tweak(item)
	_preview_cards.append(item)
	wrapper.add_child(item)

	var lbl := _small_label(label_text)
	lbl.custom_minimum_size.x = slot_width
	wrapper.add_child(lbl)
	grid.add_child(wrapper)
	return item


# ── UI 辅助 ──

func _make_grid_container() -> GridContainer:
	var g := GridContainer.new()
	g.add_theme_constant_override("h_separation", card_spacing)
	g.add_theme_constant_override("v_separation", card_spacing)
	g.columns = grid_columns if grid_columns > 0 else 5
	g.add_to_group("_card_grid")
	return g

func _section(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", Color(0.65, 0.7, 0.82))
	return l

func _small_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 9)
	l.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.clip_text = true
	l.custom_minimum_size.x = slot_width
	return l

func _add_ctrl_title(parent: Control, text: String) -> void:
	var lbl := Label.new()
	lbl.text = "── %s ──" % text
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.55, 0.7, 1.0, 0.9))
	parent.add_child(lbl)

func _add_slider(parent: Control, label: String, prop: String, min_val: int, max_val: int, step: int) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	parent.add_child(hbox)

	var lbl := Label.new()
	lbl.text = label
	lbl.custom_minimum_size.x = 100
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.75, 0.78, 0.85))
	hbox.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.step = step
	slider.value = get(prop)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size.x = 100
	slider.name = "Slider_%s" % prop
	hbox.add_child(slider)

	var val_lbl := Label.new()
	val_lbl.text = "%d" % int(get(prop))
	val_lbl.custom_minimum_size.x = 32
	val_lbl.add_theme_font_size_override("font_size", 11)
	val_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	val_lbl.name = "ValLabel_%s" % prop
	hbox.add_child(val_lbl)

	# 双向绑定：slider → prop → label
	var _prop := prop
	slider.value_changed.connect(func(v: float) -> void:
		set(_prop, int(v))
		var vl: Label = slider.get_parent().get_node_or_null("ValLabel_%s" % _prop)
		if vl:
			vl.text = "%d" % int(v)
	)

func _add_toggle(parent: Control, label: String, prop: String) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	parent.add_child(hbox)

	var lbl := Label.new()
	lbl.text = label
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.75, 0.78, 0.85))
	hbox.add_child(lbl)

	var btn := CheckButton.new()
	btn.button_pressed = get(prop)
	btn.name = "Toggle_%s" % prop
	hbox.add_child(btn)

	var _prop := prop
	btn.toggled.connect(func(v: bool) -> void:
		if _prop == "single_card_mode":
			set(_prop, v)
			if not _is_building and is_inside_tree():
				get_tree().reload_current_scene()
		else:
			set(_prop, v)
	)


# ── 数据辅助 ──

func _clone_card_for_preview(tmpl: CardResource) -> CardResource:
	if tmpl == null:
		return null
	var c: CardResource = tmpl.duplicate(true) as CardResource
	# 与 BlueprintManager 一致：未记录蓝图 id 时 get_blueprint_star 默认为 1★
	if BlueprintManager and BlueprintManager.has_method("get_blueprint_star"):
		var bp: int = clampi(int(BlueprintManager.get_blueprint_star(c.card_id)), 1, StarConfig.MAX_STAR_LEVEL)
		c.star_level = maxi(int(c.star_level), bp)
	else:
		c.star_level = maxi(1, int(c.star_level))
	return c


func _preview_card_from_blueprint_id(blueprint_id: String) -> CardResource:
	var id := blueprint_id.strip_edges()
	if id.is_empty():
		return null
	var tmpl: CardResource = DefaultCards.get_card_by_id(id)
	if tmpl == null:
		return null
	return _clone_card_for_preview(tmpl)


func _make_single_preview_card() -> CardResource:
	if single_card_use_real_blueprint:
		var c: CardResource = _preview_card_from_blueprint_id(single_card_blueprint_id)
		if c:
			return c
	return _fake_card(GC.CardType.COMBAT_UNIT, "legendary", 5, "全装型机动舱")


func _fake_card(ct: int, rarity: String, star: int, name: String) -> CardResource:
	var c := CardResource.new()
	c.card_id = "preview_%s_%s" % [name, rarity]
	c.display_name = name
	c.card_type = ct
	c.rarity = rarity
	c.energy_cost = 5.0
	c.type_line = "%s — 测试" % _type_cn(ct)
	c.summary_line = "预览卡"
	c.star_level = star
	c.max_weapons = 1
	c.weight_capacity = 5
	return c

static func _type_cn(ct: int) -> String:
	match ct:
		GC.CardType.COMBAT_UNIT: return "平台"
		GC.CardType.COMBAT_UNIT:   return "武器"
		GC.CardType.COMBAT_UNIT: return "合成"
		GC.CardType.ENERGY:   return "能量"
		GC.CardType.LAW:      return "法则"
		_: return "?"

static func _r_cn(r: String) -> String:
	match r:
		"common":    return "普通"
		"uncommon":  return "优秀"
		"rare":      return "稀有"
		"legendary": return "传说"
		_: return r

func _filled_slot_sb() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0.941, 1, 0.08)
	sb.border_width_left = 2; sb.border_width_top = 2
	sb.border_width_right = 2; sb.border_width_bottom = 2
	sb.border_color = Color(0, 0.941, 1, 0.5)
	sb.set_corner_radius_all(4)
	sb.shadow_color = Color(0, 0.941, 1, 0.25)
	sb.shadow_size = 6
	return sb