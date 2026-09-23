# v26 进化退役标注（批次4）：进化 UI 链已由制造中心接管（res://scenes/ui/evolution_panel.gd）。
# 本测试守护的均为保留的内部 API（谱系/条件/战力计算），作为数据完整性回归继续运行。
# 进化条件系统 smoke：数据完整性（旧ID回归）+ conditions 快照
# Usage: godot --headless --rendering-driver opengl3 --path . --script tests/evolution_condition_smoke.gd
extends SceneTree

const UCT = preload("res://data/unified_card_table.gd")
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
	_test_condition_snapshot()
	_test_panel_scene()
	_test_power_calibration()
	_test_intel_branch_display()

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

## ─── C. conditions 快照：非早退式全量条件 + 失败路径数字填充 ───
func _test_condition_snapshot() -> void:
	var bpm: Node = root.get_node_or_null("BlueprintManager")
	if bpm == null or not bpm.has_method("can_evolve_blueprint"):
		_fail("BlueprintManager 未加载，无法测试 conditions 快照")
		return

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
		"VBoxContainer/BodyHBox/DetailPanel/DetailInner/DetailVBox/DetailScroll/DetailContent/RequirementsPanel/ReqContent/ReqList")
	if req_list == null or not (req_list is VBoxContainer):
		_fail("ReqList VBoxContainer 节点缺失（tscn 结构回归）")
	inst.free()
	print("D. panel_scene: ReqList OK")

## ─── E. 战力阈值表锁定（军衔标尺，POWER_THRESHOLDS 仍被军衔系统消费）+ 进化门槛锚点 ───
## （0.70 白板门槛函数 v25.3 起无生产消费方，仅一致性留档；进化资格现行轴=等级+改造数）
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

	# 门槛语义锚点（v6.19.4 改写到现行资格轴）：战力门槛 v25.3 已拆、enhance_level v20.12
	# 已退出进化条件——旧"白板不过战力线/投入过线"锚点随机制退役。此前本块因
	# unlock_blueprint 死调用（蓝图体系删除批次）脚本错误中止而假绿多轮，_fails 无感知。
	# 现行实质量轴 = 等级（InstanceRegistry card_level）+ 改造数：达标后 level/mods 条件翻绿。
	var bpm: Node = root.get_node_or_null("BlueprintManager")
	var ir: Node = root.get_node_or_null("InstanceRegistry")
	if bpm == null or ir == null:
		_fail("managers 未加载，跳过门槛语义锚点")
		return
	var stage: String = UnitLineageConfig.get_stage("ww1_arm_ft17", "ww2_pz3")
	var lv_req: int = UnitLineageConfig.get_card_level_requirement(stage)
	var mod_req: int = UnitLineageConfig.get_mod_requirement(stage)
	if lv_req <= 0 or mod_req <= 0:
		_fail("ft17→pz3 stage '%s' 等级/改造要求异常：%d/%d" % [stage, lv_req, mod_req])
		return
	var iid: String = ir.create_instance("ww1_arm_ft17").instance_id
	ir.add_experience(iid, int(BattleExperienceConfig.LEVEL_EXP_THRESHOLDS[
		mini(lv_req, BattleExperienceConfig.LEVEL_EXP_THRESHOLDS.size() - 1)]))
	var inst_card = ir.get_instance(iid)
	var mods_arr: Array = []
	for i in range(mod_req):
		mods_arr.append({"id": "arm_probe_mod_%d" % i, "enabled": true})
	inst_card.mods = mods_arr
	var invested: Dictionary = bpm.can_evolve_blueprint(iid, "ww2_pz3")
	var lv_c: Dictionary = _cond_by_key(invested, "level")
	var mod_c: Dictionary = _cond_by_key(invested, "mods")
	if lv_c.is_empty() or not bool(lv_c.get("met", false)):
		_fail("等级 Lv%d 的 ft17 实例 level 条件应翻绿（stage=%s，现报 %s）" % [
			lv_req, stage, str(lv_c.get("current_text", "<缺失>"))])
	if mod_c.is_empty() or not bool(mod_c.get("met", false)):
		_fail("改造 %d 件的 ft17 实例 mods 条件应翻绿（stage=%s，现报 %s）" % [
			mod_req, stage, str(mod_c.get("current_text", "<缺失>"))])
	ir.dispose_instance(iid)
	print("E. thresholds + 0.70 bar + level/mods 门槛锚点 OK")

## ─── F. 情报进化分支显示层：enemy_type 中文映射全覆盖 + 源卡→跨系分支查询锚点 ───
## v6.19.4 自 evolution_intel_smoke 迁移收编（该脚本面板侧断言随 v26 制造重写失效退役，
## 仅这两条数据层检查仍活，归入本冒烟）。死键防回归：v7.x heavy_armor_mat 事故
## （需求键无中文显示名=进度永远凑不齐且玩家不可读）。
func _test_intel_branch_display() -> void:
	for bid in IntelBranches.get_all_branch_ids():
		var reqs: Dictionary = IntelBranches.get_intel_requirements(String(bid))
		for et in reqs.keys():
			var display: String = IntelBranches.get_enemy_type_display(String(et))
			if display == String(et):
				_fail("情报分支 %s 的需求键 %s 无中文显示名（ENEMY_TYPE_DISPLAY 缺键）" % [String(bid), String(et)])
	if IntelBranches.get_enemy_type_display("infantry") != "步兵系":
		_fail("get_enemy_type_display(infantry) 应为 步兵系")
	var has_cross := false
	for b in IntelBranches.get_branches_for_card("fut_howitzer"):
		if String(b.get("branch_id", "")) == "IB_CROSS_ARTILLERY_AIR":
			has_cross = true
	if not has_cross:
		_fail("fut_howitzer 的分支列表缺少 IB_CROSS_ARTILLERY_AIR（跨系分支查询断裂）")
	print("F. intel_branch_display: enemy_type 映射 + 跨系锚点 OK")

func _cond_by_key(check: Dictionary, key: String) -> Dictionary:
	for c in check.get("conditions", []):
		if c is Dictionary and String(c.get("key", "")) == key:
			return c
	return {}
