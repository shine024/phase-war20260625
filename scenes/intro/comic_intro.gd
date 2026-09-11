extends Control
## 序章漫画开场（docs/开场剧情_10方案.md 方案1）：分格动画讲序章（深航计划版，11 格），
## 收尾转黑 → 携 META_WAKEUP 切 bunker_main 播醒来演出（雪原睁眼，方案9 实机衔接）。
##
## 流线：标题屏“进入基地”无档 → SaveManager.start_new_game() → 本场景
##   逐格点击推进（画格砸入 + ken-burns 缓推 + 打字机旁白）→ 结束/跳过 → bunker_main。
## 干跑（测试/编辑器预览）：Engine meta "bunker_intro_dry_run" 存在时收尾不切场景。

signal intro_finished
signal dream_battle_requested

const PanelsData = preload("res://data/intro_comic_panels.gd")
const ArtScript = preload("res://scenes/intro/comic_art.gd")
const PanelStyles = preload("res://scripts/ui/panel_styles.gd")

const STAGE_SIZE := Vector2(1280, 720)
const PANEL_RECT := Rect2(90, 30, 1100, 572)
const META_COMIC_PENDING := "bunker_intro_comic_pending"
const META_WAKEUP := "bunker_intro_wakeup_pending"
const META_DRY_RUN := "bunker_intro_dry_run"
const META_BATTLE_RESUME := "bunker_intro_battle_resume"
const BUNKER_SCENE := "res://scenes/bunker/truck_base.tscn"   # v27.13：交接现役移动基地（旧固定基地 bunker_main 已停用）
const BATTLE_SCENE := "res://scenes/intro/dream_battle.tscn"
const BATTLE_RESUME_INDEX := 2   # 梦境战结束回到本场景续播的格（B3 邀约）
const ACCENT := Color(0.92, 0.89, 0.78)
const INK := Color(0.02, 0.02, 0.035)
const FRAME_TILTS := [-0.008, 0.006, -0.004, 0.009, -0.007, 0.005, -0.006]

var DT = preload("res://resources/design_tokens.gd")

var _stage: Control
var _panel_layer: Control
var _frame: PanelContainer = null
var _title_bar: ColorRect
var _title_label: Label
var _narr_label: Label
var _hint_label: Label
var _dots: HBoxContainer
var _curtain: ColorRect
var _end_label: Label
var _fx: Tween
var _index := -1
var _busy := false
var _finished := false
var _dot_rects: Array[ColorRect] = []  # v27.12: 进度点缓存复用（原每次翻格 free+new 全部 ColorRect）

func _ready() -> void:
	DesignTokens.ensure_cjk_fallback()
	mouse_filter = Control.MOUSE_FILTER_IGNORE   # 点击落进 _unhandled_input 做翻格
	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	_stage = Control.new()
	_stage.position = Vector2(0, maxf(0.0, (get_viewport_rect().size.y - STAGE_SIZE.y) * 0.5))
	_stage.size = STAGE_SIZE
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)
	_build_chrome()
	# 幕布：全屏黑（盖住比 720 高的 expand 画布），拉开后开演
	_curtain = ColorRect.new()
	_curtain.color = Color(0, 0, 0, 1)
	_curtain.set_anchors_preset(Control.PRESET_FULL_RECT)
	_curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_curtain)
	var tw := create_tween()
	tw.tween_property(_curtain, "color:a", 0.0, 0.6)
	tw.tween_callback(_show_first_panel.bind(_consume_battle_resume()))

# ───────────────────── 界面骨架 ─────────────────────

func _build_chrome() -> void:
	_panel_layer = Control.new()
	_panel_layer.size = STAGE_SIZE
	_panel_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_panel_layer)

	# 格内标题（格左上：色条 + 标题字）
	_title_bar = ColorRect.new()
	_title_bar.position = PANEL_RECT.position + Vector2(30, 24)
	_title_bar.size = Vector2(8, 34)
	_title_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_bar.modulate.a = 0.0
	_stage.add_child(_title_bar)
	_title_label = Label.new()
	_title_label.position = _title_bar.position + Vector2(20, -6)
	_title_label.size = Vector2(700, 46)
	_title_label.add_theme_font_size_override("font_size", maxf(30.0, float(DT.FONT_SIZE_TITLE)))
	_title_label.add_theme_color_override("font_color", ACCENT)
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_label.modulate.a = 0.0
	_stage.add_child(_title_label)

	# 旁白条（格下方）
	var narr := PanelContainer.new()
	narr.position = Vector2(PANEL_RECT.position.x, 618)
	narr.size = Vector2(PANEL_RECT.size.x, 80)
	narr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var nsb := StyleBoxFlat.new()
	nsb.bg_color = Color(0.03, 0.03, 0.05, 0.92)
	nsb.border_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.5)
	nsb.border_width_left = 4
	nsb.set_corner_radius_all(4)
	nsb.set_content_margin_all(14.0)
	narr.add_theme_stylebox_override("panel", nsb)
	_stage.add_child(narr)
	_narr_label = Label.new()
	_narr_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_narr_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_narr_label.add_theme_font_size_override("font_size", DT.FONT_SIZE_LARGE)
	_narr_label.add_theme_color_override("font_color", Color(0.88, 0.9, 0.95))
	_narr_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	narr.add_child(_narr_label)

	# 进度点（左下）+ 提示（右下）
	_dots = HBoxContainer.new()
	_dots.position = Vector2(PANEL_RECT.position.x, 706)
	_dots.add_theme_constant_override("separation", 8)
	_dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_dots)
	_hint_label = Label.new()
	_hint_label.position = Vector2(STAGE_SIZE.x - PANEL_RECT.position.x - 280, 700)
	_hint_label.size = Vector2(280, 24)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint_label.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	_hint_label.add_theme_color_override("font_color", Color(0.7, 0.72, 0.78, 0.8))
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_hint_label)

	# 跳过按钮（右上）
	var skip := Button.new()
	skip.text = "跳过开场 ▸"
	skip.position = Vector2(STAGE_SIZE.x - 150, 14)
	skip.size = Vector2(136, 38)
	skip.focus_mode = Control.FOCUS_NONE
	skip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var styles: Dictionary = PanelStyles.make_button_styles(Color(0.45, 0.48, 0.55), "solid")
	for key in ["normal", "hover", "pressed", "disabled", "focus"]:
		skip.add_theme_stylebox_override(key, styles[key])
	skip.add_theme_color_override("font_color", DT.COLOR_TEXT_BRIGHT)
	skip.add_theme_font_size_override("font_size", DT.FONT_SIZE_BODY)
	skip.pressed.connect(func(): _finish(true))
	_stage.add_child(skip)

	# 收尾黑幕上的点睛句
	_end_label = Label.new()
	_end_label.position = Vector2(140, 300)
	_end_label.size = Vector2(1000, 120)
	_end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_end_label.add_theme_font_size_override("font_size", DT.FONT_SIZE_TITLE)
	_end_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.72))
	_end_label.text = "——然后，你在雪原上睁开了眼。"
	_end_label.visible = false
	_end_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_end_label)

# ───────────────────── 分格推进 ─────────────────────

## v24.3：从梦境战回归时从 B3 续播（meta 在 _ready 消费一次）
func _consume_battle_resume() -> int:
	if Engine.has_meta(META_BATTLE_RESUME):
		var idx := int(Engine.get_meta(META_BATTLE_RESUME))
		Engine.remove_meta(META_BATTLE_RESUME)
		return idx
	return 0

func _show_first_panel(resume: int) -> void:
	if not _finished:
		_show_panel(resume)

func advance() -> void:
	if _finished or _busy or _index < 0:
		return
	if _index + 1 >= PanelsData.PANELS.size():
		_finish(false)
		return
	# v24.3：B2 格是梦境战入口——点击即坠入可玩梦境（方案10-lite）
	if bool(PanelsData.PANELS[_index].get("battle", false)):
		_enter_dream_battle()
		return
	_busy = true
	_show_panel(_index + 1)
	await get_tree().create_timer(0.45).timeout
	_busy = false

func _show_panel(i: int) -> void:
	_index = i
	var p: Dictionary = PanelsData.PANELS[i]
	# 旧格退场
	if _frame != null and is_instance_valid(_frame):
		var old := _frame
		_frame = null
		var out := create_tween()
		out.set_parallel(true)
		out.tween_property(old, "modulate:a", 0.0, 0.22)
		out.tween_property(old, "scale", Vector2.ONE * 1.03, 0.22)
		out.chain().tween_callback(old.queue_free)
	# 新格：纸白描边 + 微倾斜 + 砸入
	_frame = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = INK
	sb.border_color = ACCENT
	sb.set_border_width_all(5)
	sb.set_corner_radius_all(3)
	sb.shadow_size = 16
	sb.shadow_color = DesignTokens.COLOR_BACKDROP
	_frame.add_theme_stylebox_override("panel", sb)
	_frame.position = PANEL_RECT.position
	_frame.size = PANEL_RECT.size
	_frame.pivot_offset = PANEL_RECT.size * 0.5
	_frame.rotation = float(FRAME_TILTS[i % FRAME_TILTS.size()])
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel_layer.add_child(_frame)
	var margin := MarginContainer.new()
	for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(m, 10)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(margin)
	var clip := Control.new()
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(clip)
	# 画格内容：texture 槽（真图）优先，否则程序化 motif
	var tex_path := str(p.get("texture", ""))
	if tex_path != "" and ResourceLoader.exists(tex_path):
		var tr := TextureRect.new()
		tr.texture = load(tex_path)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip.add_child(tr)
	else:
		var art: Control = ArtScript.new()
		art.setup(str(p["motif"]), p["accent"], i)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip.add_child(art)
		var inner: Vector2 = PANEL_RECT.size - Vector2(30, 30)
		var s: float = inner.x / 1280.0
		art.size = Vector2(1280, 720)
		art.position = (inner - Vector2(1280, 720) * s) * 0.5 + Vector2(10, 10)
		art.scale = Vector2(s, s)
		# ken-burns 缓推（绑定 art 自身，格销毁时随节点失效）
		var kb := art.create_tween()
		kb.tween_method(func(v: float) -> void:
			art.scale = Vector2(s, s) * v
			art.position = (inner - Vector2(1280, 720) * (s * v)) * 0.5 + Vector2(10, 10),
			1.0, 1.06, 9.0)
	# 标题 / 旁白 / 进度
	var accent: Color = p["accent"]
	_title_bar.color = accent
	_title_label.text = str(p["title"])
	_narr_label.text = str(p["text"])
	_narr_label.visible_ratio = 0.0
	_refresh_dots(i)
	if bool(p.get("battle", false)):
		_hint_label.text = "%d / %d · 点击，深入梦境 ▼" % [i + 1, PanelsData.PANELS.size()]
	else:
		_hint_label.text = "%d / %d · 点击继续 ▼" % [i + 1, PanelsData.PANELS.size()]
	# 进场动画
	_frame.modulate.a = 0.0
	_frame.scale = Vector2.ONE * 1.12
	_title_bar.modulate.a = 0.0
	_title_label.modulate.a = 0.0
	var in_tw := create_tween()
	in_tw.set_parallel(true)
	in_tw.tween_property(_frame, "modulate:a", 1.0, 0.3)
	in_tw.tween_property(_frame, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	in_tw.tween_property(_title_bar, "modulate:a", 1.0, 0.4).set_delay(0.25)
	in_tw.tween_property(_title_label, "modulate:a", 1.0, 0.4).set_delay(0.3)
	if _fx != null and _fx.is_valid():
		_fx.kill()
	_fx = create_tween()
	_fx.tween_property(_narr_label, "visible_ratio", 1.0,
		clampf(str(p["text"]).length() * 0.022, 0.5, 1.6))
	_play_sfx("panel_open")

func _refresh_dots(cur: int) -> void:
	# v27.12: 进度 ColorRect 首建后缓存复用——翻格只改颜色透明度，不再 free+new 重建 11 个节点
	if _dot_rects.size() != PanelsData.PANELS.size():
		for c in _dots.get_children():
			c.free()
		_dot_rects.clear()
		for i in PanelsData.PANELS.size():
			var d := ColorRect.new()
			d.custom_minimum_size = Vector2(14, 6)
			d.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_dots.add_child(d)
			_dot_rects.append(d)
	for i in _dot_rects.size():
		var col: Color = PanelsData.PANELS[i]["accent"]
		_dot_rects[i].color = Color(col.r, col.g, col.b, 0.9 if i == cur else 0.28)

# ───────────────────── v24.3：梦境战衔接 ─────────────────────

## B2 点击 → 切入可玩梦境战；战毕 battle 侧挂 resume meta 回本场景续播 B3–B7。
## comic_pending 从标题屏带过来一直未消费，回归后的收尾照常落 wakeup。
## 干跑（测试）：只发信号 + 镜像 resume meta，不切场景。
func _enter_dream_battle() -> void:
	Engine.set_meta(META_BATTLE_RESUME, BATTLE_RESUME_INDEX)
	if Engine.has_meta(META_DRY_RUN):
		dream_battle_requested.emit()
		return
	SceneTransition.change(get_tree(), BATTLE_SCENE)

# ───────────────────── 收尾 / 跳过 ─────────────────────

func _finish(skipped: bool) -> void:
	if _finished:
		return
	_finished = true
	if _fx != null and _fx.is_valid():
		_fx.kill()
	var tw := create_tween()
	if not skipped:
		_end_label.visible = true
		_end_label.modulate.a = 0.0
		tw.tween_property(_curtain, "color:a", 1.0, 0.7)
		tw.parallel().tween_property(_end_label, "modulate:a", 1.0, 0.8).set_delay(0.35)
		tw.tween_interval(1.5)
	else:
		tw.tween_property(_curtain, "color:a", 1.0, 0.35)
	tw.tween_callback(_hand_off.bind(skipped))

func _hand_off(_skipped: bool) -> void:
	# 有 pending（正式新档流）或干跑（测试/预览）才挂醒来标记；编辑器直跑不污染状态
	var was_pending := Engine.has_meta(META_COMIC_PENDING)
	Engine.remove_meta(META_COMIC_PENDING)
	if was_pending or Engine.has_meta(META_DRY_RUN):
		Engine.set_meta(META_WAKEUP, true)
	intro_finished.emit()
	if Engine.has_meta(META_DRY_RUN):
		return
	SceneTransition.change(get_tree(), BUNKER_SCENE)

func _unhandled_input(event: InputEvent) -> void:
	if _finished:
		return
	if event is InputEventKey and event.is_pressed():
		if event.keycode == KEY_ESCAPE:
			_finish(true)
		elif event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			advance()
	elif event is InputEventMouseButton and event.is_pressed() 			and event.button_index == MOUSE_BUTTON_LEFT:
		advance()

func _play_sfx(sfx_name: String) -> void:
	if SignalBus != null and SignalBus.has_signal("play_sound"):
		SignalBus.play_sound.emit(sfx_name)
