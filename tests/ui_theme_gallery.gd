extends SceneTree
## UI 主题画廊截图（临时验证件）：构建一批裸控件，验证全局主题效果。
## 用法：godot --path . --rendering-driver opengl3 --script tests/ui_theme_gallery.gd
## 输出：.godot/ui_theme_gallery.png（改主题前后各跑一次做对比）

const OUT_PATH := "res://.godot/ui_theme_gallery.png"

var _frames := 0


func _initialize() -> void:
	# 挂中文 fallback 链（与 main/title_screen 启动时同一入口），验证打包 Noto 字体
	var DT := load("res://resources/design_tokens.gd")
	DT.ensure_cjk_fallback()
	var ui := Control.new()
	ui.name = "Gallery"
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(ui)

	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.07, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(bg)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_constant_override("margin_left", 40)
	panel.add_theme_constant_override("margin_right", 40)
	panel.add_theme_constant_override("margin_top", 24)
	panel.add_theme_constant_override("margin_bottom", 24)
	ui.add_child(panel)

	var margin := MarginContainer.new()
	for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(m, 16)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	# --- TabContainer（情报/背包/成就等面板的页签形态） ---
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var t1 := VBoxContainer.new()
	t1.name = "情报"
	var t2 := VBoxContainer.new()
	t2.name = "背包"
	var t3 := VBoxContainer.new()
	t3.name = "成就"
	tabs.add_child(t1)
	tabs.add_child(t2)
	tabs.add_child(t3)
	vbox.add_child(tabs)

	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 10)
	t1.add_child(row1)
	var b1 := Button.new()
	b1.text = "确认部署"
	row1.add_child(b1)
	var b2 := Button.new()
	b2.text = "禁用按钮"
	b2.disabled = true
	row1.add_child(b2)
	var cb := CheckBox.new()
	cb.text = "自动释放大招"
	cb.button_pressed = true
	row1.add_child(cb)
	var ck := CheckButton.new()
	ck.text = "减少动效"
	row1.add_child(ck)

	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 10)
	t1.add_child(row2)
	var le := LineEdit.new()
	le.placeholder_text = "搜索卡牌…"
	le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row2.add_child(le)
	var pb := ProgressBar.new()
	pb.value = 62.0
	pb.show_percentage = true
	pb.custom_minimum_size = Vector2(200, 0)
	row2.add_child(pb)

	var t2v := VBoxContainer.new()
	t2.add_child(t2v)
	var il := ItemList.new()
	il.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for i in 6:
		il.add_item("动力装甲 #%d" % (i + 1))
	il.select(1)
	t2v.add_child(il)

	var t3v := VBoxContainer.new()
	t3.add_child(t3v)
	var rl := RichTextLabel.new()
	rl.bbcode_enabled = true
	rl.fit_content = true
	rl.text = "[b]成就·初露锋芒[/b]\n赢得第一场战斗的胜利。"
	t3v.add_child(rl)
	t3v.add_child(HSeparator.new())

	var lbl := Label.new()
	lbl.text = "未样式化 Label / 次要文本对照"
	vbox.add_child(lbl)
	vbox.add_child(VSeparator.new())

	# 字体混排验证：标题字体（Rajdhani SemiBold + Noto Medium fallback）
	var title_lbl := Label.new()
	title_lbl.text = "PHASE WAR · 相位战争 中文字形验证"
	title_lbl.add_theme_font_override("font", DT.get_title_font())
	title_lbl.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title_lbl)

	# 质感版面板框（九宫格渐变底 + 烘焙边框）预览
	const PS := preload("res://scripts/ui/panel_styles.gd")
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", PS.make_panel_frame_textured(DT.get_panel_accent("intelligence")))
	var fl := Label.new()
	fl.text = "质感版面板框：情报中心 accent（九宫格渐变底）"
	fl.add_theme_font_size_override("font_size", DT.FONT_SIZE_BODY)
	frame.add_child(fl)
	vbox.add_child(frame)

	# 大尺寸九宫格拉伸验证（对齐真实养成面板 1180×640 量级，查渐变 banding/边框变形）
	var big := PanelContainer.new()
	big.custom_minimum_size = Vector2(920, 240)
	big.add_theme_stylebox_override("panel", PS.make_panel_frame_textured(DT.get_system_color("modify")))
	var bigv := VBoxContainer.new()
	big.add_child(bigv)
	var bl := Label.new()
	bl.text = "大面板九宫格拉伸：改造 accent 920×240（查渐变 banding 与四角 1:1）"
	bl.add_theme_font_size_override("font_size", DT.FONT_SIZE_BODY)
	bigv.add_child(bl)
	var bl2 := Label.new()
	bl2.text = "中心区垂直渐变被纵向拉伸 ~1.9 倍：应无色带、边框恒 2px、圆角恒 14px"
	bl2.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	bl2.add_theme_color_override("font_color", DT.COLOR_TEXT_MID)
	bigv.add_child(bl2)
	vbox.add_child(big)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 8:
		var img := root.get_texture().get_image()
		img.save_png(OUT_PATH)
		print("[gallery] saved -> ", OUT_PATH, " ", img.get_size())
		quit()
	return false
