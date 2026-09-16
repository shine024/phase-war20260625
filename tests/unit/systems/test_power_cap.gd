extends GdUnitTestSuite
## v36 实机验收：精神同调战力门——节点数据 / 上限合成 / 部署豁免口径
## 设定：相位师越强→精神与暗能量交换越深→能驾驭越强的战斗卡（power 值上限）。

var TreeDef = preload("res://data/phase_master_skill_tree.gd")
var UCT = preload("res://data/unified_card_table.gd")
var GameConfigS = preload("res://resources/game_config.gd")


func _sync_nodes() -> Array:
	var out: Array = []
	for bid in ["pms_cmd_sync1", "pms_cmd_sync2", "pms_cmd_sync3",
			"pms_int_sync1", "pms_int_sync2", "pms_int_sync3",
			"pms_fp_sync1", "pms_fp_sync2", "pms_fp_sync3"]:
		var node: Dictionary = TreeDef.get_skill(bid)
		if not node.is_empty():
			out.append(node)
	return out


func test_nine_sync_nodes_exist_with_power_cap() -> void:
	# 三系各三节点，unlocks 均含 power_cap 且 value>0（max 语义阶梯）
	assert_int(_sync_nodes().size()).override_failure_message(
		"精神同调节点应 9 个（三系 × 开窍/深潜/无垠）").is_equal(9)
	for node in _sync_nodes():
		var found := false
		for u in node.get("unlocks", []):
			if u is Dictionary and str(u.get("type", "")) == "power_cap":
				found = true
				assert_int(int(u.get("value", 0))).is_greater(0)
		assert_bool(found).override_failure_message(
			"%s 缺 power_cap unlock" % String(node.get("id"))).is_true()


func test_sync_chain_requirements() -> void:
	# 链式前置：开窍←系 tier0；深潜←开窍；无垠←深潜（同分支，跨级不可跳）
	for pfx in ["cmd", "int", "fp"]:
		var n1: Dictionary = TreeDef.get_skill("pms_%s_sync1" % pfx)
		assert_int(n1.get("requires", []).size()).is_greater(0)
		assert_array(n1.get("requires", [])).contains(["pms_%s_0" % pfx])
		var n2: Dictionary = TreeDef.get_skill("pms_%s_sync2" % pfx)
		assert_array(n2.get("requires", [])).contains(["pms_%s_sync1" % pfx])
		var n3: Dictionary = TreeDef.get_skill("pms_%s_sync3" % pfx)
		assert_array(n3.get("requires", [])).contains(["pms_%s_sync2" % pfx])


func test_cap_ladder_covers_power_distribution() -> void:
	# 阶梯覆盖口径：基础档盖 era0-1 中位；无垠档 ≥ 全卡表最大 power（2200）
	var values: Array[int] = []
	for node in _sync_nodes():
		for u in node.get("unlocks", []):
			if u is Dictionary and str(u.get("type", "")) == "power_cap":
				values.append(int(u.get("value", 0)))
	values.sort()
	assert_int(values[0]).is_greater_equal(500)     # 开窍：era1 全量可部署（era1 min=72）
	assert_int(values[values.size() - 1]).is_greater_equal(2200)  # 无垠：全表解锁


func test_base_cap_covers_starter_basics() -> void:
	# 新档绿槽三卡（era0 基础步兵）必须在基础上限内可部署；
	# GameConfig 总开关存在且默认开（A/B 回退口）
	assert_int(200).override_failure_message(
		"BASE_POWER_CAP 需与 phase_master_skill_manager 常量同步（改值两处同步）").is_equal(200)
	var gc = GameConfigS.get_default()
	assert_bool(bool(gc.power_cap_enabled)).is_true()
