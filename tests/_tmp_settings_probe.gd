extends Node
## R6-1 设置面板探针：布局实拍 + 键位重绑端到端（合成按键走真实输入管线）。
## 跑法：godot --path . res://tests/_tmp_settings_probe.tscn

var _fail := 0

func _chk(cond: bool, msg: String) -> void:
	if not cond:
		_fail += 1
		print("[SettingsProbe] FAIL: ", msg)


func _ready() -> void:
	var panel: PanelContainer = (load("res://scenes/ui/settings_panel.tscn") as PackedScene).instantiate()
	add_child(panel)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	await get_tree().process_frame
	await get_tree().process_frame
	# 1) 布局实拍（上/下两段）
	var scroll: ScrollContainer = panel.get_node("Margin/VBoxMain/Scroll")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://.godot/agent_tools/settings_layout.png")
	scroll.scroll_vertical = 10000
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://.godot/agent_tools/settings_bottom.png")
	scroll.scroll_vertical = 0
	# 2) 键位重绑端到端：进入捕捉 → 合成 K 键 → 断言生效+落盘
	panel._on_keybind_button_pressed("pw_open_map")
	await get_tree().process_frame
	_chk(KeyBinds.capture_active, "capture 未进入")
	var ev := InputEventKey.new()
	ev.keycode = KEY_K
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().process_frame
	await get_tree().process_frame
	var label: String = KeyBinds.get_binding_label("pw_open_map")
	print("[SettingsProbe] pw_open_map label after K = ", label)
	_chk(not KeyBinds.capture_active, "capture 未收尾")
	_chk(label == "K", "重绑后标签应=K 实际=" + label)
	var cfg := ConfigFile.new()
	var load_ok: int = cfg.load("user://settings.cfg")
	_chk(load_ok == OK, "cfg load 失败")
	var saved: Array = cfg.get_value("keybinds", "pw_open_map", [])
	_chk(KEY_K in saved, "K 未落盘 keybinds 段")
	# 3) 恢复默认
	KeyBinds.reset_all()
	_chk("M" in KeyBinds.get_binding_label("pw_open_map"), "恢复默认失败")
	# 4) 色盲下拉切到 2 档 → 断言 ColorGrade uniform 同步
	panel._cb_option.selected = 2
	panel._on_color_blind_selected(2)
	var cg: Node = get_tree().root.get_node("ColorGrade")
	_chk(cg.get_color_blind_mode() == 2, "色盲档未同步到 ColorGrade")
	# 5) 收尾实拍（键位行显示恢复后的默认值）
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://.godot/agent_tools/settings_after_rebind.png")
	print("[SettingsProbe] %s" % ("ALL PASS" if _fail == 0 else "%d FAIL" % _fail))
	get_tree().quit()
