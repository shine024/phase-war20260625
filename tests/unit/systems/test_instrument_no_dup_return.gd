extends GdUnitTestSuite
## v6.36 换装防重装备回归锁：卡退回背包"变两张"三闸
## 用户主诉（2026-10-02）：装配/换相位仪时，有的卡退回背包有时变成 2 张。
## 根因链（实机探针 tests/_tmp_swap_dup_probe.tscn 复现）：
##   ① equip_card 对"槽上已是这张卡"的重装不设防 → card_swapped(旧卡=自己)
##      → presenter 把槽上卡加回背包（槽+背包双份）；
##   ② 同实例可装进第二个槽（双持）→ unequip_all 逐槽归还 → 背包两张；
##   ③ add_extra_card 对同 instance_id 无去重（两行同 id 解析为同一实例对象）。
## 修复三闸：equip_card 同槽幂等零信号 + 跨槽移动语义；unequip_all 按实例去重；
## BackpackData.add_extra_card 同 id 去重（读档 append/restore 路径保留重复不动）。

const PIM = preload("res://managers/phase_instrument_manager.gd")
const BackpackDataScript = preload("res://scenes/ui/backpack/backpack_data.gd")
const GC = preload("res://resources/game_constants.gd")

var _pim: Node = null
var _sig_added := 0
var _sig_swapped := 0
var _sig_equipped := 0


func before_test() -> void:
	_pim = auto_free(PIM.new())
	# 挂进树内：equip_card 里的 get_node_or_null("/root/DebugLogManager") 需要
	# 树内上下文（树外实例会刷引擎报错噪音）；_ready 会先重建默认槽位，
	# 下方再覆盖为本锁需要的 3 绿槽矩阵。
	if get_tree() != null and get_tree().root != null:
		get_tree().root.add_child(_pim)
	_pim.selected_instrument_id = "pi_generic_01"
	_pim.instrument_slots = {
		"red": [], "blue": [],
		"green": [null, null, null],
		"yellow": [], "rune": [],
	}
	_sig_added = 0
	_sig_swapped = 0
	_sig_equipped = 0
	if SignalBus.card_added_to_backpack.is_connected(_on_sig_added):
		SignalBus.card_added_to_backpack.disconnect(_on_sig_added)
	if SignalBus.card_swapped.is_connected(_on_sig_swapped):
		SignalBus.card_swapped.disconnect(_on_sig_swapped)
	if SignalBus.card_equipped.is_connected(_on_sig_equipped):
		SignalBus.card_equipped.disconnect(_on_sig_equipped)
	SignalBus.card_added_to_backpack.connect(_on_sig_added)
	SignalBus.card_swapped.connect(_on_sig_swapped)
	SignalBus.card_equipped.connect(_on_sig_equipped)


func after_test() -> void:
	if SignalBus.card_added_to_backpack.is_connected(_on_sig_added):
		SignalBus.card_added_to_backpack.disconnect(_on_sig_added)
	if SignalBus.card_swapped.is_connected(_on_sig_swapped):
		SignalBus.card_swapped.disconnect(_on_sig_swapped)
	if SignalBus.card_equipped.is_connected(_on_sig_equipped):
		SignalBus.card_equipped.disconnect(_on_sig_equipped)


func _on_sig_added(_c) -> void:
	_sig_added += 1


func _on_sig_swapped(_i, _o, _n) -> void:
	_sig_swapped += 1


func _on_sig_equipped(_i, _id, _t) -> void:
	_sig_equipped += 1


func _mk_card(card_id: String, iid: String) -> CardResource:
	var c: CardResource = auto_free(CardResource.new())
	c.card_id = card_id
	c.instance_id = iid
	c.card_type = GC.CardType.COMBAT_UNIT
	return c


func test_swap_to_self_is_idempotent_and_silent() -> void:
	# 闸①：同槽重装同一实例 → 幂等成功、零信号、槽位与背包记账不动
	var c := _mk_card("ww1_mauser", "ww1_mauser#1")
	_pim.instrument_slots["green"][0] = c
	var ok: bool = bool(_pim.equip_card(0, c))
	assert_bool(ok).override_failure_message("同槽重装应返回成功（幂等语义）").is_true()
	assert_int(_sig_added).override_failure_message("同槽重装不得发 card_added_to_backpack").is_equal(0)
	assert_int(_sig_swapped).override_failure_message("同槽重装不得发 card_swapped（旧卡=自己会把槽上卡加回背包）").is_equal(0)
	assert_int(_sig_equipped).override_failure_message("同槽重装不得发 card_equipped").is_equal(0)
	assert_object(_pim.instrument_slots["green"][0] as CardResource).is_same(c)


func test_reequip_same_card_to_other_slot_moves_not_duplicates() -> void:
	# 闸②：同实例已在其槽 → 移动语义：源槽静默清空、目标槽持有、不发生归还信号
	var c := _mk_card("ww1_vickers", "ww1_vickers#1")
	_pim.instrument_slots["green"][0] = c
	var ok: bool = bool(_pim.equip_card(1, c))
	assert_bool(ok).override_failure_message("跨槽重装应成功（移动语义）").is_true()
	assert_object(_pim.instrument_slots["green"][1] as CardResource).is_same(c)
	assert_object(_pim.instrument_slots["green"][0] as CardResource).is_null()
	assert_int(_sig_added).override_failure_message("移动语义不还卡：不得发 card_added_to_backpack").is_equal(0)
	assert_int(_sig_swapped).override_failure_message("移动语义不得发 card_swapped").is_equal(0)


func test_unequip_all_returns_legacy_dual_slot_instance_once() -> void:
	# 闸②兜底：历史损坏态（同实例双槽，旧档 set_slots_from_card_ids 可恢复出）→
	# 换位仪归还链对同一实例只发一次 card_added_to_backpack
	var c := _mk_card("ww1_enfield", "ww1_enfield#1")
	var d := _mk_card("ww1_mauser", "ww1_mauser#2")
	_pim.instrument_slots["green"][0] = c
	_pim.instrument_slots["green"][1] = c
	_pim.instrument_slots["green"][2] = d
	_pim.unequip_all_and_return_to_backpack()
	assert_int(_sig_added).override_failure_message(
		"双持实例换位仪后应只归还一次（否则背包两张）").is_equal(2)
	assert_object(_pim.instrument_slots["green"][0] as CardResource).is_null()
	assert_object(_pim.instrument_slots["green"][1] as CardResource).is_null()
	assert_object(_pim.instrument_slots["green"][2] as CardResource).is_null()


func test_normal_swap_atomic_signals_intact() -> void:
	# 回归护栏：正常换装（不同卡）仍发一次 card_swapped 携带旧卡，不误伤
	var old_c := _mk_card("ww1_mauser", "ww1_mauser#1")
	var new_c := _mk_card("ww1_vickers", "ww1_vickers#1")
	_pim.instrument_slots["green"][0] = old_c
	var ok: bool = bool(_pim.equip_card(0, new_c))
	assert_bool(ok).is_true()
	assert_int(_sig_swapped).override_failure_message("正常换装应恰好发一次 card_swapped").is_equal(1)
	assert_int(_sig_added).is_equal(0)
	assert_object(_pim.instrument_slots["green"][0] as CardResource).is_same(new_c)


func test_backpack_add_extra_card_dedupes_same_instance_id() -> void:
	# 闸③：signal 入包链对同一 instance_id 去重（两行同 id=同一实例对象=玩家见"两张"）
	var data: RefCounted = auto_free(BackpackDataScript.new())
	data.add_extra_card("ww1_mauser#1")
	data.add_extra_card("ww1_mauser#1")
	assert_int(data.get_extra_card_ids().size()).override_failure_message(
		"add_extra_card 同 id 二次入包应去重").is_equal(1)


func test_backpack_append_preserves_duplicates_for_save_compat() -> void:
	# 读档路径（append/restore）保留重复条目——旧档兼容口径不被本批去重误伤
	var data: RefCounted = auto_free(BackpackDataScript.new())
	data.append_extra_cards(["ww1_mauser#1", "ww1_mauser#1"], true)
	assert_int(data.get_extra_card_ids().size()).override_failure_message(
		"append_extra_cards（读档路径）应保留重复条目").is_equal(2)
	data.restore_extra_cards(["a#1", "a#1", "b#1"])
	assert_int(data.get_extra_card_ids().size()).is_equal(3)
