extends Control
## _tmp_v653_drag_probe.gd（临时探针——复现"背包战斗卡拉到相位仪绿槽装配失败"）
## 真实链：truck_base 场景 + 教程 PHASE_INSTRUMENT 态 + Input.parse_input_event 真实注入拖拽。
## 只动内存态（不调 save），跑前无需备份存档。
##
## 跑法（headless，autoload 全加载）：
##   GODOT --headless --rendering-driver opengl3 --path . res://tests/_tmp_v653_drag_probe.tscn

const TruckBaseScene := preload("res://scenes/bunker/truck_base.tscn")
const GC = preload("res://resources/game_constants.gd")

var _fails: int = 0
var _tb: Node = null


func _ready() -> void:
	await get_tree().process_frame
	await _run()
	print("=== PROBE DONE fails=%d ===" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _check(cname: String, cond: bool, detail: String = "") -> void:
	if cond:
		print("  [PASS] %s %s" % [cname, detail])
	else:
		_fails += 1
		print("  [FAIL] %s %s" % [cname, detail])


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _push_motion(pos: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	ev.global_position = pos
	Input.parse_input_event(ev)
	Input.flush_buffered_events()


func _push_button(pos: Vector2, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = pos
	ev.global_position = pos
	Input.parse_input_event(ev)
	Input.flush_buffered_events()


func _find_card_items(root: Node, out: Array) -> void:
	for child in root.get_children():
		if child is Control and "_is_dragging" in child and "card" in child:
			out.append(child)
		_find_card_items(child, out)


func _find_slots_by_color(root: Node, color: String, out: Array) -> void:
	for child in root.get_children():
		if child is Control and child.has_meta("slot_color") \
				and String(child.get_meta("slot_color")) == color:
			out.append(child)
		_find_slots_by_color(child, color, out)


func _run() -> void:
	print("=== PROBE v653 drag equip (truck_base) ===")

	# ── 0) 教程态：先于场景 add_child（探针铁律——基地 _ready 消费教程态） ──
	var tpm: Node = get_node_or_null("/root/TutorialProgressionManager")
	_check("TPM 在", tpm != null)
	if tpm != null:
		tpm.current_step = 3  # PHASE_INSTRUMENT（v6.53 实操门步）
		tpm.completed_steps = [1, 2]

	# ── 0.5) 构造"背包有战斗卡"态：真实实例 → 装绿槽 → 归还背包（走真实信号链） ──
	var pim_init: Node = get_node_or_null("/root/PhaseInstrumentManager")
	var ir: Node = get_node_or_null("/root/InstanceRegistry")
	_check("PIM/InstanceRegistry 在", pim_init != null and ir != null)
	if pim_init != null and ir != null:
		var inst: CardResource = ir.create_instance("ww1_mauser")
		_check("创建真实卡实例 ww1_mauser", inst != null)
		if inst != null:
			var eq_ok: bool = bool(pim_init.equip_card(0, inst, null))
			_check("预装绿槽0", eq_ok)
			pim_init.unequip_card(0)  # 归还背包（真实 card_added_to_backpack 链）
			await _frames(3)

	# ── 1) 真实基地场景 ──
	_tb = TruckBaseScene.instantiate()
	get_tree().root.add_child(_tb)
	await _frames(8)

	# ── 2) 模拟玩家点卡仓 ──
	if _tb.has_method("_open_panel"):
		_tb._open_panel("backpack")
		await _frames(12)  # wrapper 显示 + 布局 deferred + aux 预热错峰
	else:
		_check("truck_base._open_panel 存在", false)
		return

	var wrapper: Control = _tb._embed_wrappers["backpack"]["wrapper"]
	var panel: Control = _tb._embed_wrappers["backpack"]["panel"]
	_check("卡仓 wrapper 可见", wrapper != null and wrapper.visible)

	# ── 3) 找战斗卡格与绿槽 ──
	var items: Array = []
	_find_card_items(panel, items)
	var combat_items: Array = []
	for it in items:
		var c = it.get("card")
		if c != null and c.get("card_type") == GC.CardType.COMBAT_UNIT:
			combat_items.append(it)
	print("  卡格总数=%d 战斗卡格=%d" % [items.size(), combat_items.size()])

	var green_slots: Array = []
	_find_slots_by_color(wrapper, "green", green_slots)
	print("  绿槽控件数=%d" % green_slots.size())
	_check("绿槽控件存在", green_slots.size() > 0)
	for gs in green_slots:
		var r: Rect2 = (gs as Control).get_global_rect()
		print("    green slot @ %s size=%s visible=%s" % [r.position, r.size, (gs as Control).is_visible_in_tree()])
	_check("战斗卡格存在", combat_items.size() > 0)

	if combat_items.is_empty() or green_slots.is_empty():
		# 拉一张绿槽卡回背包再重扫（unequip 走真实归还链）
		var pim0: Node = get_node_or_null("/root/PhaseInstrumentManager")
		if pim0 != null and pim0.has_method("unequip_card"):
			var loads: Array = pim0.get_loadouts()
			if loads.size() > 0:
				var flat_g: int = int(loads[0].get("slot_index", 0))
				# green 的 flat = red+blue 计数偏移，直接查 green 数组第一个非空
				var green_arr: Array = pim0.instrument_slots.get("green", [])
				var gi: int = -1
				for i in range(green_arr.size()):
					if green_arr[i] != null:
						gi = i
						break
				if gi >= 0:
					var cfg: Dictionary = pim0.get_current_instrument()
					var sc: Dictionary = cfg.get("slot_counts", {})
					var flat: int = int(sc.get("red", 0)) + int(sc.get("blue", 0)) + gi
					print("  背包无战斗卡：unequip green[%d] flat=%d 归还背包" % [gi, flat])
					pim0.unequip_card(flat)
					await _frames(10)
					items.clear(); combat_items.clear()
					_find_card_items(panel, items)
					for it in items:
						var c2 = it.get("card")
						if c2 != null and c2.get("card_type") == GC.CardType.COMBAT_UNIT:
							combat_items.append(it)
					print("  归还后战斗卡格=%d" % combat_items.size())
		if combat_items.is_empty():
			_check("有可拖拽战斗卡", false, "背包与绿槽均无战斗卡")
			return

	var card_item: Control = combat_items[0]
	var card_rect: Rect2 = card_item.get_global_rect()
	var card_center: Vector2 = card_rect.get_center()
	var slot_ctl: Control = green_slots[0]
	var slot_rect: Rect2 = slot_ctl.get_global_rect()
	var slot_center: Vector2 = slot_rect.get_center()
	print("  拖拽卡=%s @ %s" % [card_item.get("card").display_name, card_center])
	print("  目标绿槽 @ %s" % slot_center)

	# ── 4) 坐标系自校准：解 注入坐标→画布读回 的仿射（headless 窗口≠画布尺寸） ──
	_push_motion(Vector2(100, 100)); await _frames(2)
	var m0: Vector2 = card_item.get_global_mouse_position()
	_push_motion(Vector2(300, 300)); await _frames(2)
	var m1: Vector2 = card_item.get_global_mouse_position()
	var sx: float = (m1.x - m0.x) / 200.0
	var sy: float = (m1.y - m0.y) / 200.0
	var b_off: Vector2 = m0 - Vector2(sx * 100.0, sy * 100.0)
	print("  校准 scale=(%.4f, %.4f) offset=%s" % [sx, sy, b_off])
	_check("坐标标定有效", absf(sx) > 0.0001 and absf(sy) > 0.0001)
	var to_inject := func(canvas_pos: Vector2) -> Vector2:
		return Vector2((canvas_pos.x - b_off.x) / sx, (canvas_pos.y - b_off.y) / sy)

	# ── 5) 真实拖拽序列：按下 → 移出阈值 → 移到绿槽 → 松手 ──
	var pim: Node = get_node_or_null("/root/PhaseInstrumentManager")
	var tpm2: Node = get_node_or_null("/root/TutorialProgressionManager")
	var touched_before: bool = bool(tpm2.get("_assembly_touched")) if tpm2 != null else false

	_push_motion(to_inject.call(card_center)); await _frames(2)
	_push_button(to_inject.call(card_center), true); await _frames(2)

	# 检查事件是否到达卡格（gui_input 路由）
	var dragging_started: bool = bool(card_item.get("_is_dragging"))
	_check("按下+首段移动后 start_drag 触发", dragging_started)

	# 分段移动到绿槽（每段 <400px，模拟真实手速）
	var steps: int = 8
	for i in range(1, steps + 1):
		var p := card_center.lerp(slot_center, float(i) / float(steps))
		_push_motion(to_inject.call(p))
		await _frames(1)

	_check("拖拽中 _is_dragging=true", bool(card_item.get("_is_dragging")))
	var cached: Array = card_item.get("_cached_slot_controls")
	print("  _cached_slot_controls=%d" % cached.size())
	_check("拖拽缓存含槽位", cached.size() > 0)

	_push_button(to_inject.call(slot_center), false)
	await _frames(3)

	# ── 6) 断言结果 ──
	var touched_after: bool = bool(tpm2.get("_assembly_touched")) if tpm2 != null else false
	_check("TPM._assembly_touched 置位", touched_after and not touched_before == false or touched_after,
		"before=%s after=%s" % [touched_before, touched_after])
	var loads2: Array = pim.get_loadouts() if pim != null else []
	print("  装配后 loadouts=%d" % loads2.size())
	var green_arr2: Array = pim.instrument_slots.get("green", []) if pim != null else []
	var filled: int = 0
	for g in green_arr2:
		if g != null:
			filled += 1
	print("  绿槽占用=%d/%d" % [filled, green_arr2.size()])
	_check("绿槽仍有卡（拖回成功或未被误清）", filled > 0)

	# 拖拽残留检查（预览节点泄漏）
	var leaked: bool = card_item.get("_drag_preview") != null
	_check("无拖拽预览泄漏", not leaked)
