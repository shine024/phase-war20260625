extends Control
## 制造舱右栏复活视觉探针（窗口化跑一次自存图自退出）
## 验收点：选中配方后右栏 = 卡面预览 + 卡名 + 基础信息 + 制造条件 + 制成属性 + 资源消耗 + 制造按钮；
## 改造图纸模式 = 预览/统计九格隐藏、其余四块亮。
## 截图 .godot/agent_tools/evo_detail_probe_{card,mod}.png + stdout 分节 dump，供目视。
## 运行：godot --rendering-driver opengl3 --path . res://tests/_tmp_evo_detail_probe.tscn

const SECTIONS: Array[String] = [
	"TargetNamePanel", "InfoPanel", "RequirementsPanel",
	"StatsPanel", "ResourcePanel", "PreviewPanel",
]


func _ready() -> void:
	var panel: Control = load("res://scenes/ui/evolution_panel.tscn").instantiate()
	add_child(panel)
	await get_tree().process_frame
	await get_tree().process_frame
	var mgr: Node = panel._mgr()
	var rid := ""
	if mgr != null:
		var recipes: Array = mgr.get_recipe_ids()
		for r in recipes:
			if mgr.is_manufacturable(String(r)):
				rid = String(r)
				break
		if rid.is_empty() and recipes.size() > 0:
			rid = String(recipes[0])
	print("PROBE recipe=", rid)
	if rid != "":
		panel._on_recipe_selected(rid)
	await get_tree().process_frame
	await get_tree().process_frame
	_dump(panel, "card")
	_shot("evo_detail_probe_card.png")

	# 改造图纸模式（自动选中随机补给箱）
	panel._set_craft_mode(panel.MODE_MOD)
	await get_tree().process_frame
	await get_tree().process_frame
	_dump(panel, "mod")
	_shot("evo_detail_probe_mod.png")

	get_tree().quit()


func _dump(panel: Control, tag: String) -> void:
	for uname in SECTIONS:
		var c: Control = panel.get_node("%" + uname)
		print("PROBE[%s] %s visible=%s rect=%s" % [tag, uname, c.visible, c.get_global_rect()])
	print("PROBE[%s] name='%s' preview_tex=%s" % [
		tag, panel.target_name_label.text, panel.preview_texture.texture != null])


func _shot(fname: String) -> void:
	var img := get_viewport().get_texture().get_image()
	var dir := DirAccess.open("res://.godot")
	if dir != null and not dir.dir_exists("agent_tools"):
		dir.make_dir("agent_tools")
	img.save_png("res://.godot/agent_tools/" + fname)
	print("PROBE saved ", fname)
