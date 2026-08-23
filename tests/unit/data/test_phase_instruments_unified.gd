extends GdUnitTestSuite

const PhaseInstruments = preload("res://data/phase_instruments.gd")


func test_enemy_migrated_ids_exist() -> void:
	var ids := ["pi_steel_01", "pi_steel_05", "pi_flame_04", "pi_void_05",
				"pi_thunder_03", "pi_steelflame_01", "pi_omega_01"]
	for id in ids:
		var d: Dictionary = PhaseInstruments.get_by_id(id)
		assert(not d.is_empty(), "缺失统一池 id: %s" % id)
		assert_bool(d.get("is_generic", false)).is_true()


func test_enemy_instruments_have_slot_counts_and_level() -> void:
	var d: Dictionary = PhaseInstruments.get_by_id("pi_steel_03")
	var sc: Dictionary = d.get("slot_counts", {})
	assert_int(int(sc.get("green", 0))).is_greater(0)
	assert_int(int(d.get("level", 0))).is_equal(18)


func test_enemy_active_ability_ids_bare() -> void:
	var s3: Dictionary = PhaseInstruments.get_by_id("pi_steel_03").get("active_ability", {})
	assert_str(str(s3.get("id", ""))).is_equal("mega_shield")
	var v5: Dictionary = PhaseInstruments.get_by_id("pi_void_05").get("active_ability", {})
	assert_str(str(v5.get("id", ""))).is_equal("nano_swarm")
	var f4: Dictionary = PhaseInstruments.get_by_id("pi_flame_04").get("active_ability", {})
	assert_str(str(f4.get("id", ""))).is_equal("artillery_barrage")
	var s4: Dictionary = PhaseInstruments.get_by_id("pi_steel_04").get("active_ability", {})
	assert_str(str(s4.get("id", ""))).is_equal("rage_buff")


func test_enemy_bare_instruments_have_empty_active_ability() -> void:
	# 无 ability 的款 active_ability 应为空 Dictionary。
	# 批次8（2026-08-23）：v6.6 能力批次给六款补了 active_ability——专家档三家
	# （pi_flame_03 炮击/pi_thunder_03 炮击/pi_void_03 穿刺）与大师/神档三家
	# （pi_flame_05 核轰/pi_thunder_04 炮击/pi_thunder_05 炮击），从裸仪清单移除。
	var bare_ids := ["pi_steel_01", "pi_steel_02", "pi_flame_01", "pi_flame_02",
					"pi_thunder_01", "pi_thunder_02", "pi_void_01", "pi_void_02",
					"pi_steelflame_01", "pi_thundersteel_01", "pi_voidflame_01",
					"pi_steelthunder_01", "pi_flamevoid_01", "pi_omega_01"]
	for id in bare_ids:
		var ab: Dictionary = PhaseInstruments.get_by_id(id).get("active_ability", {"_x": 1})
		assert_bool(ab.is_empty()).is_true()


func test_all_enemy_ids_unique_and_present() -> void:
	var enemy_ids := ["pi_steel_01", "pi_steel_02", "pi_steel_03", "pi_steel_04", "pi_steel_05",
					"pi_flame_01", "pi_flame_02", "pi_flame_03", "pi_flame_04", "pi_flame_05",
					"pi_thunder_01", "pi_thunder_02", "pi_thunder_03", "pi_thunder_04", "pi_thunder_05",
					"pi_void_01", "pi_void_02", "pi_void_03", "pi_void_04", "pi_void_05",
					"pi_steelflame_01", "pi_thundersteel_01", "pi_voidflame_01",
					"pi_steelthunder_01", "pi_flamevoid_01", "pi_omega_01"]
	assert_int(enemy_ids.size()).is_equal(26)
	var seen: Dictionary = {}
	for id in enemy_ids:
		assert_bool(not seen.has(id)).is_true()
		seen[id] = true
		var d: Dictionary = PhaseInstruments.get_by_id(id)
		assert_bool(not d.is_empty()).is_true()
		# 敌方款统一标记
		assert_str(str(d.get("faction_id", ""))).is_equal("generic")
		assert_bool(d.get("is_generic", false)).is_true()
		assert_str(str(d.get("acquire_rule", ""))).is_equal("phase_master_drop")
		# level 字段必须存在且 > 0
		assert_int(int(d.get("level", 0))).is_greater(0)


func test_player_instruments_still_present() -> void:
	assert_bool(not PhaseInstruments.get_by_id("pi_generic_01").is_empty()).is_true()
	assert_bool(not PhaseInstruments.get_by_id("pi_special_rage").is_empty()).is_true()


func test_total_instrument_count() -> void:
	# 42 玩家款（12 通用 + 23 势力 + 4 特殊掉落 + 3 补丁旧款算入）+ 26 敌方 = 68
	# 注：spec 原写 35+26=61，但实际 _build_all() 玩家款为 42（见 _make_def 调用计数）。
	assert_int(PhaseInstruments.get_all().size()).is_equal(68)
