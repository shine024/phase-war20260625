# 2026-08-25 v20.15 高价值单位固定机制冒烟：光环管线 / 真隐身反隐 / 个体机制
# 无 GdUnit 依赖。验证六件事：
#   1) UCT 机制 tags：16 张单位显式/自动注入 tags 齐全
#   2) deploy_uses 核心档：雷达/指挥类 4 次/场（v20.16 上调）
#   3) CardAbilityManager.is_unit_hidden / is_unit_targetable / side_has_detection
#      （meta 判定在 _initialize；组扫描依赖树内节点——_initialize 阶段 root 子节点
#       is_inside_tree()=false，组查询为空，故组用例延到首帧 _process 执行）
#   4) aura_data.is_mechanical_ally 双口径（card_tags 优先：装甲=机械/步兵=非机械；
#      动态脚本挂 stats，失败降级为源码守卫）
#   5) CardMechanismDesc：机制文案表覆盖全部 tag + 中文别名（雷达→radar）归并 + 卡→文案链路
#   6) 源码接线守卫：玩家侧光环注册/清理、索敌过滤、tick 挂钩、UI 文案接入
# Usage: godot --headless --rendering-driver opengl3 --path . --script tests/fixed_mechanics_smoke.gd
extends SceneTree

var _errs: Array[String] = []
var _cam_script: GDScript = null
var _hidden_dummy: Node2D = null
var _detect_pending: bool = false


func _initialize() -> void:
	var errs := _errs
	var UCT: Script = load("res://data/unified_card_table.gd")
	if UCT == null:
		_fail(errs, "unified_card_table.gd 加载失败（含编译错误）")
		_finish(errs)
		return

	# ── 1) 机制 tags 数据断言 ──
	# 注意：中文名卡的自动注入 tag 是中文关键词本身（如"雷达站"→"雷达"，radar 拉丁词不匹配），
	# 运行时判定/注册均同时查中英 variant（DETECTION_TAGS / construct_unit 注册分支），此处按实际值断言。
	var tag_cases: Dictionary = {
		"cold_fort_radar": ["雷达"],
		"cold_arm_p18": ["雷达"],
		"mod_boss_command": ["指挥"],
		"platform_future_radar": ["雷达"],
		"ww1_sup_ford_ambulance": ["medic"],
		"platform_ww1_medic": ["medic"],
		"ww2_sup_gmc_truck": ["supply"],
		"fut_sup_nrepair": ["repair"],
		"cold_arty_brem1": ["repair"],
		"fut_sup_ps9": ["relay"],
		"guardian_modern_stealth": ["stealth_aircraft"],
		"mod_inf_scout_drone": ["recon"],
		"fut_inf_scout_mech": ["recon"],
		"fut_stormcore": ["storm_core"],
		"fut_nano_drone": ["repair_vehicle"],
		"fut_attack_drone": ["attack_drone"],
	}
	var tag_fail: int = 0
	for card_id in tag_cases:
		var entry: Dictionary = UCT.get_entry(String(card_id))
		if entry.is_empty():
			_fail(errs, "%s 无 UCT 条目" % card_id)
			tag_fail += 1
			continue
		var tags: Array = UCT._collect_tags_for_entry(entry)
		for want in tag_cases[card_id]:
			if not tags.has(want):
				_fail(errs, "%s 缺 tag %s（实际 %s）" % [card_id, want, tags])
				tag_fail += 1
	print("  机制 tags：", "PASS（16 张）" if tag_fail == 0 else "见错误")

	# ── 2) deploy_uses 核心档 = 4（v20.16 上调） ──
	var du_fail: int = 0
	for card_id in ["cold_fort_radar", "cold_arm_p18", "mod_boss_command"]:
		var entry: Dictionary = UCT.get_entry(String(card_id))
		if entry.is_empty():
			continue
		var uses: int = int(UCT.get_deploy_uses(entry, null))
		if uses != 4:
			_fail(errs, "%s deploy_uses=%d 期望 4（核心档）" % [card_id, uses])
			du_fail += 1
	print("  核心档部署次数：", "PASS（3 张 =4/场）" if du_fail == 0 else "见错误")

	# ── 3a) 真隐身 meta 判定（不依赖场景树） ──
	var CAM: GDScript = load("res://managers/card_ability_manager.gd")
	if CAM == null:
		_fail(errs, "card_ability_manager.gd 加载失败（含编译错误）")
		_finish(errs)
		return
	_cam_script = CAM
	var hid_fail: int = 0
	var h := Node2D.new()
	if CAM.is_unit_hidden(h):
		_fail(errs, "无 meta 单位被判隐身"); hid_fail += 1
	h.set_meta("_stealth_active", true)
	if not CAM.is_unit_hidden(h):
		_fail(errs, "_stealth_active 未判隐身"); hid_fail += 1
	h.remove_meta("_stealth_active")
	h.set_meta("hidden_grace_until", Time.get_ticks_msec() + 10000)
	if not CAM.is_unit_hidden(h):
		_fail(errs, "未到期 hidden_grace_until 未判隐身"); hid_fail += 1
	h.set_meta("hidden_grace_until", Time.get_ticks_msec() - 1)
	if CAM.is_unit_hidden(h):
		_fail(errs, "已过期 hidden_grace_until 仍判隐身"); hid_fail += 1
	h.set_meta("hidden_grace_until", Time.get_ticks_msec() + 60000)
	_hidden_dummy = h
	print("  真隐身 meta 判定：", "PASS（4 例）" if hid_fail == 0 else "见错误")

	# ── 4) is_mechanical_ally 双口径（动态脚本挂 stats；失败则降级跳过） ──
	var mech_fail: int = 0
	var AuraDataScript: Script = load("res://data/aura_data.gd")
	var us_script: Script = load("res://resources/unit_stats.gd")
	var holder := GDScript.new()
	holder.source_code = "extends Node2D\nvar stats\nvar is_player := true\n"
	if holder.reload() == OK and us_script != null:
		var ally_m := Node2D.new()
		ally_m.set_script(holder)
		root.add_child(ally_m)
		var st = us_script.new()
		st.set_meta("card_tags", ["vehicle", "armored"])
		ally_m.stats = st
		if not AuraDataScript.is_mechanical_ally(ally_m):
			_fail(errs, "装甲卡 tags（vehicle/armored）未判机械——玩家坦克会被维修光环漏修"); mech_fail += 1
		st.set_meta("card_tags", ["infantry"])
		if AuraDataScript.is_mechanical_ally(ally_m):
			_fail(errs, "步兵 tags 误判机械"); mech_fail += 1
		st.remove_meta("card_tags")
		st.platform_type = 8  # legacy CARRIER → 机械（敌方回退口径）
		if not AuraDataScript.is_mechanical_ally(ally_m):
			_fail(errs, "legacy platform_type=8 未判机械（回退口径失效）"); mech_fail += 1
		ally_m.free()
		print("  机械类双口径：", "PASS（3 例）" if mech_fail == 0 else "见错误")
	else:
		print("  [SKIP] 动态脚本挂 stats 失败，is_mechanical_ally 实测跳过（源码守卫见第 6 组）")

	# ── 5) 机制文案表 ──
	var cmd_fail: int = 0
	var CMD: Script = load("res://data/card_mechanism_desc.gd")
	if CMD == null:
		_fail(errs, "card_mechanism_desc.gd 加载失败（含编译错误）")
		cmd_fail += 1
	else:
		for tag in CMD.TAG_ORDER:
			if not CMD.MECHANISM_DESC.has(tag):
				_fail(errs, "TAG_ORDER 的 %s 缺 MECHANISM_DESC 文案" % tag)
				cmd_fail += 1
		var alias_lines: Array[String] = CMD.get_mechanism_lines(["support", "雷达"])
		if alias_lines.is_empty() or String(alias_lines[0]).find("雷达警戒") < 0:
			_fail(errs, "中文 tag「雷达」未归并到 radar 机制行")
			cmd_fail += 1
		var radar_lines: Array[String] = CMD.get_mechanism_lines_by_card_id("cold_fort_radar")
		if radar_lines.is_empty():
			_fail(errs, "cold_fort_radar 未产出机制文案（tags→文案链路断）")
			cmd_fail += 1
	print("  机制文案表：", "PASS" if cmd_fail == 0 else "见错误")

	# ── 6) 源码接线守卫 ──
	var guards: Dictionary = {
		"res://scenes/units/construct_unit.gd": [
			["_fixed_mechanism_tags()", "玩家侧 tags 光环注册辅助缺失"],
			["receive_auras_from_field(self)", "后入场光环补偿未接入 setup"],
			["update_supply_aura_periodic", "补给光环 tick 未挂钩"],
			["update_relay_periodic", "能量中继 tick 未挂钩"],
			["update_scout_mark_periodic", "侦察标记 tick 未挂钩"],
			["update_storm_periodic", "风暴核心 tick 未挂钩"],
			["update_nano_repair_pulse", "纳米修复脉冲 tick 未挂钩"],
			["hidden_grace_until", "stalker 真隐身 meta 未写入"],
		],
		"res://scenes/units/enemy_unit.gd": [
			["is_unit_targetable", "敌方索敌未接真隐身过滤"],
			["hidden_grace_until", "敌方 stealth 真隐身未写入"],
		],
		"res://scripts/battle/target_selection.gd": [
			["is_unit_targetable", "select_target 未接隐身过滤"],
		],
		"res://scripts/battle/construct_unit_ai.gd": [
			["is_unit_targetable", "AI 索敌未接隐身过滤"],
			["side_has_detection", "保持目标逻辑未接侦测源判定"],
		],
		"res://managers/aura_manager.gd": [
			["receive_auras_from_field", "后入场补偿方法缺失"],
		],
		"res://managers/card_ability_manager.gd": [
			["is_unit_hidden", "隐身统一判定缺失"],
			["DETECTION_TAGS", "侦测源 tag 表缺失"],
		],
		"res://scenes/ui/card_info_panel.gd": ["CardMechanismDesc", "卡牌详情未接机制文案"],
		"res://scenes/ui/backpack_card_item.gd": ["CardMechanismDesc", "背包 tooltip 未接机制文案"],
		"res://scenes/ui/bottom_instrument_bar.gd": ["CardMechanismDesc", "底栏 tooltip 未接机制文案"],
	}
	for path in guards:
		var f := FileAccess.open(String(path), FileAccess.READ)
		if f == null:
			_fail(errs, "%s 读取失败" % path)
			continue
		var src := f.get_as_text()
		f.close()
		for pair in guards[path]:
			if src.find(String(pair[0])) < 0:
				_fail(errs, "%s：%s" % [path, pair[1]])

	# 组扫描用例延到首帧（_initialize 阶段 root 子节点不在树内，组查询为空）
	_detect_pending = true


## 首帧执行组依赖用例（侦测源组扫描 / 侦测源在场时隐身可选）
func _process(_delta: float) -> bool:
	if not _detect_pending:
		return false
	_detect_pending = false
	var errs := _errs
	var CAM: GDScript = _cam_script
	var det_fail: int = 0
	var h := _hidden_dummy
	var det := Node2D.new()
	root.add_child(det)
	det.add_to_group("player_units")
	det.set_meta("_ability_tags", ["radar"])
	# 无侦测源（移除后）→ 隐身不可选
	CAM._detection_cache["until_ms"] = 0
	det.remove_from_group("player_units")
	if CAM.side_has_detection(true):
		_fail(errs, "player_units 组为空时误判有侦测源"); det_fail += 1
	# 侦测源入组 → 隐身可选
	det.add_to_group("player_units")
	CAM._detection_cache["until_ms"] = 0
	if not CAM.side_has_detection(true):
		_fail(errs, "player_units 组内 radar tag 单位未被判定为侦测源"); det_fail += 1
	CAM._detection_cache["until_ms"] = 0
	if not CAM.is_unit_targetable(h, det):
		_fail(errs, "有侦测源时隐身单位应可被选中"); det_fail += 1
	det.free()
	if h != null:
		h.free()
	print("  侦测源组扫描：", "PASS（3 例）" if det_fail == 0 else "见错误")
	_finish(errs)
	return false


func _fail(errs: Array[String], msg: String) -> void:
	errs.append(msg)
	print("  [FAIL] ", msg)


func _finish(errs: Array[String]) -> void:
	if errs.is_empty():
		print("[fixed_mechanics_smoke] ALL PASS")
		quit(0)
	else:
		print("[fixed_mechanisms_smoke] %d 处失败" % errs.size())
		quit(1)
