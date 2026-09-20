extends SceneTree
## R2a 经济批（设计审查 2026-09-13 F-05/09/15）验证脚本
## 运行：godot --headless --rendering-driver opengl3 --path . --script tests/_tmp_r2_economy_check.gd
## 注意：offline_idle_manager 引用 autoload（--script 模式不可独立编译），其行为以源码断言覆盖；
## 乘数公式真身在 GameConfig.offline_reward_factor（无依赖，直接单测）。

var _fails: Array = []
var _passes: int = 0

func _check(cond: bool, label: String) -> void:
	if cond:
		_passes += 1
	else:
		_fails.append(label)

func _init() -> void:
	print("=== R2a economy check ===")
	var GC = load("res://resources/game_config.gd")

	# ── 1. GameConfig 三参数默认值 + reset 保全 ──
	var cfg = GC.new()
	_check(absf(cfg.offline_idle_efficiency - 0.5) < 0.001, "效率系数默认非 0.5")
	_check(cfg.offline_idle_decay_enabled == true, "边际递减默认未开")
	_check(cfg.offline_push_levels_enabled == false, "离线推关默认未冻结")
	cfg.offline_idle_efficiency = 1.0
	cfg.offline_push_levels_enabled = true
	cfg.reset_to_defaults()
	_check(absf(cfg.offline_idle_efficiency - 0.5) < 0.001, "reset 后效率系数未复位")
	_check(cfg.offline_push_levels_enabled == false, "reset 后推关开关未复位")

	# ── 2. 离线收益乘数公式（GameConfig 静态，单例默认值驱动）──
	_check(absf(GC.offline_reward_factor(3600) - 0.5) < 0.001,
		"1h 乘数非 0.5（got %f）" % GC.offline_reward_factor(3600))
	_check(absf(GC.offline_reward_factor(7200) - 0.5) < 0.001, "2h 边界乘数非 0.5")
	# 8h：0.5 × (2h + 6h×0.5)/8h = 0.3125 → 8h 离线收益 ≈ 旧口径 31%（含推关冻结）
	_check(absf(GC.offline_reward_factor(28800) - 0.3125) < 0.001,
		"8h 乘数非 0.3125（got %f）" % GC.offline_reward_factor(28800))
	# 4h：0.5 × (2h + 2h×0.5)/4h = 0.375
	_check(absf(GC.offline_reward_factor(14400) - 0.375) < 0.001, "4h 乘数非 0.375")
	# 关递减 → 恒等于效率系数
	var dflt = GC.get_default()
	var saved_decay: bool = dflt.offline_idle_decay_enabled
	dflt.offline_idle_decay_enabled = false
	_check(absf(GC.offline_reward_factor(28800) - 0.5) < 0.001, "关递减后 8h 乘数非 0.5")
	dflt.offline_idle_decay_enabled = saved_decay

	# ── 3. offline_idle_manager 源码断言（battles 乘数接入 + 推关冻结门）──
	var oim_src: String = FileAccess.get_file_as_string("res://scripts/systems/offline_idle_manager.gd")
	_check(oim_src.contains("offline_reward_factor(capped)"), "battles 未乘离线收益系数")
	_check(oim_src.contains("if _GameConfigScript.get_default().offline_push_levels_enabled:"),
		"推关冻结门缺失")

	# ── 4. 日常奖励池 ×3（源码断言：manager 引用 autoload，--script 不可实例化）──
	var dtm_src: String = FileAccess.get_file_as_string("res://managers/daily_task_manager.gd")
	_check(dtm_src.contains('"nano_materials": [150, 300]'), "EASY 日常纳米非 150-300")
	_check(dtm_src.contains('"nano_materials": [1200, 2400]'), "EXPERT 日常纳米非 1200-2400")
	_check(dtm_src.contains('"energy_blocks": [60, 120]'), "EXPERT 能量块非 60-120")

	# ── 5. 委托奖励 ×3（直接 JSON 解析，零脚本编译依赖）──
	var qtext: String = FileAccess.get_file_as_string("res://data/json/quest_definitions.json")
	var qparse: Variant = JSON.parse_string(qtext)
	var nano_vals: Array = []
	if qparse is Dictionary and (qparse as Dictionary).get("data", []) is Array:
		for q in qparse["data"]:
			var r: Dictionary = (q as Dictionary).get("rewards", {})
			if r.has("nano_materials"):
				nano_vals.append(int(r["nano_materials"]))
	_check(nano_vals.size() == 57, "委托数 %d ≠ 57" % nano_vals.size())
	if not nano_vals.is_empty():
		var mn: int = nano_vals[0]
		var mx: int = nano_vals[0]
		for v in nano_vals:
			mn = mini(mn, v)
			mx = maxi(mx, v)
		_check(mn == 15 and mx == 720, "委托纳米范围 %d-%d ≠ 15-720" % [mn, mx])
	# LEGACY 回退表同步核对（防 JSON/LEGACY 双轨漂移；LEGACY 值域与 JSON 独立，只验同步倍率）
	var qd_src: String = FileAccess.get_file_as_string("res://data/quest_definitions.gd")
	var legacy_cnt: int = 0
	for m in qd_src.split("\n"):
		if m.contains('"nano_materials": '):
			legacy_cnt += 1
	_check(legacy_cnt == 57 and qd_src.contains('"nano_materials": 600'),
		"LEGACY 委托表未同步 ×3（条数 %d / 最大值缺失）" % legacy_cnt)

	# ── 6. 燃料回复 5/min ──
	var TT = load("res://data/truck_travel.gd")
	if TT != null:
		_check(absf(TT.REGEN_BASE_PER_MIN - 5.0) < 0.001, "燃料基础回复非 5.0/min")
	else:
		_check(false, "truck_travel 编译失败")

	# ── 7. 精神连胜减免（源码断言：advance_after_battle 内含节点依赖，不能实例跑）──
	var bm_src: String = FileAccess.get_file_as_string("res://managers/bunker_manager.gd")
	_check(bm_src.contains("_win_streak >= 3") and bm_src.contains("maxf(6.0, win_cost - 2.0)"),
		"连胜减免逻辑缺失")

	if _fails.is_empty():
		print("ALL PASS (%d checks)" % _passes)
		quit(0)
	else:
		for f in _fails:
			push_error("[R2-CHECK] " + f)
		print("FAILED: %d / passed %d" % [_fails.size(), _passes])
		quit(1)
