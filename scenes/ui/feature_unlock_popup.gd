extends Control
class_name FeatureUnlockPopup
## P2-13: 首次解锁功能说明弹窗（学黑猴"广智变身"式的功能解锁引导）
##
## 新系统首次触发时弹一次带一句话说明的 Modal，之后不再打扰（user:// 持久化）。
## 用法：FeatureUnlockPopup.show_once("key", "标题", "说明文字")
## 层级：独立 CanvasLayer(150)，低于 Toast(200)，高于 PopupLayer(100)。

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
	var layer := CanvasLayer.new()
	layer.layer = 150
	layer.name = "FeatureUnlockLayer"
	add_child(layer)

	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.55)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(430, 0)
	var accent: Color = DT.COLOR_ACCENT_CYAN
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(DT.COLOR_PANEL.r, DT.COLOR_PANEL.g, DT.COLOR_PANEL.b, 0.98)
	sb.border_color = accent
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(DT.CORNER_RADIUS)
	sb.shadow_color = Color(accent.r, accent.g, accent.b, 0.35)
	sb.shadow_size = 12
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", sb)
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
	for state_key in styles:
		btn.add_theme_stylebox_override(state_key, styles[state_key])
	btn.pressed.connect(_on_confirm)
	var btn_box := HBoxContainer.new()
	btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_box.add_child(btn)
	vbox.add_child(btn_box)

	panel.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, 0.2)

	# 弹窗期间暂停按钮区域外点击不误关（只留确认按钮），ESC 也可关闭
	var am := Engine.get_main_loop().root.get_node_or_null("AudioManager")
	if am and am.has_method("play_sfx"):
		am.play_sfx("blueprint_unlock")

func _on_confirm() -> void:
	var am := Engine.get_main_loop().root.get_node_or_null("AudioManager")
	if am and am.has_method("play_sfx"):
		am.play_sfx("button")
	queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		accept_event()
		queue_free()
