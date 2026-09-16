extends GdUnitTestSuite
## v32.0 B2-1 阵容预设单测：懒填 5 槽、绿槽快照、load_state 复位不变式（{}）、
## 惰性键往返、越界/空预设防御。应用链（equip/InstanceRegistry 解析）依赖完整
## autoload 环境，不在单测覆盖（走实机验收）。

const PIM = preload("res://managers/phase_instrument_manager.gd")
const GC = preload("res://resources/game_constants.gd")

var _pim: Node = null


func before_test() -> void:
	_pim = auto_free(PIM.new())


func _mk_card(card_id: String, iid: String) -> CardResource:
	var c: CardResource = auto_free(CardResource.new())
	c.card_id = card_id
	c.instance_id = iid
	c.card_type = GC.CardType.COMBAT_UNIT
	return c


func test_lazy_fill_five_slots() -> void:
	assert_int(_pim.get_loadout_presets().size()).is_equal(5)
	for p in _pim.get_loadout_presets():
		assert_array(p).is_empty()


func test_save_snapshot_green_combat_cards_only() -> void:
	_pim.instrument_slots["green"] = [
		_mk_card("ww1_mauser", "ww1_mauser#1"),
		null,
		_mk_card("cold_t72", "cold_t72#2"),
	]
	assert_int(_pim.save_loadout_preset(0)).is_equal(2)
	var preset: Array = _pim.get_loadout_presets()[0]
	assert_int(preset.size()).is_equal(2)
	assert_int(int(preset[0]["slot_index"])).is_equal(0)
	assert_str(preset[0]["instance_id"]).is_equal("ww1_mauser#1")
	assert_str(_pim.get_loadout_preset_summary(0)).contains("毛瑟")


func test_save_empty_green_returns_zero_and_stays_empty() -> void:
	_pim.instrument_slots["green"] = []
	assert_int(_pim.save_loadout_preset(2)).is_equal(0)
	assert_array(_pim.get_loadout_presets()[2]).is_empty()
	assert_int(_pim.apply_loadout_preset(2)).is_equal(-1)


func test_load_state_empty_resets_presets() -> void:
	# 不变式①：load_state({}) 必须复位为空预设
	_pim.instrument_slots["green"] = [_mk_card("ww1_mauser", "ww1_mauser#1")]
	_pim.save_loadout_preset(0)
	_pim.load_state({})
	assert_array(_pim.get_loadout_presets()[0]).is_empty()


func test_load_state_roundtrip_lazy_key() -> void:
	var snap: Array = [{"slot_index": 1, "card_id": "cold_t72", "instance_id": "cold_t72#9"}]
	_pim.load_state({"loadout_presets": [snap]})
	var presets: Array = _pim.get_loadout_presets()
	assert_int(presets.size()).is_equal(5)
	assert_int(presets[0].size()).is_equal(1)
	assert_str(presets[0][0]["instance_id"]).is_equal("cold_t72#9")
	# 缺档自动懒填
	assert_array(presets[4]).is_empty()


func test_out_of_range_defense() -> void:
	assert_int(_pim.save_loadout_preset(-1)).is_equal(-1)
	assert_int(_pim.save_loadout_preset(99)).is_equal(-1)
	assert_int(_pim.apply_loadout_preset(-1)).is_equal(-1)
	assert_str(_pim.get_loadout_preset_summary(99)).is_empty()
