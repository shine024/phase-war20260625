class_name SaveLoadInvariantsTest
extends GdUnitTestSuite

## v26.6 存档读侧不变式回归锁：
## ① int 字典 key 经 JSON 往返后必须归一化（读档星级归零/首通奖励重复发放的根因）
## ② 存档缺段时必须复位到默认（"先重置再覆盖"不变式，跨档污染家族的根因）
## ③ 切槽必须清非关键段缓存
## ④ 手改档非法类型/负值不得中断加载


func test_level_progress_int_key_survives_json_roundtrip() -> void:
	var lpm = auto_free(load("res://managers/level_progress_manager.gd").new())
	# 模拟 JSON 往返：int key 全部变 String key（混合写法贴近真实旧档）
	var raw := {
		"level_stars": {3: 2, "5": 1},
		"first_completion": {"3": true},
		"unlocked_eras": {2: true},
		"unlocked_levels": [1, 2, 3],
		"max_unlocked_level": 3,
	}
	var parsed: Variant = JSON.parse_string(JSON.stringify(raw))
	assert_bool(parsed is Dictionary).is_true()
	lpm.load_state(parsed)
	assert_int(lpm.get_level_stars(3)).is_equal(2)
	assert_int(lpm.get_level_stars(5)).is_equal(1)
	assert_int(lpm.get_level_stars(7)).is_equal(0)
	assert_bool(lpm.is_first_completion(3)).is_false()
	assert_bool(lpm.is_first_completion(7)).is_true()
	assert_bool(lpm.is_era_unlocked(2)).is_true()
	assert_bool(lpm.is_era_unlocked(3)).is_false()


func test_level_progress_out_of_range_entries_dropped() -> void:
	var lpm = auto_free(load("res://managers/level_progress_manager.gd").new())
	lpm.load_state({"level_stars": {"0": 3, "999": 3, "4": 9}, "first_completion": {}, "unlocked_eras": {"9": true}})
	assert_bool(lpm.level_stars.has(0)).is_false()
	assert_bool(lpm.level_stars.has(999)).is_false()
	assert_int(lpm.get_level_stars(4)).is_equal(3)  # 值钳到 0-3
	assert_bool(lpm.is_era_unlocked(9)).is_false()


func test_day_clock_empty_load_resets_to_defaults() -> void:
	var dc = auto_free(load("res://managers/day_clock.gd").new())
	dc.current_day = 200
	dc.current_phase = 3
	dc.total_loops = 2
	dc.year_completed = true
	dc.load_state({})
	assert_int(dc.current_day).is_equal(1)
	assert_int(dc.current_phase).is_equal(0)
	assert_int(dc.total_loops).is_equal(0)
	assert_bool(dc.year_completed).is_false()


func test_day_clock_clamps_out_of_range_values() -> void:
	var dc = auto_free(load("res://managers/day_clock.gd").new())
	dc.load_state({"current_day": 9999, "current_phase": 9, "total_loops": -3})
	assert_int(dc.current_day).is_equal(365)
	assert_int(dc.current_phase).is_equal(4)
	assert_int(dc.total_loops).is_equal(0)


func test_save_manager_set_slot_clears_noncritical_cache() -> void:
	var sm := get_node_or_null("/root/SaveManager")
	assert_bool(sm != null).is_true()
	sm._noncritical_save_cache["stale_key"] = {"x": 1}
	var prev_slot: int = sm.get_slot()
	sm.set_slot(2 if prev_slot != 2 else 1)
	assert_dict(sm._noncritical_save_cache).is_empty()
	sm.set_slot(prev_slot)  # 还原全局槽位


func test_save_manager_missing_section_resets_manager() -> void:
	var sm := get_node_or_null("/root/SaveManager")
	var dc := get_node_or_null("/root/DayClock")
	assert_bool(sm != null).is_true()
	assert_bool(dc != null).is_true()
	dc.current_day = 42
	# 存档缺该段 → 复位到默认（而非保留内存残留）
	sm._safe_load_manager("/root/DayClock", {}, "no_such_section_key")
	assert_int(dc.current_day).is_equal(1)


func test_quest_empty_load_resets_accepted() -> void:
	var qm = auto_free(load("res://managers/quest_manager.gd").new())
	qm._accepted = {"q_x": {"progress": 1}}
	qm._completed_ids = ["q_x"]
	qm.load_state({})
	assert_dict(qm._accepted).is_empty()
	assert_array(qm._completed_ids).is_empty()


func test_blueprint_empty_load_resets_mods() -> void:
	var bm = auto_free(load("res://managers/blueprint_manager.gd").new())
	bm.blueprint_mods = {"ww1_mauser": [{"mod": "inf_01"}]}
	bm.blueprint_weapon_slots = {"ww1_mauser": []}
	bm.load_state({})
	assert_dict(bm.blueprint_mods).is_empty()
	assert_dict(bm.blueprint_weapon_slots).is_empty()


func test_brm_negative_resources_clamped() -> void:
	var brm = auto_free(load("res://managers/basic_resource_manager.gd").new())
	brm.load_state({"total_nano_materials": -5, "total_alloy": -1, "total_crystal": 10, "total_energy_block": -100})
	assert_int(brm.total_nano_materials).is_equal(0)
	assert_int(brm.total_alloy).is_equal(0)
	assert_int(brm.total_crystal).is_equal(10)
	assert_int(brm.total_energy_block).is_equal(0)


func test_achievement_hostile_types_do_not_crash() -> void:
	var am = auto_free(load("res://managers/achievement_manager.gd").new())
	# 手改档把 Dictionary 字段换成 Array/String/数字——不得抛错中断 deferred 加载批次
	am.load_state({"unlocked_achievements": "bad", "achievement_progress": ["bad"], "reward_claimed": 1, "battle_stats": [], "collection_stats": 3})
	assert_int(am.unlocked_achievements.size()).is_equal(0)
	assert_int(am.achievement_progress.size()).is_equal(0)


func test_daily_task_hostile_tasks_type_does_not_crash() -> void:
	var dtm = auto_free(load("res://managers/daily_task_manager.gd").new())
	# tasks 被写成 Dictionary 时不得抛错中断加载批次；
	# last_refresh 负值被钳 0 → 视为过期触发重刷（重刷会写当前时间戳，语义正确）
	dtm.load_state({"tasks": {"bad": 1}, "last_refresh": -5})
	assert_bool(dtm._daily_tasks is Array).is_true()


func test_afk_shutdown_without_init_is_safe() -> void:
	var afk = load("res://scripts/systems/afk_mode_manager.gd").new()
	afk.shutdown()  # 未 init（_signal_bus 为 null）不得崩溃
	assert_bool(afk.is_running).is_false()
