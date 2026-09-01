extends Node
## 基地宿舍打开背包 → 相位仪可见性/装备链路实测（渲染模式跑，存截图）
## 复现用户路径：宿舍房间面板 → 打开背包（通用 id，不切 Tab）

const GC = preload("res://resources/game_constants.gd")

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
		# v2: 全出血水平断言（2026-08-31 修复：点锚定定宽 → min 宽超定宽后整条右移出屏）
		if absf(br.position.x - 16.0) > 3.0 or absf(br.end.x - 1264.0) > 3.0:
			_fail("相位仪栏未全出血水平铺满（x=%d..%d 应≈16..1264）" % [
				int(br.position.x), int(br.end.x)])
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

	# ── 拖拽装备链路（基地）：卡项按 instrument_bar_host 分组发现内嵌相位仪栏 →
	#    缓存槽位 → 绿槽扁平索引 → 实装一张卡（2026-08-31 修复：基地无 /root/Main
	#    宿主，槽位缓存恒空 → 拖卡静默失败）──
	var card_item: PanelContainer = _find_backpack_card_item(bp)
	if card_item == null:
		card_item = _find_backpack_card_item(bunker)
	var synthetic := false
	if card_item == null:
		# 测试档散卡可能全部在装（背包战斗卡列表为空）——现造一个卡项走同一条链路
		var item_scene: PackedScene = load("res://scenes/ui/backpack_card_item.tscn")
		var src: CardResource = _pick_any_combat_card()
		if item_scene != null and src != null:
			card_item = item_scene.instantiate() as PanelContainer
			card_item.card = src
			wrapper.add_child(card_item)
			synthetic = true
			print("[BUNKER-BACKPACK-CHECK] 背包无散卡，已现造卡项走拖拽链路（card=%s）" % str(src.card_id))
	if card_item == null:
		var ir_probe: Node = get_node_or_null("/root/InstanceRegistry")
		var ir_n: int = ir_probe.get_all_instance_ids().size() if (ir_probe != null and ir_probe.has_method("get_all_instance_ids")) else -1
		var pim_slots: Array = PhaseInstrumentManager.get_slots()
		var occupied := 0
		for c in pim_slots:
			if c != null:
				occupied += 1
		_fail("背包树里没找到卡项且现造失败（拖拽装备链路未验证）IR实例=%d PIM槽=%d/占用%d" % [
			ir_n, pim_slots.size(), occupied])
	else:
		BackpackCardItemDrag.cache_slot_controls_for_drag(card_item)
		var cached: Array = card_item._cached_slot_controls
		print("[BUNKER-BACKPACK-CHECK] 拖拽槽位缓存数=%d" % cached.size())
		if cached.is_empty():
			_fail("拖拽槽位缓存为空（内嵌相位仪栏未被拖拽系统发现，拖卡必失败）")
		else:
			var first_green: Control = null
			for s in cached:
				if s is Control and String(s.get_meta("slot_color", "")) == "green":
					first_green = s
					break
			if first_green == null:
				_fail("缓存槽位里没有绿槽")
			else:
				var flat: int = BackpackCardItemDrag.calculate_flat_index(card_item,
					"green", int(first_green.get_meta("slot_index", -1)))
				var slots: Array = PhaseInstrumentManager.get_slots()
				if flat < 0 or flat >= slots.size():
					_fail("绿槽扁平索引非法 flat=%d（槽总数=%d）" % [flat, slots.size()])
				elif slots[flat] != null:
					print("[BUNKER-BACKPACK-CHECK] 首绿槽已占用，跳过实装断言（缓存+索引已验）")
				elif card_item.card == null:
					print("[BUNKER-BACKPACK-CHECK] 卡项无 card 数据，跳过实装断言（缓存+索引已验）")
				else:
					var ok_eq: bool = bool(PhaseInstrumentManager.equip_card(flat, card_item.card, null))
					if not ok_eq:
						_fail("按缓存槽位装备失败 flat=%d card=%s" % [flat, str(card_item.card.card_id)])
					else:
						print("[BUNKER-BACKPACK-CHECK] 拖拽路径装备成功 flat=%d card=%s" % [
							flat, str(card_item.card.card_id)])
		if synthetic and card_item != null and is_instance_valid(card_item):
			card_item.queue_free()

	_finish()

func _find_backpack_card_item(root: Node) -> PanelContainer:
	if root is PanelContainer:
		var sc: Script = root.get_script()
		if sc != null and sc.resource_path.ends_with("backpack_card_item.gd"):
			return root
	for ch in root.get_children():
		var found := _find_backpack_card_item(ch)
		if found != null:
			return found
	return null

## 取一张战斗卡供拖拽链路实测：优先当前相位仪已装备的战斗卡，其次实例注册表
## 任意战斗卡实例，空存档兜底现造一张初始卡实例（仅运行时注册，不落存档）
func _pick_any_combat_card() -> CardResource:
	var slots: Array = PhaseInstrumentManager.get_slots()
	for c in slots:
		if c is CardResource and c.card_type == GC.CardType.COMBAT_UNIT:
			return c
	var ir: Node = get_node_or_null("/root/InstanceRegistry")
	if ir != null and ir.has_method("get_all_instance_ids"):
		for iid in ir.get_all_instance_ids():
			var inst: CardResource = ir.get_instance(String(iid))
			if inst != null and inst.card_type == GC.CardType.COMBAT_UNIT:
				return inst
		if ir.has_method("create_instance"):
			return ir.create_instance("ww1_mauser") as CardResource
	return null

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
