extends Node
## 临时诊断：战斗中底部 UI 重叠归因——打印 BattleBottomBar 三层 + BattleLogBar 的真实矩形
## 用法：godot --headless --script tests/_tmp_bottom_ui_probe.gd（无需模式文件）

func _wait_frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _dump(tag: String, main: Node) -> void:
	var hud: Node = main.get_node_or_null("HudLayer")
	if hud == null:
		print("[Probe] no HudLayer")
		return
	print("---- ", tag, " ----")
	for name in ["BattleBottomBar", "BattleBottomBar/BottomFunctionBar",
			"BattleBottomBar/UltimateCastBar", "BattleBottomBar/BottomInstrumentBar",
			"BattleLogBar"]:
		var c: Control = hud.get_node_or_null(name)
		if c == null:
			print("[Probe] %-42s MISSING" % name)
			continue
		var r: Rect2 = c.get_global_rect()
		print("[Probe] %-42s vis=%-5s a=%.2f rect=(%.0f, %.0f)-(%0.f, %.0f) size=%.0fx%.0f" % [
			name, str(c.visible), c.modulate.a, r.position.x, r.position.y,
			r.position.x + r.size.x, r.position.y + r.size.y, r.size.x, r.size.y])
	# 重叠检测
	var bar: Control = hud.get_node_or_null("BattleBottomBar")
	var logb: Control = hud.get_node_or_null("BattleLogBar")
	var ult: Control = hud.get_node_or_null("BattleBottomBar/UltimateCastBar")
	if ult != null and ult.has_method("get_cluster_left_x") and logb != null:
		var cl: float = float(ult.call("get_cluster_left_x"))
		var lr: Rect2 = logb.get_global_rect()
		print("[Probe] cluster_left=%.0f  log_right=%.0f  gap=%.0f  log_h=%.0f  log_bottom=%.0f" % [
			cl, lr.position.x + lr.size.x, cl - (lr.position.x + lr.size.x), lr.size.y,
			lr.position.y + lr.size.y])
	if bar != null and logb != null and logb.visible:
		var ch: Array[Control] = []
		for c in bar.get_children():
			if c is Control and c.visible:
				ch.append(c)
		for i in ch.size():
			for j in range(i + 1, ch.size()):
				var ov: Rect2 = ch[i].get_global_rect().intersection(ch[j].get_global_rect())
				if ov.size.y > 0.5 and ov.size.x > 0.5:
					print("[Probe] OVERLAP siblings: %s ∩ %s height=%.0f" % [
						ch[i].name, ch[j].name, ov.size.y])
		for c in ch:
			var ov: Rect2 = c.get_global_rect().intersection(logb.get_global_rect())
			if ov.size.y > 0.5 and ov.size.x > 0.5:
				print("[Probe] OVERLAP with BattleLogBar: %s covered %.0fpx of its %.0fpx height (log bottom=%.0f, child top=%.0f)" % [
					c.name, ov.size.y, c.get_global_rect().size.y,
					logb.get_global_rect().position.y + logb.get_global_rect().size.y,
					c.get_global_rect().position.y])

func _run() -> void:
	await _wait_frames(20)
	var sm: Node = get_node_or_null("/root/SaveManager")
	if sm != null and sm.has_method("load_game"):
		sm.call("load_game")
	await _wait_frames(10)
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	await _wait_frames(150)
	var popup: Node = main.get("popup_layer")
	if popup != null:
		for c in popup.get_children():
			var sc: Script = c.get_script()
			if sc != null and "offline" in String(sc.resource_path):
				c.queue_free()
	var pim: Node = get_node_or_null("/root/PhaseInstrumentManager")
	var ir: Node = get_node_or_null("/root/InstanceRegistry")
	if pim != null and ir != null:
		var equipped := 0
		for id in ir.call("get_all_instance_ids"):
			if equipped >= 5:
				break
			var card = ir.call("get_instance", id)
			if card != null and int(card.get("card_type")) == 0:
				if pim.call("equip_card", equipped, card):
					equipped += 1
		if equipped == 0 and ir.has_method("create_instance"):
			for starter_id in ["ww1_mauser", "ww1_arty_m81", "ww1_arm_ft17"]:
				var inst = ir.call("create_instance", starter_id)
				if inst != null and pim.call("equip_card", equipped, inst):
					equipped += 1
	var gm: Node = get_node_or_null("/root/GameManager")
	gm.call("set_current_level", 2)
	var setup: RefCounted = main.get("_battle_setup")
	setup.call("on_start_battle")
	await _wait_frames(45)
	var bm: Node = get_node_or_null("/root/BattleManager")
	var waited := 0
	while waited < 240:
		if bm != null and bool(bm.get("battle_active")):
			break
		await _wait_frames(5)
		waited += 5
	var bar: Node = main.get("bottom_instrument_bar")
	var btn: Button = bar.get("_auto_deploy_btn") if bar != null else null
	if btn != null:
		btn.button_pressed = true
		btn.pressed.emit()
	await _wait_frames(30)
	_dump("battle active, drawer CLOSED", main)
	var menu: Button = bar.get("_menu_btn") if bar != null else null
	if menu != null:
		menu.pressed.emit()
		await _wait_frames(45)
		_dump("battle active, drawer OPEN", main)
		menu.pressed.emit()
		await _wait_frames(45)
		_dump("battle active, drawer OPEN->CLOSED", main)
	var shot := get_viewport().get_texture().get_image()
	shot.save_png("res://.godot/agent_tools/bottom_ui_probe.png")
	print("[Probe] screenshot -> .godot/agent_tools/bottom_ui_probe.png")
	get_tree().quit()

func _ready() -> void:
	_run()
