# 进化条件系统 smoke：数据完整性（旧ID回归）+ registry 委托 + conditions 快照
# Usage: godot --headless --rendering-driver opengl3 --path . --script tests/evolution_condition_smoke.gd
extends SceneTree

const UCT = preload("res://data/unified_card_table.gd")
const EPR = preload("res://scripts/systems/evolution_path_registry.gd")
const CEM = preload("res://managers/evolution/card_evolution_manager.gd")
const EPIndex = preload("res://data/evolution_paths/__init__.gd")
const IntelBranches = preload("res://data/intel_evolution_branches.gd")
const EH = preload("res://managers/evolution/evolution_helpers.gd")

## 8 兵种抽样源卡（v9.x 委托修复的直接受益者：防空/工兵/侦察/火炮此前映射错乱）
const TYPE_SAMPLES := {
	"infantry": "ww1_mp18",
	"armor": "ww1_arm_ft17",
	"artillery": "ww1_arty_m81",
	"anti_air": "ww1_37mm",
	"air": "cold_mig21",
	"recon": "ww1_inf_cavalry",
	"engineer": "ww1_sup_engineer",
	"fort": "ww1_fort_pillbox",
}

var _fails: int = 0

func _fail(msg: String) -> void:
	push_error("[evo_cond_smoke] FAIL: " + msg)
	_fails += 1

func _initialize() -> void:
	_test_data_integrity()
	_test_registry_delegation()
	_test_condition_snapshot()
	_test_panel_scene()
	_test_power_calibration()

	if _fails == 0:
		print("evolution_condition_smoke: ALL PASS")
	else:
		print("evolution_condition_smoke: %d FAIL" % _fails)
	quit(0 if _fails == 0 else 1)

## ─── A. 数据完整性：evolution_paths 全节点 + 情报分支 source/target 都在统一卡表 ───
func _test_data_integrity() -> void:
	var table_ids := _get_table_ids()
	if table_ids.is_empty():
		_fail("unified_card_table 为空，无法校验")
		return

	var node_count := 0
	for type_key in TYPE_SAMPLES.keys():
		var path: Dictionary = EPIndex.get_evolution_path(String(TYPE_SAMPLES[type_key]))
		if path.is_empty():
			_fail("get_evolution_path(%s) 返回空（%s 兵种路径缺失）" % [TYPE_SAMPLES[type_key], type_key])
			continue
		for line_key in path.keys():
			node_count += _count_nodes_in(path[line_key], String(type_key) + "/" + String(line_key))
	if node_count < 50:
		_fail("evolution_paths 节点数异常少：%d（预期 54+）" % node_count)

	# 情报进化分支 source/target
	for bid in IntelBranches.get_all_branch_ids():
		var branch: Dictionary = IntelBranches.get_branch(String(bid))
		for src in branch.get("source_card_ids", []):
			if not table_ids.has(String(src)):
				_fail("情报分支 %s source '%s' 不在统一卡表" % [String(bid), String(src)])
		var tgt := String(branch.get("target_card_id", ""))
		if not tgt.is_empty() and not table_ids.has(tgt):
			_fail("情报分支 %s target '%s' 不在统一卡表" % [String(bid), tgt])

	# v9.x 回归锚点：旧 ID 修复后，panzerschreck 应能查到情报分支（旧 ID 时代恒空）
	if IntelBranches.get_branches_for_card("ww2_inf_panzerschrek").is_empty():
		_fail("get_branches_for_card(ww2_inf_panzerschrek) 为空——情报分支源 ID 断裂回归")
	print("A. data_integrity: nodes=%d intel_sources OK" % node_count)

## 递归统计并校验节点（隐藏分支比主线多一层嵌套：{branch_id: {stage: node}}）
func _count_nodes_in(container, context: String) -> int:
	if not (container is Dictionary):
		return 0
	var count := 0
	var table_ids := _get_table_ids()
	for key in (container as Dictionary).keys():
		var entry = (container as Dictionary)[key]
		if not (entry is Dictionary):
			continue
		var cid := String((entry as Dictionary).get("card_id", ""))
		if cid.is_empty():
			# 无 card_id → 是嵌套容器（隐藏分支），下钻一层
			count += _count_nodes_in(entry, context + "/" + String(key))
		else:
			count += 1
			if not table_ids.has(cid):
				_fail("evolution_paths %s/%s 节点 card_id '%s' 不在统一卡表" % [context, String(key), cid])
	return count

var _table_ids_cache: Dictionary = {}

func _get_table_ids() -> Dictionary:
	if _table_ids_cache.is_empty():
		for entry in UCT._TABLE:
			if entry is Dictionary and entry.has("card_id"):
				_table_ids_cache[String(entry["card_id"])] = true
	return _table_ids_cache

## ─── B. registry 委托：8 兵种路径非空 + 防空/火炮映射回归 + 属性预览（主线/副线） ───
func _test_registry_delegation() -> void:
	# 防空卡此前默认落 infantry 路径（前缀缺失）
	var aa_path: Dictionary = EPR.get_evolution_path("cold_sup_zsu23")
	if not _path_contains(aa_path, "ww1_37mm"):
		_fail("cold_sup_zsu23 未命中防空路径（防空前缀映射回归）")
	# 火炮卡此前被映射到 air（2/3 对调）
	var arty_path: Dictionary = EPR.get_evolution_path("mod_arty_m270")
	if not _path_contains(arty_path, "ww1_arty_m81"):
		_fail("mod_arty_m270 未命中火炮路径（火炮映射回归）")
	# 空中卡此前被映射到 artillery（样本用 mod_ah64——mod_f16 制空线 v7.x 已删）
	var air_path: Dictionary = EPR.get_evolution_path("mod_ah64")
	if not _path_contains(air_path, "cold_mig21"):
		_fail("mod_ah64 未命中空中路径（空中映射回归）")

	# 委托一致性：registry 与 __init__.gd 返回同一路径
	var reg_p: Dictionary = EPR.get_evolution_path("ww1_arm_ft17")
	var idx_p: Dictionary = EPIndex.get_evolution_path("ww1_arm_ft17")
	if reg_p.is_empty() or idx_p.is_empty() or reg_p.keys().size() != idx_p.keys().size():
		_fail("registry 委托结果与 __init__.gd 不一致")

	# calculate_evolved_stats（进化面板属性对比的活路径）：主线 + 副线（secondary_line 为 v9.x 新覆盖）
	var main_stats: Dictionary = EPR.calculate_evolved_stats(
		{"id": "ww1_arm_ft17", "installed_modifications": []}, "cold_arm_t55")
	if int(main_stats.get("max_hp", 0)) <= 0:
		_fail("calculate_evolved_stats 主线（ww1_arm_ft17→cold_arm_t55）返回空/无效")
	var sec_stats: Dictionary = EPR.calculate_evolved_stats(
		{"id": "ww1_saint", "installed_modifications": []}, "fut_arm_heavy_mech")
	if int(sec_stats.get("max_hp", 0)) <= 0:
		_fail("calculate_evolved_stats 副线（ww1_saint→fut_arm_heavy_mech）返回空/无效")
	print("B. registry_delegation: aa/arty/air OK, main+secondary stats OK")

func _path_contains(path: Dictionary, card_id: String) -> bool:
	if path.is_empty():
		return false
	for line_key in path.keys():
		var line = path[line_key]
		if not (line is Dictionary):
			continue
		for stage_key in line.keys():
			var node = line[stage_key]
			if node is Dictionary and String(node.get("card_id", "")) == card_id:
				return true
	return false

## ─── C. conditions 快照：非早退式全量条件 + 失败路径数字填充 ───
func _test_condition_snapshot() -> void:
	var bpm: Node = root.get_node_or_null("BlueprintManager")
	if bpm == null or not bpm.has_method("can_evolve_blueprint"):
		_fail("BlueprintManager 未加载，无法测试 conditions 快照")
		return
	if bpm.has_method("unlock_blueprint"):
		bpm.unlock_blueprint("ww1_mp18")

	# 全新状态：强化 0 / 改造 0 / 无图纸 → 失败但快照必须带全部条件与数字
	var can: Dictionary = bpm.can_evolve_blueprint("ww1_mp18", "ww2_thompson")
	if bool(can.get("ok", true)):
		_fail("全新状态 ww1_mp18→ww2_thompson 不应可进化")
	var conditions: Array = can.get("conditions", [])
	if conditions.size() < 3:
		_fail("conditions 快照过少：%d（至少应含图纸/强化/改造）" % conditions.size())
	var has_enh := false
	var has_mods := false
	for c in conditions:
		if not (c is Dictionary):
			_fail("conditions 含非字典条目：%s" % str(c))
			continue
		for k in ["key", "met", "current_text", "required_text"]:
			if not c.has(k):
				_fail("conditions 条目缺字段 %s：%s" % [k, str(c)])
		if String(c.get("key", "")) == "level":
			has_enh = true
			if bool(c.get("met", true)):
				_fail("level 条件在 0 级下不应满足")
			if String(c.get("current_text", "x")) != "0":
				_fail("level current_text 应为 '0'（失败路径数字填充），实为 '%s'" % String(c.get("current_text", "")))
		if String(c.get("key", "")) == "mods":
			has_mods = true
	if not has_enh or not has_mods:
		_fail("conditions 缺 level/mods 条目")
	# 失败路径同样填充旧字段（旧行为只有成功路径填；v20.12 键名 current_level）
	if int(can.get("current_level", -1)) != 0:
		_fail("失败路径 current_level 应填充 0，实为 %d" % int(can.get("current_level", -1)))

	# 结构性错误：conditions 为空数组（非 null），reason 保留
	var bad: Dictionary = bpm.can_evolve_blueprint("ww1_mp18", "zzz_not_exist")
	if bool(bad.get("ok", true)) or String(bad.get("reason", "")) == "":
		_fail("无效目标应返回 ok=false 且带 reason")
	if not (bad.get("conditions", null) is Array) or not (bad["conditions"] as Array).is_empty():
		_fail("结构性错误的 conditions 应为空数组")
	print("C. condition_snapshot: %d conditions, failure-path numbers OK" % conditions.size())

## ─── D. evolution_panel.tscn 结构：ReqList（VBox）替换旧 ReqDetails（单 Label） ───
func _test_panel_scene() -> void:
	var pk: PackedScene = load("res://scenes/ui/evolution_panel.tscn")
	if pk == null:
		_fail("evolution_panel.tscn 加载失败")
		return
	var inst: Node = pk.instantiate()
	var req_list: Node = inst.get_node_or_null(
		"VBoxContainer/BodyHBox/DetailPanel/DetailInner/DetailScroll/DetailContent/RequirementsPanel/ReqContent/ReqList")
	if req_list == null or not (req_list is VBoxContainer):
		_fail("ReqList VBoxContainer 节点缺失（tscn 结构回归）")
	inst.free()
	print("D. panel_scene: ReqList OK")

## ─── E. v9.x 战力口径重设锁定：阈值表（战斗标尺）+ 进化门槛（目标白板×0.70） ───
const PT = preload("res://data/power_tiers.gd")

func _test_power_calibration() -> void:
	# 阈值表锁定（战斗公式标尺，时代台阶语义，定标依据 tests/power_calibration_probe.gd）
	if PT.POWER_THRESHOLDS != [250, 600, 900, 1300]:
		_fail("POWER_THRESHOLDS 被改动：%s（如调整数值请同步本断言与定标注释）" % str(PT.POWER_THRESHOLDS))
	# 档位映射锚点（实测白板值）
	var anchors := [[253, PT.Tier.VETERAN], [662, PT.Tier.ELITE], [917, PT.Tier.CHAMPION],
		[1296, PT.Tier.CHAMPION], [1418, PT.Tier.OVERLORD]]
	for a in anchors:
		if PT.get_tier_by_power(a[0]) != a[1]:
			_fail("get_tier_by_power(%d) 档位锚点不符" % a[0])
	# 门槛 = 白板×0.70 一致性
	var white: int = EH.get_target_white_combat("ww2_pz3")
	if white < 700 or white > 730:
		_fail("ww2_pz3 白板战斗战力漂移：%d（定标值 715）" % white)
	if EH.get_target_power_bar("ww2_pz3") != int(float(white) * 0.70):
		_fail("get_target_power_bar 与白板×0.70 不一致")

	# 门槛语义锚点：白板步兵差 2 点不过线（需 E1 级投入）；投入后的初始坦克轻松过线
	var bpm: Node = root.get_node_or_null("BlueprintManager")
	var ir: Node = root.get_node_or_null("InstanceRegistry")
	if bpm == null or ir == null:
		_fail("managers 未加载，跳过门槛语义锚点")
		return
	bpm.unlock_blueprint("ww1_mp18")
	var fresh: Dictionary = bpm.can_evolve_blueprint("ww1_mp18", "ww2_thompson")
	var fresh_power: Dictionary = _cond_by_key(fresh, "power")
	if fresh_power.is_empty() or bool(fresh_power.get("met", true)):
		_fail("白板 mp18 应不过战力线（253 < 0.70×365=255）——步兵首进化需 E1 级投入的定标被破坏")
	bpm.unlock_blueprint("ww1_arm_ft17")
	var iid: String = ir.create_instance("ww1_arm_ft17").instance_id
	var inst_card = ir.get_instance(iid)
	inst_card.enhance_level = 5
	inst_card.mods = [{"id": "arm_01_reactive_armor", "enabled": true}, {"id": "arm_02_smoothbore", "enabled": true}]
	var invested: Dictionary = bpm.can_evolve_blueprint(iid, "ww2_pz3")
	var inv_power: Dictionary = _cond_by_key(invested, "power")
	if inv_power.is_empty() or not bool(inv_power.get("met", false)):
		_fail("强化5+2改的 ft17（≈697）应过战力线（0.70×715=500）")
	ir.dispose_instance(iid)
	print("E. power_calibration: thresholds + 0.70 bar OK")

func _cond_by_key(check: Dictionary, key: String) -> Dictionary:
	for c in check.get("conditions", []):
		if c is Dictionary and String(c.get("key", "")) == key:
			return c
	return {}
