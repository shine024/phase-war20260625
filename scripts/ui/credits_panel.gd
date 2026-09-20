extends Control
class_name CreditsPanel
## 制作人员/许可页（S17 授权链缺口修复，2026-09-20）：引擎/字体/音频授权的玩家可见声明。
## 入口 = title_screen「制作人员」按钮 → CreditsPanel.open(get_tree())。
## 数据 const 内联——assets/sfx/CREDITS.md 是内部凭据存档（*.md 不进发行包），
## BGM 授权落定后本页 MUSIC 行与该文件同步更新。
## 开合走 PanelAnim 统一规格；ESC/手柄 Ⓑ 与 ✕ 同关；接手柄时焦点落关闭键。

const DT = preload("res://resources/design_tokens.gd")
const PanelStyles = preload("res://scripts/ui/panel_styles.gd")
const PanelChrome = preload("res://scenes/ui/components/panel_chrome.gd")

const PANEL_MIN := Vector2(620, 520)

## 声明数据（顺序即展示顺序）
const SECTIONS := [
	{"title": "引擎", "lines": [
		"Godot Engine 4.5.1",
		"MIT License · © Juan Lini and the Godot community",
		"godotengine.org",
	]},
	{"title": "字体", "lines": [
		"Rajdhani — Indian Type Foundry · SIL Open Font License 1.1",
		"Noto Sans SC — Google · SIL Open Font License 1.1",
		"OFL 许可全文随游戏文件附带（assets/fonts/）",
	]},
	{"title": "音乐与音效", "lines": [
		"音效：本项目原创合成",
		"背景音乐：发行版曲目与第三方授权署名将于发行前定稿，",
		"并在商店页署名区同步公示",
	]},
	{"title": "美术", "lines": [
		"部分美术资产由 AI 生成，并经人工审核与修改；",
		"范围说明见商店页 AI 内容披露",
	]},
]


func _ready() -> void:
	# 全屏根：吃 ESC（_unhandled_input），点击空白处也可关
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.04, 0.06, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var accent := DT.get_panel_accent("settings")
	var panel := PanelContainer.new()
	panel.custom_minimum_size = PANEL_MIN
	panel.add_theme_stylebox_override("panel", PanelStyles.make_panel_frame_textured(accent))
	center.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)
	var chrome = PanelChrome.attach_to(vbox, "制作人员与许可", accent, "CREDITS & LICENSES")
	if chrome != null and chrome.has_signal("closed"):
		chrome.closed.connect(close)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 380)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 14)
	scroll.add_child(content)

	for sec in SECTIONS:
		var title := Label.new()
		title.text = String(sec.title)
		title.add_theme_font_size_override("font_size", DT.FONT_SIZE_MEDIUM)
		title.add_theme_color_override("font_color", DT.COLOR_CYAN_TECH)
		content.add_child(title)
		for line in sec.lines:
			var lbl := Label.new()
			lbl.text = String(line)
			lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			lbl.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
			lbl.add_theme_color_override("font_color", DT.COLOR_TEXT_MID)
			content.add_child(lbl)

	var close_btn := Button.new()
	close_btn.text = "关闭"
	close_btn.custom_minimum_size = Vector2(120, 34)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.pressed.connect(close)
	vbox.add_child(close_btn)
	_close_btn = close_btn

	visible = true
	PanelAnim.open(self)
	PanelAnim.focus_first.call_deferred(self)


var _close_btn: Button = null


func _unhandled_input(event: InputEvent) -> void:
	if KeyBinds.is_back_event(event):
		close()
		get_viewport().set_input_as_handled()


func close() -> void:
	PanelAnim.close(self)
	queue_free()
