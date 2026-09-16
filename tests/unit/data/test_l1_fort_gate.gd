extends GdUnitTestSuite
## v36 实机验收：首关难度保护——堡垒等级门 + WW1 敌方同场上限
## 背景：ww1 碉堡/要塞炮（646HP+堡垒护盾）原从 L1 混入基础池（30% 全池随机通路），
## 新档教学期 3 张绿槽卡打不动；WW1 同场上限 6 对 3 卡数量碾压。

var Manifest = preload("res://data/enemy_unit_manifest.gd")
var Archetypes = preload("res://data/enemy_archetypes.gd")
var LevelEras = preload("res://data/level_eras.gd")


func test_fort_min_level_gate_rows() -> void:
	assert_int(int(Manifest._make_fort_row("ww1_fort_pillbox")["archetype_config"].get("min_level", 0))) \
		.override_failure_message("ww1_fort_pillbox min_level 应为 4").is_equal(4)
	assert_int(int(Manifest._make_fort_row("ww1_fort_artillery")["archetype_config"].get("min_level", 0))) \
		.override_failure_message("ww1_fort_artillery min_level 应为 4").is_equal(4)
	# 其余时代堡垒不受影响（时代门天然限位）
	assert_int(int(Manifest._make_fort_row("fut_fort_shield")["archetype_config"].get("min_level", 0))) \
		.override_failure_message("其余时代堡垒 min_level 应缺省 0").is_equal(0)


func test_l1_to_l3_pool_has_no_fort() -> void:
	# 教学期保护：L1-3 出怪池（含 30% 全池随机通路）无堡垒
	for lv in range(1, 4):
		var pool: Array = Archetypes.get_ids_for_era_at_level(0, lv)
		var forts: Array = pool.filter(func(aid): return String(aid).begins_with("ww1_fort"))
		assert_array(forts).override_failure_message(
			"L%d 池不应含堡垒，实得 %s" % [lv, str(forts)]).is_empty()


func test_l4_pool_has_fort() -> void:
	# 门后照常出现：L4 起堡垒回归（数值面不回归）
	var pool: Array = Archetypes.get_ids_for_era_at_level(0, 4)
	assert_bool(pool.has("ww1_fort_pillbox")) \
		.override_failure_message("L4 池应含 ww1_fort_pillbox（等级门不应误伤后续关卡）").is_true()


func test_ww1_field_cap_is_4() -> void:
	assert_int(int(LevelEras.ERA_ENEMY_FIELD_CAP[LevelEras.Era.WW1])) \
		.override_failure_message("WW1 敌方同场上限应为 4（v36 实机验收）").is_equal(4)


func test_other_era_field_caps_untouched() -> void:
	# 单变量原则：只动 WW1 档，其余时代保持 v8.x 值
	assert_int(int(LevelEras.ERA_ENEMY_FIELD_CAP[LevelEras.Era.WW2])).is_equal(7)
	assert_int(int(LevelEras.ERA_ENEMY_FIELD_CAP[LevelEras.Era.COLD_WAR])).is_equal(8)
	assert_int(int(LevelEras.ERA_ENEMY_FIELD_CAP[LevelEras.Era.MODERN])).is_equal(9)
	assert_int(int(LevelEras.ERA_ENEMY_FIELD_CAP[LevelEras.Era.NEAR_FUTURE])).is_equal(9)
