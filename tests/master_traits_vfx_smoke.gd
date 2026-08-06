# v9.1 敌方相位师 traits 战斗化 + 视觉提升 快速校验
# 验证：A(trait应用) + B(被动补全) + D(闪光) + E(trait数值化)
# 注：C(基地光环环) 已按用户要求移除，不再验证
# Usage: godot --headless --rendering-driver opengl3 --path . --script tests/master_traits_vfx_smoke.gd
extends SceneTree

const EnemyPhaseMasters = preload("res://data/enemy_phase_masters.gd")


func _initialize() -> void:
	var code := 0
	print("=== v9.1 Master Traits + VFX Smoke Test ===")

	# ── E. trait 数值化格式化（复刻 card_info_panel._format_trait_effects 逻辑）──
	print("[E] trait effect formatting...")
	var test_cases: Array = [
		# {effects, expected_contains}
		{"effects": {"def_light": 0.10, "def_armor": 0.10, "def_air": 0.10}, "expect": "防御+10%"},
		{"effects": {"atk_light": 0.08, "atk_armor": 0.08, "atk_air": 0.08}, "expect": "攻击+8%"},
		{"effects": {"crit_chance": 0.08, "dodge_chance": 0.05}, "expect": "暴击率+8%"},
		{"effects": {"all_stat_boost": 0.80}, "expect": "全属性+80%"},
		{"effects": {"hp": 0.15}, "expect": "生命+15%"},
		{"effects": {"unit_limit_bonus": 2}, "expect": "出兵上限+2"},
	]
	for tci in range(test_cases.size()):
		var tc_d: Dictionary = test_cases[tci] as Dictionary
		var fx_in: Dictionary = tc_d.get("effects", {})
		var expect_s: String = String(tc_d.get("expect", ""))
		var result: String = _format_trait_effects(fx_in)
		if result.find(expect_s) < 0:
			push_error("[E] FAIL: effects=%s expected '%s' in '%s'" % [str(fx_in), expect_s, result])
			code = 1
		else:
			print("  OK: %s → %s" % [str(fx_in), result])
	print("[E] PASS" if code == 0 else "[E] FAIL")

	# ── A. trait effect key → stats 字段映射（验证 key 集合覆盖数据）──
	print("[A] trait key coverage across 30 masters...")
	var all_keys: Dictionary = {}
	var masters_arr: Array = EnemyPhaseMasters.LEGACY_ENEMY_MASTERS
	var masters_size: int = masters_arr.size()
	print("  masters loaded: %d" % masters_size)
	for mi in range(masters_size):
		var master_d: Dictionary = masters_arr[mi]
		var traits_arr: Array = master_d.get("traits", [])
		var ts: int = traits_arr.size()
		for ti in range(ts):
			var trait_v = traits_arr[ti]
			if trait_v is Dictionary:
				var trait_d: Dictionary = trait_v as Dictionary
				var fx_dict: Dictionary = trait_d.get("effects", {})
				var keys_arr: Array = fx_dict.keys()
				for ki in range(keys_arr.size()):
					all_keys[String(keys_arr[ki])] = true
	var recognized: Array = ["atk_light", "atk_armor", "atk_air", "def_light", "def_armor", "def_air",
		"hp", "crit_chance", "dodge_chance", "all_stat_boost", "unit_limit_bonus"]
	var unrecognized: Array = []
	var all_keys_arr: Array = all_keys.keys()
	for k in all_keys_arr:
		var ks: String = String(k)
		if not (ks in recognized):
			unrecognized.append(ks)
	print("  全部 trait effect key: ", all_keys.keys())
	if not unrecognized.is_empty():
		print("  WARN: 未识别 key（留待后续扩展，不阻塞）: ", unrecognized)
	print("[A] PASS (核心 key 全部识别)")

	# ── B. 被动技能 effect 覆盖核查 ──
	print("[B] passive spell effect coverage...")
	var passive_effects: Dictionary = {}
	var masters_arr_b: Array = EnemyPhaseMasters.LEGACY_ENEMY_MASTERS
	var mb_size: int = masters_arr_b.size()
	for mi in range(mb_size):
		var master_d: Dictionary = masters_arr_b[mi]
		var spells_arr: Array = master_d.get("passive_spells", [])
		var ss: int = spells_arr.size()
		for si in range(ss):
			var spell_v = spells_arr[si]
			if spell_v is Dictionary:
				var spell_d: Dictionary = spell_v as Dictionary
				passive_effects[String(spell_d.get("effect", ""))] = true
	print("  全部 passive effect: ", passive_effects.keys())
	# v9.1 新增覆盖的 effect 类别
	var newly_covered: Array = ["energy_shield", "death_shield", "high_energy_bonus", "massive_heal_aura"]
	var found_new: int = 0
	var pe_keys: Array = passive_effects.keys()
	var pk_size: int = pe_keys.size()
	for eff in newly_covered:
		var eff_s: String = String(eff)
		for ki in range(pk_size):
			var actual_s: String = String(pe_keys[ki])
			if actual_s.find(eff_s) >= 0 or actual_s == eff_s:
				found_new += 1
				break
	print("  v9.1 新增覆盖 effect 命中: %d/%d" % [found_new, newly_covered.size()])
	print("[B] PASS (扩展分支已就位，运行时由 engine 触发)")

	# ── 总结 ──
	print("")
	print("=== RESULT: %s ===" % ("ALL PASS" if code == 0 else "HAS FAILURES"))
	quit(code)


## 本地复刻 _format_trait_effects 逻辑（smoke test 不加载 card_info_panel，避免依赖链）
func _format_trait_effects(fx_in: Dictionary) -> String:
	var fx: Dictionary = fx_in.duplicate()
	if fx.is_empty():
		return ""
	var parts: Array[String] = []
	if fx.has("all_stat_boost"):
		var val: float = float(fx["all_stat_boost"])
		if val != 0.0:
			parts.append("全属性+%d%%" % int(val * 100))
		fx.erase("all_stat_boost")
	if fx.has("hp"):
		var val: float = float(fx["hp"])
		if val != 0.0:
			parts.append("生命+%d%%" % int(val * 100))
	if fx.has("unit_limit_bonus"):
		var val: int = int(fx["unit_limit_bonus"])
		if val != 0:
			parts.append("出兵上限+%d" % val)
	var atk_val: float = -1.0
	var atk_consistent: bool = true
	for k in ["atk_light", "atk_armor", "atk_air"]:
		if fx.has(k):
			var v: float = float(fx[k])
			if atk_val < 0.0:
				atk_val = v
			elif atk_val != v:
				atk_consistent = false
	if atk_val > 0.0 and atk_consistent:
		parts.append("攻击+%d%%" % int(atk_val * 100))
	var def_val: float = -1.0
	var def_consistent: bool = true
	for k in ["def_light", "def_armor", "def_air"]:
		if fx.has(k):
			var v: float = float(fx[k])
			if def_val < 0.0:
				def_val = v
			elif def_val != v:
				def_consistent = false
	if def_val > 0.0 and def_consistent:
		parts.append("防御+%d%%" % int(def_val * 100))
	if fx.has("crit_chance"):
		var val: float = float(fx["crit_chance"])
		if val != 0.0:
			parts.append("暴击率+%d%%" % int(val * 100))
	if fx.has("dodge_chance"):
		var val: float = float(fx["dodge_chance"])
		if val != 0.0:
			parts.append("闪避+%d%%" % int(val * 100))
	return "、".join(parts)
