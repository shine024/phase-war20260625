extends Control
## v6.20 教程聚光视觉探针（临时）：SubViewport 直采免 DPI 缩放。
## 用法（独立窗口跑一次自存图自退出）：
##   godot --path . res://tests/_tmp_spotlight_probe.tscn
## 输出：.godot/agent_tools/tutorial_spotlight_probe.png
## 复刻基地教程第 2 步观感：左教程框 + 中右"卡牌展示墙"热区被聚光圈住。

const TutorialSpotlight = preload("res://scripts/ui/tutorial_spotlight.gd")

func _ready() -> void:
	var svp := SubViewport.new()
	svp.size = Vector2i(1280, 720)
	svp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(svp)
	var root := Control.new()   # 聚光宿主必须是全屏 Control（SubViewport 不是 Control）
	root.size = Vector2(1280, 720)
	svp.add_child(root)

	# 底：暗色基地底板（近似车厢剖面观感的深底）
	var bg := ColorRect.new()
	bg.color = Color(0.075, 0.086, 0.102)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	for i in 6:   # 简易车厢竖梁，给暗幕挖孔提供可读参照
		var beam := ColorRect.new()
		beam.color = Color(0.11, 0.125, 0.145)
		beam.position = Vector2(120 + i * 190, 160)
		beam.size = Vector2(38, 480)
		root.add_child(beam)

	# 假热区×3（中=目标"卡牌展示墙"，flat Button + 常显短牌，样式抄 truck_base 口径）
	var names := [["补给售货机", Vector2(520, 250)], ["卡牌展示墙", Vector2(660, 230)], ["工具工作台", Vector2(810, 250)]]
	var target: Button = null
	for n in names:
		var b := Button.new()
		b.flat = true
		b.position = n[1]
		b.size = Vector2(110, 260 if String(n[0]) == "卡牌展示墙" else 240)
		root.add_child(b)
		var tag := Label.new()
		tag.text = String(n[0])
		tag.add_theme_font_size_override("font_size", 12)
		tag.add_theme_color_override("font_color", Color(0.96, 0.97, 0.93))
		var tsb := StyleBoxFlat.new()
		tsb.bg_color = Color(0.03, 0.05, 0.06, 0.92)
		tsb.border_color = Color(0.45, 0.93, 0.62)
		tsb.set_border_width_all(1)
		tsb.set_corner_radius_all(4)
		tsb.content_margin_left = 7
		tsb.content_margin_right = 7
		tsb.content_margin_top = 3
		tsb.content_margin_bottom = 3
		tag.add_theme_stylebox_override("normal", tsb)
		tag.position = Vector2(2, 2)
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(tag)
		if String(n[0]) == "卡牌展示墙":
			target = b

	# 假教程框（左带，tutorial_overlay 卡仓步口径：500×300 @ 0.28-0.72 锚）
	var box := PanelContainer.new()
	box.position = Vector2(14, 200)
	box.custom_minimum_size = Vector2(372, 300)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.1, 0.15, 0.95)
	sb.border_color = Color(0.0, 0.941, 1, 0.6)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(16)
	box.add_theme_stylebox_override("panel", sb)
	root.add_child(box)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	box.add_child(vb)
	var tl := Label.new()
	tl.text = "清点卡仓"
	tl.add_theme_font_size_override("font_size", 16)
	tl.add_theme_color_override("font_color", Color(0.941, 1, 1))
	vb.add_child(tl)
	var cl := Label.new()
	cl.text = "卡仓里是你拥有的所有卡牌。战斗卡用于部署作战，符文与资源在对应标签页管理。在移动基地点击「卡牌展示墙」工位也能打开同一个卡仓。\n\n• 战斗卡：部署到战场作战\n• 同名战斗卡各自独立养成\n• 符文/资源在对应标签页；卡牌墙工位即卡仓"
	cl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cl.add_theme_font_size_override("font_size", 13)
	cl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	vb.add_child(cl)

	# 聚光层（复刻游戏实况：教程 overlay 是游戏 UI 之外的独立层，挂在最上面；
	# 同宿主会因 move_child(0) 压到游戏 UI 底下——探针早期版本的坑，勿回退）
	var overlay_host := Control.new()
	overlay_host.name = "OverlayHost"
	overlay_host.size = Vector2(1280, 720)
	overlay_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(overlay_host)
	TutorialSpotlight.attach(overlay_host, target, "发光的工位就是卡仓，点它")

	# 诊断：聚光层是否在树上、尺寸与挖孔是否正确
	for i in 30:   # 让脉冲环跑到中段相位再截
		await get_tree().process_frame
	var sp := overlay_host.get_node_or_null("TutorialSpotlight")
	if sp == null:
		printerr("PROBE_DIAG spotlight node missing")
	else:
		var hole: Rect2 = sp.get("_hole")
		print("PROBE_DIAG sp.size=", sp.size, " hole=", hole, " visible=", sp.is_visible_in_tree(),
			" target_visible=", target.is_visible_in_tree(),
			" tip_visible=", sp.get_node("TipBack").visible if sp.has_node("TipBack") else false)
	var img := svp.get_texture().get_image()
	var out_path := ProjectSettings.globalize_path("res://.godot/agent_tools/tutorial_spotlight_probe.png")
	DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())
	img.save_png(out_path)
	print("SPOTLIGHT_PROBE_SAVED ", out_path)
	get_tree().quit()
