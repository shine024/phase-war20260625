class_name GateCoreStructureTest
extends GdUnitTestSuite
## v6.35 黑门 2.0 回归锁:随机本体深度/本体波构成/通关态/补给节点/首通 flag/布局池/渗透节点。
## 契约见 CHANGELOG v6.35 + AGENTS.md 对应段。EBM = EndlessBlackgateManager(autoload 懒加载)。

const EBMPath := "/root/EndlessBlackgateManager"


func _ebm() -> Node:
	var mll: Node = get_node_or_null("/root/ManagerLazyLoader")
	if mll != null and mll.has_method("ensure_loaded"):
		mll.ensure_loaded("endless")
	return get_node_or_null(EBMPath)


func _gm() -> Node:
	return get_node_or_null("/root/GameManager")


func _ebm_snapshot() -> Dictionary:
	var e := _ebm()
	return {
		"run_active": e.run_active, "gate_core_wave": e.gate_core_wave,
		"gate_cleared": e.gate_cleared, "gate_choice_pending": e.gate_choice_pending,
		"supplies_granted": e.supplies_granted, "gate_cleared_once": e.gate_cleared_once,
		"incursions": e.incursions.duplicate(true), "layout_variant": e.layout_variant,
		"current_rift_env": e.current_rift_env,
	}


func _ebm_restore(s: Dictionary) -> void:
	var e := _ebm()
	e.run_active = s["run_active"]
	e.gate_core_wave = s["gate_core_wave"]
	e.gate_cleared = s["gate_cleared"]
	e.gate_choice_pending = s["gate_choice_pending"]
	e.supplies_granted = s["supplies_granted"]
	e.gate_cleared_once = s["gate_cleared_once"]
	e.incursions = s["incursions"]
	e.layout_variant = s["layout_variant"]
	e.current_rift_env = s["current_rift_env"]


func before_test() -> void:
	pass


func after_test() -> void:
	pass


## 本体深度随机区间:begin_run 后 gate_core_wave ∈ [200,320] 且为 10 的倍数
func test_begin_run_rolls_gate_core_wave_in_range() -> void:
	var e := _ebm()
	assert_object(e).is_not_null()
	var bak := _ebm_snapshot()
	for _i in range(30):
		e.begin_run()
		e.run_active = false  # 防止下一次 begin_run 双扣入场次数
		assert_int(e.gate_core_wave).is_between(200, 320)
		assert_int(e.gate_core_wave % 10).is_equal(0)
		assert_bool(e.gate_cleared).is_false()
	_ebm_restore(bak)


## 本体波构成:is_core_wave 分支只在本体深度波触发;cleared 后不再刷
## (经由 spawn 系统私有逻辑不可直测——这里锁 EBM 侧语义:mark_gate_cleared 幂等+信号)
func test_mark_gate_cleared_sets_state_once_and_clears_incursions() -> void:
	var e := _ebm()
	var bak := _ebm_snapshot()
	e.run_active = true
	e.incursions = [{"host_level": 90, "seed": 7, "spawned_day": 1}]
	var fired: Array = []
	e.gate_core_destroyed.connect(func() -> void: fired.append(1))
	e.mark_gate_cleared()
	assert_bool(e.gate_cleared).is_true()
	assert_bool(e.gate_choice_pending).is_true()
	assert_int(fired.size()).is_equal(1)
	# 幂等:第二次 mark 不重复发信号
	e.mark_gate_cleared()
	assert_int(fired.size()).is_equal(1)
	# 黑门关闭世界状态:渗透节点清空
	assert_array(e.incursions).is_empty()
	# 选择收口
	e.resolve_gate_choice()
	assert_bool(e.gate_choice_pending).is_false()
	_ebm_restore(bak)


## 补给节点:25 的倍数波入账、重复触发守卫、非节点波拒绝
func test_supply_node_grants_once_per_interval() -> void:
	var e := _ebm()
	var bak := _ebm_snapshot()
	e.run_active = true
	e.supplies_granted = 0
	assert_dict(e.grant_supply_node(10)).is_empty()   # 非节点波
	assert_dict(e.grant_supply_node(25)).is_not_empty()  # 节点波入账
	assert_int(e.supplies_granted).is_equal(1)
	assert_dict(e.grant_supply_node(25)).is_empty()   # 同节点重入守卫
	assert_dict(e.grant_supply_node(50)).is_not_empty()  # 下一节点
	assert_int(e.supplies_granted).is_equal(2)
	e.gate_cleared = true
	assert_dict(e.grant_supply_node(75)).is_empty()   # 通关后不再发
	_ebm_restore(bak)


## 首通大奖:settle_run 消费 gate_cleared 一次性发 flag,二刷不再发
func test_settle_run_first_clear_flag() -> void:
	var e := _ebm()
	var bak := _ebm_snapshot()
	e.run_active = true
	e.gate_cleared_once = false
	e.gate_cleared = true
	var s1: Dictionary = e.settle_run(210, 100)
	assert_bool(s1.get("gate_cleared", false)).is_true()
	assert_bool(s1.get("gate_first_clear", false)).is_true()
	assert_bool(e.gate_cleared_once).is_true()
	# 二次通关 run:有 gate_cleared 但非首通
	e.run_active = true
	e.gate_cleared = true
	var s2: Dictionary = e.settle_run(220, 100)
	assert_bool(s2.get("gate_cleared", false)).is_true()
	assert_bool(s2.get("gate_first_clear", false)).is_false()
	_ebm_restore(bak)


## 渗透节点:日刷上限/过期/erase 匹配/编队确定性
func test_incursion_lifecycle() -> void:
	var e := _ebm()
	var bak := _ebm_snapshot()
	e.incursions = []
	e.gate_cleared_once = false
	# erase 按 host+seed 匹配
	e.incursions = [{"host_level": 90, "seed": 7, "spawned_day": 1}, {"host_level": 80, "seed": 9, "spawned_day": 1}]
	e.erase_incursion({"host_level": 90, "seed": 7})
	assert_array(e.incursions).has_size(1)
	assert_int(int(e.incursions[0].get("seed", 0))).is_equal(9)
	# 编队确定性:同 seed 同编队
	var inc := {"host_level": 88, "seed": 12345, "spawned_day": 1}
	var l1: Dictionary = e.get_incursion_loadout(inc)
	var l2: Dictionary = e.get_incursion_loadout(inc)
	assert_array(l1.get("ids", [])).is_not_empty()
	assert_array(l1.get("ids", [])).is_equal(l2.get("ids", []))
	# 编队规模 4-6 只(3-5 基础 + 1 精英位)
	assert_int(int(l1.get("ids", []).size())).is_between(4, 6)
	# 通关停刷语义(世界状态在 mark_gate_cleared 清场;此处锁 loadout 对空表安全)
	e.incursions = []
	assert_array(e.get_incursion_loadout(inc).get("ids", [])).is_not_empty()  # 推导不依赖在场表
	_ebm_restore(bak)


## 布局池:变体表驱动/越界回退默认/应用与复位
func test_endless_layout_variants() -> void:
	var layouts := load("res://data/level_battle_layouts.gd")
	var cgl := load("res://scripts/card_grid_battle_layout.gd")
	var count: int = layouts.get_endless_variant_count()
	assert_int(count).is_between(2, 8)
	for i in range(count):
		assert_dict(layouts.get_endless_variant(i)).is_not_empty()
	assert_dict(layouts.get_endless_variant(-1)).is_empty()
	assert_dict(layouts.get_endless_variant(999)).is_empty()
	# 应用变体 1(4 列×3 行) → 槽位变化;复位 → 默认 3x3
	assert_bool(cgl.apply_for_endless(1)).is_true()
	assert_int(cgl.player_slots_total()).is_equal(12)
	assert_bool(cgl.apply_for_endless(0)).is_true()
	cgl.reset_to_default()
	assert_int(cgl.player_slots_total()).is_equal(9)
	# 收尾恢复(不确定前值就复位默认,与 end_battle 同律)
	cgl.reset_to_default()


## 敌成长分段收敛:普通关小波次零变化、高波收敛(数值定案断言)
func test_enemy_stat_resolver_segmented_growth() -> void:
	var r := load("res://data/enemy_stat_resolver.gd")
	# 第一段(≤60 波)与旧线性完全一致:wave 1 = 1.0, wave 10 = 1.72
	assert_float(r.wave_hp_multiplier(1)).is_equal_approx(1.0, 0.0001)
	assert_float(r.wave_hp_multiplier(10)).is_equal_approx(1.72, 0.0001)
	# 收敛段:wave 300 = 1+0.08×59+0.015×240 = 9.32(定案值)
	assert_float(r.wave_hp_multiplier(300)).is_equal_approx(9.32, 0.0001)
	assert_float(r.wave_damage_multiplier(300)).is_equal_approx(7.42, 0.0001)
	# 攻防一致地:wave 1 恒 1.0
	assert_float(r.wave_damage_multiplier(1)).is_equal_approx(1.0, 0.0001)
	assert_float(r.wave_def_multiplier(1)).is_equal_approx(1.0, 0.0001)


## 出兵 gate:通关弹窗待选择期间波间隔事实暂停
func test_wave_interval_holds_on_gate_choice() -> void:
	var e := _ebm()
	var gm := _gm()
	var bak := _ebm_snapshot()
	var bak_endless: bool = gm._is_endless_battle
	e.run_active = true
	e.gate_choice_pending = true
	gm._is_endless_battle = true
	assert_float(gm.get_enemy_wave_interval_for_level(100)).is_equal_approx(3600.0, 0.001)
	e.gate_choice_pending = false
	assert_float(gm.get_enemy_wave_interval_for_level(100)).is_equal_approx(7.0, 0.001)
	gm._is_endless_battle = bak_endless
	_ebm_restore(bak)


## 渗透轻结算口径常量存在(收益很小定案,C3 数值单一真身)
func test_incursion_and_supply_constants() -> void:
	var e := _ebm()
	assert_int(e.GATE_CORE_WAVE_MIN).is_equal(200)
	assert_int(e.GATE_CORE_WAVE_MAX).is_equal(320)
	assert_int(e.SUPPLY_INTERVAL).is_equal(25)
	assert_int(e.INCURSION_MAX).is_equal(3)
	assert_int(e.GATE_FIRST_CLEAR_MARROW).is_equal(200)
	# xeno 本体条目存在且不在常规轮换池
	var xu := load("res://data/xeno_units.gd")
	assert_bool(xu.UNITS.has("xeno_gate_core")).is_true()
	assert_str(String(xu.UNITS["xeno_gate_core"].get("role", ""))).is_equal("core")
	assert_array(xu.get_ids_for_role("boss")).not_contains(["xeno_gate_core"])
	# 缴获本体卡必须可部署:power 不得超 power_cap 上限(2400=无垠档)
	assert_int(int(xu.UNITS["xeno_gate_core"].get("power", 0))).is_less_equal(2400)


## v6.35 复查锁:渗透战备态不直接开打——start_incursion_battle 只置 pending/关卡对齐,
## go_to_battle 由 main 标准管线(show_battle)触发。回退旧直接开打代码此用例必红。
func test_start_incursion_battle_preps_only() -> void:
	var e := _ebm()
	var gm := _gm()
	var bak := _ebm_snapshot()
	var bak_level: int = int(gm.current_level)
	var bak_phase: int = int(gm.current_phase)
	e.incursions = [{"host_level": 88, "seed": 42, "spawned_day": 1}]
	gm.start_incursion_battle(e.incursions[0])
	assert_array(gm.pending_incursion_loadout).is_not_empty()
	assert_bool(bool(gm.is_incursion_battle())).is_true()
	assert_int(int(gm.current_level)).is_equal(88)
	# 未直接开打:战斗相位不进 BATTLE(留给 main 管线)
	assert_int(int(gm.current_phase)).is_equal(bak_phase)
	# 清理渗透态
	gm.pending_incursion_loadout = []
	gm.set("_is_incursion_battle", false)
	gm.set("_pending_incursion", {})
	gm.set_current_level(bak_level)
	_ebm_restore(bak)
