extends SceneTree
## v28 T4 背包稀有度辉光实拍（临时工具）：造 6 个不同稀有度实例 → 开背包 → 截图。
## 用法：godot --rendering-driver opengl3 --path . --script tests/_tmp_t4_backpack_rarity_shot.gd

func _initialize() -> void:
	_run()

func _run() -> void:
	await process_frame
	await process_frame
	var sm: Node = root.get_node("SaveManager")
	if sm != null and sm.has_method("load_game"):
		print("[T4Shot] load_game=", sm.call("load_game"))
		if sm.has_method("flush_deferred_manager_loads"):
			sm.call("flush_deferred_manager_loads")
	await process_frame
	# 每稀有度挑第一张战斗卡建实例（走正规 create_instance 链，不碰共享模板）
	await process_frame
	# 先开面板再建实例：presenter 存活时走 card_added_to_backpack 实时消费链
	# （铁律 2 的正规路径；先建卡后开面板会让裸面板错过初始播种，QA 上下文无 main 接线）
	var panel: Node = (load("res://scenes/ui/backpack_panel.tscn") as PackedScene).instantiate()
	if panel is Control:
		(panel as Control).set_anchors_preset(Control.PRESET_FULL_RECT)
		(panel as Control).size = Vector2(1280, 720)
	root.add_child(panel)
	for i in 30:
		await process_frame
	var ir: Node = root.get_node("InstanceRegistry")
	var dc = load("res://data/default_cards.gd")
	var picked: Dictionary = {}
	for c in dc.create_all():
		if c == null or int(c.card_type) != 0:
			continue
		var r: String = str(c.rarity)
		if not picked.has(r):
			picked[r] = str(c.card_id)
	var made: Array[String] = []
	var sb: Node = root.get_node("SignalBus")
	for r in ["common", "uncommon", "rare", "epic", "legendary", "mythic"]:
		if picked.has(r):
			var inst = ir.call("create_instance", picked[r])
			if inst != null:
				made.append("%s=%s" % [r, picked[r]])
				# create_instance 只发 instance_created；card_added_to_backpack 由获取方发
				# （商店购买/drop 掉落同款）——QA 造卡必须补这一步背包才收
				sb.card_added_to_backpack.emit(inst)
	print("[T4Shot] instances=", made)
	for i in 60:
		await process_frame
	var img: Image = root.get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		img.save_png("res://.godot/agent_tools/t4_backpack_rarity.png")
		print("[T4Shot] saved")
	else:
		print("[T4Shot] EMPTY capture")
	quit(0)
