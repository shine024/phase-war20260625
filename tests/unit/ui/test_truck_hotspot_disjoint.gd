class_name TruckHotspotDisjointTest
extends GdUnitTestSuite
## v6.21 M 条回归锁：五时代任意两热区命中矩形求交为空。
## 用户实机主诉：era1 卡仓×改造交叠≈86px（点卡仓出改造面板）；同病 era3/4/5
## 另有三处（改造×打印机等）。只调矩形不改美术，此测试防回弹。

const TRUCK_BASE := preload("res://scenes/bunker/truck_base.gd")


func _rect_of(r: Array) -> Rect2:
	return Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))


func test_all_eras_hotspots_pairwise_disjoint() -> void:
	assert_that(TRUCK_BASE.HOTSPOTS.size()).is_equal(5)
	for era: String in TRUCK_BASE.HOTSPOTS.keys():
		var spots: Array = TRUCK_BASE.HOTSPOTS[era]
		for i in spots.size():
			for j in range(i + 1, spots.size()):
				var ra := _rect_of(spots[i]["r"])
				var rb := _rect_of(spots[j]["r"])
				var inter := ra.intersection(rb)
				assert_bool(inter.size.x <= 0.0 or inter.size.y <= 0.0) \
					.override_failure_message(
						"%s 热区「%s」×「%s」交叠 %s" % [era, spots[i]["name"], spots[j]["name"], inter]) \
					.is_true()


func test_era1_backpack_modification_gap() -> void:
	# 主诉条定向断言：卡仓右缘与改造左缘之间留可视缝（≥0.3% 画面宽 ≈ 4px@1280）
	var backpack: Dictionary = {}
	var modification: Dictionary = {}
	for s: Dictionary in TRUCK_BASE.HOTSPOTS["era1"]:
		if s.get("key", "") == "backpack":
			backpack = s
		elif s.get("key", "") == "modification":
			modification = s
	assert_that(backpack).is_not_null()
	assert_that(modification).is_not_null()
	var bp := _rect_of(backpack["r"])
	var mo := _rect_of(modification["r"])
	assert_float(mo.position.x - bp.end.x).is_greater_equal(0.003)
	# 改造右缘不撞 3D 打印机（制造）左缘
	var evo: Dictionary = {}
	for s: Dictionary in TRUCK_BASE.HOTSPOTS["era1"]:
		if s.get("key", "") == "evolution":
			evo = s
	if not evo.is_empty():
		assert_float(_rect_of(evo["r"]).position.x - mo.end.x).is_greater_equal(0.0)
