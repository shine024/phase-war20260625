extends Control
## 余烬要塞 P3 · 英雄档案面板
## 档案室嵌入面板：30 位牺牲相位师档案（已解锁显详情，未解锁 "???"）。
## 数据源：EnemyPhaseMasters 聚合 + HeroArchiveTexts 文案。
## 契约：closed 信号（嵌入包装层据此关闭）。

signal closed

const DT = preload("res://resources/design_tokens.gd")
const HeroArchiveTexts = preload("res://data/hero_archive_texts.gd")
const EnemyPhaseMasters = preload("res://data/enemy_phase_masters.gd")

## 系别签色（暗色调，克制）
const FACTION_COLORS := {
	"steel": Color(0.45, 0.62, 0.85),
	"flame": Color(0.85, 0.55, 0.35),
	"thunder": Color(0.85, 0.8, 0.45),
	"void": Color(0.62, 0.5, 0.85),
}

var _root: Control
var _grid_scroll: ScrollContainer
var _grid: GridContainer
var _count_label: Label
var _detail_title: Label
var _detail_meta: Label
var _detail_deed: RichTextLabel
var _detail_words: RichTextLabel
var _masters: Array = []       # [{id,name,title,faction,level}]
var _selected_id := ""

func _ready() -> void:
	# v6.14 面板尺寸收窄：1180×720 时列表/详情下方大片空带（"面板和内容不匹配"反馈）——
	# 按内容实需 1180×560，CenterContainer 居中展示
	custom_minimum_size = Vector2(1180, 560)
	# v6.14 健壮性：/root/BunkerManager 为懒加载延迟入树，_ready 时可能尚未挂载——
	# refresh 内部走 Loader 兜底，且帧末补一次刷新兜住时序
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_load_masters()
	_build()
	refresh()
	call_deferred("refresh")

func _load_masters() -> void:
	_masters.clear()
	for era in range(5):
		var arr: Array = EnemyPhaseMasters.get_era_masters(era)
		for m in arr:
			_masters.append({
				"id": str(m.get("id", "")),
				"name": str(m.get("name", "???")),
				"title": str(m.get("title", "")),
				"faction": str(m.get("faction", "")),
				"level": int(m.get("level", 0)),
			})
	_masters.sort_custom(func(a, b): return a["id"] < b["id"])

func _build() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_root = PanelContainer.new()
	_root.custom_minimum_size = DT.PANEL_SIZE_LARGE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.055, 0.065, 0.105, 0.99)
	sb.border_color = Color(0.62, 0.5, 0.85, 0.65)   # 虚空紫——档案的幽光语义
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(DT.CORNER_RADIUS)
	sb.set_content_margin_all(DT.PADDING_LARGE)
	_root.add_theme_stylebox_override("panel", sb)
	center.add_child(_root)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	_root.add_child(outer)

	# 标题行
	var title_row := HBoxContainer.new()
	outer.add_child(title_row)
	var title := Label.new()
	title.text = "同伴档案"
	title.add_theme_font_size_override("font_size", DT.FONT_SIZE_TITLE - 8)
	title.add_theme_color_override("font_color", DT.COLOR_TEXT_BRIGHT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	_count_label = Label.new()
	_count_label.add_theme_font_size_override("font_size", DT.FONT_SIZE_BODY)
	_count_label.add_theme_color_override("font_color", DT.COLOR_TEXT_DIM)
	title_row.add_child(_count_label)
	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.pressed.connect(func(): closed.emit())
	title_row.add_child(close_btn)

	var hint := Label.new()
	hint.text = "他们不是敌人。他们只是先我们一步站在了黑暗面前。"
	hint.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	hint.add_theme_color_override("font_color", Color(0.62, 0.5, 0.85, 0.8))
	outer.add_child(hint)

	# 主体：左列表 + 右详情
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(body)

	_grid_scroll = ScrollContainer.new()
	_grid_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid_scroll.custom_minimum_size = Vector2(470, 0)
	body.add_child(_grid_scroll)
	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid_scroll.add_child(_grid)

	# 详情区
	var detail := PanelContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var dsb := StyleBoxFlat.new()
	dsb.bg_color = Color(0.04, 0.05, 0.085, 0.9)
	dsb.set_corner_radius_all(DT.CORNER_RADIUS)
	dsb.set_content_margin_all(DT.PADDING_MEDIUM)
	detail.add_theme_stylebox_override("panel", dsb)
	body.add_child(detail)
	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 8)
	detail.add_child(dv)
	_detail_title = Label.new()
	_detail_title.add_theme_font_size_override("font_size", DT.FONT_SIZE_LARGE)
	_detail_title.add_theme_color_override("font_color", DT.COLOR_TEXT_BRIGHT)
	dv.add_child(_detail_title)
	_detail_meta = Label.new()
	_detail_meta.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	_detail_meta.add_theme_color_override("font_color", DT.COLOR_TEXT_DIM)
	dv.add_child(_detail_meta)
	_detail_deed = RichTextLabel.new()
	_detail_deed.bbcode_enabled = false
	_detail_deed.fit_content = true
	_detail_deed.add_theme_font_size_override("normal_font_size", DT.FONT_SIZE_BODY)
	_detail_deed.add_theme_color_override("default_color", DT.COLOR_TEXT_DIM)
	dv.add_child(_detail_deed)
	# v6.14：纵向弹性垫片——遗言锚在详情区底部，消除"下半屏空带"
	var dv_spacer := Control.new()
	dv_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dv.add_child(dv_spacer)
	_detail_words = RichTextLabel.new()
	_detail_words.bbcode_enabled = false
	_detail_words.fit_content = true
	_detail_words.add_theme_font_size_override("normal_font_size", DT.FONT_SIZE_LARGE - 2)
	_detail_words.add_theme_color_override("default_color", Color(0.85, 0.78, 0.6))
	dv.add_child(_detail_words)
	# v6.14：空态文案（未选中时详情区不再整块空白）
	_detail_title.text = "档案室"
	_detail_meta.text = "从左侧选择一位已收录的同伴，查阅生前事迹与遗言。"
	_detail_deed.text = ""
	_detail_words.text = ""

	refresh()

## manager 由外部（bunker_main 打开前）调 refresh() 传入的注册表数据不可达时兜底：
## 直接查 /root/BunkerManager
func refresh() -> void:
	var mgr: Node = get_node_or_null("/root/BunkerManager")
	if mgr == null:
		# v6.14 健壮性：懒加载管理器延迟入树时 /root 路径暂时取不到——经 Loader 拿实例
		mgr = ManagerLazyLoader.get_manager("bunker")
	var unlocked: Dictionary = {}
	if mgr:
		for mid in mgr.get_hero_fragments():
			unlocked[mid] = true
	_count_label.text = "已收录 %d / 30" % unlocked.size()
	for child in _grid.get_children():
		child.queue_free()
	for m in _masters:
		_grid.add_child(_make_entry_button(m, unlocked.has(m["id"])))

func _make_entry_button(m: Dictionary, unlocked: bool) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(108, 56)
	btn.toggle_mode = true
	if unlocked:
		btn.text = m["name"]
		var fc: Color = FACTION_COLORS.get(m["faction"], Color(0.7, 0.7, 0.75))
		btn.add_theme_color_override("font_color", fc)
		btn.add_theme_color_override("font_hover_color", fc.lightened(0.25))
		btn.tooltip_text = "%s · %s" % [m["title"], HeroArchiveTexts.era_display(m["id"])]
		var mid: String = m["id"]
		btn.pressed.connect(func(): _select(mid))
	else:
		btn.text = "？？？"
		btn.disabled = true
		btn.add_theme_color_override("font_disabled_color", Color(0.32, 0.32, 0.36))
	return btn

func _select(master_id: String) -> void:
	_selected_id = master_id
	var m: Dictionary = {}
	for cand in _masters:
		if cand["id"] == master_id:
			m = cand
			break
	if m.is_empty():
		return
	var mgr: Node = get_node_or_null("/root/BunkerManager")
	if mgr == null:
		mgr = ManagerLazyLoader.get_manager("bunker")
	if mgr and not mgr.has_hero_fragment(master_id):
		return
	var texts: Dictionary = HeroArchiveTexts.get_texts(master_id, m["faction"])
	_detail_title.text = "%s" % m["name"]
	_detail_meta.text = "%s · %s · %s · Lv%d" % [
		m["title"], HeroArchiveTexts.faction_display(m["faction"]),
		HeroArchiveTexts.era_display(master_id), m["level"]]
	_detail_deed.text = texts["deed"]
	_detail_words.text = "\n" + texts["last_words"]
