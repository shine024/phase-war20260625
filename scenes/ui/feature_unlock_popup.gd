extends Control
class_name FeatureUnlockPopup
## P2-13: 首次解锁功能说明弹窗（学黑猴"广智变身"式的功能解锁引导）
##
## 新系统首次触发时弹一次带一句话说明的 Modal，之后不再打扰（user:// 持久化）。
## 用法：FeatureUnlockPopup.show_once("key", "标题", "说明文字")
## 层级：独立 CanvasLayer(250)，全项目最高（高于 MVP/Toast 的 200）——
## 低层级会导致弹窗被结算面板的 STOP 背板盖住、按钮点不到（已踩坑，勿改回）。

const DT = preload("res://resources/design_tokens.gd")
const PanelStyles = preload("res://scripts/ui/panel_styles.gd")
const SAVE_PATH := "user://feature_unlock_seen.json"

static var _seen_cache: Dictionary = {}
static var _cache_loaded := false

static func show_once(feature_key: String, title: String, description: String) -> void:
	if feature_key.is_empty() or _already_seen(feature_key):
		return
	_mark_seen(feature_key)
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	var popup := FeatureUnlockPopup.new()
	popup._setup(feature_key, title, description)
	tree.root.add_child(popup)

static func _already_seen(feature_key: String) -> bool:
	_load_cache()
	return _seen_cache.has(feature_key)

static func _mark_seen(feature_key: String) -> void:
	_load_cache()
	_seen_cache[feature_key] = true
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_seen_cache))
		f.close()

static func _load_cache() -> void:
	if _cache_loaded:
		return
	_cache_loaded = true
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary:
		_seen_cache = parsed

# ── 实例部分 ──────────────────────────────────────────────────────

var _feature_key: String = ""
var _title: String = ""
var _description: String = ""

func _setup(feature_key: String, title: String, description: String) -> void:
	_feature_key = feature_key
	_title = title
	_description = description

func _ready() -> void:
	# 暂停豁免：弹窗可能出现在结算/暂停帧，必须仍可交互
	process_mode = Node.PROCESS_MODE_ALWAYS
	var layer := CanvasLayer.new()
	layer.layer = 250
	layer.name = "FeatureUnlockLayer"
	add_child(layer)

	var backdrop := ColorRect.new()
	backdrop.color = DT.COLOR_BACKDROP
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	# 批次三 B7：背板点击可关闭，挂手型光标提示可点
	backdrop.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# 点击背板也可关闭（防再次出现"点不到按钮卡死"类问题）
	backdrop.gui_input.connect(_on_backdrop_gui_input)
	layer.add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(430, 0)
	var accent: Color = DT.COLOR_ACCENT_CYAN
	# 批次三 B13：根框架收口 PanelStyles 工厂（原手写 StyleBox + 边距）
	panel.add_theme_stylebox_override("panel", PanelStyles.make_panel_frame(accent))
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var badge := Label.new()
	badge.text = "✦ 新功能解锁"
	badge.add_theme_font_size_override("font_size", DT.FONT_SIZE_XSMALL)
	badge.add_theme_color_override("font_color", accent)
	vbox.add_child(badge)

	var title_lbl := Label.new()
	title_lbl.text = _title
	title_lbl.add_theme_font_size_override("font_size", DT.FONT_SIZE_LARGE)
	title_lbl.add_theme_color_override("font_color", DT.COLOR_TEXT_BRIGHT)
	vbox.add_child(title_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = _description
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.custom_minimum_size = Vector2(380, 0)
	desc_lbl.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	desc_lbl.add_theme_color_override("font_color", DT.COLOR_TEXT_MID)
	vbox.add_child(desc_lbl)

	var btn := Button.new()
	btn.text = "知道了"
	btn.custom_minimum_size = Vector2(120, 34)
	var styles: Dictionary = PanelStyles.make_button_styles(accent, "solid")
	for state_key in ["normal", "hover", "pressed", "disabled", "focus"]:
		btn.add_theme_stylebox_override(state_key, styles[state_key])
	btn.pressed.connect(_on_confirm)
	var btn_box := HBoxContainer.new()
	btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_box.add_child(btn)
	vbox.add_child(btn_box)

	panel.modulate.a = 0.0
	# C7: 动效时长走 DT.MOTION_*（淡入 SINE），尊重减少动效开关
	if DesignTokens.is_motion_reduce():
		panel.modulate.a = 1.0
	else:
		var tw := create_tween()
		tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(panel, "modulate:a", 1.0, DesignTokens.MOTION_FADE_IN)

	var am = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_sfx"):
		am.play_sfx("blueprint_unlock")

func _on_backdrop_gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		queue_free()

func _on_confirm() -> void:
	var am = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_sfx"):
		am.play_sfx("button")
	queue_free()

func _input(event: InputEvent) -> void:
	# P0: 原实现用 _unhandled_input——main._close_top_overlay 在 _input 阶段先执行，
	# 解锁弹窗和底下一个 overlay 会被同一次 ESC 连关两层。改 _input + consume 先吃掉事件。
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		queue_free()
