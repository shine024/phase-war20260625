extends RefCounted
class_name KeycapBadge
## UI 四级标准修复 R-B2：快捷键可见角标——学《朝露》"图标上标按键字母"
## （审计缺口：KeyBinds 六动作 + 部署 1-9 的键位此前只活在 tooltip 文字里，图标上零标注）。
##
## 角标 = 宿主右上角小圆片 Label（暗底亮字黑描边），纯视觉 mouse_filter=IGNORE，
## 不吃点击、不挡宿主 hover/按下。字号 10px（纯数字/字母角标档，"中文 ≥12"红线不适用）。
##
## KeyBinds 是静态类无变更信号——重绑后由宿主在下次可见/展开时机批量调
## KeycapBadge.refresh(badge) 重读绑定（bottom_function_bar 抽屉展开时刷）。
## 部署槽 1-9 是固定数字键不重绑，走 bind_to_digit 静态标注。

const DT = preload("res://resources/design_tokens.gd")


## 给宿主按钮挂键位角标（幂等：已挂过只刷文本）。动作未注册/未绑定时角标隐藏。
static func bind_to_action(btn: Control, action_id: String) -> void:
	if btn == null or not is_instance_valid(btn) or action_id.is_empty():
		return
	var badge := _ensure_badge(btn)
	badge.set_meta("action_id", action_id)
	refresh(badge)


## 按部署序号挂静态数字角标（部署槽专用：槽序=键盘数字键）。
## digit 超出 1-9（含 0=不可部署）时隐藏——数字键只有 1-9。
static func bind_to_digit(host: Control, digit: int) -> void:
	if host == null or not is_instance_valid(host):
		return
	if digit < 1 or digit > 9:
		_hide_badge(host)
		return
	var badge := _ensure_badge(host)
	badge.set_meta("action_id", "")
	badge.text = str(digit)
	badge.visible = true


## 重读 action 当前绑定并刷新文本（宿主在抽屉展开等时机批量调用）。
static func refresh(badge: Label) -> void:
	if badge == null or not is_instance_valid(badge):
		return
	var action: String = String(badge.get_meta("action_id", ""))
	if action.is_empty():
		return
	var text := primary_binding_text(action)
	badge.text = text
	badge.visible = not text.is_empty()


## 动作主绑定键名（取第一个按键事件；pw_open_backpack 这类多键动作只示首选，
## 完整键位仍在 tooltip 文案里）。
static func primary_binding_text(action_id: String) -> String:
	if not InputMap.has_action(action_id):
		return ""
	for ev in InputMap.action_get_events(action_id):
		if ev is InputEventKey:
			return OS.get_keycode_string((ev as InputEventKey).keycode)
	return ""


static func _ensure_badge(host: Control) -> Label:
	var badge := host.get_node_or_null("KeycapBadge") as Label
	if badge != null and is_instance_valid(badge):
		return badge
	badge = Label.new()
	badge.name = "KeycapBadge"
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 10)
	badge.add_theme_color_override("font_color", DT.COLOR_TEXT_BRIGHT)
	badge.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	badge.add_theme_constant_override("outline_size", 3)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(DT.COLOR_PANEL_DEEP.r, DT.COLOR_PANEL_DEEP.g, DT.COLOR_PANEL_DEEP.b, 0.92)
	sb.border_color = Color(0, 0, 0, 0.65)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 3.0
	sb.content_margin_right = 3.0
	sb.content_margin_top = 0.0
	sb.content_margin_bottom = 0.0
	badge.add_theme_stylebox_override("normal", sb)
	host.add_child(badge)
	# 锚点钉宿主右上角（随 rect 自适应——按钮 62px / 部署槽 40-90px 都不溢出）
	badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	badge.offset_left = -14.0
	badge.offset_top = 1.0
	badge.offset_right = -2.0
	badge.offset_bottom = 12.0
	return badge


static func _hide_badge(host: Control) -> void:
	var badge := host.get_node_or_null("KeycapBadge") as Label
	if badge != null and is_instance_valid(badge):
		badge.visible = false
