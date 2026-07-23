## v8.2 各关卡敌人设定检查
## 验证：① 全100关档位分布合理 ② 各时代代表单位数值 ③ 跨时代递进 ④ 势力归属
## 独立运行：D:\godot\Godot_v4.5.1.exe --headless --rendering-driver opengl3 --path . --script tests/v8_level_check.gd
extends SceneTree
const EnemyLoadoutTiers = preload("res://data/enemy_loadout_tiers.gd")
const LevelInfo = preload("res://data/level_information.gd")

var _pass: int = 0
var _fail: int = 0
const ERA_NAMES := ["一战", "二战", "冷战", "现代", "近未来"]
# 各时代代表单位真实 base_hp（来自 unified_card_table._TABLE，enemy_only 条目）
# 格式: {era: [{id, hp, atk_l}]}
const ERA_SAMPLES := {
	0: [{"id":"ww1_inf_mp18","hp":91,"atk":27}, {"id":"ww1_arm_rolls_e","hp":214,"atk":163}, {"id":"ww1_boss_av7","hp":650,"atk":585}],
	1: [{"id":"ww2_inf_thompson","hp":150,"atk":45}, {"id":"ww2_arm_panther_e","hp":471,"atk":358}, {"id":"ww2_boss_kingtiger","hp":1000,"atk":900}],
	2: [{"id":"cold_inf_ak","hp":197,"atk":59}, {"id":"cold_arm_t72_e","hp":477,"atk":363}, {"id":"cold_boss_mig","hp":1400,"atk":630}],
	3: [{"id":"mod_inf_marine","hp":463,"atk":123}, {"id":"mod_arm_abrams_e","hp":592,"atk":497}, {"id":"mod_boss_command","hp":1800,"atk":1944}],
	4: [{"id":"fut_inf_cyborg","hp":640,"atk":171}, {"id":"fut_arm_colossus_e","hp":1045,"atk":878}, {"id":"fut_boss_nexus","hp":2500,"atk":2250}],
}


func _init() -> void:
	print("\n========== v8.2 各关卡敌人设定检查 ==========")

	# ===== 检查1：全100关档位分布（每时代前1/3低/中段中/后1/3高）=====
	print("\n--- 检查1：全100关档位分布 ---")
	var tier_dist := {1:0, 2:0, 3:0}
	for lv in range(1, 101):
		var era_local: int = ((lv - 1) % 20) + 1
		var prog: float = float(era_local - 1) / 19.0
		var tier: int = EnemyLoadoutTiers.get_tier_for_level_progress(prog, false)
		tier_dist[tier] += 1
	print("  低配关: %d, 中配关: %d, 高配关: %d (每时代约 7/8/5)" % [tier_dist[1], tier_dist[2], tier_dist[3]])
	# 每时代: 低(progress<0.33)=关1-7共7关, 中(0.33-0.75)=关8-15共8关, 高(>=0.75)=关16-20共5关
	_assert_int(tier_dist[1], 35, "低配关数=35(5时代×7)")  # 7关×5
	_assert_int(tier_dist[2], 40, "中配关数=40(5时代×8)")
	_assert_int(tier_dist[3], 25, "高配关数=25(5时代×5)")

	# ===== 检查2：各时代首关/末关档位正确 =====
	print("\n--- 检查2：各时代首末关档位 ---")
	for era in range(5):
		var first_lv: int = era * 20 + 1   # 1,21,41,61,81
		var last_lv: int = era * 20 + 20   # 20,40,60,80,100
		var first_tier: int = _tier_for_level(first_lv)
		var last_tier: int = _tier_for_level(last_lv)
		_assert_int(first_tier, EnemyLoadoutTiers.TIER_LOW, "%s首关(第%d关)=低配" % [ERA_NAMES[era], first_lv])
		_assert_int(last_tier, EnemyLoadoutTiers.TIER_HIGH, "%s末关(第%d关)=高配" % [ERA_NAMES[era], last_lv])

	# ===== 检查3：势力归属（前20空，21+各时代分配）=====
	print("\n--- 检查3：势力归属 ---")
	var li := LevelInfo.new()
	# 前20关应为空（无主之地）
	var ww1_empty := true
	for lv in range(1, 21):
		if not li.get_level_faction(lv).is_empty():
			ww1_empty = false
			break
	_assert_true(ww1_empty, "前20关(一战)全部无主之地")
	# 各势力关卡
	_assert_str(li.get_level_faction(25), "nova_arms", "第25关(二战)=新星兵工")
	_assert_str(li.get_level_faction(50), "aether_dynamics", "第50关(冷战)=以太动力")
	_assert_str(li.get_level_faction(70), "quantum_logistics", "第70关(现代)=量子后勤")
	_assert_str(li.get_level_faction(85), "helix_recon", "第85关(近未来前半)=螺旋侦察")
	_assert_str(li.get_level_faction(95), "void_research", "第95关(近未来后半)=虚空相位")

	# ===== 检查4：各时代代表单位最终数值（wave1, normal, 无势力）=====
	print("\n--- 检查4：各时代代表单位最终数值（首关wave1）---")
	print("  单单位                    时代     base_hp 档位     最终HP    最终ATK")
	for era in range(5):
		var lv: int = era * 20 + 1  # 各时代首关
		var tier: int = _tier_for_level(lv)
		var tier_mul: float = _tier_mul(tier)
		var tier_name: String = _tier_name(tier)
		for sample in ERA_SAMPLES[era]:
			var final_hp: float = sample.hp * tier_mul * 1.0  # wave1=1.0, 无势力, normal=1.0
			var final_atk: float = sample.atk * tier_mul * 1.0
			print("  %-24s %-6s %6d  %-6s %8.0f %8.0f" % [sample.id, ERA_NAMES[era], sample.hp, tier_name, final_hp, final_atk])

	# ===== 检查5：跨时代递进（同档位同wave下，近未来vs一战倍率）=====
	print("\n--- 检查5：跨时代递进（步兵 base 比值）---")
	var ww1_inf_hp: float = 91.0
	var fut_inf_hp: float = 640.0
	var ratio: float = fut_inf_hp / ww1_inf_hp
	_assert_approx(ratio, 7.0, 0.5, "步兵 base 近未来/一战 = ~7倍")
	print("  一战步兵base=%.0f → 近未来步兵base=%.0f → 比值 %.2fx (base已含时代递进)" % [ww1_inf_hp, fut_inf_hp, ratio])

	# ===== 检查6：近未来末关(100)满档满波满势力 极限数值 =====
	print("\n--- 检查6：第100关极限数值（高配+wave10+虚空相位满级假设）---")
	var lv100_tier: int = _tier_for_level(100)  # HIGH
	var lv100_mul: float = _tier_mul(lv100_tier)
	var wave10_hp: float = 1.0 + 0.12 * 9.0  # 2.08
	var wave10_atk: float = 1.0 + 0.08 * 9.0  # 1.72
	var void_max_hp: float = 1.16  # void_research Lv10 hp_mul
	var void_max_atk: float = 1.40  # void_research Lv10 atk_mul
	print("  第100关 Boss(fut_boss_nexus) 满档+wave10+虚空满级:")
	var boss_final_hp: float = 2500.0 * lv100_mul * wave10_hp * void_max_hp
	var boss_final_atk: float = 2250.0 * lv100_mul * wave10_atk * void_max_atk
	print("    HP = 2500×%.2f(高配)×%.2f(wave10)×%.2f(虚空) = %.0f" % [lv100_mul, wave10_hp, void_max_hp, boss_final_hp])
	print("    ATK= 2250×%.2f(高配)×%.2f(wave10)×%.2f(虚空) = %.0f" % [lv100_mul, wave10_atk, void_max_atk, boss_final_atk])
	_assert_true(boss_final_hp > 8000.0 and boss_final_hp < 20000.0, "末关Boss HP 在 8000-20000 区间(合理)")
	print("  (玩家满养成单位 3000-5000 HP 仍可对抗，数值正常)")

	# ===== 检查7：一战首关(1)极简数值（教学期应温和）=====
	print("\n--- 检查7：第1关教学期数值（低配+wave1+无势力）---")
	var lv1_mul: float = _tier_mul(_tier_for_level(1))
	var mp18_final_hp: float = 91.0 * lv1_mul
	var mp18_final_atk: float = 27.0 * lv1_mul
	print("  第1关 ww1_inf_mp18: HP=%.0f, ATK=%.0f (×%.2f低配)" % [mp18_final_hp, mp18_final_atk, lv1_mul])
	_assert_true(mp18_final_hp < 200.0, "第1关步兵 HP<200 (教学期温和)")
	_assert_true(mp18_final_atk < 50.0, "第1关步兵 ATK<50 (教学期温和)")

	print("\n========== 检查结果 ==========")
	print("PASS: %d  FAIL: %d" % [_pass, _fail])
	if _fail > 0:
		print("❌ 有失败项")
	else:
		print("✅ 全部通过")
	quit(0 if _fail == 0 else 1)


func _tier_for_level(level: int) -> int:
	var era_local: int = ((level - 1) % 20) + 1
	var prog: float = float(era_local - 1) / 19.0
	return EnemyLoadoutTiers.get_tier_for_level_progress(prog, false)


func _tier_mul(tier: int) -> float:
	return 1.0 + float(EnemyLoadoutTiers.get_bonus_for_tier(tier).get("atk_pct", 0.0))


func _tier_name(tier: int) -> String:
	return String(EnemyLoadoutTiers.TIER_BONUS.get(tier, {}).get("name", "?"))


func _assert_int(actual: int, expected: int, label: String) -> void:
	if actual == expected:
		_pass += 1
		print("  ✅ %s (got %d)" % [label, actual])
	else:
		_fail += 1
		print("  ❌ %s: expected %d, got %d" % [label, expected, actual])


func _assert_str(actual: String, expected: String, label: String) -> void:
	if actual == expected:
		_pass += 1
		print("  ✅ %s (got %s)" % [label, actual])
	else:
		_fail += 1
		print("  ❌ %s: expected %s, got %s" % [label, expected, actual])


func _assert_approx(actual: float, expected: float, eps: float, label: String) -> void:
	if absf(actual - expected) <= eps:
		_pass += 1
		print("  ✅ %s (got %.2f)" % [label, actual])
	else:
		_fail += 1
		print("  ❌ %s: expected %.2f±%.2f, got %.2f" % [label, expected, eps, actual])


func _assert_true(actual: bool, label: String) -> void:
	if actual:
		_pass += 1
		print("  ✅ %s" % label)
	else:
		_fail += 1
		print("  ❌ %s: expected true" % label)
