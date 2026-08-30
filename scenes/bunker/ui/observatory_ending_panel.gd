extends Control
## 余烬要塞 P4 · 观星台终局面板 v22.3
## 三段式终局演出：导语 → 三选一（重写/守望/远行）→ 结局徽记与文本结算。
## 已抉择的存档重访时直达结算页；抉择经 BunkerManager.choose_ending 持久化（不可反悔）。
## 文案数据源 data/hero_archive_texts.gd（2026-08-26 定稿，本轮首次接 UI）。
## 契约：closed 信号（嵌入包装层据此关闭）；refresh() 供 _open_embedded_panel 重开刷新。

signal closed

const DT = preload("res://resources/design_tokens.gd")
const PanelStyles = preload("res://scripts/ui/panel_styles.gd")
const HeroArchiveTexts = preload("res://data/hero_archive_texts.gd")

## 背景图（tools/generate_observatory_ending_bg.py 生成；缺失时程序化星空兜底）
const BG_PATH := "res://assets/bunker/observatory_sky.png"

const ACCENT := Color(0.62, 0.78, 1.0)   # 星光冷青
const GOLD := Color(1.0, 0.84, 0.5)      # 结局徽记金
const ENDING_ORDER := ["rewrite", "keep", "depart"]

var _manager: Node
var _content: VBoxContainer
var _stars: Array = []       # [{pos: Vector2, r: float, col: Color}]
var _pending_id := ""

func _ready() -> void:
	# ⚠️ 入树后设锚点必须连偏移一起归零（v22 全弹层统一修正，防出屏）
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_manager = get_node_or_null("/root/BunkerManager")
	_build_backdrop()
	_build_content_root()
	_enter_current_phase()

## 嵌入层重开入口（与 hero_archive/memorial 面板同契约）
func refresh() -> void:
	_enter_current_phase()

func open() -> void:
	_enter_current_phase()

# ───────────────────── 背景 ─────────────────────

func _build_backdrop() -> void:
	var tex: Texture2D = null
	if ResourceLoader.exists(BG_PATH, "Texture2D"):
		tex = load(BG_PATH) as Texture2D
	if tex != null:
		var tr := TextureRect.new()
		tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(tr)
		return
	# 兜底：程序化夜空（纵向渐变 + 确定性星点），无图照跑
	var grad := Gradient.new()
	grad.set_color(0, Color(0.012, 0.028, 0.066))
	grad.set_color(1, Color(0.045, 0.038, 0.085))
	var grad_tex := GradientTexture2D.new()
	grad_tex.gradient = grad
	grad_tex.fill_from = Vector2(0, 0)
	grad_tex.fill_to = Vector2(0, 1)
	var base := TextureRect.new()
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	base.texture = grad_tex
	base.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	base.stretch_mode = TextureRect.STRETCH_SCALE
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(base)

	var rng := RandomNumberGenerator.new()
	rng.seed = 20260828
	for i in range(90):
		var warm := rng.randf() < 0.18
		_stars.append({
			"pos": Vector2(rng.randf() * 1280.0, rng.randf() * 720.0),
			"r": 0.6 + rng.randf() * 1.6,
			"col": Color(1.0, 0.82, 0.5, 0.5 + rng.randf() * 0.5) if warm
				else Color(0.75, 0.87, 1.0, 0.35 + rng.randf() * 0.6),
		})
	var star_layer := Control.new()
	star_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	star_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	star_layer.draw.connect(func():
		for s in _stars:
			star_layer.draw_circle(s["pos"], s["r"], s["col"]))
	add_child(star_layer)
	if not DT.is_motion_reduce():
		var tw := create_tween().set_loops()
		tw.tween_property(star_layer, "modulate:a", 0.72, 2.2)
		tw.tween_property(star_layer, "modulate:a", 1.0, 2.2)

# ───────────────────── 内容骨架 ─────────────────────

func _build_content_root() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(880, 0)
	panel.add_theme_stylebox_override("panel", PanelStyles.make_panel_frame(ACCENT))
	center.add_child(panel)

	var inner := PanelContainer.new()
	var inner_sb := StyleBoxFlat.new()
	inner_sb.bg_color = Color(0.02, 0.03, 0.06, 0.90)
	inner_sb.set_corner_radius_all(10)
	inner_sb.set_content_margin_all(26.0)
	inner.add_theme_stylebox_override("panel", inner_sb)
	panel.add_child(inner)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 14)
	inner.add_child(_content)

func _clear_content() -> void:
	for child in _content.get_children():
		child.queue_free()

func _enter_current_phase() -> void:
	var chosen: Dictionary = {}
	if _manager != null and _manager.has_method("get_chosen_ending"):
		chosen = _manager.get_chosen_ending()
	if chosen.is_empty():
		_show_intro()
	else:
		_show_resolution(chosen, false)

# ───────────────────── 三段演出 ─────────────────────

func _show_intro() -> void:
	_clear_content()
	_content.add_child(_make_title("观星台"))
	var body := _make_body_label(HeroArchiveTexts.OBSERVATORY_PROLOGUE)
	body.custom_minimum_size = Vector2(0, 120)
	_content.add_child(body)
	_content.add_child(_make_button("走向门后 →", "solid", _show_choice, 46))

func _show_choice() -> void:
	_clear_content()
	_content.add_child(_make_title("三十个人守出来的答案"))
	var hint := _make_hint("选择一个结局。门只开一次，无法反悔。")
	_content.add_child(hint)

	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 16)
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_child(cards)
	for id in ENDING_ORDER:
		cards.add_child(_make_choice_card(id))
	_content.add_child(_make_close_ghost("暂时离开"))

func _make_choice_card(id: String) -> Control:
	var ending: Dictionary = HeroArchiveTexts.observatory_ending(id)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(256, 0)
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.045)
	sb.border_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.30)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(14.0)
	card.add_theme_stylebox_override("panel", sb)
	card.mouse_entered.connect(func():
		sb.border_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.8)
		card.queue_redraw())
	card.mouse_exited.connect(func():
		sb.border_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.3)
		card.queue_redraw())
	card.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_show_confirm(id))

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	card.add_child(vbox)

	var title := Label.new()
	title.text = "「%s」" % str(ending.get("title", id))
	title.add_theme_font_size_override("font_size", DT.FONT_SIZE_LARGE)
	title.add_theme_color_override("font_color", GOLD)
	vbox.add_child(title)

	var choice := _make_body_label(str(ending.get("choice", "")))
	choice.custom_minimum_size = Vector2(0, 96)
	vbox.add_child(choice)

	var go := _make_hint("点击选择")
	go.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(go)
	return card

func _show_confirm(id: String) -> void:
	_pending_id = id
	var ending: Dictionary = HeroArchiveTexts.observatory_ending(id)
	_clear_content()
	_content.add_child(_make_title("「%s」" % str(ending.get("title", id))))
	var body := _make_body_label(str(ending.get("choice", "")))
	body.custom_minimum_size = Vector2(0, 96)
	_content.add_child(body)
	var warn := _make_hint("门只开一次。确认吗？")
	warn.add_theme_color_override("font_color", Color(0.95, 0.66, 0.18))
	_content.add_child(warn)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_child(row)
	row.add_child(_make_button("确认", "solid", _on_confirm_pressed, 46))
	row.add_child(_make_button("再想想", "ghost", _show_choice, 46))

func _on_confirm_pressed() -> void:
	if _manager == null or not _manager.has_method("choose_ending"):
		return
	var result: Dictionary = _manager.choose_ending(_pending_id)
	if SignalBus != null and SignalBus.has_signal("play_sound"):
		SignalBus.play_sound.emit("achievement")
	if result.get("ok", false):
		_show_resolution(result.get("ending", {}), true)
	else:
		_show_resolution(result.get("ending", {}), false)

func _show_resolution(ending: Dictionary, is_new: bool) -> void:
	_clear_content()
	var emblem := Label.new()
	emblem.text = str(ending.get("emblem", "结局"))
	emblem.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	emblem.add_theme_font_size_override("font_size", DT.FONT_SIZE_TITLE - 4)
	emblem.add_theme_color_override("font_color", GOLD)
	_content.add_child(emblem)

	var meta := _make_hint("")
	if not ending.is_empty():
		meta.text = "第 %d 天 · 三十盏灯都亮着" % int(ending.get("day", 0))
	meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(meta)

	var body := _make_body_label(str(ending.get("resolution", "")))
	body.custom_minimum_size = Vector2(0, 130)
	_content.add_child(body)

	_content.add_child(_make_button("回到基地", "solid", func(): closed.emit(), 46))
	if not DT.is_motion_reduce() and is_new:
		modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 1.0, 0.8)

# ───────────────────── 控件工厂 ─────────────────────

func _make_title(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", DT.FONT_SIZE_TITLE - 8)
	lbl.add_theme_color_override("font_color", DT.COLOR_TEXT_BRIGHT)
	return lbl

func _make_body_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", DT.FONT_SIZE_BODY)
	lbl.add_theme_color_override("font_color", Color(0.80, 0.86, 0.95))
	return lbl

func _make_hint(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	lbl.add_theme_color_override("font_color", DT.COLOR_TEXT_DIM)
	return lbl

func _make_button(text: String, kind: String, cb: Callable, height := 40) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, height)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var styles: Dictionary = PanelStyles.make_button_styles(ACCENT, kind)
	for key in ["normal", "hover", "pressed", "disabled", "focus"]:
		btn.add_theme_stylebox_override(key, styles[key])
	btn.add_theme_color_override("font_color", DT.COLOR_TEXT_BRIGHT)
	btn.add_theme_color_override("font_hover_color", DT.COLOR_TEXT)
	btn.add_theme_font_size_override("font_size", DT.FONT_SIZE_BODY)
	btn.pressed.connect(func():
		SignalBus.play_sound.emit("button")
		cb.call())
	return btn

func _make_close_ghost(text: String) -> Button:
	var btn := _make_button(text, "ghost", func(): closed.emit(), 36)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return btn

func _unhandled_input(event: InputEvent) -> void:
	# ESC 关闭（未确认的抉择不落存档，随时可重开）
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		closed.emit()
		get_viewport().set_input_as_handled()
