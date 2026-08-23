class_name PlayerMasterPowerTest
extends GdUnitTestSuite
## 玩家侧战力链路测试（mock PhaseInstrumentManager + 真实 DefaultCards + 真实 autoload）
## 验证：evaluate_player_stars 跑通、单卡量级、装卡数语义、相位仪加成进入卡战力

const MasterPlayerAssembler = preload("res://scripts/master_player_assembler.gd")
const DefaultCards = preload("res://data/default_cards.gd")
const MockPlayerPm = preload("res://tests/unit/managers/mock_player_pm.gd")


func test_single_card_power_positive() -> void:
	# 单张冷战 T-72：链路跑通 + 战力 > 0 + card_breakdown 1 张
	var card = DefaultCards.get_card_by_id("cold_t72")
	if card == null:
		print("  cold_t72 卡缺失，跳过")
		return
	var pm := MockPlayerPm.new()
	add_child(pm)  # MockPlayerPm extends Node，挂到树保证 is_instance_valid + 自动释放
	pm.set_loadouts([card])
	var ev: Dictionary = MasterPlayerAssembler.evaluate_player_stars(pm)
	var total: float = float(ev.get("total_score", -1.0))
	var bd: Array = ev.get("card_breakdown", [])
	print("  cold_t72 单卡: total=%.1f stars=%d★ breakdown=%d" % [total, int(ev.get("stars", 0)), bd.size()])
	assert_float(total).is_greater(0.0)
	assert_int(bd.size()).is_equal(1)


func test_more_cards_more_power() -> void:
	# 装卡数语义：3 张 > 1 张（求和）
	var t72 = DefaultCards.get_card_by_id("cold_t72")
	var ft17 = DefaultCards.get_card_by_id("ww1_ft17")
	if t72 == null or ft17 == null:
		print("  卡缺失，跳过")
		return
	var pm1 := MockPlayerPm.new()
	add_child(pm1)
	pm1.set_loadouts([t72])
	var ev1: Dictionary = MasterPlayerAssembler.evaluate_player_stars(pm1)
	var pm3 := MockPlayerPm.new()
	add_child(pm3)
	pm3.set_loadouts([t72, ft17, t72])
	var ev3: Dictionary = MasterPlayerAssembler.evaluate_player_stars(pm3)
	print("  1卡=%.1f  3卡=%.1f" % [float(ev1.total_score), float(ev3.total_score)])
	assert_float(float(ev3.get("total_score", 0.0))).is_greater(float(ev1.get("total_score", 0.0)))


func test_instrument_bonus_enters_card_power() -> void:
	# 相位仪加成进入卡战力：强加成（hp+50%/atk+40%）> 弱加成（0%）
	var t72 = DefaultCards.get_card_by_id("cold_t72")
	if t72 == null:
		print("  cold_t72 缺失，跳过")
		return
	var pm_weak := MockPlayerPm.new()
	add_child(pm_weak)
	pm_weak.set_loadouts([t72])
	pm_weak._phase_bonus = {"hp_pct": 0.0, "atk_pct": 0.0, "def_pct": 0.0}
	var ev_weak: Dictionary = MasterPlayerAssembler.evaluate_player_stars(pm_weak)

	var pm_strong := MockPlayerPm.new()
	add_child(pm_strong)
	pm_strong.set_loadouts([t72])
	pm_strong._phase_bonus = {"hp_pct": 0.50, "atk_pct": 0.40, "def_pct": 0.30}
	var ev_strong: Dictionary = MasterPlayerAssembler.evaluate_player_stars(pm_strong)

	print("  弱加成=%.1f  强加成=%.1f" % [float(ev_weak.total_score), float(ev_strong.total_score)])
	assert_float(float(ev_strong.get("total_score", 0.0))).is_greater(float(ev_weak.get("total_score", 0.0)))
