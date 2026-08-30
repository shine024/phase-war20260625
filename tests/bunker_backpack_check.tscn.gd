extends Node
## 基地宿舍打开背包 → 相位仪可见性/装备链路实测（渲染模式跑，存截图）
## 复现用户路径：宿舍房间面板 → 打开背包（通用 id，不切 Tab）

var _fails: Array[String] = []

func _fail(msg: String) -> void:
	_fails.append(msg)
	print("[BUNKER-BACKPACK-CHECK] FAIL: " + msg)

func _ready() -> void:
	var scene: PackedScene = load("res://scenes/bunker/bunker_main.tscn")
	if scene == null:
		print("[BUNKER-BACKPACK-CHECK] FAIL: 无法加载 bunker_main.tscn")
		get_tree().quit(1)
		return
	var bunker = scene.instantiate()
	await get_tree().process_frame  # 根节点仍在装配 current_scene 时 add_child 会被拒——先让一帧
	get_tree().root.add_child(bunker)
	get_tree().current_scene = bunker
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	# 真实路径复现：光点到达宿舍 → 房间面板打开 → 点「打开背包」
	bunker._current_room_id = "dormitory"
	var def: Dictionary = bunker.BunkerRoomDefs.get_room("dormitory")
	bunker._panel.open_room(def, bunker._manager)
	await get_tree().process_frame
	# 测试档未看过开场引导卡会盖住全场——模拟点过「明白了」
	var intro: Node = bunker._ui_stage.get_node_or_null("IntroDim")
	if intro != null:
		intro.queue_free()
		await get_tree().process_frame
	bunker._open_embedded_panel("backpack")
	await get_tree().process_frame
	await get_tree().process_frame
	if not bunker._embed_wrappers.has("backpack"):
		_fail("背包内嵌面板未创建")
		_finish()
		return
	var bp: Control = bunker._embed_wrappers["backpack"]["panel"]
	var wrapper: Control = bunker._embed_wrappers["backpack"]["wrapper"]
	if not wrapper.visible:
		_fail("背包 wrapper 不可见")
	var tabc: TabContainer = bp.get_node_or_null("VBoxOuter/TabContainer")
	if tabc == null:
		_fail("TabContainer 未找到（路径 VBoxOuter/TabContainer）")
		_finish()
		return
	var titles: Array[String] = []
	for i in tabc.get_tab_count():
		titles.append(tabc.get_tab_title(i))
	print("[BUNKER-BACKPACK-CHECK] Tab 数=%d 标题=%s 当前页=%d" % [
		tabc.get_tab_count(), ", ".join(titles), tabc.current_tab])
	if tabc.get_tab_count() < 4:
		_fail("Tab 数不足 4（缺相位仪页）")
	if not titles.has("相位仪"):
		_fail("Tab 标题里没有「相位仪」: %s" % ", ".join(titles))

	# ── 几何取证：Tab 条 / 相位仪页签 在屏幕上的实际位置与遮挡 ──
	var stage: Control = bunker._ui_stage
	print("[BUNKER-BACKPACK-CHECK] stage=%s wrapper=%s panel=%s tabc(g)=%s" % [
		str(stage.size), str(wrapper.get_global_rect()),
		str(bp.get_global_rect()), str(tabc.get_global_rect())])
	var tabbar: TabBar = tabc.get_tab_bar() if tabc.has_method("get_tab_bar") else null
	if tabbar != null:
		var tb_g: Rect2 = tabbar.get_global_rect()
		print("[BUNKER-BACKPACK-CHECK] tabbar(g)=%s 可见=%s" % [str(tb_g), str(tabbar.is_visible_in_tree())])
		for i in tabbar.tab_count:
			print("[BUNKER-BACKPACK-CHECK]   tab[%d] %s local=%s" % [
				i, tabbar.get_tab_title(i), str(tabbar.get_tab_rect(i))])
		# 谁压在「相位仪」页签中心上（按绘制顺序，最后出现的在最上层）
		var idx := -1
		for i in tabbar.tab_count:
			if tabbar.get_tab_title(i) == "相位仪":
				idx = i
		if idx >= 0:
			var probe: Vector2 = tb_g.position + tabbar.get_tab_rect(idx).get_center()
			var covers: Array[String] = []
			_collect_covers(stage, probe, covers)
			var tail: Array[String] = covers.slice(maxi(0, covers.size() - 4))
			print("[BUNKER-BACKPACK-CHECK] 探针点=%s 覆盖数=%d 顶部4层(底→顶)=%s" % [
				str(probe), covers.size(), " | ".join(tail)])
			# mouse_filter 感知的最顶层拦截者（IGNORE 不拦截点击）
			var blocker: Control = null
			for path_in_stack in covers:
				pass
			var stack: Array[Control] = []
			_collect_cover_controls(stage, probe, stack)
			for i in range(stack.size() - 1, -1, -1):
				var c := stack[i]
				if c.mouse_filter != Control.MOUSE_FILTER_IGNORE:
					blocker = c
					break
			if blocker != null:
				var owner_panel := "外部"
				var anc: Node = blocker
				while anc != null:
					if anc == bp:
						owner_panel = "背包面板内"
						break
					anc = anc.get_parent()
				print("[BUNKER-BACKPACK-CHECK] 页签顶层拦截者=%s(%s) filter=%d 归属=%s" % [
					blocker.name, blocker.get_class(), blocker.mouse_filter, owner_panel])
			else:
				print("[BUNKER-BACKPACK-CHECK] 页签位置无拦截控件（点击可达 TabBar）")
	else:
		print("[BUNKER-BACKPACK-CHECK] tabbar 取不到（get_tab_bar 不存在）")

	# ── 相位仪栏随行：背包 wrapper 里应有 EmbedInstrumentBar，贴底、菜单按钮隐藏 ──
	var bar: Control = wrapper.get_node_or_null("EmbedInstrumentBar")
	if bar == null:
		_fail("背包 wrapper 里没有 EmbedInstrumentBar（基地无法拖卡装备）")
	else:
		if not bar.is_visible_in_tree():
			_fail("相位仪栏不可见")
		var br: Rect2 = bar.get_global_rect()
		print("[BUNKER-BACKPACK-CHECK] 相位仪栏(g)=%s" % str(br))
		if br.size.y <= 0.0:
			_fail("相位仪栏高度为 0")
		if absf(br.end.y - 698.0) > 3.0:
			_fail("相位仪栏未贴底（end.y=%d 应≈698）" % int(br.end.y))
		if br.position.y < 615.0:
			_fail("相位仪栏位置过高（y=%d 应≈629）" % int(br.position.y))
		var mb: Node = bar.get_node_or_null("Margin/HBox/MenuBtn")
		if mb != null and mb.visible:
			_fail("基地里菜单按钮应隐藏（死按钮）")
		if bp.get_global_rect().end.y > br.position.y + 6.0:
			_fail("背包面板底沿压过栏上沿（end.y=%d vs 栏顶=%d）" % [
				int(bp.get_global_rect().end.y), int(br.position.y)])
	# 渲染模式：宿舍打开背包时的实况截图
	print("[BUNKER-BACKPACK-CHECK] step: 截图前")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var img: Image = get_viewport().get_texture().get_image()
		if img != null and not img.is_empty():
			img.save_png("res://docs/界面一致性/基地宿舍_打开背包实况.png")
			print("[BUNKER-BACKPACK-CHECK] 已保存宿舍打开背包实况截图")
	print("[BUNKER-BACKPACK-CHECK] step: 截图后")

	# 模拟相位实验室入口：直达相位仪页（玩家从宿舍只能手动点第 4 个 Tab）
	print("[BUNKER-BACKPACK-CHECK] step: 切相位仪页前")
	if bp.has_method("switch_to_phase_instruments_tab"):
		bp.switch_to_phase_instruments_tab()
		await get_tree().process_frame
		await get_tree().process_frame
		print("[BUNKER-BACKPACK-CHECK] step: 切相位仪页后")
		print("[BUNKER-BACKPACK-CHECK] 切到相位仪页后 current_tab=%d 标题=%s" % [
			tabc.current_tab, tabc.get_tab_title(tabc.current_tab)])
		var pim: Node = get_node_or_null("/root/PhaseInstrumentManager")
		if pim != null and pim.has_method("get_unlocked_instrument_ids"):
			var unlocked: Array = pim.get_unlocked_instrument_ids()
			print("[BUNKER-BACKPACK-CHECK] 已解锁相位仪数=%d（首件=%s）" % [
				unlocked.size(), str(unlocked[0]) if unlocked.size() > 0 else "-"])
		var lst: Node = bp.get_node_or_null("VBoxOuter/TabContainer/PhaseInstTab/ScrollContainer/PhaseInstList")
		if lst != null:
			print("[BUNKER-BACKPACK-CHECK] 相位仪列表子节点数=%d" % lst.get_child_count())
		else:
			_fail("PhaseInstList 节点未找到")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			var img2: Image = get_viewport().get_texture().get_image()
			if img2 != null and not img2.is_empty():
				img2.save_png("res://docs/界面一致性/基地宿舍_相位仪页实况.png")
				print("[BUNKER-BACKPACK-CHECK] 已保存相位仪页实况截图")
	else:
		_fail("背包无 switch_to_phase_instruments_tab 方法")

	_finish()

func _collect_covers(node: Node, pt: Vector2, out: Array[String]) -> void:
	if node is Control:
		var c := node as Control
		if c.is_visible_in_tree() and c.get_global_rect().has_point(pt):
			out.append("%s(%s)" % [c.name, c.get_class()])
	for ch in node.get_children():
		_collect_covers(ch, pt, out)

func _collect_cover_controls(node: Node, pt: Vector2, out: Array[Control]) -> void:
	if node is Control:
		var c := node as Control
		if c.is_visible_in_tree() and c.get_global_rect().has_point(pt):
			out.append(c)
	for ch in node.get_children():
		_collect_cover_controls(ch, pt, out)

func _finish() -> void:
	if _fails.is_empty():
		print("[BUNKER-BACKPACK-CHECK] ALL PASS")
	else:
		print("[BUNKER-BACKPACK-CHECK] %d 项失败" % _fails.size())
	get_tree().quit(0 if _fails.is_empty() else 1)
