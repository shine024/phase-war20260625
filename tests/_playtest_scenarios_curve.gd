extends RefCounted
## P2-11 难度曲线采集场景（v3 计划 Task 1.1c；接口同 _playtest_scenarios_v2.gd）
##
## 流程：槽2 → 标题「继续」→ 落地回基地 → GameManager.set_current_level(N)
##   → 战区地图 → 进入本关 → 开战 → wait_sig battle_ended → 探针
##   （last_battle_reward_summary 非空=结算走通；get_level_stars(N)=本场星级判胜负）
##   → save_game → quit_ok。
##
## A 组=裸档；B 组=开战前注入相位场满级（XP 99999 + atk/hp/def 加点）。
## 每轮独立进程（ANGLE 连续截图堆损坏硬约束）；同名场景跑 3 轮=3 次进程。
## 驱动入口：
##   godot --path . --resolution 1280x720 res://tests/_playtest_driver_v2.tscn -- --scenario=r_curve_L43
##   godot --path . --resolution 1280x720 res://tests/_playtest_driver_v2.tscn -- --scenario=r_curve_L43_b

static func _curve_scenario(level: int, group_b: bool) -> Dictionary:
	var tag: String = "L%d%s" % [level, "_b" if group_b else ""]
	var steps: Array = [
		{"t": "frames", "n": 90},
		{"t": "call", "path": "/root/SaveManager", "method": "set_slot", "args": [2]},
		{"t": "frames", "n": 15},
		{"t": "click_text", "text": "继续"},
		{"t": "wait_scene", "match": "scenes/main", "timeout": 2400},
		{"t": "frames", "n": 60},
		{"t": "click_text", "text": "返"},
		{"t": "wait_scene", "match": "truck_base", "timeout": 2400},
		{"t": "frames", "n": 40},
		{"t": "call", "path": "/root/GameManager", "method": "set_current_level", "args": [level]},
		{"t": "frames", "n": 20},
		{"t": "call", "path": "/root/ManagerLazyLoader", "method": "ensure_loaded", "args": ["bunker"]},
		{"t": "frames", "n": 10},
		# 停靠关写入（BunkerManager.get_parked_level 无公开 setter；进地图前对齐，MapActions 才会出「进入本关」）
		{"t": "call", "path": "/root/BunkerManager", "method": "set", "args": ["_parked_level", level]},
		{"t": "frames", "n": 10},
		{"t": "probe", "label": "cur_level_after_set", "path": "/root/GameManager", "prop": "current_level"},
	]
	if group_b:
		steps.append_array([
			{"t": "call", "path": "/root/PhaseInstrumentManager", "method": "grant_phase_field_xp", "args": ["playtest_b_group", 99999]},
			{"t": "call", "path": "/root/PhaseInstrumentManager", "method": "allocate_phase_field_point", "args": ["atk_pct", 12]},
			{"t": "call", "path": "/root/PhaseInstrumentManager", "method": "allocate_phase_field_point", "args": ["hp_pct", 10]},
			{"t": "call", "path": "/root/PhaseInstrumentManager", "method": "allocate_phase_field_point", "args": ["def_pct", 7]},
			{"t": "call", "path": "/root/PhaseInstrumentManager", "method": "get_phase_field_level"},
		])
	steps.append_array([
		{"t": "click_text", "text": "战区地图"},
		{"t": "wait_scene", "match": "world_map", "timeout": 2400},
		{"t": "frames", "n": 60},
		{"t": "shot", "path": "res://.godot/agent_tools/pr_curve_%s_map.png" % tag},
		{"t": "click_text", "text": "进入本关"},
		{"t": "wait_scene", "match": "scenes/main", "timeout": 2400},
		{"t": "frames", "n": 120},
		{"t": "probe", "label": "cur_level_in_scene", "path": "/root/GameManager", "prop": "current_level"},
		{"t": "call", "path": ".", "method": "_on_start_battle"},
		{"t": "frames", "n": 150},
		{"t": "shot", "path": "res://.godot/agent_tools/pr_curve_%s_battle.png" % tag},
		{"t": "fps", "label": "curve_%s_battle" % tag},
		{"t": "wait_sig", "name": "battle_ended", "timeout": 12000},
		{"t": "frames", "n": 150},
		{"t": "call", "path": "/root/LevelProgressManager", "method": "get_level_stars", "args": [level]},
		{"t": "probe", "label": "reward_summary", "path": "/root/GameManager", "prop": "last_battle_reward_summary"},
		{"t": "probe", "label": "max_unlocked_after", "path": "/root/LevelProgressManager", "prop": "max_unlocked_level"},
		{"t": "call", "path": "/root/SaveManager", "method": "save_game"},
		{"t": "frames", "n": 30},
		{"t": "shot", "path": "res://.godot/agent_tools/pr_curve_%s_after.png" % tag},
		{"t": "quit_ok"},
	])
	return {"start": "res://scenes/title_screen.tscn", "steps": steps}


static func get_scenario(name: String) -> Dictionary:
	# r_curve_L43 / r_curve_L50 / r_curve_L60 = A 裸档；追加 _b = B 相位场满级注入组
	var base: String = name.trim_prefix("r_curve_").trim_prefix("L")
	var group_b: bool = base.ends_with("_b")
	if group_b:
		base = base.trim_suffix("_b")
	var level: int = int(base) if base.is_valid_int() else -1
	if level > 0:
		return _curve_scenario(level, group_b)
	# Task 1.1d: 教程回退复看（save=正常保存+driver quit；kill=不落盘等 taskkill）
	if name == "r_tut_save":
		return _tutorial_scenario(false)
	if name == "r_tut_kill":
		return _tutorial_scenario(true)
	if name == "r_tut_probe":
		return _tutorial_probe_scenario()
	return {}


static func _tutorial_scenario(kill_before_save: bool) -> Dictionary:
	var steps: Array = [
		{"t": "frames", "n": 90},
		{"t": "call", "path": "/root/SaveManager", "method": "set_slot", "args": [2]},
		{"t": "frames", "n": 15},
		{"t": "click_text", "text": "继续"},
		{"t": "wait_scene", "match": "scenes/main", "timeout": 2400},
		{"t": "frames", "n": 50},
		{"t": "click_text", "text": "返"},
		{"t": "wait_scene", "match": "truck_base", "timeout": 2400},
		{"t": "frames", "n": 40},
		# 教程步进（程序化）：置 INTRO_WELCOME → 连续完成 3 步
		{"t": "call", "path": "/root/TutorialProgressionManager", "method": "set", "args": ["current_step", 1]},
		{"t": "call", "path": "/root/TutorialProgressionManager", "method": "complete_current_step"},
		{"t": "call", "path": "/root/TutorialProgressionManager", "method": "complete_current_step"},
		{"t": "call", "path": "/root/TutorialProgressionManager", "method": "complete_current_step"},
		{"t": "probe", "label": "tutorial_step_after_3completes", "path": "/root/TutorialProgressionManager", "prop": "current_step"},
	]
	if not kill_before_save:
		steps.append({"t": "call", "path": "/root/SaveManager", "method": "save_game"})
		steps.append({"t": "frames", "n": 10})
		# 保存后同进程复查（区分"保存侧写旧值" vs "保存后内存被改"）
		steps.append({"t": "probe", "label": "tutorial_step_after_save", "path": "/root/TutorialProgressionManager", "prop": "current_step"})
	steps.append({"t": "frames", "n": 30})
	steps.append({"t": "shot", "path": "res://.godot/agent_tools/pr_tut_rollback.png"})
	steps.append({"t": "quit_ok"})
	return {"start": "res://scenes/title_screen.tscn", "steps": steps}


static func _tutorial_probe_scenario() -> Dictionary:
	return {"start": "res://scenes/title_screen.tscn", "steps": [
		{"t": "frames", "n": 90},
		{"t": "call", "path": "/root/SaveManager", "method": "set_slot", "args": [2]},
		{"t": "frames", "n": 15},
		{"t": "click_text", "text": "继续"},
		{"t": "wait_scene", "match": "scenes/main", "timeout": 2400},
		{"t": "frames", "n": 50},
		{"t": "probe", "label": "tutorial_step_on_reload", "path": "/root/TutorialProgressionManager", "prop": "current_step"},
		{"t": "quit_ok"},
	]}
