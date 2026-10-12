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
	# 三系各三节点，unlocks 均含 power_cap：开窍/深潜 value>0（max 语义阶梯），
	# 无垠 value<0 = 无上限哨兵（记录3#3，原 2400 封顶被用户主诉否决）
	assert_int(_sync_nodes().size()).override_failure_message(
		"精神同调节点应 9 个（三系 × 开窍/深潜/无垠）").is_equal(9)
	for node in _sync_nodes():
		var found := false
		var nid := String(node.get("id", ""))
		for u in node.get("unlocks", []):
			if u is Dictionary and str(u.get("type", "")) == "power_cap":
				found = true
				if nid.ends_with("sync3"):
					# 无垠哨兵 value<0——gdunit IntAssert 无 is_lower，比较 API 是 is_less
					assert_int(int(u.get("value", 0))).is_less(0)
				else:
					assert_int(int(u.get("value", 0))).is_greater(0)
		assert_bool(found).override_failure_message(
			"%s 缺 power_cap unlock" % nid).is_true()


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
	# 阶梯覆盖口径：开窍盖 era0-1 中位（≥500）；深潜 ≥1200；
	# 无垠=无上限哨兵（<0，记录3#3）——任何战力卡可部署，含全表 max=2200 与无垠 2400
	var sync1_min := 999999999
	var sync2_min := 999999999
	var sync3_unlimited := true
	for node in _sync_nodes():
		var nid := String(node.get("id", ""))
		for u in node.get("unlocks", []):
			if u is Dictionary and str(u.get("type", "")) == "power_cap":
				var v := int(u.get("value", 0))
				if nid.ends_with("sync1"):
					sync1_min = mini(sync1_min, v)
				elif nid.ends_with("sync2"):
					sync2_min = mini(sync2_min, v)
				elif nid.ends_with("sync3"):
					sync3_unlimited = sync3_unlimited and v < 0
	assert_int(sync1_min).is_greater_equal(500)
	assert_int(sync2_min).is_greater_equal(1200)
	assert_bool(sync3_unlimited).override_failure_message(
		"无垠档三节点均应为无上限哨兵（value<0）").is_true()


func test_unlimited_cap_semantics_via_manager() -> void:
	# 记录3#3：仅解锁无垠档时 get_power_cap 返回无上限哨兵（部署门比较永不触发），
	# 文案层显示"无限"；未解锁无垠档时维持 max 阶梯语义
	var PMSM = load("res://managers/phase_master_skill_manager.gd")
	var mgr: Node = PMSM.new()
	mgr._unlocked_nodes = ["pms_cmd_sync1", "pms_cmd_sync2"]
	assert_int(mgr.get_power_cap()).is_equal(1200)
	mgr._unlocked_nodes = ["pms_cmd_sync3"]
	assert_int(mgr.get_power_cap()).is_equal(PMSM.UNLIMITED_POWER_CAP)
	assert_str(mgr.get_power_cap_display()).is_equal("无限")
	mgr._unlocked_nodes = ["pms_cmd_sync2", "pms_cmd_sync3"]
	assert_int(mgr.get_power_cap()).is_equal(PMSM.UNLIMITED_POWER_CAP)
	mgr.free()


func test_base_cap_covers_starter_basics() -> void:
	# 新档绿槽三卡（era0 基础步兵）必须在基础上限内可部署；
	# GameConfig 总开关存在且默认开（A/B 回退口）
	assert_int(200).override_failure_message(
		"BASE_POWER_CAP 需与 phase_master_skill_manager 常量同步（改值两处同步）").is_equal(200)
	var gc = GameConfigS.get_default()
	assert_bool(bool(gc.power_cap_enabled)).is_true()
