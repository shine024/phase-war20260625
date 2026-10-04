extends Node
## 探针：换相位仪/装配时"卡退回背包变成2张"——真实链路复现（验证纪律：真实运行才得结论）
## v6.36 修复后复跑：期望全部 PASS。
## 运行：godot --path . res://tests/_tmp_swap_dup_probe.tscn
## 只做内存操作，不触发存档写盘；结束时打印 PROBE_DONE 并退出。

var fails: Array[String] = []
var notes: Array[String] = []
var panel: Node
var pim: Node
var ir: Node
var sm: Node
# 信号计数器
var sig_added := 0
var sig_swapped := 0
var sig_equipped := 0

func _ready() -> void:
	await get_tree().process_frame
	pim = get_node_or_null("/root/PhaseInstrumentManager")
	ir = get_node_or_null("/root/InstanceRegistry")
	sm = get_node_or_null("/root/SaveManager")
	if pim == null or ir == null or sm == null:
		print("PROBE_DONE fails=1 (autoload missing)")
		get_tree().quit(1)
		return
	pim.clear_slots_for_new_game()
	SignalBus.card_added_to_backpack.connect(_on_sig_added)
	SignalBus.card_swapped.connect(_on_sig_swapped)
	SignalBus.card_equipped.connect(_on_sig_equipped)
	var scene: PackedScene = load("res://scenes/ui/backpack_panel.tscn")
	panel = scene.instantiate()
	add_child(panel)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await _run_all()
	print("PROBE_DONE fails=%d" % fails.size())
	for f in fails:
		print("FAIL: " + f)
	for n in notes:
		print("NOTE: " + n)
	get_tree().quit(1 if fails.size() > 0 else 0)

func _on_sig_added(_c) -> void: sig_added += 1
func _on_sig_swapped(_i, _o, _n) -> void: sig_swapped += 1
func _on_sig_equipped(_i, _id, _t) -> void: sig_equipped += 1

func _ids() -> Array:
	return panel.get_extra_card_ids()

func _count_of(ids: Array, id: String) -> int:
	var c := 0
	for x in ids:
		if str(x) == id:
			c += 1
	return c

func _green_flat(i: int) -> int:
	var cfg: Dictionary = pim.get_current_instrument()
	var counts: Dictionary = cfg.get("slot_counts", {})
	return int(counts.get("red", 0)) + int(counts.get("blue", 0)) + i

func _mk(card_id: String) -> CardResource:
	return ir.create_instance(card_id)

func _give(card: CardResource) -> void:
	SignalBus.card_added_to_backpack.emit(card)

func _check(cond: bool, msg: String) -> void:
	if not cond:
		fails.append(msg)

func _run_all() -> void:
	var a := _mk("ww1_mauser")
	var b := _mk("ww1_enfield")
	var c := _mk("ww1_vickers")
	var aid: String = a.instance_id
	var bid: String = b.instance_id
	var cid: String = c.instance_id

	# T1 装配（空槽）→ 卡离包
	_give(a)
	await get_tree().process_frame
	_check(_ids() == [aid], "T1 前置：入包后 _data 应=[a]，实际=%s" % str(_ids()))
	var ok1: bool = pim.equip_card(_green_flat(0), a)
	await get_tree().process_frame
	_check(ok1, "T1 装备 a 到绿槽0 失败")
	_check(_ids().is_empty(), "T1 装备后 _data 应为空，实际=%s" % str(_ids()))

	# T2 卸下 → 卡回包恰好 1 张
	pim.unequip_card(_green_flat(0))
	await get_tree().process_frame
	_check(_count_of(_ids(), aid) == 1, "T2 卸下后 a 应恰好 1 张，实际=%s" % str(_ids()))

	# T3 换装（拖 b 到 a 占用的槽）→ a 回包 1 张、b 离包
	_give(b)
	await get_tree().process_frame
	var ok3: bool = pim.equip_card(_green_flat(0), b)
	await get_tree().process_frame
	_check(ok3, "T3 换装失败")
	_check(_count_of(_ids(), aid) == 1 and _count_of(_ids(), bid) == 0,
		"T3 换装后应为 [a]×1 无 b，实际=%s" % str(_ids()))

	# T4 换相位仪（equip_instrument 原地切换）→ 槽上卡全回包各 1 张
	_give(c)
	await get_tree().process_frame
	pim.equip_card(_green_flat(1), c)
	await get_tree().process_frame
	_check(_count_of(_ids(), cid) == 0, "T4 前置：c 装备后应离包，实际=%s" % str(_ids()))
	pim.equip_instrument(pim.selected_instrument_id)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(_count_of(_ids(), bid) == 1, "T4 换仪后 b 应 1 张，实际=%s" % str(_ids()))
	_check(_count_of(_ids(), cid) == 1, "T4 换仪后 c 应 1 张，实际=%s" % str(_ids()))
	_check(_count_of(_ids(), aid) == 1, "T4 换仪后 a 应仍 1 张，实际=%s" % str(_ids()))

	# T5 同卡重装同一槽（闸①）：应幂等成功、零信号、背包不动
	var ok5: bool = pim.equip_card(_green_flat(0), b)
	await get_tree().process_frame
	_check(ok5, "T5 前置：装备 b 到绿0 失败")
	_check(_count_of(_ids(), bid) == 0, "T5 前置：b 应离包，实际=%s" % str(_ids()))
	var sig0 := [sig_added, sig_swapped, sig_equipped]
	var ids_before: int = _ids().size()
	var ok5b: bool = pim.equip_card(_green_flat(0), b)  # 绿0 已是 b
	await get_tree().process_frame
	notes.append("T5 swap-to-self: ok=%s ids %d→%d, 信号 added/swapped/equipped %d/%d/%d→%d/%d/%d" % [
		str(ok5b), ids_before, _ids().size(), sig0[0], sig0[1], sig0[2], sig_added, sig_swapped, sig_equipped])
	_check(ok5b, "T5 同卡重装应返回成功（幂等）")
	_check(_ids().size() == ids_before, "T5 同卡重装后背包数量不得变化，实际=%s" % str(_ids()))
	_check(sig_added == sig0[0] and sig_swapped == sig0[1] and sig_equipped == sig0[2],
		"T5 同卡重装不得发出任何装备/入包信号")
	_check(String(pim.get_slot_card_ids()[_green_flat(0)]) == bid, "T5 绿槽0 应仍是 b")

	# T6 同卡装到另一槽（闸②移动语义）：源槽清空、目标槽持有、背包不动
	var ok6: bool = pim.equip_card(_green_flat(1), b)  # 绿0 已是 b，装绿1
	await get_tree().process_frame
	var sids: Array = pim.get_slot_card_ids()
	notes.append("T6 移动语义: 绿0=%s 绿1=%s _data=%s" % [str(sids[_green_flat(0)]), str(sids[_green_flat(1)]), str(_ids())])
	_check(ok6, "T6 移动装备应成功")
	_check(String(sids[_green_flat(0)]).is_empty(), "T6 源槽绿0 应被静默清空")
	_check(String(sids[_green_flat(1)]) == bid, "T6 目标槽绿1 应持有 b")
	_check(_count_of(_ids(), bid) == 0, "T6 移动后背包不得出现 b，实际=%s" % str(_ids()))

	# T7 旧档双持兜底：直接构造同实例双槽（历史损坏态），换位仪后各卡只回包 1 张
	pim.equip_card(_green_flat(0), c)  # c → 绿0（移动语义：_data=[a]）
	await get_tree().process_frame
	# 直写槽位构造旧档双持：绿0/绿1 都是 c，b 放绿2（1星仪器 3 绿槽）
	var green_arr: Array = pim.instrument_slots.get("green", [])
	green_arr[0] = c
	green_arr[1] = c
	green_arr[2] = b
	pim.instrument_slots["green"] = green_arr
	pim.equip_instrument(pim.selected_instrument_id)
	await get_tree().process_frame
	await get_tree().process_frame
	notes.append("T7 双持兜底换仪后 _data=%s" % str(_ids()))
	_check(_count_of(_ids(), cid) == 1, "T7 双持换仪后 c 应恰好 1 张，实际=%s" % str(_ids()))
	_check(_count_of(_ids(), bid) == 1, "T7 双持换仪后 b 应仍 1 张，实际=%s" % str(_ids()))
	_check(_count_of(_ids(), aid) == 1, "T7 双持换仪后 a 应仍 1 张，实际=%s" % str(_ids()))

	# T8 BackpackData.add_extra_card 同实例去重 + 读档 append 保留重复
	var data_obj = panel._data
	var n0: int = data_obj.get_extra_card_ids().size()
	data_obj.add_extra_card("dup_probe#1", true)
	data_obj.add_extra_card("dup_probe#1", true)  # 第二次应被去重
	var n1: int = data_obj.get_extra_card_ids().size()
	notes.append("T8 add_extra_card 去重: %d→%d（期望 +1）" % [n0, n1])
	_check(n1 == n0 + 1, "T8 同 id 二次 add_extra_card 应去重，实际 %d→%d" % [n0, n1])
	data_obj.append_extra_cards(["legacy_dup#9", "legacy_dup#9"], true)  # 读档路径保留重复
	var n2: int = data_obj.get_extra_card_ids().size()
	_check(n2 == n1 + 2, "T9 append_extra_cards 读档路径应保留重复条目，实际 %d→%d" % [n1, n2])

	notes.append("SaveManager pending=%s last_known=%s" % [
		str(sm.get_pending_backpack_ids()), str(sm.get_last_known_backpack_ids())])
