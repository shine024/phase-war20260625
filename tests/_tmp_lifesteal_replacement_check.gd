extends SceneTree
## tests/_tmp_lifesteal_replacement_check.gd — 吸血→战场回收（击杀修复）替换验证
## ① 数据源：词条/敌方词条/enh改造/词条模块/技能树 新键新值新文案
## ② 管线：UnitStats 新字段、registry/affix_manager/enemy_affixes dispatch 键
## ③ 结算：handler 击杀入口存在、旧 per-hit 入口移除、battle_manager 接线
## ④ 存档兼容：持久 id（词条/改造/模块/技能节点）全部保留
## Usage: godot --headless --rendering-driver opengl3 --path . --script tests/_tmp_lifesteal_replacement_check.gd

func _read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return "(missing)"
	var s := f.get_as_text()
	f.close()
	return s

func _initialize() -> void:
	var errs: Array[String] = []

	# ── ① 数据源 ──
	var aff: String = _read("res://data/affix_definitions.gd")
	if aff.find('"effect_key":         "kill_repair"') < 0:
		errs.append("affix_definitions: effect_key 应为 kill_repair")
	if aff.find('"base_value":         0.06') < 0:
		errs.append("affix_definitions: base_value 应为 0.06")
	if aff.find("汲能吸血") >= 0 or aff.find('"affix_name":         "战场回收"') < 0:
		errs.append("affix_definitions: 名称应为 战场回收")
	if aff.find('"lifesteal": {') < 0:
		errs.append("affix_definitions: 词条 id lifesteal（存档键）应保留")

	var eaff: String = _read("res://data/enemy_affixes.gd")
	if eaff.find('"effect_key": "kill_repair"') < 0 or eaff.find('"base_value": 0.12') < 0:
		errs.append("enemy_affixes: enemy_vampire 应为 kill_repair 0.12")
	if eaff.find('"name": "吸血"') >= 0:
		errs.append("enemy_affixes: 名称不应再是 吸血")

	var enh: String = _read("res://data/modification_modules/enhancement_mods.gd")
	if enh.find("kill_repair = 0.06") < 0 or enh.find("kill_repair = 0.14") < 0:
		errs.append("enhancement_mods: level_effects 应为 kill_repair 0.06/0.10/0.14")
	if enh.find("lifesteal =") >= 0:
		errs.append("enhancement_mods: 不应残留 lifesteal level_effects 键")

	var mod: String = _read("res://data/module_definitions.gd")
	if mod.find('"effect_key": "kill_repair"') < 0:
		errs.append("module_definitions: effect_key 应为 kill_repair")

	var tree: String = _read("res://data/phase_master_skill_tree.gd")
	if tree.find('"lifesteal": 0.08') >= 0:
		errs.append("phase_master_skill_tree: stat_bonus 不应再带 lifesteal（防与解锁路径双发）")
	if tree.find('"id": "lifesteal_unlock"') < 0:
		errs.append("phase_master_skill_tree: lifesteal_unlock 节点 id（存档键）应保留")

	# ── ② 管线 ──
	var us_res: Resource = load("res://resources/unit_stats.gd")
	var us: Object = us_res.new()
	if not ("kill_repair" in us):
		errs.append("UnitStats: 缺少 kill_repair 字段")
	if "lifesteal" in us:
		errs.append("UnitStats: 不应残留 lifesteal 字段")
	if not ("has_kill_repair_mutation" in us):
		errs.append("UnitStats: 缺少 has_kill_repair_mutation 字段")

	if mod.find('"kill_repair": 0.0,') < 0:
		errs.append("module_definitions: 汇总初值应含 kill_repair")

	# ── ③ 结算 ──
	var meh: String = _read("res://scripts/battle/module_effect_handler.gd")
	if meh.find("static func on_unit_killed") < 0 or meh.find("_apply_kill_repair") < 0:
		errs.append("module_effect_handler: 缺少击杀修复入口")
	if meh.find("func _apply_lifesteal") >= 0:
		errs.append("module_effect_handler: 旧 _apply_lifesteal 应已删除")
	if meh.find("_apply_lifesteal(") >= 0:
		errs.append("module_effect_handler: per-hit 吸血调用应已移除")
	if meh.find("stats.kill_repair") < 0:
		errs.append("module_effect_handler: 应消费 stats.kill_repair")

	var bm: String = _read("res://managers/battle/battle_manager.gd")
	if bm.find("unit_killed.is_connected(_on_unit_killed_kill_repair)") < 0:
		errs.append("battle_manager: 未接线 unit_killed → 击杀修复")
	if bm.find("disconnect(_on_unit_killed_kill_repair)") < 0:
		errs.append("battle_manager: 未断开 unit_killed 接线")

	var ust: String = _read("res://resources/unit_stats_table.gd")
	if ust.find('{"ek": "kill_repair", "ev": 0.08}') < 0:
		errs.append("unit_stats_table: 轻装强化特殊键应为 kill_repair")
	if ust.find("stats.kill_repair = minf(0.60, stats.kill_repair + 0.06)") < 0:
		errs.append("unit_stats_table: 解锁路径应 +0.06 kill_repair")

	# ── ④ UI/标签 ──
	var labels: String = _read("res://scripts/ui/mod_effect_labels.gd")
	if labels.find('"kill_repair": return "击杀修复"') < 0:
		errs.append("mod_effect_labels: 缺少 kill_repair → 击杀修复")
	var ul: String = _read("res://data/unlock_labels.gd")
	if ul.find("击杀回复自身6%最大HP") < 0:
		errs.append("unlock_labels: desc 应为击杀修复口径")
	if ul.find('"lifesteal_unlock"') < 0:
		errs.append("unlock_labels: key lifesteal_unlock（存档键）应保留")

	if errs.is_empty():
		print("[lifesteal-replacement] ALL PASS")
	else:
		for e in errs:
			printerr("[FAIL] ", e)
		quit(1)
		return
	quit()
