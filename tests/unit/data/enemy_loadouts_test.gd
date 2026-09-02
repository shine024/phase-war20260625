extends GdUnitTestSuite
## v26 敌方固定配装表完整性测试
## 覆盖：117 敌方 id 全量覆盖 / 四档 cuts 口径 / 改造 id 已注册 / conflict 无同组 /
## era_band 兼容 / 效果键白名单命中 / 档位切分边界。

var EnemyArchetypes = preload("res://data/enemy_archetypes.gd")
var Registry = preload("res://scripts/systems/modification_registry.gd")
var Tiers = preload("res://data/enemy_loadout_tiers.gd")
var Loadouts = preload("res://data/enemy_fixed_loadouts.gd")

func test_all_enemy_ids_have_loadout() -> void:
	# 全量覆盖：每个敌方原型 id 都有配装条目（含 8 张新飞机）
	var missing: Array = []
	for era in range(5):
		for aid in EnemyArchetypes.get_ids_for_era(era):
			if Loadouts.get_loadout(String(aid)).is_empty():
				missing.append(String(aid))
	assert_array(missing).override_failure_message(
		"未配装敌方 id：%s（跑 tools/gen_enemy_loadout_draft.gd 重生成）" % str(missing.slice(0, 10))).is_empty()

func test_loadout_table_size() -> void:
	assert_int(Loadouts.LOADOUTS.size()).override_failure_message(
		"配装表应 117 条（109 经典 + 8 新飞机）").is_equal(117)

func _entries() -> Array:
	return Loadouts.LOADOUTS.keys()

func test_mods_registered_and_no_conflict_dup() -> void:
	var bad: Array = []
	for aid in _entries():
		var lo: Dictionary = Loadouts.LOADOUTS[aid]
		var mods: Array = lo.get("mods", [])
		var groups: Dictionary = {}
		for mid in mods:
			var md: Dictionary = Registry.get_data(String(mid))
			if md.is_empty():
				bad.append("%s: 未注册改造 %s" % [aid, mid])
				continue
			var g := String(md.get("conflict_group", ""))
			if not g.is_empty():
				if groups.has(g):
					bad.append("%s: conflict_group 重复 %s（%s + %s）" % [aid, g, groups[g], mid])
				else:
					groups[g] = mid
	assert_array(bad).override_failure_message("\n" + "\n".join(bad.slice(0, 12))).is_empty()

func test_mods_whitelist_and_era_compatible() -> void:
	var bad: Array = []
	for aid in _entries():
		var lo: Dictionary = Loadouts.LOADOUTS[aid]
		var mods: Array = lo.get("mods", [])
		var era: int = -1
		for e in range(5):
			if EnemyArchetypes.get_ids_for_era(e).has(aid):
				era = e
				break
		for mid in mods:
			var md: Dictionary = Registry.get_data(String(mid))
			if md.is_empty():
				continue
			if era >= 0 and not Registry.is_mod_era_compatible(md, era):
				bad.append("%s(era%d): %s 超时代带" % [aid, era, mid])
			var eff: Dictionary = md.get("effects", {})
			if eff.is_empty():
				var le: Dictionary = md.get("level_effects", {})
				if not le.is_empty():
					var ks: Array = le.keys()
					ks.sort()
					eff = le[int(ks[ks.size() - 1])]
			var hit := false
			for k in eff.keys():
				if Loadouts.LOADOUT_MOD_SUPPORTED_KEYS.has(String(k)):
					hit = true
					break
			if not hit and not eff.is_empty():
				bad.append("%s: %s 无白名单键（对敌空转）" % [aid, mid])
	assert_array(bad).override_failure_message("\n" + "\n".join(bad.slice(0, 12))).is_empty()

func test_cuts_within_user_spec() -> void:
	# 用户口径：新兵5 / 老兵6-7 / 精英8-9 / 传奇9；且 cuts 单调不减、不超 mods 数
	var bad: Array = []
	for aid in _entries():
		var lo: Dictionary = Loadouts.LOADOUTS[aid]
		var mods: Array = lo.get("mods", [])
		var cuts: Dictionary = lo.get("cuts", Loadouts.DEFAULT_CUTS)
		var prev := 0
		for tier in range(1, 5):
			var n: int = int(cuts.get(tier, -1))
			if tier == 1 and n != 5:
				bad.append("%s: 新兵档应 5 条，实 %d" % [aid, n])
			if tier == 2 and (n < 6 or n > 7):
				bad.append("%s: 老兵档应 6-7 条，实 %d" % [aid, n])
			if tier == 3 and (n < 8 or n > 9):
				bad.append("%s: 精英档应 8-9 条，实 %d" % [aid, n])
			if tier == 4 and n != 9:
				bad.append("%s: 传奇档应 9 条满配，实 %d" % [aid, n])
			if n < prev or n > mods.size():
				bad.append("%s: tier%d 条数 %d 非法（mods=%d）" % [aid, tier, n, mods.size()])
			prev = n
	assert_array(bad).override_failure_message("\n" + "\n".join(bad.slice(0, 12))).is_empty()

func test_tier_split_within_era() -> void:
	# 时代内四段切分：in_era 1-5 新兵 / 6-11 老兵 / 12-17 精英 / 18-20 传奇
	for in_era in range(1, 21):
		var prog: float = float(in_era - 1) / 19.0
		var t: int = Tiers.get_tier_for_level_progress(prog)
		var expect: int = 1
		if in_era >= 18:
			expect = 4
		elif in_era >= 12:
			expect = 3
		elif in_era >= 6:
			expect = 2
		assert_int(t).override_failure_message("in_era %d 应档 %d" % [in_era, expect]).is_equal(expect)

func test_phase_master_tier_constant_legendary() -> void:
	for prog in [0.0, 0.5, 1.0]:
		assert_int(Tiers.get_phase_master_tier(prog)).is_equal(Tiers.TIER_LEGENDARY)

func test_affix_tier_mapping() -> void:
	assert_int(Tiers.LOADOUT_AFFIX_MIN_TIER).is_equal(Tiers.TIER_ELITE)
	assert_int(int(Tiers.LOADOUT_AFFIX_COUNT_BY_TIER.get(Tiers.TIER_LEGENDARY, 0))).is_equal(2)
