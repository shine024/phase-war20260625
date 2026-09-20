extends Control
## 结算页底栏四键布局视觉探针（窗口化跑一次自存图自退出）
## 复现用户报告的「按钮重叠」：v38.1 四键行里「返回整备」曾整键叠在
##「返回移动基地」上。跑完输出各按钮全局矩形到 stdout + 截图
## .godot/agent_tools/settle_row_probe.png，供像素级目视。
## 运行：godot --rendering-driver opengl3 --path . res://tests/_tmp_settle_row_probe.tscn

func _ready() -> void:
	# 教程置终态 + 造出"胜利·非挂机·有下一关"前提 → 走最多键的四键分支
	var tpm := get_node_or_null("/root/TutorialProgressionManager")
	if tpm != null:
		tpm.set("current_step", 13)  # FREEDOM_MODE
	var gm := get_node_or_null("/root/GameManager")
	if gm != null:
		gm.set("current_level", 5)
		gm.set("_pending_battle_level", 5)
	var lpm := get_node_or_null("/root/LevelProgressManager")
	if lpm != null and lpm.get("unlocked_levels") is Array:
		var ul: Array = lpm.get("unlocked_levels")
		for lv in [5, 6]:
			if not ul.has(lv):
				ul.append(lv)
	# BunkerManager 是懒加载 manager——拉起它才有第四键「返回移动基地」（用户命中的场景）。
	# root 未 ready 时挂载走 call_deferred，先等一帧再查在树。
	var mll := get_node_or_null("/root/ManagerLazyLoader")
	if mll != null and mll.has_method("ensure_loaded"):
		mll.ensure_loaded("bunker")
	await get_tree().process_frame
	var bunker := get_node_or_null("/root/BunkerManager")
	print("PROBE bunker_present=", bunker != null)
	if bunker != null and not bunker.has_method("get_day"):
		print("PROBE bunker_missing_get_day")

	var panel: Control = load("res://scenes/ui/mvp_panel.gd").create(
		self, true, [], 0, 1, {}, false)

	await get_tree().process_frame
	await get_tree().process_frame

	var img := get_viewport().get_texture().get_image()
	var dir := DirAccess.open("res://.godot")
	if dir != null and not dir.dir_exists("agent_tools"):
		dir.make_dir("agent_tools")
	img.save_png("res://.godot/agent_tools/settle_row_probe.png")

	var p := panel.get_node_or_null("MvpPanelOverlay/Panel")
	if p != null:
		var rects: Array[Rect2] = []
		for c in p.get_children():
			if c is Button and (c as Button).text != "":
				var r: Rect2 = (c as Button).get_global_rect()
				rects.append(r)
				print("BTN '", (c as Button).text, "' rect=", r)
		# 两两矩形求交：任何非空交叠即失败
		var overlaps: Array[String] = []
		for i in range(rects.size()):
			for j in range(i + 1, rects.size()):
				var inter := rects[i].intersection(rects[j])
				if inter.size.x > 1.0 and inter.size.y > 1.0:
					overlaps.append("按钮%d×按钮%d 交叠 %s" % [i, j, inter])
		if overlaps.is_empty():
			print("SETTLE_ROW_NO_OVERLAP")
		else:
			for o in overlaps:
				printerr("OVERLAP: " + o)
	get_tree().quit()
